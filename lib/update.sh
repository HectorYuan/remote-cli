#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
#  update.sh — 自更新（fetch + log）
# ═══════════════════════════════════════════════════════════

cmd_update() {
    if [[ ! -d "$REMOTE_CLI_DIR/.git" ]]; then
        die "非 git 安装，需手动更新: cd $REMOTE_CLI_DIR && git pull"
    fi
    info "检查更新..."

    local current_branch="master"
    git -C "$REMOTE_CLI_DIR" fetch --quiet origin "$current_branch" 2>/dev/null \
        || { warn "网络错误，使用 git pull"; git -C "$REMOTE_CLI_DIR" pull --ff-only && ok "已更新"; return; }

    local behind
    behind=$(git -C "$REMOTE_CLI_DIR" rev-list HEAD..origin/$current_branch --count 2>/dev/null || echo "0")

    if [[ "${behind:-0}" -eq 0 ]]; then
        ok "已是最新版本 ($REMOTE_CLI_VERSION)"
        return 0
    fi

    info "发现 $behind 个新提交:"
    echo ""
    git -C "$REMOTE_CLI_DIR" log HEAD..origin/$current_branch --oneline 2>/dev/null | head -10
    echo ""

    if [[ "${_FORCE:-0}" -eq 1 ]] || confirm "更新到最新版本？"; then
        git -C "$REMOTE_CLI_DIR" pull --ff-only && ok "已更新到 $(cat "$REMOTE_CLI_DIR/VERSION")"
    fi
}