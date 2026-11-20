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
/// Add the parts of `span` outside `[band_lo, band_hi)` into `cover`.
///
/// The sampled rows of one shape share a band every sub-scanline covers, so the
/// band is accumulated once at full weight and each sample only contributes its
/// fringe — the few pixels that stick out of the band. On a wide control that
/// turns sixteen full-width passes per row into one band pass plus sixteen
/// narrow ones.
fn sun_accumulate_span_outside(
  cover : Array[Double],
  left : Int32,
  span : (Double, Double),
  weight : Double,
  band_lo : Double,
  band_hi : Double,
) -> Unit {
  if span.0 < band_lo {
    sun_accumulate_span_coverage(
      cover,
      left,
      (span.0, span.1.min(band_lo)),
      weight,
    )
  }
  if span.1 > band_hi {
    sun_accumulate_span_coverage(
      cover,
      left,
      (span.0.max(band_hi), span.1),
      weight,
    )
  }
}

///|
/// Zero one slice of the coverage buffer.
///
/// The buffer is reused across the rows of a single shape and a straight row
/// only reads the pixels its own span touches, so clearing the rest of the row
/// — previously the whole shape width on every row — is wasted work.
fn sun_zero_cover_range(
  cover : Array[Double],
  left : Int32,
  first : Int32,
  end : Int32,
) -> Unit {
  let start = first.max(left) - left
  let stop = end.min(left + cover.length()) - left
  if stop <= start {
    return
  }
  for index in start..<stop {
    cover[index] = 0.0
  }
}

///|
/// Add one pixel that straddles a hole edge of a ring.
///
/// `inner` is contained in `outer`, so a pixel fully inside the hole adds
/// nothing; only the two pixels the hole edges cut through carry a fraction.
fn sun_accumulate_ring_edge_pixel(
  cover : Array[Double],
  left : Int32,
  outer : (Double, Double),
  inner : (Double, Double),
  px : Int32,
  weight : Double,
) -> Unit {
  let outer_overlap = (px + 1).to_double().min(outer.1) -
    outer.0.max(px.to_double())
  let inner_overlap = (px + 1).to_double().min(inner.1) -
    inner.0.max(px.to_double())
  let overlap = (outer_overlap.max(0.0) - inner_overlap.max(0.0)).max(0.0)
  if overlap > 0.0 {
    let index = px - left
    if index >= 0 && index < cover.length() {
      cover[index] = cover[index] + overlap * weight
    }
  }
}

///|
/// Accumulate a ring — an outer span minus a fully contained inner span —
/// without visiting the pixels both spans cover.
///
/// A rounded-rect border used to accumulate the outer span and then the inner
/// one with a negative weight, so every interior pixel was visited twice and
/// cancelled out. Only the two edge bands and the two pixels that straddle the
/// hole edges carry non-zero coverage, so this walks the outer span once and
/// skips the interior entirely — a straight row of a wide border costs the two
/// side bands instead of the whole width.
fn sun_accumulate_ring_coverage(
  cover : Array[Double],
  left : Int32,
  outer : (Double, Double),
  inner : (Double, Double),
  weight : Double,
) -> Unit {
  let ox0 = outer.0
  let ox1 = outer.1
  if ox1 <= ox0 {
    return
  }
  let ix0 = inner.0.max(ox0)
  let ix1 = inner.1.min(ox1)
  if ix1 <= ix0 {
    sun_accumulate_span_coverage(cover, left, outer, weight)
    return
  }
  let first_px = ox0.floor().to_int()
  let last_px = ox1.floor().to_int()
  let hole_first = ix0.floor().to_int()
  let hole_last = ix1.floor().to_int()
  // Pixels entirely left of the hole keep the plain outer overlap.
  for px in first_px..<hole_first {
    let overlap = ((px + 1).to_double().min(ox1) - ox0.max(px.to_double())).max(
      0.0,
    )
    if overlap > 0.0 {
      let index = px - left
      if index >= 0 && index < cover.length() {
        cover[index] = cover[index] + overlap * weight
      }
    }
  }
  // Pixels the hole touches take the part of the outer span it does not cover;
  // inner is contained in outer, so this stays non-negative. Every pixel
  // strictly between the two edges is fully covered by both spans and would add
  // exactly zero, so only the two straddling pixels are visited.
  sun_accumulate_ring_edge_pixel(cover, left, outer, inner, hole_first, weight)
  if hole_last > hole_first {
    sun_accumulate_ring_edge_pixel(cover, left, outer, inner, hole_last, weight)
  }
  for px in (hole_last + 1)..<=last_px {
    let overlap = ((px + 1).to_double().min(ox1) - ox0.max(px.to_double())).max(
      0.0,
    )
    if overlap > 0.0 {
      let index = px - left
      if index >= 0 && index < cover.length() {
        cover[index] = cover[index] + overlap * weight
      }
    }
  }
}

