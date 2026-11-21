# Plan: Sun route interactive parity with Skia (macOS)

- **Status**: active
- **Archive note**: work is in the working tree; archive to `done/INDEX.md`
  with the landing sha once committed
- **Goal**: Make `examples/showcase` on the Sun CPU renderer route feel like the
  Skia route interactively — slider drag follows the pointer, hover feedback is
  immediate, text input works (caret correct, Chinese IME supported) — with
  every fix attributed by measurement first and closed by reproducible evidence.
- **Non-goals**:
  - Promoting Sun to default renderer or changing its positioning (ADR 0023).
  - GPU acceleration for Sun (separate plan); pixel-level visual parity is owned
    by `sun-visual-parity.md`. This plan covers interaction behavior, input,
    and latency.
  - Optimising the Skia route itself.
- **Do-not-regress**: release cold ~31 ms / warm ~11.5 ms (previous plan's
  evidence); tolerance ±10%.

## Skia-vs-Sun sweep table (all rows closed or recorded)

All rows below were verified with real GUI automation on the release Showcase
(System Events keystrokes + CGEvent clicks, window at 410,100 pt; capture
crops under `/tmp/` are session evidence, numbers recorded here):

| Interaction | Evidence (Sun vs Skia) | State |
|---|---|---|
| Page sweep: Welcome / Patterns / Button / Text Field / Text Area / Clearable / Password / Number / Stepper / Checkbox / Toggle / Radio | Side-by-side release captures of all 12 showcase pages: layout, states and content identical (Button page: identical variant row + State card; Text Field: identical value + mirror). | closed — no differences |
| Slider drag cadence | Mask caches smaller than the page's line count thrashed (518 ms/frame at 360 lines, 1.9 fps debug). Capacities 256→2048. Synthetic drag (40 moves, ~1200-command page): Sun debug 33.3 fps / release 73.9 fps vs Skia 56.2 / 87.6; Sun release p50 13.5 ms vs Skia 11.3 ms — within one refresh. | fixed + measured |
| Hover | Pixel-diff of the Tonal button with pointer over vs away: Sun diff region x 632–772 pt / y 324–363 pt (20804 px), Skia x 632–772 / y 324–363 (20442 px) — same hover area and magnitude (<2% count delta). | closed — parity |
| Caret position | Fixed from even-split to per-glyph pen positions (regression test `A A → [0, 10, 15, 25]`); real-click captures: caret lands at the same glyph gap on both routes (state 01). Near-boundary clicks can differ by one character because the shapers' advances differ slightly — recorded as a known limitation in `docs/platform-notes-macos.md`. | fixed + real-click captures |
| Caret insert / delete / selection | Real keyboard + mouse sequence (type `X` at caret, click mid-word, `shift+←`×4, forward-delete): typed insertion lands at the same glyph, selection covers the same 4 characters with the same gray band, delete removes the same span, on both routes (states 02/03/04/05). Caret blink: neither route blinks (caret solid while focused) — parity by absence; recorded in platform notes. | closed — parity |
| Chinese IME (real system, WeType pinyin) | Real keystrokes with WeType active: composition preedit + inline underline render inside the field, the candidate window anchors at the caret, committed 你世界 lands in the field and the `Value:` mirror on Sun; Skia commits 你好世界 identically. Root cause of the original report: `apply_ime_request_data` dropped the surrounding text (window submodule, fixed) — the first fix attempt to the Enable path was a misread and was reverted; the real defect was the apply step. Sync trace (`PROBE sync`): EnableIme on focus, UpdateIme per composition, caret 16→17→20. | fixed + real-IME captures on both routes |
| Chinese glyphs | Sun's macOS font stack had no Han coverage; parser gained `ttcf` + `true` sfnt + lazy glyph decode (Arial Unicode 344→7 ms, Songti 63 MB 14 ms); renderer registers Arial Unicode lazily (Songti backstop) so CJK shares Arial's sans-serif texture; coverage + ink test green. | fixed + test |
| Scroll | Synthetic scroll-wheel injection is not delivered by AppKit in automation contexts (probe: `scrollWheel:` never fires for CGEvent scroll, both routes); PageDown does not scroll the welcome page on either route either. The scroll pipeline is shared renderer-independent code (AppKit scrollWheel → runtime Scroll → container). | known limitation (automation environment), recorded in platform notes |
| Animation | The Welcome ball canvas is paused-by-default and below the fold (button unreachable without working wheel scroll); the animation frame loop is the same pump the drag smoke measures continuously (33–74 fps across builds/routes). | known limitation (verification access), pipeline covered by drag measurement |
| **Mixed-script baseline** (user report, 11-21) | CJK sat visibly below the Latin baseline in mixed runs ("中文明显靠下"). Root cause: the fallback span loop laid each span out at `line_top + ascent(span_face)*scale`, and Arial's ascent (1854/2048 upem) is smaller than Arial Unicode's (2189/2048), so CJK dropped ~2.4 px at 15 px. Repro test with ascent 10 primary vs ascent 14 fallback shows the old code drawing the fallback 4 rows low at 10 px. Fix shifts every fallback span by the primary's ascent so all spans share one baseline. Real-window ink measurement after the fix: Sun "Showcase" bottom 698 vs CJK 700, Skia 699 vs 702 — within one device pixel. | fixed + repro test + real captures |
| **Gray vertical bands** (user report, 11-21) | Sun-only solid #e5e5e7 bands behind page content (x ≈ 668-772 pt, growing taller per navigation; absent on Skia). Root cause was NOT a command: `Canvas::solid_pattern_for` reused its opaque colour row on colour match alone, so a wide shape could blit the tail of a narrower shape's leftover row (`fill_solid_span_row` reads pattern `[0, width)`). Reproduced offscreen by rendering welcome→text-field→text-area→clearable through ONE renderer (band geometry matched the window, +32 titlebar); per-command RLE showed row 120 turning `… 251,251,252 | 229,229,231 | 251,251,252 …` inside a single background fill. Fix tracks the filled prefix width; regression `Canvas::fill_rounded_rect keeps solid colour row in step with width` fails on the old code at x=120 (red instead of green). Sequential probe after the fix: no wide runs of #e5e5e7; release window captures of Text Field/Text Area/Clearable and Clearable-again are clean. | fixed + offscreen repro + real-window captures |

