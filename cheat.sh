#!/usr/bin/env sh
# Minimal OpenAI chat client with interactive mode
# ─────────────
# Non-interactive:
#   ./cheat.sh "Tell me a joke"
#   echo "Explain DNS like I'm five" | ./cheat.sh
#
# Interactive shell:
#   ./cheat.sh -i          # REPL, quit with Ctrl-C or blank line
#
# Env vars:
#   OPENAI_API_KEY   (required)
#   MODEL            (default gpt-4.1-nano)
#   API_URL          (default http://127.0.0.1:8000)
#   JQ               (set to 0 to force dumb JSON parse)

set -e

die() { echo "$*" >&2; exit 1; }

[ -z "$OPENAI_API_KEY" ] && die "OPENAI_API_KEY not set, sort it out."

MODEL=${MODEL:-gpt-4.1-nano}
USE_JQ=${JQ:-1}
API_URL=${API_URL:-https://cheat-cli-api.abdulbaaridavids04.workers.dev}

# Colors (only if terminal supports them)
if [ -t 1 ] && [ "${TERM:-}" != "dumb" ]; then
  RED='\033[0;31m'
  BLUE='\033[0;34m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  CYAN='\033[0;36m'
  GRAY='\033[0;90m'
  BOLD='\033[1m'
  RESET='\033[0m'
else
  RED=''
  BLUE=''
  GREEN=''
  YELLOW=''
  CYAN=''
  GRAY=''
  BOLD=''
  RESET=''
fi

call_openai() {
  prompt=$1
  
  # Show simple thinking placeholder if in interactive mode
  thinking_shown=false
  if [ -t 1 ]; then
    printf " ${GRAY}<Thinking...>${RESET}"
    thinking_shown=true
  fi
  
  # Call API and get complete response
  response=$(curl -sS "$API_URL/chat" \
    -H "Content-Type: application/json" \
    -d '{
      "model": "'"$MODEL"'",
      "messages": [{"role": "user", "content": "'"$(printf %s "$prompt" | sed 's/"/\\"/g')"'"}],
      "stream": false
    }')
  
  # Clear thinking placeholder and show model prompt
  if [ "$thinking_shown" = true ]; then
    printf "\r%s> " "$MODEL"
  fi
  
  # Apply streaming effect locally
  if [ -t 1 ]; then
    # Stream word by word for interactive mode
    echo "$response" | while IFS= read -r line || [ -n "$line" ]; do
      # Split line into words and stream them
      printf "%s" "$line" | sed 's/ /\n/g' | while IFS= read -r word || [ -n "$word" ]; do
        if [ -n "$word" ]; then
          printf "%s " "$word"
          sleep 0.05 2>/dev/null || true
        fi
      done
      echo # Newline after each line
    done
  else
    # Just print directly for non-interactive
    printf "%s" "$response"
  fi
  
  echo # Final newline
}

# --- interactive UI ---------------------------------------------------------
if [ "$1" = "-i" ] || [ "$1" = "--interactive" ]; then
  printf "${BOLD}${CYAN}Chatting with ${YELLOW}%s${CYAN}. Blank line to quit.${RESET}\n" "$MODEL"
  while printf '\nyou> ' && IFS= read -r line; do
    [ -z "$line" ] && break
    # quick switch: /model gpt-4o-mini
    case "$line" in
      /model*) MODEL=$(printf %s "$line" | awk '{print $2}'); printf "${GREEN}Switched model to ${YELLOW}%s${RESET}\n" "$MODEL"; continue ;;
      /help) printf "${CYAN}Commands: ${YELLOW}/model MODELNAME${CYAN}, blank line to exit${RESET}\n"; continue ;;
    esac
    printf '\n%s> ' "$MODEL"
    call_openai "$line"
  done
  printf "${CYAN}Bye.${RESET}\n"
  exit 0
fi
# ---------------------------------------------------------------------------

# batch mode (args or stdin) or default to interactive
if [ "$#" -gt 0 ]; then
  call_openai "$*"
else
  # Check if stdin has data (non-interactive) or is empty (interactive)
  if [ -t 0 ]; then
    # stdin is a terminal (no piped input), go interactive
    printf "${BOLD}${CYAN}Chatting with ${YELLOW}%s${CYAN}. Blank line to quit.${RESET}\n" "$MODEL"
    while printf '\nyou> ' && IFS= read -r line; do
      [ -z "$line" ] && break
      # quick switch: /model gpt-4o-mini
      case "$line" in
        /model*) MODEL=$(printf %s "$line" | awk '{print $2}'); printf "${GREEN}Switched model to ${YELLOW}%s${RESET}\n" "$MODEL"; continue ;;
        /help) printf "${CYAN}Commands: ${YELLOW}/model MODELNAME${CYAN}, blank line to exit${RESET}\n"; continue ;;
      esac
      printf '\n%s> ' "$MODEL"
      call_openai "$line"
    done
    printf "${CYAN}Bye.${RESET}\n"
  else
    # stdin has piped data, use it
    input=$(cat)
    [ -z "$input" ] && die "No prompt given."
    call_openai "$input"
  fi
fi
