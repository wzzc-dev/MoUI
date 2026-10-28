///|
/// Paint-state probes for the two capability rows that were asserted from a
/// reading of `metal_geometry.mbt` rather than from pixels. Before this file,
/// `PushTransform`/`PopTransform` and `PushOpacity`/`PopOpacity` appeared in no
/// test at all: the rows reported `Partial` and nothing could have noticed a
/// route that dropped the op, replaced an outer scope instead of composing it,
/// or forgot to pop. Every number below comes from the matrix product or the
/// opacity product a correct stack produces, and every sample point is at least
/// one device pixel from the shape edge so the coverage ramp cannot supply it.

///|
fn metal_state_probe(commands~ : Array[@core.DrawCommand]) -> Bytes {
  metal_proof(width=16, height=16, commands~)
}

///|
fn metal_state_channel(pixels : Bytes, x : Int32, y : Int32) -> (Int32, Int32) {
  let pixel = metal_proof_pixel(pixels, x, y, 16)
  (pixel.0, pixel.3)
}

///|
test "a pushed transform moves the fill to where the matrix says" {
  let pixels = metal_state_probe(commands=[
    @core.PushTransform(@core.Transform2D::translation(dx=6.0, dy=2.0)),
    @core.FillRect(metal_rect(0.0, 0.0, 4.0, height=4.0), metal_white()),
    @core.PopTransform,
  ])
  // The box lands on [6,10) x [2,6). A route that dropped the op paints it on
  // [0,4) x [0,4), and one that swapped the two offsets paints the transpose at
  // [2,6) x [6,10) — both are checked by a pixel that must stay clear.
  assert_true(metal_is_white(metal_proof_pixel(pixels, 7, 3, 16)))
  assert_true(metal_is_white(metal_proof_pixel(pixels, 8, 4, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 1, 1, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 3, 7, 16)))
}

///|
test "a scale is applied from the surface origin, not the shape centre" {
  let pixels = metal_state_probe(commands=[
    @core.PushTransform(@core.Transform2D::scale(sx=2.0, sy=2.0)),
    @core.FillRect(metal_rect(0.0, 0.0, 4.0, height=4.0), metal_white()),
    @core.PopTransform,
  ])
  // (6,6) is inside the scaled box and outside the unscaled one, so it is the
  // pixel that says whether the matrix reached the vertices at all; (10,10) is
  // two device pixels past the scaled edge, so a route that also scaled the
  // surface size cannot light it either.
  assert_true(metal_is_white(metal_proof_pixel(pixels, 6, 6, 16)))
  assert_true(metal_is_white(metal_proof_pixel(pixels, 1, 1, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 10, 10, 16)))
}

///|
test "a nested transform composes with its parent instead of replacing it" {
  let pixels = metal_state_probe(commands=[
    @core.PushTransform(@core.Transform2D::translation(dx=4.0, dy=0.0)),
    @core.PushTransform(@core.Transform2D::translation(dx=0.0, dy=4.0)),
    @core.FillRect(metal_rect(0.0, 0.0, 4.0, height=4.0), metal_white()),
    @core.PopTransform,
    @core.PopTransform,
  ])
  // Only the sum of the two offsets puts ink at (6,6). A stack that overwrote
  // the parent would land on [0,4) x [4,8) or [4,8) x [0,4), each of which the
  // two clear samples below separate.
  assert_true(metal_is_white(metal_proof_pixel(pixels, 6, 6, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 2, 6, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 6, 2, 16)))
}

