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
/// Opaque native Skia font manager handle.
priv type FontMgrHandle

///|
/// Opaque native Skia shader handle.
priv type ShaderHandle

///|
/// Opaque native Skia color-filter handle.
priv type ColorFilterHandle

///|
/// Opaque native Skia image-filter handle.
priv type ImageFilterHandle

///|
/// Opaque native Skia mask-filter handle.
priv type MaskFilterHandle

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
#borrow(font, text)
extern "C" fn native_font_measure_text_utf8(
  font : FontHandle,
  text : Bytes,
) -> Float = "moonbit_skia_font_measure_text_utf8"

///|
#borrow(font, text)
extern "C" fn native_font_count_text_utf8(
  font : FontHandle,
  text : Bytes,
) -> Int = "moonbit_skia_font_count_text_utf8"

///|
#borrow(font, text)
extern "C" fn native_font_text_to_glyphs_utf8(
  font : FontHandle,
  text : Bytes,
) -> Array[GlyphId] = "moonbit_skia_font_text_to_glyphs_utf8"

///|
#borrow(font)
extern "C" fn native_font_glyph_width(font : FontHandle, glyph : Int) -> Float = "moonbit_skia_font_glyph_width"

///|
#borrow(font, glyphs)
extern "C" fn native_font_glyph_widths(
  font : FontHandle,
  glyphs : Array[GlyphId],
) -> Array[Float] = "moonbit_skia_font_glyph_widths"

///|
#borrow(font, text)
extern "C" fn native_font_text_glyph_positions_utf8(
  font : FontHandle,
  text : Bytes,
  origin_x : Float,
  origin_y : Float,
) -> Array[@skia.Point] = "moonbit_skia_font_text_glyph_positions_utf8"

///|
#borrow(font, text)
extern "C" fn native_font_text_glyph_x_positions_utf8(
  font : FontHandle,
  text : Bytes,
  origin : Float,
) -> Array[Float] = "moonbit_skia_font_text_glyph_x_positions_utf8"

///|
#borrow(font)
extern "C" fn native_font_glyph_bounds_left(
  font : FontHandle,
  glyph : Int,
) -> Float = "moonbit_skia_font_glyph_bounds_left"

///|
#borrow(font)
extern "C" fn native_font_glyph_bounds_top(
  font : FontHandle,
  glyph : Int,
) -> Float = "moonbit_skia_font_glyph_bounds_top"

///|
#borrow(font)
extern "C" fn native_font_glyph_bounds_right(
  font : FontHandle,
  glyph : Int,
) -> Float = "moonbit_skia_font_glyph_bounds_right"

///|
#borrow(font)
extern "C" fn native_font_glyph_bounds_bottom(
  font : FontHandle,
  glyph : Int,
) -> Float = "moonbit_skia_font_glyph_bounds_bottom"

///|
#borrow(font, glyphs)
extern "C" fn native_font_glyph_bounds_many(
  font : FontHandle,
  glyphs : Array[GlyphId],
) -> Array[@skia.Rect] = "moonbit_skia_font_glyph_bounds_many"

///|
#borrow(font, text)
extern "C" fn native_font_measure_text_bounds_utf8(
  font : FontHandle,
  text : Bytes,
) -> Bool = "moonbit_skia_font_measure_text_bounds_utf8"

///|
#borrow(font, text)
extern "C" fn native_font_measure_text_bounds_utf8_left(
  font : FontHandle,
  text : Bytes,
) -> Float = "moonbit_skia_font_measure_text_bounds_utf8_left"

///|
#borrow(font, text)
extern "C" fn native_font_measure_text_bounds_utf8_top(
  font : FontHandle,
  text : Bytes,
) -> Float = "moonbit_skia_font_measure_text_bounds_utf8_top"

///|
#borrow(font, text)
extern "C" fn native_font_measure_text_bounds_utf8_right(
  font : FontHandle,
  text : Bytes,
) -> Float = "moonbit_skia_font_measure_text_bounds_utf8_right"

///|
#borrow(font, text)
extern "C" fn native_font_measure_text_bounds_utf8_bottom(
  font : FontHandle,
  text : Bytes,
) -> Float = "moonbit_skia_font_measure_text_bounds_utf8_bottom"

///|
#borrow(font)
extern "C" fn native_font_metrics_value(
  font : FontHandle,
  metric : Int,
) -> Float = "moonbit_skia_font_metrics_value"

///|
#borrow(font)
extern "C" fn native_font_metrics_has(font : FontHandle, metric : Int) -> Bool = "moonbit_skia_font_metrics_has"

///|
extern "C" fn native_typeface_default() -> TypefaceHandle = "moonbit_skia_typeface_default"

///|
extern "C" fn native_font_mgr_default() -> FontMgrHandle = "moonbit_skia_font_mgr_default"

///|
#borrow(font_mgr)
extern "C" fn native_font_mgr_is_null(font_mgr : FontMgrHandle) -> Bool = "moonbit_skia_font_mgr_is_null"

///|
#borrow(font_mgr)
extern "C" fn native_font_mgr_count_families(font_mgr : FontMgrHandle) -> Int = "moonbit_skia_font_mgr_count_families"

///|
#borrow(font_mgr)
extern "C" fn native_font_mgr_family_name(
  font_mgr : FontMgrHandle,
  index : Int,
) -> Bytes = "moonbit_skia_font_mgr_family_name"

///|
#borrow(font_mgr, family_name)
extern "C" fn native_font_mgr_match_family_style(
  font_mgr : FontMgrHandle,
  family_name : Bytes,
) -> TypefaceHandle = "moonbit_skia_font_mgr_match_family_style"

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
extern "C" fn native_color_filter_null() -> ColorFilterHandle = "moonbit_skia_color_filter_null"

///|
#borrow(color_filter)
extern "C" fn native_color_filter_is_null(
  color_filter : ColorFilterHandle,
) -> Bool = "moonbit_skia_color_filter_is_null"

///|
#borrow(values)
extern "C" fn native_color_filter_matrix(
  values : Array[Float],
) -> ColorFilterHandle = "moonbit_skia_color_filter_matrix"

