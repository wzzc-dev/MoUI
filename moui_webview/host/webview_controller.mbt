///|
priv struct WebViewControllerState {
  id : String
  mut config : WebViewControllerConfig
  mut config_revision : UInt64
  mut current_navigation : WebViewNavigationId?
  mut disposed : Bool
}

///|
priv struct PendingWebViewRequest {
  controller_id : String
  request_id : WebViewRequestId
  navigation_id : WebViewNavigationId
  deadline_ms : Int64
  complete : (WebViewTaskResult[Json]) -> Unit
}

///|
pub struct WebViewHost {
  priv controllers : Array[WebViewControllerState]
  priv mut commands : Array[HostWebViewQueuedCommand]
  priv mut requests : Array[PendingWebViewRequest]
  priv mut next_command_id : UInt64
  priv mut next_navigation_id : UInt64
  priv mut next_request_id : UInt64
}

///|
pub struct WebViewController {
  priv host : WebViewHost
  priv id : String
}

///|
pub fn WebViewHost::new() -> WebViewHost {
  {
    controllers: [],
    commands: [],
    requests: [],
    next_command_id: 1UL,
    next_navigation_id: 1UL,
    next_request_id: 1UL,
  }
}

///|
pub fn WebViewHost::create_controller(
  self : WebViewHost,
  id~ : String,
  config? : WebViewControllerConfig = WebViewControllerConfig::new(),
) -> Result[WebViewController, WebViewError] {
  if id.is_empty() {
    return Err(
      WebViewError::new(
        code="invalid-controller-id",
        message="WebView controller id cannot be empty",
      ),
    )
  }
  if self.find_state(id) is Some(_) {
    return Err(
      WebViewError::new(
        code="duplicate-controller-id",
        message="WebView controller id already exists: " + id,
      ),
    )
  }
  match webview_validate_config(config) {
    Some(error) => Err(error)
    None => {
      self.controllers.push({
        id,
        config,
        config_revision: 1UL,
        current_navigation: None,
        disposed: false,
      })
      Ok({ host: self, id })
    }
  }
}

///|
pub fn WebViewController::id(self : WebViewController) -> String {
  self.id
}

///|
pub fn WebViewController::configure(
  self : WebViewController,
  config : WebViewControllerConfig,
) -> WebViewTask[WebViewCommandReceipt] {
  WebViewTask::new(
    key="webview:" + self.id + ":configure",
    label="Configure WebView",
    start=complete => {
      match self.host.configure_controller(self.id, config) {
        Ok(receipt) => complete(WebViewTaskResult::Success(receipt))
        Err(error) => complete(WebViewTaskResult::Failure(error))
      }
      None
    },
  )
}

///|
pub fn WebViewController::navigate(
  self : WebViewController,
  url : String,
) -> WebViewTask[WebViewCommandReceipt] {
  self.command_task(HostWebViewCommand::Navigate(url), navigation=true)
}

///|
pub fn WebViewController::reload(
  self : WebViewController,
) -> WebViewTask[WebViewCommandReceipt] {
  self.command_task(HostWebViewCommand::Reload, navigation=true)
}

///|
pub fn WebViewController::stop(
  self : WebViewController,
) -> WebViewTask[WebViewCommandReceipt] {
  self.command_task(HostWebViewCommand::Stop, navigation=false)
}

///|
pub fn WebViewController::go_back(
  self : WebViewController,
) -> WebViewTask[WebViewCommandReceipt] {
  self.command_task(HostWebViewCommand::GoBack, navigation=true)
}

///|
pub fn WebViewController::go_forward(
  self : WebViewController,
) -> WebViewTask[WebViewCommandReceipt] {
  self.command_task(HostWebViewCommand::GoForward, navigation=true)
}

///|
pub fn WebViewController::post_message(
  self : WebViewController,
  channel~ : String,
  payload~ : Json,
) -> WebViewTask[WebViewCommandReceipt] {
  WebViewTask::new(
    key="webview:" + self.id + ":post:" + channel,
    label="Post WebView message",
    start=complete => {
      match self.host.enqueue_message(self.id, channel, payload) {
        Ok(receipt) => complete(WebViewTaskResult::Success(receipt))
        Err(error) => complete(WebViewTaskResult::Failure(error))
      }
      None
    },
  )
}

///|
pub fn WebViewController::request(
  self : WebViewController,
  channel~ : String,
  payload~ : Json,
  timeout_ms? : Int = 10000,
) -> WebViewTask[Json] {
  WebViewTask::new(
    key="webview:" + self.id + ":request:" + channel,
    label="Request WebView message",
    start=complete => {
      self.host.start_request(
        self.id,
        channel,
        payload,
        timeout_ms.max(1),
        complete,
      )
    },
  )
}

