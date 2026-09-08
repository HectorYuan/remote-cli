# Changelog

## v0.3.1 (2026-09-07)

### Bug 修复
- detect.sh: 统一读取 RustDesk2.toml（之前读 config2.toml 导致 status 误报）
- install.ps1: 添加 UTF-8 BOM（PowerShell 5.1 兼容性）
- install.sh: 版本号改为动态读取（不再硬编码）
- install.ps1: RUNNER_KEY 默认值统一为 ~/.ssh/neorun.pem

## v0.3.0 (2026-09-07)

### 体验优化
- `remote status`: 终端不支持颜色时自动去掉 ANSI 转义
- `remote fix --auto`: sudo 不可用时跳过需 root 的修复并提示
- `remote connect --dry-run`: 不再输出私钥路径，改为显示密钥类型
- `remote setup`: sudo 前置检测，不可用时跳过 root 步骤
- config.env: 增加字段注释和分组说明
- config.sh: 迁移版本值不带引号，避免比较歧义

### 安全修复
- detect_deps 返回值语义统一为 0=正常（与 detect_* 系列一致）
- atomic_write: 失败时清理临时文件
- enable_service: Windows 分支直接用 `sc`，跳过 systemctl
- runner.sh: 简化远程命令，避免引号嵌套问题
- install.sh: Tailscale APT 源用 `lsb_release -cs` 动态获取发行版
- uninstall.sh: 移除硬编码路径，使用通用 shell_rc 检测

### 工程化
- CHANGELOG.md: 版本变更日志
- LICENSE: MIT 许可证
- bash-completion: Tab 补全脚本
- README.md: 更新安装说明

## v0.2.1 (2026-09-07)

### P0 安全修复
- files.sh: 消除 eval 注入，rsync 改为数组调用
- install.sh: REPO_URL 改为正确地址

### P1 正确性修复
- runner.sh: 增加服务名白名单校验
- forward.sh: PID 文件机制，避免误杀
- files.sh: 参数用数组处理含空格路径
- bin/remote: 移除 case 顶层 local 关键字
- remote.ps1: 版本号从 VERSION 动态读取

## v0.2.0 (2026-09-07)

### 跨平台支持
- lib/common.sh: detect_platform() 支持 Linux/macOS/WSL/Windows
- 安装器: setup/install.sh (curl) + setup/install.ps1 (PowerShell)
- Windows: bin/remote.ps1 (PowerShell 版本)
- lib/setup.sh: 交互式首次配置向导

## v0.1.3 (2026-09-07)

### 新增功能
- lib/files.sh: 文件传输 (push/pull/list)
- lib/uninstall.sh: 安全卸载
- docs/GUIDE.md: 完整使用指南

## v0.1.2 (2026-09-07)

### 安全修复
- fix.sh: 消除 eval，改为显式函数注册表（5 检查 + 5 修复函数）

## v0.1.1 (2026-09-07)

### 产品化重构
- lib/common.sh: 基础设施（日志/错误处理/幂等写入/平台检测）
- lib/config.sh: 三层配置（默认值 → config.env → 环境变量）
- lib/detect.sh: 跨平台适配（is_service_active 函数多态）
- bin/remote: 惰性加载（按需 source 模块）
- lib/runner.sh: 消除硬编码
- status --json: JSON 输出

## v0.1.0 (2026-09-07)

### 初始版本
- 10 个子命令: connect/status/fix/forward/desktop/code/runner/setup/config
- 三层访问模型: Tailscale P2P > 局域网 > Runner 中继
