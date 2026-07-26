///|
priv struct AvatarImage {
  source : String
  size : Double
}

///|
impl @core.ViewNode for AvatarImage with fn identity(_self) {
  @core.ViewIdentity::new(kind="Image")
}

///|
impl @core.ViewNode for AvatarImage with fn revision(self) {
  "avatar-image:\{self.source}:\{self.size}"
}

///|
impl @core.ViewNode for AvatarImage with fn layout(self, context) {
  @core.ViewLayoutResult::new(
    size=context.constraints.constrain(
      @core.Size::new(width=self.size, height=self.size),
    ),
  )
}

///|
impl @core.ViewNode for AvatarImage with fn paint(self, context) {
  @core.ViewPaintPlan::commands([
    @core.DrawCommand::DrawImage({
      source: self.source,
      frame: context.frame,
      opacity: 1.0,
      fit: @core.ImageFit::Contain,
    }),
  ])
}
