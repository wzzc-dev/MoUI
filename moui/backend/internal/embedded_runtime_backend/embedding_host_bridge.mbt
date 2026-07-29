///|
using @host {
  type HostPendingServiceRequest,
  type HostCompletedServiceResponse,
  type HostServiceRequestId,
  type HostServiceResponse,
  type PlatformChannelResponse,
  type HostServiceAsyncQueue,
  type HostServiceBridge,
  type HostServiceCapabilities,
  type HostServiceRequest,
  type HostClipboardRequest,
  type HostEvent,
  text_input_ime_request_diagnostics,
}

///|
pub(all) struct EmbeddingImeRequest {
  revision : Int
  enabled : Bool
  text : String
  caret : Int
  selection : @core.TextRange?
  composition : String?
  composition_cursor : @core.TextRange?
  frame : @core.Rect
  candidate_anchor : @core.Rect
} derive(Eq, Debug, ToJson)

///|
pub(all) struct EmbeddingSemanticsNode {
  node_id : @core.SemanticsNodeId
  semantic_id : @core.SemanticId?
  role : @core.SemanticsRole
  level : Int?
  url : String
  label : String
  value : String
  description : String
  state : @core.SemanticsState
  actions : Array[@core.SemanticsActionKind]
  focus_order : Int?
  frame : @core.Rect
  children : Array[@core.SemanticsNodeId]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct EmbeddingSemanticsUpdate {
  kind : String
  generation : @core.SemanticsGeneration
  root : @core.SemanticsNodeId?
  focused : @core.SemanticsNodeId?
  nodes : Array[EmbeddingSemanticsNode]
  removed : Array[@core.SemanticsNodeId]
  issues : Array[@runtime.SemanticsIssue]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct EmbeddingPlatformViewSnapshot {
  revision : Int
  placements : Array[@core.PlatformViewPlacement]
} derive(Eq, Debug, ToJson)

///|
pub(all) enum EmbeddingHostUpdate {
  Ime(EmbeddingImeRequest)
  Clipboard(HostPendingServiceRequest)
  Semantics(EmbeddingSemanticsUpdate)
  Diagnostic(String)
  PlatformViews(EmbeddingPlatformViewSnapshot)
  PlatformChannel(HostPendingServiceRequest)
} derive(Eq, Debug, ToJson)

///|
pub(all) enum EmbeddingHostResponse {
  TextInput(@core.TextInputEvent)
  Command(@core.CommandIntent)
  Clipboard(HostServiceRequestId, HostServiceResponse)
  Accessibility(@runtime.NativeAccessibilityActionRequest)
  PlatformView(Int, String, String, @core.PlatformViewEvent)
  PlatformChannel(HostServiceRequestId, PlatformChannelResponse)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct EmbeddingHostUpdateEnvelope {
  schema_version : Int
  session_generation : Int
  updates : Array[EmbeddingHostUpdate]
} derive(Eq, Debug, ToJson)

///|
pub(all) struct EmbeddingHostResponseEnvelope {
  schema_version : Int
  session_generation : Int
  response : EmbeddingHostResponse
} derive(Eq, Debug, ToJson)

///|
pub fn embedding_text_input_response(
  kind : Int,
  text : String,
  start : Int,
  end : Int,
) -> EmbeddingHostResponse? {
  let range = @core.TextRange::new(start~, end~)
  match kind {
    0 =>
      Some(
        EmbeddingHostResponse::TextInput(@core.TextInputEvent::InsertText(text)),
      )
    1 =>
      Some(
        EmbeddingHostResponse::TextInput(
          @core.TextInputEvent::ReplaceText(range, text),
        ),
      )
    2 =>
      Some(
        EmbeddingHostResponse::TextInput(
          @core.TextInputEvent::SetSelection(range),
        ),
      )
    3 =>
      Some(
        EmbeddingHostResponse::TextInput(@core.TextInputEvent::CompositionStart),
      )
    4 =>
      Some(
        EmbeddingHostResponse::TextInput(
          @core.TextInputEvent::CompositionUpdate(
            @core.CompositionUpdate::new(text~, cursor=Some(range)),
          ),
        ),
      )
    5 =>
      Some(
        EmbeddingHostResponse::TextInput(
          @core.TextInputEvent::CompositionEnd(text),
        ),
      )
    6 =>
      Some(
        EmbeddingHostResponse::TextInput(
          @core.TextInputEvent::DeleteSurrounding(start, end),
        ),
      )
    7 =>
      Some(
        EmbeddingHostResponse::TextInput(
          @core.TextInputEvent::DeleteRange(range),
        ),
      )
    _ => None
  }
}

///|
pub fn embedding_command_response(kind : Int) -> EmbeddingHostResponse? {
  match kind {
    0 => Some(EmbeddingHostResponse::Command(@core.CommandIntent::Copy))
    1 => Some(EmbeddingHostResponse::Command(@core.CommandIntent::Cut))
    2 => Some(EmbeddingHostResponse::Command(@core.CommandIntent::Paste))
    3 => Some(EmbeddingHostResponse::Command(@core.CommandIntent::Submit))
    _ => None
  }
}

///|
pub fn embedding_accessibility_response(
  node_id : @core.SemanticsNodeId,
  generation : @core.SemanticsGeneration,
  action : @core.SemanticsAction,
) -> EmbeddingHostResponse {
  EmbeddingHostResponse::Accessibility(
    @runtime.NativeAccessibilityActionRequest::new(
      node_id~,
      generation~,
      action~,
    ),
  )
}

///|
pub struct EmbeddingHostBridge {
  service_queue : HostServiceAsyncQueue
  session_generation : Int
  mut updates : Array[EmbeddingHostUpdate]
  mut ime_revision : Int
  mut last_text_input : @core.TextInputState?
  mut semantics_cursor : @core.SemanticsGeneration?
  mut platform_view_revision : Int
  mut last_platform_views : Array[@core.PlatformViewPlacement]
  mut disposed : Bool
}

///|
pub fn EmbeddingImeRequest::from_state(
  revision~ : Int,
  state : @core.TextInputState,
) -> EmbeddingImeRequest {
  let diagnostics = text_input_ime_request_diagnostics(state)
  let selection = match state.selection {
    Some(selection) =>
      Some(
        embedded_runtime_text_range_to_utf16(state.text, selection.normalized()),
      )
    None => None
  }
  let composition_cursor = match (state.composition, state.composition_cursor) {
    (Some(composition), Some(cursor)) =>
      Some(embedded_runtime_text_range_to_utf16(composition, cursor))
    _ => None
  }
  {
    revision,
    enabled: state.focused,
    text: state.text,
    caret: embedded_runtime_char_index_to_utf16(state.text, diagnostics.cursor),
    selection,
    composition: state.composition,
    composition_cursor,
    frame: state.frame,
    candidate_anchor: diagnostics.candidate_anchor,
  }
}

///|
fn embedded_runtime_char_index_to_utf16(text : String, index : Int) -> Int {
  let length = text.char_length()
  let index = if index < 0 {
    0
  } else if index > length {
    length
  } else {
    index
  }
  if index == length {
    text.length()
  } else {
    text.offset_of_nth_char(index).unwrap_or(text.length())
  }
}

///|
fn embedded_runtime_utf16_to_char_index(
  text : String,
  offset : Int,
  round_up~ : Bool,
) -> Int {
  let utf16_length = text.length()
  let offset = if offset < 0 {
    0
  } else if offset > utf16_length {
    utf16_length
  } else {
    offset
  }
  let char_length = text.char_length()
  let mut index = 0
  while index < char_length {
    let next = embedded_runtime_char_index_to_utf16(text, index + 1)
    if next == offset {
      return index + 1
    }
    if next > offset {
      return if round_up { index + 1 } else { index }
    }
    index = index + 1
  }
  char_length
}

///|
fn embedded_runtime_text_range_to_utf16(
  text : String,
  range : @core.TextRange,
) -> @core.TextRange {
  @core.TextRange::new(
    start=embedded_runtime_char_index_to_utf16(text, range.start),
    end=embedded_runtime_char_index_to_utf16(text, range.end),
  )
}

///|
fn embedded_runtime_text_range_from_utf16(
  text : String,
  range : @core.TextRange,
) -> @core.TextRange {
  let normalized = range.normalized()
  @core.TextRange::new(
    start=embedded_runtime_utf16_to_char_index(
      text,
      normalized.start,
      round_up=false,
    ),
    end=embedded_runtime_utf16_to_char_index(
      text,
      normalized.end,
      round_up=true,
    ),
  )
}

///|
fn embedded_runtime_text_input_from_utf16(
  event : @core.TextInputEvent,
  state : @core.TextInputState,
) -> @core.TextInputEvent {
  match event {
    @core.TextInputEvent::ReplaceText(range, replacement) =>
      @core.TextInputEvent::ReplaceText(
        embedded_runtime_text_range_from_utf16(state.text, range),
        replacement,
      )
    @core.TextInputEvent::SetSelection(range) =>
      @core.TextInputEvent::SetSelection(
        embedded_runtime_text_range_from_utf16(state.text, range),
      )
    @core.TextInputEvent::DeleteRange(range) =>
      @core.TextInputEvent::DeleteRange(
        embedded_runtime_text_range_from_utf16(state.text, range),
      )
    @core.TextInputEvent::DeleteSurrounding(before, after) => {
      let caret_utf16 = embedded_runtime_char_index_to_utf16(
        state.text,
        state.caret,
      )
      @core.TextInputEvent::DeleteRange(
        embedded_runtime_text_range_from_utf16(
          state.text,
          @core.TextRange::new(
            start=caret_utf16 - before,
            end=caret_utf16 + after,
          ),
        ),
      )
    }
    @core.TextInputEvent::CompositionUpdate(update) => {
      let composition = update.text()
      @core.TextInputEvent::CompositionUpdate(
        @core.CompositionUpdate::new(
          text=composition,
          cursor=match update.cursor() {
            Some(cursor) =>
              Some(embedded_runtime_text_range_from_utf16(composition, cursor))
            None => None
          },
        ),
      )
    }
    other => other
  }
}

///|
pub fn EmbeddingHostBridge::new(
  session_generation? : Int = 1,
) -> EmbeddingHostBridge {
  {
    service_queue: HostServiceAsyncQueue::new(),
    session_generation: session_generation.max(1),
    updates: [],
    ime_revision: 0,
    last_text_input: None,
    semantics_cursor: None,
    platform_view_revision: 0,
    last_platform_views: [],
    disposed: false,
  }
}

///|
pub fn EmbeddingHostBridge::session_generation(
  self : EmbeddingHostBridge,
) -> Int {
  self.session_generation
}

///|
pub fn EmbeddingHostResponseEnvelope::new(
  session_generation~ : Int,
  response~ : EmbeddingHostResponse,
) -> EmbeddingHostResponseEnvelope {
  { schema_version: 1, session_generation, response }
}

///|
pub fn EmbeddingHostBridge::disposed(self : EmbeddingHostBridge) -> Bool {
  self.disposed
}

///|
pub fn EmbeddingHostBridge::service_bridge(
  self : EmbeddingHostBridge,
) -> HostServiceBridge {
  HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(clipboard=true),
    handle=request => {
      if self.disposed {
        HostServiceResponse::Unavailable(
          "embedded runtime host channel is disposed",
        )
      } else {
        self.service_queue.submit(request)
      }
    },
  )
}

///|
pub fn EmbeddingHostBridge::sync(
  self : EmbeddingHostBridge,
  runtime : @runtime.AppRuntime,
) -> Int {
  if self.disposed {
    return 0
  }
  let previous_count = self.updates.length()
  self.sync_text_input(runtime.focused_text_input())
  self.sync_semantics(runtime)
  for pending in self.service_queue.drain_pending() {
    match pending.request {
      HostServiceRequest::Clipboard(_) =>
        self.updates.push(EmbeddingHostUpdate::Clipboard(pending))
      HostServiceRequest::PlatformChannel(_) =>
        self.updates.push(EmbeddingHostUpdate::PlatformChannel(pending))
      _ =>
        ignore(
          self.service_queue.complete(
            pending.id,
            HostServiceResponse::Unavailable(
              "embedded runtime host channel only handles clipboard requests",
            ),
          ),
        )
    }
  }
  self.updates.length() - previous_count
}

///|
pub fn EmbeddingHostBridge::sync_platform_views(
  self : EmbeddingHostBridge,
  placements : Array[@core.PlatformViewPlacement],
) -> Bool {
  if self.disposed || placements == self.last_platform_views {
    false
  } else {
    self.platform_view_revision = self.platform_view_revision + 1
    self.last_platform_views = placements.copy()
    self.updates.push(
      EmbeddingHostUpdate::PlatformViews({
        revision: self.platform_view_revision,
        placements: placements.copy(),
      }),
    )
    true
  }
}

///|
fn EmbeddingHostBridge::sync_text_input(
  self : EmbeddingHostBridge,
  state : @core.TextInputState,
) -> Unit {
  if self.last_text_input != Some(state) {
    self.ime_revision = self.ime_revision + 1
    self.last_text_input = Some(state)
    self.updates.push(
      EmbeddingHostUpdate::Ime(
        EmbeddingImeRequest::from_state(revision=self.ime_revision, state),
      ),
    )
  }
}

///|
fn EmbeddingHostBridge::sync_semantics(
  self : EmbeddingHostBridge,
  runtime : @runtime.AppRuntime,
) -> Unit {
  let read = match self.semantics_cursor {
    Some(cursor) => runtime.read_semantics(since=cursor)
    None => runtime.read_semantics()
  }
  match read {
    Ok(read) =>
      match embedding_semantics_update(read) {
        Some(update) => {
          self.semantics_cursor = Some(update.generation)
          self.updates.push(EmbeddingHostUpdate::Semantics(update))
        }
        None => ()
      }
    Err(_) => ()
  }
}

///|
pub fn EmbeddingHostBridge::drain_updates(
  self : EmbeddingHostBridge,
) -> Array[EmbeddingHostUpdate] {
  if self.disposed {
    return []
  }
  let updates = self.updates
  self.updates = []
  updates
}

///|
pub fn EmbeddingHostBridge::drain_updates_json(
  self : EmbeddingHostBridge,
) -> String {
  self
  .drain_updates()
  .map(update => embedding_host_update_json(update))
  .to_json()
  .stringify()
}

///|
pub fn EmbeddingHostBridge::drain_update_envelope(
  self : EmbeddingHostBridge,
) -> EmbeddingHostUpdateEnvelope {
  {
    schema_version: 1,
    session_generation: self.session_generation,
    updates: self.drain_updates(),
  }
}

///|
pub fn EmbeddingHostBridge::drain_update_envelope_json(
  self : EmbeddingHostBridge,
) -> String {
  let envelope = self.drain_update_envelope()
  (
    {
      "schemaVersion": envelope.schema_version,
      "sessionGeneration": envelope.session_generation,
      "updates": envelope.updates.map(embedding_host_update_json),
    } : Json).stringify()
}

///|
pub fn EmbeddingHostBridge::push_diagnostic(
  self : EmbeddingHostBridge,
  message : String,
) -> Bool {
  if self.disposed {
    false
  } else {
    self.updates.push(EmbeddingHostUpdate::Diagnostic(message))
    true
  }
}

///|
fn embedding_host_update_json(update : EmbeddingHostUpdate) -> Json {
  match update {
    EmbeddingHostUpdate::Ime(request) =>
      ({ "kind": "ime", "payload": request.to_json() } : Json)
    EmbeddingHostUpdate::Semantics(snapshot) =>
      ({ "kind": "semantics", "payload": snapshot.to_json() } : Json)
    EmbeddingHostUpdate::Diagnostic(message) =>
      ({ "kind": "diagnostic", "payload": message } : Json)
    EmbeddingHostUpdate::PlatformViews(snapshot) =>
      ({ "kind": "platform-views", "payload": snapshot.to_json() } : Json)
    EmbeddingHostUpdate::PlatformChannel(pending) =>
      match pending.request {
        HostServiceRequest::PlatformChannel(request) =>
          (
            {
              "kind": "platform-channel",
              "id": pending.id.value,
              "payload": request.to_json(),
            } : Json)
        _ => ({ "kind": "unsupported", "id": pending.id.value } : Json)
      }
    EmbeddingHostUpdate::Clipboard(pending) =>
      match pending.request {
        HostServiceRequest::Clipboard(request) =>
          (
            {
              "kind": "clipboard",
              "id": pending.id.value,
              "payload": embedded_runtime_clipboard_request_json(request),
            } : Json)
        _ => ({ "kind": "unsupported", "id": pending.id.value } : Json)
      }
  }
}

///|
/// Transfers pending MoUI updates into the host-owned neutral transport.
pub fn EmbeddingHostBridge::flush_updates_to_shell(
  self : EmbeddingHostBridge,
  transport : @host_session.HostSessionTransport,
) -> Int {
  let updates = self.drain_updates()
  for update in updates {
    let payload = embedding_host_update_json(update)
    match update {
      EmbeddingHostUpdate::Clipboard({ id, .. })
      | EmbeddingHostUpdate::PlatformChannel({ id, .. }) => {
        ignore(transport.track_request(id=id.value))
        ignore(
          match payload {
            Json::Object(fields) =>
              match fields.get("payload") {
                Some(payload) =>
                  ignore(
                    transport.enqueue_tracked_update(
                      kind=match update {
                        EmbeddingHostUpdate::Clipboard(_) => "clipboard"
                        _ => "platform-channel"
                      },
                      payload~,
                      request_id=id.value,
                    ),
                  )
                None => ()
              }
            _ => ()
          },
        )
      }
      _ =>
        match payload {
          Json::Object(fields) => {
            let kind = match fields.get("kind") {
              Some(Json::String(kind)) => kind
              _ => "diagnostic"
            }
            match fields.get("payload") {
              Some(payload) => ignore(transport.enqueue_update(kind~, payload~))
              None => ()
            }
          }
          _ => ()
        }
    }
  }
  updates.length()
}

///|
pub fn embedding_host_response_request_id(
  response : EmbeddingHostResponse,
) -> Int? {
  match response {
    EmbeddingHostResponse::Clipboard(id, _)
    | EmbeddingHostResponse::PlatformChannel(id, _) => Some(id.value)
    _ => None
  }
}

///|
fn embedded_runtime_clipboard_request_json(
  request : HostClipboardRequest,
) -> Json {
  match request {
    HostClipboardRequest::ReadText => ({ "operation": "read-text" } : Json)
    HostClipboardRequest::WriteText(text) =>
      ({ "operation": "write-text", "text": text } : Json)
    HostClipboardRequest::ReadImage => ({ "operation": "read-image" } : Json)
    HostClipboardRequest::WriteImage(mime, bytes) =>
      (
        { "operation": "write-image", "mime": mime, "bytes": bytes.to_json() } :
        Json)
  }
}

///|
pub fn EmbeddingHostBridge::dispatch_response(
  self : EmbeddingHostBridge,
  response : EmbeddingHostResponse,
  driver : @runtime.HostRuntimeDriver,
) -> Bool {
  if self.disposed {
    return false
  }
  match response {
    EmbeddingHostResponse::TextInput(event) => {
      let event = embedded_runtime_text_input_from_utf16(
        event,
        driver.focused_text_input(),
      )
      ignore(driver.dispatch(HostEvent::TextInput(event)))
      true
    }
    EmbeddingHostResponse::Command(intent) => {
      ignore(
        driver.dispatch_command_with_services(intent, self.service_bridge()),
      )
      true
    }
    EmbeddingHostResponse::Clipboard(id, result) =>
      self.complete_service_response(id, result, driver)
    EmbeddingHostResponse::Accessibility(request) =>
      match driver.perform_semantics_action(request) {
        @runtime.NativeAccessibilityActionResult::Handled(_) => true
        @runtime.NativeAccessibilityActionResult::Rejected(_)
        | @runtime.NativeAccessibilityActionResult::BridgeUnavailable(_) =>
          false
      }
    EmbeddingHostResponse::PlatformView(revision, kind, id, event) => {
      if revision != self.platform_view_revision ||
        !self.last_platform_views.any(placement => {
          placement.kind == kind && placement.id == id
        }) {
        return false
      }
      driver.dispatch_platform_view(id, event)
      true
    }
    EmbeddingHostResponse::PlatformChannel(id, response) =>
      self.complete_service_response(
        id,
        HostServiceResponse::PlatformChannel(response),
        driver,
      )
  }
}

///|
fn EmbeddingHostBridge::complete_service_response(
  self : EmbeddingHostBridge,
  id : HostServiceRequestId,
  response : HostServiceResponse,
  driver : @runtime.HostRuntimeDriver,
) -> Bool {
  if !self.service_queue.complete(id, response) {
    return false
  }
  for completion in self.service_queue.drain_completed() {
    ignore(
      driver.dispatch_service_completion(completion, self.service_bridge()),
    )
  }
  true
}

///|
pub fn EmbeddingHostBridge::dispatch_response_envelope(
  self : EmbeddingHostBridge,
  envelope : EmbeddingHostResponseEnvelope,
  driver : @runtime.HostRuntimeDriver,
) -> Bool {
  if envelope.schema_version != 1 ||
    envelope.session_generation != self.session_generation {
    false
  } else {
    self.dispatch_response(envelope.response, driver)
  }
}
