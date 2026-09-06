# remote-cli

统一远程访问 CLI，一个命令连接工作站。

## Quick Start

```bash
remote status           # 健康检查
remote connect          # 连接终端
remote desktop          # 远程桌面
remote code             # Web IDE
remote forward 8188     # 端口转发
remote fix              # 诊断修复
remote runner status    # Runner 管理
```

## 安装

```bash
# 加入 PATH（已自动添加到 bashrc.d.sh）
export PATH="$HOME/DevSpace/remote-cli/bin:$PATH"
```

## 首次使用

```bash
remote setup            # 初始化配置
remote fix --dry-run    # 查看需要修复的问题
remote fix              # 执行修复
remote status           # 确认所有服务就绪
```

## 需要 sudo 的操作

以下操作需要 `sudo` 权限，已生成脚本：

```bash
sudo bash /tmp/p0-fix.sh
```

内容包括：
1. 启动 sshd 服务
2. 创建 `/etc/ssh/sshd_config.d/hardened.conf`（禁用密码登录）
3. 创建 `~/.config/remote-cli/config.env`
4. 修复 code-server 绑定

## 架构

```
remote CLI
  ├── L1: Tailscale P2P (100.x.x.x)  ← 首选
  ├── L2: 局域网 (172.16.138.50)       ← 同网络
  └── L3: Runner 中继 (14.103.46.178)  ← RustDesk fallback
```

## 项目结构

```
bin/remote          # 主入口
lib/
  config.sh         # 配置管理
  detect.sh         # 状态检测
  connect.sh        # 连接逻辑
  status.sh         # 健康检查
  fix.sh            # 诊断修复
  forward.sh        # 端口转发
  runner.sh         # Runner 管理
  desktop.sh        # RustDesk
  code.sh           # code-server
  setup.sh          # 首次部署
```

## License

MIT
