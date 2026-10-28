# 2026-10-27: L1 — a Metal renderer with no Skia and no wgpu

- **Agent**: Qoder Desktop agent (main session, MoonBit-native work)
- **Goal**: Finish the second half of the owner's directive — "把文本 provider 从
  wgpu 模块搬出 ，然后 实现moui_metal_renderer". The first half (L0.5) is logged in
  [2026-10-27-text-provider-module-relocation.md](2026-10-27-text-provider-module-relocation.md);
  this session is `moui_metal_renderer` up to the plan's L1 acceptance frame: one
  clear colour, one filled path, one CoreText glyph run, presented through the
  `CAMetalLayer` the macOS backend already creates.
- **Outcome**: Delivered and pixel-proved. 6 hand-written externs, zero Skia and
  zero wgpu in the artifact, 16 module tests, a real-provider text smoke, and the
  route registered across every gate that enumerates renderers. Product class
  declared experimental (ADR 0045, invariant R8).
- **Where this file stands now**: the sections below append the same goal's later
  legs — L2 (strokes, brushes, shadows), L2b (images, then the host's async
  lifecycle), the gate sweep, L2c (scopes), the two gate findings, L3a (atlas
  residency), L3b (colour glyphs), L3c (atlas capacity), the L4 release-size
  measurement, the L4 gpu_recovery scoping, the L4 paint-state probes, the L4
  capability-row walk, the L4 text-fidelity leg, the L3 colour-glyph-in-group
  probes, the `Clip` rounded-clip closure, the second `AsyncImage` scoping and the
  L4 `ShaderEffect` leg, all on 2026-10-28.
  Current numbers: 8 externs, 53 mbti lines, 74 module tests plus 23 CoreText
  provider tests plus 11 shared text-conformance tests, a 1024x1024 glyph atlas,
  all 26 `PlanOp` variants drawn or counted, the four built-in shader effects drawn
  in the fragment rather than fallen back, every one of the 17 capability rows
  checked against what the device actually painted (2 of them also pinned for
  *shape*), the route's paragraph/hit-test path pinned in the suites that already
  own text fidelity rather than in a second engine, and a 4,101,856 B release
  artifact — below the `sun` figure this route was priced against. The
  L1 numbers in "Outcome" and "Summary" are the state at that frame.

## Summary

`wzzc-dev/moui_metal_renderer` binds the `RendererProvider` contract to the host
GPU surface: `bind` reads `surface.native_surface()`, points the layer at its own
device, builds two pipelines over one vertex layout (solid colour, and the same
colour scaled by glyph coverage), and presents drawables itself. Geometry comes
from the shared lowering (`lower_draw_commands`, `tessellate_path`), so the module
never re-interprets `DrawCommand`; text coverage comes from the engine the
composition root injects, so the module depends on no text provider — which is
exactly what L0.5 bought, now measured.

## Changes Made

| File | What Changed | Why |
|---|---|---|
| `moui_metal_renderer/*` | New module: `binding_factory.mbt`, `renderer.mbt`, `metal_geometry.mbt`, `metal_text.mbt`, `metal_proof.mbt`, `metal_smoke.mbt`, `capabilities.mbt`, `provider.mbt`, `native_text_engine.mbt`, `metal_device.mbt`, `metal_renderer.mm`, `build.js`, `README.mbt.md`, 3 test files | The route itself |
| `moui/render/renderer.mbt` | `RendererBackendKind::NativeDirectGpu`, `RendererFamily::DirectGpu`, plus the three label matches and `family()` | A new renderer needs an identity; the literal `Metal` name was rejected by the platform-surface guard |
| `moui_text_providers/build.js` | Emits `link_configs` for `coretext` on darwin | Its framework flags lived only in package `cc-link-flags`, which never reach an is-main link; the symbols resolved only via a backend's `ApplicationServices` umbrella |
| `moui_tests/metal_renderer_smoke/macos/*`, `examples/showcase/macos_metal/*` | Real-CoreText ink smoke executable; the windowed evidence app | The smoke is the only gate that exercises a real provider against a real GPU |
| `checks/{release-modules,source-file-policy,backend-common-ownership,compatibility-policy,profiles}.json` | Module row (`role: "renderer"`), `roots`, `sourceRoots` + `rendererModules` + forbidden tokens, `apiTiers.diagnostic`, two `host: "darwin"` platform steps | Every gate that enumerates renderers, or the new module is invisible to it |
| `tools/moui/validate_api_surface/main.mbt` | `moui_metal_renderer` PackageBudget 34/9/0; `moui/render` 606→608 with the reason; the tool's own ratchet 1750→1775 | Registering a module in a budget tool costs lines in the tool itself |
| `tools/moui/validate_renderer_provider_manifests/main.mbt`, `validate_runtime_state_render_ownership/validation.mbt`, `validate_maintenance_baseline/scan_scope.mbt`, `scripts/external-consumer-ci.mjs`, `scripts/test-moui-prebuild.mjs` | New module added to each enumeration; prebuild test asserts both new `link_configs` | Same class of silent-coverage gap L0.5 recorded |
| `tools_product/moui/validate_renderer_capability_consistency/main.mbt` | `ReportRow.metal`, `parse_table` cell index 6, `report_cell`, fifth `ColumnRule`; module deps | The capability report is machine-checked, so a new column means a new code path |
| `docs/{architecture,architecture-map,development,testing,text-system,platform-notes-macos,invariants}.md` + zh mirrors, `docs/decisions/0045-*`, `docs/decisions/README.md`, ADR 0044 status, plan | Route documented; R8 added; ADR 0045 records the measured evidence and the refusals | Root `docs/` is the source of truth |

## Key Decisions

- **Keep the guard, rename the identity.** `moui/render`'s published surface must
  not name platform surfaces, and two gates enforce that with the token `Metal`.
  Rather than weaken them, the protocol says `NativeDirectGpu` / `DirectGpu` and
  the *module* keeps the literal name. Prose keeps saying "no Skia, no wgpu",
  because "direct Metal" is already taken by the shipped Skia GPU path.
- **Text coverage is injected, never imported.** `metal(text_engine~)` takes the
  engine from the composition root and re-exports the neutral constructors, the
  same shape the WGPU route uses. The renderer's dependency closure is
  `wzzc-dev/moui` plus Apple frameworks.
- **The glyph atlas stays renderer-local.** P14 forbids importing another
  renderer's atlas, so a shared atlas is L3's architecture decision, not an L1
  shortcut. No eviction: a glyph that does not fit is dropped and counted
  (L1 state; L3a below adds the clear-and-rebuild that makes the atlas empty).
- **Refuse rather than approximate.** Unimplemented ops increment counters;
  `recover` returns `RecoveryFailed`; gradients are dropped because the shared
  tessellator cannot distinguish a solid brush from a linear gradient in the mesh
  payload, and painting one in a single colour would be the silent mis-draw L2
  exists to forbid.
- **`moon test moui_metal_renderer` cannot join `pr`/`daily`.** It needs a Metal
  device and Apple stubs, so both new gates are `platform` steps with
  `host: "darwin"` — the same reason the text providers and WGPU smoke stay
  outside the cross-platform profiles.

## Discoveries

- **A package's `cc-link-flags` do not reach an is-main link.** Proved by putting
  an invalid flag in `moui_text_providers/coretext/moon.pkg` and watching
  `macos_wgpu` build successfully anyway. It is not dead config, though: for
  `moon test <pkg>` the package *is* the is-main unit, so its own flags apply
  there. `link_configs` is the carrier for consumers — which is why
  `moui_skia/build.js` says so in a comment, and why the new module has a
  `build.js`.
