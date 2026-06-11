///|
fn WorkbenchModel::ingest_pi_jsonl(
  self : WorkbenchModel,
  session_id : String,
  line : String,
) -> WorkbenchModel {
  let parsed : Json? = Some(@json.parse(line)) catch { _ => None }
  match parsed {
    Some(Object(fields)) => self.ingest_pi_json_object(session_id, fields)
    _ => self
  }
}

///|
fn PiTransportEvent::session_replacement_refresh(
  self : PiTransportEvent,
) -> (String, String, String)? {
  match self {
    JsonLineReceived(session_id, line) =>
      if json_line_is_uncancelled_success_response(line, "new_session") {
        Some(
          (
            session_id, "Pi new session refresh queued", "Pi new session refresh queued",
          ),
        )
      } else if json_line_is_uncancelled_success_response(line, "fork") {
        Some((session_id, "Pi fork refresh queued", "Pi fork refresh queued"))
      } else if json_line_is_uncancelled_success_response(line, "prompt") {
        Some(
          (
            session_id, "Pi transcript refresh queued", "Pi transcript refresh queued",
          ),
        )
      } else if json_line_is_uncancelled_success_response(line, "steer") {
        Some(
          (
            session_id, "Pi transcript refresh queued", "Pi transcript refresh queued",
          ),
        )
      } else if json_line_is_uncancelled_success_response(line, "follow_up") {
        Some(
          (
            session_id, "Pi transcript refresh queued", "Pi transcript refresh queued",
          ),
        )
      } else if json_line_is_non_retry_agent_end(line) {
        Some(
          (
            session_id, "Pi transcript refresh queued", "Pi transcript refresh queued",
          ),
        )
      } else {
        None
      }
    _ => None
  }
}

///|
fn json_line_is_uncancelled_success_response(
  line : String,
  command : String,
) -> Bool {
  let parsed : Json? = Some(@json.parse(line)) catch { _ => None }
  match parsed {
    Some(Object(fields)) => {
      let cancelled = match json_object(fields, "data") {
        Some(data) => json_bool(data, "cancelled").unwrap_or(false)
        None => false
      }
      json_string(fields, "type").unwrap_or("") == "response" &&
      json_string(fields, "command").unwrap_or("") == command &&
      json_bool(fields, "success").unwrap_or(false) &&
      !cancelled
    }
    _ => false
  }
}

///|
fn json_line_is_non_retry_agent_end(line : String) -> Bool {
  let parsed : Json? = Some(@json.parse(line)) catch { _ => None }
  match parsed {
    Some(Object(fields)) =>
      json_string(fields, "type").unwrap_or("") == "agent_end" &&
      !json_bool(fields, "willRetry").unwrap_or(false)
    _ => false
  }
}

///|
