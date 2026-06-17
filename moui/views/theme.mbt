///|
pub using @core {type Color}

///|
pub using @core {type ColorScheme}

///|
pub fn light_theme() -> @core.Theme {
  let palette = @core.ColorPalette::light()
  let semantic_colors = @core.SemanticColorScale::default(
    palette,
    @core.ColorScheme::Light,
  )
  let spacing_scale = @core.SpacingScale::default()
  let radius_scale = @core.RadiusScale::default()
  let typography = @core.TypographyScale::default()
  let shadow_scale = @core.ShadowScale::default(scheme=@core.ColorScheme::Light)
  let motion = @core.MotionScale::default()
  let surfaces = @core.SurfaceScale::default(palette, @core.ColorScheme::Light)
  {
    scheme: @core.ColorScheme::Light,
    palette,
    semantic_colors,
    spacing_scale,
    radius_scale,
    typography,
    shadow_scale,
    motion,
    surfaces,
    font: typography.body,
    foreground: palette.foreground,
    background: palette.background,
    accent: palette.primary,
    spacing: spacing_scale.sm,
    corner_radius: radius_scale.md,
  }
}

///|
pub fn dark_theme() -> @core.Theme {
  let palette = @core.ColorPalette::dark()
  let semantic_colors = @core.SemanticColorScale::default(
    palette,
    @core.ColorScheme::Dark,
  )
  let spacing_scale = @core.SpacingScale::default()
  let radius_scale = @core.RadiusScale::default()
  let typography = @core.TypographyScale::default()
  let shadow_scale = @core.ShadowScale::default(scheme=@core.ColorScheme::Dark)
  let motion = @core.MotionScale::default()
  let surfaces = @core.SurfaceScale::default(palette, @core.ColorScheme::Dark)
  {
    scheme: @core.ColorScheme::Dark,
    palette,
    semantic_colors,
    spacing_scale,
    radius_scale,
    typography,
    shadow_scale,
    motion,
    surfaces,
    font: typography.body,
    foreground: palette.foreground,
    background: palette.background,
    accent: palette.primary,
    spacing: spacing_scale.sm,
    corner_radius: radius_scale.md,
  }
}

///|
pub fn default_theme() -> @core.Theme {
  light_theme()
}

///|
pub fn theme(
  base? : @core.Theme,
  font? : @core.FontSpec,
  foreground? : @core.Color,
  background? : @core.Color,
  accent? : @core.Color,
  spacing? : Double,
  corner_radius? : Double,
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
  palette? : @core.ColorPalette,
  semantic_colors? : @core.SemanticColorScale,
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
  match semantic_colors {
    Some(value) => base_theme = base_theme.with_semantic_colors(value)
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
  match font {
    Some(value) => base_theme = base_theme.with_font(value)
    None => ()
  }
  match foreground {
    Some(value) => base_theme = base_theme.with_foreground(value)
    None => ()
  }
  match background {
    Some(value) => base_theme = base_theme.with_background(value)
    None => ()
  }
  match accent {
    Some(value) => base_theme = base_theme.with_accent(value)
    None => ()
  }
  match spacing {
    Some(value) => base_theme = base_theme.with_spacing(value)
    None => ()
  }
  match corner_radius {
    Some(value) => base_theme = base_theme.with_corner_radius(value)
    None => ()
  }
  base_theme
}

///|
pub fn environment(theme? : @core.Theme = default_theme()) -> @core.Environment {
  @core.Environment::neutral().with_theme(theme)
}
