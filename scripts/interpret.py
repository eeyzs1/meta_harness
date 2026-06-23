#!/usr/bin/env python3
"""
Interpreter: Intent → Structured Task Definition (First Principles)

Parses a raw intent string and produces a structured task definition
following the interpreter.md specification. This is the first step
of the compilation pipeline.

Deepening (v2.4):
  - Quality attribute extraction from intent (performance, security, ...)
  - Explicit constraint extraction (must / must not / required / forbidden)
  - Explicit acceptance-criteria extraction (user-stated "must support X")
  - Domain criteria merged with explicit criteria (deduped)
  - Unknowns derived from what the intent does NOT state (stack, auth, deploy)
  - write_task_file() helper for meta-orchestrator integration

Usage:
    python scripts/interpret.py --intent "I need a customer onboarding system"
    python scripts/interpret.py --intent-file intent.txt
    python scripts/interpret.py --intent "..." --output task.yaml
"""

import argparse
import re
import sys
from pathlib import Path

import yaml

DOMAIN_KEYWORDS = {
    "web-app": ["web app", "website", "frontend", "ui", "dashboard", "portal", "landing page", "spa"],
    "api-service": ["api", "rest", "graphql", "backend", "microservice", "endpoint", "server"],
    "automation": ["automate", "schedule", "cron", "workflow", "trigger", "monitor", "alert", "bot"],
    "data-pipeline": ["data pipeline", "etl", "ingest", "transform", "analytics", "warehouse", "batch"],
    "content-system": ["content", "blog", "cms", "publish", "article", "document", "newsletter"],
}

SCALE_KEYWORDS = {
    "personal": ["personal", "my", "i need", "simple", "just me"],
    "team": ["team", "our", "we need", "group", "department"],
    "organization": ["company", "organization", "enterprise", "everyone", "all employees"],
    "public": ["public", "users", "customers", "saas", "marketplace"],
}

# Quality attribute detection: maps keyword groups to attribute names.
QUALITY_ATTRIBUTE_KEYWORDS = {
    "performance": ["fast", "performance", "latency", "throughput", "responsive", "quick", "speed", "real-time", "realtime"],
    "security": ["secure", "security", "auth", "authentication", "authorization", "encryption", "gdpr", "compliance", "pci"],
    "scalability": ["scale", "scalable", "scalability", "high-availability", "ha", "cluster", "distributed", "horizontal"],
    "reliability": ["reliable", "reliability", "fault-tolerant", "resilient", "robust", "uptime", "sla"],
    "observability": ["monitor", "monitoring", "logging", "tracing", "metrics", "alerting", "dashboard"],
    "usability": ["usable", "usability", "accessible", "accessibility", "intuitive", "user-friendly", "a11y"],
    "maintainability": ["maintainable", "maintainability", "testable", "modular", "clean", "documented"],
    "cost": ["cheap", "low-cost", "budget", "cost-effective", "affordable", "free-tier"],
}

# Explicit constraint extraction: sentences/phrases stating hard rules.
CONSTRAINT_PATTERNS = [
    # "must not use X", "cannot use X", "no X allowed"
    (re.compile(r"(?:must not|cannot|can't|no)\s+use\s+(.+?)(?:[.;]|$)", re.IGNORECASE), "forbidden-tech"),
    (re.compile(r"(?:must not|cannot|can't)\s+(.+?)(?:[.;]|$)", re.IGNORECASE), "must-not"),
    (re.compile(r"(?:must|shall|required to)\s+(.+?)(?:[.;]|$)", re.IGNORECASE), "must"),
    (re.compile(r"(?:forbidden|prohibited|banned)\s*:\s*(.+?)(?:[.;]|$)", re.IGNORECASE), "forbidden"),
    (re.compile(r"(?:only|exclusively)\s+(?:use|support)\s+(.+?)(?:[.;]|$)", re.IGNORECASE), "only"),
]

# Explicit acceptance-criteria extraction: user-stated outcomes.
CRITERIA_PATTERNS = [
    re.compile(r"(?:must|should|need to|needs to|has to)\s+(?:support|allow|enable|provide|handle|be able to)\s+(.+?)(?:[.;]|$)", re.IGNORECASE),
    re.compile(r"(?:users?|customers?|system)\s+(?:should|must|will)\s+(?:be able to|be capable of)\s+(.+?)(?:[.;]|$)", re.IGNORECASE),
    re.compile(r"(?:support|supports|handle|handles)\s+(.+?)(?:[.;]|$)", re.IGNORECASE),
]


def classify_domain(intent: str) -> str:
    intent_lower = intent.lower()
    scores = {}
    for domain, keywords in DOMAIN_KEYWORDS.items():
        scores[domain] = sum(1 for kw in keywords if kw in intent_lower)
    best = max(scores, key=scores.get)
    return best if scores[best] > 0 else "web-app"


