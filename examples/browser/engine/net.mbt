///|
/// 页面抓取层(纯 MoonBit):https + 重定向跟随 + 可选代理。
///
/// 说明:当前 demo 的实际导航走 `net_bridge.mbt`(curl 后台线程)。
/// 本模块是纯 MoonBit 网络栈(async API),测试通过,供后续 M3 接入。
/// 协程模型:MoonBit async 的 native event loop 单线程协作式调度,
/// 本模块不跨线程共享状态。

///|
pub struct PageLoad {
  url : String
  status : Int
  html : String
}

///|
pub suberror NetError {
  InvalidUrl(String)
  Network(String)
  Redirect(String)
}

///|
pub impl Show for NetError with fn output(self, logger) {
  match self {
    InvalidUrl(msg) => logger.write_string("InvalidUrl(" + msg + ")")
    Network(msg) => logger.write_string("Network(" + msg + ")")
    Redirect(msg) => logger.write_string("Redirect(" + msg + ")")
  }
}

///|
/// 抓取一个页面,跟随重定向(最多 5 跳)。
/// `proxy` 非 None 时,直连失败会自动经代理重试一次。
pub async fn fetch_page(
  url : String,
  proxy? : String? = None,
) -> PageLoad raise NetError {
  let mut current = url
  let mut hops = 0
  let mut use_proxy = proxy
  while hops <= 5 {
    let raw = one_request(current, use_proxy) catch {
      err =>
        match use_proxy {
          // 已经走代理还失败:放弃
          Some(_) => raise err
          None =>
            match proxy {
              // 直连失败且配置了代理:改走代理,并记住后续请求都走代理
              Some(p) => {
                use_proxy = Some(p)
                one_request(current, Some(p)) catch {
                  _ => raise err
                }
              }
              None => raise err
            }
        }
    }
    if raw.status >= 300 && raw.status < 400 {
      match raw.header("location") {
        Some(loc) => {
          current = resolve_location(loc, current)
          hops = hops + 1
        }
        None => return { url: current, status: raw.status, html: raw.body }
      }
    } else {
      return { url: current, status: raw.status, html: raw.body }
    }
  }
  raise NetError::Redirect("too many redirects: " + url)
}

///|
priv struct RawResponse {
  status : Int
  headers : Map[String, String]
  body : String
}

///|
fn RawResponse::header(self : RawResponse, name : String) -> String? {
  match self.headers.get(name) {
    Some(value) => Some(value)
    None =>
      // headers 已统一小写;查找时也试原样
      match self.headers.get(name.to_lower()) {
        Some(value) => Some(value)
        None => None
      }
  }
}

///|
async fn one_request(
  url : String,
  proxy_url : String?,
) -> RawResponse raise NetError {
  let (host, path) = split_url(url)
  let client = match proxy_url {
    Some(proxy_url) => {
      let proxy_client = @async_http.Client(proxy_url) catch {
        _ => raise NetError::InvalidUrl("invalid proxy url: " + proxy_url)
      }
      @async_http.Client(host, proxy=proxy_client) catch {
        _ => raise NetError::InvalidUrl("invalid url: " + url)
      }
    }
    None =>
      @async_http.Client(host) catch {
        _ => raise NetError::InvalidUrl("invalid url: " + url)
      }
  }
  let response = client.get(path) catch {
    err => {
      client.close()
      raise NetError::Network(
        "network error for " + url + ": " + err.to_string(),
      )
    }
  }
  let body = @async_io.Reader::read_all(client).text() catch {
    err => {
      client.close()
      raise NetError::Network("read error for " + url + ": " + err.to_string())
    }
  }
  client.close()
  let headers : Map[String, String] = Map([])
  for k, v in response.headers {
    headers[k.to_string().to_lower()] = v
  }
  { status: response.code, headers, body }
}
