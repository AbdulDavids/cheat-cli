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
  
  # Simple interactive loop that works with piped input
  while true; do
    printf '\nyou> '
    
    # Try to read from terminal directly
    if command -v read >/dev/null 2>&1; then
      if read -r line < /dev/tty 2>/dev/null; then
        : # Successfully read from terminal
      else
        # Fallback: try regular read
        read -r line || break
      fi
    else
      # No read command, try alternative
      line=$(head -n1 < /dev/tty 2>/dev/null || head -n1)
    fi
    
    # Exit on empty line
    [ -z "$line" ] && break
    
    # Handle commands
    case "$line" in
      /model*) 
        new_model=$(printf %s "$line" | awk '{print $2}')
        if [ -n "$new_model" ]; then
          MODEL="$new_model"
          printf "${GREEN}Switched model to ${YELLOW}%s${RESET}\n" "$MODEL"
        else
          printf "${CYAN}Available models: ${YELLOW}gpt-4o, gpt-4o-mini, gpt-4-turbo, gpt-3.5-turbo, gpt-4.1-nano${RESET}\n"
          printf "${CYAN}Usage: ${YELLOW}/model gpt-4o${RESET}\n"
        fi
        continue ;;
      /models)
        printf "${CYAN}Available models:${RESET}\n"
        printf "  ${YELLOW}gpt-4o${RESET} - Latest GPT-4 model\n"
        printf "  ${YELLOW}gpt-4o-mini${RESET} - Faster, cheaper GPT-4\n"
        printf "  ${YELLOW}gpt-4-turbo${RESET} - High performance GPT-4\n"
        printf "  ${YELLOW}gpt-3.5-turbo${RESET} - Fast and efficient\n"
        printf "  ${YELLOW}gpt-4.1-nano${RESET} - Compact model\n"
        printf "${CYAN}Switch with: ${YELLOW}/model MODEL_NAME${RESET}\n"
        continue ;;
      /help) 
        printf "${CYAN}Commands:${RESET}\n"
        printf "  ${YELLOW}/model MODEL_NAME${CYAN} - Switch to a different model${RESET}\n"
        printf "  ${YELLOW}/models${CYAN} - List available models${RESET}\n"
        printf "  ${YELLOW}/help${CYAN} - Show this help${RESET}\n"
        printf "  ${YELLOW}/quit${CYAN} or ${YELLOW}/exit${CYAN} - Exit chat${RESET}\n"
        printf "  ${CYAN}Empty line - Exit chat${RESET}\n"
        continue ;;
      /quit|/exit) break ;;
    esac
    
    printf '\n%s> ' "$MODEL"
    call_openai "$line"
  done
  printf "${CYAN}Bye.${RESET}\n"
  exit 0
fi

# Remove the -i-local handler since we're not using that approach anymore
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
        /model*) 
          new_model=$(printf %s "$line" | awk '{print $2}')
          if [ -n "$new_model" ]; then
            MODEL="$new_model"
            printf "${GREEN}Switched model to ${YELLOW}%s${RESET}\n" "$MODEL"
          else
            printf "${CYAN}Available models: ${YELLOW}gpt-4o, gpt-4o-mini, gpt-4-turbo, gpt-3.5-turbo, gpt-4.1-nano${RESET}\n"
          fi
          continue ;;
        /models)
          printf "${CYAN}Available models:${RESET}\n"
          printf "  ${YELLOW}gpt-4o${RESET} - Latest GPT-4 model\n"
          printf "  ${YELLOW}gpt-4o-mini${RESET} - Faster, cheaper GPT-4\n"
          printf "  ${YELLOW}gpt-4-turbo${RESET} - High performance GPT-4\n"
          printf "  ${YELLOW}gpt-3.5-turbo${RESET} - Fast and efficient\n"
          printf "  ${YELLOW}gpt-4.1-nano${RESET} - Compact model\n"
          continue ;;
        /help) 
          printf "${CYAN}Commands: ${YELLOW}/model MODEL${CYAN}, ${YELLOW}/models${CYAN}, blank line to exit${RESET}\n"
          continue ;;
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
