///|
pub fn[Msg] text(
  text : String,
  role? : TextRole = TextRole::Body,
  theme? : @core.Theme = default_theme(),
  width? : Double = 160.0,
  height? : Double = 32.0,
) -> @core.View[Msg] {
  let size = @core.Size::new(width~, height~)
  let font = role.font(theme)
  let color = role.color(theme)
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="Text"),
    revision=() => {
      "text:\{text}:\{size.width}:\{size.height}:\{font.size}:\{font.weight}:\{color.r}:\{color.g}:\{color.b}:\{color.a}"
    },
    layout=ctx => {
      @core.ViewLayoutResult::new(size=ctx.constraints.constrain(size))
    },
    paint=ctx => {
      @core.ViewPaintPlan::commands([
        @core.DrawCommand::DrawText(
          @core.TextRun::new(text~, frame=ctx.frame, font~, color~),
        ),
      ])
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        role=@core.SemanticsRole::Text,
        label=text,
        value=text,
      )
    },
  )
}
