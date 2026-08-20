///|
using @views {column, container, spacer, text}

///|
using @webview_views {web_view}

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
let web_view_id = "dsh-desktop-surface"

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

fn theme_for_mode(
  mode : ThemeMode,
  system_scheme : @state.ColorScheme,
) -> @moui.Theme {
  mode.resolve_theme(system_scheme)
}

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

///|
pub fn update(model : Model, msg : Msg) -> Model {
  match msg {
    WebViewEvent(event) =>
      match event {
        @webview_host.WebViewEvent::NavigationRequested(url)
        | @webview_host.WebViewEvent::NavigationStarted(url) =>
          { ..model, url, status: "loading" }
        @webview_host.WebViewEvent::NavigationCommitted(url) =>
          { ..model, url, status: "loaded" }
        @webview_host.WebViewEvent::NavigationFinished(url) =>
          { ..model, url, status: "ready" }
        @webview_host.WebViewEvent::NavigationFailed(_url, reason) =>
          {
            ..model,
            status: "failed: " + reason,
          }
        @webview_host.WebViewEvent::TitleChanged(title) => { ..model, title, }
        @webview_host.WebViewEvent::CanGoBackChanged(_)
        | @webview_host.WebViewEvent::CanGoForwardChanged(_)
        | @webview_host.WebViewEvent::JavaScriptResult(_, _) => model
      }
    SettingsLoaded(result) => {
      let harness = match result {
        @services.ServiceTaskResult::Success(Some(value)) =>
          normalize_request_url(value).unwrap_or(model.harness_url)
        _ => model.harness_url
      }
      {
        ..model,
        url: if model.active_site == Harness {
          harness
        } else {
          model.url
        },
        configured_url: harness,
        harness_url: harness,
        request_url_input: harness,
        harness_settings_ready: true,
        settings_ready: model.chat_settings_ready && model.theme_settings_ready,
        settings_error: "",
      }
    }
    ThemeModeLoaded(result) => {
      let mode = match result {
        @services.ServiceTaskResult::Success(Some(value)) => theme_mode_from_id(value)
        _ => model.theme_mode
      }
      {
        ..model,
        theme_mode: mode,
        theme_mode_input: mode,
        theme_settings_ready: true,
        settings_ready: model.harness_settings_ready && model.chat_settings_ready,
        settings_error: "",
      }
    }
    SystemColorSchemeLoaded(result) => {
      match result {
        @services.ServiceTaskResult::Success(value) => {
          ..model,
          system_color_scheme: value,
        }
        _ => model
      }
    }
    ChatSettingsLoaded(result) => {
      let chat = match result {
        @services.ServiceTaskResult::Success(Some(value)) =>
          normalize_request_url(value).unwrap_or(model.chat_url)
        _ => model.chat_url
      }
      {
        ..model,
        url: if model.active_site == Chat {
          chat
        } else {
          model.url
        },
        chat_url: chat,
        chat_url_input: chat,
        chat_settings_ready: true,
        settings_ready: model.harness_settings_ready && model.theme_settings_ready,
        settings_error: "",
      }
    }
    OpenSettings =>
      {
        ..model,
        settings_presented: true,
        request_url_input: model.harness_url,
        chat_url_input: model.chat_url,
        theme_mode_input: model.theme_mode,
        settings_error: "",
        settings_saving: false,
        settings_writes_pending: 0,
      }
    RequestUrlChanged(value) if !model.settings_saving =>
      { ..model, request_url_input: value, settings_error: "" }
    ChatUrlChanged(value) if !model.settings_saving =>
      { ..model, chat_url_input: value, settings_error: "" }
    ThemeModeChanged(value) if !model.settings_saving =>
      { ..model, theme_mode_input: theme_mode_from_id(value), settings_error: "" }
    RequestUrlChanged(_) | ChatUrlChanged(_) | ThemeModeChanged(_) => model
    SaveSettings => {
      let harness_ok = normalize_request_url(model.request_url_input) is Some(_)
      let chat_ok = normalize_request_url(model.chat_url_input) is Some(_)
      if !harness_ok || !chat_ok {
        {
          ..model,
          settings_error: "Enter valid HTTP or HTTPS URLs.",
          settings_saving: false,
        }
      } else {
        {
          ..model,
          request_url_input: normalize_request_url(model.request_url_input).unwrap_or(
            model.harness_url,
          ),
          chat_url_input: normalize_request_url(model.chat_url_input).unwrap_or(
            model.chat_url,
          ),
          theme_mode_input: model.theme_mode_input,
          settings_error: "",
          settings_saving: true,
          settings_writes_pending: 3,
        }
      }
    }
    CancelSettings =>
      {
        ..model,
        settings_presented: false,
        request_url_input: model.harness_url,
        chat_url_input: model.chat_url,
        theme_mode_input: model.theme_mode,
        settings_error: "",
        settings_saving: false,
        settings_writes_pending: 0,
      }
    SettingsBackdropPressed => model
    SwitchSite if !model.settings_presented => {
      let next_site = match model.active_site {
        Harness => Chat
        Chat => Harness
      }
      let next_url = match next_site {
        Harness => model.harness_url
        Chat => model.chat_url
      }
      {
        ..model,
        active_site: next_site,
        url: next_url,
        status: "loading",
        // A click on the visible tab also expands a docked button.
        floating_collapsed: false,
      }
    }
    SwitchSite => model
    ToggleFloating =>
      { ..model, floating_enabled: !model.floating_enabled }
    FloatingSecondaryTap =>
      update({ ..model, floating_collapsed: false }, OpenSettings)
    FloatingDragged(event) => update_floating_drag(model, event, None, None)
    FloatingDraggedInViewport(event, width, height) =>
      update_floating_drag(model, event, Some(width), Some(height))
    HarnessSettingsSaved(value, result) =>
      apply_settings_result(model, Harness, value, result)
    ChatSettingsSaved(value, result) =>
      apply_settings_result(model, Chat, value, result)
    ThemeModeSaved(mode, result) => apply_theme_mode_result(model, mode, result)
    // Kept for callers/tests using the original single-setting message.
    SettingsSaved(value, result) =>
      apply_settings_result(
        { ..model, settings_writes_pending: 1 },
        Harness,
        value,
        result,
      )
  }
}

