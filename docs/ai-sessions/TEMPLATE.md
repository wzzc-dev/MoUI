# YYYY-MM-DD: Short Description

- **Agent**: (e.g., "Claude Code")
- **Goal**: What the user asked to accomplish.
- **Outcome**: Success / Partial / Blocked (with reason).

## Summary

2–3 sentences on what was done.

## Changes Made

| Package/File | What Changed | Why |
|---|---|---|
| `moui/views/button.mbt` | ... | ... |

## Key Decisions

- Decision — rationale (→ ADR link if applicable).

## Discoveries

- Non-obvious facts, APIs, conventions or constraints.

## Validation

Commands run and their result (`moon test ...`, `sh scripts/check.sh --profile daily`).

## Follow-Up

- [ ] Open tasks, known gaps, related ADRs/docs.

## Promote (required checklist)

If the next agent cannot discover it from the repo, it does not exist.

- [ ] Durable facts → `memories/repo/<topic>.md` (≤20 lines each)
- [ ] Architectural choice → `docs/decisions/` ADR
- [ ] Remaining multi-session work → `docs/plans/active/` or `debt/`
- [ ] Stale guidance → fix the canonical doc (`invariants` / `testing` / `INDEX`), not only here
