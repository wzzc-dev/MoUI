# wzzc-dev/moui_skia

MoonBit bindings for the Skia Graphics Library, structured after
`rust-skia/rust-skia`.

The public API is organized in the same spirit as `skia-safe`: start with safe
value-layer drawing types, opt into native handles through the `native`
subpackage, and treat resource planning/frame submission contracts as backend
integration APIs.

- Safe drawing values: geometry, colors, image metadata, transforms, paint,
  sampling, and portable paths are available directly from `@moui_skia`.
- Native drawing handles: `@native.Surface`, `@native.Canvas`, `@native.Image`,
  `@native.Path`, `@native.Font`, shaders, filters, and codecs are opt-in and
  return `None` on the fallback build instead of exposing unavailable handles.
- Backend planning contracts: `SurfaceTargetDescriptor`, `RenderCommandList`,
  `RenderFrameDescriptor`, `RendererResourcePlan`, and related descriptors are
  for GUI/runtime integrations that need replay, cache preflight, presentation,
  or future GPU admission checks.

The current package exposes the following value-layer API surface:

- geometry: `Point`, `IPoint`, `Size`, `ISize`, `Rect`, `IRect`, `RRect`,
  including point vector helpers, rectangle constructors, sortedness, centers,
  offsets, and integer rounding helpers
- color: `Color`, `Color4f`
- image metadata and pixel layout: `ColorInfo`, `ImageInfo`
- copied pixel snapshots: `Pixmap`
- transforms: `Matrix`, including member access, finite and affine queries,
  pre/post concat helpers, and point/vector/radius/rect mapping
- paint state: `Paint`, `PaintStyle`, `StrokeCap`, `StrokeJoin`, `BlendMode`
- canvas point drawing modes: `PointMode`
- image sampling: `SamplingOptions`, `FilterMode`, `MipmapMode`,
  `CubicResampler`
- surface contracts: `SurfaceDescriptor`, `SurfaceTargetDescriptor`,
  `SurfacePresentDescriptor`, `SurfaceFinalizationDescriptor`,
  `WindowSurfaceDescriptor`, `SurfaceBackend`, `SurfaceOrigin`, `SurfaceBudget`,
  `SurfacePresentMode`,
  `GpuContextBackend`, and `GpuContextDescriptor` for raster, window, and
  future GPU render targets, with stable window target identity plus typed
  resource descriptors for backend surface, present scheduling, finalization,
  and GPU context caches
- renderer resource cache: `ResourceCache` and `ResourceCacheStats` provide a
  deterministic byte-budgeted LRU boundary for images, shaders, typefaces, and
  other backend-owned resources, including cache preflight splits for resident
  and missing cacheable resource plans
- renderer resource identity: `RendererResourceKind`, `RendererResourceKey`,
  `RendererResourceDescriptor`, and `RendererResourcePlan` give those caches
  typed keys and auditable resource requirements for images, shaders, filters,
  text runs, paths, surfaces, and future GPU resources, including GPU-backed
  resource subplans for backend admission checks plus cacheable/uncacheable
  subplans for separating reusable handles from one-shot frame work
- shader and filter resource recipes: `ShaderDescriptor`,
  `ColorFilterDescriptor`, `ImageFilterDescriptor`, and `MaskFilterDescriptor`
  provide stable cache keys for native shader/filter handles before a backend
  allocates them
- render pass contracts: `RenderPassDescriptor`, `RenderPassLoadOp`, and
  `RenderPassStoreOp` define target bounds plus load/clear/store/present
  semantics before a concrete backend records draw commands, including defaults
  derived from `SurfaceTargetDescriptor` and resource descriptors for target
  surfaces
- render command contracts: `RenderCommandList`, `RenderCommand`, and
  `RenderCommandStats` provide the backend-neutral command stream boundary a GUI
  renderer can validate before replaying into a native Canvas, including
  current-clip color/paint and shader fills, rounded-rectangle and path clipping,
  cacheable text-run and shaped glyph-run draw commands, explicit
  shader/filter/image resource declarations, and target-bound resource plans
  for backend caches
