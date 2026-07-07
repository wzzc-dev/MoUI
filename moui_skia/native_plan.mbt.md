# Native Skia Binding Plan

This package currently provides the value-layer API that mirrors the most common
`skia_safe` types from rust-skia: geometry with point vector helpers, rectangle
constructors, sorting, centers, offsets, and rounding helpers, colors, matrices
with member access, affine helpers, pre/post concat helpers, and point/vector/
radius/rect mapping, paint flags, and paint state.

The native layer is staged in the `native` subpackage. It currently exposes a
safe fallback build that compiles without Skia and reports unavailable. Real Skia
support is enabled by compiling the C++ stub with `MOUI_SKIA_HAS_SKIA`, Skia
headers, and Skia linker flags.

The MoonBit side follows this shape:

```mbt nocheck
///|
#external
type NativeSurface

///|
#borrow(surface)
extern "c" fn skia_surface_width(surface : NativeSurface) -> Int = "moonbit_skia_surface_width"
```

Minimal raster-surface milestone:

- expose `NativeSurface`, `NativeCanvas`, and `NativePaint` as opaque handles;
- wrap `SkSurfaces::Raster`, `SkSurface::getCanvas`, `SkSurface::width`, and
  `SkSurface::height`;
- add draw calls only after `Paint` and geometry conversion functions are tested;
- keep the value-layer `ImageInfo` as the public constructor argument and convert
  it to `SkImageInfo` inside the C++ stub.

Current implemented milestone:

- `NativeSurface` / `NativeCanvas` opaque handles;
- `NativeData` opaque handle for immutable encoded bytes;
- `NativeImage` opaque handle from `Surface::image_snapshot`;
- `NativePath` opaque handle with path construction calls;
- `NativeGpuContext` opaque handle for opt-in Metal/Ganesh GPU contexts;
- `skia_available`;
- raster N32 premul surface constructor API;
- surface width, height, dimensions, image info, and canvas borrow;
- opt-in macOS Metal GPU context support diagnostics that create a real Ganesh
  `GrDirectContext`, plus offscreen GPU-backed N32 premul surface allocation,
  target/context admission checks, and GPU flush/submit;
- immutable full-surface and bounded image snapshots with width, height,
  dimensions, and image info;
- reading surface pixels into copied value-layer `Pixmap` snapshots;
- image encoding to `Data`, data size inspection, and copying data into
  MoonBit `Bytes`;
- snapshotting native `Bitmap` pixels into immutable `Image` handles;
- copying MoonBit `Bytes` into `Data` and decoding encoded image data into
  `Image`;
- native `Codec` construction from `Data`/`Bytes`, encoded format inspection,
  and N32 premultiplied bitmap decode;
- native `Bitmap` allocation for N32 premultiplied pixels, color erase, pixel
  byte export, and copied value-layer `Pixmap` snapshots;
- native `Typeface` and `Font` handles, including font construction from
  typeface, and UTF-8 text drawing through `Canvas::draw_text_utf8`;
- native `Shader` handles with color, two-stop linear gradient, and two-stop
  radial gradient constructors, plus shader-backed canvas paint/rect drawing;
- portable value-layer `Path` with fill type, direction, line/quad/conic/cubic
  verb data, rectangle/oval/circle/round-rectangle contour construction,
  verb/point counts, segment masks, finite-coordinate checks, contour closed
  queries, per-corner `RRect` geometry, and `reset`/`rewind`, control-point
  bounds, curve-aware tight bounds, paint-aware stroke bounds, transform,
  offset, `add_poly`, `add_path`, add-path append/extend modes, and
  offset/matrix add-path helpers, plus native replay/querying through
  `Path::from_value`, native `Path` shape builders including round-rectangle
  contours, native `Path::transform` /
  `Path::offset`, `Path::contains`, `Path::segment_masks`, `Path::is_finite`,
  `Path::is_inverse_fill_type`, `Path::last_point`, `Path::is_line`,
  `Path::is_rect`, `Path::is_oval`, `Path::bounds`,
  `Path::compute_tight_bounds`, native `Path::add_poly`, native
  `Path::add_path_value`, native value-path offset/matrix append helpers, and
  `Canvas::draw_path_value`;
- canvas state and transform calls: `save`, `save_layer`, `restore`,
  `restore_to_count`, `save_count`, `translate`, `scale`, `rotate`, `skew`,
  `concat`, `reset_matrix`, and `discard`;
- canvas clipping with rect/rrect/path geometry, `ClipOp`, clip-bound queries,
  and rect/path quick rejection;
