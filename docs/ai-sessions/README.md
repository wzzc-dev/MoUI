# AI Session Logs

Durable, thematic summaries of significant AI-agent-assisted sessions for MoUI.
Individual session files were folded into these theme pages (2026-11 docs diet);
one-off session logs are no longer kept in-tree.

## Purpose

- Record **what landed**, **why**, and **what was learned**.
- Keep context that is not visible in the code or commit messages alone.
- Track patterns and pitfalls worth reusing.

## Files

| Theme | Covers |
|---|---|
| [renderer-and-gpu.md](renderer-and-gpu.md) | Skia cache/damage, GPU promotion, HarmonyOS direct present, ADR 0044 route, text-provider relocation, Metal renderer L1–L4 |
| [text-and-editors.md](text-and-editors.md) | richtext, Markdown session/caret/layout, Code Editor example, Studio blocks canvas |
| [platform-readiness.md](platform-readiness.md) | mobile host services, Windows/Android/iOS promotions, cross-platform ownership |
| [tui-and-input.md](tui-and-input.md) | terminal output path S0–S7, TUI hardening, pointer/RTL parity |
| [toolchain-ci-and-release.md](toolchain-ci-and-release.md) | feature-proof CI, MoonBit 0.10.4/0.10.20, playground assets, release + governance-tax arcs |
| [examples-harness-and-cadence.md](examples-harness-and-cadence.md) | Showcase consolidation, harness map, hot-path convergence, maturity-gap commits |

## When to Log

- Multi-file changes that touch architecture boundaries.
- Sessions that produced an ADR.
- Sessions where significant debugging or discovery happened.
- Sessions that established a new pattern or anti-pattern.
- **Not needed** for routine single-file edits, test additions, or doc tweaks.

## Template

Copy the shape in [TEMPLATE.md](TEMPLATE.md). Prefer promoting a durable fact to
`memories/repo/` and a durable decision to `docs/decisions/`; the session page is
the narrative that remains.
