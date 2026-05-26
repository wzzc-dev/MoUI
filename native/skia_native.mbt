///|
/// Opaque native Skia surface handle.
priv type SurfaceHandle

///|
/// Opaque native Skia canvas handle borrowed from a surface.
priv type CanvasHandle

///|
/// Opaque native Skia immutable data handle.
priv type DataHandle

///|
/// Opaque native Skia codec handle.
priv type CodecHandle

///|
/// Opaque native Skia image handle.
priv type ImageHandle

///|
/// Opaque native Skia path handle.
priv type PathHandle

///|
/// Opaque native Skia font handle.
priv type FontHandle

///|
/// Opaque native Skia typeface handle.
priv type TypefaceHandle

///|
/// Opaque native Skia shader handle.
priv type ShaderHandle

///|
/// Opaque native Skia bitmap handle.
priv type BitmapHandle

///|
/// Runtime availability of the linked Skia native backend.
pub extern "C" fn skia_available() -> Bool = "moonbit_skia_available"

///|
extern "C" fn native_path_new() -> PathHandle = "moonbit_skia_path_new"

///|
extern "C" fn native_font_default(size : Float) -> FontHandle = "moonbit_skia_font_default"

///|
#borrow(typeface)
extern "C" fn native_font_from_typeface(
  typeface : TypefaceHandle,
  size : Float,
) -> FontHandle = "moonbit_skia_font_from_typeface"

///|
#borrow(font)
extern "C" fn native_font_is_null(font : FontHandle) -> Bool = "moonbit_skia_font_is_null"

///|
#borrow(font)
extern "C" fn native_font_size(font : FontHandle) -> Float = "moonbit_skia_font_size"

///|
#borrow(font)
extern "C" fn native_font_set_size(font : FontHandle, size : Float) -> Unit = "moonbit_skia_font_set_size"

///|
extern "C" fn native_typeface_default() -> TypefaceHandle = "moonbit_skia_typeface_default"

///|
#borrow(family_name)
extern "C" fn native_typeface_from_name(family_name : Bytes) -> TypefaceHandle = "moonbit_skia_typeface_from_name"

///|
#borrow(typeface)
extern "C" fn native_typeface_is_null(typeface : TypefaceHandle) -> Bool = "moonbit_skia_typeface_is_null"

///|
#borrow(typeface)
extern "C" fn native_typeface_is_bold(typeface : TypefaceHandle) -> Bool = "moonbit_skia_typeface_is_bold"

///|
#borrow(typeface)
extern "C" fn native_typeface_is_italic(typeface : TypefaceHandle) -> Bool = "moonbit_skia_typeface_is_italic"

///|
#borrow(typeface)
extern "C" fn native_typeface_is_fixed_pitch(typeface : TypefaceHandle) -> Bool = "moonbit_skia_typeface_is_fixed_pitch"

///|
extern "C" fn native_shader_color(color_argb : UInt) -> ShaderHandle = "moonbit_skia_shader_color"

///|
extern "C" fn native_shader_linear_gradient(
  x0 : Float,
  y0 : Float,
  x1 : Float,
  y1 : Float,
  color0_argb : UInt,
  color1_argb : UInt,
  tile_mode : Int,
) -> ShaderHandle = "moonbit_skia_shader_linear_gradient"

///|
extern "C" fn native_shader_radial_gradient(
  center_x : Float,
  center_y : Float,
  radius : Float,
  color0_argb : UInt,
  color1_argb : UInt,
  tile_mode : Int,
) -> ShaderHandle = "moonbit_skia_shader_radial_gradient"

///|
#borrow(shader)
extern "C" fn native_shader_is_null(shader : ShaderHandle) -> Bool = "moonbit_skia_shader_is_null"

///|
extern "C" fn native_bitmap_alloc_n32_premul(
  width : Int,
  height : Int,
) -> BitmapHandle = "moonbit_skia_bitmap_alloc_n32_premul"

///|
#borrow(bitmap)
extern "C" fn native_bitmap_is_null(bitmap : BitmapHandle) -> Bool = "moonbit_skia_bitmap_is_null"

///|
#borrow(bitmap)
extern "C" fn native_bitmap_width(bitmap : BitmapHandle) -> Int = "moonbit_skia_bitmap_width"

///|
#borrow(bitmap)
extern "C" fn native_bitmap_height(bitmap : BitmapHandle) -> Int = "moonbit_skia_bitmap_height"

///|
#borrow(bitmap)
extern "C" fn native_bitmap_row_bytes(bitmap : BitmapHandle) -> Int = "moonbit_skia_bitmap_row_bytes"

///|
#borrow(bitmap)
extern "C" fn native_bitmap_byte_size(bitmap : BitmapHandle) -> Int = "moonbit_skia_bitmap_byte_size"

///|
#borrow(bitmap)
extern "C" fn native_bitmap_to_bytes(bitmap : BitmapHandle) -> Bytes = "moonbit_skia_bitmap_to_bytes"

///|
#borrow(bitmap)
extern "C" fn native_bitmap_erase_color(
  bitmap : BitmapHandle,
  color_argb : UInt,
) -> Unit = "moonbit_skia_bitmap_erase_color"

///|
#borrow(bytes)
extern "C" fn native_data_from_bytes(bytes : Bytes) -> DataHandle = "moonbit_skia_data_from_bytes"

///|
#borrow(data)
extern "C" fn native_data_is_null(data : DataHandle) -> Bool = "moonbit_skia_data_is_null"

///|
#borrow(data)
extern "C" fn native_data_size(data : DataHandle) -> Int = "moonbit_skia_data_size"

///|
#borrow(data)
extern "C" fn native_data_to_bytes(data : DataHandle) -> Bytes = "moonbit_skia_data_to_bytes"