- **A fully covered test glyph hides a real shader bug.** The first text test used
  an all-255 mask and passed while real CoreText text painted solid white bars:
  multiplying a *premultiplied* colour by a *straight-alpha* texel leaves rgb at
  full intensity, so coverage only ever reached alpha. A half-covered mask fails
  it for the right reason. The uv byte offset was a second, independent way to get
  the same "everything is white" result (offset 16 aliases the colour's `b,a`).
- **Metal SDK facts worth not rediscovering**: with an `MTLVertexDescriptor`, the
  vertex function must take a `[[stage_in]]` struct whose fields carry
  `[[attribute(n)]]` — discrete attributed arguments are rejected. Blending
  properties live directly on `MTLRenderPipelineColorAttachmentDescriptor`
  (`blendingEnabled`, no `.blending` object in this SDK), `rasterizer` is not on
  `MTLRenderPipelineDescriptor`, `MTLTextureUsage` has **no** `HostReadable`
  (textures are host-readable by default), and
  `MTLResourceOptionCPUCacheModeDefault` is deprecated for
  `MTLResourceStorageModeShared`.
- **MoonBit surface details that cost a cycle each**: `priv fn` is not a thing
  (bare `fn` is package-private); `Int` and `Int32` are interchangeable at call
  sites and `moon fmt` rewrites `Int` to `Int32`; `for i in 0..(expr)` is a parse
  error (hoist the bound); labelled arguments are supplied as `label=value`, the
  `~` form is only for forwarding; an FFI pointer parameter without
  `#borrow`/`#owned` is a hard error; and `moon fmt` rewrites a package README's
  ```moonbit fence to ```moonbit nocheck, which `pr`'s `moon fmt --check` catches.
- **The api-surface budget tool has a budget of its own.** Registering the new
  module's PackageBudget entry pushed `tools/moui/validate_api_surface/main.mbt`
  to 1764 logic lines against a 1750 ceiling; the repo convention is one 25-line
  quantum with the reason appended to the `source-file-policy.json` entry, so the
  bump is recorded with what it bought rather than as a bare raise.
- **`screencapture -x` is enough for window evidence here** — it captured the
  running showcase without a permission prompt, which is what let me distinguish
  "layer not composited" (white window) from "layer composited, content missing"
  (red probe clear with white bars).

## Validation

`moon test moui_metal_renderer --target native` 16/16; `moon run
moui_tests/metal_renderer_smoke/macos --target native` passes with ink ratio 0.245
and a 0-ink control; `examples/showcase/macos_metal` presents its first frame and
exits 0 under `MOUI_MACOS_METAL_EXIT_AFTER_FIRST_PRESENT=1`. Symbol gate on the
artifact: `otool -L` 0, `nm -a` 0, `strings -a` 0 matches for Skia/wgpu. All eight
static validators green, including the five-column capability check (85 cells) and
`validate-release-module-closures` (P14). `check.sh --profile pr` green. Release
size was **not** measured, so the route's size motive remains unpriced.

## L2 increment (same day, continuing the goal)

The goal was restated as "实现完整的 `moui_metal_renderer`", so the next stage ran
in the same session: the shape pipeline. 18 of the 26 `DrawCommand` variants are
now handled (10 paint ops + 8 scope ops) and the remaining 8 are counted, never
approximated.

| File | What Changed |
|---|---|
| `moui_metal_renderer/metal_renderer.mm` | Two pipelines over one 76-byte vertex (clip position, shape-local point, atlas uv, gradient endpoints, two brush colours, brush kind) plus an 8-float per-item box parameter via `setFragmentBytes`; the visual fragment carries fill / stroke / shadow / path modes |
| `moui_metal_renderer/metal_geometry.mbt` | `StrokeRect`, `FillRoundedRect`, `StrokeRoundedRect`, `FillRoundedRectBrush`, `StrokeRoundedRectBrush`, `DrawShadow` arms; gradient paths stopped being dropped; one vertex format for all modes |
| `moui_metal_renderer/metal_report.mbt` | `metal_frame_report` — CPU-only, host-independent answer to "what would this frame refuse to draw" |
| `moui_metal_renderer/metal_l2_wbtest.mbt` | Pixel proofs: rounded corners transparent with an anti-aliased arc, stroke ring with a clean interior, linear gradient monotonic along its axis and constant across it, radial falloff, shadow falloff band, gradient-filled path |
| `moui_metal_renderer/capabilities.mbt`, `docs/renderer-capability-report.md` + zh | Rect / RoundedRect / Gradient / PathVector moved to `supported`, Shadow / Text / Clip / Transform / Opacity to `partial` with the missing half named, TextShaping to `host-forwarded` |

- **Why colours are per vertex, not per item:** the shared `tessellate_path` mesh
  mixes a fill sub-mesh and a stroke sub-mesh in one vertex array with different
  brushes. A per-item colour repaints the stroke with the fill.
- **Why there is no "unsupported command" event:** `RendererEvent` carries only
  `PresentCompleted` / `ImageLoadRequested` and both host backends ignore
  anything else, so a new variant would be a channel with no reader. The report
  function is the version that is actually readable, and the macOS smoke prints
  it (`items=1 vertices=54 refused=0`).
- **Two test bugs the pixel maps caught, not the code:** the first rounded-rect
  and shadow assertions sampled the *saturated plateau* of the falloff band
  (dumping the 16×16 and 24×24 maps showed a textbook rounded box and a
  symmetric gradient 255→234→211→188→119→95→24→4→0), so the sample points moved
  onto the band and the band's width is now named in the test.
- Gates: 25 module tests, capability consistency 85 cells, `platform` profile
  green including both darwin Metal steps, `pr` green at 199 steps.

## L2b: images through ImageIO

`DrawImage` went from counted to drawn with no new third-party dependency: the
stub decodes with `CGImageSourceCreateWithData` + a `CGBitmapContext` forced to
`kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big` (so memory order really
is RGBA for `MTLPixelFormatRGBA8Unorm`), caches the texture in an
`NSMutableDictionary` on the context keyed by an Int32 id MoonBit assigns per
source string, and a third pipeline samples it with a linear clamp-to-edge
sampler. `fit` and `src_rect` resolve through the shared
`image_placement`/`image_src_window`, so the route cannot invent crop rules.

- The fixture is a 4×4 PNG that is red on the left and blue on the right. A
  uniform image would pass with any uv mapping; this one fails if the source
  window or the axis is wrong. `metal_image_wbtest.mbt` asserts both.
- The image fragment multiplies a *premultiplied* texel by the run opacity only.
  Scaling rgb again would darken the image twice — the same class of bug the text
  pipeline already caught.
- Decoding is synchronous at draw time in that first cut. The session's async
  contract (`image_records`, `apply_image_load_completion`, `image_decoder`) was
  not wired yet, so `Image` was `partial`, not `supported`, and a missing file
  blocked its frame instead of retrying. That is the remaining half of this leg,
  closed the next morning — see "L2b (cont.)".
- Externs: 6 → 7 (`image_upload`). Public surface: 48 lines / 13 declarations.
  19 of 26 command variants are now handled, 7 counted.

## L2b (cont., 2026-10-28): the host's async image lifecycle

The synchronous decode was only ever the proof path; a real app runs with
`async_image_loading=true`, so the source is requested, resolved off frame, and
painted when the completion lands. The session now supplies all four image-side
contract slots over the shared `@render_common.ImageResourceLifecycle`
(`image_source`, `image_decoder`, `image_records`,
`apply_image_load_completion`), which means the route inherits the host's
request-dedup / retry / snapshot semantics instead of re-implementing them, and
the record snapshot the diagnostics surface reads is the same shape Skia and
Sun's routes pin. `Image` moved `partial → supported`; the module is at 31 tests.

Two facts here cost real debugging and are the reason this section exists:

- **A completion carries decoded RGBA, not encoded bytes.** The first version
  forwarded completions into the decode stub, whose contract starts from an
  encoded file. `moui_metal_image_decode` returned `0`, the image was marked
  failed, and every async image disappeared with no signal pointing at the
  mismatch. The stub boundary is now explicit: `image_write_rgba` uploads
  already-decoded pixels (the completion path), and the proof path chains
  `image_decode` into it.
- **`has_decoded_rgba_payload()` is a real predicate, not a formality.** It
  requires `decoded_row_bytes >= width * 4` *and*
  `pixels.length() >= row_bytes * height`. Passing `width * height * 4` as the
  row stride fails it, and the symptom looks like a texture bug rather than a
  payload-validation bug.

The async pixel proof is deliberately a two-frame test. Frame 1 asserts
`items=0` with `image_ops_pending=1`; the completion is then applied and asserted
to have produced exactly one upload and an `ImageReady` record; frame 2 asserts
`items=1` and reads back the fixture's red-left / blue-right halves. A
synchronous decode sneaking into the requesting frame would fail frame 1, which
is the point — the alternative is a test that passes whichever way the lifecycle
happens to fall.

A failed request re-requests only when the bytes become readable, so a missing
file does not spin: the test pins one request per absence.

## Gate sweep found three pre-existing `daily` reds (2026-10-28)

Certifying this increment against `daily` surfaced three failures that all
reproduce at HEAD — none of them is renderer work, and each was attributed by an
A/B rather than assumed:

- `scripts/test-moui-prebuild.mjs` demanded **zero** `link_configs` from the Skia
  binding, while `af9bafa6c fix(fallback-ci)` had deliberately restored the
  native entry. Fixed the assertion (now: exactly one entry for
  `wzzc-dev/moui_skia/native`, each archive once inside it), not the flags —
  clearing `link_configs` is the wrong side, because package `cc-link-flags`
  never reach an is-main link.
- `tools/moui/generate_grapheme_break_fixtures` emitted `Array[Int]` and `moon
  fmt` normalizes that to `Array[Int32]` (measured, not recalled), so the
  generated fixture could never equal its own generator's output. Emitting
  `Array[Int32]` reproduces the committed file byte-for-byte.
- `website/app/i18n_catalog_generated.mbt` disagreed with the i18n generator by
  1595 lines. The first instinct — shorten the generator — was **refuted by its
  blast radius**: the `moui_studio` submodule's copy of the same generated file
  still uses the qualified names, and `moon fmt` does not shorten qualified
  constructor names (406 → 406 under a real fmt pass). So the generator is the
  contract and commit `5fb1dd912` had edited a `DO NOT EDIT` file directly; the
  website file was regenerated instead and the generator left alone.
- Still red, deliberately not fixed: `check.sh` injects
  `MOUI_SKIA_DISABLE_PREBUILD_SKIA=1` into every step
  (`scripts/lib/check-runner.mjs:106`), so `daily` runs the no-Skia fallback
  stubs, and `renderer_embedded_fonts_wbtest.mbt:26` asserts a *real* Skia
  behavior (SFNS variable-font `wght` 900 wider than 100). Proven by A/B: the
  same command fails with that env and passes without it, at HEAD's `build.js`
  too — which also means `-Wl,-dead_strip` is **not** implicated, and the earlier
  "dead_strip keeps 141 Skia tests green" note is config-dependent. The clean
  fix needs either a MoonBit-visible "Skia is linked" predicate (new public API
  on `moui_skia`, plus `mbti` and api-surface budget work) or that step opting
  into the real-Skia path — an owner call, not a drive-by.

## L2c (2026-10-28): scopes, and the first mis-draw this route ever found

The last 7 of the 26 command variants — `PushLayer`/`PopLayer` with their blend
modes, `PushFilter`/`PopFilter`, `BeginRetainedLayer`/`EndRetainedLayer`,
`DrawShaderEffect` — plus the geometry host they needed. This closes L2.

**The host side.** Layers became a real pass, not an approximate clip. One flat
item stream carries 9 int32 per item, the 9th an `owner` tag (`-1` main pass,
`-2` discarded, `>= 0` a layer slot), 36 floats per shape and 11 words per layer
record (7 int32 + 4 float) over one 76-byte vertex. Slots are claimed eagerly in
post-order so nesting resolves before the walk, and the host renders
`slot = count-1 … 0` then the main pass, keeping exactly one active encoder; each
pass target is reused while its width/height match. The per-pass transform is
bound as `constant float4& pass [[buffer(1)]]` via `setVertexBytes` rather than
inflating the vertex, and pipelines are keyed `role-format[-blend]`, which is how
BlendMode became fixed-function instead of a shader branch. Composite is one
full-bleed quad at role 3. Externs stayed at 8.

**Exactness is counted, never implied.** Metal expresses SourceOver, Multiply
(`DestinationColor, Zero`), Screen (`OneMinusDestinationColor, One`) and
Darken/Lighten (`MTLBlendOperationMin`/`Max` — not `Minimum`/`Maximum`, those do
not exist). `Overlay` needs a backdrop snapshot and is not expressible at all →
`blend_modes_unsupported`. Any non-SourceOver mode is exact only over an opaque
destination → `blend_modes_approximated`. Blur is a 3×3 weighted tap →
`filter_approximations`. The alternative — a backdrop blit for a true
convolution — was rejected: a second texture per filtered group for fidelity
there is no evidence yet that anyone needs here.

**The first mis-draw.** Box fragments measure the brush from
`in.local - half_size`, i.e. rect-origin-relative, while the path mesh hands the
shader absolute surface positions as `local`. Brush endpoints were being pushed
in surface coordinates, so a gradient on a rect that did not start at the origin
drew a shifted axis: declared `2→10`, measured `4→12`. The reason no earlier test
caught it is that every gradient proof anchored at `(0,0)`, where the two spaces
coincide. `metal_box_brush` now shifts endpoints by the rect origin — and
deliberately does *not* shift a radial gradient's `end.x`, which is a radius, a
length, not a point. Two off-origin pixel proofs pin both halves (the radial one
asserts the ring's symmetry as well as its falloff, so a collapsed radius and an
unshifted centre each fail their own way). The durable lesson: **a proof that
only holds at the origin proves the arithmetic, not the coordinate space.** The
bug was found by writing the new proof first and reading the measured pixels from
a throwaway probe test, not by adjusting expectations.

**No catch-all, and a counter that died.** `build_metal_range` now matches all 26
`PlanOp` variants with no `_ =>` arm; `moon check` reported the old catch-all as
`unreachable_code` (Warning 0012), which was the proof that nothing was left
unmatched. So `dropped_ops` could never be non-zero and was removed — from the
private geometry struct, the public `MetalFrameReport`, `refused_count()` and
five test asserts. An op this route cannot draw at all is now a compile error,
not a number. Checked against the sibling: `moui_wgpu_renderer/native_visual_plan.mbt`
uses neither a catch-all nor a dropped-op counter, so this matches precedent
rather than inventing a policy. The public surface grew 48 → 53 mbti lines, all
of it inside the one report struct (the new counters), and the api-surface budget
was raised with that reason written in the comment — not silently.

**Capability truth.** `LayerCompositing`, `BlendMode`, `FilterEffect`,
`ShaderEffect` and `AsyncImage` are `Partial` with notes naming the test that
proves them; `Image` is `Supported` from L2b. En and zh-Hans matrix rows flipped
in the same change (the zh table is a 7-column mirror with Chinese row labels and
is not machine-checked, so it has to be done by hand and be right anyway).
Validation: `moon test moui_metal_renderer --target native` → 43 passed, 0 failed;
`validate-renderer-capability-consistency` → 85 cells match; the other five static
guards green; package `moon check` clean.

## Two gate findings, and what they cost (2026-10-28)

- **`validate_source_file_policy` caught this route's own growth**: `metal_geometry.mbt`
  at 1674 lines and `metal_renderer.mm` at 1291, both past the 1200-line new-file
  hard limit. Both files were created the day before, so a ratchet would have
  bought permanent headroom for code that had just outgrown itself — the gate's
  named failure mode. The geometry file split along seams that already existed
  (op walk 789 / wire format and MSL code values 622 / scope stack and pass slots
  275). The bridge split along a different kind of seam: the 182-line embedded MSL
  string moved to `metal_shaders.h`, because shader text compiled at runtime by
  `newLibraryWithSource` is data the host reads, not host logic, and it is the
  only thing a fragment change edits — leaving 1096 lines of host code, which
  lands in the repo's 1000+ *review* queue alongside 40 other files instead of
  failing. No public API, no extern, no assertion changed.
- **`checks/api-surface-report.json` was stale** and `pr` said so in
  `generate-repo-docs --check`: the committed report still carried the pre-L0.2
  render-protocol numbers and no Metal entry at all. `--write` regenerated it (and
  `docs/repository-facts.md`, which was missing `moui_metal_renderer`,
  `moui_text_providers` and `moui/render/native_text` from its package table).
  The lesson is a sequencing one: a generated artifact that only `pr` checks stays
  silently stale through a whole feature leg, and the fix belongs to the leg that
  made it stale.
- **Never run `pr` while editing the tree.** The first attempt after the split
  failed inside `moon fmt --check` with a `git diff --no-index` error, because I
  was editing `metal_geometry.mbt` at the same time. That is a race in my own
  workflow, not a repository red, and it cost a cycle to tell apart.

## L3a (2026-10-28): the atlas could not empty, so text vanished for good

The first L3 leg was a correctness cliff, not a fidelity gap. The 512×512
coverage atlas had no way to release a placement: when it filled, `Full` fell into
the same branch as `Missing`, the glyph was dropped and counted, and every later
frame hit the same wall — a scrolling document lost its text and kept losing it.
`moui_wgpu_renderer` already answers this with clear-and-rebuild
(`native_visual_plan.mbt:342` clears and retries the plan;
`native_text_rendering.mbt:147` turns the report into that signal), so the fix was
to copy the sibling's policy rather than invent an eviction scheme: `Full` now
sets `atlas_overflowed`, `build_metal_geometry` clears and builds the frame a
second time, and the retry is bounded at one because a frame that cannot fit an
*empty* atlas would fail identically twice.

- Non-vacuity proven by A/B: disabling the retry fails the new test at
  `assert_eq(second.item_count, 1)` with `0 != 1`. The test packs four 200×200
  rasters — exactly two shelves of two, so the fifth request is a residency test
  and not a size accident — then draws a frame needing one new glyph and asserts
  it paints, `resets == 1`, and the atlas holds **one** placement afterwards:
  the current frame's working set, not four glyphs the next frame never draws.
- `atlas.resets` stayed package-private on purpose. A successful retry draws the
  right pixels, so a host has nothing to be told; the drop count already covers
  the case where recovery is impossible. The thrash case (working set bigger than
  the atlas, so a 1 MB re-upload per frame) is a *cost* signal, and this route has
  no perf gate that could act on it — L4 is where the report grows, and only with
  a named failure mode.
- Measured before writing the shared-atlas decision: the copies are **two**, not
  three (Sun is a CPU raster and owns no atlas), and they differ on four
  behaviours — two-sided vs trailing padding, zero-size rasters consuming no shelf
  in WGPU but padding in Metal, transparent texels skipped in WGPU and written in
  Metal, and full/missing as a return value vs a counter. Four switches at the
  seam, on a file the remaining L3 work keeps editing, is why extraction waits
  until the behaviours converge. 45 module tests pass.

## L3b (2026-10-28): the emoji row was measured, and the provider was wrong

`EmojiText` was this route's only `Gap`, and the note in `capabilities.mbt` said
the honest thing — a colour raster's pixels do survive the atlas branch that skips
tinting, but no emoji run had ever been put through the route. Putting one through
it printed `inked=690 green-channel=0`. The claim "the atlas preserves colour" was
true of the code path and false of the product, because nothing upstream was
handing over colour.

- **Root cause, in the shared provider, not in Metal.**
  `moui_text_providers/coretext/macos_coretext_text.m` chose the raster format by
  comparing the PostScript name with `"AppleColorEmoji"`. The system cascade on
  macOS 26.3 resolves an emoji to `.AppleColorEmojiUI` — so every glyph came back
  as a 37×42 DeviceGray coverage mask. Measured with throwaway probes before
  touching anything: the resolved font's traits are `0xc0002000` with
  `kCTFontColorGlyphsTrait` set, and it draws 472 chromatic pixels out of 539 into
  a `kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big` context. Fix is the
  documented trait check (`CTFontGetSymbolicTraits & kCTFontColorGlyphsTrait`) at
  both format decisions; the name-equality helper is deleted. Keying by name is not
  a viable fallback: `CTFontCreateWithName(".AppleColorEmojiUI")` is refused (it
  returns TimesNewRomanPSMT with a CoreText console note) and
  `moui_create_named_font_from_bytes` explicitly returns NULL for a `.`-prefixed
  name, so the trait can only be read off the font the cascade already picked.
- **Non-vacuity had to be built before it could be believed.** One run colour
  cannot distinguish a colour glyph from a solid bar, so the smoke now draws the
  same run twice — pure red, asserting the green channel lights, and pure green,
  asserting the red channel lights. Each claim names a channel the other run's
  colour zeroes, so a monochrome provider fails both and a bar fails neither claim
  as written. A paired in-module test gives the same glyph box in the two raster
  formats and asserts opposite channels, and the noop-engine control must paint 0
  pixels. Post-fix: `🙂` 698 inked / 686 green / 698 mirrored, and the ZWJ sequence
  `👩‍💻` 1011 / 993 / 1011, both with `dropped=0`.
- **The change pays outside this route, and it pays as an upgrade.**
  `moui_wgpu_renderer` shares this provider, and its `EmojiText` row claims
  `supported` — which the old name keying cannot have been delivering on macOS.
  This leg did not re-evidence that row; its 61 tests and
  `moui_tests/text_conformance/native`'s 10 pass unchanged, and the wgpu claim is
  L4 work with a number attached to it now.
- **Two `Gap` catch-alls became a compile error.** With all 17 features named
  explicitly, `moon check` reported `unreachable_code` on `_ =>` in the status walk
  — the same signal that already deleted the `PlanOp` catch-all at L2c — so both
  catch-alls are gone and a future `RendererFeature` variant fails the build here
  instead of silently reporting `gap`. Recorded trade: the in-module tripwire's
  `Gap` half now has no row to fire on, and what replaces that guarantee is the
  compile error plus the 85-cell capability validator, which runs on every host
  while this module compiles only on darwin.
- **A drift the machine cannot see.** `docs/zh-Hans/renderer-capability-report.md`
  is a hand-maintained mirror; the same edit line found Sun's `EmojiText` cell
  claiming `supported` where `moui_sun_renderer/capabilities.mbt:24` says `Partial`.
  Both matrix cells and the code row flipped together; the validator confirms
  "85 cells match the code self-reports".

## L3c (2026-10-28): the atlas divergence that mattered was not on the list

L3b's scoping note said the two atlas copies differ on four behaviours and that
the padding and empty-glyph rules are the correctness ones. Measured, all four are
inert and the failure was in a constant nobody compared: this route's atlas was
512x512 while `moui_wgpu_renderer/native_text_model.mbt:31-37` runs 1024x1024.

- Why the four are inert, each with its mechanism rather than a guess: the glyph
  sampler is `MTLSamplerMinMagFilterNearest` (`metal_renderer.mm:317`), so no
  fragment reads a neighbour texel and the 1px-vs-2px padding gap cannot bleed;
  both routes' `clear()` reallocates a zeroed pixel array, so "Metal writes
  transparent texels, WGPU skips them" cannot leave a ghost; a zero-size raster
  spends one shelf pixel per *distinct empty cache key* here, so it takes 512 of
  them to cost a row; and return-value-vs-counter is reporting.
- The capacity failure, measured through the real CoreText provider (a temporary
  probe in `metal_smoke.mbt`, run then deleted): with 512, one frame fit ~200
  distinct hanzi at 14pt and device scale 2.0, ~651 at 14pt/1.0, ~333 at 24pt/1.0,
  ~92 at 24pt/2.0. A Retina page of Chinese prose wants on the order of a thousand
  distinct ideographs, so the densest pages dropped their own overflow **every
  frame**. L3a removed the cross-frame wall; this is the within-frame ceiling, and
  a drop counter describes it without making it a degradation anyone would accept.
- The change is to match the sibling's budget, not to invent one: `METAL_ATLAS_SIZE`
  and `kMouiMetalAtlasSize` both 1024, capacity ~818 at 14pt/2.0 (4.1x), ~347 at
  24pt/2.0, ~1389 at 24pt/1.0, and no drops for 1600 distinct 14pt ideographs.
  Cost stated in full: 4 MB CPU buffer + 4 MB texture resident (was 1 MB each), a
  whole-texture re-upload on any frame that introduces a glyph, and a 4 MB zero-fill
  per overflow retry. `clear_metal_glyph_atlas` fills the existing array in place
  instead of reallocating, which removes the allocation churn — and the compiler
  then reported `unused_mut` on the field, so `pixels` lost its `mut`: the second
  time in this route that a warning was the proof of a structural fact.
- Drift between the two constants is now caught rather than assumed: the bridge's
  length check became an equality against `side*side*4` where it was a floor, so a
  caller larger than the texture is refused instead of uploading a prefix and
  sampling garbage. A/B proof: setting only the MoonBit side back to 512 fails three
  GPU pixel tests plus the new capacity floor, whose message reads "a 512x512 atlas
  only fit 289 distinct 28x28 glyph boxes". The floor asserts >=700 for 28x28 boxes
  — under the measured 818, far over the old 289 — so shrinking the budget fails in
  the module instead of showing up as missing text.
- Deferred with the reason, so nobody mistakes them for finished: LRU eviction (a
  working set above capacity thrashes exactly as it clears now, so it prevents no
  drop), dirty-rect uploads (a cost signal with no perf gate to act on it — L4),
  and the ceiling itself, now written into the `Text` row's note with its numbers.

## L4 size (2026-10-28): the release artifact refuted the band it was priced against

The owner's 体积 motive had only ever been argued. The plan's own text read: "a
no-third-party GPU renderer adds a rasterizer to that body; it cannot subtract
from it. So **size below the floor** is not a consequence of this route", with a
derived landing zone between `sun`'s 4.06 MB and wgpu's 11.05 MB, the engine cost
estimated at 4.80 MB of `__text` from `wgpu` − `sun`. Building it and running
`size -m` says otherwise:

| same app, same flags, same day | artifact | `__text` | `__const` (TEXT) |
|---|---|---|---|
| `macos_sun` (CPU raster, re-measured to confirm the pair) | 4,260,688 B | 3,699,004 | 338,848 |
| `macos_metal` (this route) | **4,101,856 B** | 3,527,568 | 339,584 |

- The GPU route is **158,832 B below** the number the plan called its floor, and
  its `__text` is 171,436 B smaller than Sun's whole software rasterizer while
  `__const` moved only +736 B. The missing step in the derivation is a category
  error: 4.80 MB is *wgpu's* engine, not the price of touching a GPU. A direct
  route substitutes per-fragment/command work for pixel-scan work, so the swap can
  be net negative — and against Skia's 21,340,336 B this artifact is a fifth of
  mainline.
- Boundary proof moved from config to product, which is what the L1d gate always
  claimed to be about: `otool -L` on the release binary lists Apple frameworks
  plus `libSystem`/`libz`/`libobjc` only, and `nm -a` returns 0 matches for
  `skia|Skia|wgpu|hal::|vulkan|Vulkan` with `strings -a` finding none.
- Recorded limits, because a good number invites a bad citation. The `-Wl,-dead_strip
  -Wl,-x` flags were added to `examples/showcase/macos_metal/moon.pkg` and
  `macos_sun/moon.pkg` for the two builds and reverted to `""` straight after, so
  the committed tree stays flag-free and the measurement is not reproducible by
  `moon test`. `moui package macos` builds **debug** artifacts and the
  `packageBytes` budgets (70–105 MB) are placeholders, so this is a release-binary
  figure, not a packaging-gate figure — the follow-up item "measure the release
  artifact through the packaging check" cannot be satisfied as written: that check
  does not produce a release artifact. One app, arm64, one build. The route still
  owes blur quality, a rounded-clip stencil path and `Overlay` blend code, so the
  gap could close or reverse as that lands.
- Documentation handled as corrections, not deletions: the plan's "The language
  floor, measured" section, its L0 outcome summary, its kill-reason table row 1 and
  ADR 0044's status bullet all still contain the refuted sentence, so each got an
  in-place correction naming the magnitude. ADR 0043 keeps its numbers as history.

## L4 gpu_recovery (2026-10-28): the vacuous gate was real, and one half was worse than the note

The plan's L4 line said `gpu_recovery` / `recover` "must not use the default that
always returns success (a known vacuous gate in this repo)". Scoping that against
this route found two distinct vacuities, neither of them Metal's own:

- `RendererSession::new`'s `recover~` default was `_ => RecoverySucceeded`. It is
  not reachable as a live lie today — Skia/WGPU/Sun pass `FallbackToCpu`, TUI/Web
  pass success, Metal passes a named refusal — but it is exactly the trap this
  route had to step around, so a new renderer could fall in without deciding. The
  default now returns `RecoveryFailed("renderer session was built without a
  recovery path")`, and `a session with no recovery path refuses rather than
  claiming success` (`moui/render/provider_binding_test.mbt:148`) is A/B-proven:
  with the old default it fails at the guard, with the new one it passes.
- The macOS GPU promotion harness was the worse half. Its context-loss phase
  finished with `context_loss_done = context_loss_injected` and
  `recovered_within_vsyncs = wait_presents` regardless of whether anything
  recovered, and since no route advances `gpu_recovery_count()` (Skia wires only
  `gpu_fallback_active`; inject is a no-op everywhere), `diagnostics.recoveryCount`
  in every promotion artifact was the number of losses *injected*. Now a loss
  counts only when the counter moved, and the lifecycle line carries
  `context_loss_injected=` + `recovery_count_after=` next to
  `recovery_count_before=`; the overlay parses `contextLossInjected` into
  `promotionGates.contextLoss`. Skia's recorded claim survives untouched because it
  rides `automatic_fallback`, the one wired signal.
- What was *not* built, with the reason: a Metal device-loss rebuild. `recover` has
  no production caller in the repo (all four call sites are tests), and
  `MTLDevice isRemoved` is never polled — so an injection seam plus a rebuild would
  price an extern against a failure no host path can produce. The reopen condition
  is written into ADR 0045: a host that calls `recover` on a real signal, at which
  point Metal's `RecoveryFailed("metal direct has no gpu recovery path before plan
  stage L4")` is the thing to replace.
- Honesty limit: the host half has no automated test. The phase machine needs a
  real window, so the proof is that the emitted line is now self-describing —
  `context_loss_injected=3 context_loss_done=0 recovery_count_before=0
  recovery_count_after=0` reads as "not instrumented" instead of "three clean
  recoveries".

Verification for this leg: `moon test moui/render --target native` 21/21 (the new
test included), `moon test moui/backend/macos --target native` 49/49.

## L4 paint-state probes (2026-10-28): a capability row nobody had drawn

The plan's remaining L4 item was "real probes for the 17 `RendererFeature`
states". Rather than build a 17-row probe table on top of evidence that already
existed, the first step was to find which rows had *none*: `PushTransform`,
`PopTransform`, `PushOpacity` and `PopOpacity` appear in zero tests across the
whole module, so those two rows had been reporting `Partial` from a reading of
`metal_geometry.mbt`. Eleven probes in `moui_metal_renderer/metal_state_wbtest.mbt`
put them through `metal_proof_pixels` — real Metal, real readback, abort rather
than skip when the host has no device — and the very first stream that combined a
transform with a scope produced nothing on screen.

- **Bug 1, a box culled by a rect the transform had already moved.**
  `append_metal_box` tested `state.clip.intersection(rect)` before emitting any
  vertex. Under `PushLayer(RectMask(4,4,8,8))` + `PushTranslate(4,4)` +
  `FillRect(0,0,4,4)` the rect's untransformed footprint sits outside the mask, so
  the op was counted as `clipped_away_ops` and drew nothing; the same stream
  without the layer drew it, and the same layer without the transform drew an
  in-frame rect. Diagnosis was by ink-extent probe, six variants, not by guessing:
  a `NoMask` layer and a zero-origin mask both kept the transformed box, a
  `DrawPath` kept it in every variant, so the failure was the rect cull rather
  than the pass machinery. Fixed with `metal_transformed_bounds` in
  `metal_geometry_wire.mbt`, applied to the image op's identical test as well
  (`append_metal_image` had copied the same cull).
- **Bug 2, a clip that stayed in the caller's space.** `metal_state_with_clip`
  intersected the raw clip rect. `moui_wgpu_renderer/native_visual_state.mbt:48`
  intersects `transform_rect(rect, state.transform)`, so the two native GPU routes
  read the same command stream differently and only one of them was wrong. The
  exception is shared too, deliberately: a `LayerSpec` mask is *not* transformed on
  either route (`native_visual_state.mbt:185`), because a mask names a rectangle on
  the surface while a clip names a shape in the space the caller paints in.
- **Non-vacuity, three ways.** Reverting either fix fails exactly its own probes
  (1 and 2). Replacing `transform_metal_point` with the identity fails all eight
  transform and clip probes while leaving the three opacity ones green, which is
  the shape of result this check should have. The first revert attempt was a false
  pass: `moon fmt` had re-indented the expression the patch was matching, so the
  substitution never applied and the "revert" reported 59/59. Same trap as the
  `recover~` A/B earlier in this route, and the reason the script now asserts the
  pattern is present before writing.
- **What did not change.** `Transform` and `Opacity` stay `Partial` for the reasons
  their notes already gave (CPU per-vertex composition with no per-object matrix
  upload; bounding-rect rounded clips counted through `approximated_clip_count`).
  Their notes now cite device-read bytes, and the module went 48 → 59 tests. The
  capability validator is unchanged at 85 cells because no status moved.

The reusable read of this leg: **a capability row whose op no test has ever drawn is
an unverified claim wearing a `Partial` label** — the label looks conservative and
is not evidence. The cheap way to find such rows is not to write probes for all 17,
it is to grep the ops each row names against the module's test files and start at
the rows that come back empty.

## L4 capability-row walk (2026-10-28): the table itself, checked against ink

The leg above left the honest score at "2 of 17 rows probed", and that framing was
itself the thing worth questioning. The other 15 rows *have* pixel tests. What they
did not have was any connection between the row's label and a number the device
produced: `validate-renderer-capability-consistency.mjs` compares the report table's
five columns against `metal_feature_status`, so docs and code can agree precisely
about a feature this route paints as nothing, and every review since has been
reading that agreement as evidence.

`moui_metal_renderer/metal_feature_probe_wbtest.mbt` (4 tests; module 59 → 63) is
one minimum command stream per row, put through the real Metal pass, with four
claims:

- **Label vs. pixels.** `Supported`/`Partial`/`HostForwarded` must put at least one
  pixel more than 40 above the opaque black clear in some channel; `Gap`/
  `Unavailable` must put none. The walk also asserts `probed == 16` — otherwise a
  loop that quietly skipped rows would still pass its own body.
- **Exemptions are named and re-tested.** `AsyncImage` is the one row a single frame
  cannot answer (request on frame one, paint after the completion), so it is
  exempted in a list with its reason, and `the exempted row is exempt because one
  frame really paints nothing` asserts that premise every run. An exemption that is
  never checked becomes a place to hide.
- **`Supported` must refuse nothing.** That test walks the rows claiming full
  fidelity and fails any whose probe stream trips `MetalFrameReport::refused_count()`.
  `image_ops_unresolved` is deliberately outside that count, because
  `metal_frame_report` runs without a decoder by design — including it would make
  the `Image` row's status depend on an instrument rather than on the route.
- **`HostForwarded` must be engine-dependent.** `the shaping row is forwarded, not
  drawn by this route` runs the same stream with and without the injected engine and
  requires ink in the first case and none in the second. This is the only row whose
  claim is an absence, so it is the one row where "paints something" is the wrong
  assertion.

Two streams were not free. The `BlendMode` probe's first version used `Multiply` and
painted **nothing** — which is multiply against an opaque black clear doing its job.
The fork there was between changing the stream and loosening the assertion, and the
second would have made the row's evidence depend on the clear colour; it uses
`Screen`, whose white-over-black is the composite's own output, with the reason in a
comment so nobody "fixes" it back. `Text`, `TextShaping` and `EmojiText` needed
different rasters (coverage vs. the green colour bitmap) or their three probes were
one frame three times.

Non-vacuity, measured: `Rect → Gap` fails the ink walk ("the rect row reports gap
while its probe stream paints 64 pixels") *and* the notes test ("a Gap row must say
the feature is absent"); `BlendMode → Supported` fails the claim check ("the
blend-mode row reports supported, but its probe refuses 1 ops"). 3 failures, then
63/63 after restoring — and this time the restore was byte-verified with
`shasum -c` against a pre-mutation checksum, and each pattern was confirmed present
in the *formatted* file before running, which is the step whose absence produced two
false "passing" A/Bs earlier in this same route.

What the walk does **not** claim, stated in the file's header: it proves that the
stream named after a row paints ink, not that the stream contains that row's op.
That direction needs a `DrawCommand`-to-row registry, and is left as a review
obligation on `metal_probe_commands` backed by the per-feature pixel proofs. The
shaping row's engine-dependence assertion is the one place where the absence is
machine-checked rather than reviewed.

## L4 text fidelity (2026-10-28): the route's text claim was two claims

The walk above left the 17 rows agreeing with the device. It did not touch the half
of "this route draws text" that this route does not draw: `binding_factory.mbt:62`
installs `native_text_system_with_cache(self.cache)`, `text_cache.mbt:227-231` builds
that system with `measure` and no `paragraph_layout` hook, and `text_layout.mbt:155`
then answers every `Text`/`TextArea`/`TextField` paragraph with core's fallback
arithmetic over the provider's metrics. Line breaking, caret rects, selection rects
and hit-testing on Metal are shared-module code paths, and the only suite that owns
that contract ran it through `skia_text_system()`, which *does* pass a native hook —
so the combination this route actually ships had never been asserted anywhere.

The scope fork was real and went the other way from "build it": a Metal-owned
paragraph engine would have been a third copy of a contract `moui/core` and the Skia
route already own, for a row the route already publishes as `partial` (its
`capabilities.mbt` note says the composition root wraps the platform provider with no
second engine behind it). What landed instead went into the suites that own text
fidelity — `assert_diagnostic_native_paragraph_contract(system)` extracted from the
Skia paragraph test rather than copied, one cosmic-backed case beside it (conformance
10 → 11; cosmic is cross-platform, so Linux and Windows CI now hold this route's
paragraph path), and one CoreText-backed case in `moui_text_providers/coretext`
(22 → 23) asserting the same contract against the engine
`examples/showcase/macos_metal` injects, plus `native_paragraph_ready == false` — the
honest half, since those line breaks came from arithmetic, not a shaper.

Three findings came out of writing it:

- **A title had outlived its content by three legs.** `metal session reports the
  fallback text system until the text leg lands` asserted `present_count` and the
  `recover` reason and nothing about a text system. Renamed to what it pins; the
  wiring claim got its own probe (`metal session gives the runtime the injected
  engine's text system`, module 63 → 64) that reads the metrics back off the session's
  own system and fails alone when `text_system=` is re-pointed at
  `@core.TextSystem::fallback()`.
- **The first fixture tripped a real split rather than a loose assert.** It measured
  8.8 wide where the provider said 6.0, because `NativeTextLayout::is_valid_for_measure`
  (`layout_validation.mbt:18`) demands a caret per cluster, rejects a caret-less
  layout, and the shared model then substitutes core's ~0.55em estimate for the widget
  while the painter still uses the provider's placements. Real providers ship caret
  tables (the CoreText suite pins those counts), so the finding is a fixture property —
  but it is exactly the widget-vs-paint divergence the new test exists to catch, so the
  fixture keeps numbers no estimate produces.
- **No profile ran the provider this route's text depends on.** `checks/profiles.json`
  had steps for `moui_metal_renderer` and its smoke and none for `moui_text_providers`,
  so those 22 CoreText tests only executed when someone typed the command. A
  darwin-host `CoreText provider tests` step now sits beside the Metal ones in
  `platform`.

Teeth: making `fallback_paragraph_should_wrap` (`text_layout.mbt:544`) never wrap fails
both new paragraph cases while the Skia one stays green — i.e. the coverage genuinely
was absent rather than redundant. Both mutations were confirmed present in the
formatted file before running, and both restores byte-verified with `shasum -c`.

Honest limit, written in the plan too: the contract is asserted through the text system
the route installs, not through a Metal frame. Wrapped paragraph *pixels* on the device
stay the run-placement tests in `metal_text_wbtest.mbt`, and no capability cell moved
(85 cells still match).

## L3 colour glyph inside a group (2026-10-28): a row's own note as a work queue

The `EmojiText` note had been naming its missing half in the plainest possible terms —
"a colour glyph inside a layer or filter group has not been put through" — and that
sentence was the whole task. Putting it through needed no new mechanism, only three
compositions of fixtures the module already carried (module 64 → 67):

- `a colour glyph keeps its pixels through a layer composite` — the group renders into
  its own offscreen target and returns as one composite quad, so green must still be
  green under a pure-red run.
- `a filter group rewrites a colour glyph as colour, not as coverage` — brightness 0.5
  halves the glyph's green; the assert carrying the meaning is the *red* one, because a
  coverage glyph tinted by that same run colour puts 128 there.
- `a masked layer clips its colour glyph as well as its pixels` — nothing had put text
  inside a masked group before (the mask tests all used fills), so this pins inked at
  (1,1) and black at (5,3) where the 4x4 mask ends, in one frame.

Two mutations, both confirmed in the formatted file before running and both restored with
`shasum -c`: `coverage_only` forced in `blit_metal_glyph` (`metal_text.mbt:163`) fails 3 —
the main-pass pair and both group cases, the filter one reporting "red channel 128 leaked
the run colour"; the mask dropped out of `metal_layer_clip`
(`metal_geometry_scopes.mbt:24`) fails 5, including the new text case. The second
mutation is shared with the fill-based mask tests, and saying so is the point: these
three extend the *context* the colour branch is claimed in rather than testing a
group-specific colour path, because the atlas is one texture and a group composite never
sees a run colour to leak. Status unchanged (`Partial`), the note now names only what is
actually left.

Chasing that row also surfaced the opposite asymmetry, in another module: the wgpu route's
`Clip` cell says `supported` while `moui_wgpu_renderer/native_visual_state.mbt:56-81`
tracks a `clip_radius` that **no code reads** — the scissor comes from `state.clip`, a
plain `Rect` (`:162`), and the one per-vertex radius channel is `mask_radius`, fed from
`layer.mask` (`native_visual_advanced.mbt:10`). So that route rounds a layer *mask* and
not a *clip*, which is the exact approximation this route discloses as its own missing
half, tabled as `partial` and counted. Left unfixed on purpose: correcting another
module's published self-report is a claim change on the diagnostic route, and the real
fix (stencil write on the clip shape, stencil-equal on what follows — a vertex carries one
clip slot, which is why an SDF-in-fragment cannot do nested clips) is one mechanism that
would move both rows. Nothing in the plan's stages asks for it, so it is recorded rather
than scheduled.

## Follow-Up

- L2 is closed (all 26 variants draw or count). Remaining honest gaps inside it:
  no cross-frame retained-layer cache (`retained_layers_rebuilt` was the cost —
  closed the same day by the pass-pool cache, see "Retained boundaries are kept
  across frames" at the end of this file),
  `Overlay` blend, true blur, and shader-effect `uniforms`.
- L3: atlas residency (L3a), colour glyphs (L3b) and atlas capacity (L3c, now the
  sibling's 1024x1024) landed; the four packing divergences were measured and are
  inert, so the shared-atlas extraction has nothing left to protect and waits for a
  third GPU route. Left: the engine's fallback chain (one codepoint, one font, main
  pass, 32pt, scale factor 1.0), and the rest of the `EmojiText` note — a
  colour-carrying glyph in a *rounded*-mask group or in two nested groups. ~~The two
  atlas behaviour divergences (padding rule, zero-size glyph rule)~~ were measured at
  L3c and are inert, so they are not a task; the shared-atlas extraction waits for a
  third GPU route. A colour glyph inside a layer or filter group **is** now put
  through ("L3 colour glyph inside a group" above).
  ~~The paragraph/hit-test fidelity in `moui_tests/text_conformance` that is still
  Skia-bound~~ is closed by the text-fidelity leg above: the contract is now asserted
  through the system this route installs, on cosmic (cross-platform) and on CoreText.
- L4: real capability probes for the 17 states are **all 17 rows under a device
  claim check now** — the 2 rows with no evidence at all are device-probed for shape
  ("L4 paint-state probes" above) and every row's label is checked against the ink
  its own probe stream paints ("L4 capability-row walk" above). What is left in this
  item is the walk's known gap: nothing machine-checks that a row's stream contains
  that row's op, so adding a row means editing `metal_probe_commands` under review
  rather than under a gate. The wgpu `EmojiText` row
  whose `supported` is now suspect is still open, and the same walk added a second one:
  wgpu's `Clip` cell says `supported` while its `clip_radius` has no reader, so that
  route's rounded clips are bounding rects too (see the last section).
  Corrected later the same day for *this* route only: `Clip` closed its bounding-rect
  half here (see "L4 `Clip`" below), while the wgpu cell is still the claim change that
  waits for its own module. Both are claim
  changes on another module, so they wait for the owner; then the product-class question
  can be revisited. Four L4 questions are answered: the recovery vacuity (see "L4
  gpu_recovery" above — the contract default now refuses, and the promotion
  harness no longer counts injections as recoveries), the release size (see "L4
  size" above — `macos_metal` measures 3.91 MB, below the `sun` figure this route
  was priced against) and the text half of "does this route draw text" (see "L4
  text fidelity" above — asserted through the system the route installs, on two
  engines, instead of left Skia-bound).
- ~~Measure the release artifact through the packaging check before any size
  claim.~~ Done as a direct `size -m` pair instead, because `moui package macos`
  builds debug artifacts — the packaging check cannot produce a release number at
  all, so that follow-up was unsatisfiable as written. If a release-size *gate* is
  ever wanted, it needs a new check that builds `--release` and reads `size -m`,
  not the existing `packageBytes` placeholder.
- `moui_metal_renderer` is a new public module, so the next release line must
  publish it (`mooncakes-release-playbook`), and the module-registration
  enumeration list there should gain the three gates this session added.

## Promote

`memories/repo/renderer-route-economics.md` carries the durable route facts: the
link-flag carrier rule, the platform-surface token guard, the premultiplied-text
and half-covered-mask lesson, the measured extern/API/evidence numbers, and what
remains unpriced.

## L4 `Clip`: a rounded clip that can stay a rounded box does (2026-10-28)

The row had disclosed its own missing half for three stages — `PushRoundedClip`
became its bounding rect's scissor, and `approximated_clips` counted the corner
difference instead of drawing it. This is the first leg since L2c that changes
what the route *draws* rather than what it reports.

The fix reuses two mechanisms that already existed, which is why the wire format
and the MSL source did not move — and the Web route reached for the same shape
first: `docs/renderer-capability-report.md:375` describes `PushRoundedClip` there as
"submitted as offscreen layer scopes with a rounded mask, reusing the browser
runtime's layer-mask composite path". A `LayerMask::RoundedMask` composite already
rounds its group with `moui_rounded_box_sdf`, and `PushLayer`/`PushFilter`
already open an offscreen pass for a scope. So a rounded clip is now that: a
scope whose pass is clipped by the bounding rect and whose single composite quad
is clipped by the arc. `metal_exact_rounded_clip` decides whether one rounded box
still describes the shape — the open transform must be axis-aligned with a
uniform scale (a rotation or a non-uniform scale turns the corner arcs into
ellipses), and neither the parent clip nor the surface edge may shrink the rect,
because the composite rounds the box it is handed and a shrunk frame would round
the wrong corners. Where either precondition fails the scope keeps the old
behaviour and keeps incrementing `approximated_clips`, so the disclosure stays
true for the cases still not drawn.

Three probes, and the middle one is the one that pays for itself:

- "a rounded clip rounds the corner instead of squaring it off" — a 16x16 white
  fill under a radius-6 clip reads clear at (0,0) and (15,15) and inked at (2,2)
  and (8,2); the same point is two device pixels inside the bounding rect, so no
  rect-scissor route can produce that pair.
- "a rounded clip under a scale rounds at the scaled radius" — under `scale(2)`
  a radius-3 clip on an 8x8 rect must land as radius 6 on a 16x16 one. The
  corner sample is the whole claim: 13 on the exact path, 255 when the radius
  stops scaling.
- "a rounded clip that cannot stay a rounded box is still counted" — a parent
  `PushClip` that shrinks the rect, and a skewed transform, both still report
  one approximation each. This is the precondition test, and it is what keeps
  the previous bullet from being read as "rounded clips are solved".

Two earlier pins changed because the behaviour they described changed, not to
make the suite green: `metal_state_wbtest.mbt`'s translated rounded clip moved
from `approximated_clips = 1` to `0` (a translation keeps a rounded box a rounded
box), and `metal_report_wbtest.mbt`'s empty rounded-clip group now refuses
nothing, because an empty group opens no composite — the same rule the layer
scope already applied.

A/B was run against the production change, not the tests: forcing
`metal_exact_rounded_clip` to return `None` makes 4 of 70 fail — the two new
pixel claims, the translated clip's counter, and the report's `refused_count` —
and the scale probe's failure message carries the number that separates the
routes. Restoring returns 70/70, `moon fmt --check` clean, all six static
validators clean.

**Cost, stated in the row rather than discovered later.** An exact rounded clip
is now a pass: one offscreen target the size of the clip's own device frame, one
composite quad, `report.layers` counting it. A page that round-clips every card
pays a target per card. That is the honest price of exactness without a stencil
attachment, and it is why the plan keeps stencil as *shared* work: it would be
exact for rotated and skewed clips too and cost no extra pass. The wgpu route's
`Clip` row claims `supported` while its own `clip_radius` has no reader — see the
cross-route finding in `docs/plans/active/no-third-party-gpu-route.md` — so the
stencil mechanism, when it is built, should be built once for both.

## Second `AsyncImage` scoping: a parity change declined on the same evidence

`SkiaRasterRenderer::dispose` marks every cached source `ImageDisposed` before
clearing its cache (`moui_skia_renderer/renderer_image.mbt:630-634`);
`MetalRenderer::dispose` releases the FFI context and leaves its records alone.
Writing the mirror here was the obvious next edit and is not happening: the only
readers of those records are tests (`RendererSession::image_diagnostics` appears
in `moui_tests/renderer_contract/renderer_contract_test.mbt:182` and
`moui/backend/host_rendering_test.mbt:132` and nowhere in a host path), and both
host dispose paths are terminal — `moui/backend/common/frame/window_frame_state.mbt:166-172`
refuses further frames once disposed, `moui/backend/common/window_host_workflows.mbt:16`
drops the session it just disposed. A stale record with no reader prevents no
failure mode, so this is the L4 `recover` discriminator applied in the other
direction: not "don't build a capability nobody calls", but "don't build parity
nobody reads". The mid-session half — `ImageResourceLifecycle::evict_disposed`
has zero callers on either route, so a departed source's texture lives until the
context does — is the part with a real user-visible cost, and it needs a policy
decision above this module.

The note edit written before this reading claimed the Skia route "also does not
exercise" a teardown policy. That was wrong in exactly the direction this file
keeps catching, and `capabilities.mbt` now carries the verified asymmetry, the
verified absence of a reader, and the shared mid-session half.

## L4 `ShaderEffect`: the four builtins are drawn, not fallen back (2026-10-28)

The `ShaderEffect` row had disclosed its own gap in words — "the named builtins
Skia and Sun implement (checker, vignette, linear-gradient-debug) have no
equivalent on this route" — and the shared contract that names them is a
function, not folklore: `builtin_shader_names()`
(`moui/render/common/advanced_execution.mbt:87`) returns exactly `solid`,
`checker`, `linear-gradient-debug`, `vignette`. So the leg was scoped as
"implement the declared list", with `moui_metal_renderer` free to disagree with a
route's *reading* of a name as long as the disagreement is written down.

No new bytes. `MOUIMetalShape` is 36 floats and two of them — `edge.z`, `edge.w`
— were being written as literal `0.0` with no reader, so the effect kind and the
effect amount moved into the slots the wire already reserved. `metal_renderer.mm`
reads the record as an opaque 144-byte constant, so neither it nor the record's
size nor the vertex format changed: the only new code is two `push_metal_f32le`
calls and one MSL helper. That is the same reuse-the-existing-mechanism move the
`Clip` leg made (a rounded clip rode on the layer pass and its mask SDF), and it
is worth naming as the route's pattern: this renderer already ships a per-item
constant block with slack in it, so a new per-draw parameter is a slot, not a
format change.

Formulation was chosen per effect, not per route:

- `checker` and `vignette` follow **Skia and Sun**, which agree with each other
  and disagree with wgpu. Skia's `draw_checker_effect` and Sun's
  `draw_checker_effect` both take square cells of `min(w,h)/amount` with
  `amount.max(1.0)`, measure from the frame origin and parity `(row+column)%2`;
  `moui_wgpu_renderer`'s WGSL normalizes each axis (`floor(local * max(amount,
  8.0))` over a 0..1 `local`), which produces *rectangular* cells on a
  non-square frame and silently ignores a request for cells coarser than 8. The
  Metal fragment does what the mainline does, and the shader comment says why.
- `linear-gradient-debug` is the one name all three already agree on (the frame's
  own horizontal span), so it is `mix(color0, color1, local.x / width)`.
- `solid` follows **wgpu** — one flat colour, the fallback brush's first colour —
  while `moui_skia_renderer`'s arm for `"solid"` is `draw_brush_rect`, i.e. the
  whole fallback brush. Over a solid brush the two are the same pixel; over a
  gradient they are not, and the note says that out loud instead of claiming
  agreement with the mainline. A/B case 4 below is what pins which reading this
  route actually implements.
- The colours come from the spec's `fallback` brush (`color0`/`color1` on the
  vertex), which is exactly `skia_shader_effect_colors` /
  `sun_shader_effect_colors`: solid → (c, c), linear → two stops, radial →
  centre/edge. So a fallback brush is never discarded, it is the palette.
- `uniforms[0]` is the only uniform read, and its *default* is per effect,
  because the mainline defaults are per effect: 8.0 cells for a checker, 0.8 of
  the frame radius for a vignette. Defaulting both to 8.0 would have made a
  bare `vignette` spec fade almost not at all, diverging from every other route
  for a case no test would have caught.

The row is `Partial` still, for four reasons that are now different from the
previous four: an app-defined effect name has no registry to resolve to and paints
its fallback brush (counted), `uniforms[1..]` are unread, `solid` diverges from
Skia, and the checker/vignette geometry diverges from wgpu. Two of those are
"nobody here has a shader registry", which is a shared gap rather than this
route's.

Two A/B runs, and the first one was weaker than it looked. Forcing
`effect_kind = metal_effect_none` fails exactly 4 of 74 — but all four die at
their `assert_eq(report.shader_effects_fallback_painted, 0)`, which is the first
assertion in each test, so the pixel claims were never executed. That run proves
the counter, not the picture. Breaking only the CPU→MSL handoff — writing `0.0`
into `edge.z` while leaving the CPU map and the counters alone — fails the same
4 at their **pixel** assertions (checker's diagonal red, vignette's black corner,
gradient-debug's left red, solid's far-edge red) with every counter still green.
Only the second run shows that the MSL branch produces the pixels and that the
shape blob is what carries the effect. Restored by exact string replacement,
`grep -c mutation` = 0, 74/74 again.

`examples/showcase/app/diagnostics/advanced_rendering_section.mbt:207-224` emits
`checker` with `uniforms=[8.0, 0.6]` and `vignette` with `[0.35]` on every frame of
the diagnostics section, so unlike the `Clip` row's prospective cost this one is
already emitted by a shipped app: wherever the showcase shows that section, two of
its own effects were being flattened until this leg. Scope corrected during the
`LayerCompositing` walk below — that app's *landing* frame is not this section (no
committed script launches `macos_metal`, and it passes no route), so the claim is
"every frame of that section", not "every frame of the evidence app". The smoke's
own counts are unchanged by the effects leg (2587 glyph pixels, 698/1011 emoji),
because the smoke stream draws no effect.

## `Text` atlas pages: a frame denser than one page (2026-10-28)

The third time a row's own note served as the work queue. `Text` had been carrying
its own remaining half since L3c — *"a frame whose own glyph set does not fit an
empty 1024x1024 atlas still drops and counts"* — and L3a's clear-and-rebuild could
not answer it: repacking into a second empty page of the *same* size walks into the
same wall, so such a frame lost its overflow on every frame, and the only sign was a
`text_dropped_glyphs` number that read as an ordinary counted degradation. The
`Text` row's `Partial` was honest about it, which is exactly what the capability
model is for on this route: the note names the half, and the half is where the next
leg comes from.

The fix reuses a word instead of adding one, which is now the route's pattern (the
`Clip` leg rode the layer pass and its mask SDF; `ShaderEffect` moved two effects
into the shape blob's dead `0.0` slots). Shelf packing is monotone — a glyph goes on
the current shelf or the next, never back — so within one run the page index never
decreases and the run splits into **contiguous vertex ranges**, one text item per
page. The item already had `texture_key` at `item[7]`, read by the image role as an
image record and by the composite role as a pass slot, so the page index went there
and nothing else had to move: the 76-byte vertex, the 9-int32 item row, the 36-float
shape blob and the MSL are untouched, and u/v stay page-normalized because every
page is the same 1024×1024. The alternative that looked better per megabyte —
splitting coverage by alpha depth, ~4× capacity for the same bytes — was rejected
for exactly that reason: selecting a page per *glyph* needs a new vertex attribute,
i.e. a wire change, while paging needs none.

Cost, stated before it was written down rather than after. Page 0 is allocated at
construction, so a text-light route pays the same one 4 MB CPU buffer + one 4 MB
RGBA8 texture it paid before paging; later pages exist only because a frame needed
them; `METAL_ATLAS_MAX_PAGES = 4` bounds the worst case at 16 MB + 16 MB, which is
why the cap is part of the design and not an oversight; `dirty` is per page, so a
frame that touched only page 0 uploads only page 0 (the previous behaviour was one
whole-texture re-upload for any new glyph at all). Past the cap, clear-and-rebuild is
retained rather than replaced. The host deliberately does not free page textures on
a clear — it keeps them until the context is released, because releasing them there
would rebuild a 4 MB texture on every frame of a document that keeps crossing the
cap — and the page cap is now written in two languages the way the side is, so the
host refuses a page index past its own constant rather than growing on a value the
CPU side never meant to send.

Measured, both directions, through the real CoreText provider on one
1,600-distinct-ideograph frame at 14pt:

- device scale 2.0 → `items=2 dropped=0`; the same frame with the cap pinned to one
  page → `items=1 dropped=782`. That second number is the interesting one: 1600 −
  782 = 818, which independently reproduces the ceiling L3c had derived, from a
  different fixture than the one that produced it.
- device scale 1.0 → `items=1 dropped=0`. This half is now asserted, not just
  printed: a frame page 0 already covers must not grow the atlas, so the steady
  state has a test rather than a comment. Fixing it also turned up that L3c's plan
  sentence "no drops at all for 1600 distinct 14pt ideographs" had omitted its
  scale and therefore read as a Retina claim that was never true — corrected in the
  plan, where both smoke lines are now quoted.

Module tests 74 → 76, and all three A/B mutations were chosen to fail at a **pixel**
assert, because this feature's first assertion in every test is a counter and a
counter-only failure would prove nothing about what reached the device. The new
device probe draws one glyph per page into a 1024×512 frame and reads four pixels:
both pages inked at (100,100) and (700,200), the gap clean at both (300,300) and
(612,100). Binding page 0 always in the host (`moui_metal_atlas_page(context,
item[7])` → `context, 0`) fails exactly one pixel — `metal_text_wbtest.mbt:529`, the
second page's clean gap, i.e. it draws page 0's glyph where page 1's belongs.
`METAL_ATLAS_MAX_PAGES = 1` fails 3 tests including `:530` (the second page never
lights). Making the run-split condition unsatisfiable fails `:527` (the first page's
own ink). All three restored, 76/76.

`Text` stays `Partial`, with three named reasons instead of the previous two:
capacity is a capped page set with clear-and-rebuild rather than a use-keyed eviction
record; the ceiling is measured rather than asserted; and colour glyphs are
composited as straight alpha with the composition root wrapping one engine, so a
codepoint the system cascade cannot resolve still has nowhere further to go. Updated
in `moui_metal_renderer/capabilities.mbt`, both capability-report `Text` rows (the zh
mirror had no Metal sentence at all there), `docs/text-system.md` plus its zh mirror
(a new direct-GPU text section), the plan's L3c block, and ADR 0045's decision 3,
whose "4 MB … for the life of the renderer" is now a per-page figure.

## Do retained layers actually happen? A verification that refuted its own draft (2026-10-28)

The `LayerCompositing` row's open half says the route rebuilds every
`BeginRetainedLayer` into a fresh pass because nothing is keyed by `key` or
`content_revision`. Whether that cost is *live* or *prospective* — the same
discriminator the `Clip` row had to state — had never been checked, so the walk was
"does any real emitter exist?"

It does, and the chain is short: the `View::repaint_boundary()` modifier
(`moui/core/view_modifiers.mbt:511`) sets `plan.repaint_boundary`
(`moui/core/modifier_paint.mbt:270`), `moui/runtime/paint_engine.mbt:134` then calls
`with_repaint_boundary_cache()` (`render_tree.mbt:197`), whose key is an always
non-empty `"element=…;x=…;w=…"` string (`:230-232`) so `cached_layer_spec()` returns
`Some` and `:98` pushes `BeginRetainedLayer(spec)`. On the app side the emitters are
`examples/showcase/app/diagnostics/components.mbt:24,32,80` — every diagnostics
section's scroll body **and** its header panel. So a Metal frame of one of those
sections does repaint each boundary with no cache to hit.

The draft of the note said more than that, and the extra was wrong. It claimed the
rebuild was "being paid on every frame of the evidence app". Four checks killed it:
`examples/showcase/macos_metal/main.mbt` passes neither `route` nor
`initial_section_code`; `ShowcaseRoute::default()` is `Components/welcome`
(`examples/showcase/app/workspace.mbt:84-86`), not a diagnostics section; the only
`repaint_boundary()` calls anywhere in the showcase are the diagnostics panels; and
`grep -rn macos_metal scripts/ checks/` returns nothing — no committed gate launches
that app at all. The honest sentence is "live on the first navigation into a
diagnostics section, not on the landing frame", and the same correction went into the
`ShaderEffect` record above, which had made the mirror-image overstatement about the
effects section.

Two findings are worth more than the correction. `benchmarks/app_cached_layer`
already navigates to that section (`:376`), so a retained-layer cache leg on this
route inherits a committed instrument instead of needing a new one — and because
`RetainedLayerSpec` already carries `key` and `content_revision`, a cache needs no
wire change to exist. That makes the cache the cheapest remaining `Partial`→ better
half on the route that has a benchmark for it, which is a sequencing fact the plan
should use when it picks the next leg.

## Retained boundaries are kept across frames, on the pool the host already had (2026-10-28)

The next leg was the one that finding pointed at, and it landed the same day. The
mechanism turned out to be something the route already had: `moui_metal_pass_target`
keeps one offscreen target per pass slot between frames and rebuilds it only when the
size differs. So a boundary that claims **the same slot at the same device rect** in
the frame after the one that painted it can composite that texture instead of
rebuilding its group — no copy, no new host object, no second record stream. The hit
pushes a pass record with `child_count = 0` and consumes the child stream without
drawing it, and the host's pass loop gained exactly one branch: a childless record
gets no encoder, because opening one clears the cached pixels. That branch is a no-op
for every stream that existed before this leg, since an empty group releases its slot
rather than shipping a record.

Three guards make the reuse safe rather than lucky, and each closes a different way to
paint an old picture: `content_revision` must match; `slot`, `device_x/y/width/height`
must all match; and the entry must come from the *immediately preceding* frame,
because a pass target is not private to a boundary — anything that claimed that slot
in a gap overwrote it. `retained_layers_cached` / `_rebuilt` / `_updated` / `_evicted`
now say which case ran, which is what the `LayerCompositing` note had been saying did
not exist.

The first version of the cache was wrong, and only a four-frame device run could see
it: an entry aged out on its **second** hit, because a hit does not paint, so a stable
page would save one frame in two. The fix is to re-stamp the entry on a hit — sound,
because the hitting frame also claims the slot, so nothing else could have painted it
in between. The test that caught it asserts `outcomes[2].cached == 1` in a run of
`[red, red, green, bumped]`.

Seven new tests (`metal_retained_wbtest.mbt`, module 76 → 83), five of them
device-free over the bookkeeping (hit, revision bump, moved rect, gap, changed
context) so they run anywhere, and two on the device over pixels. The decisive pixel
claim is deliberately a stale one: frame three keeps the key and revision but asks for
a **green** child, and the test asserts the pixel is still **red** — a hit that painted
what the current stream asked for would be indistinguishable from re-rendering it, so
the stale read is the only proof that the child stream was skipped. Its mirror (a
revision bump arriving as green) is asserted in the same run, and a second device run
pins that a boundary whose rect *grew* repaints rather than compositing an old frame.

Three A/B mutations, each confirmed to have landed before reading its result:
deleting the host's childless-record branch fails one test and it dies at the pixel
assert (`metal_retained_wbtest.mbt:351`, red expected where the cleared target gives
black), which is what proves the host hook carries the pixels; letting a hit ignore
every guard fails 4 tests (the revision, move and grow cases, and the device run);
making the hit test always miss fails 5, including the pixel run's `cached` asserts.
All three restored, `shasum -c` verified against the pre-mutation checksums, 83/83.

Cost and surface: the cache adds no GPU memory of its own (the targets it pins are the
ones a rebuild would have allocated), one field on `MetalFrameContext`, one struct in
the package, and three fields on the one existing public report struct — which moved
the module's interface budget 53 → 56 with its rationale written into
`tools/moui/validate_api_surface/main.mbt`. No declaration, type or function became
public. A stale test title went with it: `a retained layer rebuilds into its own pass
every frame` is now `a retained boundary with no frame before it rebuilds into its own
pass`, because the behaviour it named is no longer the general case.

`LayerCompositing` stays `Partial`, with three reasons that are no longer "there is no
cache": the reuse is the pass pool rather than a picture or pixel cache (so it is
valid only for the frame immediately after, at the same slot and rect); content
fidelity is delegated whole to `content_revision`; and entries are aged, never capped
or prioritised, so there is no residency decision of the kind Skia's picture cache and
Sun's pixel cache make.

## Colour glyphs through the last two group shapes (2026-10-28)

The row's note had named the remaining group cases itself, so the leg was two tests
rather than a design. A colour glyph inside a `LayerSpec` carrying
`LayerMask::RoundedMask`, and one inside two nested groups. The first turned out to be
the route's first device probe of that mask kind from a `PushLayer` at all — until now
the rounded mask SDF had only ever been reached from inside the `PushRoundedClip`
machinery (`metal_geometry.mbt:331`) — so the test does duty twice: colour fidelity and
the mask's own geometry.

Both are written as pairs so neither can pass by accident. The rounded case reads green
at `(3,3)` and `(2,2)` (deep inside the arc, inked by the fixture) and black at `(0,0)`
— the same fixture inks that corner, so a composite that dropped the mask paints green
there and fails, while a mask that swallowed the whole group fails the centre. The
nested case reads the three pixels the single-group test reads and adds
`report.layers == 2`, so it cannot be satisfied by one composite.

Module tests 83 → 85, and the candour clause matters more than the count: all five
group cases share one mechanism — the colour branch is decided at the vertex, and the
composite neither reads nor can re-tint it — so these probes widen the contexts where
the claim holds rather than proving a new path, and the note in
`moui_metal_renderer/capabilities.mbt` now says that in as many words. Two mutations
keep each other honest: forcing the coverage branch fails 6 tests including both new
ones (that shared signature is precisely the limitation being disclosed), while
dropping only the rounded mask's kind fails 3 and the new test dies on its own message
("the corner the radius should clear is inked"). The second run is the one that shows
the new probe is not the old probe in a costume. Restores `shasum -c`-verified, 85/85,
85 capability cells and six validators unmoved. `EmojiText` stays `Partial`; what is
left is real-provider evidence past one run on the main pass at 32pt and scale 1.0, and
the fact that whether a codepoint arrives as colour at all is the shared provider's
`kCTFontColorGlyphsTrait` call, not this module's.

## The blur was an echo; now it is a bell, and a pre-existing bug came with it (2026-10-28)

`FilterEffect` said "a 3x3 weighted tap, not a Gaussian". Measuring the pixels said
more than the sentence did: with taps at 0 and +-radius, a two-pixel mark blurred at
radius 8 came back as 128, 128 at the mark, **six pixels of nothing**, then 64, 64 at
+8. The group was being replicated at +-radius, not softened — a hairline or a glyph
inside a blurred group has two ghosts and no counter to explain them.

The fix is separable, and the route already owned every part of it. The horizontal stage
is one composite-role item; its target is an ordinary pass record, claimed *before* the
group so the host's descending walk renders it after; two filter-kind numbers replace the
blur payload at the composite. No vertex, item-row, record-layout or host change. A
blurred group now reports `layers = 2` — the intermediate is a pass and is counted as one
— while still counting one `filter_approximations`, and sigma is the radius, matching the
mainline's `ImageFilter::blur(radius, radius)`, with taps at every device pixel to
`min(2*sigma, 12)` normalised by their own weight sum.

The new test asserts a **profile** rather than a number: light must reach past the mark on
both axes, the falloff must be non-increasing in each direction, and the +8 sample must
not out-shine the ones nearer the mark. That last clause is the one the old kernel could
not pass, which is the point of writing the test as a shape.

Getting the second pass to work surfaced a bug that predated this leg. The intermediate
came back saturated, and chasing it found the composite fragment's `else if (kind > 4.5)`
— open above, so the new kinds 6 and 7 fell into the colour-matrix branch — and
`metal_identity_color_matrix` holding the numbers `moui_wgpu_renderer` ships, which are an
identity for a `mat4x5f` indexed *by column* and not for this shader's row reads. Under
this shader that "identity" mapped every channel onto red, so `o.w = c.r`: alpha became
red's value. Reachable today without any blur at all, through `ColorMatrix` given fewer
than 20 values, where the copy leaves the tail of the shipped array in place. Both fixed —
branch bounded at 5.5, identity row-major with each row's translation last — and pinned by
separate tests.

Three A/B runs, each aimed at one claim: the wrong identity fails exactly the
colour-matrix test, on its green-channel pixel assert, with the bell green; running the
horizontal axis twice instead of vertically fails the bell's "no light below the mark"
assert; disabling the blur branch fails the bell and the older softening test. Restores
`shasum -c`-verified; 87/87, six validators, 85 capability cells. `FilterEffect` stays
`Partial`, now for quality and scope rather than for a kernel that echoed: support stops
near 2 sigma, the 8-bit intermediate quantises twice, there is no backdrop, and the colour
filters run un-premultiplied where WGPU does not.

Two process facts are worth more than the diff. An embedded-MSL header can be rebuilt
verbatim from the compiled object — slice `_build/native/debug/build/.../metal_renderer.o`
from `#include <metal_stdlib>` to the next NUL; a `strings` dump is not enough because it
drops runs shorter than four characters and silently loses every `  }` line. That recovery
was needed because a substring anchor matched the *wrong* `kind > 0.5 && kind < 1.5` — the
shader-effect dispatch carries the same test — and one slice deleted a third of the shader.
And in that C-literal form every MSL line needs its own `\n`: a comment line without one
concatenates with the next literal, harmless inside a comment, fatal for the statement
after it.


## A shadow was a slab; now it is a bell (2026-10-28)

The `Shadow` row said "a soft-edge approximation, not a Gaussian convolution". That
was an understatement bought by never reading the pixels. Measured through
`metal_proof` — a 12-pixel mark, `blur_radius = 8`, `spread = 0` — the alpha along a
line through the middle was **255 from eight pixels left of the shape to seven pixels
right of it**, then fell to zero with a 76-level step at the grown box's own rim. The
box is inflated by `2*blur + spread` and the ramp only spans the last sigma, so what
reaches the screen is a solid rounded rectangle with a soft edge: a slab. Every card
with a drop shadow has been painting a hard-edged plate behind itself.

The fix is one line of maths, not a pipeline. Coverage at signed distance `d` from the
shape is `0.5 * erfc(d / (sigma * sqrt 2))` — the exact profile a Gaussian leaves at a
hard edge — with `sigma = blur_radius`, which is the mainline's reading because
`moui_skia_renderer` hands `radius` to `ImageFilter::blur` as sigma. `erfc` does not
exist in this MSL build, so the normal tail comes from Abramowitz & Stegun 7.1.26
(~1.5e-7, far below an 8-bit output). Two structural details matter: the distance is
measured from the **shape** inflated by `spread`, not from the box, which is why the
grow now has to be carried to the shader in the unused `edge.x` slot; and the box grows
by `3*sigma` instead of `2*sigma`, because a Gaussian is at 2.3% two sigmas out and
0.13% at three, so clipping it at two edges the tail. No new pass, no new texture, no
wire change — one `exp` per fragment over a somewhat larger quad.

The device test asserts a *profile*: half at the shape's edge, ~16% one sigma out,
under 10% at two, monotone out to three, and no single pixel carrying a large step. The
previous test only asked whether some ramp existed, and it kept passing against the
slab — so it was rewritten rather than kept as a witness. Two mutations confirm both
decisions are load-bearing: restoring the old ramp fails both tests; **keeping the
Gaussian but measuring the distance from the grown box fails only the new test**, which
is the cleanest demonstration that the old assertion could not see a shadow anchored to
the wrong geometry.

What stays honest about it: the distance field is one-sided, so a shape thinner than its
blur reads brighter at its centre than Skia's real two-sided convolution (that 12-pixel
mark peaks near 81% where the exact answer is about 50%), corners follow the SDF rather
than a true 2-D blur. (One clause written here was wrong and is left corrected rather
than erased: it claimed a path- or texture-filled source "casts its bounding box", but
`ShadowSpec` carries a `RoundedRect`, so the command model has no path-shaped shadow to
get wrong. The residual really is the corner falloff. Found while checking whether a
pessimistic claim was as poorly verified as an optimistic one would be.) And the two diagnostic routes now
disagree on this look: `moui_wgpu_renderer` still carries the ramp and its note still
claims the shared formulation, which is now the stale side — recorded as a cross-route
finding, the same shape as its unread `clip_radius`, and not this module's edit to make.


