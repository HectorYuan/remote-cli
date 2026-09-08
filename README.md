# remote-cli

统一远程访问 CLI — 一个命令连接工作站。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.3.1-blue.svg)](VERSION)

## Quick Start

```bash
# Linux / macOS / WSL
curl -fksSL https://14.103.46.178/setup/install.sh | bash

# Windows PowerShell
irm https://14.103.46.178/setup/install.ps1 | iex
```

## 使用

```bash
remote setup           # 首次配置
remote status          # 健康检查
remote connect         # 连接工作站
remote files push <f>  # 上传文件
remote files pull <f>  # 下载文件
remote forward 8188    # 端口转发
remote desktop         # RustDesk 远程桌面
remote fix             # 诊断修复
remote --help          # 查看所有命令
```

## 支持平台

| 平台 | 安装方式 | CLI 版本 |
|---|---|---|
| Linux | `curl ... \| bash` | bash |
| macOS | `curl ... \| bash` | bash |
| WSL | 自动检测 | bash |
| Windows | `irm ... \| iex` | PowerShell |

## 功能

| 命令 | 说明 |
|---|---|
| `remote connect` | 自动选路连接（Tailscale > LAN），支持 --mosh/--ssh/--dry-run |
| `remote status` | 健康检查 + --json 输出 + --deps 依赖检测 |
| `remote fix` | 5 项诊断 + 幂等修复，支持 --dry-run/--auto/--backup |
| `remote files push/pull/list` | 文件传输（rsync 优先 + scp fallback） |
| `remote forward <port>` | SSH 端口转发 |
| `remote desktop` | RustDesk 远程桌面 |
| `remote code` | code-server Web IDE |
| `remote runner` | Runner 中继管理（status/restart/logs/ssh） |
| `remote config` | 查看配置 |
| `remote update` | 自更新（git pull） |
| `remote uninstall` | 安全卸载 |

## 架构

```
remote CLI
  ├── L1: Tailscale P2P (100.x.x.x)  ← 首选
  ├── L2: 局域网 (172.x.x.x)          ← 同网络
  └── L3: Runner 中继 (公网 IP)        ← RustDesk fallback
```

## 安全

- SSH 仅允许密钥认证（密码已禁用）
- 所有流量经 Tailscale WireGuard 加密
- RustDesk 使用自建中继，数据不经第三方
- 敏感配置在 `~/.config/remote-cli/config.env`，不入 git
- 所有修复操作幂等（可安全重复执行）

## 开发

```bash
git clone https://github.com/HectorYuan/remote-cli.git
cd remote-cli
bin/remote --version
bash tests/smoke.sh
```

## License

[MIT](LICENSE)
