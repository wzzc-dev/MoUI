///|
using @views {
  button,
  column,
  expanded,
  row,
  spacer,
  container,
  text,
  text_field,
}
using @webview_views {
  web_view,
}

///|
pub let default_url = "https://example.com/"

///|
let web_view_id = "webview-demo-main"

///|
pub struct Model {
  url : String
  address : String
  title : String
  status : String
  can_go_back : Bool
  can_go_forward : Bool
  js_result : String
  logs : Array[String]
  commands : @webview_host.HostWebViewCommandQueue
  capabilities : @webview_host.HostWebViewCapabilities
}

///|
pub(all) enum Msg {
  AddressChanged(String)
  LoadAddress
  Reload
  Stop
  GoBack
  GoForward
  EvaluateLocation
  WebViewEvent(@webview_host.WebViewEvent)
}

///|
pub fn Model::new(
  commands~ : @webview_host.HostWebViewCommandQueue,
  capabilities~ : @webview_host.HostWebViewCapabilities,
  url? : String = default_url,
) -> Model {
  {
    url,
    address: url,
    title: "MoUI",
    status: if capabilities.available {
      "ready"
    } else {
      "unavailable"
    },
    can_go_back: false,
    can_go_forward: false,
    js_result: "",
    logs: [],
    commands,
    capabilities,
  }
}

///|
pub fn update(model : Model, msg : Msg) -> Model {
  match msg {
    AddressChanged(value) => { ..model, address: value }
    LoadAddress => {
      model.commands.load_url(id=web_view_id, url=model.address)
      model.with_log("load " + model.address).with_url(model.address)
    }
    Reload => {
      model.commands.reload(id=web_view_id)
      model.with_log("reload")
    }
    Stop => {
      model.commands.stop(id=web_view_id)
      model.with_log("stop")
    }
    GoBack => {
      model.commands.go_back(id=web_view_id)
      model.with_log("back")
    }
    GoForward => {
      model.commands.go_forward(id=web_view_id)
      model.with_log("forward")
    }
    EvaluateLocation => {
      model.commands.evaluate_javascript(
        id=web_view_id,
        script="window.location.href",
        request_id="location",
      )
      model.with_log("eval location")
    }
    WebViewEvent(event) => model.apply_web_view_event(event)
  }
}

///|
fn Model::with_url(self : Model, url : String) -> Model {
  { ..self, url, address: url, status: "loading" }
}

///|
fn Model::with_log(self : Model, entry : String) -> Model {
  let logs = [entry]
  for existing in self.logs {
    if logs.length() < 7 {
      logs.push(existing)
    }
  }
  { ..self, logs, }
}

///|
fn Model::apply_web_view_event(
  self : Model,
  event : @webview_host.WebViewEvent,
) -> Model {
  match event {
    @webview_host.WebViewEvent::NavigationRequested(url) =>
      self.with_log("request " + url).with_url(url)
    @webview_host.WebViewEvent::NavigationStarted(url) =>
      { ..self.with_log("start " + url), status: "loading" }
    @webview_host.WebViewEvent::NavigationCommitted(url) =>
      { ..self.with_log("commit " + url), url, address: url, status: "loaded" }
    @webview_host.WebViewEvent::NavigationFinished(url) =>
      { ..self.with_log("finish " + url), url, address: url, status: "done" }
    @webview_host.WebViewEvent::NavigationFailed(url, reason) =>
      { ..self.with_log("failed " + url), status: reason }
    @webview_host.WebViewEvent::TitleChanged(value) =>
      { ..self.with_log("title " + value), title: value }
    @webview_host.WebViewEvent::CanGoBackChanged(value) =>
      { ..self, can_go_back: value }
    @webview_host.WebViewEvent::CanGoForwardChanged(value) =>
      { ..self, can_go_forward: value }
    @webview_host.WebViewEvent::JavaScriptResult(request_id, value) =>
      {
        ..self.with_log("js " + request_id),
        js_result: value,
        status: "script result",
      }
  }
}

///|
pub fn view(model : Model) -> @moui.View[Msg] {
  let theme = @views.default_theme()
  column(
    [
      header(model, theme),
      toolbar(model),
      row(
        [expanded(browser_surface(model, theme)), status_panel(model, theme)],
        spacing=14.0,
      ).expanded(),
    ],
    spacing=14.0,
  )
  .padding(18.0)
  .background(theme.palette.background)
}

///|
fn header(model : Model, theme : @moui.Theme) -> @moui.View[Msg] {
  container(
    row(
      [
        column(
          [
            text("WebView Demo").font(theme.typography.title),
            text(model.title)
            .font(theme.typography.caption)
            .foreground(theme.palette.muted),
          ],
          spacing=4.0,
        ),
        spacer(min_length=12.0),
        status_chip(model, theme),
      ],
      align=@views.CrossAlign::Center,
    ),
    padding=14.0,
  )
}

