# Text System

MoUI keeps text measurement in the platform-neutral runtime while letting
native and Web hosts install the renderer-backed text system that matches their
platform. The public boundary is `@core.TextSystem`; measurement-only legacy
shapes are no longer part of the framework contract.
Native Skia is the recommended native renderer/text route, Web uses browser
WebGPU plus browser text integration, and the native WGPU provider stack below
remains an explicit diagnostic route for comparing provider behavior.

## Runtime Boundary

- `core/text_layout.mbt` defines `TextSystem`, `TextSystem::fallback()`,
  `TextSystem::layout_paragraph()`, and font data registration. The
  deterministic fallback keeps per-character caret arrays for stable geometry
  while a UAX #29-style `TextGraphemeBoundaries` scanner folds cluster
  interiors back to the cluster start. It covers CRLF/control breaks, Hangul
  L/V/T sequences, Extend/ZWJ/SpacingMark, Prepend, regional-indicator pairs,
  emoji ZWJ sequences, emoji tags, ZWNJ as an Extend boundary, and Indic
  virama/linker conjuncts without swallowing virama followed by Latin text or
  whitespace. The
  paragraph contract returns line metrics, caret rectangles,
  selection rectangles, hit-test results, and visual-order metadata with
  explicit readiness flags, so simplified fallback or diagnostic renderer
  layout can expose geometry without claiming native SkParagraph or bidi
  parity. Core text editing uses the same cluster boundaries for basic
  left/right caret movement and shift-selection.
- `AppRuntime` exposes `text_system()` and `set_text_system()` so hosts can
  install a platform text system before layout, painting, hit testing,
  selection, and IME anchor geometry are produced. The underlying
  `RuntimeState` stores the active system as an engine detail.
- `FontSpec` carries a structured family stack. The default stack is
  `SystemUi`; concrete font names are resolved by the active native or Web
  provider unless app code requests a named family.
- `core/` owns only the neutral contract and deterministic fallback. It does
  not import `Milky2018/moon_cosmic`, `Milky2018/moon_swash`, CoreText,
  DirectWrite, fontconfig, HarfBuzz, FreeType, or browser APIs.

The live text path is:

```text
View[Msg] -> internal view tree -> DrawCommand::DrawText(TextRun) -> active TextSystem measurement -> renderer glyph path
```

Caret positions, selection geometry, wrapping, clipping, and IME request
coordinates should all use the same active `TextSystem` that layout uses.
Rich text runs may contain explicit newline characters; core splits those runs
into line fragments for drawing, hit testing, caret geometry, and document
height so renderer-backed text systems never need to interpret embedded
newlines inside a single draw command.

## Native WGPU

`render/wgpu` owns the native provider protocol, provider response validation,
fallback composition, glyph atlas upload, and renderer-side cache keys. It does
not depend on the standalone Cosmic provider package.

Provider packages are intentionally separate:

- `render/wgpu/cosmic_text/`: Moon Cosmic provider used directly by examples
  that select `MoonCosmic`, and as the fallback provider for platform defaults.
- `render/wgpu/coretext/`: macOS CoreText/CoreGraphics provider. macOS defaults
  to this provider composed with Cosmic fallback.
- `render/wgpu/directwrite/`: Windows DirectWrite scaffold. Windows defaults to
  this scaffold composed with Cosmic fallback until the real DirectWrite engine
  returns platform layout and raster data.
- `render/wgpu/fontconfig/`: Linux fontconfig/FreeType provider boundary.
  Linux defaults to this provider composed with Cosmic fallback. The provider
  can return native color-emoji glyphs from Noto Color Emoji for explicit emoji
  family runs when FreeType and the font are available; broader shaping,
  measurement, and non-emoji raster data still fall back to Cosmic until the
  full fontconfig/HarfBuzz path is implemented.
- `render/wgpu/text_protocol/`: shared native-stub payload protocol for UTF-32
  input, versioned `FontSpec` encoding, measure/run/raster envelopes, and
  embedded-font registration payloads.