- render frame contracts: `RenderFrameDescriptor`,
  `RenderFrameSubmissionDescriptor`, `RenderFrameFinalizationDescriptor`, and
  `RenderFrameValidationStatus` combine a target, finalized command stream,
  resource plan, readiness diagnostics, cache population boundary, optional
  present scheduling descriptor, and auditable per-frame submission/finalization
  resource plans with GPU-backed plus cacheable/uncacheable subsets for backend
  admission, cache staging, and resident/missing preflight
- text layout and fallback contracts: `TextRunDescriptor`,
  `TextMeasurementDescriptor`, `MeasuredTextRunDescriptor`,
  `TextShapingDescriptor`,
  `ShapedTextRunDescriptor`, `ShapedGlyphRunDescriptor`, `FontDescriptor`,
  `FontFallbackRequest`, `FontFallbackMatchDescriptor`,
  `FontFallbackResolutionDescriptor`, `FontFallbackChain`, and `FontStyleRequest`
  define the value-layer input and resolved-match metadata for native shaping
  and font fallback, including deterministic byte-range text-run,
  text-measurement, measured-result, text-shaping, shaped-result, detailed
  shaped-glyph, font, fallback request, fallback match, and fallback resolution
  resource keys, with invalid measured/shaped/fallback-request/result metadata
  kept uncacheable without downstream cache dependencies, and
  plans for backend measurement, shaping, font-handle, and typeface-resolution
  caches
- portable paths: `Path`, `PathLine`, `PathRect`, `PathVerb`, `PathFillType`,
  `PathDirection`, `PathSegmentMask`,
  including verb/point counts, contour closed queries, rectangle, oval, circle,
  rounded-rectangle and polyline/polygon contours, control-point and tight
  bounds, append/extend path modes, path appends, resource descriptors, `reset`,
  and `rewind`

Native Skia object handles are intentionally staged behind a separate FFI plan so
ownership, ref-counting, and linker configuration can be validated package by
package.

The `native` subpackage contains the first opt-in native boundary:

- `@native.skia_available()` reports whether the stub was compiled with real
  Skia headers and libraries;
- `@native.skia_shaper_available()` reports whether the SkShaper
  boundary was compiled and linked;
- `@native.skia_paragraph_available()` reports whether the
  SkParagraph boundary was compiled and linked; use
  `MOUI_SKIA_REQUIRE_SKPARAGRAPH=1` for smoke/proof runs that should fail when
  SkParagraph, SkShaper, SkUnicode, HarfBuzz, or ICU support is missing;
- `@native.Surface::raster_n32_premul(size)` is the first raster surface entry;
- `@native.Surface::gpu_context_support_status(context)` reports the native
  GPU-context readiness gate for a value-layer context descriptor. macOS Metal
  probing is opt-in with `MOUI_SKIA_ENABLE_GPU_METAL=1`; it checks the Skia
  Ganesh Metal headers plus real `GrDirectContext` creation;
- `@native.GpuContext::metal(context)` creates an explicit native Metal/Ganesh
  context when the opt-in readiness gate is available;
- `@native.Surface::gpu_n32_premul(context, descriptor)` and
  `@native.Surface::for_target_with_gpu_context(target, context)` allocate
  offscreen GPU-backed Skia surfaces for matching GPU target/context pairs;
- `@native.Surface::target_support_status(target)` reports whether a target can
  be allocated as a native surface, including empty, unavailable Skia,
  window-unsupported, and GPU-unsupported decisions;
- `@native.Surface::for_target(target)` allocates supported raster targets from
  value-layer `SurfaceTargetDescriptor` values. This default path remains
  raster-only; GPU targets must use the explicit target+context API;
- `@native.Surface::descriptor()` reports the value-layer surface contract
  satisfied by the native raster surface;
- `@native.Surface::image_snapshot()` returns an immutable `@native.Image`
  handle when a surface is available;
- `@native.Surface::image_snapshot_with_bounds(bounds)` snapshots a bounded
  surface rectangle and rejects rectangles outside the surface bounds;
- `@native.Surface::flush_and_submit()` establishes an explicit finalization
  boundary for native surfaces; raster surfaces treat it as a no-op, while
  GPU-backed surfaces flush through their owning direct context;
