# 2026-09-02: Markdown editor hot-path overhaul (P1/P2) + public-surface convergence (P3) + undo merge window

- **Agent**: ZCode agent (goal mode)
- **Goal**: Without changing the canonical-Markdown-source + `MarkdownDocumentSession` architecture, reference `/Volumes/Data/Code/moon/md_mbt` techniques (read-only, no dependency) to fix four review findings: P1 no real soft-wrap at narrow width; P2 O(n) scroll-height scan; P2 full parse per keystroke; P3 oversized `moui_richtext` public surface. Prove with GUI-free instrumented tests + before/after benchmarks.
- **Outcome**: Partial-success. All four findings fixed with instrumented proof; P3 landed at 96 pub lines (target ~30) with a documented structural bound; interactive narrow-width/IME/drag-select host check blocked by macOS Screen Recording permission.

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
moon test moui_richtext --target native                       # 197/197
moon test examples/markdown_editor/app --target native        # 420/420
moon test moui_richtext/code_editor examples/code_editor/app  # 22/22 (incl. 9 undo-window wbtests)
moon build examples/markdown_editor/web_wasm --target wasm-gc # ok
moon build examples/markdown_editor/macos_skia --target native # ok (via smoke rebuild)
scripts/macos-skia-renderer-smoke.sh --run-showcase-smoke --run-markdown-smoke # EXIT=0, 0 warnings, first-frame verified
node scripts/validate-guidance-consistency.mjs                # ok
# plus pre-push static trio (maintenance-baseline, api-surface, release-module-closures,
# guidance-consistency, renderer-capability-consistency, doc-references) — see goal transcript
```

Benchmark counters are compiled-in package-private refs (`hot_path_*`) + gated `MOUI_EDITOR_HOT_BENCH=1` harness; wheel/rebuild paths assert 0 height-walk blocks in tests.

## Host check status (P1 acceptance item)

- Skia smoke ran the real markdown editor binary on macOS with the native renderer and verified the presented first frame (`artifacts/skia-renderer-smoke2.log`, `artifacts/macos-skia-smoke2.out`).
- **Blocked**: interactive narrow-width long-paragraph / drag-select / undo-feel verification requires screenshots; macOS Screen Recording is not granted to `ZCode Computer Use.app` (accessibility-only queries work). Grant it in System Settings → Privacy & Security → Screen Recording, reopen ZCode, then re-run `./_build/native/debug/build/examples/markdown_editor/macos_skia/macos_skia.exe` and check: long paragraph wraps at narrow width with caret/click landing on the right visual line, multi-line drag paints per-line bands, typed word disappears in one Cmd+Z. IME composition memoization is covered deterministically by tests instead.

## Follow-Up

- [ ] Host check of narrow-width/IME/drag-select after Screen Recording permission grant (commands above).
- [ ] `markdown_editor_substring` O(source) debt in `examples/markdown_editor/app` — dominant residual of the ≈19 ms steady rebuild.
- [ ] P3 final step to ~30 pub lines: relocate markdown editing domain model out of `moui_richtext` into the app package (needs plan doc; `docs/plans/debt/` does not exist yet — use `docs/plans/active/`).
- [ ] Undo grouping app test depends on real clock < 500 ms between dispatched keystrokes; consider injecting the fake clock through the app runtime if it ever flakes.

## Promote

- [x] Short durable facts → `memories/repo/markdown-editor-hotpath.md`
- [x] Docs synced EN + zh-Hans
- [ ] ADR not required (no invariant change)
- [x] Follow-ups listed above (substring debt, P3 relocation plan, host check)
