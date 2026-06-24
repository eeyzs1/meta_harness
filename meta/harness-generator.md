# Meta-Harness-Generator: Task → Executable Harness Project

## Purpose
Generate a COMPLETE, RUNNABLE, SELF-EVOLVING harness engineering project.
Not documents. Not descriptions. An executable system with all seven layers.

## What Gets Generated
A full project in `generated/[project-name]/` that includes:

### Layer 1: Context Engineering
- AGENTS.md / CLAUDE.md — project-specific context files (AGENTS.md now slim: ~40 lines bootstrap)
- Dynamic context loader — `meta/phase-loader.md` (Phase-level lazy loading, never load all rules at once)
- Knowledge index — maps which files contain what knowledge (v2: 每条 mapping 为 `{description, tags}` dict，支持 loader.py 多信号排序检索)
- **运行时契约** — `harness-profile.yaml`（已实现，替换原 CONCEPTUAL 的 `run_mode` 设计）：tier (minimal/standard/full) 由 S/C/N/K 推导，驱动 ARTIFACT_GATE 裁剪与 agent 拓扑。原 fast/full/deep run_mode 概念已推翻，replaced by S/C/N/K tier

### Layer 2: Tool Integration
- Tool schema definitions (OpenAPI/function-call format)
- Sandbox config (Docker/container config if applicable)
- Permission manifests (what each agent role can access)
- MCP server configs (if applicable)
- **NEW: Tool discovery engine** (`tool-discovery.py`) — evaluates alternatives before adopting tools

### Layer 3: Memory & State
- Session state files (progress, checkpoints)
- Long-term memory structure (vector DB config or file-based index)
- Snapshot/rollback mechanism (git-based)
- Memory compression rules (what to keep, what to summarize, what to forget)
- **NEW: STATE.md template** — human-readable phase progress tracking with Failure Log and Audit Results (CONCEPTUAL — not yet emitted; use `memory/session-state.yaml`)
- **NEW: ROADMAP.md template** — full plan with phases, assumptions, risks, deliverables, acceptance criteria (CONCEPTUAL — not yet emitted; use `task.yaml`)

### Layer 3.5: Phase-Aware Skills
- **10 skills with full SKILL.md definitions** in `seeds/skills/` (loaded on demand by the phase loader; NOT copied into each generated project)
- PLAN phase: `brainstorming` (design before code) + `writing-plans` (zero-context implementation plans)
- IMPLEMENT phase: `tdd` (test-first) + `subagent-driven-dev` (parallel task dispatch + 2-stage review) or `executing-plans` (fallback)
- TEST phase: `code-review` + `verification` (evidence-before-claims) + `systematic-debugging` (root cause first, on failure)
- Cross-phase: `dispatching-parallel-agents` (multiple independent problem domains)
- Post-audit: `finishing-a-development-branch` (merge/PR/cleanup)

### Layer 4: Planning & Orchestration
- Task decomposition engine (DAG builder script)
- Execution flow controller (sequential, parallel, conditional, retry)
- Sub-agent dispatcher (role routing config)
- Reasoning budget config (step limits, time limits, token limits)
- **NEW: Leaf Protocol** (`leaf-protocol.md`) — Supervisor/Leaf two-level dispatch with standardized task.json/result.json
- **Layer Activation (已实现)** — 层裁剪在生成时由 `ARTIFACT_GATE` 按 S/C/N/K 因子驱动（替换原 CONCEPTUAL 的 per-phase `phase-activation.yaml` 设计）；运行时契约写入 `harness-profile.yaml`
- **NEW: Planner Engine** (`planner-engine.md`) — 8-stage planning pipeline (Env Detection → Handoff)
- **NEW: Executor Engine** (`executor-engine.md`) — Phase execution loop with 3-Strike recovery
- **NEW: Protocol Template** (`protocol-template.md`) — Agent execution protocol (PROTOCOL.md) for generated projects
- **NEW: Phase Spec Template** (`phase-spec-template.md`) — Standardized phase specification format