- `@native.Surface::render_frame(frame)` and `render_frame_with_resources(...)`
  return `SurfaceFrameReplayStats`, whose `status()` classifies validation,
  surface mismatch, replay skip, finalization failure, and complete outcomes;
  the stats also expose the value-layer frame finalization descriptor and
  resource plan used for the native flush/submit boundary;
- `@native.NativeReplayResources::stats()` reports aggregate cache slots,
  resident resources, byte budgets, hits, misses, and evictions across the
  native replay caches used by Canvas and Surface frame replay;
- `@native.Surface::read_pixels(bounds)` reads N32 premultiplied surface pixels
  into an owned `@moui_skia.Pixmap`, rejecting rectangles outside the surface
  bounds;
- `@native.Image::encode_to_data(format, quality)` returns immutable
  `@native.Data` bytes for PNG/JPEG output, with WEBP enabled only when the
  linked native Skia build exposes the encoder capability, rejecting unsupported
  native encode formats and clamping quality to Skia's `0..100` range;
- `@native.Image::from_bitmap(bitmap)` snapshots a native bitmap into an
  immutable image;
- `@native.Data::from_bytes(bytes)` and `@native.Image::from_encoded_bytes(bytes)`
  provide the first in-memory image decode path;
- `@native.Codec::from_data(data)` and `@native.Codec::from_bytes(bytes)` expose
  encoded image metadata and decode to an N32 premultiplied `Bitmap`;
- `@native.Bitmap::alloc_n32_premul(size)` owns raster pixel storage and can
  export a copied `@moui_skia.Pixmap`;
- `@native.FontMgr::default()` enumerates native font families and matches a
  family plus Skia-style weight/width/slant values to a typeface;
  `@native.Typeface::default()` / `from_name(family, weight, width, slant)` and
  `@native.Font::default(size)` / `from_typeface(typeface, size)` create the
  first native text handles for drawing and measurement; native typefaces can
  report their Skia family name; native font sizes, shaping widths, and glyph
  position origins are finite-checked before crossing into Skia;
  `FontStyleRequest` and `FontFallbackRequest`
  can be passed through the native FontMgr/Typeface adapters, including Skia
  character fallback when the request includes BCP47 language tags and a code
  point, then recorded with `FontFallbackMatchDescriptor` metadata for cache
  planning;
- `@native.Shader::color(color)`, `linear_gradient(start, end, colors...)`,
  and `radial_gradient(center, radius, colors...)` create the first native
  shader handles for shader-backed paint calls, with degenerate
  linear-gradient inputs plus non-finite linear/radial-gradient geometry
  rejected before native replay/resource planning;
- `@native.ColorFilter`, `ImageFilter`, and `MaskFilter` reject non-finite
  parameters before native handle creation and value-layer resource planning,
  with native FFI stubs also nulling non-finite matrix/sigma inputs;
- direct invalid shader/filter descriptor variants produce uncacheable resource
  descriptors, preserving cache safety even when constructors are bypassed;
- native replay skips invalid shader/filter descriptor commands without
  touching or populating shader, color-filter, image-filter, or mask-filter
  caches;
- native replay skips undecodable or empty encoded image draw commands without
  touching or populating image caches;
- native replay keeps empty path draw, clip, and path-shader commands out of
  path cache lookups, with zero path-cache resources/misses/hits while still
  replaying harmless empty native paths;
- non-finite value-layer paths produce uncacheable resource descriptors, are
  filtered out of command-list resource plans, and skip native replay without
  touching path caches;
- native path appends skip non-finite portable paths or matrices without
  mutating existing `@native.Path` geometry;
- direct native path verb, shape, transform, and offset mutations skip
  non-finite inputs without mutating existing `@native.Path` geometry;
- `@native.Path` supports the first path construction calls: `new`, `reset`,
  `rewind`,
  `set_fill_type`, `fill_type`, `move_to`, `line_to`, `quad_to`, `cubic_to`,
  `conic_to`, `close`, `count_points`, `count_verbs`,
  `segment_masks`, `is_finite`, `is_inverse_fill_type`,
  `is_last_contour_closed`, `last_point`, `is_line`, `is_rect`, `is_oval`,
  `contains`, `bounds`, `compute_tight_bounds`, `add_path_value`, `add_poly`,
  `add_rect`, `add_oval`, `add_circle`, `add_round_rect`, `add_rrect`,
  `transform`, `offset`, and `is_empty`;
