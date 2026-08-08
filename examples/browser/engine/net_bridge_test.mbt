///|
/// curl 桥测试。
///
/// 注意:MoonBit native 测试并行执行,而 C 桥的导航槽是进程级单槽,
/// 因此**本文件内的 start_fetch 场景都放在同一个测试里串行执行**。
/// 成功断言需要本机代理 127.0.0.1:7897 可用(与既有网络测试一致)。

///|
test "curl bridge start/wait/take lifecycle" {
  // 场景 1:非法 URL → FetchFailed
  ignore(start_fetch("not-a-url", None))
  let outcome1 = wait_fetch(5000)
  inspect(
    outcome1 is Some(FetchOutcome::FetchFailed(_)),
    content="true",
  )
  // 取走后槽已清空
  inspect(poll_fetch() is None, content="true")

  // 场景 2:非法代理 → FetchFailed(不 panic)
  ignore(start_fetch("https://example.com", Some("not-a-proxy")))
  let outcome2 = wait_fetch(5000)
  inspect(
    outcome2 is Some(FetchOutcome::FetchFailed(_)),
    content="true",
  )
}

///|
/// 批量抓取生命周期:并行抓取 3 个 URL(混合成功/失败),1:1 对应,
/// 取走后槽全部释放(可再次复用)。
test "fetch_resources batch lifecycle" {
  let urls = [
    "https://example.com",
    "not-a-url",
    "https://example.com",
  ]
  let results = fetch_resources(urls, Some("http://127.0.0.1:7897"))
  debug_inspect(results.length(), content="3")
  debug_inspect(results[0].ok, content="true")
  debug_inspect(results[0].body.length() > 100, content="true")
  debug_inspect(results[1].ok, content="false")
  debug_inspect(results[2].ok, content="true")
  // 槽已全部释放:再来一批仍能并行抓取
  let again = fetch_resources(["https://example.com"], Some("http://127.0.0.1:7897"))
  debug_inspect(again.length(), content="1")
  debug_inspect(again[0].ok, content="true")
}
