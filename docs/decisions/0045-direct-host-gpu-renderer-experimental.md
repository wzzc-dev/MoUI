# 0045: `moui_metal_renderer` is declared an experimental renderer at its L1 evidence frame

- **Date**: 2026-10-27
- **Status**: Accepted
- **Deciders**: wzzc-dev (owner — directed "把文本 provider 从 wgpu 模块搬出，然后
  实现 moui_metal_renderer"), agent-assisted (implementation and verification)
- **Related**: implements ADR 0044's L1 stage; declares the product class the way
  ADR 0023 declared `sun`'s; adds invariant R8 (`docs/invariants.md:38`); depends
  on the L0.5 provider relocation (`wzzc-dev/moui_text_providers`); amends
  ADR 0005's "Metal only through Skia" reading through ADR 0044.
- **Amended**: 2026-10-28 — L2 (strokes, brushes, shadows, the async image
  lifecycle) and L2c (layer, blend, filter, retained-layer and shader-effect
  scopes) landed, so this route's frame is "every `PlanOp` variant is drawn or
  counted", not L1's clear-rect-glyph. The same day L3a (the glyph atlas can now
  empty and rebuild) and L3b (colour glyphs, through a fix in the shared CoreText
  provider) landed, so the capability row has no `Gap` left. Also the same day the
  route's size motive was measured instead of derived, and the measurement refuted
  the band ADR 0044 had priced it against (§"Amended 2026-10-28 (L4 size)"), and
  plan stage L4's vacuous-gate item was scoped and closed at the contract rather
  than by writing a recovery engine (§"Amended 2026-10-28 (L4)"). The sections below
  carry the current numbers; §"Amended 2026-10-28: command honesty" and §"Amended
  2026-10-28 (L3)" record the decisions a later reader is most likely to reverse.

## Context

ADR 0044 authorized a GPU route that links **no external graphics library** —
Apple frameworks yes, Skia/wgpu no — and its L0 kill gate fired on the
performance branch, leaving size-versus-Skia and autonomy as the surviving
motives. The owner then directed the two remaining structural steps: move the
platform text providers out of the WGPU module (L0.5, so that a second renderer
may reuse them without violating P14), and implement the Metal renderer (L1).

L1's acceptance was fixed before any drawing code existed: one clear colour, one
filled path, and one CoreText glyph run, presented through the `CAMetalLayer` the
macOS backend already creates, with `otool -L` / `nm` / `strings` proving no Skia
and no wgpu symbol or link entry in the artifact, and the FFI surface inside the
10–40 extern estimate.

## Decision

`wzzc-dev/moui_metal_renderer` is registered as a renderer module
(`checks/release-modules.json`, `role: "renderer"`) and its product class is
**experimental**: no product commitment, not on default composition roots, no
`auto` selection, and new capabilities are exceptions that require an ADR note.
Invariant R8 records that; `docs/renderer-capability-report.md` carries the
route's 17-feature self-report as its own column, machine-checked against
`metal_feature_capabilities()`.

Three naming and dependency choices are the part a later reader is most likely
to reverse, so they are recorded with their reasons:

1. **The protocol identity is neutral, the module name is not.** The route is
   `moui_metal_renderer`, but the `moui/render` enum cases are
   `RendererBackendKind::NativeDirectGpu` and `RendererFamily::DirectGpu`. A
   `Metal` case would have been the literal name and is a guard violation:
   `moui/render`'s published surface is forbidden from naming platform surfaces
   (`checks/backend-common-ownership.json` `rootRenderForbiddenTokens` lists
   `Metal`, `HWND`, `Wayland`, `Vulkan`, `EGL`, `D3D`, `Direct3D`, and
   `validate-api-surface.mjs` rejects the token in `moui/render/pkg.generated.mbti`).
   The guard fired on the first attempt and the guard won: the neutral term is
   what the layer already uses (`RendererPresentationModel::HostGpuSurface`), and
   the disambiguating phrase for prose remains "no Skia, no wgpu" — because
   `docs/platform-notes-macos.md` already calls the *shipped* Skia-on-Metal path
   "the direct Metal GPU provider".