///|
/// Per-channel lookup tables for one translucent solid SourceOver paint.
///
/// A straight row of a solid paint is fully covered across its span, so the
/// interior only needs `dst * inverse + src * weight` per channel. A table
/// lookup replaces the multiply-and-divide the coverage formula costs on every
/// pixel — the per-pixel integer divisions that dominate unoptimised builds.
priv struct SunSolidLerp {
  red : FixedArray[Byte]
  green : FixedArray[Byte]
  blue : FixedArray[Byte]
}

///|
fn SunSolidLerp::new(color : Color) -> SunSolidLerp {
  let weight = color.a.to_int()
  let inverse = 255 - weight
  let red : FixedArray[Byte] = FixedArray::make(256, 0)
  let green : FixedArray[Byte] = FixedArray::make(256, 0)
  let blue : FixedArray[Byte] = FixedArray::make(256, 0)
  for dst in 0..<256 {
    let dst_byte = clamp_byte(dst)
    red[dst] = sun_lerp_channel(color.r, dst_byte, weight, inverse)
    green[dst] = sun_lerp_channel(color.g, dst_byte, weight, inverse)
    blue[dst] = sun_lerp_channel(color.b, dst_byte, weight, inverse)
  }
  { red, green, blue, }
}

///|
/// One pixel of a straight-row span of a solid paint.
///
/// `covered` is derived from the analytic span edges; a pixel fully inside
/// `[first_full, end_full)` is full coverage. Returns whether the pixel was
/// written, for the caller's dirty bookkeeping.
fn Canvas::fill_solid_span_pixel(
  self : Canvas,
  color : Color,
  blend_mode : BlendMode,
  lerp : SunSolidLerp?,
  y : Int32,
  px : Int32,
  first_full : Int32,
  end_full : Int32,
  x_left : Double,
  x_right : Double,
) -> Bool {
  let pixmap = self.pixmap
  let pixels = pixmap.pixels
  let row_offset = y * pixmap.width
  let src_a = color.a.to_int()
  let full_alpha = clamp_byte(255)
  let covered = if px >= first_full && px < end_full {
    255
  } else {
    let overlap = (x_right.min((px + 1).to_double()) -
    x_left.max(px.to_double())).max(0.0)
    if overlap >= 1.0 {
      255
    } else {
      (overlap * 255.0 + 0.5).to_int()
    }
  }
  if covered <= 0 {
    return false
  }
  let weight = if covered == 255 {
    src_a
  } else {
    (src_a * covered + 127) / 255
  }
  let offset = (row_offset + px) * 4
  if blend_mode is Source {
    pixels[offset] = color.r
    pixels[offset + 1] = color.g
    pixels[offset + 2] = color.b
    pixels[offset + 3] = clamp_byte(weight)
    return true
  }
  if pixels[offset + 3] != full_alpha {
    return blend_coverage_pixel(pixmap, px, y, color, covered, 255, SourceOver)
  }
  if weight == 255 {
    pixels[offset] = color.r
    pixels[offset + 1] = color.g
    pixels[offset + 2] = color.b
    return true
  }
  if weight <= 0 {
    return false
  }
  if covered == 255 {
    match lerp {
      Some(table) => {
        pixels[offset] = table.red[pixels[offset].to_int()]
        pixels[offset + 1] = table.green[pixels[offset + 1].to_int()]
        pixels[offset + 2] = table.blue[pixels[offset + 2].to_int()]
      }
      None => {
        let inverse = 255 - weight
        pixels[offset] = sun_lerp_channel(
          color.r,
          pixels[offset],
          weight,
          inverse,
        )
        pixels[offset + 1] = sun_lerp_channel(
          color.g,
          pixels[offset + 1],
          weight,
          inverse,
        )
        pixels[offset + 2] = sun_lerp_channel(
          color.b,
          pixels[offset + 2],
          weight,
          inverse,
        )
      }
    }
  } else {
    let inverse = 255 - weight
    pixels[offset] = sun_lerp_channel(color.r, pixels[offset], weight, inverse)
    pixels[offset + 1] = sun_lerp_channel(
      color.g,
      pixels[offset + 1],
      weight,
      inverse,
    )
    pixels[offset + 2] = sun_lerp_channel(
      color.b,
      pixels[offset + 2],
      weight,
      inverse,
    )
  }
  true
}

