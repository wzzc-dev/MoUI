///|
pub(all) enum WebViewBridgeKind {
  Hello
  Event
  Request
  Response
  Cancel
} derive(Eq, Debug)

///|
pub(all) struct WebViewBridgeEnvelope {
  kind : WebViewBridgeKind
  channel : String
  request_id : WebViewRequestId?
  navigation_id : WebViewNavigationId
  payload : Json
  error : WebViewError?
} derive(Eq, Debug)

///|
pub fn WebViewBridgeEnvelope::event(
  channel~ : String,
  navigation_id~ : WebViewNavigationId,
  payload~ : Json,
) -> WebViewBridgeEnvelope {
  {
    kind: WebViewBridgeKind::Event,
    channel,
    request_id: None,
    navigation_id,
    payload,
    error: None,
  }
}

///|
pub fn WebViewBridgeEnvelope::request(
  channel~ : String,
  request_id~ : WebViewRequestId,
  navigation_id~ : WebViewNavigationId,
  payload~ : Json,
) -> WebViewBridgeEnvelope {
  {
    kind: WebViewBridgeKind::Request,
    channel,
    request_id: Some(request_id),
    navigation_id,
    payload,
    error: None,
  }
}

///|
pub fn WebViewBridgeEnvelope::response(
  request_id~ : WebViewRequestId,
  navigation_id~ : WebViewNavigationId,
  result~ : Result[Json, WebViewError],
) -> WebViewBridgeEnvelope {
  match result {
    Ok(payload) =>
      {
        kind: WebViewBridgeKind::Response,
        channel: "",
        request_id: Some(request_id),
        navigation_id,
        payload,
        error: None,
      }
    Err(error) =>
      {
        kind: WebViewBridgeKind::Response,
        channel: "",
        request_id: Some(request_id),
        navigation_id,
        payload: Json::null(),
        error: Some(error),
      }
  }
}

///|
pub fn WebViewBridgeEnvelope::cancel(
  request_id~ : WebViewRequestId,
  navigation_id~ : WebViewNavigationId,
) -> WebViewBridgeEnvelope {
  {
    kind: WebViewBridgeKind::Cancel,
    channel: "",
    request_id: Some(request_id),
    navigation_id,
    payload: Json::null(),
    error: None,
  }
}

///|
pub fn WebViewBridgeEnvelope::to_json_string(
  self : WebViewBridgeEnvelope,
) -> String {
  let navigation_id = self.navigation_id.to_wire()
  match (self.kind, self.request_id, self.error) {
    (WebViewBridgeKind::Hello, _, _) =>
      (
        {
          "schemaVersion": 1,
          "kind": "hello",
          "navigationId": navigation_id,
          "payload": self.payload,
        } : Json).stringify()
    (WebViewBridgeKind::Event, _, _) =>
      (
        {
          "schemaVersion": 1,
          "kind": "event",
          "channel": self.channel,
          "navigationId": navigation_id,
          "payload": self.payload,
        } : Json).stringify()
    (WebViewBridgeKind::Request, Some(request_id), _) =>
      (
        {
          "schemaVersion": 1,
          "kind": "request",
          "channel": self.channel,
          "requestId": request_id.to_wire(),
          "navigationId": navigation_id,
          "payload": self.payload,
        } : Json).stringify()
    (WebViewBridgeKind::Response, Some(request_id), None) =>
      (
        {
          "schemaVersion": 1,
          "kind": "response",
          "requestId": request_id.to_wire(),
          "navigationId": navigation_id,
          "payload": self.payload,
        } : Json).stringify()
    (WebViewBridgeKind::Response, Some(request_id), Some(error)) =>
      (
        {
          "schemaVersion": 1,
          "kind": "response",
          "requestId": request_id.to_wire(),
          "navigationId": navigation_id,
          "payload": self.payload,
          "error": error,
        } : Json).stringify()
    (WebViewBridgeKind::Cancel, Some(request_id), _) =>
      (
        {
          "schemaVersion": 1,
          "kind": "cancel",
          "requestId": request_id.to_wire(),
          "navigationId": navigation_id,
          "payload": self.payload,
        } : Json).stringify()
    _ =>
      (
        {
          "schemaVersion": 1,
          "kind": "invalid",
          "navigationId": navigation_id,
          "payload": Json::null(),
        } : Json).stringify()
  }
}

