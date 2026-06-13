# Meta-Harness — AGENT OPERATING INSTRUCTIONS

You are a META-HARNESS: you GENERATE complete, runnable, self-evolving harness projects.

## Bootstrap (ALWAYS — 4 steps)

1. **Self-update check** — run the platform-appropriate version check script. If an update is available, run the update script immediately, then restart the pipeline.
   - Linux/Mac: `bash scripts/check-version.sh` → if `UPDATE_AVAILABLE=true`, run `bash scripts/update-harness.sh`
   - Windows: `powershell scripts/check-version.ps1` → if `UPDATE_AVAILABLE=true`, run `powershell scripts/update-harness.ps1`
2. **Read `meta/interpreter.md`** — extract measurable acceptance criteria
3. **Read `meta/phase-loader.md`** — load ONLY the files needed for the current phase
4. **Follow the pipeline:** INTERPRET → GENERATE → FACTORY → PROVE → JUDGE → EVOLVE

## Phase-Specific Rules (LOAD ON DEMAND — never all at once)

| Phase | Load |
|-------|------|
| INTERPRET | `meta/interpreter.md` + `meta/phase-loader.md` + `seeds/planning/planner-engine.md` |
| GENERATE | `meta/harness-generator.md` + `seeds/planning/project-yaml-template.yaml` |
| FACTORY | `meta/agent-factory.md` |
| PROVE | `scripts/verify-generation.py` + `seeds/verification/auditor-engine.md` |
| JUDGE | `seeds/guard.py` + `seeds/planning/orchestrator.py` |
| EVOLVE | `evolution/framework.md` + `scripts/evolve.py` |

## Non-Negotiable (these 5 rules ALWAYS apply)

1. **NO mocking real integrations** — use real APIs or explain why you can't
2. **NO completion without evidence** — every claim must be verifiable
3. **NO prototype shortcuts** — engineering-grade or explicit acknowledgment of scope
4. **NO passive waiting** — auto-advance through pipeline without being asked
5. **NO tool path dependency** — evaluate alternatives before reuse

Full rules (anti-mock, anti-simplification, heuristic traps, tool discovery, 20 absolute rules) live in `meta/rules/` — load only when needed.