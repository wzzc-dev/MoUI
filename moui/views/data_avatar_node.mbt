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
impl @core.ViewNode for AvatarImage with fn declaration(self) {
  view_declaration(
    layout=view_exact_channel(@core.DeclarationKey::double(self.size)),
    paint=view_exact_channel(
      view_record_key("AvatarImage.paint", [
        ("source", @core.DeclarationKey::string(self.source)),
        ("size", @core.DeclarationKey::double(self.size)),
      ]),
    ),
  )
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

///|
impl @core.ViewNode for AvatarImage with fn semantics(_self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Transparent,
  )
}
