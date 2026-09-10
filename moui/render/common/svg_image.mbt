///|
/// SVG image support for the renderer-neutral image pipeline.
///
/// Backends decode only the raster formats their codec library understands,
/// so a document that references an `.svg` asset renders as a placeholder on
/// every platform. This module supplies the missing decoder as a plugin: SVG
/// is rasterized here, in pure MoonBit, and handed back through the existing
/// `ready_decoded_rgba` completion. Nothing downstream needs to know the
/// pixels came from a vector source.
///
/// The rasterizer understands `viewBox`, `preserveAspectRatio`, `clipPath`
/// and `mask`, and the module compiles for every target (native, wasm,
/// wasm-gc), so the same plugin covers desktop and Web.

///|
/// Upper bound on the longest rasterized edge. Keeps a hostile or merely
/// oversized document from allocating an enormous bitmap.
let svg_raster_max_side : Int = 2048

///|
/// Upper bound on total rasterized pixels, independent of aspect ratio.
let svg_raster_max_pixels : Int = 4194304

///|
/// Preferred over-sampling factor. SVG is resolution independent: rasterizing
/// slightly above the intrinsic size keeps downscaled placements crisp on
/// high-density displays without exploding the bitmap on large assets.
let svg_raster_scale : Double = 2.0

///|
/// True when `source` should be treated as SVG: either its path carries an
/// `.svg`/`.svgz` suffix, or its leading bytes contain an `<svg` root tag.
/// The suffix alone is not enough — plenty of sources are served without one —
/// and the tag scan is bounded so a large binary payload is never walked whole.
pub fn svg_source_is_svg(source : String, bytes : Bytes) -> Bool {
  let lowered = source.to_lower()
  lowered.has_suffix(".svg") ||
  lowered.has_suffix(".svgz") ||
  svg_bytes_contain_root_tag(bytes)
}

///|
/// Scan the leading bytes for the ASCII `<svg` root tag.
fn svg_bytes_contain_root_tag(bytes : Bytes) -> Bool {
  let limit = if bytes.length() < 2048 { bytes.length() } else { 2048 }
  let mut index = 0
  while index + 4 <= limit {
    if svg_byte(bytes, index) == 0x3C &&
      svg_byte(bytes, index + 1) == 0x73 &&
      svg_byte(bytes, index + 2) == 0x76 &&
      svg_byte(bytes, index + 3) == 0x67 {
      return true
    }
    index = index + 1
  }
  false
}

///|
fn svg_byte(bytes : Bytes, index : Int) -> Int {
  match bytes.get(index) {
    Some(byte) => byte.to_int()
    None => -1
  }
}

///|
/// Fallback replaced-element size. Matches the SVG/CSS default of 300x150 and
/// keeps a parseable document renderable when it declares neither `viewBox`
/// nor resolvable `width`/`height`.
let svg_default_size : @core.Size = @core.Size::new(width=300.0, height=150.0)

///|
/// Intrinsic size of an SVG document: `viewBox` when present, otherwise the
/// root element's `width`/`height`. Returns `None` when neither is usable,
/// which lets callers keep their own placeholder sizing.
pub fn svg_intrinsic_size(svg_text : String) -> @core.Size? {
  match @svg.parse_svg_document(svg_text) {
    Some(document) => {
      let root = document.root
      match root.view_box {
        Some(view_box) =>
          if view_box.width > 0.0 && view_box.height > 0.0 {
            return Some(
              @core.Size::new(
                width=view_box.width,
                height=view_box.height,
              ),
            )
          }
        None => ()
      }
      // The parser records `viewport_width`/`viewport_height` only for nested
      // `<svg>` elements, so a root-level `width`/`height` pair has to be read
      // from the tag text itself.
      svg_root_viewport_size(svg_text)
    }
    None => None
  }
}

///|
/// Intrinsic size of `bytes` when they hold an SVG document, otherwise `None`.
///
/// Size probes that only have raw bytes — the markdown intrinsic-size reader,
/// for example — route SVG through the same detection the image decoder uses,
/// so a vector asset reserves the right box instead of a placeholder ratio.
pub fn svg_intrinsic_size_from_bytes(bytes : Bytes) -> @core.Size? {
  if !svg_source_is_svg("", bytes) {
    return None
  }
  svg_intrinsic_size(@utf8.decode_lossy(bytes[:], ignore_bom=false))
}

