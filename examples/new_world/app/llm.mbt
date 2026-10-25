///|
/// LLM request construction and reply parsing.
///
/// Pure functions only: no IO, no async, no provider client — that lives in the
/// app-private `llm_native` package. Keeping this layer pure is what makes the
/// provider path testable without a network, and what makes a provider swap a
/// one-file change.

///|
/// One request to send on behalf of a character.
///
/// `messages` is the full wire payload, already ordered and budget-trimmed by
/// `plan_messages`. It is carried as `(role, content)` pairs rather than as
/// separate `system`/`user` fields because the whole point of the context
/// layer is that the model sees the *history*: a two-message request would
/// silently drop the rolling summary, the world-book hits, and every earlier
/// turn.
pub struct LlmRequest {
  character_id : String
  /// Provider base URL or full chat/completions path.
  endpoint : String
  api_key : String
  model : String
  temperature : Double
  /// Ordered wire messages: `("system" | "user" | "assistant", content)`.
  messages : Array[(String, String)]
} derive(Eq, Debug)

///|
pub extend LlmRequest with Debug::{to_repr}

///|
pub extend LlmRequest with Eq::{not_equal, equal}

///|
pub fn LlmRequest::new(
  character_id~ : String,
  endpoint~ : String,
  api_key~ : String,
  model~ : String,
  temperature~ : Double,
  messages~ : Array[(String, String)],
) -> LlmRequest {
  { character_id, endpoint, api_key, model, temperature, messages, }
}

///|
/// A request that carries exactly one system prompt and one user turn. Used by
/// the auxiliary flows (world generation, memory compression, memory
/// extraction) whose prompts are single-shot and have no history.
pub fn LlmRequest::single_shot(
  character_id~ : String,
  endpoint~ : String,
  api_key~ : String,
  model~ : String,
  temperature~ : Double,
  system~ : String,
  user~ : String,
) -> LlmRequest {
  LlmRequest::new(character_id~, endpoint~, api_key~, model~, temperature~, messages=[
    ("system", system),
    ("user", user),
  ])
}

///|
pub fn LlmRequest::character_id(self : LlmRequest) -> String {
  self.character_id
}

///|
pub fn LlmRequest::endpoint(self : LlmRequest) -> String {
  self.endpoint
}

///|
pub fn LlmRequest::api_key(self : LlmRequest) -> String {
  self.api_key
}

///|
pub fn LlmRequest::model(self : LlmRequest) -> String {
  self.model
}

///|
pub fn LlmRequest::temperature(self : LlmRequest) -> Double {
  self.temperature
}

///|
/// The ordered wire messages this request will send.
pub fn LlmRequest::messages(self : LlmRequest) -> Array[(String, String)] {
  self.messages
}

///|
/// The first system message (the persona prompt), or `""` when the request
/// carries none. Kept for the prompt inspector and for tests that pin what the
/// model was told about the world.
pub fn LlmRequest::system(self : LlmRequest) -> String {
  for message in self.messages {
    if message.0 == "system" {
      return message.1
    }
  }
  ""
}

///|
/// The last user turn, or `""` when the request carries none.
pub fn LlmRequest::user(self : LlmRequest) -> String {
  let mut index = self.messages.length()
  while index > 0 {
    index -= 1
    if self.messages[index].0 == "user" {
      return self.messages[index].1
    }
  }
  ""
}

///|
/// Build the request body for an OpenAI-compatible chat/completions call.
///
/// Every planned message rides along in order: system prompts first (persona,
/// rolling summary, world-book hits), then the history, then the player's turn
/// last so the model always answers the thing just said.
pub fn llm_request_body(request : LlmRequest, stream~ : Bool = false) -> Json {
  let messages : Array[Json] = []
  for message in request.messages {
    messages.push(json_message(message.0, message.1))
  }
  let root : Map[String, Json] = {
    "model": Json::string(request.model),
    "messages": Json::array(messages),
    "temperature": Json::number(request.temperature),
  }
  if stream {
    // Server-Sent Events: the reply arrives in pieces, and the stage shows
    // them as they land instead of freezing for five seconds.
    //
    root["stream"] = json_true()
  }
  Json::object(root)
}

///|
/// A JSON `true`.
///
/// The core json package has no boolean constructor, and the request body is
/// JSON: the literal is parsed once, when the body is built.
fn json_true() -> Json {
  @json.parse("true") catch {
    _ => Json::string("")
  }
}

