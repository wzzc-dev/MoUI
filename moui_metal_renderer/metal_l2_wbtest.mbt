///|
/// Pixel proofs for the L2 shape modes. Each one asserts a *difference* the
/// wrong shader cannot produce: a rounded corner that a square fill would paint
/// opaque, a stroke ring with a clean interior, a gradient that changes along
/// its axis and not across it, and a shadow whose alpha falls off gradually.
fn metal_shape_rounded() -> @core.DrawCommand {
  @core.FillRoundedRect(
    @core.RoundedRect::new(
      rect=metal_rect(0.0, 0.0, 16.0, height=16.0),
      radius=6.0,
    ),
    @core.Color::rgba(r=1.0, g=0.0, b=0.0),
  )
}

///|
test "rounded rect fill clears its own corners" {
  let pixels = metal_proof(width=16, height=16, commands=[metal_shape_rounded()])
  assert_true(metal_is_red(metal_proof_pixel(pixels, 8, 8, 16)))
  // The corner pixel sits outside a radius-6 rounded box; a square fill would
  // paint it, which is the difference this asserts.
  assert_true(metal_is_black(metal_proof_pixel(pixels, 0, 0, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 15, 15, 16)))
  // The corner arc is anti-aliased, not a binary step: some pixel in the 4x4
  // corner block is partially covered.
  let mut partial = 0
  for y in 0..<4 {
    for x in 0..<4 {
      let value = metal_proof_pixel(pixels, x, y, 16).0
      if value > 4 && value < 250 {
        partial = partial + 1
      }
    }
  }
  assert_true(partial > 0)
}

///|
test "stroke draws a ring and leaves the interior clean" {
  let pixels = metal_proof(width=16, height=16, commands=[
    @core.StrokeRect(
      metal_rect(0.0, 0.0, 16.0, height=16.0),
      @core.Color::rgba(r=1.0, g=0.0, b=0.0),
      2.0,
    ),
  ])
  assert_true(metal_is_red(metal_proof_pixel(pixels, 0, 8, 16)))
  assert_true(metal_is_red(metal_proof_pixel(pixels, 8, 0, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 8, 8, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 4, 8, 16)))
}

///|
test "linear gradient interpolates along its axis only" {
  let pixels = metal_proof(width=16, height=8, commands=[
    @core.FillRoundedRectBrush(
      @core.RoundedRect::new(rect=metal_rect(0.0, 0.0, 16.0, height=8.0)),
      @core.Brush::linear_gradient(
        start=@core.Point::new(x=0.0, y=0.0),
        end=@core.Point::new(x=16.0, y=0.0),
        start_color=@core.Color::rgba(r=0.0, g=0.0, b=0.0),
        end_color=@core.Color::rgba(r=1.0, g=1.0, b=1.0),
      ),
    ),
  ])
  let left = metal_proof_pixel(pixels, 1, 4, 16).0
  let middle = metal_proof_pixel(pixels, 8, 4, 16).0
  let right = metal_proof_pixel(pixels, 15, 4, 16).0
  assert_true(left < middle && middle < right)
  // Same row, different columns only: a column must be constant down the box.
  assert_true(metal_proof_pixel(pixels, 8, 1, 16).0 == middle)
  assert_true(metal_proof_pixel(pixels, 8, 6, 16).0 == middle)
}

///|
test "radial gradient falls off from its center" {
  let pixels = metal_proof(width=16, height=16, commands=[
    @core.FillRoundedRectBrush(
      @core.RoundedRect::new(rect=metal_rect(0.0, 0.0, 16.0, height=16.0)),
      @core.Brush::radial_gradient(
        center=@core.Point::new(x=8.0, y=8.0),
        radius=8.0,
        center_color=@core.Color::rgba(r=1.0, g=1.0, b=1.0),
        edge_color=@core.Color::rgba(r=0.0, g=0.0, b=0.0),
      ),
    ),
  ])
  let center = metal_proof_pixel(pixels, 8, 8, 16).0
  let near = metal_proof_pixel(pixels, 11, 8, 16).0
  let far = metal_proof_pixel(pixels, 15, 8, 16).0
  assert_true(center > near && near > far)
}

///|
test "shadow produces a soft falloff, not a hard box" {
  // A 12px mark with sigma 8 has no plateau to hide in: the coverage a Gaussian
  // leaves at the shape's own edge is a half, and the box drawn around the shape
  // is only margin, not ink. Before this leg the grown box saturated to its own
  // rim and fell off a cliff there, so the asserts below name where the ink is.
  let pixels = metal_proof(width=24, height=24, commands=[
    @core.DrawShadow(
      @core.ShadowSpec::new(
        rect=@core.RoundedRect::new(
          rect=metal_rect(6.0, 6.0, 12.0, height=12.0),
          radius=2.0,
        ),
        color=@core.Color::rgba(r=1.0, g=1.0, b=1.0),
        offset=@core.Point::new(x=0.0, y=0.0),
        blur_radius=2.0,
        spread=0.0,
      ),
    ),
  ])
  let inside = metal_proof_pixel(pixels, 12, 12, 24).0
  // One sigma past the shape's right edge (x=18) is x=20: a blur still paints
  // about 16% there, where the old ramp was already at its rim.
  let one_sigma = metal_proof_pixel(pixels, 20, 12, 24).0
  let rim = metal_proof_pixel(pixels, 22, 12, 24).0
  assert_true(
    inside > 200,
    msg="the shape's own centre should saturate: \{inside}",
  )
  assert_true(
    one_sigma < inside && one_sigma > 15,
    msg="one sigma out should be faint but present: \{one_sigma}",
  )
  assert_true(
    rim < one_sigma,
    msg="the far rim should be fainter still: \{rim} vs \{one_sigma}",
  )
}