///|
pub fn WebViewController::respond(
  self : WebViewController,
  request_id~ : WebViewRequestId,
  result~ : Result[Json, WebViewError],
) -> WebViewTask[WebViewCommandReceipt] {
  WebViewTask::new(
    key="webview:" + self.id + ":respond:" + request_id.to_wire(),
    label="Respond to WebView request",
    start=complete => {
      match self.host.enqueue_response(self.id, request_id, result) {
        Ok(receipt) => complete(WebViewTaskResult::Success(receipt))
        Err(error) => complete(WebViewTaskResult::Failure(error))
      }
      None
    },
  )
}

///|
pub fn WebViewController::dispose(
  self : WebViewController,
) -> WebViewTask[WebViewCommandReceipt] {
  self.command_task(HostWebViewCommand::Dispose, navigation=false)
}

///|
fn WebViewController::command_task(
  self : WebViewController,
  command : HostWebViewCommand,
  navigation~ : Bool,
) -> WebViewTask[WebViewCommandReceipt] {
  WebViewTask::new(
    key="webview:" + self.id + ":command",
    label="Dispatch WebView command",
    start=complete => {
      match self.host.enqueue_controller_command(self.id, command, navigation) {
        Ok(receipt) => complete(WebViewTaskResult::Success(receipt))
        Err(error) => complete(WebViewTaskResult::Failure(error))
      }
      None
    },
  )
}

///|
pub fn WebViewHost::pending_command_count(self : WebViewHost) -> Int {
  self.commands.length()
}

///|
pub fn WebViewHost::pending_request_count(self : WebViewHost) -> Int {
  self.requests.length()
}

///|
pub fn WebViewHost::drain_commands(
  self : WebViewHost,
  handle : (HostWebViewQueuedCommand) -> Unit,
) -> Int {
  let commands = self.commands
  self.commands = []
  for command in commands {
    handle(command)
  }
  commands.length()
}

///|
pub fn WebViewHost::native_config(
  self : WebViewHost,
  id : String,
) -> HostWebViewNativeConfig? {
  match self.find_state(id) {
    Some(state) if !state.disposed => Some(webview_native_config(state))
    _ => None
  }
}

///|
pub fn WebViewHost::poll_timeouts(self : WebViewHost, now_ms : Int64) -> Int64? {
  let remaining : Array[PendingWebViewRequest] = []
  let mut next : Int64? = None
  for request in self.requests {
    if request.deadline_ms <= now_ms {
      (request.complete)(
        WebViewTaskResult::Failure(
          WebViewError::new(
            code="request-timeout",
            message="WebView request timed out",
          ),
        ),
      )
    } else {
      remaining.push(request)
      match next {
        Some(value) =>
          if request.deadline_ms < value {
            next = Some(request.deadline_ms)
          }
        None => next = Some(request.deadline_ms)
      }
    }
  }
  self.requests = remaining
  next
}

///|
fn WebViewHost::find_state(
  self : WebViewHost,
  id : String,
) -> WebViewControllerState? {
  for state in self.controllers {
    if state.id == id {
      return Some(state)
    }
  }
  None
}

///|
fn WebViewHost::next_command(self : WebViewHost) -> WebViewCommandId {
  let id : WebViewCommandId = { value: self.next_command_id }
  self.next_command_id = self.next_command_id + 1UL
  id
}

///|
fn WebViewHost::next_navigation(self : WebViewHost) -> WebViewNavigationId {
  let id : WebViewNavigationId = { value: self.next_navigation_id }
  self.next_navigation_id = self.next_navigation_id + 1UL
  id
}

///|
fn WebViewHost::next_request(self : WebViewHost) -> WebViewRequestId {
  let id : WebViewRequestId = { value: self.next_request_id }
  self.next_request_id = self.next_request_id + 1UL
  id
}

///|
fn WebViewHost::configure_controller(
  self : WebViewHost,
  id : String,
  config : WebViewControllerConfig,
) -> Result[WebViewCommandReceipt, WebViewError] {
  match webview_validate_config(config) {
    Some(error) => return Err(error)
    None => ()
  }
  guard self.find_state(id) is Some(state) && !state.disposed else {
    return Err(webview_controller_unavailable(id))
  }
  state.config = config
  state.config_revision = state.config_revision + 1UL
  self.cancel_requests(id, WebViewTaskResult::Cancelled)
  Ok({ command_id: self.next_command(), navigation_id: None })
}

