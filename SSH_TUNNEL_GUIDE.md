# OpenClaw Cloud Deployment & SSH Tunnel Guide

## 1. 部署步骤 (Server Side)

1.  **上传文件**:
    将 `D:\OpenClaw\deploy` 目录下的所有文件上传到您的 Ubuntu 服务器（例如 `~/openclaw-deploy`）。
    ```bash
    scp -r D:\OpenClaw\deploy user@your-server-ip:~/openclaw-deploy
    ```

2.  **执行安装脚本**:
    SSH 登录服务器并运行部署脚本：
    ```bash
    ssh user@your-server-ip
    cd ~/openclaw-deploy
    chmod +x deploy_openclaw.sh
    ./deploy_openclaw.sh
    ```

3.  **验证运行**:
    ```bash
    docker compose ps
    ```

## 2. 安全连接指南 (Client Side - Huawei Laptop)

由于 OpenClaw Gateway 仅绑定了 `127.0.0.1` (localhost)，外部无法直接访问。我们需要使用 SSH 隧道将服务器端口映射到本地。

### 步骤 A: 建立 SSH 隧道
在您的笔记本电脑上打开 PowerShell 或 CMD，运行以下命令：

```powershell
# 格式: ssh -L 本地端口:127.0.0.1:远程端口 用户@服务器IP
ssh -L 18789:127.0.0.1:18789 user@your-server-ip
```

*保持此窗口开启，不要关闭。*

### 步骤 B: 本地连接
现在，您的本地机器 (localhost:18789) 已经通过加密隧道连接到了云端 Gateway。

1.  **访问 Web 面板**:
    在浏览器中打开: `http://localhost:18789`

2.  **使用 CLI 控制**:
    在本地终端使用 OpenClaw CLI 连接：
    ```powershell
    # Token 可以在服务器的 ~/openclaw-deploy/.env 文件中找到
    openclaw gateway --host 127.0.0.1 --port 18789 --token <YOUR_TOKEN>
    ```

## 3. Telegram Bot 配置

1.  在 Telegram 中搜索 `@BotFather` 创建新 Bot，获取 `BOT_TOKEN`。
2.  通过 SSH 隧道连接到 OpenClaw Web 面板。
3.  进入 **Channels** 设置，添加 **Telegram**。
4.  填入 `BOT_TOKEN`。
5.  在 Telegram 中向您的 Bot 发送 `/start`，完成绑定。

完成以上步骤后，`arbitrage_monitor.py` 检测到的套利机会将可以通过 OpenClaw 的 Telegram 通道发送给您。
