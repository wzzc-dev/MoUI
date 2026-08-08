///|
/// curl 桥的 wasm/js 占位:当前 demo 目标为 native,
/// 非 native 目标下导航与批量资源抓取均不可用。

///|
pub fn start_fetch(_url : String, _proxy : String?) -> Bool {
  false
}

///|
pub fn poll_fetch() -> FetchOutcome? {
  None
}

///|
pub fn wait_fetch(_timeout_ms : Int) -> FetchOutcome? {
  None
}

///|
/// 批量抓取占位:全部按失败处理(与 urls 1:1)。
pub fn fetch_resources(urls : Array[String], _proxy : String?) -> Array[FetchedResource] {
  let out : Array[FetchedResource] = []
  for _ in urls {
    out.push({ ok: false, body: "" })
  }
  out
}