///|
fn WebViewHost::enqueue_controller_command(
  self : WebViewHost,
  id : String,
  command : HostWebViewCommand,
  navigation : Bool,
) -> Result[WebViewCommandReceipt, WebViewError] {
  guard self.find_state(id) is Some(state) && !state.disposed else {
    return Err(webview_controller_unavailable(id))
  }
  match command {
    HostWebViewCommand::Navigate(url) =>
      if !webview_policy_allows_url(state.config.security, url) {
        return Err(
          WebViewError::new(
            code="navigation-denied",
            message="WebView security policy blocked URL: " + url,
          ),
        )
      }
    _ => ()
  }
  let command_id = self.next_command()
  let navigation_id = if navigation {
    let value = self.next_navigation()
    state.current_navigation = Some(value)
    self.cancel_requests(id, WebViewTaskResult::Cancelled)
    Some(value)
  } else {
    None
  }
  if command is HostWebViewCommand::Dispose {
    state.disposed = true
    self.cancel_requests(id, WebViewTaskResult::Cancelled)
  }
  self.commands.push({ controller_id: id, command_id, navigation_id, command })
  Ok({ command_id, navigation_id })
}

///|
fn WebViewHost::enqueue_message(
  self : WebViewHost,
  id : String,
  channel : String,
  payload : Json,
) -> Result[WebViewCommandReceipt, WebViewError] {
  guard self.find_state(id) is Some(state) && !state.disposed else {
    return Err(webview_controller_unavailable(id))
  }
  guard state.current_navigation is Some(navigation_id) else {
    return Err(
      WebViewError::new(
        code="not-navigated",
        message="WebView has no active navigation",
      ),
    )
  }
  if !webview_channel_allowed(state.config.security, channel, host_to_page=true) {
    return Err(
      WebViewError::new(
        code="channel-denied",
        message="WebView channel is not allowed for host-to-page messages: " +
          channel,
      ),
    )
  }
  let envelope = WebViewBridgeEnvelope::event(
    channel~,
    navigation_id~,
    payload~,
  )
  let wire = envelope.to_json_string()
  if webview_utf8_size(wire) > state.config.security.max_message_bytes {
    return Err(
      WebViewError::new(
        code="message-too-large",
        message="WebView message exceeds configured byte limit",
      ),
    )
  }
  self.enqueue_wire_message(id, navigation_id, wire)
}

///|
fn WebViewHost::start_request(
  self : WebViewHost,
  id : String,
  channel : String,
  payload : Json,
  timeout_ms : Int,
  complete : (WebViewTaskResult[Json]) -> Unit,
) -> (() -> Unit)? {
  guard self.find_state(id) is Some(state) && !state.disposed else {
    complete(WebViewTaskResult::Failure(webview_controller_unavailable(id)))
    return None
  }
  guard state.current_navigation is Some(navigation_id) else {
    complete(
      WebViewTaskResult::Failure(
        WebViewError::new(
          code="not-navigated",
          message="WebView has no active navigation",
        ),
      ),
    )
    return None
  }
  if !webview_channel_allowed(state.config.security, channel, host_to_page=true) {
    complete(
      WebViewTaskResult::Failure(
        WebViewError::new(
          code="channel-denied",
          message="WebView channel is not allowed for host-to-page requests: " +
            channel,
        ),
      ),
    )
    return None
  }
  if self.requests.length() >= state.config.security.max_pending_requests {
    complete(
      WebViewTaskResult::Failure(
        WebViewError::new(
          code="too-many-requests",
          message="WebView pending request limit reached",
        ),
      ),
    )
    return None
  }
  let request_id = self.next_request()
  let wire = WebViewBridgeEnvelope::request(
    channel~,
    request_id~,
    navigation_id~,
    payload~,
  ).to_json_string()
  if webview_utf8_size(wire) > state.config.security.max_message_bytes {
    complete(
      WebViewTaskResult::Failure(
        WebViewError::new(
          code="message-too-large",
          message="WebView request exceeds configured byte limit",
        ),
      ),
    )
    return None
  }
  ignore(self.enqueue_wire_message(id, navigation_id, wire))
  self.requests.push({
    controller_id: id,
    request_id,
    navigation_id,
    deadline_ms: @env.now().reinterpret_as_int64() + timeout_ms.to_int64(),
    complete,
  })
  Some(() => {
    if self.remove_request(id, request_id) is Some(request) {
      (request.complete)(WebViewTaskResult::Cancelled)
      ignore(
        self.enqueue_wire_message(
          id,
          navigation_id,
          WebViewBridgeEnvelope::cancel(request_id~, navigation_id~).to_json_string(),
        ),
      )
    }
  })
}

///|
fn WebViewHost::enqueue_response(
  self : WebViewHost,
  id : String,
  request_id : WebViewRequestId,
  result : Result[Json, WebViewError],
) -> Result[WebViewCommandReceipt, WebViewError] {
  guard self.find_state(id) is Some(state) && !state.disposed else {
    return Err(webview_controller_unavailable(id))
  }
  guard state.current_navigation is Some(navigation_id) else {
    return Err(
      WebViewError::new(
        code="not-navigated",
        message="WebView has no active navigation",
      ),
    )
  }
  self.enqueue_wire_message(
    id,
    navigation_id,
    WebViewBridgeEnvelope::response(request_id~, navigation_id~, result~).to_json_string(),
  )
}

