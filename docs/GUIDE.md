# 远程访问使用指南

> 工作站: `yons-Z790-EAGLE-AX` | Tailscale IP: `100.86.106.59` | Runner 中继: `14.103.46.178`

---

## 一、30 秒速查

```bash
remote status           # 查看所有服务状态
remote connect          # 连接工作站
remote desktop          # 远程桌面
remote code             # Web IDE
remote files push <file>  # 上传文件
remote files pull <file>  # 下载文件
remote forward 8188     # 端口转发
remote fix              # 诊断修复
remote --help           # 查看所有命令
```

---

## 二、其他设备接入（从零开始）

### 步骤 1：安装 Tailscale

在**每台需要远程访问的设备**上安装：

| 平台 | 安装方式 |
|---|---|
| **Windows** | https://tailscale.com/download/windows → 下载安装包 |
| **macOS** | `brew install tailscale` 或 App Store 搜索 Tailscale |
| **Linux** | `curl -fsSL https://tailscale.com/install.sh \| sh` |
| **iPhone/iPad** | App Store 搜索 Tailscale |
| **Android** | Google Play 搜索 Tailscale |

安装后用 **同一个账号** 登录（GitHub/Google/SSO 均可）。

### 步骤 2：安装 remote-cli（其他设备）

```bash
# Linux/macOS
git clone <repo-url> ~/.local/remote-cli
export PATH="$HOME/.local/remote-cli/bin:$PATH"

# 或直接下载
curl -fsSL <repo-url>/setup/install.sh | bash
```

### 步骤 3：选择访问方式

| 我要... | 方式 | 命令/操作 |
|---|---|---|
| **敲命令** | SSH | `ssh hector@100.86.106.59` |
| **写代码** | VS Code Remote SSH | VS Code → Remote-SSH → Connect to Host |
| **看 GUI 界面** | RustDesk | 安装 RustDesk → 设置中继 → 输入 ID |
| **浏览器写代码** | code-server | 浏览器打开 `http://100.86.106.59:8080` |
| **端口转发** | SSH 隧道 | `remote forward 8188` |
| **文件传输** | remote files | `remote files push/pull` |
| **手机操作** | Tailscale + Termius | Termius → 新建 Host → `100.86.106.59:22` |

---

## 三、Windows 笔记本详细指南

### SSH 终端

1. 打开 PowerShell 或 Windows Terminal（Windows 10/11 自带 OpenSSH）
2. 执行：
   ```powershell
   ssh hector@100.86.106.59
   ```
3. 首次连接会提示指纹确认，输入 `yes`
4. 进入后可启动 Zellij：
   ```bash
   zellij --layout dev
   ```

### VS Code Remote SSH（推荐写代码）

1. VS Code 安装扩展：`Remote - SSH`（微软官方）
2. `Ctrl+Shift+P` → 输入 `Remote-SSH: Connect to Host`
3. 输入 `hector@100.86.106.59`
4. 选择平台：`Linux`
5. 等待 VS Code 连接，安装 server 组件
6. 完整的 VS Code 环境 + 终端 + 文件浏览器 + 插件

### RustDesk 远程桌面（看 ComfyUI/Blender 等 GUI）

1. 下载安装：https://rustdesk.com/download
2. 打开 RustDesk → 点击右上角 **菜单** → **网络设置**
3. 填写：

| 字段 | 值 |
|---|---|
| ID 服务器 | `14.103.46.178` |
| Key | `见 ~/.config/remote-cli/config.env` |

4. 回到主界面，在 **远程桌面** 输入框输入工作站的 RustDesk ID
5. 点击连接，输入一次性密码

### 浏览器 Web IDE

浏览器直接打开 `http://100.86.106.59:8080`

---

## 四、macOS 笔记本详细指南

### SSH 终端

打开终端：
```bash
ssh hector@100.86.106.59
```

### 保持连接（合盖不断）

```bash
mosh hector@100.86.106.59
```

Mosh 基于 UDP，WiFi 切换、合盖再开都不会断连。

### VS Code Remote SSH

同 Windows 步骤。

---

## 五、手机访问（iOS/Android）

### 安装

1. App Store / Google Play 安装 **Tailscale**
2. 安装 **Termius**（SSH 客户端）
3. 用同一账号登录 Tailscale

### Termius 配置

1. 打开 Termius → **New Host**
2. 填写：

| 字段 | 值 |
|---|---|
| Label | `Workstation` |
| Hostname | `100.86.106.59` |
| Port | `22` |
| Username | `hector` |
| Key | 生成或导入 SSH 密钥 |

3. 保存后点击连接

### 手机远程桌面

安装 RustDesk App → 设置中继 → 连接。

---

## 六、文件传输

```bash
# 上传文件到工作站
remote files push ./local-file.txt /home/hector/remote-file.txt

# 从工作站下载文件
remote files pull /home/hector/data.csv ./local-data.csv

# 列出远程目录
remote files list /home/hector/projects
```

底层优先使用 rsync（加速），不可用时 fallback 到 scp。

---

## 七、端口转发（访问工作站本地服务）

### 场景：笔记本访问工作站的 ComfyUI (8188)

```bash
remote forward 8188
# 浏览器打开 http://localhost:8188
```

### 常用端口转发

| 服务 | 端口 | 命令 |
|---|---|---|
| ComfyUI | 8188 | `remote forward 8188` |
| Jupyter | 8888 | `remote forward 8888` |
| Ollama | 11434 | `remote forward 11434` |

---

## 八、故障排查

### 连不上 Tailscale

```bash
tailscale status              # 检查状态
sudo tailscale logout && sudo tailscale up  # 重新登录
```

### SSH 连不上

```bash
remote status                 # 查看所有服务状态
remote fix --dry-run          # 诊断问题
remote fix                    # 修复
```

### RustDesk 连不上

```bash
remote runner status          # 检查 Runner 中继
remote runner restart         # 重启 Runner 容器
```

### 诊断所有问题

```bash
remote status                 # 人类可读表格
remote status --json          # JSON 格式（供脚本消费）
remote fix --dry-run          # 只诊断不修复
remote fix                    # 交互式修复
```

---

## 九、安全注意事项

| 项目 | 说明 |
|---|---|
| **SSH 密码已禁用** | 仅允许密钥认证 |
| **Tailscale 加密** | 所有流量 WireGuard 加密，P2P 直连 |
| **RustDesk 中继** | 自建中继，数据不经第三方 |
| **config.env** | 敏感配置在 `~/.config/remote-cli/config.env`，不入 git |
| **密钥管理** | 不在文档/脚本中明文存储密钥 |

---

## 十、快速参考

| 命令 | 说明 |
|---|---|
| `remote status` | 健康检查 |
| `remote status --json` | JSON 格式状态 |
| `remote connect` | 自动连接 |
| `remote connect --dry-run` | 只显示路径 |
| `remote desktop` | RustDesk |
| `remote code` | Web IDE URL |
| `remote files push <file>` | 上传文件 |
| `remote files pull <file>` | 下载文件 |
| `remote files list` | 远程目录 |
| `remote forward <port>` | 端口转发 |
| `remote fix` | 诊断+修复 |
| `remote fix --dry-run` | 只诊断 |
| `remote runner status` | Runner 状态 |
| `remote runner restart` | Runner 重启 |
| `remote config` | 查看配置 |
| `remote update` | 自更新 |
| `remote --version` | 版本号 |
