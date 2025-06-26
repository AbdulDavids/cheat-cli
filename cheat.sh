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
  
  # Simple approach: escape the content for JSON and build the payload directly
  escaped_prompt=$(printf %s "$prompt" | \
    sed 's/\\/\\\\/g' | \
    sed 's/"/\\"/g' | \
    sed 's/	/\\t/g' | \
    awk '{printf "%s\\n", $0}' | \
    sed 's/\\n$//')
  
  # Call API with properly escaped JSON
  response=$(curl -sS "$API_URL/chat" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"$escaped_prompt\"}],\"stream\":false}")
  
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
          case "$new_model" in
            gpt-4.1-nano|gpt-4o-mini)
              MODEL="$new_model"
              printf "${GREEN}Switched model to ${YELLOW}%s${RESET}\n" "$MODEL"
              ;;
            *)
              printf "${RED}Invalid model. Available models: ${YELLOW}gpt-4.1-nano, gpt-4o-mini${RESET}\n"
              ;;
          esac
        else
          printf "${CYAN}Available models: ${YELLOW}gpt-4.1-nano, gpt-4o-mini${RESET}\n"
          printf "${CYAN}Usage: ${YELLOW}/model gpt-4o-mini${RESET}\n"
        fi
        continue ;;
      /models)
        printf "${CYAN}Available models:${RESET}\n"
        printf "  ${YELLOW}gpt-4.1-nano${RESET} - Compact model (default)\n"
        printf "  ${YELLOW}gpt-4o-mini${RESET} - Faster, cheaper GPT-4\n"
        printf "${CYAN}Switch with: ${YELLOW}/model MODEL_NAME${RESET}\n"
        continue ;;
      /help) 
        printf "${CYAN}Commands:${RESET}\n"
        printf "  ${YELLOW}/model MODEL_NAME${CYAN} - Switch to a different model${RESET}\n"
        printf "  ${YELLOW}/models${CYAN} - List available models${RESET}\n"
        printf "  ${YELLOW}/context FILE [question]${CYAN} - Read and send file content with optional question${RESET}\n"
        printf "  ${YELLOW}/context <command [question]${CYAN} - Read and send command output with optional question${RESET}\n"
        printf "  ${YELLOW}/help${CYAN} - Show this help${RESET}\n"
        printf "  ${YELLOW}/quit${CYAN} or ${YELLOW}/exit${CYAN} - Exit chat${RESET}\n"
        printf "  ${CYAN}Empty line - Exit chat${RESET}\n"
        continue ;;
      /context*)
        context_args=$(printf %s "$line" | cut -d' ' -f2-)
        if [ -n "$context_args" ]; then
          # Parse first argument as file/command, rest as prompt
          first_arg=$(printf %s "$context_args" | awk '{print $1}')
          rest_args=$(printf %s "$context_args" | cut -d' ' -f2-)
          
          # Check if it starts with < for command execution
          if printf %s "$first_arg" | grep -q "^<"; then
            # Remove the < and execute the command
            command_to_run=$(printf %s "$first_arg" | sed 's/^<//')
            printf "${CYAN}Executing: ${YELLOW}%s${RESET}\n" "$command_to_run"
            context_content=$(eval "$command_to_run" 2>/dev/null) || {
              printf "${RED}Error executing command: %s${RESET}\n" "$command_to_run"
              continue
            }
          else
            # Treat as file path
            if [ -f "$first_arg" ]; then
              printf "${CYAN}Reading file: ${YELLOW}%s${RESET}\n" "$first_arg"
              context_content=$(cat "$first_arg" 2>/dev/null) || {
                printf "${RED}Error reading file: %s${RESET}\n" "$first_arg"
                continue
              }
            else
              printf "${RED}File not found: %s${RESET}\n" "$first_arg"
              continue
            fi
          fi
          
          # Show preview of content
          content_preview=$(printf %s "$context_content" | head -c 100)
          if [ ${#context_content} -gt 100 ]; then
            content_preview="${content_preview}..."
          fi
          printf "${GRAY}Content preview: %s${RESET}\n" "$content_preview"
          
          # Combine context content with additional prompt if provided
          if [ -n "$rest_args" ] && [ "$rest_args" != "$first_arg" ]; then
            if printf %s "$first_arg" | grep -q "^<"; then
              # Command execution
              full_prompt="Here is the output from running the command '$command_to_run':

$context_content

$rest_args"
            else
              # File content
              full_prompt="Here is the content of the file '$first_arg':

$context_content

$rest_args"
            fi
          else
            if printf %s "$first_arg" | grep -q "^<"; then
              # Command execution without question
              full_prompt="Here is the output from running the command '$command_to_run':

$context_content"
            else
              # File content without question
              full_prompt="Here is the content of the file '$first_arg':

$context_content"
            fi
          fi
          
          printf '\n%s> ' "$MODEL"
          call_openai "$full_prompt"
        else
          printf "${CYAN}Usage:${RESET}\n"
          printf "  ${YELLOW}/context filename.txt${CYAN} - Send file content${RESET}\n"
          printf "  ${YELLOW}/context filename.txt what does this say?${CYAN} - Send file with question${RESET}\n"
          printf "  ${YELLOW}/context <cat file.txt${CYAN} - Send command output${RESET}\n"
          printf "  ${YELLOW}/context <ls -la explain this${CYAN} - Send command output with question${RESET}\n"
        fi
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
            case "$new_model" in
              gpt-4.1-nano|gpt-4o-mini)
                MODEL="$new_model"
                printf "${GREEN}Switched model to ${YELLOW}%s${RESET}\n" "$MODEL"
                ;;
              *)
                printf "${RED}Invalid model. Available models: ${YELLOW}gpt-4.1-nano, gpt-4o-mini${RESET}\n"
                ;;
            esac
          else
            printf "${CYAN}Available models: ${YELLOW}gpt-4.1-nano, gpt-4o-mini${RESET}\n"
          fi
          continue ;;
        /models)
          printf "${CYAN}Available models:${RESET}\n"
          printf "  ${YELLOW}gpt-4.1-nano${RESET} - Compact model (default)\n"
          printf "  ${YELLOW}gpt-4o-mini${RESET} - Faster, cheaper GPT-4\n"
          continue ;;
        /help) 
          printf "${CYAN}Commands: ${YELLOW}/model MODEL${CYAN}, ${YELLOW}/models${CYAN}, ${YELLOW}/context FILE [question]${CYAN}, blank line to exit${RESET}\n"
          continue ;;
        /context*)
          context_args=$(printf %s "$line" | cut -d' ' -f2-)
          if [ -n "$context_args" ]; then
            # Parse first argument as file/command, rest as prompt
            first_arg=$(printf %s "$context_args" | awk '{print $1}')
            rest_args=$(printf %s "$context_args" | cut -d' ' -f2-)
            
            # Check if it starts with < for command execution
            if printf %s "$first_arg" | grep -q "^<"; then
              # Remove the < and execute the command
              command_to_run=$(printf %s "$first_arg" | sed 's/^<//')
              printf "${CYAN}Executing: ${YELLOW}%s${RESET}\n" "$command_to_run"
              context_content=$(eval "$command_to_run" 2>/dev/null) || {
                printf "${RED}Error executing command: %s${RESET}\n" "$command_to_run"
                continue
              }
            else
              # Treat as file path
              if [ -f "$first_arg" ]; then
                printf "${CYAN}Reading file: ${YELLOW}%s${RESET}\n" "$first_arg"
                context_content=$(cat "$first_arg" 2>/dev/null) || {
                  printf "${RED}Error reading file: %s${RESET}\n" "$first_arg"
                  continue
                }
              else
                printf "${RED}File not found: %s${RESET}\n" "$first_arg"
                continue
              fi
            fi
            
            # Show preview of content
            content_preview=$(printf %s "$context_content" | head -c 100)
            if [ ${#context_content} -gt 100 ]; then
              content_preview="${content_preview}..."
            fi
            printf "${GRAY}Content preview: %s${RESET}\n" "$content_preview"
            
            # Combine context content with additional prompt if provided
            if [ -n "$rest_args" ] && [ "$rest_args" != "$first_arg" ]; then
              if printf %s "$first_arg" | grep -q "^<"; then
                # Command execution
                full_prompt="Here is the output from running the command '$command_to_run':

$context_content

$rest_args"
              else
                # File content
                full_prompt="Here is the content of the file '$first_arg':

$context_content

$rest_args"
              fi
            else
              if printf %s "$first_arg" | grep -q "^<"; then
                # Command execution without question
                full_prompt="Here is the output from running the command '$command_to_run':

$context_content"
              else
                # File content without question
                full_prompt="Here is the content of the file '$first_arg':

$context_content"
              fi
            fi
            
            printf '\n%s> ' "$MODEL"
            call_openai "$full_prompt"
          else
            printf "${CYAN}Usage: ${YELLOW}/context filename.txt [question]${CYAN} or ${YELLOW}/context <command [question]${RESET}\n"
          fi
          continue ;;
        /pipe*)
          pipe_input=$(printf %s "$line" | cut -d' ' -f2-)
          if [ -n "$pipe_input" ]; then
            # Check if it starts with < for command execution
            if printf %s "$pipe_input" | grep -q "^<"; then
              # Remove the < and execute the command
              command_to_run=$(printf %s "$pipe_input" | sed 's/^<//')
              printf "${CYAN}Executing: ${YELLOW}%s${RESET}\n" "$command_to_run"
              piped_content=$(eval "$command_to_run" 2>/dev/null) || {
                printf "${RED}Error executing command: %s${RESET}\n" "$command_to_run"
                continue
              }
            else
              # Treat as file path
              if [ -f "$pipe_input" ]; then
                printf "${CYAN}Reading file: ${YELLOW}%s${RESET}\n" "$pipe_input"
                piped_content=$(cat "$pipe_input" 2>/dev/null) || {
                  printf "${RED}Error reading file: %s${RESET}\n" "$pipe_input"
                  continue
                }
              else
                printf "${RED}File not found: %s${RESET}\n" "$pipe_input"
                continue
              fi
            fi
            
            # Show preview of content
            content_preview=$(printf %s "$piped_content" | head -c 100)
            if [ ${#piped_content} -gt 100 ]; then
              content_preview="${content_preview}..."
            fi
            printf "${GRAY}Content preview: %s${RESET}\n" "$content_preview"
            
            printf '\n%s> ' "$MODEL"
            call_openai "$piped_content"
          else
            printf "${CYAN}Usage: ${YELLOW}/pipe filename.txt${CYAN} or ${YELLOW}/pipe <command${RESET}\n"
          fi
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
