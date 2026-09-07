#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  files.sh — 文件传输（push/pull/list）
#  优先 rsync，fallback scp
#  v0.2.1: 消除 eval，用数组处理含空格路径
# ═══════════════════════════════════════════════════════════════════

_files_target() {
    detect_best_target || { error "无法连接工作站"; return 1; }
    [[ -z "$_TARGET_IP" ]] && { error "未找到连接目标"; return 1; }
}

_files_transfer() {
    local direction="$1" src="$2" dst="$3"

    if command -v rsync &>/dev/null; then
        local -a rsync_opts=(-avz --progress -e "ssh -i $SSH_KEY -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10")
        if [[ "$direction" == "push" ]]; then
            "${rsync_opts[@]}" "$src" "$REMOTE_USER@$_TARGET_IP:$dst"
        else
            "${rsync_opts[@]}" "$REMOTE_USER@$_TARGET_IP:$dst" "$src"
        fi
    else
        local -a scp_opts=(-r -i "$SSH_KEY" -o "StrictHostKeyChecking=accept-new" -o "ConnectTimeout=10")
        if [[ "$direction" == "push" ]]; then
            scp "${scp_opts[@]}" "$src" "$REMOTE_USER@$_TARGET_IP:$dst"
        else
            scp "${scp_opts[@]}" "$REMOTE_USER@$_TARGET_IP:$dst" "$src"
        fi
    fi
}

cmd_files() {
    local subcmd="${1:-help}"
    shift 2>/dev/null || true

    case "$subcmd" in
        push)
            local local_path="${1:?需要指定本地文件}"
            local remote_path="${2:-$(basename "$local_path")}"
            [[ ! -e "$local_path" ]] && { error "文件不存在: $local_path"; return 1; }
            _files_target || return 1
            info "📤 上传: $local_path → $_TARGET_IP:$remote_path"
            _files_transfer push "$local_path" "$remote_path" && ok "上传完成" || error "上传失败"
            ;;
        pull)
            local remote_path="${1:?需要指定远程文件}"
            local local_path="${2:-$(basename "$remote_path")}"
            _files_target || return 1
            info "📥 下载: $_TARGET_IP:$remote_path → $local_path"
            _files_transfer pull "$local_path" "$remote_path" && ok "下载完成" || error "下载失败"
            ;;
        list)
            local remote_path="${1:-.}"
            _files_target || return 1
            info "📂 远程目录: $remote_path"
            ssh -i "$SSH_KEY" -o StrictHostKeyChecking=accept-new \
                "$REMOTE_USER@$_TARGET_IP" "ls -la \"$remote_path\"" 2>/dev/null
            ;;
        help|--help|-h)
            echo "用法:"
            echo "  remote files push <local_path> [remote_path]    上传文件"
            echo "  remote files pull <remote_path> [local_path]    下载文件"
            echo "  remote files list [remote_path]                 远程目录列表"
            ;;
        *)
            error "未知子命令: $subcmd"
            cmd_files help
            ;;
    esac
}
