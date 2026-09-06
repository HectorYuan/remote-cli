#!/usr/bin/env bash
# remote-cli 健康检查模块

cmd_status() {
    load_config

    local has_error=0

    echo ""
    printf "%-20s %-12s %s\n" "服务" "状态" "详情"
    printf "%-20s %-12s %s\n" "--------------------" "------------" "----"

    # SSH
    detect_sshd
    if [[ "$_SSHD_ACTIVE" -eq 0 ]]; then
        printf "%-20s %-12s %s\n" "sshd" "✅ active" "端口 22"
    else
        printf "%-20s %-12s %s\n" "sshd" "❌ inactive" "sudo systemctl enable --now ssh"
        has_error=1
    fi

    # Mosh
    detect_mosh
    if [[ "$_MOSH_AVAILABLE" -eq 0 ]]; then
        printf "%-20s %-12s %s\n" "mosh" "✅ ready" "端口 ${MOSH_PORT_START}-${MOSH_PORT_END}"
    else
        printf "%-20s %-12s %s\n" "mosh" "⚠️  missing" "sudo apt install mosh"
    fi

    # Tailscale
    detect_tailscale
    if [[ "$_TS_RUNNING" -eq 0 ]]; then
        printf "%-20s %-12s %s\n" "tailscale" "✅ online" "$_TS_IP"
    elif command -v tailscale &>/dev/null; then
        printf "%-20s %-12s %s\n" "tailscale" "⚠️  logged out" "sudo tailscale up"
    else
        printf "%-20s %-12s %s\n" "tailscale" "❌ missing" "sudo apt install tailscale"
        has_error=1
    fi

    # RustDesk
    detect_rustdesk
    if [[ "$_RD_CONFIGURED" -eq 0 ]]; then
        printf "%-20s %-12s %s\n" "rustdesk" "✅ ready" "中继: $_RD_SERVER"
    else
        printf "%-20s %-12s %s\n" "rustdesk" "⚠️  not configured" "remote fix"
    fi

    # code-server
    detect_code_server
    if [[ "$_CS_ACTIVE" -eq 0 ]]; then
        local cs_ip
        cs_ip=$(get_tailscale_ip 2>/dev/null || echo "localhost")
        printf "%-20s %-12s %s\n" "code-server" "✅ active" "http://${cs_ip}:${_CS_PORT:-8443}"
    else
        printf "%-20s %-12s %s\n" "code-server" "⚠️  inactive" "sudo systemctl enable --now code-server@$(whoami)"
    fi

    # Zellij
    if command -v zellij &>/dev/null; then
        local layouts
        layouts=$(ls ~/.config/zellij/layouts/*.kdl 2>/dev/null | wc -l)
        printf "%-20s %-12s %s\n" "zellij" "✅ ready" "${layouts} layouts"
    else
        printf "%-20s %-12s %s\n" "zellij" "❌ missing" "需要安装"
    fi

    # Runner
    if [[ -n "${RUNNER_IP:-}" ]]; then
        detect_runner
        if [[ "$_RUNNER_REACHABLE" -eq 0 ]]; then
            printf "%-20s %-12s %s\n" "runner" "✅ reachable" "$RUNNER_IP"
        else
            printf "%-20s %-12s %s\n" "runner" "⚠️  unreachable" "$RUNNER_IP"
        fi
    fi

    echo ""
    if [[ "$has_error" -eq 1 ]]; then
        echo "⚠️  有服务未就绪，运行 'remote fix' 修复"
    else
        echo "✅ 所有核心服务就绪"
    fi
    echo ""
}