### Layer 5: Verification & Guardrails
- Output format validators (JSON/XML schema files)
- Logic consistency checks (test configs, linter rules)
- Security guardrails (sensitive data filters, dangerous operation blockers)
- Self-verification loop script (execute → check → reflect → fix)
- **NEW: Anti-mock check** (`anti-mock-check.py`) — scans all code for mock/fake/stub/simulated patterns
- **NEW: Quality gate** (`quality-gate.py`) — enforces engineering-grade standards before completion
- **NEW: 3-Strike Recovery Protocol** (`recovery-and-audit.md`) — structured failure escalation: probe → fix spec → handoff
- **NEW: Final Audit Protocol** — closes the self-report loophole: re-verify against original ROADMAP, max 3 audit rounds
- **NEW: Auditor Engine** (`auditor-engine.md`) — Independent audit engine: re-verify all phases against original ROADMAP
- **NEW: Baseline Diff Check** (`baseline-diff-check.md`) — Detect unexpected file changes outside Phase spec deliverables

### Layer 6: Feedback & Self-Healing
- Error capture and parser (structured error format)
- Auto-retry with backoff strategy config
- Error→constraint optimization loop (mistakes.md → constraints/)
- Human intervention interface (approval queue, escalation config)
- **NEW: Proactive execution driver** — auto-advance through pipeline without manual prompts

### Layer 7: Constraints & Entropy Management
- Architecture constraint rules (dependency direction, layer rules)
- Code enforcement configs (custom linter rules, pre-commit hooks)
- Entropy reduction schedule (cleanup scripts, consistency checks)
- Resource/cost constraints (budget config, rate limits, circuit breakers)

### Cross-Cutting: Security & Isolation
- Environment isolation config (sandbox, network rules)
- Data security rules (encryption, masking, access control)
- Audit log config (traceability, immutability)

### Cross-Cutting: Observability & Governance
- Tracing config (call chains, timing, token consumption)
- Metrics dashboard config (success rate, error rate, latency, cost)
- Session replay config (conversation reconstruction, issue reproduction)
- Version & config management (harness versioning, reproducibility)
- **NEW: Transcript Blocks** (`transcript-blocks.md`) — standardized execution markers (PHASE_START, PHASE_VERIFY, AUDIT_*, RUN_COMPLETE) for machine-parseable logs

### Self-Evolution System
- evolution/framework.md — evidence-driven evolution algorithm
- seeds/evolution/genome.yaml — current evolvable state (generation seed)
- seeds/evolution/log.yaml — evolution history (generation seed)
- Evolution triggers: periodic, reactive, emergency, adaptive

## Generation Steps

1. **Read task definition** from interpreter output（含 `complexity` 字段：S/C/N/K + tier）
2. **Select base template** from `templates/` as reference (NOT as starting point)
3. **Compute complexity profile** via `compute_profile(task)` — 缺省回退 `{S:3,C:3,N:3,K:3,standard}`（向后兼容旧 task.yaml）
4. **For each layer**: 按 `ARTIFACT_GATE` 谓词过滤 seed artifacts，仅复制因子需要的（核心层 always；可选层 verification/observability/feedback/security 按 S/C/N/K/tier 裁剪）。`copy_seed_artifacts(output_dir, layer, profile)` 实现
5. **Wire layers together**: ensure each layer references the others correctly
6. **Generate entry points**: AGENTS.md, CLAUDE.md, main execution scripts
7. **Preseed long-term memory** by Novelty — `preseed_long_term()`：N≤2 不预填 / N==3 Solid 阶段 / N≥4 Solid+Advanced 阶段（输出 known-patterns.yaml [+ anti-patterns.yaml]）
8. **Generate evolution system**: adapted to the task's specific metrics
9. **Write harness-profile.yaml** — `write_harness_profile()`：运行时契约（tier/factors/active_layers/active_artifacts/context_budget/agent_topology）
10. **Verify completeness**: `verify_completeness(output_dir, profile)` — 被 gate 裁剪的文件不计为 missing；最小可行 harness 边界（6 核心层 + agent≥3 + self-check.py + evolution 三件套）必在

## Complexity-Driven Adaptive Generation (S/C/N/K + ARTIFACT_GATE)

> **已实现**（替换原 CONCEPTUAL 的 `phase-activation.yaml` 与 `run_mode` 设计）。
> 第一性原理：harness 规模应按任务复杂度自适应，而非固定全量复制；
> 知识库应按 Novelty 差异化预填，而非 long-term 初始为空。
> 原 per-phase `phase-activation.yaml` 概念已推翻，replaced by S/C/N/K + ARTIFACT_GATE（生成时裁剪）+ harness-profile.yaml（运行时契约）。

