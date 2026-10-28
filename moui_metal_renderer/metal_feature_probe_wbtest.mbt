///|
/// The capability table put against observation.
///
/// `scripts/validate-renderer-capability-consistency.mjs` already fails when
/// `docs/renderer-capability-report.md` disagrees with `metal_feature_status`,
/// and `metal_capability notes cannot be more optimistic than their status` fails
/// when a note is shorter than its status claims. Neither of those can notice a
/// row whose op simply does not reach the screen: the table and the docs can agree
/// perfectly about a feature the route paints as nothing. This file closes that
/// gap by asking the device, once per row, what the row's own probe stream
/// produced, and refusing a row that claims ink it did not paint — or that reports
/// `Gap` while ink is there, which is the same drift in the pessimistic
/// direction.
///
/// The streams are the *minimum* that exercises a row, not a re-run of the
/// per-feature pixel proofs elsewhere in the package: those assert the shape of
/// the result (a ring with a clean interior, a gradient that is monotonic along
/// its axis), while this walk asks only whether the row's status is compatible
/// with the frame it paints.
///
/// The stronger half, added after the first version of this file only asked about
/// ink: `metal_probe_row_observed` demands the consequence only the row's own op
/// produces — a measured number or pixel relation the other sixteen streams cannot
/// yield. A clip that was ignored leaves 64 inked pixels where the row demands
/// ~16, a transform that was ignored puts ink at the origin, a blur that was
/// ignored keeps its light inside the shape, a colour glyph composited as coverage
/// fails the channel test its row is named for.
///
/// What still needs review rather than a compile error: the *stream* a row is
/// filed under is chosen here, so a new row can be given a stream that does not
/// exercise it — but that stream then has to pass the predicate written for it,
/// which is where the mistake becomes visible to a reader instead of invisible to
/// a gate.

///|
/// The row's own observable: what only that row's op can leave behind in a frame.
///
/// Ink alone cannot tell a row that works from a row whose stream happens to paint
/// something else — the previous version of this file said so out loud. Each arm
/// below is set from a measured value on the stream above, and each is a property
/// the other fifteen streams do not produce: the clip halves the rect's coverage to
/// its own 4x4, the transform moves the ink rather than adding it, the blur puts
/// light outside the shape it wrapped (ink past the 64 pixels the fill could cover),
/// the rounded box leaves its corner clear, a colour glyph lights a channel the run
/// colour zeroes. There is no catch-all, so a new `RendererFeature` variant is a
/// compile error here as well as in the two walks in `capabilities.mbt`.
fn metal_probe_row_observed(
  feature : @render.RendererFeature,
  report : MetalFrameReport,
  pixels : Bytes,
) -> Bool {
  let ink = metal_probe_ink(pixels)
  fn at(x : Int32, y : Int32) -> (Int32, Int32, Int32, Int32) {
    metal_proof_pixel(pixels, x, y, 16)
  }
  match feature {
    @render.RendererFeature::Rect => ink == 64
    RoundedRect => ink < 64 && ink > 50 && at(0, 0).0 < 12
    Gradient => at(0, 0).1 > 200 && at(6, 6).1 < 120 && at(6, 6).0 > 200
    Shadow => at(0, 0).0 > 0 && at(0, 0).0 < at(1, 1).0 && ink > 30 && ink < 64
    Text => ink > 0 && ink < 48
    // The fixture is red on its left half and blue on its right, so this is a
    // texture sample and not a solid brush: no other row's stream can produce two
    // different pure channels in one 8x8 draw.
    Image =>
      at(0, 0).0 > 200 && at(0, 0).1 < 60 && at(6, 6).2 > 200 && at(6, 6).0 < 60
    Clip => ink > 9 && ink < 25
    Transform => at(0, 0).0 < 12 && at(6, 6).0 > 200
    Opacity => at(0, 0).0 > 100 && at(0, 0).0 < 160 && ink == 64
    LayerCompositing =>
      report.layers == 1 && at(0, 0).0 > 100 && at(0, 0).0 < 160
    BlendMode => report.blend_modes_approximated == 1 && ink == 64
    FilterEffect =>
      report.layers == 2 && report.filter_approximations == 1 && ink > 64
    PathVector => ink > 8 && ink < 60
    ShaderEffect => report.shader_effects_fallback_painted == 1 && ink == 64
    TextShaping => ink > 0 && ink < 48 && report.text_dropped_glyphs == 0
    EmojiText => at(0, 0).1 > 200 && at(0, 0).0 < 60
    AsyncImage => true
  }
}