## The gate that could not read: `Partial` rows must now name their gaps (2026-10-28)

`metal_renderer_wbtest.mbt` carried a check titled "a Partial row must explain the
half that is missing" and implemented it as `note.length() < 60`. That is a proxy
that cannot fail for the wrong reason: `Transform` (814 characters) and `Opacity`
(715) passed on paragraphs that describe what works and name nothing missing, and
the other nine rows kept their reasons mid-sentence where nothing pointed at them.

The convention is now one a machine can check: every `Partial` note ends with a
`Remaining:` sentence, and the gate collects *all* offenders and fails with their
labels rather than one per run. Eleven notes rewritten to carry it — nine of them
summarising gaps they had already described, two of them stating gaps that had never
been stated. Those two are the value of the exercise, and both are code-derived:
`Transform` owes its gaps to a vertex-only affine stack (a corner radius, stroke
width or shadow blur band is right under uniform scale and rotation, cannot be right
on both axes under a non-uniform scale or skew — which is the same fact that makes
`PushRoundedClip` decline its exact path — and a rotated clip contributes only its
axis-aligned bounds to the scissor); `Opacity` owes its gaps to being folded into
each vertex colour (a mesh covering an area twice double-blends where a save-layer
route dims once) and to a group's opacity landing on the composite, where the
fixed-function factors are exact only over an opaque destination.