### 1. 复杂度模型：difficulty 拆为 S/C/N/K 四正交因子

`scripts/interpret.py` 的 `classify_complexity()` 从 intent 推导四个正交因子（每因子 1-5）：

| 因子 | 含义 | 驱动 |
|------|------|------|
| Scope (S) | 独立关注点数 | agent 数、上下文预算 |
| Criticality (C) | 失效代价（不可逆性 × 爆炸半径） | 验证严格度、人工 gate |
| Novelty (N) | 距训练分布/已积累知识 | 知识库质量 |
| Coupling (K) | 跨组件咬合度 | 一致性检查、架构规则 |

派生 tier（粗粒度层裁剪派生量）：
- `minimal`: S≤2 ∧ C≤2 ∧ N≤2 ∧ K≤2
- `standard`: 默认
- `full`: S≥4 ∨ C≥4 ∨ N≥4

`task.yaml` 新增 `complexity` 字段：`{scope, criticality, novelty, coupling, tier}`。
旧 task.yaml 无此字段时回退 `{S:3,C:3,N:3,K:3,standard}`（≈ 全量复制，向后兼容）。

### 2. ARTIFACT_GATE：按因子裁剪 artifact

`scripts/generate.py` 的 `ARTIFACT_GATE` 谓词表，`copy_seed_artifacts(output_dir, layer, profile)` 按 profile 过滤：

| 层 | artifact | 谓词 |
|----|----------|------|
| verification | self-check.py | always |
| verification | consistency-check.py | K>=3 |
| verification | security-guardrails.yaml | C>=3 |
| verification | anti-mock-check.py | C>=3 or N>=3 |
| verification | quality-gate.py | C>=3 |
| observability | tracing.yaml | tier!='minimal' |
| observability | metrics-dashboard.yaml | tier!='minimal' |
| observability | session-replay.yaml | tier=='full' |
| observability | versioning.yaml | always |
| feedback | error-capture.py | always |
| feedback | retry-config.yaml | always |
| feedback | mistake-to-constraint.py | tier!='minimal' |
| feedback | human-interface.yaml | C>=4 |
| security | sandbox-config.yaml | tier!='minimal' |
| security | encryption-rules.yaml | C>=3 |
| security | audit-log.yaml | C>=4 |

**核心层**（context / memory / planning / constraints / evolution / tools）全部 `always`，不裁剪。
未列入 gate 的文件默认 `always`（保守，避免意外丢失）。
谓词解析失败默认复制（保守，避免意外丢失 artifact）。

**最小可行 harness 边界**（gate 内保证）：
- 6 核心层 artifact 必有
- agent 最少 3（planner + executor + verifier）
- verification 最少 self-check.py
- evolution 三件套（framework.md / genome.yaml / log.yaml）必在

### 3. harness-profile.yaml：运行时契约

`scripts/generate.py` 的 `write_harness_profile()` 写入项目根 `harness-profile.yaml`：

```yaml
version: 1
generated_at: <ISO timestamp>
tier: standard              # minimal | standard | full
factors:
  scope: 3
  criticality: 3
  novelty: 3
  coupling: 3
active_layers: [context, evolution, feedback, ...]   # 实际复制了 artifact 的层
active_artifacts: [context/loader.py, ...]            # 实际复制的文件清单
context_budget: 500          # 500 + 100×max(0,S-2) + 150×max(0,N-2)
agent_topology:
  estimated_count: 5         # planner + ⌈S/2⌉ executors + verifier + (C>=4?sec) + (K>=3?integ) + (N>=3?curator)
note: Structure fixed at generation; activation tuned at runtime via phase-activation.
```

**结构生成时定**（tier/factors/active_artifacts/context_budget），**激活运行时调**（`loader.py` / `agent-factory.py` 读此文件）。
`harness-profile.yaml` 缺失时运行时视为 `standard`（向后兼容）。

### 4. preseed_long_term：按 N 预填知识库

`scripts/generate.py` 的 `preseed_long_term()` 按 Novelty 差异化预填 `memory/long-term/`：