///|
/// Read `width`/`height` off the root `<svg>` start tag. Percentage and
/// unit-relative lengths yield `None` because they cannot be resolved without
/// a containing viewport.
fn svg_root_viewport_size(svg_text : String) -> @core.Size? {
  let tag = match svg_root_tag_text(svg_text) {
    Some(tag) => tag
    None => return None
  }
  let width = match svg_attr_value(tag, "width") {
    Some(raw) => svg_parse_length_literal(raw)
    None => None
  }
  let height = match svg_attr_value(tag, "height") {
    Some(raw) => svg_parse_length_literal(raw)
    None => None
  }
  match (width, height) {
    (Some(width), Some(height)) =>
      if width > 0.0 && height > 0.0 {
        Some(@core.Size::new(width~, height~))
      } else {
        None
      }
    _ => None
  }
}

///|
/// The root `<svg ...>` start tag, taken from the first `>`-delimited segment
/// that opens an `svg` element.
fn svg_root_tag_text(svg_text : String) -> String? {
  for segment in svg_text.split(">").to_array() {
    if segment.contains("<svg") {
      return Some(segment.to_owned())
    }
  }
  None
}

///|
/// Value of `name` in a start tag, tolerating single or double quotes.
fn svg_attr_value(tag : String, name : String) -> String? {
  for raw in tag.split(" ").to_array() {
    let parts = raw.split("=").to_array()
    if parts.length() == 2 && parts[0].to_owned() == name {
      return Some(svg_strip_quotes(parts[1].to_owned()))
    }
  }
  None
}

///|
fn svg_strip_quotes(value : String) -> String {
  let chars = value.to_array()
  let mut start = 0
  let mut end = chars.length()
  if start < end && (chars[start] == '"' || chars[start] == '\'') {
    start = start + 1
  }
  if end > start && (chars[end - 1] == '"' || chars[end - 1] == '\'') {
    end = end - 1
  }
  String::from_array(chars[start:end])
}

///|
/// Parse a leading unsigned decimal literal such as `24`, `24.5` or `24px`.
/// Percentages return `None`; any other trailing unit is ignored, which is
/// correct for the pixel lengths that appear in real-world assets.
fn svg_parse_length_literal(value : String) -> Double? {
  let trimmed = value.trim().to_owned()
  if trimmed == "" || trimmed.contains("%") {
    return None
  }
  let chars = trimmed.to_array()
  let mut index = 0
  let mut whole = 0.0
  let mut integral_digits = 0
  while index < chars.length() {
    let ch = chars[index]
    if ch < '0' || ch > '9' {
      break
    }
    whole = whole * 10.0 + (ch.to_int() - 48).to_double()
    integral_digits = integral_digits + 1
    index = index + 1
  }
  if integral_digits == 0 {
    return None
  }
  let mut fraction = 0.0
  let mut scale = 1.0
  if index < chars.length() && chars[index] == '.' {
    index = index + 1
    while index < chars.length() {
      let ch = chars[index]
      if ch < '0' || ch > '9' {
        break
      }
      scale = scale * 10.0
      fraction = fraction + (ch.to_int() - 48).to_double() / scale
      index = index + 1
    }
  }
  Some(whole + fraction)
}

///|
/// Rasterized pixel size for an intrinsic size, preserving aspect ratio while
/// respecting the oversampling preference and the memory budget.
pub fn svg_raster_target_size(intrinsic : @core.Size) -> (Int, Int) {
  let extent = if intrinsic.width > intrinsic.height {
    intrinsic.width
  } else {
    intrinsic.height
  }
  let mut scale = svg_raster_scale
  if extent > 0.0 {
    let side_bound = svg_raster_max_side.to_double() / extent
    if scale > side_bound {
      scale = side_bound
    }
  }
  let mut width = svg_pixel_dimension(intrinsic.width * scale)
  let mut height = svg_pixel_dimension(intrinsic.height * scale)
  while width * height > svg_raster_max_pixels && scale > 0.25 {
    scale = scale / 2.0
    width = svg_pixel_dimension(intrinsic.width * scale)
    height = svg_pixel_dimension(intrinsic.height * scale)
  }
  (width, height)
}

