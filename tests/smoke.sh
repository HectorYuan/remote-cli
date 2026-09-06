#!/usr/bin/env bash
# remote-cli 冒烟测试
set -uo pipefail

REMOTE_CLI_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0 FAIL=0

run_test() {
    local name="$1" cmd="$2" expect="$3"
    result=$(eval "$cmd" 2>&1)
    if echo "$result" | grep -q "$expect"; then
        echo "  ✅ $name"
        ((PASS++))
    else
        echo "  ❌ $name (expected '$expect' in output)"
        ((FAIL++))
    fi
}

echo "🧪 remote-cli 冒烟测试"
echo ""

echo "基本命令:"
run_test "--version"  "$REMOTE_CLI_DIR/bin/remote --version" "remote-cli"
run_test "--help"     "$REMOTE_CLI_DIR/bin/remote --help" "用法"

echo ""
echo "子命令路由:"
run_test "config"     "$REMOTE_CLI_DIR/bin/remote config" "配置文件"
run_test "forward help" "$REMOTE_CLI_DIR/bin/remote forward help" "用法"

echo ""
echo "模块加载:"
source "$REMOTE_CLI_DIR/lib/config.sh"
source "$REMOTE_CLI_DIR/lib/detect.sh"
load_config

detect_sshd && echo "  ✅ detect_sshd (返回 0)" || echo "  ⚠️  detect_sshd (返回非 0，可能 sshd 未运行)"
detect_mosh && echo "  ✅ detect_mosh" || echo "  ⚠️  detect_mosh (未安装)"
detect_tailscale && echo "  ✅ detect_tailscale" || echo "  ⚠️  detect_tailscale (未登录)"

echo ""
echo "结果: $PASS 通过, $FAIL 失败"
[[ "$FAIL" -eq 0 ]] && exit 0 || exit 1
