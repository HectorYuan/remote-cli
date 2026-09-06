#!/usr/bin/env bash
# remote-cli 首次部署模块

cmd_setup() {
    echo "🚀 Remote CLI 首次部署"
    echo ""

    # 1. 创建配置目录
    mkdir -p "$CONFIG_DIR"
    if [[ ! -f "$CONFIG_ENV" ]]; then
        cat > "$CONFIG_ENV" << 'EOF'
# Remote CLI 敏感配置（不要提交到 git）
RUNNER_IP="14.103.46.178"
RUSTDESK_KEY=""
CODE_SERVER_PORT="8443"
EOF
        chmod 600 "$CONFIG_ENV"
        echo "✅ 配置目录已创建: $CONFIG_DIR"
        echo "   请编辑 $CONFIG_ENV 填入 RUSTDESK_KEY"
    else
        echo "✅ 配置已存在: $CONFIG_ENV"
    fi

    # 2. 检查依赖
    echo ""
    echo "检查依赖..."
    local missing=()
    for cmd in ssh mosh tailscale rustdesk zellij; do
        if command -v "$cmd" &>/dev/null; then
            echo "  ✅ $cmd"
        else
            echo "  ❌ $cmd (未安装)"
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo ""
        echo "缺少以下工具，运行安装脚本:"
        echo "  sudo bash $REMOTE_CLI_DIR/setup/install.sh"
    fi

    # 3. 检查服务状态
    echo ""
    echo "服务状态:"
    cmd_status
}
