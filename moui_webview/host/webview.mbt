///|
pub struct WebViewCommandId {
  priv value : UInt64
} derive(Eq, Compare, Hash, Debug)

///|
pub struct WebViewNavigationId {
  priv value : UInt64
} derive(Eq, Compare, Hash, Debug)

///|
pub struct WebViewRequestId {
  priv value : UInt64
} derive(Eq, Compare, Hash, Debug)

///|
pub fn WebViewCommandId::to_wire(self : WebViewCommandId) -> String {
  self.value.to_string(radix=10)
}

///|
pub fn WebViewNavigationId::to_wire(self : WebViewNavigationId) -> String {
  self.value.to_string(radix=10)
}

///|
pub fn WebViewRequestId::to_wire(self : WebViewRequestId) -> String {
  self.value.to_string(radix=10)
}

///|
pub fn WebViewCommandId::value(self : WebViewCommandId) -> UInt64 {
  self.value
}

///|
pub fn WebViewNavigationId::value(self : WebViewNavigationId) -> UInt64 {
  self.value
}

///|
pub fn WebViewRequestId::value(self : WebViewRequestId) -> UInt64 {
  self.value
}

///|
pub struct WebViewOrigin {
  priv value : String
} derive(Eq, Compare, Hash, Debug)

///|
pub fn WebViewOrigin::parse(url_or_origin : String) -> WebViewOrigin? {
  webview_parse_origin(url_or_origin).map(value => { value, })
}

///|
pub fn WebViewOrigin::value(self : WebViewOrigin) -> String {
  self.value
}

///|
pub(all) enum WebViewChannelDirection {
  PageToHost
  HostToPage
  Bidirectional
} derive(Eq, Debug, ToJson)

///|
pub(all) struct WebViewChannelPolicy {
  name : String
  direction : WebViewChannelDirection
} derive(Eq, Debug, ToJson)

///|
pub fn WebViewChannelPolicy::new(
  name~ : String,
  direction? : WebViewChannelDirection = WebViewChannelDirection::Bidirectional,
) -> WebViewChannelPolicy {
  { name, direction }
}

///|
pub(all) struct WebViewSecurityPolicy {
  allowed_origins : Array[WebViewOrigin]
  allowed_channels : Array[WebViewChannelPolicy]
  allow_file_urls : Bool
  max_message_bytes : Int
  max_pending_requests : Int
} derive(Eq, Debug)

///|
pub fn WebViewSecurityPolicy::deny_all() -> WebViewSecurityPolicy {
  {
    allowed_origins: [],
    allowed_channels: [],
    allow_file_urls: false,
    max_message_bytes: 256 * 1024,
    max_pending_requests: 64,
  }
}

///|
pub fn WebViewSecurityPolicy::new(
  allowed_origins? : Array[WebViewOrigin] = [],
  allowed_channels? : Array[WebViewChannelPolicy] = [],
  allow_file_urls? : Bool = false,
  max_message_bytes? : Int = 256 * 1024,
  max_pending_requests? : Int = 64,
) -> WebViewSecurityPolicy {
  {
    allowed_origins,
    allowed_channels,
    allow_file_urls,
    max_message_bytes: max_message_bytes.max(1),
    max_pending_requests: max_pending_requests.max(1),
  }
}

///|
pub(all) struct HostPatchBundle {
  id : String
  version : String
  allowed_origins : Array[WebViewOrigin]
  stylesheet : String?
  document_start_script : String?
  document_end_script : String?
} derive(Eq, Debug)

///|
pub fn HostPatchBundle::new(
  id~ : String,
  version~ : String,
  allowed_origins~ : Array[WebViewOrigin],
  stylesheet? : String? = None,
  document_start_script? : String? = None,
  document_end_script? : String? = None,
) -> HostPatchBundle {
  {
    id,
    version,
    allowed_origins,
    stylesheet,
    document_start_script,
    document_end_script,
  }
}

///|
pub(all) struct WebViewControllerConfig {
  security : WebViewSecurityPolicy
  capabilities : Array[String]
  host_patches : Array[HostPatchBundle]
} derive(Eq, Debug)

///|
pub fn WebViewControllerConfig::new(
  security? : WebViewSecurityPolicy = WebViewSecurityPolicy::deny_all(),
  capabilities? : Array[String] = [],
  host_patches? : Array[HostPatchBundle] = [],
) -> WebViewControllerConfig {
  { security, capabilities, host_patches }
}

///|
pub(all) struct WebViewError {
  code : String
  message : String
} derive(Eq, Debug, ToJson)

///|
pub fn WebViewError::new(code~ : String, message~ : String) -> WebViewError {
  { code, message }
}

///|
pub(all) enum WebViewTaskResult[T] {
  Success(T)
  Failure(WebViewError)
  Cancelled
} derive(Eq, Debug)

///|
pub struct WebViewTask[T] {
  key : String
  label : String
  start_fn : ((WebViewTaskResult[T]) -> Unit) -> (() -> Unit)?
}

///|
pub fn[T] WebViewTask::new(
  key~ : String,
  start~ : ((WebViewTaskResult[T]) -> Unit) -> (() -> Unit)?,
  label? : String = "",
) -> WebViewTask[T] {
  { key, label, start_fn: start }
}