Native WGPU text-engine selection belongs to the WGPU provider packages, not to
the platform host cores. Use
`MacosWgpuAppOptions::new(text_engine=...)`,
`WindowsWgpuAppOptions::new(text_engine=...)`, or
`LinuxWgpuAppOptions::new(text_engine=...)` through
`backend/<platform>/wgpu.run_app_with_options`. `PlatformDefault` composes the
platform provider with Cosmic fallback; `MoonCosmic` selects the Cosmic provider
directly. Showcase also has explicit `macos_wgpu_cosmic`, `windows_wgpu_cosmic`, and
`linux_wgpu_cosmic` entrypoints for comparing those paths. The separate Showcase and
Markdown Editor `*_skia` entrypoints select Skia provider packages, not WGPU
text-provider variants. By default, Skia basic text
measurement and drawing
resolve the MoUI `FontSpec` family stack, weight, and style through `moui_skia`
`FontMgr` and `Font`. The system `FontMgr` path now builds a `FontFallbackRequest`
with a representative coverage character, preferring emoji hints, then
non-ASCII code points, then the first code point before falling back to regular
family matching. It also attaches inferred BCP47 script language tags for
emoji, CJK, kana, Hangul, Hebrew, Arabic, Devanagari, Thai, Lao, Sinhala,
Khmer, Myanmar, and Latin/default text so native `FontMgr`
`match_fallback_request` can use language-aware fallback metadata before
family matching. Its `TextSystem` returns Skia font-metric baseline/height
plus caret positions for basic input geometry. When
`moui_skia/native` is linked with SkShaper support, the Skia text system maps
shaped-run source clusters back to MoUI's per-character caret array; otherwise
it falls back to Skia-measured prefix carets. Both caret paths apply
representative combining-mark, Indic matra/virama, Arabic mark, Thai mark,
Lao mark, Sinhala mark, Khmer vowel/coeng, Myanmar mark, Hangul Jamo L/V/T
clusters, keycap,
emoji-modifier, variation-selector,
regional-indicator pairs, emoji tag-sequence flags, Unicode prepend marks, and
ZWJ cluster interior stabilization. Rendering uses the
same optional SkShaper shaped glyph runs when linked, and otherwise falls back
to positioned glyph runs. The mixed-run fallback segmenter follows the same
Indic virama/linker boundary, including virama plus Extend marks before an
Indic consonant, so per-run font fallback does not split that edit cluster.
Skia segmentation and fallback caret stabilization now route through core
`TextGraphemeBoundaries` directly, with Skia white-box tests comparing cluster
slices and IME-facing `nearest_boundary_utf8_offset` conversion against the
core scanner so renderer text proof, editor movement, selection geometry, hit
testing, and host IME requests share one boundary source.
Linux Skia resolves its default `FontMgr` through fontconfig/FreeType
when those Skia port headers are available, with a directory font manager
fallback over common system font directories. If the selected Skia font produces
a blank or incomplete glyph run, the renderer retries measurement and drawing;
the system `FontMgr` path first tries platform emoji font candidates for
emoji-hint text and then falls back to Skia's default font. Complete fallback
runs are accepted immediately, while partial default-font fallback is accepted
only when it reduces missing glyph ids or recovers visible text from a blank
primary run, so startup Showcase text remains visible and text-field caret
positions stay aligned with the drawn glyphs without silently treating an
equally incomplete fallback run as recovered. Skia drawing aligns the selected
glyph run inside `TextRun.frame` and
clips the canvas to that same frame before rasterization, so bounded text
controls use the same platform-neutral frame for measurement, caret geometry,
and native raster output. `skia_text_system()` also inherits the core paragraph
layout contract. In fallback-safe builds it can still produce wrapped line
metrics, paragraph caret rectangles, selection rectangles, and hit-test results
from the existing Skia measurement path while keeping `native_paragraph_ready`
and `bidi_visual_order_ready` false. When `moui_skia/native` is compiled with
`MOUI_SKIA_ENABLE_SKPARAGRAPH=1` and `skia_paragraph_available()` is true, the
Skia text system routes paragraph layout through the native `Paragraph`
wrapper, consumes SkParagraph line metrics, selection boxes, and hit-test
offsets through the binding, and sets readiness metadata only when line
metrics, caret geometry, selection rectangles, hit testing, and
mixed-direction visual-order metadata are all valid. The default
selection-box policy is the SkParagraph equivalent of
`RectHeightStyle::kMax` plus `RectWidthStyle::kTight`. Invalid or unavailable
SkParagraph geometry falls back to the existing core paragraph result without
promoting those readiness flags. The macOS, Windows, and Linux Skia providers default
to the system `FontMgr` path, so normal native Skia entrypoints exercise
platform font lookup, emoji retry, and optional SkShaper when linked. The
renderer package also exposes `skia_text_system()` directly so the Skia
measurement path can be included in native diagnostic text conformance without
requiring a platform window or treating provider checks as runtime evidence.
Those diagnostics assert monotonic caret coverage and max-width clamping for
mixed CJK, emoji, ZWJ emoji, Indic mark, Arabic mark, Thai mark, Lao mark,
Sinhala mark, Khmer vowel/coeng, Myanmar mark, Hangul Jamo, and bidi samples,
and they now
inject `skia_text_system()` into a public `AppRuntime` text field to prove the
Skia measurement path drives focused text-input composition caret geometry and
selection highlight drawing. Fallback-safe diagnostics do not claim visual bidi
reordering, native-platform IME runtime behavior, or native SkParagraph parity;
only the opt-in real-Skia SkParagraph smoke and renderer-proof artifacts may
claim those observations. macOS
first-frame smoke entrypoints still explicitly select
`SkiaFontResolution::EmptyTypeface` when their exit-after-first-present
environment flag is set; that keeps CLI smoke runs on the safer default-font
retry path without changing the normal app default. The fallback-safe Skia
renderer tests also consume the
new `moui_skia` `FontFallbackRequest`, `TextMeasurementDescriptor`,
`TextShapingDescriptor`, `ShapedTextRunDescriptor`, and
`ShapedGlyphRunDescriptor` resource plans through an internal descriptor
preflight so font fallback and shaped-run cache keys stay auditable without
requiring real Skia linkage. `backend_info()` also reports a fallback-safe
`text maturity audit partial` summary: it counts the audited descriptor,
fallback-request, representative shaped/fallback caret, emoji-hint, and
empty-typeface retry boundaries, missing-glyph recovery rule, and the Skia
mixed-run fallback segment path separately from tracked gaps. The paragraph API is now present for line metrics
and geometry, and the optional SkParagraph route is wired through the native
binding. Native paragraph and bidi readiness remain release gates until the
macOS, Windows, and Linux Skia mainline renderer-proof manifests pass with real
SkParagraph evidence. Deterministic color emoji, future Unicode grapheme data
refreshes, and broader typography conformance remain follow-up work.

