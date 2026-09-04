///|
pub fn[Msg] progress(
  value : Double,
  label? : String = "",
  value_text? : String,
  width? : Double = 180.0,
  height? : Double = 8.0,
  theme? : @core.Theme,
  style? : @style.ProgressStyle,
  foreground? : @core.Color,
  background? : @core.Color,
) -> @core.View[Msg] {
  let value = @common.clamp_view_double(value, 0.0, 1.0)
  @core.View::from_node(Progress::{
    value,
    label,
    value_text,
    width,
    height,
    theme,
    style,
    foreground,
    background,
  })
}

///|
/// Immutable declaration and rendering state for `progress`.
priv struct Progress {
  value : Double
  label : String
  value_text : String?
  width : Double
  height : Double
  theme : @core.Theme?
  style : @style.ProgressStyle?
  foreground : @core.Color?
  background : @core.Color?
}

///|
impl @core.ViewNode for Progress with fn identity(_self) {
  @core.ViewIdentity::new(kind="Progress")
}

///|
impl @core.ViewNode for Progress with fn declaration(self) {
  let paint_key = @common.view_record_key("Progress.paint", [
    ("value", @core.DeclarationKey::double(self.value)),
    (
      "style",
      @core.DeclarationKey::option(
        self.style.map(style => {
          @common.view_record_key("ProgressStyle", [
            ("foreground", @common.view_color_key(style.foreground)),
            ("background", @common.view_color_key(style.background)),
            ("radius", @core.DeclarationKey::double(style.radius)),
          ])
        }),
      ),
    ),
    (
      "foreground",
      @core.DeclarationKey::option(self.foreground.map(@common.view_color_key)),
    ),
    (
      "background",
      @core.DeclarationKey::option(self.background.map(@common.view_color_key)),
    ),
  ])
  @common.view_declaration(
    layout=@common.view_exact_channel(
      @common.view_record_key("Progress.layout", [
        ("width", @core.DeclarationKey::double(self.width)),
        ("height", @core.DeclarationKey::double(self.height)),
      ]),
    ),
    paint=if self.theme is Some(_) {
      @core.DeclarationChannel::Uncacheable
    } else {
      @common.view_exact_channel(paint_key)
    },
    semantics=@common.view_exact_channel(
      @common.view_record_key("Progress.semantics", [
        ("value", @core.DeclarationKey::double(self.value)),
        ("label", @core.DeclarationKey::string(self.label)),
        (
          "value_text",
          @core.DeclarationKey::option(
            self.value_text.map(@core.DeclarationKey::string),
          ),
        ),
      ]),
    ),
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
    None => @style.ProgressStyle::default(theme=resolved_theme)
  }
  let resolved_foreground = @common.resolve_control_color(
    self.foreground,
    resolved_style.foreground,
  )
  let resolved_background = @common.resolve_control_color(
    self.background,
    resolved_style.background,
  )
  let frame = ctx.frame
  let radius = @common.min_view_double(self.height / 2.0, resolved_style.radius)
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
    label=self.label,
    value="\{self.value}",
    numeric=@core.SemanticsNumericValue::new(
      current=self.value,
      min=0.0,
      max=1.0,
      value_text?=self.value_text,
    ),
  )
}