A tempting gap was checked and dropped rather than written: "colour glyphs ignore
opacity" is false — the colour branch multiplies white by `state.opacity` at
`metal_geometry.mbt:704`. Naming a missing half the code does not support would be
the same class of error as an optimistic row, pointed the other way.

Then I destroyed `capabilities.mbt` with my own patch script and got it back, which
belongs in the record: `open(p, "w").write(s.replace(a, b, "1"))` truncates the file
*before* Python evaluates the argument, so the invalid `str.replace` call raised
after the damage and left a zero-byte file in an untracked module. The copy
`moon fmt` had written to `_build/wasm-gc/release/format/.../capabilities.mbt`
sixty seconds earlier was the only recovery, and the restored checksum matched
exactly. Two rules fall out: build and assert on the new text before opening the
file for writing, and do not clean a build tree while untracked work depends on it.

A/B: removing one marker takes the suite from 88 to 87 with the gate naming the row;
restoring it is checksum-identical. `Remaining:` is also written into the model's
own header and the report's Update Rule, scoped to this module so it does not read
as a claim about the other routes' note text.


## The async-image evidence half, corrected three times before it stood (2026-10-28)

The `AsyncImage` row had a remaining half that read like this module's: "a
completion arriving over a presented host's event channel is still unevidenced".
Investigating it to *close* it turned into checking the claim itself, and the claim
did not survive.