2. **The renderer depends on no text provider.** `metal(text_engine~)` takes the
   engine from the composition root and re-exports the neutral constructors, so
   the same route runs on CoreText, DirectWrite or Fontconfig coverage. This is
   the payoff of L0.5 measured: the module's dependency closure contains
   `wzzc-dev/moui` and Apple frameworks and nothing else.
3. **The glyph atlas is renderer-local.** P14 forbids importing another
   renderer's atlas, so a shared atlas is an L3 architecture decision, not an L1
   shortcut. The local one keeps no per-glyph residency record: at L1 a glyph
   that did not fit was dropped and counted, and nothing ever emptied the atlas,
   so a long document lost text permanently. Amended 2026-10-28 (L3a) — a full
   atlas now clears and rebuilds the frame once, the policy
   `moui_wgpu_renderer/native_visual_plan.mbt` already applies to the same op,
   so the working set of the current frame is what occupies the atlas.

## Measured evidence

- Zero Skia / zero wgpu: `otool -L`, `nm -a` and `strings` on
  `examples/showcase/macos_metal` all report 0 matches; the only non-system
  library on the link line is none — the artifact links `Metal` and `QuartzCore`
  from `/System/Library/Frameworks`.
- FFI surface: **7** `extern "C"` declarations (`context_create`,
  `context_prepare`, `texture_write`, `image_upload`, `draw_frame`,
  `draw_proof`, `context_release`) at L1 — below the 10–40 estimate, not above
  it. Amended 2026-10-28 by the image lifecycle: `image_upload` split into
  `image_decode` + `image_write_rgba`, so the surface is **8**; and again the same day by the decoded-image budget, which added `image_release` to drop a texture the renderer no longer has room for — **9** externs (`grep -c '^extern "C" fn ' moui_metal_renderer/metal_device.mbt`), still inside the 10–40 estimate the reopened plan priced.
- Frame wire format, as the host reads it: **9 int32 per item** (the 8th being
  the `owner` slot tag — `-1` main pass, `-2` discarded, `>= 0` a layer slot),
  **36 floats per shape**, **11 words per layer record** (7 int32 + 4 float),
  76 B per vertex. A fixed small record set is what keeps the extern count at 8:
  geometry is passed as flat buffers, not as one call per op.
- Public API: `moui_metal_renderer/pkg.generated.mbti` is 53 lines / 13 public
  declarations (9 functions, 1 report struct of 13 counters, 2 methods, 1 type
  alias); the renderer, its geometry, glyph atlas, image cache and frame types
  are package-private.
- 16 module tests pass at L1 (43 since the image lifecycle and the L2c scope
  proofs landed), including
  offscreen pixel assertions for the clear
  colour, a filled rect, a solid tessellated path, a scissored clip, and a
  **half-covered** synthetic glyph (a fully covered mask cannot distinguish
  "coverage applied to colour" from "coverage applied to alpha" — the first
  version of that test passed while real text painted solid bars).
- `moui_tests/metal_renderer_smoke/macos` renders one real CoreText glyph run and
  asserts the read-back ink ratio is glyph-shaped (measured 0.245 of the frame)
  with a noop-engine control at exactly 0 ink.
- A real window shows the showcase's text, correctly oriented, top-left origin.
  The release artifact has **not** been sized against the 20.35 MB Skia figure:
  the 8.9 MB above is a debug build, and `packageBytes` baselines in this repo are
  placeholder values, so the size motive stays unproven until a release build is
  measured through the packaging check.

## What L1 does not claim

(Updated as later stages land. L2 same day: `FillRoundedRect`, the stroke
variants, the brush variants and `DrawShadow` are drawn with pixel proofs. L2b
2026-10-28: `DrawImage` draws on the host's asynchronous image lifecycle —
`image_source`, `image_decoder`, `image_records` and
`apply_image_load_completion` are wired over the shared
`@render_common.ImageResourceLifecycle`, decoding is ImageIO, and the pixel proof
asserts the image paints on the *frame after* the completion, not inside the
requesting frame. L2c 2026-10-28: the layer, blend, filter, retained-layer and
shader-effect ops draw too, which closes L2 — **all 26 `PlanOp` variants now
carry a draw arm and none is silently skipped.** The refusal list below is the
L1 state; the plan's progress notes and
`docs/renderer-capability-report.md` carry the current one.)

