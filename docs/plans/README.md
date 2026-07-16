# Plans

Executable work memory for multi-step agent and human efforts.
Formal specs and standing decisions live in **`docs/`** (ADRs under
`docs/decisions/`), not in tool-specific plan folders.

## Layout

```text
docs/plans/
  README.md                 # this file
  active/<id>.md            # in-flight exec plans
  done/<id>.md              # finished plans (keep for audit)
  debt/<id>.md              # known tech debt with acceptance notes
```

Historical topic pointers (pre-layout notes) remain useful:

| Topic | Canonical doc |
|-------|----------------|
| App package imports, sugar packages, `@core` vs prefixes | [moui-app-package-boundary.md](../moui-app-package-boundary.md) |
| Public API tiers and guards | [api-surface.md](../api-surface.md) |
| Facade / domain facade decision | [decisions/0003-domain-sugar-and-root-facade.md](../decisions/0003-domain-sugar-and-root-facade.md) |
| Agent workflow | [ai-collaboration.md](../ai-collaboration.md), [AGENTS.md](../../AGENTS.md) |
| Harness map + invariant mechanization | [done/harness-mechanize-invariants-batch1.md](done/harness-mechanize-invariants-batch1.md) |

## When to write a plan

| Scale | Artifact |
|-------|----------|
| Single package, clear acceptance | PR description only |
| Multi-package, platform, public API, or >1 session | `active/<id>.md` before coding |
| Deferred cleanup | `debt/<id>.md` |

## Plan skeleton

```markdown
# Plan: <title>

- **Status**: active | done | debt
- **Goal**:
- **Non-goals**:

## Acceptance
- [ ] ...

## Decision log
| Date | Decision |
|------|----------|

## Progress
| Date | Note |
|------|------|
```

## Active

| Plan | Summary |
|------|---------|
| _(none)_ | |

## Done (recent)

| Plan | Summary |
|------|---------|
| [harness-mechanize-invariants-batch1](done/harness-mechanize-invariants-batch1.md) | Map-style AGENTS/docs + P1/P2/A6/R3/M5/G1/G2 machine checks |

Move finished plans to `done/` in the same PR that closes the work.
