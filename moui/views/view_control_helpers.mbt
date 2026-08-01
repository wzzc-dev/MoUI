///|
/// Resolve an optional theme override against the neutral fallback. Composite
/// views use this for construction-time layout reads (spacing/shadow); their
/// leaf children receive the theme Option via `theme?=theme` so the children's
/// paint-time colors track the ambient `ctx.environment.theme` directly.
fn views_ambient_theme(theme : @core.Theme?) -> @core.Theme {
  theme.unwrap_or(@core.Theme::neutral())
}

///|
fn view_exact_channel(key : @core.DeclarationKey) -> @core.DeclarationChannel {
  @core.DeclarationChannel::Exact(key)
}

///|
fn view_declaration(
  layout? : @core.DeclarationChannel = @core.DeclarationChannel::Constant,
  paint? : @core.DeclarationChannel = @core.DeclarationChannel::Constant,
  semantics? : @core.DeclarationChannel = @core.DeclarationChannel::Constant,
  platform? : @core.DeclarationChannel = @core.DeclarationChannel::Constant,
) -> @core.ViewDeclaration {
  @core.ViewDeclaration::channels(layout~, paint~, semantics~, platform~)
}

///|
fn view_paint_declaration(key : @core.DeclarationKey) -> @core.ViewDeclaration {
  view_declaration(paint=view_exact_channel(key))
}

///|
fn[Msg] modal_scrim(alpha~ : Double) -> @core.View[Msg] {
  empty().background_brush(
    @core.Brush::solid(@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=alpha)),
  )
}
