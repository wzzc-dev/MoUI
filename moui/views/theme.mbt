///|
pub using @core {type Color}

///|
pub using @core {type ColorScheme}

///|
/// Minimal light theme. Resolved from a `ThemeSpec` so the full palette
/// (on*/container matrix), scales, and default `ComponentThemes` are derived
/// consistently with the resolver path used by host `ThemeChanged` events.
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
/// Compose a theme by overriding individual token groups over an optional
/// base. Semantic colors are no longer a separate group: they live on
/// `ColorPalette` (success/danger/info/...), so override them via `palette?`.
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
  components? : @core.ComponentThemes,
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
  match components {
    Some(value) => base_theme = base_theme.with_components(value)
    None => ()
  }
  base_theme
}

///|
pub fn environment(theme? : @core.Theme = default_theme()) -> @core.Environment {
  @core.Environment::neutral().with_theme(theme)
}
