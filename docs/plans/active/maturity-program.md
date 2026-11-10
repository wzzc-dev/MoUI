# Plan: Maturity program — close the external-adopter loop

- **Status**: active
- **Goal**: Turn the maturity gap analysis into a sequenced program: make the
  external developer path (`new → dev → inspect → package → verify`) work
  without repo-local hacks, seed a real addon/app ecosystem, and make platform
  claims match recorded evidence.
- **Non-goals**: renderer/layout rewrite, new built-in controls, interpreter
  or wasm in-process hot reload in Phase 1, a browser-hosted compiler/IDE.

## Context

MoUI's kernel and evidence chain are ahead of most pre-1.0 frameworks: L1-L3
proof, golden rendering, release-module closures, API budgets, and the platform
matrix are all enforced. The remaining adoption blockers are the developer
loop, ecosystem, productization, and documentation truth. This plan sequences
those fixes without expanding the renderer or control surface.

Chosen routes:

- Hot reload: restart-based with transient-state handoff (ADR 0068).
- Ecosystem: find 2-3 genuinely external apps before building a registry.
- Program shape: three release phases with explicit exit gates.

## Phase 1 — close the loop (next release)

| Workstream | Owner plan | Exit |
|---|---|---|
| W1 Developer loop | [maturity-dev-loop](maturity-dev-loop.md) | `moui dev` restores scroll/focus/caret; `moui inspect` reads live tree/trace/diagnostics |
| W2 Productization | [maturity-productization](maturity-productization.md) | release packaging on macOS/Windows/Linux/Web; `moui verify` provenance fixed; physical-device Android/iOS evidence recorded |
| W3 Ecosystem seed | [maturity-ecosystem](maturity-ecosystem.md) | 2-3 external apps onboarded; addon registry seed; notifications/permissions vertical slice on macOS/Web/Android |
| W4 Governance truth | [maturity-governance](maturity-governance.md) | docs, backend flags, and `checks/platforms/*.json` agree; validators catch regressions |

## Phase 2 — public quality (P1)

- **W5 Test assets**: publish `runtime/test_support` as a documented test API,
  add `moui test`, put golden rendering in a profile.
- **W6 Accessibility**: macOS VoiceOver L3, Windows UIA L2, Linux AT-SPI L2,
  then flip capability flags; AX recorders in nightly/manual workflows.
- **W7 Motion**: wire `SpringSpec` into `View::transition`/`View::presence`,
  add paired exit transitions, integrate `SpringState` frame pumping.
- **W8 Learning path**: 30-minute tutorial, cookbook, and a preset-example
  playground; CI builds the referenced examples.
- **W9 Distribution depth**: macOS notarization, Windows installer,
  Linux AppImage/deb.

## Phase 3 — 1.0 readiness (P2)

- **W10 API freeze**: inventory public tiers, freeze `moui`/facades/`views`/
  `ViewNode`, migration notes/codemods.
- **W11 Performance visibility**: dedicated benchmark runner, per-release
  baseline table, timing ratchet, full-surface redraw debt.
- **W12 Desktop integration**: AppShell/WindowProgram decision, tray/
  notifications/associations/deep links, window state.
- **W13 Security/supply chain**: signing, notarization, SBOM, dependency
  update policy, WebView bridge review.
- **W14 Ecosystem scale**: typed service registry, camera/share/print/
  associations plugins, addon quality badges and compatibility matrix.

## Acceptance

- [ ] Phase 1: external developer completes `new → dev → inspect → package →
      verify` in a generated project; 2-3 external pilots are running; docs
      and platform evidence agree.
- [ ] Phase 2: public test/golden API, three-desktop accessibility evidence,
      spring/exit motion, and the 30-minute tutorial are shipped.
- [ ] Phase 3: 1.0 freeze list, published performance baseline, signed
      artifacts, and desktop system integration are shipped.

## Decision log

| Date | Decision |
|---|---|
| 2026-11-10 | Program accepted; Phase 1 starts with governance truth + packaging correctness + spring wiring |
| 2026-11-10 | Hot reload narrowed to transient handoff (ADR 0068); web module reload stays an experiment |
| 2026-11-10 | Ecosystem starts with external pilots, not a registry-first build |

## Progress

| Date | Note |
|---|---|
| 2026-11-10 | Program plan created; sub-plans and ADR 0068 added. |
| 2026-11-10 | First slice landed: spring wiring, platform-claim sync, release packaging + Linux bundle, verify provenance/applicationId, and dev transient handoff. `moon test` for core/runtime/native/CLI and `sh scripts/check.sh --profile pr` pass. |
| 2026-11-10 | DevTools v1 landed: versioned document, native publisher, `moui inspect`, `moui dev --inspect`, and Web endpoints. PR profile passes; socket/NDJSON transport remains the next transport slice. |
| 2026-11-10 | Packaging depth landed: macOS icon/PkgInfo, Windows `icudtl.dat`, Web package metadata, plus macOS/Linux/Windows packaging tests. |
| 2026-11-10 | Governance drift check extended in `validate_portfolio_governance`; live Android/iOS experimental claims now fail the PR profile, and the remaining zh-Hans/WeChat drift was fixed. |
