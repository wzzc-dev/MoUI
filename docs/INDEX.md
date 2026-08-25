# Docs Index

Active implementation plan: [AI-Native UI](plans/active/ai-native-ui.md).

Progressive-disclosure catalog for MoUI. Start here after `AGENTS.md`.
Statuses are editorial signals for agents (not CI evidence grades).

| Status | Meaning |
|---|---|
| `canonical` | Prefer this page for the topic |
| `map` | Short orientation; follow links for depth |
| `deep` | Long-form; load only when needed |
| `generated` | Do not hand-edit; regenerate via scripts |
| `historical` | Context only; not day-to-day routing |

## Entry points

| Doc | Status | Use when |
|---|---|---|
| [../AGENTS.md](../AGENTS.md) | `map` | Agent cold start (short map only) |
| [architecture-map.md](architecture-map.md) | `map` | Package layers and dependency direction |
| [architecture.md](architecture.md) | `deep` | Full package narrative and target routes |
| [invariants.md](invariants.md) | `canonical` | Structural constraints (sole source) |
| [testing.md](testing.md) | `canonical` | Validation policy and command catalog |
| [development.md](development.md) | `canonical` | Setup, workspace, window-dev-mode |
| [getting-started.md](getting-started.md) | `canonical` | New apps via `moui` CLI (not monorepo clone) |

## Core product & API

| Doc | Status | Use when |
|---|---|---|
| [moui-app-package-boundary.md](moui-app-package-boundary.md) | `canonical` | App imports and owning-package rules |
| [api-surface.md](api-surface.md) | `canonical` | Public API tiers and guards |
| [compatibility-policy.md](compatibility-policy.md) | `canonical` | SemVer, deprecation, quality levels, and external consumers |
| [view-catalog.md](view-catalog.md) | `canonical` | Public controls coverage |
| [views-api-guide.md](views-api-guide.md) | `deep` | Views API usage |
| [tea-program-model.md](tea-program-model.md) | `canonical` | Program / Effect / Subscription model |
| [agent-semantics.md](agent-semantics.md) | `canonical` | Committed semantics, generations, typed Agent actions, and MCP surface |
| [plans/active/native-accessibility.md](plans/active/native-accessibility.md) | `map` | Native accessibility adapters, Probe work graph, and evidence rollout |
| [canvas-and-custom-paint.md](canvas-and-custom-paint.md) | `canonical` | Custom paint / canvas |
| [non-render-component-cookbook.md](non-render-component-cookbook.md) | `canonical` | Host services from app code |
| [button-styling-guide.md](button-styling-guide.md) | `canonical` | Button colors / styles pipeline |
| [text-system.md](text-system.md) | `deep` | Text architecture |
| [internationalization.md](internationalization.md) | `canonical` | Message catalogs, locale selection, and bilingual docs workflow |
| [visual-theme-system.md](visual-theme-system.md) | `deep` | Theme system |
| [markdown-editor.md](markdown-editor.md) | `deep` | Markdown editor product behavior |

## Platforms & readiness

| Doc | Status | Use when |
|---|---|---|
| [platform-host-contract.md](platform-host-contract.md) | `canonical` | Event and host services |
| [platform-readiness-declaration.md](platform-readiness-declaration.md) | `canonical` | Product class / readiness claims |
| [platform-notes.md](platform-notes.md) | `canonical` | Cross-platform caveats hub |
| [platform-notes-macos.md](platform-notes-macos.md) | `deep` | macOS |
| [platform-notes-windows.md](platform-notes-windows.md) | `deep` | Windows |
| [platform-notes-linux.md](platform-notes-linux.md) | `deep` | Linux |
| [platform-notes-web.md](platform-notes-web.md) | `deep` | Web |
| [android-support.md](android-support.md) | `deep` | Android window-hosted route |
| [ios-support.md](ios-support.md) | `deep` | iOS window-hosted route |
| [harmonyos-support.md](harmonyos-support.md) | `deep` | HarmonyOS window-hosted route |
| [wechat-support.md](wechat-support.md) | `deep` | WeChat Mini Program (微信小程序) Skyline Canvas 2D + wasm-gc host |
| [window-hosted-moui.md](window-hosted-moui.md) | `canonical` | Embedded-runtime event-loop ownership and route |
| [renderer-capability-report.md](renderer-capability-report.md) | `canonical` | Renderer capability matrix |
| [3d-capability-report.md](3d-capability-report.md) | `canonical` | Independent 3D addon capability/status |
| [gpu-promotion-runbook.md](gpu-promotion-runbook.md) | `deep` | GPU promotion process |

## Examples, release, maintenance

| Doc | Status | Use when |
|---|---|---|
| [examples.md](examples.md) | `canonical` | Example commands and coverage |
| [showcases.md](showcases.md) | `canonical` | Showcase routes |
| [app-templates.md](app-templates.md) | `canonical` | Templates |
| [release-readiness.md](release-readiness.md) | `canonical` | Release gates |
| [maintenance.md](maintenance.md) | `canonical` | Baselines and ratchets |
| [feature-status-dashboard.md](feature-status-dashboard.md) | `canonical` | Feature status overview |
| [feature-proof-matrix.md](feature-proof-matrix.md) | `canonical` | Proof / evidence matrix |
| [repository-facts.md](repository-facts.md) | `generated` | Workspace members and generated facts |
| [api-surface-audit.md](api-surface-audit.md) | `generated` | API audit snapshot (if present) |

## Agent harness & history

| Doc | Status | Use when |
|---|---|---|
| [ai-collaboration.md](ai-collaboration.md) | `canonical` | Agent workflow and anti-patterns |
| [plans/README.md](plans/README.md) | `canonical` | Exec plan layout |
| [decisions/README.md](decisions/README.md) | `canonical` | ADR index |
| [ai-sessions/](ai-sessions/) | `historical` | Past multi-file sessions |
| [harness-mechanize-invariants-batch1.md](plans/done/harness-mechanize-invariants-batch1.md) | `map` | First mechanizable invariants batch (done) |
| [golden-principles.md](golden-principles.md) | `canonical` | Short mechanical taste rules |
| [../memories/repo/](../memories/repo/) | `map` | Short durable facts for agents |

## Roadmaps & proposals

| Doc | Status | Use when |
|---|---|---|
| [roadmap-2026.md](roadmap-2026.md) | `deep` | Year roadmap |
| [PROPOSAL.md](PROPOSAL.md) | `historical` | Proposals |
| [tutorials.md](tutorials.md) | `deep` | Tutorials index |
| [templates.md](templates.md) | `deep` | Template notes |
| [mo-workbench.md](mo-workbench.md) | `deep` | Mo Workbench |

## Validation surfaces (not prose docs)

| Path | Role |
|---|---|
| `checks/profiles.json` | `pr` / `daily` / `platform` / `theme` steps |
| `smoke/gates.json` | daily / nightly / release smoke suites |
| `scripts/check.sh` | Check facade |
| `node scripts/smoke-gate.mjs` | Smoke catalog runner |
| `tools/moui/*` | MoonBit-backed validators |

## Maintenance rules for this index

1. New standing guidance page → add a row here in the same PR.
2. Do not duplicate invariant text; link `invariants.md`.
3. Do not duplicate command lists; link `testing.md` / check catalogs.
4. After large renames, run `node scripts/validate-guidance-consistency.mjs`.