Rounded-rect fills, all strokes, shadows, images, gradients, layer and filter
scopes and retained layers were **counted as dropped work, not approximated**
(97 dropped ops in the showcase's first frame, measured before L2 and L2b);
`recover` returns
`RecoveryFailed` because there is no recovery path before L4; colour (emoji)
glyphs are composited as straight alpha with no colour-font evidence; the
engine's fallback layout is never consulted; and the headless performance
harness still cannot drive a `HostGpuSurface` provider, so no frame-time claim is
made either way.

## Amended 2026-10-28: command honesty

L2 and L2c turned the route from "draws four things and counts the rest" into
"draws everything, counts what is approximate". Three choices in that work are
the ones a later reader is most likely to reverse, so they are recorded here
rather than only in the plan notes.

1. **Nothing is left undrawn, and the guarantee is the compiler's.** The op walk
   in `metal_geometry.mbt` matches every `PlanOp` variant with **no catch-all
   arm**, so a new variant in `moui/render/common/draw_plan.mbt` is a compile
   error in this module rather than a frame that quietly stops drawing it — the
   same guarantee `moui_wgpu_renderer/native_visual_plan.mbt` has relied on.
   The consequence for the public surface: `MetalFrameReport.dropped_ops` was
   deleted. Once every variant had an arm, the counter could not be non-zero, and
   a permanently-zero field in a report a host reads is decoration. An op that is
   *degraded* is still counted (`blend_modes_unsupported`,
   `blend_modes_approximated`, `filter_approximations`,
   `retained_layers_rebuilt`, `shader_effects_fallback_painted`); an op that is
   *missing* is now impossible to ship.
2. **Exactness is counted, never implied.** Metal's fixed-function blend can
   express SourceOver, Multiply, Screen, Darken and Lighten; `Overlay` is not
   expressible at all, and any non-SourceOver mode is exact only over an opaque
   destination. Those are two different facts and get two different counters, so
   a host can tell "this mode is not drawn" from "this mode is drawn with an
   approximation we cannot prove is invisible here". Blur is a 3×3 weighted tap
   into `filter_approximations`. A backdrop-copy blit for the true convolution
   was evaluated and rejected: it costs a second texture per filtered group for a
   fidelity this route has no evidence yet that anyone needs.
3. **A box and a path do not share a coordinate space.** The MSL box SDF measures
   the brush from `in.local - half_size`, i.e. rect-origin-relative, while the
   path mesh carries absolute surface positions as `local`. Brush endpoints for
   boxes are therefore shifted by the rect origin before upload, except a radial
   gradient's `end.x`, which is a *radius* (a length) and must not shift.
   Every gradient test written before this existed anchored its rect at `(0,0)`,
   where the two spaces agree, so the whole suite was green while a linear
   gradient on an offset rect interpolated a shifted axis (declared `2→10`,
   measured `4→12`). Pinned by the two off-origin proofs in
   `metal_l2c_wbtest.mbt`. The general fact worth keeping: **a pixel proof that
   only holds at the origin proves the arithmetic, not the coordinate space.**

Retained layers were the one honest "worse, not missing": this route had no
cross-frame cache keyed by `RetainedLayerSpec.key`, so a repaint boundary was
rebuilt into a fresh pass every frame — same pixels, none of the saved work — and
`retained_layers_rebuilt` was where that showed. Amended the same day (L5):
`moui_metal_renderer/metal_retained.mbt` keeps boundaries across frames by reusing
the pass pool the host already had — one target per slot, rebuilt only when the size
differs — so a boundary that claims the same slot at the same device rect in the
frame after the one that painted it composites that texture with a childless pass
record, and the host's pass loop skips the encoder for exactly that record because
opening one would clear the cached pixels. It is a reuse of the pool, not a picture
or pixel cache: an entry is trusted only for the frame immediately after the one
that painted or carried it, at the same slot and rect; content fidelity is delegated
whole to `content_revision`; and entries are aged rather than capped or prioritised.
Four records now say which case ran: `retained_layers_cached`,
`retained_layers_rebuilt`, `retained_layers_updated` and `retained_layers_evicted`,
which is why the module's interface budget moved 53 → 56 (three fields of the one
existing report struct, no new declaration).
A `DrawShaderEffect` whose name
is one of the four `builtin_shader_names()` declares is drawn per fragment (L4,
same day: checker cells and vignette radii follow Skia and Sun, `uniforms[0]` is
the only uniform read); an app-defined name is still painted with the `fallback`
brush its own spec declares, counted in `shader_effects_fallback_painted`. Both are `Partial` in the
capability report and cite the test names that prove them; the report's own
in-package tripwire refuses a note that is more optimistic than its status.

