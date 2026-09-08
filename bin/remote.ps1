<#
  remote-cli Windows PowerShell entry point
  Usage: remote <command> [options]
  Supports: Windows 10/11 (PowerShell 5.1+)
#>

param(
    [Parameter(Position=0)]
    [string]$Command,

    [Parameter(Position=1, ValueFromRemainingArguments)]
    [string[]]$Args,

    [switch]$Help,
    [switch]$Version
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- Config loading ---
$ConfigDir = "$env:USERPROFILE\.config\remote-cli"
$ConfigFile = "$ConfigDir\config.env"
$Config = @{}

if (Test-Path $ConfigFile) {
    Get-Content $ConfigFile | ForEach-Object {
        if ($_ -match '^(\w+)=(.*)$') {
            $Config[$Matches[1]] = $Matches[2].Trim('"').Trim("'")
        }
    }
}

$RemoteHost = $Config['REMOTE_HOST']
$RemoteUser = $Config['REMOTE_USER']
if (-not $RemoteUser) { $RemoteUser = "hector" }
$RunnerIp = $Config['RUNNER_IP']
$RunnerUser = $Config['RUNNER_USER']
if (-not $RunnerUser) { $RunnerUser = "root" }
$RunnerKey = $Config['RUNNER_KEY']
if (-not $RunnerKey) { $RunnerKey = "$env:USERPROFILE\.ssh\id_ed25519" }
$RunnerKey = $RunnerKey -replace '~', $env:USERPROFILE
$RustdeskKey = $Config['RUSTDESK_KEY']

# --- Help ---
function Show-Help {
    Write-Host ""
    Write-Host "Usage: remote <command> [options]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  connect [host]       SSH connect to workstation"
    Write-Host "  status               Health check"
    Write-Host "  desktop              RustDesk remote desktop"
    Write-Host "  config               Show config"
    Write-Host "  --version            Version"
    Write-Host "  --help               Help"
    Write-Host ""
    Write-Host "Windows limitations: no mosh, no zellij, use scp for file transfer"
    Write-Host ""
}

# --- connect ---
function Connect-Remote {
    param([string]$TargetHost)

    if ($TargetHost) {
        $host_ = $TargetHost
    } elseif ($RemoteHost) {
        $host_ = $RemoteHost
    } else {
        Write-Host "[ERROR] REMOTE_HOST not configured. Edit $ConfigFile" -ForegroundColor Red
        return
    }

    Write-Host "[INFO]  Connecting to $RemoteUser@$host_ ..." -ForegroundColor Cyan
    ssh "$RemoteUser@$host_"
}

# --- status ---
function Show-Status {
    Write-Host ""
    Write-Host "Service              Status        Detail"
    Write-Host "------               ------        ------"

    # SSH Client
    $ssh = Get-Command ssh -ErrorAction SilentlyContinue
    if ($ssh) {
        Write-Host "ssh                 OK installed $($ssh.Source)"
    } else {
        Write-Host "ssh                 -- missing"
    }

    # Tailscale
    $ts = Get-Command tailscale -ErrorAction SilentlyContinue
    if ($ts) {
        $tsStatus = & tailscale status --json 2>$null | ConvertFrom-Json
        if ($tsStatus.BackendState -eq "Running") {
            $tsIp = & tailscale ip -4 2>$null
            Write-Host "tailscale           OK online    $tsIp"
        } else {
            Write-Host "tailscale           -- logged out"
        }
    } else {
        Write-Host "tailscale           -- missing    Install required"
    }

    # RustDesk
    $rd = Get-Command rustdesk -ErrorAction SilentlyContinue
    if ($rd) {
        Write-Host "rustdesk            OK installed"
    } else {
        Write-Host "rustdesk            -- missing    Install required"
    }

    # Config
    if ($RemoteHost) {
        Write-Host "remote_host         OK configured $RemoteHost"
    } else {
        Write-Host "remote_host         -- not set    Edit $ConfigFile"
    }

    Write-Host ""
}

# --- install ---
function Install-Deps {
    $deps = @(
        @{ Tool = "ssh";       Pkg = "OpenSSH.Client" }
        @{ Tool = "tailscale"; Pkg = "Tailscale.Tailscale" }
        @{ Tool = "rustdesk";  Pkg = "RustDesk.RustDesk" }
        @{ Tool = "git";       Pkg = "Git.Git" }
    )

    Write-Host ""
    Write-Host "Checking dependencies..." -ForegroundColor Cyan

    $missing = @()
    foreach ($d in $deps) {
        if (Get-Command $d.Tool -ErrorAction SilentlyContinue) {
            Write-Host "[OK]    $($d.Tool) installed" -ForegroundColor Green
        } else {
            Write-Host "[--]    $($d.Tool) missing" -ForegroundColor Yellow
            $missing += $d
        }
    }

    if ($missing.Count -eq 0) {
        Write-Host ""
        Write-Host "All dependencies installed" -ForegroundColor Green
        return
    }

    if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host ""
        Write-Host "[WARN] winget not found. Install manually:" -ForegroundColor Yellow
        foreach ($d in $missing) {
            Write-Host "  $($d.Tool): https://www.google.com/search?q=$($d.Tool)+download" -ForegroundColor Yellow
        }
        return
    }

    Write-Host ""
    $confirm = Read-Host "Install missing dependencies? [y/N]"
    if ($confirm -ne "y" -and $confirm -ne "Y") {
        Write-Host "Cancelled"
        return
    }

    foreach ($d in $missing) {
        Write-Host ""
        Write-Host "[INFO]  Installing $($d.Tool)..." -ForegroundColor Cyan
        winget install --id $d.Pkg --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[OK]    $($d.Tool) installed" -ForegroundColor Green
        } else {
            Write-Host "[FAIL]  $($d.Tool) install failed" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "Done. Run 'remote status' to verify." -ForegroundColor Green
}

# --- desktop ---
function Start-Desktop {
    $rd = Get-Command rustdesk -ErrorAction SilentlyContinue
    if (-not $rd) {
        Write-Host "[ERROR] RustDesk not installed" -ForegroundColor Red
        Write-Host "  Download: https://rustdesk.com/download" -ForegroundColor Yellow
        return
    }

    if ($RunnerIp -and $RustdeskKey) {
        Write-Host "[INFO]  Starting RustDesk (relay: $RunnerIp)" -ForegroundColor Cyan
    } else {
        Write-Host "[INFO]  Starting RustDesk" -ForegroundColor Cyan
    }
    Start-Process rustdesk
}

# --- Main router ---
if ($Help -or $Command -eq "help" -or -not $Command) {
    Show-Help
    return
}

if ($Version) {
    $ver = Get-Content "$PSScriptRoot\..\VERSION" -ErrorAction SilentlyContinue
    if (-not $ver) { $ver = "dev" }
    Write-Host "remote-cli $($ver.Trim()) (Windows)"
    return
}

switch ($Command) {
    "connect"  { Connect-Remote -TargetHost ($Args | Select-Object -First 1) }
    "status"   { Show-Status }
    "desktop"  { Start-Desktop }
    "install"  { Install-Deps }
    "config" {
        Write-Host "Config: $ConfigFile"
        if (Test-Path $ConfigFile) {
            Get-Content $ConfigFile | Where-Object { $_ -notmatch 'KEY|PASSWORD|SECRET|TOKEN' }
        }
    }
    default {
        Write-Host "[ERROR] Unknown command: $Command" -ForegroundColor Red
        Show-Help
    }
}