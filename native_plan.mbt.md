# Native Skia Binding Plan

This package currently provides the value-layer API that mirrors the most common
`skia_safe` types from rust-skia: geometry, colors, matrices, paint flags, and
paint state.

The native layer is staged in the `native` subpackage. It currently exposes a
safe fallback build that compiles without Skia and reports unavailable. Real Skia
support is enabled by compiling the C++ stub with `SKIA_MBT_HAS_SKIA`, Skia
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
- `skia_available`;
- raster N32 premul surface constructor API;
- surface width, height, dimensions, image info, and canvas borrow;
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
- canvas state and transform calls: `save`, `restore`, `restore_to_count`,
  `save_count`, `translate`, `scale`, `rotate`, `skew`, `concat`,
  `reset_matrix`, and `discard`;
- canvas clipping with rect/path geometry and `ClipOp`;
- canvas `clear`, `draw_color`, `draw_paint`, `draw_point`, `draw_line`,
  `draw_rect`, `draw_oval`, `draw_circle`, `draw_arc`, and
  `draw_round_rect`, plus `draw_path`, `draw_image`, and `draw_image_rect`
  with `SamplingOptions`;
- value-layer sampling controls: `FilterMode`, `MipmapMode`,
  `CubicResampler`, and `SamplingOptions`;
- primitive paint conversion for color, anti-aliasing, dither, style, stroke
  width, stroke miter, stroke cap, stroke join, and blend mode;
- fallback C++ stub path for environments without Skia.

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
link(
  native(
    "stub-cc-flags": "-DSKIA_MBT_HAS_SKIA -I/path/to/skia",
    "cc-link-flags": "-L/path/to/skia/out/Static -lskia",
  ),
)
```

The exact flags are platform- and Skia-build-dependent. On Windows with GCC,
MinGW-compatible Skia libraries are required; MSVC `.lib` files are not directly
compatible with `g++`.
