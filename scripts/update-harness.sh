#!/usr/bin/env bash
# update-harness.sh — 一键更新 meta-harness submodule
# 用法：bash meta-harness/scripts/update-harness.sh
# 做三件事：git pull → migrate project.yaml → git commit

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MH_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$MH_ROOT/.." && pwd)"

echo "=== Meta-Harness Update ==="
echo ""

# Step 1: 检查是否 submodule
if [ ! -f "$PROJECT_ROOT/.gitmodules" ]; then
  echo "ERROR: No .gitmodules found. Is meta-harness installed as a submodule?" >&2
  echo "Run: git submodule add <url> meta-harness" >&2
  exit 1
fi

if ! grep -q "meta-harness" "$PROJECT_ROOT/.gitmodules" 2>/dev/null; then
  echo "ERROR: meta-harness not found in .gitmodules." >&2
  exit 1
fi

# Step 2: 记录当前版本
CURRENT_VERSION=$(cat "$MH_ROOT/VERSION" 2>/dev/null | tr -d ' \n\r' || echo "unknown")
echo "Current version: $CURRENT_VERSION"

# Step 3: Git pull
echo ""
echo "--- Pulling latest framework ---"
cd "$MH_ROOT"
git pull origin main
cd "$PROJECT_ROOT"

NEW_VERSION=$(cat "$MH_ROOT/VERSION" 2>/dev/null | tr -d ' \n\r')
echo "Updated to: $NEW_VERSION"

# Step 4: 迁移 project.yaml（如果 schema 版本变化）
if [ -f "$MH_ROOT/scripts/migrate.sh" ]; then
  echo ""
  echo "--- Migrating project configuration ---"
  bash "$MH_ROOT/scripts/migrate.sh" "$PROJECT_ROOT/.meta-harness/project.yaml" || true
fi

# Step 5: 提交更新
echo ""
echo "--- Committing update ---"
cd "$PROJECT_ROOT"
git add meta-harness
if [ -f ".meta-harness/project.yaml" ]; then
  git add .meta-harness/project.yaml
fi

# 检查是否有变更
if git diff --cached --quiet; then
  echo "No changes to commit (already up to date)."
else
  git commit -m "chore: update meta-harness $CURRENT_VERSION -> $NEW_VERSION"
  echo ""
  echo "=== Committed: meta-harness $CURRENT_VERSION -> $NEW_VERSION ==="
fi

echo ""
echo "Done. Framework is now at $NEW_VERSION."