## Amended 2026-10-28 (L3): colour is a property of the font, not of its name

L3a (atlas residency), L3b (colour glyphs) and L3c (atlas capacity) landed the same
day, and L3b changed a file outside this route. Three decisions here are the ones a
later reader is most likely to reverse.

1. **A raster's format is decided by `kCTFontColorGlyphsTrait`, never by a
   PostScript name.** The shared CoreText provider (`moui_text_providers/coretext/
   macos_coretext_text.m`) chose colour by comparing the resolved font's PostScript
   name with `"AppleColorEmoji"`. On macOS 26.3 the system cascade resolves an
   emoji to `.AppleColorEmojiUI`, so the comparison never matched and every emoji
   came back as a 37×42 DeviceGray coverage mask — it drew, it was shaped right,
   and it had no colour, which no counter in this repo reports. The trait check is
   the documented API for exactly this question. Reverting to name keying is not
   available as a shortcut: `CTFontCreateWithName(".AppleColorEmojiUI")` is refused
   (TimesNewRomanPSMT comes back with a CoreText console note) and
   `moui_create_named_font_from_bytes` returns NULL for a `.`-prefixed name, so the
   trait can only be read from the font the cascade already produced.
   **This decision is not Metal-scoped.** `moui_wgpu_renderer` links the same
   provider, and its `EmojiText` row claims `supported` — a claim the old keying
   cannot have been delivering on this OS. That row is now known-suspect rather
   than known-good, and re-evidencing it is L4 work.
2. **A capability row is earned by an arm, not defaulted.** With all 17 features
   named, `moon check` reported `unreachable_code` on the `_ => Gap` arm — the same
   compiler signal that deleted the `PlanOp` catch-all above — so both catch-arms in
   `moui_metal_renderer/capabilities.mbt` are gone. A new `RendererFeature` variant
   is now a compile error in this module instead of a row that silently reports
   `gap`. The cost is recorded rather than hidden: the in-module tripwire's `Gap`
   half (a Gap note must contain the literal "not implemented") has no row to fire
   on today, and what guarantees the behaviour instead is the compile error plus the
   85-cell capability validator — the latter runs on every host, while this module
   compiles only on darwin.

3. **The glyph atlas is 1024x1024 because the sibling route's is, and the number
   is measured rather than assumed.** At 512 the atlas held ~200 distinct Chinese
   ideographs at 14pt and device scale 2.0 — a Retina page of prose wants on the
   order of a thousand — so the densest pages dropped their own overflow on every
   frame, which is a missing-text failure rather than a counted degradation. Growing
   to 1024 (the budget `moui_wgpu_renderer/native_text_model.mbt` already pays)
   raises that to ~818. The permanent cost is part of the decision, not a footnote:
   4 MB of CPU pixel buffer and a 4 MB RGBA8 texture for the life of the renderer, a
   full-texture re-upload on any frame that introduces a glyph, and the fact that
   the size is written in two languages, so `moui_metal_texture_write` now requires
   an exact length match to refuse drift instead of sampling garbage. Eviction was
   evaluated and not adopted: a working set above capacity thrashes identically
   whether it clears or evicts, so it prevents no dropped glyph.
   Amended 2026-10-28 (L5) — the ~818 is now a per-page figure, not the route's
   ceiling. Clear-and-repack recovers a *document* that outruns the atlas across
   frames, but a single frame whose own glyph set exceeds one empty page was
   repacked into the same shortfall, so it lost that overflow every frame and no
   counter made that look like anything but `text_dropped_glyphs`. Atlas packing is
   shelf monotone, which means the glyphs of one run arrive in non-decreasing page
   order for free, so the run splits into contiguous vertex ranges — one text draw
   per page — and the page each draw samples is named in the item word the wire
   already had (`texture_key`). The 76-byte vertex, the 9-int32 item and the MSL are
   untouched, which is why this is an amendment rather than a new wire decision.
   The cost changed shape, not magnitude, in the common case: page 0 is allocated at
   construction, so a text-light route pays the same 4 MB buffer + 4 MB texture it
   paid before, `dirty` is per page so a frame that touched only page 0 still
   uploads one page, and pages after that are allocated only by a frame that needs
   them, bounded by a 4-page cap — a worst case of 16 MB staging + 16 MB texture,
   which is why the cap is part of the design. Past the cap the clear-and-rebuild
   recovery is retained, not replaced. The two sides are measured through the real
   provider on one 1,600-distinct-hanzi frame at 14pt and scale 2.0: `items=2
   dropped=0` with pages against `items=1 dropped=782` with the cap pinned to one
   page, which is also an independent confirmation of the ~818 figure (1600 − 782).
   Host page textures are deliberately not freed on a clear: they stay until the
   context is released, because releasing them here would rebuild a 4 MB texture on
   every frame of a document that keeps crossing the cap.

