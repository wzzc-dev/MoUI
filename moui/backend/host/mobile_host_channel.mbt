///|
pub(all) struct MobileImeRequest {
  revision : Int
  enabled : Bool
  element_id : Int?
  text : String
  caret : Int
  selection : @core.TextRange?
  composition : String?
  composition_cursor : @core.TextRange?
  frame : @core.Rect
  candidate_anchor : @core.Rect
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MobileSemanticsNode {
  element_id : Int
  parent_id : Int?
  role : @core.SemanticsRole
  label : String
  value : String
  description : String
  state : @core.SemanticsState
  actions : Array[@core.SemanticsAction]
  focus_order : Int?
  frame : @core.Rect
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MobileSemanticsSnapshot {
  revision : Int
  root_id : Int
  nodes : Array[MobileSemanticsNode]
} derive(Eq, Debug, ToJson)

///|
pub(all) enum MobileHostUpdate {
  Ime(MobileImeRequest)
  Clipboard(HostPendingServiceRequest)
  Semantics(MobileSemanticsSnapshot)
  Diagnostic(String)
} derive(Eq, Debug, ToJson)

///|
pub(all) enum MobileHostResponse {
  TextInput(@core.TextInputEvent)
  Command(@core.CommandIntent)
  Clipboard(HostServiceRequestId, HostServiceResponse)
  Accessibility(NativeAccessibilityActionRequest)
} derive(Eq, Debug, ToJson)

///|
pub fn mobile_text_input_response(
  kind : Int,
  text : String,
  start : Int,
  end : Int,
) -> MobileHostResponse? {
  let range = @core.TextRange::new(start~, end~)
  match kind {
    0 =>
      Some(
        MobileHostResponse::TextInput(@core.TextInputEvent::InsertText(text)),
      )
    1 =>
      Some(
        MobileHostResponse::TextInput(
          @core.TextInputEvent::ReplaceText(range, text),
        ),
      )
    2 =>
      Some(
        MobileHostResponse::TextInput(@core.TextInputEvent::SetSelection(range)),
      )
    3 =>
      Some(
        MobileHostResponse::TextInput(@core.TextInputEvent::CompositionStart),
      )
    4 =>
      Some(
        MobileHostResponse::TextInput(
          @core.TextInputEvent::CompositionUpdate(
            @core.CompositionUpdate::new(text~, cursor=Some(range)),
          ),
        ),
      )
    5 =>
      Some(
        MobileHostResponse::TextInput(
          @core.TextInputEvent::CompositionEnd(text),
        ),
      )
    6 =>
      Some(
        MobileHostResponse::TextInput(
          @core.TextInputEvent::DeleteSurrounding(start, end),
        ),
      )
    7 =>
      Some(
        MobileHostResponse::TextInput(@core.TextInputEvent::DeleteRange(range)),
      )
    _ => None
  }
}

///|
pub fn mobile_command_response(kind : Int) -> MobileHostResponse? {
  match kind {
    0 => Some(MobileHostResponse::Command(@core.CommandIntent::Copy))
    1 => Some(MobileHostResponse::Command(@core.CommandIntent::Cut))
    2 => Some(MobileHostResponse::Command(@core.CommandIntent::Paste))
    3 => Some(MobileHostResponse::Command(@core.CommandIntent::Submit))
    _ => None
  }
}

///|
pub fn mobile_accessibility_response(
  element_id : Int,
  action : Int,
  value : String,
) -> MobileHostResponse? {
  let action = match action {
    0 => @core.SemanticsAction::Activate
    1 => @core.SemanticsAction::Focus
    2 => @core.SemanticsAction::SetText
    3 => @core.SemanticsAction::Submit
    4 => @core.SemanticsAction::Scroll
    5 => @core.SemanticsAction::Select
    6 => @core.SemanticsAction::Expand
    7 => @core.SemanticsAction::Collapse
    8 => @core.SemanticsAction::Dismiss
    _ => return None
  }
  Some(
    MobileHostResponse::Accessibility(
      NativeAccessibilityActionRequest::new(
        element_id=@core.ElementId::new(element_id),
        action~,
        value=Some(value),
      ),
    ),
  )
}

///|
pub struct MobileHostChannel {
  service_queue : HostServiceAsyncQueue
  mut updates : Array[MobileHostUpdate]
  mut ime_revision : Int
  mut last_text_input : @core.TextInputState?
  mut semantics_revision : Int
  mut last_semantics_nodes : Array[MobileSemanticsNode]
  mut disposed : Bool
}

///|
pub fn MobileImeRequest::from_state(
  revision~ : Int,
  state : @core.TextInputState,
) -> MobileImeRequest {
  let diagnostics = text_input_ime_request_diagnostics(state)
  let selection = match state.selection {
    Some(selection) =>
      Some(mobile_text_range_to_utf16(state.text, selection.normalized()))
    None => None
  }
  let composition_cursor = match (state.composition, state.composition_cursor) {
    (Some(composition), Some(cursor)) =>
      Some(mobile_text_range_to_utf16(composition, cursor))
    _ => None
  }
  {
    revision,
    enabled: state.focused,
    element_id: match state.element_id {
      Some(id) => Some(id.value())
      None => None
    },
    text: state.text,
    caret: mobile_char_index_to_utf16(state.text, diagnostics.cursor),
    selection,
    composition: state.composition,
    composition_cursor,
    frame: state.frame,
    candidate_anchor: diagnostics.candidate_anchor,
  }
}

///|
fn mobile_char_index_to_utf16(text : String, index : Int) -> Int {
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
fn mobile_utf16_to_char_index(
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
    let next = mobile_char_index_to_utf16(text, index + 1)
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
fn mobile_text_range_to_utf16(
  text : String,
  range : @core.TextRange,
) -> @core.TextRange {
  @core.TextRange::new(
    start=mobile_char_index_to_utf16(text, range.start),
    end=mobile_char_index_to_utf16(text, range.end),
  )
}

///|
fn mobile_text_range_from_utf16(
  text : String,
  range : @core.TextRange,
) -> @core.TextRange {
  let normalized = range.normalized()
  @core.TextRange::new(
    start=mobile_utf16_to_char_index(text, normalized.start, round_up=false),
    end=mobile_utf16_to_char_index(text, normalized.end, round_up=true),
  )
}

///|
fn mobile_text_input_from_utf16(
  event : @core.TextInputEvent,
  state : @core.TextInputState,
) -> @core.TextInputEvent {
  match event {
    @core.TextInputEvent::ReplaceText(range, replacement) =>
      @core.TextInputEvent::ReplaceText(
        mobile_text_range_from_utf16(state.text, range),
        replacement,
      )
    @core.TextInputEvent::SetSelection(range) =>
      @core.TextInputEvent::SetSelection(
        mobile_text_range_from_utf16(state.text, range),
      )
    @core.TextInputEvent::DeleteRange(range) =>
      @core.TextInputEvent::DeleteRange(
        mobile_text_range_from_utf16(state.text, range),
      )
    @core.TextInputEvent::DeleteSurrounding(before, after) => {
      let caret_utf16 = mobile_char_index_to_utf16(state.text, state.caret)
      @core.TextInputEvent::DeleteRange(
        mobile_text_range_from_utf16(
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
              Some(mobile_text_range_from_utf16(composition, cursor))
            None => None
          },
        ),
      )
    }
    other => other
  }
}

///|
pub fn MobileHostChannel::new() -> MobileHostChannel {
  {
    service_queue: HostServiceAsyncQueue::new(),
    updates: [],
    ime_revision: 0,
    last_text_input: None,
    semantics_revision: 0,
    last_semantics_nodes: [],
    disposed: false,
  }
}

///|
pub fn MobileHostChannel::disposed(self : MobileHostChannel) -> Bool {
  self.disposed
}

///|
pub fn MobileHostChannel::service_bridge(
  self : MobileHostChannel,
) -> HostServiceBridge {
  HostServiceBridge::new(
    capabilities=HostServiceCapabilities::new(clipboard=true),
    handle=request => {
      if self.disposed {
        HostServiceResponse::Unavailable("mobile host channel is disposed")
      } else {
        self.service_queue.submit(request)
      }
    },
  )
}

///|
pub fn MobileHostChannel::sync(
  self : MobileHostChannel,
  runtime : @runtime.AppRuntime,
) -> Int {
  if self.disposed {
    return 0
  }
  let previous_count = self.updates.length()
  self.sync_text_input(runtime.focused_text_input())
  self.sync_semantics(runtime.semantics())
  for pending in self.service_queue.drain_pending() {
    match pending.request {
      HostServiceRequest::Clipboard(_) =>
        self.updates.push(MobileHostUpdate::Clipboard(pending))
      _ =>
        ignore(
          self.service_queue.complete(
            pending.id,
            HostServiceResponse::Unavailable(
              "mobile host channel only handles clipboard requests",
            ),
          ),
        )
    }
  }
  self.updates.length() - previous_count
}

///|
fn MobileHostChannel::sync_text_input(
  self : MobileHostChannel,
  state : @core.TextInputState,
) -> Unit {
  if self.last_text_input != Some(state) {
    self.ime_revision = self.ime_revision + 1
    self.last_text_input = Some(state)
    self.updates.push(
      MobileHostUpdate::Ime(
        MobileImeRequest::from_state(revision=self.ime_revision, state),
      ),
    )
  }
}

///|
fn MobileHostChannel::sync_semantics(
  self : MobileHostChannel,
  root : @core.SemanticsNode,
) -> Unit {
  let nodes : Array[MobileSemanticsNode] = []
  flatten_mobile_semantics(nodes, root, parent_id=None)
  if nodes != self.last_semantics_nodes {
    self.semantics_revision = self.semantics_revision + 1
    self.last_semantics_nodes = nodes.copy()
    self.updates.push(
      MobileHostUpdate::Semantics({
        revision: self.semantics_revision,
        root_id: root.element_id.value(),
        nodes,
      }),
    )
  }
}

///|
fn flatten_mobile_semantics(
  nodes : Array[MobileSemanticsNode],
  node : @core.SemanticsNode,
  parent_id~ : Int?,
) -> Unit {
  let element_id = node.element_id.value()
  nodes.push({
    element_id,
    parent_id,
    role: node.role,
    label: node.label,
    value: node.value,
    description: node.description,
    state: node.state,
    actions: node.actions.copy(),
    focus_order: node.focus_order,
    frame: node.frame,
  })
  for child in node.children {
    flatten_mobile_semantics(nodes, child, parent_id=Some(element_id))
  }
}

///|
pub fn MobileHostChannel::drain_updates(
  self : MobileHostChannel,
) -> Array[MobileHostUpdate] {
  if self.disposed {
    return []
  }
  let updates = self.updates
  self.updates = []
  updates
}

///|
pub fn MobileHostChannel::drain_updates_json(
  self : MobileHostChannel,
) -> String {
  self
  .drain_updates()
  .map(update => mobile_host_update_json(update))
  .to_json()
  .stringify()
}

///|
pub fn MobileHostChannel::push_diagnostic(
  self : MobileHostChannel,
  message : String,
) -> Bool {
  if self.disposed {
    false
  } else {
    self.updates.push(MobileHostUpdate::Diagnostic(message))
    true
  }
}

///|
fn mobile_host_update_json(update : MobileHostUpdate) -> Json {
  match update {
    MobileHostUpdate::Ime(request) =>
      ({ "kind": "ime", "payload": request.to_json() } : Json)
    MobileHostUpdate::Semantics(snapshot) =>
      ({ "kind": "semantics", "payload": snapshot.to_json() } : Json)
    MobileHostUpdate::Diagnostic(message) =>
      ({ "kind": "diagnostic", "payload": message } : Json)
    MobileHostUpdate::Clipboard(pending) =>
      match pending.request {
        HostServiceRequest::Clipboard(request) =>
          (
            {
              "kind": "clipboard",
              "id": pending.id.value,
              "payload": mobile_clipboard_request_json(request),
            } : Json)
        _ => ({ "kind": "unsupported", "id": pending.id.value } : Json)
      }
  }
}

///|
fn mobile_clipboard_request_json(request : HostClipboardRequest) -> Json {
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
pub fn MobileHostChannel::dispatch_response(
  self : MobileHostChannel,
  response : MobileHostResponse,
  driver : HostRuntimeDriver,
) -> Bool {
  if self.disposed {
    return false
  }
  match response {
    MobileHostResponse::TextInput(event) => {
      let event = mobile_text_input_from_utf16(
        event,
        driver.focused_text_input(),
      )
      ignore(driver.dispatch(HostEvent::TextInput(event)))
      true
    }
    MobileHostResponse::Command(intent) => {
      ignore(
        driver.dispatch_command_with_services(intent, self.service_bridge()),
      )
      true
    }
    MobileHostResponse::Clipboard(id, result) => {
      if !self.service_queue.complete(id, result) {
        return false
      }
      for completion in self.service_queue.drain_completed() {
        ignore(
          driver.dispatch_service_completion(completion, self.service_bridge()),
        )
      }
      true
    }
    MobileHostResponse::Accessibility(request) =>
      driver.dispatch_semantics_action(
        request.element_id,
        request.action,
        value=request.value,
      )
  }
}

///|
pub fn MobileHostChannel::dispose(self : MobileHostChannel) -> Unit {
  if !self.disposed {
    self.disposed = true
    self.updates = []
    self.last_text_input = None
    self.last_semantics_nodes = []
  }
}
