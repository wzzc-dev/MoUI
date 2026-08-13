///|
pub fn[Msg] image(
  source : String,
  width? : Double,
  height? : Double,
  opacity? : Double = 1.0,
  corner_radius? : Double = 0.0,
  fit? : @core.ImageFit = @core.ImageFit::Contain,
  accessibility_label? : String = "",
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
impl @core.ViewNode for Image with fn declaration(self) {
  let fit = @core.DeclarationKey::int(
    match self.fit {
      @core.ImageFit::Contain => 0
      @core.ImageFit::Cover => 1
      @core.ImageFit::Stretch => 2
      @core.ImageFit::ScaleDown => 3
      @core.ImageFit::FitWidth => 4
      @core.ImageFit::FitHeight => 5
    },
  )
  @common.view_declaration(
    layout=@common.view_exact_channel(@common.view_size_option_key(self.size)),
    paint=@common.view_exact_channel(
      @common.view_record_key("Image.paint", [
        ("source", @core.DeclarationKey::string(self.source)),
        ("size", @common.view_size_option_key(self.size)),
        ("opacity", @core.DeclarationKey::double(self.opacity)),
        ("corner_radius", @core.DeclarationKey::double(self.corner_radius)),
        ("fit", fit),
      ]),
    ),
    semantics=@common.view_exact_channel(
      @core.DeclarationKey::string(self.accessibility_label),
    ),
  )
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

///|
impl @core.ViewNode for Image with fn semantics(self) {
  if self.accessibility_label == "" {
    @core.ViewSemanticsInfo::new(composition=@core.SemanticsComposition::Hidden)
  } else {
    @core.ViewSemanticsInfo::new(
      composition=@core.SemanticsComposition::Boundary,
      role=@core.SemanticsRole::Image,
      label=self.accessibility_label,
    )
  }
}
