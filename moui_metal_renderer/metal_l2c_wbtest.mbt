///|
/// Pixel proofs for the L2c scope ops: layers, blend modes, filters, retained
/// layers and shader-effect fallbacks. Each one
/// asserts a value a route that skipped the offscreen pass, mis-set the pass
/// transform or forgot the composite could not produce, because the expected
/// number only comes out of drawing the group into its own target and blending
/// that target back at the layer's own device frame.
fn metal_red() -> @core.Color {
  @core.Color::rgba(r=1.0, g=0.0, b=0.0)
}

///|
fn metal_white() -> @core.Color {
  @core.Color::rgba(r=1.0, g=1.0, b=1.0)
}

///|
fn metal_near(actual : Int32, expected : Int32) -> Bool {
  let delta = actual - expected
  delta > -13 && delta < 13
}

///|
fn metal_layer(
  spec : @core.LayerSpec,
  inner : Array[@core.DrawCommand],
) -> Array[@core.DrawCommand] {
  [@core.PushLayer(spec)] + inner + [@core.PopLayer]
}

///|
fn metal_filter(
  filter : @core.FilterEffect,
  inner : Array[@core.DrawCommand],
) -> Array[@core.DrawCommand] {
  [@core.PushFilter(filter)] + inner + [@core.PopFilter]
}

///|
fn metal_fill(
  rect : @core.Rect,
  color : @core.Color,
  radius~ : Double = 0.0,
) -> @core.DrawCommand {
  @core.FillRoundedRect(@core.RoundedRect::new(rect~, radius~), color)
}

///|
test "a rect-masked layer clips its group to the layer frame" {
  let pixels = metal_proof(
    width=16,
    height=16,
    commands=metal_layer(
      @core.LayerSpec::new(
        mask=@core.LayerMask::RectMask(metal_rect(0.0, 0.0, 4.0, height=4.0)),
      ),
      [metal_fill(metal_rect(0.0, 0.0, 16.0, height=16.0), metal_red())],
    ),
  )
  // The group is a 16x16 fill; only the 4x4 the mask keeps may reach the frame.
  assert_true(metal_is_red(metal_proof_pixel(pixels, 1, 1, 16)))
  assert_true(metal_is_red(metal_proof_pixel(pixels, 3, 3, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 4, 4, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 12, 12, 16)))
}

///|
test "a layer opacity dims the whole group at the composite" {
  let pixels = metal_proof(
    width=16,
    height=16,
    commands=metal_layer(@core.LayerSpec::new(opacity=0.5), [
      metal_fill(metal_rect(0.0, 0.0, 16.0, height=16.0), metal_white()),
    ]),
  )
  let pixel = metal_proof_pixel(pixels, 8, 8, 16)
  // Children build at full strength and the composite scales them, so a half
  // opacity group over an opaque clear is half bright and still fully opaque.
  assert_true(metal_near(pixel.0, 128))
  assert_true(metal_near(pixel.1, 128))
  assert_true(metal_near(pixel.2, 128))
  assert_true(pixel.3 > 240)
}

