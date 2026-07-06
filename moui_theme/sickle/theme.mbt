///|
pub(all) enum SickleStyleMode {
  Skeuo
  Flat
  Hybrid
} derive(Eq, Debug, ToJson)

///|
pub fn SickleStyleMode::label(self : SickleStyleMode) -> String {
  match self {
    Skeuo => "skeuomorphic"
    Flat => "flat"
    Hybrid => "hybrid"
  }
}

///|
pub fn theme(
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
  mode? : SickleStyleMode = SickleStyleMode::Hybrid,
) -> @core.Theme {
  let base = match scheme {
    @core.ColorScheme::Light =>
      @core.resolve_minimal_theme(
        @core.ThemeSpec::minimal_light(),
        @core.ColorScheme::Light,
      )
    @core.ColorScheme::Dark =>
      @core.resolve_minimal_theme(
        @core.ThemeSpec::minimal_dark(),
        @core.ColorScheme::Dark,
      )
  }
  let palette = sickle_palette(scheme)
  base
  .with_palette(palette)
  .with_spacing_scale(sickle_spacing(mode))
  .with_radius_scale(sickle_radius(mode))
  .with_typography(sickle_typography())
  .with_shadow_scale(sickle_shadow_scale(scheme, mode))
  .with_motion(sickle_motion(mode))
  .with_surfaces(sickle_surfaces(palette, scheme, mode))
  .with_components(sickle_components(palette, scheme, mode))
}

///|
pub fn light_theme(
  mode? : SickleStyleMode = SickleStyleMode::Hybrid,
) -> @core.Theme {
  theme(scheme=@core.ColorScheme::Light, mode~)
}

///|
pub fn dark_theme(
  mode? : SickleStyleMode = SickleStyleMode::Hybrid,
) -> @core.Theme {
  theme(scheme=@core.ColorScheme::Dark, mode~)
}

///|
pub fn skeuo_theme(
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
) -> @core.Theme {
  theme(scheme~, mode=SickleStyleMode::Skeuo)
}

///|
pub fn flat_theme(
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
) -> @core.Theme {
  theme(scheme~, mode=SickleStyleMode::Flat)
}

///|
pub fn hybrid_theme(
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
) -> @core.Theme {
  theme(scheme~, mode=SickleStyleMode::Hybrid)
}

///|
pub fn palette(
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
) -> @core.ColorPalette {
  sickle_palette(scheme)
}

///|
fn sickle_palette(scheme : @core.ColorScheme) -> @core.ColorPalette {
  match scheme {
    @core.ColorScheme::Light =>
      {
        ..@core.ColorPalette::from_seed(
          primary=color_byte(r=185, g=36, b=34),
          @core.ColorScheme::Light,
          foreground=color_byte(r=42, g=37, b=33),
          background=color_byte(r=242, g=238, b=230),
          surface=color_byte(r=252, g=250, b=245),
          surface_variant=color_byte(r=230, g=223, b=211),
          outline=color_byte(r=168, g=158, b=143),
          muted=color_byte(r=111, g=104, b=94),
        ),
        secondary: color_byte(r=72, g=86, b=92),
        tertiary: color_byte(r=158, g=119, b=63),
        primary_container: color_byte(r=247, g=222, b=214),
        on_primary_container: color_byte(r=96, g=19, b=20),
        surface: color_byte(r=252, g=250, b=245),
        surface_variant: color_byte(r=230, g=223, b=211),
        on_surface_variant: color_byte(r=83, g=76, b=68),
        outline_variant: color_byte(r=206, g=197, b=182),
        success: color_byte(r=37, g=126, b=82),
        on_success: @core.Color::white(),
        warning: color_byte(r=159, g=109, b=27),
        on_warning: @core.Color::white(),
        danger: color_byte(r=185, g=36, b=34),
        on_danger: @core.Color::white(),
        info: color_byte(r=49, g=91, b=132),
        on_info: @core.Color::white(),
        focus: color_byte(r=185, g=36, b=34),
        scrim: color(r=0.0, g=0.0, b=0.0, a=0.42),
      }
    @core.ColorScheme::Dark =>
      {
        ..@core.ColorPalette::from_seed(
          primary=color_byte(r=236, g=91, b=75),
          @core.ColorScheme::Dark,
          foreground=color_byte(r=238, g=232, b=221),
          background=color_byte(r=28, g=26, b=24),
          surface=color_byte(r=43, g=39, b=35),
          surface_variant=color_byte(r=60, g=54, b=48),
          outline=color_byte(r=121, g=111, b=99),
          muted=color_byte(r=186, g=176, b=162),
        ),
        secondary: color_byte(r=151, g=165, b=170),
        tertiary: color_byte(r=217, g=170, b=95),
        primary_container: color_byte(r=91, g=31, b=28),
        on_primary_container: color_byte(r=255, g=218, b=209),
        surface: color_byte(r=43, g=39, b=35),
        surface_variant: color_byte(r=60, g=54, b=48),
        on_surface_variant: color_byte(r=218, g=209, b=196),
        outline_variant: color_byte(r=86, g=78, b=69),
        success: color_byte(r=103, g=198, b=142),
        on_success: color_byte(r=10, g=45, b=26),
        warning: color_byte(r=239, g=188, b=96),
        on_warning: color_byte(r=66, g=42, b=6),
        danger: color_byte(r=255, g=135, b=118),
        on_danger: color_byte(r=79, g=18, b=16),
        info: color_byte(r=132, g=182, b=225),
        on_info: color_byte(r=10, g=37, b=66),
        focus: color_byte(r=236, g=91, b=75),
        scrim: color(r=0.0, g=0.0, b=0.0, a=0.60),
      }
  }
}