///|
/// Write one straight-row span of a solid paint directly into the pixmap.
///
/// A straight row has full coverage across its span, so neither the coverage
/// buffer nor the generic per-pixel path is needed. A fully opaque paint
/// (`row_pattern` present) makes every fully covered pixel the paint colour
/// whatever the destination was — Porter-Duff with `sa == 255` collapses to a
/// copy under both Source and SourceOver — so the span interior is one bulk
/// blit of a colour row built once per shape. Only the pixels under a
/// fractional span edge evaluate the coverage formula, and a non-opaque
/// destination keeps the general path.
fn Canvas::fill_solid_span_row(
  self : Canvas,
  color : Color,
  blend_mode : BlendMode,
  lerp : SunSolidLerp?,
  row_pattern : FixedArray[Byte]?,
  y : Int32,
  clip_left : Int32,
  clip_right : Int32,
  x_left : Double,
  x_right : Double,
) -> Unit {
  if x_right <= x_left || clip_left >= clip_right {
    return
  }
  let pixmap = self.pixmap
  let pixels = pixmap.pixels
  let row_offset = y * pixmap.width
  // [first_full, end_full) are the pixels the span covers completely.
  let first_full = clip_left.max(x_left.ceil().to_int())
  let end_full = clip_right.min(x_right.floor().to_int())
  let first_px = clip_left.max(x_left.floor().to_int())
  let last_px = clip_right.min(x_right.floor().to_int() + 1)
  let mut dirty_start = clip_right
  let mut dirty_end = clip_left
  let mut interior_lo = last_px
  let mut interior_hi = last_px
  match row_pattern {
    Some(pattern) => {
      let lo = first_full.max(first_px)
      let hi = end_full.min(last_px)
      if lo < hi {
        FixedArray::unsafe_blit(
          pixels,
          (row_offset + lo) * 4,
          pattern,
          0,
          (hi - lo) * 4,
        )
        interior_lo = lo
        interior_hi = hi
        dirty_start = dirty_start.min(lo)
        dirty_end = dirty_end.max(hi)
      }
    }
    None => ()
  }
  if first_px < interior_lo {
    for px in first_px..<interior_lo {
      if self.fill_solid_span_pixel(
          color, blend_mode, lerp, y, px, first_full, end_full, x_left, x_right,
        ) {
        dirty_start = dirty_start.min(px)
        dirty_end = dirty_end.max(px + 1)
      }
    }
  }
  if interior_hi < last_px {
    for px in interior_hi..<last_px {
      if self.fill_solid_span_pixel(
          color, blend_mode, lerp, y, px, first_full, end_full, x_left, x_right,
        ) {
        dirty_start = dirty_start.min(px)
        dirty_end = dirty_end.max(px + 1)
      }
    }
  }
  if dirty_start < dirty_end {
    self.mark_dirty_bounds(dirty_start, y, dirty_end, y + 1)
  }
}

