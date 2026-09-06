#!/usr/bin/env bash
# remote-cli 状态检测模块
# 接口约定: return 0=可用, 1=不可用, 2=错误
# 所有 detect 函数内部用 || true 保护，不会因 set -e 中断

# ─── 检测 SSH 可达性 ─────────────────────────────────────────────
detect_ssh() {
    local host="${1:?host required}"
    local timeout="${2:-3}"
    _SSH_REACHABLE=1
    if timeout "$timeout" bash -c "echo >/dev/tcp/$host/22" 2>/dev/null; then
        _SSH_REACHABLE=0
    fi
    return "$_SSH_REACHABLE"
}

# ─── 检测 mosh 可用性 ────────────────────────────────────────────
detect_mosh() {
    _MOSH_AVAILABLE=1
    if command -v mosh-server &>/dev/null && command -v mosh &>/dev/null; then
        _MOSH_AVAILABLE=0
    fi
    return "$_MOSH_AVAILABLE"
}

# ─── 检测 sshd 状态 ──────────────────────────────────────────────
detect_sshd() {
    _SSHD_ACTIVE=1
    if systemctl is-active --quiet ssh.service 2>/dev/null || \
       systemctl is-active --quiet sshd.service 2>/dev/null || \
       systemctl is-active --quiet ssh.socket 2>/dev/null; then
        _SSHD_ACTIVE=0
    fi
    if [[ "$_SSHD_ACTIVE" -ne 0 ]] && ss -tlnp 2>/dev/null | grep -q ':22 '; then
        _SSHD_ACTIVE=0
    fi
    return "$_SSHD_ACTIVE"
}

# ─── 检测 Tailscale 状态 ─────────────────────────────────────────
detect_tailscale() {
    _TS_IP=""
    _TS_RUNNING=1
    _TS_IP=$(tailscale ip -4 2>/dev/null || true)
    local state
    state=$(tailscale status --json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('BackendState',''))" 2>/dev/null || true)
    if [[ "$state" == "Running" ]]; then
        _TS_RUNNING=0
    fi
    return "$_TS_RUNNING"
}

# ─── 检测 RustDesk 状态 ──────────────────────────────────────────
detect_rustdesk() {
    _RD_CONFIGURED=1
    _RD_SERVER=""
    local config="$HOME/.config/rustdesk/config2.toml"
    if [[ -f "$config" ]]; then
        _RD_SERVER=$(grep "rendezvous_server" "$config" 2>/dev/null | sed "s/.*= *'\\(.*\\)'.*/\\1/" || true)
        if [[ -n "$_RD_SERVER" ]]; then
            _RD_CONFIGURED=0
        fi
    fi
    return "$_RD_CONFIGURED"
}

# ─── 检测 code-server 状态 ───────────────────────────────────────
detect_code_server() {
    _CS_ACTIVE=1
    _CS_PORT=""
    if systemctl is-active --quiet snap.code-server.daemon 2>/dev/null; then
        _CS_ACTIVE=0
        _CS_PORT=$(grep 'bind-addr' ~/snap/code-server/*/config.yaml 2>/dev/null | grep -oP ':\K[0-9]+' | head -1 || true)
    fi
    if systemctl is-active --quiet code-server@"$USER" 2>/dev/null; then
        _CS_ACTIVE=0
        _CS_PORT="${CODE_SERVER_PORT:-8443}"
    fi
    return "$_CS_ACTIVE"
}

# ─── 检测 Runner 可达性 ──────────────────────────────────────────
detect_runner() {
    _RUNNER_REACHABLE=1
    if [[ -n "${RUNNER_IP:-}" ]]; then
        if timeout 3 bash -c "echo >/dev/tcp/$RUNNER_IP/22" 2>/dev/null; then
            _RUNNER_REACHABLE=0
        fi
    fi
    return "$_RUNNER_REACHABLE"
}

# ─── 选择最优连接目标 ────────────────────────────────────────────
detect_best_target() {
    _TARGET_IP=""
    _TARGET_SOURCE="none"

    detect_tailscale || true
    if [[ "$_TS_RUNNING" -eq 0 ]] && [[ -n "$_TS_IP" ]]; then
        detect_ssh "$_TS_IP" 3 || true
        if [[ "$_SSH_REACHABLE" -eq 0 ]]; then
            _TARGET_IP="$_TS_IP"
            _TARGET_SOURCE="tailscale"
            return 0
        fi
    fi

    detect_ssh "$LAN_IP" 2 || true
    if [[ "$_SSH_REACHABLE" -eq 0 ]]; then
        _TARGET_IP="$LAN_IP"
        _TARGET_SOURCE="lan"
        return 0
    fi

    return 1
}
