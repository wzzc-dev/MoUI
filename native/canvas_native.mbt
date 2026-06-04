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
#borrow(canvas, glyphs, positions, font)
extern "C" fn native_canvas_draw_glyphs(
  canvas : CanvasHandle,
  glyphs : Array[GlyphId],
  positions : Array[@skia.Point],
  origin_x : Float,
  origin_y : Float,
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
) -> Unit = "moonbit_skia_canvas_draw_glyphs"

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
  let bounds = match bounds {
    Some(rect) if rect.is_finite() => Some(rect)
    _ => None
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
        native_canvas_paint_stroke_width(paint),
        native_canvas_paint_stroke_miter(paint),
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
        native_canvas_paint_stroke_width(paint),
        native_canvas_paint_stroke_miter(paint),
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
fn native_canvas_scalar_is_finite(value : Float) -> Bool {
  value == value && value - value == 0.0
}

///|
fn native_canvas_paint_stroke_width(paint : @skia.Paint) -> Float {
  if native_canvas_scalar_is_finite(paint.stroke_width) {
    paint.stroke_width
  } else {
    0.0
  }
}

///|
fn native_canvas_paint_stroke_miter(paint : @skia.Paint) -> Float {
  if native_canvas_scalar_is_finite(paint.stroke_miter) {
    paint.stroke_miter
  } else {
    4.0
  }
}

///|
fn native_canvas_sampling_uses_cubic(sampling : @skia.SamplingOptions) -> Bool {
  sampling.uses_cubic() &&
  native_canvas_scalar_is_finite(sampling.cubic_b()) &&
  native_canvas_scalar_is_finite(sampling.cubic_c())
}

///|
fn native_canvas_sampling_cubic_b(sampling : @skia.SamplingOptions) -> Float {
  if native_canvas_sampling_uses_cubic(sampling) {
    sampling.cubic_b()
  } else {
    0.0
  }
}

///|
fn native_canvas_sampling_cubic_c(sampling : @skia.SamplingOptions) -> Float {
  if native_canvas_sampling_uses_cubic(sampling) {
    sampling.cubic_c()
  } else {
    0.0
  }
}

///|
fn native_canvas_rrect_is_finite(rrect : @skia.RRect) -> Bool {
  rrect.rect.is_finite() &&
  rrect.upper_left.is_finite() &&
  rrect.upper_right.is_finite() &&
  rrect.lower_right.is_finite() &&
  rrect.lower_left.is_finite()
}

///|
fn native_canvas_points_are_finite(points : Array[@skia.Point]) -> Bool {
  let mut finite = true
  for i = 0; i < points.length(); i = i + 1 {
    if !points[i].is_finite() {
      finite = false
    }
  }
  finite
}

///|
pub fn Canvas::translate(self : Canvas, delta : @skia.Point) -> Unit {
  if delta.is_finite() {
    native_canvas_translate(self.handle, delta.x, delta.y)
  }
}

///|
pub fn Canvas::scale(self : Canvas, scale : @skia.Size) -> Unit {
  if scale.is_finite() {
    native_canvas_scale(self.handle, scale.width, scale.height)
  }
}

///|
pub fn Canvas::rotate(self : Canvas, degrees : Float) -> Unit {
  if native_canvas_scalar_is_finite(degrees) {
    native_canvas_rotate(self.handle, degrees)
  }
}

///|
pub fn Canvas::skew(self : Canvas, skew : @skia.Point) -> Unit {
  if skew.is_finite() {
    native_canvas_skew(self.handle, skew.x, skew.y)
  }
}

///|
pub fn Canvas::concat(self : Canvas, matrix : @skia.Matrix) -> Unit {
  if matrix.is_finite() {
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
  op? : @skia.ClipOp = Intersect,
  anti_alias? : Bool = false,
) -> Unit {
  if rect.is_finite() {
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
}

///|
pub fn Canvas::clip_rrect(
  self : Canvas,
  rrect : @skia.RRect,
  op? : @skia.ClipOp = Intersect,
  anti_alias? : Bool = false,
) -> Unit {
  if native_canvas_rrect_is_finite(rrect) {
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
}

///|
pub fn Canvas::clip_path(
  self : Canvas,
  path : Path,
  op? : @skia.ClipOp = Intersect,
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
  rect.is_finite() &&
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
  blend_mode? : @skia.BlendMode = SrcOver,
) -> Unit {
  native_canvas_draw_color(
    self.handle,
    color.argb(),
    blend_mode.to_skia_ordinal(),
  )
}

///|
pub fn Canvas::clear(self : Canvas, color : @skia.Color) -> Unit {
  self.draw_color(color, blend_mode=Src)
}

///|
pub fn Canvas::draw_paint(self : Canvas, paint : @skia.Paint) -> Unit {
  native_canvas_draw_paint(
    self.handle,
    paint.color_argb(),
    paint.anti_alias,
    paint.dither,
    paint.style_ordinal(),
    native_canvas_paint_stroke_width(paint),
    native_canvas_paint_stroke_miter(paint),
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
  if point.is_finite() {
    native_canvas_draw_point(
      self.handle,
      point.x,
      point.y,
      paint.color_argb(),
      paint.anti_alias,
      paint.dither,
      paint.style_ordinal(),
      native_canvas_paint_stroke_width(paint),
      native_canvas_paint_stroke_miter(paint),
      paint.stroke_cap_ordinal(),
      paint.stroke_join_ordinal(),
      paint.blend_mode_ordinal(),
    )
  }
}

///|
pub fn Canvas::draw_line(
  self : Canvas,
  start : @skia.Point,
  end : @skia.Point,
  paint : @skia.Paint,
) -> Unit {
  if start.is_finite() && end.is_finite() {
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
      native_canvas_paint_stroke_width(paint),
      native_canvas_paint_stroke_miter(paint),
      paint.stroke_cap_ordinal(),
      paint.stroke_join_ordinal(),
      paint.blend_mode_ordinal(),
    )
  }
}

///|
pub fn Canvas::draw_points(
  self : Canvas,
  points : Array[@skia.Point],
  paint : @skia.Paint,
  mode? : @skia.PointMode = Points,
) -> Unit {
  match mode {
    Points =>
      for point in points {
        self.draw_point(point, paint)
      }
    Lines =>
      for i = 0; i + 1 < points.length(); i = i + 2 {
        self.draw_line(points[i], points[i + 1], paint)
      }
    Polygon =>
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
  if rect.is_finite() {
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
      native_canvas_paint_stroke_width(paint),
      native_canvas_paint_stroke_miter(paint),
      paint.stroke_cap_ordinal(),
      paint.stroke_join_ordinal(),
      paint.blend_mode_ordinal(),
    )
  }
}

///|
pub fn Canvas::draw_oval(
  self : Canvas,
  oval : @skia.Rect,
  paint : @skia.Paint,
) -> Unit {
  if oval.is_finite() {
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
      native_canvas_paint_stroke_width(paint),
      native_canvas_paint_stroke_miter(paint),
      paint.stroke_cap_ordinal(),
      paint.stroke_join_ordinal(),
      paint.blend_mode_ordinal(),
    )
  }
}

///|
pub fn Canvas::draw_circle(
  self : Canvas,
  center : @skia.Point,
  radius : Float,
  paint : @skia.Paint,
) -> Unit {
  if center.is_finite() &&
    native_canvas_scalar_is_finite(radius) &&
    radius > 0.0 {
    native_canvas_draw_circle(
      self.handle,
      center.x,
      center.y,
      radius,
      paint.color_argb(),
      paint.anti_alias,
      paint.dither,
      paint.style_ordinal(),
      native_canvas_paint_stroke_width(paint),
      native_canvas_paint_stroke_miter(paint),
      paint.stroke_cap_ordinal(),
      paint.stroke_join_ordinal(),
      paint.blend_mode_ordinal(),
    )
  }
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
  if oval.is_finite() &&
    native_canvas_scalar_is_finite(start_angle) &&
    native_canvas_scalar_is_finite(sweep_angle) {
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
      native_canvas_paint_stroke_width(paint),
      native_canvas_paint_stroke_miter(paint),
      paint.stroke_cap_ordinal(),
      paint.stroke_join_ordinal(),
      paint.blend_mode_ordinal(),
    )
  }
}

///|
pub fn Canvas::draw_round_rect(
  self : Canvas,
  rect : @skia.Rect,
  rx : Float,
  ry : Float,
  paint : @skia.Paint,
) -> Unit {
  if rect.is_finite() &&
    native_canvas_scalar_is_finite(rx) &&
    native_canvas_scalar_is_finite(ry) {
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
      native_canvas_paint_stroke_width(paint),
      native_canvas_paint_stroke_miter(paint),
      paint.stroke_cap_ordinal(),
      paint.stroke_join_ordinal(),
      paint.blend_mode_ordinal(),
    )
  }
}

///|
pub fn Canvas::draw_rrect(
  self : Canvas,
  rrect : @skia.RRect,
  paint : @skia.Paint,
) -> Unit {
  if native_canvas_rrect_is_finite(rrect) {
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
      native_canvas_paint_stroke_width(paint),
      native_canvas_paint_stroke_miter(paint),
      paint.stroke_cap_ordinal(),
      paint.stroke_join_ordinal(),
      paint.blend_mode_ordinal(),
    )
  }
}

