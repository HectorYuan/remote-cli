#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  forward.sh — SSH 端口转发
#  v0.2.1: PID 文件机制，避免误杀
# ═══════════════════════════════════════════════════════════════════

_FWD_PID_DIR="/tmp/remote-fwd"

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
            mkdir -p "$_FWD_PID_DIR"
            info "活跃 SSH 隧道:"
            local found=0
            for pidfile in "$_FWD_PID_DIR"/*.pid; do
                [[ -f "$pidfile" ]] || continue
                local pid
                pid=$(cat "$pidfile")
                if kill -0 "$pid" 2>/dev/null; then
                    local port
                    port=$(basename "$pidfile" .pid)
                    echo "  端口 :$port (PID=$pid)"
                    found=1
                else
                    rm -f "$pidfile"  # 清理过期 PID
                fi
            done
            [[ "$found" -eq 0 ]] && echo "  无活跃隧道"
            ;;
        kill)
            local port="${1:?需要指定端口}"
            local pidfile="$_FWD_PID_DIR/${port}.pid"
            if [[ -f "$pidfile" ]]; then
                local pid
                pid=$(cat "$pidfile")
                if kill -0 "$pid" 2>/dev/null; then
                    kill "$pid" && ok "已关闭隧道 :$port (PID=$pid)"
                else
                    warn "进程 $pid 已不存在"
                fi
                rm -f "$pidfile"
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

            if [[ "$_TARGET_SOURCE" == "tailscale" ]] || [[ "$_TARGET_SOURCE" == "lan" ]]; then
                info "🔀 端口转发: localhost:$local_port → $_TARGET_IP:$remote_port"

                # 检查端口是否已被占用
                if ss -tlnp 2>/dev/null | grep -q ":${local_port} "; then
                    error "端口 $local_port 已被占用"
                    return 1
                fi

                mkdir -p "$_FWD_PID_DIR"
                local pidfile="$_FWD_PID_DIR/${local_port}.pid"

                # 创建隧道（后台）
                ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new \
                    -L "${local_port}:localhost:${remote_port}" \
                    -N -f \
                    "$REMOTE_USER@$_TARGET_IP" 2>/dev/null
                local pid=$!

                # 保存 PID
                echo "$pid" > "$pidfile"
                ok "隧道已建立 (PID=$pid，端口 :$local_port)"
            else
                error "不支持通过 Runner 中继进行端口转发"
            fi
            ;;
    esac
}
