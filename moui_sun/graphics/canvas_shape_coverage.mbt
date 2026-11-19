// Coverage rasterisation for the shapes the control surfaces are built from:
// rounded rectangles, and the circles / rings that come from them.
//
// The generic path fill samples a 4x4 grid inside every pixel, so an anti
// aliased edge only ever has 17 coverage levels. On a 20 px checkbox corner, or
// a 2 px focus ring, that quantisation is visible as jaggies next to Skia's
// 8-bit scan-converted coverage.
//
// These helpers keep the generic path for every other shape and accumulate
// coverage row by row: `sun_shape_coverage_steps` samples across the pixel row
// and each sample contributes its exact horizontal overlap, so the horizontal
// axis has full precision while the vertical axis is quantised to 1/16 of a
// pixel. That is the accuracy Skia's analytic edges effectively provide and it
// costs O(rows) span evaluations instead of O(pixels x samples).

///|
/// Vertical coverage samples per device pixel row.
let sun_shape_coverage_steps : Int32 = 16

///|
/// Device-space scale when the canvas transform is an axis-aligned, uniform
/// scale — the device-pixel-ratio transform every hosted backend hands Sun.
/// Rotated or skewed transforms return `None` and keep the generic path, so the
/// fast path can never claim geometry it did not transform.
fn Canvas::uniform_device_scale(self : Canvas) -> Double? {
  let transform = self.transform
  if transform.b == 0.0 &&
    transform.c == 0.0 &&
    transform.a > 0.0 &&
    transform.a == transform.d {
    Some(transform.a)
  } else {
    None
  }
}

///|
/// Horizontal span of an axis-aligned rounded rectangle at device row `y`.
fn sun_rounded_rect_span_at(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  radius : Double,
  y : Double,
) -> (Double, Double) {
  let half_side = ((x1 - x0) * 0.5).min((y1 - y0) * 0.5)
  let r = radius.max(0.0).min(half_side)
  // Outside the shape's vertical range the span is empty, not full: the same
  // helper describes the hole of a stroked round rect, where a full-width span
  // outside the inner rect would erase the ring.
  if y <= y0 || y >= y1 {
    return (x0, x0)
  }
  if r <= 0.0 {
    return (x0, x1)
  }
  if y < y0 + r {
    let dy = y0 + r - y
    let dx = r - (r * r - dy * dy).max(0.0).sqrt()
    (x0 + dx, x1 - dx)
  } else if y > y1 - r {
    let dy = y - (y1 - r)
    let dx = r - (r * r - dy * dy).max(0.0).sqrt()
    (x0 + dx, x1 - dx)
  } else {
    (x0, x1)
  }
}

///|
/// Add one sub-scanline's horizontal coverage of `span` into `cover`.
///
/// `cover` is indexed from `left`; `weight` is one vertical sample's share of
/// the row. Horizontal overlap is exact, so vertical edges stay sharp while
/// arcs get a smooth 1/16-per-row ramp.
fn sun_accumulate_span_coverage(
  cover : Array[Double],
  left : Int32,
  span : (Double, Double),
  weight : Double,
) -> Unit {
  let x_left = span.0
  let x_right = span.1
  if x_right <= x_left {
    return
  }
  let first = x_left.floor().to_int()
  let last = x_right.floor().to_int()
  for px in first..<=last {
    let overlap = (x_right.min((px + 1).to_double()) -
    x_left.max(px.to_double())).max(0.0)
    if overlap > 0.0 {
      let index = px - left
      if index >= 0 && index < cover.length() {
        cover[index] = cover[index] + overlap * weight
      }
    }
  }
}

///|
/// Blend one accumulated coverage row into the pixmap.
fn Canvas::blend_coverage_row(
  self : Canvas,
  paint : Paint,
  y : Int32,
  left : Int32,
  cover : Array[Double],
) -> Unit {
  for index in 0..<cover.length() {
    let coverage = cover[index].min(1.0)
    if coverage > 0.0 {
      let px = left + index
      let covered = (coverage * 255.0 + 0.5).to_int()
      if covered > 0 {
        let color = self.sample_paint_color(
          paint,
          px.to_double() + 0.5,
          y.to_double() + 0.5,
        )
        let did_blend = blend_coverage_pixel(
          self.pixmap,
          px,
          y,
          color,
          covered,
          255,
          paint.blend_mode,
        )
        if did_blend {
          self.mark_dirty_bounds(px, y, px + 1, y + 1)
        }
      }
    }
  }
}

