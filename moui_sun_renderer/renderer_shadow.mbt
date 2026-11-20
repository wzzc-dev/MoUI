///|
/// Identity of a rasterised shadow mask: device-pixel footprint plus colour.
///
/// Position is deliberately absent — placement happens at blit time — and so
/// is `opacity`, which the blit paint applies. A shadow that only moves, or
/// fades during a hover/press transition, therefore keeps its cached mask.
priv struct SunShadowMaskKey {
  width : Int32
  height : Int32
  pad : Int32
  inner_w : Double
  inner_h : Double
  radius : Double
  blur : Int32
  r : Byte
  g : Byte
  b : Byte
  a : Byte
}

///|
priv struct SunShadowMaskEntry {
  key : SunShadowMaskKey
  // Fully rasterised (and blurred) mask; `draw_shadow` only reads it.
  pixmap : @sun_graphics.Pixmap
}

///|
let sun_shadow_cache_capacity : Int32 = 8

///|
fn sun_shadow_mask_key_eq(a : SunShadowMaskKey, b : SunShadowMaskKey) -> Bool {
  a.width == b.width &&
  a.height == b.height &&
  a.pad == b.pad &&
  a.inner_w == b.inner_w &&
  a.inner_h == b.inner_h &&
  a.radius == b.radius &&
  a.blur == b.blur &&
  a.r == b.r &&
  a.g == b.g &&
  a.b == b.b &&
  a.a == b.a
}

///|
fn SunRasterRenderer::shadow_mask(
  self : SunRasterRenderer,
  key : SunShadowMaskKey,
) -> @sun_graphics.Pixmap {
  for entry in self.shadow_cache {
    if sun_shadow_mask_key_eq(entry.key, key) {
      return entry.pixmap
    }
  }
  self.rasterize_shadow_mask(key)
}

///|
fn SunRasterRenderer::rasterize_shadow_mask(
  self : SunRasterRenderer,
  key : SunShadowMaskKey,
) -> @sun_graphics.Pixmap {
  let shadow_pixmap = @sun_graphics.Pixmap::new(key.width, key.height)
  let pixels = shadow_pixmap.get_pixels()
  let cx = key.pad.to_double() + key.inner_w * 0.5
  let cy = key.pad.to_double() + key.inner_h * 0.5
  let hx = key.inner_w * 0.5
  let hy = key.inner_h * 0.5
  let radius = key.radius
  let sr = key.r
  let sg = key.g
  let sb = key.b
  let sa = key.a
  // Coverage is binary (`d < 0.5`), so every raster row is one contiguous run
  // of pixels: `|px - cx| < (hx - radius) + x_lim`. In the flat vertical band
  // `x_lim` is exactly `radius + 0.5`; past it the limit shrinks along the
  // corner arc as `sqrt((radius + 0.5)^2 - qy^2)`. That turns the old
  // per-pixel rounded-rect SDF (a sqrt for every pixel of the padded pixmap,
  // each written through `set_pixel`) into one sqrt and one span fill per row.
  let flat_x_lim = radius + 0.5
  let row_stride = key.width * 4
  for sy in 0..<key.height {
    let py = sy.to_double() + 0.5
    let qy = (py - cy).abs() - (hy - radius)
    let x_lim = if qy <= 0.0 {
      flat_x_lim
    } else {
      let reach = flat_x_lim * flat_x_lim - qy * qy
      if reach > 0.0 {
        reach.sqrt()
      } else {
        0.0
      }
    }
    if x_lim > 0.0 {
      let half_span = hx - radius + x_lim
      let x_start = (cx - half_span - 0.5).floor().to_int().max(0)
      let x_end = (cx + half_span - 0.5).ceil().to_int().min(key.width)
      let row = sy * row_stride
      for sx in x_start..<x_end {
        let offset = row + sx * 4
        pixels[offset] = sr
        pixels[offset + 1] = sg
        pixels[offset + 2] = sb
        pixels[offset + 3] = sa
      }
    }
  }
  let masked = if key.blur > 0 {
    sun_box_blur_pixmap(shadow_pixmap, key.blur.to_double())
  } else {
    shadow_pixmap
  }
  let cache = self.shadow_cache
  if cache.length() < sun_shadow_cache_capacity {
    cache.push({ key, pixmap: masked, })
  } else {
    // Round-robin eviction: a UI keeps only a handful of shadow styles alive,
    // and an evicted entry costs one mask raster plus three blur passes.
    cache[self.shadow_cache_next] = { key, pixmap: masked, }
    self.shadow_cache_next = (self.shadow_cache_next + 1) %
      sun_shadow_cache_capacity
  }
  masked
}

///|
fn SunRasterRenderer::draw_shadow(
  self : SunRasterRenderer,
  shadow : @core.ShadowSpec,
  opacity : Double,
) -> Unit {
  let rect = shadow.rect.rect
  let corner_radius = shadow.rect.radius.max(0.0)
  let base_color = shadow.color
  let spread = shadow.spread.max(0.0)
  let blur_r = shadow.blur_radius.max(0.0)
  guard opacity > 0.0 else { return }
  guard base_color.a > 0.0 else { return }
  // The offscreen shadow pixmap is rasterised in device pixels, so spread and
  // size scale by the surface scale factor; otherwise a DPR=2 surface renders
  // a shadow half the intended size. The blur kernel stays at `blur_radius`
  // device pixels to match the Skia mask-filter sigma, which is not
  // CTM-scaled; three box passes give a support of 3 * radius per side.
  let transform = self.canvas.get_transform()
  let scale = self.metrics.scale_factor
  let blur_px = blur_r
  let spread_dev = spread * scale
  let pad = (blur_px * 3.0).ceil().to_int().max(1)
  let inner_w = rect.size.width * scale + spread_dev * 2.0
  let inner_h = rect.size.height * scale + spread_dev * 2.0
  let shadow_w = inner_w.ceil().to_int().max(1) + pad * 2
  let shadow_h = inner_h.ceil().to_int().max(1) + pad * 2
  let mask_key : SunShadowMaskKey = {
    width: shadow_w,
    height: shadow_h,
    pad,
    inner_w,
    inner_h,
    radius: (corner_radius * scale).min(inner_w * 0.5).min(inner_h * 0.5),
    blur: blur_px.to_int(),
    r: sun_channel(base_color.r),
    g: sun_channel(base_color.g),
    b: sun_channel(base_color.b),
    a: sun_channel(base_color.a),
  }
  let masked = self.shadow_mask(mask_key)
  // Device-space blit: the shadow pixmap is rasterised in device pixels, so its
  // placement comes from the canvas transform instead of raw logical offsets.
  // Opacity is applied here rather than baked into the mask so animated
  // shadows reuse one cache entry.
  let (device_x, device_y) = transform.apply(
    rect.origin.x + shadow.offset.x - spread,
    rect.origin.y + shadow.offset.y - spread,
  )
  let draw_x = device_x.floor().to_int() - pad
  let draw_y = device_y.floor().to_int() - pad
  self.canvas.draw_pixmap(
    masked,
    draw_x,
    draw_y,
    @sun_graphics.Paint::new().set_opacity(opacity),
  )
}
