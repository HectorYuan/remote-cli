# ═══════════════════════════════════════════════════════════════════
#  remote — Windows PowerShell 版本
#  功能: 通过 SSH 连接远程工作站
# ═══════════════════════════════════════════════════════════════════
param(
    [Parameter(Position=0)]
    [string]$Command,

    [Parameter(Position=1, ValueFromRemainingArguments)]
    [string[]]$Args,

    [switch]$Help,
    [switch]$Version
)

$ErrorActionPreference = "Stop"

# ─── 配置加载 ──────────────────────────────────────────────────
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

# ─── 帮助 ──────────────────────────────────────────────────────
function Show-Help {
    Write-Host ""
    Write-Host "用法: remote <command> [options]"
    Write-Host ""
    Write-Host "命令:"
    Write-Host "  connect [host]       SSH 连接工作站"
    Write-Host "  status               健康检查"
    Write-Host "  desktop              RustDesk 远程桌面"
    Write-Host "  config               查看配置"
    Write-Host "  --version            版本号"
    Write-Host "  --help               帮助"
    Write-Host ""
    Write-Host "Windows 不支持: mosh, zellij, 文件传输（用 scp 替代）"
    Write-Host ""
}

# ─── connect ───────────────────────────────────────────────────
function Connect-Remote {
    param([string]$TargetHost)

    if ($TargetHost) {
        $host_ = $TargetHost
    } elseif ($RemoteHost) {
        $host_ = $RemoteHost
    } else {
        Write-Host "[ERROR] 未配置 REMOTE_HOST，请编辑 $ConfigFile" -ForegroundColor Red
        return
    }

    Write-Host "[INFO]  连接 $RemoteUser@$host_ ..." -ForegroundColor Cyan
    ssh "$RemoteUser@$host_"
}

# ─── status ────────────────────────────────────────────────────
function Show-Status {
    Write-Host ""
    Write-Host "服务              状态         详情"
    Write-Host "────              ────         ────"

    # SSH Client
    $ssh = Get-Command ssh -ErrorAction SilentlyContinue
    if ($ssh) { Write-Host "ssh              ✅ installed  $($ssh.Source)" }
    else { Write-Host "ssh              ❌ missing" }

    # Tailscale
    $ts = Get-Command tailscale -ErrorAction SilentlyContinue
    if ($ts) {
        $tsStatus = & tailscale status --json 2>$null | ConvertFrom-Json
        if ($tsStatus.BackendState -eq "Running") {
            $tsIp = & tailscale ip -4 2>$null
            Write-Host "tailscale        ✅ online     $tsIp"
        } else {
            Write-Host "tailscale        ⚠️  logged out"
        }
    } else {
        Write-Host "tailscale        ❌ missing    需要安装"
    }

    # RustDesk
    $rd = Get-Command rustdesk -ErrorAction SilentlyContinue
    if ($rd) { Write-Host "rustdesk         ✅ installed" }
    else { Write-Host "rustdesk         ⚠️  missing   需要安装" }

    # Config
    if ($RemoteHost) {
        Write-Host "remote_host      ✅ configured $RemoteHost"
    } else {
        Write-Host "remote_host      ⚠️  not set   编辑 $ConfigFile"
    }

    Write-Host ""
}

# ─── desktop ───────────────────────────────────────────────────
function Start-Desktop {
    $rd = Get-Command rustdesk -ErrorAction SilentlyContinue
    if (-not $rd) {
        Write-Host "[ERROR] RustDesk 未安装" -ForegroundColor Red
        Write-Host "  下载: https://rustdesk.com/download" -ForegroundColor Yellow
        return
    }

    if ($RunnerIp -and $Config['RUSTDESK_KEY']) {
        Write-Host "[INFO]  启动 RustDesk (中继: $RunnerIp)" -ForegroundColor Cyan
        Start-Process rustdesk
    } else {
        Write-Host "[INFO]  启动 RustDesk" -ForegroundColor Cyan
        Start-Process rustdesk
    }
}

# ─── 主路由 ────────────────────────────────────────────────────
if ($Help -or $Command -eq "help" -or -not $Command) {
    Show-Help
    return
}

if ($Version) {
    Write-Host "remote-cli 0.2.0 (Windows)"
    return
}

switch ($Command) {
    "connect"  { Connect-Remote -TargetHost ($Args | Select-Object -First 1) }
    "status"   { Show-Status }
    "desktop"  { Start-Desktop }
    "config" {
        Write-Host "配置文件: $ConfigFile"
        if (Test-Path $ConfigFile) {
            Get-Content $ConfigFile | Where-Object { $_ -notmatch 'KEY|PASSWORD|SECRET|TOKEN' }
        }
    }
    default {
        Write-Host "[ERROR] 未知命令: $Command" -ForegroundColor Red
        Show-Help
    }
}