///|
pub fn Canvas::draw_drrect(
  self : Canvas,
  outer : @skia.RRect,
  inner : @skia.RRect,
  paint : @skia.Paint,
) -> Unit {
  if native_canvas_rrect_is_finite(outer) &&
    native_canvas_rrect_is_finite(inner) {
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
      native_canvas_paint_stroke_width(paint),
      native_canvas_paint_stroke_miter(paint),
      paint.stroke_cap_ordinal(),
      paint.stroke_join_ordinal(),
      paint.blend_mode_ordinal(),
    )
  }
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
    native_canvas_paint_stroke_width(paint),
    native_canvas_paint_stroke_miter(paint),
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
    native_canvas_paint_stroke_width(paint),
    native_canvas_paint_stroke_miter(paint),
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
  if top_left.is_finite() {
    native_canvas_draw_image(self.handle, image.handle, top_left.x, top_left.y)
  }
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
  if src.is_finite() && dst.is_finite() {
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
      native_canvas_paint_stroke_width(paint),
      native_canvas_paint_stroke_miter(paint),
      paint.stroke_cap_ordinal(),
      paint.stroke_join_ordinal(),
      paint.blend_mode_ordinal(),
      sampling.filter_ordinal(),
      sampling.mipmap_ordinal(),
      native_canvas_sampling_uses_cubic(sampling),
      native_canvas_sampling_cubic_b(sampling),
      native_canvas_sampling_cubic_c(sampling),
    )
  }
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
    native_canvas_paint_stroke_width(paint),
    native_canvas_paint_stroke_miter(paint),
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
  if rect.is_finite() {
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
      native_canvas_paint_stroke_width(paint),
      native_canvas_paint_stroke_miter(paint),
      paint.stroke_cap_ordinal(),
      paint.stroke_join_ordinal(),
      paint.blend_mode_ordinal(),
    )
  }
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
  if rect.is_finite() &&
    native_canvas_scalar_is_finite(rx) &&
    native_canvas_scalar_is_finite(ry) {
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
      native_canvas_paint_stroke_width(paint),
      native_canvas_paint_stroke_miter(paint),
      paint.stroke_cap_ordinal(),
      paint.stroke_join_ordinal(),
      paint.blend_mode_ordinal(),
    )
  }
}

