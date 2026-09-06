#!/usr/bin/env bash
# remote-cli 连接模块
# 自动选择最优路径（Tailscale > LAN）+ 协议（Mosh > SSH）+ Zellij attach

cmd_connect() {
    local host="${1:-}"
    local target_ip=""
    local target_source=""
    local method="ssh"

    if [[ -n "$host" ]]; then
        # 指定了 host，直接连
        target_ip="$host"
        target_source="manual"
    else
        # 自动选路
        detect_best_target
        if [[ -z "$_TARGET_IP" ]]; then
            echo "❌ 无法连接工作站"
            echo "   - Tailscale: $(_TS_RUNNING && echo "在线 $_TS_IP" || echo "离线")"
            echo "   - 局域网: $LAN_IP 不可达"
            echo ""
            echo "请检查网络或运行: sudo tailscale up"
            return 1
        fi
        target_ip="$_TARGET_IP"
        target_source="$_TARGET_SOURCE"
    fi

    # 选择协议
    detect_mosh
    if [[ "$_MOSH_AVAILABLE" -eq 0 ]]; then
        method="mosh"
    fi

    # 显示连接信息
    echo "🔗 连接工作站 ($target_source)"
    echo "   目标: $SSH_USER@$target_ip"
    echo "   协议: $method"

    # 执行连接
    if [[ "$method" == "mosh" ]]; then
        mosh --ssh="ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new" \
             "$SSH_USER@$target_ip"
    else
        ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new \
            -o ServerAliveInterval=60 -o ServerAliveCountMax=3 \
            "$SSH_USER@$target_ip"
    fi
}
