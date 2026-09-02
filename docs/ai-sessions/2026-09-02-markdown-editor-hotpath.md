# 2026-09-02: Markdown editor hot-path overhaul (P1/P2) + public-surface convergence (P3) + undo merge window

- **Agent**: ZCode agent (goal mode)
- **Goal**: Without changing the canonical-Markdown-source + `MarkdownDocumentSession` architecture, reference `/Volumes/Data/Code/moon/md_mbt` techniques (read-only, no dependency) to fix four review findings: P1 no real soft-wrap at narrow width; P2 O(n) scroll-height scan; P2 full parse per keystroke; P3 oversized `moui_richtext` public surface. Prove with GUI-free instrumented tests + before/after benchmarks.
- **Outcome**: Success on the acceptance-relevant fixes; the host check exposed two stacked pre-existing host rendering bugs (SkParagraph UTF-16 line metrics; wrong-typeface glyph painting for CJK), both fixed with host-gated regression tests. P3 landed at 96 pub lines (target ~30) with a documented structural bound; the remaining convergence needs a domain-model relocation, planned separately.

## Summary

The markdown editor hot paths were reworked on top of the unchanged session architecture: keystrokes now re-parse only the affected block cluster with offset rebase (guarded full-parse fallback), scroll geometry persists a measured-height prefix-sum index queried by binary search, and paint/height/caret/hit-test/copy/selection share one memoized soft-wrap layout per block so narrow-width soft wrap is real and consistent. Keystroke undo now groups contiguous same-kind edits within a 500 ms window. `moui_richtext`'s public surface was halved by privatizing internals and deleting dead code, taking the production build from 36 new warnings to zero.

## Benchmark (same fixture `docs/markdown-editor.md`-class 79 KB doc, same machine, instrumented counters, `MOUI_EDITOR_HOT_BENCH=1`)

| Path | Before | After | Counter evidence |
|---|---|---|---|
| End-of-doc keystroke (big doc) | 123 680 µs/keystroke | 11 845 µs/keystroke | `full_parses=0`, `region_reparses=80/80` steady |
| Wheel scroll step | 22 815 µs | ≈284 µs | height-walk `0` blocks/wheel (3901-block first build amortized) |
| Session rebuild (steady) | 37 213 µs | ≈19 ms | geometry 180 µs, walk 0 blocks, conversion builds 0, wrap builds 0 / 23 cache hits |

Residual ≈19 ms rebuild is dominated by the pre-existing `markdown_editor_substring` O(source) copy debt (app package), not by parse/scroll/wrap.

## Changes Made

