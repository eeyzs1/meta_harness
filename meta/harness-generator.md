# Meta-Harness-Generator: Task → Executable Harness Project

## Purpose
Generate a COMPLETE, RUNNABLE, SELF-EVOLVING harness engineering project.
Not documents. Not descriptions. An executable system with all seven layers.

## What Gets Generated
A full project in `generated/[project-name]/` that includes:

### Layer 1: Context Engineering
- AGENTS.md / CLAUDE.md — project-specific context files (AGENTS.md now slim: ~40 lines bootstrap)
- Dynamic context loader — `meta/phase-loader.md` (Phase-level lazy loading, never load all rules at once)
- Knowledge index — maps which files contain what knowledge
- **NEW: Run modes** — fast (skip review) / full (default) / deep (+research +pair-review), set via `project.yaml` → `run_mode` (CONCEPTUAL — `project.yaml` not yet emitted)

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
- **NEW: Phase-aware Layer Activation** — layers activate differently per phase (plan/implement/test/audit)
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

1. **Read task definition** from interpreter output
2. **Select base template** from `templates/` as reference (NOT as starting point)
3. **For each layer**: analyze what the task requires, generate ONLY what's needed
4. **Wire layers together**: ensure each layer references the others correctly
5. **Generate entry points**: AGENTS.md, CLAUDE.md, main execution scripts
6. **Generate evolution system**: adapted to the task's specific metrics
7. **Verify completeness**: every layer has at least one concrete artifact

## Phase-Aware Layer Activation Strategy

When generating the harness, layers are NOT all active at all times. Each layer activates differently depending on the execution phase. The generator produces a `phase-activation.yaml` config that controls this:

```yaml
# Generated per-project: which layers are active in which phase
phases:
  plan:
    active_layers:
      - layer1_context        # AGENTS.md, knowledge index
      - layer3_memory         # STATE.md, ROADMAP.md templates
      - layer4_planning       # DAG builder, leaf protocol
      - layer6_feedback       # Memory preload
    active_seeds:
      - planning/leaf-protocol.md
      - planning/dag-builder.py
      - memory/snapshot.py

  implement:
    active_layers:
      - layer2_tools          # Tool schemas, permissions
      - layer4_planning       # Sub-agent dispatcher, leaf protocol
      - layer5_verification   # Quality gate, anti-mock
      - layer7_constraints    # Architecture rules, linter
    active_seeds:
      - planning/leaf-protocol.md
      - planning/sub-agent-dispatch.yaml
      - verification/quality-gate.py
      - verification/anti-mock-check.py

  test:
    active_layers:
      - layer5_verification   # Full verification suite
      - layer6_feedback       # Error capture, retry
      - observability         # Transcript blocks, tracing
    active_seeds:
      - verification/recovery-and-audit.md
      - verification/quality-gate.py
      - verification/self-check.py
      - observability/transcript-blocks.md

  audit:
    active_layers:
      - layer5_verification   # Audit protocol
      - layer3_memory         # STATE.md update
      - observability         # AUDIT_* transcript blocks
      - security              # Audit log
    active_seeds:
      - verification/recovery-and-audit.md
      - observability/transcript-blocks.md
      - security/audit-log.yaml
```

### Activation Rules
1. **Layer 1 (Context)** is always active — every phase needs context
2. **Layer 7 (Constraints)** is always active — every phase respects constraints
3. **Cross-cutting concerns** (Security, Observability) are always active
4. **Layer 4 (Planning)** is most active in `plan` and `implement` phases
5. **Layer 5 (Verification)** peaks in `test` and `audit` phases
6. **Layer 6 (Feedback)** activates reactively — on failure, not on success

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
> auto-generated.

```
generated/[project-name]/
├── .harness-generated     ← Marker file (prevents accidental rmtree on non-harness dirs)
├── AGENTS.md              ← Project context + execution protocol (auto-loaded by AI IDEs)
├── CLAUDE.md              ← Redirect to AGENTS.md (Claude Code)
├── .cursorrules           ← Redirect to AGENTS.md (Cursor)
├── task.yaml              ← The locked task definition from INTERPRET
├── orchestrator.py        ← Layer 4 entry point: --status/--verify/--mark-complete/--evolve
├── guard.py               ← Layer 5 entry point: --check pre-code guard
├── project.yaml           ← CONCEPTUAL (not yet emitted; see note above)
├── phase-activation.yaml  ← CONCEPTUAL (not yet emitted; see strategy above)
├── STATE.md               ← CONCEPTUAL (not yet emitted; use memory/session-state.yaml)
├── ROADMAP.md             ← CONCEPTUAL (not yet emitted; use task.yaml)
├── src/                   ← Domain-specific source layout (e.g. src/api, src/services)
├── tests/                 ← Test directory
├── context/               ← Layer 1: Context Engineering (seed artifacts)
├── tools/                 ← Layer 2: Tool Integration (seed artifacts)
├── memory/                ← Layer 3: Memory & State
│   ├── session-state.yaml ←   Progress, completed/failed criteria, guard_log
│   └── long-term/         ←   Long-term memory (.gitkeep)
├── planning/              ← Layer 4: Planning & Orchestration (seed artifacts)
├── verification/          ← Layer 5: Verification & Guardrails (seed artifacts)
│   └── format-validators/ ←   JSON schemas (api-contract, config)
├── feedback/              ← Layer 6: Feedback & Self-Healing (seed artifacts)
├── constraints/           ← Layer 7: Constraints & Entropy (seed artifacts)
├── security/              ← Cross-cutting: Security & Isolation (seed artifacts)
├── observability/         ← Cross-cutting: Observability & Governance (seed artifacts)
├── evolution/             ← Self-Evolution System
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