///|
fn toolbar(model : Model) -> @moui.View[Msg] {
  container(
    row(
      [
        text_field(
          model.address,
          on_input=value => AddressChanged(value),
          on_submit=Some(LoadAddress),
          variant=@views.TextFieldVariant::Outline,
          width=520.0,
          height=36.0,
        ),
        button(
          "Open",
          on_click=LoadAddress,
          variant=@views.ButtonVariant::Primary,
        ),
        command_button("Back", GoBack, enabled=model.can_go_back),
        command_button("Forward", GoForward, enabled=model.can_go_forward),
        button("Reload", on_click=Reload, variant=@views.ButtonVariant::Tonal),
        button("Stop", on_click=Stop, variant=@views.ButtonVariant::Ghost),
        button(
          "Eval",
          on_click=EvaluateLocation,
          variant=@views.ButtonVariant::Outline,
        ),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    ),
    padding=10.0,
  )
}

///|
fn command_button(
  label : String,
  message : Msg,
  enabled~ : Bool,
) -> @moui.View[Msg] {
  if enabled {
    button(label, on_click=message, variant=@views.ButtonVariant::Tonal)
  } else {
    button(label, variant=@views.ButtonVariant::Ghost).disabled()
  }
}

///|
fn browser_surface(model : Model, theme : @moui.Theme) -> @moui.View[Msg] {
  let child = if model.capabilities.available {
    web_view(
      id=web_view_id,
      url=model.url,
      title=model.title,
      on_event=Some(event => WebViewEvent(event)),
    )
  } else {
    unavailable_view(model, theme)
  }
  container(child, padding=8.0)
}

///|
fn unavailable_view(model : Model, theme : @moui.Theme) -> @moui.View[Msg] {
  column(
    [
      spacer(min_length=120.0, weight=0.0),
      text("Native WebView unavailable").font(theme.typography.title),
      text(model.capabilities.description)
      .font(theme.typography.body)
      .foreground(theme.palette.muted),
      spacer(min_length=120.0, weight=0.0),
    ],
    spacing=12.0,
    align=@views.CrossAlign::Center,
  ).background(theme.palette.surface_variant.multiply_alpha(0.45))
}

///|
fn status_panel(model : Model, theme : @moui.Theme) -> @moui.View[Msg] {
  container(
    column(
      [
        text("Status").font(theme.typography.title),
        stat_line("Native", capability_text(model.capabilities)),
        stat_line("State", model.status),
        stat_line("Back", bool_text(model.can_go_back)),
        stat_line("Forward", bool_text(model.can_go_forward)),
        stat_line("JS", compact_text(model.js_result)),
        text("Events").font(theme.typography.control),
        event_log(model.logs, theme),
      ],
      spacing=10.0,
    ),
    width=292.0,
    padding=16.0,
  )
}

///|
fn status_chip(model : Model, theme : @moui.Theme) -> @moui.View[Msg] {
  let (background, foreground) = if model.capabilities.available {
    (theme.palette.primary_container, theme.palette.on_primary_container)
  } else {
    (theme.palette.surface_variant, theme.palette.foreground)
  }
  text(capability_text(model.capabilities))
  .font(theme.typography.control)
  .foreground(foreground)
  .padding(8.0)
  .background(background)
  .corner_radius(6.0)
}

///|
fn stat_line(label : String, value : String) -> @moui.View[Msg] {
  row(
    [text(label).caption().frame(width=74.0), text(value).mono().expanded()],
    spacing=8.0,
    align=@views.CrossAlign::Start,
  )
}

///|
fn event_log(logs : Array[String], theme : @moui.Theme) -> @moui.View[Msg] {
  let children : Array[@moui.View[Msg]] = []
  if logs.is_empty() {
    children.push(text("waiting").caption().foreground(theme.palette.muted))
  } else {
    for entry in logs {
      children.push(text(compact_text(entry)).caption())
    }
  }
  column(children, spacing=6.0)
}

///|
fn capability_text(capabilities : @webview_host.HostWebViewCapabilities) -> String {
  if capabilities.available {
    "available"
  } else {
    "unavailable"
  }
}

///|
fn bool_text(value : Bool) -> String {
  if value {
    "yes"
  } else {
    "no"
  }
}

///|
fn compact_text(value : String) -> String {
  if value.length() > 72 {
    value[:69].to_owned() + "..."
  } else if value == "" {
    "-"
  } else {
    value
  }
}

///|
pub fn program(
  commands~ : @webview_host.HostWebViewCommandQueue,
  capabilities~ : @webview_host.HostWebViewCapabilities,
) -> @moui.Program[Model, Msg] {
  @moui.Program::simple(
    init=Model::new(commands~, capabilities~),
    update~,
    view~,
  )
}
