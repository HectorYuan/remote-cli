#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  fix.sh — 诊断+修复（v0.1.2 重写：消除 eval，显式函数）
#  支持: --dry-run --auto --backup
# ═══════════════════════════════════════════════════════════════════

# ─── 修复函数注册表 ────────────────────────────────────────────
# 格式: "函数名|描述|是否需要 sudo|检查函数"
declare -a _FIX_REGISTRY=(
    "fix_sshd_start|sshd 未运行|yes|check_sshd"
    "fix_authorized_keys|authorized_keys 为空|no|check_authorized_keys"
    "fix_hardened_conf|SSH 未加固 (无 hardened.conf)|yes|check_hardened_conf"
    "fix_rustdesk_config|RustDesk2.toml 指向官方服务器|no|check_rustdesk_config"
    "fix_code_server|code-server 未运行|yes|check_code_server"
)

# ─── 检查函数（每个返回 0=有问题需修复, 1=已正常）─────────────
check_sshd() {
    detect_sshd; [[ "$_SSHD_ACTIVE" -ne 0 ]]
}

check_authorized_keys() {
    [[ ! -f "$HOME/.ssh/authorized_keys" ]] || [[ ! -s "$HOME/.ssh/authorized_keys" ]]
}

check_hardened_conf() {
    [[ ! -f /etc/ssh/sshd_config.d/hardened.conf ]]
}

check_rustdesk_config() {
    local config="$HOME/.config/rustdesk/RustDesk2.toml"
    [[ -f "$config" ]] && grep -q "rustdesk.com" "$config" 2>/dev/null
}

check_code_server() {
    detect_code_server; [[ "$_CS_ACTIVE" -ne 0 ]]
}

# ─── 修复函数（每个都幂等：已是目标状态则跳过）───────────────
fix_sshd_start() {
    if is_service_active ssh 2>/dev/null; then
        return 0  # 已运行
    fi
    if [[ "${_BACKUP:-0}" -eq 1 ]]; then
        info "备份 sshd 配置..."
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%s) 2>/dev/null || true
    fi
    sudo systemctl enable --now ssh 2>/dev/null && ok "sshd 已启动" || warn "sshd 启动失败"
}

fix_authorized_keys() {
    if [[ -f "$HOME/.ssh/authorized_keys" ]] && [[ -s "$HOME/.ssh/authorized_keys" ]]; then
        return 0  # 已有公钥
    fi
    if [[ -f "$SSH_KEY.pub" ]]; then
        ensure_authorized_key "$SSH_KEY.pub"
        ok "公钥已写入 authorized_keys"
    else
        warn "未找到公钥文件: ${SSH_KEY}.pub"
    fi
}

fix_hardened_conf() {
    local conf="/etc/ssh/sshd_config.d/hardened.conf"
    if [[ -f "$conf" ]]; then
        return 0  # 已存在
    fi
    local content
    content=$(cat << 'SSHEOF'
# Hardened SSH config (managed by remote-cli)
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin prohibit-password
MaxAuthTries 3
LoginGraceTime 30
ClientAliveInterval 60
ClientAliveCountMax 3
SSHEOF
)
    if [[ "${_BACKUP:-0}" -eq 1 ]]; then
        info "备份 sshd 配置..."
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak.$(date +%s) 2>/dev/null || true
    fi
    sudo bash -c "cat > '$conf'" <<< "$content" && ok "hardened.conf 已创建" || warn "写入失败"
}

fix_rustdesk_config() {
    local config="$HOME/.config/rustdesk/RustDesk2.toml"
    [[ ! -f "$config" ]] && return 0
    local current
    current=$(grep "rendezvous_server" "$config" 2>/dev/null | sed "s/.*= *'\\(.*\\)'.*/\\1/")
    [[ "$current" != *"rustdesk.com"* ]] && return 0  # 已指向 Runner

    local target="${RUNNER_IP:-}"
    [[ -z "$target" ]] && { warn "未配置 RUNNER_IP，跳过"; return 0; }

    if [[ "${_BACKUP:-0}" -eq 1 ]]; then
        cp "$config" "$config.bak.$(date +%s)" 2>/dev/null || true
    fi
    sed -i "s|rendezvous_server = '.*'|rendezvous_server = '$target:21116'|" "$config"
    ok "RustDesk2.toml 已指向 $target:21116"
}

fix_code_server() {
    if is_service_active "snap.code-server.daemon" 2>/dev/null || \
       is_service_active "code-server@$USER" 2>/dev/null; then
        return 0  # 已运行
    fi
    sudo systemctl enable --now "code-server@$USER" 2>/dev/null && ok "code-server 已启动" || warn "code-server 启动失败"
}

# ─── 主入口 ────────────────────────────────────────────────────
cmd_fix() {
    local dry_run=0 auto=0
    for arg in "$@"; do
        case "$arg" in
            --dry-run) dry_run=1 ;;
            --auto)    auto=1 ;;
            --backup)  _BACKUP=1 ;;
        esac
    done

    local issues=()
    local check_funcs=()
    local fix_funcs=()
    local need_sudo=()

    # ─── 检测阶段 ─────────────────────────────────────────────
    for entry in "${_FIX_REGISTRY[@]}"; do
        IFS='|' read -r fix_fn desc sudo_flag check_fn <<< "$entry"
        if "$check_fn" 2>/dev/null; then
            issues+=("$desc")
            check_funcs+=("$check_fn")
            fix_funcs+=("$fix_fn")
            need_sudo+=("$sudo_flag")
        fi
    done

    # ─── sudo 可用性检测 ────────────────────────────────────────
    local _has_sudo=0
    sudo -n true 2>/dev/null && _has_sudo=1

    # ─── 输出诊断 ─────────────────────────────────────────────
    if [[ ${#issues[@]} -eq 0 ]]; then
        ok "未发现问题"
        return 0
    fi

    echo ""
    warn "发现 ${#issues[@]} 个问题:"
    echo ""
    for i in "${!issues[@]}"; do
        local sudo_hint=""
        [[ "${need_sudo[$i]}" == "yes" ]] && sudo_hint=" (需要 sudo)"
        printf "  %d. %s%s\n" $((i+1)) "${issues[$i]}" "$sudo_hint"
    done
    echo ""

    if [[ "$dry_run" -eq 1 ]]; then
        info "(--dry-run 模式，不执行修复)"
        return 0
    fi

    # ─── 执行修复 ─────────────────────────────────────────────
    if [[ "$auto" -ne 1 ]]; then
        confirm "执行修复？" || { info "已取消"; return 0; }
    fi

    for i in "${!fix_funcs[@]}"; do
        echo ""
        if [[ "${need_sudo[$i]}" == "yes" ]] && [[ "$_has_sudo" -ne 1 ]]; then
            warn "需要 sudo 权限，跳过: ${issues[$i]}"
            continue
        fi
        info "修复: ${issues[$i]}"
        # 审计日志
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${issues[$i]} → ${fix_funcs[$i]}" >> "$CONFIG_DIR/audit.log" 2>/dev/null || true
        "${fix_funcs[$i]}" 2>&1 || warn "修复失败: ${issues[$i]}"
    done

    echo ""
    ok "修复完成"
}