- `@native.Path::from_value(path)` replays a finite portable `@moui_skia.Path`
  into a native path when Skia is linked and rejects non-finite paths;
- `@native.Canvas` supports `clear`, `draw_color`, `draw_paint`,
  `draw_point`, `draw_line`, `draw_points`, `draw_rect`, `draw_oval`, `draw_circle`,
  `draw_arc`, `draw_round_rect`, `draw_rrect`, `draw_drrect`, `draw_path`,
  `draw_image`, and `draw_image_rect` with explicit `SamplingOptions`, plus
  portable path drawing through `draw_path_value`, render command replay through
  `replay` with `CanvasReplayStats::status()` diagnostics that distinguish
  complete Canvas work, deferred surface present commands, and skipped replay
  commands, plus command/resource category counters for declarations, images,
  shaders, filters, paths, and text resources, UTF-8 text through
  `draw_text_utf8`, text-run replay that honors descriptor byte ranges and
  skips empty ranges without populating text caches, positioned glyph runs
  through `draw_glyphs`, invalid shaped glyph replay skips without cacheable
  dependency planning, optional
  shaped glyph runs through `Font::shape_text_utf8` when SkShaper is linked,
  shaped-run metadata through `TextShapingDescriptor` and
  `ShapedTextRunDescriptor`, detailed shaped glyph-run metadata through
  `ShapedGlyphRunDescriptor`,
  optional paragraph layout through `Paragraph::layout_utf8` with line metrics,
  UTF-8 range text boxes, and UTF-8 hit-test offsets when SkParagraph is linked,
  font measurement through `Font::measure_text_utf8`, glyph IDs through
  `Font::count_text_utf8` / `Font::text_to_glyphs_utf8`, glyph advances through
  `Font::glyph_width` / `Font::glyph_widths`, glyph positions through
  `Font::glyph_positions` / `Font::glyph_x_positions` and
  `Font::text_glyph_positions_utf8` / `Font::text_glyph_x_positions_utf8`, glyph bounds through
  `Font::glyph_bounds` / `Font::glyph_bounds_many`, text bounds through
  `Font::measure_text_bounds_utf8`, font metrics through `Font::metrics`, and
  color-shader paint through `draw_paint_shader` / `draw_rect_shader`;
- direct Canvas geometry, clip, image placement, and text/glyph positioning
  calls skip non-finite coordinates without mutating pixels;
- native Canvas paint forwarding sanitizes non-finite stroke scalars, and
  `save_layer` treats non-finite bounds as an unbounded layer;
- native Canvas image sampling disables cubic resampling when cubic
  coefficients are non-finite, preserving the image draw with ordinary
  filter/mipmap sampling;
- `@native.Canvas` also exposes the first state and transform calls:
  `save`, `save_layer`, `restore`, `restore_to_count`, `save_count`,
  `translate`, `scale`, `rotate`, `skew`, `concat`, `reset_matrix`, and
  `discard`;
- `@native.Canvas` exposes clipping with `clip_rect`, `clip_rrect`, and
  `clip_path` using `ClipOp`, local/device clip bound queries, and
  rect/path quick rejection;
- without Skia link flags it compiles as a safe fallback and returns `None`.

## Native smoke test

The regular test suite keeps the no-Skia fallback build green by skipping the
real-backend-only assertions. A real native Skia build should additionally pass
the dedicated smoke test:

The fallback gate also verifies that each target-specific native MoonBit file
has an unavailable fallback twin in `native/moon.pkg`, so new native bindings do
not accidentally compile only on the linked Skia path. CI also runs
`moon check --target all` to keep the wasm/js fallback and native/LLVM target
maps compileable together.

```text
cd scripts/native_smoke
moon run --target native .
```

The smoke module is intentionally separate from the default test suite. Without
real Skia link flags it fails fast instead of silently exercising the fallback.

For the fallback-only validation gate, run:

```powershell
.\scripts\check-fallback.ps1
```

