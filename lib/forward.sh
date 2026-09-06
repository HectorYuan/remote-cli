#!/usr/bin/env bash
# remote-cli 端口转发模块

cmd_forward() {
    local subcmd="${1:-help}"

    case "$subcmd" in
        help|--help|-h)
            echo "用法:"
            echo "  remote forward <port>              转发工作站:port 到 localhost:port"
            echo "  remote forward <remote>:<local>    自定义本地端口"
            echo "  remote forward list                 查看活跃隧道"
            echo "  remote forward kill <port>          关闭指定隧道"
            ;;
        list)
            echo "活跃 SSH 隧道:"
            ps aux | grep "ssh.*-L.*localhost" | grep -v grep | awk '{print "  PID="$2, $NF}' || echo "  无"
            ;;
        kill)
            local port="${2:?需要指定端口}"
            local pid
            pid=$(ps aux | grep "ssh.*-L.*:${port}:localhost:${port}" | grep -v grep | awk '{print $2}')
            if [[ -n "$pid" ]]; then
                kill "$pid" && echo "已关闭隧道 :$port (PID=$pid)"
            else
                echo "未找到端口 $port 的隧道"
            fi
            ;;
        *)
            # 端口转发
            local remote_port local_port
            if [[ "$subcmd" == *":"* ]]; then
                remote_port="${subcmd%%:*}"
                local_port="${subcmd##*:}"
            else
                remote_port="$subcmd"
                local_port="$subcmd"
            fi

            # 选择目标
            detect_best_target
            if [[ -z "$_TARGET_IP" ]]; then
                echo "❌ 无法连接工作站"
                return 1
            fi

            echo "🔀 端口转发: localhost:$local_port → $_TARGET_IP:$remote_port"
            echo "   按 Ctrl+C 关闭隧道"
            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new \
                -L "${local_port}:localhost:${remote_port}" \
                -N -f \
                "$SSH_USER@$_TARGET_IP" 2>/dev/null && \
                echo "✅ 隧道已建立 (后台运行)" || \
                echo "❌ 隧道建立失败"
            ;;
    esac
}
