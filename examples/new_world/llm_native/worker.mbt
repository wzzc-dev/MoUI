///|
/// OpenAI-compatible transport for the AI world (native only).
///
/// Why a separate package: the shared app package must stay a pure TEA package
/// and must not import `moonbitlang/async` (see `docs/moui-app-package-boundary.md`
/// — app-private subpackages may own host IO). This package is the only place
/// that touches the network.
///
/// Pattern (same as `moui/image_remote/remote_image.mbt` and
/// `examples/mo_workbench/openseek_native_transport/openseek_worker.mbt`):
/// the UI thread submits synchronously onto an async queue, a worker loop
/// parked as a sibling of the window pump performs the request, and the result
/// comes back through a callback that the app maps into a typed `Msg`. The UI
/// thread never waits on the network.
///
/// `moonbitlang/async/http` covers native / js / wasm only, so this package is
/// `supported_targets = "native"`; web builds keep the deterministic brain.

///|
/// One pending request.
pub struct LlmJob {
  endpoint : String
  api_key : String
  model : String
  temperature : Double
  /// Ordered wire messages (`system` / `user` / `assistant`), already planned
  /// and budget-trimmed by the app. Passing the whole array is what makes the
  /// native transport history-aware.
  messages : Array[(String, String)]
  on_result : (String?) -> Unit
  /// Called with each piece of the reply as it lands.
  on_delta : (String) -> Unit
}

///|
/// App-private queue and worker handle.
pub struct LlmOwner {
  queue : @async.Queue[LlmJob]
}

///|
pub fn LlmOwner::new() -> LlmOwner {
  { queue: Queue(kind=Unbounded), }
}

///|
/// Submit a request. Called from the UI thread; returns immediately.
pub fn llm_submit(
  owner : LlmOwner,
  endpoint : String,
  api_key : String,
  model : String,
  temperature : Double,
  messages : Array[(String, String)],
  on_result : (String?) -> Unit,
  on_delta : (String) -> Unit,
) -> Unit {
  let job = LlmJob::{
    endpoint,
    api_key,
    model,
    temperature,
    messages,
    on_result,
    on_delta,
  }
  // The queue is unbounded, so a full queue is not a failure mode here.
  ignore(owner.queue.try_put(job) catch { _ => false })
}

///|
/// Build the OpenAI-compatible chat/completions body from the planned
/// messages, in order.
fn llm_request_body(job : LlmJob, stream~ : Bool = false) -> String {
  let messages : Array[Json] = []
  for message in job.messages {
    let fields : Map[String, Json] = {
      "role": Json::string(message.0),
      "content": Json::string(message.1),
    }
    messages.push(Json::object(fields))
  }
  let root : Map[String, Json] = {
    "model": Json::string(job.model),
    "messages": Json::array(messages),
    "temperature": Json::number(job.temperature),
  }
  if stream {
    // Server-Sent Events: the reply arrives in pieces.
    root["stream"] = json_true()
  }
  @json.to_json(Json::object(root)).stringify()
}

///|
/// Resolve the chat/completions URL from a configured base URL. An endpoint
/// that already names the path is used verbatim, matching the OpenAI SDK.
fn llm_completion_url(endpoint : String) -> String {
  if endpoint.contains("/chat/completions") {
    return endpoint
  }
  let trimmed : String = endpoint.trim().to_owned()
  let base = if trimmed.has_suffix("/") {
    trimmed[0:trimmed.length() - 1].to_owned()
  } else {
    trimmed
  }
  base + "/chat/completions"
}

