///|
test "link regions extracted from rendered page" {
  let html = "<a href='https://example.com' style='display:block;width:100px;height:20px'>link</a>"
  let result = render_html_document(html, 400.0, 300.0)
  debug_inspect(result.links.length(), content="1")
  debug_inspect(result.links[0].href, content="\"https://example.com\"")
  debug_inspect(result.links[0].width, content="100")
  debug_inspect(result.links[0].x, content="8")
  debug_inspect(result.commands.length() > 0, content="true")
}

///|
/// 多个链接按文档顺序对齐
test "multiple links keep document order" {
  let html = "<a href='#one' style='display:block'>first</a><a href='#two' style='display:block'>second</a>"
  let result = render_html_document(html, 400.0, 300.0)
  debug_inspect(result.links.length(), content="2")
  debug_inspect(result.links[0].href, content="\"#one\"")
  debug_inspect(result.links[1].href, content="\"#two\"")
  debug_inspect(result.links[1].y > result.links[0].y, content="true")
}

///|
/// 无链接页面返回空 links
test "no links yields empty regions" {
  let result = render_html_document("<p>plain</p>", 400.0, 300.0)
  debug_inspect(result.links.length(), content="0")
  debug_inspect(result.commands.length() > 0, content="true")
}

///|
/// display:none 链接不出现在 paint 树,后续链接不因 zip 错位
test "hidden link in the middle does not mispair later links" {
  let html = "<a href='#one' style='display:block'>first</a><a href='#hidden' style='display:none'>hidden</a><a href='#two' style='display:block'>second</a>"
  let result = render_html_document(html, 400.0, 300.0)
  debug_inspect(result.links.length(), content="2")
  debug_inspect(result.links[0].href, content="\"#one\"")
  debug_inspect(result.links[1].href, content="\"#two\"")
}

///|
/// visibility:hidden 链接不产生可点击区域
test "visibility hidden anchor yields no region" {
  let html = "<a href='#v' style='visibility:hidden;display:block'>v</a><a href='#w' style='display:block'>w</a>"
  let result = render_html_document(html, 400.0, 300.0)
  debug_inspect(result.links.length(), content="1")
  debug_inspect(result.links[0].href, content="\"#w\"")
}

///|
/// href 值内含 '>' 时标签重写不被截断(引号感知扫描)
test "anchor tag with gt inside href value survives rewrite" {
  let html = "<a href='data:text/html,<h1>x</h1>' style='display:block;width:100px;height:20px'>go</a>"
  let result = render_html_document(html, 400.0, 300.0)
  debug_inspect(result.links.length(), content="1")
  debug_inspect(result.links[0].href, content="\"data:text/html,<h1>x</h1>\"")
  debug_inspect(result.commands.length() > 0, content="true")
}

///|
/// 无 href 的锚点不产生区域,也不挤占后续链接的 id
test "anchor without href yields no region" {
  let html = "<a style='display:block;width:100px;height:20px'>noop</a><a href='#real' style='display:block'>real</a>"
  let result = render_html_document(html, 400.0, 300.0)
  debug_inspect(result.links.length(), content="1")
  debug_inspect(result.links[0].href, content="\"#real\"")
}

///|
/// script 体内的 <a ...> 字符串不被误识别为锚点
test "script bodies are not scanned for anchors" {
  let html = "<script>var s = \"<a href='#fake'>\";</script><a href='#real' style='display:block'>real</a>"
  let result = render_html_document(html, 400.0, 300.0)
  debug_inspect(result.links.length(), content="1")
  debug_inspect(result.links[0].href, content="\"#real\"")
}

///|
/// data URL 解码:明文、base64 与 percent 编码
test "data url decode" {
  debug_inspect(
    decode_data_url("data:text/html,<h1>hi</h1>"),
    content="Some(\"<h1>hi</h1>\")",
  )
  // "aGVsbG8=" is UTF-8 base64 of "hello"
  debug_inspect(
    decode_data_url("data:text/html;base64,aGVsbG8="),
    content="Some(\"hello\")",
  )
  debug_inspect(
    decode_data_url("data:text/html,%3Ch1%3Ehi%3C%2Fh1%3E"),
    content="Some(\"<h1>hi</h1>\")",
  )
  // UTF-8 多字节序列:"中" = E4 B8 AD
  debug_inspect(
    decode_data_url("data:text/html,%E4%B8%AD"),
    content="Some(\"中\")",
  )
  debug_inspect(decode_data_url("https://example.com"), content="None")
}
