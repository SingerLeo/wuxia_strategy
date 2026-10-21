# 在云服务器上搭建开发环境，并用手机远程编程

> 目标：在 Google Cloud 的一台 Linux 虚拟机上装好本项目需要的全部软件，用 Claude Code 的 **Remote Control** 让手机（Claude App）连上服务器上运行的会话，随时随地编程。
> 状态：`scripts/server-bootstrap.sh` 已在 Ubuntu 24.04 (x86_64) 上用临时目录试跑通过：Godot 校验下载、GUT、Claude Code 安装、导入、**全部 111 个测试通过**。
> 尚未验证：apt 安装基础包那一步（试跑时跳过了）、`gh` 登录、真实 GCP 虚拟机。

## 0. 先决条件
- Claude 账号：**Pro / Max / Team / Enterprise**（免费版不含 Claude Code；Remote Control **不支持 API Key**；Team/Enterprise 需管理员开启 Remote Control）。
- 手机装 **Claude App**（iOS / Android）。
- GitHub 账号，能访问私有仓库 `SingerLeo/wuxia_strategy`。
- Google Cloud 账号（已启用 Compute Engine）。

## 1. 创建虚拟机（Compute Engine）
| 项 | 建议 |
|---|---|
| 机型 | **e2-medium**（2 vCPU / 4 GB）起步。Claude Code 要求 4 GB 以上内存，别用 e2-micro / e2-small |
| 系统 | **Ubuntu 24.04 LTS**（x86_64，已验证）。Debian 12 通常也可以 |
| 磁盘 | 30 GB 标准持久盘 |
| 区域 | 选在 [Anthropic 支持的国家/地区](https://www.anthropic.com/supported-countries)（如美国、日本） |
| 网络 | **不需要开放任何入站端口**。Remote Control 只做出站 HTTPS 连接；SSH 用默认的 22 即可 |

费用提示：开机时按小时计费；不用时可在控制台"停止"实例，只收少量磁盘费。

## 2. 登录服务器
- 最简单：Google Cloud 控制台 → Compute Engine → VM 实例 → 点该实例的 **SSH** 按钮（浏览器里打开终端，不用配密钥）。
- 手机上也可以用 Google Cloud App 或 Termius 等 SSH 客户端。

## 3. 拿到代码（仓库是私有的，需要先登录 GitHub）
在服务器终端里依次执行：

```bash
sudo apt-get update && sudo apt-get install -y git curl
```

安装 GitHub CLI（官方安装方式）：

```bash
sudo mkdir -p -m 755 /etc/apt/keyrings
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update && sudo apt-get install -y gh
```

登录 GitHub（选 GitHub.com → HTTPS → 用浏览器登录；终端会显示一个一次性验证码，在手机或电脑浏览器里打开给出的网址输入即可）：

```bash
gh auth login
gh auth setup-git
```

克隆并设置提交身份：

```bash
gh repo clone SingerLeo/wuxia_strategy ~/wuxia_strategy
cd ~/wuxia_strategy
git config user.name "BruceLau"
git config user.email "你的邮箱"
```

## 4. 一键装环境并验收
```bash
bash scripts/server-bootstrap.sh
```
它会依次：装基础包与 tmux → 按 `scripts/versions.env` 装 Godot 和 GUT（带 SHA512 校验）→ 把 `~/.local/bin` 加进 PATH → 安装 Claude Code → 导入项目并跑全部测试。
最后看到 **"验收通过"** 就说明服务器环境和本机一致。可以重复运行，已装的会跳过。

## 5. 登录 Claude（只需一次）
```bash
source ~/.bashrc
claude
```
按提示打开给出的网址，用你的 Claude 账号授权，把返回的代码贴回终端。服务器没有浏览器也没关系，网址可以在手机或电脑上打开。

## 6. 启动远程控制（关键）
**必须放进 tmux**，否则断开 SSH 后进程就停了，手机会掉线：

```bash
tmux new -s dev
cd ~/wuxia_strategy
claude remote-control --name "武侠项目"
```
- 第一次会问 `Enable Remote Control? (y/n)`，选 `y`；问是否信任目录选 `y`。
- 终端显示会话网址，**按空格键显示二维码**。
- 手机：打开 **Claude App → Code**，在会话列表里找到"武侠项目"；或扫二维码。也可以用任意浏览器打开 claude.ai/code。
- 离开但保持运行：按 `Ctrl+b`，松开，再按 `d`。回来：`tmux attach -t dev`。
- 如果 `claude remote-control` 进程退出了，在同一目录重新运行同一条命令即可把会话接回来（约 4 小时内）。

## 7. 日常使用
- 手机里发消息，服务器上的 Claude 就在 `~/wuxia_strategy` 里改代码、跑测试、提交。
- 项目的约定（`CLAUDE.md`）在服务器上同样生效：**只有你明确说"push"才会推送**。
- 测试命令（在服务器上）：
  ```bash
  godot --headless -s addons/gut/gut_cmdln.gd -gexit
  ```

## 8. 本机与服务器如何同步
两边都是同一个 GitHub 仓库的克隆，**靠 Git 同步，不要两边同时改**：
- 在服务器上做完 → 说 "push" → 回到本机 `git pull`。
- 在本机做完 → `git push` → 服务器上让 Claude `git pull`。
- 有冲突时先让 Claude 处理，不要强行覆盖。

## 9. 限制
- 服务器没有显示器，**无法打开游戏窗口、无法用 `tools/shot.gd` 截图**。逻辑与测试没问题；界面效果要回到本机看。（以后需要的话可以加虚拟显示 Xvfb，再单独做。）
- Windows 专用的东西（`启动游戏.bat`、`setup.ps1`）在服务器上用不到。
- 服务器的 Claude 登录信息保存在 `~/.claude/`，等同于你的账号凭据，别把这个目录打包分享。

## 10. 排错
| 现象 | 处理 |
|---|---|
| `claude: command not found` | 新开终端，或 `source ~/.bashrc`；确认 `~/.local/bin` 在 PATH 里 |
| `claude remote-control` 报没有登录 | 先运行 `claude` 完成登录；确认账号是 Pro/Max/Team/Enterprise |
| 提示 `Workspace not trusted` | 在真实终端（不是管道）里运行并回答 `y` |
| 手机上看不到会话 | 确认手机和服务器登录的是**同一个** Claude 账号；会话列表在 App 的 Code 页 |
| 断开 SSH 后手机掉线 | 没放进 tmux；按第 6 节重来 |
| Godot 启动报缺少 `.so` 库 | `sudo apt-get install -y libfontconfig1 libgl1 libx11-6 libxcursor1 libxi6 libxinerama1 libxrandr2` |
| 下载 Godot 时 GitHub 接口限流 | 版本已固定在 `scripts/versions.env`，一般不会触发；仍失败就稍后重试 |
