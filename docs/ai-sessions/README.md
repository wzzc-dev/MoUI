# AI Session Logs

This directory stores summaries of significant AI-agent-assisted
development sessions for MoUI.

## Purpose

- Record **what was done**, **why**, and **what was learned**.
- Help future agents (and maintainers) understand context that is
  not captured in commit messages alone.
- Track patterns that work well or pitfalls to avoid.

## Naming Convention

```
YYYY-MM-DD-short-description.md
```

Example: `2026-06-25-button-variant-refactor.md`

## When to Log a Session

- Multi-file changes that touch architecture boundaries.
- Sessions that produced an ADR.
- Sessions where significant debugging or discovery happened.
- Sessions that established a new pattern or anti-pattern.
- **Not needed** for routine single-file edits, test additions, or doc tweaks.

## Template

Copy `TEMPLATE.md` and fill in the relevant sections.
Keep it brief — aim for 1–2 pages max per session.

## Index

<!-- Add new entries newest-first: -->
- [2026-08-29: Windows promoted to committed product class](2026-08-29-windows-committed-promotion.md)
- [2026-08-05: Cross-platform behavior convergence](2026-08-05-cross-platform-behavior-convergence.md)
- [2026-07-13: All-platform native GPU workers](2026-07-13-all-platform-native-gpu-workers.md)
- [2026-07-12: Skia layer cache indexing and damage region partial clear](2026-07-12-skia-layer-cache-damage-region.md)
- [2026-07-11: Mobile mainline and host services](2026-07-11-mobile-mainline-host-services.md)
- [2026-07-07: Native Code Editor Example](2026-07-07-code-editor-example.md)
- [2026-06-29: CI feature proof system](2026-06-29-ci-feature-proof-system.md)
- [2026-06-29: Richtext blackbox tests (Workflow 4)](2026-06-29-moui-richtext-blackbox-tests.md)
- [2026-06-29: Fix Markdown Editor file tree scroll](2026-06-29-markdown-editor-file-tree-scroll.md)
- [2026-06-29: Fix Markdown Editor table click caret](2026-06-29-markdown-editor-table-click-caret.md)
- [2026-06-29: Markdown Editor Typora flush layout](2026-06-29-markdown-editor-typora-flush-layout.md)
- [2026-06-28: Markdown scroll cache and caret latency](2026-06-28-markdown-scroll-cache-caret.md)
- [2026-06-28: Markdown session virtual scrolling](2026-06-28-markdown-session-virtual-scrolling.md)
<!-- - [2026-06-25: Button variant refactor](2026-06-25-button-variant-refactor.md) -->
