# ═══════════════════════════════════════════════════════════════════
#  remote-cli Windows installer
#  Usage: irm http://14.103.46.178/setup/install.ps1 | iex
#  Supports: Windows 10/11 (PowerShell 5.1+)
# ═══════════════════════════════════════════════════════════════════

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$RepoUrl = "https://14.103.46.178"
$InstallDir = "$env:USERPROFILE\.local\remote-cli"
$ConfigDir = "$env:USERPROFILE\.config\remote-cli"

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "  remote-cli Windows installer" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host ""

# --- Check dependencies ---
Write-Host "[INFO]  Checking dependencies..." -ForegroundColor Cyan

# Git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[FAIL]  Git is required: https://git-scm.com/download/win" -ForegroundColor Red
    exit 1
}
Write-Host "[OK]    Git installed" -ForegroundColor Green

# --- Install remote-cli ---
if (Test-Path "$InstallDir\.git") {
    Write-Host "[INFO]  Updating remote-cli..." -ForegroundColor Cyan
    Push-Location $InstallDir
    git pull --ff-only --quiet 2>$null
    Pop-Location
} else {
    Write-Host "[INFO]  Downloading remote-cli..." -ForegroundColor Cyan
    if (Test-Path $InstallDir) { Remove-Item -Recurse -Force $InstallDir }
    # Try tarball download first
    $tarball = "$env:TEMP\remote-cli.tar.gz"
    try {
        Invoke-WebRequest -Uri "$RepoUrl/remote-cli.tar.gz" -OutFile $tarball -UseBasicParsing -SkipCertificateCheck
        New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
        tar xzf $tarball -C $InstallDir --strip-components=1
        Remove-Item $tarball -Force
    } catch {
        # Fallback: git clone
        git clone --depth 1 $RepoUrl $InstallDir 2>$null
        if (-not (Test-Path "$InstallDir\bin\remote.ps1")) {
            Write-Host "[FAIL]  Download failed. Check network." -ForegroundColor Red
            exit 1
        }
    }
}
$Version = Get-Content "$InstallDir\VERSION" -ErrorAction SilentlyContinue
if (-not $Version) { $Version = "dev" }
Write-Host "[OK]    remote-cli v$($Version.Trim()) installed to $InstallDir" -ForegroundColor Green

# --- Configure PATH ---
$BinDir = "$InstallDir\bin"
$CurrentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($CurrentPath -notlike "*$BinDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$BinDir;$CurrentPath", "User")
    $env:Path = "$BinDir;$env:Path"
    Write-Host "[INFO]  Added to PATH (restart terminal to take effect)" -ForegroundColor Cyan
} else {
    Write-Host "[OK]    PATH already includes remote-cli" -ForegroundColor Green
}

# --- Check system deps (skip admin-required checks) ---
Write-Host "[INFO]  Checking system dependencies..." -ForegroundColor Cyan

# OpenSSH Client (usually pre-installed on Windows 10+)
$ssh = Get-Command ssh -ErrorAction SilentlyContinue
if ($ssh) {
    Write-Host "[OK]    OpenSSH Client installed" -ForegroundColor Green
} else {
    Write-Host "[WARN]  OpenSSH Client not found" -ForegroundColor Yellow
}

# Tailscale
if (Get-Command tailscale -ErrorAction SilentlyContinue) {
    Write-Host "[OK]    Tailscale installed" -ForegroundColor Green
} else {
    Write-Host "[WARN]  Tailscale not installed" -ForegroundColor Yellow
    Write-Host "  Download: https://tailscale.com/download/windows" -ForegroundColor Yellow
    Write-Host "  Or run: winget install Tailscale.Tailscale" -ForegroundColor Yellow
}

# RustDesk
if (Get-Command rustdesk -ErrorAction SilentlyContinue) {
    Write-Host "[OK]    RustDesk installed" -ForegroundColor Green
} else {
    Write-Host "[WARN]  RustDesk not installed" -ForegroundColor Yellow
    Write-Host "  Download: https://rustdesk.com/download" -ForegroundColor Yellow
    Write-Host "  Or run: winget install RustDesk.RustDesk" -ForegroundColor Yellow
}

# Mosh (not supported on Windows)
Write-Host "[WARN]  Mosh is not supported on Windows, SSH will be used" -ForegroundColor Yellow

# --- Initialize config ---
if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }
$ConfigFile = "$ConfigDir\config.env"
if (-not (Test-Path $ConfigFile)) {
    @"
# remote-cli config (do not commit to git)
# --- Remote workstation ---
REMOTE_HOST=""                    # Workstation Tailscale IP or LAN IP
REMOTE_USER="hector"              # SSH username
# --- Runner relay server ---
RUNNER_IP=""                      # Runner public IP (for RustDesk relay)
RUNNER_USER="root"                # Runner SSH username
RUNNER_KEY="~/.ssh/neorun.pem"    # Runner SSH private key path
RUSTDESK_KEY=""                   # RustDesk relay public key
# --- Services ---
CODE_SERVER_PORT=8080             # code-server port
"@ | Out-File -FilePath $ConfigFile -Encoding UTF8
    Write-Host "[OK]    Config created: $ConfigFile" -ForegroundColor Green
    Write-Host "  Edit it to fill in your workstation info" -ForegroundColor Yellow
} else {
    Write-Host "[OK]    Config exists: $ConfigFile" -ForegroundColor Green
}

# --- Done ---
Write-Host ""
Write-Host "==============================================" -ForegroundColor Green
Write-Host "  Installation complete!" -ForegroundColor Green
Write-Host ""
Write-Host "  Getting started:" -ForegroundColor White
Write-Host "    remote --help              Show all commands"
Write-Host "    remote status              Check status"
Write-Host "    remote connect             Connect to workstation"
Write-Host ""
Write-Host "  Config: $ConfigFile"
Write-Host "==============================================" -ForegroundColor Green
Write-Host ""