///|
/// The profile, not the pixel. A shadow whose box is grown by 3 sigma used to be
/// filled solid out to the box and dropped to zero across one texel there; this
/// asserts the shape Skia's `MaskFilter` and Sun's separable box produce at the
/// same sigma: half-covered at the edge, a tail that thins monotonically for
/// three sigma, and no step anywhere near the box's own rim.
test "a shadow's falloff is a Gaussian tail, not a grown hard box" {
  let mark = @core.DrawShadow(
    @core.ShadowSpec::new(
      rect=@core.RoundedRect::new(
        rect=metal_rect(18.0, 18.0, 12.0, height=12.0),
        radius=0.0,
      ),
      color=@core.Color::rgba(r=1.0, g=1.0, b=1.0),
      offset=@core.Point::new(x=0.0, y=0.0),
      blur_radius=8.0,
      spread=0.0,
    ),
  )
  let pixels = metal_proof(width=48, height=48, commands=[mark])
  fn alpha(x : Int32) -> Int32 {
    metal_proof_pixel(pixels, x, 24, 48).0
  }
  // Five pixels outside the shape's left edge, and one pixel off its right edge:
  // the old kernel held 255 at both, because the plateau reached 2 sigma out.
  assert_true(
    alpha(13) < 160,
    msg="5px left of the shape is \{alpha(13)}: plateau",
  )
  assert_true(
    alpha(30) > 60 && alpha(30) < 190,
    msg="at the shape's edge a blur is about half: \{alpha(30)}",
  )
  assert_true(
    alpha(38) > 12 && alpha(38) < 70,
    msg="one sigma out is about 16%: \{alpha(38)}",
  )
  assert_true(alpha(46) < 24, msg="two sigmas out is nearly gone: \{alpha(46)}")
  let mut previous = alpha(30)
  let mut biggest_drop = 0
  for x in 31..<48 {
    let now = alpha(x)
    assert_true(now <= previous, msg="the tail brightens again at x=\{x}")
    if previous - now > biggest_drop {
      biggest_drop = previous - now
    }
    previous = now
  }
  // The old ramp ended in a step of 76 at the box's own rim; a Gaussian tail
  // thins gradually, so no single pixel may carry most of the remaining ink.
  assert_true(
    biggest_drop < 24,
    msg="a \{biggest_drop}-level single-pixel step is the box edge, not a tail",
  )
}

///|
test "a gradient-filled path is painted as a gradient" {
  let pixels = metal_proof(width=16, height=16, commands=[
    @core.DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.MoveTo(metal_point(0.0, 0.0)),
          @core.LineTo(metal_point(16.0, 0.0)),
          @core.LineTo(metal_point(16.0, 16.0)),
          @core.Close,
        ],
        fill=Some(
          @core.Brush::linear_gradient(
            start=@core.Point::new(x=0.0, y=0.0),
            end=@core.Point::new(x=16.0, y=0.0),
            start_color=@core.Color::rgba(r=0.0, g=0.0, b=0.0),
            end_color=@core.Color::rgba(r=1.0, g=1.0, b=1.0),
          ),
        ),
      ),
    ),
  ])
  let left = metal_proof_pixel(pixels, 1, 8, 16).0
  let right = metal_proof_pixel(pixels, 15, 8, 16).0
  assert_true(left < right)
  assert_true(right > 200)
}

///|
/// The radius has to widen the blur, not just flatten its weights. The tap budget
/// is thirteen samples an axis; spaced one device pixel apart under a cap of
/// twelve, the kernel reached +-12 pixels whatever the radius asked for, so at
/// `Blur(16.0)` a straight edge measured zero one sigma out where a Gaussian is at
/// 15.9%, and the sigma inside stayed fully opaque instead of falling to 84%. The
/// samples now spread over ~2 sigma, which these four readings are the shape of.
test "a large blur radius widens the falloff instead of flattening it" {
  let half_plane = metal_fill(
    metal_rect(0.0, 0.0, 24.0, height=48.0),
    metal_white(),
  )
  let pixels = metal_proof(
    width=64,
    height=48,
    commands=metal_filter(@core.FilterEffect::Blur(16.0), [half_plane]),
  )
  fn ink(x : Int32) -> Int32 {
    metal_proof_pixel(pixels, x, 24, 64).0
  }
  // Sixteen pixels inside the edge: a Gaussian is at 84% there, where the spaced
  // kernel still read a hard 100%.
  let inside = ink(8)
  // The edge itself, then one and one-and-a-half sigma past it.
  let edge = ink(24)
  let one_sigma = ink(40)
  let one_and_a_half = ink(48)
  assert_true(
    inside > 190 && inside < 245,
    msg="16px inside a sigma-16 edge should be ~84%: \{inside}",
  )
  assert_true(
    edge > 100 && edge < 156,
    msg="a blurred edge is half-covered at the edge: \{edge}",
  )
  assert_true(
    one_sigma > 20 && one_sigma < 62,
    msg="one sigma out should be ~16%: \{one_sigma}",
  )
  assert_true(
    one_and_a_half > 4 && one_and_a_half < one_sigma,
    msg="1.5 sigma out should be faint but present: \{one_and_a_half}",
  )
}
