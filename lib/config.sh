#!/usr/bin/env bash
# remote-cli 配置管理
# 非敏感默认值 + 加载用户配置

# ─── 版本 ────────────────────────────────────────────────────────
REMOTE_CLI_VERSION="0.1.0"

# ─── 路径 ────────────────────────────────────────────────────────
REMOTE_CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_DIR="$HOME/.config/remote-cli"
CONFIG_ENV="$CONFIG_DIR/config.env"
BACKUP_DIR="$CONFIG_DIR/backups"

# ─── 非敏感默认值 ────────────────────────────────────────────────
LAN_IP="${REMOTE_LAN_IP:-172.16.138.50}"
MOSH_PORT_START="${REMOTE_MOSH_PORT_START:-60000}"
MOSH_PORT_END="${REMOTE_MOSH_PORT_END:-60100}"
SSH_USER="${REMOTE_SSH_USER:-hector}"
SSH_KEY="${REMOTE_SSH_KEY:-$HOME/.ssh/id_ed25519}"
ZELLIJ_LAYOUTS=("dev" "ollama-work" "writing")

# ─── 加载用户敏感配置 ────────────────────────────────────────────
load_config() {
    if [[ -f "$CONFIG_ENV" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_ENV"
    fi
    # 从环境变量补充（优先级最高）
    RUNNER_IP="${RUNNER_IP:-}"
    RUSTDESK_KEY="${RUSTDESK_KEY:-}"
    CODE_SERVER_PORT="${CODE_SERVER_PORT:-8443}"
}

# ─── 获取 Tailscale IP（动态，不缓存）────────────────────────────
get_tailscale_ip() {
    tailscale ip -4 2>/dev/null || echo ""
}

# ─── 检测 Tailscale 是否在线 ─────────────────────────────────────
is_tailscale_running() {
    local state
    state=$(tailscale status --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('BackendState',''))" 2>/dev/null)
    [[ "$state" == "Running" ]]
}
