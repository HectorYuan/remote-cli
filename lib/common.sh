#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  common.sh — 基础设施
#  职责：日志 / 错误处理 / 幂等写入 / 平台检测
#  不含任何业务逻辑，只提供纯工具函数
# ═══════════════════════════════════════════════════════════════════

# ─── 路径定位 ──────────────────────────────────────────────────
REMOTE_CLI_DIR="${REMOTE_CLI_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# ─── 版本号（从 VERSION 文件读取）──────────────────────────────
REMOTE_CLI_VERSION="$(cat "$REMOTE_CLI_DIR/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "dev")"

# ─── 日志（写 stderr，不污染 stdout）───────────────────────────
_RC_QUIET="${RC_QUIET:-0}"

info()  { [[ "$_RC_QUIET" -eq 0 ]] && echo -e "\033[0;36m[INFO]\033[0m  $*" >&2; }
ok()    { [[ "$_RC_QUIET" -eq 0 ]] && echo -e "\033[0;32m[OK]\033[0m    $*" >&2; }
warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*" >&2; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
die()   { error "$@"; exit 1; }

# ─── 工具函数 ──────────────────────────────────────────────────
require_cmd() {
    local cmd="$1" msg="${2:-需要安装 $1}"
    command -v "$cmd" &>/dev/null || { error "$msg"; return 1; }
}

confirm() {
    local prompt="${1:-确认执行?}"
    [[ "${_FORCE:-0}" -eq 1 ]] && return 0
    read -rp "$prompt [y/N] " _answer
    [[ "$_answer" =~ ^[Yy]$ ]]
}

# ─── 平台检测 ──────────────────────────────────────────────────
is_linux()  { [[ "$(uname -s)" == "Linux" ]]; }
is_macos()  { [[ "$(uname -s)" == "Darwin" ]]; }

# 服务检测（跨平台多态）
# 用法: is_service_active <service_name>
# return: 0=active, 1=inactive, 2=unknown platform
is_service_active() {
    local service="$1"
    if command -v systemctl &>/dev/null; then
        systemctl is-active --quiet "$service" 2>/dev/null
    elif is_macos; then
        launchctl list "$service" &>/dev/null 2>&1
    else
        return 2
    fi
}

# 启用并启动服务（跨平台）
enable_service() {
    local service="$1"
    if command -v systemctl &>/dev/null; then
        sudo systemctl enable --now "$service" 2>/dev/null
    elif is_macos; then
        brew services start "$service" 2>/dev/null
    else
        return 2
    fi
}

# ─── 幂等写入 ──────────────────────────────────────────────────
# 原子写入：先写 tmp 再 mv，避免中断写坏
atomic_write() {
    local target="$1" content="$2"
    local tmp="${target}.tmp.$$"
    echo "$content" > "$tmp" && mv "$tmp" "$target"
}

# 文件包含某行则跳过，否则追加
ensure_line_in_file() {
    local file="$1" line="$2"
    if [[ -f "$file" ]] && grep -qF "$line" "$file" 2>/dev/null; then
        return 0
    fi
    mkdir -p "$(dirname "$file")" 2>/dev/null
    echo "$line" >> "$file"
}

# SSH 公钥幂等写入（不重复追加）
ensure_authorized_key() {
    local pubkey_file="${1:-$HOME/.ssh/id_ed25519.pub}"
    local auth_file="$HOME/.ssh/authorized_keys"
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    [[ -f "$auth_file" ]] || touch "$auth_file"
    local pubkey
    pubkey=$(cat "$pubkey_file" 2>/dev/null)
    [[ -z "$pubkey" ]] && return 1
    if grep -qF "$pubkey" "$auth_file"; then
        return 0
    fi
    echo "$pubkey" >> "$auth_file"
}

# 文件内容相同则跳过，否则原子写入
ensure_file_content() {
    local file="$1" content="$2"
    if [[ -f "$file" ]] && diff -q <(echo "$content") "$file" &>/dev/null; then
        return 0
    fi
    atomic_write "$file" "$content"
}

# ─── SSH 端口可达性检测 ────────────────────────────────────────
# 用法: check_port <host> [timeout_seconds]
check_port() {
    local host="$1" timeout="${2:-3}"
    timeout "$timeout" bash -c "echo >/dev/tcp/$host/22" 2>/dev/null
}

# ─── 获取 Tailscale IP ─────────────────────────────────────────
get_tailscale_ip() {
    tailscale ip -4 2>/dev/null || echo ""
}

# Tailscale 是否在线
is_tailscale_running() {
    local state
    state=$(tailscale status --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('BackendState',''))" 2>/dev/null || true)
    [[ "$state" == "Running" ]]
}