///|
fn update_floating_drag(
  model : Model,
  event : @views.DragGestureEvent,
  viewport_width : Double?,
  viewport_height : Double?,
) -> Model {
  if event.phase == @views.DragGesturePhase::Cancelled {
    // Cancellation is terminal. Keep the last committed position; a lost
    // pointer stream must not snap the button back to an edge.
    return model
  }
  // A collapsed button starts with its visible tab offset. Promote it to
  // the full button as soon as a real drag crosses the gesture slop, then
  // continue applying deltas from that expanded position.
  let base_x = if event.phase == @views.DragGesturePhase::Started &&
    model.floating_collapsed {
    if model.floating_left {
      -(floating_button_size - floating_peek_size)
    } else {
      floating_button_size - floating_peek_size
    }
  } else {
    model.floating_x
  }
  let raw_x = base_x + event.delta.x
  let raw_y = model.floating_y + event.delta.y
  let next_y = match viewport_height {
    Some(height) =>
      raw_y.clamp(min=0.0, max=(height - floating_button_size).max(0.0))
    None => raw_y.max(0.0)
  }
  if event.phase == @views.DragGesturePhase::Ended {
    // `position.x` is in window coordinates, so the left edge is
    // unambiguous. For a right-anchored button, the horizontal offset also
    // identifies the right edge. Once a user has moved freely from the
    // left edge we preserve that anchor until they intentionally return to
    // the left; this avoids surprising snaps in the middle of the window.
    let near_left = event.position.x <= floating_edge_threshold
    let near_right = match viewport_width {
      Some(width) => event.position.x >= width - floating_edge_threshold
      None => !model.floating_left && raw_x >= -floating_edge_threshold
    }
    let docked = near_left || near_right
    let dock_left = if near_left {
      true
    } else if near_right {
      false
    } else {
      // Once the button is on the left side, keep using that coordinate
      // system for free positions. This lets a user pull a left peek tab
      // back into the window without a jump caused by an unknown viewport
      // width.
      model.floating_left
    }
    // Preserve the free position. A docked button stores the expanded
    // edge anchor and derives its hidden offset in `view`.
    {
      ..model,
      floating_x: if docked {
        0.0
      } else {
        clamp_floating_x(raw_x, model.floating_left, viewport_width)
      },
      floating_y: next_y,
      floating_left: dock_left,
      floating_collapsed: docked,
    }
  } else {
    {
      ..model,
      floating_x: clamp_floating_x(raw_x, model.floating_left, viewport_width),
      floating_y: next_y,
      floating_collapsed: false,
    }
  }
}

