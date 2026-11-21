# Archived plans — index

- **Status**: done (archive index; the individual plan files were retired 2026-11-19)
- **What this is**: one row per plan that finished in `docs/plans/done/`. The plan bodies
  (~11.7k lines, 69 files) were replaced by this index during the 2026-11 docs diet; the
  original text is still reachable from git history.
- **Where the knowledge lives now**: landed behavior in code, standing decisions in
  `docs/decisions/`, narrative + pitfalls in `docs/ai-sessions/`, open work in
  `docs/plans/active/`, deferred cleanup in `docs/plans/debt/`.

Two plans keep their files because live docs link them directly:
[visual-quality.md](visual-quality.md) and
[harness-mechanize-invariants-batch1.md](harness-mechanize-invariants-batch1.md).

How to read a row: **Plan** is the old filename stem (`done/<stem>.md`, retired);
**Landed** is the last commit that touched that file, so `git show <sha>` recovers the
body; **Outcome** is the one-line result. ADRs and older prose that cite a retired stem
are still readable — find the stem here.

## Architecture, packages, and boundaries

| Plan | Outcome | Landed |
|---|---|---|
| `moui-architecture-convergence` | Converged core/views/backend/render/platform ownership and dependency direction per ADR 0014–0020 (Phases A–G). | `68dfba21` 2026-08-06 |
| `core-component-theme-to-views` | Neutral theme schema stayed in `core`; control tokens moved to `@views.ControlThemeSet`. Superseded by ADR 0017. | `27543760` 2026-08-02 |
| `backend-hosting-terminology` | One vocabulary across code and guidance: `native host backend` vs `embedded runtime backend`. | `dd788257` 2026-07-29 |
| `backend-render-package-convergence` | Replaced `backend/host` + `platform_bridge` with symmetric root-protocol and common-implementation packages; closed lifecycle/frame/DPI/teardown ownership gaps. | `68dfba21` 2026-08-06 |
| `renderer-backend-decoupling` | Historical predecessor of backend-renderer extraction; renderer assembly moved out of backends. Superseded. | `c3fc84f6` 2026-11-06 |
| `backend-renderer-extraction` | Renderers no longer constructed inside platform backends; composition roots pick `render(skia).backend(linux)`. | `c3fc84f6` 2026-11-06 |
| `renderer-provider-trait-refactor` | Early provider-trait proposal for the renderer split; superseded and archived. | `a982053b` 2026-08-04 |
| `release-module-dependency-closures` | Concrete renderers and integration-test libraries split out of the base publication closure. | `5aae00a5` 2026-08-08 |
| `runtime-state-render-ownership-convergence` | Accessibility left runtime, one application state/effect owner, renderer sessions own render resources. | `29640e93` 2026-11-01 |
| `view-framework-remediation` | Closed declaration-key coverage, flex tight-fit remeasure, shaping cache, map amplification, and Effect-key collisions; added `ViewNode` declaration-coverage gate. | `6df5c699` 2026-09-04 |
| `agent-semantic-actions` | Four-channel `ViewDeclaration` invalidation, runtime-owned committed Agent semantics, typed generation-checked actions, semantic-only MCP surface. | `68dfba21` 2026-08-06 |
| `semantic-id-ergonomics-and-path-targeting` | Inline semantic ids plus a filtered `ByPath` target for walked committed semantics. | `e0327379` 2026-09-24 |
| `feature-scope-composition` | `Feature[Model, Msg]` + `Feature::scope` lens composition in core, `FieldAction` keyed forms, settings/workbench pilots. | `29640e93` 2026-11-01 |
| `hot-path-invalidation-boilerplate-convergence` | Ten workstreams from the 2026-10-31 review: generation-based invalidation, per-message sync throttling, render-pipeline subtraction, ADR 0034 Option B codegen, RFC 0007 sizing. | `29640e93` 2026-11-01 |
| `mature-framework-parity-optimizations` | Closed the six Flutter/SwiftUI/Compose/Qt/iced gaps (declaration cache, placement-level damage, retained-payload replay, Feature skipping, intrinsic sizing, CLDR i18n); released `0.6.0`. | `7253237f` 2026-11-09 |
| `architecture-priority-execution` | Ran the three 2026-11-05 reviews as one evidence-gated program: update/render caching, leaf-only memoization, content-coordinate scrolling, Feature-first boundary, extension discipline. | `1f0e4dc7` 2026-11-05 |
| `moui-tier-tea-debt-convergence` | One platform-tier source of truth, strict TEA app boundaries, entrypoint cleanup, doc debt. | `29640e93` 2026-11-01 |
| `overlay-system-redesign` | `OverlayHost + PresentationSpec` ordering with runtime-owned placement, input, focus, semantics, and a neutral host-modal transport. | `327ed2ce` 2026-08-25 |
| `overlay-placement-portal-unification` | Anchoring moved to a post-layout placement pass; portal primitive added; dropdown/combobox/autocomplete/tooltip/context-menu/picker/datepicker popups unified. | `29640e93` 2026-11-01 |
| `window-scene-family-relocation` | `WindowSceneResolver` family moved from runtime to `backend/common/lifecycle`. | `fae6f5f1` 2026-09-15 |
| `platform-adapter-duplication-remediation` | Shared platform behavior made single-owner code; superseded by backend-render-package-convergence. | `71d9a74a` 2026-08-30 |
| `moonbit-tooling-formalization` | Formalizable rules moved into `moon test`-able `tools/moui` packages; other languages kept as orchestration shells. | `a982053b` 2026-08-04 |
| `validation-hygiene-cleanup` | Removed validator self-tests; kept product/evidence validation. | `68dfba21` 2026-08-06 |