///|
fn svg_pixel_dimension(value : Double) -> Int {
  if value <= 0.0 {
    return 1
  }
  let rounded = value.round().to_int()
  if rounded < 1 { 1 } else { rounded }
}

///|
/// Make sure the root element carries a `viewBox`.
///
/// The rasterizer only maps user units onto the target canvas through a
/// `viewBox` -> viewport transform. A document that declares just `width` and
/// `height` therefore gets no scaling at all: its content is painted at 1:1
/// user units into whatever canvas we allocate, so an oversampled raster ends
/// up with the artwork shrunk into one corner and the rest transparent. Real
/// assets do this — the shields.io badges are `width="120" height="20"` with no
/// `viewBox` — so derive the missing viewBox from the declared size.
fn svg_ensure_root_view_box(
  document : @svg.SVGDocument,
  declared : @core.Size?,
) -> Unit {
  match document.root.view_box {
    Some(_) => ()
    None =>
      match declared {
        Some(size) =>
          if size.width > 0.0 && size.height > 0.0 {
            document.root.view_box = Some(
              @svg.ViewBox::{
                min_x: 0.0,
                min_y: 0.0,
                width: size.width,
                height: size.height,
              },
            )
          }
        None => ()
      }
  }
}

///|
/// Rasterize `svg_text` into premultiplied RGBA8888 pixels with
/// `row_bytes = pixel_width * 4`. Returns `None` when the document cannot be
/// parsed or the requested size is degenerate.
///
/// The premultiplied layout matches what raster backends expect from a decoded
/// image payload, so the result is interchangeable with a codec's output.
pub fn svg_rasterize_rgba(
  svg_text : String,
  pixel_width : Int,
  pixel_height : Int,
) -> Bytes? {
  if pixel_width <= 0 || pixel_height <= 0 {
    return None
  }
  match @svg.parse_svg_document(svg_text) {
    Some(document) => {
      svg_ensure_root_view_box(document, svg_root_viewport_size(svg_text))
      let pixels = svg_render_document_rgba(
        document,
        pixel_width,
        pixel_height,
      )
      Some(svg_pixels_to_premultiplied_rgba(pixels, pixel_width, pixel_height))
    }
    None => None
  }
}

///|
/// Rasterize a document into straight-alpha pixels using **source-over**
/// compositing.
///
/// The stock `render_svg_document_to_image` paints through `Image::set_pixel`,
/// which overwrites the destination. Nothing that relies on translucency can
/// survive that: a 10%-opacity gradient overlay — which is exactly how
/// shields.io shades its badges — replaces the badge body with near-transparent
/// grey, so the badge renders blank. Compositing here instead of overwriting
/// keeps the layers stacked the way the document intends.
fn svg_render_document_rgba(
  document : @svg.SVGDocument,
  pixel_width : Int,
  pixel_height : Int,
) -> Array[@svg.Color] {
  let pixels : Array[@svg.Color] = Array::make(
    pixel_width * pixel_height,
    @svg.Color::transparent(),
  )
  let setter : @svg.PixelSetter = {
    set: (x, y, color) => {
      if x < 0 || y < 0 || x >= pixel_width || y >= pixel_height {
        return
      }
      let index = y * pixel_width + x
      pixels[index] = svg_composite_over(pixels[index], color)
    },
  }
  document.render(@svg.RenderContext::new(setter, pixel_width, pixel_height))
  pixels
}