///|
fn clamp_floating_x(
  value : Double,
  left : Bool,
  viewport_width : Double?,
) -> Double {
  match viewport_width {
    Some(width) => {
      let extent = (width - floating_button_size).max(0.0)
      if left {
        value.clamp(min=0.0, max=extent)
      } else {
        value.clamp(min=-extent, max=0.0)
      }
    }
    None => value
  }
}

///|
fn apply_settings_result(
  model : Model,
  site : Site,
  value : String,
  result : @services.ServiceTaskResult[Unit],
) -> Model {
  if !model.settings_presented || !model.settings_saving {
    return model
  }
  match result {
    @services.ServiceTaskResult::Failure(error) =>
      {
        ..model,
        settings_error: error.message,
        settings_saving: false,
        settings_writes_pending: 0,
      }
    @services.ServiceTaskResult::Cancelled =>
      {
        ..model,
        settings_error: "Saving was cancelled.",
        settings_saving: false,
        settings_writes_pending: 0,
      }
    @services.ServiceTaskResult::Success(_) => {
      let harness = if site == Harness { value } else { model.harness_url }
      let chat = if site == Chat { value } else { model.chat_url }
      let pending = if model.settings_writes_pending > 0 {
        model.settings_writes_pending - 1
      } else {
        0
      }
      let next_url = match model.active_site {
        Harness => harness
        Chat => chat
      }
      if pending > 0 {
        {
          ..model,
          harness_url: harness,
          configured_url: harness,
          chat_url: chat,
          url: next_url,
          settings_writes_pending: pending,
        }
      } else {
        {
          ..model,
          harness_url: harness,
          configured_url: harness,
          chat_url: chat,
          url: next_url,
          request_url_input: harness,
          chat_url_input: chat,
          settings_presented: false,
          settings_error: "",
          settings_saving: false,
          settings_writes_pending: 0,
          status: "loading",
        }
      }
    }
  }
}

///|
fn apply_theme_mode_result(
  model : Model,
  mode : ThemeMode,
  result : @services.ServiceTaskResult[Unit],
) -> Model {
  if !model.settings_presented || !model.settings_saving {
    return model
  }
  match result {
    @services.ServiceTaskResult::Failure(error) =>
      {
        ..model,
        settings_error: error.message,
        settings_saving: false,
        settings_writes_pending: 0,
      }
    @services.ServiceTaskResult::Cancelled =>
      {
        ..model,
        settings_error: "Saving was cancelled.",
        settings_saving: false,
        settings_writes_pending: 0,
      }
    @services.ServiceTaskResult::Success(_) => {
      let pending = if model.settings_writes_pending > 0 {
        model.settings_writes_pending - 1
      } else {
        0
      }
      let next = {
        ..model,
        theme_mode: mode,
        theme_mode_input: mode,
        settings_writes_pending: pending,
      }
      if pending > 0 {
        next
      } else {
        {
          ..next,
          request_url_input: next.harness_url,
          chat_url_input: next.chat_url,
          settings_presented: false,
          settings_error: "",
          settings_saving: false,
          settings_writes_pending: 0,
        }
      }
    }
  }
}

///|
pub fn normalize_request_url(value : String) -> String? {
  let trimmed = value.trim().to_owned()
  let lower = trimmed.to_lower()
  let has_http = lower.has_prefix("http://") && trimmed.length() > 7
  let has_https = lower.has_prefix("https://") && trimmed.length() > 8
  if (has_http || has_https) &&
    !trimmed.contains(" ") &&
    !trimmed.contains("\n") &&
    !trimmed.contains("\t") {
    Some(trimmed)
  } else {
    None
  }
}