First miss: I grepped for `window_image_task_starter_set`, found nothing, and wrote
"no production caller". The real symbol is `window_image_task_starter_install`, and
`examples/momark/macos_skia/main.mbt:24` calls it — `remote_image_starter` installed
before launch, the worker loop run as a sibling of the window pump, remote images
fetched off the UI thread. One shipped app, on the Skia route.

Second miss, and the more expensive one: the queued follow-up was to wire that same
starter into `examples/showcase/macos_metal` and observe the async completion there.
Before touching the entrypoint I read what the starter defers — `https:` sources only;
a local file or a `data:` URI completes inline. The showcase's images are `data:` URIs.
The plan would have produced a synchronous completion and been reported as evidence.
Closed as its own refutation.

Third miss: my replacement said the module was "unpublished". It is registered
`publication: public` in `checks/release-modules.json:68`; what has not happened is a
release line shipping it, and `examples/momark` is a submodule pinned to released
versions with no Metal variant to add. Registration and release are different claims
and the row needed the second one.

What the row says now, with each link checked: the two-frame lifecycle is proven
renderer-local; the mid-frame arrival through a real window's loop has never been
observed on this route because no in-repo app installs a starter and the only app that
does is a Skia one; the ordering semantics *are* evidenced at the backend with injected
`spawn`/`post` hooks; and closing the rest is a release line plus a network-fetching
Metal app — not renderer code. Which is the point of writing gaps precisely: a
half-attribute that sounds like work is a work queue item nobody should spend a day on
until it is checked, and here it took three checks to get one sentence right.