///|
pub fn WebViewBridgeEnvelope::parse(
  text : String,
) -> Result[WebViewBridgeEnvelope, WebViewError] {
  let parsed = @json.parse(text) catch {
    _ =>
      return Err(
        WebViewError::new(
          code="invalid-json",
          message="WebView bridge message is not valid JSON",
        ),
      )
  }
  guard parsed is Json::Object(fields) else {
    return Err(
      WebViewError::new(
        code="invalid-envelope",
        message="WebView bridge envelope must be an object",
      ),
    )
  }
  guard webview_json_int(fields.get("schemaVersion")) is Some(1) else {
    return Err(
      WebViewError::new(
        code="unsupported-version",
        message="Unsupported WebView bridge schema version",
      ),
    )
  }
  guard webview_json_string(fields.get("kind")) is Some(kind_text) else {
    return Err(
      WebViewError::new(
        code="invalid-envelope",
        message="WebView bridge kind is required",
      ),
    )
  }
  guard webview_json_wire_u64(fields.get("navigationId"))
    is Some(navigation_raw) &&
    navigation_raw != 0UL else {
    return Err(
      WebViewError::new(
        code="invalid-navigation-id",
        message="WebView bridge navigationId must be a positive decimal string",
      ),
    )
  }
  let navigation_id : WebViewNavigationId = { value: navigation_raw }
  let payload = fields.get("payload").unwrap_or(Json::null())
  let channel = webview_json_string(fields.get("channel")).unwrap_or("")
  let request_id = match fields.get("requestId") {
    None | Some(Json::Null) => None
    value =>
      match webview_json_wire_u64(value) {
        Some(raw) if raw != 0UL => Some(({ value: raw } : WebViewRequestId))
        _ =>
          return Err(
            WebViewError::new(
              code="invalid-request-id",
              message="WebView bridge requestId must be a positive decimal string",
            ),
          )
      }
  }
  let error = match fields.get("error") {
    None | Some(Json::Null) => None
    Some(Json::Object(error_fields)) => {
      guard webview_json_string(error_fields.get("code")) is Some(code) &&
        webview_json_string(error_fields.get("message")) is Some(message) else {
        return Err(
          WebViewError::new(
            code="invalid-error",
            message="WebView bridge error must contain code and message",
          ),
        )
      }
      Some(WebViewError::new(code~, message~))
    }
    _ =>
      return Err(
        WebViewError::new(
          code="invalid-error",
          message="WebView bridge error must be an object",
        ),
      )
  }
  let kind = match kind_text {
    "hello" => WebViewBridgeKind::Hello
    "event" => WebViewBridgeKind::Event
    "request" => WebViewBridgeKind::Request
    "response" => WebViewBridgeKind::Response
    "cancel" => WebViewBridgeKind::Cancel
    _ =>
      return Err(
        WebViewError::new(
          code="unknown-kind",
          message="Unknown WebView bridge kind: " + kind_text,
        ),
      )
  }
  match kind {
    WebViewBridgeKind::Event if channel.is_empty() =>
      return Err(
        WebViewError::new(
          code="invalid-channel",
          message="WebView event channel is required",
        ),
      )
    WebViewBridgeKind::Request if channel.is_empty() || request_id is None =>
      return Err(
        WebViewError::new(
          code="invalid-request",
          message="WebView request requires channel and requestId",
        ),
      )
    WebViewBridgeKind::Response | WebViewBridgeKind::Cancel if request_id
      is None =>
      return Err(
        WebViewError::new(
          code="invalid-response",
          message="WebView response/cancel requires requestId",
        ),
      )
    _ => ()
  }
  Ok({ kind, channel, request_id, navigation_id, payload, error })
}

