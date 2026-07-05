//  design tokens ported from base-shell.css.
// Light: violet accents on cool-white canvas.
// Dark: deep-sea navy with light-violet highlights.

///|
/// Resolve the active color scheme from the appearance mode.
fn active_scheme(
  appearance : AppearanceMode,
  env : @moui.ViewEnvironment,
) -> @state.ColorScheme {
  match appearance {
    System => env.environment().system_scheme
    Light => @state.ColorScheme::Light
    Dark => @state.ColorScheme::Dark
  }
}

///|
fn workbench_theme(
  appearance : AppearanceMode,
  env : @moui.ViewEnvironment,
) -> @moui.Theme {
  let scheme = active_scheme(appearance, env)
  let base = match scheme {
    Light => @views.light_theme()
    Dark => @views.dark_theme()
  }
  let accent = match scheme {
    Light =>
      @graphics.Color::rgba(
        r=100.0 / 255.0,
        g=100.0 / 255.0,
        b=100.0 / 255.0,
        a=1.0,
      )
    Dark =>
      @graphics.Color::rgba(
        r=180.0 / 255.0,
        g=180.0 / 255.0,
        b=180.0 / 255.0,
        a=1.0,
      )
  }
  let palette = { ..base.palette, primary: accent }
  { ..base, palette, }
}

// ---------------------------------------------------------------------------
// Background layers  (bg-app → bg-sidebar → bg-canvas)
// ---------------------------------------------------------------------------

///|
/// Outermost window background.   light: #f3f5fc, dark: #0f1422.
fn workbench_app_background(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    Light =>
      @graphics.Color::rgba(
        r=243.0 / 255.0,
        g=245.0 / 255.0,
        b=252.0 / 255.0,
        a=1.0,
      )
    Dark =>
      @graphics.Color::rgba(
        r=15.0 / 255.0,
        g=20.0 / 255.0,
        b=34.0 / 255.0,
        a=1.0,
      )
  }
}

///|
/// Sidebar / inspector panel background.  : #eef2fa / #121829.
fn workbench_sidebar_background(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    Light =>
      @graphics.Color::rgba(
        r=238.0 / 255.0,
        g=242.0 / 255.0,
        b=250.0 / 255.0,
        a=1.0,
      )
    Dark =>
      @graphics.Color::rgba(
        r=18.0 / 255.0,
        g=24.0 / 255.0,
        b=41.0 / 255.0,
        a=1.0,
      )
  }
}

///|
/// Center canvas.  : #fafbff / #161d30.
fn workbench_canvas_background(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    Light =>
      @graphics.Color::rgba(
        r=250.0 / 255.0,
        g=251.0 / 255.0,
        b=255.0 / 255.0,
        a=1.0,
      )
    Dark =>
      @graphics.Color::rgba(
        r=22.0 / 255.0,
        g=29.0 / 255.0,
        b=48.0 / 255.0,
        a=1.0,
      )
  }
}

///|
/// Card / pane surface.  : rgba(255,255,255,0.9) / rgba(22,29,47,0.92).
fn workbench_card_background(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    Light => @graphics.Color::rgba(r=1.0, g=1.0, b=1.0, a=0.9)
    Dark =>
      @graphics.Color::rgba(
        r=22.0 / 255.0,
        g=29.0 / 255.0,
        b=47.0 / 255.0,
        a=0.92,
      )
  }
}

///|
/// Subtle row tint.  : #eaf0f9 / #1b2338.
fn workbench_subtle_background(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    Light =>
      @graphics.Color::rgba(
        r=234.0 / 255.0,
        g=240.0 / 255.0,
        b=249.0 / 255.0,
        a=1.0,
      )
    Dark =>
      @graphics.Color::rgba(
        r=27.0 / 255.0,
        g=35.0 / 255.0,
        b=56.0 / 255.0,
        a=1.0,
      )
  }
}

///|
/// Dark gray fill for selected sidebar tab segment (Work / Code / Design).
fn workbench_tab_selected_button_style(
  theme : @moui.Theme,
) -> @views.ButtonStyle {
  let bg = match theme.scheme {
    Light =>
      @graphics.Color::rgba(
        r=120.0 / 255.0,
        g=120.0 / 255.0,
        b=120.0 / 255.0,
        a=1.0,
      )
    Dark =>
      @graphics.Color::rgba(
        r=72.0 / 255.0,
        g=78.0 / 255.0,
        b=92.0 / 255.0,
        a=1.0,
      )
  }
  let fg = match theme.scheme {
    Light => @graphics.Color::rgba(r=1.0, g=1.0, b=1.0, a=1.0)
    Dark => workbench_text(theme)
  }
  let state : @views.ControlStateStyle = {
    foreground: fg,
    background: @graphics.Brush::solid(bg),
    border: None,
    radius: 6.0,
    shadow: None,
    bottom_border_only: false,
    inner_focus_border: None,
  }
  { normal: state, hovered: state, pressed: state, disabled: state }
}

