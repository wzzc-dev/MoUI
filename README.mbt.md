# wzzc-dev/skia_mbt

MoonBit bindings for the Skia Graphics Library, structured after
`rust-skia/rust-skia`.

The current package exposes the first value-layer API surface:

- geometry: `Point`, `IPoint`, `Size`, `ISize`, `Rect`, `IRect`
- color: `Color`, `Color4f`
- image metadata: `ColorInfo`, `ImageInfo`
- pixel snapshots: `Pixmap`
- transforms: `Matrix`
- paint state: `Paint`, `PaintStyle`, `StrokeCap`, `StrokeJoin`, `BlendMode`
- image sampling: `SamplingOptions`, `FilterMode`, `MipmapMode`,
  `CubicResampler`

Native Skia object handles are intentionally staged behind a separate FFI plan so
ownership, ref-counting, and linker configuration can be validated package by
package.

The `native` subpackage contains the first opt-in native boundary:

- `@native.skia_available()` reports whether the stub was compiled with real
  Skia headers and libraries;
- `@native.Surface::raster_n32_premul(size)` is the first raster surface entry;
- `@native.Surface::image_snapshot()` returns an immutable `@native.Image`
  handle when a surface is available;
- `@native.Surface::image_snapshot_with_bounds(bounds)` snapshots a bounded
  surface rectangle;
- `@native.Surface::read_pixels(bounds)` reads N32 premultiplied surface pixels
  into an owned `@skia_mbt.Pixmap`;
- `@native.Image::encode_to_data(format, quality)` returns immutable
  `@native.Data` bytes for encoded image output;
- `@native.Image::from_bitmap(bitmap)` snapshots a native bitmap into an
  immutable image;
- `@native.Data::from_bytes(bytes)` and `@native.Image::from_encoded_bytes(bytes)`
  provide the first in-memory image decode path;
- `@native.Codec::from_data(data)` and `@native.Codec::from_bytes(bytes)` expose
  encoded image metadata and decode to an N32 premultiplied `Bitmap`;
- `@native.Bitmap::alloc_n32_premul(size)` owns raster pixel storage and can
  export a copied `@skia_mbt.Pixmap`;
- `@native.Typeface::default()` / `from_name(family)` and
  `@native.Font::default(size)` / `from_typeface(typeface, size)` create the
  first native text handles for drawing;
- `@native.Shader::color(color)`, `linear_gradient(start, end, colors...)`,
  and `radial_gradient(center, radius, colors...)` create the first native
  shader handles for shader-backed paint calls;
- `@native.Path` supports the first path construction calls: `new`, `reset`,
  `move_to`, `line_to`, `quad_to`, `cubic_to`, `close`, and `is_empty`;
- `@native.Canvas` supports `clear`, `draw_color`, `draw_paint`,
  `draw_point`, `draw_line`, `draw_rect`, `draw_oval`, `draw_circle`,
  `draw_arc`, `draw_round_rect`, `draw_path`, `draw_image`, and
  `draw_image_rect` with explicit `SamplingOptions`, plus UTF-8 text through
  `draw_text_utf8` and color-shader paint through `draw_paint_shader` /
  `draw_rect_shader`;
- `@native.Canvas` also exposes the first state and transform calls:
  `save`, `restore`, `restore_to_count`, `save_count`, `translate`, `scale`,
  `rotate`, `skew`, `concat`, `reset_matrix`, and `discard`;
- `@native.Canvas` exposes clipping with `clip_rect` and `clip_path` using
  `ClipOp`;
- without Skia link flags it compiles as a safe fallback and returns `None`.

```mbt check
///|
test {
  let info = @skia_mbt.ImageInfo::n32_premul(@skia_mbt.ISize::new(1, 1))
  let pixmap = @skia_mbt.Pixmap::new(info, 4, b"\xff\x00\x00\xff")

  assert_true(pixmap is Some(_))
}
```

```mbt check
///|
test {
  let paint = @skia_mbt.Paint::new(
    color=@skia_mbt.Color::from_rgb(0xff, 0, 0),
    anti_alias=true,
  ).set_stroke(true)

  assert_true(paint.style == @skia_mbt.Stroke)
  assert_true(paint.color == @skia_mbt.Color::red())
}
```

```mbt check
///|
test {
  let sampling = @skia_mbt.SamplingOptions::new(
    filter=@skia_mbt.FilterMode::Linear,
    mipmap=@skia_mbt.MipmapMode::Linear,
  )

  assert_eq(sampling.filter_ordinal(), 1)
  assert_eq(sampling.mipmap_ordinal(), 2)
  assert_true(!sampling.uses_cubic())
}
```