///|
pub fn WebViewEvent::to_platform_event(
  self : WebViewEvent,
) -> @core.PlatformViewEvent {
  @core.PlatformViewEvent::Named(
    name="moui-webview-v1",
    value=webview_event_to_json(self).stringify(),
    detail="",
    flag=false,
  )
}

///|
pub fn WebViewEvent::from_platform_event(
  event : @core.PlatformViewEvent,
) -> WebViewEvent? {
  guard event is @core.PlatformViewEvent::Named(name~, value~, ..) &&
    name == "moui-webview-v1" else {
    return None
  }
  let parsed = @json.parse(value) catch { _ => return None }
  webview_event_from_json(parsed)
}

///|
pub fn webview_encode_ffi_string(text : String) -> Bytes {
  @utf8.encode(text[:], bom=false)
}

///|
/// Bridge limits are byte limits because native message transports carry UTF-8.
pub fn webview_utf8_size(text : String) -> Int {
  @utf8.encode(text[:], bom=false).length()
}

///|
pub fn webview_decode_ffi_string(bytes : Bytes) -> String {
  @utf8.decode_lossy(bytes[:], ignore_bom=true)
}

///|
pub fn webview_encode_native_command(
  queued : HostWebViewQueuedCommand,
) -> (Int, UInt64, UInt64, String) {
  let navigation_id = match queued.navigation_id {
    Some(value) => value.value()
    None => 0UL
  }
  match queued.command {
    HostWebViewCommand::Navigate(url) =>
      (0, queued.command_id.value(), navigation_id, url)
    HostWebViewCommand::Reload =>
      (1, queued.command_id.value(), navigation_id, "")
    HostWebViewCommand::Stop =>
      (2, queued.command_id.value(), navigation_id, "")
    HostWebViewCommand::GoBack =>
      (3, queued.command_id.value(), navigation_id, "")
    HostWebViewCommand::GoForward =>
      (4, queued.command_id.value(), navigation_id, "")
    HostWebViewCommand::PostMessage(message) =>
      (5, queued.command_id.value(), navigation_id, message)
    HostWebViewCommand::Dispose =>
      (6, queued.command_id.value(), navigation_id, "")
  }
}

///|
pub fn WebViewHost::accept_native_event(
  self : WebViewHost,
  controller_id~ : String,
  kind~ : Int,
  navigation_raw~ : UInt64,
  url~ : String,
  detail~ : String,
  flag~ : Int,
) -> WebViewEvent? {
  guard self.find_state(controller_id) is Some(state) else { return None }
  let native_navigation : WebViewNavigationId? = if navigation_raw == 0UL {
    state.current_navigation
  } else {
    Some({ value: navigation_raw })
  }
  if kind >= 1 && kind <= 4 && native_navigation != state.current_navigation {
    return None
  }
  match kind {
    0 =>
      if webview_policy_allows_url(state.config.security, url) {
        Some(WebViewEvent::NavigationRequested(url))
      } else {
        Some(
          webview_diagnostic_event(
            "navigation-denied", "WebView native navigation request was outside the configured origin policy",
          ),
        )
      }
    1 =>
      native_navigation.map(id => {
        WebViewEvent::NavigationStarted({ id, url, redirected: false })
      })
    2 =>
      native_navigation.map(id => {
        WebViewEvent::NavigationCommitted({ id, url, redirected: false })
      })
    3 =>
      native_navigation.map(id => {
        WebViewEvent::NavigationFinished({ id, url, redirected: false })
      })
    4 =>
      Some(
        WebViewEvent::NavigationFailed(
          native_navigation,
          url,
          WebViewError::new(code="navigation-failed", message=detail),
        ),
      )
    5 => Some(WebViewEvent::TitleChanged(detail))
    6 => Some(WebViewEvent::CanGoBackChanged(flag != 0))
    7 => Some(WebViewEvent::CanGoForwardChanged(flag != 0))
    8 => self.accept_bridge_message(state, native_navigation, url, detail)
    9 =>
      webview_host_patch_report(native_navigation, detail).map(report => {
        WebViewEvent::HostPatchReported(report)
      })
    10 => Some(WebViewEvent::Ready(state.config.capabilities.copy()))
    11 => Some(WebViewEvent::Disposed)
    _ =>
      Some(
        WebViewEvent::Diagnostic({
          code: "unknown-native-event",
          message: "Unknown native WebView event kind: " + kind.to_string(),
        }),
      )
  }
}

