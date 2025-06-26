#!/usr/bin/env pwsh
# Minimal OpenAI chat client with interactive mode
# ─────────────
# Non-interactive:
#   ./cheat.ps1 "Tell me a joke"
#   echo "Explain DNS like I'm five" | ./cheat.ps1
#
# Interactive shell:
#   ./cheat.ps1 -i          # REPL, quit with Ctrl-C or blank line
#
# Env vars:
#   OPENAI_API_KEY   (required)
#   MODEL            (default gpt-4.1-nano)
#   API_URL          (default https://cheat-cli-api.abdulbaaridavids04.workers.dev)
#   JQ               (set to 0 to force dumb JSON parse)

param(
    [switch]$Interactive,
    [alias("i")]
    [switch]$I,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Prompt
)

$ErrorActionPreference = "Stop"

function Write-Error-Exit {
    param([string]$Message)
    Write-Host $Message -ForegroundColor Red
    exit 1
}

# Environment variables with defaults
$MODEL = $env:MODEL ?? "gpt-4.1-nano"
$USE_JQ = if ($env:JQ -eq "0") { $false } else { $true }
$API_URL = $env:API_URL ?? "https://cheat-cli-api.abdulbaaridavids04.workers.dev"

# Colors (only if terminal supports them)
$Colors = @{
    Red    = "`e[0;31m"
    Blue   = "`e[0;34m"
    Green  = "`e[0;32m"
    Yellow = "`e[0;33m"
    Cyan   = "`e[0;36m"
    Gray   = "`e[0;90m"
    Bold   = "`e[1m"
    Reset  = "`e[0m"
}

# Disable colors for non-interactive or dumb terminals
if (-not [Console]::IsOutputRedirected -and $env:TERM -ne "dumb") {
    # Colors enabled
} else {
    $Colors = @{
        Red = ""; Blue = ""; Green = ""; Yellow = ""; Cyan = ""; Gray = ""; Bold = ""; Reset = ""
    }
}

function Call-OpenAI {
    param([string]$PromptText)
    
    # Show simple thinking placeholder if in interactive mode
    $thinkingShown = $false
    if (-not [Console]::IsOutputRedirected) {
        Write-Host " $($Colors.Gray)<Thinking...>$($Colors.Reset)" -NoNewline
        $thinkingShown = $true
    }
    
    # Escape the content for JSON
    $escapedPrompt = $PromptText -replace '\\', '\\' -replace '"', '\"' -replace "`t", '\t' -replace "`r`n", '\n' -replace "`n", '\n'
    
    # Build JSON payload
    $payload = @{
        model = $MODEL
        messages = @(
            @{
                role = "user"
                content = $escapedPrompt
            }
        )
        stream = $false
    } | ConvertTo-Json -Depth 3 -Compress
    
    try {
        # Call API
        $response = Invoke-RestMethod -Uri "$API_URL/chat" -Method Post -ContentType "application/json" -Body $payload
        
        # Clear thinking placeholder and show model prompt
        if ($thinkingShown) {
            Write-Host "`r$MODEL> " -NoNewline
        }
        
        # Apply streaming effect locally
        if (-not [Console]::IsOutputRedirected) {
            # Stream word by word for interactive mode
            $words = $response -split '\s+'
            foreach ($word in $words) {
                if ($word) {
                    Write-Host "$word " -NoNewline
                    Start-Sleep -Milliseconds 50
                }
            }
            Write-Host # Final newline
        } else {
            # Just print directly for non-interactive
            Write-Host $response
        }
    }
    catch {
        if ($thinkingShown) {
            Write-Host "`r" -NoNewline
        }
        Write-Error-Exit "API call failed: $($_.Exception.Message)"
    }
}

