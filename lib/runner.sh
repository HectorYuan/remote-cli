#!/usr/bin/env bash
# remote-cli Runner 管理模块

cmd_runner() {
    load_config
    local subcmd="${1:-status}"

    if [[ -z "${RUNNER_IP:-}" ]]; then
        echo "❌ 未配置 RUNNER_IP，请在 ~/.config/remote-cli/config.env 中设置"
        return 1
    fi

    case "$subcmd" in
        status)
            echo "🖥️  Runner: $RUNNER_IP"
            echo ""
            ssh -i "$HOME/.ssh/neorun.pem" -o StrictHostKeyChecking=accept-new \
                "root@$RUNNER_IP" "
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
            local service="${2:-hbbs}"
            ssh -i "$HOME/.ssh/neorun.pem" "root@$RUNNER_IP" \
                "docker logs $service --tail 30 2>&1" 2>/dev/null
            ;;
        restart)
            echo "重启 Runner 容器..."
            ssh -i "$HOME/.ssh/neorun.pem" "root@$RUNNER_IP" "
                docker restart hbbs hbbr 2>&1
                echo '状态:' \$(docker ps --format '{{.Names}} {{.Status}}' | tr '\n' ', ')
            " 2>/dev/null
            ;;
        ssh)
            ssh -i "$HOME/.ssh/neorun.pem" "root@$RUNNER_IP"
            ;;
        *)
            echo "用法: remote runner [status|logs|restart|ssh]"
            ;;
    esac
}
