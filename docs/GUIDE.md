# 远程访问使用指南

> 工作站: `yons-Z790-EAGLE-AX` | Tailscale IP: `100.86.106.59` | Runner 中继: `14.103.46.178`

---

## 一、30 秒速查

```bash
remote status           # 查看所有服务状态
remote connect          # 连接工作站
remote desktop          # 远程桌面
remote code             # Web IDE
remote fix              # 诊断修复
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

登录后在 Tailscale 控制台能看到所有设备，自动组网。

### 步骤 2：选择访问方式

| 我要... | 方式 | 命令/操作 |
|---|---|---|
| **敲命令** | SSH | `ssh hector@100.86.106.59` |
| **写代码** | VS Code Remote SSH | VS Code → Remote-SSH → Connect to Host |
| **看 GUI 界面** | RustDesk | 安装 RustDesk → 设置中继 → 输入 ID |
| **浏览器写代码** | code-server | 浏览器打开 `http://100.86.106.59:8080` |
| **端口转发** | SSH 隧道 | `ssh -L 8188:localhost:8188 hector@100.86.106.59` |
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
| Key | `YiZCzMo+R3uO2p062yahrQrz4Oc08aqTtBQE1MqOPz4=` |

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

### iTerm2 + tmux

```bash
# SSH 后自动 attach zellij
ssh hector@100.86.106.59 -t "zellij attach --create dev"
```

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

## 六、端口转发（访问工作站本地服务）

### 场景：笔记本访问工作站的 ComfyUI (8188)

```bash
# 在笔记本终端执行
ssh -L 8188:localhost:8188 hector@100.86.106.59 -N

# 浏览器打开 http://localhost:8188
```

### 常用端口转发

| 服务 | 端口 | 命令 |
|---|---|---|
| ComfyUI | 8188 | `ssh -L 8188:localhost:8188 hector@100.86.106.59 -N` |
| Jupyter | 8888 | `ssh -L 8888:localhost:8888 hector@100.86.106.59 -N` |
| Ollama | 11434 | `ssh -L 11434:localhost:11434 hector@100.86.106.59 -N` |
| 多个端口 | 多次执行 | 每个端口单独一条命令 |

---

## 七、故障排查

### 连不上 Tailscale

```bash
# 检查 Tailscale 状态
tailscale status

# 重新登录
sudo tailscale logout
sudo tailscale up
```

### SSH 连不上

```bash
# 工作站上检查
systemctl status ssh
ss -tlnp | grep :22
```

### RustDesk 连不上

1. 确认中继服务器填写正确：`14.103.46.178`
2. 确认 Key 填写正确：`YiZCzMo+R3uO2p062yahrQrz4Oc08aqTtBQE1MqOPz4=`
3. 检查 Runner 中继是否运行：`remote runner status`

### code-server 打不开

```bash
# 工作站上检查
systemctl status snap.code-server.daemon
# 或
systemctl status code-server@hector
```

---

## 八、安全注意事项

| 项目 | 说明 |
|---|---|
| **SSH 密码已禁用** | 仅允许密钥认证 |
| **Tailscale 加密** | 所有流量 WireGuard 加密，P2P 直连 |
| **RustDesk 中继** | 自建中继，数据不经第三方 |
| **config.env** | 敏感配置在 `~/.config/remote-cli/config.env`，不入 git |

---

## 九、快速参考

| 命令 | 说明 |
|---|---|
| `remote status` | 健康检查 |
| `remote connect` | 自动连接 |
| `remote desktop` | RustDesk |
| `remote code` | Web IDE URL |
| `remote forward 8188` | 端口转发 |
| `remote fix` | 诊断+修复 |
| `remote runner status` | Runner 状态 |
| `remote runner logs hbbs` | RustDesk 中继日志 |
| `remote --version` | 版本号 |
