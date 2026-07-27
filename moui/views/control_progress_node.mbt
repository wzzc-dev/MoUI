///|
/// Immutable declaration and rendering state for `progress`.
priv struct Progress {
  value : Double
  width : Double
  height : Double
  theme : @core.Theme?
  style : ProgressStyle?
  foreground : @core.Color?
  background : @core.Color?
}

///|
impl @core.ViewNode for Progress with fn identity(_self) {
  @core.ViewIdentity::new(kind="Progress")
}

///|
impl @core.ViewNode for Progress with fn declaration(self) {
  let paint_key = view_record_key("Progress.paint", [
    ("value", @core.DeclarationKey::double(self.value)),
    (
      "style",
      @core.DeclarationKey::option(
        self.style.map(style => {
          view_record_key("ProgressStyle", [
            ("foreground", view_color_key(style.foreground)),
            ("background", view_color_key(style.background)),
            ("radius", @core.DeclarationKey::double(style.radius)),
          ])
        }),
      ),
    ),
    (
      "foreground",
      @core.DeclarationKey::option(self.foreground.map(view_color_key)),
    ),
    (
      "background",
      @core.DeclarationKey::option(self.background.map(view_color_key)),
    ),
  ])
  view_declaration(
    layout=view_exact_channel(
      view_record_key("Progress.layout", [
        ("width", @core.DeclarationKey::double(self.width)),
        ("height", @core.DeclarationKey::double(self.height)),
      ]),
    ),
    paint=if self.theme is Some(_) {
      @core.DeclarationChannel::Uncacheable
    } else {
      view_exact_channel(paint_key)
    },
    semantics=view_exact_channel(@core.DeclarationKey::double(self.value)),
  )
}

///|
impl @core.ViewNode for Progress with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(
      @core.Size::new(width=self.width, height=self.height),
    ),
  )
}

///|
impl @core.ViewNode for Progress with fn paint(self, ctx) {
  let resolved_theme = self.theme.unwrap_or(ctx.environment.theme)
  let resolved_style = match self.style {
    Some(value) => value
    None => ProgressStyle::default(theme=resolved_theme)
  }
  let resolved_foreground = resolve_control_color(
    self.foreground,
    resolved_style.foreground,
  )
  let resolved_background = resolve_control_color(
    self.background,
    resolved_style.background,
  )
  let frame = ctx.frame
  let radius = min_view_double(self.height / 2.0, resolved_style.radius)
  @core.ViewPaintPlan::commands([
    @core.DrawCommand::FillRoundedRectBrush(
      @core.RoundedRect::new(rect=frame, radius~),
      @core.Brush::solid(resolved_background),
    ),
    @core.DrawCommand::FillRoundedRectBrush(
      @core.RoundedRect::new(
        rect=@core.Rect::new(
          x=frame.origin.x,
          y=frame.origin.y,
          width=frame.size.width * self.value,
          height=frame.size.height,
        ),
        radius~,
      ),
      @core.Brush::solid(resolved_foreground),
    ),
  ])
}

///|
impl @core.ViewNode for Progress with fn semantics(self) {
  @core.ViewSemanticsInfo::new(
    composition=@core.SemanticsComposition::Boundary,
    role=@core.SemanticsRole::Progress,
    label="Progress",
    value="\{self.value}",
  )
}