///|
test "a scale then a translation does not move the scaled size" {
  let pixels = metal_state_probe(commands=[
    @core.PushTransform(@core.Transform2D::translation(dx=4.0, dy=4.0)),
    @core.PushTransform(@core.Transform2D::scale(sx=2.0, sy=2.0)),
    @core.FillRect(metal_rect(0.0, 0.0, 2.0, height=2.0), metal_white()),
    @core.PopTransform,
    @core.PopTransform,
  ])
  // Parent-then-child means the child matrix is applied first: the 2x2 box
  // becomes 4x4 and only then moves, landing on [4,8) x [4,8). A route that
  // composed in the other order would translate before scaling and put the box
  // on [12,16) x [12,16), which (2,2) and (14,14) tell apart.
  assert_true(metal_is_white(metal_proof_pixel(pixels, 6, 6, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 2, 2, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 14, 14, 16)))
}

///|
test "a popped transform leaves the next op in surface space" {
  let pixels = metal_state_probe(commands=[
    @core.PushTransform(@core.Transform2D::translation(dx=8.0, dy=8.0)),
    @core.FillRect(metal_rect(0.0, 0.0, 4.0, height=4.0), metal_white()),
    @core.PopTransform,
    @core.FillRect(metal_rect(0.0, 0.0, 4.0, height=4.0), metal_red()),
  ])
  // Two fills of the same rect must land in two different places. An unbalanced
  // stack leaves the red one on [8,12) x [8,12) too, painting over the white and
  // leaving (2,2) clear.
  assert_true(metal_is_white(metal_proof_pixel(pixels, 9, 9, 16)))
  assert_true(metal_is_red(metal_proof_pixel(pixels, 2, 2, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 14, 2, 16)))
}

///|
test "a transform that moves a box into a masked layer's frame is not culled" {
  let pixels = metal_state_probe(commands=[
    @core.PushLayer(
      @core.LayerSpec::new(
        mask=@core.LayerMask::RectMask(metal_rect(4.0, 4.0, 8.0, height=8.0)),
      ),
    ),
    @core.PushTransform(@core.Transform2D::translation(dx=4.0, dy=4.0)),
    @core.FillRect(metal_rect(0.0, 0.0, 4.0, height=4.0), metal_white()),
    @core.PopTransform,
    @core.PopLayer,
  ])
  // The offscreen pass is the test: drop the transform and the group's only
  // content sits on [0,4) x [0,4), entirely outside the mask, so the composite
  // brings back nothing at (6,6). Subtract the pass origin twice and the same
  // pixel is empty while (2,2) — outside the mask — lights up.
  assert_true(metal_is_white(metal_proof_pixel(pixels, 6, 6, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 2, 2, 16)))
}

///|
test "a pushed opacity scales the fill's alpha at the vertex" {
  let pixels = metal_state_probe(commands=[
    @core.PushOpacity(0.5),
    @core.FillRect(metal_rect(0.0, 0.0, 8.0, height=8.0), metal_white()),
    @core.PopOpacity,
  ])
  let (red, alpha) = metal_state_channel(pixels, 3, 3)
  guard metal_near(red, 128) else {
    fail(
      "a half-strength white fill must land at 128 on a black clear, got \{red}",
    )
  }
  // Premultiplied source-over onto an opaque clear keeps the destination alpha.
  guard alpha > 240 else {
    fail("the composited pixel must stay opaque, got alpha \{alpha}")
  }
  assert_true(metal_is_black(metal_proof_pixel(pixels, 10, 10, 16)))
}

///|
test "nested opacity multiplies rather than taking the innermost" {
  let pixels = metal_state_probe(commands=[
    @core.PushOpacity(0.5),
    @core.PushOpacity(0.5),
    @core.FillRect(metal_rect(0.0, 0.0, 8.0, height=8.0), metal_white()),
    @core.PopOpacity,
    @core.PopOpacity,
  ])
  let (red, _) = metal_state_channel(pixels, 3, 3)
  // 0.25 of white is 63.75; a stack that replaced instead of multiplying would
  // report 128, which is 65 away and outside the tolerance this file allows.
  guard metal_near(red, 64) else {
    fail("nested opacity must multiply to a quarter, got \{red}")
  }
}