| Novelty | 预填内容 | 输出文件 |
|---------|----------|----------|
| N≤2 | 不预填（熟悉领域，多了是上下文污染） | 仅 .gitkeep |
| N==3 | domain-advancements 的 Solid 阶段 innovations | known-patterns.yaml |
| N≥4 | Solid + Advanced 阶段，并从 trigger 字段生成反模式 | known-patterns.yaml + anti-patterns.yaml |

源数据来自 `seeds/evolution/domain-advancements-{template}.yaml`（回退 `domain-advancements.yaml`）。

### 5. agent-factory：从 S 推导 agent 拓扑

`scripts/agent-factory.py` 的 `derive_roles()` 从 `sub-agent-dispatch.yaml` 的 prototypes + profile 实例化：

| 角色 | count / condition |
|------|-------------------|
| planner | count: 1 |
| executor | count: `ceil(S/2)` |
| verifier | count: 1 |
| security-reviewer | condition: `C>=4` |
| integration-checker | condition: `K>=3` |
| knowledge-curator | condition: `N>=3` |

`compute_context_budget(S,N) = 500 + 100×max(0,S-2) + 150×max(0,N-2)`，写入每 agent 的 `boundaries.max_context_lines` 与 `agent-topology.yaml`。

`seeds/planning/sub-agent-dispatch.yaml` 为 v2 prototypes 格式（保留 `roles` 字段回退旧格式）。

### 6. loader.py：四职能分离

`seeds/context/loader.py` 重构为四职能（替代旧布尔关键词匹配）：

| 职能 | 职责 | 信号 |
|------|------|------|
| `inject(task, profile)` | 主动注入（高 N 注入 long-term 已知模式） | 静态预载 |
| `retrieve(task, index, profile)` | 被动检索 | 三信号加权：path-prefix +3 / domain-tag +2 / keyword overlap +1（封顶 +2） |
| `active_constraints(profile)` | 约束（gate 校验规则） | architecture-rules.yaml |
| `recall(task, profile)` | 记忆（session-state + evolution log） | 历史回放 |

`knowledge-index.yaml` 升级为 v2：每条 mapping 为 `{description, tags}` dict，支持多信号排序检索。旧格式（字符串值）自动包装为 `{description: <str>, tags: []}`（向后兼容）。

### 7. 向后兼容

- `task.yaml` 的 `complexity` 字段可选，旧 task 默认 `{S:3,C:3,N:3,K:3,standard}` ≈ 全量复制
- `harness-profile.yaml` 缺失时运行时（loader.py / agent-factory.py）视为 `standard`
- `sub-agent-dispatch.yaml` 旧格式（`roles`）在无 `prototypes` 时回退使用
- `knowledge-index.yaml` 旧格式（字符串值）自动包装为 v2 dict

## Single-File Configuration (project.yaml) — CONCEPTUAL

> **Note:** `project.yaml` is a design target. The current `scripts/generate.py`
> does NOT yet emit a `project.yaml`; configuration is spread across the
> per-layer YAML files copied from `seeds/`. When a future generator upgrade
> adds `project.yaml` emission, the per-layer files should be derived from it.

In addition to the layered YAML configs, the generator produces a `project.yaml` as the single source of truth. All other configs reference this file:

```yaml
# project.yaml — Single Source of Truth
# All components (AGENTS.md, orchestrator, adapters) read from here.
# Minimum: just project.name + repos to start.

project:
  name: "{{PROJECT_NAME}}"
  description: "{{PROJECT_DESCRIPTION}}"

repos:
  - name: main
    path: "."
    language: "{{LANGUAGE}}"
    build_command: "{{BUILD_COMMAND}}"
    typecheck_command: "{{TYPECHECK_COMMAND}}"
    lint_command: "{{LINT_COMMAND}}"
    test_command: "{{TEST_COMMAND}}"

adapters:
  work_item:
    type: "file"          # file | github-issues | jira
  ci:
    type: "noop"          # noop | github-actions
  executor:
    type: "sub-agent"     # sub-agent | claude-goal | codex-task

phases: [plan, implement, test]

quality_gates:
  - name: lint
    command: "lint_command"
  - name: typecheck
    command: "typecheck_command"
  - name: test
    command: "test_command"

phase_skills:
  plan:
    - brainstorming
    - writing-plans
  implement:
    - tdd
    - subagent-driven-dev
  test:
    - code-review
    - verification
    - systematic-debugging

memory:
  enabled: true
  dir: ".meta-harness/memory"
```

