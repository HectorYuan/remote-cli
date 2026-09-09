# remote-cli

统一远程访问 CLI — 一个命令连接工作站。

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-0.5.0-blue.svg)](VERSION)
[![CI](https://github.com/HectorYuan/remote-cli/actions/workflows/ci.yml/badge.svg)](https://github.com/HectorYuan/remote-cli/actions/workflows/ci.yml)

## 架构总览

```
┌────────────────────────────────────────────────────────────┐
│  Runner 中继服务器（云 ECS）                                 │
│                                                            │
│  ├─ nginx (Docker)      安装源 + tarball 下载 (80→443 TLS)  │
│  ├─ remote-enroll       设备注册服务 (8100)                 │
│  └─ hbbs/hbbr           RustDesk 中继 (21115-21119)        │
└────────────────────────────────────────────────────────────┘
                          │
        ┌─────────────────┼──────────────────┐
        │                 │                  │
┌───────▼────────┐  ┌─────▼──────┐  ┌────────▼────────┐
│ 工作站          │  │ Windows    │  │ 手机/其他设备     │
│ (Ubuntu)       │  │ 笔记本      │  │                 │
└────────────────┘  └────────────┘  └─────────────────┘
         └──────── Tailscale P2P 组网 (WireGuard 加密) ────────┘
```

**三层访问模型**（自动选路）：

| 层 | 通道 | 说明 |
|---|---|---|
| L1 | Tailscale P2P | 首选，WireGuard 加密直连 |
| L2 | 局域网直连 | 同网络时自动切换 |
| L3 | Runner 中继 | RustDesk 桌面的 fallback |

## Quick Start

### 工作站初始化（一次性）

```bash
# 1. 安装 remote-cli 本体
curl -fsSL http://14.103.46.178/setup/install.sh | bash

# 2. 安装所有依赖（ssh/mosh/tailscale/rustdesk/zellij，已装的自动跳过）
remote install

# 3. 交互式首次配置（SSH 密钥、Tailscale 登录引导、服务启动）
remote setup

# 4. 确认状态
remote status        # 健康检查
remote doctor        # 深度诊断（--json / --fix）
```

### 新设备接入（2 条命令）

```bash
# ── 工作站：生成一次性 token ──
remote enroll create
# 输出: remote enroll RC-xxxxxxxxxxxxxx

# ── 新设备：装好 remote-cli 后执行 ──
remote enroll RC-xxxxxxxxxxxxxx
# 自动完成: 拉取配置 → 生成 SSH 密钥 → 上传公钥 → 写本地配置

# ── 工作站：接收公钥（推荐挂自动化，只需执行一次）──
remote enroll sync-install   # systemd timer 每分钟自动接收
```

约 1 分钟后新设备即可连接。token 一次性、1 小时过期、用后即焚。

### Windows

```powershell
# 安装
irm http://14.103.46.178/setup/install.ps1 | iex

# 接入
remote enroll RC-xxxxxxxxxxxxxx

# 连接
remote connect
```

Windows 支持 connect/status/desktop/install/enroll/config；mosh/zellij 不适用（用 SSH 替代）。

## 日常使用

| 场景 | 命令 |
|---|---|
| 连终端 | `remote connect`（自动选 mosh/Tailscale/LAN） |
| 查看连接路径 | `remote connect --dry-run` |
| 远程桌面 | `remote desktop`（RustDesk） |
| Web IDE | `remote code`（输出浏览器 URL） |
| 传文件 | `remote files push/pull/list`（rsync 优先） |
| 端口转发 | `remote forward 8188`（如 ComfyUI） |
| 改配置 | `remote config show / set <k> <v> / edit` |
| 查状态 | `remote status`（`--json` / `--watch 5`） |
| 诊断修复 | `remote doctor`（`--fix` 联动自动修复） |
| 管理 Runner | `remote runner status/logs/restart/ssh` |
| 自更新 | `remote update` |
| 卸载 | `remote uninstall` |

Tab 补全自动安装（`completions/remote.bash`）。

## 安全设计

| 机制 | 说明 |
|---|---|
| SSH | 仅密钥认证，密码已禁用 |
| 传输 | Tailscale WireGuard 端到端加密，P2P 直连 |
| RustDesk | 自建中继，数据不经第三方 |
| enroll token | 128 位随机、一次性使用、1 小时过期、用后即焚 |
| 敏感配置 | `~/.config/remote-cli/config.env`（600 权限，不入 git） |
| 幂等操作 | 所有 fix/写入操作可安全重复执行 |
| 审计 | fix 操作记录到 `~/.config/remote-cli/audit.log` |

## 开发

```bash
git clone https://github.com/HectorYuan/remote-cli.git
cd remote-cli
bin/remote --version
bash tests/smoke.sh
```

### CI/CD

| 流程 | 触发 | 内容 |
|---|---|---|
| CI | push/PR | bash -n + shellcheck + smoke（ubuntu + macos matrix）+ doctor JSON 验证 |
| Release | tag `v*` | tag/VERSION 一致性校验 → lint + smoke → 自动构建 tarball 附加到 Release |

### 版本路线

```
v0.1.x  产品化重构 + 消除 eval + 文件传输
v0.2.x  跨平台 + 安全修复 + Windows 兼容 + HTTPS 安装源
v0.3.x  一键装依赖 + 可靠性修复 + 配置管理 + 审计
v0.4.x  doctor 集成诊断 + GitHub Actions CI + bash 3.2 兼容
v0.5.0  remote enroll 一键设备接入
```

详见 [CHANGELOG.md](CHANGELOG.md)。

## License

[MIT](LICENSE)