# Interactive mode
if ($Interactive -or $I) {
    Write-Host "$($Colors.Bold)$($Colors.Cyan)Chatting with $($Colors.Yellow)$MODEL$($Colors.Cyan). Blank line to quit.$($Colors.Reset)"
    
    while ($true) {
        Write-Host "`nyou> " -NoNewline
        
        try {
            $line = Read-Host
        }
        catch {
            break
        }
        
        # Exit on empty line
        if ([string]::IsNullOrWhiteSpace($line)) {
            break
        }
        
        # Handle commands
        switch -Regex ($line) {
            '^/model\s*(.*)' {
                $newModel = $Matches[1].Trim()
                if ($newModel) {
                    switch ($newModel) {
                        { $_ -in @("gpt-4.1-nano", "gpt-4o-mini") } {
                            $script:MODEL = $newModel
                            Write-Host "$($Colors.Green)Switched model to $($Colors.Yellow)$MODEL$($Colors.Reset)"
                        }
                        default {
                            Write-Host "$($Colors.Red)Invalid model. Available models: $($Colors.Yellow)gpt-4.1-nano, gpt-4o-mini$($Colors.Reset)"
                        }
                    }
                } else {
                    Write-Host "$($Colors.Cyan)Available models: $($Colors.Yellow)gpt-4.1-nano, gpt-4o-mini$($Colors.Reset)"
                    Write-Host "$($Colors.Cyan)Usage: $($Colors.Yellow)/model gpt-4o-mini$($Colors.Reset)"
                }
                continue
            }
            '^/models$' {
                Write-Host "$($Colors.Cyan)Available models:$($Colors.Reset)"
                Write-Host "  $($Colors.Yellow)gpt-4.1-nano$($Colors.Reset) - Compact model (default)"
                Write-Host "  $($Colors.Yellow)gpt-4o-mini$($Colors.Reset) - Faster, cheaper GPT-4"
                Write-Host "$($Colors.Cyan)Switch with: $($Colors.Yellow)/model MODEL_NAME$($Colors.Reset)"
                continue
            }
            '^/help$' {
                Write-Host "$($Colors.Cyan)Commands:$($Colors.Reset)"
                Write-Host "  $($Colors.Yellow)/model MODEL_NAME$($Colors.Cyan) - Switch to a different model$($Colors.Reset)"
                Write-Host "  $($Colors.Yellow)/models$($Colors.Cyan) - List available models$($Colors.Reset)"
                Write-Host "  $($Colors.Yellow)/context FILE [question]$($Colors.Cyan) - Read and send file content with optional question$($Colors.Reset)"
                Write-Host "  $($Colors.Yellow)/context <command [question]$($Colors.Cyan) - Read and send command output with optional question$($Colors.Reset)"
                Write-Host "  $($Colors.Yellow)/help$($Colors.Cyan) - Show this help$($Colors.Reset)"
                Write-Host "  $($Colors.Yellow)/quit$($Colors.Cyan) or $($Colors.Yellow)/exit$($Colors.Cyan) - Exit chat$($Colors.Reset)"
                Write-Host "  $($Colors.Cyan)Empty line - Exit chat$($Colors.Reset)"
                continue
            }
            '^/context\s*(.*)' {
                $contextArgs = $Matches[1].Trim()
                if ($contextArgs) {
                    # Parse first argument as file/command, rest as prompt
                    $parts = $contextArgs -split '\s+', 2
                    $firstArg = $parts[0]
                    $restArgs = if ($parts.Length -gt 1) { $parts[1] } else { "" }
                    
                    $contextContent = ""
                    $contentType = ""
                    
                    # Check if it starts with < for command execution
                    if ($firstArg.StartsWith("<")) {
                        # Remove the < and execute the command
                        $commandToRun = $firstArg.Substring(1)
                        Write-Host "$($Colors.Cyan)Executing: $($Colors.Yellow)$commandToRun$($Colors.Reset)"
                        try {
                            $contextContent = Invoke-Expression $commandToRun | Out-String
                            $contentType = "command"
                        }
                        catch {
                            Write-Host "$($Colors.Red)Error executing command: $commandToRun$($Colors.Reset)"
                            continue
                        }
                    } else {
                        # Treat as file path
                        if (Test-Path $firstArg -PathType Leaf) {
                            Write-Host "$($Colors.Cyan)Reading file: $($Colors.Yellow)$firstArg$($Colors.Reset)"
                            try {
                                $contextContent = Get-Content $firstArg -Raw
                                $contentType = "file"
                            }
                            catch {
                                Write-Host "$($Colors.Red)Error reading file: $firstArg$($Colors.Reset)"
                                continue
                            }
                        } else {
                            Write-Host "$($Colors.Red)File not found: $firstArg$($Colors.Reset)"
                            continue
                        }
                    }
                    
                    # Show preview of content
                    $contentPreview = if ($contextContent.Length -gt 100) {
                        $contextContent.Substring(0, 100) + "..."
                    } else {
                        $contextContent
                    }
                    Write-Host "$($Colors.Gray)Content preview: $contentPreview$($Colors.Reset)"
                    
                    # Combine context content with additional prompt if provided
                    $fullPrompt = ""
                    if ($restArgs) {
                        if ($contentType -eq "command") {
                            $fullPrompt = "Here is the output from running the command '$commandToRun':`n`n$contextContent`n`n$restArgs"
                        } else {
                            $fullPrompt = "Here is the content of the file '$firstArg':`n`n$contextContent`n`n$restArgs"
                        }
                    } else {
                        if ($contentType -eq "command") {
                            $fullPrompt = "Here is the output from running the command '$commandToRun':`n`n$contextContent"
                        } else {
                            $fullPrompt = "Here is the content of the file '$firstArg':`n`n$contextContent"
                        }
                    }
                    
                    Write-Host "`n$MODEL> " -NoNewline
                    Call-OpenAI $fullPrompt
                } else {
                    Write-Host "$($Colors.Cyan)Usage:$($Colors.Reset)"
                    Write-Host "  $($Colors.Yellow)/context filename.txt$($Colors.Cyan) - Send file content$($Colors.Reset)"
                    Write-Host "  $($Colors.Yellow)/context filename.txt what does this say?$($Colors.Cyan) - Send file with question$($Colors.Reset)"
                    Write-Host "  $($Colors.Yellow)/context <Get-ChildItem$($Colors.Cyan) - Send command output$($Colors.Reset)"
                    Write-Host "  $($Colors.Yellow)/context <Get-ChildItem -Force explain this$($Colors.Cyan) - Send command output with question$($Colors.Reset)"
                }
                continue
            }
            '^/(quit|exit)$' {
                break
            }
        }
        
        Write-Host "`n$MODEL> " -NoNewline
        Call-OpenAI $line
    }
    Write-Host "$($Colors.Cyan)Bye.$($Colors.Reset)"
    exit 0
}