///|
pub fn Canvas::draw_text_utf8(
  self : Canvas,
  text : Bytes,
  origin : @skia.Point,
  font : Font,
  paint : @skia.Paint,
) -> Unit {
  if !text.is_empty() && origin.is_finite() {
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
      native_canvas_paint_stroke_width(paint),
      native_canvas_paint_stroke_miter(paint),
      paint.stroke_cap_ordinal(),
      paint.stroke_join_ordinal(),
      paint.blend_mode_ordinal(),
    )
  }
}

///|
pub fn Canvas::draw_glyphs(
  self : Canvas,
  glyphs : Array[GlyphId],
  positions : Array[@skia.Point],
  font : Font,
  paint : @skia.Paint,
  origin? : @skia.Point = @skia.Point::zero(),
) -> Unit {
  if !glyphs.is_empty() &&
    glyphs.length() == positions.length() &&
    origin.is_finite() &&
    native_canvas_points_are_finite(positions) {
    native_canvas_draw_glyphs(
      self.handle,
      glyphs,
      positions,
      origin.x,
      origin.y,
      font.handle,
      paint.color_argb(),
      paint.anti_alias,
      paint.dither,
      paint.style_ordinal(),
      native_canvas_paint_stroke_width(paint),
      native_canvas_paint_stroke_miter(paint),
      paint.stroke_cap_ordinal(),
      paint.stroke_join_ordinal(),
      paint.blend_mode_ordinal(),
    )
  }
}

///|
fn Canvas::replay_text_utf8(
  self : Canvas,
  text : Bytes,
  origin : @skia.Point,
  paint : @skia.Paint,
  font : Font?,
) -> Bool {
  let font = match font {
    Some(font) => Some(font)
    None => Font::default()
  }
  match font {
    None => false
    Some(font) => {
      self.draw_text_utf8(text, origin, font, paint)
      true
    }
  }
}

///|
fn native_replay_font(font : Font?) -> Font? {
  match font {
    Some(font) => Some(font)
    None => Font::default()
  }
}

///|
fn native_replay_font_from_resources(
  font_key : @skia.RendererResourceKey,
  font : Font?,
  resources : NativeReplayResources?,
) -> Font? {
  if font_key.kind != FontResource || font_key.is_empty() {
    native_replay_font(font)
  } else {
    match resources {
      None => native_replay_font(font)
      Some(resources) =>
        match resources.font_cache.get(font_key) {
          Some(font) => Some(font)
          None =>
            match native_replay_font(font) {
              None => None
              Some(font) => {
                ignore(resources.font_cache.insert(font_key, font))
                Some(font)
              }
            }
        }
    }
  }
}