///|
#borrow(data)
extern "C" fn native_codec_from_data(data : DataHandle) -> CodecHandle = "moonbit_skia_codec_from_data"

///|
#borrow(codec)
extern "C" fn native_codec_is_null(codec : CodecHandle) -> Bool = "moonbit_skia_codec_is_null"

///|
#borrow(codec)
extern "C" fn native_codec_width(codec : CodecHandle) -> Int = "moonbit_skia_codec_width"

///|
#borrow(codec)
extern "C" fn native_codec_height(codec : CodecHandle) -> Int = "moonbit_skia_codec_height"

///|
#borrow(codec)
extern "C" fn native_codec_encoded_format(codec : CodecHandle) -> Int = "moonbit_skia_codec_encoded_format"

///|
#borrow(codec)
extern "C" fn native_codec_decode_n32_premul(
  codec : CodecHandle,
) -> BitmapHandle = "moonbit_skia_codec_decode_n32_premul"

///|
#borrow(image)
extern "C" fn native_image_is_null(image : ImageHandle) -> Bool = "moonbit_skia_image_is_null"

///|
#borrow(image)
extern "C" fn native_image_width(image : ImageHandle) -> Int = "moonbit_skia_image_width"

///|
#borrow(image)
extern "C" fn native_image_height(image : ImageHandle) -> Int = "moonbit_skia_image_height"

///|
#borrow(bitmap)
extern "C" fn native_image_from_bitmap(bitmap : BitmapHandle) -> ImageHandle = "moonbit_skia_image_from_bitmap"

///|
#borrow(image)
extern "C" fn native_image_encode_to_data(
  image : ImageHandle,
  format : Int,
  quality : Int,
) -> DataHandle = "moonbit_skia_image_encode_to_data"

///|
#borrow(data)
extern "C" fn native_image_from_encoded_data(data : DataHandle) -> ImageHandle = "moonbit_skia_image_from_encoded_data"

///|
#borrow(path)
extern "C" fn native_path_is_null(path : PathHandle) -> Bool = "moonbit_skia_path_is_null"

///|
#borrow(path)
extern "C" fn native_path_reset(path : PathHandle) -> Unit = "moonbit_skia_path_reset"

///|
#borrow(path)
extern "C" fn native_path_move_to(
  path : PathHandle,
  x : Float,
  y : Float,
) -> Unit = "moonbit_skia_path_move_to"

///|
#borrow(path)
extern "C" fn native_path_line_to(
  path : PathHandle,
  x : Float,
  y : Float,
) -> Unit = "moonbit_skia_path_line_to"

///|
#borrow(path)
extern "C" fn native_path_quad_to(
  path : PathHandle,
  x1 : Float,
  y1 : Float,
  x2 : Float,
  y2 : Float,
) -> Unit = "moonbit_skia_path_quad_to"

///|
#borrow(path)
extern "C" fn native_path_cubic_to(
  path : PathHandle,
  x1 : Float,
  y1 : Float,
  x2 : Float,
  y2 : Float,
  x3 : Float,
  y3 : Float,
) -> Unit = "moonbit_skia_path_cubic_to"

///|
#borrow(path)
extern "C" fn native_path_close(path : PathHandle) -> Unit = "moonbit_skia_path_close"

///|
#borrow(path)
extern "C" fn native_path_is_empty(path : PathHandle) -> Bool = "moonbit_skia_path_is_empty"

///|
extern "C" fn native_surface_raster_n32_premul(
  width : Int,
  height : Int,
) -> SurfaceHandle = "moonbit_skia_surface_raster_n32_premul"

///|
#borrow(surface)
extern "C" fn native_surface_is_null(surface : SurfaceHandle) -> Bool = "moonbit_skia_surface_is_null"

///|
#borrow(surface)
extern "C" fn native_surface_width(surface : SurfaceHandle) -> Int = "moonbit_skia_surface_width"

///|
#borrow(surface)
extern "C" fn native_surface_height(surface : SurfaceHandle) -> Int = "moonbit_skia_surface_height"

///|
#borrow(surface)
extern "C" fn native_surface_canvas(surface : SurfaceHandle) -> CanvasHandle = "moonbit_skia_surface_canvas"

///|
#borrow(surface)
extern "C" fn native_surface_image_snapshot(
  surface : SurfaceHandle,
) -> ImageHandle = "moonbit_skia_surface_image_snapshot"

///|
#borrow(surface)
extern "C" fn native_surface_image_snapshot_with_bounds(
  surface : SurfaceHandle,
  left : Int,
  top : Int,
  right : Int,
  bottom : Int,
) -> ImageHandle = "moonbit_skia_surface_image_snapshot_with_bounds"

///|
#borrow(surface)
extern "C" fn native_surface_read_pixels(
  surface : SurfaceHandle,
  left : Int,
  top : Int,
  width : Int,
  height : Int,
) -> Bytes = "moonbit_skia_surface_read_pixels"

///|
#borrow(canvas)
extern "C" fn native_canvas_is_null(canvas : CanvasHandle) -> Bool = "moonbit_skia_canvas_is_null"

///|
#borrow(canvas)
extern "C" fn native_canvas_save(canvas : CanvasHandle) -> Int = "moonbit_skia_canvas_save"

///|
#borrow(canvas)
extern "C" fn native_canvas_restore(canvas : CanvasHandle) -> Unit = "moonbit_skia_canvas_restore"

///|
#borrow(canvas)
extern "C" fn native_canvas_restore_to_count(
  canvas : CanvasHandle,
  count : Int,
) -> Unit = "moonbit_skia_canvas_restore_to_count"

///|
#borrow(canvas)
extern "C" fn native_canvas_save_count(canvas : CanvasHandle) -> Int = "moonbit_skia_canvas_save_count"

