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
| [dsh-desktop-settings-menu](active/dsh-desktop-settings-menu.md) | Add the macOS Settings command and a persisted MoUI request-URL dialog above WKWebView |
| [dsh-floating-site-switch](active/dsh-floating-site-switch.md) | DeepSeek Harness Desktop floating site-switch overlay button and URL handling |
| [linux-riscv64-support](active/linux-riscv64-support.md) | Add non-blocking Linux Skia Raster L0-L2 cross-build evidence for `riscv64-linux-gnu` |
| [mo-workbench-message-windowing](active/mo-workbench-message-windowing.md) | Mo Workbench 消息列表窗口化与重建优化 |
| [release-module-dependency-closures](done/release-module-dependency-closures.md) | Split concrete renderers and integration tests out of the base publication closure |
| [backend-renderer-lifecycle-convergence](active/backend-renderer-lifecycle-convergence.md) | Split backend-common state owners and collapse renderer binding to provider/session |
| [runtime-state-render-ownership-convergence](active/runtime-state-render-ownership-convergence.md) | Move accessibility out of runtime, unify app state ownership, and make renderer sessions own render resources |
| [mo-desktop-example](active/mo-desktop-example.md) | Add a responsive macOS-inspired MoUI desktop simulation with Web and macOS Skia entrypoints |
| [window-cross-platform-parity](active/window-cross-platform-parity.md) | Align window (Windows/Linux/Web) with macOS reference in MoUI-ready semantics |
| [view-node-trait-refactor](active/view-node-trait-refactor.md) | Complete the public ViewNode trait migration |
| [crater-browser-integration](active/crater-browser-integration.md) | Pure-MoonBit browser demo: crater HTML engine + js_engine scripts rendered through MoUI canvas |
| [moui-tier-tea-debt-convergence](active/moui-tier-tea-debt-convergence.md) | Converge platform tiers, strict TEA boundaries, entrypoints, and documentation debt |

## Done (recent)

| Plan | Summary |
|------|---------|
| [macos-first-present-visibility](done/macos-first-present-visibility.md) | Reveal Mo Desktop and Mo Workbench only after their first successful macOS presentation |
| [webview-window-drag](done/webview-window-drag.md) | Preserve clickable WKWebView top-bar controls while blank space drags the macOS window |
| [webview-moui-overlay](done/webview-moui-overlay.md) | Expose MoUI overlay pixels and pointer input above macOS WKWebView siblings |
| [backend-render-package-convergence](done/backend-render-package-convergence.md) | Replace host/bridge packages with symmetric backend/render protocol and common implementation layers |
| [platform-adapter-duplication-remediation](done/platform-adapter-duplication-remediation.md) | Eliminate shared platform behavior copies and remove similarity budgets |
| [moui-support-upstream-workspace](done/moui-support-upstream-workspace.md) | Complete the upstream-layout migration, compatibility release, and published-dependency handoff |
| [window-host-lifecycle-unification](done/window-host-lifecycle-unification.md) | Move all logical window lifecycle and frame coordination into MoUI window_host |
| [backend-renderer-extraction](done/backend-renderer-extraction.md) | Move renderer construction out of platform backends and into composition roots |
| [renderer-backend-decoupling](done/renderer-backend-decoupling.md) | Historical predecessor superseded by backend renderer extraction |
| [renderer-provider-trait-refactor](done/renderer-provider-trait-refactor.md) | Historical provider proposal superseded by architecture convergence |
| [validation-hygiene-cleanup](done/validation-hygiene-cleanup.md) | Remove validator self-tests and retain product/evidence validation |
| [moonbit-tooling-formalization](done/moonbit-tooling-formalization.md) | Move formalizable repository rules into MoonBit tools |
| [all-target-diagnostics-cleanup](done/all-target-diagnostics-cleanup.md) | Restore clean `moon check --target all` output outside window packages |
| [moui-architecture-convergence](done/moui-architecture-convergence.md) | Converge package ownership and dependency direction per ADRs 0014/0015/0017–0020 (Phases A–G) — complete |
| [core-component-theme-to-views](done/core-component-theme-to-views.md) | Component theme → views control set (superseded by ADR 0017; `Theme.components` removed) — complete |
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
