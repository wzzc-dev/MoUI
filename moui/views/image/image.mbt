///|
pub fn[Msg] image(
  source : String,
  width? : Double,
  height? : Double,
  opacity~ : Double = 1.0,
  corner_radius~ : Double = 0.0,
  fit~ : @core.ImageFit = Contain,
  accessibility_label~ : String = "",
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
    accessibility_label,
  })
}

///|
priv struct Image {
  source : String
  size : @core.Size?
  opacity : Double
  corner_radius : Double
  fit : @core.ImageFit
  accessibility_label : String
}

///|
impl @core.ViewNode for Image with fn identity(_self) {
  @core.ViewIdentity::new(kind="Image")
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
    commands.push(PushClip(frame))
  }
  commands.push(
    DrawImage({
      source: self.source,
      frame,
      opacity: self.opacity,
      fit: self.fit,
      src_rect: None,
    }),
  )
  if self.corner_radius > 0.0 {
    commands.push(PopClip)
  }
  @core.ViewPaintPlan::commands(commands)
}

///|
impl @core.ViewNode for Image with fn semantics(self) {
  if self.accessibility_label == "" {
    @core.ViewSemanticsInfo::hidden()
  } else {
    @core.ViewSemanticsInfo::leaf(role=Image, label=self.accessibility_label)
  }
}
