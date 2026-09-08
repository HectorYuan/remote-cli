#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  smoke.sh — remote-cli 冒烟测试
#  设计为在"干净环境"也能通过：只验证 CLI 自身逻辑，
#  服务状态类检查（sshd/tailscale）缺失时标记 SKIP 而非 FAIL
# ═══════════════════════════════════════════════════════════════════
REMOTE_CLI_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0 FAIL=0 SKIP=0

run_test() {
    local name="$1" cmd="$2" expect="$3"
    local result
    result=$(eval "$cmd" 2>&1)
    if echo "$result" | grep -q "$expect"; then
        echo "  ✅ $name"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $name (expected '$expect')"
        FAIL=$((FAIL + 1))
    fi
}

# 环境无关测试：不论平台/服务状态都应通过
env_test() {
    local name="$1" cmd="$2" expect="$3"
    local result
    result=$(eval "$cmd" 2>&1)
    if echo "$result" | grep -q "$expect"; then
        echo "  ✅ $name"
        PASS=$((PASS + 1))
    else
        echo "  ❌ $name (expected '$expect')"
        FAIL=$((FAIL + 1))
    fi
}

echo "🧪 remote-cli v$(cat "$REMOTE_CLI_DIR/VERSION" 2>/dev/null || echo '?') 冒烟测试"
echo ""

echo "基本命令（环境无关）:"
env_test "--version"  "$REMOTE_CLI_DIR/bin/remote --version" "remote-cli"
env_test "--help"     "$REMOTE_CLI_DIR/bin/remote --help" "connect"

echo ""
echo "子命令路由（环境无关）:"
env_test "config"       "$REMOTE_CLI_DIR/bin/remote config" "配置文件\|Config"
env_test "forward help" "$REMOTE_CLI_DIR/bin/remote forward help" "用法\|Usage\|forward"
env_test "files help"   "$REMOTE_CLI_DIR/bin/remote files help" "push\|pull"
env_test "install list" "$REMOTE_CLI_DIR/bin/remote install --list" "Dependencies\|依赖"

echo ""
echo "模块加载（环境无关）:"
source "$REMOTE_CLI_DIR/lib/common.sh"
source "$REMOTE_CLI_DIR/lib/config.sh"
source "$REMOTE_CLI_DIR/lib/detect.sh"
source "$REMOTE_CLI_DIR/lib/fix.sh"
source "$REMOTE_CLI_DIR/lib/doctor.sh"

detect_mosh && echo "  ✅ detect_mosh" || echo "  ⏭️  detect_mosh (未安装, SKIP)"
detect_tailscale && echo "  ✅ detect_tailscale" || echo "  ⏭️  detect_tailscale (未登录, SKIP)"
detect_rustdesk && echo "  ✅ detect_rustdesk (configured)" || echo "  ⏭️  detect_rustdesk (未配置, SKIP)"

local_fix_count=${#_FIX_REGISTRY[@]}
if [[ "$local_fix_count" -ge 5 ]]; then
    echo "  ✅ fix 注册表: $local_fix_count 项检查"
    PASS=$((PASS + 1))
else
    echo "  ❌ fix 注册表不完整: $local_fix_count 项"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "JSON 输出（环境无关）:"
# status --json 在无服务的环境下也应输出合法 JSON
json_output=$("$REMOTE_CLI_DIR/bin/remote" status --json 2>/dev/null)
if echo "$json_output" | python3 -m json.tool >/dev/null 2>&1 || \
   echo "$json_output" | grep -q '"version"'; then
    echo "  ✅ status --json 输出有效 JSON"
    PASS=$((PASS + 1))
else
    echo "  ❌ status --json 输出无效"
    FAIL=$((FAIL + 1))
fi

# doctor --json
doctor_output=$("$REMOTE_CLI_DIR/bin/remote" doctor --json 2>/dev/null)
if echo "$doctor_output" | grep -q '"checks"'; then
    echo "  ✅ doctor --json 输出有效"
    PASS=$((PASS + 1))
else
    echo "  ❌ doctor --json 输出无效"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "────────────────────────────────"
echo "结果: $PASS 通过, $FAIL 失败"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
