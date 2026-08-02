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
| 0021 | [Mobile platforms downgraded to experimental product class](0021-mobile-platform-experimental-downgrade.md) | 2026-08-02 | Accepted |
| 0020 | [Platform Bridge convergence and duplication budget](0020-platform-adapter-convergence-and-duplication-budget.md) | 2026-07-28 (amended 2026-07-29) | Accepted |
| 0019 | [Renderer provider plugin architecture](0019-renderer-provider-plugin-architecture.md) | 2026-07-28 | Accepted |
| 0018 | [Host contract split — runtime/render ownership leaves backend/host](0018-host-contract-split-and-runtime-render-ownership.md) | 2026-07-28 | Accepted |
| 0017 | [Theme layering and views-owned ControlThemeSet](0017-theme-layering-and-control-theme-set.md) | 2026-07-28 | Accepted |
| 0016 | [Declaration invalidation and committed Agent semantics](0016-declaration-invalidation-and-committed-agent-semantics.md) | 2026-07-27 | Accepted |
| 0015 | [Public object-safe ViewNode with typed View adapters](0015-public-view-node-trait.md) | 2026-07-26 | Accepted |
| 0014 | [Core owns value types; domain packages are facades only](0014-core-owns-domain-facades.md) | 2026-07-16 | Accepted |
| 0013 | [Showcase unified shell](0013-showcase-unified-shell.md) | 2026-07-16 | Accepted |
| 0012 | [Showcase consolidation and moui_cli quick start](0012-showcase-consolidation-and-moui-cli-quickstart.md) | 2026-07-16 | Accepted |
| 0011 | [Platform product class and mobile readiness](0011-platform-product-class-and-mobile-readiness.md) | 2026-07-16 (amended 2026-08-02) | Accepted (product-class decision superseded in part by ADR 0021) |
| 0009 | [DrawFrame clear ownership and Skia damage clipping](0009-draw-frame-clear-and-skia-damage-clip.md) | 2026-07-14 | Accepted |
| 0008 | [MoonBit-native browser Playground](0008-moonbit-native-playground.md) | 2026-07-13 | Accepted |
| 0007 | [Skia layer cache indexing and damage region partial clear](0007-skia-layer-cache-indexing-and-damage-region.md) | 2026-07-12 | Accepted |
| 0006 | [Mobile GPU surface and render thread ownership](0006-mobile-gpu-surface-and-render-thread.md) | 2026-07-11 | Accepted |
| 0005 | [Mobile host channel ownership](0005-mobile-host-channel-ownership.md) | 2026-07-11 | Accepted |
| 0004 | [Views API visibility migration](0004-views-api-visibility-migration.md) | 2026-07-10 | Accepted |
| 0003 | [Domain facade and root app-loop facade](0003-domain-sugar-and-root-facade.md) | 2026-07-04 | Accepted |
| 0002 | [MouiRichtext optimization](0002-moui-richtext-optimization.md) | 2026-06-29 | Accepted |
| 0001 | [Markdown session virtual scrolling](0001-markdown-session-virtual-scrolling.md) | 2026-06-28 | Accepted |
<!-- Add new entries here: -->
<!-- | 0001 | [View generic parameter](0001-view-generic-parameter-default.md) | 2026-06-25 | Accepted | -->
