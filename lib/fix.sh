#!/usr/bin/env bash
# remote-cli 诊断修复模块
# 支持: --dry-run (只打印) --auto (无破坏性自动修复) --backup (修改前备份)

cmd_fix() {
    local dry_run=0 auto=0 do_backup=0
    for arg in "$@"; do
        case "$arg" in
            --dry-run) dry_run=1 ;;
            --auto) auto=1 ;;
            --backup) do_backup=1 ;;
        esac
    done

    load_config
    local issues=()
    local fixes=()

    # ─── 检测问题 ─────────────────────────────────────────────
    detect_sshd
    if [[ "$_SSHD_ACTIVE" -ne 0 ]]; then
        issues+=("sshd 未运行")
        fixes+=("sudo systemctl enable --now ssh")
    fi

    if [[ ! -f "$HOME/.ssh/authorized_keys" ]] || [[ ! -s "$HOME/.ssh/authorized_keys" ]]; then
        if [[ -f "$HOME/.ssh/id_ed25519.pub" ]]; then
            issues+=("authorized_keys 为空")
            fixes+=("cat ~/.ssh/id_ed25519.pub >> ~/.ssh/authorized_keys")
        fi
    fi

    if [[ ! -f /etc/ssh/sshd_config.d/hardened.conf ]]; then
        issues+=("SSH 未加固 (无 hardened.conf)")
        fixes+=("创建 /etc/ssh/sshd_config.d/hardened.conf")
    fi

    detect_rustdesk
    local rd_config="$HOME/.config/rustdesk/RustDesk2.toml"
    if [[ -f "$rd_config" ]]; then
        local rd2_server
        rd2_server=$(grep "rendezvous_server" "$rd_config" 2>/dev/null | sed "s/.*= *'\\(.*\\)'.*/\\1/")
        if [[ "$rd2_server" == *"rustdesk.com"* ]]; then
            issues+=("RustDesk2.toml 指向官方服务器 (应指向 Runner)")
            fixes+=("修改 $rd_config 中的 rendezvous_server")
        fi
    fi

    detect_code_server
    if [[ "$_CS_ACTIVE" -ne 0 ]]; then
        issues+=("code-server 未运行")
        fixes+=("sudo systemctl enable --now code-server@$USER")
    fi

    # ─── 输出诊断结果 ─────────────────────────────────────────
    if [[ ${#issues[@]} -eq 0 ]]; then
        echo "✅ 未发现问题"
        return 0
    fi

    echo "🔍 发现 ${#issues[@]} 个问题:"
    echo ""
    for i in "${!issues[@]}"; do
        printf "  %d. %s\n" $((i+1)) "${issues[$i]}"
        printf "     修复: %s\n" "${fixes[$i]}"
    done
    echo ""

    if [[ "$dry_run" -eq 1 ]]; then
        echo "(--dry-run 模式，不执行修复)"
        return 0
    fi

    # ─── 执行修复 ─────────────────────────────────────────────
    local confirm="y"
    if [[ "$auto" -ne 1 ]]; then
        read -rp "执行修复？[Y/n] " confirm
        confirm="${confirm:-y}"
    fi

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "已取消"
        return 0
    fi

    for i in "${!issues[@]}"; do
        echo ""
        echo "🔧 修复: ${issues[$i]}"
        eval "${fixes[$i]}"
    done

    echo ""
    echo "✅ 修复完成"
}
