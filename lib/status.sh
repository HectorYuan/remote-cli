#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  status.sh — 健康检查
#  支持: --json (JSON 输出) --deps (含依赖检测)
# ═══════════════════════════════════════════════════════════════════

cmd_status() {
    local json=0 deps=0 watch=0 interval=5
    for arg in "$@"; do
        case "$arg" in
            --json) json=1 ;;
            --deps) deps=1 ;;
            --watch)
                # 兼容 --watch=N 或 --watch N
                if [[ "$arg" == *=* ]]; then
                    interval="${arg#*=}"
                else
                    interval="${2:-5}"
                    shift
                fi
                watch=1
                ;;
        esac
    done

    if [[ "$watch" -eq 1 ]]; then
        info "定时刷新 (每 ${interval}s, Ctrl+C 退出)"
        while true; do
            clear
            cmd_status
            sleep "$interval"
        done
    fi

    detect_all

    if [[ "$json" -eq 1 ]]; then
        _status_json
        return 0
    fi

    _status_human "$deps"
}

_status_human() {
    local deps="${1:-0}"
    local has_error=0

    echo ""
    printf "%-20s %-12s %s\n" "服务" "状态" "详情"
    printf "%-20s %-12s %s\n" "--------------------" "------------" "----"

    # SSH
    if [[ "$_SSHD_ACTIVE" -eq 0 ]]; then
        printf "%-20s %-12s %s\n" "sshd" "✅ active" "端口 22"
    else
        printf "%-20s %-12s %s\n" "sshd" "❌ inactive" "sudo systemctl enable --now ssh"
        has_error=1
    fi

    # Mosh
    if [[ "$_MOSH_AVAILABLE" -eq 0 ]]; then
        printf "%-20s %-12s %s\n" "mosh" "✅ ready" "端口 ${MOSH_PORT_START}-${MOSH_PORT_END}"
    else
        printf "%-20s %-12s %s\n" "mosh" "⚠️  missing" "sudo apt install mosh"
    fi

    # Tailscale
    if [[ "$_TS_RUNNING" -eq 0 ]]; then
        printf "%-20s %-12s %s\n" "tailscale" "✅ online" "$_TS_IP"
    elif command -v tailscale &>/dev/null; then
        printf "%-20s %-12s %s\n" "tailscale" "⚠️  logged out" "sudo tailscale up"
    else
        printf "%-20s %-12s %s\n" "tailscale" "❌ missing" "sudo apt install tailscale"
        has_error=1
    fi

    # RustDesk
    if [[ "$_RD_CONFIGURED" -eq 0 ]]; then
        printf "%-20s %-12s %s\n" "rustdesk" "✅ ready" "中继: $_RD_SERVER"
    else
        printf "%-20s %-12s %s\n" "rustdesk" "⚠️  not configured" "remote fix"
    fi

    # code-server
    if [[ "$_CS_ACTIVE" -eq 0 ]]; then
        local cs_ip
        cs_ip=$(get_tailscale_ip 2>/dev/null || echo "localhost")
        printf "%-20s %-12s %s\n" "code-server" "✅ active" "http://${cs_ip}:${_CS_PORT:-8080}"
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
        if [[ "$_RUNNER_REACHABLE" -eq 0 ]]; then
            printf "%-20s %-12s %s\n" "runner" "✅ reachable" "$RUNNER_IP"
        else
            printf "%-20s %-12s %s\n" "runner" "⚠️  unreachable" "$RUNNER_IP"
        fi
    fi

    # 依赖检测
    if [[ "$deps" -eq 1 ]]; then
        echo ""
        printf "%-20s %-12s\n" "依赖" "状态"
        printf "%-20s %-12s\n" "--------------------" "------------"
        _dep_row "ssh" "$_DEPS_SSH"
        _dep_row "mosh" "$_DEPS_MOSH"
        _dep_row "tailscale" "$_DEPS_TAILSCALE"
        _dep_row "rustdesk" "$_DEPS_RUSTDESK"
        _dep_row "zellij" "$_DEPS_ZELLIJ"
    fi

    echo ""
    if [[ "$has_error" -eq 1 ]]; then
        warn "有服务未就绪，运行 'remote fix' 修复"
    else
        ok "所有核心服务就绪"
    fi
    echo ""
}

_dep_row() {
    local name="$1" installed="$2"
    if [[ "$installed" -eq 0 ]]; then
        printf "%-20s %-12s\n" "$name" "✅ installed"
    else
        printf "%-20s %-12s\n" "$name" "❌ missing"
    fi
}

_status_json() {
    # 纯 bash JSON 输出，不依赖 jq
    local sep=""
    echo "{"
    echo "  \"version\": \"$REMOTE_CLI_VERSION\","
    echo "  \"platform\": \"$(uname -s | tr '[:upper:]' '[:lower:]')\","
    echo "  \"services\": {"
    _json_kv "sshd" "$_SSHD_ACTIVE" "端口 22" true
    echo ","
    _json_kv "mosh" "$_MOSH_AVAILABLE" "端口 ${MOSH_PORT_START}-${MOSH_PORT_END}" true
    echo ","
    _json_kv "tailscale" "$_TS_RUNNING" "${_TS_IP:-}" true
    echo ","
    _json_kv "rustdesk" "$_RD_CONFIGURED" "${_RD_SERVER:-}" true
    echo ","
    _json_kv "code_server" "$_CS_ACTIVE" "http://$(get_tailscale_ip 2>/dev/null || echo 'localhost'):${_CS_PORT:-8080}" true
    echo ","
    _json_kv "zellij" "$(command -v zellij &>/dev/null && echo 0 || echo 1)" "$(ls ~/.config/zellij/layouts/*.kdl 2>/dev/null | wc -l) layouts" true
    echo ","
    if [[ -n "${RUNNER_IP:-}" ]]; then
        _json_kv "runner" "$_RUNNER_REACHABLE" "$RUNNER_IP" false
    else
        echo "    \"runner\": {\"active\": null, \"detail\": \"not configured\"}"
    fi
    echo ""
    echo "  },"
    echo "  \"dependencies\": {"
    echo "    \"ssh\": $([ "$_DEPS_SSH" -eq 0 ] && echo true || echo false),"
    echo "    \"mosh\": $([ "$_DEPS_MOSH" -eq 0 ] && echo true || echo false),"
    echo "    \"tailscale\": $([ "$_DEPS_TAILSCALE" -eq 0 ] && echo true || echo false),"
    echo "    \"rustdesk\": $([ "$_DEPS_RUSTDESK" -eq 0 ] && echo true || echo false),"
    echo "    \"zellij\": $([ "$_DEPS_ZELLIJ" -eq 0 ] && echo true || echo false)"
    echo "  }"
    echo "}"
}

_json_kv() {
    local name="$1" active="$2" detail="$3" comma="${4:-true}"
    local active_json
    [[ "$active" -eq 0 ]] && active_json="true" || active_json="false"
    detail="${detail//\\/\\\\}"
    detail="${detail//\"/\\\"}"
    echo "    \"$name\": {\"active\": $active_json, \"detail\": \"$detail\"}"
}
