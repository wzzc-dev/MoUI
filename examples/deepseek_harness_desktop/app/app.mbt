///|
using @views {column, container, spacer, text}

///|
using @webview_views {web_view}

///|
/// DSH owns the product UI. This app only supplies a native WebView surface
/// for an already running loopback Host.
pub let default_url = "http://127.0.0.1:3080"

///|
let web_view_id = "dsh-desktop-surface"

///|
pub let request_url_settings_key = "dsh-desktop/request-url"

///|
pub struct Model {
  url : String
  configured_url : String
  title : String
  status : String
  web_view_available : Bool
  web_view_description : String
  settings_ready : Bool
  settings_presented : Bool
  request_url_input : String
  settings_error : String
  settings_saving : Bool
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
  OpenSettings
  RequestUrlChanged(String)
  SaveSettings
  CancelSettings
  SettingsBackdropPressed
  SettingsSaved(String, @services.ServiceTaskResult[Unit])
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
    title: "DeepSeek Harness",
    status: if capability.available {
      "connecting"
    } else {
      "unavailable"
    },
    web_view_available: capability.available,
    web_view_description: capability.description,
    settings_ready: false,
    settings_presented: false,
    request_url_input: initial_url,
    settings_error: "",
    settings_saving: false,
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
        @webview_host.WebViewEvent::NavigationRequested(url) =>
          { ..model, url, status: "loading" }
        @webview_host.WebViewEvent::NavigationStarted(url) =>
          { ..model, url, status: "loading" }
        @webview_host.WebViewEvent::NavigationCommitted(url) =>
          { ..model, url, status: "loaded" }
        @webview_host.WebViewEvent::NavigationFinished(url) =>
          { ..model, url, status: "ready" }
        @webview_host.WebViewEvent::NavigationFailed(_url, reason) =>
          { ..model, status: "failed: " + reason }
        @webview_host.WebViewEvent::TitleChanged(title) => { ..model, title, }
        @webview_host.WebViewEvent::CanGoBackChanged(_value) => model
        @webview_host.WebViewEvent::CanGoForwardChanged(_value) => model
        @webview_host.WebViewEvent::JavaScriptResult(_request_id, _value) =>
          model
      }
    SettingsLoaded(result) => {
      let configured_url = match result {
        @services.ServiceTaskResult::Success(Some(value)) =>
          normalize_request_url(value).unwrap_or(model.configured_url)
        @services.ServiceTaskResult::Success(None)
        | @services.ServiceTaskResult::Failure(_)
        | @services.ServiceTaskResult::Cancelled => model.configured_url
      }
      {
        ..model,
        url: configured_url,
        configured_url,
        request_url_input: configured_url,
        settings_ready: true,
        settings_error: "",
      }
    }
    OpenSettings =>
      {
        ..model,
        settings_presented: true,
        request_url_input: model.configured_url,
        settings_error: "",
        settings_saving: false,
      }
    RequestUrlChanged(value) =>
      if model.settings_saving {
        model
      } else {
        { ..model, request_url_input: value, settings_error: "" }
      }
    SaveSettings =>
      match normalize_request_url(model.request_url_input) {
        Some(value) =>
          {
            ..model,
            request_url_input: value,
            settings_error: "",
            settings_saving: true,
          }
        None =>
          {
            ..model,
            settings_error: "Enter a valid HTTP or HTTPS URL.",
            settings_saving: false,
          }
      }
    CancelSettings =>
      {
        ..model,
        settings_presented: false,
        request_url_input: model.configured_url,
        settings_error: "",
        settings_saving: false,
      }
    SettingsBackdropPressed => model
    SettingsSaved(value, result) =>
      if !model.settings_saving || model.request_url_input != value {
        model
      } else {
        match result {
          @services.ServiceTaskResult::Success(_) =>
            {
              ..model,
              url: value,
              configured_url: value,
              request_url_input: value,
              settings_presented: false,
              settings_error: "",
              settings_saving: false,
              status: "loading",
            }
          @services.ServiceTaskResult::Failure(error) =>
            { ..model, settings_error: error.message, settings_saving: false }
          @services.ServiceTaskResult::Cancelled =>
            {
              ..model,
              settings_error: "Saving was cancelled.",
              settings_saving: false,
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
pub fn view(model : Model) -> @moui.View[Msg] {
  let theme = @views.default_theme()
  let content = if model.web_view_available && model.settings_ready {
    web_view(
      id=web_view_id,
      url=model.url,
      title=model.title,
      policy=@webview_host.WebViewNavigationPolicy::AllowHttpHttps,
      on_event=Some(event => WebViewEvent(event)),
    )
  } else if model.web_view_available {
    loading_view(theme)
  } else {
    unavailable_view(model, theme)
  }
  @views.dialog_host(
    content,
    dialog=Some(settings_dialog(model, theme)),
    presented=model.settings_presented,
    on_backdrop=Some(SettingsBackdropPressed),
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
        text("Request URL").caption(),
        @views.text_field(
          model.request_url_input,
          on_input=value => RequestUrlChanged(value),
          on_submit=Some(SaveSettings),
          placeholder=default_url,
          width=416.0,
          height=40.0,
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
    height=250.0,
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
  ]
}

///|
fn program_commands() -> Array[@moui.ProgramCommand[Msg]] {
  [
    @moui.ProgramCommand::new(
      command=settings_action_command(),
      message=OpenSettings,
    ),
  ]
}

///|
fn request_settings_load(services : @services.AppServices) -> @moui.Effect[Msg] {
  services
  .settings()
  .read(request_url_settings_key)
  .effect(map=result => SettingsLoaded(result))
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
      let value = next.request_url_input
      (
        next,
        services
        .settings()
        .write(request_url_settings_key, value)
        .effect(map=result => SettingsSaved(value, result)),
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
    view=(model, _environment) => view(model),
  ).with_commands(commands=_model => program_commands())
}
