///|
/// Shared view declaration helpers. These compose `@core.DeclarationKey` values
/// for incremental cache invalidation without depending on any views internals.

///|
pub fn exact_channel(key : @core.DeclarationKey) -> @core.DeclarationChannel {
  Exact(key)
}

///|
pub fn view_declaration(
  layout~ : @core.DeclarationChannel = Constant,
  paint~ : @core.DeclarationChannel = Constant,
  semantics~ : @core.DeclarationChannel = Constant,
  platform~ : @core.DeclarationChannel = Constant,
) -> @core.ViewDeclaration {
  @core.ViewDeclaration::channels(layout~, paint~, semantics~, platform~)
}

///|
/// Build a `ViewDeclaration` from per-channel field lists, eliminating the
/// repetitive record-key + channel boilerplate every control repeats by hand.
///
/// A theme override (`theme?` passed to the control) makes the affected
/// channels `Uncacheable` (the resolved theme is not part of the cache key),
/// otherwise an `Exact` channel is built from the record key. `semantics` is
/// always `Exact`. Use `layout_theme_dependent=false` for controls whose layout
/// does not depend on the theme (e.g. the slider, which sizes from width/height
/// only) to preserve their prior cache behavior.
pub fn view_declaration_auto(
  kind : String,
  theme_override : @core.Theme?,
  layout_fields : Array[(String, @core.DeclarationKey)],
  paint_fields : Array[(String, @core.DeclarationKey)],
  semantics_fields : Array[(String, @core.DeclarationKey)],
  layout_theme_dependent~ : Bool = true,
  paint_theme_dependent~ : Bool = true,
) -> @core.ViewDeclaration {
  let layout_key = view_record_key(kind + ".layout", layout_fields)
  let paint_key = view_record_key(kind + ".paint", paint_fields)
  let semantics_key = view_record_key(kind + ".semantics", semantics_fields)
  view_declaration(
    layout=if layout_theme_dependent && theme_override is Some(_) {
      Uncacheable
    } else {
      view_exact_channel(layout_key)
    },
    paint=if paint_theme_dependent && theme_override is Some(_) {
      Uncacheable
    } else {
      view_exact_channel(paint_key)
    },
    semantics=view_exact_channel(semantics_key),
  )
}

///|
pub fn view_constant_declaration() -> @core.ViewDeclaration {
  @core.ViewDeclaration::constant()
}

///|
pub fn view_uncacheable_declaration() -> @core.ViewDeclaration {
  @core.ViewDeclaration::uncacheable()
}

///|
pub fn view_layout_declaration(
  key : @core.DeclarationKey,
) -> @core.ViewDeclaration {
  view_declaration(layout=exact_channel(key))
}

///|
pub fn view_paint_declaration(
  key : @core.DeclarationKey,
) -> @core.ViewDeclaration {
  view_declaration(paint=exact_channel(key))
}

///|
pub fn view_semantics_declaration(
  key : @core.DeclarationKey,
) -> @core.ViewDeclaration {
  view_declaration(semantics=exact_channel(key))
}

///|
pub fn view_record_key(
  tag : String,
  fields : Array[(String, @core.DeclarationKey)],
) -> @core.DeclarationKey {
  @core.DeclarationKey::record(type_tag=tag, fields~)
}

///|
pub fn view_size_key(size : @core.Size) -> @core.DeclarationKey {
  view_record_key("Size", [
    ("width", @core.DeclarationKey::double(size.width)),
    ("height", @core.DeclarationKey::double(size.height)),
  ])
}

///|
pub fn view_color_key(color : @core.Color) -> @core.DeclarationKey {
  @core.DeclarationKey::record(type_tag="Color", fields=[
    ("r", @core.DeclarationKey::double(color.r)),
    ("g", @core.DeclarationKey::double(color.g)),
    ("b", @core.DeclarationKey::double(color.b)),
    ("a", @core.DeclarationKey::double(color.a)),
  ])
}

///|
/// Resolve an optional theme override against the neutral fallback.
pub fn views_ambient_theme(theme : @core.Theme?) -> @core.Theme {
  theme.unwrap_or(@core.Theme::neutral())
}
