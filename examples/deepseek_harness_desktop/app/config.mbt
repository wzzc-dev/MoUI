///|
/// DSH owns the product UI. This app only supplies native WebView surfaces.
pub let default_url = "http://127.0.0.1:3080"

///|
pub let default_chat_url = "https://chat.deepseek.com/"

///|
pub let request_url_settings_key = "dsh-desktop/request-url"

///|
pub let chat_url_settings_key = "dsh-desktop/chat-url"

///|
pub let theme_mode_settings_key = "dsh-desktop/theme-mode"

///|
let floating_button_size = 52.0

///|
// Keep a small, easy-to-hit tab visible when the button is docked. The rest
// of the button can sit outside the window without covering the WebView.
let floating_peek_size = 16.0

///|
// A drag released inside this inset is an intentional edge dock. Releases in
// the rest of the window keep their exact free position.
let floating_edge_threshold = 28.0

///|
/// The two root sites are deliberately independent of WebView history.
pub(all) enum Site {
  Harness
  Chat
} derive(Eq, Debug)

///|
/// DSH's host appearance preference. `System` resolves against the current
/// desktop color scheme; the explicit modes keep the native WebView surface
/// and the MoUI settings surface on the same background.
pub(all) enum ThemeMode {
  System
  Dark
  Light
} derive(Eq, Debug)

///|
pub fn ThemeMode::id(self : ThemeMode) -> String {
  match self {
    System => "system"
    Dark => "dark"
    Light => "light"
  }
}

///|
pub fn ThemeMode::label(self : ThemeMode) -> String {
  match self {
    System => "System"
    Dark => "Dark"
    Light => "Light"
  }
}

///|
fn theme_mode_from_id(id : String) -> ThemeMode {
  match id {
    "dark" => ThemeMode::Dark
    "light" => ThemeMode::Light
    _ => ThemeMode::System
  }
}

///|
pub fn ThemeMode::resolve_scheme(
  self : ThemeMode,
  system_scheme : @state.ColorScheme,
) -> @state.ColorScheme {
  match self {
    ThemeMode::System => system_scheme
    ThemeMode::Dark => @state.ColorScheme::Dark
    ThemeMode::Light => @state.ColorScheme::Light
  }
}

///|
pub fn ThemeMode::resolve_theme(
  self : ThemeMode,
  system_scheme : @state.ColorScheme,
) -> @moui.Theme {
  match self.resolve_scheme(system_scheme) {
    @state.ColorScheme::Dark => @views.dark_theme()
    @state.ColorScheme::Light => @views.light_theme()
  }
}

///|
fn theme_for_mode(
  mode : ThemeMode,
  system_scheme : @state.ColorScheme,
) -> @moui.Theme {
  mode.resolve_theme(system_scheme)
}
