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
  @core.View::from_node(Image::{
    source,
    size,
    opacity,
    corner_radius,
    fit,
  })
}

///|
priv struct Image {
  source : String
  size : @core.Size?
  opacity : Double
  corner_radius : Double
  fit : @core.ImageFit
}

///|
impl @core.ViewNode for Image with fn identity(_self) {
  @core.ViewIdentity::new(kind="Image")
}

///|
impl @core.ViewNode for Image with fn revision(self) {
  "image:\{self.source}:\{size_revision(self.size)}:\{self.opacity}:\{self.corner_radius}:\{image_fit_revision(self.fit)}"
}

///|
impl @core.ViewNode for Image with fn layout(self, context) {
  let measured = self.size.unwrap_or(@core.Size::new(width=0.0, height=0.0))
  @core.ViewLayoutResult::new(size=context.constraints.constrain(measured))
}

///|
impl @core.ViewNode for Image with fn paint(self, context) {
  let frame = match self.size {
    Some(size) =>
      @core.Rect::new(
        x=context.frame.origin.x,
        y=context.frame.origin.y,
        width=size.width,
        height=size.height,
      )
    None => context.frame
  }
  let commands : Array[@core.DrawCommand] = []
  if self.corner_radius > 0.0 {
    commands.push(@core.DrawCommand::PushClip(frame))
  }
  commands.push(
    @core.DrawCommand::DrawImage({
      source: self.source,
      frame,
      opacity: self.opacity,
      fit: self.fit,
    }),
  )
  if self.corner_radius > 0.0 {
    commands.push(@core.DrawCommand::PopClip)
  }
  @core.ViewPaintPlan::commands(commands)
}
