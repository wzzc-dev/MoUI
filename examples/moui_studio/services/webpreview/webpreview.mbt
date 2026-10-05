///|
/// 本地静态文件服务(M2 第一步,native-only)。
///
/// 用 `moonbitlang/async` 的 `@http.Server` 服务工程构建产物目录,
/// 供 webview(`WebViewController::navigate`)加载:
/// - 端口管理:绑定 `127.0.0.1:0`(OS 分配),从 `server.addr().port()`
///   读回实际端口;
/// - MIME:`.wasm → application/wasm`(wasm-gc 流式编译必需)、html/js/
///   mjs/css/json/图片等;
/// - 路径安全:`..` 段与反斜杠一律拒绝(防目录穿越);
/// - 文件体**流式**服务(open → write_reader),二进制(wasm/图片)安全;
/// - 未知扩展名 → application/octet-stream。
///
/// 服务循环(`serve_forever`)在随从 worker 里跑(与构建 worker 同模式);
/// `Server::close` 可令循环返回(优雅停止)。

///|
/// MIME 映射(按扩展名;未识别 → application/octet-stream)。
pub fn mime_for(path : String) -> String {
  let lower = path.to_lower()
  if lower.has_suffix(".wasm") {
    return "application/wasm"
  }
  if lower.has_suffix(".html") || lower.has_suffix(".htm") {
    return "text/html"
  }
  if lower.has_suffix(".css") {
    return "text/css"
  }
  if lower.has_suffix(".mjs") || lower.has_suffix(".js") {
    return "text/javascript"
  }
  if lower.has_suffix(".json") {
    return "application/json"
  }
  if lower.has_suffix(".svg") {
    return "image/svg+xml"
  }
  if lower.has_suffix(".png") {
    return "image/png"
  }
  if lower.has_suffix(".jpg") || lower.has_suffix(".jpeg") {
    return "image/jpeg"
  }
  if lower.has_suffix(".gif") {
    return "image/gif"
  }
  if lower.has_suffix(".ico") {
    return "image/x-icon"
  }
  if lower.has_suffix(".txt") {
    return "text/plain"
  }
  "application/octet-stream"
}

///|
/// URL 路径安全检查:拒绝 `..` 段与反斜杠(防目录穿越)。
/// 返回规范化的 URL 路径(空 → "/")或 None(拒绝)。
pub fn safe_join(url_path : String) -> String? {
  let normalized = if url_path == "" { "/" } else { url_path }
  let chars : Array[Char] = []
  for c in normalized {
    chars.push(c)
  }
  let n = chars.length()
  let mut i = 0
  while i < n {
    if chars[i] == '\\' {
      return None
    }
    if chars[i] == '.' && i + 1 < n && chars[i + 1] == '.' {
      let prev_ok = i == 0 || chars[i - 1] == '/'
      let next_idx = i + 2
      let next_ok = next_idx >= n || chars[next_idx] == '/'
      if prev_ok && next_ok {
        return None
      }
    }
    i = i + 1
  }
  Some(normalized)
}

///|
/// 从 URL 路径剥查询串("?..." 之后)。
pub fn strip_query(url_path : String) -> String {
  match url_path.rev_find("?") {
    Some(idx) => url_path[:idx].to_owned()
    None => url_path
  }
}

///|
/// 静态服务句柄:绑定的 http server + 实际端口 + **动态**服务目录
/// (Ref——服务先于导入存在,目录在构建回执后由 app 经闭包设置)。
pub(all) struct StaticServer {
  server : @http.Server
  port : Int
  directory : Ref[String]
}

///|
pub fn StaticServer::set_directory(
  self : StaticServer,
  directory : String,
) -> Unit {
  self.directory.val = directory
}

///|
pub fn StaticServer::port(self : StaticServer) -> Int {
  self.port
}

///|
pub fn StaticServer::url(self : StaticServer) -> String {
  "http://127.0.0.1:\{self.port}/"
}

///|
/// 绑定静态服务:127.0.0.1 + OS 分配端口,构造即绑定,读回实际端口。
/// 服务循环随后由 `serve_forever` 在随从 worker 里驱动。
pub async fn bind_static_server() -> Result[StaticServer, String] {
  let addr = @socket.Addr::parse("127.0.0.1:0") catch {
    err => return Err("无法解析回环地址:\{err}")
  }
  let server = @http.Server(addr) catch {
    err => return Err("无法绑定静态服务端口:\{err}")
  }
  let port = server.addr.port()
  Ok(StaticServer::{ server, port, directory: Ref("/"), })
}

///|
async fn reject(
  conn : @http.ServerConnection,
  code : Int,
  reason : String,
  body : String,
) -> Unit {
  conn
  ..send_response(code, reason, extra_headers={ "Content-Type": "text/plain" })
  ..write(body)
  .end_response()
}

///|
/// 服务循环:GET only;"/" 尝试 index.html;穿越 403;缺失 404;
/// 读取失败 500;成功按 MIME 流式返回。`Server::close` 令本循环返回。
pub async fn serve_forever(server : StaticServer) -> Unit {
  server.server.run_forever((request, _body, conn) => {
    guard request.meth is Get else { return }
    let url_path = strip_query(request.path)
    let relative = match safe_join(url_path) {
      Some(relative) => relative
      None => {
        let _ = reject(conn, 403, "Forbidden", "path traversal rejected")
        return
      }
    }
    let directory = server.directory.val
    let file_path = if relative == "/" {
      directory + "/index.html"
    } else {
      directory + relative
    }
    if !@fs.exists(file_path) {
      let _ = reject(conn, 404, "NotFound", "not found: \{relative}")
      return
    }
    let file = @fs.open(file_path, mode=ReadOnly) catch {
      err => {
        let _ = reject(conn, 500, "ServerError", "open failed: \{err}")
        return
      }
    }
    defer file.close()
    conn
    ..send_response(200, "OK", extra_headers={
      "Content-Type": mime_for(file_path),
      "Content-Length": file.size().to_string(),
    })
    ..write_reader(file)
    .end_response()
  })
}

///|
/// workspace 根探测:从工程根向上找 `moon.work`(moon 把 `_build` 放在
/// workspace 根;独立模块无 workspace → 模块根自身)。静态服务的服务
/// 目录必须是这个根——index.html 里 `../../../_build/...` 的相对引用
/// 才能解析。
pub async fn workspace_root_for(project_root : String) -> String {
  let mut current = project_root
  let mut hops = 0
  while hops < 16 {
    hops = hops + 1
    if @fs.exists(current + "/moon.work") {
      return current
    }
    match current.rev_find("/") {
      Some(idx) if idx > 0 => current = current[:idx].to_owned()
      _ => break
    }
  }
  project_root
}
