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

ADRs are grouped by theme; each original decision keeps its number as an
in-file section anchor (e.g. `## 0017: Theme layering ...` inside
`0017-theme-and-host-contract.md`).

| # | Title | Date | Status |
|---|-------|------|--------|
| 0017–0018 | [Theme and host contract](0017-theme-and-host-contract.md) | 2026-07-28 | Accepted |
| 0015–0016 | [Core protocols](0015-core-protocols.md) | 2026-07-26 | Accepted |
| 0011–0021 | [Platform class and convergence](0011-platform-class-and-convergence.md) | 2026-07-16 (amended 2026-08-02) | Accepted |
| 0008–0013 | [Tools and examples](0008-tools-and-examples.md) | 2026-07-13 | Accepted |
| 0007–0022 | [Renderer and Skia](0007-renderer-and-skia.md) | 2026-07-12 (amended 2026-08-02) | Accepted |
| 0005–0006 | [Mobile host and GPU](0005-mobile-host-and-gpu.md) | 2026-07-11 | Accepted |
| 0003–0014 | [Core package and API](0003-core-package-and-api.md) | 2026-07-04 | Accepted |
| 0001–0002 | [Editor and rich text](0001-editor-and-richtext.md) | 2026-06-28 | Accepted |
| 0023 | [Sun CPU raster is an experimental renderer](0023-sun-experimental-renderer.md) | 2026-08-02 | Accepted |
| 0024 | [Unified MoUI window-host lifecycle owner](0024-unified-window-host-lifecycle.md) | 2026-08-05 | Accepted |
| 0025 | [Backend and render package convergence](0025-backend-render-package-convergence.md) | 2026-08-05 | Accepted |
| 0026 | [Release module dependency closures](0026-release-module-dependency-closures.md) | 2026-08-07 | Accepted |
| 0027 | [Backend ownership and renderer lifecycle convergence](0027-backend-renderer-lifecycle-convergence.md) | 2026-08-07 | Accepted |
| 0028 | [Runtime neutrality, state ownership, and render resources](0028-runtime-state-render-ownership-convergence.md) | 2026-08-07 | Accepted |
| 0032 | [Linux promoted to committed product class](0032-linux-committed-product-class.md) | 2026-08-30 | Accepted |
| 0031 | [Windows promoted to committed product class](0031-windows-committed-product-class.md) | 2026-08-29 | Accepted |
| 0030 | Overlay presentation host and neutral modal transport | 2026-08-25 | Accepted |
| 0033 | [Overlay placement pass, portal, and layer stack](0033-overlay-placement-and-portal.md) | 2026-09-03 | Accepted |
| 0034 | [ViewNode declaration-key coverage gate](0034-viewnode-declaration-coverage-gate.md) | 2026-09-04 | Accepted |
| 0035 | [Tight-fit child frames and place-time re-measure](0035-tight-fit-child-remeasure.md) | 2026-09-04 | Accepted |
| 0036 | [Ambient theme resolution at paint time](0036-ambient-theme-resolution.md) | 2026-09-29 | Accepted |
| 0039 | [Studio shell completion line and budget ratchet](0039-studio-shell-completion-line.md) | 2026-10-12 | Accepted |
| 0040 | [Studio shell completion stages (amends 0039)](0040-studio-shell-completion-stages.md) | 2026-10-12 | Accepted |
| 0041 | [Studio shell Msg structural floor (amends 0040 A-tier metrics)](0041-studio-shell-variant-structural-floor.md) | 2026-10-13 | Accepted |
| 0042 | [Studio editor-first workbench (workbench package and narrow extension points)](0042-studio-editor-first-workbench.md) | 2026-10-24 | Accepted |
| 0043 | [Metal-direct renderer is not adopted](0043-metal-direct-renderer-not-adopted.md) | 2026-10-26 | Superseded by 0044 |
| 0044 | [A GPU route with no external graphics library is authorized (Apple-first, experimental)](0044-no-third-party-graphics-library-gpu-route.md) | 2026-10-27 | Accepted — L0 executed and parked at its kill gate; owner directed L0.5 + L1 on 2026-10-27 |
| 0045 | [`moui_metal_renderer` is declared an experimental renderer at its L1 evidence frame](0045-direct-host-gpu-renderer-experimental.md) | 2026-10-27 | Accepted |
| 0046 | [HarmonyOS product class raised to `committed`](0046-harmonyos-committed-with-gaps.md) | 2026-10-30 | Accepted |
<!-- Add new entries here: -->
<!-- | 0001 | [View generic parameter](0001-view-generic-parameter-default.md) | 2026-06-25 | Accepted | -->