Sweep harness: sidebar clicks at fixed points (565, y) navigate all pages;
page content crops compared via pixel diff; harness scripts live in `/tmp`
(session-local, re-runnable).

## Evidence

### IME runtime smoke (both routes, 8 markers each)

`moui_tests/tester/macos_sun_ime_smoke` / `macos_skia_ime_smoke` — candidate
anchor, surrounding text, composition visual, commit+delete, cursor update,
scroll anchor, scale-DPR anchor, resize anchor: **all pass on both routes**
after the fixes. The CI platform-evidence IME step is vacuous today: it sets
`MOUI_MACOS_NATIVE_IME_EVIDENCE=1` on the showcase, which nothing reads.

### Synthetic drag smoke (40 pointer moves, heavy page)

`moui_tests/tester/macos_{sun,skia}_drag_smoke` over `fixtures/slider_drag_app`
(~30 cards × 12 text rows + slider ≈ 1200 commands — heavier than the Showcase
first screen):

| Route | build | p50 | p95 | fps |
|---|---|---|---|---|
| Sun | debug | 29.8 ms | 31.8 ms | 33.3 |
| Sun | release | 13.5 ms | 16.9 ms | 73.9 |
| Skia GPU | debug | 17.6 ms | 20.7 ms | 56.2 |
| Skia GPU | release | 11.3 ms | 12.4 ms | 87.6 |

Before the cache fix the same Sun debug page measured **518 ms / 1.9 fps**.
Sun release stays within one refresh of Skia; the remaining debug gap
(33 vs 56 fps) is unoptimised MoonBit code generation on the CPU replay path.

### Regression gates

`moon test moui_sun/text` 149/149, `moui_sun/graphics` 616/616,
`moui_sun/renderer` 150/150, `moui_sun_renderer` 129/129,
`moui/backend/macos` 55/55,
`moui/backend/common` 11/11. Nine pre-push validators green; `moon fmt --check`
clean. Showcase first screen unchanged: cold ~32 ms, warm ~10.5 ms.

## What changed

- `moui/backend/macos/macos_native_ime.mbt` + `macos_app_handler.mbt` +
  `macos_backend.mbt` + `macos_app_runtime.mbt`: IME smoke re-entrancy guard
  (`native_ime_runtime_smoke_in_present`), phase-0 waits for the key window,
  first-frame auto-exit disarmed while a smoke owns the run; new synthetic
  slider-drag smoke (`macos_drag_smoke.mbt`) with per-present interval
  recording.
- `window/modules/window/macos/window.mbt` (submodule): `apply_ime_request_data`
  now applies the surrounding text like Windows/Linux/iOS. **Needs a window
  publish + MoUI pin bump to reach non-local builds** (see
  `memories/repo/` window release loop); until then, run with
  `sh scripts/window-dev-mode.sh on`.