///|
fn native_replay_typeface_from_resources(
  request : @skia.FontFallbackRequest,
  resources : NativeReplayResources?,
) -> Typeface? {
  let key = request.resource_key()
  if request.is_empty() || key.kind != TypefaceResource || key.is_empty() {
    None
  } else {
    match resources {
      None =>
        match FontMgr::default() {
          None => None
          Some(font_mgr) => font_mgr.match_fallback_request(request)
        }
      Some(resources) =>
        match resources.typeface_cache.get(key) {
          Some(typeface) => Some(typeface)
          None =>
            match FontMgr::default() {
              None => None
              Some(font_mgr) =>
                match font_mgr.match_fallback_request(request) {
                  None => None
                  Some(typeface) => {
                    ignore(
                      resources.typeface_cache.insert(
                        key,
                        typeface,
                        byte_size=request.resource_descriptor().byte_size,
                      ),
                    )
                    Some(typeface)
                  }
                }
            }
        }
    }
  }
}

///|
fn shaped_glyph_run_native_glyph_ids(
  glyph_run : @skia.ShapedGlyphRunDescriptor,
) -> Array[GlyphId] {
  let glyphs : Array[GlyphId] = Array::new(
    capacity=glyph_run.glyph_ids.length(),
  )
  for glyph_id in glyph_run.glyph_ids {
    glyphs.push(GlyphId::new(glyph_id.clamp(min=0, max=65535).to_uint16()))
  }
  glyphs
}

///|
fn native_text_run_from_resources(
  text : Bytes,
  descriptor : @skia.TextRunDescriptor,
  font_key : @skia.RendererResourceKey,
  font : Font,
  resources : NativeReplayResources?,
) -> NativeReplayTextRun {
  let key = descriptor.resource_key(text, font_key~)
  let shaping = @skia.TextShapingDescriptor::new(run=descriptor, font_key~)
  match resources {
    None =>
      match font.shape_text_run_utf8(text, shaping) {
        None => DirectTextRun(descriptor)
        Some(glyph_run) => ShapedTextRun(glyph_run)
      }
    Some(resources) =>
      match resources.text_run_cache.get(key) {
        Some(replay_text_run) => replay_text_run
        None => {
          let replay_text_run = match font.shape_text_run_utf8(text, shaping) {
            None => DirectTextRun(descriptor)
            Some(glyph_run) => ShapedTextRun(glyph_run)
          }
          ignore(
            resources.text_run_cache.insert(
              key,
              replay_text_run,
              byte_size=descriptor.resource_descriptor(text, font_key~).byte_size,
            ),
          )
          replay_text_run
        }
      }
  }
}

///|
fn Canvas::replay_text_run_utf8(
  self : Canvas,
  text : Bytes,
  descriptor : @skia.TextRunDescriptor,
  font_key : @skia.RendererResourceKey,
  origin : @skia.Point,
  paint : @skia.Paint,
  font : Font?,
  resources : NativeReplayResources?,
) -> Bool {
  let run_text = text_run_bytes_for_shaping(text, descriptor)
  if run_text.is_empty() || descriptor.is_empty() {
    false
  } else {
    ignore(
      native_replay_typeface_from_resources(descriptor.fallback, resources),
    )
    match native_replay_font_from_resources(font_key, font, resources) {
      None => false
      Some(font) =>
        match
          native_text_run_from_resources(
            text, descriptor, font_key, font, resources,
          ) {
          DirectTextRun(_) => {
            self.draw_text_utf8(run_text, origin, font, paint)
            true
          }
          ShapedTextRun(glyph_run) =>
            self.replay_shaped_glyph_run_utf8(
              glyph_run,
              origin,
              paint,
              Some(font),
            )
        }
    }
  }
}

///|
fn Canvas::replay_shaped_glyph_run_utf8(
  self : Canvas,
  glyph_run : @skia.ShapedGlyphRunDescriptor,
  origin : @skia.Point,
  paint : @skia.Paint,
  font : Font?,
) -> Bool {
  let font = match font {
    Some(font) => Some(font)
    None => Font::default()
  }
  match font {
    None => false
    Some(font) =>
      if !glyph_run.is_valid() {
        false
      } else {
        self.draw_glyphs(
          shaped_glyph_run_native_glyph_ids(glyph_run),
          glyph_run.positions,
          font,
          paint,
          origin~,
        )
        true
      }
  }
}

///|
fn native_path_from_value(
  path : @skia.Path,
  resources : NativeReplayResources?,
) -> Path? {
  if !path.is_finite() {
    None
  } else {
    match resources {
      None => Path::from_value(path)
      Some(resources) => {
        let descriptor = path.resource_descriptor()
        if !descriptor.is_cacheable() {
          Path::from_value(path)
        } else {
          match resources.path_cache.get(descriptor.key) {
            Some(native_path) => Some(native_path)
            None =>
              match Path::from_value(path) {
                None => None
                Some(native_path) => {
                  ignore(
                    resources.path_cache.insert(
                      descriptor.key,
                      native_path,
                      byte_size=descriptor.byte_size,
                    ),
                  )
                  Some(native_path)
                }
              }
          }
        }
      }
    }
  }
}

///|
fn Canvas::replay_path_value(
  self : Canvas,
  path : @skia.Path,
  paint : @skia.Paint,
  resources : NativeReplayResources?,
) -> Bool {
  match native_path_from_value(path, resources) {
    None => false
    Some(native_path) => {
      self.draw_path(native_path, paint)
      true
    }
  }
}

