#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  runner.sh — Runner 中继服务器管理
#  v0.2.2: 简化远程命令，避免引号嵌套
# ═══════════════════════════════════════════════════════════════════

_runner_ssh() {
    local host="${1:-$RUNNER_IP}" user="${2:-$RUNNER_USER}" key="${3:-$RUNNER_KEY}" cmd="${4:-}"
    [[ -z "$host" ]] && die "未配置 RUNNER_IP，请在 $CONFIG_ENV 中设置"
    ssh -i "$key" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "$user@$host" "$cmd"
}

_runner_cmd() {
    _runner_ssh "$RUNNER_IP" "$RUNNER_USER" "$RUNNER_KEY" "$1" 2>/dev/null
}

cmd_runner() {
    local subcmd="${1:-status}"
    shift 2>/dev/null || true

    case "$subcmd" in
        status)
            info "Runner: $RUNNER_IP"
            _runner_cmd "docker ps --format '{{.Names}}\t{{.Status}}'" && echo ""
            _runner_cmd "df -h / | tail -1" && echo ""
            _runner_cmd "free -h | head -2 | tail -1"
            ;;
        logs)
            local service="${1:-hbbs}"
            [[ "$service" =~ ^[a-zA-Z0-9._-]+$ ]] || die "非法服务名: $service"
            _runner_cmd "docker logs $service --tail 30 2>&1"
            ;;
        restart)
            info "重启 Runner 容器..."
            _runner_cmd "docker restart hbbs hbbr"
            echo ""
            _runner_cmd "docker ps --format '{{.Names}} {{.Status}}'"
            ;;
        ssh)
            _runner_ssh "$RUNNER_IP" "$RUNNER_USER" "$RUNNER_KEY"
            ;;
        *)
            echo "用法: remote runner [status|logs|restart|ssh]"
            ;;
    esac
}