## A blur radius that did not widen the blur (2026-10-28)

`Blur(16.0)` and `Blur(6.0)` produced nearly the same spread. The separable kernel
had thirteen samples per axis one device pixel apart under a cap of
`min(ceil(2*sigma), 12)`, so its reach was twelve pixels whatever sigma was — a
bigger radius only flattened the weights. Measured on device across a straight edge
at sigma 16: **255 sixteen pixels inside the edge** (a Gaussian reads 214), 122 at
the edge, and **exactly zero one sigma out** where the truth is 40 of 255.

The test went in first and failed, which is the record: `a large blur radius widens
the falloff instead of flattening it`. The fix is a divisor — `stride =
max(sigma/6, 1)`, taps at `index * stride` pixels, weights over `(index*stride)^2`,
support `min(ceil(2*sigma/stride), 12)`. Same sample count, same cost, and the samples
now cover ~2 sigma at every radius. Measured after: 212 / 119 / 32 / 10 / 0 at
-sigma, the edge, +sigma, +1.5 sigma, +2 sigma against the ideal 214 / 128 / 40 / 17
/ 6.

The residue is the price of thirteen samples and is now what the row names, instead
of the old (wrong) "support truncates near 2 sigma" line: the far tail reads about a
fifth low, the intermediate is 8-bit so a wide blur quantises twice, a blur cannot
spill past its own group's frame because that frame *is* the pass target, there is no
backdrop, and the colour filters run un-premultiplied where WGPU runs premultiplied.