Renderer-proof color emoji artifacts now have a stronger audit boundary:
`colorEmojiPixels` must carry high-saturation glyph/raster evidence plus
`font-metadata` and `glyph-metadata` tokens, and the manifest validator requires
structured `metadata.font` / `metadata.glyph` fields. The native Skia
text/emoji smoke records the requested emoji family, Skia text-system id,
shaper path, RGBA glyph format, cluster count, pixel counts, stable glyph key,
measured glyph size, inferred fallback script/language-tag counts, resolved
missing-glyph count, fallback request character, and
emoji-hint/fallback-request/missing-glyph-recovery status through
`skia_emoji_font_fallback_proof()`; it also records paragraph
selection rectangles, line-range geometry, hit-test diagnostics, and visual
bidi-order diagnostics through `skia_text_selection_geometry_proof()` /
`skia_text_visual_order_proof()`. Passed native proof now requires the
SkParagraph markers `engine=skparagraph native_paragraph_ready=true
line-metrics later-line-pixels` for `paragraphWrapping`,
`engine=skparagraph bidi_visual_order_ready=true visual-order` for
`bidiLayout`, and `engine=skparagraph selection-rects line-range hit-test` for
`selectionRects`; fallback geometry, caret-only diagnostics, and heuristic
visual-order logs are rejected by the renderer-proof validator.
For native Skia, `colorEmojiPixels` also requires `fallback-request`,
`emoji-hint`, and `stable-glyph-key` proof tokens so high-saturation pixels are
tied to the FontMgr fallback request and glyph metadata path rather than a
generic raster-only observation. The Skia emoji/font fallback proof payload now
also records the inferred fallback language tags, primary script tag, request
language count, and missing-glyph recovery audit fields used by that request.
WebGPU wasm records the browser canvas font stack plus glyph atlas key and size
metadata. Renderer proof also reserves separate
contract keys for `selectionRects`, `graphemeEditing`, `imeCandidateAnchor`,
and `imeCompositionVisual`; those keys must be backed by selection rectangle,
line-range, grapheme-boundary, edit-action, candidate-anchor, surrounding-text,
composition-range, and preedit-pixel evidence before text or IME readiness can
be promoted. Native Skia `imeCandidateAnchor` also requires `utf8-offsets`
evidence for grapheme-normalized cursor and anchor offsets, and native Skia
`imeCompositionVisual` also requires `composition-cursor` evidence.
The native Skia text/emoji smoke records `graphemeEditing`,
`imeCandidateAnchor`, and `imeCompositionVisual` from the shared
`TextGraphemeBoundaries`, host IME diagnostics including UTF-8 cursor and anchor
offsets plus composition cursor geometry, Skia text-system geometry, and
captured text-field composition pixels.
These are renderer/text-system proof
markers, not matching-host native IME runtime evidence.
Platform runtime evidence splits native IME readiness further: native
`status=passed` entries must also record `imeSurroundingText`,
`imeCommitDelete`, `imeCursorUpdate`, `imeScrollAnchor`,
`imeScaleDprAnchor`, `imeResizeAnchor`, and `imeMarkdownEditor` observations
from matching-host Showcase or Markdown Editor artifacts. Those logs must carry
matching-host runtime, native-app, `renderer=skia`, the matching app marker,
platform-protocol, candidate-window, surrounding-text, composition-visual,
commit/delete, cursor-update, scroll, scale/DPR, resize, and Markdown Editor
dogfood markers, so package-only composition tests and coarse `textInput`
observations cannot promote native IME readiness by themselves.
These fields make CI artifacts easier to audit, but they are not yet a
guarantee of exact cross-platform typeface identity, glyph-id determinism,
native IME behavior, or full Unicode bidi layout parity.

