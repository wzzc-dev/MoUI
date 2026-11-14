///|
/// Theme token helpers re-exported for app theme construction.
/// Value colors/schemes belong on domain facades: `@graphics.Color`,
/// `@state.ColorScheme` (ADR 0014 model B).
pub using @core {type ColorPalette}

///|
pub using @core {type TypographyScale}

///|
pub using @core {type LayoutScale}

///|
pub using @core {type ThemeSpec}

///|
pub using @core {type ThemePreset}

///|
/// Minimal light theme. Resolved from a `ThemeSpec` so the full palette
/// (on*/container matrix) and scales are derived consistently with the
/// resolver path used by host `ThemeChanged` events. Concrete control tokens
/// are resolved views-side as a `ControlThemeSet` (ADR 0017); this builder
/// returns the neutral `core.Theme` only.
pub fn light_theme() -> @core.Theme {
  @core.resolve_minimal_theme(@core.ThemeSpec::minimal_light(), Light)
}

///|
/// Minimal dark theme. Mirrors `light_theme` via the resolver.
pub fn dark_theme() -> @core.Theme {
  @core.resolve_minimal_theme(@core.ThemeSpec::minimal_dark(), Dark)
}

///|
/// Desktop light theme: brand accent, compact control metrics, softer radii
/// and layered elevation. This is the preset README/website screenshots are
/// judged against; `light_theme()` stays Minimal for compatibility.
pub fn desktop_light_theme() -> @core.Theme {
  @core.resolve_desktop_theme(@core.ThemeSpec::desktop_light(), Light)
}

///|
/// Desktop dark theme. Mirrors `desktop_light_theme` via the resolver.
pub fn desktop_dark_theme() -> @core.Theme {
  @core.resolve_desktop_theme(@core.ThemeSpec::desktop_dark(), Dark)
}

///|
/// Minimal theme spec for hosts that resolve through `Environment`: pass it to
/// `Environment::neutral().with_theme_spec(...)` so a system scheme change
/// rebuilds the same preset instead of falling back to the default.
pub fn minimal_theme_spec(
  scheme~ : @core.ColorScheme = Light,
) -> @core.ThemeSpec {
  match scheme {
    Light => @core.ThemeSpec::minimal_light()
    Dark => @core.ThemeSpec::minimal_dark()
  }
}

///|
/// Desktop theme spec. This is the resolver-driven counterpart of
/// `desktop_light_theme()` / `desktop_dark_theme()`: a host that stores a
/// `ThemeSpec` on the environment keeps the Desktop preset across system
/// scheme changes.
pub fn desktop_theme_spec(
  scheme~ : @core.ColorScheme = Light,
) -> @core.ThemeSpec {
  match scheme {
    Light => @core.ThemeSpec::desktop_light()
    Dark => @core.ThemeSpec::desktop_dark()
  }
}

///|
/// Resolve the theme a `ThemeSpec` describes against a system scheme. Kept as
/// a views-level entry so apps do not need to reach into `core`.
pub fn theme_from_spec(
  spec : @core.ThemeSpec,
  system_scheme~ : @core.ColorScheme = Light,
) -> @core.Theme {
  @core.resolve_theme(spec, system_scheme)
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
  scheme~ : @core.ColorScheme = Light,
  palette? : @core.ColorPalette,
  spacing_scale? : @core.SpacingScale,
  radius_scale? : @core.RadiusScale,
  layout_scale? : @core.LayoutScale,
  typography? : @core.TypographyScale,
  shadow_scale? : @core.ShadowScale,
  motion? : @core.MotionScale,
  surfaces? : @core.SurfaceScale,
) -> @core.Theme {
  let mut base_theme = match base {
    Some(value) => value
    None =>
      match scheme {
        Light => light_theme()
        Dark => dark_theme()
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
  match layout_scale {
    Some(value) => base_theme = base_theme.with_layout_scale(value)
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
