///|
/// 抓取结果:后台 curl 线程完成后由主线程轮询取回。
/// 请求 URL 由 app 的 Model 记录(pending_url),不随结果传输。
#warnings("-unused_constructor")
pub enum FetchOutcome {
  Fetched(html~ : String)
  FetchFailed(message~ : String)
}

///|
/// 单个抓取结果:ok=true 时 body 为内容;ok=false 时抓取失败/超时。
pub struct FetchedResource {
  ok : Bool
  body : String
}