///|
test "blend modes composite the group against what the pass painted" {
  // A destination that is neither black nor white, so the four modes this route
  // can express land on four different values and cannot be confused with each
  // other or with a plain source-over.
  let backdrop = metal_fill(
    metal_rect(0.0, 0.0, 16.0, height=16.0),
    @core.Color::rgba(r=0.25, g=0.75, b=0.5),
  )
  let group = metal_fill(
    metal_rect(4.0, 4.0, 8.0, height=8.0),
    @core.Color::rgba(r=0.5, g=0.5, b=0.5),
  )
  let cases = [
    (@core.BlendMode::Multiply, (32, 96, 64)),
    (@core.BlendMode::Screen, (159, 223, 191)),
    (@core.BlendMode::Darken, (64, 128, 128)),
    (@core.BlendMode::Lighten, (128, 191, 128)),
    (@core.BlendMode::SourceOver, (128, 128, 128)),
  ]
  for case in cases {
    let (blend_mode, expected) = case
    let pixels = metal_proof(
      width=16,
      height=16,
      commands=[backdrop] +
        metal_layer(
          @core.LayerSpec::new(
            mask=@core.LayerMask::RectMask(
              metal_rect(4.0, 4.0, 8.0, height=8.0),
            ),
            blend_mode~,
          ),
          [group],
        ),
    )
    let pixel = metal_proof_pixel(pixels, 6, 6, 16)
    assert_true(
      metal_near(pixel.0, expected.0) &&
      metal_near(pixel.1, expected.1) &&
      metal_near(pixel.2, expected.2),
    )
    // The group must stay inside its own frame: the destination outside it is
    // untouched, which is what a mis-clamped pass transform would break first.
    assert_true(metal_near(pixel.3, 255))
    let outside = metal_proof_pixel(pixels, 1, 1, 16)
    assert_true(
      metal_near(outside.0, 64) &&
      metal_near(outside.1, 191) &&
      metal_near(outside.2, 128),
    )
  }
}

///|
test "overlay has no fixed-function state, so it is counted and not drawn" {
  let commands = [
      metal_fill(
        metal_rect(0.0, 0.0, 16.0, height=16.0),
        @core.Color::rgba(r=0.25, g=0.75, b=0.5),
      ),
    ] +
    metal_layer(
      @core.LayerSpec::new(
        mask=@core.LayerMask::RectMask(metal_rect(4.0, 4.0, 8.0, height=8.0)),
        blend_mode=@core.BlendMode::Overlay,
      ),
      [
        metal_fill(
          metal_rect(4.0, 4.0, 8.0, height=8.0),
          @core.Color::rgba(r=0.5, g=0.5, b=0.5),
        ),
      ],
    )
  let report = metal_frame_report(commands~, width=16.0, height=16.0)
  assert_eq(report.blend_modes_unsupported, 1)
  assert_eq(report.layers, 0)
  assert_eq(report.blend_modes_approximated, 0)
  assert_true(report.refused_count() > 0)
  // Nothing of the group reaches the frame: the route leaves the backdrop alone
  // instead of painting a guess for a mode it cannot express.
  let pixels = metal_proof(width=16, height=16, commands~)
  let inside = metal_proof_pixel(pixels, 6, 6, 16)
  assert_true(
    metal_near(inside.0, 64) &&
    metal_near(inside.1, 191) &&
    metal_near(inside.2, 128),
  )
}

///|
test "a filter group keeps its own scope and a blend mode reports honestly" {
  let report = metal_frame_report(
    commands=metal_filter(@core.FilterEffect::Blur(2.0), [
      metal_fill(metal_rect(0.0, 0.0, 8.0, height=8.0), metal_white()),
    ]),
    width=16.0,
    height=16.0,
  )
  // Two passes for the blurred group: a blur is a horizontal pass into its own
  // target plus the composite that reads that target vertically, so `layers`
  // counts the intermediate as the pass it is. One counted approximation still,
  // because two passes are this route's blur rather than a blur and a half.
  assert_eq(report.layers, 2)
  assert_eq(report.filter_approximations, 1)
  assert_eq(report.blend_modes_approximated, 0)
}

///|
test "a blurred group softens the edge it wrapped" {
  let pixels = metal_proof(
    width=16,
    height=16,
    commands=metal_filter(@core.FilterEffect::Blur(2.0), [
      metal_fill(metal_rect(4.0, 4.0, 4.0, height=4.0), metal_white()),
    ]),
  )
  let inside = metal_proof_pixel(pixels, 6, 6, 16).0
  let edge = metal_proof_pixel(pixels, 3, 6, 16).0
  let far = metal_proof_pixel(pixels, 1, 6, 16).0
  assert_true(inside > edge)
  assert_true(edge > far)
  // A hard-edged box would leave the outside exactly cleared; partial light is
  // the tap reaching past the group.
  assert_true(edge > 8 && edge < 250)
}

