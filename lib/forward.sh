#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  forward.sh — SSH 端口转发
# ═══════════════════════════════════════════════════════════════════

cmd_forward() {
    local subcmd="${1:-help}"
    shift 2>/dev/null || true

    case "$subcmd" in
        help|--help|-h)
            echo "用法:"
            echo "  remote forward <port>              转发工作站:port 到 localhost:port"
            echo "  remote forward <remote>:<local>    自定义本地端口"
            echo "  remote forward list                 查看活跃隧道"
            echo "  remote forward kill <port>          关闭指定隧道"
            ;;
        list)
            info "活跃 SSH 隧道:"
            pgrep -f "ssh.*-L.*localhost" 2>/dev/null | while read -r pid; do
                local cmd
                cmd=$(ps -p "$pid" -o args= 2>/dev/null)
                echo "  PID=$pid ${cmd##*ssh}"
            done || echo "  无"
            ;;
        kill)
            local port="${1:?需要指定端口}"
            local pid
            pid=$(pgrep -f "ssh.*-L.*:${port}:localhost:${port}" 2>/dev/null | head -1)
            if [[ -n "$pid" ]]; then
                kill "$pid" && ok "已关闭隧道 :$port (PID=$pid)"
            else
                warn "未找到端口 $port 的隧道"
            fi
            ;;
        *)
            local remote_port local_port
            if [[ "$subcmd" == *":"* ]]; then
                remote_port="${subcmd%%:*}"
                local_port="${subcmd##*:}"
            else
                remote_port="$subcmd"
                local_port="$subcmd"
            fi

            detect_best_target || { error "无法连接工作站"; return 1; }

            info "🔀 端口转发: localhost:$local_port → $_TARGET_IP:$remote_port"

            if [[ "$_TARGET_IP" == "$LAN_IP" ]] || [[ "$_TARGET_SOURCE" == "tailscale" ]]; then
                ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new \
                    -L "${local_port}:localhost:${remote_port}" \
                    -N -f \
                    "$REMOTE_USER@$_TARGET_IP" 2>/dev/null && \
                    ok "隧道已建立 (后台运行)" || \
                    error "隧道建立失败"
            else
                error "不支持通过 Runner 中继进行端口转发"
            fi
            ;;
    esac
}