That script formats/checks the root module, runs `moon info`, runs the default
tests, and builds the native smoke module without real Skia link flags so the
smoke entry stays compileable while remaining opt-in at runtime.

The GitHub Actions fallback workflow mirrors this gate on Windows and Linux.
Real Skia smoke tests are intentionally separate until the repository owns a
repeatable Skia binary/build source for CI.

The optional shaped-text boundary is off by default so small Skia builds remain
usable. On macOS, pass `--enable-skshaper` to `scripts/macos-skia-smoke.sh`
when the Skia library directory also contains `libskshaper`, `libskunicode_core`,
`libskunicode_icu`, `libharfbuzz`, and `libicu`. The wrapper adds
`-DMOUI_SKIA_HAS_SKSHAPER`, links those module libraries, and verifies the native
smoke log contains the shaped-run marker.

The default real-Skia binary provider is now the `wzzc-dev/skia` GitHub release
locked by `skia-provider-lock.json` to tag `dev-6d73578a36` and commit
`6d73578a36506d10bc044e920cc71037982e481d`. The fetch helpers cache packages
under `.skia-cache/release` and print the include/lib/flag values consumed by
the existing native package configurators. The default link mode is static;
dynamic libraries are selected explicitly with
`MOUI_SKIA_LINK_MODE=dynamic` or `--link-mode dynamic`:

```bash
bash scripts/fetch-release-skia.sh --platform auto --arch auto --print-env
```

```powershell
.\scripts\fetch-release-skia.ps1 -Platform auto -Arch auto -PrintEnv
```

Use [REAL_SKIA_SMOKE.md](REAL_SKIA_SMOKE.md) as the acceptance checklist for
real-backend artifacts. A passing fallback build, dry-run, or syntax check is
not enough to claim real Skia acceptance.

The smoke test requires `@native.skia_available()` to be true. It creates a
32x32 raster N32 premul surface, clears it to white, draws red, green,
and blue rectangles, exercises `draw_points` in point, line, and polygon modes,
draws a positioned glyph run,
checks canvas save/restore state, clip bounds, quick rejection, and clipped
drawing, reads pixels back, checks representative BGRA N32 pixels,
snapshots the
surface, encodes the snapshot as PNG, verifies the encoded PNG signature,
decodes those bytes back into an image, and decodes an N32 bitmap whose pixels
still match the drawn scene and N32 channel layout.

On Windows with a MinGW-compatible Skia build, use the acceptance wrapper to
temporarily inject the native link flags, run the smoke test, save logs, and
verify the temporary package rewrites were restored afterwards:

```powershell
.\scripts\windows-accept-real-skia-smoke.ps1 -LogDir logs `
  -SkiaInclude C:\path\to\skia `
  -SkiaLibDir C:\path\to\skia\out\Static
```

Pass `-ExtraCcFlags` or `-ExtraLinkFlags` if your Skia build needs additional
defines or dependent libraries. The helper checks that the Skia headers and a
MinGW-compatible `libskia.a` or `skia.lib` are present before rewriting package
configuration. The `Windows Real Skia Smoke` workflow exposes the same helper as
a manual job for runners that already have such a Skia build available.

On Linux, use the acceptance wrapper. With an existing Skia build visible to the
system compiler, pass its include and library paths:

```bash
bash scripts/linux-accept-real-skia-smoke.sh --log-dir logs \
  --skia-provider existing \
  --skia-include /path/to/skia \
  --skia-lib-dir /path/to/skia/out/Static
```

Pass `--extra-cc-flags` or `--extra-link-flags` for Skia builds that need
additional defines, rpaths, or dependent libraries. Add `--dry-run-config` to
print the selected mode and effective build/smoke arguments without fetching or
building Skia or rewriting `native/moon.pkg`; in source-build mode it prints the
resolved checkout/build paths and GN args, and with existing Skia paths it also
checks for the Skia header and library files and prints the exact native flags
that would be injected. When `libskia.so` is used, the Linux smoke helper adds
the supplied library directory to `LD_LIBRARY_PATH` before running the smoke
executable. Pass `--smoke-log logs/linux-native-smoke-output.log` to keep the
native smoke executable's stdout/stderr separate from the wrapper log.

On macOS with an existing Skia build, use the acceptance wrapper:

