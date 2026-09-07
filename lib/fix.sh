#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  fix.sh — 诊断+修复
#  支持: --dry-run (只打印) --auto (非交互式修复)
#  v0.1.x 保留简单 eval 逻辑，v0.2.x 改为显式函数
# ═══════════════════════════════════════════════════════════════════

cmd_fix() {
    local dry_run=0 auto=0
    for arg in "$@"; do
        case "$arg" in
            --dry-run) dry_run=1 ;;
            --auto) auto=1 ;;
        esac
    done

    local issues=()
    local fixes=()

    # ─── 检测问题 ─────────────────────────────────────────────
    detect_sshd
    if [[ "$_SSHD_ACTIVE" -ne 0 ]]; then
        issues+=("sshd 未运行")
        fixes+=("sudo systemctl enable --now ssh")
    fi

    if [[ ! -f "$HOME/.ssh/authorized_keys" ]] || [[ ! -s "$HOME/.ssh/authorized_keys" ]]; then
        if [[ -f "$SSH_KEY.pub" ]]; then
            issues+=("authorized_keys 为空")
            fixes+=("ensure_authorized_key '$SSH_KEY.pub'")
        fi
    fi

    if [[ ! -f /etc/ssh/sshd_config.d/hardened.conf ]]; then
        issues+=("SSH 未加固 (无 hardened.conf)")
        fixes+=("sudo bash -c 'cat > /etc/ssh/sshd_config.d/hardened.conf << SSHEOF
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin prohibit-password
MaxAuthTries 3
LoginGraceTime 30
ClientAliveInterval 60
ClientAliveCountMax 3
SSHEOF'")
    fi

    detect_rustdesk
    local rd_config="$HOME/.config/rustdesk/RustDesk2.toml"
    if [[ -f "$rd_config" ]]; then
        local rd2_server
        rd2_server=$(grep "rendezvous_server" "$rd_config" 2>/dev/null | sed "s/.*= *'\\(.*\\)'.*/\\1/")
        if [[ "$rd2_server" == *"rustdesk.com"* ]]; then
            issues+=("RustDesk2.toml 指向官方服务器 (应指向 Runner)")
            fixes+=("sed -i \"s|rendezvous_server = '.*'|rendezvous_server = '$RUNNER_IP:21116'|\" '$rd_config'")
        fi
    fi

    detect_code_server
    if [[ "$_CS_ACTIVE" -ne 0 ]]; then
        issues+=("code-server 未运行")
        fixes+=("sudo systemctl enable --now code-server@$(whoami)")
    fi

    # ─── 输出诊断结果 ─────────────────────────────────────────
    if [[ ${#issues[@]} -eq 0 ]]; then
        ok "未发现问题"
        return 0
    fi

    echo ""
    warn "发现 ${#issues[@]} 个问题:"
    echo ""
    for i in "${!issues[@]}"; do
        printf "  %d. %s\n" $((i+1)) "${issues[$i]}"
        printf "     修复: %s\n" "${fixes[$i]}"
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

    for i in "${!issues[@]}"; do
        echo ""
        info "修复: ${issues[$i]}"
        eval "${fixes[$i]}" 2>&1 || warn "修复失败: ${issues[$i]}"
    done

    echo ""
    ok "修复完成"
}
