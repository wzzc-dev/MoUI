# 2026-07-16: Harness-engineering map for agent entry

- **Agent**: ZCode / Grok
- **Goal**: Apply OpenAI harness-engineering lessons to MoUI structure (map not manual; mechanizable invariants).
- **Outcome**: Success for docs/harness surface; validator implementation deferred to plan.

## Summary

Reworked agent cold-start into progressive disclosure: short `AGENTS.md` router,
`docs/INDEX.md`, `docs/architecture-map.md`, golden principles, and an active
plan for batch-1 machine checks. Guidance-consistency tokens on `AGENTS.md`
were preserved.

## Changes Made

| Package/File | What Changed | Why |
|---|---|---|
| `AGENTS.md` | Map + task router + facades | Context budget / progressive disclosure |
| `docs/INDEX.md` | New catalog | Single docs directory |
| `docs/architecture-map.md` | One-page layers | Avoid always-loading deep architecture |
| `docs/golden-principles.md` | Taste rules | Encode for GC / future agents |
| `docs/plans/...` | Exec plan + README layout | Plans as first-class artifacts |
| `docs/invariants.md` | Batch1 detection notes | Track mechanization |
| `docs/ai-collaboration.md` | Workflow aligned to map | Stop encyclopedia workflow |
| `docs/ai-sessions/TEMPLATE.md` | Promote checklist | Session → memory/ADR/plan |
| `memories/repo/harness-entry.md` | Short facts | Next-session load |

## Key Decisions

- Keep `AGENTS.md` token-compatible with `validate_guidance_consistency` rather than relaxing the contract in the same change.
- Mechanize invariants in a follow-up (plan active); this change is harness map only.
- Prefer extending MoonBit validators over new Node-only logic.

## Validation

```sh
node scripts/validate-guidance-consistency.mjs
moon test tools/moui/validate_window_dependency --target native
node scripts/validate-window-dependency.mjs
node scripts/validate-harmonyos-shell.mjs
node scripts/validate-harness-invariants.mjs
node scripts/validate-check-profiles.mjs
```

## Promote

- [x] `memories/repo/harness-entry.md`
- [x] `docs/plans/done/harness-mechanize-invariants-batch1.md`
- [x] A6 + M5 + P1/P2/R3/G1/G2 mechanized
