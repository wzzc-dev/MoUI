///|
extern "C" fn metal_context_create() -> UInt64 = "moui_metal_context_create"

///|
extern "C" fn metal_context_prepare(context : UInt64, layer : UInt64) -> Int32 = "moui_metal_context_prepare"

///|
#borrow(vertices, items, shapes, layers)
extern "C" fn metal_draw_frame(
  context : UInt64,
  layer : UInt64,
  red : Double,
  green : Double,
  blue : Double,
  alpha : Double,
  vertices : Bytes,
  vertex_bytes : Int32,
  items : Bytes,
  item_bytes : Int32,
  shapes : Bytes,
  shape_bytes : Int32,
  layers : Bytes,
  layer_bytes : Int32,
) -> Int32 = "moui_metal_draw_frame"

///|
/// Offscreen proof pass: renders into a host-readable texture and copies the
/// pixels back. Tests and smoke gates use it; no presentation path calls it.
#borrow(vertices, items, shapes, layers, output)
extern "C" fn metal_draw_proof(
  context : UInt64,
  width : Int32,
  height : Int32,
  red : Double,
  green : Double,
  blue : Double,
  alpha : Double,
  vertices : Bytes,
  vertex_bytes : Int32,
  items : Bytes,
  item_bytes : Int32,
  shapes : Bytes,
  shape_bytes : Int32,
  layers : Bytes,
  layer_bytes : Int32,
  output : Bytes,
  output_bytes : Int32,
) -> Int32 = "moui_metal_draw_proof"

///|
extern "C" fn metal_context_release(context : UInt64) -> Unit = "moui_metal_context_release"

///|
/// Upload one glyph coverage atlas page. The texture is created on first use, so
/// an offscreen proof pass needs no host layer. `page` is the index a text item's
/// `texture_key` names, and pages arrive in growing order.
#borrow(pixels)
extern "C" fn metal_texture_write(
  context : UInt64,
  page : Int32,
  pixels : Bytes,
  pixel_bytes : Int32,
) -> Int32 = "moui_metal_texture_write"

///|
/// Decode one encoded image with ImageIO into premultiplied RGBA8. Returns 1 on
/// success, 2 when `out_pixels` is too small (retry with the size reported
/// through `out_size`), 0 when the bytes do not decode.
#borrow(bytes, out_pixels, out_size)
extern "C" fn metal_image_decode(
  bytes : Bytes,
  byte_len : Int32,
  out_pixels : Bytes,
  out_capacity : Int32,
  out_size : Bytes,
) -> Int32 = "moui_metal_image_decode"

///|
/// Install decoded RGBA8 as the texture one `ImageRun` samples.
#borrow(pixels)
extern "C" fn metal_image_write_rgba(
  context : UInt64,
  key : Int32,
  width : Int32,
  height : Int32,
  row_bytes : Int32,
  pixels : Bytes,
  pixel_bytes : Int32,
) -> Int32 = "moui_metal_image_write_rgba"

///|
/// Release the texture installed under `key`. Returns 0 when there is no context
/// or nothing was installed, which is what the CPU-only report path hits.
extern "C" fn metal_image_release(context : UInt64, key : Int32) -> Int32 = "moui_metal_image_release"
