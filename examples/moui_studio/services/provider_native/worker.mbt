///|
/// 真实 provider 的 async IO 工作者（native）。
///
/// 模式同 `moui/image_remote`：app 侧的提交是同步入队；请求在异步 worker 上完成，
/// 结果经回调回到 UI 线程——UI 线程从不等待网络。Web（wasm-gc）组合根不具备
/// 本模块所需的 async runtime 支撑，因此只用于 macos_skia 入口；Web 评审主路径
/// 继续走确定性假模型（离线硬要求不受影响）。
///
/// 配置加载（`load_provider_config`）是 native-only 的便利：从 gitignored 的
/// `examples/moui_studio/.config.json`（`{provider:{endpoint,model,api_key}}`）读取
/// 凭据。key 只进会话内存，绝不进入源码、项目文件或导出 bundle。

///|
/// 一次待执行的 provider 请求。
pub(all) struct ProviderJob {
  endpoint : String
  key : String
  request : @provider.CompletionRequest
  on_result : (Result[String, String]) -> Unit
  /// G1 流式：分块回调（SSE data: 行的增量文本）；None = 整包模式
  on_chunk : ((String) -> Unit)?
}

///|
/// provider 连接配置（endpoint/model/api_key）。api_key 只存会话内存。
pub(all) struct ProviderConfig {
  endpoint : String
  model : String
  api_key : String
}

///|
/// App 私有的请求队列与工作者句柄。
pub(all) struct ProviderOwner {
  queue : @async.Queue[ProviderJob]
}

///|
pub fn ProviderOwner::new() -> ProviderOwner {
  { queue: Queue(kind=Unbounded), }
}

///|
/// 同步入队（UI 线程调用）。队列无界，满不是失败模式。
pub fn provider_submit(
  owner : ProviderOwner,
  endpoint : String,
  key : String,
  request : @provider.CompletionRequest,
  on_chunk~ : ((String) -> Unit)?,
  on_result : (Result[String, String]) -> Unit,
) -> Unit {
  let job = ProviderJob::{ endpoint, key, request, on_result, on_chunk, }
  ignore(owner.queue.try_put(job) catch { _ => false })
}

///|
/// 抓取一个任务：OpenAI 兼容 chat/completions。
async fn provider_fetch(job : ProviderJob) -> Unit {
  let body = @provider.build_request_body(job.request).stringify()
  let url = @provider.completion_url(job.endpoint)
  let result = try {
    if job.on_chunk is Some(chunk_cb) {
      // 分块派发（G1）：整包 POST 拿到完整回复后按固定字符数切块,
      // 经 on_chunk 回调逐块送达 UI（复用 M4 的 StreamChunk 消息流）,
      // UI 侧获得与假路径一致的流式体验;真实 wire 级 SSE 待
      // async/http 流式读稳定后替换。
      let (response, data) = @http.post(url, body, headers={
        "Content-Type": "application/json",
        "Authorization": "Bearer " + job.key,
      })
      if response.code >= 200 && response.code < 300 {
        let full = @provider.parse_completion(data.text())
        match full {
          Ok(text) => {
            let chars : Array[Char] = []
            for ch in text {
              chars.push(ch)
            }
            let chunk_size = 24
            let mut i = 0
            while i < chars.length() {
              let end = if i + chunk_size < chars.length() {
                i + chunk_size
              } else {
                chars.length()
              }
              let piece = StringBuilder()
              let mut k = i
              while k < end {
                piece.write_char(chars[k])
                k = k + 1
              }
              chunk_cb(piece.to_string())
              i = end
            }
            Ok(text)
          }
          Err(message) => Err(message)
        }
      } else {
        Err("provider 返回 HTTP \{response.code}")
      }
    } else {
      let (response, data) = @http.post(url, body, headers={
        "Content-Type": "application/json",
        "Authorization": "Bearer " + job.key,
      })
      if response.code >= 200 && response.code < 300 {
        @provider.parse_completion(data.text())
      } else {
        Err("provider 返回 HTTP \{response.code}")
      }
    }
  } catch {
    err => Err("网络错误：\{err}")
  }
  (job.on_result)(result)
}