- canvas `clear`, `draw_color`, `draw_paint`, `draw_point`, `draw_line`,
  `draw_points` with Skia-compatible `PointMode`,
  `draw_rect`, `draw_oval`, `draw_circle`, `draw_arc`, and
  `draw_round_rect` / `draw_rrect` / `draw_drrect`, plus `draw_path`,
  `draw_image`, and `draw_image_rect` with `SamplingOptions`;
- value-layer sampling controls: `FilterMode`, `MipmapMode`,
  `CubicResampler`, and `SamplingOptions`;
- primitive paint conversion for color, anti-aliasing, dither, style, stroke
  width, stroke miter, stroke cap, stroke join, and blend mode;
- value-layer `SurfaceDescriptor` contracts for raster, window, and future GPU
  surfaces, with native raster/GPU surfaces reporting the descriptor they
  satisfy;
- value-layer `ResourceCache` contracts for byte-budgeted LRU resource reuse
  and renderer-cache hit/miss/eviction accounting without taking native handle
  ownership;
- fallback C++ stub path for environments without Skia.
- `scripts/native_smoke` real-backend smoke executable that forces
  `skia_available()`, draws red/green/blue rectangles to a raster surface,
  exercises `draw_points` point/line/polygon modes, checks representative N32
  pixels, verifies canvas save/restore state, clip bounds, quick rejection, and
  clipped drawing, snapshots, PNG-encodes, checks the encoded
  PNG signature, decodes the bytes back into an image, and decodes an N32
  bitmap whose pixels still match;
- `scripts/windows-skia-smoke.ps1` helper that temporarily adds Windows
  MinGW-style Skia include/link flags and runs the native smoke executable;
- `scripts/windows-accept-real-skia-smoke.ps1` acceptance wrapper that captures
  wrapper/native/acceptance logs, verifies the smoke marker, and checks package
  restoration for existing Windows Skia builds;
- `scripts/linux-skia-smoke.sh` helper that does the same for a Unix-like Skia
  build and executes the produced native smoke binary.
- `scripts/linux-accept-real-skia-smoke.sh` acceptance wrapper that captures
  Linux wrapper/native/acceptance logs, verifies the smoke marker, checks
  package restoration, and reports the resolved Skia commit;
- `scripts/macos-skia-smoke.sh` helper for an existing macOS Skia build with
  common CoreFoundation/CoreGraphics/CoreText/ImageIO framework links.
- `scripts/macos-accept-real-skia-smoke.sh` acceptance wrapper that captures
  macOS wrapper/native/acceptance logs, verifies the smoke marker, and checks
  package restoration;
- `scripts/macos-build-skia.sh` helper that checks out depot_tools/Skia and
  builds a small CPU-only static Skia for the macOS smoke test.
- `scripts/linux-build-skia.sh` helper that checks out depot_tools/Skia and
  builds a small CPU-only static Skia for the Linux smoke test.
- `scripts/linux-real-skia-smoke.sh` one-step Linux helper that builds Skia,
  temporarily links `native/moon.pkg`, and runs the real native smoke
  executable.
- `scripts/check-fallback.ps1` helper for the fallback CI gate: format/check,
  update interface metadata, run default tests, and compile the native smoke
  module without requiring linked Skia, plus Windows fake-Skia dry-run checks
  for the existing-build smoke helper and acceptance-wrapper misuse guard.
- `REAL_SKIA_SMOKE.md` acceptance runbook that defines which logs and marker
  fields prove a real Skia smoke pass and which dry-run/fallback checks do not.

Implementation notes:

- Keep extern declarations private and expose safe MoonBit wrappers.
- Use `#borrow` on call-scoped handles and `#owned` only when C++ stores a
  MoonBit-managed object.
- Wrap ref-counted Skia objects in C stubs that call the matching `ref` and
  `unref` APIs.
- Use `moonbit_make_external_object` for owning handles whose finalizer calls
  Skia `unref` or `delete`.
- Keep Skia build discovery outside MoonBit source files; configure it through
  `moon.pkg` `native-stub` and native linker flags.

To link real Skia, update `native/moon.pkg` with native flags similar to:

```moonbit nocheck
options(
  "native-stub": [
    "skia_stub_common.cpp",
    "skia_stub_surface_image_data.cpp",
    "skia_stub_canvas.cpp",
    "skia_stub_path.cpp",
    "skia_stub_text_font.cpp",
    "skia_stub_shader_filter.cpp",
  ],
  link: {
    "native": {
      "stub-cc-flags": "-DMOUI_SKIA_HAS_SKIA -I/path/to/skia",
      "cc-link-flags": "-L/path/to/skia/out/Static -lskia",
    },
  },
)
```

