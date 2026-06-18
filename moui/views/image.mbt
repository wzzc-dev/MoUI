///|
pub fn[Msg] image(
  source : String,
  width? : Double,
  height? : Double,
  opacity? : Double = 1.0,
  corner_radius? : Double = 0.0,
  fit? : @core.ImageFit = @core.ImageFit::Contain,
) -> @core.View[Msg] {
  let size = match (width, height) {
    (Some(width), Some(height)) => Some(@core.Size::new(width~, height~))
    _ => None
  }
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="Image"),
    revision=() => {
      "image:\{source}:\{size_revision(size)}:\{opacity}:\{corner_radius}:\{image_fit_revision(fit)}"
    },
    layout=ctx => {
      let measured = size.unwrap_or(@core.Size::new(width=0.0, height=0.0))
      @core.ViewLayoutResult::new(size=ctx.constraints.constrain(measured))
    },
    paint=ctx => {
      let frame = match size {
        Some(size) =>
          @core.Rect::new(
            x=ctx.frame.origin.x,
            y=ctx.frame.origin.y,
            width=size.width,
            height=size.height,
          )
        None => ctx.frame
      }
      let commands : Array[@core.DrawCommand] = []
      if corner_radius > 0.0 {
        commands.push(@core.DrawCommand::PushClip(frame))
      }
      commands.push(
        @core.DrawCommand::DrawImage({ source, frame, opacity, fit }),
      )
      if corner_radius > 0.0 {
        commands.push(@core.DrawCommand::PopClip)
      }
      @core.ViewPaintPlan::commands(commands)
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(role=@core.SemanticsRole::Group)
    },
  )
}
