// Slimmed-down theme helpers for the Codex-style workbench chrome.

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

/// Build the workbench theme. A clean, minimal palette with a single accent.
fn workbench_theme(
  appearance : AppearanceMode,
  env : @core.ViewEnvironment,
) -> @core.Theme {
  let scheme = active_scheme(appearance, env)
  let base = match scheme {
  Light => @views.light_theme()
  Dark => @views.dark_theme()
  }
  // A calm indigo accent works well for a Codex-style minimal chrome.
  let accent = match scheme {
  Light => @core.Color::rgba(r=0.35, g=0.4, b=0.85, a=1.0)
  Dark => @core.Color::rgba(r=0.55, g=0.6, b=0.95, a=1.0)
  }
  let palette = { ..base.palette, primary: accent }
  { ..base, palette }
}

// Semantic background colors for the chat surface. Kept intentionally small:
// just panel / user / assistant / tool, in both schemes.

fn panel_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
  Light => @core.Color::rgba(r=0.99, g=0.99, b=1.0, a=1.0)
  Dark => @core.Color::rgba(r=0.09, g=0.09, b=0.11, a=1.0)
  }
}

fn sidebar_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
  Light => @core.Color::rgba(r=0.96, g=0.96, b=0.98, a=1.0)
  Dark => @core.Color::rgba(r=0.07, g=0.07, b=0.09, a=1.0)
  }
}

fn user_message_background(theme : @core.Theme) -> @core.Color {
  theme.palette.primary_container
}

fn assistant_message_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
  Light => @core.Color::rgba(r=0.97, g=0.97, b=0.99, a=1.0)
  Dark => @core.Color::rgba(r=0.13, g=0.13, b=0.16, a=1.0)
  }
}

fn tool_message_background(theme : @core.Theme) -> @core.Color {
  match theme.scheme {
  Light => @core.Color::rgba(r=0.95, g=0.95, b=0.97, a=1.0)
  Dark => @core.Color::rgba(r=0.11, g=0.11, b=0.14, a=1.0)
  }
}

fn hairline_border(theme : @core.Theme) -> @core.BorderStyle {
  @core.BorderStyle::new(
    brush=@core.Brush::solid(theme.palette.outline),
    width=1.0,
  )
}
