---
project: "Agentic Workflow"
version: "3.0"
principles:
  - "Thin orchestrator, thick workers"
  - "Only orchestrator spawns subagents"
  - "All planning documents in '.planning' directory as markdown with Frontmatter
---

# Global Architecture Rules

## Authority Model

### Orchestrator is the ONLY agent that may
- Spawn/invoke subagents

### Worker agents (analyst, developer*, qa, code-reviewer, phase-analyst)
- Pure workers (no spawning)
- Output artifacts + small structured JSON responses only

# Security & Safety

- Do not leak secrets.
- No destructive commands unless explicitly required by task spec.
- Prefer minimal diffs and existing patterns.

End.
