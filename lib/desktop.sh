#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  desktop.sh — RustDesk 远程桌面
# ═══════════════════════════════════════════════════════════════════

cmd_desktop() {
    detect_rustdesk

    if [[ "$_RD_CONFIGURED" -ne 0 ]]; then
        warn "RustDesk 未配置中继服务器"
        info "运行 'remote fix' 修复"
        return 1
    fi

    info "🖥️  RustDesk 远程桌面"
    info "   中继服务器: $_RD_SERVER"

    if command -v rustdesk &>/dev/null; then
        if pgrep -x rustdesk &>/dev/null; then
            info "RustDesk 已在运行"
        else
            info "启动 RustDesk..."
            nohup rustdesk &>/dev/null &
            ok "RustDesk 已启动"
        fi
        echo ""
        info "在笔记本端输入工作站的 RustDesk ID 即可连接"
    else
        error "RustDesk 未安装"
        info "需要: sudo snap install rustdesk"
    fi
}