///|
test "a popped opacity leaves the next fill at full strength" {
  let pixels = metal_state_probe(commands=[
    @core.PushOpacity(0.5),
    @core.PopOpacity,
    @core.FillRect(metal_rect(0.0, 0.0, 8.0, height=8.0), metal_white()),
  ])
  let (red, _) = metal_state_channel(pixels, 3, 3)
  guard metal_near(red, 255) else {
    fail("the popped scope must hand full strength back, got \{red}")
  }
}

///|

///|
test "a clip pushed under a transform clips where the transform puts it" {
  let pixels = metal_state_probe(commands=[
    @core.PushTransform(@core.Transform2D::translation(dx=4.0, dy=4.0)),
    @core.PushClip(metal_rect(0.0, 0.0, 8.0, height=8.0)),
    @core.FillRect(metal_rect(0.0, 0.0, 16.0, height=16.0), metal_white()),
    @core.PopClip,
    @core.PopTransform,
  ])
  // The fill only reaches [4,16) once the transform is on the stack, so the two
  // halves of this assertion read apart three routes: the scissor moved with the
  // transform keeps (9,9) inked; a scissor left in surface space stops at 8 and
  // loses it; a route that dropped the clip keeps (14,14).
  assert_true(metal_is_white(metal_proof_pixel(pixels, 9, 9, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 14, 14, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 2, 2, 16)))
}

///|
test "a rounded clip under a transform moves with it too" {
  let report = metal_frame_report(
    commands=[
      @core.PushTransform(@core.Transform2D::translation(dx=4.0, dy=4.0)),
      @core.PushRoundedClip(
        @core.RoundedRect::new(
          rect=metal_rect(0.0, 0.0, 8.0, height=8.0),
          radius=2.0,
        ),
      ),
      @core.FillRect(metal_rect(0.0, 0.0, 16.0, height=16.0), metal_white()),
      @core.PopRoundedClip,
      @core.PopTransform,
    ],
    width=16.0,
    height=16.0,
  )
  // Same arithmetic as the rect clip: a translation keeps the rounded box a
  // rounded box, so the corners are now clipped by the arc rather than by the
  // bounding rect, and there is no approximation left to report.
  let pixels = metal_state_probe(commands=[
    @core.PushTransform(@core.Transform2D::translation(dx=4.0, dy=4.0)),
    @core.PushRoundedClip(
      @core.RoundedRect::new(
        rect=metal_rect(0.0, 0.0, 8.0, height=8.0),
        radius=2.0,
      ),
    ),
    @core.FillRect(metal_rect(0.0, 0.0, 16.0, height=16.0), metal_white()),
    @core.PopRoundedClip,
    @core.PopTransform,
  ])
  assert_true(metal_is_white(metal_proof_pixel(pixels, 9, 9, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 14, 14, 16)))
  assert_eq(report.approximated_clips, 0)
}

///|
test "a rounded clip rounds the corner instead of squaring it off" {
  // The half the `Clip` row used to give up on. A 16x16 group clipped by a
  // radius-6 arc leaves its own corner outside the arc while the same point is
  // two device pixels inside the bounding rect, so a route that clips by the
  // rect cannot put (0,0) back to black -- and a route that clips at the wrong
  // radius cannot keep (2,2) white.
  let pixels = metal_state_probe(commands=[
    @core.PushRoundedClip(
      @core.RoundedRect::new(
        rect=metal_rect(0.0, 0.0, 16.0, height=16.0),
        radius=6.0,
      ),
    ),
    @core.FillRect(metal_rect(0.0, 0.0, 16.0, height=16.0), metal_white()),
    @core.PopRoundedClip,
  ])
  assert_true(metal_is_black(metal_proof_pixel(pixels, 0, 0, 16)))
  assert_true(metal_is_black(metal_proof_pixel(pixels, 15, 15, 16)))
  assert_true(metal_is_white(metal_proof_pixel(pixels, 2, 2, 16)))
  assert_true(metal_is_white(metal_proof_pixel(pixels, 8, 2, 16)))
  let report = metal_frame_report(
    commands=[
      @core.PushRoundedClip(
        @core.RoundedRect::new(
          rect=metal_rect(0.0, 0.0, 16.0, height=16.0),
          radius=6.0,
        ),
      ),
      @core.FillRect(metal_rect(0.0, 0.0, 16.0, height=16.0), metal_white()),
      @core.PopRoundedClip,
    ],
    width=16.0,
    height=16.0,
  )
  // An exact clip is not an approximation, so the counter that used to carry
  // every rounded clip is empty here -- `metal_report_wbtest.mbt`'s refused
  // count is the other half of the same claim.
  assert_eq(report.approximated_clips, 0)
  assert_eq(report.layers, 1)
}

