#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  enroll.sh — 新设备一键接入
#  create: 工作站生成一次性 token（打印新设备要执行的命令）
#  join:   新设备用 token 自动完成接入（生成密钥→上传公钥→写配置）
#  sync:   工作站拉取已注册的公钥加入 authorized_keys
#
#  公钥经 Runner 中转：token 一次性、1 小时过期
# ═══════════════════════════════════════════════════════════════════

ENROLL_PORT="${ENROLL_PORT:-8100}"
ENROLL_TTL="${ENROLL_TTL:-3600}"

# Runner 上的 enroll 数据目录
_enroll_data_dir() {
    echo "/opt/remote-cli-enroll"
}

# ─── create: 工作站生成 token ──────────────────────────────────
enroll_create() {
    [[ -z "${RUNNER_IP:-}" ]] && die "未配置 RUNNER_IP"
    [[ -f "$RUNNER_KEY" ]] || die "Runner 私钥不存在: $RUNNER_KEY"

    local name="${1:-device}"
    local token
    # 128-bit 随机 token（URL 安全）
    token="RC-$(head -c 16 /dev/urandom | base64 | tr '+/' '-_' | tr -d '=\n' | head -c 22)"

    # 工作站的 Tailscale IP（新设备要用）
    local ts_ip
    ts_ip=$(get_tailscale_ip)
    [[ -z "$ts_ip" ]] && warn "Tailscale 未在线，新设备将无法通过 Tailscale 连接"

    # 写入 Runner 的 enroll 数据目录
    local payload
    payload=$(cat << EOF
{"name":"$name","created_at":$(date +%s),"expires_at":$(($(date +%s) + ENROLL_TTL)),"used":false,"config":{"REMOTE_HOST":"$ts_ip","REMOTE_USER":"$REMOTE_USER","RUNNER_IP":"$RUNNER_IP","RUNNER_USER":"$RUNNER_USER","RUSTDESK_KEY":"${RUSTDESK_KEY:-}","CODE_SERVER_PORT":"${CODE_SERVER_PORT:-8080}"}}
EOF
)
    _runner_cmd "mkdir -p $(_enroll_data_dir) && echo '$payload' > $(_enroll_data_dir)/$token.json" \
        || die "写入 Runner 失败"

    ok "已生成接入 token (1 小时内有效)"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  在新设备上执行以下命令（安装后）:"
    echo ""
    echo "    remote enroll $token"
    echo ""
    echo "  设备名: $name"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    info "提示: 工作站需运行 'remote enroll sync' 接收公钥"
    info "      可挂 systemd timer 自动同步 (remote enroll sync-install)"
}

# ─── join: 新设备接入 ─────────────────────────────────────────
enroll_join() {
    local token="${1:-}"
    [[ -z "$token" ]] && die "用法: remote enroll <token>"
    [[ ! "$token" =~ ^RC-[A-Za-z0-9_-]{16,64}$ ]] && die "token 格式错误"
    [[ -z "${RUNNER_IP:-}" ]] && die "请先在配置中设置 RUNNER_IP (编辑 $CONFIG_ENV)"

    info "开始接入 (token: $token)..."

    # 1. 拉取工作站配置（enroll 服务为纯 HTTP，token 即凭证）
    info "[1/4] 拉取工作站配置..."
    local config_json
    config_json=$(curl -fsS --max-time 10 "http://$RUNNER_IP:$ENROLL_PORT/enroll/config/$token" 2>/dev/null) \
        || die "拉取配置失败（token 无效或已过期）"

    # 解析 JSON 配置（python3 兜底，macOS 也自带）
    local ts_ip remote_user runner_ip rustdesk_key cs_port
    ts_ip=$(echo "$config_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['config'].get('REMOTE_HOST',''))")
    remote_user=$(echo "$config_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['config'].get('REMOTE_USER','hector'))")
    runner_ip=$(echo "$config_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['config'].get('RUNNER_IP',''))")
    rustdesk_key=$(echo "$config_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['config'].get('RUSTDESK_KEY',''))")
    cs_port=$(echo "$config_json" | python3 -c "import sys,json; print(json.load(sys.stdin)['config'].get('CODE_SERVER_PORT','8080'))")

    # 2. 生成 SSH 密钥（幂等）
    info "[2/4] 检查 SSH 密钥..."
    local keyfile="$HOME/.ssh/id_ed25519"
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    if [[ ! -f "$keyfile" ]]; then
        ssh-keygen -t ed25519 -f "$keyfile" -N "" -q
        ok "SSH 密钥已生成"
    else
        ok "SSH 密钥已存在"
    fi

    # 3. 上传公钥到 Runner（token 一次性）
    info "[3/4] 上传公钥..."
    local http_code
    http_code=$(curl -fsS --max-time 10 -o /dev/null -w '%{http_code}' \
        -X POST -H "Content-Type: text/plain" \
        --data-binary @"$keyfile.pub" \
        "http://$RUNNER_IP:$ENROLL_PORT/enroll/key/$token" 2>/dev/null) \
        || die "上传公钥失败"

    case "$http_code" in
        200) ok "公钥已上传" ;;
        409) die "token 已被使用（如需重新接入请让工作站重新生成 token）" ;;
        410) die "token 已过期（请让工作站重新生成）" ;;
        *)   die "上传失败 (HTTP $http_code)" ;;
    esac

    # 4. 写入本地配置
    info "[4/4] 写入本地配置..."
    mkdir -p "$CONFIG_DIR"
    {
        echo "# remote-cli 配置（remote enroll 自动生成）"
        echo "REMOTE_HOST=\"$ts_ip\""
        echo "REMOTE_USER=\"$remote_user\""
        echo "RUNNER_IP=\"$runner_ip\""
        echo "RUSTDESK_KEY=\"$rustdesk_key\""
        echo "CODE_SERVER_PORT=$cs_port"
    } > "$CONFIG_ENV"
    chmod 600 "$CONFIG_ENV"

    echo ""
    ok "接入完成！"
    echo ""
    echo "下一步:"
    echo "  1. 等待工作站执行 'remote enroll sync'（或其 systemd timer 自动执行）"
    echo "  2. 然后: remote connect"
    echo ""
    echo "工作站 Tailscale IP: $ts_ip"
}