///|
/// Blend one accumulated coverage row into the pixmap.
///
/// The paint sampler is built once per shape and reused for every pixel, so a
/// gradient row pays one matrix inversion (already) instead of one per pixel;
/// solid paints sample a precomputed constant. Dirty bookkeeping is per row.
fn Canvas::blend_coverage_row(
  self : Canvas,
  paint : Paint,
  sampler : PaintSampler,
  y : Int32,
  left : Int32,
  cover : Array[Double],
  first : Int32,
  end : Int32,
) -> Unit {
  // Solid paints take a dedicated row loop: the generic path builds a
  // coverage-scaled colour and runs the full Porter-Duff pipeline per pixel,
  // which is several integer divisions on every touched pixel. Solid fills are
  // the dominant control-surface case and only need a 255-weight lerp (or a
  // plain copy at full coverage) over the opaque clear colour.
  if sampler.is_solid && paint.blend_mode is SourceOver {
    self.blend_solid_coverage_row(sampler.constant, y, left, cover, first, end)
    return
  }
  if sampler.is_solid && paint.blend_mode is Source {
    self.copy_solid_coverage_row(sampler.constant, y, left, cover, first, end)
    return
  }
  let mut dirty_start = end
  let mut dirty_end = first
  let start = first.max(left)
  let stop = end.min(left + cover.length())
  for px in start..<stop {
    let index = px - left
    let coverage = cover[index].min(1.0)
    if coverage > 0.0 {
      let covered = (coverage * 255.0 + 0.5).to_int()
      if covered > 0 {
        let color = sampler.sample(px.to_double() + 0.5, y.to_double() + 0.5)
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
          dirty_start = dirty_start.min(px)
          dirty_end = dirty_end.max(px + 1)
        }
      }
    }
  }
  if dirty_start < dirty_end {
    self.mark_dirty_bounds(dirty_start, y, dirty_end, y + 1)
  }
}

///|
/// One channel of `src * weight + dst * inverse`, weight + inverse == 255.
///
/// The literal 255 divisor lets the native backend strength-reduce the
/// division, and the formula matches `Color::blend_over`'s rounding exactly for
/// an opaque destination.
fn sun_lerp_channel(
  src : Byte,
  dst : Byte,
  weight : Int32,
  inverse : Int32,
) -> Byte {
  clamp_byte((src.to_int() * weight + dst.to_int() * inverse + 127) / 255)
}

