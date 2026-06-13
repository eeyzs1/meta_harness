# 引用式部署方案 — Git Submodule

## 问题

当前方案：复制粘贴框架文件到每个项目。框架更新后，已有项目不受益。

## 方案：Git Submodule

```
your-project/
├── AGENTS.md              ← 10行引导文件，引用 submodule（唯一需复制的文件）
├── meta-harness/          ← git submodule → meta-harness 仓库（框架代码）
│   ├── AGENTS.md          ← 完整操作指令
│   ├── meta/              ← 解释器、生成器、工厂
│   ├── seeds/             ← 所有种子模板
│   └── scripts/           ← 所有脚本
├── .meta-harness/         ← 本地专属（不提交到 submodule）
│   ├── project.yaml       ← 唯一需编辑的文件
│   ├── runs/              ← 运行时产物
│   └── memory/            ← 项目记忆
└── .gitmodules
```

---

## 新项目初始化

```bash
# 1. 进入你的项目根目录
cd ~/my-project

# 2. 添加 meta-harness 为 submodule
git submodule add https://github.com/your-org/meta-harness.git meta-harness

# 3. 运行初始化脚本
bash meta-harness/scripts/init-harness-submodule.sh

# 4. 编辑 .meta-harness/project.yaml
#    - 设置 project.name
#    - 设置 repos
#    - 选择 adapters

# 5. 提交
git add meta-harness .meta-harness AGENTS.md .gitmodules
git commit -m "Add meta-harness framework"
```

---

## 框架更新

```bash
# Linux/Mac
bash meta-harness/scripts/update-harness.sh

# Windows
powershell meta-harness/scripts/update-harness.ps1
```

Agent 会在每次启动时自动检测更新并执行（见 AGENTS.md 第 1 步）。

---

## 已有项目迁移（从复制粘贴到 submodule）

```bash
# Linux/Mac
cd ~/my-old-project
bash meta-harness/scripts/migrate-legacy.sh

# Windows
cd ~/my-old-project
powershell meta-harness/scripts/migrate-legacy.ps1
```

迁移脚本做 5 步：备份 → 清理旧框架文件 → 添加 submodule → 恢复本地文件 → 生成项目级 AGENTS.md。

如果还没有 meta-harness 目录（还没有 submodule），先从 meta-harness 仓库复制 migrate-legacy 脚本到项目根，再运行。

---

## 目录职责

| 路径 | 谁拥有 | 更新方式 |
|------|--------|----------|
| `meta-harness/` | 框架（submodule） | `git pull` in submodule |
| `.meta-harness/project.yaml` | 你 | 手动编辑 |
| `.meta-harness/runs/` | 运行时 | 自动生成 |
| `.meta-harness/memory/` | 运行时 | 自动生成 + 手动审查 |
| `AGENTS.md` | 引导文件 | init 时生成，通常不改 |

---

## 锁定版本（可选）

```bash
# 锁定到特定 tag/commit
cd meta-harness
git checkout v2.1.0
cd ..
git add meta-harness
git commit -m "Pin meta-harness to v2.1.0"
```

推荐：在稳定版本上用 tag 锁定。需要新特性时手动升级，而不是自动拉最新。