///|
#borrow(canvas)
extern "C" fn native_canvas_translate(
  canvas : CanvasHandle,
  dx : Float,
  dy : Float,
) -> Unit = "moonbit_skia_canvas_translate"

///|
#borrow(canvas)
extern "C" fn native_canvas_scale(
  canvas : CanvasHandle,
  sx : Float,
  sy : Float,
) -> Unit = "moonbit_skia_canvas_scale"

///|
#borrow(canvas)
extern "C" fn native_canvas_rotate(
  canvas : CanvasHandle,
  degrees : Float,
) -> Unit = "moonbit_skia_canvas_rotate"

///|
#borrow(canvas)
extern "C" fn native_canvas_skew(
  canvas : CanvasHandle,
  sx : Float,
  sy : Float,
) -> Unit = "moonbit_skia_canvas_skew"

///|
#borrow(canvas)
extern "C" fn native_canvas_concat(
  canvas : CanvasHandle,
  scale_x : Float,
  skew_x : Float,
  trans_x : Float,
  skew_y : Float,
  scale_y : Float,
  trans_y : Float,
  persp_0 : Float,
  persp_1 : Float,
  persp_2 : Float,
) -> Unit = "moonbit_skia_canvas_concat"

///|
#borrow(canvas)
extern "C" fn native_canvas_reset_matrix(canvas : CanvasHandle) -> Unit = "moonbit_skia_canvas_reset_matrix"

///|
#borrow(canvas)
extern "C" fn native_canvas_discard(canvas : CanvasHandle) -> Unit = "moonbit_skia_canvas_discard"

///|
#borrow(canvas)
extern "C" fn native_canvas_clip_rect(
  canvas : CanvasHandle,
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
  op : Int,
  anti_alias : Bool,
) -> Unit = "moonbit_skia_canvas_clip_rect"

///|
#borrow(canvas, path)
extern "C" fn native_canvas_clip_path(
  canvas : CanvasHandle,
  path : PathHandle,
  op : Int,
  anti_alias : Bool,
) -> Unit = "moonbit_skia_canvas_clip_path"

///|
#borrow(canvas)
extern "C" fn native_canvas_draw_color(
  canvas : CanvasHandle,
  color_argb : UInt,
  blend_mode : Int,
) -> Unit = "moonbit_skia_canvas_draw_color"

///|
#borrow(canvas)
extern "C" fn native_canvas_draw_paint(
  canvas : CanvasHandle,
  color_argb : UInt,
  anti_alias : Bool,
  dither : Bool,
  style : Int,
  stroke_width : Float,
  stroke_miter : Float,
  stroke_cap : Int,
  stroke_join : Int,
  blend_mode : Int,
) -> Unit = "moonbit_skia_canvas_draw_paint"

///|
#borrow(canvas)
extern "C" fn native_canvas_draw_point(
  canvas : CanvasHandle,
  x : Float,
  y : Float,
  color_argb : UInt,
  anti_alias : Bool,
  dither : Bool,
  style : Int,
  stroke_width : Float,
  stroke_miter : Float,
  stroke_cap : Int,
  stroke_join : Int,
  blend_mode : Int,
) -> Unit = "moonbit_skia_canvas_draw_point"

///|
#borrow(canvas)
extern "C" fn native_canvas_draw_line(
  canvas : CanvasHandle,
  x0 : Float,
  y0 : Float,
  x1 : Float,
  y1 : Float,
  color_argb : UInt,
  anti_alias : Bool,
  dither : Bool,
  style : Int,
  stroke_width : Float,
  stroke_miter : Float,
  stroke_cap : Int,
  stroke_join : Int,
  blend_mode : Int,
) -> Unit = "moonbit_skia_canvas_draw_line"

///|
#borrow(canvas)
extern "C" fn native_canvas_draw_rect(
  canvas : CanvasHandle,
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
  color_argb : UInt,
  anti_alias : Bool,
  dither : Bool,
  style : Int,
  stroke_width : Float,
  stroke_miter : Float,
  stroke_cap : Int,
  stroke_join : Int,
  blend_mode : Int,
) -> Unit = "moonbit_skia_canvas_draw_rect"

///|
#borrow(canvas)
extern "C" fn native_canvas_draw_oval(
  canvas : CanvasHandle,
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
  color_argb : UInt,
  anti_alias : Bool,
  dither : Bool,
  style : Int,
  stroke_width : Float,
  stroke_miter : Float,
  stroke_cap : Int,
  stroke_join : Int,
  blend_mode : Int,
) -> Unit = "moonbit_skia_canvas_draw_oval"

///|
#borrow(canvas)
extern "C" fn native_canvas_draw_circle(
  canvas : CanvasHandle,
  x : Float,
  y : Float,
  radius : Float,
  color_argb : UInt,
  anti_alias : Bool,
  dither : Bool,
  style : Int,
  stroke_width : Float,
  stroke_miter : Float,
  stroke_cap : Int,
  stroke_join : Int,
  blend_mode : Int,
) -> Unit = "moonbit_skia_canvas_draw_circle"

///|
#borrow(canvas)
extern "C" fn native_canvas_draw_arc(
  canvas : CanvasHandle,
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
  start_angle : Float,
  sweep_angle : Float,
  use_center : Bool,
  color_argb : UInt,
  anti_alias : Bool,
  dither : Bool,
  style : Int,
  stroke_width : Float,
  stroke_miter : Float,
  stroke_cap : Int,
  stroke_join : Int,
  blend_mode : Int,
) -> Unit = "moonbit_skia_canvas_draw_arc"

