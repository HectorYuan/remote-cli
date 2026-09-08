#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════
#  config_cmd.sh — 配置管理（show/set/get）
# ═══════════════════════════════════════════════════════════

_config_set() {
    local key="$1" value="$2"
    if [[ -z "$key" ]] || [[ -z "$value" ]]; then
        error "用法: remote config set <key> <value>"
        return 1
    fi
    # 拒绝写入 KEY/PASSWORD/SECRET/TOKEN
    if [[ "$key" =~ KEY|PASSWORD|SECRET|TOKEN ]]; then
        error "出于安全考虑，不允许直接修改敏感字段，请手动编辑 config.env"
        return 1
    fi
    if [[ -f "$CONFIG_ENV" ]] && grep -q "^${key}=" "$CONFIG_ENV" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=\"${value}\"|" "$CONFIG_ENV"
    else
        echo "${key}=\"${value}\"" >> "$CONFIG_ENV"
    fi
    ok "已设置 $key=$value"
    load_config  # 重新加载
}

_config_show() {
    echo "配置文件: $CONFIG_ENV"
    echo "版本: $REMOTE_CLI_VERSION"
    echo "平台: $RC_PLATFORM ($RC_DISTRO)"
    echo "工作目录: $REMOTE_CLI_DIR"
    echo ""
    echo "当前配置（非敏感字段）:"
    echo "  REMOTE_HOST = $REMOTE_HOST"
    echo "  REMOTE_USER = $REMOTE_USER"
    echo "  RUNNER_IP = $RUNNER_IP"
    echo "  RUNNER_USER = $RUNNER_USER"
    echo "  CODE_SERVER_PORT = $CODE_SERVER_PORT"
}

cmd_config() {
    local subcmd="${1:-show}"
    shift 2>/dev/null || true

    # 确保 detect_platform 已执行
    [[ -z "${RC_PLATFORM:-}" ]] && detect_platform

    case "$subcmd" in
        show)   _config_show ;;
        set)    _config_set "$@" ;;
        get)
            local key="${1:?需要指定 key}"
            [[ -f "$CONFIG_ENV" ]] && grep "^${key}=" "$CONFIG_ENV" || echo "(未配置)"
            ;;
        edit)
            "${EDITOR:-nano}" "$CONFIG_ENV"
            ;;
        *)
            echo "用法: remote config [show|set <k> <v>|get <k>|edit]"
            ;;
    esac
}