///|
/// Porter-Duff source-over blend of a straight-alpha `src` onto `dst`.
fn svg_composite_over(dst : @svg.Color, src : @svg.Color) -> @svg.Color {
  let src_alpha = svg_clamp_channel(src.a)
  if src_alpha <= 0 {
    return dst
  }
  if src_alpha >= 255 {
    return src
  }
  let dst_alpha = svg_clamp_channel(dst.a)
  let keep = 255 - src_alpha
  let out_alpha = src_alpha + (dst_alpha * keep + 127) / 255
  if out_alpha <= 0 {
    return @svg.Color::transparent()
  }
  let dst_weight = dst_alpha * keep
  @svg.Color::rgba(
    svg_blend_channel(src.r, src_alpha, dst.r, dst_weight, out_alpha),
    svg_blend_channel(src.g, src_alpha, dst.g, dst_weight, out_alpha),
    svg_blend_channel(src.b, src_alpha, dst.b, dst_weight, out_alpha),
    out_alpha,
  )
}

///|
fn svg_blend_channel(
  src : Int,
  src_alpha : Int,
  dst : Int,
  dst_weight : Int,
  out_alpha : Int,
) -> Int {
  let weighted = svg_clamp_channel(src) * src_alpha +
    svg_clamp_channel(dst) * dst_weight / 255
  svg_clamp_channel((weighted + out_alpha / 2) / out_alpha)
}

///|
/// Convert straight-alpha pixels into premultiplied RGBA8888 bytes.
fn svg_pixels_to_premultiplied_rgba(
  pixels : Array[@svg.Color],
  pixel_width : Int,
  pixel_height : Int,
) -> Bytes {
  let row_bytes = pixel_width * 4
  let out : Array[Byte] = Array::make(row_bytes * pixel_height, b'\x00')
  for y = 0; y < pixel_height; y = y + 1 {
    let source_row = y * pixel_width
    let target_row = y * row_bytes
    for x = 0; x < pixel_width; x = x + 1 {
      let color = pixels[source_row + x]
      let alpha = svg_clamp_channel(color.a)
      let offset = target_row + x * 4
      out[offset] = svg_premultiply(color.r, alpha).to_byte()
      out[offset + 1] = svg_premultiply(color.g, alpha).to_byte()
      out[offset + 2] = svg_premultiply(color.b, alpha).to_byte()
      out[offset + 3] = alpha.to_byte()
    }
  }
  Bytes::from_array(out)
}

///|
fn svg_clamp_channel(value : Int) -> Int {
  if value < 0 {
    0
  } else if value > 255 {
    255
  } else {
    value
  }
}

///|
fn svg_premultiply(channel : Int, alpha : Int) -> Int {
  let clamped = svg_clamp_channel(channel)
  if clamped <= 0 {
    return 0
  }
  let scaled = (clamped * alpha + 127) / 255
  if scaled > 255 { 255 } else { scaled }
}

///|
/// The SVG decoder plugin. Sources that are not SVG produce a failed
/// completion so a decoder chain can continue to a raster codec; SVG sources
/// either rasterize or fail with a diagnostic the renderer can surface.
pub fn svg_image_decoder() -> @render.RendererImageDecoder {
  @render.RendererImageDecoder::new(decode=(source, bytes) => {
    match bytes {
      Some(data) =>
        if !svg_source_is_svg(source, data) {
          @render.ImageResourceLoadCompletion::failed(
            source,
            diagnostic="source is not SVG",
          )
        } else {
          svg_decode_bytes(source, data)
        }
      None =>
        @render.ImageResourceLoadCompletion::failed(
          source,
          diagnostic="SVG source bytes are unavailable",
        )
    }
  })
}

///|
fn svg_decode_bytes(
  source : String,
  data : Bytes,
) -> @render.ImageResourceLoadCompletion {
  let text = @utf8.decode_lossy(data[:], ignore_bom=false)
  // A document without a usable intrinsic size still renders, at the CSS
  // default replaced-element box, rather than degrading to a placeholder.
  let intrinsic = match svg_intrinsic_size(text) {
    Some(size) => size
    None => svg_default_size
  }
  let (width, height) = svg_raster_target_size(intrinsic)
  match svg_rasterize_rgba(text, width, height) {
    Some(pixels) =>
      @render.ImageResourceLoadCompletion::ready_decoded_rgba(
        source,
        width~,
        height~,
        row_bytes=width * 4,
        pixels,
      )
    None =>
      @render.ImageResourceLoadCompletion::failed(
        source,
        diagnostic="SVG rasterization failed",
      )
  }
}
