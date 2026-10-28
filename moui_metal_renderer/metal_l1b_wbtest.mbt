///|
fn metal_proof_pixel(
  pixels : Bytes,
  x : Int32,
  y : Int32,
  width : Int32,
) -> (Int32, Int32, Int32, Int32) {
  let index = (y * width + x) * 4
  (
    pixels[index].to_int(),
    pixels[index + 1].to_int(),
    pixels[index + 2].to_int(),
    pixels[index + 3].to_int(),
  )
}

///|
fn metal_is_red(pixel : (Int32, Int32, Int32, Int32)) -> Bool {
  pixel.0 > 200 && pixel.1 < 60 && pixel.2 < 60
}

///|
fn metal_is_green(pixel : (Int32, Int32, Int32, Int32)) -> Bool {
  pixel.0 < 60 && pixel.1 > 200 && pixel.2 < 60
}

///|
fn metal_is_blue(pixel : (Int32, Int32, Int32, Int32)) -> Bool {
  pixel.0 < 60 && pixel.1 < 130 && pixel.2 > 200
}

///|
fn metal_is_white(pixel : (Int32, Int32, Int32, Int32)) -> Bool {
  pixel.0 > 200 && pixel.1 > 200 && pixel.2 > 200 && pixel.3 > 200
}

///|
fn metal_is_black(pixel : (Int32, Int32, Int32, Int32)) -> Bool {
  pixel.0 < 12 && pixel.1 < 12 && pixel.2 < 12 && pixel.3 > 240
}

///|
fn metal_proof(
  width~ : Int32,
  height~ : Int32,
  commands~ : Array[@core.DrawCommand],
  text_engine~ : NativeTextEngine = native_noop_text_engine(),
  image_source~ : @render.HostImageSource = @render.HostImageSource::unavailable(),
) -> Bytes {
  match
    metal_proof_pixels(
      width~,
      height~,
      commands~,
      clear=@core.Color::black(),
      text_engine~,
      image_source~,
    ) {
    Some(pixels) => pixels
    None =>
      abort(
        "metal proof pass needs a Metal device; this host cannot run the direct Metal route",
      )
  }
}

///|
fn metal_rect(
  x : Double,
  y : Double,
  width : Double,
  height~ : Double = width,
) -> @core.Rect {
  @core.Rect::new(x~, y~, width~, height~)
}

///|
fn metal_point(x : Double, y : Double) -> @core.Point {
  @core.Point::new(x~, y~)
}

///|
fn metal_noop_text() -> MetalFrameContext {
  MetalFrameContext::{
    cache: @native_text.NativeTextCache::new(),
    atlas: new_metal_glyph_atlas(),
    images: new_metal_image_cache(),
    image_source: @render.HostImageSource::unavailable(),
    context: 0UL,
    async_images: false,
    image_budget_bytes: METAL_IMAGE_MAX_RESIDENT_BYTES,
    retained: new_metal_retained_cache(),
  }
}

///|
fn metal_triangle(color : @core.Color) -> @core.DrawCommand {
  @core.DrawPath(
    @core.PathSpec::new(
      verbs=[
        @core.MoveTo(metal_point(0.0, 0.0)),
        @core.LineTo(metal_point(8.0, 0.0)),
        @core.LineTo(metal_point(0.0, 8.0)),
        @core.Close,
      ],
      fill=Some(@core.Brush::solid(color)),
    ),
  )
}

///|
test "metal proof pass clears the whole frame" {
  let pixels = metal_proof(width=4, height=4, commands=[])
  for y in 0..<4 {
    for x in 0..<4 {
      assert_true(metal_is_black(metal_proof_pixel(pixels, x, y, 4)))
    }
  }
}

///|
test "metal fills a rect with top-left origin pixels" {
  let pixels = metal_proof(width=8, height=8, commands=[
    @core.FillRect(
      metal_rect(0.0, 0.0, 4.0, height=4.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0),
    ),
  ])
  assert_true(metal_is_red(metal_proof_pixel(pixels, 1, 1, 8)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 6, 6, 8)))
  assert_true(metal_is_red(metal_proof_pixel(pixels, 3, 3, 8)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 4, 4, 8)))
}

///|
test "metal fills one solid path" {
  let pixels = metal_proof(width=8, height=8, commands=[
    metal_triangle(@core.Color::rgba(r=0.0, g=1.0, b=0.0)),
  ])
  assert_true(metal_is_green(metal_proof_pixel(pixels, 1, 1, 8)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 7, 7, 8)))
}

///|
test "metal clips geometry to the pushed rect" {
  let pixels = metal_proof(width=8, height=8, commands=[
    @core.PushClip(metal_rect(0.0, 0.0, 2.0, height=2.0)),
    @core.FillRect(
      metal_rect(0.0, 0.0, 8.0, height=8.0),
      @core.Color::rgba(r=0.12, g=0.36, b=0.95),
    ),
    @core.PopClip,
  ])
  assert_true(metal_is_blue(metal_proof_pixel(pixels, 1, 1, 8)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 4, 4, 8)))
}