The exact flags are platform- and Skia-build-dependent. On Windows with GCC,
MinGW-compatible Skia libraries are required; MSVC `.lib` files are not directly
compatible with `g++`.

Windows acceptance helper for an existing MinGW-compatible Skia build:

```powershell
.\scripts\windows-accept-real-skia-smoke.ps1 -LogDir logs `
  -SkiaInclude C:\path\to\skia `
  -SkiaLibDir C:\path\to\skia\out\Static
```

The acceptance wrapper calls the lower-level smoke helper, captures
`windows-real-skia-smoke.log`, `windows-native-smoke-output.log`, and
`windows-real-skia-acceptance.log`, verifies the final
`moui_skia native smoke test passed` marker, and checks that `native/moon.pkg`
was restored. The lower-level helper rewrites `native/moon.pkg` only for the
duration of the run, adding `MOUI_SKIA_HAS_SKIA`, the supplied include directory,
and `-L... -lskia`. It restores the original file in a `finally` block, then
runs:

```text
cd scripts/native_smoke
moon build --target native
_build/native/debug/build/moui_skia_native_smoke.exe
```

The lower-level helper executes the generated `.exe` directly so the process
exit code is preserved.

Use `-SkiaLib`, `-ExtraCcFlags`, and `-ExtraLinkFlags` for non-default library
names or extra Skia dependencies.

The Windows smoke helper verifies `include/core/SkSurface.h` and a
MinGW-compatible `libskia.a` or `skia.lib` before rewriting package
configuration, and prepends the Skia library directory to `PATH` before running
the executable. MSVC-only `.lib` files may still fail at link time because
MoonBit's native stub path uses the GCC/MinGW toolchain today. Use
`scripts/windows-skia-smoke.ps1 -DryRunConfig` for preflight; the acceptance
wrapper intentionally rejects dry-run mode.

Linux one-step real-Skia smoke helper:

```bash
# Build Skia from source, link it, run smoke, and verify logs/restore state.
bash scripts/linux-accept-real-skia-smoke.sh --work-dir .skia-cache/linux

# Or reuse an existing Skia checkout/build.
bash scripts/linux-accept-real-skia-smoke.sh \
  --skia-include /path/to/skia \
  --skia-lib-dir /path/to/skia/out/Static
```

Without existing Skia paths, the wrapper fetches depot_tools and Skia through
`scripts/linux-build-skia.sh`, runs `tools/git-sync-deps`, uses `gn gen` and
`ninja -C ... skia` with a CPU-only static-library configuration, then calls
`scripts/linux-skia-smoke.sh` to temporarily link `native/moon.pkg` and execute
the produced native smoke binary. The wrapper prints its selected mode,
effective include/lib paths, library name, and extra flags before linking so CI
failures are diagnosable; the lower-level helper also logs package backup,
temporary rewrite, and restore events. It verifies that the executable prints
`moui_skia native smoke test passed`, so a successful Linux run proves the smoke
reached its final assertion. Pass `--smoke-log` to keep the native smoke
executable's stdout/stderr as a dedicated artifact-friendly log. This is
intended as the first Linux CI path, not as the final cross-platform Skia
distribution story.

The acceptance wrapper `scripts/linux-accept-real-skia-smoke.sh` sits above the
one-step helper for local validation. It captures wrapper/native logs, runs
`scripts/verify-native-smoke-log.sh`, and verifies `native/moon.pkg` is restored
to its original hash. In GitHub Actions it also exports the marker, restore, and
acceptance-log fields through `GITHUB_ENV` for the workflow summary.

When `--skia-rev` is omitted, the Linux source-build helpers read the first
non-comment line of `skia-revision.txt`. Keep this file pinned to the first Skia
commit proven by a real runner; use explicit `--skia-rev` only while evaluating
new revisions. The acceptance summary records the resolved `skia_commit`, which
is the value to copy into `skia-revision.txt` after a passing source-build run.

Use `--dry-run-config` on `scripts/linux-real-skia-smoke.sh` to print the
selected mode and effective build/smoke arguments without fetching or building
Skia or rewriting `native/moon.pkg`; in source-build mode it prints the resolved
checkout/build paths and GN args, and in existing-build mode it also checks for
the Skia header and library files and prints the exact native flags that would be
injected. The lower-level `scripts/linux-build-skia.sh` and
`scripts/linux-skia-smoke.sh` helpers remain available for debugging individual
build/link stages. The lower-level build helper accepts `--dry-run-config` to
validate source-build paths and GN args without fetching, syncing, or building;
the lower-level smoke helper accepts `--dry-run-config` to validate an existing
Skia build without rewriting `native/moon.pkg`. The Linux smoke helper adds the selected Skia library
directory to `LD_LIBRARY_PATH` before executing the smoke binary so shared
`libskia.so` builds can be tested without a system install step.