///|
fn WebViewHost::accept_bridge_message(
  self : WebViewHost,
  state : WebViewControllerState,
  native_navigation : WebViewNavigationId?,
  source_url : String,
  wire : String,
) -> WebViewEvent? {
  if webview_utf8_size(wire) > state.config.security.max_message_bytes {
    return Some(
      webview_diagnostic_event(
        "message-too-large", "WebView page message exceeds configured byte limit",
      ),
    )
  }
  guard native_navigation is Some(navigation_id) &&
    state.current_navigation == Some(navigation_id) else {
    return None
  }
  guard WebViewOrigin::parse(source_url) is Some(origin) &&
    state.config.security.allowed_origins.contains(origin) else {
    return Some(
      webview_diagnostic_event(
        "origin-denied", "WebView page message came from a disallowed origin",
      ),
    )
  }
  let envelope = match WebViewBridgeEnvelope::parse(wire) {
    Ok(value) => value
    Err(error) =>
      return Some(webview_diagnostic_event(error.code, error.message))
  }
  if envelope.navigation_id != navigation_id {
    return None
  }
  match envelope.kind {
    WebViewBridgeKind::Hello =>
      Some(WebViewEvent::Ready(state.config.capabilities.copy()))
    WebViewBridgeKind::Event =>
      if !webview_channel_allowed(
          state.config.security,
          envelope.channel,
          host_to_page=false,
        ) {
        Some(
          webview_diagnostic_event(
            "channel-denied",
            "WebView page event used a disallowed channel: " + envelope.channel,
          ),
        )
      } else {
        Some(
          WebViewEvent::Message({
            channel: envelope.channel,
            origin,
            navigation_id,
            payload: envelope.payload,
          }),
        )
      }
    WebViewBridgeKind::Request =>
      if !webview_channel_allowed(
          state.config.security,
          envelope.channel,
          host_to_page=false,
        ) {
        Some(
          webview_diagnostic_event(
            "channel-denied",
            "WebView page request used a disallowed channel: " +
            envelope.channel,
          ),
        )
      } else {
        match envelope.request_id {
          Some(request_id) if self.requests.any(item => {
              item.controller_id == state.id && item.request_id == request_id
            }) =>
            Some(
              webview_diagnostic_event(
                "duplicate-request-id", "WebView page request reused a pending requestId",
              ),
            )
          Some(request_id) =>
            Some(
              WebViewEvent::Request({
                id: request_id,
                channel: envelope.channel,
                origin,
                navigation_id,
                payload: envelope.payload,
              }),
            )
          None => None
        }
      }
    WebViewBridgeKind::Response => {
      match envelope.request_id {
        Some(request_id) =>
          match self.remove_request(state.id, request_id) {
            Some(request) if request.navigation_id == navigation_id =>
              match envelope.error {
                Some(error) =>
                  (request.complete)(WebViewTaskResult::Failure(error))
                None =>
                  (request.complete)(
                    WebViewTaskResult::Success(envelope.payload),
                  )
              }
            _ => ()
          }
        None => ()
      }
      None
    }
    WebViewBridgeKind::Cancel => {
      match envelope.request_id {
        Some(request_id) =>
          match self.remove_request(state.id, request_id) {
            Some(request) => (request.complete)(WebViewTaskResult::Cancelled)
            None => ()
          }
        None => ()
      }
      None
    }
  }
}