## Renderer, GPU, and canvas surface

| Plan | Outcome | Landed |
|---|---|---|
| `advanced-blend-modes` | `BlendMode` grew to 13 modes with true Skia/Sun/Canvas2D compositing and documented source-over degradation on WGPU/Metal. | `69f0afff` 2026-11-18 |
| `source-blend` | `BlendMode::Source` exact-replace compositing (alpha included) so p5 overlays commit and erase to transparent. | `69f0afff` 2026-11-18 |
| `stroke-text` | `TextRun` grew optional `stroke_color`/`stroke_width`; Skia draws stroke under fill, other backends stay fill-only. | `69f0afff` 2026-11-18 |
| `path-clip-command` | Renderer-neutral `PushPathClip` command replaced the p5 bounding-box approximation; true Skia path clip with documented bounds fallback. | `69f0afff` 2026-11-18 |
| `web-canvas-rasterizer` | p5-local wasm `CanvasRasterizer`: command-JSON serializer + example-supplied `p5_raster` namespace + offscreen-2D interpreter, so `save_canvas`/`load_pixels` work without touching the shared web runtime. | `69f0afff` 2026-11-18 |

## Platforms, hosting, and developer loop

| Plan | Outcome | Landed |
|---|---|---|
| `window-host-lifecycle-unification` | `wzzc-dev/window` keeps the physical event loop; MoUI `window_host` owns logical lifecycle, surface generation, window registration, frame coordination. | `71d9a74a` 2026-08-30 |
| `window-hosted-legacy-cleanup` | Retired mobile packaging/embedding entrypoints; window-hosted entrypoints are canonical. | `c5edfbf8` 2026-08-04 |
| `window-upstream-sync` | Rebased the fork onto the `moonbit-community/window` workspace layout and split branches. | `68dfba21` 2026-08-06 |
| `moui-support-upstream-workspace` | Finished the upstream-layout migration, published a compatibility release, restored the default workspace. | `71d9a74a` 2026-08-30 |
| `macos-first-present-visibility` | Mo Desktop/Mo Workbench hide until the first successful Metal presentation. | `5aae00a5` 2026-08-08 |
| `webview-window-drag` | WKWebView top-bar controls stay clickable while blank space drags the native window. | `85831e48` 2026-08-18 |
| `webview-moui-overlay` | MoUI overlay pixels and pointer input work above macOS WKWebView siblings. | `85831e48` 2026-08-18 |
| `p1-daily-developer-efficiency` | Dev loop, structured Inspector, performance budgets, scalable data-view primitives. | `841370e6` 2026-08-23 |
| `p2-platform-ecosystem` | App-facing platform service contracts, deterministic packaging/publishing, compatibility governance. | `c49498e3` 2026-08-23 |
| `moui-cli-desktop-commands` | `moui run/build/package` covers all platforms with in-process MSVC env and packaging helpers absorbed into the CLI. | `a21c7e3c` 2026-09-16 |

