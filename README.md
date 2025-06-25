# Cheat CLI

A minimal, fast OpenAI chat client that works from your terminal. Built with a shell script frontend and a Cloudflare Worker backend for global, serverless API access.

## Features

- 🚀 **Interactive and Batch modes** - Use as a REPL or pipe/pass arguments
- 🌍 **Serverless backend** - Runs on Cloudflare Workers for global edge performance
- 🎨 **Colored output** - Beautiful terminal UI with model switching
- ⚡ **Fast responses** - Direct OpenAI API integration with artificial streaming effect
- 🔧 **Model switching** - Easy model changes with `/model` command
- 📦 **Zero dependencies** - Just needs `curl` and a shell

## Quick Start

### Option 1: Run Directly from URL (No Download)

```bash
# Set your OpenAI API key
export OPENAI_API_KEY="your-api-key-here"

# Run directly from GitHub - batch mode
curl -s https://raw.githubusercontent.com/your-username/cheat-cli/main/cheat.sh | sh -s -- "What is Docker?"

# Interactive mode
curl -s https://raw.githubusercontent.com/your-username/cheat-cli/main/cheat.sh | sh -s -- -i

# Pipe input
echo "Explain REST APIs" | curl -s https://raw.githubusercontent.com/your-username/cheat-cli/main/cheat.sh | sh
```

**Create a convenient alias:**

```bash
# Add to your ~/.bashrc or ~/.zshrc
alias cheat='curl -s https://raw.githubusercontent.com/your-username/cheat-cli/main/cheat.sh | sh -s --'

# Then use it anywhere:
cheat "What is Kubernetes?"
cheat -i  # Interactive mode
```

### Option 2: Download and Use Locally

1. **Set your OpenAI API key:**
   ```bash
   export OPENAI_API_KEY="your-api-key-here"
   ```

2. **Make the script executable:**
   ```bash
   chmod +x cheat.sh
   ```

3. **Use it:**
   ```bash
   # Interactive mode
   ./cheat.sh -i

   # Batch mode
   ./cheat.sh "Explain quantum computing"
   echo "What is Docker?" | ./cheat.sh
   ```

## Usage Examples

### Interactive Mode
```bash
$ ./cheat.sh -i
Chatting with gpt-4.1-nano. Blank line to quit.

you> hello
gpt-4.1-nano> Hello! How can I assist you today?

you> /model gpt-4o
Switched model to gpt-4o

you> what's 2+2
gpt-4o> 2 + 2 equals 4.

you> 
Bye.
```

### Batch Mode
```bash
# Direct argument
./cheat.sh "Write a haiku about coding"

# Pipe input
echo "Explain REST APIs" | ./cheat.sh

# From file
cat question.txt | ./cheat.sh
```

## Environment Variables

- `OPENAI_API_KEY` - **Required** - Your OpenAI API key
- `MODEL` - Default model (default: `gpt-4.1-nano`)
- `API_URL` - API endpoint (default: Cloudflare Worker URL)

## Commands (Interactive Mode)

- `/model MODEL_NAME` - Switch to a different model
- `/help` - Show available commands
- Empty line or `Ctrl-C` - Exit

## Architecture

```
┌─────────────┐    HTTP     ┌──────────────────┐    OpenAI API    ┌─────────────┐
│   cheat.sh  │ ──────────► │ Cloudflare Worker│ ───────────────► │   OpenAI    │
│ (Terminal)  │             │   (Edge/Global)  │                  │   Service   │
└─────────────┘             └──────────────────┘                  └─────────────┘
```

- **Frontend**: Portable shell script with interactive features
- **Backend**: Cloudflare Worker for serverless, global API proxy
- **AI**: Direct OpenAI API integration

## Files

- `cheat.sh` - Main CLI script
- `worker.js` - Cloudflare Worker source code
- `wrangler.toml` - Cloudflare Worker configuration
- `package.json` - Node.js package configuration
- `CLOUDFLARE.md` - Cloudflare Worker deployment guide

## Development

To deploy your own Cloudflare Worker:

1. Install Wrangler CLI: `npm install -g wrangler`
2. Login: `wrangler login`
3. Set your OpenAI API key: `wrangler secret put OPENAI_API_KEY`
4. Deploy: `wrangler deploy`

## License

MIT License - Feel free to use and modify as needed.