///|
/// Sidebar row active. : rgba(200,200,200,0.50) / rgba(100,100,100,0.18).
fn workbench_sidebar_active(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    Light =>
      @graphics.Color::rgba(
        r=200.0 / 255.0,
        g=200.0 / 255.0,
        b=200.0 / 255.0,
        a=0.50,
      )
    Dark =>
      @graphics.Color::rgba(
        r=100.0 / 255.0,
        g=100.0 / 255.0,
        b=100.0 / 255.0,
        a=0.18,
      )
  }
}

// ---------------------------------------------------------------------------
// Text colors
// ---------------------------------------------------------------------------

///|
/// Primary text.  light: #233659, dark: #f0f5fc.
fn workbench_text(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    Light =>
      @graphics.Color::rgba(
        r=35.0 / 255.0,
        g=54.0 / 255.0,
        b=89.0 / 255.0,
        a=1.0,
      )
    Dark =>
      @graphics.Color::rgba(
        r=240.0 / 255.0,
        g=245.0 / 255.0,
        b=252.0 / 255.0,
        a=1.0,
      )
  }
}

///|
/// Secondary / muted text.  light: #54678c, dark: #bdc9de.
fn workbench_text_muted(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    Light =>
      @graphics.Color::rgba(
        r=84.0 / 255.0,
        g=103.0 / 255.0,
        b=140.0 / 255.0,
        a=1.0,
      )
    Dark =>
      @graphics.Color::rgba(
        r=189.0 / 255.0,
        g=201.0 / 255.0,
        b=222.0 / 255.0,
        a=1.0,
      )
  }
}

///|
/// Tertiary / faint text.  light: #8492b1, dark: #8593b1.
fn workbench_text_faint(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    Light =>
      @graphics.Color::rgba(
        r=132.0 / 255.0,
        g=146.0 / 255.0,
        b=177.0 / 255.0,
        a=1.0,
      )
    Dark =>
      @graphics.Color::rgba(
        r=133.0 / 255.0,
        g=147.0 / 255.0,
        b=177.0 / 255.0,
        a=1.0,
      )
  }
}

// ---------------------------------------------------------------------------
// Accent colors
// ---------------------------------------------------------------------------

///|
///  accent. Light: #646464, dark: #b4b4b4 (neutral gray instead of purple).
fn workbench_accent(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    Light =>
      @graphics.Color::rgba(
        r=100.0 / 255.0,
        g=100.0 / 255.0,
        b=100.0 / 255.0,
        a=1.0,
      )
    Dark =>
      @graphics.Color::rgba(
        r=180.0 / 255.0,
        g=180.0 / 255.0,
        b=180.0 / 255.0,
        a=1.0,
      )
  }
}

///|
/// Soft accent tint. : rgba(100,100,100,0.12) / rgba(180,180,180,0.12).
fn workbench_accent_soft(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    Light =>
      @graphics.Color::rgba(
        r=100.0 / 255.0,
        g=100.0 / 255.0,
        b=100.0 / 255.0,
        a=0.12,
      )
    Dark =>
      @graphics.Color::rgba(
        r=180.0 / 255.0,
        g=180.0 / 255.0,
        b=180.0 / 255.0,
        a=0.12,
      )
  }
}

// ---------------------------------------------------------------------------
// Semantic colors
// ---------------------------------------------------------------------------

///|
/// Success. : #128a4a / #40c977.
fn workbench_success(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    Light =>
      @graphics.Color::rgba(
        r=18.0 / 255.0,
        g=138.0 / 255.0,
        b=74.0 / 255.0,
        a=1.0,
      )
    Dark =>
      @graphics.Color::rgba(
        r=64.0 / 255.0,
        g=201.0 / 255.0,
        b=119.0 / 255.0,
        a=1.0,
      )
  }
}