# ─── sync: 工作站拉取公钥 ──────────────────────────────────────
enroll_sync() {
    [[ -z "${RUNNER_IP:-}" ]] && die "未配置 RUNNER_IP"

    local data_dir
    data_dir=$(_enroll_data_dir)
    local found=0

    # 找出已上传公钥但未同步的 token（兼容有无空格的 JSON 格式）
    local pending
    pending=$(_runner_cmd "grep -l '\"used\": *true' $data_dir/*.json 2>/dev/null || true") || pending=""
    [[ -z "$pending" ]] && { ok "没有待同步的设备"; return 0; }

    for json_file in $pending; do
        local token
        token=$(basename "$json_file" .json)
        local synced_marker="$data_dir/$token.synced"
        # 已同步过则跳过
        _runner_cmd "test -f $synced_marker" 2>/dev/null && continue

        local pubkey
        pubkey=$(_runner_cmd "cat $data_dir/$token.pub 2>/dev/null") || continue
        [[ -z "$pubkey" ]] && continue

        local device_name created_at
        device_name=$(_runner_cmd "grep -o '\"name\": *\"[^\"]*\"' $json_file | head -1 | sed 's/\"name\": *\"//;s/\"//'" 2>/dev/null) || device_name="unknown"
        created_at=$(_runner_cmd "grep -o '\"created_at\": *[0-9]*' $json_file | head -1 | grep -o '[0-9]*'" 2>/dev/null) || created_at="0"

        # 写入 authorized_keys（幂等）
        if ensure_authorized_key_content "$pubkey"; then
            # 打标记 + 清理过期的 token 文件
            _runner_cmd "touch $synced_marker && rm -f $json_file $data_dir/$token.pub" >/dev/null
            ok "已接入设备: $device_name ($(date -d @$created_at '+%m-%d %H:%M' 2>/dev/null || echo ''))"
            found=$((found + 1))
        fi
    done

    if [[ "$found" -eq 0 ]]; then
        ok "没有新设备"
    else
        info "共接入 $found 台设备"
    fi
}

# 幂等写入公钥（内容级去重）
ensure_authorized_key_content() {
    local pubkey="$1"
    local auth_file="$HOME/.ssh/authorized_keys"
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    [[ -f "$auth_file" ]] || touch "$auth_file"
    grep -qF "$pubkey" "$auth_file" 2>/dev/null && return 1
    echo "$pubkey" >> "$auth_file"
    return 0
}

# ─── sync-install: 挂 systemd timer 自动同步 ───────────────────
enroll_sync_install() {
    local service="/etc/systemd/system/remote-enroll-sync.service"
    local timer="/etc/systemd/system/remote-enroll-sync.timer"
    local remote_bin="$REMOTE_CLI_DIR/bin/remote"

    cat << EOF | sudo tee "$service" > /dev/null
[Unit]
Description=remote-cli enroll sync

[Service]
Type=oneshot
ExecStart=$remote_bin enroll sync
EOF

    cat << EOF | sudo tee "$timer" > /dev/null
[Unit]
Description=remote-cli enroll sync timer

[Timer]
OnCalendar=*-*-* *:*:00
Persistent=false

[Install]
WantedBy=timers.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now remote-enroll-sync.timer
    ok "enroll sync 已挂 systemd timer（每分钟自动同步）"
}

# ─── 主入口 ────────────────────────────────────────────────────
cmd_enroll() {
    local subcmd="${1:-help}"
    shift 2>/dev/null || true

    case "$subcmd" in
        create)
            enroll_create "$@"
            ;;
        sync)
            enroll_sync
            ;;
        sync-install)
            enroll_sync_install
            ;;
        join)
            enroll_join "$@"
            ;;
        help|--help|-h)
            echo "用法:"
            echo "  工作站:"
            echo "    remote enroll create [设备名]   生成一次性接入 token"
            echo "    remote enroll sync              接收新设备公钥"
            echo "    remote enroll sync-install      挂 systemd timer 自动接收"
            echo "  新设备:"
            echo "    remote enroll <RC-xxxx token>   一键接入"
            echo "    remote enroll join <token>      同上（显式）"
            ;;
        RC-*|*)
            # 直接传 token = join
            enroll_join "$subcmd"
            ;;
    esac
}
