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
  event : @core.WebViewEvent
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HostWebViewQueuedCommand {
  id : String
  command : @core.WebViewCommand
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
pub fn HostWebViewCommandQueue::new() -> HostWebViewCommandQueue {
  { pending: [] }
}

///|
pub fn HostWebViewCommandQueue::enqueue(
  self : HostWebViewCommandQueue,
  id~ : String,
  command~ : @core.WebViewCommand,
) -> Unit {
  self.pending.push({ id, command })
}

///|
pub fn HostWebViewCommandQueue::load_url(
  self : HostWebViewCommandQueue,
  id~ : String,
  url~ : String,
) -> Unit {
  self.enqueue(id~, command=@core.WebViewCommand::LoadUrl(url))
}

///|
pub fn HostWebViewCommandQueue::reload(
  self : HostWebViewCommandQueue,
  id~ : String,
) -> Unit {
  self.enqueue(id~, command=@core.WebViewCommand::Reload)
}

///|
pub fn HostWebViewCommandQueue::stop(
  self : HostWebViewCommandQueue,
  id~ : String,
) -> Unit {
  self.enqueue(id~, command=@core.WebViewCommand::Stop)
}

///|
pub fn HostWebViewCommandQueue::go_back(
  self : HostWebViewCommandQueue,
  id~ : String,
) -> Unit {
  self.enqueue(id~, command=@core.WebViewCommand::GoBack)
}

///|
pub fn HostWebViewCommandQueue::go_forward(
  self : HostWebViewCommandQueue,
  id~ : String,
) -> Unit {
  self.enqueue(id~, command=@core.WebViewCommand::GoForward)
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
    command=@core.WebViewCommand::EvaluateJavaScript(script, request_id),
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
  event~ : @core.WebViewEvent,
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
