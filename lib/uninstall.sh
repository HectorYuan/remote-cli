#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  uninstall.sh — 卸载 remote-cli（只删自身+配置，不删系统依赖）
# ═══════════════════════════════════════════════════════════════════

cmd_uninstall() {
    local confirm_flag=0
    for arg in "$@"; do
        [[ "$arg" == "--confirm" ]] && confirm_flag=1
    done

    echo ""
    warn "即将卸载 remote-cli v$REMOTE_CLI_VERSION"
    echo ""
    echo "  将删除:"
    echo "    $REMOTE_CLI_DIR"
    echo "    $CONFIG_DIR"
    echo ""
    echo "  不会删除:"
    echo "    SSH/Mosh/Tailscale/RustDesk/Zellij/code-server（系统依赖）"
    echo ""

    if [[ "$confirm_flag" -eq 0 ]]; then
        read -rp "确认卸载？[y/N] " answer
        [[ "$answer" =~ ^[Yy]$ ]] || { info "已取消"; return 0; }
    fi

    # 1. 删除 PATH 配置（从 bashrc.d.sh 移除）
    local bashrc="$HOME/DevSpace/config/bash/bashrc.d.sh"
    if [[ -f "$bashrc" ]]; then
        sed -i '/remote-cli/d' "$bashrc" 2>/dev/null
        ok "已从 bashrc.d.sh 移除 PATH"
    fi

    # 2. 删除配置目录
    if [[ -d "$CONFIG_DIR" ]]; then
        rm -rf "$CONFIG_DIR"
        ok "已删除配置: $CONFIG_DIR"
    fi

    # 3. 删除 remote-cli 目录
    rm -rf "$REMOTE_CLI_DIR"
    ok "已删除 remote-cli: $REMOTE_CLI_DIR"

    echo ""
    ok "卸载完成"
}