///|
test "brightness and colour-matrix filters rewrite the group" {
  let bright = metal_proof(
    width=16,
    height=16,
    commands=metal_filter(@core.FilterEffect::Brightness(1.5), [
      metal_fill(
        metal_rect(2.0, 2.0, 6.0, height=6.0),
        @core.Color::rgba(r=0.4, g=0.4, b=0.4),
      ),
    ]),
  )
  let lifted = metal_proof_pixel(bright, 4, 4, 16)
  assert_true(metal_near(lifted.0, 230))
  assert_true(metal_near(lifted.1, 230))

  // Swap red into blue: only a filter that really reads the matrix produces it.
  let swapped = metal_proof(
    width=16,
    height=16,
    commands=metal_filter(
      @core.FilterEffect::ColorMatrix([
        0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0,
        0.0, 0.0, 0.0, 1.0, 0.0,
      ]),
      [metal_fill(metal_rect(2.0, 2.0, 6.0, height=6.0), metal_red())],
    ),
  )
  assert_true(metal_is_blue(metal_proof_pixel(swapped, 4, 4, 16)))
  let control = metal_proof(width=16, height=16, commands=[
    metal_fill(metal_rect(2.0, 2.0, 6.0, height=6.0), metal_red()),
  ])
  assert_true(metal_is_red(metal_proof_pixel(control, 4, 4, 16)))
}

///|
test "nested layers clip to the tighter of the two frames" {
  let inner = metal_layer(
    @core.LayerSpec::new(
      mask=@core.LayerMask::RectMask(metal_rect(0.0, 0.0, 6.0, height=6.0)),
    ),
    [metal_fill(metal_rect(0.0, 0.0, 16.0, height=16.0), metal_red())],
  )
  let pixels = metal_proof(
    width=16,
    height=16,
    commands=metal_layer(
      @core.LayerSpec::new(
        mask=@core.LayerMask::RectMask(metal_rect(2.0, 2.0, 12.0, height=12.0)),
      ),
      inner,
    ),
  )
  let report = metal_frame_report(
    commands=metal_layer(
      @core.LayerSpec::new(
        mask=@core.LayerMask::RectMask(metal_rect(2.0, 2.0, 12.0, height=12.0)),
      ),
      inner,
    ),
    width=16.0,
    height=16.0,
  )
  // Two passes, one per layer, and the walk terminated both scopes.
  assert_eq(report.layers, 2)
  assert_eq(report.items, 3)
  // The inner 6x6 wins inside the outer frame, and the outer 2,2 origin wins
  // where the inner would have painted further out.
  assert_true(metal_is_red(metal_proof_pixel(pixels, 4, 4, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 8, 8, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 1, 1, 16)))
}

///|
test "a clipped-away item leaves no parameter row behind" {
  // The first fill is entirely off the surface, so its item is dropped while its
  // vertices are rolled back. If the parameter row were pushed anyway, the second
  // item would read the first one's radius and paint square corners.
  let commands = [
    metal_fill(metal_rect(100.0, 100.0, 4.0, height=4.0), metal_red()),
    metal_fill(metal_rect(0.0, 0.0, 16.0, height=16.0), metal_red(), radius=6.0),
  ]
  let report = metal_frame_report(commands~, width=16.0, height=16.0)
  assert_eq(report.items, 1)
  assert_eq(report.clipped_away, 1)
  let pixels = metal_proof(width=16, height=16, commands~)
  assert_true(metal_is_black(metal_proof_pixel(pixels, 0, 0, 16)))
  assert_true(metal_is_red(metal_proof_pixel(pixels, 8, 8, 16)))
}