///|
fn webview_diagnostic_event(code : String, message : String) -> WebViewEvent {
  WebViewEvent::Diagnostic({ code, message })
}

///|
fn webview_event_to_json(event : WebViewEvent) -> Json {
  match event {
    Ready(capabilities) =>
      ({ "kind": "ready", "capabilities": capabilities } : Json)
    NavigationRequested(url) =>
      ({ "kind": "navigation-requested", "url": url } : Json)
    NavigationStarted(navigation) =>
      webview_navigation_event_json("navigation-started", navigation)
    NavigationCommitted(navigation) =>
      webview_navigation_event_json("navigation-committed", navigation)
    NavigationFinished(navigation) =>
      webview_navigation_event_json("navigation-finished", navigation)
    NavigationFailed(id, url, error) =>
      match id {
        Some(value) =>
          (
            {
              "kind": "navigation-failed",
              "navigationId": value.to_wire(),
              "url": url,
              "error": error,
            } : Json)
        None =>
          ({ "kind": "navigation-failed", "url": url, "error": error } : Json)
      }
    TitleChanged(title) => ({ "kind": "title-changed", "title": title } : Json)
    CanGoBackChanged(value) =>
      ({ "kind": "can-go-back-changed", "value": value } : Json)
    CanGoForwardChanged(value) =>
      ({ "kind": "can-go-forward-changed", "value": value } : Json)
    Message(message) =>
      (
        {
          "kind": "message",
          "channel": message.channel,
          "origin": message.origin.value(),
          "navigationId": message.navigation_id.to_wire(),
          "payload": message.payload,
        } : Json)
    Request(request) =>
      (
        {
          "kind": "request",
          "requestId": request.id.to_wire(),
          "channel": request.channel,
          "origin": request.origin.value(),
          "navigationId": request.navigation_id.to_wire(),
          "payload": request.payload,
        } : Json)
    HostPatchReported(report) =>
      (
        {
          "kind": "host-patch-reported",
          "bundleId": report.bundle_id,
          "version": report.version,
          "navigationId": report.navigation_id.to_wire(),
          "success": report.success,
          "detail": report.detail,
        } : Json)
    Diagnostic(diagnostic) =>
      (
        {
          "kind": "diagnostic",
          "code": diagnostic.code,
          "message": diagnostic.message,
        } : Json)
    Disposed => ({ "kind": "disposed" } : Json)
  }
}

///|
fn webview_navigation_event_json(
  kind : String,
  navigation : WebViewNavigation,
) -> Json {
  (
    {
      "kind": kind,
      "navigationId": navigation.id.to_wire(),
      "url": navigation.url,
      "redirected": navigation.redirected,
    } : Json)
}