```bash
bash scripts/macos-accept-real-skia-smoke.sh --log-dir logs \
  --skia-provider existing \
  --skia-include /path/to/skia \
  --skia-lib-dir /path/to/skia/out/Static
```

The macOS helper adds common CoreFoundation/CoreGraphics/CoreText/ImageIO
frameworks by default; pass `--extra-link-flags` for additional Skia build
dependencies. Use `--link-mode dynamic|static` or
`MOUI_SKIA_LINK_MODE=dynamic|static` when you need to force
`libskia.dylib` or `libskia.a`; `auto` chooses the mode based on available
library files.

The package prebuild hook now enables native real-Skia configuration by
default for native builds. Set `MOUI_SKIA_ENABLE_PREBUILD_SKIA=0` or
`MOUI_SKIA_DISABLE_PREBUILD_SKIA=1` when you need the fallback-unavailable
compile path. Environment values for `MOUI_SKIA_SKIA_INCLUDE`,
`MOUI_SKIA_SKIA_LIB_DIR`, `MOUI_SKIA_SKIA_LIB`,
`MOUI_SKIA_EXTRA_CC_FLAGS`, `MOUI_SKIA_EXTRA_LINK_FLAGS`, and
`MOUI_SKIA_LINK_MODE` take precedence over the release provider defaults.

To build a small CPU-only Skia from source for the macOS smoke test, run:

```bash
bash scripts/macos-accept-real-skia-smoke.sh --log-dir logs \
  --skia-provider source \
  --work-dir .skia-cache/macos
```

The `macOS Real Skia Smoke` workflow exposes the same path as a manual GitHub
Actions job.

To build a small CPU-only Skia from source and run the Linux smoke test in one
locally with acceptance checks, run:

```bash
bash scripts/install-linux-smoke-deps.sh
bash scripts/linux-accept-real-skia-smoke.sh --work-dir .skia-cache/linux
```

On an already prepared Ubuntu runner,
`bash scripts/install-linux-smoke-deps.sh --check` verifies the same apt package
set that the workflow installs before spending time on native smoke work. This
includes `libwayland-dev`, `libwayland-bin`, and `wayland-protocols`, which
`wzzc-dev/window` needs while preparing the native smoke dependency graph and
generating the xdg-shell client header. The Linux source-build defaults install
`clang` plus fontconfig/FreeType/HarfBuzz development headers and pass
`cc="clang"` / `cxx="clang++"` to Skia GN so the smoke build does not depend on
the runner's default C++ compiler.

When `--skia-rev` is omitted, the Linux source-build helpers read
`skia-revision.txt`. Keep that file on a known-good Skia commit after the first
successful real runner, or override it with `--skia-rev` while testing a new
Skia revision. The acceptance summary log records the resolved `skia_commit`;
use the guarded pin helpers below to write that value after a passing
source-built run. Do not write release-provider commits into
`skia-revision.txt`; they are tracked in `skia-provider-lock.json`.

For the first source-built Linux acceptance, the guarded pinning wrapper runs
the smoke, verifies the artifact bundle with a required full commit hash, pins
`skia-revision.txt`, and verifies the pin:

```bash
bash scripts/linux-accept-and-pin-skia.sh --work-dir .skia-cache/linux
```

It rejects dry runs and existing-build Skia paths so only a real source-built
Linux acceptance can establish the initial repository pin. It checks Ubuntu
smoke dependencies before starting the expensive build; pass `--install-deps` to
install them first, or `--skip-deps-check` for a runner managed elsewhere.