///|
test "a retained boundary with no frame before it rebuilds into its own pass" {
  let commands = [
    @core.BeginRetainedLayer(
      @core.RetainedLayerSpec::new(
        key="boundary",
        frame=metal_rect(0.0, 0.0, 6.0, height=6.0),
        content_revision=3,
      ),
    ),
    metal_fill(metal_rect(0.0, 0.0, 16.0, height=16.0), metal_red()),
    @core.EndRetainedLayer("boundary"),
  ]
  let report = metal_frame_report(commands~, width=16.0, height=16.0)
  assert_eq(report.layers, 1)
  assert_eq(report.items, 2)
  assert_eq(report.retained_layers_rebuilt, 1)
  let pixels = metal_proof(width=16, height=16, commands~)
  // The group's own fill covers the surface; the frame it was declared with is
  // what reaches it, so this reads as the pass clip and not as a dropped child.
  assert_true(metal_is_red(metal_proof_pixel(pixels, 1, 1, 16)))
  assert_true(metal_is_red(metal_proof_pixel(pixels, 5, 5, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 6, 6, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 12, 12, 16)))
}

///|
test "an effect name with no formulation is drawn with its fallback brush" {
  let commands = [
    @core.DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="glow",
        frame=metal_rect(2.0, 2.0, 8.0, height=8.0),
        fallback=@core.Brush::linear_gradient(
          start=@core.Point::new(x=2.0, y=2.0),
          end=@core.Point::new(x=10.0, y=2.0),
          start_color=@core.Color::rgba(r=1.0, g=0.0, b=0.0),
          end_color=@core.Color::rgba(r=0.0, g=0.0, b=1.0),
        ),
      ),
    ),
  ]
  let report = metal_frame_report(commands~, width=16.0, height=16.0)
  assert_eq(report.items, 1)
  assert_eq(report.shader_effects_fallback_painted, 1)
  let pixels = metal_proof(width=16, height=16, commands~)
  // Both halves of the assertion are needed: a black box would prove the frame
  // but not that the fallback brush was used, and a full-bleed gradient would
  // prove the brush but not the frame. The frame is deliberately not at the
  // surface origin, because a box fragment measures itself from its own origin —
  // reading the brush axis in surface coordinates would shift this gradient by
  // 2 pixels and put no red at x=2.
  assert_true(metal_is_red(metal_proof_pixel(pixels, 2, 5, 16)))
  assert_true(metal_is_blue(metal_proof_pixel(pixels, 9, 5, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 12, 12, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 1, 1, 16)))
}

///|
test "a checker effect alternates its cells rather than painting its fallback" {
  let commands = [
    @core.DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="checker",
        frame=metal_rect(2.0, 2.0, 8.0, height=8.0),
        uniforms=[2.0],
        fallback=@core.Brush::linear_gradient(
          start=@core.Point::new(x=2.0, y=2.0),
          end=@core.Point::new(x=10.0, y=2.0),
          start_color=@core.Color::rgba(r=1.0, g=0.0, b=0.0),
          end_color=@core.Color::rgba(r=0.0, g=0.0, b=1.0),
        ),
      ),
    ),
  ]
  let report = metal_frame_report(commands~, width=16.0, height=16.0)
  assert_eq(report.shader_effects_fallback_painted, 0)
  let pixels = metal_proof(width=16, height=16, commands~)
  // 2 cells across an 8x8 frame is a 4x4-pixel cell, so the frame holds a 2x2
  // board. The two colours are the fallback brush's endpoints, which is the
  // shared reading (`skia_shader_effect_colors`), but the *layout* is what a
  // fallback frame cannot produce: the horizontal gradient alone would put red
  // at x=3 in both rows and blue at x=7 in both rows. The diagonal pair below
  // is only red where the cell index sums even.
  assert_true(metal_is_red(metal_proof_pixel(pixels, 3, 3, 16)))
  assert_true(metal_is_blue(metal_proof_pixel(pixels, 7, 3, 16)))
  assert_true(metal_is_blue(metal_proof_pixel(pixels, 3, 7, 16)))
  assert_true(metal_is_red(metal_proof_pixel(pixels, 7, 7, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 12, 12, 16)))
}

