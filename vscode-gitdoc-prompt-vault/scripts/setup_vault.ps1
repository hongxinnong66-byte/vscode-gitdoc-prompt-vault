<#
.SYNOPSIS
    One-click setup, restore, or diagnose script for a VS Code + GitDoc + GitHub Private Prompt & Skills Vault on Windows.
.EXAMPLE
    # Restore an existing private GitHub repo on a new PC:
    powershell -ExecutionPolicy Bypass -File .\scripts\setup_vault.ps1 -Mode restore -RepoName "ai-prompts-and-skills" -TargetDir "D:\AI-Prompt-Vault"

    # Initialize a brand new vault & create a private GitHub repo:
    powershell -ExecutionPolicy Bypass -File .\scripts\setup_vault.ps1 -Mode init -RepoName "ai-prompts-and-skills" -TargetDir "D:\AI-Prompt-Vault"

    # Diagnose environment only:
    powershell -ExecutionPolicy Bypass -File .\scripts\setup_vault.ps1 -Mode diagnose
#>

[CmdletBinding()]
param(
    [ValidateSet("restore", "init", "diagnose")]
    [string]$Mode = "restore",

    [string]$RepoName = "ai-prompts-and-skills",

    [string]$TargetDir = "",

    [string]$TimeZone = "Asia/Shanghai",

    [switch]$SkipOpen
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillRoot = Split-Path -Parent $ScriptDir
$TemplatesDir = Join-Path $SkillRoot "templates"

function Write-Step($msg) {
    Write-Host "`n==> $msg" -ForegroundColor Cyan
}

function Find-GhExe {
    $cmd = Get-Command gh -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $defaultPath = "C:\Program Files\GitHub CLI\gh.exe"
    if (Test-Path $defaultPath) { return $defaultPath }
    return $null
}

function Find-CodeExe {
    $cmd = Get-Command code -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $defaultPath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd"
    if (Test-Path $defaultPath) { return $defaultPath }
    return $null
}

function Ensure-Prerequisites {
    Write-Step "Checking Git, VS Code, and GitHub CLI"

    $gitCmd = Get-Command git -ErrorAction SilentlyContinue
    if (-not $gitCmd) {
        throw "Git is not installed or not in PATH. Install Git first: https://git-scm.com/download/win"
    }
    Write-Host "  [OK] git  : $($gitCmd.Source)"

    $codeExe = Find-CodeExe
    if (-not $codeExe) {
        throw "VS Code CLI ('code') not found. Install VS Code first: https://code.visualstudio.com/"
    }
    Write-Host "  [OK] code : $codeExe"

    $ghExe = Find-GhExe
    if (-not $ghExe) {
        if ($Mode -eq "diagnose") {
            Write-Host "  [MISSING] gh (GitHub CLI) is not installed." -ForegroundColor Yellow
        } else {
            Write-Host "  [INFO] Installing GitHub CLI (gh) via winget..." -ForegroundColor Yellow
            if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
                throw "winget not found. Please install GitHub CLI manually: https://cli.github.com/"
            }
            winget install --id GitHub.cli -e --accept-source-agreements --accept-package-agreements --silent
            $ghExe = Find-GhExe
            if (-not $ghExe) {
                throw "GitHub CLI installation finished but gh.exe was not found. Restart your terminal and retry."
            }
            Write-Host "  [OK] gh installed: $ghExe"
        }
    } else {
        Write-Host "  [OK] gh   : $ghExe"
    }

    return @{
        Git  = $gitCmd.Source
        Code = $codeExe
        Gh   = $ghExe
    }
}

function Ensure-VsCodeExtensions($codeExe) {
    Write-Step "Installing VS Code extensions (GitDoc + Markdown All in One)"
    $installed = & $codeExe --list-extensions 2>$null
    foreach ($ext in @("vsls-contrib.gitdoc", "yzhang.markdown-all-in-one")) {
        if ($installed -contains $ext) {
            Write-Host "  [OK] Already installed: $ext"
        } else {
            Write-Host "  [INFO] Installing $ext..."
            & $codeExe --install-extension $ext --force
        }
    }
}