///|
fn Canvas::replay_clip_path(
  self : Canvas,
  path : @skia.Path,
  op : @skia.ClipOp,
  resources : NativeReplayResources?,
) -> Bool {
  match native_path_from_value(path, resources) {
    None => false
    Some(native_path) => {
      self.clip_path(native_path, op~)
      true
    }
  }
}

///|
fn native_shader_from_descriptor(
  descriptor : @skia.ShaderDescriptor,
) -> Shader? {
  match descriptor {
    ColorShader(color) => Shader::color(color)
    LinearGradientShader(start, end, start_color, end_color, tile_mode) =>
      Shader::linear_gradient(start, end, start_color, end_color, tile_mode~)
    RadialGradientShader(center, radius, inner_color, outer_color, tile_mode) =>
      Shader::radial_gradient(
        center,
        radius,
        inner_color,
        outer_color,
        tile_mode~,
      )
  }
}

///|
fn native_shader_from_resources(
  descriptor : @skia.ShaderDescriptor,
  resources : NativeReplayResources?,
) -> Shader? {
  let key = descriptor.resource_key()
  if key.is_empty() || !descriptor.is_valid() {
    native_shader_from_descriptor(descriptor)
  } else {
    match resources {
      None => native_shader_from_descriptor(descriptor)
      Some(resources) =>
        match resources.shader_cache.get(key) {
          Some(shader) => Some(shader)
          None =>
            match native_shader_from_descriptor(descriptor) {
              None => None
              Some(shader) => {
                ignore(
                  resources.shader_cache.insert(
                    key,
                    shader,
                    byte_size=descriptor.resource_descriptor().byte_size,
                  ),
                )
                Some(shader)
              }
            }
        }
    }
  }
}

///|
fn Canvas::replay_paint_shader(
  self : Canvas,
  shader_descriptor : @skia.ShaderDescriptor,
  paint : @skia.Paint,
  resources : NativeReplayResources?,
) -> Bool {
  match native_shader_from_resources(shader_descriptor, resources) {
    None => false
    Some(shader) => {
      self.draw_paint_shader(shader, paint)
      true
    }
  }
}

///|
fn Canvas::replay_rect_shader(
  self : Canvas,
  rect : @skia.Rect,
  shader_descriptor : @skia.ShaderDescriptor,
  paint : @skia.Paint,
  resources : NativeReplayResources?,
) -> Bool {
  match native_shader_from_resources(shader_descriptor, resources) {
    None => false
    Some(shader) => {
      self.draw_rect_shader(rect, shader, paint)
      true
    }
  }
}

///|
fn Canvas::replay_round_rect_shader(
  self : Canvas,
  rect : @skia.Rect,
  rx : Float,
  ry : Float,
  shader_descriptor : @skia.ShaderDescriptor,
  paint : @skia.Paint,
  resources : NativeReplayResources?,
) -> Bool {
  match native_shader_from_resources(shader_descriptor, resources) {
    None => false
    Some(shader) => {
      self.draw_round_rect_shader(rect, rx, ry, shader, paint)
      true
    }
  }
}

///|
fn Canvas::replay_path_shader(
  self : Canvas,
  path : @skia.Path,
  shader_descriptor : @skia.ShaderDescriptor,
  paint : @skia.Paint,
  resources : NativeReplayResources?,
) -> Bool {
  match native_path_from_value(path, resources) {
    None => false
    Some(native_path) =>
      match native_shader_from_resources(shader_descriptor, resources) {
        None => false
        Some(shader) => {
          self.draw_path_shader(native_path, shader, paint)
          true
        }
      }
  }
}

///|
fn native_image_decode_descriptor(descriptor : @skia.ImageDescriptor) -> Image? {
  match descriptor {
    EncodedImage(bytes, _, _) => Image::from_encoded_bytes(bytes)
  }
}

///|
fn native_image_from_descriptor(
  descriptor : @skia.ImageDescriptor,
  resources : NativeReplayResources?,
) -> Image? {
  let key = descriptor.resource_key()
  if key.is_empty() {
    native_image_decode_descriptor(descriptor)
  } else {
    match resources {
      None => native_image_decode_descriptor(descriptor)
      Some(resources) =>
        match resources.image_cache.get(key) {
          Some(image) => Some(image)
          None =>
            match native_image_decode_descriptor(descriptor) {
              None => None
              Some(image) => {
                ignore(
                  resources.image_cache.insert(
                    key,
                    image,
                    byte_size=descriptor.byte_size(),
                  ),
                )
                Some(image)
              }
            }
        }
    }
  }
}

///|
fn Canvas::replay_image(
  self : Canvas,
  descriptor : @skia.ImageDescriptor,
  top_left : @skia.Point,
  resources : NativeReplayResources?,
) -> Bool {
  match native_image_from_descriptor(descriptor, resources) {
    None => false
    Some(image) => {
      self.draw_image(image, top_left)
      true
    }
  }
}

