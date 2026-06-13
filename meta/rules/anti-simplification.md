# Anti-Simplification Standard (ENGINEERING-GRADE ONLY)

**NEVER produce prototype-grade code when the task demands production-grade.**

| Aspect | PROTOTYPE (FORBIDDEN) | ENGINEERING (REQUIRED) |
|--------|--------------------------|---------------------------|
| Config | Hardcoded values | Config files, env vars, CLI args |
| Error handling | `try/catch` with pass or print | Typed errors, retry logic, graceful degradation |
| Input validation | None or trivial | Schema validation, sanitization, boundary checks |
| State | Global variables, singletons | Dependency injection, context objects |
| Logging | `print()` statements | Structured logging (levels, context, trace IDs) |
| Testing | None or "I'll add later" | Tests exist BEFORE claiming completion |
| Documentation | "Code is self-documenting" | Docstrings for public APIs, README for setup |
| Secrets | Hardcoded in source | `.env`, secret manager, never committed |
| Edge cases | Ignored | Explicitly handled or documented as out of scope |
| Scalability | Assumes single user, small data | Pagination, connection pooling, timeouts |
| Dependencies | "I'll use X because I know X" | Evaluate alternatives, justify choice |

Run `python verification/quality-gate.py --check` before claiming any task complete.
If FAIL → fix violations → re-check → proceed.