## Web presentation and website

| Plan | Outcome | Landed |
|---|---|---|
| `web-first-click-dpr-fix` | Website control activates on the first physical click after DPR synchronization. | `4b1415ef` 2026-07-20 |
| `web-input-router-consolidation` | `moui/backend/web` is the single owner of trusted browser pointer routing. | `68dfba21` 2026-08-06 |
| `website-scroll-performance` | Removed avoidable DOM/input work from the Web presentation path; text selection and accessibility preserved. | `62ecb11b` 2026-08-03 |
| `website-showcases-single-scroll` | Single-scroll Showcases page with screenshot virtualization and accurate platform/source metadata. | `d8a3de54` 2026-07-30 |
| `markdown-html-image-gallery` | Markdown Editor renders the safe, presentation-only HTML image-gallery subset while source/export stay lossless. | `70c1c721` 2026-07-19 |
| `markdown-scroll-layer-spacing` | Retained paint-layer bounds seeded from the layer frame, so cached rich-text keeps local coordinates and headings stop drifting across the viewport origin. | `36bdf5f1` 2026-11-14 |
| `i18n-website` | Pure `moui_i18n` addon plus `en-US`/`zh-Hans` public website and documentation catalog. | `d8a3de54` 2026-07-30 |

## MoUI Studio product line

| Plan | Outcome | Landed |
|---|---|---|
| `moeui-studio` | Mo易 Studio (Chinese DSL + form designer + proposal AI); replaced and its code removed 2026-09-27 by MoUI Studio. | `f5cdfac6` 2026-09-28 |
| `moblocks-studio` | MoBlocks Studio (block workflow + AI proposals + export) shipped for the 2026-10 contest; replaced by MoUI Studio. | `f5cdfac6` 2026-09-28 |
| `moblocks-studio-v2` | Post-freeze additions: Web canvas drag regression, mortise/puzzle block shapes, four-zone IDE layout. Replaced by MoUI Studio. | `f5cdfac6` 2026-09-28 |
| `moui-studio` | Single bilingual block/code-same-source IDE replacing both Mo studios: one program IR drives design/blocks/bilingual-code views and structured AI proposals. | `29640e93` 2026-11-01 |
| `moui-studio-plugin-kernel` | Static plugin kernel (Plugin contract/service registry/event bus), three-mode workbench, full AI mode, editor polish. | `7cb2f3ad` 2026-10-11 |
| `moui-studio-capability-upgrade` | Eight slices toward a mature IDE: real code editor, runtime inspector, diagnostics, keyboard/process hygiene, language and control surface growth. | `7cb2f3ad` 2026-10-11 |
| `moui-studio-workbench` | Project workbench: MoonBit files as source of truth, three preview modes, drag layout designer, `.studio.json` retired. | `7cb2f3ad` 2026-10-11 |
| `moui-studio-folder-projects` | New projects land in a chosen local folder (moon.mod + compilable skeleton + IR snapshot); AI proposals write through the project channel; fake offline model removed. | `7cb2f3ad` 2026-10-11 |
| `moui-studio-props-v2` | Typed `ControlProps` (size/bold/color/align/visible/disabled + TextField trio) with codec defaults and an inspector panel through the undo point. | `7cb2f3ad` 2026-10-11 |
| `moui-studio-blocks-standalone` | OnStart form-level event, `ForEach`, builtin completion, fully reachable statement skeletons, dual-track differential gate. | `7cb2f3ad` 2026-10-11 |
| `moui-studio-workspace-feel` | Multi-tab editing with caret/close/save-all semantics, file CRUD, full-text search, save-triggered live diagnostics. | `7cb2f3ad` 2026-10-11 |
| `moui-studio-markdown-plugin` | `.md` opens the MoMark rich-text editing surface as a stateless view-contribution plugin reusing the existing draft/save channel. | `7cb2f3ad` 2026-10-11 |
| `moui-studio-workspace-import` | `moon.work` members imported per module with scale limits and persisted project records (`.studio/projects.json` v1, silent rescan). | `7cb2f3ad` 2026-10-11 |
| `moui-studio-ai-chat` | AI mode became a dialog transcript workbench: user bubbles, markdown AI messages, work-card timeline, composer info layer, session list, native session files. | `7cb2f3ad` 2026-10-11 |
| `moui-studio-ai-look` | Second AI-mode pass replicating the VS Code agent-mode empty state: two-line session rows, header actions, chip row, prompt folded into the composer card. | `ad13077a` 2026-10-07 |
| `moui-studio-standalone-subrepo` | Studio extracted to `wzzc-dev/moui_studio` via subtree split, mounted as a submodule, with `moon.work`/checks/docs references synced. | `80317ec8` 2026-10-09 |
| `moui-shared-markdown-components` | MoMark's Markdown chrome (find/replace, outline folding, format panel, document info, HTML export, Msg-generic views) extracted into the `moui_markdown` addon. | `29640e93` 2026-11-01 |

