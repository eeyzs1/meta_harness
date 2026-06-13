#!/usr/bin/env bash
# check-version.sh — 检查 meta-harness 是否有更新
# 用法：bash meta-harness/scripts/check-version.sh
# 输出：当前版本 vs 远程最新版本，以及建议操作

set -euo pipefail

# 检测是否在 submodule 中
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MH_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

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

# 获取远程最新版本
# 策略 1: 如果是 GitHub，尝试 raw VERSION 文件
GITHUB_RAW=""
if echo "$REMOTE_URL" | grep -q "github.com"; then
  # 转换 HTTPS URL 或 git URL 到 raw URL
  RAW_URL=$(echo "$REMOTE_URL" | sed 's|https://github.com/|https://raw.githubusercontent.com/|' | sed 's|git@github.com:|https://raw.githubusercontent.com/|' | sed 's|\.git$||')
  RAW_URL="$RAW_URL/main/VERSION"
  
  LATEST_VERSION=$(curl -s --connect-timeout 5 "$RAW_URL" 2>/dev/null | tr -d ' \n\r' | head -1 || echo "")
else
  LATEST_VERSION=""
fi

# 策略 2: 如果策略 1 失败，用 git ls-remote
if [ -z "$LATEST_VERSION" ]; then
  # git ls-remote 不能直接读文件内容，只能比较 commit hash
  LOCAL_HASH=$(cd "$MH_ROOT" && git rev-parse HEAD 2>/dev/null)
  REMOTE_HASH=$(cd "$MH_ROOT" && git ls-remote origin HEAD 2>/dev/null | awk '{print $1}' || echo "")
  
  if [ -n "$REMOTE_HASH" ] && [ "$LOCAL_HASH" != "$REMOTE_HASH" ]; then
    LATEST_VERSION="newer (commit differs)"
    UPDATE_AVAILABLE="true"
  else
    LATEST_VERSION="$CURRENT_VERSION"
    UPDATE_AVAILABLE="false"
  fi
else
  # 比较版本号
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