///|
fn sickle_spacing(mode : SickleStyleMode) -> @core.SpacingScale {
  let multiplier = match mode {
    SickleStyleMode::Skeuo => 1.10
    SickleStyleMode::Flat => 0.92
    SickleStyleMode::Hybrid => 1.0
  }
  {
    xs: 4.0 * multiplier,
    sm: 8.0 * multiplier,
    md: 14.0 * multiplier,
    lg: 20.0 * multiplier,
    xl: 30.0 * multiplier,
  }
}

///|
fn sickle_radius(mode : SickleStyleMode) -> @core.RadiusScale {
  match mode {
    SickleStyleMode::Skeuo => { sm: 6.0, md: 10.0, lg: 16.0, pill: 999.0 }
    SickleStyleMode::Flat => { sm: 3.0, md: 5.0, lg: 7.0, pill: 999.0 }
    SickleStyleMode::Hybrid => { sm: 5.0, md: 8.0, lg: 12.0, pill: 999.0 }
  }
}

///|
fn sickle_typography() -> @core.TypographyScale {
  let control = @core.FontSpec::new(size=15.0, weight=700)
  {
    display: @core.FontSpec::new(size=36.0, weight=700),
    headline: @core.FontSpec::new(size=26.0, weight=700),
    title: @core.FontSpec::new(size=21.0, weight=700),
    subtitle: @core.FontSpec::new(size=17.0, weight=600),
    body: @core.FontSpec::new(size=15.0, weight=400),
    label: control,
    caption: @core.FontSpec::new(size=12.0, weight=500),
    overline: @core.FontSpec::new(size=11.0, weight=700),
    control,
  }
}

///|
fn sickle_shadow_scale(
  scheme : @core.ColorScheme,
  mode : SickleStyleMode,
) -> @core.ShadowScale {
  let alpha = match scheme {
    @core.ColorScheme::Light => 0.22
    @core.ColorScheme::Dark => 0.54
  }
  let lift = match mode {
    SickleStyleMode::Skeuo => 1.28
    SickleStyleMode::Flat => 0.36
    SickleStyleMode::Hybrid => 0.84
  }
  {
    sm: shadow(alpha=alpha * 0.48 * lift, y=1.0, blur=4.0),
    md: shadow(alpha=alpha * 0.86 * lift, y=3.0, blur=10.0),
    lg: shadow(alpha=alpha * 1.18 * lift, y=8.0, blur=24.0, spread=1.0),
  }
}

///|
fn sickle_motion(mode : SickleStyleMode) -> @core.MotionScale {
  match mode {
    SickleStyleMode::Skeuo =>
      {
        fast_ms: 140.0,
        normal_ms: 220.0,
        slow_ms: 360.0,
        easing: @core.Easing::EaseOut,
      }
    SickleStyleMode::Flat =>
      {
        fast_ms: 80.0,
        normal_ms: 120.0,
        slow_ms: 180.0,
        easing: @core.Easing::EaseInOut,
      }
    SickleStyleMode::Hybrid =>
      {
        fast_ms: 110.0,
        normal_ms: 170.0,
        slow_ms: 260.0,
        easing: @core.Easing::EaseOut,
      }
  }
}