- `moui_sun/text/parser.mbt` + `tables.mbt` + `font_face.mbt`: `ttcf`
  collections (per-face table directories, `true` sfnt tag allowed), glyph
  outlines decode on demand with a memo (`Font::get_glyph` /
  `Font::decode_glyph`); `FontFace::from_data` accepts a collection index.
  Core-table errors stay at parse time; glyph outline errors moved to decode
  time and tests were rewritten to the new contract
  (`render_text_mask_face` degrades malformed outlines to empty ink).
- `moui_sun_renderer/renderer_font_faces.mbt` + `renderer.mbt` +
  `renderer_text_layout.mbt`: lazy CJK fallback registration on the first
  uncovered run (`register_platform_cjk_fallback`: Arial Unicode → Songti SC;
  Hiragino is CFF/OTTO and stays unparseable), registered under its own family
  so it only joins the fallback tail.
- `moui_sun_renderer/renderer_text_draw.mbt`: caret positions from real glyph
  pen positions (`measure_single_line_text`), missing spans keep the even-split
  estimate.
- `moui_sun/renderer/renderer_text.mbt`: fallback spans are laid on the primary
  face's baseline — `fallback_span_y` offsets each span by the difference
  between the primary and span ascent, since per-face layout put CJK ~2.4 px
  low next to Latin at 15 px. Regression test
  `Renderer::draw_text_fallback_line keeps one baseline across ascenders`
  (ascent 10 vs 14) fails on the old code at (14, 4); the TTF fixture builders
  in `renderer_ttf_fixtures_test.mbt` gained an `ascent~` parameter.
