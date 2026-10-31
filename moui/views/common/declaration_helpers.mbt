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
/// Memoized pinned-theme keys: apps hold a handful of distinct theme values,
/// so the assoc-list scan (structural Eq over at most `pinned_theme_key_cache_limit`
/// entries) is far cheaper than re-encoding the theme on every view build. The
/// cache clears when it exceeds the bound; correctness never depends on it (a
/// miss just re-encodes).
let pinned_theme_key_cache : Array[(@core.Theme, @core.DeclarationKey)] = []

///|
let pinned_theme_key_cache_limit : Int32 = 32

///|
/// Canonical declaration key for a pinned theme value. The key encodes the
/// theme's complete value (via its `ToJson` form), so any change to the pinned
/// theme produces a different key and invalidates exactly the pinned subtrees.
pub fn views_pinned_theme_key(theme : @core.Theme) -> @core.DeclarationKey {
  for entry in pinned_theme_key_cache {
    if entry.0 == theme {
      return entry.1
    }
  }
  let key = @core.DeclarationKey::string("Theme:" + theme.to_json().stringify())
  pinned_theme_key_cache.push((theme, key))
  if pinned_theme_key_cache.length() > pinned_theme_key_cache_limit {
    pinned_theme_key_cache.clear()
  }
  key
}

///|
/// Declaration channel for a theme-dependent pass. Without a pinned theme the
/// channel is exact on the pass's own record key (ambient theme changes reach
/// the control through the environment's global invalidation, not through the
/// declaration). With a pinned theme the resolved theme value is folded into
/// the key, so the channel stays `Exact` instead of degrading to
/// `Uncacheable` on every reconciliation.
pub fn views_theme_channel(
  base_key : @core.DeclarationKey,
  theme : @core.Theme?,
) -> @core.DeclarationChannel {
  match theme {
    Some(pinned) =>
      Exact(
        view_record_key("theme-pinned", [
          ("base", base_key),
          ("theme", views_pinned_theme_key(pinned)),
        ]),
      )
    None => Exact(base_key)
  }
}

///|
/// Build a `ViewDeclaration` from per-channel field lists, eliminating the
/// repetitive record-key + channel boilerplate every control repeats by hand.
///
/// Theme-dependent channels are `Exact`: a pinned theme override is folded
/// into the channel key via `views_theme_channel` instead of degrading the
/// channel to `Uncacheable`. `semantics` is always `Exact`. Use
/// `layout_theme_dependent=false` for controls whose layout does not depend on
/// the theme (e.g. the slider, which sizes from width/height only) to keep
/// their key independent of the theme entirely.
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
    layout=if layout_theme_dependent {
      views_theme_channel(layout_key, theme_override)
    } else {
      view_exact_channel(layout_key)
    },
    paint=if paint_theme_dependent {
      views_theme_channel(paint_key, theme_override)
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