///|
fn sickle_surfaces(
  palette : @core.ColorPalette,
  scheme : @core.ColorScheme,
  mode : SickleStyleMode,
) -> @core.SurfaceScale {
  let base = match scheme {
    @core.ColorScheme::Light => color_byte(r=242, g=238, b=230)
    @core.ColorScheme::Dark => color_byte(r=28, g=26, b=24)
  }
  let raised_top = match scheme {
    @core.ColorScheme::Light => color_byte(r=255, g=253, b=248)
    @core.ColorScheme::Dark => color_byte(r=64, g=58, b=51)
  }
  let raised_bottom = match scheme {
    @core.ColorScheme::Light => color_byte(r=229, g=222, b=208)
    @core.ColorScheme::Dark => color_byte(r=37, g=34, b=31)
  }
  let overlay = match scheme {
    @core.ColorScheme::Light => color_byte(r=255, g=255, b=252)
    @core.ColorScheme::Dark => color_byte(r=72, g=65, b=57)
  }
  match mode {
    SickleStyleMode::Flat =>
      {
        base: @core.Brush::solid(palette.surface),
        raised: @core.Brush::solid(palette.surface),
        overlay: @core.Brush::solid(palette.surface_variant),
      }
    SickleStyleMode::Skeuo | SickleStyleMode::Hybrid =>
      {
        base: @core.Brush::solid(base),
        raised: @core.Brush::linear_gradient(
          start=@core.Point::new(x=0.0, y=0.0),
          end=@core.Point::new(x=0.0, y=1.0),
          start_color=raised_top,
          end_color=raised_bottom,
        ),
        overlay: @core.Brush::linear_gradient(
          start=@core.Point::new(x=0.0, y=0.0),
          end=@core.Point::new(x=0.0, y=1.0),
          start_color=overlay,
          end_color=raised_top,
        ),
      }
  }
}

///|
fn sickle_components(
  palette : @core.ColorPalette,
  scheme : @core.ColorScheme,
  mode : SickleStyleMode,
) -> @core.ComponentThemes {
  let radius = sickle_radius(mode)
  let spacing = sickle_spacing(mode)
  let shadow = sickle_shadow_scale(scheme, mode)
  let typography = sickle_typography()
  let flat = mode == SickleStyleMode::Flat
  let primary_shadow = if flat { None } else { Some(shadow.sm) }
  let surface_shadow = if flat { None } else { Some(shadow.md) }
  let inset_border = match scheme {
    @core.ColorScheme::Light => color_byte(r=152, g=139, b=124)
    @core.ColorScheme::Dark => color_byte(r=120, g=108, b=96)
  }
  let field_background = match scheme {
    @core.ColorScheme::Light => color_byte(r=255, g=253, b=248)
    @core.ColorScheme::Dark => color_byte(r=35, g=32, b=29)
  }
  {
    button: {
      primary: control_tokens(
        foreground=palette.on_primary,
        background=palette.primary,
        border=palette.primary.darken(0.16),
        border_width=if flat { 0.0 } else { 1.0 },
        radius=radius.md,
      ),
      tonal: control_tokens(
        foreground=palette.foreground,
        background=palette.primary_container,
        border=palette.outline_variant,
        border_width=1.0,
        radius=radius.md,
      ),
      outline: control_tokens(
        foreground=palette.foreground,
        background=transparent(),
        border=palette.outline,
        border_width=1.0,
        radius=radius.md,
      ),
      ghost: control_tokens(
        foreground=palette.foreground,
        background=transparent(),
        border=transparent(),
        border_width=0.0,
        radius=radius.md,
      ),
      subtle: control_tokens(
        foreground=palette.foreground,
        background=palette.surface_variant.multiply_alpha(
          if flat {
            0.45
          } else {
            0.70
          },
        ),
        border=transparent(),
        border_width=0.0,
        radius=radius.md,
      ),
      subtle_brand: control_tokens(
        foreground=palette.primary,
        background=palette.primary_container.multiply_alpha(
          if flat {
            0.36
          } else {
            0.70
          },
        ),
        border=transparent(),
        border_width=0.0,
        radius=radius.md,
      ),
      state_layer: {
        color: palette.primary,
        hover_alpha: if flat {
          0.06
        } else {
          0.10
        },
        focus_alpha: 0.14,
        pressed_alpha: if flat {
          0.10
        } else {
          0.16
        },
        dragged_alpha: 0.18,
        selected_alpha: 0.12,
        disabled_alpha: 0.38,
      },
    },
    text_field: {
      normal: control_tokens(
        foreground=palette.foreground,
        background=field_background,
        border=inset_border,
        border_width=1.0,
        radius=radius.md,
      ),
      focused: control_tokens(
        foreground=palette.foreground,
        background=field_background,
        border=palette.primary,
        border_width=2.0,
        radius=radius.md,
        inner_focus_border=if flat {
          None
        } else {
          Some(palette.primary_container)
        },
      ),
      disabled: control_tokens(
        foreground=palette.muted,
        background=palette.surface_variant,
        border=palette.outline_variant,
        border_width=1.0,
        radius=radius.md,
      ),
      placeholder: palette.muted,
      cursor: palette.primary,
      font: typography.body,
      appearance: @core.TextFieldAppearance::Outline,
    },
    surface: {
      base_padding: spacing.md,
      raised_padding: spacing.lg,
      overlay_padding: spacing.md,
      base_radius: radius.md,
      raised_radius: radius.lg,
      overlay_radius: radius.lg,
      base_shadow: primary_shadow,
      raised_shadow: surface_shadow,
      overlay_shadow: if flat {
        None
      } else {
        Some(shadow.lg)
      },
    },
    choice_control: {
      foreground: palette.foreground,
      selected_color: palette.primary,
      disabled_foreground: palette.muted,
      disabled_selected_color: palette.primary.multiply_alpha(0.40),
      control_size: if flat {
        18.0
      } else {
        20.0
      },
      box_shape: @core.ChoiceControlShape::Square,
      check_style: @core.CheckMarkStyle::Checkmark,
    },
    progress: {
      foreground: palette.primary,
      background: palette.surface_variant,
      radius: radius.pill,
    },
    slider: {
      foreground: palette.primary,
      background: palette.surface_variant,
      thumb_color: if flat {
        palette.primary
      } else {
        field_background
      },
      track_height: if flat {
        4.0
      } else {
        7.0
      },
      thumb_size: if flat {
        18.0
      } else {
        22.0
      },
      radius: radius.pill,
      thumb_shape: @core.ThumbShape::Circle,
    },
    picker: {
      font: typography.control,
      foreground: palette.foreground,
      background: @core.Brush::solid(field_background),
      radius: radius.md,
      popup_max_height: 220.0,
    },
    feedback: feedback_theme(palette, radius, spacing),
    badge: badge_theme(palette, radius),
    form_validation: {
      foreground: palette.danger,
      background: palette.danger.multiply_alpha(0.12),
      border: palette.danger.multiply_alpha(0.72),
      radius: radius.md,
      padding: spacing.md,
    },
  }
}

