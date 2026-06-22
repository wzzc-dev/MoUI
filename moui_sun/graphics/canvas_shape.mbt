///|
/// Draw a filled rectangle
pub fn Canvas::fill_rect(
  self : Canvas,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  paint : Paint,
) -> Unit {
  guard paint.style is PaintStyle::Fill else { return }
  guard w > 0.0 && h > 0.0 else { return }

  if self.transform != Transform::identity() ||
    !is_pixel_aligned_rect(x, y, w, h) {
    self.fill_path(Path::new().add_rect(x, y, w, h), paint)
    return
  }

  let ix = x.to_int()
  let iy = y.to_int()
  let iw = w.to_int()
  let ih = h.to_int()
  let (x_start, y_start, x_end, y_end) = clipped_int_bounds(
    self,
    ix,
    iy,
    ix + iw,
    iy + ih,
  )
  guard x_start < x_end && y_start < y_end else { return }

  if paint.has_shader() {
    let mut dirty_x_start = x_end
    let mut dirty_y_start = y_end
    let mut dirty_x_end = x_start
    let mut dirty_y_end = y_start
    for py in y_start..<y_end {
      for px in x_start..<x_end {
        let color = paint.sample_color(
          px.to_double() + 0.5,
          py.to_double() + 0.5,
        )
        guard should_blend_source_color(color, paint.blend_mode) else {
          continue
        }
        self.pixmap.blend_pixel_with_mode(px, py, color, paint.blend_mode)
        dirty_x_start = dirty_x_start.min(px)
        dirty_y_start = dirty_y_start.min(py)
        dirty_x_end = dirty_x_end.max(px + 1)
        dirty_y_end = dirty_y_end.max(py + 1)
      }
    }
    if dirty_x_start < dirty_x_end && dirty_y_start < dirty_y_end {
      self.mark_dirty_bounds(
        dirty_x_start, dirty_y_start, dirty_x_end, dirty_y_end,
      )
    }
  } else {
    let color = paint.sample_color(0.0, 0.0)
    guard should_blend_source_color(color, paint.blend_mode) else { return }
    self.pixmap.blend_rect_with_mode(
      x_start,
      y_start,
      x_end - x_start,
      y_end - y_start,
      color,
      paint.blend_mode,
    )
    self.mark_dirty_bounds(x_start, y_start, x_end, y_end)
  }
}

///|
fn is_pixel_aligned_rect(
  x : Double,
  y : Double,
  w : Double,
  h : Double,
) -> Bool {
  is_pixel_aligned_value(x) &&
  is_pixel_aligned_value(y) &&
  is_pixel_aligned_value(w) &&
  is_pixel_aligned_value(h)
}

///|
fn is_pixel_aligned_value(value : Double) -> Bool {
  value == value.to_int().to_double()
}

///|
/// Draw a filled rounded rectangle.
pub fn Canvas::fill_rounded_rect(
  self : Canvas,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  radius : Double,
  paint : Paint,
) -> Unit {
  guard w > 0.0 && h > 0.0 else { return }
  self.fill_path(Path::new().add_rounded_rect(x, y, w, h, radius), paint)
}

///|
/// Draw a filled rounded rectangle with independent corner radii.
pub fn Canvas::fill_rounded_rect_corners(
  self : Canvas,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  top_left : Double,
  top_right : Double,
  bottom_right : Double,
  bottom_left : Double,
  paint : Paint,
) -> Unit {
  guard w > 0.0 && h > 0.0 else { return }
  self.fill_path(
    Path::new().add_rounded_rect_corners(
      x, y, w, h, top_left, top_right, bottom_right, bottom_left,
    ),
    paint,
  )
}

///|
/// Draw a filled circle.
pub fn Canvas::fill_circle(
  self : Canvas,
  cx : Double,
  cy : Double,
  radius : Double,
  paint : Paint,
) -> Unit {
  guard radius > 0.0 else { return }
  self.fill_path(Path::new().add_circle(cx, cy, radius), paint)
}

///|
/// Draw a filled ellipse.
pub fn Canvas::fill_ellipse(
  self : Canvas,
  cx : Double,
  cy : Double,
  rx : Double,
  ry : Double,
  paint : Paint,
) -> Unit {
  guard rx > 0.0 && ry > 0.0 else { return }
  self.fill_path(Path::new().add_ellipse(cx, cy, rx, ry), paint)
}

