///|
pub fn theme(
  font? : @core.FontSpec,
  foreground? : @core.Color,
  background? : @core.Color,
  accent? : @core.Color,
  spacing? : Double,
  corner_radius? : Double,
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
  palette? : @core.ColorPalette,
  spacing_scale? : @core.SpacingScale,
  radius_scale? : @core.RadiusScale,
  typography? : @core.TypographyScale,
) -> @core.Theme {
  let mut base = match scheme {
    @core.ColorScheme::Light => @core.Theme::light()
    @core.ColorScheme::Dark => @core.Theme::dark()
  }
  match palette {
    Some(value) => base = base.with_palette(value)
    None => ()
  }
  match spacing_scale {
    Some(value) => base = base.with_spacing_scale(value)
    None => ()
  }
  match radius_scale {
    Some(value) => base = base.with_radius_scale(value)
    None => ()
  }
  match typography {
    Some(value) => base = base.with_typography(value)
    None => ()
  }
  match font {
    Some(value) => base = base.with_font(value)
    None => ()
  }
  match foreground {
    Some(value) => base = base.with_foreground(value)
    None => ()
  }
  match background {
    Some(value) => base = base.with_background(value)
    None => ()
  }
  match accent {
    Some(value) => base = base.with_accent(value)
    None => ()
  }
  match spacing {
    Some(value) => base = base.with_spacing(value)
    None => ()
  }
  match corner_radius {
    Some(value) => base = base.with_corner_radius(value)
    None => ()
  }
  base
}

///|
pub fn environment(
  theme? : @core.Theme = @core.Theme::default(),
) -> @core.Environment {
  @core.Environment::default().with_theme(theme)
}

///|
pub fn light_theme() -> @core.Theme {
  @core.Theme::light()
}

///|
pub fn dark_theme() -> @core.Theme {
  @core.Theme::dark()
}
