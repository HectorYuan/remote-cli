#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  remote-cli 一键安装脚本
#  用法: curl -fsSL <repo>/setup/install.sh | bash
#  支持: Linux / macOS / WSL
# ═══════════════════════════════════════════════════════════════════
set -euo pipefail

REMOTE_CLI_VERSION="$(curl -fsSL "${REPO_URL:-http://14.103.46.178}/VERSION" 2>/dev/null || cat "$(dirname "$0")/../VERSION" 2>/dev/null || echo "dev")"
INSTALL_DIR="${REMOTE_CLI_DIR:-$HOME/.local/remote-cli}"
REPO_URL="${REMOTE_CLI_REPO:-http://14.103.46.178}"

# ─── 日志 ──────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()  { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

# ─── 平台检测 ──────────────────────────────────────────────────
detect_platform() {
    PLATFORM="unknown"
    PKG_MGR=""
    case "$(uname -s)" in
        Linux)
            if [[ -n "${WSL_DISTRO_NAME:-}" ]] || grep -qi microsoft /proc/version 2>/dev/null; then
                PLATFORM="wsl"
            else
                PLATFORM="linux"
            fi
            command -v apt-get &>/dev/null && PKG_MGR="apt"
            command -v dnf &>/dev/null && PKG_MGR="dnf"
            command -v pacman &>/dev/null && PKG_MGR="pacman"
            ;;
        Darwin) PLATFORM="macos"; command -v brew &>/dev/null && PKG_MGR="brew" ;;
    esac
    info "平台: $PLATFORM (${PKG_MGR:-无包管理器})"
}

# ─── 检查依赖 ──────────────────────────────────────────────────
check_deps() {
    local missing=()
    for cmd in git curl; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    [[ ${#missing[@]} -gt 0 ]] && fail "缺少依赖: ${missing[*]}"
    ok "基础依赖就绪"
}

# ─── 安装 remote-cli ──────────────────────────────────────────
install_remote_cli() {
    if [[ -d "$INSTALL_DIR/.git" ]]; then
        info "remote-cli 已安装，更新中..."
        git -C "$INSTALL_DIR" pull --ff-only --quiet 2>/dev/null || warn "更新失败，使用现有版本"
    else
        info "下载 remote-cli..."
        mkdir -p "$(dirname "$INSTALL_DIR")"
        # 尝试从 HTTP 服务器下载 tarball
        local tarball_url="${REPO_URL}/remote-cli.tar.gz"
        if curl -fsSL --retry 3 -o /tmp/remote-cli.tar.gz "$tarball_url" 2>/dev/null; then
            mkdir -p "$INSTALL_DIR"
            tar xzf /tmp/remote-cli.tar.gz -C "$INSTALL_DIR" --strip-components=1
            rm -f /tmp/remote-cli.tar.gz
        elif command -v git &>/dev/null; then
            # Fallback: git clone
            git clone --depth 1 "$REPO_URL" "$INSTALL_DIR" 2>/dev/null || \
            fail "下载失败，请检查网络"
        else
            fail "下载失败，请安装 git 或检查网络"
        fi
    fi
    chmod +x "$INSTALL_DIR/bin/remote"
    ok "remote-cli 已安装到 $INSTALL_DIR"
}

# ─── 配置 PATH ─────────────────────────────────────────────────
setup_path() {
    local shell_rc=""
    if [[ "$(uname -s)" == "Darwin" ]]; then
        shell_rc="$HOME/.zshrc"
    elif [[ -f "$HOME/.bashrc" ]]; then
        shell_rc="$HOME/.bashrc"
    elif [[ -f "$HOME/.zprofile" ]]; then
        shell_rc="$HOME/.zprofile"
    fi

    if [[ -n "$shell_rc" ]]; then
        if ! grep -q "remote-cli" "$shell_rc" 2>/dev/null; then
            echo '' >> "$shell_rc"
            echo '# remote-cli' >> "$shell_rc"
            echo "export PATH=\"$INSTALL_DIR/bin:\$PATH\"" >> "$shell_rc"
            info "已添加 PATH 到 $shell_rc"
        fi
    fi
    export PATH="$INSTALL_DIR/bin:$PATH"
}

# ─── 安装系统依赖 ──────────────────────────────────────────────
install_system_deps() {
    info "检查系统依赖..."
    local need_install=()

    # SSH
    command -v ssh &>/dev/null || need_install+=("ssh")
    # Mosh
    command -v mosh &>/dev/null || need_install+=("mosh")
    # Tailscale
    command -v tailscale &>/dev/null || need_install+=("tailscale")

    if [[ ${#need_install[@]} -gt 0 ]]; then
        info "将安装: ${need_install[*]}"
        case "$PKG_MGR" in
            apt)
                sudo apt-get update -qq 2>/dev/null
                for pkg in "${need_install[@]}"; do
                    case "$pkg" in
                        ssh)       sudo apt-get install -y -qq openssh-server openssh-client 2>/dev/null ;;
                        mosh)      sudo apt-get install -y -qq mosh 2>/dev/null ;;
                        tailscale) install_tailscale_apt ;;
                    esac
                done
                ;;
            brew)
                for pkg in "${need_install[@]}"; do
                    case "$pkg" in
                        ssh)       brew install openssh 2>/dev/null ;;
                        mosh)      brew install mosh 2>/dev/null ;;
                        tailscale) brew install --cask tailscale 2>/dev/null ;;
                    esac
                done
                ;;
            *)
                warn "自动安装暂不支持 $PKG_MGR，请手动安装: ${need_install[*]}"
                ;;
        esac
    fi
    ok "系统依赖就绪"
}

