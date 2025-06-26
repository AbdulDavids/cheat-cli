# Cheat CLI

A minimal OpenAI chat client that works from your terminal. Zero setup required. Built for those annoying machines in the lab that have almost everything blacklisted.

<figure class="video_container">
  <iframe src="assets/showcase.mp4" frameborder="0" allowfullscreen="true"> 
</iframe>
</figure>

## Quick Start

**Run directly from URL:**

**Single question:**

```bash
curl -s https://raw.githubusercontent.com/AbdulDavids/cheat-cli/main/cheat.sh | sh -s -- "What is Docker?"
```

**Very cool interactive mode thing:**

```bash
# Interactive mode
curl -s https://raw.githubusercontent.com/AbdulDavids/cheat-cli/main/cheat.sh | sh -s -- -i
```

![Interactive mode](https://github.com/user-attachments/assets/3e4003ae-0452-4190-8413-dc3a8f97be26)


**Or create an alias for convenience (obviously dont use this if you are using a shared machine):**

```bash
# Add to ~/.bashrc or ~/.zshrc
alias cheat='curl -s https://raw.githubusercontent.com/AbdulDavids/cheat-cli/main/cheat.sh | sh -s --'
```

Then you can use `cheat` directly in your terminal:

```bash
# Then use anywhere
cheat "Explain quantum computing"
```

```bash
cheat -i  # Interactive mode
```

### Windows Users

If you're unlucky enough to be on Windows, you can use WSL (Windows Subsystem for Linux) or Git Bash to run the above commands.

## Usage Examples

```bash
# Quick questions
cheat "What's the difference between Docker and VM?"
```

**Model Switching**:

```bash
# Interactive chat
cheat -i
you> hello
gpt-4.1-nano> Hello! How can I assist you today?
you> /model gpt-4o-mini
you> explain REST APIs
gpt-4o-mini> REST APIs are...
```

![Cleanshot of curl in Warp 000797@2x](https://github.com/user-attachments/assets/de077428-7b9b-48e4-ac28-7f36ac6b66f0)


You can also use the `cheat` command in a pipe, so you can push in some text from a  file or another command:

```bash
# Pipe input
echo "Explain machine learning" | cheat
```

Limited file context is supported, so you can use it like this:

```bash
# Use a file as context
you> /context myfile.txt what is in this file?
gpt-4.1-nano> The file contains a lot of memes.
```



Want to deploy your own? See [CLOUDFLARE.md](CLOUDFLARE.md) for deployment instructions.