///|
fn webview_event_from_json(value : Json) -> WebViewEvent? {
  guard value is Json::Object(fields) &&
    webview_json_string(fields.get("kind")) is Some(kind) else {
    return None
  }
  match kind {
    "ready" =>
      Some(
        WebViewEvent::Ready(
          webview_json_string_array(fields.get("capabilities")).unwrap_or([]),
        ),
      )
    "navigation-requested" =>
      webview_json_string(fields.get("url")).map(url => {
        WebViewEvent::NavigationRequested(url)
      })
    "navigation-started" =>
      webview_navigation_from_fields(fields).map(navigation => {
        WebViewEvent::NavigationStarted(navigation)
      })
    "navigation-committed" =>
      webview_navigation_from_fields(fields).map(navigation => {
        WebViewEvent::NavigationCommitted(navigation)
      })
    "navigation-finished" =>
      webview_navigation_from_fields(fields).map(navigation => {
        WebViewEvent::NavigationFinished(navigation)
      })
    "navigation-failed" => {
      guard webview_json_string(fields.get("url")) is Some(url) &&
        webview_error_from_json(fields.get("error")) is Some(error) else {
        return None
      }
      let id = webview_json_wire_u64(fields.get("navigationId")).map(raw => {
        ({ value: raw } : WebViewNavigationId)
      })
      Some(WebViewEvent::NavigationFailed(id, url, error))
    }
    "title-changed" =>
      webview_json_string(fields.get("title")).map(title => {
        WebViewEvent::TitleChanged(title)
      })
    "can-go-back-changed" =>
      webview_json_bool(fields.get("value")).map(value => {
        WebViewEvent::CanGoBackChanged(value)
      })
    "can-go-forward-changed" =>
      webview_json_bool(fields.get("value")).map(value => {
        WebViewEvent::CanGoForwardChanged(value)
      })
    "message" => {
      guard webview_message_fields(fields)
        is Some((channel, origin, navigation_id, payload)) else {
        return None
      }
      Some(WebViewEvent::Message({ channel, origin, navigation_id, payload }))
    }
    "request" => {
      guard webview_message_fields(fields)
        is Some((channel, origin, navigation_id, payload)) &&
        webview_json_wire_u64(fields.get("requestId")) is Some(request_raw) else {
        return None
      }
      Some(
        WebViewEvent::Request({
          id: { value: request_raw },
          channel,
          origin,
          navigation_id,
          payload,
        }),
      )
    }
    "host-patch-reported" => {
      guard webview_json_string(fields.get("bundleId")) is Some(bundle_id) &&
        webview_json_string(fields.get("version")) is Some(version) &&
        webview_json_wire_u64(fields.get("navigationId"))
        is Some(navigation_raw) &&
        webview_json_bool(fields.get("success")) is Some(success) else {
        return None
      }
      Some(
        WebViewEvent::HostPatchReported({
          bundle_id,
          version,
          navigation_id: { value: navigation_raw },
          success,
          detail: webview_json_string(fields.get("detail")).unwrap_or(""),
        }),
      )
    }
    "diagnostic" => {
      guard webview_json_string(fields.get("code")) is Some(code) &&
        webview_json_string(fields.get("message")) is Some(message) else {
        return None
      }
      Some(WebViewEvent::Diagnostic({ code, message }))
    }
    "disposed" => Some(WebViewEvent::Disposed)
    _ => None
  }
}

///|
fn webview_navigation_from_fields(
  fields : Map[String, Json],
) -> WebViewNavigation? {
  guard webview_json_wire_u64(fields.get("navigationId")) is Some(raw) &&
    webview_json_string(fields.get("url")) is Some(url) else {
    return None
  }
  Some({
    id: { value: raw },
    url,
    redirected: webview_json_bool(fields.get("redirected")).unwrap_or(false),
  })
}

///|
fn webview_message_fields(
  fields : Map[String, Json],
) -> (String, WebViewOrigin, WebViewNavigationId, Json)? {
  guard webview_json_string(fields.get("channel")) is Some(channel) &&
    webview_json_string(fields.get("origin")) is Some(origin_text) &&
    WebViewOrigin::parse(origin_text) is Some(origin) &&
    webview_json_wire_u64(fields.get("navigationId")) is Some(raw) else {
    return None
  }
  Some(
    (
      channel,
      origin,
      { value: raw },
      fields.get("payload").unwrap_or(Json::null()),
    ),
  )
}

///|
fn webview_error_from_json(value : Json?) -> WebViewError? {
  guard value is Some(Json::Object(fields)) &&
    webview_json_string(fields.get("code")) is Some(code) &&
    webview_json_string(fields.get("message")) is Some(message) else {
    return None
  }
  Some({ code, message })
}

///|
fn webview_host_patch_report(
  navigation_id : WebViewNavigationId?,
  text : String,
) -> HostPatchReport? {
  guard navigation_id is Some(navigation_id) else { return None }
  let parsed = @json.parse(text) catch { _ => return None }
  guard parsed is Json::Object(fields) &&
    webview_json_string(fields.get("bundleId")) is Some(bundle_id) &&
    webview_json_string(fields.get("version")) is Some(version) else {
    return None
  }
  Some({
    bundle_id,
    version,
    navigation_id,
    success: webview_json_bool(fields.get("success")).unwrap_or(false),
    detail: webview_json_string(fields.get("detail")).unwrap_or(""),
  })
}

