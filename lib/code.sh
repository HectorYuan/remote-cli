#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  code.sh — code-server Web IDE
# ═══════════════════════════════════════════════════════════════════

cmd_code() {
    detect_code_server

    if [[ "$_CS_ACTIVE" -ne 0 ]]; then
        warn "code-server 未运行"
        info "启动: sudo systemctl enable --now code-server@$(whoami)"
        return 1
    fi

    local cs_ip
    cs_ip=$(get_tailscale_ip 2>/dev/null || echo "$LAN_IP")
    local url="http://${cs_ip}:${_CS_PORT:-8080}"

    info "💻 code-server"
    info "   URL: $url"
    echo ""
    info "在浏览器中打开上述地址即可访问"
}