///|
fn Canvas::replay_image_rect(
  self : Canvas,
  descriptor : @skia.ImageDescriptor,
  src : @skia.Rect,
  dst : @skia.Rect,
  paint : @skia.Paint,
  sampling : @skia.SamplingOptions,
  resources : NativeReplayResources?,
) -> Bool {
  match native_image_from_descriptor(descriptor, resources) {
    None => false
    Some(image) => {
      self.draw_image_rect(image, src, dst, paint, sampling~)
      true
    }
  }
}

///|
fn native_color_filter_from_descriptor(
  descriptor : @skia.ColorFilterDescriptor,
) -> ColorFilter? {
  match descriptor {
    ColorMatrixFilter(values) => ColorFilter::matrix(values)
    SaturationFilter(amount) => ColorFilter::saturation(amount)
    BrightnessFilter(amount) => ColorFilter::brightness(amount)
    ContrastFilter(amount) => ColorFilter::contrast(amount)
  }
}

///|
fn native_color_filter_from_resources(
  descriptor : @skia.ColorFilterDescriptor,
  resources : NativeReplayResources?,
) -> ColorFilter? {
  let key = descriptor.resource_key()
  if key.is_empty() || !descriptor.is_valid() {
    native_color_filter_from_descriptor(descriptor)
  } else {
    match resources {
      None => native_color_filter_from_descriptor(descriptor)
      Some(resources) =>
        match resources.color_filter_cache.get(key) {
          Some(filter) => Some(filter)
          None =>
            match native_color_filter_from_descriptor(descriptor) {
              None => None
              Some(filter) => {
                ignore(
                  resources.color_filter_cache.insert(
                    key,
                    filter,
                    byte_size=descriptor.resource_descriptor().byte_size,
                  ),
                )
                Some(filter)
              }
            }
        }
    }
  }
}

///|
fn native_image_filter_from_descriptor(
  descriptor : @skia.ImageFilterDescriptor,
) -> ImageFilter? {
  match descriptor {
    BlurImageFilter(sigma_x, sigma_y) => ImageFilter::blur(sigma_x, sigma_y)
  }
}

///|
fn native_image_filter_from_resources(
  descriptor : @skia.ImageFilterDescriptor,
  resources : NativeReplayResources?,
) -> ImageFilter? {
  let key = descriptor.resource_key()
  if key.is_empty() || !descriptor.is_valid() {
    native_image_filter_from_descriptor(descriptor)
  } else {
    match resources {
      None => native_image_filter_from_descriptor(descriptor)
      Some(resources) =>
        match resources.image_filter_cache.get(key) {
          Some(filter) => Some(filter)
          None =>
            match native_image_filter_from_descriptor(descriptor) {
              None => None
              Some(filter) => {
                ignore(
                  resources.image_filter_cache.insert(
                    key,
                    filter,
                    byte_size=descriptor.resource_descriptor().byte_size,
                  ),
                )
                Some(filter)
              }
            }
        }
    }
  }
}

///|
fn native_mask_filter_from_descriptor(
  descriptor : @skia.MaskFilterDescriptor,
) -> MaskFilter? {
  match descriptor {
    BlurMaskFilter(sigma) => MaskFilter::blur(sigma)
  }
}

///|
fn native_mask_filter_from_resources(
  descriptor : @skia.MaskFilterDescriptor,
  resources : NativeReplayResources?,
) -> MaskFilter? {
  let key = descriptor.resource_key()
  if key.is_empty() || !descriptor.is_valid() {
    native_mask_filter_from_descriptor(descriptor)
  } else {
    match resources {
      None => native_mask_filter_from_descriptor(descriptor)
      Some(resources) =>
        match resources.mask_filter_cache.get(key) {
          Some(filter) => Some(filter)
          None =>
            match native_mask_filter_from_descriptor(descriptor) {
              None => None
              Some(filter) => {
                ignore(
                  resources.mask_filter_cache.insert(
                    key,
                    filter,
                    byte_size=descriptor.resource_descriptor().byte_size,
                  ),
                )
                Some(filter)
              }
            }
        }
    }
  }
}