///|
extern "C" fn native_image_filter_null() -> ImageFilterHandle = "moonbit_skia_image_filter_null"

///|
#borrow(image_filter)
extern "C" fn native_image_filter_is_null(
  image_filter : ImageFilterHandle,
) -> Bool = "moonbit_skia_image_filter_is_null"

///|
extern "C" fn native_image_filter_blur(
  sigma_x : Float,
  sigma_y : Float,
) -> ImageFilterHandle = "moonbit_skia_image_filter_blur"

///|
extern "C" fn native_mask_filter_null() -> MaskFilterHandle = "moonbit_skia_mask_filter_null"

///|
#borrow(mask_filter)
extern "C" fn native_mask_filter_is_null(
  mask_filter : MaskFilterHandle,
) -> Bool = "moonbit_skia_mask_filter_is_null"

///|
extern "C" fn native_mask_filter_blur(sigma : Float) -> MaskFilterHandle = "moonbit_skia_mask_filter_blur"

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
extern "C" fn native_path_rewind(path : PathHandle) -> Unit = "moonbit_skia_path_rewind"

///|
#borrow(path)
extern "C" fn native_path_set_fill_type(
  path : PathHandle,
  fill_type : Int,
) -> Unit = "moonbit_skia_path_set_fill_type"

///|
#borrow(path)
extern "C" fn native_path_fill_type(path : PathHandle) -> Int = "moonbit_skia_path_fill_type"

///|
#borrow(path)
extern "C" fn native_path_is_inverse_fill_type(path : PathHandle) -> Bool = "moonbit_skia_path_is_inverse_fill_type"

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
extern "C" fn native_path_conic_to(
  path : PathHandle,
  x1 : Float,
  y1 : Float,
  x2 : Float,
  y2 : Float,
  weight : Float,
) -> Unit = "moonbit_skia_path_conic_to"

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
extern "C" fn native_path_add_rect(
  path : PathHandle,
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
  direction : Int,
) -> Unit = "moonbit_skia_path_add_rect"

///|
#borrow(path)
extern "C" fn native_path_add_oval(
  path : PathHandle,
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
  direction : Int,
) -> Unit = "moonbit_skia_path_add_oval"

///|
#borrow(path)
extern "C" fn native_path_add_circle(
  path : PathHandle,
  x : Float,
  y : Float,
  radius : Float,
  direction : Int,
) -> Unit = "moonbit_skia_path_add_circle"

///|
#borrow(path)
extern "C" fn native_path_add_round_rect(
  path : PathHandle,
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
  rx : Float,
  ry : Float,
  direction : Int,
) -> Unit = "moonbit_skia_path_add_round_rect"

///|
#borrow(path)
extern "C" fn native_path_add_rrect(
  path : PathHandle,
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
  upper_left_width : Float,
  upper_left_height : Float,
  upper_right_width : Float,
  upper_right_height : Float,
  lower_right_width : Float,
  lower_right_height : Float,
  lower_left_width : Float,
  lower_left_height : Float,
  direction : Int,
) -> Unit = "moonbit_skia_path_add_rrect"

///|
#borrow(path)
extern "C" fn native_path_transform(
  path : PathHandle,
  scale_x : Float,
  skew_x : Float,
  trans_x : Float,
  skew_y : Float,
  scale_y : Float,
  trans_y : Float,
  persp_0 : Float,
  persp_1 : Float,
  persp_2 : Float,
) -> Unit = "moonbit_skia_path_transform"

///|
#borrow(path)
extern "C" fn native_path_offset(
  path : PathHandle,
  dx : Float,
  dy : Float,
) -> Unit = "moonbit_skia_path_offset"

///|
#borrow(path)
extern "C" fn native_path_contains(
  path : PathHandle,
  x : Float,
  y : Float,
) -> Bool = "moonbit_skia_path_contains"

///|
#borrow(path)
extern "C" fn native_path_is_empty(path : PathHandle) -> Bool = "moonbit_skia_path_is_empty"

///|
#borrow(path)
extern "C" fn native_path_is_finite(path : PathHandle) -> Bool = "moonbit_skia_path_is_finite"

///|
#borrow(path)
extern "C" fn native_path_count_points(path : PathHandle) -> Int = "moonbit_skia_path_count_points"

///|
#borrow(path)
extern "C" fn native_path_count_verbs(path : PathHandle) -> Int = "moonbit_skia_path_count_verbs"

///|
#borrow(path)
extern "C" fn native_path_segment_masks(path : PathHandle) -> Int = "moonbit_skia_path_segment_masks"

///|
#borrow(path)
extern "C" fn native_path_is_last_contour_closed(path : PathHandle) -> Bool = "moonbit_skia_path_is_last_contour_closed"

///|
#borrow(path)
extern "C" fn native_path_has_last_point(path : PathHandle) -> Bool = "moonbit_skia_path_has_last_point"

///|
#borrow(path)
extern "C" fn native_path_last_point_x(path : PathHandle) -> Float = "moonbit_skia_path_last_point_x"

///|
#borrow(path)
extern "C" fn native_path_last_point_y(path : PathHandle) -> Float = "moonbit_skia_path_last_point_y"

///|
#borrow(path)
extern "C" fn native_path_is_line(path : PathHandle) -> Bool = "moonbit_skia_path_is_line"

///|
#borrow(path)
extern "C" fn native_path_line_start_x(path : PathHandle) -> Float = "moonbit_skia_path_line_start_x"

///|
#borrow(path)
extern "C" fn native_path_line_start_y(path : PathHandle) -> Float = "moonbit_skia_path_line_start_y"

///|
#borrow(path)
extern "C" fn native_path_line_end_x(path : PathHandle) -> Float = "moonbit_skia_path_line_end_x"

///|
#borrow(path)
extern "C" fn native_path_line_end_y(path : PathHandle) -> Float = "moonbit_skia_path_line_end_y"

///|
#borrow(path)
extern "C" fn native_path_is_rect(path : PathHandle) -> Bool = "moonbit_skia_path_is_rect"