///|
/// The text of one streamed delta, or `None` when the line carries none.
///
/// The OpenAI-compatible streaming format is Server-Sent Events: lines of
/// `data: {json}`, where the json carries `choices[0].delta.content`. The
/// final line is `data: [DONE]`, which carries no text.
pub fn llm_parse_delta(line : String) -> String? {
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
fn json_message(role : String, content : String) -> Json {
  let message : Map[String, Json] = {
    "role": Json::string(role),
    "content": Json::string(content),
  }
  Json::object(message)
}

///|
/// Extract the first choice's text from an OpenAI-compatible response.
///
/// Every malformed shape yields `None`, and the caller falls back to the local
/// script: a provider quirk must degrade the reply, never crash the world.
pub fn llm_parse_reply(text : String) -> String? {
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
            // Plain text: the shape OpenAI itself returns.
            Some(String(content)) => Some(content)
            // Content blocks: Anthropic-style gateways and several
            // OpenAI-compatible proxies return `[{"type":"text","text":…}]`
            // instead of a string. Rejecting it made every reply from such an
            // endpoint look like a failure, with no hint as to why.
            Some(Array(blocks)) => text_from_blocks(blocks)
            _ => None
          }
        _ => None
      }
    _ => None
  }
}

///|
/// Join the text of a content-block array, ignoring non-text blocks.
fn text_from_blocks(blocks : Array[Json]) -> String? {
  let parts : Array[String] = []
  for block in blocks {
    match block {
      Object(fields) =>
        match fields.get("text") {
          Some(String(text)) => parts.push(text)
          _ => ()
        }
      _ => ()
    }
  }
  if parts.is_empty() {
    // A block array with no text (for example a pure tool-call response) is
    // still a reply we cannot use; treating it as `None` keeps the failure
    // path honest instead of appending an empty line.
    None
  } else {
    Some(parts.join(""))
  }
}

///|
/// The reply carried by a completed HTTP body.
///
/// A provider answers one of two ways: a canonical completion object
/// (`choices[0].message.content`) when it ignores `stream: true`, or a
/// Server-Sent Events stream of `data:` lines when it honors it. Both hosts
/// hand over the raw body, so this is the one place that decides — running
/// `llm_parse_reply` on text already folded from deltas was the bug that made
/// every streamed reply look like a provider failure.
pub fn llm_reply_from_body(body : String) -> String? {
  match llm_parse_reply(body) {
    Some(text) => return Some(text)
    None => ()
  }
  let pieces : Array[String] = []
  for line in body.split("\n") {
    match llm_parse_delta(line.to_owned()) {
      Some(delta) => if delta != "" { pieces.push(delta) }
      None => ()
    }
  }
  if pieces.is_empty() {
    None
  } else {
    Some(pieces.join(""))
  }
}

///|
/// Strip the framing some models add around a reply.
///
/// Models frequently wrap their answer in `「…」` or prefix it with the
/// character's own name. Left in place, that prefix reads as the character
/// narrating themselves in the third person.
///
/// The prefix is only stripped when it *is* the character's name. A colon inside
/// dialogue ("他说：明早再走") is content, and stripping it would delete what
/// the character actually said — so the name is passed in rather than guessed.
pub fn llm_clean_reply(text : String, character_name : String) -> String {
  let trimmed = drop_corner_brackets(text.trim().to_owned())
  match leading_name_prefix(trimmed, character_name) {
    Some(end) => trimmed[end:].trim().to_owned()
    None => trimmed
  }
}

///|
/// End index of a leading `Name:` prefix, or `None` when the colon belongs to
/// the dialogue itself.
fn leading_name_prefix(text : String, character_name : String) -> Int32? {
  if character_name == "" {
    return None
  }
  match find_colon(text) {
    Some(index) =>
      if text[0:index] == character_name {
        Some(index + 1)
      } else {
        None
      }
    None => None
  }
}

///|
fn drop_corner_brackets(text : String) -> String {
  if text.length() > 1 && text.has_prefix("「") && text.has_suffix("」") {
    text[1:text.length() - 1].to_owned()
  } else {
    text
  }
}

///|
/// Index of the first colon, full-width or ASCII. Returns the index of the
/// colon itself so the caller can slice past it.
fn find_colon(text : String) -> Int32? {
  let chars : Array[Char] = []
  for ch in text {
    chars.push(ch)
  }
  let mut index = 0
  while index < chars.length() {
    if chars[index] == '：' || chars[index] == ':' {
      return Some(index)
    }
    index += 1
  }
  None
}
