#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  common.sh — 基础设施
#  职责：日志 / 错误处理 / 幂等写入 / 平台检测 / 依赖安装
# ═══════════════════════════════════════════════════════════════════

# ─── 路径定位 ──────────────────────────────────────────────────
REMOTE_CLI_DIR="${REMOTE_CLI_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# ─── 版本号 ────────────────────────────────────────────────────
REMOTE_CLI_VERSION="$(cat "$REMOTE_CLI_DIR/VERSION" 2>/dev/null | tr -d '[:space:]' || echo "dev")"

# ─── 日志（写 stderr，自动检测终端颜色）───────────────────────
_RC_QUIET="${RC_QUIET:-0}"
_RC_COLOR=0
[[ -t 2 ]] && _RC_COLOR=1

if [[ "$_RC_COLOR" -eq 1 ]]; then
    info()  { [[ "$_RC_QUIET" -eq 0 ]] && echo -e "\033[0;36m[INFO]\033[0m  $*" >&2; }
    ok()    { [[ "$_RC_QUIET" -eq 0 ]] && echo -e "\033[0;32m[OK]\033[0m    $*" >&2; }
    warn()  { echo -e "\033[1;33m[WARN]\033[0m  $*" >&2; }
    error() { echo -e "\033[0;31m[ERROR]\033[0m $*" >&2; }
else
    info()  { [[ "$_RC_QUIET" -eq 0 ]] && echo "[INFO]  $*" >&2; }
    ok()    { [[ "$_RC_QUIET" -eq 0 ]] && echo "[OK]    $*" >&2; }
    warn()  { echo "[WARN]  $*" >&2; }
    error() { echo "[ERROR] $*" >&2; }
fi
die() { error "$@"; exit 1; }

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
# 设置全局变量: RC_PLATFORM, RC_DISTRO, RC_PKG_MGR, RC_INIT, RC_SUDO, RC_HAS_GUI
detect_platform() {
    RC_PLATFORM="unknown"
    RC_DISTRO=""
    RC_PKG_MGR=""
    RC_INIT=""
    RC_SUDO="sudo"
    RC_HAS_GUI=1

    case "$(uname -s)" in
        Linux)
            # WSL 检测（优先级最高）
            if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
                RC_PLATFORM="wsl"
                RC_DISTRO="${WSL_DISTRO_NAME:-wsl}"
            else
                RC_PLATFORM="linux"
            fi

            if [[ -f /etc/os-release ]]; then
                RC_DISTRO=$(grep ^ID= /etc/os-release | cut -d= -f2 | tr -d '"')
            fi

            # 包管理器
            if command -v apt-get &>/dev/null; then
                RC_PKG_MGR="apt"
            elif command -v dnf &>/dev/null; then
                RC_PKG_MGR="dnf"
            elif command -v pacman &>/dev/null; then
                RC_PKG_MGR="pacman"
            fi

            # init 系统
            if pidof systemd &>/dev/null; then
                RC_INIT="systemd"
            fi

            # WSL 无 GUI
            [[ "$RC_PLATFORM" == "wsl" ]] && RC_HAS_GUI=0
            ;;

        Darwin)
            RC_PLATFORM="macos"
            RC_DISTRO="macos"
            if command -v brew &>/dev/null; then
                RC_PKG_MGR="brew"
            fi
            RC_INIT="launchd"
            ;;

        MINGW*|MSYS*|CYGWIN*)
            RC_PLATFORM="windows"
            RC_DISTRO="windows"
            RC_PKG_MGR="winget"
            RC_INIT="services"
            # Windows 可能有 GUI
            RC_HAS_GUI=1
            ;;
    esac

    export RC_PLATFORM RC_DISTRO RC_PKG_MGR RC_INIT RC_SUDO RC_HAS_GUI
}

is_linux()  { [[ "${RC_PLATFORM:-}" == "linux" || "${RC_PLATFORM:-}" == "wsl" ]]; }
is_macos()  { [[ "${RC_PLATFORM:-}" == "macos" ]]; }
is_wsl()    { [[ "${RC_PLATFORM:-}" == "wsl" ]]; }
is_windows(){ [[ "${RC_PLATFORM:-}" == "windows" ]]; }

