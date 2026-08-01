///|
/// Generic, theme-aware control constructor. It wires the repetitive
/// `ViewNode` plumbing (identity, theme resolution, focusable, event
/// forwarding) so a new control only supplies its `layout`, `paint`, and
/// optional `event`/`semantics` logic. This is the recommended path for adding
/// a standard themed control: the `Style` is resolved from `ControlThemeSet`
/// once per frame and forwarded to the supplied callbacks, keeping the single
/// source-of-truth for theming.
///
/// Example: a 24×24 colored dot control.
/// ```moonbit
/// pub fn[Msg] dot(color : @core.Color, on_tap? : (Unit) -> Msg) -> @core.View[Msg] {
///   themeable_control(
///     kind="Dot",
///     style_resolver=_set => _set.choice_control.selected_color,
///     layout=(_ctx, _s) => @core.ViewLayoutResult::new(
///       size=@core.Size::new(width=24.0, height=24.0),
///     ),
///     paint=(ctx, color) => @core.ViewPaintPlan::commands([
///       @core.DrawCommand::FillCircle(ctx.frame.center(), 12.0, color),
///     ]),
///     event?=(ctx, _s) => match on_tap {
///       Some(handler) => ...
///       None => @core.ViewEventResult::ignored()
///     },
///   )
/// }
/// ```
pub fn[Msg, Style] themeable_control(
  kind : String,
  theme? : @core.Theme,
  style_resolver : (@style.ControlThemeSet) -> Style,
  layout : (@core.ViewLayoutContext, Style) -> @core.ViewLayoutResult,
  paint : (@core.ViewPaintContext, Style) -> @core.ViewPaintPlan,
  semantics? : () -> @core.ViewSemanticsInfo,
  event? : (@core.ViewEventContext, Style) -> @core.ViewEventResult[Msg],
  focusable? : Bool = true,
  key? : String? = None,
) -> @core.View[Msg] {
  let node = ThemedControl::{
    kind,
    theme,
    style_resolver,
    layout_fn: layout,
    paint_fn: paint,
    semantics_fn: semantics,
    focusable_flag: focusable,
    key,
  }
  @core.View::from_node(
    node,
    event=(_node, ctx) => {
      let resolved_theme = theme.unwrap_or(ctx.environment.theme)
      let style = style_resolver(@style.views_ambient_control_theme(resolved_theme))
      match event {
        Some(handler) => handler(ctx, style)
        None => @core.ViewEventResult::ignored()
      }
    },
  )
}

///|
priv struct ThemedControl[Style] {
  kind : String
  theme : @core.Theme?
  style_resolver : (@style.ControlThemeSet) -> Style
  layout_fn : (@core.ViewLayoutContext, Style) -> @core.ViewLayoutResult
  paint_fn : (@core.ViewPaintContext, Style) -> @core.ViewPaintPlan
  semantics_fn : (() -> @core.ViewSemanticsInfo)?
  focusable_flag : Bool
  key : String?
}

///|
impl[Style] @core.ViewNode for ThemedControl[Style] with fn identity(
  self,
) -> @core.ViewIdentity {
  @core.ViewIdentity::new(kind=self.kind, key=self.key)
}

///|
impl[Style] @core.ViewNode for ThemedControl[Style] with fn layout(
  self,
  ctx : @core.ViewLayoutContext,
) -> @core.ViewLayoutResult {
  let resolved_theme = self.theme.unwrap_or(ctx.environment.theme)
  let style = (self.style_resolver)(@style.views_ambient_control_theme(resolved_theme))
  (self.layout_fn)(ctx, style)
}

///|
impl[Style] @core.ViewNode for ThemedControl[Style] with fn paint(
  self,
  ctx : @core.ViewPaintContext,
) -> @core.ViewPaintPlan {
  let resolved_theme = self.theme.unwrap_or(ctx.environment.theme)
  let style = (self.style_resolver)(@style.views_ambient_control_theme(resolved_theme))
  (self.paint_fn)(ctx, style)
}

///|
impl[Style] @core.ViewNode for ThemedControl[Style] with fn semantics(
  self,
) -> @core.ViewSemanticsInfo {
  match self.semantics_fn {
    Some(handler) => handler()
    None => @core.ViewSemanticsInfo::new()
  }
}

///|
impl[Style] @core.ViewNode for ThemedControl[Style] with fn focusable(
  self,
) -> Bool {
  self.focusable_flag
}

///|
test "themeable_control_builds_view" {
  let view : @core.View[Unit] = themeable_control(
    "DemoDot",
    _set => _set.choice_control.selected_color,
    (_ctx, _s) => @core.ViewLayoutResult::new(
      size=@core.Size::new(width=24.0, height=24.0),
    ),
    (_ctx, _s) => @core.ViewPaintPlan::empty(),
    focusable=true,
  )
  ignore(view)
}