///|
#borrow(canvas)
extern "C" fn native_canvas_draw_round_rect(
  canvas : CanvasHandle,
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
  rx : Float,
  ry : Float,
  color_argb : UInt,
  anti_alias : Bool,
  dither : Bool,
  style : Int,
  stroke_width : Float,
  stroke_miter : Float,
  stroke_cap : Int,
  stroke_join : Int,
  blend_mode : Int,
) -> Unit = "moonbit_skia_canvas_draw_round_rect"

///|
#borrow(canvas, path)
extern "C" fn native_canvas_draw_path(
  canvas : CanvasHandle,
  path : PathHandle,
  color_argb : UInt,
  anti_alias : Bool,
  dither : Bool,
  style : Int,
  stroke_width : Float,
  stroke_miter : Float,
  stroke_cap : Int,
  stroke_join : Int,
  blend_mode : Int,
) -> Unit = "moonbit_skia_canvas_draw_path"

///|
#borrow(canvas, image)
extern "C" fn native_canvas_draw_image(
  canvas : CanvasHandle,
  image : ImageHandle,
  x : Float,
  y : Float,
) -> Unit = "moonbit_skia_canvas_draw_image"

///|
#borrow(canvas, image)
extern "C" fn native_canvas_draw_image_rect(
  canvas : CanvasHandle,
  image : ImageHandle,
  src_left : Float,
  src_top : Float,
  src_right : Float,
  src_bottom : Float,
  dst_left : Float,
  dst_top : Float,
  dst_right : Float,
  dst_bottom : Float,
  color_argb : UInt,
  anti_alias : Bool,
  dither : Bool,
  style : Int,
  stroke_width : Float,
  stroke_miter : Float,
  stroke_cap : Int,
  stroke_join : Int,
  blend_mode : Int,
  sampling_filter : Int,
  sampling_mipmap : Int,
  sampling_use_cubic : Bool,
  sampling_cubic_b : Float,
  sampling_cubic_c : Float,
) -> Unit = "moonbit_skia_canvas_draw_image_rect"

///|
#borrow(canvas, shader)
extern "C" fn native_canvas_draw_paint_shader(
  canvas : CanvasHandle,
  shader : ShaderHandle,
  color_argb : UInt,
  anti_alias : Bool,
  dither : Bool,
  style : Int,
  stroke_width : Float,
  stroke_miter : Float,
  stroke_cap : Int,
  stroke_join : Int,
  blend_mode : Int,
) -> Unit = "moonbit_skia_canvas_draw_paint_shader"

///|
#borrow(canvas, shader)
extern "C" fn native_canvas_draw_rect_shader(
  canvas : CanvasHandle,
  shader : ShaderHandle,
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
  color_argb : UInt,
  anti_alias : Bool,
  dither : Bool,
  style : Int,
  stroke_width : Float,
  stroke_miter : Float,
  stroke_cap : Int,
  stroke_join : Int,
  blend_mode : Int,
) -> Unit = "moonbit_skia_canvas_draw_rect_shader"

///|
#borrow(canvas, text, font)
extern "C" fn native_canvas_draw_text_utf8(
  canvas : CanvasHandle,
  text : Bytes,
  x : Float,
  y : Float,
  font : FontHandle,
  color_argb : UInt,
  anti_alias : Bool,
  dither : Bool,
  style : Int,
  stroke_width : Float,
  stroke_miter : Float,
  stroke_cap : Int,
  stroke_join : Int,
  blend_mode : Int,
) -> Unit = "moonbit_skia_canvas_draw_text_utf8"

///|
/// Native Skia image.
pub(all) struct Image {
  priv handle : ImageHandle
}

///|
/// Immutable encoded or raw byte data owned by Skia.
pub(all) struct Data {
  priv handle : DataHandle
}

///|
/// Native Skia codec for encoded image data.
pub(all) struct Codec {
  priv handle : CodecHandle
}

///|
/// Native Skia path.
pub(all) struct Path {
  priv handle : PathHandle
}

///|
/// Native Skia font.
pub(all) struct Font {
  priv handle : FontHandle
}

///|
/// Native Skia typeface.
pub(all) struct Typeface {
  priv handle : TypefaceHandle
}

///|
/// Native Skia shader.
pub(all) struct Shader {
  priv handle : ShaderHandle
}

///|
/// Native Skia bitmap with owned pixel storage.
pub(all) struct Bitmap {
  priv handle : BitmapHandle
}

///|
/// Native raster surface. The handle owns a Skia `SkSurface` when Skia is linked.
pub(all) struct Surface {
  priv handle : SurfaceHandle
}

///|
/// Canvas borrowed from a native surface.
pub(all) struct Canvas {
  priv handle : CanvasHandle
  priv owner : Surface?
}

