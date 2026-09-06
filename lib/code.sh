#!/usr/bin/env bash
# remote-cli code-server 模块

cmd_code() {
    load_config
    detect_code_server

    if [[ "$_CS_ACTIVE" -ne 0 ]]; then
        echo "⚠️  code-server 未运行"
        echo "   启动: sudo systemctl enable --now code-server@$USER"
        return 1
    fi

    local cs_ip
    cs_ip=$(get_tailscale_ip 2>/dev/null || echo "$LAN_IP")
    local url="http://${cs_ip}:${_CS_PORT:-8443}"

    echo "💻 code-server"
    echo "   URL: $url"
    echo ""
    echo "   在浏览器中打开上述地址即可访问"
}