///|
pub fn[T] WebViewTask::start(
  self : WebViewTask[T],
  complete : (WebViewTaskResult[T]) -> Unit,
) -> (() -> Unit)? {
  (self.start_fn)(complete)
}

///|
pub fn[T, Msg] WebViewTask::effect(
  self : WebViewTask[T],
  map~ : (WebViewTaskResult[T]) -> Msg,
) -> @core.Effect[Msg] {
  @core.Effect::service_task(key=self.key, label=self.label, start=dispatch => {
    self.start(result => dispatch(map(result)))
  })
}

///|
pub(all) struct WebViewCommandReceipt {
  command_id : WebViewCommandId
  navigation_id : WebViewNavigationId?
} derive(Eq, Debug)

///|
pub(all) struct WebViewNavigation {
  id : WebViewNavigationId
  url : String
  redirected : Bool
} derive(Eq, Debug)

///|
pub(all) struct WebViewBridgeMessage {
  channel : String
  origin : WebViewOrigin
  navigation_id : WebViewNavigationId
  payload : Json
} derive(Eq, Debug)

///|
pub(all) struct WebViewPageRequest {
  id : WebViewRequestId
  channel : String
  origin : WebViewOrigin
  navigation_id : WebViewNavigationId
  payload : Json
} derive(Eq, Debug)

///|
pub(all) struct HostPatchReport {
  bundle_id : String
  version : String
  navigation_id : WebViewNavigationId
  success : Bool
  detail : String
} derive(Eq, Debug)

///|
pub(all) struct WebViewDiagnostic {
  code : String
  message : String
} derive(Eq, Debug, ToJson)

///|
pub(all) enum WebViewEvent {
  Ready(Array[String])
  NavigationRequested(String)
  NavigationStarted(WebViewNavigation)
  NavigationCommitted(WebViewNavigation)
  NavigationFinished(WebViewNavigation)
  NavigationFailed(WebViewNavigationId?, String, WebViewError)
  TitleChanged(String)
  CanGoBackChanged(Bool)
  CanGoForwardChanged(Bool)
  Message(WebViewBridgeMessage)
  Request(WebViewPageRequest)
  HostPatchReported(HostPatchReport)
  Diagnostic(WebViewDiagnostic)
  Disposed
} derive(Eq, Debug)

///|
pub(all) struct HostWebViewCapabilities {
  available : Bool
  controlled_navigation : Bool
  commands : Bool
  messaging : Bool
  host_patch : Bool
  native_embedding : Bool
  description : String
} derive(Eq, Debug, ToJson)

///|
pub fn HostWebViewCapabilities::unavailable(
  description? : String = "Native WebView is unavailable on this host.",
) -> HostWebViewCapabilities {
  {
    available: false,
    controlled_navigation: false,
    commands: false,
    messaging: false,
    host_patch: false,
    native_embedding: false,
    description,
  }
}

///|
pub fn HostWebViewCapabilities::native_available(
  description? : String = "Native controlled WebView embedding is available.",
) -> HostWebViewCapabilities {
  {
    available: true,
    controlled_navigation: true,
    commands: true,
    messaging: true,
    host_patch: true,
    native_embedding: true,
    description,
  }
}

///|
pub(all) enum HostWebViewCommand {
  Navigate(String)
  Reload
  Stop
  GoBack
  GoForward
  PostMessage(String)
  Dispose
} derive(Eq, Debug)

///|
pub(all) struct HostWebViewQueuedCommand {
  controller_id : String
  command_id : WebViewCommandId
  navigation_id : WebViewNavigationId?
  command : HostWebViewCommand
} derive(Eq, Debug)

///|
pub(all) struct HostWebViewNativeConfig {
  revision : UInt64
  allowed_origins : String
  document_start_script : String
  document_end_script : String
} derive(Eq, Debug)

///|
pub(all) struct WebViewSpec {
  id : String
  width : Double?
  height : Double?
  title : String
  visible : Bool
  background_color : @core.Color?
  color_scheme : @core.ColorScheme?
}

///|
pub fn WebViewSpec::new(
  id~ : String,
  width? : Double? = None,
  height? : Double? = None,
  title? : String = "",
  visible? : Bool = true,
  background_color? : @core.Color? = None,
  color_scheme? : @core.ColorScheme? = None,
) -> WebViewSpec {
  { id, width, height, title, visible, background_color, color_scheme }
}

///|
pub fn WebViewSpec::platform_view_placement(
  self : WebViewSpec,
  frame~ : @core.Rect,
  clip? : @core.Rect? = None,
) -> @core.PlatformViewPlacement {
  @core.PlatformViewPlacement::new(id=self.id, kind="web_view", frame~, clip~, properties=[
    @core.PlatformViewProperty::new(key="title", value=self.title),
    @core.PlatformViewProperty::new(
      key="visible",
      value=if self.visible { "true" } else { "false" },
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
pub fn web_view_color_wire_value(color : @core.Color) -> String {
  color.r.to_string() +
  "," +
  color.g.to_string() +
  "," +
  color.b.to_string() +
  "," +
  color.a.to_string()
}