///|
/// Compatibility entrypoint for callers that render the app without a host
/// environment. Native composition roots use `view_with_environment` below so
/// the floating control can clamp itself to the actual window size.
pub fn view(model : Model) -> @moui.View[Msg] {
  view_with_viewport(model, 1280.0, 820.0, model.system_color_scheme)
}

///|
fn view_with_environment(
  model : Model,
  view_environment : @moui.ViewEnvironment,
) -> @moui.View[Msg] {
  let viewport = view_environment.viewport_size()
  view_with_viewport(
    model,
    viewport.width,
    viewport.height,
    view_environment.environment().system_scheme,
  )
}

///|
fn view_with_viewport(
  model : Model,
  viewport_width : Double,
  viewport_height : Double,
  system_color_scheme : @state.ColorScheme,
) -> @moui.View[Msg] {
  // Preview the selected mode while Settings is open so the native WebView
  // surface and MoUI dialog use the same appearance before Save.
  let selected_mode = if model.settings_presented {
    model.theme_mode_input
  } else {
    model.theme_mode
  }
  let theme = theme_for_mode(selected_mode, system_color_scheme)
  let content = if model.web_view_available && model.settings_ready {
    web_view(
      id=web_view_id,
      url=model.url,
      title=model.title,
      policy=@webview_host.WebViewNavigationPolicy::AllowHttpHttps,
      background_color=Some(theme.palette.background),
      color_scheme=Some(theme.scheme),
      on_event=Some(event => WebViewEvent(event)),
    )
  } else if model.web_view_available {
    loading_view(theme)
  } else {
    unavailable_view(model, theme)
  }
  let floating = if model.settings_presented || !model.floating_enabled {
    @views.empty()
  } else {
    floating_button(model, theme, viewport_width, viewport_height)
  }
  let body = @views.overlay(content, floating)
  let root = @views.dialog_host(
    body,
    dialog=Some(settings_dialog(model, theme)),
    presented=model.settings_presented,
    on_backdrop=Some(SettingsBackdropPressed),
  )
  root.theme(theme)
}

///|
fn floating_button(
  model : Model,
  _theme : @moui.Theme,
  viewport_width : Double,
  viewport_height : Double,
) -> @moui.View[Msg] {
  // DeepSeek blue keeps the affordance legible in both light and dark themes.
  let brand_blue = @graphics.Color::rgba(r=0.302, g=0.420, b=0.996, a=1.0)
  let button = @views.container(
      @views.text(
        "D",
        role=@views.TextRole::Control,
        width=floating_button_size,
        height=floating_button_size,
      ).foreground(@graphics.Color::white()),
      width=floating_button_size,
      height=floating_button_size,
      background=brand_blue,
      corner_radius=floating_button_size / 2.0,
      padding=0.0,
      // Keep drag inside the tap modifiers so it receives the terminal Up/Cancel
      // before a child tap consumes a click. Otherwise a click can leave the drag
      // recognizer pending and subsequent pointer moves move the button.
    )
    .on_drag(event => {
      FloatingDraggedInViewport(event, viewport_width, viewport_height)
    })
    .on_secondary_tap(FloatingSecondaryTap)
    .on_tap(SwitchSite)
    .accessibility_label("Switch Chat/DSH site")
  let surface = @views.stack([
    button,
    @views.overlay_marker(
      width=floating_button_size,
      height=floating_button_size,
    ),
  ])
  let placed = if model.floating_left {
    @views.row([surface, @views.spacer(weight=1.0)], spacing=0.0)
  } else {
    @views.row([@views.spacer(weight=1.0), surface], spacing=0.0)
  }
  let horizontal_offset = if model.floating_collapsed {
    if model.floating_left {
      -(floating_button_size - floating_peek_size)
    } else {
      floating_button_size - floating_peek_size
    }
  } else {
    clamp_floating_x(
      model.floating_x,
      model.floating_left,
      Some(viewport_width),
    )
  }
  @views.column([placed], spacing=0.0).offset(
    dx=horizontal_offset,
    dy=model.floating_y.clamp(
      min=0.0,
      max=(viewport_height - floating_button_size).max(0.0),
    ),
  )
}

