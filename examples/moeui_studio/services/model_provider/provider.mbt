///|
/// Mo易 Studio 模型 provider 协议与 OpenAI 兼容编解码。
/// 产品域私有包：只被 moblocks_studio app 依赖。
///
/// 边界：
/// - provider 只做「请求体构造 / 响应体解析」与确定性假模型；
///   真实 IO（async HTTP → ServiceTask → Msg）在 app 侧接线，
///   凭据不进入本包、不进入项目文件。
/// - 与 app 的 `ai_generation.mbt` 提案契约正交：这里管单次对话补全，
///   BlockGraphProposal 的结构化生成复用同一请求通道（schema 约束见 app 侧）。

///|
pub(all) enum ChatRole {
  System
  User
  Assistant
}

///|
pub(all) struct ChatMessage {
  role : ChatRole
  content : String
}

///|
pub(all) struct CompletionRequest {
  model : String
  system : String
  messages : Array[ChatMessage]
  temperature : Double
}

///|
pub fn CompletionRequest::new(
  model : String,
  system : String,
) -> CompletionRequest {
  { model, system, messages: [], temperature: 0.7, }
}

///|
pub fn CompletionRequest::with_message(
  self : CompletionRequest,
  role : ChatRole,
  content : String,
) -> CompletionRequest {
  { ..self, messages: [..self.messages, ChatMessage::{ role, content, }], }
}

///|
fn role_label(role : ChatRole) -> String {
  match role {
    System => "system"
    User => "user"
    Assistant => "assistant"
  }
}

///|
/// OpenAI 兼容 chat/completions 请求体。
pub fn build_request_body(request : CompletionRequest) -> Json {
  let messages : Array[Json] = []
  if request.system != "" {
    let system = Map([], capacity=8)
    system["role"] = Json::string("system")
    system["content"] = Json::string(request.system)
    messages.push(Json::object(system))
  }
  for message in request.messages {
    let object = Map([], capacity=8)
    object["role"] = Json::string(role_label(message.role))
    object["content"] = Json::string(message.content)
    messages.push(Json::object(object))
  }
  let root = Map([], capacity=8)
  root["model"] = Json::string(request.model)
  root["messages"] = Json::array(messages)
  root["temperature"] = Json::number(request.temperature)
  let response_format = Map([], capacity=1)
  response_format["type"] = Json::string("json_object")
  root["response_format"] = Json::object(response_format)
  Json::object(root)
}

///|
/// 从 OpenAI 兼容响应体提取首选文本。结构不符/错误体一律拒绝。
pub fn parse_completion(text : String) -> Result[String, String] {
  let payload = @json.parse(text) catch {
    _ => return Err("响应不是合法 JSON")
  }
  let fields = match payload {
    Object(fields) => fields
    _ => return Err("响应不是 JSON 对象")
  }
  // 显式错误体优先
  match fields.get("error") {
    Some(Object(error_fields)) =>
      match error_fields.get("message") {
        Some(String(message)) => return Err("provider 错误：\{message}")
        _ => return Err("provider 返回错误体")
      }
    _ => ()
  }
  let choices = match fields.get("choices") {
    Some(Array(choices)) => choices
    _ => return Err("响应缺少 choices")
  }
  if choices.is_empty() {
    return Err("choices 为空")
  }
  match choices[0] {
    Object(first) =>
      match first.get("message") {
        Some(Object(message)) =>
          match message.get("content") {
            Some(String(content)) => Ok(content)
            _ => return Err("首个 choice 的 message.content 不是字符串")
          }
        _ => return Err("首个 choice 缺少 message")
      }
    _ => return Err("choices[0] 不是对象")
  }
}

///|
/// 确定性假模型：离线可演示、可回放。相同的请求总是得到相同的回复。
/// 面试演示不依赖网络；真实 provider 走 build_request_body/parse_completion。
pub fn deterministic_completion(request : CompletionRequest) -> String {
  let last_user = request.messages
    .filter(fn(message) { message.role is User })
    .map(fn(message) { message.content })
  let prompt = if last_user.is_empty() {
    ""
  } else {
    let last = last_user.length() - 1
    last_user[last]
  }
  let persona = if request.system == "" {
    "友好助手"
  } else {
    request.system
  }
  "【\{persona}】收到：\{prompt}。这是确定性假模型的回复（模型 \{request.model}，温度 \{request.temperature.to_int()}）。"
}

///|
/// 请求体大小守卫：超过上限的请求在 IO 前拒绝（参数截断红线）。
pub fn request_within_budget(
  request : CompletionRequest,
  max_chars : Int,
) -> Bool {
  let mut total = request.system.length()
  for message in request.messages {
    total = total + message.content.length()
  }
  total <= max_chars
}