Without `--skia-include` / `--skia-lib-dir`, the acceptance wrapper checks out
and builds Skia through `scripts/linux-real-skia-smoke.sh`, captures wrapper and
native executable logs, verifies `native/moon.pkg` was restored, and checks that
the executable prints
`moui_skia native smoke test passed`, proving the real smoke reached its final
assertion. The `Linux Real Skia Smoke` workflow uses the same acceptance wrapper
for real runs; its optional inputs can either build Skia from `skia_rev` or
reuse an existing `skia_include` / `skia_lib_dir` pair with extra compile/link
flags. It also runs weekly as an expensive real-backend canary.
The workflow runs a dry-run preflight before installing build dependencies or
compiling Skia, then uploads the preflight log, `logs/linux-skia-build.log` for
source-built runs, wrapper log, and dedicated native executable log, plus the
acceptance summary log, as a `linux-real-skia-smoke-log` artifact on success or
failure. On real runs, it also greps `logs/linux-native-smoke-output.log` for
`moui_skia native smoke test passed` and records the marker check in the workflow
summary. The same artifact check can be rerun manually with
`scripts/verify-native-smoke-log.sh logs/linux-native-smoke-output.log`. The
summary records the selected mode, dry-run setting, artifact name, key Skia
inputs, expected log paths, the marker check, plus whether
the temporary package rewrites were restored after the run.
Set the workflow's `dry_run_config` input to print the
resolved build/smoke arguments without installing MoonBit/build dependencies,
building Skia, restoring the Skia cache, or rewriting package files; with
existing Skia paths it also checks for the Skia header and library files. The
workflow only restores the Skia source-build cache when it is building Skia from
source; `extra_gn_args` is ignored for existing builds.

```mbt check
///|
test {
  let point = @moui_skia.Point::new(3, 4)
  let rect = @moui_skia.Rect::from_point_and_size(
    @moui_skia.Point::new(2, 3),
    @moui_skia.Size::new(4, 5),
  )
  let sorted = @moui_skia.Rect::new(5, 4, 1, 2).sorted()
  let fractional = @moui_skia.Rect::new(1.2, -2.8, 5.7, 3.1)
  let wide = @moui_skia.IRect::new(-2000000000, 0, 2000000000, 1)

  assert_true(point.is_finite())
  assert_eq(point.length_squared(), 25.0)
  assert_eq(point.dot(@moui_skia.Point::new(-2, 5)), 14.0)
  assert_eq(point.cross(@moui_skia.Point::new(-2, 5)), 23.0)
  assert_true(point.with_length(10) == Some(@moui_skia.Point::new(6, 8)))
  assert_true(point.rotate_cw() == @moui_skia.Point::new(4, -3))
  assert_true(rect == @moui_skia.Rect::from_ltrb(2, 3, 6, 8))
  assert_eq(rect.left(), 2.0)
  assert_eq(rect.bottom(), 8.0)
  assert_true(rect.tl() == @moui_skia.Point::new(2, 3))
  assert_true(rect.intersects(@moui_skia.Rect::from_xywh(5, 7, 3, 3)))
  assert_true(
    @moui_skia.Rect::from_points([point, @moui_skia.Point::new(8, -1)]) ==
    Some(@moui_skia.Rect::new(3, -1, 8, 4)),
  )
  assert_true(
    rect.to_quad() ==
    [
      @moui_skia.Point::new(2, 3),
      @moui_skia.Point::new(6, 3),
      @moui_skia.Point::new(6, 8),
      @moui_skia.Point::new(2, 8),
    ],
  )
  assert_true(
    rect.with_offset_to(@moui_skia.Point::new(10, -1)) ==
    @moui_skia.Rect::from_xywh(10, -1, 4, 5),
  )
  assert_true(sorted.is_sorted())
  assert_true(sorted.center() == @moui_skia.Point::new(3, 3))
  assert_eq(wide.width_64(), 4000000000L)
  assert_true(!wide.is_empty_64())
  assert_true(fractional.round_in() == @moui_skia.IRect::new(2, -2, 5, 3))
  assert_true(fractional.round_out() == @moui_skia.IRect::new(1, -3, 6, 4))
}
```

```mbt check
///|
test {
  let info = @moui_skia.ImageInfo::n32_premul(@moui_skia.ISize::new(1, 1))
  let pixmap = @moui_skia.Pixmap::new(info, 4, b"\xff\x00\x00\xff")

  assert_true(pixmap is Some(_))
  assert_eq(info.shift_per_pixel(), 2)
  assert_eq(info.compute_min_byte_size64(), 4L)
}
```