The measurement method for claim 1 is worth keeping as a pattern: a single run
colour cannot tell a colour glyph from a solid bar, so the smoke draws the same run
in pure red and in pure green and asserts the channel **the run colour zeroes** is
lit in each — a monochrome provider fails both claims, and a bar is caught by
neither claim as written, which is why each names a different channel. Paired with
an identical glyph box delivered in both raster formats and a noop-engine control
that must paint zero pixels.

## Amended 2026-10-28 (L4 size): the floor this route was priced against was not GPU-shaped

ADR 0044 left the size motive as "well under Skia's 20.35 MB, but never below
`sun`'s 4.06 MB", derived from `wgpu` − `sun` ≈ 4.80 MB of `__text` and restated
in the plan as a landing zone between those two numbers. The first release build
of this route falsifies the derivation:

| `examples/showcase`, `--release --target native`, `-Wl,-dead_strip -Wl,-x`, same day | artifact | `__text` | `__const` (TEXT) |
|---|---|---|---|
| `macos_sun` — CPU raster, links no graphics library | 4,260,688 B | 3,699,004 | 338,848 |
| `macos_metal` — this route, direct GPU | **4,101,856 B** | 3,527,568 | 339,584 |

The GPU route is **158,832 B smaller** than the CPU-raster route it was said to
sit above, and its `__text` is 171,436 B smaller than Sun's entire software
rasterizer, while `__const` moved by +736 B. The step the derivation was missing:
a GPU route does not *add* a rasterizer to the always-linked MoUI body, it
*substitutes* Metal command encoding for scan-raster code — and that substitution
measured net negative. Against the mainline (21,340,336 B) this is a fifth of
Skia's artifact with no external graphics library in the link.

Boundary proof taken from the shipped binary rather than from `moon.pkg`:
`otool -L` on the release artifact lists only Apple system frameworks plus
`libSystem`/`libz`/`libobjc`, and `nm -a` finds 0 matches for
`skia|Skia|wgpu|hal::|vulkan|Vulkan` with `strings -a` finding none either.

What the number is **not**, stated so it is not over-read later:

- It is not a packaging-gate measurement. `moui package macos` builds debug
  artifacts, and `checks/performance-budgets.json`'s `packageBytes` limits
  (70–105 MB) are placeholders no route approaches — so no gate enforces, or is
  satisfied by, anything in this table.
- The two link flags are not committed on these entrypoints; they were added to
  `examples/showcase/macos_metal/moon.pkg` and `macos_sun/moon.pkg` for the
  measurement and reverted to `""` immediately after, which is why the numbers
  are reproducible only with them re-added.
- It is one app, one architecture (arm64), measured once. The route still owes
  engine code this build does not contain — a real stencil path for rounded clips
  instead of the bounding rect, and the `Overlay` blend mode, both of them shared
  work with `moui_wgpu_renderer` rather than this module's to add alone — so "GPU
  is smaller than CPU raster" is a fact about today's two binaries, not a property
  of the route. Amended later the same day: two items had come off that list, the
  separable Gaussian-quality blur (sigma = radius, one axis into a second pass
  target) and cross-frame retained-layer cache keying on the pooled pass target,
  so the size numbers above describe a slightly larger binary than the one
  measured.

