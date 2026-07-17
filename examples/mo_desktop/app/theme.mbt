///|
priv struct DesktopPalette {
  dark : Bool
  foreground : @graphics.Color
  muted : @graphics.Color
  glass : @graphics.Color
  glass_strong : @graphics.Color
  content : @graphics.Color
  sidebar : @graphics.Color
  outline : @graphics.Color
  shadow : @graphics.Color
  accent : @graphics.Color
  accent_soft : @graphics.Color
  dock : @graphics.Color
  scrim : @graphics.Color
}

///|
fn rgba8(r : Int, g : Int, b : Int, a? : Double = 1.0) -> @graphics.Color {
  @graphics.Color::rgba(
    r=r.to_double() / 255.0,
    g=g.to_double() / 255.0,
    b=b.to_double() / 255.0,
    a~,
  )
}

///|
fn desktop_palette(dark : Bool) -> DesktopPalette {
  if dark {
    {
      dark: true,
      foreground: rgba8(241, 245, 249),
      muted: rgba8(174, 184, 197),
      glass: rgba8(26, 32, 43, a=0.82),
      glass_strong: rgba8(24, 29, 38, a=0.95),
      content: rgba8(38, 43, 54, a=0.97),
      sidebar: rgba8(27, 32, 42, a=0.97),
      outline: rgba8(255, 255, 255, a=0.13),
      shadow: rgba8(0, 0, 0, a=0.48),
      accent: rgba8(57, 151, 255),
      accent_soft: rgba8(42, 91, 142, a=0.72),
      // Lighter, more translucent dock glass so wallpaper shows through like macOS.
      dock: rgba8(30, 36, 46, a=0.52),
      scrim: rgba8(4, 10, 18, a=0.28),
    }
  } else {
    {
      dark: false,
      foreground: rgba8(28, 34, 42),
      muted: rgba8(100, 109, 120),
      glass: rgba8(245, 248, 252, a=0.82),
      // App windows own readable, opaque surfaces; otherwise bright wallpaper
      // features show through as distracting lines in the Finder content.
      glass_strong: rgba8(249, 250, 252),
      content: rgba8(252, 253, 255),
      sidebar: rgba8(238, 241, 246),
      outline: rgba8(255, 255, 255, a=0.62),
      shadow: rgba8(18, 31, 48, a=0.30),
      accent: rgba8(22, 130, 246),
      accent_soft: rgba8(180, 216, 255, a=0.92),
      // Frosted dock plate: pale and translucent rather than chalky opaque.
      dock: rgba8(255, 255, 255, a=0.42),
      scrim: rgba8(3, 20, 36, a=0.16),
    }
  }
}

///|
fn dock_shadow(palette : DesktopPalette) -> @graphics.ShadowStyle {
  @graphics.ShadowStyle::new(
    color=palette.shadow.multiply_alpha(0.85),
    offset=@geometry.Point::new(x=0.0, y=10.0),
    blur_radius=28.0,
    spread=0.0,
  )
}

///|
fn dock_tile_shadow(palette : DesktopPalette) -> @graphics.ShadowStyle {
  @graphics.ShadowStyle::new(
    color=palette.shadow.multiply_alpha(0.55),
    offset=@geometry.Point::new(x=0.0, y=3.0),
    blur_radius=8.0,
    spread=0.0,
  )
}

///|
fn desktop_theme(dark : Bool) -> @moui.Theme {
  let base = if dark { @views.dark_theme() } else { @views.light_theme() }
  let palette = desktop_palette(dark)
  base.with_palette({
    ..base.palette,
    background: palette.content,
    surface: palette.content,
    surface_variant: palette.sidebar,
    foreground: palette.foreground,
    on_surface: palette.foreground,
    on_surface_variant: palette.foreground,
    muted: palette.muted,
    outline: palette.outline,
    outline_variant: palette.outline,
    primary: palette.accent,
    primary_container: palette.accent_soft,
  })
}

///|
fn desktop_hairline(palette : DesktopPalette) -> @graphics.BorderStyle {
  @graphics.BorderStyle::new(
    brush=@graphics.Brush::solid(palette.outline),
    width=1.0,
  )
}

///|
fn desktop_shadow(palette : DesktopPalette) -> @graphics.ShadowStyle {
  @graphics.ShadowStyle::new(
    color=palette.shadow,
    offset=@geometry.Point::new(x=0.0, y=14.0),
    blur_radius=34.0,
    spread=0.0,
  )
}

///|
fn overlay_panel_background(palette : DesktopPalette) -> @graphics.Color {
  if palette.dark {
    rgba8(31, 37, 48, a=0.88)
  } else {
    rgba8(245, 248, 252, a=0.72)
  }
}

///|
fn overlay_card_background(palette : DesktopPalette) -> @graphics.Color {
  if palette.dark {
    rgba8(255, 255, 255, a=0.10)
  } else {
    rgba8(255, 255, 255, a=0.58)
  }
}

///|
fn overlay_group_background(palette : DesktopPalette) -> @graphics.Color {
  if palette.dark {
    rgba8(255, 255, 255, a=0.06)
  } else {
    rgba8(255, 255, 255, a=0.30)
  }
}

///|
fn overlay_card_outline(palette : DesktopPalette) -> @graphics.BorderStyle {
  @graphics.BorderStyle::new(
    brush=@graphics.Brush::solid(
      if palette.dark {
        rgba8(255, 255, 255, a=0.15)
      } else {
        rgba8(255, 255, 255, a=0.50)
      },
    ),
    width=1.0,
  )
}

///|
fn overlay_neutral_icon_background(palette : DesktopPalette) -> @graphics.Color {
  if palette.dark {
    rgba8(255, 255, 255, a=0.14)
  } else {
    rgba8(210, 216, 226)
  }
}

///|
fn[Msg] glass_panel(
  child : @moui.View[Msg],
  width : Double,
  height : Double,
  palette : DesktopPalette,
  radius? : Double = 18.0,
  padding? : Double = 0.0,
) -> @moui.View[Msg] {
  @views.container(
    child,
    width~,
    height~,
    background=palette.glass,
    corner_radius=radius,
    border=Some(desktop_hairline(palette)),
    padding~,
  ).shadow(desktop_shadow(palette))
}

///|
fn[Msg] solid_panel(
  child : @moui.View[Msg],
  width : Double,
  height : Double,
  palette : DesktopPalette,
  background? : @graphics.Color,
  radius? : Double = 14.0,
  padding? : Double = 0.0,
) -> @moui.View[Msg] {
  @views.container(
    child,
    width~,
    height~,
    background=background.unwrap_or(palette.content),
    corner_radius=radius,
    border=Some(desktop_hairline(palette)),
    padding~,
  )
}
