///|
test "the frame report names what the route refuses without a device" {
  let report = metal_frame_report(
    commands=[
      @core.FillRoundedRect(
        @core.RoundedRect::new(
          rect=metal_rect(0.0, 0.0, 8.0, height=8.0),
          radius=2.0,
        ),
        @core.Color::white(),
      ),
      @core.PushRoundedClip(
        @core.RoundedRect::new(
          rect=metal_rect(0.0, 0.0, 4.0, height=4.0),
          radius=2.0,
        ),
      ),
      @core.PopRoundedClip,
      @core.DrawImage(
        @core.ImageRun::new("missing.png", metal_rect(0.0, 0.0, 4.0)),
      ),
      @core.PushFilter(@core.FilterEffect::blur(2.0)),
      @core.PopFilter,
      @core.DrawShaderEffect(
        @core.ShaderEffectSpec::new(
          name="glow",
          frame=metal_rect(0.0, 0.0, 4.0),
        ),
      ),
    ],
    width=16.0,
    height=16.0,
  )
  assert_true(report.draws_anything())
  assert_eq(report.items, 2)
  // Nothing in this stream is left undrawn. `DrawImage` is handled, but a report
  // computed without a device cannot decode, so it lands in the unresolved
  // counter instead of pretending the route cannot draw images. A filter scope
  // over an empty group counts as neither: it paints nothing on any route. The
  // shader effect names an effect this route has no formulation for, so it is
  // drawn with its own fallback brush — a declared degradation rather than a
  // refusal, which is why it shows up in its own counter. The rounded clip is
  // exact now (nothing shrinks it), and its group is empty, so it opens no
  // composite and leaves nothing to report; the approximation itself is pinned
  // by `metal_state_wbtest.mbt`.
  assert_eq(report.approximated_clips, 0)
  assert_eq(report.image_ops_unresolved, 1)
  assert_eq(report.layers, 0)
  assert_eq(report.filter_approximations, 0)
  assert_eq(report.shader_effects_fallback_painted, 1)
  assert_eq(report.retained_layers_rebuilt, 0)
  assert_eq(report.refused_count(), 0)
  assert_eq(report.text_dropped_glyphs, 0)
}

///|
test "a text run without an engine is reported, not silently empty" {
  let run = @core.DrawText(
    @core.TextRun::new(
      text="i",
      frame=metal_rect(0.0, 0.0, 40.0, height=16.0),
      font=@core.FontSpec::new(),
      color=@core.Color::white(),
      align=@core.TextStart,
    ),
  )
  let without_engine = metal_frame_report(
    commands=[run],
    width=40.0,
    height=16.0,
  )
  let with_engine = metal_frame_report(
    commands=[run],
    width=40.0,
    height=16.0,
    text_engine=metal_test_text_engine(),
  )
  assert_eq(without_engine.text_runs_dropped, 1)
  assert_eq(without_engine.items, 0)
  assert_eq(with_engine.text_runs_dropped, 0)
  assert_eq(with_engine.items, 1)
  assert_eq(with_engine.vertices, 6)
}