# Batch mode (args or stdin) or default to interactive
if ($Prompt.Count -gt 0) {
    $promptText = $Prompt -join " "
    Call-OpenAI $promptText
} else {
    # Check if stdin has data (non-interactive) or is empty (interactive)
    if ([Console]::IsInputRedirected) {
        # stdin has piped data, use it
        $input = [Console]::In.ReadToEnd().Trim()
        if ([string]::IsNullOrWhiteSpace($input)) {
            Write-Error-Exit "No prompt given."
        }
        Call-OpenAI $input
    } else {
        # stdin is a terminal (no piped input), go interactive
        Write-Host "$($Colors.Bold)$($Colors.Cyan)Chatting with $($Colors.Yellow)$MODEL$($Colors.Cyan). Blank line to quit.$($Colors.Reset)"
        
        while ($true) {
            Write-Host "`nyou> " -NoNewline
            
            try {
                $line = Read-Host
            }
            catch {
                break
            }
            
            if ([string]::IsNullOrWhiteSpace($line)) {
                break
            }
            
            # Handle quick commands
            switch -Regex ($line) {
                '^/model\s*(.*)' {
                    $newModel = $Matches[1].Trim()
                    if ($newModel) {
                        switch ($newModel) {
                            { $_ -in @("gpt-4.1-nano", "gpt-4o-mini") } {
                                $script:MODEL = $newModel
                                Write-Host "$($Colors.Green)Switched model to $($Colors.Yellow)$MODEL$($Colors.Reset)"
                            }
                            default {
                                Write-Host "$($Colors.Red)Invalid model. Available models: $($Colors.Yellow)gpt-4.1-nano, gpt-4o-mini$($Colors.Reset)"
                            }
                        }
                    } else {
                        Write-Host "$($Colors.Cyan)Available models: $($Colors.Yellow)gpt-4.1-nano, gpt-4o-mini$($Colors.Reset)"
                    }
                    continue
                }
                '^/models$' {
                    Write-Host "$($Colors.Cyan)Available models:$($Colors.Reset)"
                    Write-Host "  $($Colors.Yellow)gpt-4.1-nano$($Colors.Reset) - Compact model (default)"
                    Write-Host "  $($Colors.Yellow)gpt-4o-mini$($Colors.Reset) - Faster, cheaper GPT-4"
                    continue
                }
                '^/help$' {
                    Write-Host "$($Colors.Cyan)Commands: $($Colors.Yellow)/model MODEL$($Colors.Cyan), $($Colors.Yellow)/models$($Colors.Cyan), $($Colors.Yellow)/context FILE [question]$($Colors.Cyan), blank line to exit$($Colors.Reset)"
                    continue
                }
                '^/context\s*(.*)' {
                    $contextArgs = $Matches[1].Trim()
                    if ($contextArgs) {
                        # Parse first argument as file/command, rest as prompt
                        $parts = $contextArgs -split '\s+', 2
                        $firstArg = $parts[0]
                        $restArgs = if ($parts.Length -gt 1) { $parts[1] } else { "" }
                        
                        $contextContent = ""
                        $contentType = ""
                        
                        # Check if it starts with < for command execution
                        if ($firstArg.StartsWith("<")) {
                            # Remove the < and execute the command
                            $commandToRun = $firstArg.Substring(1)
                            Write-Host "$($Colors.Cyan)Executing: $($Colors.Yellow)$commandToRun$($Colors.Reset)"
                            try {
                                $contextContent = Invoke-Expression $commandToRun | Out-String
                                $contentType = "command"
                            }
                            catch {
                                Write-Host "$($Colors.Red)Error executing command: $commandToRun$($Colors.Reset)"
                                continue
                            }
                        } else {
                            # Treat as file path
                            if (Test-Path $firstArg -PathType Leaf) {
                                Write-Host "$($Colors.Cyan)Reading file: $($Colors.Yellow)$firstArg$($Colors.Reset)"
                                try {
                                    $contextContent = Get-Content $firstArg -Raw
                                    $contentType = "file"
                                }
                                catch {
                                    Write-Host "$($Colors.Red)Error reading file: $firstArg$($Colors.Reset)"
                                    continue
                                }
                            } else {
                                Write-Host "$($Colors.Red)File not found: $firstArg$($Colors.Reset)"
                                continue
                            }
                        }
                        
                        # Show preview of content
                        $contentPreview = if ($contextContent.Length -gt 100) {
                            $contextContent.Substring(0, 100) + "..."
                        } else {
                            $contextContent
                        }
                        Write-Host "$($Colors.Gray)Content preview: $contentPreview$($Colors.Reset)"
                        
                        # Combine context content with additional prompt if provided
                        $fullPrompt = ""
                        if ($restArgs) {
                            if ($contentType -eq "command") {
                                $fullPrompt = "Here is the output from running the command '$commandToRun':`n`n$contextContent`n`n$restArgs"
                            } else {
                                $fullPrompt = "Here is the content of the file '$firstArg':`n`n$contextContent`n`n$restArgs"
                            }
                        } else {
                            if ($contentType -eq "command") {
                                $fullPrompt = "Here is the output from running the command '$commandToRun':`n`n$contextContent"
                            } else {
                                $fullPrompt = "Here is the content of the file '$firstArg':`n`n$contextContent"
                            }
                        }
                        
                        Write-Host "`n$MODEL> " -NoNewline
                        Call-OpenAI $fullPrompt
                    } else {
                        Write-Host "$($Colors.Cyan)Usage: $($Colors.Yellow)/context filename.txt [question]$($Colors.Cyan) or $($Colors.Yellow)/context <command [question]$($Colors.Reset)"
                    }
                    continue
                }
            }
            
            Write-Host "`n$MODEL> " -NoNewline
            Call-OpenAI $line
        }
        Write-Host "$($Colors.Cyan)Bye.$($Colors.Reset)"
    }
} 