See `seeds/planning/project-yaml-template.yaml` for the full template with all options.

## Output Structure

> This tree reflects what `scripts/generate.py` actually emits. Items marked
> `CONCEPTUAL` are described above as design targets but are NOT yet
> auto-generated. Items gated by `ARTIFACT_GATE` are conditionally emitted
> based on the S/C/N/K complexity profile (see above).

```
generated/[project-name]/
├── .harness-generated     ← Marker file (prevents accidental rmtree on non-harness dirs)
├── AGENTS.md              ← Project context + execution protocol (auto-loaded by AI IDEs)
├── CLAUDE.md              ← Redirect to AGENTS.md (Claude Code)
├── .cursorrules           ← Redirect to AGENTS.md (Cursor)
├── task.yaml              ← The locked task definition from INTERPRET (含 complexity: S/C/N/K + tier)
├── harness-profile.yaml   ← 运行时契约：tier/factors/active_layers/active_artifacts/context_budget/agent_topology
├── orchestrator.py        ← Layer 4 entry point: --status/--verify/--mark-complete/--evolve
├── guard.py               ← Layer 5 entry point: --check pre-code guard
├── project.yaml           ← CONCEPTUAL (not yet emitted; see note above)
├── STATE.md               ← CONCEPTUAL (not yet emitted; use memory/session-state.yaml)
├── ROADMAP.md             ← CONCEPTUAL (not yet emitted; use task.yaml)
├── src/                   ← Domain-specific source layout (e.g. src/api, src/services)
├── tests/                 ← Test directory
├── context/               ← Layer 1: Context Engineering (seed artifacts, always)
├── tools/                 ← Layer 2: Tool Integration (seed artifacts, always)
├── memory/                ← Layer 3: Memory & State
│   ├── session-state.yaml ←   Progress, completed/failed criteria, guard_log
│   └── long-term/         ←   按 N 预填：.gitkeep (N≤2) / known-patterns.yaml (N==3) / +anti-patterns.yaml (N≥4)
├── planning/              ← Layer 4: Planning & Orchestration (seed artifacts, always)
├── verification/          ← Layer 5: Verification & Guardrails (ARTIFACT_GATE 裁剪；self-check.py 必在)
│   └── format-validators/ ←   JSON schemas (api-contract, config)
├── feedback/              ← Layer 6: Feedback & Self-Healing (ARTIFACT_GATE 裁剪；error-capture/retry 必在)
├── constraints/           ← Layer 7: Constraints & Entropy (seed artifacts, always)
├── security/              ← Cross-cutting: Security & Isolation (ARTIFACT_GATE 裁剪)
├── observability/         ← Cross-cutting: Observability & Governance (ARTIFACT_GATE 裁剪；versioning 必在)
├── evolution/             ← Self-Evolution System (三件套必在)
│   ├── framework.md       ←   Evolution algorithm description
│   ├── genome.yaml        ←   Current evolvable state
│   ├── log.yaml           ←   Evolution history
│   ├── innovation-engine.py ← Product analysis + innovation proposals
│   └── domain-advancements.yaml ← Domain-specific advancement seeds
└── scripts/               ← Executable scripts
    └── evolve.py          ←   Evolution engine (copied from meta-harness)
```

> **Not yet auto-generated** (referenced conceptually above): `skills/` directory
> (skills live in the meta-harness `seeds/skills/` and are loaded on demand by
> the phase loader, not copied into each generated project), and the shell
> helpers `claim-run.sh` / `detect-env.sh` / `detect-stack.sh` /
> `summarize-repo.sh` / `repo-state.sh` / `validate-phase.sh`.

## Anti-Patterns
- Do NOT generate documentation-only layers — every layer must have executable artifacts
- Do NOT generate boilerplate — only what the specific task requires
- Do NOT skip layers — even minimal implementations are required
- Do NOT generate without evidence traceability — every artifact traces to a requirement
- **NEW: Do NOT generate mock/fake/stub implementations** — if the task requires real integration, generate real API client code. If API keys are missing, flag as blocker.
- **NEW: Do NOT generate prototype-grade shortcuts** — every generated artifact must meet engineering standards (config-driven, error-handled, validated, tested)
- **NEW: Do NOT generate without tool evaluation** — for each tool/library choice, include a justification comment referencing alternatives considered