///|
fn webview_json_string(value : Json?) -> String? {
  match value {
    Some(Json::String(text)) => Some(text)
    _ => None
  }
}

///|
fn webview_json_bool(value : Json?) -> Bool? {
  match value {
    Some(Json::True) => Some(true)
    Some(Json::False) => Some(false)
    _ => None
  }
}

///|
fn webview_json_int(value : Json?) -> Int? {
  match value {
    Some(Json::Number(number, repr=_)) => {
      let result = number.to_int()
      if result.to_double() == number {
        Some(result)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn webview_json_string_array(value : Json?) -> Array[String]? {
  guard value is Some(Json::Array(values)) else { return None }
  let result = []
  for value in values {
    guard value is Json::String(text) else { return None }
    result.push(text)
  }
  Some(result)
}

///|
fn webview_json_wire_u64(value : Json?) -> UInt64? {
  guard webview_json_string(value) is Some(text) else { return None }
  webview_parse_decimal_u64(text)
}

///|
fn webview_parse_decimal_u64(value : String) -> UInt64? {
  if value.is_empty() {
    return None
  }
  let mut result = 0UL
  for char in value {
    let code = char.to_int()
    if code < '0'.to_int() || code > '9'.to_int() {
      return None
    }
    let digit = (code - '0'.to_int()).to_uint64()
    let next = result * 10UL + digit
    if next < result {
      return None
    }
    result = next
  }
  Some(result)
}

///|
fn webview_parse_origin(url_or_origin : String) -> String? {
  let text = url_or_origin.trim().to_owned().to_lower()
  let chars = text.to_array()
  let mut separator = -1
  for index in 0..<(chars.length() - 2) {
    if chars[index] == ':' && chars[index + 1] == '/' && chars[index + 2] == '/' {
      separator = index
      break
    }
  }
  if separator <= 0 {
    return None
  }
  let scheme = String::from_array(chars[0:separator])
  if scheme != "http" && scheme != "https" {
    return None
  }
  let authority_start = separator + 3
  let mut authority_end = chars.length()
  for index in authority_start..<chars.length() {
    if chars[index] == '/' || chars[index] == '?' || chars[index] == '#' {
      authority_end = index
      break
    }
  }
  if authority_end <= authority_start {
    return None
  }
  let mut authority = String::from_array(chars[authority_start:authority_end])
  if authority.contains("@") ||
    authority.contains("\n") ||
    authority.contains("\r") {
    return None
  }
  if scheme == "http" && authority.has_suffix(":80") {
    let authority_chars = authority.to_array()
    authority = String::from_array(
      authority_chars[0:authority_chars.length() - 3],
    )
  } else if scheme == "https" && authority.has_suffix(":443") {
    let authority_chars = authority.to_array()
    authority = String::from_array(
      authority_chars[0:authority_chars.length() - 4],
    )
  }
  Some(scheme + "://" + authority)
}

///|
fn webview_native_config(
  state : WebViewControllerState,
) -> HostWebViewNativeConfig {
  let origins = state.config.security.allowed_origins
    .map(origin => origin.value())
    .join("\n")
  {
    revision: state.config_revision,
    allowed_origins: origins,
    document_start_script: webview_document_start_script(state.config),
    document_end_script: webview_document_end_script(state.config),
  }
}

///|
fn webview_document_start_script(config : WebViewControllerConfig) -> String {
  let origins_json = config.security.allowed_origins
    .map(origin => origin.value())
    .to_json()
    .stringify()
  let channels_json = config.security.allowed_channels
    .map(channel => channel.name)
    .to_json()
    .stringify()
  let scripts = [webview_bridge_bootstrap(origins_json, channels_json)]
  for patch in config.host_patches {
    match patch.stylesheet {
      Some(stylesheet) =>
        scripts.push(
          webview_patch_wrapper(
            patch,
            webview_stylesheet_script(patch.id, stylesheet),
          ),
        )
      None => ()
    }
    match patch.document_start_script {
      Some(script) => scripts.push(webview_patch_wrapper(patch, script))
      None => ()
    }
  }
  scripts.join("\n")
}

///|
fn webview_document_end_script(config : WebViewControllerConfig) -> String {
  let scripts = []
  for patch in config.host_patches {
    match patch.document_end_script {
      Some(script) => scripts.push(webview_patch_wrapper(patch, script))
      None => ()
    }
  }
  scripts.join("\n")
}

///|
fn webview_patch_wrapper(patch : HostPatchBundle, source : String) -> String {
  let origins = patch.allowed_origins
    .map(origin => origin.value())
    .to_json()
    .stringify()
  "(function(){var allowed=" +
  origins +
  ";if(allowed.indexOf(location.origin)<0)return;try{" +
  source +
  "}catch(error){console.error('MoUI HostPatch " +
  patch.id +
  "@" +
  patch.version +
  " failed',error);}})();"
}

///|
fn webview_stylesheet_script(id : String, stylesheet : String) -> String {
  let id_json = Json::string("moui-host-patch-" + id).stringify()
  let css_json = Json::string(stylesheet).stringify()
  "var install=function(){var node=document.getElementById(" +
  id_json +
  ");if(!node){node=document.createElement('style');node.id=" +
  id_json +
  ";(document.head||document.documentElement).appendChild(node);}node.textContent=" +
  css_json +
  ";};if(document.head){install();}else{document.addEventListener('DOMContentLoaded',install,{once:true});}"
}

///|
fn webview_bridge_bootstrap(
  origins_json : String,
  channels_json : String,
) -> String {
  "(function(){if(window.__mouiBridgeV1)return;var origins=" +
  origins_json +
  ",channels=" +
  channels_json +
  ";if(origins.indexOf(location.origin)<0)return;var next=1,pending=new Map(),listeners=[];function send(value){var text=JSON.stringify(value);if(window.webkit&&window.webkit.messageHandlers&&window.webkit.messageHandlers.mouiBridge){window.webkit.messageHandlers.mouiBridge.postMessage(text);}else if(window.chrome&&window.chrome.webview){window.chrome.webview.postMessage(text);}}function envelope(kind,channel,payload,id){var value={schemaVersion:1,kind:kind,channel:channel||'',navigationId:String(window.__mouiNavigationId||0),payload:payload===undefined?null:payload};if(id!==undefined)value.requestId=String(id);return value;}function receive(value){if(typeof value==='string'){try{value=JSON.parse(value);}catch(_){return;}}if(!value||value.schemaVersion!==1)return;if(value.kind==='response'&&pending.has(value.requestId)){var item=pending.get(value.requestId);pending.delete(value.requestId);value.error?item.reject(value.error):item.resolve(value.payload);return;}listeners.slice().forEach(function(listener){listener(value);});}window.__mouiBridgeReceive=receive;if(window.chrome&&window.chrome.webview){window.chrome.webview.addEventListener('message',function(event){receive(event.data);});}window.__mouiBridgeV1=Object.freeze({post:function(channel,payload){if(channels.indexOf(channel)<0)throw new Error('channel denied');send(envelope('event',channel,payload));},request:function(channel,payload){if(channels.indexOf(channel)<0)return Promise.reject(new Error('channel denied'));var id=next++;return new Promise(function(resolve,reject){pending.set(String(id),{resolve:resolve,reject:reject});send(envelope('request',channel,payload,id));});},respond:function(id,payload,error){var value=envelope('response','',payload,id);if(error)value.error=error;send(value);},onMessage:function(listener){listeners.push(listener);return function(){listeners=listeners.filter(function(item){return item!==listener;});};}});send(envelope('hello','',{capabilities:['event','request','response']}));})();"
}