///|
fn loading_view(theme : @moui.Theme) -> @moui.View[Msg] {
  container(spacer(min_length=1.0, weight=1.0), padding=0.0).background(
    theme.palette.surface,
  )
}

///|
fn settings_dialog(model : Model, theme : @moui.Theme) -> @moui.View[Msg] {
  let support = if model.settings_error == "" {
    text("HTTP or HTTPS").caption().foreground(theme.palette.muted)
  } else {
    text(model.settings_error).caption().foreground(theme.palette.danger)
  }
  @views.dialog(
    "Settings",
    content=column(
      [
        text("Harness URL").caption(),
        @views.text_field(
          model.request_url_input,
          on_input=value => RequestUrlChanged(value),
          on_submit=Some(SaveSettings),
          placeholder=default_url,
          width=416.0,
          height=40.0,
        ),
        text("Chat URL").caption(),
        @views.text_field(
          model.chat_url_input,
          on_input=value => ChatUrlChanged(value),
          on_submit=Some(SaveSettings),
          placeholder=default_chat_url,
          width=416.0,
          height=40.0,
        ),
        text("Theme").caption(),
        @views.segmented_control(
          [
            @views.choice_item("system", "System"),
            @views.choice_item("dark", "Dark"),
            @views.choice_item("light", "Light"),
          ],
          selected=model.theme_mode_input.id(),
          on_select=value => ThemeModeChanged(value),
          theme~,
          width=416.0,
        ),
        support.frame(width=416.0, height=28.0),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Start,
    ),
    primary_action=Some(
      @views.StateViewAction::new(
        label=if model.settings_saving { "Saving..." } else { "Save" },
        message=SaveSettings,
      ),
    ),
    secondary_action=Some(
      @views.StateViewAction::new(label="Cancel", message=CancelSettings),
    ),
    theme~,
    width=480.0,
    height=404.0,
  )
}

///|
fn unavailable_view(model : Model, theme : @moui.Theme) -> @moui.View[Msg] {
  container(
    column(
      [
        spacer(min_length=120.0, weight=0.0),
        text("Native WebView unavailable").title(),
        text(model.web_view_description).foreground(theme.palette.muted),
        text("Start a native composition root to open the local DSH Host.")
        .caption()
        .foreground(theme.palette.muted),
        spacer(min_length=120.0, weight=0.0),
      ],
      spacing=12.0,
      align=@views.CrossAlign::Center,
    ),
    padding=24.0,
  ).background(theme.palette.surface_variant.multiply_alpha(0.45))
}

///|
pub fn settings_action_command() -> @views.ActionCommand {
  @views.ActionCommand::new(
    intent=@views.CommandIntent::Activate,
    label="Settings\u{2026}",
    shortcut=Some(
      @views.KeyboardShortcut::new(
        key=",",
        modifiers=@views.KeyModifiers::new(meta=true),
      ),
    ),
  )
}

///|
pub fn switch_site_action_command() -> @views.ActionCommand {
  @views.ActionCommand::new(
    intent=@views.CommandIntent::SwitchSite,
    label="Switch Chat/DSH Site",
    group="View",
    description="Switch between the Harness and Chat roots.",
  )
}

///|
pub fn toggle_floating_action_command() -> @views.ActionCommand {
  @views.ActionCommand::new(
    intent=@views.CommandIntent::ToggleFloating,
    label="Toggle Floating Button",
    group="View",
    description="Show or hide the floating site-switch button.",
  )
}

///|
fn edit_action_command(
  intent : @views.CommandIntent,
  label : String,
  key : String,
  shift? : Bool = false,
) -> @views.ActionCommand {
  @views.ActionCommand::new(
    intent~,
    label~,
    shortcut=Some(
      @views.KeyboardShortcut::new(
        key~,
        modifiers=@views.KeyModifiers::new(shift~, meta=true),
      ),
    ),
  )
}

///|
pub fn application_menus() -> Array[@services.ApplicationMenu] {
  [
    @services.ApplicationMenu::application(items=[
      @services.ApplicationMenuItem::MenuCommand(settings_action_command()),
    ]),
    @services.ApplicationMenu::new(title="Edit", items=[
      @services.ApplicationMenuItem::MenuCommand(
        edit_action_command(@views.CommandIntent::Undo, "Undo", "z"),
      ),
      @services.ApplicationMenuItem::MenuCommand(
        edit_action_command(@views.CommandIntent::Redo, "Redo", "z", shift=true),
      ),
      @services.ApplicationMenuItem::MenuSeparator,
      @services.ApplicationMenuItem::MenuCommand(
        edit_action_command(@views.CommandIntent::Cut, "Cut", "x"),
      ),
      @services.ApplicationMenuItem::MenuCommand(
        edit_action_command(@views.CommandIntent::Copy, "Copy", "c"),
      ),
      @services.ApplicationMenuItem::MenuCommand(
        edit_action_command(@views.CommandIntent::Paste, "Paste", "v"),
      ),
      @services.ApplicationMenuItem::MenuSeparator,
      @services.ApplicationMenuItem::MenuCommand(
        edit_action_command(@views.CommandIntent::SelectAll, "Select All", "a"),
      ),
    ]),
    @services.ApplicationMenu::new(title="View", items=[
      @services.ApplicationMenuItem::MenuCommand(switch_site_action_command()),
      @services.ApplicationMenuItem::MenuSeparator,
      @services.ApplicationMenuItem::MenuCommand(toggle_floating_action_command()),
    ]),
  ]
}

///|
fn program_commands() -> Array[@moui.ProgramCommand[Msg]] {
  [
    @moui.ProgramCommand::new(
      command=settings_action_command(),
      message=OpenSettings,
    ),
    @moui.ProgramCommand::new(
      command=switch_site_action_command(),
      message=SwitchSite,
    ),
    @moui.ProgramCommand::new(
      command=toggle_floating_action_command(),
      message=ToggleFloating,
    ),
  ]
}

///|
fn request_settings_load(services : @services.AppServices) -> @moui.Effect[Msg] {
  @moui.Effect::batch([
    services
    .settings()
    .read(request_url_settings_key)
    .effect(map=result => SettingsLoaded(result)),
    services
    .settings()
    .read(chat_url_settings_key)
    .effect(map=result => ChatSettingsLoaded(result)),
    services
    .settings()
    .read(theme_mode_settings_key)
    .effect(map=result => ThemeModeLoaded(result)),
    services
    .appearance()
    .system_color_scheme()
    .effect(map=result => SystemColorSchemeLoaded(result)),
  ])
}

///|
fn update_with_services(
  model : Model,
  msg : Msg,
  services : @services.AppServices,
) -> (Model, @moui.Effect[Msg]) {
  if msg is SaveSettings && model.settings_saving {
    return (model, @moui.Effect::none())
  }
  let next = update(model, msg)
  match msg {
    SaveSettings if next.settings_saving => {
      let harness = next.request_url_input
      let chat = next.chat_url_input
      let theme_mode = next.theme_mode_input.id()
      (
        next,
        @moui.Effect::batch([
          services
          .settings()
          .write(request_url_settings_key, harness)
          .effect(map=result => HarnessSettingsSaved(harness, result)),
          services
          .settings()
          .write(chat_url_settings_key, chat)
          .effect(map=result => ChatSettingsSaved(chat, result)),
          services
          .settings()
          .write(theme_mode_settings_key, theme_mode)
          .effect(map=result => {
            ThemeModeSaved(next.theme_mode_input, result)
          }),
        ]),
      )
    }
    _ => (next, @moui.Effect::none())
  }
}

///|
pub fn program(
  capability~ : WebViewCapability,
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
  url? : String = default_url,
  on_navigation_finished? : (String) -> Unit = _ => (),
) -> @moui.Program[Model, Msg] {
  let services = environment.services()
  @moui.Program::new_with_environment(
    init=() => (Model::new(capability~, url~), request_settings_load(services)),
    update=(model, msg) => {
      let (next, effect) = update_with_services(model, msg, services)
      match msg {
        WebViewEvent(@webview_host.WebViewEvent::NavigationFinished(url)) =>
          on_navigation_finished(url)
        _ => ()
      }
      (next, effect)
    },
    view=(model, view_environment) => {
      view_with_environment(model, view_environment)
    },
  ).with_commands(commands=_model => program_commands())
}