## Amended 2026-10-28 (L4): an uninstrumented recovery path no longer reports success

Plan stage L4 named `gpu_recovery` / `recover` as "a known vacuous gate in this
repo". Scoped it against this route and it was worse than the note, in two places:

1. `RendererSession::new`'s `recover~` default returned `RecoverySucceeded`. The
   default is what a renderer gets if it does not decide, so the route that has no
   recovery path was one omission away from claiming one. **This decision is not
   Metal-scoped** — it lives in `moui/render`, and every concrete renderer already
   passed `recover~` explicitly (Skia/WGPU/Sun `FallbackToCpu`, TUI/Web success,
   Metal a named refusal), so the flip changes no live behaviour; it makes the next
   renderer's silence mean "no". Pinned A/B: with the old default,
   `a session with no recovery path refuses rather than claiming success` fails at
   the guard; with the refusal it passes.
2. The macOS GPU promotion harness's context-loss phase ended by setting
   `context_loss_done = context_loss_injected` and
   `recovered_within_vsyncs = wait_presents` **whether or not the renderer
   recovered**, and no route advances `gpu_recovery_count()` (Skia wires only
   `gpu_fallback_active`, so inject is a no-op and the count is a constant 0). Every
   promotion artifact's `diagnostics.recoveryCount` was therefore the number of
   losses *injected*. A loss now counts as done only when the counter moved, the
   summary line carries `context_loss_injected=` and `recovery_count_after=` beside
   `recovery_count_before=`, and the metrics overlay exposes `contextLossInjected`.
   Skia's recorded claim is unaffected because it rides `automatic_fallback`, set
   from the one wired signal (`gpu_fallback_active()`), and the derived
   `rasterFallback.automaticAfterRepeatedFailure` reads that flag first.

The host half has no automated test: the phase machine needs a real window, so its
proof is the emitted line, which is now self-describing (`context_loss_injected=3
context_loss_done=0 recovery_count_before=0 recovery_count_after=0` is legible as
"not instrumented" rather than as three clean recoveries).

What this route still does **not** implement, with the reason: a real Metal
device-loss rebuild. `RendererSession::recover` has no production caller — every
call site in the repo is a test (`moui/render/provider_binding_test.mbt`,
`moui_tests/renderer_contract/renderer_contract_test.mbt:180`,
`moui_tui_renderer/renderer_test.mbt:603`, and this module's own
tripwire) — so a rebuild path would answer a question nobody asks, and `MTLDevice
isRemoved` is never polled (a nil `nextDrawable` is already survived). The reopen
condition is specific: a host that calls `recover` in response to a real signal
(`isRemoved`, a surface recreate, a wake-from-sleep), at which point Metal's
`RecoveryFailed("metal direct has no gpu recovery path before plan stage L4")`
becomes the thing to replace, with the injection seam earning its extern the same
way every other seam on this route had to.

## Two toolchain facts this stage settled

- A package's `link.native.cc-link-flags` do **not** reach an is-main link:
  measured by injecting an invalid flag into `moui_text_providers/coretext` and
  watching `macos_wgpu` build anyway. The carrier is a prebuild `link_configs`
  entry (as `moui_skia/build.js:1059` already documents), which is why
  `moui_metal_renderer/build.js` exists and why the module's own `moon.pkg`
  carries no framework flags.
- The same gap was latent in the CoreText provider: its Apple frameworks were
  declared only in package `cc-link-flags`, and the symbols resolved solely
  because a platform backend also links the `ApplicationServices` umbrella, which
  re-exports CoreText. Any consumer that links CoreText without a backend would
  fail to link. `moui_text_providers/build.js` now emits those flags as
  `link_configs` on darwin, so the provider is self-sufficient.

## Consequences

- `docs/renderer-capability-report.md` and its zh-Hans mirror gain a fifth
  renderer column; `tools_product/moui/validate_renderer_capability_consistency`
  now checks 85 cells across five columns instead of 68 across four.