///|
/// Draw a filled polygon.
pub fn Canvas::fill_polygon(
  self : Canvas,
  points : Array[Point],
  paint : Paint,
) -> Unit {
  guard points.length() >= 3 else { return }
  self.fill_path(Path::new().add_polygon(points), paint)
}

///|
/// Draw a filled pie slice.
pub fn Canvas::fill_pie(
  self : Canvas,
  cx : Double,
  cy : Double,
  radius : Double,
  start_angle : Double,
  sweep_angle : Double,
  paint : Paint,
) -> Unit {
  guard radius > 0.0 && sweep_angle != 0.0 else { return }
  self.fill_path(
    Path::new().add_pie(cx, cy, radius, start_angle, sweep_angle),
    paint,
  )
}

///|
/// Draw a stroked rectangle.
pub fn Canvas::stroke_rect(
  self : Canvas,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  paint : Paint,
) -> Unit {
  guard w > 0.0 && h > 0.0 else { return }
  self.stroke_path(Path::new().add_rect(x, y, w, h), paint)
}

///|
/// Draw a stroked line segment.
pub fn Canvas::stroke_line(
  self : Canvas,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  paint : Paint,
) -> Unit {
  self.stroke_path(Path::new().move_to(x0, y0).line_to(x1, y1), paint)
}

///|
/// Draw a stroked open polyline.
pub fn Canvas::stroke_polyline(
  self : Canvas,
  points : Array[Point],
  paint : Paint,
) -> Unit {
  guard points.length() >= 2 else { return }
  self.stroke_path(Path::new().add_polyline(points), paint)
}

///|
/// Draw a stroked closed polygon.
pub fn Canvas::stroke_polygon(
  self : Canvas,
  points : Array[Point],
  paint : Paint,
) -> Unit {
  guard points.length() >= 3 else { return }
  self.stroke_path(Path::new().add_polygon(points), paint)
}

///|
/// Draw a stroked circular arc.
pub fn Canvas::stroke_arc(
  self : Canvas,
  cx : Double,
  cy : Double,
  radius : Double,
  start_angle : Double,
  sweep_angle : Double,
  paint : Paint,
) -> Unit {
  guard radius > 0.0 && sweep_angle != 0.0 else { return }
  self.stroke_path(
    Path::new().add_arc(cx, cy, radius, start_angle, sweep_angle),
    paint,
  )
}

///|
/// Draw a stroked circle.
pub fn Canvas::stroke_circle(
  self : Canvas,
  cx : Double,
  cy : Double,
  radius : Double,
  paint : Paint,
) -> Unit {
  guard radius > 0.0 else { return }
  self.stroke_path(Path::new().add_circle(cx, cy, radius), paint)
}

///|
/// Draw a stroked ellipse.
pub fn Canvas::stroke_ellipse(
  self : Canvas,
  cx : Double,
  cy : Double,
  rx : Double,
  ry : Double,
  paint : Paint,
) -> Unit {
  guard rx > 0.0 && ry > 0.0 else { return }
  self.stroke_path(Path::new().add_ellipse(cx, cy, rx, ry), paint)
}

///|
/// Fill a path with the given paint
pub fn Canvas::fill_path(self : Canvas, path : Path, paint : Paint) -> Unit {
  guard paint.style is PaintStyle::Fill && !path.is_empty() else { return }
  let edges = path_to_edges(path, self.transform)
  guard edges.length() > 0 else { return }

  let (min_x_value, min_y_value, max_x_value, max_y_value) = path_bounds(edges)
  let (x_start, y_start, x_end, y_end) = clipped_int_bounds(
    self,
    min_x_value.to_int(),
    min_y_value.to_int(),
    max_x_value.to_int() + 1,
    max_y_value.to_int() + 1,
  )
  guard x_start < x_end && y_start < y_end else { return }
  let sample_count = 4
  let sample_count_sq = sample_count * sample_count
  let sample_count_double = sample_count.to_double()

  for y in y_start..<y_end {
    for x in x_start..<x_end {
      let mut covered = 0
      for sy in 0..<sample_count {
        for sx in 0..<sample_count {
          let sample_x = x.to_double() +
            (sx.to_double() + 0.5) / sample_count_double
          let sample_y = y.to_double() +
            (sy.to_double() + 0.5) / sample_count_double
          if is_point_in_edges(sample_x, sample_y, edges, paint.fill_rule) {
            covered = covered + 1
          }
        }
      }
      if covered > 0 {
        let did_blend = blend_coverage_pixel(
          self.pixmap,
          x,
          y,
          paint.sample_color(x.to_double() + 0.5, y.to_double() + 0.5),
          covered,
          sample_count_sq,
          paint.blend_mode,
        )
        if did_blend {
          self.mark_dirty_bounds(x, y, x + 1, y + 1)
        }
      }
    }
  }
}

