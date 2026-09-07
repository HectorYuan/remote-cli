#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  setup.sh — 首次交互式配置
# ═══════════════════════════════════════════════════════════════════

cmd_setup() {
    detect_platform
    info "remote-cli v$REMOTE_CLI_VERSION 首次配置"
    info "平台: $RC_PLATFORM ($RC_DISTRO)"
    echo ""

    # 1. 创建配置文件
    init_config

    # 2. 交互式配置
    _setup_interactive_config

    # 3. 重新加载配置
    load_config

    # 4. SSH 密钥
    _setup_ssh_key

    # 5. Tailscale 登录
    _setup_tailscale

    # 6. 启动服务
    _setup_services

    # 7. 最终状态
    echo ""
    ok "配置完成！"
    echo ""
    remote status 2>&1
}

_setup_interactive_config() {
    echo ""
    info "── 配置远程工作站 ──"

    # REMOTE_HOST
    if [[ -z "${REMOTE_HOST:-}" ]]; then
        read -rp "远程工作站 IP 或 Tailscale IP: " input_host
        if [[ -n "$input_host" ]]; then
            _update_config "REMOTE_HOST" "$input_host"
        fi
    else
        info "REMOTE_HOST: $REMOTE_HOST"
    fi

    # REMOTE_USER
    read -rp "SSH 用户名 [$REMOTE_USER]: " input_user
    if [[ -n "$input_user" ]]; then
        _update_config "REMOTE_USER" "$input_user"
    fi

    # Runner
    echo ""
    info "── 配置 Runner 中继 ──"
    read -rp "Runner IP（留空跳过）[${RUNNER_IP:-}]: " input_runner
    if [[ -n "$input_runner" ]]; then
        _update_config "RUNNER_IP" "$input_runner"
    fi

    if [[ -n "${RUNNER_IP:-}" ]]; then
        read -rp "Runner SSH 用户名 [$RUNNER_USER]: " input_runner_user
        if [[ -n "$input_runner_user" ]]; then
            _update_config "RUNNER_USER" "$input_runner_user"
        fi
    fi
}

_update_config() {
    local key="$1" value="$2"
    if grep -q "^${key}=" "$CONFIG_ENV" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$CONFIG_ENV"
    else
        echo "${key}=\"${value}\"" >> "$CONFIG_ENV"
    fi
}

_setup_ssh_key() {
    echo ""
    info "── SSH 密钥 ──"

    if [[ -f "$HOME/.ssh/id_ed25519" ]]; then
        ok "SSH 密钥已存在: ~/.ssh/id_ed25519"
    else
        if confirm "生成新的 SSH 密钥对？"; then
            ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -q
            ok "SSH 密钥已生成"
        fi
    fi

    # 配置 authorized_keys
    if [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then
        ensure_authorized_key "$HOME/.ssh/id_ed25519.pub"
    fi
}

_setup_tailscale() {
    echo ""
    info "── Tailscale ──"

    if ! command -v tailscale &>/dev/null; then
        warn "Tailscale 未安装"
        case "$RC_PKG_MGR" in
            apt)    info "安装: sudo apt install tailscale" ;;
            brew)   info "安装: brew install --cask tailscale" ;;
            *)      info "请访问 https://tailscale.com/download 安装" ;;
        esac
        return
    fi

    detect_tailscale
    if [[ "$_TS_RUNNING" -eq 0 ]]; then
        ok "Tailscale 已在线: $_TS_IP"
    else
        info "Tailscale 需要登录"
        if confirm "现在登录 Tailscale？"; then
            sudo tailscale up 2>&1 || warn "登录失败，请手动运行: sudo tailscale up"
        else
            info "稍后运行: sudo tailscale up"
        fi
    fi
}

_setup_services() {
    echo ""
    info "── 启动服务 ──"

    # SSH
    if ! is_service_active ssh 2>/dev/null && ! is_service_active ssh.socket 2>/dev/null; then
        if confirm "启动 SSH 服务？"; then
            sudo systemctl enable --now ssh 2>/dev/null || true
        fi
    fi

    # RustDesk
    if command -v rustdesk &>/dev/null && [[ -n "${RUSTDESK_KEY:-}" ]]; then
        ok "RustDesk 已配置"
    fi
}