def classify_scale(intent: str) -> str:
    intent_lower = intent.lower()
    for scale, keywords in SCALE_KEYWORDS.items():
        if any(kw in intent_lower for kw in keywords):
            return scale
    return "team"


def extract_goal(intent: str) -> str:
    goal = intent.strip()
    prefixes = ["i need ", "i want ", "build ", "create ", "make ", "help me "]
    for prefix in prefixes:
        if goal.lower().startswith(prefix):
            goal = goal[len(prefix):].strip()
    return goal[0].upper() + goal[1:] if goal else "Complete the task"


def extract_quality_attributes(intent: str) -> list:
    """Detect quality attributes mentioned in the intent."""
    intent_lower = intent.lower()
    found = []
    for attr, keywords in QUALITY_ATTRIBUTE_KEYWORDS.items():
        if any(kw in intent_lower for kw in keywords):
            found.append(attr)
    return found


def extract_explicit_constraints(intent: str) -> tuple:
    """Extract hard and soft constraints explicitly stated in the intent.

    Returns (hard_constraints, soft_constraints) as lists of strings.
    """
    hard = []
    soft = []
    for pattern, kind in CONSTRAINT_PATTERNS:
        for match in pattern.finditer(intent):
            text = match.group(0).strip().rstrip(".;")
            if kind in ("must", "only"):
                hard.append(text)
            elif kind in ("must-not", "forbidden", "forbidden-tech"):
                hard.append(text)
            else:
                soft.append(text)
    # Dedupe while preserving order.
    hard = list(dict.fromkeys(hard))
    soft = list(dict.fromkeys(soft))
    return hard, soft


def extract_explicit_criteria(intent: str) -> list:
    """Extract acceptance criteria explicitly stated by the user.

    These override/supplement the domain-template criteria because they
    represent the user's actual stated outcomes, not generic defaults.
    """
    found = []
    for pattern in CRITERIA_PATTERNS:
        for match in pattern.finditer(intent):
            raw = match.group(1).strip().rstrip(".;")
            # Capitalize the captured outcome as a capability statement.
            criterion = raw[0].upper() + raw[1:] if raw else raw
            found.append(criterion)
    # Dedupe while preserving order.
    return list(dict.fromkeys(found))


def generate_acceptance_criteria(intent: str, domain: str) -> list:
    """Combine domain-template criteria with user-stated explicit criteria.

    Explicit criteria (stated by the user) come FIRST because they reflect
    actual intent; domain-template criteria follow as sensible defaults
    the user may not have thought to state.
    """
    explicit = extract_explicit_criteria(intent)

    template_criteria = {
        "api-service": [
            "API endpoints respond with correct status codes",
            "Input validation rejects invalid requests",
            "Error responses follow consistent format",
            "API documentation is auto-generated",
        ],
        "web-app": [
            "Users can complete the primary workflow end-to-end",
            "UI is responsive on mobile and desktop",
            "Authentication works correctly",
            "Build succeeds with no errors",
        ],
        "automation": [
            "Automation triggers correctly on events",
            "Actions produce expected results",
            "Error handling works (simulate failures)",
            "Manual override is available",
        ],
        "data-pipeline": [
            "Data is ingested without loss",
            "Transformations produce correct output",
            "Error records are quarantined, not dropped",
            "Pipeline completes within time budget",
        ],
        "content-system": [
            "Content follows style guide",
            "Review step catches quality issues",
            "Metadata is complete before publication",
            "Version history is maintained",
        ],
    }
    domain_criteria = template_criteria.get(domain, template_criteria["web-app"])

    # Merge: explicit first, then domain defaults that aren't already covered.
    # Dedupe by lowercase comparison so paraphrases don't double up.
    seen = {c.lower() for c in explicit}
    merged = list(explicit)
    for c in domain_criteria:
        if c.lower() not in seen:
            merged.append(c)
            seen.add(c.lower())
    return merged


