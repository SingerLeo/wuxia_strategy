#!/usr/bin/env bash
# Linux 服务器一键环境（Debian/Ubuntu 优先）：基础包 + tmux + Godot(headless) + GUT + Claude Code，
# 然后在服务器上跑一遍导入与全部测试作为验收。可重复运行（已装的会跳过）。
#
# 用法（已经把仓库 clone 到服务器之后，在仓库根目录运行）：
#   bash scripts/server-bootstrap.sh
# 环境变量：
#   SKIP_APT=1      不执行 apt/dnf 安装（只在测试环境用）
#   SKIP_CLAUDE=1   不安装 Claude Code
#   SKIP_TESTS=1    不跑验收测试
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$HOME/.local/bin"
export PATH="$BIN:$PATH"
SUDO=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1 && SUDO="sudo"
have() { command -v "$1" >/dev/null 2>&1; }
step() { printf '\n\033[1m== %s ==\033[0m\n' "$*"; }

# 新建的虚拟机常常正在自动更新并占着 apt 锁，所以让 apt 最多等 5 分钟而不是直接失败
APT="apt-get -o DPkg::Lock::Timeout=300"

install_pkgs() {
  if have apt-get; then $SUDO $APT update -qq && $SUDO $APT install -y -qq "$@"
  elif have dnf; then $SUDO dnf install -y -q "$@"
  elif have yum; then $SUDO yum install -y -q "$@"
  else echo "不支持的包管理器，请手动安装: $*"; return 1; fi
}

# ---------- 1. 基础包 ----------
step "1/5 基础包（curl unzip git tmux）"
if [ "${SKIP_APT:-0}" != "1" ]; then
  install_pkgs curl unzip git tmux ca-certificates
  # Godot 无界面运行所需的运行库（缺了才会报错，装不上也不致命）
  if have apt-get; then
    $SUDO $APT install -y -qq libfontconfig1 libgl1 libx11-6 libxcursor1 libxi6 libxinerama1 libxrandr2 >/dev/null 2>&1 || true
  fi
else
  echo "跳过（SKIP_APT=1）"
fi

# ---------- 2. Godot + GUT（版本见 scripts/versions.env） ----------
step "2/5 Godot 与 GUT"
bash "$ROOT/scripts/setup.sh"

# ---------- 3. PATH ----------
step "3/5 PATH"
if ! grep -qs 'HOME/.local/bin' "$HOME/.bashrc" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  echo "已把 ~/.local/bin 加入 ~/.bashrc（新开终端生效）"
else
  echo "~/.bashrc 已包含 ~/.local/bin"
fi

# ---------- 4. Claude Code（官方安装脚本） ----------
step "4/5 Claude Code"
if [ "${SKIP_CLAUDE:-0}" = "1" ]; then
  echo "跳过（SKIP_CLAUDE=1）"
elif have claude; then
  echo "已安装：$(claude --version 2>&1 | head -1)"
else
  curl -fsSL https://claude.ai/install.sh | bash
  have claude && echo "已安装：$(claude --version 2>&1 | head -1)" || echo "提示：新开终端后运行 claude --version 确认"
fi

# ---------- 5. 验收：导入项目并跑全部测试 ----------
step "5/5 验收（导入 + 全部测试）"
RESULT=0
if [ "${SKIP_TESTS:-0}" = "1" ]; then
  echo "跳过（SKIP_TESTS=1）"
else
  cd "$ROOT"
  godot --headless --import >/dev/null 2>&1 || true
  OUT="$(godot --headless -s addons/gut/gut_cmdln.gd -gexit 2>&1 || true)"
  echo "$OUT" | grep -E '^\s*(Scripts|Tests|Passing Tests|Failing Tests)\b|All tests passed|failing tests|Parse Error|SCRIPT ERROR' || true
  if echo "$OUT" | grep -q 'All tests passed'; then
    echo "验收通过"
  else
    echo "验收未通过：请把上面的输出发给我"; RESULT=1
  fi
fi

cat <<'EOF'

===== 接下来（手机远程编程）=====
1) 首次登录 Claude（只需一次）：运行  claude
   按提示打开给出的网址登录你的 Claude 账号（需要 Pro/Max/Team/Enterprise；API Key 不支持远程控制）。
2) 在 tmux 里启动远程控制（这样断开 SSH 后也不会掉线）：
     tmux new -s dev
     cd ~/wuxia_strategy     # 换成你的仓库路径
     claude remote-control
   按空格可显示二维码；用手机上的 Claude App 扫码，或在 claude.ai/code 的会话列表里打开。
3) 断开 tmux 但保持运行：先按 Ctrl+b，再按 d。重新进入：tmux attach -t dev
EOF
exit $RESULT