- `checks/profiles.json` gains two `host: "darwin"` steps in the `platform`
  profile. The module's tests cannot join `pr`/`daily`: they need a Metal device
  and Apple stubs, which is the same reason the text-provider and WGPU smoke
  packages stay outside the cross-platform profiles.
- The route now has a second renderer to keep honest in the capability report, so
  a future WGPU-side capability change and a Metal-side one are checked by the
  same validator.
- L2 is closed (all 26 `PlanOp` variants draw or count). What this section said
  then about L3 and L4 is superseded by the amendment below: the paragraph/hit-test
  layer is pinned in shared conformance, the 17 feature states are probed against the
  device (including a per-row consequence, not just ink), and the route presents in a
  real window under a committed smoke. The suspect wgpu `EmojiText` row is still the
  other module's to re-evidence, and the plan's note still stands: nothing on this
  route is a product claim until the matching-device evidence exists.


## Amended 2026-10-28 (late): where the route actually stands

Nine legs landed the same day, several of them after a claim in this ADR, the plan or
the module's own notes had been checked against the device rather than reread.

- **Text**: the glyph atlas is a lazily-grown, capped set of 1024×1024 pages rather
  than one fixed texture, so a frame denser than a page draws instead of dropping; the
  measured ceiling per page and the Retina case are printed by the smoke each run.
- **LayerCompositing**: `BeginRetainedLayer` boundaries are kept across frames on the
  pass target the host already pools per slot, with hit/rebuild/update/eviction
  records, and the "no cross-frame cache" sentence in this ADR is now history.
- **FilterEffect**: blur is separable with sigma = radius — the mainline's reading —
  and its samples spread `max(sigma/6, 1)` device pixels, so a larger radius really is a
  wider blur rather than a flatter weights over the same twelve pixels (measured: a
  sigma-16 edge went 255/122/0/0 to 212/119/32/10 against the ideal 214/128/40/17). Two
  open-ended-branch bugs surfaced building it, one of them pre-existing here.
  and its samples spread `max(sigma/6, 1)` pixels so a larger radius really is a wider
  blur. Two open-ended-branch bugs surfaced building it, one of them pre-existing here.
- **Shadow**: the fragment evaluates the Gaussian's own edge profile instead of a
  squared ramp over a grown box; measured before and after, because before it was a
  slab with a soft rim.
- **Evidence**: colour glyphs are read back at 24/32/48pt and through a layer
  composite, and the proof pass now takes a device scale, so Retina colour is a
  measurement rather than a disclaimer.
- **Gates**: a `Partial` note must name its missing half in a `Remaining:` sentence
  (a length check was passing rows that named nothing); each capability row must show
  a consequence only its own op produces; and
  `scripts/macos-metal-presentation-smoke.sh` presents a first frame in a real
  window, requiring the renderer's own identity line, the host's marker, and ink on the
  surface it presented: the host copies the drawable before presenting it and counts
  pixels differing from the clear colour, which a blank frame cannot pass.
- **AsyncImage / residency**: installed image textures are no longer unbounded while
  the window lives — each build enforces a resident-bytes budget, releasing the
  least-recently-used through `moui_metal_image_release` (the FFI surface goes 8 → 9,
  still inside the 10–40 estimate this plan priced) and reporting
  `image_textures_released`; a device test proves release is not disappearance.
- **Decisions recorded rather than implemented**: damage is not honoured (the present
  pass clears on load, so a damage rect would erase the rest); image textures are not
  yet bounded (eviction needs a lifecycle reset this module should not guess at);
  `Overlay` and stencil clipping stay shared work with `moui_wgpu_renderer`, which now
  *disagrees* with this route on the shadow and blur look and still describes the
  shared formulation.
- **Claims withdrawn from this ADR's own record**: a path- or texture-shaped shadow
  "casting its bounding box" (the command model cannot express one) and an async
  completion "unevidenced because no app installs a starter" (one app does — on the
  Skia route — and the deferred path covers remote sources only). Over-pessimistic
  rows cost the same trust as optimistic ones: one invents work, the other hides a
  gap, and both were caught by going to the type or the device.