///|
test "geometry counts what the L1 legs refuse to draw" {
  let geometry = build_metal_geometry(
    @render_common.lower_draw_commands([
      @core.StrokeRect(
        metal_rect(0.0, 0.0, 4.0, height=4.0),
        @core.Color::black(),
        1.0,
      ),
      @core.DrawPath(
        @core.PathSpec::new(
          verbs=[
            @core.MoveTo(metal_point(0.0, 0.0)),
            @core.LineTo(metal_point(4.0, 0.0)),
            @core.LineTo(metal_point(0.0, 4.0)),
            @core.Close,
          ],
          fill=Some(
            @core.Brush::linear_gradient(
              start=metal_point(0.0, 0.0),
              end=metal_point(4.0, 4.0),
              start_color=@core.Color::black(),
              end_color=@core.Color::white(),
            ),
          ),
        ),
      ),
    ]),
    @core.SurfaceMetrics::new(
      logical_size=@core.Size::new(width=8.0, height=8.0),
      physical_size=@core.Size::new(width=8.0, height=8.0),
      scale_factor=1.0,
    ),
    metal_noop_text(),
  )
  // Both ops draw now: the stroke is an SDF ring and the gradient path carries
  // its own brush in the mesh, so nothing here is counted or guessed.
  assert_eq(geometry.item_count, 2)
}

///|
test "every op in the stream is drawn or lands in a counter" {
  let geometry = build_metal_geometry(
    @render_common.lower_draw_commands([
      @core.PushLayer(@core.LayerSpec::new()),
      @core.PopLayer,
      @core.PushFilter(@core.FilterEffect::blur(4.0)),
      @core.PopFilter,
      @core.BeginRetainedLayer(
        @core.RetainedLayerSpec::new(
          key="layer",
          frame=metal_rect(0.0, 0.0, 4.0),
          content_revision=0,
        ),
      ),
      @core.EndRetainedLayer("layer"),
      @core.DrawShaderEffect(
        @core.ShaderEffectSpec::new(
          name="glow",
          frame=metal_rect(0.0, 0.0, 4.0),
        ),
      ),
      @core.DrawImage(
        @core.ImageRun::new("missing.png", metal_rect(0.0, 0.0, 4.0)),
      ),
    ]),
    @core.SurfaceMetrics::new(
      logical_size=@core.Size::new(width=8.0, height=8.0),
      physical_size=@core.Size::new(width=8.0, height=8.0),
      scale_factor=1.0,
    ),
    metal_noop_text(),
  )
  // No `PlanOp` variant is left without an arm: the empty layer, filter and
  // retained-layer scopes release their pass without drawing, the unknown shader
  // effect paints its declared fallback brush (the one item here), and the image
  // op is handled but unresolvable without a device.
  assert_eq(geometry.item_count, 1)
  assert_eq(geometry.retained_layers_rebuilt, 1)
  assert_eq(geometry.shader_effects_fallback_painted, 1)
  assert_eq(geometry.image_ops_unresolved, 1)
  assert_eq(geometry.layers_composited, 0)
}

///|
test "unbalanced scope ops surface as plan diagnostics" {
  let plan = @render_common.lower_draw_commands([@core.PopClip])
  let geometry = build_metal_geometry(
    plan,
    @core.SurfaceMetrics::new(
      logical_size=@core.Size::new(width=8.0, height=8.0),
      physical_size=@core.Size::new(width=8.0, height=8.0),
      scale_factor=1.0,
    ),
    metal_noop_text(),
  )
  assert_eq(plan.diagnostics.length(), 1)
  assert_eq(geometry.item_count, 0)
}

///|
/// The proof pass renders at device resolution, which is what lets a Retina
/// assertion exist at all. A four-logical-pixel box is eight device pixels wide at
/// scale 2.0, so `(6,6)` is inked there and `(9,9)` is empty; a scale that was
/// ignored, or applied to the metrics but not to the texture, fails one of those,
/// and the buffer length pins which.
test "a proof frame at device scale two renders four times the texels" {
  let commands = [
    metal_fill(metal_rect(0.0, 0.0, 4.0, height=4.0), metal_red()),
  ]
  let pixels = match
    metal_proof_pixels(
      width=8,
      height=8,
      commands~,
      clear=@core.Color::black(),
      scale_factor=2.0,
    ) {
    Some(pixels) => pixels
    None => abort("a scale-2 proof needs a Metal device")
  }
  assert_eq(pixels.length(), 16 * 16 * 4)
  assert_true(metal_is_red(metal_proof_pixel(pixels, 0, 0, 16)))
  assert_true(
    metal_is_red(metal_proof_pixel(pixels, 6, 6, 16)),
    msg="a 4-logical-pixel box should reach device pixel 6 at scale 2.0",
  )
  assert_true(metal_is_black(metal_proof_pixel(pixels, 9, 9, 16)))
  // The same stream at scale 1.0 stays four pixels wide, so the two reads above
  // cannot both pass unless the scale really reached the texture.
  let flat = metal_proof(width=8, height=8, commands~)
  assert_true(metal_is_black(metal_proof_pixel(flat, 6, 6, 8)))
}