///|
fn WebViewHost::enqueue_wire_message(
  self : WebViewHost,
  id : String,
  navigation_id : WebViewNavigationId,
  wire : String,
) -> Result[WebViewCommandReceipt, WebViewError] {
  let command_id = self.next_command()
  self.commands.push({
    controller_id: id,
    command_id,
    navigation_id: Some(navigation_id),
    command: HostWebViewCommand::PostMessage(wire),
  })
  Ok({ command_id, navigation_id: Some(navigation_id) })
}

///|
fn WebViewHost::remove_request(
  self : WebViewHost,
  id : String,
  request_id : WebViewRequestId,
) -> PendingWebViewRequest? {
  let remaining = []
  let mut found : PendingWebViewRequest? = None
  for request in self.requests {
    if found is None &&
      request.controller_id == id &&
      request.request_id == request_id {
      found = Some(request)
    } else {
      remaining.push(request)
    }
  }
  self.requests = remaining
  found
}

///|
fn WebViewHost::cancel_requests(
  self : WebViewHost,
  id : String,
  result : WebViewTaskResult[Json],
) -> Unit {
  let remaining = []
  for request in self.requests {
    if request.controller_id == id {
      (request.complete)(result)
    } else {
      remaining.push(request)
    }
  }
  self.requests = remaining
}

///|
fn webview_controller_unavailable(id : String) -> WebViewError {
  WebViewError::new(
    code="controller-unavailable",
    message="WebView controller is missing or disposed: " + id,
  )
}

///|
fn webview_validate_config(config : WebViewControllerConfig) -> WebViewError? {
  let channel_names : Array[String] = []
  for channel in config.security.allowed_channels {
    if !webview_valid_channel_name(channel.name) {
      return Some(
        WebViewError::new(
          code="invalid-channel",
          message="Invalid WebView channel: " + channel.name,
        ),
      )
    }
    if channel_names.contains(channel.name) {
      return Some(
        WebViewError::new(
          code="duplicate-channel",
          message="Duplicate WebView channel: " + channel.name,
        ),
      )
    }
    channel_names.push(channel.name)
  }
  let patch_ids : Array[String] = []
  for patch in config.host_patches {
    if patch.id.is_empty() || patch.version.is_empty() {
      return Some(
        WebViewError::new(
          code="invalid-host-patch",
          message="HostPatch id and version cannot be empty",
        ),
      )
    }
    if patch_ids.contains(patch.id) {
      return Some(
        WebViewError::new(
          code="duplicate-host-patch",
          message="Duplicate HostPatch id: " + patch.id,
        ),
      )
    }
    if patch.allowed_origins.is_empty() {
      return Some(
        WebViewError::new(
          code="empty-host-patch-origin",
          message="HostPatch must declare at least one exact origin: " +
            patch.id,
        ),
      )
    }
    for origin in patch.allowed_origins {
      if !config.security.allowed_origins.contains(origin) {
        return Some(
          WebViewError::new(
            code="host-patch-origin-denied",
            message="HostPatch origin is outside the controller security policy: " +
              origin.value(),
          ),
        )
      }
    }
    patch_ids.push(patch.id)
  }
  None
}

///|
fn webview_valid_channel_name(value : String) -> Bool {
  if value.is_empty() || value.length() > 64 {
    return false
  }
  for char in value {
    let code = char.to_int()
    let alphanumeric = (code >= '0'.to_int() && code <= '9'.to_int()) ||
      (code >= 'A'.to_int() && code <= 'Z'.to_int()) ||
      (code >= 'a'.to_int() && code <= 'z'.to_int())
    if !(alphanumeric || char == '.' || char == '_' || char == '-') {
      return false
    }
  }
  true
}

///|
fn webview_policy_allows_url(
  policy : WebViewSecurityPolicy,
  url : String,
) -> Bool {
  match WebViewOrigin::parse(url) {
    Some(origin) => policy.allowed_origins.contains(origin)
    None => policy.allow_file_urls && url.to_lower().has_prefix("file:")
  }
}

///|
fn webview_channel_allowed(
  policy : WebViewSecurityPolicy,
  channel : String,
  host_to_page~ : Bool,
) -> Bool {
  policy.allowed_channels.any(item => {
    if item.name != channel {
      false
    } else {
      match item.direction {
        WebViewChannelDirection::Bidirectional => true
        WebViewChannelDirection::HostToPage => host_to_page
        WebViewChannelDirection::PageToHost => !host_to_page
      }
    }
  })
}
