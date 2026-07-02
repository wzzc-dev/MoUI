// OpenAI-compatible async agent backend for Mo Workbench.
//
// Currently, `openai_backend_from_env()` returns `None` so the entrypoint
// falls back to the stub backend. The helper functions `build_request_json`
// and `extract_reply` are provided for future use when the async HTTP
// infrastructure is wired in.

/// Try to create an AgentBackendRuntime from environment variables.
/// Always returns None for now (stub backend is used).
/// TODO: Wire in a real async HTTP backend once the sync-to-async bridge
/// infrastructure is available.
pub fn openai_backend_from_env() -> @app.AgentBackendRuntime? {
  None
}

/// Build the JSON POST body for a chat-completion request.
fn build_request_json(task : String) -> String {
  let escaped = task.replace(old="\\", new="\\\\")
    .replace(old="\"", new="\\\"")
    .replace(old="\n", new="\\n")
    .replace(old="\r", new="\\r")
    .replace(old="\t", new="\\t")
  "{\"model\":\"deepseek-chat\",\"messages\":[{\"role\":\"user\",\"content\":\"" +
  escaped +
  "\"}],\"stream\":false}"
}

/// Extract the assistant reply text from a chat-completion JSON response.
fn extract_reply(json_str : String) -> Result[String, String] {
  let json = try @json.parse(json_str) catch {
    _ => return Err("invalid JSON from API")
  }
  guard json is Object(obj) else {
    return Err("expected JSON object")
  }
  let choices = match obj.get("choices") {
    Some(Array(arr)) => arr
    _ => return Err("no 'choices' array in response")
  }
  if choices.is_empty() {
    return Err("no choices in response")
  }
  let first = match choices[0] {
    Object(obj) => obj
    _ => return Err("malformed choice entry")
  }
  let message = match first.get("message") {
    Some(Object(obj)) => obj
    _ => return Err("no 'message' in choice")
  }
  match message.get("content") {
    Some(String(s)) => Ok(s)
    Some(Null) => Err("empty assistant content")
    _ => Err("no 'content' in message")
  }
}