///|
/// Fill a convex shape given its horizontal span at a device scanline.
///
/// `hole_span_at` subtracts a second, fully contained shape (a stroke ring),
/// which is how a rounded-rect border keeps exact inner and outer edges.
fn Canvas::fill_span_shape(
  self : Canvas,
  paint : Paint,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  span_at : (Double) -> (Double, Double),
  hole_span_at : ((Double) -> (Double, Double))?,
) -> Unit {
  if x1 <= x0 || y1 <= y0 {
    return
  }
  let (left, top, right, bottom) = clipped_int_bounds(
    self,
    x0.floor().to_int(),
    y0.floor().to_int(),
    x1.ceil().to_int(),
    y1.ceil().to_int(),
  )
  guard left < right && top < bottom else { return }
  let width = right - left
  let cover : Array[Double] = Array::make(width, 0.0)
  let step = 1.0 / sun_shape_coverage_steps.to_double()
  for y in top..<bottom {
    for index in 0..<width {
      cover[index] = 0.0
    }
    for sample in 0..<sun_shape_coverage_steps {
      let sample_y = y.to_double() + (sample.to_double() + 0.5) * step
      sun_accumulate_span_coverage(cover, left, span_at(sample_y), step)
      match hole_span_at {
        Some(hole_span) =>
          sun_accumulate_span_coverage(cover, left, hole_span(sample_y), -step)
        None => ()
      }
    }
    self.blend_coverage_row(paint, y, left, cover)
  }
}

///|
/// Fill an axis-aligned rounded rectangle with sampled coverage.
///
/// Returns `false` when the transform is not an axis-aligned uniform scale, so
/// callers can fall back to the generic path instead.
fn Canvas::fill_rounded_rect_coverage(
  self : Canvas,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  radius : Double,
  paint : Paint,
) -> Bool {
  guard w > 0.0 && h > 0.0 else { return true }
  guard paint.style is Fill else { return true }
  match self.uniform_device_scale() {
    Some(scale) => {
      let x0 = x * scale + self.transform.tx
      let y0 = y * scale + self.transform.ty
      let x1 = (x + w) * scale + self.transform.tx
      let y1 = (y + h) * scale + self.transform.ty
      let device_radius = radius * scale
      let span_at = sample_y => {
        sun_rounded_rect_span_at(x0, y0, x1, y1, device_radius, sample_y)
      }
      self.fill_span_shape(paint, x0, y0, x1, y1, span_at, None)
      true
    }
    None => false
  }
}

///|
/// Stroke an axis-aligned rounded rectangle with sampled coverage.
///
/// The ring is the union of the outer rounded rect minus the inner one, which
/// gives both edges the same analytic accuracy as a filled shape. A dashed
/// stroke keeps the generic path, since the ring model does not describe it.
fn Canvas::stroke_rounded_rect_coverage(
  self : Canvas,
  x : Double,
  y : Double,
  w : Double,
  h : Double,
  radius : Double,
  paint : Paint,
) -> Bool {
  guard w > 0.0 && h > 0.0 else { return true }
  guard paint.style is Stroke else { return true }
  guard paint.stroke_width > 0.0 else { return true }
  guard paint.stroke_dash_pattern.is_empty() else { return false }
  match self.uniform_device_scale() {
    Some(scale) => {
      let half = paint.stroke_width * scale * 0.5
      let x0 = x * scale + self.transform.tx - half
      let y0 = y * scale + self.transform.ty - half
      let x1 = (x + w) * scale + self.transform.tx + half
      let y1 = (y + h) * scale + self.transform.ty + half
      let outer_radius = radius * scale + half
      let inner_radius = (radius * scale - half).max(0.0)
      let inner_x0 = x0 + half * 2.0
      let inner_y0 = y0 + half * 2.0
      let inner_x1 = x1 - half * 2.0
      let inner_y1 = y1 - half * 2.0
      let has_hole = inner_x1 > inner_x0 && inner_y1 > inner_y0
      let span_at = sample_y => {
        sun_rounded_rect_span_at(x0, y0, x1, y1, outer_radius, sample_y)
      }
      let hole_span_at = if has_hole {
        Some(fn(sample_y : Double) -> (Double, Double) {
          sun_rounded_rect_span_at(
            inner_x0, inner_y0, inner_x1, inner_y1, inner_radius, sample_y,
          )
        })
      } else {
        None
      }
      self.fill_span_shape(paint, x0, y0, x1, y1, span_at, hole_span_at)
      true
    }
    None => false
  }
}
