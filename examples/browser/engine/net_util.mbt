///|
/// URL 工具(所有目标可用,无网络依赖):
/// 拆 host/path、相对引用解析。

///|
/// 拆出 host 前缀与 path(含 query)。
pub fn split_url(url : String) -> (String, String) {
  let scheme_len = if url.has_prefix("https://") {
    8
  } else if url.has_prefix("http://") {
    7
  } else {
    0
  }
  // 找 host 后的第一个 '/'
  let mut path_start : Int? = None
  for i = scheme_len; i < url.length(); i = i + 1 {
    if url[i].to_int() == '/'.to_int() {
      path_start = Some(i)
      break
    }
  }
  match path_start {
    Some(i) =>
      (
        url.unsafe_substring(start=0, end=i),
        url.unsafe_substring(start=i, end=url.length()),
      )
    None => (url, "/")
  }
}

///|
/// Location/引用解析:支持绝对与相对地址(含无前导 / 的相对路径)。
pub fn resolve_location(location : String, base : String) -> String {
  if location.has_prefix("http://") || location.has_prefix("https://") {
    return location
  }
  // 相对地址:取 base 的 scheme+host 前缀
  let scheme_len = if base.has_prefix("https://") {
    8
  } else if base.has_prefix("http://") {
    7
  } else {
    0
  }
  let mut host_end : Int? = None
  for i = scheme_len; i < base.length(); i = i + 1 {
    if base[i].to_int() == '/'.to_int() {
      host_end = Some(i)
      break
    }
  }
  match host_end {
    Some(i) =>
      if location.has_prefix("/") {
        base.unsafe_substring(start=0, end=i) + location
      } else {
        // 无前导 / 的相对路径(如 "news.css"):补 /
        base.unsafe_substring(start=0, end=i) + "/" + location
      }
    None => base + "/" + location
  }
}
