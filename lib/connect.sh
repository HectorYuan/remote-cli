#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  connect.sh — 连接工作站终端
#  支持: --mosh (强制 mosh) --ssh (强制 ssh) --dry-run (只显示路径)
# ═══════════════════════════════════════════════════════════════════

cmd_connect() {
    local host="" method="auto" dry_run=0

    # 解析参数
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --mosh)    method="mosh"; shift ;;
            --ssh)     method="ssh"; shift ;;
            --dry-run) dry_run=1; shift ;;
            -*)        error "未知选项: $1"; return 1 ;;
            *)         host="$1"; shift ;;
        esac
    done

    local target_ip="" target_source=""

    if [[ -n "$host" ]]; then
        target_ip="$host"
        target_source="manual"
    else
        detect_best_target || true
        if [[ -z "$_TARGET_IP" ]]; then
            error "无法连接工作站"
            error "  Tailscale: $(is_tailscale_running && echo "在线 $(get_tailscale_ip)" || echo "离线")"
            error "  局域网: $LAN_IP 不可达"
            error ""
            error "请检查网络或运行: sudo tailscale up"
            return 1
        fi
        target_ip="$_TARGET_IP"
        target_source="$_TARGET_SOURCE"
    fi

    # 选择协议
    if [[ "$method" == "auto" ]]; then
        detect_mosh && method="mosh" || method="ssh"
    fi

    # dry-run 模式
    if [[ "$dry_run" -eq 1 ]]; then
        info "连接路径:"
        echo "  目标: $REMOTE_USER@$target_ip"
        echo "  来源: $target_source"
        echo "  协议: $method"
        echo "  SSH密钥: $SSH_KEY"
        return 0
    fi

    info "🔗 连接工作站 ($target_source)"

    if [[ "$method" == "mosh" ]]; then
        mosh --ssh="ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new" \
             "$REMOTE_USER@$target_ip"
    else
        ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new \
            -o ServerAliveInterval=60 -o ServerAliveCountMax=3 \
            "$REMOTE_USER@$target_ip"
    fi
}