| Package/File | What Changed | Why |
|---|---|---|
| `moui_richtext/editor_session.mbt` (+helpers) | Incremental `apply`: re-parse affected cluster, stitch with offset rebase; guards (fence/HTML/table/footnote/bracket/global-context) fall back to full parse; dirty-range tracking | P2 parse |
| `moui_richtext/editor_session.mbt`, layout cache | Persisted measured-height prefix-sum index keyed by font/width/source, epoch-invalidated on measured-height change; content height O(1); visible window by binary search | P2 scroll |
| `moui_richtext/rich_text_editor*.mbt`, wrap memo | One memoized soft-wrap layout per block per content width shared by paint/height/caret/hit-test/copy/selection; per-line selection bands; copy strips injected soft breaks | P1 soft wrap |
| `moui_richtext/rich_text_editor_history.mbt` (new) + push gates in `rich_text_editor_helpers.mbt` / `rich_text_editor_caret_hit.mbt` | Undo merge window: contiguous same-kind single-char edits within 500 ms merge into one undo entry; newline/paste/selection-replace/undo/redo reset | undo feel |
| `moui_richtext/*` (P3) | 52 declarations privatized, consumer-closure verified; dead code deleted (`text_viewer` + `TextViewerNode`, `controlled_rich_text_document_editor`, `caret_rect_at_source`/`source_offset_y`/`visible_block_count` methods, 16 unused `derive(Eq, Debug)`, unused `MarkdownReferenceDefinition.title` field + `markdown_trim_reference_title`) | P3 surface + warning hygiene |
| 4 blackbox tests → `_wbtest.mbt` | Compiler-forced (privates referenced) | P3 |
| `docs/markdown-editor.md`, `docs/zh-Hans/markdown-editor.md` | Hot-path paragraphs (incremental reparse, persisted scroll geometry, shared soft-wrap) + undo grouping bullet | doc sync |
| `examples/markdown_editor/app/editor_app_keyboard_runtime_wbtest.mbt` | Undo expectation `#` → `""` after two-char typing | intentional behavior change from merge window |
| `moui_skia_renderer/renderer_text_caret.mbt`, `renderer_text_system.mbt` | `skia_utf16_char_offsets` table: SkParagraph `fStartIndex`/`fEndIndex` are UTF-16 code units, previously mapped through the UTF-8 byte-offset table | fixes host CJK wrap corruption (see Host check findings) |
| `moui_skia_renderer/skia_renderer_test.mbt` | Host-gated regression: CJK/Latin mixed paragraph line metrics are contiguous character ranges ending at the text length | guards the UTF-16/UTF-8 unit fix |
| `moui_skia_renderer/renderer_text_glyphs.mbt`, `renderer_text_layout.mbt` | Typeface candidates (embedded/font-files/fallback-request) accepted only when their own cmap covers the text; payload accepts a shaped run only when its font covers the text | fixes CJK painting blank on GPU: shaper-fallback glyph ids no longer painted through an unrelated primary typeface (see Host check findings) |
| `moui_skia_renderer/skia_renderer_text_wbtest.mbt` | Host-capability-aware regression: CJK payload font must map every character through its own cmap | guards the glyph-id/drawing-typeface invariant |
| `examples/markdown_editor/{app/app.mbt,runtime.mbt,macos_skia/main.mbt,macos_skia/moon.pkg}` | `macos_skia <document.md>` command-line argument opens the document at startup via `Effect::send(OpenRecentDocument(path))` from program init (same message as the recent-files menu) | user request: open a document directly from the command line |
| `examples/markdown_editor/app/editor_app_initial_document_wbtest.mbt` (new) | Init effect carries `OpenRecentDocument(path)` iff a non-empty initial path was given; app suite 422/422 | guards the CLI-open wiring |
| `examples/markdown_editor/app/{app.mbt,editor_state_edits.mbt,document_io.mbt,view_chrome.mbt}` + `editor_app_contextual_runtime_wbtest.mbt` | `selection_engaged` flag: block target palette (HTML/table/link/image/footnote toolbar) only surfaces after a user selection/edit places the caret; opening a document with the default caret at offset 0 no longer pops the palette when the first block is rich; regression test asserts engage-on-selection / reset-on-load (app 423/423) | user request: floating bar should not show until clicking into a block |
| `moui_richtext/markdown_model.mbt` | Blockquote text falls back to the marker-stripped source line when per-line re-parse of quoted children flattens it to empty and the content is a fence line (`markdown_quote_block_text`) | user report: quoted ```powershell fence inside `README.zh-CN.md` blockquote rendered as two tall blank bands |
| `moui_richtext/markdown_model_inline.mbt` | `markdown_inline_text` concatenates flattened inline nodes instead of joining them with `\n` (SoftBreak/HardBreak nodes already flatten to newline; joining added a newline *per node*) | same screenshot: inline-code span split by inserted newlines forced empty quote rows around the command line |
| `moui_richtext/rich_text_document_wbtest.mbt` | Two regressions: quoted fence marker lines stay visible in parsed Blockquote blocks; inline nodes concatenate without inserting breaks (richtext 201/201) | guards the quote-line fidelity and inline-flatten contract |

## Key Decisions

- Incremental parse shipped **before** P1 soft-wrap (implementation-order deviation from the review list) because the scroll benchmark needed a stable parse layer first; both acceptance proofs remain independent.
- ~30 pub-line target structurally unreachable while `MarkdownDocumentSession` keeps `pub(all)` fields typed by dirty-range/height-index/layout-cache internals and `markdown_editor/app` consumes ~35 domain symbols via `using @moui_richtext`; reaching ~30 requires relocating the markdown editing domain model into the app package → tracked as follow-up, not forced.
- MoonBit field-visibility limits (pub struct fields always visible; `pub(all)` vs `pub` differs only for constructors) make accessor-wrapping useless — confirmed experimentally, reverted.
- `title` on reference definitions parsed but never read anywhere → removed rather than suppressed (MoonBit unused-field warnings can't be suppressed; repo has no `@warning.ignore` precedent).
- 4046 (public-depends-on-private) forced 40 restorations (MarkdownDocumentBlock/HeightIndex/LayoutCache/DirtyRange/RichTextWindow/EditResult/ReferenceContext/SourceRange/link/table types) — compiler-driven loop, full `moon test` only (`--no-run` hides 4046).

## Discoveries

- Undo merge tests must drive with **pre-edit** caret; post-edit caret kills contiguity classification.
- `@env.now()` (UInt64 ms) works native/js/wasm and is precedented in library modules (`moui_skia_renderer`); fake-clock `Ref[Int]` (−1 sentinel) keeps undo tests deterministic.
- App-level undo test now relies on the two dispatched keystrokes falling inside the real 500 ms window (fast enough in practice; noted flake risk).
- MoonBit struct *declaration* fields have no trailing commas; `derive` rides on the closing-brace line — script edits must keep the brace.

## Validation

```sh
moon test moui_richtext --target native                       # 201/201 (final, incl. quote-fence + inline-concat regressions)
moon test examples/markdown_editor/app --target native        # 423/423 (final, incl. selection_engaged palette regression)
moon test moui_richtext/code_editor examples/code_editor/app  # 22/22 (incl. 9 undo-window wbtests); app+code_editor combined 440/440
moon build examples/markdown_editor/web_wasm --target wasm-gc # ok
moon build examples/markdown_editor/macos_skia --target native # ok (via smoke rebuild)
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke # EXIT=0, 0 warnings, first-frame verified
node scripts/validate-guidance-consistency.mjs                # ok
# plus pre-push static trio (maintenance-baseline, api-surface, release-module-closures,
# guidance-consistency, renderer-capability-consistency, doc-references) — see goal transcript
```

Benchmark counters are compiled-in package-private refs (`hot_path_*`) + gated `MOUI_EDITOR_HOT_BENCH=1` harness; wheel/rebuild paths assert 0 height-walk blocks in tests.

## Host check findings (P1 acceptance item — completed)

- Skia smoke ran the real markdown editor binary on macOS with the native renderer and verified the presented first frame (`artifacts/skia-renderer-smoke2.log`, `artifacts/macos-skia-smoke2.out`).
- After Screen Recording was granted to `ZCode Computer Use.app` and ZCode restarted, the host check on `README.zh-CN.md` exposed a real rendering bug: CJK/Latin mixed paragraphs wrapped with scattered/missing characters and inline-code spans broke mid-word.
- **Root cause (pre-existing, not a P1 regression)**: SkParagraph reports `LineMetrics.fStartIndex/fEndIndex` in UTF-16 code units, but `skia_paragraph_line_metrics` mapped them through the UTF-8 byte-offset table. Identical for ASCII (which is why all prior tests/smokes passed), drifting ~2 chars per CJK char. Git archaeology: introduced by `c34ea1eec` ("skia: route paragraph layout through SkParagraph"); P1 exposed it by consuming line `text_range` for wrap break positions. Fix: `skia_utf16_char_offsets` + UTF-16-aware conversion at the line-metrics call site; host-gated regression test in `skia_renderer_test.mbt` (failed before the fix; suite 127/127 after).
- **Remaining "still missing Chinese" report was real, not a stale binary.** After the UTF-16 fix was rebuilt and re-opened, the user reported the body paragraph CJK still invisible (Latin visible with gaps, pure-CJK lines blank, text selectable/copyable, correct placeholder widths). That symptom is geometry-intact-but-no-ink: a paint-layer bug, not layout.
- **Root cause #2 (pre-existing, exposed by P1's per-line paint)**: `moonbit_skia_font_shape_text_utf8` shapes through `SkShapers` with a font-mgr fallback, but the FFI run handler flattens the shaped output to `glyphs/positions/clusters` and **drops per-glyph typefaces**. For a CJK segment whose primary typeface lacks coverage — the editor font chain resolves "Open Sans" via the font-files path — the shaper silently substitutes PingFang glyph ids that *look* complete (`missing=0`, correct advances), `skia_glyph_run_can_draw_text` passes, and painting maps those foreign ids through Open Sans's glyph-id space: blank on the Metal canvas. The earlier CPU-raster probe was misleading because mis-mapped ids produce garbage ink there (`dark=900` was garbage, not glyphs). Old pre-wrap code painted the whole paragraph through one fallback typeface, so ids matched and CJK painted.
- **Fix** (`renderer_text_glyphs.mbt`, `renderer_text_layout.mbt`): accept a candidate typeface (embedded, font-files, `match_fallback_request`) only when its own cmap maps every character (`skia_typeface_covers_text`), and require the same invariant at the payload level (`skia_font_covers_text`). Glyph ids are then guaranteed to belong to the drawing typeface; CJK segments now resolve to PingFang SC via `match_fallback_request` and paint identically on raster and GPU.
- **Regression test**: `skia cjk text payload draws with a typeface covering that text` (`skia_renderer_text_wbtest.mbt`) — host-capability aware (skips only hosts with no CJK typeface, following the emoji-fallback convention); fails against the pre-fix resolution chain.
- **Host verification**: frame-end GPU pixel readback (temporary instrumentation, since removed) showed the pure-CJK line going from `dark=0` to `dark=15358`, and a screenshot of the exact user-quoted paragraph rendered correctly in the rich view; README.zh-CN.md source and rich views also render CJK.
- Caret/hit/drag-select/undo-merge interactions at narrow width were exercised deterministically by wbtests rather than re-driven by pointer automation in this pass; the host pass visually confirmed wrap correctness and presentation on the previously broken document.
- A further user report on the same document ("这个中间为什么这么多空行") pointed at two tall blank bands inside a `>` blockquote wrapping a ```powershell fence. Root cause: the quote path re-parses **per source line**, so a quoted fence line re-parses to an empty Paragraph and the Blockquote text collapsed to "" for exactly those lines; separately `markdown_inline_text` **joined** per-node flatten results with `markdown_join_lines`, injecting a newline per inline node (a SoftBreak/HardBreak node already flattens to `\n`). Together these produced full-height empty quote rows around the command line. Fixed in `moui_richtext` (see Changes Made); verified on the rebuilt real-Skia binary opening a README-exact fixture — fence lines and the command paint inline with no gaps.

