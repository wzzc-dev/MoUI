///|
/// Theme token helpers re-exported for app theme construction.
/// Value colors/schemes belong on domain facades: `@graphics.Color`,
/// `@state.ColorScheme` (ADR 0014 model B).
pub using @core {type ColorPalette}

///|
pub using @core {type TypographyScale}

///|
/// Minimal light theme. Resolved from a `ThemeSpec` so the full palette
/// (on*/container matrix) and scales are derived consistently with the
/// resolver path used by host `ThemeChanged` events. Concrete control tokens
/// are resolved views-side as a `ControlThemeSet` (ADR 0017); this builder
/// returns the neutral `core.Theme` only.
pub fn light_theme() -> @core.Theme {
  @core.resolve_minimal_theme(
    @core.ThemeSpec::minimal_light(),
    @core.ColorScheme::Light,
  )
}

///|
/// Minimal dark theme. Mirrors `light_theme` via the resolver.
pub fn dark_theme() -> @core.Theme {
  @core.resolve_minimal_theme(
    @core.ThemeSpec::minimal_dark(),
    @core.ColorScheme::Dark,
  )
}

///|
pub fn default_theme() -> @core.Theme {
  light_theme()
}

///|
/// Compose a neutral theme by overriding individual token groups over an
/// optional base. Semantic colors live on `ColorPalette`
/// (success/danger/info/...), so override them via `palette?`. Concrete
/// control tokens are not accepted here: `core.Theme` no longer carries a
/// `components` field (ADR 0017). Apps that want a branded control theme set
/// a `ControlThemeSet` via the ambient resolver; this builder composes the
/// neutral base only.
pub fn theme(
  base? : @core.Theme,
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
  palette? : @core.ColorPalette,
  spacing_scale? : @core.SpacingScale,
  radius_scale? : @core.RadiusScale,
  typography? : @core.TypographyScale,
  shadow_scale? : @core.ShadowScale,
  motion? : @core.MotionScale,
  surfaces? : @core.SurfaceScale,
) -> @core.Theme {
  let mut base_theme = match base {
    Some(value) => value
    None =>
      match scheme {
        @core.ColorScheme::Light => light_theme()
        @core.ColorScheme::Dark => dark_theme()
      }
  }
  match palette {
    Some(value) => base_theme = base_theme.with_palette(value)
    None => ()
  }
  match spacing_scale {
    Some(value) => base_theme = base_theme.with_spacing_scale(value)
    None => ()
  }
  match radius_scale {
    Some(value) => base_theme = base_theme.with_radius_scale(value)
    None => ()
  }
  match typography {
    Some(value) => base_theme = base_theme.with_typography(value)
    None => ()
  }
  match shadow_scale {
    Some(value) => base_theme = base_theme.with_shadow_scale(value)
    None => ()
  }
  match motion {
    Some(value) => base_theme = base_theme.with_motion(value)
    None => ()
  }
  match surfaces {
    Some(value) => base_theme = base_theme.with_surfaces(value)
    None => ()
  }
  base_theme
}

///|
pub fn environment(theme? : @core.Theme) -> @core.Environment {
  let resolved_theme = @common.views_ambient_theme(theme)
  @core.Environment::neutral().with_theme(resolved_theme)
}