///|
fn Canvas::replay_save_layer(
  self : Canvas,
  bounds : @skia.Rect?,
  paint : @skia.Paint,
  color_filter : @skia.ColorFilterDescriptor?,
  image_filter : @skia.ImageFilterDescriptor?,
  mask_filter : @skia.MaskFilterDescriptor?,
  resources : NativeReplayResources?,
) -> Bool {
  let mut failed = false
  let mut color_filter_handle : ColorFilter? = None
  match color_filter {
    None => ()
    Some(descriptor) =>
      match native_color_filter_from_resources(descriptor, resources) {
        None => failed = true
        Some(filter) => color_filter_handle = Some(filter)
      }
  }
  let mut image_filter_handle : ImageFilter? = None
  match image_filter {
    None => ()
    Some(descriptor) =>
      match native_image_filter_from_resources(descriptor, resources) {
        None => failed = true
        Some(filter) => image_filter_handle = Some(filter)
      }
  }
  let mut mask_filter_handle : MaskFilter? = None
  match mask_filter {
    None => ()
    Some(descriptor) =>
      match native_mask_filter_from_resources(descriptor, resources) {
        None => failed = true
        Some(filter) => mask_filter_handle = Some(filter)
      }
  }
  if failed {
    false
  } else {
    self.save_layer(
      bounds~,
      paint~,
      color_filter=color_filter_handle,
      image_filter=image_filter_handle,
      mask_filter=mask_filter_handle,
    ) >
    0
  }
}

///|
fn Canvas::replay_command(
  self : Canvas,
  command : @skia.RenderCommand,
  font : Font?,
  resources : NativeReplayResources?,
) -> Bool {
  match command {
    SaveCanvas => {
      ignore(self.save())
      true
    }
    RestoreCanvas => {
      self.restore()
      true
    }
    SaveCanvasLayer(bounds, paint, color_filter, image_filter, mask_filter) =>
      self.replay_save_layer(
        bounds, paint, color_filter, image_filter, mask_filter, resources,
      )
    TranslateCanvas(delta) => {
      self.translate(delta)
      true
    }
    ScaleCanvas(scale) => {
      self.scale(scale)
      true
    }
    RotateCanvas(degrees) => {
      self.rotate(degrees)
      true
    }
    SkewCanvas(skew) => {
      self.skew(skew)
      true
    }
    ConcatCanvas(matrix) => {
      self.concat(matrix)
      true
    }
    ResetCanvasMatrix => {
      self.reset_matrix()
      true
    }
    ClearCanvas(color) => {
      self.clear(color)
      true
    }
    DrawCanvasColor(color, blend_mode) => {
      self.draw_color(color, blend_mode~)
      true
    }
    DrawCanvasPaint(paint) => {
      self.draw_paint(paint)
      true
    }
    DrawCanvasPaintShader(shader_descriptor, paint) =>
      self.replay_paint_shader(shader_descriptor, paint, resources)
    ClipCanvasRect(rect, op) => {
      self.clip_rect(rect, op~)
      true
    }
    ClipCanvasRRect(rrect, op) => {
      self.clip_rrect(rrect, op~)
      true
    }
    ClipCanvasPath(path, op) => self.replay_clip_path(path, op, resources)
    DrawCanvasPoint(point, paint) => {
      self.draw_point(point, paint)
      true
    }
    DrawCanvasLine(start, end, paint) => {
      self.draw_line(start, end, paint)
      true
    }
    DrawCanvasPoints(points, mode, paint) => {
      self.draw_points(points, paint, mode~)
      true
    }
    DrawCanvasRect(rect, paint) => {
      self.draw_rect(rect, paint)
      true
    }
    DrawCanvasOval(oval, paint) => {
      self.draw_oval(oval, paint)
      true
    }
    DrawCanvasCircle(center, radius, paint) => {
      self.draw_circle(center, radius, paint)
      true
    }
    DrawCanvasArc(oval, start_angle, sweep_angle, use_center, paint) => {
      self.draw_arc(oval, start_angle, sweep_angle, use_center, paint)
      true
    }
    DrawCanvasRoundRect(rect, rx, ry, paint) => {
      self.draw_round_rect(rect, rx, ry, paint)
      true
    }
    DrawCanvasRRect(rrect, paint) => {
      self.draw_rrect(rrect, paint)
      true
    }
    DrawCanvasDRRect(outer, inner, paint) => {
      self.draw_drrect(outer, inner, paint)
      true
    }
    DrawCanvasRectShader(rect, shader_descriptor, paint) =>
      self.replay_rect_shader(rect, shader_descriptor, paint, resources)
    DrawCanvasRoundRectShader(rect, rx, ry, shader_descriptor, paint) =>
      self.replay_round_rect_shader(
        rect, rx, ry, shader_descriptor, paint, resources,
      )
    DrawCanvasPath(path, paint) =>
      self.replay_path_value(path, paint, resources)
    DrawCanvasPathShader(path, shader_descriptor, paint) =>
      self.replay_path_shader(path, shader_descriptor, paint, resources)
    DrawCanvasImage(image_descriptor, top_left) =>
      self.replay_image(image_descriptor, top_left, resources)
    DrawCanvasImageRect(image_descriptor, src, dst, paint, sampling) =>
      self.replay_image_rect(
        image_descriptor, src, dst, paint, sampling, resources,
      )
    DrawCanvasTextUtf8(text, origin, paint) =>
      self.replay_text_utf8(text, origin, paint, font)
    DrawCanvasTextRunUtf8(text, descriptor, font_key, origin, paint) =>
      self.replay_text_run_utf8(
        text, descriptor, font_key, origin, paint, font, resources,
      )
    DrawCanvasShapedGlyphRunUtf8(_, glyph_run, origin, paint) =>
      self.replay_shaped_glyph_run_utf8(glyph_run, origin, paint, font)
    DeclareRenderResource(_) => true
    PresentSurface => false
  }
}

