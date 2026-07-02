//  design tokens ported from base-shell.css.
// Light: whale-blue accents on cool-white canvas.
// Dark: deep-sea navy with light-blue highlights.

///|
/// Resolve the active color scheme from the appearance mode.
fn active_scheme(
  appearance : AppearanceMode,
  env : @core.ViewEnvironment,
) -> @core.ColorScheme {
  match appearance {
    System => env.environment().system_scheme
    Light => @core.ColorScheme::Light
    Dark => @core.ColorScheme::Dark
  }
}

///|
fn workbench_theme(
  appearance : AppearanceMode,
  env : @core.ViewEnvironment,
) -> @core.Theme {
  let scheme = active_scheme(appearance, env)
  let base = match scheme {
    Light => @views.light_theme()
    Dark => @views.dark_theme()
  }
  let accent = match scheme {
    Light => @core.Color::rgba(r=59.0/255.0, g=130.0/255.0, b=216.0/255.0, a=1.0)
    Dark => @core.Color::rgba(r=111.0/255.0, g=176.0/255.0, b=232.0/255.0, a=1.0)
  }
  let palette = { ..base.palette, primary: accent }
  { ..base, palette, }
}

// ---------------------------------------------------------------------------
// Background layers  (bg-app → bg-sidebar → bg-canvas)
// ---------------------------------------------------------------------------

///|
/// Outermost window background.   light: #f3f5fc, dark: #0f1422.
fn workbench_app_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    Light => @core.Color::rgba(r=243.0/255.0, g=245.0/255.0, b=252.0/255.0, a=1.0)
    Dark => @core.Color::rgba(r=15.0/255.0, g=20.0/255.0, b=34.0/255.0, a=1.0)
  }
}

///|
/// Sidebar / inspector panel background.  : #eef2fa / #121829.
fn workbench_sidebar_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    Light => @core.Color::rgba(r=238.0/255.0, g=242.0/255.0, b=250.0/255.0, a=1.0)
    Dark => @core.Color::rgba(r=18.0/255.0, g=24.0/255.0, b=41.0/255.0, a=1.0)
  }
}

///|
/// Center canvas.  : #fafbff / #161d30.
fn workbench_canvas_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    Light => @core.Color::rgba(r=250.0/255.0, g=251.0/255.0, b=255.0/255.0, a=1.0)
    Dark => @core.Color::rgba(r=22.0/255.0, g=29.0/255.0, b=48.0/255.0, a=1.0)
  }
}

///|
/// Card / pane surface.  : rgba(255,255,255,0.9) / rgba(22,29,47,0.92).
fn workbench_card_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    Light => @core.Color::rgba(r=1.0, g=1.0, b=1.0, a=0.9)
    Dark => @core.Color::rgba(r=22.0/255.0, g=29.0/255.0, b=47.0/255.0, a=0.92)
  }
}

///|
/// Slightly elevated surface. : rgba(255,255,255,0.98) / #1b2338.
fn workbench_elevated_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    Light => @core.Color::rgba(r=1.0, g=1.0, b=1.0, a=0.98)
    Dark => @core.Color::rgba(r=27.0/255.0, g=35.0/255.0, b=56.0/255.0, a=1.0)
  }
}

///|
/// Subtle row tint.  : #eaf0f9 / #1b2338.
fn workbench_subtle_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    Light => @core.Color::rgba(r=234.0/255.0, g=240.0/255.0, b=249.0/255.0, a=1.0)
    Dark => @core.Color::rgba(r=27.0/255.0, g=35.0/255.0, b=56.0/255.0, a=1.0)
  }
}

///|
/// Sidebar row hover. : rgba(108,162,221,0.10) / rgba(151,192,235,0.09).
fn workbench_sidebar_hover(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    Light => @core.Color::rgba(r=108.0/255.0, g=162.0/255.0, b=221.0/255.0, a=0.10)
    Dark => @core.Color::rgba(r=151.0/255.0, g=192.0/255.0, b=235.0/255.0, a=0.09)
  }
}

///|
/// Sidebar row active. : rgba(216,232,249,0.85) / rgba(151,192,235,0.13).
fn workbench_sidebar_active(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    Light => @core.Color::rgba(r=216.0/255.0, g=232.0/255.0, b=249.0/255.0, a=0.85)
    Dark => @core.Color::rgba(r=151.0/255.0, g=192.0/255.0, b=235.0/255.0, a=0.13)
  }
}

// ---------------------------------------------------------------------------
// Text colors
// ---------------------------------------------------------------------------

///|
/// Primary text.  light: #233659, dark: #f0f5fc.
fn workbench_text(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    Light => @core.Color::rgba(r=35.0/255.0, g=54.0/255.0, b=89.0/255.0, a=1.0)
    Dark => @core.Color::rgba(r=240.0/255.0, g=245.0/255.0, b=252.0/255.0, a=1.0)
  }
}

///|
/// Secondary / muted text.  light: #54678c, dark: #bdc9de.
fn workbench_text_muted(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    Light => @core.Color::rgba(r=84.0/255.0, g=103.0/255.0, b=140.0/255.0, a=1.0)
    Dark => @core.Color::rgba(r=189.0/255.0, g=201.0/255.0, b=222.0/255.0, a=1.0)
  }
}

///|
/// Tertiary / faint text.  light: #8492b1, dark: #8593b1.
fn workbench_text_faint(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    Light => @core.Color::rgba(r=132.0/255.0, g=146.0/255.0, b=177.0/255.0, a=1.0)
    Dark => @core.Color::rgba(r=133.0/255.0, g=147.0/255.0, b=177.0/255.0, a=1.0)
  }
}

// ---------------------------------------------------------------------------
// Accent colors
// ---------------------------------------------------------------------------