///|
test "a vignette effect fades to black before the frame edge" {
  let commands = [
    @core.DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="vignette",
        frame=metal_rect(0.0, 0.0, 16.0, height=16.0),
        uniforms=[1.0],
        fallback=@core.Brush::solid(@core.Color::rgba(r=1.0, g=1.0, b=1.0)),
      ),
    ),
  ]
  let report = metal_frame_report(commands~, width=16.0, height=16.0)
  assert_eq(report.shader_effects_fallback_painted, 0)
  let pixels = metal_proof(width=16, height=16, commands~)
  // radius = max(w,h)/2 * 1.0 = 8, so the centre keeps the colour, the far
  // corner is past the fade, and texel (12,8) sits at t=0.56: a mid grey no
  // flat-brush frame and no all-black frame can both produce.
  let centre = metal_proof_pixel(pixels, 8, 8, 16)
  let mid = metal_proof_pixel(pixels, 12, 8, 16)
  assert_true(metal_is_white(centre))
  assert_true(mid.0 > 60 && mid.0 < 180 && mid.0 < centre.0)
  assert_true(metal_is_black(metal_proof_pixel(pixels, 15, 15, 16)))
}

///|
test "a linear-gradient-debug effect runs across its own frame, not its brush axis" {
  // The fallback brush is vertical, so a frame that reads red at x=2 and blue at
  // x=9 along one row is the effect's own horizontal axis, not the brush.
  let commands = [
    @core.DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="linear-gradient-debug",
        frame=metal_rect(2.0, 2.0, 8.0, height=8.0),
        fallback=@core.Brush::linear_gradient(
          start=@core.Point::new(x=2.0, y=2.0),
          end=@core.Point::new(x=2.0, y=10.0),
          start_color=@core.Color::rgba(r=1.0, g=0.0, b=0.0),
          end_color=@core.Color::rgba(r=0.0, g=0.0, b=1.0),
        ),
      ),
    ),
  ]
  let report = metal_frame_report(commands~, width=16.0, height=16.0)
  assert_eq(report.shader_effects_fallback_painted, 0)
  let pixels = metal_proof(width=16, height=16, commands~)
  assert_true(metal_is_red(metal_proof_pixel(pixels, 2, 5, 16)))
  assert_true(metal_is_blue(metal_proof_pixel(pixels, 9, 5, 16)))
  // The ramp is independent of y, which the vertical fallback is not: under the
  // brush, x=2 at y=8 would already be well past red.
  assert_true(metal_is_red(metal_proof_pixel(pixels, 2, 8, 16)))
}

///|
test "a solid effect paints one colour across a gradient fallback" {
  let commands = [
    @core.DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="solid",
        frame=metal_rect(0.0, 0.0, 16.0, height=16.0),
        fallback=@core.Brush::linear_gradient(
          start=@core.Point::new(x=0.0, y=0.0),
          end=@core.Point::new(x=16.0, y=0.0),
          start_color=@core.Color::rgba(r=1.0, g=0.0, b=0.0),
          end_color=@core.Color::rgba(r=0.0, g=0.0, b=1.0),
        ),
      ),
    ),
  ]
  let report = metal_frame_report(commands~, width=16.0, height=16.0)
  assert_eq(report.shader_effects_fallback_painted, 0)
  let pixels = metal_proof(width=16, height=16, commands~)
  // `moui_wgpu_renderer` reads `solid` as the fallback brush's first colour, so
  // the far edge has to stay red; painting the brush instead would put blue
  // there. `moui_skia_renderer` answers with the brush, which is why this row
  // stays partial rather than supported.
  assert_true(metal_is_red(metal_proof_pixel(pixels, 1, 8, 16)))
  assert_true(metal_is_red(metal_proof_pixel(pixels, 14, 8, 16)))
}

