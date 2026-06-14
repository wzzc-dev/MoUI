///|
pub type View[Msg] = @core.View[Msg]

///|
pub type Program[Model, Msg] = @core.Program[Model, Msg]

///|
pub type Effect[Msg] = @core.Effect[Msg]

///|
pub type Subscription[Msg] = @core.Subscription[Msg]

///|
pub type Theme = @core.Theme

///|
pub fn default_theme() -> Theme {
  @core.Theme::default()
}

///|
pub fn light_theme() -> Theme {
  @core.Theme::light()
}

///|
pub fn dark_theme() -> Theme {
  @core.Theme::dark()
}

///|
pub fn theme(
  base? : Theme,
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
) -> Theme {
  let mut base_theme = match base {
    Some(value) => value
    None =>
      match scheme {
        @core.ColorScheme::Light => @core.Theme::light()
        @core.ColorScheme::Dark => @core.Theme::dark()
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