///|
///  accent. Light: #3b82d8, dark: #6fb0e8.
fn workbench_accent(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    Light => @core.Color::rgba(r=59.0/255.0, g=130.0/255.0, b=216.0/255.0, a=1.0)
    Dark => @core.Color::rgba(r=111.0/255.0, g=176.0/255.0, b=232.0/255.0, a=1.0)
  }
}

///|
/// Soft accent tint. : rgba(59,130,216,0.15) / rgba(111,176,232,0.18).
fn workbench_accent_soft(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    Light => @core.Color::rgba(r=59.0/255.0, g=130.0/255.0, b=216.0/255.0, a=0.15)
    Dark => @core.Color::rgba(r=111.0/255.0, g=176.0/255.0, b=232.0/255.0, a=0.18)
  }
}

// ---------------------------------------------------------------------------
// Semantic colors
// ---------------------------------------------------------------------------

///|
/// Success. : #128a4a / #40c977.
fn workbench_success(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    Light => @core.Color::rgba(r=18.0/255.0, g=138.0/255.0, b=74.0/255.0, a=1.0)
    Dark => @core.Color::rgba(r=64.0/255.0, g=201.0/255.0, b=119.0/255.0, a=1.0)
  }
}

///|
/// Danger. : #d6493f / #f8736a.
fn workbench_danger(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    Light => @core.Color::rgba(r=214.0/255.0, g=73.0/255.0, b=63.0/255.0, a=1.0)
    Dark => @core.Color::rgba(r=248.0/255.0, g=115.0/255.0, b=106.0/255.0, a=1.0)
  }
}

///|
/// Warning. : #d97706 / #fbbf24.
fn workbench_warning(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    Light => @core.Color::rgba(r=217.0/255.0, g=119.0/255.0, b=6.0/255.0, a=1.0)
    Dark => @core.Color::rgba(r=251.0/255.0, g=191.0/255.0, b=36.0/255.0, a=1.0)
  }
}

///|
/// Diff added tint. : rgba(18,138,74,0.10) / rgba(64,201,119,0.16).
fn workbench_diff_added_soft(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    Light => @core.Color::rgba(r=18.0/255.0, g=138.0/255.0, b=74.0/255.0, a=0.10)
    Dark => @core.Color::rgba(r=64.0/255.0, g=201.0/255.0, b=119.0/255.0, a=0.16)
  }
}

///|
/// Diff removed tint. : rgba(214,73,63,0.10) / rgba(248,115,106,0.16).
fn workbench_diff_removed_soft(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    Light => @core.Color::rgba(r=214.0/255.0, g=73.0/255.0, b=63.0/255.0, a=0.10)
    Dark => @core.Color::rgba(r=248.0/255.0, g=115.0/255.0, b=106.0/255.0, a=0.16)
  }
}

///|
/// Purple skill tint. : rgba(122,104,232,0.13) / rgba(168,155,245,0.16).
fn workbench_skill_soft(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    Light => @core.Color::rgba(r=122.0/255.0, g=104.0/255.0, b=232.0/255.0, a=0.13)
    Dark => @core.Color::rgba(r=168.0/255.0, g=155.0/255.0, b=245.0/255.0, a=0.16)
  }
}

// ---------------------------------------------------------------------------
// Message colors
// ---------------------------------------------------------------------------

///|
/// User message bubble. : rgba(133,193,241,0.20) / rgba(133,193,241,0.13).
fn user_message_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    Light => @core.Color::rgba(r=133.0/255.0, g=193.0/255.0, b=241.0/255.0, a=0.20)
    Dark => @core.Color::rgba(r=133.0/255.0, g=193.0/255.0, b=241.0/255.0, a=0.13)
  }
}

///|
/// Assistant message bubble — card surface.
fn assistant_message_background(theme : @core.Theme) -> @core.Color {
  workbench_card_background(theme)
}

///|
/// User avatar circle fill — accent blue.
fn user_avatar_color(theme : @core.Theme) -> @core.Color {
  workbench_accent(theme)
}

///|
/// Assistant avatar circle fill — warm amber.
fn assistant_avatar_color(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
    Light => @core.Color::rgba(r=0.8, g=0.5, b=0.2, a=1.0)
    Dark => @core.Color::rgba(r=0.9, g=0.6, b=0.3, a=1.0)
  }
}

// ---------------------------------------------------------------------------
// Border helpers
// ---------------------------------------------------------------------------

///|
/// Thin hairline border using 's border-soft token.
fn hairline_border(theme : @core.Theme) -> @core.BorderStyle {
  match theme.scheme {
    Light =>
      @core.BorderStyle::new(
        brush=@core.Brush::solid(
          @core.Color::rgba(r=20.0/255.0, g=47.0/255.0, b=95.0/255.0, a=0.13),
        ),
        width=1.0,
      )
    Dark =>
      @core.BorderStyle::new(
        brush=@core.Brush::solid(
          @core.Color::rgba(r=151.0/255.0, g=192.0/255.0, b=235.0/255.0, a=0.13),
        ),
        width=1.0,
      )
  }
}

///|
/// Divider line using 's sidebar-divider token.
fn sidebar_divider(theme : @core.Theme) -> @core.BorderStyle {
  match theme.scheme {
    Light =>
      @core.BorderStyle::new(
        brush=@core.Brush::solid(
          @core.Color::rgba(r=108.0/255.0, g=162.0/255.0, b=221.0/255.0, a=0.22),
        ),
        width=1.0,
      )
    Dark =>
      @core.BorderStyle::new(
        brush=@core.Brush::solid(
          @core.Color::rgba(r=151.0/255.0, g=192.0/255.0, b=235.0/255.0, a=0.12),
        ),
        width=1.0,
      )
  }
}
