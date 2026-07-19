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
fn parse_platform_view_response(
  fields : Map[String, Json],
) -> EmbeddingHostResponse? {
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
    EmbeddingHostResponse::PlatformView(
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
) -> EmbeddingHostResponse? {
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
    EmbeddingHostResponse::PlatformChannel(
      @host.HostServiceRequestId::new(request_id),
      response,
    ),
  )
}

///|
fn parse_embedder_host_response_envelope_json(
  text : String,
) -> EmbeddingHostResponseEnvelope? {
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
    "platform-view" => parse_platform_view_response(response_fields)
    "platform-channel" => parse_platform_channel_response(response_fields)
    _ => None
  }
  match response {
    Some(response) =>
      Some(EmbeddingHostResponseEnvelope::new(session_generation~, response~))
    None => None
  }
}

///|
pub fn EmbeddedSessionCore::dispatch_host_response_envelope_json(
  self : EmbeddedSessionCore,
  text : String,
) -> Bool {
  match parse_embedder_host_response_envelope_json(text) {
    Some(envelope) => self.dispatch_host_response_envelope(envelope)
    None => false
  }
}
