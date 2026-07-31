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
fn view_record_key(
  type_tag : String,
  fields : Array[(String, @core.DeclarationKey)],
) -> @core.DeclarationKey {
  @core.DeclarationKey::record(type_tag~, fields~)
}

///|
fn view_color_key(color : @core.Color) -> @core.DeclarationKey {
  view_record_key("Color", [
    ("r", @core.DeclarationKey::double(color.r)),
    ("g", @core.DeclarationKey::double(color.g)),
    ("b", @core.DeclarationKey::double(color.b)),
    ("a", @core.DeclarationKey::double(color.a)),
  ])
}

///|
fn view_semantics_role_key(role : @core.SemanticsRole) -> @core.DeclarationKey {
  @core.DeclarationKey::int(
    match role {
      @core.SemanticsRole::None => 0
      @core.SemanticsRole::Text => 1
      @core.SemanticsRole::Link => 2
      @core.SemanticsRole::Heading => 3
      @core.SemanticsRole::Navigation => 4
      @core.SemanticsRole::Main => 5
      @core.SemanticsRole::Button => 6
      @core.SemanticsRole::Checkbox => 7
      @core.SemanticsRole::TextField => 8
      @core.SemanticsRole::List => 9
      @core.SemanticsRole::ListItem => 10
      @core.SemanticsRole::Grid => 11
      @core.SemanticsRole::ScrollView => 12
      @core.SemanticsRole::Switch => 13
      @core.SemanticsRole::Radio => 14
      @core.SemanticsRole::Slider => 15
      @core.SemanticsRole::Progress => 16
      @core.SemanticsRole::Tab => 17
      @core.SemanticsRole::Dialog => 18
      @core.SemanticsRole::Tooltip => 19
      @core.SemanticsRole::Menu => 20
      @core.SemanticsRole::ButtonGroup => 21
      @core.SemanticsRole::Form => 22
      @core.SemanticsRole::FormField => 23
      @core.SemanticsRole::Tree => 24
      @core.SemanticsRole::TreeItem => 25
      @core.SemanticsRole::Group => 26
      @core.SemanticsRole::WebView => 27
    },
  )
}

///|
fn view_min_double(left : Double, right : Double) -> Double {
  if left <= right {
    left
  } else {
    right
  }
}

///|
fn[Msg] modal_scrim(alpha~ : Double) -> @core.View[Msg] {
  empty().background_brush(
    @core.Brush::solid(@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=alpha)),
  )
}