///|
test "a radial gradient on an offset rect keeps its centre and its radius" {
  let commands = [
    @core.FillRoundedRectBrush(
      @core.RoundedRect::new(rect=metal_rect(4.0, 0.0, 8.0, height=8.0)),
      @core.Brush::radial_gradient(
        center=@core.Point::new(x=8.0, y=4.0),
        radius=4.0,
        center_color=@core.Color::rgba(r=1.0, g=1.0, b=1.0),
        edge_color=@core.Color::rgba(r=0.0, g=0.0, b=0.0),
      ),
    ),
  ]
  let pixels = metal_proof(width=16, height=8, commands~)
  let middle = metal_proof_pixel(pixels, 8, 4, 16).0
  // The two samples are equidistant from the centre, so the falloff must be
  // symmetric about x=8 even though the rect starts at x=4.
  let left = metal_proof_pixel(pixels, 6, 4, 16).0
  let right = metal_proof_pixel(pixels, 9, 4, 16).0
  assert_true(middle > 180)
  assert_true(metal_near(left, right))
  // A radial `end.x` is a length: shifting it with the centre collapses the
  // gradient to a point, which would leave these two samples black.
  assert_true(left > 60 && left < 220)
  assert_true(right > 60 && right < 220)
}

///|
/// The falloff, both axes. A single 3x3 tap with its outer samples at 0 and
/// +-radius leaves a two-pixel mark unreadable inside its own support: measured
/// before this leg it came back as 128 at the mark, six empty pixels, then 64
/// again eight pixels out. These asserts pin the profile's shape, not its values,
/// so an echo, a hole and a missing axis each fail a different one.
test "a blurred group falls off on both axes rather than echoing at the radius" {
  let mark = metal_fill(metal_rect(15.0, 15.0, 2.0, height=2.0), metal_white())
  let pixels = metal_proof(
    width=32,
    height=32,
    commands=metal_filter(@core.FilterEffect::Blur(8.0), [mark]),
  )
  let across : Array[Int32] = []
  let down : Array[Int32] = []
  for offset in 0..<14 {
    across.push(metal_proof_pixel(pixels, 17 + offset, 16, 32).0)
    down.push(metal_proof_pixel(pixels, 16, 17 + offset, 32).0)
  }
  assert_true(
    down[0] > 0 && down[1] > 0,
    msg="no light below the mark: the vertical pass did not run",
  )
  for index in 1..<14 {
    assert_true(
      across[index] <= across[index - 1],
      msg="horizontal falloff rises at +" + (index + 1).to_string() + " px",
    )
    assert_true(
      down[index] <= down[index - 1],
      msg="vertical falloff rises at +" + (index + 1).to_string() + " px",
    )
  }
  // The old tap put its outer sample at +8, so an echo there out-shone everything
  // between it and the mark -- no bell does that.
  assert_true(
    across[1] > across[7],
    msg="the +8 sample out-shines +3: a tap echo, not a falloff",
  )
  assert_true(
    across[4] > 0,
    msg="six pixels out is empty: the taps are spaced, not integrated",
  )
}

///|
/// A colour matrix with fewer than 20 values keeps this module's own identity for
/// the rest, so the identity has to be an identity *for the reader that reads it*.
/// The array `moui_wgpu_renderer` ships is one its column-indexed `mat4x5f` reads
/// as one; this shader reads rows, and under that reading the copied array mapped
/// every channel onto red -- a red group came back white with its alpha forced
/// opaque, which is also what saturated the first separable blur.
test "an identity colour matrix really leaves the group alone" {
  let pixels = metal_proof(
    width=16,
    height=16,
    commands=metal_filter(
      @core.FilterEffect::ColorMatrix([1.0, 0.0, 0.0, 0.0, 0.0]),
      [metal_fill(metal_rect(2.0, 2.0, 6.0, height=6.0), metal_red())],
    ),
  )
  let pixel = metal_proof_pixel(pixels, 4, 4, 16)
  assert_true(
    pixel.0 > 200,
    msg="red channel \{pixel.0}: the matrix ate the group's red",
  )
  assert_true(
    pixel.1 < 60,
    msg="green channel \{pixel.1}: every channel is being taken from red",
  )
  assert_true(
    pixel.2 < 60,
    msg="blue channel \{pixel.2}: every channel is being taken from red",
  )
  assert_true(
    pixel.3 > 200 && pixel.3 < 256,
    msg="alpha \{pixel.3}: the alpha row is not an identity",
  )
}
