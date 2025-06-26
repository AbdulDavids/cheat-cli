# Cheat CLI

A minimal OpenAI chat client that works from your terminal. Zero setup required. Built for those annoying machines in the lab that have almost everything blacklisted.



https://github.com/user-attachments/assets/b5fab1d7-3ac7-4d7e-bfe0-45b57dad948d


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

### Windows Users (PowerShell)

>[!NOTE]
> Fine I made a PowerShell version too, because I know some of you are stuck on Windows and PowerShell is the only thing you have.

**Single question:**

```powershell
Invoke-RestMethod https://raw.githubusercontent.com/AbdulDavids/cheat-cli/main/cheat.ps1 | Invoke-Expression; cheat "What is Docker?"
```

**Interactive mode:**

```powershell
# Download and run interactively
Invoke-RestMethod https://raw.githubusercontent.com/AbdulDavids/cheat-cli/main/cheat.ps1 | Out-File cheat.ps1; .\cheat.ps1 -i
```

**Create a PowerShell function for convenience:**

```powershell
# Add to your PowerShell profile ($PROFILE)
function cheat {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$args)
    $script = Invoke-RestMethod https://raw.githubusercontent.com/AbdulDavids/cheat-cli/main/cheat.ps1
    $tempFile = [System.IO.Path]::GetTempFileName() + ".ps1"
    $script | Out-File $tempFile
    try { & $tempFile @args } finally { Remove-Item $tempFile -ErrorAction SilentlyContinue }
}
```

Then use it like:

```powershell
cheat "Explain quantum computing"
cheat -i  # Interactive mode
```

**Alternative: Download locally and run**

```powershell
# Download once
Invoke-WebRequest https://raw.githubusercontent.com/AbdulDavids/cheat-cli/main/cheat.ps1 -OutFile cheat.ps1

# Then use
.\cheat.ps1 "What is PowerShell?"
.\cheat.ps1 -Interactive
```


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

### PowerShell-Specific Examples

```powershell
# Quick questions
.\cheat.ps1 "What's the difference between PowerShell and CMD?"

# Pipe input
"Explain PowerShell objects" | .\cheat.ps1

# Interactive chat with PowerShell commands
.\cheat.ps1 -i
you> hello
gpt-4.1-nano> Hello! How can I assist you today?
you> /model gpt-4o-mini
Switched model to gpt-4o-mini
you> /context <Get-Process explain what these processes are
Executing: Get-Process
Content preview: Handles  NPM(K)    PM(K)      WS(K)     CPU(s)     Id  SI ProcessName...
gpt-4o-mini> These are the currently running processes on your system...

# Use file context
you> /context package.json what dependencies does this have?
Reading file: package.json
Content preview: {"name": "my-app", "dependencies": {...
gpt-4o-mini> This package.json file contains several dependencies...
```



Want to deploy your own? See [CLOUDFLARE.md](CLOUDFLARE.md) for deployment instructions.