- `moui_sun/graphics/canvas.mbt` + `canvas_shape_coverage.mbt`: `solid_pattern_for`
  records the prefix width written for the current colour and refills when a
  wider row is requested; `fill_solid_span_row` blits `[0, width)` so reusing a
  longer row without refilling painted the previous shape's colour into the new
  one (the #e5e5e7 bands). New regression test in `canvas_shape_test.mbt`.
- Mask caches 256 → 2048 (`moui_sun_renderer/renderer.mbt`), text-run cache 512 → 2048.
- New fixtures/entries: `moui_tests/tester/fixtures/slider_drag_app`,
  `macos_sun_ime_smoke`, `macos_sun_drag_smoke`, `macos_skia_drag_smoke`.

## Known limitations / follow-ups

- The macOS window IME fix needs a window release + pin bump; CI evidence for
  IME currently runs nothing (the platform-evidence env var is unconsumed) —
  wire the per-route smoke fixtures into `scripts/macos-skia-renderer-smoke.sh`
  and the platform evidence workflow.
- Mask caches are fixed-size: a page with >2048 distinct text lines thrashes
  again. A scale-with-page knob or LRU sweep is future work.
- Debug-build replay is codegen-bound (~2× Skia debug on the heavy page);
  damage/partial replay is the architectural lever if that matters.
- Hiragino faces (CFF/OTTO) remain unparseable by the Sun font parser;
  Arial Unicode is primary and Songti SC is the coverage backstop. Arial
  Unicode's CJK is sans-serif like the Latin Arial stack; Songti's serif CJK
  read as a different typeface next to Latin text (user report, fixed by the
  candidate order).

## Acceptance

- [x] Release pointer-move→present ≤ Skia + 1 frame (drag smoke: 13.5 vs
      11.3 ms); debug drag holds ≥30 fps (33.3).
- [x] Hover: pixel-diff parity on the Tonal button (same region, <2% delta).
- [x] Caret position/insert/delete/selection parity with real keyboard+mouse
      captures; caret follows per-glyph advances (regression test).
- [x] Chinese input via the REAL system IME (WeType pinyin) verified on the
      macos_sun showcase: composition + candidate anchoring + commit into the
      model, plus the deterministic IME smoke (8/8) covering the Sun route.
- [x] Sweep table closed for all 12 showcase pages + scroll/animation rows
      recorded as known limitations (platform notes updated).
- [x] Release cold ≤35 ms (32.3), warm ≤13 ms (10.5).
- [x] Sun packages, backend macOS/common tests green; 9 validators green;
      `moon fmt --check` clean.
- [x] Evidence recorded here; archive with landing sha after commit.

## Decision log

| Date | Decision |
|------|----------|
| 2026-11-21 | Fix the IME smoke harness first (it was silently broken for both routes) so "IME events broken" can be separated from "glyphs missing". |
| 2026-11-21 | Per-glyph outlines decode lazily rather than shipping a smaller face: coverage/metrics parse up front, outlines cost only for drawn glyphs; glyph-error tests rewritten to the decode-time contract. |
| 2026-11-21 | CJK face registered lazily on the first uncovered run instead of at startup, keeping the 31 ms cold start. Arial Unicode first: sans-serif CJK matches the Arial Latin stack and parses in 7 ms; Songti (serif) stays as the backstop. Hiragino is CFF (OTTO) and stays unparseable. |
| 2026-11-21 | Carets from the span layout's glyph pen positions; even division kept only for missing (placeholder) spans. |
| 2026-11-21 | Cache capacity raised to a fixed 2048 rather than dynamic scaling; a page above it thrashes and is recorded as a known limitation. |
| 2026-11-21 | Fallback spans align to the primary face's baseline (`y + primary_ascent - span_ascent`) instead of their own ascent: one line of mixed scripts must sit on one baseline, and the faces' differing ascents otherwise shift CJK runs down. |
| 2026-11-21 | Synthetic drag smoke drives one pointer move per presented frame so Sun/Skia (and debug/release) compare the identical interaction loop. |

## Progress

| Date | Note |
|------|------|
| 2026-11-21 | Repo state verified (dev, sun merged at `c0fb5a30`); font stack, caret paint path, IME smoke fixture located. |
| 2026-11-21 | IME smoke un-hung (re-entrancy + key-window wait + auto-exit race); macOS window surrounding-text drop fixed; both route smokes pass 8/8. |
| 2026-11-21 | Sun font parser: TTC + `true` tag + lazy glyph decoding; Arial Unicode 344→7 ms, Songti.ttc parses at 14 ms; CJK coverage test green with ink. |
| 2026-11-21 | Caret even-split root-caused and fixed; `A A` regression test pins exact advances. |
| 2026-11-21 | Drag smoke built; 360-line mask-cache thrash found (518 ms/frame) and fixed; 4-way cadence measured (Sun release 73.9 fps, within one refresh of Skia). |
| 2026-11-21 | Real-GUI verification pass: 12-page sweep captures, caret/insert/delete/selection sequences, hover pixel-diff parity, and real WeType IME composition/commit on both routes (the earlier "ASCII only" trace was a probe script bug — it never navigated to the Text Field page). |
| 2026-11-21 | Platform notes: IME verification status + known limitations (vacuous CI env var, synthetic wheel not delivered, no caret blink, near-boundary click caret variance). |
| 2026-11-21 | User-reported follow-up: caret drawn mid-word after the first CJK commit. Root cause: the commit frame's view-side measure ran BEFORE the lazy CJK face registration (which lived only in the draw path), so carets used the missing-span estimate while the draw already rendered full-width glyphs; no further rebuild kept the stale caret on screen until the next keystroke. Fix: measure_text_layout now runs the same lazy-registration trigger (idempotent flag shared with the draw path). Verified with real WeType input: caret lands after 好 on the commit frame (trace cursor_x 29.2→42 pre/post fix). Regression test pins measure-only carets 你好 → [0, 14, 28]. |
| 2026-11-21 | window 0.5.4-0.2.13 published (0.2.12 was already taken on 11-18 without the fix); all MoUI consumers aligned; registry download host quirk (download.mooncakes.io 404/DNS vs mooncakes.io working) worked around by pre-warming ~/.moon/registry/cache. |
| 2026-11-21 | Mixed-script style follow-up: the field showed Arial Latin beside Songti serif CJK, which read as two typefaces. Candidate order now prefers Arial Unicode; the rebuilt release's `Showcase Compone你好nts` field and `Value:` mirror match the Skia capture's sans texture (side-by-side crops near-identical). |
| 2026-11-21 | Mixed-script baseline follow-up closed: per-span `ascent(span_face)` layout put Arial Unicode CJK ~2.4 px below the Arial baseline (ascent 1854 vs 2189 per 2048 upem at 15 px). Spans now shift to the primary face's baseline via `fallback_span_y`; regression `keeps one baseline across ascenders` (10 vs 14) fails on the old code at (14, 4). Rebuilt release: Sun ink bottoms 698/700 vs Skia reference 699/702 — CJK aligned within one device pixel. |
| 2026-11-21 | Gray-band follow-up closed: root cause was the opaque solid colour-row scratch reusing a longer row after a narrower shape refilled only its prefix; `fill_solid_span_row` then blitted a stale tail. Fixed by tracking the filled width; offscreen sequential probe (4 routes, one renderer) shows no #e5e5e7 strip, and the rebuilt release showcase's Text Field/Text Area/Clearable pages are clean. Real WeType re-check on the rebuilt binary: commit caret after 好, continued typing at the end. |
