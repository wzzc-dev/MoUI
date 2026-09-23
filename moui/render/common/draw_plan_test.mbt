///|
/// Tests for the shared DrawCommand lowering: every variant lowers to the
/// matching neutral op, and scope balance diagnostics are produced for
/// unbalanced streams.

///|
test "lower_draw_commands mirrors every variant" {
  let commands = [
    @core.DrawCommand::Clear(@core.Color::white()),
    FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
      @core.Color::black(),
    ),
    StrokeRect(
      @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
      @core.Color::black(),
      2.0,
    ),
    FillRoundedRect(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
        radius=2.0,
      ),
      @core.Color::black(),
    ),
    StrokeRoundedRect(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
        radius=2.0,
      ),
      @core.Color::black(),
      2.0,
    ),
    FillRoundedRectBrush(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
        radius=2.0,
      ),
      @core.Brush::solid(@core.Color::black()),
    ),
    StrokeRoundedRectBrush(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
        radius=2.0,
      ),
      @core.Brush::solid(@core.Color::black()),
      2.0,
    ),
    DrawShadow(
      @core.ShadowSpec::new(
        rect=@core.RoundedRect::new(
          rect=@core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
          radius=2.0,
        ),
        color=@core.Color::black(),
        offset=@core.Point::new(x=1.0, y=1.0),
        blur_radius=2.0,
        spread=0.0,
      ),
    ),
    DrawText(
      @core.TextRun::new(
        text="hello",
        frame=@core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
        font=@core.FontSpec::new(size=10.0),
        color=@core.Color::black(),
      ),
    ),
    DrawImage({
      source: "",
      frame: @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
      opacity: 1.0,
      fit: Contain,
    }),
    DrawPath(
      @core.PathSpec::new(
        verbs=[MoveTo(@core.Point::new(x=0.0, y=0.0))],
        fill=Some(@core.Brush::solid(@core.Color::black())),
      ),
    ),
    DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="vignette",
        frame=@core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
        fallback=@core.Brush::solid(@core.Color::black()),
      ),
    ),
  ]
  let plan = @common.lower_draw_commands(commands)
  assert_eq(plan.ops.length(), 12)
  assert_eq(plan.diagnostics.length(), 0)
}

///|
test "lower_draw_commands balances scopes and reports mismatches" {
  let plan = @common.lower_draw_commands([
    PushClip(@core.Rect::new(x=0.0, y=0.0, width=1.0, height=1.0)),
    PushTransform(@core.Transform2D::identity()),
    PushOpacity(0.5),
    PopTransform,
    PopClip,
    PopOpacity,
    PopClip,
  ])
  assert_eq(plan.ops.length(), 7)
  assert_eq(plan.diagnostics.length(), 4)
  inspect(plan.diagnostics[0].command, content="PopTransform")
  inspect(plan.diagnostics[1].command, content="PopClip")
  inspect(plan.diagnostics[2].command, content="PopOpacity")
  inspect(plan.diagnostics[3].command, content="PopClip")
}

///|
test "lower_draw_commands reports unpopped scopes" {
  let plan = @common.lower_draw_commands([
    PushLayer(@core.LayerSpec::new()),
    PushFilter(@core.FilterEffect::blur(2.0)),
    FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=1.0, height=1.0),
      @core.Color::black(),
    ),
  ])
  assert_eq(plan.ops.length(), 3)
  assert_eq(plan.diagnostics.length(), 2)
  inspect(plan.diagnostics[0].command, content="PushFilter")
  inspect(plan.diagnostics[1].command, content="PushLayer")
}

///|
test "lower_draw_commands accepts balanced cached layer scopes" {
  let plan = @common.lower_draw_commands([
    BeginRetainedLayer(
      @core.RetainedLayerSpec::new(
        key="k",
        frame=@core.Rect::new(x=0.0, y=0.0, width=1.0, height=1.0),
        content_revision=1,
      ),
    ),
    EndRetainedLayer("k"),
  ])
  assert_eq(plan.diagnostics.length(), 0)
}
