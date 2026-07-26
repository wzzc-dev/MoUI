///|
/// Concrete view node for the `progress` control.
///
/// Carries only immutable declaration data: the resolved value, geometry,
/// theme, optional style, and optional foreground/background overrides. The
/// node message-independent; `View::from_node` is what wires it into a typed
/// `View[Msg]`. The `revision` deliberately captures *every* field that can
/// change paint output (value, geometry, theme, style, colors) so the runtime
/// reconcile path correctly detects "value-only" changes and does not reuse a
/// stale `RenderNode` for a control whose colors changed but `value` did not.
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
impl @core.ViewNode for Progress with fn revision(self) {
  // The previous revision only captured value/width/height/theme; style,
  // foreground, and background overrides were painted from closures but did
  // not flow into the revision. That meant the runtime could judge the node
  // clean and reuse a stale RenderNode when only the colors changed. Fold
  // every paint-affecting field into the revision so reconcile is honest.
  let style_token = match self.style {
    Some(style) => "\{round4(style.foreground.r)},\{round4(style.foreground.g)},\{round4(style.foreground.b)},\{round4(style.foreground.a)}:\{round4(style.background.r)},\{round4(style.background.g)},\{round4(style.background.b)},\{round4(style.background.a)}:\{style.radius}"
    None => "default"
  }
  let foreground_token = match self.foreground {
    Some(color) => "\{round4(color.r)},\{round4(color.g)},\{round4(color.b)},\{round4(color.a)}"
    None => "auto"
  }
  let background_token = match self.background {
    Some(color) => "\{round4(color.r)},\{round4(color.g)},\{round4(color.b)},\{round4(color.a)}"
    None => "auto"
  }
  let theme_token = match self.theme {
    Some(theme) => theme.revision_fingerprint()
    None => "context"
  }
  "progress:\{self.value}:\{self.width}:\{self.height}:\{theme_token}:\{style_token}:\{foreground_token}:\{background_token}"
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
  // Resolve the progress style ambient-ly so the bar tracks dark-mode /
  // palette changes without the caller rebuilding the view tree.
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
    role=@core.SemanticsRole::Progress,
    label="Progress",
    value="\{self.value}",
  )
}

///|
pub fn[Msg] progress(
  value : Double,
  width? : Double = 180.0,
  height? : Double = 8.0,
  theme? : @core.Theme,
  style? : ProgressStyle,
  foreground? : @core.Color,
  background? : @core.Color,
) -> @core.View[Msg] {
  let value = clamp_view_double(value, 0.0, 1.0)
  @core.View::from_node(
    Progress::{
      value,
      width,
      height,
      theme,
      style,
      foreground,
      background,
    },
  )
}
