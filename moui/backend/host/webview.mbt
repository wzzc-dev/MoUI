///|

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
pub(all) struct HostWebViewEvent {
  window_id : HostWindowId
  id : String
  event : WebViewEvent
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
pub struct HostWebViewEventSource {
  priv mut next_handler_value : Int
  priv mut handlers : Array[HostWebViewEventSubscriptionHandler]
}

///|
priv struct HostWebViewEventSubscriptionHandler {
  token : Int
  handle : (HostWebViewEvent) -> Unit
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
  on_event? : ((WebViewEvent) -> Unit)? = None,
) -> WebViewSpec {
  { key: None, id, url, width, height, title, policy, on_event }
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
      value=self.policy.revision_key(),
    ),
  ])
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
pub fn WebViewNavigationPolicy::revision_key(
  self : WebViewNavigationPolicy,
) -> String {
  match self {
    AllowHttpHttpsFile => "http-https-file"
    AllowHttpHttps => "http-https"
    AllowAll => "all"
  }
}

///|
pub fn WebViewNavigationPolicy::from_revision_key(
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
pub fn HostWebViewEvent::new(
  window_id~ : HostWindowId,
  id~ : String,
  event~ : WebViewEvent,
) -> HostWebViewEvent {
  { window_id, id, event }
}

///|
pub fn HostWebViewEventSource::new() -> HostWebViewEventSource {
  { next_handler_value: 1, handlers: [] }
}

///|
pub fn HostWebViewEventSource::active_handler_count(
  self : HostWebViewEventSource,
) -> Int {
  self.handlers.length()
}

///|
pub fn HostWebViewEventSource::publish(
  self : HostWebViewEventSource,
  event : HostWebViewEvent,
) -> Int {
  let handlers = self.handlers.copy()
  for handler in handlers {
    (handler.handle)(event)
  }
  handlers.length()
}

///|
pub fn[Msg] HostWebViewEventSource::subscription(
  self : HostWebViewEventSource,
  key? : String = "host:web-view",
  label? : String = "Host WebView event",
  map~ : (HostWebViewEvent) -> Msg?,
) -> @core.Subscription[Msg] {
  let start = dispatch => {
    let token = self.add_handler(event => {
      match map(event) {
        Some(message) => dispatch(message)
        None => ()
      }
    })
    Some(() => ignore(self.remove_handler(token)))
  }
  @core.Subscription::host_event(key~, label~, start~)
}

///|
fn HostWebViewEventSource::add_handler(
  self : HostWebViewEventSource,
  handle : (HostWebViewEvent) -> Unit,
) -> Int {
  let token = self.next_handler_value
  self.next_handler_value = self.next_handler_value + 1
  self.handlers.push({ token, handle })
  token
}

///|
fn HostWebViewEventSource::remove_handler(
  self : HostWebViewEventSource,
  token : Int,
) -> Bool {
  let before = self.handlers.length()
  let remaining : Array[HostWebViewEventSubscriptionHandler] = []
  for handler in self.handlers {
    if handler.token != token {
      remaining.push(handler)
    }
  }
  self.handlers = remaining
  self.handlers.length() != before
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
