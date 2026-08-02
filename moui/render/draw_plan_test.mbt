///|
/// Tests for the shared DrawCommand lowering: every variant lowers to the
/// matching neutral op, and scope balance diagnostics are produced for
/// unbalanced streams.

///|
test "lower_draw_commands mirrors every variant" {
  let commands = [
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
      @core.Color::black(),
    ),
    @core.DrawCommand::StrokeRect(
      @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
      @core.Color::black(),
      2.0,
    ),
    @core.DrawCommand::FillRoundedRect(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
        radius=2.0,
      ),
      @core.Color::black(),
    ),
    @core.DrawCommand::StrokeRoundedRect(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
        radius=2.0,
      ),
      @core.Color::black(),
      2.0,
    ),
    @core.DrawCommand::FillRoundedRectBrush(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
        radius=2.0,
      ),
      @core.Brush::solid(@core.Color::black()),
    ),
    @core.DrawCommand::StrokeRoundedRectBrush(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
        radius=2.0,
      ),
      @core.Brush::solid(@core.Color::black()),
      2.0,
    ),
    @core.DrawCommand::DrawShadow(
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
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text="hello",
        frame=@core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
        font=@core.FontSpec::new(size=10.0),
        color=@core.Color::black(),
      ),
    ),
    @core.DrawCommand::DrawImage(
      @core.ImageRun::{
        source: "",
        frame: @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
        opacity: 1.0,
        fit: @core.ImageFit::Contain,
      },
    ),
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[@core.PathVerb::MoveTo(@core.Point::new(x=0.0, y=0.0))],
        fill=Some(@core.Brush::solid(@core.Color::black())),
      ),
    ),
    @core.DrawCommand::DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="vignette",
        frame=@core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
        fallback=@core.Brush::solid(@core.Color::black()),
      ),
    ),
  ]
  let plan = lower_draw_commands(commands)
  assert_eq(plan.ops.length(), 12)
  assert_eq(plan.diagnostics.length(), 0)
}

///|
test "lower_draw_commands balances scopes and reports mismatches" {
  let plan = lower_draw_commands([
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=0.0, y=0.0, width=1.0, height=1.0),
    ),
    @core.DrawCommand::PushTransform(@core.Transform2D::identity()),
    @core.DrawCommand::PushOpacity(0.5),
    @core.DrawCommand::PopTransform,
    @core.DrawCommand::PopClip,
    @core.DrawCommand::PopOpacity,
    @core.DrawCommand::PopClip,
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
  let plan = lower_draw_commands([
    @core.DrawCommand::PushLayer(@core.LayerSpec::new()),
    @core.DrawCommand::PushFilter(@core.FilterEffect::blur(2.0)),
    @core.DrawCommand::FillRect(
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
  let plan = lower_draw_commands([
    @core.DrawCommand::BeginCachedLayer(
      @core.CachedLayerSpec::new(
        key="k",
        frame=@core.Rect::new(x=0.0, y=0.0, width=1.0, height=1.0),
        content_revision=1,
      ),
    ),
    @core.DrawCommand::EndCachedLayer("k"),
  ])
  assert_eq(plan.diagnostics.length(), 0)
}
