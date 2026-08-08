///|
/// 批量抓取生命周期:并行抓取 3 个 URL(混合成功/失败),1:1 对应,
/// 取走后槽全部释放(可再次复用)。
test "fetch_resources batch lifecycle" {
  let urls = ["https://example.com", "not-a-url", "https://example.com"]
  let results = fetch_resources(urls, Some("http://127.0.0.1:7897"))
  debug_inspect(results.length(), content="3")
  debug_inspect(results[0].ok, content="true")
  debug_inspect(results[0].body.length() > 100, content="true")
  debug_inspect(results[1].ok, content="false")
  debug_inspect(results[2].ok, content="true")
  // 槽已全部释放:再来一批仍能并行抓取
  let again = fetch_resources(
    ["https://example.com"],
    Some("http://127.0.0.1:7897"),
  )
  debug_inspect(again.length(), content="1")
  debug_inspect(again[0].ok, content="true")
}
