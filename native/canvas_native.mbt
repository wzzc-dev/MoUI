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
pub fn Canvas::draw_glyphs(
  self : Canvas,
  glyphs : Array[GlyphId],
  positions : Array[@skia.Point],
  font : Font,
  paint : @skia.Paint,
  origin? : @skia.Point = @skia.Point::zero(),
) -> Unit {
  if !glyphs.is_empty() && glyphs.length() == positions.length() {
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
      paint.stroke_width,
      paint.stroke_miter,
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
fn Canvas::replay_path_value(
  self : Canvas,
  path : @skia.Path,
  paint : @skia.Paint,
) -> Bool {
  match Path::from_value(path) {
    None => false
    Some(native_path) => {
      self.draw_path(native_path, paint)
      true
    }
  }
}

///|
fn Canvas::replay_command(
  self : Canvas,
  command : @skia.RenderCommand,
  font : Font?,
) -> Bool {
  match command {
    @skia.SaveCanvas => {
      ignore(self.save())
      true
    }
    @skia.RestoreCanvas => {
      self.restore()
      true
    }
    @skia.ClearCanvas(color) => {
      self.clear(color)
      true
    }
    @skia.ClipCanvasRect(rect, op) => {
      self.clip_rect(rect, op~)
      true
    }
    @skia.DrawCanvasRect(rect, paint) => {
      self.draw_rect(rect, paint)
      true
    }
    @skia.DrawCanvasPath(path, paint) => self.replay_path_value(path, paint)
    @skia.DrawCanvasTextUtf8(text, origin, paint) =>
      self.replay_text_utf8(text, origin, paint, font)
    @skia.DrawCanvasTextRunUtf8(text, _, _, origin, paint) =>
      self.replay_text_utf8(text, origin, paint, font)
    @skia.DeclareRenderResource(_) => true
    @skia.PresentSurface => false
  }
}

///|
/// Replay the CPU Canvas subset of a value-layer render command list.
pub fn Canvas::replay(
  self : Canvas,
  commands : @skia.RenderCommandList,
  font? : Font? = None,
) -> CanvasReplayStats {
  let mut command_count = 0
  let mut replayed_count = 0
  let mut skipped_count = 0
  let mut draw_count = 0
  let mut text_count = 0
  let mut present_count = 0
  for command in commands.commands {
    command_count += 1
    if command.is_draw() {
      draw_count += 1
    }
    if command.is_text() {
      text_count += 1
    }
    if command.is_present() {
      present_count += 1
    }
    if self.replay_command(command, font) {
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
    text_count,
    present_count,
  }
}
