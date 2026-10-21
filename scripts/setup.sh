#!/usr/bin/env bash
# Linux 服务器一键安装 + 检查：Godot 4 标准版(headless 用)、Git、GUT
# 用法：
#   bash scripts/setup.sh --check     只检查，不改动
#   bash scripts/setup.sh             检查并安装缺失项
# 环境变量：GODOT_VERSION(如 4.4.1-stable)、GUT_REF(如 v9.4.0)、PROJECT_DIR
# 服务器默认不装编辑器；如需 VS Code 请自行安装。
set -euo pipefail

CHECK=0; [ "${1:-}" = "--check" ] && CHECK=1
PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

# 读取固定版本（scripts/versions.env）；已设置的环境变量优先
VERSIONS_FILE="$(cd "$(dirname "$0")" && pwd)/versions.env"
if [ -f "$VERSIONS_FILE" ]; then
  while IFS='=' read -r k v; do
    case "$k" in GODOT_VERSION|GUT_REF) [ -z "${!k:-}" ] && export "$k=$v";; esac
  done < <(grep -E '^(GODOT_VERSION|GUT_REF)=' "$VERSIONS_FILE" | tr -d '\r')
fi
GODOT_HOME="$HOME/.local/share/godot"
BIN="$HOME/.local/bin"
MISSING=0
SUDO=""; [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null && SUDO="sudo"

have() { command -v "$1" >/dev/null 2>&1; }
latest() { curl -fsSL -H 'User-Agent: setup' "https://api.github.com/repos/$1/releases/latest" | grep -m1 '"tag_name"' | sed -E 's/.*"tag_name": *"([^"]+)".*/\1/'; }
pkg() {
  if have apt-get; then $SUDO apt-get update -qq && $SUDO apt-get install -y -qq "$@"
  elif have dnf; then $SUDO dnf install -y -q "$@"
  elif have yum; then $SUDO yum install -y -q "$@"
  elif have pacman; then $SUDO pacman -Sy --noconfirm "$@"
  else echo "不支持的包管理器，请手动安装: $*"; return 1; fi
}

# ---------- 基础工具 ----------
if [ $CHECK -eq 0 ]; then
  for t in curl unzip git; do have $t || pkg $t; done
fi

# ---------- 1. Godot ----------
if ! have godot && [ $CHECK -eq 0 ]; then
  VER="${GODOT_VERSION:-$(latest godotengine/godot)}"
  ARCH="$(uname -m)"
  case "$ARCH" in x86_64) A="linux.x86_64";; aarch64) A="linux.arm64";; *) echo "不支持的架构 $ARCH"; exit 1;; esac
  NAME="Godot_v${VER}_${A}"
  BASE="https://github.com/godotengine/godot/releases/download/$VER"
  TMP="$(mktemp -d)"
  echo "下载 Godot $VER ..."
  curl -fsSL "$BASE/$NAME.zip" -o "$TMP/g.zip"
  curl -fsSL "$BASE/SHA512-SUMS.txt" -o "$TMP/sums.txt"
  WANT="$(grep "$NAME.zip" "$TMP/sums.txt" | awk '{print $1}' | head -1)"
  GOT="$(sha512sum "$TMP/g.zip" | awk '{print $1}')"
  [ -n "$WANT" ] && [ "$WANT" = "$GOT" ] || { echo "Godot 校验和不匹配，已中止"; exit 1; }
  unzip -q "$TMP/g.zip" -d "$TMP"
  mkdir -p "$GODOT_HOME" "$BIN"
  install -m 755 "$TMP/$NAME" "$GODOT_HOME/godot"
  ln -sf "$GODOT_HOME/godot" "$BIN/godot"
  rm -rf "$TMP"
  case ":$PATH:" in *":$BIN:"*) ;; *) export PATH="$BIN:$PATH"; echo "提示：请把 $BIN 加入 PATH（~/.bashrc）";; esac
fi
if have godot; then G="$(godot --headless --version 2>&1 | head -1)"; else G="MISSING"; MISSING=1; fi

# ---------- 2. Git ----------
if have git; then GIT="$(git --version)"; else GIT="MISSING"; MISSING=1; fi

# ---------- 3. GUT ----------
GUT_DIR="$PROJECT_DIR/addons/gut"
if [ ! -d "$GUT_DIR" ] && [ $CHECK -eq 0 ]; then
  REF="${GUT_REF:-$(latest bitwes/Gut)}"
  TMP="$(mktemp -d)"
  git clone --quiet --depth 1 --branch "$REF" https://github.com/bitwes/Gut.git "$TMP/gut"
  mkdir -p "$PROJECT_DIR/addons"
  cp -r "$TMP/gut/addons/gut" "$GUT_DIR"
  rm -rf "$TMP"
fi
if [ -d "$GUT_DIR" ]; then GUT="installed at $GUT_DIR"; else GUT="MISSING"; MISSING=1; fi

# ---------- 汇总 ----------
echo
echo "===== 检查结果 ====="
printf '%-10s %s\n' Godot "$G" Git "$GIT" GUT "$GUT"
[ -f "$PROJECT_DIR/project.godot" ] || echo "提示：$PROJECT_DIR 下还没有 project.godot；GUT 需在项目创建后启用插件。"
exit $MISSING
