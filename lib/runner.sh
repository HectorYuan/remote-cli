#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  runner.sh — Runner 中继服务器管理
#  所有配置从 config.env 读取，不硬编码
# ═══════════════════════════════════════════════════════════════════

_runner_ssh() {
    local host="${1:-$RUNNER_IP}"
    local user="${2:-$RUNNER_USER}"
    local key="${3:-$RUNNER_KEY}"
    [[ -z "$host" ]] && die "未配置 RUNNER_IP，请在 $CONFIG_ENV 中设置"
    ssh -i "$key" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "$user@$host"
}

cmd_runner() {
    local subcmd="${1:-status}"
    shift 2>/dev/null || true

    case "$subcmd" in
        status)
            info "Runner: $RUNNER_IP"
            _runner_ssh "$RUNNER_IP" "$RUNNER_USER" "$RUNNER_KEY" "
                echo 'Docker 容器:'
                docker ps --format '  {{.Names}}\t{{.Status}}' 2>/dev/null
                echo ''
                echo '磁盘:'
                df -h / | tail -1 | awk '{print \"  使用: \"\$3\"/\"\$2\" (\"\$5\")\"}'
                echo ''
                echo '内存:'
                free -h | head -2 | tail -1 | awk '{print \"  使用: \"\$3\"/\"\$2}'
            " 2>/dev/null
            ;;
        logs)
            local service="${1:-hbbs}"
            # 安全校验：只允许合法容器名
            [[ "$service" =~ ^[a-zA-Z0-9._-]+$ ]] || die "非法服务名: $service"
            _runner_ssh "$RUNNER_IP" "$RUNNER_USER" "$RUNNER_KEY" \
                "docker logs $service --tail 30 2>&1" 2>/dev/null
            ;;
        restart)
            info "重启 Runner 容器..."
            _runner_ssh "$RUNNER_IP" "$RUNNER_USER" "$RUNNER_KEY" "
                docker restart hbbs hbbr 2>&1
                echo '状态:' \$(docker ps --format '{{.Names}} {{.Status}}' | tr '\n' ', ')
            " 2>/dev/null
            ;;
        ssh)
            _runner_ssh "$RUNNER_IP" "$RUNNER_USER" "$RUNNER_KEY"
            ;;
        *)
            echo "用法: remote runner [status|logs|restart|ssh]"
            ;;
    esac
}
