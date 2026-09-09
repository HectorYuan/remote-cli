#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  config.sh — 配置管理
#  三层优先级：内置默认值 → config.env → 环境变量（最高）
#  所有硬编码值已消除，统一走配置体系
# ═══════════════════════════════════════════════════════════════════

CONFIG_VERSION_EXPECTED=1
CONFIG_DIR="$HOME/.config/remote-cli"
CONFIG_ENV="$CONFIG_DIR/config.env"
BACKUP_DIR="$CONFIG_DIR/backups"

# ─── 内置默认值（不可变）──────────────────────────────────────
_defaults() {
    : "${REMOTE_HOST:=}"                                              # 远程工作站 Tailscale IP 或主机名
    : "${REMOTE_USER:=hector}"                                        # SSH 用户名
    : "${SSH_KEY:=$HOME/.ssh/id_ed25519}"                             # 本地 SSH 私钥
    : "${LAN_IP:=172.16.138.50}"                                      # 局域网 IP
    : "${MOSH_PORT_START:=60000}"                                     # Mosh UDP 端口起始
    : "${MOSH_PORT_END:=60100}"                                       # Mosh UDP 端口结束
    : "${RUNNER_IP:=}"                                                # Runner 中继 IP
    : "${RUNNER_USER:=root}"                                          # Runner SSH 用户
    : "${RUNNER_KEY:=$HOME/.ssh/neorun.pem}"                          # Runner SSH 私钥
    : "${RUSTDESK_KEY:=}"                                             # RustDesk 中继公钥
    : "${CODE_SERVER_PORT:=8080}"                                     # code-server 端口
    : "${CONFIG_VERSION:=0}"                                          # 配置版本号
}

# ─── 加载配置 ──────────────────────────────────────────────────
load_config() {
    # 1. 设内置默认值
    _defaults

    # 2. 加载 config.env（覆盖默认值）
    if [[ -f "$CONFIG_ENV" ]]; then
        # shellcheck source=/dev/null
        source "$CONFIG_ENV"
    fi

    # 3. 环境变量已在 _defaults 中通过 := 语法处理（不覆盖已有值）
    #    但用户如果显式 export 了变量，bash 的 := 语义是：
    #    如果变量未设置或为空字符串，则设置为默认值
    #    所以用户 export RUNNER_IP=xxx 时，:= 不会覆盖它 — 这正是我们想要的

    # 4. 展开 ~ 路径（bash source 不展开变量值中的 tilde）
    SSH_KEY="${SSH_KEY/#\~/$HOME}"
    RUNNER_KEY="${RUNNER_KEY/#\~/$HOME}"

    # 5. CONFIG_VERSION 迁移检查
    if [[ "$CONFIG_VERSION" -lt "$CONFIG_VERSION_EXPECTED" ]]; then
        _migrate_config "$CONFIG_VERSION" "$CONFIG_VERSION_EXPECTED"
    fi
}

# ─── 配置迁移（幂等）──────────────────────────────────────────
_migrate_config() {
    local from="$1" to="$2"
    info "配置迁移: v${from} -> v${to}"

    # 备份旧配置
    [[ -f "$CONFIG_ENV" ]] && cp "$CONFIG_ENV" "$CONFIG_ENV.bak.${from}"

    # 增量追加缺失字段
    _append_if_missing "CONFIG_VERSION" "$to"

    ok "配置已迁移到 v${to}"
}

_append_if_missing() {
    local key="$1" default="$2"
    # 目录不存在时静默跳过（干净 CI 环境没有配置目录）
    [[ -d "$CONFIG_DIR" ]] || return 0
    if ! grep -q "^${key}=" "$CONFIG_ENV" 2>/dev/null; then
        echo "${key}=${default}" >> "$CONFIG_ENV" 2>/dev/null || true
        info "已添加 ${key}=${default}"
    fi
}

# ─── 初始化（首次 setup 时调用）────────────────────────────────
init_config() {
    mkdir -p "$CONFIG_DIR"
    if [[ ! -f "$CONFIG_ENV" ]]; then
        cat > "$CONFIG_ENV" << 'EOF'
# remote-cli 敏感配置（不要提交到 git）
# ─── 远程工作站 ──────────────────────────
REMOTE_HOST=""                    # 工作站 Tailscale IP 或局域网 IP
REMOTE_USER="hector"              # SSH 用户名
# ─── Runner 中继服务器 ──────────────────
RUNNER_IP=""                      # Runner 公网 IP（用于 RustDesk 中继）
RUNNER_USER="root"                # Runner SSH 用户名
RUNNER_KEY="~/.ssh/neorun.pem"    # Runner SSH 私钥路径
RUSTDESK_KEY=""                   # RustDesk 中继公钥
# ─── 服务配置 ──────────────────────────
CODE_SERVER_PORT=8080             # code-server 端口
EOF
        chmod 600 "$CONFIG_ENV"
    fi
}
