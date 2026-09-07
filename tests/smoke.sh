#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  smoke.sh — remote-cli 冒烟测试
# ═══════════════════════════════════════════════════════════════════
REMOTE_CLI_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0 FAIL=0

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

echo "🧪 remote-cli v$(cat "$REMOTE_CLI_DIR/VERSION" 2>/dev/null || echo '?') 冒烟测试"
echo ""

echo "基本命令:"
run_test "--version"  "$REMOTE_CLI_DIR/bin/remote --version" "remote-cli"
run_test "--help"     "$REMOTE_CLI_DIR/bin/remote --help" "用法"

echo ""
echo "子命令路由:"
run_test "config"       "$REMOTE_CLI_DIR/bin/remote config" "配置文件"
run_test "forward help" "$REMOTE_CLI_DIR/bin/remote forward help" "用法"

echo ""
echo "模块加载:"
source "$REMOTE_CLI_DIR/lib/common.sh"
source "$REMOTE_CLI_DIR/lib/config.sh"
load_config
source "$REMOTE_CLI_DIR/lib/detect.sh"

detect_sshd && echo "  ✅ detect_sshd (active)" || echo "  ⚠️  detect_sshd (inactive, 可能 sshd 未运行)"
detect_mosh && echo "  ✅ detect_mosh" || echo "  ⚠️  detect_mosh (未安装)"
detect_tailscale && echo "  ✅ detect_tailscale" || echo "  ⚠️  detect_tailscale (未登录)"
detect_rustdesk && echo "  ✅ detect_rustdesk (configured)" || echo "  ⚠️  detect_rustdesk (未配置)"

echo ""
echo "惰性加载测试:"
# 验证 status --json 能输出有效 JSON
json_output=$($REMOTE_CLI_DIR/bin/remote status --json 2>/dev/null)
if echo "$json_output" | grep -q '"version"'; then
    echo "  ✅ status --json 输出有效 JSON"
    PASS=$((PASS + 1))
else
    echo "  ❌ status --json 输出无效"
    FAIL=$((FAIL + 1))
fi

echo ""
echo "────────────────────────────────"
echo "结果: $PASS 通过, $FAIL 失败"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
