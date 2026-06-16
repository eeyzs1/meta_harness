#!/usr/bin/env bash
# check-version.sh — 检查 meta-harness 是否有更新
# 用法：bash meta-harness/scripts/check-version.sh
# 输出：当前版本 vs 远程最新版本，以及建议操作
# 协议：自动支持 SSH 和 HTTPS remote（raw URL 转换天然兼容两种来源），
#       如果当前 remote 不可达，会临时切换到另一种协议重试。
#       不会持久改写 remote URL（脚本结束前会恢复原值）。

set -uo pipefail

# 检测是否在 submodule 中
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MH_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

MH_REPO_SSH="git@github.com:eeyzs1/meta_harness.git"
MH_REPO_HTTPS="https://github.com/eeyzs1/meta_harness.git"

if [ ! -f "$MH_ROOT/VERSION" ]; then
  echo "ERROR: VERSION file not found at $MH_ROOT/VERSION" >&2
  exit 1
fi

CURRENT_VERSION=$(cat "$MH_ROOT/VERSION" | tr -d ' \n\r')

# 尝试获取远程 URL
REMOTE_URL=$(cd "$MH_ROOT" && git remote get-url origin 2>/dev/null || echo "")
if [ -z "$REMOTE_URL" ]; then
  echo "WARNING: Cannot determine remote URL. Skipping version check." >&2
  echo "CURRENT=$CURRENT_VERSION"
  echo "LATEST=unknown"
  echo "UPDATE_AVAILABLE=false"
  exit 0
fi

# 协议探测：如果当前 remote 是 SSH form，则备用协议是 HTTPS，反之亦然
PROTO="https"
ALT_REMOTE="$MH_REPO_SSH"
if echo "$REMOTE_URL" | grep -q "^git@github.com:"; then
  PROTO="ssh"
  ALT_REMOTE="$MH_REPO_HTTPS"
fi

# 策略 1: 如果是 GitHub，尝试 raw VERSION 文件（SSH/HTTPS remote 转换结果一致）
LATEST_VERSION=""
RAW_URL=""
if echo "$REMOTE_URL" | grep -q "github.com"; then
  RAW_URL=$(echo "$REMOTE_URL" | sed 's|https://github.com/|https://raw.githubusercontent.com/|' | sed 's|git@github.com:|https://raw.githubusercontent.com/|' | sed 's|\.git$||')
  RAW_URL="$RAW_URL/main/VERSION"
  LATEST_VERSION=$(curl -s --connect-timeout 5 "$RAW_URL" 2>/dev/null | tr -d ' \n\r' | head -1 || echo "")
fi

UPDATE_AVAILABLE="false"

# 策略 2: git ls-remote 兜底
if [ -z "$LATEST_VERSION" ]; then
  LOCAL_HASH=$(cd "$MH_ROOT" && git rev-parse HEAD 2>/dev/null || echo "")
  # 第一次尝试：当前 remote
  RAW=$(cd "$MH_ROOT" && git ls-remote origin HEAD 2>/dev/null || true)
  REMOTE_HASH=$(echo "$RAW" | awk 'NR==1{print $1}')

  # 失败则切到备用协议
  if [ -z "$REMOTE_HASH" ] && [ -n "$LOCAL_HASH" ]; then
    echo "  WARNING: $PROTO remote $REMOTE_URL unreachable, retrying with $([ "$PROTO" = "ssh" ] && echo https || echo ssh)..." >&2
    SAVED_REMOTE="$REMOTE_URL"
    (cd "$MH_ROOT" && git remote set-url origin "$ALT_REMOTE" >/dev/null 2>&1) || true
    RAW=$(cd "$MH_ROOT" && git ls-remote origin HEAD 2>/dev/null || true)
    REMOTE_HASH=$(echo "$RAW" | awk 'NR==1{print $1}')
    # 还原 remote
    (cd "$MH_ROOT" && git remote set-url origin "$SAVED_REMOTE" >/dev/null 2>&1) || true
  fi

  if [ -n "$REMOTE_HASH" ] && [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
    LATEST_VERSION="newer (commit differs)"
    UPDATE_AVAILABLE="true"
  else
    LATEST_VERSION="$CURRENT_VERSION"
    UPDATE_AVAILABLE="false"
  fi
else
  if [ "$CURRENT_VERSION" != "$LATEST_VERSION" ]; then
    UPDATE_AVAILABLE="true"
  else
    UPDATE_AVAILABLE="false"
  fi
fi

echo "CURRENT=$CURRENT_VERSION"
echo "LATEST=$LATEST_VERSION"
echo "UPDATE_AVAILABLE=$UPDATE_AVAILABLE"

if [ "$UPDATE_AVAILABLE" = "true" ]; then
  echo ""
  echo "=============================================="
  echo "  Meta-Harness update available!"
  echo "  Current: $CURRENT_VERSION"
  echo "  Latest:  $LATEST_VERSION"
  echo ""
  echo "  To update:"
  echo "    bash meta-harness/scripts/update-harness.sh"
  echo "=============================================="
fi