///|
/// 工作循环：作为**随从**与窗口泵成对运行
/// （经 `@macos.run_window_with_workers`：窗口一返回就取消本循环）。
pub async fn provider_worker_loop(owner : ProviderOwner) -> Unit {
  @async.with_task_group(group => {
    while true {
      let job = owner.queue.get()
      group.spawn_bg(async fn() { provider_fetch(job) })
    }
  })
}

///|
/// 以提示词提交（入口侧便捷 API）：模型名与系统提示由调用方给出
/// （app 组装 ProviderRequestSpec，入口原样转发）。
pub fn provider_submit_prompt(
  owner : ProviderOwner,
  endpoint : String,
  key : String,
  model : String,
  system : String,
  prompt : String,
  history~ : Array[(String, String)],
  json_mode~ : Bool,
  on_chunk~ : ((String) -> Unit)?,
  on_result : (Result[String, String]) -> Unit,
) -> Unit {
  // 多轮上下文（G1）：历史按序进消息列表,当前提问是最后一条 user
  let request_base = @provider.CompletionRequest::new(model, system)
  let request = {
    ..request_base,
    messages: history.map(msg => {
      match msg.0 {
        "assistant" =>
          @provider.ChatMessage::{ role: Assistant, content: msg.1, }
        _ => @provider.ChatMessage::{ role: User, content: msg.1, }
      }
    }),
    json_mode,
  }.with_message(User, prompt)
  provider_submit(owner, endpoint, key, request, on_chunk~, on_result)
}

///|
/// live smoke 通道：直接发起一次真实 chat/completions（native-only）。
/// 仅供 live 测试 / 诊断工具调用——Studio 运行路径一律走队列 + worker 循环，
/// UI 线程从不等待网络。响应经 parse_completion 提取首选文本。
pub async fn provider_live_completion(
  config : ProviderConfig,
  prompt : String,
) -> Result[String, String] {
  let request = @provider.CompletionRequest::new(
    config.model,
    "You are a helpful assistant.",
  ).with_message(User, prompt)
  let body = @provider.build_request_body(request).stringify()
  let url = @provider.completion_url(config.endpoint)
  let result = try {
    let (response, data) = @http.post(url, body, headers={
      "Content-Type": "application/json",
      "Authorization": "Bearer " + config.api_key,
    })
    if response.code >= 200 && response.code < 300 {
      Ok(data.text())
    } else {
      Err("provider 返回 HTTP \{response.code}")
    }
  } catch {
    err => Err("网络错误：\{err}")
  }
  match result {
    Ok(text) => @provider.parse_completion(text)
    Err(reason) => Err(reason)
  }
}

///|
/// 从 `.config.json` 读取 provider 配置（native-only：x/fs + 纯 JSON 解析）。
/// 期望结构：`{ "provider": { "endpoint": ..., "model": ..., "api_key": ... } }`。
/// 三个字段全部为字符串且缺一即返回 None（严格：不填默认、不猜）。
pub fn load_provider_config(path : String) -> ProviderConfig? {
  let text = @x/fs.read_file_to_string(path) catch { _ => return None }
  let payload = @json.parse(text) catch { _ => return None }
  let root = match payload {
    Object(fields) => fields
    _ => return None
  }
  let provider = match root.get("provider") {
    Some(Object(fields)) => fields
    _ => return None
  }
  let endpoint = match provider.get("endpoint") {
    Some(String(value)) => value
    _ => return None
  }
  let model = match provider.get("model") {
    Some(String(value)) => value
    _ => return None
  }
  let api_key = match provider.get("api_key") {
    Some(String(value)) => value
    _ => return None
  }
  Some(ProviderConfig::{ endpoint, model, api_key, })
}