///|
#borrow(path)
extern "C" fn native_path_rect_left(path : PathHandle) -> Float = "moonbit_skia_path_rect_left"

///|
#borrow(path)
extern "C" fn native_path_rect_top(path : PathHandle) -> Float = "moonbit_skia_path_rect_top"

///|
#borrow(path)
extern "C" fn native_path_rect_right(path : PathHandle) -> Float = "moonbit_skia_path_rect_right"

///|
#borrow(path)
extern "C" fn native_path_rect_bottom(path : PathHandle) -> Float = "moonbit_skia_path_rect_bottom"

///|
#borrow(path)
extern "C" fn native_path_rect_is_closed(path : PathHandle) -> Bool = "moonbit_skia_path_rect_is_closed"

///|
#borrow(path)
extern "C" fn native_path_rect_direction(path : PathHandle) -> Int = "moonbit_skia_path_rect_direction"

///|
#borrow(path)
extern "C" fn native_path_is_oval(path : PathHandle) -> Bool = "moonbit_skia_path_is_oval"

///|
#borrow(path)
extern "C" fn native_path_oval_left(path : PathHandle) -> Float = "moonbit_skia_path_oval_left"

///|
#borrow(path)
extern "C" fn native_path_oval_top(path : PathHandle) -> Float = "moonbit_skia_path_oval_top"

///|
#borrow(path)
extern "C" fn native_path_oval_right(path : PathHandle) -> Float = "moonbit_skia_path_oval_right"

///|
#borrow(path)
extern "C" fn native_path_oval_bottom(path : PathHandle) -> Float = "moonbit_skia_path_oval_bottom"

///|
#borrow(path)
extern "C" fn native_path_bounds_left(path : PathHandle) -> Float = "moonbit_skia_path_bounds_left"

///|
#borrow(path)
extern "C" fn native_path_bounds_top(path : PathHandle) -> Float = "moonbit_skia_path_bounds_top"

///|
#borrow(path)
extern "C" fn native_path_bounds_right(path : PathHandle) -> Float = "moonbit_skia_path_bounds_right"

///|
#borrow(path)
extern "C" fn native_path_bounds_bottom(path : PathHandle) -> Float = "moonbit_skia_path_bounds_bottom"

///|
#borrow(path)
extern "C" fn native_path_tight_bounds_left(path : PathHandle) -> Float = "moonbit_skia_path_tight_bounds_left"

///|
#borrow(path)
extern "C" fn native_path_tight_bounds_top(path : PathHandle) -> Float = "moonbit_skia_path_tight_bounds_top"

///|
#borrow(path)
extern "C" fn native_path_tight_bounds_right(path : PathHandle) -> Float = "moonbit_skia_path_tight_bounds_right"

///|
#borrow(path)
extern "C" fn native_path_tight_bounds_bottom(path : PathHandle) -> Float = "moonbit_skia_path_tight_bounds_bottom"

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
#borrow(canvas, color_filter, image_filter, mask_filter)
extern "C" fn native_canvas_save_layer(
  canvas : CanvasHandle,
  has_bounds : Bool,
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
  color_filter : ColorFilterHandle,
  image_filter : ImageFilterHandle,
  mask_filter : MaskFilterHandle,
) -> Int = "moonbit_skia_canvas_save_layer"

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
#borrow(canvas)
extern "C" fn native_canvas_clip_rrect(
  canvas : CanvasHandle,
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
  upper_left_width : Float,
  upper_left_height : Float,
  upper_right_width : Float,
  upper_right_height : Float,
  lower_right_width : Float,
  lower_right_height : Float,
  lower_left_width : Float,
  lower_left_height : Float,
  op : Int,
  anti_alias : Bool,
) -> Unit = "moonbit_skia_canvas_clip_rrect"

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
extern "C" fn native_canvas_local_clip_bounds(canvas : CanvasHandle) -> Bool = "moonbit_skia_canvas_local_clip_bounds"

///|
#borrow(canvas)
extern "C" fn native_canvas_local_clip_bounds_left(
  canvas : CanvasHandle,
) -> Float = "moonbit_skia_canvas_local_clip_bounds_left"

///|
#borrow(canvas)
extern "C" fn native_canvas_local_clip_bounds_top(
  canvas : CanvasHandle,
) -> Float = "moonbit_skia_canvas_local_clip_bounds_top"

///|
#borrow(canvas)
extern "C" fn native_canvas_local_clip_bounds_right(
  canvas : CanvasHandle,
) -> Float = "moonbit_skia_canvas_local_clip_bounds_right"

///|
#borrow(canvas)
extern "C" fn native_canvas_local_clip_bounds_bottom(
  canvas : CanvasHandle,
) -> Float = "moonbit_skia_canvas_local_clip_bounds_bottom"

///|
#borrow(canvas)
extern "C" fn native_canvas_device_clip_bounds(canvas : CanvasHandle) -> Bool = "moonbit_skia_canvas_device_clip_bounds"

///|
#borrow(canvas)
extern "C" fn native_canvas_device_clip_bounds_left(
  canvas : CanvasHandle,
) -> Int = "moonbit_skia_canvas_device_clip_bounds_left"

///|
#borrow(canvas)
extern "C" fn native_canvas_device_clip_bounds_top(
  canvas : CanvasHandle,
) -> Int = "moonbit_skia_canvas_device_clip_bounds_top"

///|
#borrow(canvas)
extern "C" fn native_canvas_device_clip_bounds_right(
  canvas : CanvasHandle,
) -> Int = "moonbit_skia_canvas_device_clip_bounds_right"

///|
#borrow(canvas)
extern "C" fn native_canvas_device_clip_bounds_bottom(
  canvas : CanvasHandle,
) -> Int = "moonbit_skia_canvas_device_clip_bounds_bottom"

///|
#borrow(canvas)
extern "C" fn native_canvas_quick_reject_rect(
  canvas : CanvasHandle,
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
) -> Bool = "moonbit_skia_canvas_quick_reject_rect"

