#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  detect.sh — 状态检测
#  所有 detect_* 函数通过 common.sh 的 is_service_active 做跨平台适配
#  接口约定：return 0=正常, 1=异常/不可用
#  结果通过全局变量 _* 传递（过渡方案，v0.2.x 改为函数返回值）
# ═══════════════════════════════════════════════════════════════════

# ─── 检测 SSH 服务状态 ─────────────────────────────────────────
detect_sshd() {
    _SSHD_ACTIVE=1
    # 优先检查 sshd.service / ssh.service / ssh.socket
    if is_service_active ssh 2>/dev/null || \
       is_service_active sshd 2>/dev/null || \
       is_service_active ssh.socket 2>/dev/null; then
        _SSHD_ACTIVE=0
    fi
    # 兜底：检查端口 22 是否在监听
    if [[ "$_SSHD_ACTIVE" -ne 0 ]]; then
        ss -tlnp 2>/dev/null | grep -q ':22 ' && _SSHD_ACTIVE=0
    fi
    return "$_SSHD_ACTIVE"
}

# ─── 检测 mosh 可用性 ─────────────────────────────────────────
detect_mosh() {
    _MOSH_AVAILABLE=1
    command -v mosh-server &>/dev/null && command -v mosh &>/dev/null && _MOSH_AVAILABLE=0
    return "$_MOSH_AVAILABLE"
}

# ─── 检测 Tailscale 状态 ──────────────────────────────────────
detect_tailscale() {
    _TS_IP=""
    _TS_RUNNING=1
    _TS_IP=$(get_tailscale_ip)
    is_tailscale_running && _TS_RUNNING=0
    return "$_TS_RUNNING"
}

# ─── 检测 RustDesk 配置 ──────────────────────────────────────
detect_rustdesk() {
    _RD_CONFIGURED=1
    _RD_SERVER=""
    local config="$HOME/.config/rustdesk/config2.toml"
    if [[ -f "$config" ]]; then
        _RD_SERVER=$(grep "rendezvous_server" "$config" 2>/dev/null | sed "s/.*= *'\\(.*\\)'.*/\\1/" || true)
        [[ -n "$_RD_SERVER" ]] && _RD_CONFIGURED=0
    fi
    return "$_RD_CONFIGURED"
}

# ─── 检测 code-server 状态 ────────────────────────────────────
detect_code_server() {
    _CS_ACTIVE=1
    _CS_PORT=""
    if is_service_active snap.code-server.daemon 2>/dev/null; then
        _CS_ACTIVE=0
        _CS_PORT=$(grep 'bind-addr' ~/snap/code-server/*/config.yaml 2>/dev/null | grep -oP ':\K[0-9]+' | head -1 || true)
    fi
    if is_service_active "code-server@$USER" 2>/dev/null; then
        _CS_ACTIVE=0
        _CS_PORT="${CODE_SERVER_PORT:-8080}"
    fi
    return "$_CS_ACTIVE"
}

# ─── 检测 Runner 可达性 ──────────────────────────────────────
detect_runner() {
    _RUNNER_REACHABLE=1
    if [[ -n "${RUNNER_IP:-}" ]]; then
        check_port "$RUNNER_IP" 3 && _RUNNER_REACHABLE=0
    fi
    return "$_RUNNER_REACHABLE"
}

# ─── 检测依赖安装 ─────────────────────────────────────────────
detect_deps() {
    _DEPS_SSH=$(command -v ssh &>/dev/null && echo 1 || echo 0)
    _DEPS_MOSH=$(command -v mosh &>/dev/null && echo 1 || echo 0)
    _DEPS_TAILSCALE=$(command -v tailscale &>/dev/null && echo 1 || echo 0)
    _DEPS_RUSTDESK=$(command -v rustdesk &>/dev/null && echo 1 || echo 0)
    _DEPS_ZELLIJ=$(command -v zellij &>/dev/null && echo 1 || echo 0)
}

# ─── 汇总所有检测结果 ────────────────────────────────────────
detect_all() {
    detect_sshd
    detect_mosh
    detect_tailscale
    detect_rustdesk
    detect_code_server
    detect_runner
    detect_deps
}

# ─── 选择最优连接目标 ─────────────────────────────────────────
# 结果: _TARGET_IP (string), _TARGET_SOURCE ("tailscale"/"lan"/"none")
detect_best_target() {
    _TARGET_IP=""
    _TARGET_SOURCE="none"

    # 如果配置了 REMOTE_HOST，优先使用
    if [[ -n "${REMOTE_HOST:-}" ]]; then
        if check_port "$REMOTE_HOST" 3; then
            _TARGET_IP="$REMOTE_HOST"
            _TARGET_SOURCE="config"
            return 0
        fi
    fi

    # L1: Tailscale
    detect_tailscale || true
    if [[ "$_TS_RUNNING" -eq 0 ]] && [[ -n "$_TS_IP" ]]; then
        check_port "$_TS_IP" 3 && { _TARGET_IP="$_TS_IP"; _TARGET_SOURCE="tailscale"; return 0; }
    fi

    # L2: 局域网
    check_port "$LAN_IP" 2 && { _TARGET_IP="$LAN_IP"; _TARGET_SOURCE="lan"; return 0; }

    return 1
}
