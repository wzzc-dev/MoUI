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
  system : String
  user : String
  on_result : (String?) -> Unit
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
  system : String,
  user : String,
  on_result : (String?) -> Unit,
) -> Unit {
  let job = LlmJob::{
    endpoint,
    api_key,
    model,
    temperature,
    system,
    user,
    on_result,
  }
  // The queue is unbounded, so a full queue is not a failure mode here.
  ignore(owner.queue.try_put(job) catch { _ => false })
}

///|
/// Build the OpenAI-compatible chat/completions body.
fn llm_request_body(job : LlmJob) -> String {
  let system_message : Map[String, Json] = {
    "role": Json::string("system"),
    "content": Json::string(job.system),
  }
  let user_message : Map[String, Json] = {
    "role": Json::string("user"),
    "content": Json::string(job.user),
  }
  let root : Map[String, Json] = {
    "model": Json::string(job.model),
    "messages": Json::array([
      Json::object(system_message),
      Json::object(user_message),
    ]),
    "temperature": Json::number(job.temperature),
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
async fn llm_fetch(job : LlmJob) -> Unit {
  let url = llm_completion_url(job.endpoint)
  let body = llm_request_body(job)
  let result = try {
    let (response, data) = @http.post(url, body, headers={
      "Content-Type": "application/json",
      "Authorization": "Bearer " + job.api_key,
    })
    if response.code >= 200 && response.code < 300 {
      llm_parse_completion(data.text())
    } else {
      None
    }
  } catch {
    _ => None
  }
  (job.on_result)(result)
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