///|
#borrow(canvas, path)
extern "C" fn native_canvas_quick_reject_path(
  canvas : CanvasHandle,
  path : PathHandle,
) -> Bool = "moonbit_skia_canvas_quick_reject_path"

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
#borrow(canvas)
extern "C" fn native_canvas_draw_rrect(
  canvas : CanvasHandle,
  left : Float,
  top : Float,
  right : Float,
  bottom : Float,
  upper_left_width : Float,
  upper_left_height : Float,
  upper_right_width : Float,
  upper_right_height : Float,
  lower_right_width : Float,
  lower_right_height : Float,
  lower_left_width : Float,
  lower_left_height : Float,
  color_argb : UInt,
  anti_alias : Bool,
  dither : Bool,
  style : Int,
  stroke_width : Float,
  stroke_miter : Float,
  stroke_cap : Int,
  stroke_join : Int,
  blend_mode : Int,
) -> Unit = "moonbit_skia_canvas_draw_rrect"

///|
#borrow(canvas)
extern "C" fn native_canvas_draw_drrect(
  canvas : CanvasHandle,
  outer_left : Float,
  outer_top : Float,
  outer_right : Float,
  outer_bottom : Float,
  outer_upper_left_width : Float,
  outer_upper_left_height : Float,
  outer_upper_right_width : Float,
  outer_upper_right_height : Float,
  outer_lower_right_width : Float,
  outer_lower_right_height : Float,
  outer_lower_left_width : Float,
  outer_lower_left_height : Float,
  inner_left : Float,
  inner_top : Float,
  inner_right : Float,
  inner_bottom : Float,
  inner_upper_left_width : Float,
  inner_upper_left_height : Float,
  inner_upper_right_width : Float,
  inner_upper_right_height : Float,
  inner_lower_right_width : Float,
  inner_lower_right_height : Float,
  inner_lower_left_width : Float,
  inner_lower_left_height : Float,
  color_argb : UInt,
  anti_alias : Bool,
  dither : Bool,
  style : Int,
  stroke_width : Float,
  stroke_miter : Float,
  stroke_cap : Int,
  stroke_join : Int,
  blend_mode : Int,
) -> Unit = "moonbit_skia_canvas_draw_drrect"

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
#borrow(canvas, path, shader)
extern "C" fn native_canvas_draw_path_shader(
  canvas : CanvasHandle,
  path : PathHandle,
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
) -> Unit = "moonbit_skia_canvas_draw_path_shader"

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
#borrow(canvas, shader)
extern "C" fn native_canvas_draw_round_rect_shader(
  canvas : CanvasHandle,
  shader : ShaderHandle,
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
) -> Unit = "moonbit_skia_canvas_draw_round_rect_shader"

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
/// Native Skia glyph identifier.
pub(all) struct GlyphId(UInt16) derive(Debug, Eq)

///|
pub fn GlyphId::new(value : UInt16) -> GlyphId {
  GlyphId(value)
}

///|
pub fn GlyphId::to_uint16(self : GlyphId) -> UInt16 {
  let GlyphId(value) = self
  value
}

///|
pub fn GlyphId::to_int(self : GlyphId) -> Int {
  self.to_uint16().to_int()
}

///|
/// Native Skia font metrics in y-down coordinates.
pub(all) struct FontMetrics {
  top : Float
  ascent : Float
  descent : Float
  bottom : Float
  leading : Float
  average_char_width : Float
  max_char_width : Float
  x_min : Float
  x_max : Float
  x_height : Float
  cap_height : Float
  underline_thickness : Float?
  underline_position : Float?
  strikeout_thickness : Float?
  strikeout_position : Float?
  has_bounds : Bool
} derive(Debug, Eq)

///|
/// Native Skia typeface.
pub(all) struct Typeface {
  priv handle : TypefaceHandle
}

///|
/// Native Skia font manager.
pub(all) struct FontMgr {
  priv handle : FontMgrHandle
}

///|
/// Native Skia shader.
pub(all) struct Shader {
  priv handle : ShaderHandle
}

///|
/// Native Skia color filter.
pub(all) struct ColorFilter {
  priv handle : ColorFilterHandle
}

///|
/// Native Skia image filter.
pub(all) struct ImageFilter {
  priv handle : ImageFilterHandle
}

