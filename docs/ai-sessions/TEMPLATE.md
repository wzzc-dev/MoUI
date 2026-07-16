# YYYY-MM-DD: Short Description

- **Agent**: (e.g., "Claude 3.5 Sonnet via Copilot", "Claude Code")
- **Goal**: What the user asked to accomplish.
- **Outcome**: Success / Partial / Blocked (with reason).

## Summary

2–3 sentence overview of what was done.

## Changes Made

| Package/File | What Changed | Why |
|---|---|---|
| `moui/views/button.mbt` | ... | ... |
| `docs/...` | ... | ... |

## Key Decisions

- Decision 1 — rationale (→ ADR link if applicable)
- Decision 2 — rationale

## Discoveries

- Facts or patterns discovered during the session.
- APIs, conventions, or constraints that were not initially obvious.

## Validation

What commands were run? What was the result?

```sh
# e.g.
moon test moui/views --target native
sh scripts/check.sh --profile daily
```

## Follow-Up

- [ ] Open tasks or known gaps.
- [ ] Related ADRs or docs to update.

## Promote (required checklist)

Harness rule: if the next agent cannot discover it from the repo, it does not exist.

- [ ] Short durable facts → `memories/repo/<topic>.md` (≤20 lines each)
- [ ] Architectural choice → `docs/decisions/` ADR
- [ ] Multi-session work remaining → `docs/plans/active/` or `docs/plans/debt/`
- [ ] Stale guidance found → fix canonical doc (`invariants` / `testing` / `INDEX`), do not only note it here
