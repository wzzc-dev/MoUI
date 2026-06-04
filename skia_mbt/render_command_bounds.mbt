///|
fn render_paint_stroke_radius(paint : Paint) -> Float {
  let width : Float = if paint.stroke_width <= 0.0 {
    1.0
  } else {
    paint.stroke_width
  }
  width / 2.0
}

///|
fn point_draw_bounds(point : Point, paint : Paint) -> Rect {
  let radius = render_paint_stroke_radius(paint)
  Rect::from_xywh(
    point.x - radius,
    point.y - radius,
    radius * 2.0,
    radius * 2.0,
  )
}

///|
fn points_draw_bounds(points : Array[Point], paint : Paint) -> Rect? {
  match Rect::from_points(points) {
    None => None
    Some(bounds) => {
      let radius = render_paint_stroke_radius(paint)
      Some(bounds.outset(radius, radius))
    }
  }
}

///|
fn line_draw_bounds(start : Point, end : Point, paint : Paint) -> Rect? {
  points_draw_bounds([start, end], paint)
}

///|
let estimated_render_text_advance_per_byte : Float = 8.0

///|
let estimated_render_text_ascent : Float = 12.0

///|
let estimated_render_text_descent : Float = 4.0

///|
fn point_mode_draw_bounds(
  points : Array[Point],
  mode : PointMode,
  paint : Paint,
) -> Rect? {
  match mode {
    Points => points_draw_bounds(points, paint)
    Lines => {
      let used : Array[Point] = []
      for i = 0; i + 1 < points.length(); i = i + 2 {
        used.push(points[i])
        used.push(points[i + 1])
      }
      points_draw_bounds(used, paint)
    }
    Polygon =>
      if points.length() < 2 {
        None
      } else {
        points_draw_bounds(points, paint)
      }
  }
}

///|
fn text_utf8_draw_bounds(
  byte_count : Int,
  origin : Point,
  is_right_to_left? : Bool = false,
) -> Rect? {
  if byte_count <= 0 {
    None
  } else {
    let width = Float::from_int(byte_count) *
      estimated_render_text_advance_per_byte
    let left = if is_right_to_left { origin.x - width } else { origin.x }
    let right = if is_right_to_left { origin.x } else { origin.x + width }
    Some(
      Rect::new(
        left,
        origin.y - estimated_render_text_ascent,
        right,
        origin.y + estimated_render_text_descent,
      ).sorted(),
    )
  }
}

///|
fn text_run_draw_bounds(
  text : Bytes,
  descriptor : TextRunDescriptor,
  origin : Point,
) -> Rect? {
  let range = descriptor.range.clamp_to_text(text)
  text_utf8_draw_bounds(
    range.length(),
    origin,
    is_right_to_left=descriptor.is_right_to_left(),
  )
}

///|
fn shaped_glyph_run_draw_bounds(
  glyph_run : ShapedGlyphRunDescriptor,
  origin : Point,
) -> Rect? {
  if !glyph_run.is_valid() {
    None
  } else {
    let advance = glyph_run.shaped_run.advance
    let right = origin.x + advance.x
    let bottom = origin.y + advance.y
    Some(Rect::new(origin.x, origin.y, right, bottom).sorted())
  }
}

///|
fn image_draw_bounds(image : ImageDescriptor, top_left : Point) -> Rect? {
  match image.dimensions() {
    None => None
    Some(dimensions) =>
      Some(
        Rect::from_xywh(
          top_left.x,
          top_left.y,
          Float::from_int(dimensions.width),
          Float::from_int(dimensions.height),
        ),
      )
  }
}

///|
fn RenderCommand::draw_bounds(self : RenderCommand) -> Rect? {
  match self {
    DrawCanvasPoint(point, paint) => Some(point_draw_bounds(point, paint))
    DrawCanvasLine(start, end, paint) => line_draw_bounds(start, end, paint)
    DrawCanvasPoints(points, mode, paint) =>
      point_mode_draw_bounds(points, mode, paint)
    DrawCanvasRect(rect, _) => Some(rect.sorted())
    DrawCanvasOval(oval, _) => Some(oval.sorted())
    DrawCanvasCircle(center, radius, _) =>
      if radius <= 0.0 {
        None
      } else {
        Some(
          Rect::from_xywh(
            center.x - radius,
            center.y - radius,
            radius * 2.0,
            radius * 2.0,
          ),
        )
      }
    DrawCanvasArc(oval, _, _, _, paint) => {
      let radius = render_paint_stroke_radius(paint)
      Some(oval.sorted().outset(radius, radius))
    }
    DrawCanvasRoundRect(rect, _, _, _) => Some(rect.sorted())
    DrawCanvasRRect(rrect, _) => Some(rrect.bounds())
    DrawCanvasDRRect(outer, _, _) => Some(outer.bounds())
    DrawCanvasRectShader(rect, _, _) => Some(rect.sorted())
    DrawCanvasRoundRectShader(rect, _, _, _, _) => Some(rect.sorted())
    DrawCanvasPath(path, _) => path.bounds()
    DrawCanvasPathShader(path, _, _) => path.bounds()
    DrawCanvasImage(image, top_left) => image_draw_bounds(image, top_left)
    DrawCanvasImageRect(_, _, dst, _, _) => Some(dst.sorted())
    DrawCanvasTextUtf8(text, origin, _) =>
      text_utf8_draw_bounds(text.length(), origin)
    DrawCanvasTextRunUtf8(text, descriptor, _, origin, _) =>
      text_run_draw_bounds(text, descriptor, origin)
    DrawCanvasShapedGlyphRunUtf8(_, glyph_run, origin, _) =>
      shaped_glyph_run_draw_bounds(glyph_run, origin)
    _ => None
  }
}