Two self-corrections in the same leg, both kept in the record because they are the
cheap kind that gets expensive if smoothed over. A figure in the `Shadow` note said
the exact two-sided integral is "~50%" where `Phi(6/8) - Phi(-6/8)` is 0.547 — the
device peak of 81% was measured, the comparison was not. And the plan row first
explained the one-sided shadow error away with "no view in this repo draws a shadow
thinner than its blur", which I had not checked; the sentence now says the claim is
unchecked and that the disclosed number, not the excuse, is the reason to leave it.


## The evidence grid the two text rows had been disclaiming (2026-10-28)

`Text` and `EmojiText` both carried a `Remaining:` sentence saying, in effect, "we
only measured one thing". That is a disclaimer doing the work of a measurement, so
the smoke grew.

Emoji evidence now runs 24, 32 and 48pt per sample and *through a layer composite* as
well as on the main pass. Measured: the ZWJ sequence inks 576 / 1011 / 2290 pixels
across those sizes, 571 / 993 / 2240 of them lighting green under a pure-red run, the
pure-green run lighting red in turn, and 2098 inked with 2048 green inside a group at
`layers` 1 — with the noop engine at zero in every case, which is what keeps any of it
a claim about text rather than about the clear colour.

The capacity check became a grid of cells: (14pt, scale 1.0, 1600 glyphs) → 1 text
item; (14pt, 2.0, 1600) → 2; (24pt, 2.0, 900) → 3; every cell with
`text_dropped_glyphs` 0. The third cell is the point — it confirms the per-page ceiling
at a second size instead of restating the 14pt one.