///|
fn Data::from_handle(handle : DataHandle) -> Data? {
  if native_data_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn Data::from_bytes(bytes : Bytes) -> Data? {
  if bytes.is_empty() {
    None
  } else {
    Data::from_handle(native_data_from_bytes(bytes))
  }
}

///|
pub fn Data::is_available(self : Data) -> Bool {
  !native_data_is_null(self.handle)
}

///|
pub fn Data::size(self : Data) -> Int {
  native_data_size(self.handle)
}

///|
pub fn Data::is_empty(self : Data) -> Bool {
  self.size() == 0
}

///|
pub fn Data::to_bytes(self : Data) -> Bytes {
  native_data_to_bytes(self.handle)
}

///|
fn Codec::from_handle(handle : CodecHandle) -> Codec? {
  if native_codec_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn Codec::from_data(data : Data) -> Codec? {
  Codec::from_handle(native_codec_from_data(data.handle))
}

///|
pub fn Codec::from_bytes(bytes : Bytes) -> Codec? {
  match Data::from_bytes(bytes) {
    None => None
    Some(data) => Codec::from_data(data)
  }
}

///|
pub fn Codec::is_available(self : Codec) -> Bool {
  !native_codec_is_null(self.handle)
}

///|
pub fn Codec::width(self : Codec) -> Int {
  native_codec_width(self.handle)
}

///|
pub fn Codec::height(self : Codec) -> Int {
  native_codec_height(self.handle)
}

///|
pub fn Codec::dimensions(self : Codec) -> @skia.ISize {
  @skia.ISize::new(self.width(), self.height())
}

///|
pub fn Codec::image_info(self : Codec) -> @skia.ImageInfo {
  @skia.ImageInfo::n32_premul(self.dimensions())
}

///|
pub fn Codec::encoded_format(self : Codec) -> @skia.EncodedImageFormat? {
  @skia.EncodedImageFormat::from_skia_ordinal(
    native_codec_encoded_format(self.handle),
  )
}

///|
pub fn Codec::decode_n32_premul(self : Codec) -> Bitmap? {
  Bitmap::from_handle(native_codec_decode_n32_premul(self.handle))
}

///|
fn Image::from_handle(handle : ImageHandle) -> Image? {
  if native_image_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn Image::is_available(self : Image) -> Bool {
  !native_image_is_null(self.handle)
}

///|
pub fn Image::width(self : Image) -> Int {
  native_image_width(self.handle)
}

///|
pub fn Image::height(self : Image) -> Int {
  native_image_height(self.handle)
}

///|
pub fn Image::dimensions(self : Image) -> @skia.ISize {
  @skia.ISize::new(self.width(), self.height())
}

///|
pub fn Image::image_info(self : Image) -> @skia.ImageInfo {
  @skia.ImageInfo::n32_premul(self.dimensions())
}

///|
pub fn Image::from_bitmap(bitmap : Bitmap) -> Image? {
  Image::from_handle(native_image_from_bitmap(bitmap.handle))
}

///|
pub fn Image::from_encoded_data(data : Data) -> Image? {
  Image::from_handle(native_image_from_encoded_data(data.handle))
}

///|
pub fn Image::from_encoded_bytes(bytes : Bytes) -> Image? {
  match Data::from_bytes(bytes) {
    None => None
    Some(data) => Image::from_encoded_data(data)
  }
}

///|
pub fn Image::encode_to_data(
  self : Image,
  format? : @skia.EncodedImageFormat = @skia.PNG,
  quality? : Int = 100,
) -> Data? {
  Data::from_handle(
    native_image_encode_to_data(self.handle, format.to_skia_ordinal(), quality),
  )
}

///|
pub fn Path::new() -> Path? {
  let handle = native_path_new()
  if native_path_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn Path::is_available(self : Path) -> Bool {
  !native_path_is_null(self.handle)
}

///|
pub fn Path::reset(self : Path) -> Unit {
  native_path_reset(self.handle)
}

///|
pub fn Path::move_to(self : Path, point : @skia.Point) -> Unit {
  native_path_move_to(self.handle, point.x, point.y)
}

///|
pub fn Path::line_to(self : Path, point : @skia.Point) -> Unit {
  native_path_line_to(self.handle, point.x, point.y)
}

///|
pub fn Path::quad_to(
  self : Path,
  control : @skia.Point,
  end : @skia.Point,
) -> Unit {
  native_path_quad_to(self.handle, control.x, control.y, end.x, end.y)
}

///|
pub fn Path::cubic_to(
  self : Path,
  control0 : @skia.Point,
  control1 : @skia.Point,
  end : @skia.Point,
) -> Unit {
  native_path_cubic_to(
    self.handle,
    control0.x,
    control0.y,
    control1.x,
    control1.y,
    end.x,
    end.y,
  )
}

///|
pub fn Path::close(self : Path) -> Unit {
  native_path_close(self.handle)
}

///|
pub fn Path::is_empty(self : Path) -> Bool {
  native_path_is_empty(self.handle)
}

///|
fn Font::from_handle(handle : FontHandle) -> Font? {
  if native_font_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn Font::default(size? : Float = 12.0) -> Font? {
  if size <= 0.0 {
    None
  } else {
    Font::from_handle(native_font_default(size))
  }
}

///|
pub fn Font::from_typeface(typeface : Typeface, size? : Float = 12.0) -> Font? {
  if size <= 0.0 {
    None
  } else {
    Font::from_handle(native_font_from_typeface(typeface.handle, size))
  }
}

///|
pub fn Font::is_available(self : Font) -> Bool {
  !native_font_is_null(self.handle)
}

///|
pub fn Font::size(self : Font) -> Float {
  native_font_size(self.handle)
}

///|
pub fn Font::set_size(self : Font, size : Float) -> Unit {
  if size > 0.0 {
    native_font_set_size(self.handle, size)
  }
}

///|
fn Typeface::from_handle(handle : TypefaceHandle) -> Typeface? {
  if native_typeface_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn Typeface::default() -> Typeface? {
  Typeface::from_handle(native_typeface_default())
}

///|
pub fn Typeface::from_name(family_name : Bytes) -> Typeface? {
  if family_name.is_empty() {
    None
  } else {
    Typeface::from_handle(native_typeface_from_name(family_name))
  }
}

///|
pub fn Typeface::is_available(self : Typeface) -> Bool {
  !native_typeface_is_null(self.handle)
}

///|
pub fn Typeface::is_bold(self : Typeface) -> Bool {
  native_typeface_is_bold(self.handle)
}

///|
pub fn Typeface::is_italic(self : Typeface) -> Bool {
  native_typeface_is_italic(self.handle)
}

///|
pub fn Typeface::is_fixed_pitch(self : Typeface) -> Bool {
  native_typeface_is_fixed_pitch(self.handle)
}

///|
fn Shader::from_handle(handle : ShaderHandle) -> Shader? {
  if native_shader_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn Shader::color(color : @skia.Color) -> Shader? {
  Shader::from_handle(native_shader_color(color.argb()))
}

///|
pub fn Shader::linear_gradient(
  start : @skia.Point,
  end : @skia.Point,
  start_color : @skia.Color,
  end_color : @skia.Color,
  tile_mode? : @skia.TileMode = @skia.Clamp,
) -> Shader? {
  Shader::from_handle(
    native_shader_linear_gradient(
      start.x,
      start.y,
      end.x,
      end.y,
      start_color.argb(),
      end_color.argb(),
      tile_mode.to_skia_ordinal(),
    ),
  )
}

///|
pub fn Shader::radial_gradient(
  center : @skia.Point,
  radius : Float,
  inner_color : @skia.Color,
  outer_color : @skia.Color,
  tile_mode? : @skia.TileMode = @skia.Clamp,
) -> Shader? {
  if radius <= 0.0 {
    None
  } else {
    Shader::from_handle(
      native_shader_radial_gradient(
        center.x,
        center.y,
        radius,
        inner_color.argb(),
        outer_color.argb(),
        tile_mode.to_skia_ordinal(),
      ),
    )
  }
}

///|
pub fn Shader::is_available(self : Shader) -> Bool {
  !native_shader_is_null(self.handle)
}

///|
fn Bitmap::from_handle(handle : BitmapHandle) -> Bitmap? {
  if native_bitmap_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn Bitmap::alloc_n32_premul(size : @skia.ISize) -> Bitmap? {
  if size.is_empty() {
    None
  } else {
    Bitmap::from_handle(native_bitmap_alloc_n32_premul(size.width, size.height))
  }
}

///|
pub fn Bitmap::is_available(self : Bitmap) -> Bool {
  !native_bitmap_is_null(self.handle)
}

///|
pub fn Bitmap::width(self : Bitmap) -> Int {
  native_bitmap_width(self.handle)
}

///|
pub fn Bitmap::height(self : Bitmap) -> Int {
  native_bitmap_height(self.handle)
}

///|
pub fn Bitmap::dimensions(self : Bitmap) -> @skia.ISize {
  @skia.ISize::new(self.width(), self.height())
}

///|
pub fn Bitmap::image_info(self : Bitmap) -> @skia.ImageInfo {
  @skia.ImageInfo::n32_premul(self.dimensions())
}

///|
pub fn Bitmap::row_bytes(self : Bitmap) -> Int {
  native_bitmap_row_bytes(self.handle)
}

///|
pub fn Bitmap::byte_size(self : Bitmap) -> Int {
  native_bitmap_byte_size(self.handle)
}

///|
pub fn Bitmap::erase_color(self : Bitmap, color : @skia.Color) -> Unit {
  native_bitmap_erase_color(self.handle, color.argb())
}

///|
pub fn Bitmap::to_bytes(self : Bitmap) -> Bytes {
  native_bitmap_to_bytes(self.handle)
}

///|
pub fn Bitmap::to_pixmap(self : Bitmap) -> @skia.Pixmap? {
  @skia.Pixmap::new(self.image_info(), self.row_bytes(), self.to_bytes())
}

///|
pub fn Canvas::is_available(self : Canvas) -> Bool {
  ignore(self.owner)
  !native_canvas_is_null(self.handle)
}

///|
pub fn Canvas::save(self : Canvas) -> Int {
  native_canvas_save(self.handle)
}

///|
pub fn Canvas::restore(self : Canvas) -> Unit {
  native_canvas_restore(self.handle)
}

///|
pub fn Canvas::restore_to_count(self : Canvas, count : Int) -> Unit {
  native_canvas_restore_to_count(self.handle, count)
}

///|
pub fn Canvas::save_count(self : Canvas) -> Int {
  native_canvas_save_count(self.handle)
}

///|
pub fn Canvas::translate(self : Canvas, delta : @skia.Point) -> Unit {
  native_canvas_translate(self.handle, delta.x, delta.y)
}

///|
pub fn Canvas::scale(self : Canvas, scale : @skia.Size) -> Unit {
  native_canvas_scale(self.handle, scale.width, scale.height)
}

///|
pub fn Canvas::rotate(self : Canvas, degrees : Float) -> Unit {
  native_canvas_rotate(self.handle, degrees)
}

///|
pub fn Canvas::skew(self : Canvas, skew : @skia.Point) -> Unit {
  native_canvas_skew(self.handle, skew.x, skew.y)
}

///|
pub fn Canvas::concat(self : Canvas, matrix : @skia.Matrix) -> Unit {
  native_canvas_concat(
    self.handle,
    matrix.scale_x,
    matrix.skew_x,
    matrix.trans_x,
    matrix.skew_y,
    matrix.scale_y,
    matrix.trans_y,
    matrix.persp_0,
    matrix.persp_1,
    matrix.persp_2,
  )
}

///|
pub fn Canvas::reset_matrix(self : Canvas) -> Unit {
  native_canvas_reset_matrix(self.handle)
}

///|
pub fn Canvas::discard(self : Canvas) -> Unit {
  native_canvas_discard(self.handle)
}

///|
pub fn Canvas::clip_rect(
  self : Canvas,
  rect : @skia.Rect,
  op? : @skia.ClipOp = @skia.Intersect,
  anti_alias? : Bool = false,
) -> Unit {
  native_canvas_clip_rect(
    self.handle,
    rect.left,
    rect.top,
    rect.right,
    rect.bottom,
    op.to_skia_ordinal(),
    anti_alias,
  )
}

///|
pub fn Canvas::clip_path(
  self : Canvas,
  path : Path,
  op? : @skia.ClipOp = @skia.Intersect,
  anti_alias? : Bool = false,
) -> Unit {
  native_canvas_clip_path(
    self.handle,
    path.handle,
    op.to_skia_ordinal(),
    anti_alias,
  )
}

///|
pub fn Canvas::draw_color(
  self : Canvas,
  color : @skia.Color,
  blend_mode? : @skia.BlendMode = @skia.SrcOver,
) -> Unit {
  native_canvas_draw_color(
    self.handle,
    color.argb(),
    blend_mode.to_skia_ordinal(),
  )
}

///|
pub fn Canvas::clear(self : Canvas, color : @skia.Color) -> Unit {
  self.draw_color(color, blend_mode=@skia.Src)
}

///|
pub fn Canvas::draw_paint(self : Canvas, paint : @skia.Paint) -> Unit {
  native_canvas_draw_paint(
    self.handle,
    paint.color_argb(),
    paint.anti_alias,
    paint.dither,
    paint.style_ordinal(),
    paint.stroke_width,
    paint.stroke_miter,
    paint.stroke_cap_ordinal(),
    paint.stroke_join_ordinal(),
    paint.blend_mode_ordinal(),
  )
}

///|
pub fn Canvas::draw_point(
  self : Canvas,
  point : @skia.Point,
  paint : @skia.Paint,
) -> Unit {
  native_canvas_draw_point(
    self.handle,
    point.x,
    point.y,
    paint.color_argb(),
    paint.anti_alias,
    paint.dither,
    paint.style_ordinal(),
    paint.stroke_width,
    paint.stroke_miter,
    paint.stroke_cap_ordinal(),
    paint.stroke_join_ordinal(),
    paint.blend_mode_ordinal(),
  )
}

///|
pub fn Canvas::draw_line(
  self : Canvas,
  start : @skia.Point,
  end : @skia.Point,
  paint : @skia.Paint,
) -> Unit {
  native_canvas_draw_line(
    self.handle,
    start.x,
    start.y,
    end.x,
    end.y,
    paint.color_argb(),
    paint.anti_alias,
    paint.dither,
    paint.style_ordinal(),
    paint.stroke_width,
    paint.stroke_miter,
    paint.stroke_cap_ordinal(),
    paint.stroke_join_ordinal(),
    paint.blend_mode_ordinal(),
  )
}

///|
pub fn Canvas::draw_rect(
  self : Canvas,
  rect : @skia.Rect,
  paint : @skia.Paint,
) -> Unit {
  native_canvas_draw_rect(
    self.handle,
    rect.left,
    rect.top,
    rect.right,
    rect.bottom,
    paint.color_argb(),
    paint.anti_alias,
    paint.dither,
    paint.style_ordinal(),
    paint.stroke_width,
    paint.stroke_miter,
    paint.stroke_cap_ordinal(),
    paint.stroke_join_ordinal(),
    paint.blend_mode_ordinal(),
  )
}

///|
pub fn Canvas::draw_oval(
  self : Canvas,
  oval : @skia.Rect,
  paint : @skia.Paint,
) -> Unit {
  native_canvas_draw_oval(
    self.handle,
    oval.left,
    oval.top,
    oval.right,
    oval.bottom,
    paint.color_argb(),
    paint.anti_alias,
    paint.dither,
    paint.style_ordinal(),
    paint.stroke_width,
    paint.stroke_miter,
    paint.stroke_cap_ordinal(),
    paint.stroke_join_ordinal(),
    paint.blend_mode_ordinal(),
  )
}

///|
pub fn Canvas::draw_circle(
  self : Canvas,
  center : @skia.Point,
  radius : Float,
  paint : @skia.Paint,
) -> Unit {
  native_canvas_draw_circle(
    self.handle,
    center.x,
    center.y,
    radius,
    paint.color_argb(),
    paint.anti_alias,
    paint.dither,
    paint.style_ordinal(),
    paint.stroke_width,
    paint.stroke_miter,
    paint.stroke_cap_ordinal(),
    paint.stroke_join_ordinal(),
    paint.blend_mode_ordinal(),
  )
}

///|
pub fn Canvas::draw_arc(
  self : Canvas,
  oval : @skia.Rect,
  start_angle : Float,
  sweep_angle : Float,
  use_center : Bool,
  paint : @skia.Paint,
) -> Unit {
  native_canvas_draw_arc(
    self.handle,
    oval.left,
    oval.top,
    oval.right,
    oval.bottom,
    start_angle,
    sweep_angle,
    use_center,
    paint.color_argb(),
    paint.anti_alias,
    paint.dither,
    paint.style_ordinal(),
    paint.stroke_width,
    paint.stroke_miter,
    paint.stroke_cap_ordinal(),
    paint.stroke_join_ordinal(),
    paint.blend_mode_ordinal(),
  )
}

///|
pub fn Canvas::draw_round_rect(
  self : Canvas,
  rect : @skia.Rect,
  rx : Float,
  ry : Float,
  paint : @skia.Paint,
) -> Unit {
  native_canvas_draw_round_rect(
    self.handle,
    rect.left,
    rect.top,
    rect.right,
    rect.bottom,
    rx,
    ry,
    paint.color_argb(),
    paint.anti_alias,
    paint.dither,
    paint.style_ordinal(),
    paint.stroke_width,
    paint.stroke_miter,
    paint.stroke_cap_ordinal(),
    paint.stroke_join_ordinal(),
    paint.blend_mode_ordinal(),
  )
}

///|
pub fn Canvas::draw_path(
  self : Canvas,
  path : Path,
  paint : @skia.Paint,
) -> Unit {
  native_canvas_draw_path(
    self.handle,
    path.handle,
    paint.color_argb(),
    paint.anti_alias,
    paint.dither,
    paint.style_ordinal(),
    paint.stroke_width,
    paint.stroke_miter,
    paint.stroke_cap_ordinal(),
    paint.stroke_join_ordinal(),
    paint.blend_mode_ordinal(),
  )
}

///|
pub fn Canvas::draw_image(
  self : Canvas,
  image : Image,
  top_left : @skia.Point,
) -> Unit {
  native_canvas_draw_image(self.handle, image.handle, top_left.x, top_left.y)
}

///|
pub fn Canvas::draw_image_rect(
  self : Canvas,
  image : Image,
  src : @skia.Rect,
  dst : @skia.Rect,
  paint : @skia.Paint,
  sampling? : @skia.SamplingOptions = @skia.SamplingOptions::new(),
) -> Unit {
  native_canvas_draw_image_rect(
    self.handle,
    image.handle,
    src.left,
    src.top,
    src.right,
    src.bottom,
    dst.left,
    dst.top,
    dst.right,
    dst.bottom,
    paint.color_argb(),
    paint.anti_alias,
    paint.dither,
    paint.style_ordinal(),
    paint.stroke_width,
    paint.stroke_miter,
    paint.stroke_cap_ordinal(),
    paint.stroke_join_ordinal(),
    paint.blend_mode_ordinal(),
    sampling.filter_ordinal(),
    sampling.mipmap_ordinal(),
    sampling.uses_cubic(),
    sampling.cubic_b(),
    sampling.cubic_c(),
  )
}

///|
pub fn Canvas::draw_paint_shader(
  self : Canvas,
  shader : Shader,
  paint : @skia.Paint,
) -> Unit {
  native_canvas_draw_paint_shader(
    self.handle,
    shader.handle,
    paint.color_argb(),
    paint.anti_alias,
    paint.dither,
    paint.style_ordinal(),
    paint.stroke_width,
    paint.stroke_miter,
    paint.stroke_cap_ordinal(),
    paint.stroke_join_ordinal(),
    paint.blend_mode_ordinal(),
  )
}

///|
pub fn Canvas::draw_rect_shader(
  self : Canvas,
  rect : @skia.Rect,
  shader : Shader,
  paint : @skia.Paint,
) -> Unit {
  native_canvas_draw_rect_shader(
    self.handle,
    shader.handle,
    rect.left,
    rect.top,
    rect.right,
    rect.bottom,
    paint.color_argb(),
    paint.anti_alias,
    paint.dither,
    paint.style_ordinal(),
    paint.stroke_width,
    paint.stroke_miter,
    paint.stroke_cap_ordinal(),
    paint.stroke_join_ordinal(),
    paint.blend_mode_ordinal(),
  )
}

///|
pub fn Canvas::draw_text_utf8(
  self : Canvas,
  text : Bytes,
  origin : @skia.Point,
  font : Font,
  paint : @skia.Paint,
) -> Unit {
  if !text.is_empty() {
    native_canvas_draw_text_utf8(
      self.handle,
      text,
      origin.x,
      origin.y,
      font.handle,
      paint.color_argb(),
      paint.anti_alias,
      paint.dither,
      paint.style_ordinal(),
      paint.stroke_width,
      paint.stroke_miter,
      paint.stroke_cap_ordinal(),
      paint.stroke_join_ordinal(),
      paint.blend_mode_ordinal(),
    )
  }
}

///|
fn Surface::from_handle(handle : SurfaceHandle) -> Surface? {
  if native_surface_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
/// Allocate a raster N32 premultiplied surface.
///
/// Returns `None` when the native Skia backend is not linked or the size is empty.
pub fn Surface::raster_n32_premul(size : @skia.ISize) -> Surface? {
  if size.is_empty() {
    None
  } else {
    Surface::from_handle(
      native_surface_raster_n32_premul(size.width, size.height),
    )
  }
}

///|
pub fn Surface::width(self : Surface) -> Int {
  native_surface_width(self.handle)
}

///|
pub fn Surface::height(self : Surface) -> Int {
  native_surface_height(self.handle)
}

///|
pub fn Surface::dimensions(self : Surface) -> @skia.ISize {
  @skia.ISize::new(self.width(), self.height())
}

///|
pub fn Surface::image_info(self : Surface) -> @skia.ImageInfo {
  @skia.ImageInfo::n32_premul(self.dimensions())
}

///|
/// Snapshot current surface contents into an immutable image.
pub fn Surface::image_snapshot(self : Surface) -> Image? {
  Image::from_handle(native_surface_image_snapshot(self.handle))
}

///|
/// Snapshot a bounded rectangle of current surface contents into an image.
pub fn Surface::image_snapshot_with_bounds(
  self : Surface,
  bounds : @skia.IRect,
) -> Image? {
  if bounds.is_empty() {
    None
  } else {
    Image::from_handle(
      native_surface_image_snapshot_with_bounds(
        self.handle,
        bounds.left,
        bounds.top,
        bounds.right,
        bounds.bottom,
      ),
    )
  }
}

///|
/// Read surface pixels into an owned MoonBit `Pixmap`.
pub fn Surface::read_pixels(
  self : Surface,
  bounds? : @skia.IRect = self.image_info().bounds(),
) -> @skia.Pixmap? {
  if bounds.is_empty() {
    None
  } else {
    let info = @skia.ImageInfo::n32_premul(bounds.size())
    let row_bytes = info.min_row_bytes()
    let pixels = native_surface_read_pixels(
      self.handle,
      bounds.left,
      bounds.top,
      bounds.width(),
      bounds.height(),
    )
    @skia.Pixmap::new(info, row_bytes, pixels)
  }
}

///|
/// Borrow the surface canvas.
pub fn Surface::canvas(self : Surface) -> Canvas? {
  let handle = native_surface_canvas(self.handle)
  if native_canvas_is_null(handle) {
    None
  } else {
    Some({ handle, owner: Some(self) })
  }
}