install_tailscale_apt() {
    if ! command -v tailscale &>/dev/null; then
        local codename
        codename=$(lsb_release -cs 2>/dev/null || echo "jammy")
        curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.noarmor.gpg" | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null 2>&1
        curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.tailscale-keyring.list" | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null 2>&1
        sudo apt-get update -qq 2>/dev/null
        sudo apt-get install -y -qq tailscale 2>/dev/null
    fi
}

# ─── 初始化配置 ────────────────────────────────────────────────
init_config() {
    local config_dir="$HOME/.config/remote-cli"
    local config_file="$config_dir/config.env"
    mkdir -p "$config_dir"
    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" << 'EOF'
# remote-cli 配置（不要提交到 git）
CONFIG_VERSION=1
REMOTE_HOST=""
REMOTE_USER="hector"
RUNNER_IP=""
RUNNER_USER="root"
RUNNER_KEY="~/.ssh/neorun.pem"
RUSTDESK_KEY=""
CODE_SERVER_PORT=8080
EOF
        chmod 600 "$config_file"
        ok "配置文件已创建: $config_file"
        info "请编辑 $config_file 填入你的远程工作站信息"
    else
        ok "配置已存在: $config_file"
    fi
}

# ─── 主流程 ────────────────────────────────────────────────────
main() {
    echo ""
    echo "═══════════════════════════════════════════════"
    echo "  remote-cli v$REMOTE_CLI_VERSION 安装器"
    echo "═══════════════════════════════════════════════"
    echo ""

    detect_platform
    check_deps
    install_remote_cli
    setup_path
    install_system_deps
    init_config

    echo ""
    echo "═══════════════════════════════════════════════"
    ok "安装完成！"
    echo ""
    echo "  运行以下命令开始:"
    echo "    remote --help              # 查看所有命令"
    echo "    remote setup               # 首次配置"
    echo "    remote status              # 检查状态"
    echo "    remote connect             # 连接工作站"
    echo ""
    echo "  配置文件: ~/.config/remote-cli/config.env"
    echo "═══════════════════════════════════════════════"
    echo ""
}

main "$@"