## Known issue (environmental, pre-existing — not caused by this session's changes)

- Unscoped `moon build --target native` (whole workspace) fails on moon `0.1.20260824`: library packages (`moui_skia/native`, `moui_skia_renderer`, `moui_wgpu_renderer/directwrite`, …) get linked as executables without a `_main` (`Undefined symbols for architecture arm64: "_main"`), after `moon clean --target native`. Reproduced identically on `moui_wgpu_renderer/directwrite`, a package untouched by this session, so the failure mode is independent of the markdown work. No check profile in `checks/profiles.json` runs an unscoped native build (all steps are package-scoped), which is why the repo gate stays green; the sanctioned loops (`moon test <pkg> --target native`, package-scoped `moon build`, the smoke scripts) are unaffected.

## Follow-Up

- [x] Host check of narrow-width rendering after Screen Recording permission grant — completed; found and fixed the UTF-16 line-metrics bug (see Host check findings).
- [ ] `markdown_editor_substring` O(source) debt in `examples/markdown_editor/app` — dominant residual of the ≈19 ms steady rebuild.
- [ ] P3 final step to ~30 pub lines: relocate markdown editing domain model out of `moui_richtext` into the app package (needs plan doc; `docs/plans/debt/` does not exist yet — use `docs/plans/active/`).
- [ ] Undo grouping app test depends on real clock < 500 ms between dispatched keystrokes; consider injecting the fake clock through the app runtime if it ever flakes.

## Promote

- [x] Short durable facts → `memories/repo/markdown-editor-hotpath.md`
- [x] Docs synced EN + zh-Hans
- [ ] ADR not required (no invariant change)
- [x] Follow-ups listed above (substring debt, P3 relocation plan, host check)