///|
/// Draw a stroked rounded rectangle.
pub fn Canvas::stroke_rounded_rect(
  self : Canvas,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  radius : Double,
  paint : Paint,
) -> Unit {
  guard w > 0.0 && h > 0.0 else { return }
  self.stroke_path(Path::new().add_rounded_rect(x, y, w, h, radius), paint)
}

///|
/// Draw a stroked rounded rectangle with independent corner radii.
pub fn Canvas::stroke_rounded_rect_corners(
  self : Canvas,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  top_left : Double,
  top_right : Double,
  bottom_right : Double,
  bottom_left : Double,
  paint : Paint,
) -> Unit {
  guard w > 0.0 && h > 0.0 else { return }
  self.stroke_path(
    Path::new().add_rounded_rect_corners(
      x, y, w, h, top_left, top_right, bottom_right, bottom_left,
    ),
    paint,
  )
}

///|
/// Stroke a path with the given paint
pub fn Canvas::stroke_path(self : Canvas, path : Path, paint : Paint) -> Unit {
  guard paint.style is PaintStyle::Stroke && !path.is_empty() else { return }
  guard paint.stroke_width > 0.0 else { return }
  match self.transform.inverse() {
    Some(device_to_local) =>
      self.stroke_path_with_local_metrics(path, paint, device_to_local)
    None => self.stroke_path_with_device_metrics(path, paint)
  }
}

///|
fn Canvas::stroke_path_with_local_metrics(
  self : Canvas,
  path : Path,
  paint : Paint,
  device_to_local : Transform,
) -> Unit {
  let solid_stroke_path = path_to_stroke_path(path, Transform::identity())
  guard solid_stroke_path.edges.length() > 0 else { return }
  let stroke_path = apply_stroke_dash(
    solid_stroke_path,
    paint.stroke_dash_pattern,
    paint.stroke_dash_offset,
  )
  guard stroke_path.edges.length() > 0 else { return }

  let half_width = paint.stroke_width / 2.0
  let bounds_outset = stroke_bounds_outset(
    half_width,
    paint.stroke_cap,
    paint.stroke_join,
    paint.miter_limit,
  )
  let (min_x_value, min_y_value, max_x_value, max_y_value) = path_bounds(
    stroke_path.edges,
  )
  let (left, top, right, bottom) = transformed_rect_bounds(
    self.transform,
    min_x_value - bounds_outset,
    min_y_value - bounds_outset,
    max_x_value - min_x_value + bounds_outset * 2.0,
    max_y_value - min_y_value + bounds_outset * 2.0,
  )
  let (x_start, y_start, x_end, y_end) = clipped_int_bounds(
    self, left, top, right, bottom,
  )
  guard x_start < x_end && y_start < y_end else { return }
  let sample_count = 4
  let sample_count_sq = sample_count * sample_count
  let sample_count_double = sample_count.to_double()

  for y in y_start..<y_end {
    for x in x_start..<x_end {
      let mut covered = 0
      for sy in 0..<sample_count {
        for sx in 0..<sample_count {
          let sample_x = x.to_double() +
            (sx.to_double() + 0.5) / sample_count_double
          let sample_y = y.to_double() +
            (sy.to_double() + 0.5) / sample_count_double
          let (local_x, local_y) = device_to_local.apply(sample_x, sample_y)
          if is_point_on_stroke(
              local_x,
              local_y,
              stroke_path,
              half_width,
              paint.stroke_cap,
              paint.stroke_join,
              paint.miter_limit,
            ) {
            covered = covered + 1
          }
        }
      }
      if covered > 0 {
        let did_blend = blend_coverage_pixel(
          self.pixmap,
          x,
          y,
          paint.sample_color(x.to_double() + 0.5, y.to_double() + 0.5),
          covered,
          sample_count_sq,
          paint.blend_mode,
        )
        if did_blend {
          self.mark_dirty_bounds(x, y, x + 1, y + 1)
        }
      }
    }
  }
}