Native provider responses must report valid metrics, monotonic caret positions
covering the input text, and raster glyph payloads whose cache keys include all
raster-affecting inputs such as glyph identity, font size, style, weight, and
scale. Invalid layout or raster data is rejected at the renderer boundary and
falls back when a fallback engine was supplied. Run-layout responses may omit
carets, but any non-empty caret array must be monotonic and cover the input
text before glyphs are accepted for atlas upload.

The Cosmic provider loads platform emoji fallback font candidates when they are
available. For provider-fragile emoji diagnostics, it safe-maps representative
single-codepoint, variation-selector, and ZWJ samples to equal-length layout
text before shaping, so measurement and native run-layout responses keep
monotonic caret coverage without claiming full emoji shaping parity.

## Web Wasm-GC

The Web path stays on `wasm-gc + window/web + browser WebGPU host imports`.
`backend/web` installs a browser Canvas-backed `TextSystem` and the WebGPU
runtime draws text through a DPR-aware canvas-rasterized glyph atlas. Measurement
and drawing use the same CSS `system-ui` stack generated from `FontSpec`.
The Web host also routes browser IME composition events and accepts
`TextInputSession` IME requests for focused text controls, including cursor
geometry and surrounding-text updates. This covers browser input-method
plumbing; broader shaping, bidi, and deterministic browser glyph rasterization
remain tracked conformance topics rather than Web-host capability claims.

The browser runtime assets live under `backend/web/*.js`; Web example packages
should only supply app-specific entrypoints, wasm URLs, canvas hosts, and UI
callbacks.

## Embedded Fonts

Apps can register embedded font bytes through `AppRuntime::register_font_data`.
Native WGPU forwards those bytes to the active provider and, when present, the
composed fallback provider. CoreText v1 attempts process-local registration
under the requested family alias. Future DirectWrite and
fontconfig/HarfBuzz/FreeType implementations should use the same hook for
private font collections.

Remote font loading is intentionally outside the current backend contract.

## Current Gaps

