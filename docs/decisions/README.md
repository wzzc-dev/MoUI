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