///|
/// Coverage-blend one row of a solid paint under SourceOver.
///
/// Over the opaque clear colour every touched pixel keeps `a == 255`, so the
/// Porter-Duff result collapses to a per-channel lerp and the full-coverage
/// case is a plain copy. Non-opaque destinations — retained layers and nested
/// opacity scopes — keep the general path.
fn Canvas::blend_solid_coverage_row(
  self : Canvas,
  color : Color,
  y : Int32,
  left : Int32,
  cover : Array[Double],
  first : Int32,
  end : Int32,
) -> Unit {
  let pixmap = self.pixmap
  let pixels = pixmap.pixels
  let row_offset = y * pixmap.width
  let src_a = color.a.to_int()
  let full_alpha = clamp_byte(255)
  let mut dirty_start = end
  let mut dirty_end = first
  for px in first.max(left)..<end.min(left + cover.length()) {
    let coverage = cover[px - left]
    if coverage > 0.0 {
      let covered = if coverage >= 1.0 {
        255
      } else {
        (coverage * 255.0 + 0.5).to_int()
      }
      if covered > 0 {
        let offset = (row_offset + px) * 4
        let mut wrote = false
        if pixels[offset + 3] == full_alpha {
          let weight = if covered == 255 {
            src_a
          } else {
            (src_a * covered + 127) / 255
          }
          if weight == 255 {
            pixels[offset] = color.r
            pixels[offset + 1] = color.g
            pixels[offset + 2] = color.b
            wrote = true
          } else if weight > 0 {
            let inverse = 255 - weight
            pixels[offset] = sun_lerp_channel(
              color.r,
              pixels[offset],
              weight,
              inverse,
            )
            pixels[offset + 1] = sun_lerp_channel(
              color.g,
              pixels[offset + 1],
              weight,
              inverse,
            )
            pixels[offset + 2] = sun_lerp_channel(
              color.b,
              pixels[offset + 2],
              weight,
              inverse,
            )
            wrote = true
          }
        } else {
          wrote = blend_coverage_pixel(
            pixmap,
            px,
            y,
            color,
            covered,
            255,
            SourceOver,
          )
        }
        if wrote {
          dirty_start = dirty_start.min(px)
          dirty_end = dirty_end.max(px + 1)
        }
      }
    }
  }
  if dirty_start < dirty_end {
    self.mark_dirty_bounds(dirty_start, y, dirty_end, y + 1)
  }
}

///|
/// Coverage-blend one row of a solid paint under Source: the destination is
/// replaced outright, only the source alpha follows the coverage.
fn Canvas::copy_solid_coverage_row(
  self : Canvas,
  color : Color,
  y : Int32,
  left : Int32,
  cover : Array[Double],
  first : Int32,
  end : Int32,
) -> Unit {
  let pixmap = self.pixmap
  let pixels = pixmap.pixels
  let row_offset = y * pixmap.width
  let src_a = color.a.to_int()
  let mut dirty_start = end
  let mut dirty_end = first
  for px in first.max(left)..<end.min(left + cover.length()) {
    let coverage = cover[px - left]
    if coverage > 0.0 {
      let covered = if coverage >= 1.0 {
        255
      } else {
        (coverage * 255.0 + 0.5).to_int()
      }
      if covered > 0 {
        let weight = if covered == 255 {
          src_a
        } else {
          (src_a * covered + 127) / 255
        }
        let offset = (row_offset + px) * 4
        pixels[offset] = color.r
        pixels[offset + 1] = color.g
        pixels[offset + 2] = color.b
        pixels[offset + 3] = clamp_byte(weight)
        dirty_start = dirty_start.min(px)
        dirty_end = dirty_end.max(px + 1)
      }
    }
  }
  if dirty_start < dirty_end {
    self.mark_dirty_bounds(dirty_start, y, dirty_end, y + 1)
  }
}

///|
/// Grow-on-demand coverage row shared by every shape fill on this canvas.
fn Canvas::cover_scratch_for(self : Canvas, width : Int32) -> Array[Double] {
  if self.cover_scratch.length() < width {
    self.cover_scratch = Array::make(width, 0.0)
  }
  self.cover_scratch
}