///|
/// Perform one request and hand the completion text (or `None`) back.
///
/// The reply is streamed: the provider sends Server-Sent Events, and every
/// `data:` line is handed to the app as it lands, so the stage shows the
/// words while they are still being written. The whole text is also
/// returned at the end, so a provider that ignores `stream` still works.
async fn llm_fetch(job : LlmJob) -> Unit {
  let url = llm_completion_url(job.endpoint)
  let body = llm_request_body(job, stream=true)
  let result = try {
    let (host, path) = llm_split_url(url)
    // The client is opened on the host root; the request carries the path.
    let client = @http.Client::Client(host + "/")
    client.request(
      @http.RequestMethod::Post,
      path,
      extra_headers={
        "Content-Type": "application/json",
        "Authorization": "Bearer " + job.api_key,
        "Accept": "text/event-stream",
      },
    )
    client.write(body)
    let response = client.end_request()
    if response.code < 200 || response.code >= 300 {
      None
    } else {
      let mut text = ""
      while true {
        match client.read_until("\n") {
          Some(line) =>
            match llm_parse_delta(line) {
              Some(delta) => {
                text += delta
                (job.on_delta)(delta)
              }
              None => ()
            }
          None => break
        }
      }
      if text != "" {
        Some(text)
      } else {
        // A provider that ignored `stream` sent one JSON document instead
        // of events: read what is left and parse it the plain way, so the
        // reply is never lost to a capability the provider does not have.
        let whole = client.read_all().text()
        llm_parse_completion(whole)
      }
    }
  } catch {
    _ => None
  }
  (job.on_result)(result)
}

///|
/// A JSON `true`.
///
/// The core json package has no boolean constructor, and the body is JSON:
/// the literal is parsed once, when the body is built.
fn json_true() -> Json {
  @json.parse("true") catch { _ => Json::string("") }
}

///|
/// Split a URL into the host root and the path.
///
/// `https://api.openai.com/v1/chat/completions` becomes
/// (`https://api.openai.com`, `/v1/chat/completions`).
fn llm_split_url(url : String) -> (String, String) {
  let scheme_end = url.find("://")
  let rest = match scheme_end {
    Some(at) => url[at + 3:].to_owned()
    None => url
  }
  let slash = rest.find("/")
  match slash {
    Some(at) => {
      let host = url[0:scheme_end.unwrap_or(0) + 3 + at].to_owned()
      let path = rest[at:].to_owned()
      (host, path)
    }
    None => (url, "/")
  }
}

///|
/// The text of one streamed delta, or `None` when the line carries none.
///
/// The OpenAI-compatible streaming format is Server-Sent Events: lines of
/// `data: {json}`, where the json carries `choices[0].delta.content`. The
/// final line is `data: [DONE]`, which carries no text.
fn llm_parse_delta(line : String) -> String? {
  let trimmed = line.trim().to_owned()
  if !trimmed.has_prefix("data:") {
    return None
  }
  let payload = trimmed[5:].trim().to_owned()
  if payload == "[DONE]" || payload == "" {
    return None
  }
  let json = @json.parse(payload) catch { _ => return None }
  let fields = match json {
    Object(values) => values
    _ => return None
  }
  let choices = match fields.get("choices") {
    Some(Array(values)) => values
    _ => return None
  }
  if choices.is_empty() {
    return None
  }
  match choices[0] {
    Object(first) =>
      match first.get("delta") {
        Some(Object(delta)) =>
          match delta.get("content") {
            Some(String(content)) => Some(content)
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
/// Extract the first choice's text from an OpenAI-compatible response.
///
/// Every malformed shape yields `None`: the caller falls back to the
/// deterministic brain, so a provider quirk degrades behaviour instead of
/// crashing the world.
fn llm_parse_completion(text : String) -> String? {
  let payload = @json.parse(text) catch { _ => return None }
  let fields = match payload {
    Object(values) => values
    _ => return None
  }
  let choices = match fields.get("choices") {
    Some(Array(values)) => values
    _ => return None
  }
  if choices.is_empty() {
    return None
  }
  match choices[0] {
    Object(first) =>
      match first.get("message") {
        Some(Object(message)) =>
          match message.get("content") {
            Some(String(content)) => Some(content)
            _ => return None
          }
        _ => return None
      }
    _ => return None
  }
}

///|
/// Worker loop. Run it as a **worker** next to the window pump through the
/// host's `run_window_with_workers`, never as a peer via `@async.all`: this
/// loop never returns on its own, so `all` would keep the process alive after
/// the window closes.
pub async fn llm_worker_loop(owner : LlmOwner) -> Unit {
  @async.with_task_group(group => {
    while true {
      let job = owner.queue.get()
      group.spawn_bg(async fn() { llm_fetch(job) })
    }
  })
}