///|
fn feedback_theme(
  palette : @core.ColorPalette,
  radius : @core.RadiusScale,
  spacing : @core.SpacingScale,
) -> @core.FeedbackTheme {
  {
    neutral: tone(foreground=palette.muted, alpha=0.12),
    info: tone(foreground=palette.info, alpha=0.12),
    success: tone(foreground=palette.success, alpha=0.12),
    warning: tone(foreground=palette.warning, alpha=0.14),
    danger: tone(foreground=palette.danger, alpha=0.12),
    radius: radius.md,
    padding: spacing.sm,
  }
}

///|
fn badge_theme(
  palette : @core.ColorPalette,
  radius : @core.RadiusScale,
) -> @core.BadgeTheme {
  {
    neutral: {
      foreground: palette.foreground,
      background: palette.surface_variant,
      border: palette.outline_variant,
    },
    accent: filled_tone(palette.info),
    success: filled_tone(palette.success),
    warning: filled_tone(palette.warning),
    danger: filled_tone(palette.danger),
    radius: radius.pill,
    padding: 4.0,
  }
}

///|
fn control_tokens(
  foreground~ : @core.Color,
  background~ : @core.Color,
  border~ : @core.Color,
  border_width~ : Double,
  radius~ : Double,
  bottom_border_only? : Bool = false,
  inner_focus_border? : @core.Color? = None,
) -> @core.ControlStateTokens {
  @core.ControlStateTokens::new(
    foreground~,
    background~,
    border~,
    border_width~,
    radius~,
    bottom_border_only~,
    inner_focus_border~,
  )
}

///|
fn tone(foreground~ : @core.Color, alpha~ : Double) -> @core.ToneTokens {
  {
    foreground,
    background: foreground.multiply_alpha(alpha),
    border: foreground.multiply_alpha(0.62),
  }
}

///|
fn filled_tone(color : @core.Color) -> @core.ToneTokens {
  { foreground: @core.Color::white(), background: color, border: color }
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

///|
fn transparent() -> @core.Color {
  @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)
}