///|
/// The rows a single frame cannot answer, named rather than quietly absent: an
/// async image is requested on frame one and painted on the frame after the
/// completion, so its evidence is the two lifecycle proof in
/// `metal_image_wbtest.mbt` and nothing a one-frame probe could assert. The
/// companion test below checks this row really is empty on one frame, so the
/// exemption stays true instead of becoming a place to hide.
let metal_probe_exempt_rows : Array[@render.RendererFeature] = [
  @render.RendererFeature::AsyncImage,
]

///|
fn metal_probe_commands(
  feature : @render.RendererFeature,
) -> Array[@core.DrawCommand] {
  let fill = @core.FillRect(
    metal_rect(0.0, 0.0, 8.0, height=8.0),
    metal_white(),
  )
  match feature {
    @render.RendererFeature::Rect => [fill]
    RoundedRect =>
      [
        metal_fill(
          metal_rect(0.0, 0.0, 8.0, height=8.0),
          metal_white(),
          radius=3.0,
        ),
      ]
    Gradient =>
      [
        @core.FillRoundedRectBrush(
          @core.RoundedRect::new(
            rect=metal_rect(0.0, 0.0, 8.0, height=8.0),
            radius=0.0,
          ),
          @core.Brush::linear_gradient(
            start=metal_point(0.0, 0.0),
            end=metal_point(8.0, 8.0),
            start_color=metal_white(),
            end_color=metal_red(),
          ),
        ),
      ]
    Shadow =>
      [
        @core.DrawShadow(
          @core.ShadowSpec::new(
            rect=@core.RoundedRect::new(
              rect=metal_rect(2.0, 2.0, 4.0, height=4.0),
              radius=1.0,
            ),
            color=metal_white(),
            offset=metal_point(0.0, 0.0),
            blur_radius=2.0,
          ),
        ),
      ]
    Text => [metal_test_run_coloured(metal_white())]
    Image => [metal_test_image_run(frame=metal_rect(0.0, 0.0, 8.0, height=8.0))]
    Clip =>
      [
        @core.PushClip(metal_rect(0.0, 0.0, 4.0, height=4.0)),
        fill,
        @core.PopClip,
      ]
    Transform =>
      [
        @core.PushTransform(@core.Transform2D::translation(dx=4.0, dy=4.0)),
        @core.FillRect(metal_rect(0.0, 0.0, 4.0, height=4.0), metal_white()),
        @core.PopTransform,
      ]
    Opacity => [@core.PushOpacity(0.5), fill, @core.PopOpacity]
    LayerCompositing => metal_layer(@core.LayerSpec::new(opacity=0.5), [fill])
    // `Screen`, not `Multiply`, because the probe frame clears to opaque black:
    // multiply against that destination is *correctly* nothing, and the row's ink
    // would then have to come from somewhere else. Screen of white over black is
    // white, so the bright pixels in this frame are the composite's own.
    BlendMode =>
      metal_layer(@core.LayerSpec::new(blend_mode=@core.BlendMode::Screen), [
        fill,
      ])
    FilterEffect => metal_filter(@core.FilterEffect::blur(1.0), [fill])
    PathVector => [metal_triangle(metal_white())]
    ShaderEffect =>
      [
        @core.DrawShaderEffect(
          @core.ShaderEffectSpec::new(
            name="probe",
            frame=metal_rect(0.0, 0.0, 8.0, height=8.0),
            fallback=@core.Brush::solid(metal_white()),
          ),
        ),
      ]
    TextShaping => [metal_test_run_coloured(metal_white())]
    EmojiText => [metal_test_run_coloured(metal_white())]
    AsyncImage =>
      [metal_test_image_run(frame=metal_rect(0.0, 0.0, 8.0, height=8.0))]
  }
}

///|
/// The engine each row needs. Text rows are the only ones that can produce ink
/// without a device-side dependency: the coverage path needs a raster, and the
/// colour path needs the colour raster, which is what makes the `EmojiText` row's
/// probe distinguishable from the `Text` row's.
fn metal_probe_engine(feature : @render.RendererFeature) -> NativeTextEngine {
  match feature {
    @render.RendererFeature::Text | TextShaping =>
      metal_test_engine_for(metal_test_glyph_raster())
    EmojiText => metal_test_engine_for(metal_colour_glyph_raster())
    _ => native_noop_text_engine()
  }
}

///|
fn metal_probe_image_source(
  feature : @render.RendererFeature,
) -> @render.HostImageSource {
  match feature {
    @render.RendererFeature::Image => metal_test_png_source()
    _ => @render.HostImageSource::unavailable()
  }
}

