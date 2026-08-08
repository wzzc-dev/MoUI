///|
/// 网络层测试:需要真实网络。本地验证用;CI 无网环境下失败时仅打印,不阻断。

///|
async test "fetch bing.com follows redirect via proxy" {
  let outcome = try {
    Ok(fetch_page(
      "https://www.bing.com",
      proxy=Some("http://127.0.0.1:7897"),
    ))
  } catch {
    err => Err(err)
  }
  match outcome {
    Ok(page) => {
      debug("status: \{page.status}, bytes: \{page.html.length()}")
      inspect(page.status, content="200")
      inspect(page.html.length() > 1000, content="true")
      // 重定向后 url 应为 www.bing.com
      inspect(page.url.contains("www.bing.com"), content="true")
    }
    Err(err) => debug("network unavailable: \{err}")
  }
}

///|
async test "fetch follows redirect without proxy when direct works" {
  let outcome = try {
    Ok(fetch_page("https://www.bing.com"))
  } catch {
    err => Err(err)
  }
  match outcome {
    Ok(page) => {
      debug("direct status: \{page.status}, url: \{page.url}")
      inspect(page.status, content="200")
    }
    Err(err) => debug("direct network unavailable: \{err}")
  }
}

///|
test "split_url and resolve_location" {
  let (host, path) = split_url("https://www.bing.com/search?q=moui")
  inspect(host, content="https://www.bing.com")
  inspect(path, content="/search?q=moui")
  let (host2, path2) = split_url("http://example.com")
  inspect(host2, content="http://example.com")
  inspect(path2, content="/")
  inspect(resolve_location("/en-us", "https://www.bing.com/x"), content="https://www.bing.com/en-us")
  inspect(
    resolve_location("https://cn.bing.com", "https://www.bing.com/x"),
    content="https://cn.bing.com",
  )
}

///|
test "resolve_url relative without leading slash" {
  inspect(resolve_url("https://news.ycombinator.com", "news.css"), content="https://news.ycombinator.com/news.css")
  inspect(resolve_url("https://www.bing.com/rp/x.js", "/rp/y.js"), content="https://www.bing.com/rp/y.js")
}