///|
/// Grow-on-demand fully opaque colour row for bulk span blits. Rewritten only
/// when the colour changes; a frame of same-coloured fills pays one pass.
fn Canvas::solid_pattern_for(
  self : Canvas,
  color : Color,
  width : Int32,
) -> FixedArray[Byte] {
  let bytes = width * 4
  let red = color.r.to_int()
  let green = color.g.to_int()
  let blue = color.b.to_int()
  let reusable = self.solid_pattern_scratch.length() >= bytes &&
    self.solid_pattern_red == red &&
    self.solid_pattern_green == green &&
    self.solid_pattern_blue == blue
  if !reusable {
    if self.solid_pattern_scratch.length() < bytes {
      self.solid_pattern_scratch = FixedArray::make(bytes, clamp_byte(255))
    }
    let pattern = self.solid_pattern_scratch
    for px in 0..<width {
      pattern[px * 4] = color.r
      pattern[px * 4 + 1] = color.g
      pattern[px * 4 + 2] = color.b
    }
    self.solid_pattern_red = red
    self.solid_pattern_green = green
    self.solid_pattern_blue = blue
  }
  self.solid_pattern_scratch
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
  straight_row : ((Double) -> Bool)?,
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
  let cover = self.cover_scratch_for(width)
  let step = 1.0 / sun_shape_coverage_steps.to_double()
  let sampler = self.paint_sampler(paint)
  // Straight rows of a solid paint skip the coverage buffer entirely: the span
  // is constant across the row, so a pixel is either fully covered or carries a
  // single analytic edge fraction. `solid_lerp` is the per-channel table used by
  // translucent SourceOver fills over the opaque clear colour.
  let solid = sampler.is_solid &&
    (paint.blend_mode is SourceOver || paint.blend_mode is Source)
  let solid_color = sampler.constant
  let solid_lerp = if sampler.is_solid &&
    paint.blend_mode is SourceOver &&
    solid_color.a.to_int() > 0 &&
    solid_color.a.to_int() < 255 {
    Some(SunSolidLerp::new(solid_color))
  } else {
    None
  }
  // A fully opaque solid paint overwrites the destination outright, so a
  // straight span's interior can be a bulk copy of this colour row. Build it
  // once per shape — one pixel pass against the many rows that blit it.
  let solid_pattern : FixedArray[Byte]? = if solid &&
    solid_color.a.to_int() == 255 {
    Some(self.solid_pattern_for(solid_color, width))
  } else {
    None
  }
  for y in top..<bottom {
    let row_centre = y.to_double() + 0.5
    // A row that stays inside both straight bands has the same span on every
    // sub-scanline, so one full-weight sample replaces the sixteen and the
    // interior of a large control stops paying arc-sampling cost per row.
    let straight = match straight_row {
      Some(is_straight) => is_straight(row_centre)
      None => false
    }
    if straight {
      let span = span_at(row_centre)
      // Only the pixels this row can touch are zeroed and blended; stale
      // coverage outside the span is never read by a range-limited blend.
      let first_px = left.max(span.0.floor().to_int())
      let end_px = right.min(span.1.floor().to_int() + 1)
      match hole_span_at {
        None =>
          if solid {
            self.fill_solid_span_row(
              solid_color,
              paint.blend_mode,
              solid_lerp,
              solid_pattern,
              y,
              left,
              right,
              span.0,
              span.1,
            )
          } else {
            sun_zero_cover_range(cover, left, first_px, end_px)
            sun_accumulate_span_coverage(cover, left, span, 1.0)
            self.blend_coverage_row(
              paint, sampler, y, left, cover, first_px, end_px,
            )
          }
        Some(hole_span) => {
          let hole = hole_span(row_centre)
          let ix0 = hole.0.max(span.0)
          let ix1 = hole.1.min(span.1)
          if ix1 <= ix0 {
            // No hole on this row after clipping: a plain full-span row.
            sun_zero_cover_range(cover, left, first_px, end_px)
            sun_accumulate_span_coverage(cover, left, span, 1.0)
            self.blend_coverage_row(
              paint, sampler, y, left, cover, first_px, end_px,
            )
          } else {
            // The hole cancels the interior outright, so only the two side bands
            // and the pixels straddling the hole edges carry coverage. Blending
            // (and zeroing) only those two windows keeps a wide border row a
            // couple of pixels wide instead of a full surface-width pass.
            let hole_first = left.max(ix0.floor().to_int())
            let hole_last = right.min(ix1.floor().to_int())
            let left_end = end_px.min(hole_first + 1)
            let right_start = left_end.max(hole_last)
            sun_zero_cover_range(cover, left, first_px, left_end)
            if right_start < end_px {
              sun_zero_cover_range(cover, left, right_start, end_px)
            }
            sun_accumulate_ring_coverage(cover, left, span, hole, 1.0)
            self.blend_coverage_row(
              paint, sampler, y, left, cover, first_px, left_end,
            )
            if right_start < end_px {
              self.blend_coverage_row(
                paint, sampler, y, left, cover, right_start, end_px,
              )
            }
          }
        }
      }
    } else {
      // Sampled rows: the sixteen sub-scanline spans of one row share a band
      // that every sample covers, so that band is accumulated once at full
      // weight and each sample only contributes the fringe pixels outside it.
      // A wide control's corner rows stop walking the whole width sixteen
      // times, which is what dominates an unoptimised build.
      let steps = sun_shape_coverage_steps
      let outer_lo = self.sample_outer_lo
      let outer_hi = self.sample_outer_hi
      let hole_lo = self.sample_hole_lo
      let hole_hi = self.sample_hole_hi
      let mut band_lo = 0.0
      let mut band_hi = 0.0
      let mut union_lo = 0.0
      let mut union_hi = 0.0
      let mut hole_band_lo = 0.0
      let mut hole_band_hi = 0.0
      let mut hole_band_ok = true
      for sample in 0..<steps {
        let sample_y = y.to_double() + (sample.to_double() + 0.5) * step
        let span = span_at(sample_y)
        outer_lo[sample] = span.0
        outer_hi[sample] = span.1
        let hole = match hole_span_at {
          Some(hole_span) => hole_span(sample_y)
          None => (span.0, span.0)
        }
        hole_lo[sample] = hole.0
        hole_hi[sample] = hole.1
        if sample == 0 {
          band_lo = span.0
          band_hi = span.1
          union_lo = span.0
          union_hi = span.1
          hole_band_lo = hole.0
          hole_band_hi = hole.1
          hole_band_ok = hole.1 > hole.0
        } else {
          band_lo = band_lo.max(span.0)
          band_hi = band_hi.min(span.1)
          union_lo = union_lo.min(span.0)
          union_hi = union_hi.max(span.1)
          // A row where one sample misses the hole entirely keeps the shared
          // hole band empty; the hole then accumulates per sample like before.
          if hole_band_ok {
            if hole.1 > hole.0 {
              hole_band_lo = hole_band_lo.max(hole.0)
              hole_band_hi = hole_band_hi.min(hole.1)
            } else {
              hole_band_ok = false
            }
          }
        }
      }
      let band_ok = band_hi > band_lo
      let first_px = left.max(union_lo.floor().to_int())
      let end_px = right.min(union_hi.floor().to_int() + 1)
      // The part of a sampled row that every sub-scanline covers is fully
      // covered, so a fully opaque solid paint bulk-copies it and only the
      // fringe pixels outside the band carry accumulated coverage. A ring
      // cancels the band through its hole, so it keeps the general path.
      let mut band_px_lo = end_px
      let mut band_px_hi = end_px
      let mut band_blit = false
      if band_ok && hole_span_at is None {
        match solid_pattern {
          Some(pattern) => {
            let lo = left.max(band_lo.ceil().to_int())
            let hi = right.min(band_hi.floor().to_int())
            if lo < hi {
              FixedArray::unsafe_blit(
                self.pixmap.pixels,
                (y * self.pixmap.width + lo) * 4,
                pattern,
                0,
                (hi - lo) * 4,
              )
              band_px_lo = lo
              band_px_hi = hi
              band_blit = true
              self.mark_dirty_bounds(lo, y, hi, y + 1)
            }
          }
          None => ()
        }
      }
      if band_blit {
        if first_px < band_px_lo {
          sun_zero_cover_range(cover, left, first_px, band_px_lo)
        }
        if band_px_hi < end_px {
          sun_zero_cover_range(cover, left, band_px_hi, end_px)
        }
        // The two pixels the band edges cut through sit outside the blit but
        // still carry the band's partial overlap.
        if band_px_lo > left {
          let overlap = (band_px_lo.to_double().min(band_hi) - band_lo).max(0.0)
          let index = band_px_lo - left - 1
          if overlap > 0.0 && index >= 0 && index < cover.length() {
            cover[index] = cover[index] + overlap
          }
        }
        if band_px_hi < right {
          let overlap = (band_hi - band_px_hi.to_double()).max(0.0)
          let index = band_px_hi - left
          if overlap > 0.0 && index >= 0 && index < cover.length() {
            cover[index] = cover[index] + overlap
          }
        }
      } else {
        sun_zero_cover_range(cover, left, first_px, end_px)
        if band_ok {
          sun_accumulate_span_coverage(cover, left, (band_lo, band_hi), 1.0)
        }
      }
      for sample in 0..<steps {
        let span = (outer_lo[sample], outer_hi[sample])
        if band_ok {
          sun_accumulate_span_outside(cover, left, span, step, band_lo, band_hi)
        } else {
          sun_accumulate_span_coverage(cover, left, span, step)
        }
      }
      match hole_span_at {
        None => ()
        Some(_) => {
          if hole_band_ok {
            sun_accumulate_span_coverage(
              cover,
              left,
              (hole_band_lo, hole_band_hi),
              -1.0,
            )
          }
          for sample in 0..<steps {
            let hole = (hole_lo[sample], hole_hi[sample])
            if hole_band_ok {
              sun_accumulate_span_outside(
                cover,
                left,
                hole,
                -step,
                hole_band_lo,
                hole_band_hi,
              )
            } else {
              sun_accumulate_span_coverage(cover, left, hole, -step)
            }
          }
        }
      }
      if band_blit {
        // The band pixels are already painted, so only the fringe windows are
        // blended; their coverage entries are the only ones the accumulation
        // above touched.
        if first_px < band_px_lo {
          self.blend_coverage_row(
            paint, sampler, y, left, cover, first_px, band_px_lo,
          )
        }
        if band_px_hi < end_px {
          self.blend_coverage_row(
            paint, sampler, y, left, cover, band_px_hi, end_px,
          )
        }
      } else {
        self.blend_coverage_row(
          paint, sampler, y, left, cover, first_px, end_px,
        )
      }
    }
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
      // Rows wholly inside the straight side band have one span for the whole
      // row; only the corner bands need the sixteen sub-scanline samples.
      let straight_row = fn(row_centre : Double) -> Bool {
        row_centre - 0.5 >= y0 + device_radius &&
        row_centre + 0.5 <= y1 - device_radius
      }
      self.fill_span_shape(
        paint,
        x0,
        y0,
        x1,
        y1,
        span_at,
        None,
        Some(straight_row),
      )
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
      // A row is straight when both the outer span and (if present) the hole
      // span are constant across it: the outer row must be inside the outer
      // side band, and the hole must be wholly in its own straight band or
      // wholly outside the inner rectangle.
      let straight_row = fn(row_centre : Double) -> Bool {
        let row_top = row_centre - 0.5
        let row_bottom = row_centre + 0.5
        let outer_straight = if outer_radius <= 0.0 {
          row_top >= y0 && row_bottom <= y1
        } else {
          row_top >= y0 + outer_radius && row_bottom <= y1 - outer_radius
        }
        if !outer_straight {
          false
        } else if !has_hole {
          true
        } else {
          (
            row_top >= inner_y0 + inner_radius &&
            row_bottom <= inner_y1 - inner_radius
          ) ||
          row_bottom <= inner_y0 ||
          row_top >= inner_y1
        }
      }
      self.fill_span_shape(
        paint,
        x0,
        y0,
        x1,
        y1,
        span_at,
        hole_span_at,
        Some(straight_row),
      )
      true
    }
    None => false
  }
}