def derive_unknowns(intent: str, domain: str, scale: str, quality_attrs: list) -> list:
    """Derive unknowns from what the intent does NOT state.

    Rather than a static list, surface gaps based on domain/scale/quality
    signals actually present in the intent.
    """
    intent_lower = intent.lower()
    unknowns = []

    # Tech stack: only flag as unknown if not mentioned.
    stack_terms = ["python", "javascript", "typescript", "node", "react", "vue", "go", "rust", "java", "c#", ".net", "fastapi", "django", "flask", "express"]
    if not any(t in intent_lower for t in stack_terms):
        unknowns.append("Exact technical stack preference")

    # Auth: flag unless explicitly mentioned.
    if not any(t in intent_lower for t in ["auth", "login", "sso", "oauth", "jwt", "session"]):
        unknowns.append("Authentication method")

    # Deployment: flag unless explicitly mentioned.
    if not any(t in intent_lower for t in ["deploy", "docker", "kubernetes", "k8s", "aws", "gcp", "azure", "cloud", "on-prem", "serverless"]):
        unknowns.append("Deployment target")

    # Data storage: relevant for most domains except pure content/automation.
    if domain in ("web-app", "api-service", "data-pipeline") and not any(
        t in intent_lower for t in ["database", "postgres", "mysql", "mongo", "redis", "sql", "dynamodb", "sqlite"]
    ):
        unknowns.append("Data storage choice")

    # Scale numbers: if scale is organization/public but no numbers given.
    if scale in ("organization", "public") and not re.search(r"\d+\s*(?:user|customer|request|qps|rps|record|row)", intent_lower):
        unknowns.append(f"Expected user/load volume for {scale} scale")

    # Security compliance: if security mentioned but no specific standard.
    if "security" in quality_attrs and not any(t in intent_lower for t in ["gdpr", "pci", "hipaa", "soc2", "iso27001"]):
        unknowns.append("Specific security/compliance standard required")

    return unknowns if unknowns else ["No specific unknowns detected — confirm assumptions with user"]


def derive_assumptions(intent: str, domain: str, scale: str, quality_attrs: list, hard_constraints: list) -> list:
    """Derive assumptions from the classification evidence."""
    assumptions = [
        f"Domain classified as {domain} based on intent keywords",
        f"Scale classified as {scale} based on intent keywords",
    ]
    if quality_attrs:
        assumptions.append(f"Quality attributes prioritized: {', '.join(quality_attrs)} (inferred from intent)")
    else:
        assumptions.append("No explicit quality attributes stated — defaulting to correctness + maintainability")
    if hard_constraints:
        assumptions.append(f"{len(hard_constraints)} hard constraint(s) extracted from intent text")
    assumptions.append("Acceptance criteria are initial suggestions — user should refine during INTERPRET confirmation")
    return assumptions


def interpret_intent(intent: str) -> dict:
    domain = classify_domain(intent)
    scale = classify_scale(intent)
    goal = extract_goal(intent)
    quality_attrs = extract_quality_attributes(intent)
    hard_constraints, soft_constraints = extract_explicit_constraints(intent)
    criteria = generate_acceptance_criteria(intent, domain)
    unknowns = derive_unknowns(intent, domain, scale, quality_attrs)
    assumptions = derive_assumptions(intent, domain, scale, quality_attrs, hard_constraints)

    task = {
        "name": goal[:80],
        "domain": domain.replace("-", "_"),
        "real_need": intent.strip(),
        "goal": goal,
        "scale": scale,
        "quality_attributes": quality_attrs,
        "hard_constraints": hard_constraints,
        "soft_constraints": soft_constraints,
        "acceptance_criteria": criteria,
        "unknowns": unknowns,
        "assumptions": assumptions,
    }
    return task


def write_task_file(task: dict, output_path: Path) -> None:
    """Write the task definition to a YAML file (used by meta-orchestrator)."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        yaml.dump(task, f, default_flow_style=False, allow_unicode=True, sort_keys=False)


def main():
    parser = argparse.ArgumentParser(description="Meta-Harness Interpreter")
    parser.add_argument("--intent", default=None, help="Raw intent string")
    parser.add_argument("--intent-file", default=None, help="File containing raw intent")
    parser.add_argument("--output", default=None, help="Output task definition file (YAML)")
    args = parser.parse_args()

    if args.intent:
        intent = args.intent
    elif args.intent_file:
        intent_file = Path(args.intent_file)
        if not intent_file.exists():
            print(f"ERROR: Intent file not found: {intent_file}")
            sys.exit(1)
        intent = intent_file.read_text(encoding="utf-8").strip()
    else:
        print("ERROR: Provide --intent or --intent-file")
        sys.exit(1)

    task = interpret_intent(intent)

    output = yaml.dump(task, default_flow_style=False, allow_unicode=True, sort_keys=False)

    if args.output:
        write_task_file(task, Path(args.output))
        print(f"Task definition written to: {args.output}")
        print(f"  Domain: {task['domain']}")
        print(f"  Scale: {task['scale']}")
        print(f"  Quality attributes: {task['quality_attributes']}")
        print(f"  Hard constraints: {len(task['hard_constraints'])}")
        print(f"  Acceptance criteria: {len(task['acceptance_criteria'])}")
    else:
        print(output)


if __name__ == "__main__":
    main()