///|
/// Native Skia mask filter.
pub(all) struct MaskFilter {
  priv handle : MaskFilterHandle
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
fn ColorFilter::from_handle(handle : ColorFilterHandle) -> ColorFilter? {
  if native_color_filter_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn ColorFilter::matrix(values : Array[Float]) -> ColorFilter? {
  if values.length() != 20 {
    None
  } else {
    ColorFilter::from_handle(native_color_filter_matrix(values))
  }
}

///|
pub fn ColorFilter::saturation(amount : Float) -> ColorFilter? {
  if !skia_scalar_is_finite(amount) {
    None
  } else {
    let one : Float = 1.0
    let zero : Float = 0.0
    let inv = one - amount
    let r : Float = 0.2126 * inv
    let g : Float = 0.7152 * inv
    let b : Float = 0.0722 * inv
    ColorFilter::matrix([
      r + amount,
      g,
      b,
      zero,
      zero,
      r,
      g + amount,
      b,
      zero,
      zero,
      r,
      g,
      b + amount,
      zero,
      zero,
      zero,
      zero,
      zero,
      one,
      zero,
    ])
  }
}

///|
pub fn ColorFilter::brightness(amount : Float) -> ColorFilter? {
  if !skia_scalar_is_finite(amount) {
    None
  } else {
    let zero : Float = 0.0
    let one : Float = 1.0
    ColorFilter::matrix([
      amount, zero, zero, zero, zero, zero, amount, zero, zero, zero, zero, zero,
      amount, zero, zero, zero, zero, zero, one, zero,
    ])
  }
}

///|
pub fn ColorFilter::contrast(amount : Float) -> ColorFilter? {
  if !skia_scalar_is_finite(amount) {
    None
  } else {
    let zero : Float = 0.0
    let one : Float = 1.0
    let offset : Float = 0.5 * (one - amount)
    ColorFilter::matrix([
      amount, zero, zero, zero, offset, zero, amount, zero, zero, offset, zero, zero,
      amount, zero, offset, zero, zero, zero, one, zero,
    ])
  }
}

///|
pub fn ColorFilter::is_available(self : ColorFilter) -> Bool {
  !native_color_filter_is_null(self.handle)
}

///|
fn ImageFilter::from_handle(handle : ImageFilterHandle) -> ImageFilter? {
  if native_image_filter_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn ImageFilter::blur(sigma_x : Float, sigma_y : Float) -> ImageFilter? {
  if !skia_scalar_is_finite(sigma_x) ||
    !skia_scalar_is_finite(sigma_y) ||
    sigma_x <= 0.0 ||
    sigma_y <= 0.0 {
    None
  } else {
    ImageFilter::from_handle(native_image_filter_blur(sigma_x, sigma_y))
  }
}

///|
pub fn ImageFilter::is_available(self : ImageFilter) -> Bool {
  !native_image_filter_is_null(self.handle)
}

///|
fn MaskFilter::from_handle(handle : MaskFilterHandle) -> MaskFilter? {
  if native_mask_filter_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn MaskFilter::blur(sigma : Float) -> MaskFilter? {
  if !skia_scalar_is_finite(sigma) || sigma <= 0.0 {
    None
  } else {
    MaskFilter::from_handle(native_mask_filter_blur(sigma))
  }
}

///|
pub fn MaskFilter::is_available(self : MaskFilter) -> Bool {
  !native_mask_filter_is_null(self.handle)
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
pub fn Path::from_value(path : @skia.Path) -> Path? {
  match Path::new() {
    None => None
    Some(native_path) => {
      native_path.set_fill_type(path.fill_type)
      native_path.add_path_value(path)
      Some(native_path)
    }
  }
}

///|
pub fn Path::is_available(self : Path) -> Bool {
  !native_path_is_null(self.handle)
}

///|
pub fn Path::set_fill_type(self : Path, fill_type : @skia.PathFillType) -> Unit {
  native_path_set_fill_type(self.handle, fill_type.to_skia_ordinal())
}

///|
pub fn Path::fill_type(self : Path) -> @skia.PathFillType {
  match native_path_fill_type(self.handle) {
    1 => @skia.EvenOdd
    2 => @skia.InverseWinding
    3 => @skia.InverseEvenOdd
    _ => @skia.Winding
  }
}

///|
pub fn Path::is_inverse_fill_type(self : Path) -> Bool {
  native_path_is_inverse_fill_type(self.handle)
}

///|
pub fn Path::reset(self : Path) -> Unit {
  native_path_reset(self.handle)
}

///|
pub fn Path::rewind(self : Path) -> Unit {
  native_path_rewind(self.handle)
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
pub fn Path::conic_to(
  self : Path,
  control : @skia.Point,
  end : @skia.Point,
  weight : Float,
) -> Unit {
  native_path_conic_to(self.handle, control.x, control.y, end.x, end.y, weight)
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
pub fn Path::add_path_value(
  self : Path,
  path : @skia.Path,
  matrix? : @skia.Matrix = @skia.Matrix::identity(),
  mode? : @skia.AddPathMode = @skia.Append,
) -> Unit {
  let path = path.transform(matrix)
  let start_index = if mode is @skia.Extend && !path.verbs.is_empty() {
    match (self.last_point(), path.verbs[0]) {
      (Some(_), @skia.MoveTo(point)) => {
        self.line_to(point)
        1
      }
      _ => 0
    }
  } else {
    0
  }
  for i = start_index; i < path.verbs.length(); i = i + 1 {
    let verb = path.verbs[i]
    match verb {
      @skia.MoveTo(point) => self.move_to(point)
      @skia.LineTo(point) => self.line_to(point)
      @skia.QuadTo(control, end) => self.quad_to(control, end)
      @skia.ConicTo(control, end, weight) => self.conic_to(control, end, weight)
      @skia.CubicTo(control0, control1, end) =>
        self.cubic_to(control0, control1, end)
      @skia.Close => self.close()
    }
  }
}

///|
pub fn Path::add_path_value_matrix(
  self : Path,
  path : @skia.Path,
  matrix : @skia.Matrix,
  mode? : @skia.AddPathMode = @skia.Append,
) -> Unit {
  self.add_path_value(path, matrix~, mode~)
}

///|
pub fn Path::add_path_value_offset(
  self : Path,
  path : @skia.Path,
  offset : @skia.Point,
  mode? : @skia.AddPathMode = @skia.Append,
) -> Unit {
  self.add_path_value(
    path,
    matrix=@skia.Matrix::translate(offset.x, offset.y),
    mode~,
  )
}

///|
pub fn Path::add_poly(
  self : Path,
  points : Array[@skia.Point],
  close? : Bool = false,
) -> Unit {
  if !points.is_empty() {
    self.move_to(points[0])
    for i = 1; i < points.length(); i = i + 1 {
      self.line_to(points[i])
    }
    if close {
      self.close()
    }
  }
}

///|
pub fn Path::add_rect(
  self : Path,
  rect : @skia.Rect,
  direction? : @skia.PathDirection = @skia.CW,
) -> Unit {
  native_path_add_rect(
    self.handle,
    rect.left,
    rect.top,
    rect.right,
    rect.bottom,
    direction.to_skia_ordinal(),
  )
}

///|
pub fn Path::add_oval(
  self : Path,
  oval : @skia.Rect,
  direction? : @skia.PathDirection = @skia.CW,
) -> Unit {
  native_path_add_oval(
    self.handle,
    oval.left,
    oval.top,
    oval.right,
    oval.bottom,
    direction.to_skia_ordinal(),
  )
}

///|
pub fn Path::add_circle(
  self : Path,
  center : @skia.Point,
  radius : Float,
  direction? : @skia.PathDirection = @skia.CW,
) -> Unit {
  native_path_add_circle(
    self.handle,
    center.x,
    center.y,
    radius,
    direction.to_skia_ordinal(),
  )
}

///|
pub fn Path::add_round_rect(
  self : Path,
  rect : @skia.Rect,
  rx : Float,
  ry : Float,
  direction? : @skia.PathDirection = @skia.CW,
) -> Unit {
  native_path_add_round_rect(
    self.handle,
    rect.left,
    rect.top,
    rect.right,
    rect.bottom,
    rx,
    ry,
    direction.to_skia_ordinal(),
  )
}

///|
pub fn Path::add_rrect(
  self : Path,
  rrect : @skia.RRect,
  direction? : @skia.PathDirection = @skia.CW,
) -> Unit {
  native_path_add_rrect(
    self.handle,
    rrect.rect.left,
    rrect.rect.top,
    rrect.rect.right,
    rrect.rect.bottom,
    rrect.upper_left.width,
    rrect.upper_left.height,
    rrect.upper_right.width,
    rrect.upper_right.height,
    rrect.lower_right.width,
    rrect.lower_right.height,
    rrect.lower_left.width,
    rrect.lower_left.height,
    direction.to_skia_ordinal(),
  )
}

///|
pub fn Path::transform(self : Path, matrix : @skia.Matrix) -> Unit {
  native_path_transform(
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
pub fn Path::offset(self : Path, dx : Float, dy : Float) -> Unit {
  native_path_offset(self.handle, dx, dy)
}

///|
pub fn Path::contains(self : Path, point : @skia.Point) -> Bool {
  native_path_contains(self.handle, point.x, point.y)
}

///|
pub fn Path::is_empty(self : Path) -> Bool {
  native_path_is_empty(self.handle)
}

///|
pub fn Path::is_finite(self : Path) -> Bool {
  native_path_is_finite(self.handle)
}

///|
pub fn Path::count_points(self : Path) -> Int {
  native_path_count_points(self.handle)
}

///|
pub fn Path::count_verbs(self : Path) -> Int {
  native_path_count_verbs(self.handle)
}

///|
pub fn Path::segment_masks(self : Path) -> @skia.PathSegmentMask {
  @skia.PathSegmentMask::new(native_path_segment_masks(self.handle))
}

///|
pub fn Path::is_last_contour_closed(self : Path) -> Bool {
  native_path_is_last_contour_closed(self.handle)
}

///|
pub fn Path::last_point(self : Path) -> @skia.Point? {
  if native_path_has_last_point(self.handle) {
    Some(
      @skia.Point::new(
        native_path_last_point_x(self.handle),
        native_path_last_point_y(self.handle),
      ),
    )
  } else {
    None
  }
}

///|
pub fn Path::is_line(self : Path) -> @skia.PathLine? {
  if native_path_is_line(self.handle) {
    Some(
      @skia.PathLine::new(
        @skia.Point::new(
          native_path_line_start_x(self.handle),
          native_path_line_start_y(self.handle),
        ),
        @skia.Point::new(
          native_path_line_end_x(self.handle),
          native_path_line_end_y(self.handle),
        ),
      ),
    )
  } else {
    None
  }
}

///|
pub fn Path::is_rect(self : Path) -> @skia.PathRect? {
  if native_path_is_rect(self.handle) {
    let direction = match native_path_rect_direction(self.handle) {
      1 => @skia.CCW
      _ => @skia.CW
    }
    Some(
      @skia.PathRect::new(
        @skia.Rect::new(
          native_path_rect_left(self.handle),
          native_path_rect_top(self.handle),
          native_path_rect_right(self.handle),
          native_path_rect_bottom(self.handle),
        ),
        native_path_rect_is_closed(self.handle),
        direction,
      ),
    )
  } else {
    None
  }
}

///|
pub fn Path::is_oval(self : Path) -> @skia.Rect? {
  if native_path_is_oval(self.handle) {
    Some(
      @skia.Rect::new(
        native_path_oval_left(self.handle),
        native_path_oval_top(self.handle),
        native_path_oval_right(self.handle),
        native_path_oval_bottom(self.handle),
      ),
    )
  } else {
    None
  }
}

///|
pub fn Path::bounds(self : Path) -> @skia.Rect? {
  if self.is_empty() {
    None
  } else {
    Some(
      @skia.Rect::new(
        native_path_bounds_left(self.handle),
        native_path_bounds_top(self.handle),
        native_path_bounds_right(self.handle),
        native_path_bounds_bottom(self.handle),
      ),
    )
  }
}

///|
pub fn Path::compute_tight_bounds(self : Path) -> @skia.Rect? {
  if self.is_empty() {
    None
  } else {
    Some(
      @skia.Rect::new(
        native_path_tight_bounds_left(self.handle),
        native_path_tight_bounds_top(self.handle),
        native_path_tight_bounds_right(self.handle),
        native_path_tight_bounds_bottom(self.handle),
      ),
    )
  }
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
pub fn Font::measure_text_utf8(self : Font, text : Bytes) -> Float {
  if text.is_empty() {
    0.0
  } else {
    native_font_measure_text_utf8(self.handle, text)
  }
}

///|
pub fn Font::count_text_utf8(self : Font, text : Bytes) -> Int {
  if text.is_empty() {
    0
  } else {
    native_font_count_text_utf8(self.handle, text)
  }
}

///|
pub fn Font::text_to_glyphs_utf8(self : Font, text : Bytes) -> Array[GlyphId] {
  if text.is_empty() {
    []
  } else {
    native_font_text_to_glyphs_utf8(self.handle, text)
  }
}

///|
pub fn Font::glyph_width(self : Font, glyph : GlyphId) -> Float {
  native_font_glyph_width(self.handle, glyph.to_int())
}

///|
pub fn Font::glyph_widths(self : Font, glyphs : Array[GlyphId]) -> Array[Float] {
  if glyphs.is_empty() {
    []
  } else {
    native_font_glyph_widths(self.handle, glyphs)
  }
}

///|
pub fn Font::glyph_x_positions(
  self : Font,
  glyphs : Array[GlyphId],
  origin? : Float = 0.0,
) -> Array[Float] {
  let positions : Array[Float] = Array::new(capacity=glyphs.length())
  for x = origin, i = 0; i < glyphs.length(); i = i + 1 {
    positions.push(x)
    continue x + self.glyph_width(glyphs[i]), i + 1
  }
  positions
}

///|
pub fn Font::glyph_positions(
  self : Font,
  glyphs : Array[GlyphId],
  origin? : @skia.Point = @skia.Point::new(0.0, 0.0),
) -> Array[@skia.Point] {
  let positions : Array[@skia.Point] = Array::new(capacity=glyphs.length())
  let x_positions = self.glyph_x_positions(glyphs, origin=origin.x)
  for x in x_positions {
    positions.push(@skia.Point::new(x, origin.y))
  }
  positions
}

///|
pub fn Font::text_glyph_x_positions_utf8(
  self : Font,
  text : Bytes,
  origin? : Float = 0.0,
) -> Array[Float] {
  if text.is_empty() {
    []
  } else {
    native_font_text_glyph_x_positions_utf8(self.handle, text, origin)
  }
}

///|
pub fn Font::text_glyph_positions_utf8(
  self : Font,
  text : Bytes,
  origin? : @skia.Point = @skia.Point::new(0.0, 0.0),
) -> Array[@skia.Point] {
  if text.is_empty() {
    []
  } else {
    native_font_text_glyph_positions_utf8(self.handle, text, origin.x, origin.y)
  }
}

///|
pub fn Font::glyph_bounds(self : Font, glyph : GlyphId) -> @skia.Rect {
  let glyph_int = glyph.to_int()
  @skia.Rect::new(
    native_font_glyph_bounds_left(self.handle, glyph_int),
    native_font_glyph_bounds_top(self.handle, glyph_int),
    native_font_glyph_bounds_right(self.handle, glyph_int),
    native_font_glyph_bounds_bottom(self.handle, glyph_int),
  )
}

///|
pub fn Font::glyph_bounds_many(
  self : Font,
  glyphs : Array[GlyphId],
) -> Array[@skia.Rect] {
  if glyphs.is_empty() {
    []
  } else {
    native_font_glyph_bounds_many(self.handle, glyphs)
  }
}

///|
pub fn Font::measure_text_bounds_utf8(self : Font, text : Bytes) -> @skia.Rect? {
  if text.is_empty() || !native_font_measure_text_bounds_utf8(self.handle, text) {
    None
  } else {
    Some(
      @skia.Rect::new(
        native_font_measure_text_bounds_utf8_left(self.handle, text),
        native_font_measure_text_bounds_utf8_top(self.handle, text),
        native_font_measure_text_bounds_utf8_right(self.handle, text),
        native_font_measure_text_bounds_utf8_bottom(self.handle, text),
      ),
    )
  }
}

///|
fn font_metric_optional(font : FontHandle, metric : Int) -> Float? {
  if native_font_metrics_has(font, metric) {
    Some(native_font_metrics_value(font, metric))
  } else {
    None
  }
}

///|
pub fn Font::metrics(self : Font) -> FontMetrics {
  let font = self.handle
  {
    top: native_font_metrics_value(font, 0),
    ascent: native_font_metrics_value(font, 1),
    descent: native_font_metrics_value(font, 2),
    bottom: native_font_metrics_value(font, 3),
    leading: native_font_metrics_value(font, 4),
    average_char_width: native_font_metrics_value(font, 5),
    max_char_width: native_font_metrics_value(font, 6),
    x_min: native_font_metrics_value(font, 7),
    x_max: native_font_metrics_value(font, 8),
    x_height: native_font_metrics_value(font, 9),
    cap_height: native_font_metrics_value(font, 10),
    underline_thickness: font_metric_optional(font, 11),
    underline_position: font_metric_optional(font, 12),
    strikeout_thickness: font_metric_optional(font, 13),
    strikeout_position: font_metric_optional(font, 14),
    has_bounds: native_font_metrics_has(font, 15),
  }
}

///|
pub fn Font::spacing(self : Font) -> Float {
  let metrics = self.metrics()
  metrics.descent - metrics.ascent + metrics.leading
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
fn FontMgr::from_handle(handle : FontMgrHandle) -> FontMgr? {
  if native_font_mgr_is_null(handle) {
    None
  } else {
    Some({ handle, })
  }
}

///|
pub fn FontMgr::default() -> FontMgr? {
  FontMgr::from_handle(native_font_mgr_default())
}

///|
pub fn FontMgr::is_available(self : FontMgr) -> Bool {
  !native_font_mgr_is_null(self.handle)
}

///|
pub fn FontMgr::count_families(self : FontMgr) -> Int {
  native_font_mgr_count_families(self.handle)
}

///|
pub fn FontMgr::family_name(self : FontMgr, index : Int) -> Bytes? {
  if index < 0 || index >= self.count_families() {
    None
  } else {
    let name = native_font_mgr_family_name(self.handle, index)
    if name.is_empty() {
      None
    } else {
      Some(name)
    }
  }
}

///|
pub fn FontMgr::match_family_style(
  self : FontMgr,
  family_name : Bytes,
) -> Typeface? {
  if family_name.is_empty() {
    None
  } else {
    Typeface::from_handle(
      native_font_mgr_match_family_style(self.handle, family_name),
    )
  }
}

///|
pub fn Typeface::from_font_mgr_family(
  font_mgr : FontMgr,
  family_name : Bytes,
) -> Typeface? {
  font_mgr.match_family_style(family_name)
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
pub fn Canvas::save_layer(
  self : Canvas,
  bounds? : @skia.Rect? = None,
  paint? : @skia.Paint = @skia.Paint::new(),
  color_filter? : ColorFilter? = None,
  image_filter? : ImageFilter? = None,
  mask_filter? : MaskFilter? = None,
) -> Int {
  let color_filter_handle = match color_filter {
    Some(filter) => filter.handle
    None => native_color_filter_null()
  }
  let image_filter_handle = match image_filter {
    Some(filter) => filter.handle
    None => native_image_filter_null()
  }
  let mask_filter_handle = match mask_filter {
    Some(filter) => filter.handle
    None => native_mask_filter_null()
  }
  match bounds {
    None =>
      native_canvas_save_layer(
        self.handle,
        false,
        0,
        0,
        0,
        0,
        paint.color_argb(),
        paint.anti_alias,
        paint.dither,
        paint.style_ordinal(),
        paint.stroke_width,
        paint.stroke_miter,
        paint.stroke_cap_ordinal(),
        paint.stroke_join_ordinal(),
        paint.blend_mode_ordinal(),
        color_filter_handle,
        image_filter_handle,
        mask_filter_handle,
      )
    Some(rect) =>
      native_canvas_save_layer(
        self.handle,
        true,
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
        color_filter_handle,
        image_filter_handle,
        mask_filter_handle,
      )
  }
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
pub fn Canvas::clip_rrect(
  self : Canvas,
  rrect : @skia.RRect,
  op? : @skia.ClipOp = @skia.Intersect,
  anti_alias? : Bool = false,
) -> Unit {
  native_canvas_clip_rrect(
    self.handle,
    rrect.rect.left,
    rrect.rect.top,
    rrect.rect.right,
    rrect.rect.bottom,
    rrect.upper_left.width,
    rrect.upper_left.height,
    rrect.upper_right.width,
    rrect.upper_right.height,
    rrect.lower_right.width,
    rrect.lower_right.height,
    rrect.lower_left.width,
    rrect.lower_left.height,
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
pub fn Canvas::local_clip_bounds(self : Canvas) -> @skia.Rect? {
  if native_canvas_local_clip_bounds(self.handle) {
    Some(
      @skia.Rect::new(
        native_canvas_local_clip_bounds_left(self.handle),
        native_canvas_local_clip_bounds_top(self.handle),
        native_canvas_local_clip_bounds_right(self.handle),
        native_canvas_local_clip_bounds_bottom(self.handle),
      ),
    )
  } else {
    None
  }
}

///|
pub fn Canvas::device_clip_bounds(self : Canvas) -> @skia.IRect? {
  if native_canvas_device_clip_bounds(self.handle) {
    Some(
      @skia.IRect::new(
        native_canvas_device_clip_bounds_left(self.handle),
        native_canvas_device_clip_bounds_top(self.handle),
        native_canvas_device_clip_bounds_right(self.handle),
        native_canvas_device_clip_bounds_bottom(self.handle),
      ),
    )
  } else {
    None
  }
}

///|
pub fn Canvas::quick_reject_rect(self : Canvas, rect : @skia.Rect) -> Bool {
  native_canvas_quick_reject_rect(
    self.handle,
    rect.left,
    rect.top,
    rect.right,
    rect.bottom,
  )
}

///|
pub fn Canvas::quick_reject_path(self : Canvas, path : Path) -> Bool {
  native_canvas_quick_reject_path(self.handle, path.handle)
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
pub fn Canvas::draw_points(
  self : Canvas,
  points : Array[@skia.Point],
  paint : @skia.Paint,
  mode? : @skia.PointMode = @skia.Points,
) -> Unit {
  match mode {
    @skia.Points =>
      for point in points {
        self.draw_point(point, paint)
      }
    @skia.Lines =>
      for i = 0; i + 1 < points.length(); i = i + 2 {
        self.draw_line(points[i], points[i + 1], paint)
      }
    @skia.Polygon =>
      for i = 0; i + 1 < points.length(); i = i + 1 {
        self.draw_line(points[i], points[i + 1], paint)
      }
  }
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
pub fn Canvas::draw_rrect(
  self : Canvas,
  rrect : @skia.RRect,
  paint : @skia.Paint,
) -> Unit {
  native_canvas_draw_rrect(
    self.handle,
    rrect.rect.left,
    rrect.rect.top,
    rrect.rect.right,
    rrect.rect.bottom,
    rrect.upper_left.width,
    rrect.upper_left.height,
    rrect.upper_right.width,
    rrect.upper_right.height,
    rrect.lower_right.width,
    rrect.lower_right.height,
    rrect.lower_left.width,
    rrect.lower_left.height,
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
pub fn Canvas::draw_drrect(
  self : Canvas,
  outer : @skia.RRect,
  inner : @skia.RRect,
  paint : @skia.Paint,
) -> Unit {
  native_canvas_draw_drrect(
    self.handle,
    outer.rect.left,
    outer.rect.top,
    outer.rect.right,
    outer.rect.bottom,
    outer.upper_left.width,
    outer.upper_left.height,
    outer.upper_right.width,
    outer.upper_right.height,
    outer.lower_right.width,
    outer.lower_right.height,
    outer.lower_left.width,
    outer.lower_left.height,
    inner.rect.left,
    inner.rect.top,
    inner.rect.right,
    inner.rect.bottom,
    inner.upper_left.width,
    inner.upper_left.height,
    inner.upper_right.width,
    inner.upper_right.height,
    inner.lower_right.width,
    inner.lower_right.height,
    inner.lower_left.width,
    inner.lower_left.height,
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
pub fn Canvas::draw_path_shader(
  self : Canvas,
  path : Path,
  shader : Shader,
  paint : @skia.Paint,
) -> Unit {
  native_canvas_draw_path_shader(
    self.handle,
    path.handle,
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
pub fn Canvas::draw_path_value(
  self : Canvas,
  path : @skia.Path,
  paint : @skia.Paint,
) -> Unit {
  match Path::from_value(path) {
    None => ()
    Some(native_path) => self.draw_path(native_path, paint)
  }
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
pub fn Canvas::draw_round_rect_shader(
  self : Canvas,
  rect : @skia.Rect,
  rx : Float,
  ry : Float,
  shader : Shader,
  paint : @skia.Paint,
) -> Unit {
  native_canvas_draw_round_rect_shader(
    self.handle,
    shader.handle,
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

///|
fn skia_scalar_is_finite(value : Float) -> Bool {
  value == value && value - value == 0.0
}
