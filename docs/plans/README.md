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
| Facade / domain facade decision | [decisions/0003-core-package-and-api.md](../decisions/0003-core-package-and-api.md) |
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
| [mo-desktop-example](active/mo-desktop-example.md) | Add a responsive macOS-inspired MoUI desktop simulation with Web and macOS Skia entrypoints |
| [moonbit-tooling-formalization](active/moonbit-tooling-formalization.md) | Move formalizable script rules/generators into `tools/moui`; keep host shells thin |
| [core-component-theme-to-views](active/core-component-theme-to-views.md) | Component theme schema stays core (S1); control styles in views; Theme.components split is RFC |
| [moui-architecture-convergence](active/moui-architecture-convergence.md) | Converge package ownership and dependency direction per ADRs 0014/0015/0017–0020 (Phases A–G) |
| [window-cross-platform-parity](active/window-cross-platform-parity.md) | Align window (Windows/Linux/Web) with macOS reference in MoUI-ready semantics |
| [all-target-diagnostics-cleanup](active/all-target-diagnostics-cleanup.md) | Restore moon check --target all and remove compiler warnings outside window/ packages |

## Done (recent)

| Plan | Summary |
|------|---------|
| [i18n-website](done/i18n-website.md) | Add a pure i18n addon and localize the complete public website and docs |
| [web-input-router-consolidation](done/web-input-router-consolidation.md) | Make moui/backend/web the single owner of trusted browser pointer routing |
| [website-showcases-single-scroll](done/website-showcases-single-scroll.md) | Single-scroll Showcases page with accurate platform/source metadata |
| [window-hosted-legacy-cleanup](done/window-hosted-legacy-cleanup.md) | Remove retired mobile packaging and embedding entrypoints |
| [agent-semantic-actions](done/agent-semantic-actions.md) | Declaration invalidation, committed Agent semantics, four-channel ViewDeclaration |
| [web-first-click-dpr-fix](done/web-first-click-dpr-fix.md) | Fix Website first-click activation by synchronizing browser DPR |
| [window-upstream-sync](done/window-upstream-sync.md) | Rebase MoUI fork onto upstream moonbit-community/window workspace layout |
| [backend-hosting-terminology](done/backend-hosting-terminology.md) | Classify backends by host ownership: native-host and embedded-runtime routes |
| [harness-mechanize-invariants-batch1](done/harness-mechanize-invariants-batch1.md) | Map-style AGENTS/docs + P1/P2/A6/R3/M5/G1/G2 machine checks |
| [website-scroll-performance](done/website-scroll-performance.md) | Remove Website scroll-path DOM churn and ship optimized showcase previews |
| [markdown-html-image-gallery](done/markdown-html-image-gallery.md) | Render the safe HTML image-gallery subset in Markdown Editor |

Move finished plans to `done/` in the same PR that closes the work.