///|
test "a rounded clip under a scale rounds at the scaled radius" {
  // The clip rect becomes 16x16 under the scale, so the arc has to become 6 as
  // well. At the scaled radius the corner pixel is almost untouched and the
  // point one pixel in is nearly clear; a route that kept the logical radius 3
  // on the scaled box paints both white, which is the mis-draw this pins.
  let pixels = metal_state_probe(commands=[
    @core.PushTransform(@core.Transform2D::scale(sx=2.0, sy=2.0)),
    @core.PushRoundedClip(
      @core.RoundedRect::new(
        rect=metal_rect(0.0, 0.0, 8.0, height=8.0),
        radius=3.0,
      ),
    ),
    @core.FillRect(metal_rect(0.0, 0.0, 8.0, height=8.0), metal_white()),
    @core.PopRoundedClip,
    @core.PopTransform,
  ])
  // Only the red channel carries the arc here: the group composites over an
  // opaque black clear, so source-over restores full alpha even where the mask
  // has almost nothing left to show.
  let corner = metal_proof_pixel(pixels, 1, 1, 16)
  assert_true(
    corner.0 < 60,
    msg="corner \{corner.0} is inside an unscaled radius-3 arc",
  )
  assert_true(metal_is_white(metal_proof_pixel(pixels, 3, 3, 16)))
  assert_true(metal_is_white(metal_proof_pixel(pixels, 8, 2, 16)))
}

///|
test "a rounded clip that cannot stay a rounded box is still counted" {
  // Two shapes the composite SDF cannot describe: a parent clip that shrinks
  // the rect (so the arc would round the wrong box) and a transform with a
  // skew (so the corners are ellipses). Both fall back to the bounding-rect
  // scissor, and the fallback has to show up in the report rather than in a
  // corner that looks clipped but is not.
  let clipped = metal_frame_report(
    commands=[
      @core.PushClip(metal_rect(0.0, 0.0, 8.0, height=16.0)),
      @core.PushRoundedClip(
        @core.RoundedRect::new(
          rect=metal_rect(0.0, 0.0, 16.0, height=16.0),
          radius=6.0,
        ),
      ),
      @core.FillRect(metal_rect(0.0, 0.0, 16.0, height=16.0), metal_white()),
      @core.PopRoundedClip,
      @core.PopClip,
    ],
    width=16.0,
    height=16.0,
  )
  assert_eq(clipped.approximated_clips, 1)
  let skewed = metal_frame_report(
    commands=[
      @core.PushTransform(@core.Transform2D::{
        a: 1.0,
        b: 0.5,
        c: -0.5,
        d: 1.0,
        tx: 0.0,
        ty: 0.0,
      }),
      @core.PushRoundedClip(
        @core.RoundedRect::new(
          rect=metal_rect(0.0, 0.0, 4.0, height=4.0),
          radius=2.0,
        ),
      ),
      @core.FillRect(metal_rect(0.0, 0.0, 4.0, height=4.0), metal_white()),
      @core.PopRoundedClip,
      @core.PopTransform,
    ],
    width=16.0,
    height=16.0,
  )
  assert_eq(skewed.approximated_clips, 1)
}
