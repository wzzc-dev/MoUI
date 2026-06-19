///|
pub(all) enum DesignPreset {
  Material
  Carbon
  Primer
  Fluent
} derive(Eq, Debug, ToJson)

///|
pub fn DesignPreset::label(self : DesignPreset) -> String {
  match self {
    Material => "Material"
    Carbon => "Carbon"
    Primer => "Primer"
    Fluent => "Fluent"
  }
}

///|
pub fn DesignPreset::summary(self : DesignPreset) -> String {
  match self {
    Material =>
      "Bold color, rounded controls, and generous motion-friendly spacing."
    Carbon => "Dense, rational enterprise tokens for data-heavy tools."
    Primer => "Developer-tool tokens with quiet contrast and compact surfaces."
    Fluent => "Soft desktop tokens with layered surfaces and gentle depth."
  }
}

///|
pub fn preset(
  preset : DesignPreset,
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
) -> @core.Theme {
  preset.theme(scheme~)
}

///|
pub fn preset_for_variant(
  preset : DesignPreset,
  variant? : DesignSchemeVariant = DesignSchemeVariant::SchemeLight,
  system_scheme? : @core.ColorScheme = @core.ColorScheme::Light,
  density? : DesignDensity = DesignDensity::Standard,
) -> @core.Theme {
  preset.theme_for_variant(variant~, system_scheme~, density~)
}

///|
pub fn DesignPreset::theme(
  self : DesignPreset,
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
  density? : DesignDensity = DesignDensity::Standard,
) -> @core.Theme {
  self.tokens(scheme~, density~).to_theme()
}

///|
pub fn DesignPreset::theme_for_variant(
  self : DesignPreset,
  variant? : DesignSchemeVariant = DesignSchemeVariant::SchemeLight,
  system_scheme? : @core.ColorScheme = @core.ColorScheme::Light,
  density? : DesignDensity = DesignDensity::Standard,
) -> @core.Theme {
  self.tokens_for_variant(variant~, system_scheme~, density~).to_theme()
}

///|
pub fn custom(
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
  base? : @core.Theme,
  palette? : @core.ColorPalette,
  semantic_colors? : @core.SemanticColorScale,
  spacing_scale? : @core.SpacingScale,
  radius_scale? : @core.RadiusScale,
  typography? : @core.TypographyScale,
  shadow_scale? : @core.ShadowScale,
  motion? : @core.MotionScale,
  surfaces? : @core.SurfaceScale,
) -> @core.Theme {
  let mut theme = match base {
    Some(value) => value
    None =>
      match scheme {
        @core.ColorScheme::Light => @views.light_theme()
        @core.ColorScheme::Dark => @views.dark_theme()
      }
  }
  match palette {
    Some(value) => theme = theme.with_palette(value)
    None => ()
  }
  match semantic_colors {
    Some(value) => theme = theme.with_semantic_colors(value)
    None => ()
  }
  match spacing_scale {
    Some(value) => theme = theme.with_spacing_scale(value)
    None => ()
  }
  match radius_scale {
    Some(value) => theme = theme.with_radius_scale(value)
    None => ()
  }
  match typography {
    Some(value) => theme = theme.with_typography(value)
    None => ()
  }
  match shadow_scale {
    Some(value) => theme = theme.with_shadow_scale(value)
    None => ()
  }
  match motion {
    Some(value) => theme = theme.with_motion(value)
    None => ()
  }
  match surfaces {
    Some(value) => theme = theme.with_surfaces(value)
    None => ()
  }
  theme
}

///|
fn palette(
  foreground~ : @core.Color,
  background~ : @core.Color,
  surface~ : @core.Color,
  surface_variant~ : @core.Color,
  primary~ : @core.Color,
  primary_foreground~ : @core.Color,
  outline~ : @core.Color,
  muted~ : @core.Color,
) -> @core.ColorPalette {
  {
    foreground,
    background,
    surface,
    surface_variant,
    primary,
    primary_foreground,
    outline,
    muted,
  }
}

///|
fn shadow_scale(
  scheme : @core.ColorScheme,
  lift~ : Double,
) -> @core.ShadowScale {
  let base_alpha = match scheme {
    @core.ColorScheme::Light => 0.16
    @core.ColorScheme::Dark => 0.34
  }
  {
    sm: shadow(alpha=base_alpha * 0.55 * lift, y=1.0, blur=5.0),
    md: shadow(alpha=base_alpha * lift, y=4.0, blur=14.0),
    lg: shadow(alpha=base_alpha * 1.28 * lift, y=10.0, blur=26.0, spread=2.0),
  }
}

///|
fn shadow(
  alpha~ : Double,
  y~ : Double,
  blur~ : Double,
  spread? : Double = 0.0,
) -> @core.ShadowStyle {
  @core.ShadowStyle::new(
    color=color(r=0.0, g=0.0, b=0.0, a=alpha),
    offset=@core.Point::new(x=0.0, y~),
    blur_radius=blur,
    spread~,
  )
}

///|
fn color(
  r~ : Double,
  g~ : Double,
  b~ : Double,
  a? : Double = 1.0,
) -> @core.Color {
  @core.Color::rgba(r~, g~, b~, a~)
}

///|
fn color_byte(r~ : Int, g~ : Int, b~ : Int, a? : Double = 1.0) -> @core.Color {
  color(
    r=r.to_double() / 255.0,
    g=g.to_double() / 255.0,
    b=b.to_double() / 255.0,
    a~,
  )
}
