#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  doctor.sh — 集成诊断
#  把 status + fix + 网络连通性 + Runner 中继状态整合成单一入口
# ═══════════════════════════════════════════════════════════════════

ssh_runner_cmd_quiet() {
    ssh -i "$RUNNER_KEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 \
        "$RUNNER_USER@$RUNNER_IP" "$1" 2>/dev/null
}

doctor_check_sshd() {
    detect_sshd; [[ "$_SSHD_ACTIVE" -eq 0 ]]
}

doctor_check_ssh_key() {
    [[ -f "$HOME/.ssh/id_ed25519" ]] || [[ -f "$SSH_KEY" ]]
}

doctor_check_tailscale() {
    detect_tailscale; [[ "$_TS_RUNNING" -eq 0 ]]
}

doctor_check_rustdesk() {
    detect_rustdesk; [[ "$_RD_CONFIGURED" -eq 0 ]]
}

doctor_check_runner() {
    detect_runner; [[ "$_RUNNER_REACHABLE" -eq 0 ]]
}

doctor_check_config() {
    [[ -f "$CONFIG_ENV" ]] && grep -q "^REMOTE_HOST=" "$CONFIG_ENV" 2>/dev/null
}

doctor_check_disk() {
    if [[ -n "${RUNNER_IP:-}" ]]; then
        local pct
        pct=$(ssh_runner_cmd_quiet "df / | tail -1 | awk '{print \$5}' | tr -d '%'")
        [[ "${pct:-0}" -lt 90 ]]
    else
        return 0
    fi
}

doctor_check_nginx() {
    if [[ -n "${RUNNER_IP:-}" ]]; then
        ssh_runner_cmd_quiet "docker ps | grep -q remote-cli-nginx"
    else
        return 0
    fi
}

# 严重性图标
_severity_icon() {
    case "$1" in
        critical) echo "🔴";;
        high)     echo "🟠";;
        medium)   echo "🟡";;
        info)     echo "🟢";;
        *)        echo "⚪";;
    esac
}

# 诊断项定义在函数内（避免 set -u + 数组跨子 shell 的问题）
_doctor_check_one() {
    local check_fn="$1" severity="$2" desc="$3"
    local icon
    icon=$(_severity_icon "$severity")
    if "$check_fn" 2>/dev/null; then
        printf "%-30s %-10s %s\n" "$check_fn" "✅ pass" ""
        return 0
    else
        printf "%-30s %-10s %s %s\n" "$check_fn" "❌ FAIL" "$icon" "$desc"
        return 1
    fi
}

cmd_doctor() {
    local fix_mode=0 json_mode=0 verbose=0
    for arg in "$@"; do
        case "$arg" in
            --fix)     fix_mode=1 ;;
            --json)    json_mode=1 ;;
            --verbose) verbose=1 ;;
        esac
    done

    load_config
    detect_platform

    # 检查项列表（函数内定义，格式：check_fn|severity|description）
    local checks=(
        "doctor_check_sshd|critical|sshd 服务未运行"
        "doctor_check_ssh_key|critical|SSH 密钥未配置"
        "doctor_check_tailscale|high|Tailscale 未登录"
        "doctor_check_rustdesk|high|RustDesk 未配置 Runner 中继"
        "doctor_check_runner|medium|Runner 中继不可达"
        "doctor_check_config|medium|配置文件缺失或格式错误"
        "doctor_check_disk|info|Runner 磁盘空间"
        "doctor_check_nginx|info|Runner nginx 服务"
    )

    local total=${#checks[@]}
    local passed=0 failed=0
    local -a json_results=()

    echo ""
    info "remote-cli doctor (v$REMOTE_CLI_VERSION)"
    info "Platform: $RC_PLATFORM"

    if [[ "$json_mode" -eq 1 ]]; then
        local -a json_lines=()
        for entry in "${checks[@]}"; do
            IFS='|' read -r check_fn severity desc <<< "$entry"
            local status
            if "$check_fn" 2>/dev/null; then
                status="pass"; passed=$((passed + 1))
            else
                status="fail"; failed=$((failed + 1))
            fi
            json_lines+=("    {\"name\": \"$check_fn\", \"status\": \"$status\", \"severity\": \"$severity\"}")
        done
        # 用逗号连接
        local IFS=','
        echo "{"
        echo "  \"version\": \"$REMOTE_CLI_VERSION\","
        echo "  \"platform\": \"$RC_PLATFORM\","
        echo "  \"checks\": ["
        echo "    ${json_lines[*]}"
        echo "  ]"
        echo "}"
        return "$failed"
    fi

    echo ""
    printf "%-30s %-10s %s\n" "检查项" "状态" "详情"
    printf "%-30s %-10s %s\n" "----------------------" "--------" "----"

    for entry in "${checks[@]}"; do
        IFS='|' read -r check_fn severity desc <<< "$entry"
        if _doctor_check_one "$check_fn" "$severity" "$desc"; then
            passed=$((passed + 1))
        else
            failed=$((failed + 1))
        fi
    done

    echo ""
    info "通过 $passed / $total"
    [[ "$failed" -gt 0 ]] && warn "有 $failed 项失败"

    if [[ "$fix_mode" -eq 1 ]] && [[ "$failed" -gt 0 ]]; then
        echo ""
        info "联动 fix..."
        cmd_fix --auto
    fi

    if [[ "$verbose" -eq 1 ]]; then
        echo ""
        info "详细信息:"
        echo "  Tailscale IP: ${_TS_IP:-N/A}"
        echo "  Runner IP: ${RUNNER_IP:-N/A}"
        echo "  Config file: $CONFIG_ENV"
        echo "  Bin directory: $REMOTE_CLI_DIR/bin"
    fi

    return "$failed"
}
