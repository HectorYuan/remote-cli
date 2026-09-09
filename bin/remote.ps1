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

# --- enroll (join a new device with one-time token) ---
function Join-Enroll {
    param([string]$Token)

    if (-not $Token) {
        Write-Host "Usage: remote enroll <RC-xxxx token>" -ForegroundColor Yellow
        return
    }
    if (-not $RunnerIp) {
        Write-Host "[ERROR] RUNNER_IP not set. Edit $ConfigFile" -ForegroundColor Red
        return
    }

    $enrollPort = 8100
    Write-Host "[INFO]  Enrolling with token $Token ..." -ForegroundColor Cyan

    # 1. Fetch workstation config
    Write-Host "[1/4]  Fetching workstation config..." -ForegroundColor Cyan
    try {
        $resp = Invoke-RestMethod -Uri "http://${RunnerIp}:${enrollPort}/enroll/config/$Token" -TimeoutSec 10 -SkipCertificateCheck
    } catch {
        Write-Host "[FAIL]  Invalid or expired token" -ForegroundColor Red
        return
    }
    $cfg = $resp.config

    # 2. Generate SSH key (idempotent)
    Write-Host "[2/4]  Checking SSH key..." -ForegroundColor Cyan
    $sshDir = "$env:USERPROFILE\.ssh"
    $keyFile = "$sshDir\id_ed25519"
    if (-not (Test-Path $keyFile)) {
        New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
        ssh-keygen -t ed25519 -f $keyFile -N '""' -q 2>$null
        # Windows ssh-keygen 需要 -N '' 处理差异，验证生成结果
        if (-not (Test-Path $keyFile)) {
            ssh-keygen -t ed25519 -f $keyFile -N '""' | Out-Null
        }
        Write-Host "[OK]    SSH key generated" -ForegroundColor Green
    } else {
        Write-Host "[OK]    SSH key exists" -ForegroundColor Green
    }

    # 3. Upload public key
    Write-Host "[3/4]  Uploading public key..." -ForegroundColor Cyan
    try {
        $pubKey = Get-Content "$keyFile.pub" -Raw
        $resp2 = Invoke-RestMethod -Uri "http://${RunnerIp}:${enrollPort}/enroll/key/$Token" `
            -Method Post -ContentType "text/plain" -Body $pubKey -TimeoutSec 10 -SkipCertificateCheck
        Write-Host "[OK]    Public key uploaded" -ForegroundColor Green
    } catch {
        Write-Host "[FAIL]  Upload failed (token may be used/expired): $_" -ForegroundColor Red
        return
    }

    # 4. Write local config
    Write-Host "[4/4]  Writing local config..." -ForegroundColor Cyan
    if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }
    @"
# remote-cli config (auto-generated by remote enroll)
REMOTE_HOST="$($cfg.REMOTE_HOST)"
REMOTE_USER="$($cfg.REMOTE_USER)"
RUNNER_IP="$RunnerIp"
RUNNER_USER="root"
RUNNER_KEY="~/.ssh/id_ed25519"
RUSTDESK_KEY="$($cfg.RUSTDESK_KEY)"
CODE_SERVER_PORT=$($cfg.CODE_SERVER_PORT)
"@ | Out-File -FilePath $ConfigFile -Encoding UTF8

    Write-Host ""
    Write-Host "Enrollment complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1. Wait for workstation to run 'remote enroll sync'"
    Write-Host "  2. Then: remote connect"
    Write-Host ""
    Write-Host "Workstation Tailscale IP: $($cfg.REMOTE_HOST)"
}

switch ($Command) {
    "connect"  { Connect-Remote -TargetHost ($Args | Select-Object -First 1) }
    "status"   { Show-Status }
    "desktop"  { Start-Desktop }
    "install"  { Install-Deps }
    "enroll"   { Join-Enroll -Token ($Args | Select-Object -First 1) }
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