## TUI output path

| Plan | Outcome | Landed |
|---|---|---|
| `tui-output-path` | Existing `@moui.View[Msg]` apps run in a real terminal: S0 cell projection probe → publishable cell buffer → pure-MoonBit `moui_tui_renderer` → terminal backend input → dual-pane split → PTY evidence. | `2e979622` 2026-10-16 |
| `tui-hardening` | Closed the path into a governed surface: contract-ified projection, theme→ANSI palette, deterministic PTY gate in nightly, `tui_layers` as the only dual-pane gate. | `2e979622` 2026-10-16 |

## Tooling, CI, and repo hygiene

| Plan | Outcome | Landed |
|---|---|---|
| `skia-manual-smoke-prebuild-migration` | macOS/Linux/Windows smoke runners moved off `configure-*-native-pkg --write` + `MOON_CC` onto the `build.mbtx` prebuild env; package rewrites and real-Skia disable switches removed. Migration landed 2026-11-22; per-OS CI markers confirm the next run. | pending |
| `all-target-diagnostics-cleanup` | `moon check --target all` clean; no compiler warnings outside `window/` packages. | `a982053b` 2026-08-04 |
| `governance-ci-docs-and-p5-layering` | Governance tools got whitebox suites (zero-test ceiling 0); the PR gate split into `pr-static` (ubuntu, Linux-host only) / `pr-native` (macOS, the one runner with ObjC++ and real Skia link), with landing-only packaging/benchmark jobs, dev triggers, and per-job timeouts; `docs/` ratcheted to a 40,000-line budget after the ai-sessions/plans/zh-Hans diet; the p5 slice became the `moui_p5` addon with port-injected file IO; and the Skia C++ stub moved into the `build.mbtx` prebuild (`/std:c++20`), so Windows runs without `MOON_CC=clang-cl`. CI run `44433924728` green. | `528ad3dd` 2026-11-19 |
| `repo-format-and-ratchet-drift` | Repository-wide format drift and stale source-file ratchets fixed 2026-09-26: regenerated facts, six ratchets re-registered, five files formatted. | `a29eb8e3` 2026-09-26 |
| `row-child-hit-testing` | Reported row-child pointer miss re-checked on moon 0.1.20260920 and closed as a coordinate-space misdiagnosis; behavior pinned by a regression test. | `a29eb8e3` 2026-09-26 |

## Product examples

| Plan | Outcome | Landed |
|---|---|---|
| `ai-world-engine` | `examples/ai_world` grew into a web-first AI world engine: per-world Markdown folder database, in-UI character setup, real provider conversation, AI-generated worlds. | `91a90e9f` 2026-11-09 |
| `ai-world-product` | Turned the example into a local-first AI narrative tool (cross-refresh authorization, incremental writes, export, dialogue editing, character art, world-book hits) and graduated it to `wzzc-dev/new_world`. | `91a90e9f` 2026-11-09 |

Retired plan bodies are not re-created; reopen a subject by writing a fresh
`docs/plans/active/<id>.md` and citing the git history above.
