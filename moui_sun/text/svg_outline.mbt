///|
/// Flattened outline of one laid-out text run, in user-space coordinates.
pub(all) struct TextRunOutline {
  /// Total advance width of the laid-out run in user units.
  width : Double
  /// Closed polygons for the run, outer contours and holes alike. Windings
  /// come straight from the font, so a nonzero fill rule preserves holes.
  polygons : Array[Array[(Double, Double)]]
} derive(Debug)

///|
/// Flatten every glyph contour of `text` laid out with `font_size` so that the
/// run starts at `origin_x` and sits on the baseline `baseline_y`. Composite
/// glyphs fall back to nothing (matching the rasterizer), so callers pairing
/// this with a bitmap fallback keep full coverage.
pub fn FontFace::text_run_outline(
  self : FontFace,
  text : String,
  font_size : Double,
  origin_x : Double,
  baseline_y : Double,
  target_length? : Double,
) -> TextRunOutline {
  let layout = layout_text_face(
    self,
    text,
    LayoutConfig::new(font_size~, alignment=TextAlign::Left),
  )
  let font = self.get_font()
  let upem = self.get_units_per_em().to_double()
  let scale = if upem > 0.0 { font_size / upem } else { 1.0 }
  // SVG textLength="spacing" semantics: advances compress (or expand) so the
  // run spans exactly the target length while glyph shapes stay unscaled.
  let length_factor = match target_length {
    Some(target) =>
      if target > 0.0 && layout.get_width() > 0.0 {
        target / layout.get_width()
      } else {
        1.0
      }
    None => 1.0
  }
  let polygons : Array[Array[(Double, Double)]] = []
  // Layout positions runs below a top-of-box origin; re-anchor them so the
  // caller's y is the text baseline itself.
  let layout_baseline = layout.get_baseline()
  for run in layout.get_runs() {
    let run_baseline = baseline_y + (run.get_baseline_y() - layout_baseline)
    for glyph in run.get_glyphs() {
      let pen_x = origin_x + glyph.x * length_factor
      match font.get_glyph(glyph.glyph_id) {
        GlyphData::Simple(simple) =>
          for contour in simple.contours {
            let polygon = flatten_contour_polygon(
              contour,
              pen_x,
              run_baseline,
              scale,
            )
            if polygon.length() >= 3 {
              polygons.push(polygon)
            }
          }
        _ => ()
      }
    }
  }
  TextRunOutline::{
    width: match target_length {
      Some(target) if target > 0.0 => target
      _ => layout.get_width()
    },
    polygons,
  }
}

///|
/// Flatten one TrueType contour into an ordered closed polygon in user space.
/// The contour ring is walked from its first on-curve point; quadratic
/// segments subdivide into a bounded number of chords and close back to the
/// anchor point, including the implicit-endpoint case where the ring ends on
/// an off-curve control point.
fn flatten_contour_polygon(
  contour : GlyphContour,
  origin_x : Double,
  baseline_y : Double,
  scale : Double,
) -> Array[(Double, Double)] {
  let out : Array[(Double, Double)] = []
  let count = contour.points.length()
  if count < 2 {
    return out
  }
  let points = contour.points
  // Anchor the walk on the first on-curve point; a contour made entirely of
  // off-curve points is promoted by inserting implicit on-curve midpoints.
  let mut start = -1
  for i in 0..<count {
    if points[i].on_curve {
      start = i
      break
    }
  }
  if start < 0 {
    let midpoints : Array[GlyphPoint] = []
    for i in 0..<count {
      let a = points[i]
      let b = points[(i + 1) % count]
      midpoints.push(
        { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2, on_curve: true },
      )
    }
    return flatten_contour_polygon(
      { points: midpoints },
      origin_x,
      baseline_y,
      scale,
    )
  }
  fn emit(x : Int, y : Int) -> Unit {
    out.push((origin_x + x.to_double() * scale, baseline_y - y.to_double() * scale))
  }

  /// Subdivide the quadratic with control point `ctrl` and on-curve end `end`,
  /// emitting interior points; the caller emits `end` itself.
  fn quad_steps(
    from : GlyphPoint,
    ctrl : GlyphPoint,
    end : GlyphPoint,
  ) -> Int {
    let dx = (from.x - ctrl.x).to_double().abs() +
      (ctrl.x - end.x).to_double().abs()
    let dy = (from.y - ctrl.y).to_double().abs() +
      (ctrl.y - end.y).to_double().abs()
    let extent = if dx > dy { dx } else { dy }
    let steps = (extent * 0.25).ceil().to_int()
    if steps < 2 {
      2
    } else if steps > 12 {
      12
    } else {
      steps
    }
  }

  fn emit_quad(
    ctrl : GlyphPoint,
    end : GlyphPoint,
    from : GlyphPoint,
  ) -> Unit {
    let steps = quad_steps(from, ctrl, end)
    for s = 1; s < steps; s = s + 1 {
      let t = s.to_double() / steps.to_double()
      let inv = 1.0 - t
      let x = inv * inv * from.x.to_double() +
        2.0 * inv * t * ctrl.x.to_double() +
        t * t * end.x.to_double()
      let y = inv * inv * from.y.to_double() +
        2.0 * inv * t * ctrl.y.to_double() +
        t * t * end.y.to_double()
      out.push((origin_x + x * scale, baseline_y - y * scale))
    }
  }

  fn midpoint(a : GlyphPoint, b : GlyphPoint) -> GlyphPoint {
    { x: (a.x + b.x) / 2, y: (a.y + b.y) / 2, on_curve: true }
  }

  let anchor = points[start]
  emit(anchor.x, anchor.y)
  let mut pending : GlyphPoint? = None
  let mut previous = anchor
  for step = 1; step <= count; step = step + 1 {
    let point = points[(start + step) % count]
    let is_anchor_wrap = step == count
    match pending {
      Some(ctrl) =>
        if is_anchor_wrap {
          emit_quad(ctrl, anchor, previous)
          pending = None
        } else if point.on_curve {
          emit_quad(ctrl, point, previous)
          emit(point.x, point.y)
          pending = None
          previous = point
        } else {
          let mid = midpoint(ctrl, point)
          emit_quad(ctrl, mid, previous)
          emit(mid.x, mid.y)
          pending = Some(point)
          previous = mid
        }
      None =>
        if is_anchor_wrap {
          // The ring closes with an explicit segment back to the anchor.
          emit(point.x, point.y)
        } else if point.on_curve {
          emit(point.x, point.y)
          previous = point
        } else {
          pending = Some(point)
        }
    }
  }
  out
}
