///|
pub struct Model {
  url : String
  /// Kept as the compatibility name for the original Harness setting.
  configured_url : String
  harness_url : String
  chat_url : String
  active_site : Site
  title : String
  status : String
  web_view_available : Bool
  web_view_description : String
  harness_settings_ready : Bool
  chat_settings_ready : Bool
  theme_settings_ready : Bool
  settings_ready : Bool
  settings_presented : Bool
  request_url_input : String
  chat_url_input : String
  theme_mode : ThemeMode
  theme_mode_input : ThemeMode
  system_color_scheme : @state.ColorScheme
  settings_error : String
  settings_saving : Bool
  settings_writes_pending : Int
  floating_x : Double
  floating_y : Double
  floating_left : Bool
  floating_collapsed : Bool
  floating_enabled : Bool
}

///|
pub(all) struct WebViewCapability {
  available : Bool
  description : String
}

///|
pub(all) enum Msg {
  WebViewEvent(@webview_host.WebViewEvent)
  SettingsLoaded(@services.ServiceTaskResult[String?])
  ChatSettingsLoaded(@services.ServiceTaskResult[String?])
  ThemeModeLoaded(@services.ServiceTaskResult[String?])
  SystemColorSchemeLoaded(@services.ServiceTaskResult[@state.ColorScheme])
  OpenSettings
  RequestUrlChanged(String)
  ChatUrlChanged(String)
  ThemeModeChanged(String)
  SaveSettings
  CancelSettings
  SettingsBackdropPressed
  SettingsSaved(String, @services.ServiceTaskResult[Unit])
  HarnessSettingsSaved(String, @services.ServiceTaskResult[Unit])
  ChatSettingsSaved(String, @services.ServiceTaskResult[Unit])
  ThemeModeSaved(ThemeMode, @services.ServiceTaskResult[Unit])
  SwitchSite
  ToggleFloating
  FloatingSecondaryTap
  FloatingDragged(@views.DragGestureEvent)
  // The environment-aware route lets the app clamp a free position to the
  // current window and recognize either edge, including after a resize.
  FloatingDraggedInViewport(@views.DragGestureEvent, Double, Double)
}

///|
pub fn Model::new(
  capability~ : WebViewCapability,
  url? : String = default_url,
) -> Model {
  let initial_url = normalize_request_url(url).unwrap_or(default_url)
  {
    url: initial_url,
    configured_url: initial_url,
    harness_url: initial_url,
    chat_url: default_chat_url,
    active_site: Harness,
    title: "DeepSeek Harness",
    status: if capability.available {
      "connecting"
    } else {
      "unavailable"
    },
    web_view_available: capability.available,
    web_view_description: capability.description,
    harness_settings_ready: false,
    chat_settings_ready: false,
    theme_settings_ready: false,
    settings_ready: false,
    settings_presented: false,
    request_url_input: initial_url,
    chat_url_input: default_chat_url,
    theme_mode: ThemeMode::System,
    theme_mode_input: ThemeMode::System,
    system_color_scheme: @state.ColorScheme::Light,
    settings_error: "",
    settings_saving: false,
    settings_writes_pending: 0,
    floating_x: 0.0,
    floating_y: 0.0,
    floating_left: false,
    floating_collapsed: false,
    floating_enabled: true,
  }
}

///|
pub fn WebViewCapability::available(
  description? : String = "Native WebView embedding is available.",
) -> WebViewCapability {
  { available: true, description }
}

///|
pub fn WebViewCapability::unavailable(
  description? : String = "Native WebView is unavailable on this host.",
) -> WebViewCapability {
  { available: false, description }
}
