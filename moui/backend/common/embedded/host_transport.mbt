///|
fn wire_object(value : Json?) -> Map[String, Json]? {
  match value {
    Some(Json::Object(fields)) => Some(fields)
    _ => None
  }
}

///|
fn wire_string(value : Json?, allow_empty? : Bool = false) -> String? {
  match value {
    Some(Json::String(text)) if allow_empty || text != "" => Some(text)
    _ => None
  }
}

///|
fn wire_int(value : Json?) -> Int? {
  match value {
    Some(Json::Number(number, repr=_)) => {
      let integer = number.to_int()
      if integer.to_double() == number {
        Some(integer)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn wire_bool(value : Json?) -> Bool? {
  match value {
    Some(Json::True) => Some(true)
    Some(Json::False) => Some(false)
    _ => None
  }
}

///|
fn wire_fields_are_exact(
  fields : Map[String, Json],
  allowed : Array[String],
) -> Bool {
  for name, _ in fields {
    if !allowed.contains(name) {
      return false
    }
  }
  true
}

///|
fn wire_decimal_u64(value : Json?) -> UInt64? {
  guard wire_string(value) is Some(text) else { return None }
  let mut parsed = 0UL
  for character in text {
    let code = character.to_int()
    if code < '0' || code > '9' {
      return None
    }
    let digit = (code - ('0' : Int)).to_uint64()
    if parsed > (18446744073709551615UL - digit) / 10UL {
      return None
    }
    parsed = parsed * 10UL + digit
  }
  Some(parsed)
}

///|
fn parse_semantics_scroll_direction(
  value : Json?,
) -> @core.SemanticsScrollDirection? {
  match wire_string(value) {
    Some("forward") => Some(@core.SemanticsScrollDirection::Forward)
    Some("backward") => Some(@core.SemanticsScrollDirection::Backward)
    Some("up") => Some(@core.SemanticsScrollDirection::Up)
    Some("down") => Some(@core.SemanticsScrollDirection::Down)
    Some("left") => Some(@core.SemanticsScrollDirection::Left)
    Some("right") => Some(@core.SemanticsScrollDirection::Right)
    _ => None
  }
}

///|
fn parse_semantics_action(value : Json?) -> @core.SemanticsAction? {
  guard wire_object(value) is Some(fields) else { return None }
  match wire_string(fields.get("kind")) {
    Some("activate") if wire_fields_are_exact(fields, ["kind"]) =>
      Some(@core.SemanticsAction::Activate)
    Some("focus") if wire_fields_are_exact(fields, ["kind"]) =>
      Some(@core.SemanticsAction::Focus)
    Some("set-text") =>
      if wire_fields_are_exact(fields, ["kind", "value"]) {
        match wire_string(fields.get("value"), allow_empty=true) {
          Some(value) => Some(@core.SemanticsAction::SetText(value))
          None => None
        }
      } else {
        None
      }
    Some("submit") if wire_fields_are_exact(fields, ["kind"]) =>
      Some(@core.SemanticsAction::Submit)
    Some("scroll") =>
      if wire_fields_are_exact(fields, ["kind", "direction"]) {
        match parse_semantics_scroll_direction(fields.get("direction")) {
          Some(direction) => Some(@core.SemanticsAction::Scroll(direction))
          None => None
        }
      } else {
        None
      }
    Some("select") if wire_fields_are_exact(fields, ["kind"]) =>
      Some(@core.SemanticsAction::Select)
    Some("expand") if wire_fields_are_exact(fields, ["kind"]) =>
      Some(@core.SemanticsAction::Expand)
    Some("collapse") if wire_fields_are_exact(fields, ["kind"]) =>
      Some(@core.SemanticsAction::Collapse)
    Some("dismiss") if wire_fields_are_exact(fields, ["kind"]) =>
      Some(@core.SemanticsAction::Dismiss)
    _ => None
  }
}

///|
fn parse_accessibility_response(
  fields : Map[String, Json],
) -> EmbeddedHostResponse? {
  guard wire_fields_are_exact(fields, ["kind", "nodeId", "generation", "action"]) else {
    return None
  }
  guard wire_decimal_u64(fields.get("nodeId")) is Some(node_id) && node_id > 0UL else {
    return None
  }
  guard wire_decimal_u64(fields.get("generation")) is Some(generation) else {
    return None
  }
  guard parse_semantics_action(fields.get("action")) is Some(action) else {
    return None
  }
  Some(
    embedded_accessibility_response(
      @core.SemanticsNodeId::new(node_id),
      @core.SemanticsGeneration::new(generation),
      action,
    ),
  )
}

///|
fn parse_platform_view_response(
  fields : Map[String, Json],
) -> EmbeddedHostResponse? {
  guard wire_int(fields.get("revision")) is Some(revision) && revision > 0 else {
    return None
  }
  guard wire_string(fields.get("viewKind")) is Some(view_kind) else {
    return None
  }
  guard wire_string(fields.get("id")) is Some(id) else { return None }
  guard wire_object(fields.get("event")) is Some(event) else { return None }
  guard wire_string(event.get("name")) is Some(name) else { return None }
  guard wire_string(event.get("value"), allow_empty=true) is Some(value) else {
    return None
  }
  guard wire_string(event.get("detail"), allow_empty=true) is Some(detail) else {
    return None
  }
  guard wire_bool(event.get("flag")) is Some(flag) else { return None }
  Some(
    EmbeddedHostResponse::PlatformView(
      revision,
      view_kind,
      id,
      @core.PlatformViewEvent::Named(name~, value~, detail~, flag~),
    ),
  )
}

///|
fn parse_platform_channel_response(
  fields : Map[String, Json],
) -> EmbeddedHostResponse? {
  guard wire_int(fields.get("requestId")) is Some(request_id) && request_id > 0 else {
    return None
  }
  guard wire_string(fields.get("status")) is Some(status) else { return None }
  guard wire_string(fields.get("payload"), allow_empty=true) is Some(payload) else {
    return None
  }
  let response : @host.PlatformChannelResponse = match status {
    "ok" => @host.PlatformChannelResponse::Ok(payload)
    "error" => @host.PlatformChannelResponse::Error(payload)
    "unavailable" => @host.PlatformChannelResponse::Unavailable(payload)
    _ => return None
  }
  Some(
    EmbeddedHostResponse::PlatformChannel(
      @host.HostServiceRequestId::new(request_id),
      response,
    ),
  )
}

///|
fn parse_embedder_host_response_envelope_json(
  text : String,
) -> EmbeddedHostResponseEnvelope? {
  let parsed = @json.parse(text) catch { _ => return None }
  guard wire_object(Some(parsed)) is Some(root) else { return None }
  guard wire_int(root.get("schemaVersion")) is Some(1) else { return None }
  guard wire_int(root.get("sessionGeneration")) is Some(session_generation) &&
    session_generation > 0 else {
    return None
  }
  guard wire_object(root.get("response")) is Some(response_fields) else {
    return None
  }
  guard wire_string(response_fields.get("kind")) is Some(kind) else {
    return None
  }
  let response = match kind {
    "accessibility" => parse_accessibility_response(response_fields)
    "platform-view" => parse_platform_view_response(response_fields)
    "platform-channel" => parse_platform_channel_response(response_fields)
    _ => None
  }
  match response {
    Some(response) =>
      Some(EmbeddedHostResponseEnvelope::new(session_generation~, response~))
    None => None
  }
}

///|
pub fn EmbeddedRuntimeBackendCore::dispatch_host_response_envelope_json(
  self : EmbeddedRuntimeBackendCore,
  text : String,
) -> Bool {
  match parse_embedder_host_response_envelope_json(text) {
    Some(envelope) => self.dispatch_host_response_envelope(envelope)
    None => false
  }
}

///|
pub fn EmbeddedRuntimeHostBridge::drain_updates(
  self : EmbeddedRuntimeHostBridge,
) -> Array[EmbeddedHostUpdate] {
  if self.disposed {
    return []
  }
  let updates = self.updates
  self.updates = []
  updates
}

///|
pub fn EmbeddedRuntimeHostBridge::drain_updates_json(
  self : EmbeddedRuntimeHostBridge,
) -> String {
  self
  .drain_updates()
  .map(update => embedded_host_update_json(update))
  .to_json()
  .stringify()
}

///|
pub fn EmbeddedRuntimeHostBridge::drain_update_envelope(
  self : EmbeddedRuntimeHostBridge,
) -> EmbeddedHostUpdateEnvelope {
  {
    schema_version: 1,
    session_generation: self.session_generation,
    updates: self.drain_updates(),
  }
}

///|
pub fn EmbeddedRuntimeHostBridge::drain_update_envelope_json(
  self : EmbeddedRuntimeHostBridge,
) -> String {
  let envelope = self.drain_update_envelope()
  (
    {
      "schemaVersion": envelope.schema_version,
      "sessionGeneration": envelope.session_generation,
      "updates": envelope.updates.map(embedded_host_update_json),
    } : Json).stringify()
}

///|
fn embedded_host_update_json(update : EmbeddedHostUpdate) -> Json {
  match update {
    EmbeddedHostUpdate::Ime(request) =>
      ({ "kind": "ime", "payload": ToJson::to_json(request) } : Json)
    EmbeddedHostUpdate::Semantics(snapshot) =>
      ({ "kind": "semantics", "payload": ToJson::to_json(snapshot) } : Json)
    EmbeddedHostUpdate::Diagnostic(message) =>
      ({ "kind": "diagnostic", "payload": message } : Json)
    EmbeddedHostUpdate::PlatformViews(snapshot) =>
      ({ "kind": "platform-views", "payload": ToJson::to_json(snapshot) } : Json)
    EmbeddedHostUpdate::PlatformChannel(pending) =>
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
    EmbeddedHostUpdate::Clipboard(pending) =>
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
pub fn EmbeddedRuntimeHostBridge::flush_updates_to_shell(
  self : EmbeddedRuntimeHostBridge,
  transport : @host_services_embedded.HostSessionTransport,
) -> Int {
  let updates = self.drain_updates()
  for update in updates {
    let payload = embedded_host_update_json(update)
    match update {
      EmbeddedHostUpdate::Clipboard({ id, .. })
      | EmbeddedHostUpdate::PlatformChannel({ id, .. }) => {
        ignore(transport.track_request(id=id.value))
        ignore(
          match payload {
            Json::Object(fields) =>
              match fields.get("payload") {
                Some(payload) =>
                  ignore(
                    transport.enqueue_tracked_update(
                      kind=match update {
                        EmbeddedHostUpdate::Clipboard(_) => "clipboard"
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
pub fn embedded_host_response_request_id(
  response : EmbeddedHostResponse,
) -> Int? {
  match response {
    EmbeddedHostResponse::Clipboard(id, _)
    | EmbeddedHostResponse::PlatformChannel(id, _) => Some(id.value)
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
pub fn EmbeddedRuntimeHostBridge::dispatch_response(
  self : EmbeddedRuntimeHostBridge,
  response : EmbeddedHostResponse,
  driver : @runtime.HostRuntimeDriver,
) -> Bool {
  if self.disposed {
    return false
  }
  match response {
    EmbeddedHostResponse::TextInput(event) => {
      let event = embedded_runtime_text_input_from_utf16(
        event,
        driver.focused_text_input(),
      )
      ignore(driver.dispatch(Event::TextInput(event)))
      true
    }
    EmbeddedHostResponse::Command(intent) => {
      ignore(
        driver.dispatch_command_with_services(intent, self.service_bridge()),
      )
      true
    }
    EmbeddedHostResponse::Clipboard(id, result) =>
      self.complete_service_response(id, result, driver)
    EmbeddedHostResponse::Accessibility(request) =>
      match driver.perform_semantics_action(request) {
        Ok(_) => true
        Err(_) => false
      }
    EmbeddedHostResponse::PlatformView(revision, kind, id, event) =>
      self.dispatch_platform_view_response(revision, kind, id, event, driver)
    EmbeddedHostResponse::PlatformChannel(id, response) =>
      self.complete_service_response(
        id,
        HostServiceResponse::PlatformChannel(response),
        driver,
      )
  }
}

///|
fn EmbeddedRuntimeHostBridge::complete_service_response(
  self : EmbeddedRuntimeHostBridge,
  id : HostServiceRequestId,
  response : HostServiceResponse,
  driver : @runtime.HostRuntimeDriver,
) -> Bool {
  if !self.services.complete(id, response) {
    return false
  }
  for completion in self.services.drain_completed() {
    ignore(
      driver.dispatch_service_completion(completion, self.service_bridge()),
    )
  }
  true
}

///|
pub fn EmbeddedRuntimeHostBridge::dispatch_response_envelope(
  self : EmbeddedRuntimeHostBridge,
  envelope : EmbeddedHostResponseEnvelope,
  driver : @runtime.HostRuntimeDriver,
) -> Bool {
  if envelope.schema_version != 1 ||
    envelope.session_generation != self.session_generation {
    false
  } else {
    self.dispatch_response(envelope.response, driver)
  }
}