macOS smoke-test helper for an existing Skia build:

```bash
bash scripts/macos-accept-real-skia-smoke.sh --log-dir logs \
  --skia-include /path/to/skia \
  --skia-lib-dir /path/to/skia/out/Static
```

The macOS acceptance wrapper has the same wrapper/native/acceptance log and
restore-check shape as Linux. The lower-level smoke helper adds common
CoreFoundation/CoreGraphics/CoreText/ImageIO frameworks by default. Use
`--extra-link-flags` for build-specific frameworks or libraries.

macOS Skia source build helper:

```bash
bash scripts/macos-build-skia.sh --work-dir .skia-cache/macos
bash scripts/macos-accept-real-skia-smoke.sh --log-dir logs \
  --skia-include .skia-cache/macos/skia \
  --skia-lib-dir .skia-cache/macos/skia/out/moonbit-smoke
```

This mirrors the Linux source-build helper, but uses macOS GN defaults and the
macOS smoke helper's framework link flags. Like Linux, `--skia-rev` defaults to
the first non-comment line of `skia-revision.txt`.

Fallback CI helper:

```powershell
.\scripts\check-fallback.ps1
```

This intentionally does not execute the real Skia smoke binary. It verifies the
fallback build stays green, the smoke module still compiles, and the Windows
existing-build dry-run path does not rewrite `native/moon.pkg`; real Skia
validation is covered by the platform acceptance wrappers above.

Real smoke acceptance checklist:

```text
REAL_SKIA_SMOKE.md
```

Use that runbook to review downloaded artifacts. A fallback pass, dry-run,
syntax check, or workflow summary without acceptance logs does not prove a real
Skia backend pass.

GitHub Actions:

- `.github/workflows/moui-skia-provider-fallback-ci.yml` runs the fallback gate on Windows and Linux;
  the Linux job also syntax-checks the Linux shell helpers with `bash -n`,
  verifies `native/ownership.json` against the MoonBit handle declarations and
  C++ wrapper finalizers, checks MoonBit native extern borrow annotations,
  dry-runs `scripts/linux-real-skia-smoke.sh` in source-build mode, and dry-runs
  existing-build mode against fake Skia header/library files so both wrapper
  branches and argument construction are checked without building Skia. It also
  dry-runs the lower-level Linux smoke helper against fake static and shared
  libraries and verifies `native/moon.pkg` is unchanged.
- `.github/workflows/moui-skia-provider-linux-real-skia-nightly.yml` is a manual/scheduled Linux job that
  uses `scripts/linux-accept-real-skia-smoke.sh` for real runs; it can build Skia from source or
  reuse user-supplied `skia_include` / `skia_lib_dir` inputs with extra flags.
  It also runs weekly as the first scheduled real-backend canary.
  The workflow runs a dry-run preflight before installing build dependencies or
  compiling Skia, then uploads the preflight log, wrapper log, dedicated native
  executable log, and acceptance summary log as a `linux-real-skia-smoke-log`
  artifact on success or failure. On real runs it also greps the native executable log for
  `moui_skia native smoke test passed` through
  `scripts/verify-native-smoke-log.sh`, which can also be used to manually
  recheck downloaded artifacts. Its workflow summary records the selected mode,
  dry-run setting, artifact name, key Skia inputs, expected log paths, the marker
  check, plus whether the temporary package rewrites were restored after the run.
  Its `dry_run_config` input forwards `--dry-run-config` for parameter preflight
  without installing MoonBit/build dependencies, restoring the Skia cache,
  building Skia, or rewriting package files. The Skia cache step only runs
  for source-built Skia, and `extra_gn_args` is ignored for existing-build mode.
- `.github/workflows/moui-skia-provider-macos-real-skia-manual.yml` is a manual macOS job that
  builds Skia from source, runs `scripts/macos-accept-real-skia-smoke.sh`, and
  uploads preflight/build/wrapper/native/acceptance logs.
- `.github/workflows/moui-skia-provider-windows-real-skia-manual.yml` is a manual Windows job for
  release or existing Skia provider runs; it runs a fake-Skia
  preflight, then uses the matching Windows acceptance script for real
  smoke acceptance and uploads wrapper/native/acceptance logs.
- Future real-Skia CI work should add a repeatable Windows Skia build/download
  source while keeping fallback jobs independent so no-Skia builds remain
  supported.