```mbt check
///|
test {
  let paint = @moui_skia.Paint::new(
      color=@moui_skia.Color::from_rgb(0xff, 0, 0),
      anti_alias=true,
    )
    .set_stroke(true)
    .set_stroke_width(4)
  let path = @moui_skia.Path::new().add_rect(
    @moui_skia.Rect::from_xywh(0, 0, 8, 8),
  )

  assert_true(paint.style == Stroke)
  assert_true(paint.color == @moui_skia.Color::red())
  assert_true(
    path.stroke_bounds(paint) == Some(@moui_skia.Rect::new(-2, -2, 10, 10)),
  )
}
```

```mbt check
///|
test {
  let sampling = @moui_skia.SamplingOptions::new(filter=Linear, mipmap=Linear)

  assert_eq(sampling.filter_ordinal(), 1)
  assert_eq(sampling.mipmap_ordinal(), 2)
  assert_true(!sampling.uses_cubic())
}
```

```mbt check
///|
test {
  let matrix = @moui_skia.Matrix::translate(10, 20).concat(
    @moui_skia.Matrix::scale(2, 3),
  )
  let rect = matrix.map_rect(@moui_skia.Rect::from_xywh(0, 0, 4, 5))
  let points = @moui_skia.Matrix::translate(1, 2).map_points([
    @moui_skia.Point::new(0, 0),
    @moui_skia.Point::new(3, 4),
  ])

  assert_true(matrix.is_invertible())
  assert_true(rect == @moui_skia.Rect::from_xywh(10, 20, 8, 15))
  assert_true(
    points == [@moui_skia.Point::new(1, 2), @moui_skia.Point::new(4, 6)],
  )
}
```

```mbt check
///|
test {
  let path = @moui_skia.Path::new(fill_type=EvenOdd).add_circle(
    @moui_skia.Point::new(5, 5),
    5,
    direction=CCW,
  )

  let shifted = path.offset(10, 20)

  assert_eq(path.verb_count(), 6)
  assert_true(path.fill_type == EvenOdd)
  assert_true(
    shifted.bounds() == Some(@moui_skia.Rect::from_xywh(10, 20, 10, 10)),
  )
}
```

```mbt check
///|
test {
  let triangle = @moui_skia.Path::new().add_poly(
    [
      @moui_skia.Point::new(0, 0),
      @moui_skia.Point::new(10, 0),
      @moui_skia.Point::new(10, 10),
    ],
    close=true,
  )

  assert_true(triangle.is_last_contour_closed())
  assert_eq(triangle.count_points(), 3)
  assert_true(
    triangle.bounds() == Some(@moui_skia.Rect::from_xywh(0, 0, 10, 10)),
  )
}
```

```mbt check
///|
test {
  let base = @moui_skia.Path::new().add_rect(
    @moui_skia.Rect::from_xywh(0, 0, 2, 2),
  )
  let triangle = @moui_skia.Path::new().add_poly(
    [
      @moui_skia.Point::new(0, 0),
      @moui_skia.Point::new(10, 0),
      @moui_skia.Point::new(10, 10),
    ],
    close=true,
  )

  let combined = base.add_path(
    triangle,
    matrix=@moui_skia.Matrix::translate(10, 0),
  )
  let shifted = base.add_path_offset(triangle, @moui_skia.Point::new(10, 0))

  assert_eq(combined.count_verbs(), 9)
  assert_true(combined.bounds() == Some(@moui_skia.Rect::new(0, 0, 20, 10)))
  assert_true(shifted == combined)
}
```

```mbt check
///|
test {
  let rrect = @moui_skia.RRect::new(
    @moui_skia.Rect::from_xywh(0, 0, 10, 8),
    @moui_skia.Size::new(2, 2),
    @moui_skia.Size::new(3, 1),
    @moui_skia.Size::new(1, 2),
    @moui_skia.Size::empty(),
  )
  let path = @moui_skia.Path::new().add_rrect(rrect)

  assert_true(!rrect.is_rect())
  assert_true(
    rrect.with_offset_to(@moui_skia.Point::new(10, 20)).bounds() ==
    @moui_skia.Rect::from_xywh(10, 20, 10, 8),
  )
  assert_true(rrect.contains_rect(@moui_skia.Rect::from_xywh(3, 3, 4, 2)))
  assert_eq(path.verb_count(), 10)
  assert_true(path.bounds() == Some(rrect.bounds()))
}
```
