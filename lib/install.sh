#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  install.sh — 依赖自动安装（ssh/mosh/tailscale/rustdesk/zellij）
#  支持: Linux (apt/dnf/pacman) / macOS (brew) / Windows (winget)
# ═══════════════════════════════════════════════════════════════════

# 依赖定义：tool_name|display_name|pkg_name(apt)|pkg_name(brew)|pkg_name(winget)
_DEPS=(
    "ssh|SSH client+server|openssh-client,openssh-server|openssh|OpenSSH.Client"
    "mosh|Mosh UDP shell|mosh|mosh|"
    "tailscale|Tailscale VPN||tailscale|Tailscale.Tailscale"
    "rustdesk|RustDesk desktop|rustdesk||RustDesk.RustDesk"
    "zellij|Zellij terminal multiplexer|zellij|zellij|"
    "rsync|rsync file sync|rsync|rsync|"
    "git|Git version control|git|git|Git.Git"
)

# 检查依赖是否已安装
_install_check_one() {
    local tool="$1"
    if command -v "$tool" &>/dev/null; then
        ok "$tool already installed"
        return 0
    fi
    return 1
}

# Linux apt 安装
_install_linux_apt() {
    local tool="$1" pkg="$2"
    info "Installing $tool via apt..."
    sudo apt-get install -y -qq "$pkg" 2>&1 || {
        warn "apt install failed for $pkg"
        return 1
    }
}

# Linux dnf 安装
_install_linux_dnf() {
    local tool="$1" pkg="$2"
    info "Installing $tool via dnf..."
    sudo dnf install -y -q "$pkg" 2>&1 || {
        warn "dnf install failed for $pkg"
        return 1
    }
}

# macOS brew 安装
_install_macos_brew() {
    local tool="$1" pkg="$2"
    info "Installing $tool via brew..."
    if [[ "$pkg" == "tailscale" ]]; then
        brew install --cask "$pkg" 2>&1 || return 1
    else
        brew install "$pkg" 2>&1 || return 1
    fi
}

# Windows winget 安装
_install_windows_winget() {
    local tool="$1" pkg="$2"
    info "Installing $tool via winget..."
    winget install --id "$pkg" --silent --accept-package-agreements --accept-source-agreements 2>&1 || {
        warn "winget install failed for $pkg"
        return 1
    }
}

# Tailscale 特殊安装（apt 源不在默认仓库）
_install_tailscale_apt() {
    info "Adding Tailscale apt repository..."
    local codename
    codename=$(lsb_release -cs 2>/dev/null || echo "jammy")
    curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.noarmor.gpg" \
        | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null 2>&1
    curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.tailscale-keyring.list" \
        | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null 2>&1
    sudo apt-get update -qq 2>/dev/null
    sudo apt-get install -y -qq tailscale 2>&1 || return 1
}

# ─── 主入口 ────────────────────────────────────────────────────
cmd_install() {
    local force=0 list_only=0
    for arg in "$@"; do
        case "$arg" in
            --force)  force=1 ;;
            --list)   list_only=1 ;;
        esac
    done

    detect_platform
    info "remote-cli installer"
    info "Platform: $RC_PLATFORM ($RC_DISTRO, $RC_PKG_MGR)"
    echo ""

    # 列出模式
    if [[ "$list_only" -eq 1 ]]; then
        info "Dependencies:"
        for entry in "${_DEPS[@]}"; do
            local tool="${entry%%|*}"
            local rest="${entry#*|}"
            local display="${rest%%|*}"
            local installed="no"
            command -v "$tool" &>/dev/null && installed="yes"
            echo "  $tool ($display): $installed"
        done
        return 0
    fi

    # 检测缺失
    local missing=()
    local missing_names=()
    for entry in "${_DEPS[@]}"; do
        local tool="${entry%%|*}"
        if ! command -v "$tool" &>/dev/null; then
            missing+=("$entry")
            missing_names+=("$tool")
        fi
    done

    if [[ ${#missing[@]} -eq 0 ]]; then
        ok "All dependencies already installed"
        return 0
    fi

    info "Missing: ${missing_names[*]}"
    echo ""

    if [[ "$force" -ne 1 ]]; then
        confirm "Install missing dependencies?" || { info "Cancelled"; return 0; }
    fi

    # 逐个安装
    for entry in "${missing[@]}"; do
        IFS='|' read -r tool display apt_pkg brew_pkg winget_pkg <<< "$entry"
        echo ""
        info "Installing $tool ($display)..."

        case "$RC_PLATFORM" in
            linux|wsl)
                # Tailscale 走 apt 源
                if [[ "$tool" == "tailscale" ]]; then
                    _install_tailscale_apt || warn "$tool install failed"
                    continue
                fi
                # apt 包可能多个（逗号分隔）
                if [[ -n "$apt_pkg" ]]; then
                    IFS=',' read -ra pkgs <<< "$apt_pkg"
                    local pkg_str="${pkgs[*]}"
                    if [[ "$RC_PKG_MGR" == "apt" ]]; then
                        _install_linux_apt "$tool" "$pkg_str"
                    elif [[ "$RC_PKG_MGR" == "dnf" ]]; then
                        _install_linux_dnf "$tool" "$pkg_str"
                    else
                        warn "Unknown package manager: $RC_PKG_MGR"
                    fi
                else
                    warn "No apt package defined for $tool"
                fi
                ;;
            macos)
                if [[ -n "$brew_pkg" ]]; then
                    _install_macos_brew "$tool" "$brew_pkg"
                else
                    warn "No brew package defined for $tool"
                fi
                ;;
            windows)
                if [[ -n "$winget_pkg" ]]; then
                    _install_windows_winget "$tool" "$winget_pkg"
                else
                    warn "No winget package defined for $tool (install manually)"
                fi
                ;;
            *)
                warn "Unsupported platform: $RC_PLATFORM"
                ;;
        esac
    done

    echo ""
    ok "Installation complete"
    info "Run 'remote status' to verify"
}