# ─── 服务检测（跨平台多态）────────────────────────────────────
is_service_active() {
    local service="$1"
    if command -v systemctl &>/dev/null; then
        systemctl is-active --quiet "$service" 2>/dev/null
    elif is_macos; then
        launchctl list "$service" &>/dev/null 2>&1
    elif is_windows; then
        sc query "$service" 2>/dev/null | grep -q "RUNNING"
    else
        return 2
    fi
}

enable_service() {
    local service="$1"
    if is_windows; then
        sc start "$service" 2>/dev/null
    elif command -v systemctl &>/dev/null; then
        sudo systemctl enable --now "$service" 2>/dev/null
    elif is_macos; then
        brew services start "$service" 2>/dev/null
    else
        return 2
    fi
}

# ─── 幂等写入 ──────────────────────────────────────────────────
atomic_write() {
    local target="$1" content="$2"
    local tmp="${target}.tmp.$$"
    printf '%s\n' "$content" > "$tmp" && mv "$tmp" "$target"
    local rc=$?
    [[ $rc -ne 0 ]] && rm -f "$tmp"
    return $rc
}

ensure_line_in_file() {
    local file="$1" line="$2"
    if [[ -f "$file" ]] && grep -qF "$line" "$file" 2>/dev/null; then
        return 0
    fi
    mkdir -p "$(dirname "$file")" 2>/dev/null
    echo "$line" >> "$file"
}

ensure_authorized_key() {
    local pubkey_file="${1:-$HOME/.ssh/id_ed25519.pub}"
    local auth_file="$HOME/.ssh/authorized_keys"
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    [[ -f "$auth_file" ]] || touch "$auth_file"
    local pubkey
    pubkey=$(cat "$pubkey_file" 2>/dev/null)
    [[ -z "$pubkey" ]] && return 1
    grep -qF "$pubkey" "$auth_file" || echo "$pubkey" >> "$auth_file"
}

ensure_file_content() {
    local file="$1" content="$2"
    if [[ -f "$file" ]] && diff -q <(echo "$content") "$file" &>/dev/null; then
        return 0
    fi
    atomic_write "$file" "$content"
}

# ─── 网络检测 ──────────────────────────────────────────────────
check_port() {
    local host="$1" timeout="${2:-3}"
    timeout "$timeout" bash -c "echo >/dev/tcp/$host/22" 2>/dev/null
}

# ─── Tailscale ─────────────────────────────────────────────────
get_tailscale_ip() {
    tailscale ip -4 2>/dev/null || echo ""
}

is_tailscale_running() {
    local state
    state=$(tailscale status --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('BackendState',''))" 2>/dev/null || true)
    [[ "$state" == "Running" ]]
}

# ─── 跨平台依赖安装 ────────────────────────────────────────────
install_dep() {
    local pkg="$1" display="${2:-$1}"
    # 已安装则跳过
    command -v "$pkg" &>/dev/null && return 0

    info "安装 $display..."
    case "$RC_PKG_MGR" in
        apt)
            sudo apt-get install -y -qq "$pkg" 2>/dev/null
            ;;
        dnf)
            sudo dnf install -y -q "$pkg" 2>/dev/null
            ;;
        brew)
            brew install "$pkg" 2>/dev/null
            ;;
        winget)
            winget install --id "$pkg" --silent --accept-package-agreements 2>/dev/null
            ;;
        *)
            warn "未知包管理器，无法自动安装 $display"
            warn "请手动安装: $display"
            return 1
            ;;
    esac
}

# ─── PATH 管理 ─────────────────────────────────────────────────
add_to_path() {
    local dir="$1"
    local shell_rc=""

    # 确定 shell 配置文件
    if is_macos; then
        shell_rc="$HOME/.zshrc"
    elif [[ -f "$HOME/.bashrc" ]]; then
        shell_rc="$HOME/.bashrc"
    elif [[ -f "$HOME/.zprofile" ]]; then
        shell_rc="$HOME/.zprofile"
    fi

    if [[ -n "$shell_rc" ]]; then
        ensure_line_in_file "$shell_rc" "export PATH=\"$dir:\$PATH\""
        export PATH="$dir:$PATH"
    fi
}

remove_from_path() {
    local dir="$1"
    local shell_rc=""
    if is_macos; then
        shell_rc="$HOME/.zshrc"
    elif [[ -f "$HOME/.bashrc" ]]; then
        shell_rc="$HOME/.bashrc"
    fi
    [[ -n "$shell_rc" ]] && sed -i "\|$dir|d" "$shell_rc" 2>/dev/null
}
