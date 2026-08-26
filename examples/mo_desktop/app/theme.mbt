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
      // macOS dark mode foreground/text: systemLabelColor ~ #F5F5F7.
      foreground: rgba8(245, 245, 247),
      // systemSecondaryLabelColor ~ #A6A6A6.
      muted: rgba8(166, 166, 166),
      glass: rgba8(26, 32, 43, a=0.82),
      glass_strong: rgba8(24, 29, 38, a=0.95),
      content: rgba8(38, 43, 54, a=0.97),
      sidebar: rgba8(27, 32, 42, a=0.97),
      // macOS dark separator: systemSeparatorColor ~ #38383A (opaque).
      outline: rgba8(56, 56, 58, a=0.55),
      shadow: rgba8(0, 0, 0, a=0.48),
      // macOS accent: systemBlue dark ~ #0A84FF.
      accent: rgba8(10, 132, 255),
      accent_soft: rgba8(42, 91, 142, a=0.72),
      // Dark liquid-glass: lower opacity than before to avoid a heavy
      // solid bar over the lake.
      dock: rgba8(30, 36, 46, a=0.42),
      scrim: rgba8(4, 10, 18, a=0.28),
    }
  } else {
    {
      dark: false,
      // macOS light mode foreground/text: systemLabelColor ~ #1D1D1F.
      foreground: rgba8(29, 29, 31),
      // systemSecondaryLabelColor ~ #6C6C70.
      muted: rgba8(108, 108, 112),
      glass: rgba8(245, 248, 252, a=0.82),
      // App windows own readable, opaque surfaces; otherwise bright wallpaper
      // features show through as distracting lines in the Finder content.
      glass_strong: rgba8(249, 250, 252),
      content: rgba8(252, 253, 255),
      sidebar: rgba8(238, 241, 246),
      // macOS light separator: systemSeparatorColor ~ #E5E5EA (opaque).
      outline: rgba8(229, 229, 234, a=0.85),
      shadow: rgba8(18, 31, 48, a=0.30),
      // macOS accent: systemBlue light ~ #007AFF.
      accent: rgba8(0, 122, 255),
      accent_soft: rgba8(180, 216, 255, a=0.92),
      // Frosted dock plate: Tahoe liquid-glass. Keep it very translucent
      // so the plate bottom does not read as a solid white shelf over
      // the lake wallpaper.
      dock: rgba8(255, 255, 255, a=0.26),
      scrim: rgba8(3, 20, 36, a=0.16),
    }
  }
}

///|
/// Dock plate shadow: soft ambient lift rather than a hard drop. Tahoe
/// liquid-glass reads as a frosted plate floating just above the wallpaper,
/// so the shadow is diffuse, centered, and low-opacity. Keep a single
/// shadow (MoUI exposes one per node) but tune it close to
/// `0 12px 32px rgba(0,0,0,0.12)` / `0 10px 28px rgba(0,0,0,0.32)`.
fn dock_shadow(palette : DesktopPalette) -> @graphics.ShadowStyle {
  if palette.dark {
    @graphics.ShadowStyle::new(
      color=rgba8(0, 0, 0, a=0.32),
      offset=@geometry.Point::new(x=0.0, y=10.0),
      blur_radius=32.0,
      spread=0.0,
    )
  } else {
    @graphics.ShadowStyle::new(
      color=rgba8(0, 0, 0, a=0.14),
      offset=@geometry.Point::new(x=0.0, y=8.0),
      blur_radius=28.0,
      spread=0.0,
    )
  }
}

///|
/// Tile shadow: barely lifted; the icon shell already carries a top sheen.
fn dock_tile_shadow(palette : DesktopPalette) -> @graphics.ShadowStyle {
  if palette.dark {
    @graphics.ShadowStyle::new(
      color=rgba8(0, 0, 0, a=0.28),
      offset=@geometry.Point::new(x=0.0, y=4.0),
      blur_radius=10.0,
      spread=0.0,
    )
  } else {
    @graphics.ShadowStyle::new(
      color=rgba8(0, 0, 0, a=0.12),
      offset=@geometry.Point::new(x=0.0, y=3.0),
      blur_radius=8.0,
      spread=0.0,
    )
  }
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
