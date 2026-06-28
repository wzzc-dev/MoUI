# Architecture Decision Records (ADR)

This directory stores formal decision records for MoUI development,
especially those made during AI-agent-assisted sessions.

## Naming Convention

```
NNNN-title-in-kebab-case.md
```

- `NNNN` is a zero-padded sequential number (start from `0001`).
- Title should be concise and descriptive.
- Example: `0001-view-generic-parameter-default.md`

## When to Create an ADR

- Choosing between two or more architectural approaches.
- Changing a public API contract or package boundary.
- Introducing a new dependency or external protocol.
- Changing renderer, backend, or runtime pipeline behavior.
- Decisions that affect how agents should work in this repo.

## Template

Copy `TEMPLATE.md` and fill in all sections. Keep it concise.

## Index

| # | Title | Date | Status |
|---|-------|------|--------|
| 0001 | [Markdown session virtual scrolling](0001-markdown-session-virtual-scrolling.md) | 2026-06-28 | Accepted |
<!-- Add new entries here: -->
<!-- | 0001 | [View generic parameter](0001-view-generic-parameter-default.md) | 2026-06-25 | Accepted | -->
