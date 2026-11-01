///|
pub fn[Msg] progress(
  value : Double,
  label~ : String = "",
  value_text? : String,
  width~ : Double = 180.0,
  height~ : Double = 8.0,
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
impl @core.ViewNode for Progress with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(
      @core.Size::new(width=self.width, height=self.height),
    ),
  )
}

///|
impl @core.ViewNode for Progress with fn paint(self, ctx) {
  let resolved_theme = ctx.effective_theme(pinned=self.theme)
  let resolved_style = match self.style {
    Some(value) => value
    None => @style.ProgressStyle::default(theme=resolved_theme)
  }
  let resolved_foreground = self.foreground.unwrap_or(resolved_style.foreground)
  let resolved_background = self.background.unwrap_or(resolved_style.background)
  let frame = ctx.frame
  let radius = @common.view_min_double(self.height / 2.0, resolved_style.radius)
  @core.ViewPaintPlan::commands([
    FillRoundedRectBrush(
      @core.RoundedRect::new(rect=frame, radius~),
      @core.Brush::solid(resolved_background),
    ),
    FillRoundedRectBrush(
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
  @core.ViewSemanticsInfo::leaf(
    role=Progress,
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