///|
fn include_render_command_bounds(bounds : Rect?, next : Rect) -> Rect? {
  if next.is_empty() {
    bounds
  } else {
    match bounds {
      None => Some(next)
      Some(bounds) => Some(bounds.join(next))
    }
  }
}

///|
priv struct RenderCommandBoundsState {
  matrix : Matrix
  clip : Rect
}

///|
fn RenderCommandBoundsState::new(
  pass_bounds : Rect,
) -> RenderCommandBoundsState {
  { matrix: Matrix::identity(), clip: pass_bounds }
}

///|
fn render_command_update_matrix(
  command : RenderCommand,
  current_matrix : Matrix,
  matrix_stack : Array[Matrix],
) -> Matrix {
  match command {
    SaveCanvas | SaveCanvasLayer(_, _, _, _, _) => {
      matrix_stack.push(current_matrix)
      current_matrix
    }
    RestoreCanvas =>
      match matrix_stack.pop() {
        None => Matrix::identity()
        Some(matrix) => matrix
      }
    TranslateCanvas(delta) => current_matrix.post_translate(delta.x, delta.y)
    ScaleCanvas(scale) => current_matrix.post_scale(scale.width, scale.height)
    RotateCanvas(degrees) => current_matrix.post_rotate_degrees(degrees)
    SkewCanvas(skew) => current_matrix.post_skew(skew.x, skew.y)
    ConcatCanvas(matrix) => current_matrix.post_concat(matrix)
    ResetCanvasMatrix => Matrix::identity()
    _ => current_matrix
  }
}

///|
fn render_command_clip_bounds(
  rect : Rect,
  current_matrix : Matrix,
  pass_bounds : Rect,
) -> Rect? {
  current_matrix.map_rect(rect).intersect(pass_bounds)
}

///|
fn render_command_update_clip(
  command : RenderCommand,
  current_matrix : Matrix,
  current_clip : Rect,
  pass_bounds : Rect,
  clip_stack : Array[Rect],
) -> Rect {
  match command {
    SaveCanvas | SaveCanvasLayer(_, _, _, _, _) => {
      clip_stack.push(current_clip)
      current_clip
    }
    RestoreCanvas =>
      match clip_stack.pop() {
        None => pass_bounds
        Some(clip) => clip
      }
    ResetCanvasMatrix => current_clip
    ClipCanvasRect(rect, Intersect) =>
      match render_command_clip_bounds(rect, current_matrix, pass_bounds) {
        None => Rect::empty()
        Some(clip) =>
          match current_clip.intersect(clip) {
            None => Rect::empty()
            Some(clip) => clip
          }
      }
    ClipCanvasRRect(rrect, Intersect) =>
      match
        render_command_clip_bounds(rrect.bounds(), current_matrix, pass_bounds) {
        None => Rect::empty()
        Some(clip) =>
          match current_clip.intersect(clip) {
            None => Rect::empty()
            Some(clip) => clip
          }
      }
    ClipCanvasPath(path, Intersect) =>
      match path.bounds() {
        None => Rect::empty()
        Some(bounds) =>
          match
            render_command_clip_bounds(bounds, current_matrix, pass_bounds) {
            None => Rect::empty()
            Some(clip) =>
              match current_clip.intersect(clip) {
                None => Rect::empty()
                Some(clip) => clip
              }
          }
      }
    ClipCanvasRect(_, Difference)
    | ClipCanvasRRect(_, Difference)
    | ClipCanvasPath(_, Difference) => current_clip
    _ => current_clip
  }
}

///|
fn render_command_transformed_bounds(
  command : RenderCommand,
  current_matrix : Matrix,
  current_clip : Rect,
) -> Rect? {
  match command {
    ClearCanvas(_) => Some(current_clip)
    DrawCanvasColor(_, _) | DrawCanvasPaint(_) => Some(current_clip)
    DrawCanvasPaintShader(_, _) => Some(current_clip)
    command =>
      match command.draw_bounds() {
        None => None
        Some(draw_bounds) =>
          current_matrix.map_rect(draw_bounds).intersect(current_clip)
      }
  }
}

///|
pub fn RenderCommandList::touched_bounds(self : RenderCommandList) -> Rect? {
  let pass_bounds = self.pass.bounds.to_rect()
  if pass_bounds.is_empty() {
    None
  } else {
    let initial_bounds : Rect? = None
    let matrix_stack : Array[Matrix] = []
    let clip_stack : Array[Rect] = []
    for bounds = initial_bounds, state = RenderCommandBoundsState::new(
            pass_bounds,
          ), i = 0
        i < self.commands.length()
        i = i + 1 {
      let command = self.commands[i]
      let next = render_command_transformed_bounds(
        command,
        state.matrix,
        state.clip,
      )
      let bounds = match next {
        None => bounds
        Some(next) => include_render_command_bounds(bounds, next)
      }
      let matrix = render_command_update_matrix(
        command,
        state.matrix,
        matrix_stack,
      )
      let clip = render_command_update_clip(
        command,
        state.matrix,
        state.clip,
        pass_bounds,
        clip_stack,
      )
      continue bounds, { matrix, clip }, i + 1
    } nobreak {
      bounds
    }
  }
}