- Full typography conformance, native emoji font fallback, ZWJ/color emoji
  conformance, future Unicode grapheme data refreshes, and provider shaping
  parity remain follow-up work. Native
  Skia paragraph layout and bidi visual-order promotion now have an opt-in
  SkParagraph implementation path, but the release claim remains pending until
  macOS, Windows, and Linux real-Skia renderer-proof manifests pass with
  SkParagraph line metrics, later-line pixels, selection rectangles, line
  ranges, hit tests, and mixed-direction visual-order evidence. Core now
  exposes `TextGraphemeBoundaries` as the single UAX-style
  cluster-boundary contract used by fallback caret stabilization, left/right
  caret movement, selection/range normalization, surrounding delete ranges,
  composition cursor offsets, rich text hit testing, raw UTF-8 offset
  conversion, and `nearest_boundary_utf8_offset` conversion for later IME
  handoff. This keeps deterministic text-field, selection, and IME-anchor
  geometry on one path. The repo now has an offline
  `GraphemeBreakTest.txt`-style fixture and generator guard
  (`scripts/generate-grapheme-break-fixtures.mjs --check`) for curated samples
  plus a vendored Unicode 17.0 default grapheme break fixture generated from
  `moui/core/testdata/GraphemeBreakTest-17.0.0.txt`; `moon test moui/core
  --target native` runs the curated fixture, full boundary fixture, and a full
  editing fixture that checks `is_boundary`, floor/ceil/nearest boundary
  snapping, collapsed and expanded range normalization, surrounding delete
  ranges, raw boundary-to-UTF-8 offset conversion, and every-index
  `nearest_boundary_utf8_offset` snapping across every Unicode 17 sample. A
  separate full layout fixture checks fallback paragraph caret
  rectangles, collapsed selection rectangles, and hit-test offsets snap to the
  same Unicode 17 boundaries. `moui/render/skia` also generates a Skia
  white-box fixture from the same file so `moon test moui/render/skia --target native`
  verifies `skia_grapheme_cluster_texts` against the Unicode 17 default break
  samples and checks every-index `nearest_boundary_utf8_offset` snapping against
  the Skia-produced cluster boundaries.
  The full Unicode fixtures use distinct generated helper/test names and are
  checked with
  `node scripts/generate-grapheme-break-fixtures.mjs --input moui/core/testdata/GraphemeBreakTest-17.0.0.txt --output moui/core/text_grapheme_break_unicode_17_wbtest.mbt --helper-name assert_unicode_17_grapheme_break_fixture --test-name "unicode 17 grapheme break fixture samples" --check`.
  For the core editing fixture, use
  `node scripts/generate-grapheme-break-fixtures.mjs --input moui/core/testdata/GraphemeBreakTest-17.0.0.txt --output moui/core/text_grapheme_editing_unicode_17_wbtest.mbt --helper-name assert_unicode_17_grapheme_editing_fixture --test-name "unicode 17 grapheme editing fixture samples" --actual-kind core-editing --check`.
  For the core layout fixture, use
  `node scripts/generate-grapheme-break-fixtures.mjs --input moui/core/testdata/GraphemeBreakTest-17.0.0.txt --output moui/core/text_grapheme_layout_unicode_17_wbtest.mbt --helper-name assert_unicode_17_grapheme_layout_fixture --test-name "unicode 17 grapheme layout fixture samples" --actual-kind core-layout --check`.
  For Skia, use
  `node scripts/generate-grapheme-break-fixtures.mjs --input moui/core/testdata/GraphemeBreakTest-17.0.0.txt --output moui/render/skia/skia_grapheme_break_unicode_17_wbtest.mbt --helper-name assert_skia_unicode_17_grapheme_break_fixture --test-name "skia unicode 17 grapheme break fixture samples" --actual-kind skia-clusters --check`.
  The
  scanner now drives core grapheme break classes from generated Unicode 17.0
  property predicates for CR/LF/control, Prepend, Extend, SpacingMark,
  Regional_Indicator, ZWJ, Extended_Pictographic, and Indic_Conjunct_Break
  Linker/Consonant/Extend. Regenerate those predicates with
  `node scripts/generate-grapheme-property-data.mjs --grapheme-property <Unicode-17.0.0-GraphemeBreakProperty.txt> --emoji-data <Unicode-17.0.0-emoji-data.txt> --derived-core-properties <Unicode-17.0.0-DerivedCoreProperties.txt> --check`
  after downloading the pinned Unicode files from
  `https://www.unicode.org/Public/17.0.0/ucd/auxiliary/GraphemeBreakProperty.txt`
  `https://www.unicode.org/Public/17.0.0/ucd/emoji/emoji-data.txt`, and
  `https://www.unicode.org/Public/17.0.0/ucd/DerivedCoreProperties.txt`.
  It treats ZWNJ as an Extend code point for GB9, applies the Unicode 17
  Indic_Conjunct_Break linker rule instead of the earlier hand-written virama
  shortcut, and keeps deletion and IME offsets aligned with the full default
  grapheme break fixture.
  Native IME runtime readiness is also still pending: macOS, Windows, and Linux
  must each record matching-host Showcase or Markdown Editor artifacts for
  candidate anchors, surrounding text, composition visuals, commit/delete
  behavior, cursor updates, scroll anchors, scale/DPR anchors, resize anchors,
  and Markdown Editor IME dogfood before native IME can be called ready.
  Native WGPU can preserve RGBA color glyph payloads
  through the provider protocol and glyph atlas path, with Cosmic platform
  emoji fallback candidate loading, Cosmic color swash preservation,
  provider-safe emoji layout mapping, and a CoreText AppleColorEmoji RGBA path
  covered by focused tests. Stable and diagnostic tests assert caret counts,
  monotonicity, clamping, editor selection behavior, IME anchor geometry, core
  fallback cluster stabilization and movement, CRLF/control segmentation,
  emoji ZWJ restrictions, regional-indicator pairing, Indic conjuncts, and
  provider fallback safety across mixed bidi, CJK, single-codepoint emoji,
  variation-selector emoji, and ZWJ emoji samples; Cosmic run-layout tests
  additionally assert glyph output
  plus caret coverage through the safe-mapped layout path. Skia renderer tests
  cover the same representative emoji caret coverage, shaped-run and fallback caret
  stabilization for combining-mark, Indic matra/virama, Arabic mark, Thai mark,
  Lao mark, Sinhala mark, Khmer vowel/coeng, Myanmar mark, Hangul Jamo L/V/T
  clusters, emoji-modifier, variation-selector, regional-indicator pairs, emoji
  tag-sequence flags, Unicode prepend marks, and ZWJ cluster interiors, the system-FontMgr-only
  emoji font retry boundary, and fallback-safe descriptor resource plans for
  text measurement and shaping. Native diagnostic conformance also injects the
  Skia text system into a text field runtime to validate composition caret
  geometry and selection highlight drawing. They do not claim full Unicode
  shaping parity.
