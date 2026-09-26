///|
/// 真实 provider 的 async IO 工作者（native）。
///
/// 模式同 `moui/image_remote`：app 侧的提交是同步入队；请求在异步 worker 上完成，
/// 结果经回调回到 UI 线程——UI 线程从不等待网络。Web（wasm-gc）组合根不具备
/// 本模块所需的 async runtime 支撑，因此只用于 macos_skia 入口；Web 评审主路径
/// 继续走确定性假模型（离线硬要求不受影响）。

///|
/// 一次待执行的 provider 请求。
pub(all) struct ProviderJob {
  endpoint : String
  key : String
  request : @provider.CompletionRequest
  on_result : (Result[String, String]) -> Unit
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
  on_result : (Result[String, String]) -> Unit,
) -> Unit {
  let job = ProviderJob::{ endpoint, key, request, on_result, }
  ignore(owner.queue.try_put(job) catch { _ => false })
}

///|
/// 抓取一个任务：OpenAI 兼容 chat/completions。
async fn provider_fetch(job : ProviderJob) -> Unit {
  let body = @provider.build_request_body(job.request).stringify()
  let result = try {
    let (response, data) = @http.post(job.endpoint, body, headers={
      "Content-Type": "application/json",
      "Authorization": "Bearer " + job.key,
    })
    if response.code >= 200 && response.code < 300 {
      Ok(data.text())
    } else {
      Err("provider 返回 HTTP \{response.code}")
    }
  } catch {
    err => Err("网络错误：\{err}")
  }
  (job.on_result)(result)
}

///|
/// 工作循环：与窗口泵成对运行（`@async.all([window_task, worker_task])`）。
pub async fn provider_worker_loop(owner : ProviderOwner) -> Unit {
  @async.with_task_group(group => {
    while true {
      let job = owner.queue.get()
      group.spawn_bg(async fn() { provider_fetch(job) })
    }
  })
}

///|
/// 以提示词提交（入口侧便捷 API）：系统提示由调用方给出（app 的提案 schema）。
pub fn provider_submit_prompt(
  owner : ProviderOwner,
  endpoint : String,
  key : String,
  system : String,
  prompt : String,
  on_result : (Result[String, String]) -> Unit,
) -> Unit {
  let request = @provider.CompletionRequest::new("moblocks-proposal", system).with_message(
    User,
    prompt,
  )
  provider_submit(owner, endpoint, key, request, on_result)
}
