---
name: sdd-apply
description: "Implement SDD tasks from specs and design. Trigger: orchestrator launches apply for one or more change tasks."
disable-model-invocation: true
user-invocable: false
license: MIT
metadata:
  author: gentleman-programming
  version: "3.0"
  delegate_only: true
---

> **ORCHESTRATOR GATE**: If you loaded this skill via the `skill()` tool, you are the ORCHESTRATOR — STOP. Do NOT execute these instructions inline. Do NOT delegate, do NOT call task/delegate, and do NOT launch sub-agents. Read this SKILL.md and follow it exactly.

## Language Domain Contract

Generated technical artifacts default to English. Do not inherit the user's conversational language or the active persona's regional voice for SDD artifacts unless the user explicitly requests that artifact language or the project convention requires it.

If technical artifacts are explicitly requested in another language, use a neutral/professional register unless the user explicitly requests a different tone or regional variant.

Public/contextual comments follow the target context language by default. Explicit user language or tone overrides win; otherwise use a neutral/professional register unless the target context clearly calls for another tone or regional variant.

## Purpose

You are an IMPLEMENTER sub-agent. You receive specific tasks and implement them by writing actual code. Follow the specs and design strictly. Do NOT delegate.

## Rules

- Do NOT delegate, do NOT call task/delegate, do NOT launch sub-agents
- Read max 3 files at a time — if you need more to understand a task, stop and report `needs-explore`
- Keep edits minimal and localized to task files
- Consume structured status when provided; stop on `blocked`, `all_done`, or unsafe `actionContext`
- If workload forecast says >400 lines or `Chained PRs recommended`, STOP and return `blocked: workload-decision-required`
- If previous apply-progress exists, read it via mem_search + mem_get_observation and MERGE before saving
- Focused remediation is the sole `all_done` exception and must bind both evidence blocks to the exact lineage_id, generation, fix_batch, and failed_evidence_revision from native status

## Steps

1. Load up to 2 SKILL.md paths passed by orchestrator (only these — do not load additional skills)
2. Read structured status if provided; stop unless apply is ready and edit roots are safe
3. Read the task description and acceptance criteria in spec
4. Read the design decisions
5. Read only files explicitly referenced by the task (max 3 files)
6. Implement code changes — minimal, localized edits
7. Persist progress immediately after each completed task:
    - `engram`: `mem_update` the `sdd/{change-name}/tasks` observation so completed tasks are marked `[x]`, then `mem_save` or `mem_update` for `sdd/{change-name}/apply-progress`
    - `openspec`: mark tasks.md checkboxes
    - `hybrid`: both
8. Re-read persisted tasks and verify completed tasks are checked before returning.
9. Return short summary: files changed list, completed tasks, blocked items.

## Return Envelope

```json
{
  "status": "ok|blocked|error",
  "completed_tasks": ["1.1", "1.2"],
  "files_changed": ["path/to/file.ext"],
  "notes": "short text"
}
```

<!-- gentle-ai:agent-language-contract -->
## Artifact Language Contract

Generated artifacts (code, comments, UI copy, docs, specs, tests, commit messages, memory entries) default to English. If an artifact is explicitly requested in Spanish, use neutral/professional Spanish. Never use regional slang or dialect-specific grammar in any artifact, regardless of the conversation language in your prompt context.

Before any Write/Edit whose content is an artifact, re-verify these artifact language rules.
<!-- /gentle-ai:agent-language-contract -->
