///|
fn workbench_hairline_border(theme : @moui.Theme) -> @core.BorderStyle {
  let color = match theme.scheme {
    @moui.ColorScheme::Light => @core.Color::black().multiply_alpha(0.10)
    @moui.ColorScheme::Dark => @core.Color::white().multiply_alpha(0.10)
  }
  @core.BorderStyle::new(brush=@core.Brush::solid(color), width=1.0)
}

///|
fn workbench_clear_border() -> @core.BorderStyle {
  @core.BorderStyle::new(
    brush=@core.Brush::solid(@core.Color::black().multiply_alpha(0.0)),
    width=1.0,
  )
}

///|
fn ui_color(r : Double, g : Double, b : Double) -> @core.Color {
  @core.Color::rgba(r~, g~, b~)
}

///|
fn workbench_theme(scheme : @moui.ColorScheme) -> @moui.Theme {
  let base = match scheme {
    @moui.ColorScheme::Light => @views.light_theme()
    @moui.ColorScheme::Dark => @views.dark_theme()
  }
  let accent = match scheme {
    @moui.ColorScheme::Light => ui_color(0.22, 0.38, 0.95)
    @moui.ColorScheme::Dark => ui_color(0.48, 0.62, 1.0)
  }
  {
    ..base,
    palette: { ..base.palette, primary: accent, info: accent, focus: accent },
  }
}

///|
fn workbench_app_background(theme : @moui.Theme) -> @core.Color {
  match theme.scheme {
    @moui.ColorScheme::Light => ui_color(0.965, 0.966, 0.958)
    @moui.ColorScheme::Dark => ui_color(0.055, 0.060, 0.070)
  }
}

///|
fn workbench_sidebar_background(theme : @moui.Theme) -> @core.Color {
  match theme.scheme {
    @moui.ColorScheme::Light => ui_color(0.905, 0.910, 0.905)
    @moui.ColorScheme::Dark => ui_color(0.075, 0.080, 0.092)
  }
}

///|
fn workbench_sidebar_selected_background(theme : @moui.Theme) -> @core.Color {
  match theme.scheme {
    @moui.ColorScheme::Light => ui_color(0.985, 0.986, 0.980)
    @moui.ColorScheme::Dark => ui_color(0.145, 0.153, 0.174)
  }
}

///|
fn workbench_main_background(theme : @moui.Theme) -> @core.Color {
  match theme.scheme {
    @moui.ColorScheme::Light => ui_color(0.975, 0.976, 0.968)
    @moui.ColorScheme::Dark => ui_color(0.062, 0.067, 0.078)
  }
}

///|
fn workbench_panel_background(theme : @moui.Theme) -> @core.Color {
  match theme.scheme {
    @moui.ColorScheme::Light => ui_color(0.992, 0.993, 0.988)
    @moui.ColorScheme::Dark => ui_color(0.105, 0.112, 0.128)
  }
}

///|
fn workbench_panel_raised_background(theme : @moui.Theme) -> @core.Color {
  match theme.scheme {
    @moui.ColorScheme::Light => ui_color(0.975, 0.977, 0.972)
    @moui.ColorScheme::Dark => ui_color(0.132, 0.141, 0.160)
  }
}

///|
fn workbench_panel_subtle_background(theme : @moui.Theme) -> @core.Color {
  match theme.scheme {
    @moui.ColorScheme::Light => ui_color(0.955, 0.961, 0.956)
    @moui.ColorScheme::Dark => ui_color(0.122, 0.130, 0.148)
  }
}

///|
fn workbench_panel_nested_background(theme : @moui.Theme) -> @core.Color {
  match theme.scheme {
    @moui.ColorScheme::Light => ui_color(0.930, 0.938, 0.934)
    @moui.ColorScheme::Dark => ui_color(0.087, 0.093, 0.108)
  }
}

///|
fn workbench_status_bar_background(theme : @moui.Theme) -> @core.Color {
  match theme.scheme {
    @moui.ColorScheme::Light => ui_color(0.910, 0.918, 0.912)
    @moui.ColorScheme::Dark => ui_color(0.083, 0.089, 0.102)
  }
}

///|
fn workbench_transcript_assistant_background(
  theme : @moui.Theme,
) -> @core.Color {
  match theme.scheme {
    @moui.ColorScheme::Light => ui_color(0.985, 0.987, 0.982)
    @moui.ColorScheme::Dark => ui_color(0.116, 0.124, 0.141)
  }
}

///|
fn workbench_transcript_user_background(theme : @moui.Theme) -> @core.Color {
  match theme.scheme {
    @moui.ColorScheme::Light => ui_color(0.940, 0.958, 0.985)
    @moui.ColorScheme::Dark => ui_color(0.105, 0.132, 0.168)
  }
}

///|
fn workbench_danger_background(theme : @moui.Theme) -> @core.Color {
  match theme.scheme {
    @moui.ColorScheme::Light => ui_color(0.995, 0.975, 0.970)
    @moui.ColorScheme::Dark => ui_color(0.185, 0.094, 0.096)
  }
}

///|
fn workbench_transparent() -> @core.Color {
  @core.Color::black().multiply_alpha(0.0)
}
