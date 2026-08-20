///|
pub(all) enum WebViewNavigationPolicy {
  AllowHttpHttpsFile
  AllowHttpHttps
  AllowAll
} derive(Eq, Debug, ToJson)

///|
pub(all) enum WebViewEvent {
  NavigationRequested(String)
  NavigationStarted(String)
  NavigationCommitted(String)
  NavigationFinished(String)
  NavigationFailed(String, String)
  TitleChanged(String)
  CanGoBackChanged(Bool)
  CanGoForwardChanged(Bool)
  JavaScriptResult(String, String)
} derive(Eq, Debug, ToJson)

///|
pub(all) enum WebViewCommand {
  LoadUrl(String)
  Reload
  Stop
  GoBack
  GoForward
  EvaluateJavaScript(String, String)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct WebViewSpec {
  key : @core.Key?
  id : String
  url : String
  width : Double?
  height : Double?
  title : String
  policy : WebViewNavigationPolicy
  background_color : @core.Color?
  color_scheme : @core.ColorScheme?
  on_event : ((WebViewEvent) -> Unit)?
}

///|
pub(all) struct HostWebViewCapabilities {
  available : Bool
  controlled_navigation : Bool
  commands : Bool
  javascript_evaluation : Bool
  native_embedding : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostWebViewQueuedCommand {
  id : String
  command : WebViewCommand
} derive(Eq, Debug, ToJson)

///|
pub struct HostWebViewCommandQueue {
  priv pending : Array[HostWebViewQueuedCommand]
}

///|
pub fn HostWebViewCapabilities::unavailable(
  description? : String = "Native WebView is unavailable on this host.",
) -> HostWebViewCapabilities {
  {
    available: false,
    controlled_navigation: false,
    commands: false,
    javascript_evaluation: false,
    native_embedding: false,
    description,
  }
}

///|
pub fn HostWebViewCapabilities::native_available(
  javascript_evaluation? : Bool = true,
  description? : String = "Native controlled WebView embedding is available.",
) -> HostWebViewCapabilities {
  {
    available: true,
    controlled_navigation: true,
    commands: true,
    javascript_evaluation,
    native_embedding: true,
    description,
  }
}

///|
pub fn WebViewSpec::new(
  id~ : String,
  url~ : String,
  width? : Double? = None,
  height? : Double? = None,
  title? : String = "",
  policy? : WebViewNavigationPolicy = WebViewNavigationPolicy::AllowHttpHttpsFile,
  background_color? : @core.Color? = None,
  color_scheme? : @core.ColorScheme? = None,
  on_event? : ((WebViewEvent) -> Unit)? = None,
) -> WebViewSpec {
  {
    key: None,
    id,
    url,
    width,
    height,
    title,
    policy,
    background_color,
    color_scheme,
    on_event,
  }
}

///|
pub fn WebViewSpec::allows_url(self : WebViewSpec, url : String) -> Bool {
  match self.policy {
    AllowAll => true
    AllowHttpHttpsFile =>
      web_view_url_has_any_scheme(url, ["http:", "https:", "file:"])
    AllowHttpHttps => web_view_url_has_any_scheme(url, ["http:", "https:"])
  }
}

///|
pub fn WebViewSpec::platform_view_placement(
  self : WebViewSpec,
  frame~ : @core.Rect,
  clip? : @core.Rect? = None,
) -> @core.PlatformViewPlacement {
  @core.PlatformViewPlacement::new(id=self.id, kind="web_view", frame~, clip~, properties=[
    @core.PlatformViewProperty::new(key="url", value=self.url),
    @core.PlatformViewProperty::new(key="title", value=self.title),
    @core.PlatformViewProperty::new(
      key="policy",
      value=self.policy.wire_value(),
    ),
    @core.PlatformViewProperty::new(
      key="background-color",
      value=match self.background_color {
        Some(color) => web_view_color_wire_value(color)
        None => ""
      },
    ),
    @core.PlatformViewProperty::new(
      key="color-scheme",
      value=match self.color_scheme {
        Some(@core.ColorScheme::Dark) => "dark"
        Some(@core.ColorScheme::Light) => "light"
        None => ""
      },
    ),
  ])
}

///|
/// Serialize normalized RGBA channels for native WebView hosts.
pub fn web_view_color_wire_value(color : @core.Color) -> String {
  color.r.to_string() + "," + color.g.to_string() + "," + color.b.to_string() + "," + color.a.to_string()
}

///|
pub fn WebViewCommand::load_url(url : String) -> WebViewCommand {
  LoadUrl(url)
}

///|
pub fn WebViewCommand::evaluate_javascript(
  script~ : String,
  request_id? : String = "",
) -> WebViewCommand {
  EvaluateJavaScript(script, request_id)
}

///|
pub fn WebViewNavigationPolicy::wire_value(
  self : WebViewNavigationPolicy,
) -> String {
  match self {
    AllowHttpHttpsFile => "http-https-file"
    AllowHttpHttps => "http-https"
    AllowAll => "all"
  }
}

///|
pub fn WebViewNavigationPolicy::from_wire_value(
  value : String,
) -> WebViewNavigationPolicy {
  match value {
    "http-https" => AllowHttpHttps
    "all" => AllowAll
    _ => AllowHttpHttpsFile
  }
}

///|
pub fn WebViewEvent::to_platform_event(
  self : WebViewEvent,
) -> @core.PlatformViewEvent {
  match self {
    NavigationRequested(url) =>
      @core.PlatformViewEvent::Named(
        name="navigation-requested",
        value=url,
        detail="",
        flag=false,
      )
    NavigationStarted(url) =>
      @core.PlatformViewEvent::Named(
        name="navigation-started",
        value=url,
        detail="",
        flag=false,
      )
    NavigationCommitted(url) =>
      @core.PlatformViewEvent::Named(
        name="navigation-committed",
        value=url,
        detail="",
        flag=false,
      )
    NavigationFinished(url) =>
      @core.PlatformViewEvent::Named(
        name="navigation-finished",
        value=url,
        detail="",
        flag=false,
      )
    NavigationFailed(url, reason) =>
      @core.PlatformViewEvent::Named(
        name="navigation-failed",
        value=url,
        detail=reason,
        flag=false,
      )
    TitleChanged(title) =>
      @core.PlatformViewEvent::Named(
        name="title-changed",
        value=title,
        detail="",
        flag=false,
      )
    CanGoBackChanged(value) =>
      @core.PlatformViewEvent::Named(
        name="can-go-back-changed",
        value="",
        detail="",
        flag=value,
      )
    CanGoForwardChanged(value) =>
      @core.PlatformViewEvent::Named(
        name="can-go-forward-changed",
        value="",
        detail="",
        flag=value,
      )
    JavaScriptResult(request_id, value) =>
      @core.PlatformViewEvent::Named(
        name="javascript-result",
        value=request_id,
        detail=value,
        flag=false,
      )
  }
}

///|
pub fn WebViewEvent::from_platform_event(
  event : @core.PlatformViewEvent,
) -> WebViewEvent? {
  match event {
    Named(name~, value~, detail~, flag~) =>
      match name {
        "navigation-requested" => Some(NavigationRequested(value))
        "navigation-started" => Some(NavigationStarted(value))
        "navigation-committed" => Some(NavigationCommitted(value))
        "navigation-finished" => Some(NavigationFinished(value))
        "navigation-failed" => Some(NavigationFailed(value, detail))
        "title-changed" => Some(TitleChanged(value))
        "can-go-back-changed" => Some(CanGoBackChanged(flag))
        "can-go-forward-changed" => Some(CanGoForwardChanged(flag))
        "javascript-result" => Some(JavaScriptResult(value, detail))
        _ => None
      }
  }
}

///|
pub fn HostWebViewCommandQueue::new() -> HostWebViewCommandQueue {
  { pending: [] }
}

///|
pub fn HostWebViewCommandQueue::enqueue(
  self : HostWebViewCommandQueue,
  id~ : String,
  command~ : WebViewCommand,
) -> Unit {
  self.pending.push({ id, command })
}

///|
pub fn HostWebViewCommandQueue::load_url(
  self : HostWebViewCommandQueue,
  id~ : String,
  url~ : String,
) -> Unit {
  self.enqueue(id~, command=WebViewCommand::LoadUrl(url))
}

///|
pub fn HostWebViewCommandQueue::reload(
  self : HostWebViewCommandQueue,
  id~ : String,
) -> Unit {
  self.enqueue(id~, command=WebViewCommand::Reload)
}

///|
pub fn HostWebViewCommandQueue::stop(
  self : HostWebViewCommandQueue,
  id~ : String,
) -> Unit {
  self.enqueue(id~, command=WebViewCommand::Stop)
}

///|
pub fn HostWebViewCommandQueue::go_back(
  self : HostWebViewCommandQueue,
  id~ : String,
) -> Unit {
  self.enqueue(id~, command=WebViewCommand::GoBack)
}

///|
pub fn HostWebViewCommandQueue::go_forward(
  self : HostWebViewCommandQueue,
  id~ : String,
) -> Unit {
  self.enqueue(id~, command=WebViewCommand::GoForward)
}

///|
pub fn HostWebViewCommandQueue::evaluate_javascript(
  self : HostWebViewCommandQueue,
  id~ : String,
  script~ : String,
  request_id? : String = "",
) -> Unit {
  self.enqueue(
    id~,
    command=WebViewCommand::EvaluateJavaScript(script, request_id),
  )
}

///|
pub fn HostWebViewCommandQueue::pending_count(
  self : HostWebViewCommandQueue,
) -> Int {
  self.pending.length()
}

///|
pub fn HostWebViewCommandQueue::drain_with_handler(
  self : HostWebViewCommandQueue,
  handle : (HostWebViewQueuedCommand) -> Unit,
) -> Int {
  let commands = self.pending.copy()
  self.pending.clear()
  for command in commands {
    handle(command)
  }
  commands.length()
}

///|
fn web_view_url_has_any_scheme(url : String, schemes : Array[String]) -> Bool {
  let lower = url.to_lower()
  schemes.any(scheme => web_view_string_starts_with(lower, scheme))
}

///|
fn web_view_string_starts_with(text : String, prefix : String) -> Bool {
  let chars = text.to_array()
  let prefix_chars = prefix.to_array()
  if prefix_chars.length() > chars.length() {
    false
  } else {
    for index in 0..<prefix_chars.length() {
      if chars[index] != prefix_chars[index] {
        return false
      }
    }
    true
  }
}