///|
/// Any pixel the clear colour did not already supply. The probe frames clear to
/// black and every stream here paints white, red or green, so "some channel above
/// the clear's noise floor" is the weakest claim that still distinguishes a drawn
/// feature from an absent one.
fn metal_probe_ink(pixels : Bytes) -> Int32 {
  let mut inked = 0
  let total = pixels.length() / 4
  let mut index = 0
  while index < total {
    let offset = index * 4
    if pixels[offset].to_int() > 40 ||
      pixels[offset + 1].to_int() > 40 ||
      pixels[offset + 2].to_int() > 40 {
      inked += 1
    }
    index += 1
  }
  inked
}

///|
fn metal_probe_frame(feature : @render.RendererFeature) -> Bytes {
  metal_proof(
    width=16,
    height=16,
    commands=metal_probe_commands(feature),
    text_engine=metal_probe_engine(feature),
    image_source=metal_probe_image_source(feature),
  )
}

///|
/// The same stream counted on the CPU, because three rows' consequences are
/// counters (`layers`, `blend_modes_approximated`, `filter_approximations`,
/// `shader_effects_fallback_painted`) rather than pixels.
fn metal_probe_report(feature : @render.RendererFeature) -> MetalFrameReport {
  metal_frame_report(
    commands=metal_probe_commands(feature),
    width=16.0,
    height=16.0,
    text_engine=metal_probe_engine(feature),
  )
}

///|
test "no capability row claims ink the device did not paint" {
  let caps = metal_feature_capabilities()
  assert_eq(caps.length(), 17)
  let mut probed = 0
  for cap in caps {
    if metal_probe_exempt_rows.contains(cap.feature) {
      continue
    }
    let pixels = metal_probe_frame(cap.feature)
    let ink = metal_probe_ink(pixels)
    match cap.status {
      @render.RendererFeatureStatus::Supported | Partial | HostForwarded =>
        if ink == 0 {
          fail(
            "the \{cap.feature.label()} row reports \{cap.status.label()} but its probe stream paints nothing",
          )
        }
      @render.RendererFeatureStatus::Gap | Unavailable =>
        if ink > 0 {
          fail(
            "the \{cap.feature.label()} row reports \{cap.status.label()} while its probe stream paints \{ink} pixels",
          )
        }
    }
    // The consequence, not just the ink: a stream that paints something is
    // compatible with almost every row, a stream that shows what only this row's
    // op produces is evidence about the row.
    if ink > 0 &&
      !metal_probe_row_observed(
        cap.feature,
        metal_probe_report(cap.feature),
        pixels,
      ) {
      fail(
        "the \{cap.feature.label()} row is not shown by its own probe stream's consequence",
      )
    }
    probed += 1
  }
  // 16 of 17: every row except the one-frame-exempt async image. A walk that
  // silently probed fewer rows would still pass the loop above, so the count is
  // the assertion that the walk is the walk.
  assert_eq(probed, 16)
}

///|
test "the exempted row is exempt because one frame really paints nothing" {
  let ink = metal_probe_ink(
    metal_probe_frame(@render.RendererFeature::AsyncImage),
  )
  assert_eq(ink, 0)
}

///|
test "a row that claims supported refuses nothing in its own probe" {
  for cap in metal_feature_capabilities() {
    if cap.status != @render.RendererFeatureStatus::Supported {
      continue
    }
    let report = metal_frame_report(
      commands=metal_probe_commands(cap.feature),
      width=16.0,
      height=16.0,
      text_engine=metal_probe_engine(cap.feature),
    )
    // `metal_frame_report` is computed without a decoder by design, so
    // `image_ops_unresolved` is not evidence about the `Image` row and is left
    // out of `refused_count()`; everything in it is a departure this route
    // reported while drawing a row that says it does not depart.
    if report.refused_count() != 0 {
      fail(
        "the \{cap.feature.label()} row reports supported, but its probe refuses \{report.refused_count()} ops",
      )
    }
  }
}

///|
test "the shaping row is forwarded, not drawn by this route" {
  // `TextShaping` reports `HostForwarded`: the claim is that this module
  // implements no shaping and only paints what the injected engine placed. The
  // device-level form of that claim is a stream whose ink depends entirely on the
  // engine being there — with the noop engine the same command paints nothing.
  let commands = metal_probe_commands(@render.RendererFeature::TextShaping)
  let with_engine = metal_probe_ink(
    metal_probe_frame(@render.RendererFeature::TextShaping),
  )
  let without_engine = metal_probe_ink(
    metal_proof(width=16, height=16, commands~),
  )
  guard without_engine == 0 else {
    fail(
      "a route that shaped nothing must paint nothing when the engine hands it nothing, got \{without_engine} pixels",
    )
  }
  guard with_engine > 0 else {
    fail(
      "the injected engine's placements must reach the screen or this row proves nothing",
    )
  }
}