function Ensure-GitHubAuth($ghExe) {
    Write-Step "Checking GitHub CLI authentication"
    $ErrorActionPreference = "Continue"
    & $ghExe auth status 2>&1 | Out-Null
    $authExit = $LASTEXITCODE
    $ErrorActionPreference = "Stop"

    if ($authExit -ne 0) {
        Write-Host "  [ACTION REQUIRED] Starting GitHub browser device authorization..." -ForegroundColor Yellow
        Write-Host "  Tip: Open https://github.com/login/device in your regular browser (Edge/Chrome) and paste the one-time code." -ForegroundColor Yellow
        & $ghExe auth login --hostname github.com --git-protocol https --web --clipboard
        if ($LASTEXITCODE -ne 0) {
            throw "GitHub CLI login did not complete."
        }
    } else {
        Write-Host "  [OK] GitHub CLI is already logged in."
    }

    Write-Step "Configuring Git credential helper and user identity"
    & $ghExe auth setup-git

    $userJson = & $ghExe api user | ConvertFrom-Json
    $login = $userJson.login
    $uid = $userJson.id
    $name = if ($userJson.name) { $userJson.name } else { $login }
    $email = if ($userJson.email) { $userJson.email } else { "${uid}+${login}@users.noreply.github.com" }

    git config --global user.name "$name"
    git config --global user.email "$email"
    git config --global core.quotepath false
    Write-Host "  [OK] GitHub user: $login ($email)"

    return @{
        Login = $login
        Name  = $name
        Email = $email
    }
}

function Write-Utf8NoBom($filePath, $text) {
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($filePath, $text, $utf8NoBom)
}