///|
/// Danger. : #d6493f / #f8736a.
fn workbench_danger(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    Light =>
      @graphics.Color::rgba(
        r=214.0 / 255.0,
        g=73.0 / 255.0,
        b=63.0 / 255.0,
        a=1.0,
      )
    Dark =>
      @graphics.Color::rgba(
        r=248.0 / 255.0,
        g=115.0 / 255.0,
        b=106.0 / 255.0,
        a=1.0,
      )
  }
}

///|
/// Diff added tint. : rgba(18,138,74,0.10) / rgba(64,201,119,0.16).
fn workbench_diff_added_soft(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    Light =>
      @graphics.Color::rgba(
        r=18.0 / 255.0,
        g=138.0 / 255.0,
        b=74.0 / 255.0,
        a=0.10,
      )
    Dark =>
      @graphics.Color::rgba(
        r=64.0 / 255.0,
        g=201.0 / 255.0,
        b=119.0 / 255.0,
        a=0.16,
      )
  }
}

///|
/// Diff removed tint. : rgba(214,73,63,0.10) / rgba(248,115,106,0.16).
fn workbench_diff_removed_soft(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    Light =>
      @graphics.Color::rgba(
        r=214.0 / 255.0,
        g=73.0 / 255.0,
        b=63.0 / 255.0,
        a=0.10,
      )
    Dark =>
      @graphics.Color::rgba(
        r=248.0 / 255.0,
        g=115.0 / 255.0,
        b=106.0 / 255.0,
        a=0.16,
      )
  }
}

// ---------------------------------------------------------------------------
// Message colors
// ---------------------------------------------------------------------------

///|
/// User message bubble. : rgba(133,193,241,0.20) / rgba(133,193,241,0.13).
fn user_message_background(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    Light =>
      @graphics.Color::rgba(
        r=133.0 / 255.0,
        g=193.0 / 255.0,
        b=241.0 / 255.0,
        a=0.20,
      )
    Dark =>
      @graphics.Color::rgba(
        r=133.0 / 255.0,
        g=193.0 / 255.0,
        b=241.0 / 255.0,
        a=0.13,
      )
  }
}

///|
/// Assistant message bubble — card surface.
fn assistant_message_background(theme : @moui.Theme) -> @graphics.Color {
  workbench_card_background(theme)
}

///|
/// User avatar circle fill — accent blue.
fn user_avatar_color(theme : @moui.Theme) -> @graphics.Color {
  workbench_accent(theme)
}

///|
/// Assistant avatar circle fill — warm amber.
fn assistant_avatar_color(theme : @moui.Theme) -> @graphics.Color {
  match theme.scheme {
    Light => @graphics.Color::rgba(r=0.8, g=0.5, b=0.2, a=1.0)
    Dark => @graphics.Color::rgba(r=0.9, g=0.6, b=0.3, a=1.0)
  }
}

///|
/// Purple circular send control (square frame + radius = diameter / 2).
fn[Msg] workbench_send_button(
  theme : @moui.Theme,
  diameter? : Double = 36.0,
  on_tap~ : Msg,
) -> @moui.View[Msg] {
  let radius = diameter / 2.0
  @views.container(
    @views.center(
      @views.icon(
        @views.IconName::ArrowRight,
        size=18.0,
        color=@graphics.Color::rgba(r=1.0, g=1.0, b=1.0, a=1.0),
      ),
      width=diameter,
      height=diameter,
      theme~,
    ),
    width=diameter,
    height=diameter,
    background=workbench_accent(theme),
    corner_radius=radius,
    padding=0.0,
  ).on_tap(on_tap)
}

// ---------------------------------------------------------------------------
// Border helpers
// ---------------------------------------------------------------------------

///|
/// Thin hairline border using 's border-soft token.
fn hairline_border(theme : @moui.Theme) -> @graphics.BorderStyle {
  match theme.scheme {
    Light =>
      @graphics.BorderStyle::new(
        brush=@graphics.Brush::solid(
          @graphics.Color::rgba(
            r=20.0 / 255.0,
            g=47.0 / 255.0,
            b=95.0 / 255.0,
            a=0.13,
          ),
        ),
        width=1.0,
      )
    Dark =>
      @graphics.BorderStyle::new(
        brush=@graphics.Brush::solid(
          @graphics.Color::rgba(
            r=151.0 / 255.0,
            g=192.0 / 255.0,
            b=235.0 / 255.0,
            a=0.13,
          ),
        ),
        width=1.0,
      )
  }
}