///|
fn Canvas::replay_internal(
  self : Canvas,
  commands : @skia.RenderCommandList,
  font : Font?,
  resources : NativeReplayResources?,
) -> CanvasReplayStats {
  let mut command_count = 0
  let mut replayed_count = 0
  let mut skipped_count = 0
  let mut draw_count = 0
  let mut state_count = 0
  let mut transform_count = 0
  let mut clip_count = 0
  let mut clear_count = 0
  let mut text_count = 0
  let mut present_count = 0
  let mut resource_declaration_count = 0
  let mut image_resource_count = 0
  let mut shader_resource_count = 0
  let mut filter_resource_count = 0
  let mut path_resource_count = 0
  let mut text_resource_count = 0
  for command in commands.commands {
    command_count += 1
    if command.is_draw() {
      draw_count += 1
    }
    if command.is_state() {
      state_count += 1
    }
    if command.is_transform() {
      transform_count += 1
    }
    if command.is_clip() {
      clip_count += 1
    }
    if command.is_clear() {
      clear_count += 1
    }
    if command.is_text() {
      text_count += 1
    }
    if command.is_resource_declaration() {
      resource_declaration_count += 1
    }
    let resource_counts = canvas_replay_command_resource_counts(command)
    image_resource_count += resource_counts.image_resource_count
    shader_resource_count += resource_counts.shader_resource_count
    filter_resource_count += resource_counts.filter_resource_count
    path_resource_count += resource_counts.path_resource_count
    text_resource_count += resource_counts.text_resource_count
    if command.is_present() {
      present_count += 1
    }
    if self.replay_command(command, font, resources) {
      replayed_count += 1
    } else if !command.is_present() {
      skipped_count += 1
    }
  }
  {
    command_count,
    replayed_count,
    skipped_count,
    draw_count,
    state_count,
    transform_count,
    clip_count,
    clear_count,
    text_count,
    present_count,
    resource_declaration_count,
    image_resource_count,
    shader_resource_count,
    filter_resource_count,
    path_resource_count,
    text_resource_count,
  }
}

///|
fn Canvas::replay_frame_internal(
  self : Canvas,
  frame : @skia.RenderFrameDescriptor,
  font : Font?,
  resources : NativeReplayResources?,
) -> CanvasReplayStats {
  if frame.is_ready() {
    self.replay_internal(frame.command_list, font, resources)
  } else {
    canvas_replay_skipped_stats(frame.command_list)
  }
}

///|
/// Replay the CPU Canvas subset of a value-layer render command list.
pub fn Canvas::replay(
  self : Canvas,
  commands : @skia.RenderCommandList,
  font? : Font? = None,
) -> CanvasReplayStats {
  self.replay_internal(commands, font, None)
}

///|
/// Replay a ready render frame, preserving frame validation as the native boundary.
pub fn Canvas::replay_frame(
  self : Canvas,
  frame : @skia.RenderFrameDescriptor,
  font? : Font? = None,
) -> CanvasReplayStats {
  self.replay_frame_internal(frame, font, None)
}

///|
/// Replay render commands while reusing decoded native resources by key.
pub fn Canvas::replay_with_resources(
  self : Canvas,
  commands : @skia.RenderCommandList,
  resources : NativeReplayResources,
  font? : Font? = None,
) -> CanvasReplayStats {
  self.replay_internal(commands, font, Some(resources))
}

///|
/// Replay a ready render frame while reusing native resources by key.
pub fn Canvas::replay_frame_with_resources(
  self : Canvas,
  frame : @skia.RenderFrameDescriptor,
  resources : NativeReplayResources,
  font? : Font? = None,
) -> CanvasReplayStats {
  self.replay_frame_internal(frame, font, Some(resources))
}

///|
/// Replay render commands while reusing decoded native images by resource key.
pub fn Canvas::replay_with_image_cache(
  self : Canvas,
  commands : @skia.RenderCommandList,
  image_cache : @skia.ResourceCache[@skia.RendererResourceKey, Image],
  font? : Font? = None,
) -> CanvasReplayStats {
  self.replay_with_resources(
    commands,
    {
      image_cache,
      shader_cache: @skia.ResourceCache::new(),
      path_cache: @skia.ResourceCache::new(),
      text_run_cache: @skia.ResourceCache::new(),
      font_cache: @skia.ResourceCache::new(),
      typeface_cache: @skia.ResourceCache::new(),
      color_filter_cache: @skia.ResourceCache::new(),
      image_filter_cache: @skia.ResourceCache::new(),
      mask_filter_cache: @skia.ResourceCache::new(),
    },
    font~,
  )
}