function Ensure-VaultSettings($vaultDir) {
    $vscodeDir = Join-Path $vaultDir ".vscode"
    New-Item -ItemType Directory -Force -Path $vscodeDir | Out-Null

    $settingsDest = Join-Path $vscodeDir "settings.json"
    if (-not (Test-Path -LiteralPath $settingsDest)) {
        $raw = Get-Content -LiteralPath (Join-Path $TemplatesDir "settings.json") -Raw -Encoding UTF8
        $raw = $raw -replace '"Asia/Shanghai"', "`"$TimeZone`""
        Write-Utf8NoBom $settingsDest $raw
        Write-Host "  [OK] Created .vscode/settings.json"
    }

    $extDest = Join-Path $vscodeDir "extensions.json"
    if (-not (Test-Path -LiteralPath $extDest)) {
        Copy-Item -LiteralPath (Join-Path $TemplatesDir "extensions.json") -Destination $extDest
        Write-Host "  [OK] Created .vscode/extensions.json"
    }
}

function Copy-StarterTemplates($vaultDir) {
    Write-Step "Scaffolding directory structure and starter templates"
    New-Item -ItemType Directory -Force -Path (Join-Path $vaultDir "prompts") | Out-Null
    New-Item -ItemType Directory -Force -Path (Join-Path $vaultDir "skills\_SKILL模板") | Out-Null

    Ensure-VaultSettings $vaultDir

    $gitignoreDest = Join-Path $vaultDir ".gitignore"
    if (-not (Test-Path -LiteralPath $gitignoreDest)) {
        Copy-Item -LiteralPath (Join-Path $TemplatesDir "gitignore") -Destination $gitignoreDest
    }

    $readmeDest = Join-Path $vaultDir "README.md"
    if (-not (Test-Path -LiteralPath $readmeDest)) {
        Copy-Item -LiteralPath (Join-Path $TemplatesDir "README.template.md") -Destination $readmeDest
    }

    $skillDest = Join-Path $vaultDir "skills\_SKILL模板\SKILL.md"
    if (-not (Test-Path -LiteralPath $skillDest)) {
        Copy-Item -LiteralPath (Join-Path $TemplatesDir "SKILL.template.md") -Destination $skillDest
    }

    $modules = @(
        @{ File = "01-学术写作与润色.md"; Title = "01 - 学术写作与润色 Prompt" },
        @{ File = "02-翻译与文献精读.md"; Title = "02 - 翻译与文献精读 Prompt" },
        @{ File = "03-科研绘图与代码.md"; Title = "03 - 科研绘图与代码 Prompt" },
        @{ File = "04-通用高频Prompt.md"; Title = "04 - 通用高频 Prompt" }
    )
    $tpl = Get-Content -LiteralPath (Join-Path $TemplatesDir "prompt-module.template.md") -Raw -Encoding UTF8
    foreach ($m in $modules) {
        $dest = Join-Path (Join-Path $vaultDir "prompts") $m.File
        if (-not (Test-Path -LiteralPath $dest)) {
            $content = $tpl.Replace("{{MODULE_TITLE}}", $m.Title)
            Write-Utf8NoBom $dest $content
        }
    }
    Write-Host "  [OK] Templates ready in $vaultDir"
}

function Open-CleanVsCode($codeExe, $vaultDir) {
    Write-Step "Launching VS Code with clean Git environment (stripping GIT_CONFIG_*)"
    Get-ChildItem Env:GIT_CONFIG* -ErrorAction SilentlyContinue | Remove-Item
    $readme = Join-Path $vaultDir "README.md"
    if (Test-Path -LiteralPath $readme) {
        & $codeExe --new-window "$vaultDir" "$readme"
    } else {
        & $codeExe --new-window "$vaultDir"
    }
    Write-Host "  [OK] VS Code launched cleanly." -ForegroundColor Green
}

# ---------------- Main ----------------
$tools = Ensure-Prerequisites

if ($Mode -eq "diagnose") {
    Write-Step "Checking VS Code extensions"
    $exts = & $tools.Code --list-extensions 2>$null
    foreach ($e in @("vsls-contrib.gitdoc", "yzhang.markdown-all-in-one")) {
        $status = if ($exts -contains $e) { "INSTALLED" } else { "MISSING" }
        Write-Host "  [$status] $e"
    }

    Write-Step "Checking process GIT_CONFIG_* pollution"
    $gitEnv = Get-ChildItem Env:GIT_CONFIG* -ErrorAction SilentlyContinue
    if ($gitEnv) {
        $emptyVals = $gitEnv | Where-Object { $_.Name -like "GIT_CONFIG_VALUE_*" -and [string]::IsNullOrEmpty($_.Value) }
        if ($emptyVals) {
            Write-Host "  [WARNING] Detected empty GIT_CONFIG_VALUE_* vars (e.g. $($emptyVals[0].Name)). Always strip Env:GIT_CONFIG* before launching VS Code!" -ForegroundColor Yellow
        } else {
            Write-Host "  [INFO] GIT_CONFIG_* vars present, no empty values detected."
        }
    } else {
        Write-Host "  [OK] Clean process environment (no GIT_CONFIG_* vars)."
    }

    Write-Step "Checking Git global config"
    $ErrorActionPreference = "Continue"
    git config --global user.name
    git config --global user.email
    git config --global core.quotepath
    if ($tools.Gh) {
        Write-Step "Checking GitHub CLI auth"
        & $tools.Gh auth status 2>&1
    }
    exit 0
}

if ([string]::IsNullOrWhiteSpace($TargetDir)) {
    $TargetDir = Join-Path $env:USERPROFILE $RepoName
    Write-Host "[INFO] -TargetDir not provided, defaulting to: $TargetDir" -ForegroundColor Yellow
}

Ensure-VsCodeExtensions $tools.Code
$ghUser = Ensure-GitHubAuth $tools.Gh
$fullRepo = if ($RepoName -match "/") { $RepoName } else { "$($ghUser.Login)/$RepoName" }

if ($Mode -eq "restore") {
    Write-Step "Cloning private repository $fullRepo -> $TargetDir"
    if (Test-Path -LiteralPath (Join-Path $TargetDir ".git")) {
        Write-Host "  [INFO] Git repo already exists at $TargetDir, pulling latest..."
        git -C "$TargetDir" pull --ff-only
    } else {
        $parent = Split-Path -Parent $TargetDir
        if ($parent -and -not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Force -Path $parent | Out-Null
        }
        & $tools.Gh repo clone $fullRepo "$TargetDir"
    }
    Ensure-VaultSettings $TargetDir
    Write-Step "Verifying passwordless pull/push"
    git -C "$TargetDir" pull --ff-only
    git -C "$TargetDir" push --dry-run
}
elseif ($Mode -eq "init") {
    New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
    Copy-StarterTemplates $TargetDir

    Write-Step "Initializing local Git repo and syncing to GitHub private repo $fullRepo"
    if (-not (Test-Path -LiteralPath (Join-Path $TargetDir ".git"))) {
        git -C "$TargetDir" init -b main
    }
    git -C "$TargetDir" add -A
    $ErrorActionPreference = "Continue"
    git -C "$TargetDir" diff --cached --quiet
    $hasStaged = ($LASTEXITCODE -ne 0)
    $ErrorActionPreference = "Stop"
    if ($hasStaged) {
        git -C "$TargetDir" commit -m "chore: initialize AI Prompt and Skills vault with GitDoc auto-sync"
    }

    $ErrorActionPreference = "Continue"
    & $tools.Gh repo view $fullRepo 2>&1 | Out-Null
    $repoExists = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = "Stop"

    if ($repoExists) {
        Write-Host "  [INFO] Remote repo $fullRepo already exists, linking origin and pushing..."
        $ErrorActionPreference = "Continue"
        git -C "$TargetDir" remote remove origin 2>$null
        $ErrorActionPreference = "Stop"
        git -C "$TargetDir" remote add origin "https://github.com/$fullRepo.git"
        git -C "$TargetDir" push -u origin main
    } else {
        $shortName = ($fullRepo -split "/")[-1]
        Push-Location -LiteralPath $TargetDir
        try {
            & $tools.Gh repo create $shortName --private --description "Personal AI Prompts and Skills Vault (auto-synced via VS Code GitDoc)" --source=. --remote=origin --push
        } finally {
            Pop-Location
        }
    }
}

Write-Host "`n[SUCCESS] Vault ready at: $TargetDir" -ForegroundColor Green
Write-Host "[SUCCESS] GitHub Private Repo: https://github.com/$fullRepo" -ForegroundColor Green

if (-not $SkipOpen) {
    Open-CleanVsCode $tools.Code $TargetDir
}
