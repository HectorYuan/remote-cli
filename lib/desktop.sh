#!/usr/bin/env bash
# remote-cli RustDesk 远程桌面模块

cmd_desktop() {
    load_config
    detect_rustdesk

    if [[ "$_RD_CONFIGURED" -ne 0 ]]; then
        echo "⚠️  RustDesk 未配置中继服务器"
        echo "   运行 'remote fix' 修复"
        return 1
    fi

    echo "🖥️  RustDesk 远程桌面"
    echo "   中继服务器: $_RD_SERVER"
    echo ""

    if command -v rustdesk &>/dev/null; then
        # 检查 RustDesk 是否已在运行
        if pgrep -x rustdesk &>/dev/null; then
            echo "RustDesk 已在运行"
        else
            echo "启动 RustDesk..."
            nohup rustdesk &>/dev/null &
            echo "✅ RustDesk 已启动"
        fi
        echo ""
        echo "在笔记本端输入工作站的 RustDesk ID 即可连接"
    else
        echo "❌ RustDesk 未安装"
        echo "   需要: sudo snap install rustdesk"
    fi
}
