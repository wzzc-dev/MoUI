///|
/// curl 后台抓取桥(native):在 detached 线程里执行
/// `curl -sL --max-time 20 [-x 代理] URL`,stdout 写入加锁槽,
/// 主线程每帧 `poll_fetch` 原子取回。阻塞网络 IO 不卡 UI 线程。
///
/// 陈旧结果保护:每次 `start_fetch` 递增代数计数,旧 worker 完成后
/// 发现自己被取代则丢弃输出,避免把旧页标成新导航的结果。
///
/// 依赖:macOS/各发行版自带的 curl 与 pthread(系统库,无需额外链接)。
/// wasm/js 目标使用 `net_bridge_unavailable.mbt` 的占位实现。

///|
#borrow(cmd)
extern "C" fn nav_curl_start(cmd : Bytes, cmd_len : Int) -> Int = "moui_nav_curl_start"

///|
#borrow(dst)
extern "C" fn nav_result_take(dst : Bytes, cap : Int) -> Int = "moui_nav_result_take"

///|
extern "C" fn nav_result_wait(timeout_ms : Int) -> Int = "moui_nav_result_wait"

///|
/// 批量抓取 API:并行 worker 线程,每 URL 一个槽。
#borrow(cmd)
extern "C" fn fetch_slot_start(cmd : Bytes, cmd_len : Int) -> Int = "moui_fetch_slot_start"

///|
extern "C" fn fetch_wait_all(timeout_ms : Int) -> Int = "moui_fetch_wait_all"

///|
extern "C" fn fetch_slot_state(id : Int) -> Int = "moui_fetch_slot_state"

///|
extern "C" fn fetch_slot_len(id : Int) -> Int = "moui_fetch_slot_len"

///|
#borrow(dst)
extern "C" fn fetch_slot_take(id : Int, dst : Bytes, cap : Int) -> Int = "moui_fetch_slot_take"

///|
extern "C" fn fetch_slot_clear(id : Int) -> Unit = "moui_fetch_slot_clear"

///|
/// 并行抓取一批 URL(页面外链脚本/样式表)。
/// 返回与 `urls` 一一对应的结果;槽分配失败或超时的 URL 按失败处理。
pub fn fetch_resources(
  urls : Array[String],
  proxy : String?,
) -> Array[FetchedResource] {
  let ids : Array[Int] = []
  for url in urls {
    let cmd = build_curl_command(url, proxy)
    let bytes = @utf8.encode(cmd)
    let id = fetch_slot_start(bytes, bytes.length())
    // 槽满时也压入 -1,保持与 urls 的 1:1 对应(下游按位置 zip)
    ids.push(if id >= 0 { id } else { -1 })
  }
  if ids.length() == 0 {
    return []
  }
  ignore(fetch_wait_all(30000))
  let out : Array[FetchedResource] = []
  for id in ids {
    if id < 0 {
      out.push({ ok: false, body: "" })
      continue
    }
    let st = fetch_slot_state(id)
    if st == 1 {
      let len = fetch_slot_len(id)
      let buf = Bytes::make(len + 1, 0)
      let n = fetch_slot_take(id, buf, buf.length())
      out.push({
        ok: true,
        body: @utf8.decode(buf.view(start=0, end=n)) catch {
          _ => ""
        },
      })
    } else {
      out.push({ ok: false, body: "" })
    }
    fetch_slot_clear(id)
  }
  out
}

///|
/// 阻塞等待抓取完成(最多 timeout_ms),完成后取走结果。
/// 用于测试与需要同步等待的调用方;app 主循环用非阻塞 `poll_fetch`。
pub fn wait_fetch(timeout_ms : Int) -> FetchOutcome? {
  if nav_result_wait(timeout_ms) == 0 {
    return None
  }
  poll_fetch()
}

///|
/// 启动一次后台抓取;成功返回 true。
/// 同一时间只保留最新一次导航的结果。
pub fn start_fetch(url : String, proxy : String?) -> Bool {
  let cmd = build_curl_command(url, proxy)
  let bytes = @utf8.encode(cmd)
  nav_curl_start(bytes, bytes.length()) >= 0
}

///|
/// 主线程每帧轮询:有完成结果则取走并返回,没有则返回 None。
/// 缓冲不足时槽保持原样,按所需长度精确扩容重试(有上限)。
pub fn poll_fetch() -> FetchOutcome? {
  let mut cap = 1 << 20
  let mut attempts = 0
  while attempts < 8 {
    let buf = Bytes::make(cap, 0)
    let n = nav_result_take(buf, cap)
    if n == 0 {
      return None
    }
    let size = if n > 0 { n } else { -n }
    if size > cap {
      // 缓冲不够:槽未被取走,精确扩容后重试
      cap = size
      attempts = attempts + 1
      continue
    }
    let text = @utf8.decode(buf.view(start=0, end=size)) catch { _ => "" }
    return if n > 0 {
      Some(FetchOutcome::Fetched(html=text))
    } else {
      Some(FetchOutcome::FetchFailed(message=text))
    }
  }
  None
}

///|
/// 构造 curl 命令行;URL 与代理经 shell 单引号转义,防注入。
fn build_curl_command(url : String, proxy : String?) -> String {
  let parts = ["curl", "-sL", "--max-time", "20"]
  match proxy {
    Some(p) => {
      parts.push("-x")
      parts.push(shell_quote(p))
    }
    None => ()
  }
  parts.push(shell_quote(url))
  parts.join(" ")
}

///|
fn shell_quote(s : String) -> String {
  let mut out = "'"
  for c in s.iter() {
    if c == '\'' {
      out = out + "'\\''"
    } else {
      out = out + "\{c}"
    }
  }
  out + "'"
}