///|
fn Canvas::stroke_path_with_device_metrics(
  self : Canvas,
  path : Path,
  paint : Paint,
) -> Unit {
  let solid_stroke_path = path_to_stroke_path(path, self.transform)
  guard solid_stroke_path.edges.length() > 0 else { return }
  let stroke_scale = stroke_metric_scale(self.transform)
  let stroke_path = apply_stroke_dash(
    solid_stroke_path,
    scaled_stroke_dash_pattern(paint.stroke_dash_pattern, stroke_scale),
    paint.stroke_dash_offset * stroke_scale,
  )
  guard stroke_path.edges.length() > 0 else { return }

  let half_width = paint.stroke_width * stroke_scale / 2.0
  let bounds_outset = stroke_bounds_outset(
    half_width,
    paint.stroke_cap,
    paint.stroke_join,
    paint.miter_limit,
  )
  let (min_x_value, min_y_value, max_x_value, max_y_value) = path_bounds(
    stroke_path.edges,
  )
  let (x_start, y_start, x_end, y_end) = clipped_int_bounds(
    self,
    (min_x_value - bounds_outset).to_int(),
    (min_y_value - bounds_outset).to_int(),
    (max_x_value + bounds_outset).to_int() + 1,
    (max_y_value + bounds_outset).to_int() + 1,
  )
  guard x_start < x_end && y_start < y_end else { return }
  let sample_count = 4
  let sample_count_sq = sample_count * sample_count
  let sample_count_double = sample_count.to_double()

  for y in y_start..<y_end {
    for x in x_start..<x_end {
      let mut covered = 0
      for sy in 0..<sample_count {
        for sx in 0..<sample_count {
          let sample_x = x.to_double() +
            (sx.to_double() + 0.5) / sample_count_double
          let sample_y = y.to_double() +
            (sy.to_double() + 0.5) / sample_count_double
          if is_point_on_stroke(
              sample_x,
              sample_y,
              stroke_path,
              half_width,
              paint.stroke_cap,
              paint.stroke_join,
              paint.miter_limit,
            ) {
            covered = covered + 1
          }
        }
      }
      if covered > 0 {
        let did_blend = blend_coverage_pixel(
          self.pixmap,
          x,
          y,
          paint.sample_color(x.to_double() + 0.5, y.to_double() + 0.5),
          covered,
          sample_count_sq,
          paint.blend_mode,
        )
        if did_blend {
          self.mark_dirty_bounds(x, y, x + 1, y + 1)
        }
      }
    }
  }
}

///|
fn stroke_bounds_outset(
  half_width : Double,
  stroke_cap : StrokeCap,
  stroke_join : StrokeJoin,
  miter_limit : Double,
) -> Double {
  let cap_extension = match stroke_cap {
    StrokeCap::Butt => 0.0
    StrokeCap::Round | StrokeCap::Square => half_width
  }
  let join_extension = match stroke_join {
    StrokeJoin::Miter => half_width * (miter_limit - 1.0).max(0.0)
    StrokeJoin::Round | StrokeJoin::Bevel => 0.0
  }
  half_width + cap_extension.max(join_extension)
}

///|
fn stroke_metric_scale(transform : Transform) -> Double {
  let x_scale = (transform.a * transform.a + transform.c * transform.c).sqrt()
  let y_scale = (transform.b * transform.b + transform.d * transform.d).sqrt()
  let scale = x_scale.max(y_scale)
  guard scale == scale && scale > 0.0 else { return 1.0 }
  scale
}

///|
fn scaled_stroke_dash_pattern(
  pattern : Array[Double],
  scale : Double,
) -> Array[Double] {
  guard pattern.length() > 0 && scale != 1.0 else { return pattern }
  let scaled = []
  for value in pattern {
    scaled.push(value * scale)
  }
  scaled
}