And the grid was shown able to fail, which is the whole difference between a gate and a
print statement: pinning `METAL_ATLAS_MAX_PAGES` to 1 makes the smoke report
`items=1 least=2 dropped=782` and abort, reproducing the 782 drops the paging leg
measured by hand weeks ago — now a regression tripwire instead of a paragraph.

What the rows concede afterwards is narrower and truer than before: read-back colour
evidence stops at device scale 1.0, because `metal_proof` renders one logical pixel per
texel, so Retina coverage is counters plus the module's own fake-raster probes; and the
capacity grid is two sizes and two scales, not every font and script. Neither row left
`Partial` — the grid removed a disclaimer, not a gap — which is the distinction the
`Remaining:` convention exists to keep honest.


## The proof pass can now render at Retina scale (2026-10-28)

Every pixel claim this module makes was a 1× claim, because `metal_proof_pixels`
hard-coded `physical_size = logical_size, scale_factor = 1.0` while the renderer it
mirrors has always taken a scale. That is how `EmojiText` came to carry a disclaimer
about "read-back colour at a Retina device scale" — not a missing capability, an
unreachable measurement.

`metal_proof_pixels` takes `scale_factor~ : Double = 1.0` now: logical `width` and
`height`, `width * scale` device texels. Only the proof pass changed, because the
geometry already splits those spaces — NDC normalises by logical size, scissors and
pass transforms by device size.

The test that keeps the parameter honest is a pair: at scale 2.0 a four-logical-pixel
box is inked at device `(6,6)` and empty at `(9,9)`, and the *same* stream at scale
1.0 is black at `(6,6)`. Both readings cannot pass if the scale is inert. Setting the
device dimensions back to the logical ones fails that test alone (89/90), which is the
A/B this module asks for before it believes a green.

Through the real provider the smoke now reads Retina colour: 🙂 6084 inked with 6018
green, the ZWJ sequence 8146 with 8049, noop control zero for both — alongside the
24/32/48pt size grid and the layer-composite case from earlier today. Both text rows
then lost an untrue disclaimer and gained the narrower true one: the matrix is sampled,
not covered (Retina is one run per sample on the main pass; the sizes and the group are
read at scale 1.0), and whether a codepoint arrives as colour is the provider's trait
call. Neither row moved off `Partial`.


## It had never been run in a window by anything committed (2026-10-28)

Offscreen pixel proofs, a real-provider text smoke, 90 module tests, six validators —
and not one committed step that opened a `CAMetalLayer` and presented through the
direct route. Running it by hand answered the question in one line:
`MOUI_MACOS_METAL_EXIT_AFTER_FIRST_PRESENT=1 moon run examples/showcase/macos_metal`
printed `macOS renderer presented first frame; exiting by request` and exited 0. The
framework loop holds: build, layout, text, images, host present.

A manual run is evidence, not a gate, so it became
`scripts/macos-metal-presentation-smoke.sh`, registered as a darwin `platform` step
beside the Metal tests and the Metal text smoke. It requires **two** lines. The host's
marker names the platform — Skia and wgpu present through the same backend and print
the same sentence — so the entrypoint now also prints an identity line assembled from
the module's own descriptor and capability rows:
`MoUI macos_metal renderer=direct-gpu family=direct-gpu provider=metal-direct`.

A/B on the gate itself: pointing its identity pattern at `renderer=skia-raster` makes it
exit 1 with "no renderer identity line; the presenting route is unnamed"; restoring it
passes. Without that second grep the step would go green for any renderer, which is the
same vacuity the capability notes were fixed for earlier today, arriving by a different
route.

Two sentences written earlier the same day became false and were refreshed rather than
left standing: the `LayerCompositing` note's "no committed script launches it" and the
plan's matching claim, both now marked as retired history with the script named. The
claim this does *not* make: it is a first-frame present, not a pixel assertion inside a
window — nothing reads the drawable back — and readiness stays `experimental`.


## Each capability row now pays for its own consequence (2026-10-28)

The row walk asked one question of all 17 rows: does the status match the ink? Its
own header admitted the half it could not ask — *"nothing here checks that a stream
contains the op its row is named for"*. Ink is cheap: a frame that ignores a clip, a
transform, an opacity or a blend mode still paints something.

`metal_probe_row_observed(feature, report, pixels)` asks the second question as a
total match over the 17 features, so a new variant is a compile error here too. Each
arm is a consequence only its row's op produces, and each number came from printing
all 17 streams first: the clip cuts 64 pixels to ~16, the transform leaves `(0,0)`
black and inks `(6,6)`, the blur puts light **outside** the shape it wrapped (80
pixels where the fill could cover 64) and reports two passes with one counted
approximation, the rounded box leaves its corner clear at 60/64, opacity sits at 128,
the shadow thins outward past its rect, the image samples red-left/blue-right, text
and shaping stay below 48 so neither can be a bar, a colour glyph lights green under a
pure-red run, and the fallback/blend rows produce their own counters.

The print-first habit paid for itself immediately: my first `Image` predicate asserted
red *and* blue in one pixel because I had read the printed tuple's channel order
wrong, and the walk went red before anything shipped. The measured values, not my
memory of the fixture, settled it.

A/B: replace the Clip row's stream with a bare fill — the op gone, the ink unchanged —
and the walk fails on exactly the consequence assert. Restore checksum-verified;
90/90. What is still review rather than a gate is the *choice* of stream for a row,
which the header now says plainly; the difference is that a stream not exercising its
row now has to survive a predicate written for that row.


## Two disclosures, one of them about my own writing (2026-10-28)

**Damage.** The route ignores `frame.damage` and repaints the whole surface, and no
sentence anywhere said so. The reason is structural, not lazy: the present pass clears
the drawable on load, so drawing only a damage rect would *erase* everything outside it.
Partial repaint needs a retained backbuffer or `framebufferOnly = NO` plus a copy — the
same cost family the `Overlay` backdrop was declined for. Now written at
`MetalRenderer::render_frame` and in the plan's permanent-cost section, so the
omission reads as a decision and the tempting "fix" (route the damage into the scissor
and skip the rest) is warned off before it ships a blank frame.

**A claim of mine that was not true.** The same discipline applied to my own prose found
it: the `Shadow` note said "a path- or texture-filled source still casts its bounding
box". `ShadowSpec::new` takes `rect~ : RoundedRect` plus colour, offset, blur and
spread — the command model cannot request a path-shaped shadow, so nothing was being
approximated there and no app could ever hit the limitation. Fixed in the module's
self-report and both report matrices, with the true residual named instead (the corner
falloff follows the distance field rather than an exact 2-D convolution).

The general shape of the mistake is worth keeping: an over-pessimistic row costs the same
as an optimistic one, because both make the table untrustworthy — one hides a gap, the
other invents one, and a reader allocating work from either is wrong. 90/90, six
validators green.


## The windowed gate now looks at what it presented (2026-10-28)

The presentation gate proved the right renderer was selected and that a frame was
presented. It would have been happy with a blank screen — the host prints its marker
once a drawable is handed over, ink or no ink.

So the host now copies the drawable before presenting it and counts the pixels that
differ from the frame's clear colour:
`MOUI-METAL-PRESENT width=2200 height=1360 ink=1817023` on a real Retina window —
60.6% of the surface carrying the UI. The gate parses that line and rejects anything
outside a 0.5%–99.5% band, so an untouched surface fails and so does a surface that
differs from its clear colour everywhere, which would be a broken clear rather than a
UI. `framebufferOnly = NO` is applied only while the smoke variable is set, because the
copy costs bandwidth on every frame; unflagged runs build the layer exactly as before.

Falsified the only way that means anything: force the reported count to zero and watch
the identity line and the first-frame marker both print — the old gate green on a blank
window — while the new one exits 1 with the ink figure in its message. Restore is
byte-exact by `diff`, and the run passes again.

Not to be oversold: this is coverage, not in-window pixel fidelity. Per-pixel claims
stay with the offscreen proofs, which can assert exact channels; the windowed step
answers the different question of whether what reaches a real drawable is a scene at
all.


## Decoded images now have a budget, and the claim about them became a test (2026-10-28)

`AsyncImage` said plainly that one texture per distinct source lived until the context
died, and offered the reason: reclamation policy "belongs above this module". Half of
that was a policy question and half was simply work nobody had done — the code that
installs a texture can also release one.

Each build now enforces a resident-bytes budget, releasing least-recently-used through a
new `moui_metal_image_release` host call (the FFI surface goes 8 → 9), dropping the
lookups so the next frame treats the source as unresolved, and counting what it dropped
in `image_textures_released`. The budget is a field on `MetalFrameContext` rather than a
constant at the call site, and that detail is the difference between a tested feature and
a decorated one: the first test called the enforcement helper directly, so deleting the
wiring left it green. Wiring a field a test can shrink makes the A/B bite.

The test asserts the invariant that matters about eviction — a released image is either
re-resolved or requested on the next frame, and after the completion it paints its
fixture's red/blue halves again — and it corrected its own premise while being written:
with a readable host source the build resolves the image *in place*, so the staged
request/complete/request script the first draft assumed never happens. Assertions became
invariants rather than choreography.

Still true and still named in the note: this is eviction under pressure, not reclamation
on notification — `evict_disposed` has no callers anywhere, and deciding when a disposed
source should go is above this module. 91/91.
