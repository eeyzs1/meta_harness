# Changelog

All notable changes to Meta-Harness are documented in this file.
Format based on [Keep a Changelog](https://keepachangelog.com/), adheres to
[Semantic Versioning](https://semver.org/).

## [2.4.0] — 2026-06-22

### Added
- **`--interpret-intent` flag** on `meta/meta-orchestrator.py`: scripted INTERPRET
  entry point. Runs `scripts/interpret.py` on a raw intent string, writes
  `task.yaml`, and locks the resulting acceptance criteria in one command.
- **`--advance` auto-run**: `--advance` now automatically executes the next
  phase's script after advancing (generate.py / agent-factory.py /
  verify-generation.py / judge.py / evolve.py). The pipeline can now run
  end-to-end with a chain of `--advance` calls.
- **`--no-auto-run` flag**: skips auto-execution when you want to run phase
  scripts manually (restores pre-2.4 `--advance` behavior).
- **`scripts/agent-factory.py`**: scripted FACTORY phase. Reads task.yaml +
  planning configs, generates per-role agent configs + topology YAML.
- **`scripts/judge.py`**: scripted JUDGE phase. Reads acceptance criteria +
  session-state, produces verdict (PROVEN / NOT_PROVEN / INSUFFICIENT_EVIDENCE)
  with exit codes (0 / 1 / 2).
- **interpret.py deepening**: quality-attribute extraction, explicit constraint
  extraction (must / must not / forbidden), explicit acceptance-criteria
  extraction, unknowns derived from missing info, assumptions derived from
  classification evidence. New output fields: `quality_attributes`,
  `hard_constraints`, `soft_constraints`.
- **evolve.py context-awareness**: detects meta-harness vs generated-project
  context. In generated projects, reads `memory/session-state.yaml` for
  `completed_criteria` and `guard_log` verification failures.
- **evolve.py substantive mutations**: ADD_CONSTRAINT generates concrete rules
  from evidence; STRENGTHEN_CONSTRAINT appends verification enforcement;
  WEAKEN_CONSTRAINT downgrades "must" to "should".

### Changed
- **`--advance` behavior** (BREAKING): now auto-runs the next phase script.
  Use `--no-auto-run` to restore the old manual behavior.
- **`consistency-check.py` scan scope** (BREAKING): now scans only `src/`
  instead of the entire project tree. Prevents false positives on the harness's
  own scripts. Projects without `src/` get a warning instead of a full scan.
- **`harness-generator.md` documentation**: `project.yaml`, `phase-activation.yaml`,
  `STATE.md`, `ROADMAP.md`, `skills/` directory now marked as CONCEPTUAL
  (design targets not yet auto-generated). Output Structure tree updated to
  match what `generate.py` actually emits.
- **`interpret.py` output structure**: added `quality_attributes`,
  `hard_constraints`, `soft_constraints` fields. Existing fields unchanged
  (backward compatible).

### Fixed
- **entropy-reduction.py argument bug** (BLOCKING): `orchestrator.py` passed
  `--check-only` but the script only accepts `--dry-run` / `--fix`. This caused
  `--verify` to always fail → `--mark-complete` always rejected → acceptance
  criteria could never complete. Fixed to pass `--dry-run`.
- **evolve.py path bug**: evolve.py only worked in the meta-harness context
  (read `meta/pipeline-state.yaml`). In generated projects it found no evidence
  and proposed no mutations. Fixed with context detection.
- **evolve.py superficial mutations**: mutations appended text labels
  ("(strengthened)") instead of modifying constraint logic. Fixed to make
  substantive rule changes.
- **`.cursorrules` generation**: `generate.py` now emits `.cursorrules`
  (redirect to AGENTS.md) so Cursor users get automatic rule loading.
- **`rmtree` safety**: `generate.py` writes a `.harness-generated` marker file
  and refuses to delete directories without it. Prevents accidental data loss.
- **`verify-generation.py` syntax check**: now uses `py_compile` for real
  syntax validation instead of just checking file existence.
- **`force_phase` stale evidence**: `--force-phase` now resets
  `verified_criteria` so stale evidence from a prior run doesn't mislead.
- **`verify_criterion` whitespace matching**: criteria matching now normalizes
  whitespace so YAML round-trip differences don't break verification.

### Upgrade Guide

1. Run `powershell scripts/check-version.ps1` (Windows) or
   `bash scripts/check-version.sh` (Linux/Mac) to confirm update is available.
2. Run `powershell scripts/update-harness.ps1` (Windows) or
   `bash scripts/update-harness.sh` (Linux/Mac) to update.
3. **If you have an in-progress pipeline**, reset it:
   `python meta/meta-orchestrator.py --reset`
4. **If you rely on manual `--advance` behavior** (no auto script execution),
   add `--no-auto-run` to your `--advance` calls.
5. **If you have downstream scripts parsing `task.yaml`**, they will still work
   — new fields (`quality_attributes`, `hard_constraints`, `soft_constraints`)
   are additive. Strict-schema validators may need updating.

## [2.3.0] — 2026-06 (initial structured release)

- 6-phase pipeline: INTERPRET → GENERATE → FACTORY → PROVE → JUDGE → EVOLVE
- PHASE_BRIEF.md context-loss recovery mechanism
- Acceptance criteria locking for task-drift prevention
- 7-layer + 2 cross-cutting + self-evolution architecture
- Domain templates: web-app, api-service, automation, data-pipeline, content-system
- Version check + self-update scripts (Windows + Linux/Mac)
