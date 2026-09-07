# ═══════════════════════════════════════════════════════════════════
#  remote-cli Windows 安装脚本
#  用法: irm https://raw.githubusercontent.com/HectorYuan/remote-cli/main/setup/install.ps1 | iex
#  支持: Windows 10/11 (PowerShell 5.1+)
# ═══════════════════════════════════════════════════════════════════

$ErrorActionPreference = "Stop"
$RepoUrl = "https://github.com/HectorYuan/remote-cli"
$InstallDir = "$env:USERPROFILE\.local\remote-cli"
$ConfigDir = "$env:USERPROFILE\.config\remote-cli"

Write-Host ""
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  remote-cli Windows 安装器" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# ─── 检查依赖 ──────────────────────────────────────────────────
Write-Host "[INFO]  检查依赖..." -ForegroundColor Cyan

# Git
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[FAIL]  需要安装 Git: https://git-scm.com/download/win" -ForegroundColor Red
    exit 1
}
Write-Host "[OK]    Git 已安装" -ForegroundColor Green

# ─── 安装 remote-cli ──────────────────────────────────────────
if (Test-Path "$InstallDir\.git") {
    Write-Host "[INFO]  remote-cli 已安装，更新中..." -ForegroundColor Cyan
    Push-Location $InstallDir
    git pull --ff-only --quiet 2>$null
    Pop-Location
} else {
    Write-Host "[INFO]  下载 remote-cli..." -ForegroundColor Cyan
    if (Test-Path $InstallDir) { Remove-Item -Recurse -Force $InstallDir }
    git clone --depth 1 $RepoUrl $InstallDir 2>$null
    if (-not (Test-Path "$InstallDir\bin\remote.ps1")) {
        Write-Host "[FAIL]  克隆失败，请检查网络" -ForegroundColor Red
        exit 1
    }
}
$Version = Get-Content "$InstallDir\VERSION" -ErrorAction SilentlyContinue
if (-not $Version) { $Version = "dev" }
Write-Host "[OK]    remote-cli v$($Version.Trim()) 已安装到 $InstallDir" -ForegroundColor Green

# ─── 配置 PATH ─────────────────────────────────────────────────
$BinDir = "$InstallDir\bin"
$CurrentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($CurrentPath -notlike "*$BinDir*") {
    [Environment]::SetEnvironmentVariable("Path", "$BinDir;$CurrentPath", "User")
    $env:Path = "$BinDir;$env:Path"
    Write-Host "[INFO]  已添加到 PATH (需要重启终端生效)" -ForegroundColor Cyan
} else {
    Write-Host "[OK]    PATH 已包含 remote-cli" -ForegroundColor Green
}

# ─── 安装系统依赖 ──────────────────────────────────────────────
Write-Host "[INFO]  检查系统依赖..." -ForegroundColor Cyan

# OpenSSH Client（Windows 10+ 自带）
$sshClient = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Client*'
if ($sshClient.State -ne "Installed") {
    Write-Host "[INFO]  安装 OpenSSH Client..." -ForegroundColor Cyan
    Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
}
Write-Host "[OK]    OpenSSH Client 已安装" -ForegroundColor Green

# Tailscale
if (-not (Get-Command tailscale -ErrorAction SilentlyContinue)) {
    Write-Host "[WARN]  Tailscale 未安装" -ForegroundColor Yellow
    Write-Host "  下载: https://tailscale.com/download/windows" -ForegroundColor Yellow
    Write-Host "  或运行: winget install Tailscale.Tailscale" -ForegroundColor Yellow
} else {
    Write-Host "[OK]    Tailscale 已安装" -ForegroundColor Green
}

# RustDesk
if (-not (Get-Command rustdesk -ErrorAction SilentlyContinue)) {
    Write-Host "[WARN]  RustDesk 未安装" -ForegroundColor Yellow
    Write-Host "  下载: https://rustdesk.com/download" -ForegroundColor Yellow
    Write-Host "  或运行: winget install RustDesk.RustDesk" -ForegroundColor Yellow
} else {
    Write-Host "[OK]    RustDesk 已安装" -ForegroundColor Green
}

# Mosh（Windows 不支持原生 mosh）
Write-Host "[WARN]  Mosh 在 Windows 上不支持，将使用 SSH" -ForegroundColor Yellow

# ─── 初始化配置 ────────────────────────────────────────────────
if (-not (Test-Path $ConfigDir)) { New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null }
$ConfigFile = "$ConfigDir\config.env"
if (-not (Test-Path $ConfigFile)) {
    @"
# remote-cli 敏感配置（不要提交到 git）
# ─── 远程工作站 ──────────────────────────
REMOTE_HOST=""                    # 工作站 Tailscale IP 或局域网 IP
REMOTE_USER="hector"              # SSH 用户名
# ─── Runner 中继服务器 ──────────────────
RUNNER_IP=""                      # Runner 公网 IP（RustDesk 中继）
RUNNER_USER="root"                # Runner SSH 用户名
RUNNER_KEY="~/.ssh/id_ed25519"    # Runner SSH 私钥路径
RUSTDESK_KEY=""                   # RustDesk 中继公钥
# ─── 服务配置 ──────────────────────────
CODE_SERVER_PORT=8080             # code-server 端口
"@ | Out-File -FilePath $ConfigFile -Encoding UTF8
    Write-Host "[OK]    配置文件已创建: $ConfigFile" -ForegroundColor Green
    Write-Host "  请编辑 $ConfigFile 填入你的远程工作站信息" -ForegroundColor Yellow
} else {
    Write-Host "[OK]    配置已存在: $ConfigFile" -ForegroundColor Green
}

# ─── 完成 ──────────────────────────────────────────────────────
Write-Host ""
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Green
Write-Host "  安装完成！" -ForegroundColor Green
Write-Host ""
Write-Host "  运行以下命令开始:" -ForegroundColor White
Write-Host "    remote --help              # 查看所有命令"
Write-Host "    remote status              # 检查状态"
Write-Host "    remote connect             # 连接工作站"
Write-Host ""
Write-Host "  配置文件: $ConfigFile"
Write-Host "═══════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""