- Focused text inputs expose MoUI's default copy, cut, paste, undo, redo, and
  select-all commands through host context menus, so keyboard shortcuts and
  native menu selections share the same selection, clipboard, and Unicode paste
  dispatch path.
- Linux native Skia is the Preview Ready text/render route and continues to use
  the Skia text system described above. The Linux native WGPU
  fontconfig/HarfBuzz/FreeType provider remains diagnostic and partial, with
  only the explicit FreeType color-emoji path handled natively while composed
  Cosmic fallback handles general text. Windows DirectWrite remains a scaffold
  on the native WGPU diagnostic route.
- Web can surface browser emoji and font fallback behavior, while stable Web
  adapter tests keep the host-backed `TextSystem` contract deterministic.
- Text changes that affect renderer feature status must update
  `render/capabilities.mbt`, `render/capabilities_test.mbt`, and
  `docs/renderer-capability-report.md`.

## Validation

Text conformance is split into two layers:

- Stable tests run inside normal package checks and cover `core`,
  `render/wgpu`, `render/wgpu/cosmic_text`, `render/webgpu_adapter`, and
  `backend/web`.
- Diagnostic matrix tests live under `moui/tests/text_conformance/` and are opt-in.
  They compare core fallback, Cosmic, platform-default composed fallback,
  malformed-provider fallback, and Web text systems where the current host can
  actually exercise them. Strict failures stay limited to contract invariants;
  width/baseline differences across engines are diagnostic unless the contract
  says otherwise.

Focused checks for text-system work:

```sh
sh scripts/conformance-check.sh --text
sh scripts/conformance-check.sh --text-diagnostic
moon test moui/tests/text_conformance/native --target native
moon test moui/core --target native
moon test moui/render/wgpu --target native
moon test moui/render/wgpu/cosmic_text --target native
moon test moui/render/skia --target native
moon test moui/render/webgpu_adapter --target wasm-gc
moon test moui/backend/web --target wasm-gc
```

Platform text provider changes should also run the affected WGPU provider
package tests. Public API changes require `moon info` and review of generated
`pkg.generated.mbti` diffs.
