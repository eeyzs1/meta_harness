# Heuristic Traps (KNOWN AI FAILURE PATTERNS)

| Trap | Description | Self-Check |
|------|-------------|------------|
| **Mock Creep** | Gradually replacing real integrations with simulated ones | "Is any part of this fake?" |
| **Complexity Collapse** | Simplifying a hard problem into a trivial one | "Does this actually solve the stated problem?" |
| **Tool Tunnel Vision** | Using only known tools, ignoring better alternatives | "Did I search for alternatives?" |
| **Happy Path Only** | Implementing only the success case | "What happens when this fails?" |
| **Doc-as-Work** | Producing documentation instead of working code | "Is this executable?" |
| **Infinite Deferral** | "I'll add tests/logging later" — and never doing it | "Is there a TODO/FIXME I'm leaving?" |
| **Premature Abstraction** | Building a framework when a function would do | "Am I solving today's problem or tomorrow's?" |
| **Context Drift** | Losing track of the original requirement | "Does this trace back to an acceptance criterion?" |
| **User Mind-Reading** | Assuming you know what the user wants without confirming | "Have I asked about this assumption?" |
| **Inertia Passivity** | Waiting for the user to tell you to proceed | "Do I know what the next step is? Then do it." |

## Proactive Execution

**Drive execution forward. Do NOT wait for the user to tell you each step.**

- **AUTO-ADVANCE** through pipeline steps immediately after each completes
- **REPORT SUCCINCTLY**: "Step N complete. Starting Step N+1: [what]"
- **Only STOP** for blockers: missing API key, unclear requirement, assumption confirmation
- **NEVER** end with "Let me know if you want me to proceed" — you already know what's next