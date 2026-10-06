///|
/// 静态服务的纯逻辑测试(MIME/防穿越)与 async 全链测试
/// (绑端口 0 → HTTP GET 断言 → close 优雅退出)。

///|
test "MIME 映射:wasm 必须是 application/wasm" {
  assert_eq(mime_for("/x/counter.wasm"), "application/wasm")
  assert_eq(mime_for("/x/index.html"), "text/html")
  assert_eq(mime_for("/x/app.mjs"), "text/javascript")
  assert_eq(mime_for("/x/style.css"), "text/css")
  assert_eq(mime_for("/x/data.json"), "application/json")
  assert_eq(mime_for("/x/logo.svg"), "image/svg+xml")
  assert_eq(mime_for("/x/unknown.bin"), "application/octet-stream")
}

///|
test "路径安全:拒绝穿越与反斜杠" {
  assert_eq(safe_join("/index.html"), Some("/index.html"))
  assert_eq(safe_join(""), Some("/"))
  assert_eq(safe_join("/a/../.."), None)
  assert_eq(safe_join("/../../etc/passwd"), None)
  assert_eq(safe_join("/a\\b"), None)
  assert_eq(safe_join("/dir/sub/file.js"), Some("/dir/sub/file.js"))
}

///|
test "查询串剥离" {
  assert_eq(strip_query("/index.html?v=2"), "/index.html")
  assert_eq(strip_query("/index.html"), "/index.html")
}

///|
/// 绑定与端口管理:端口 0 → OS 分配,addr().port() 读回实际值。
/// (serve 循环为无限运行,其真实 GET 验证由 M2 第二步的真 webview 承担;
/// 放进单测会让测试进程被无限 accept 循环挂住。)
async test "静态服务绑定:端口 0 → 实际端口回读 → close" {
  let dir = "/tmp/studio-webpreview-bind"
  @fs.mkdir(dir, recursive=true) catch {
    _ => ()
  } // 已存在亦可
  let server = match bind_static_server() {
    Ok(server) => server
    Err(message) => fail(message)
  }
  assert_true(server.port() > 0, msg="OS 应分配非零端口")
  server.set_directory(dir)
  assert_true(server.url().has_prefix("http://127.0.0.1:"), msg=server.url())
  server.server.close()
}

///|
/// 真机验证(M2-3):在真实 counter 工程上跑 workspace 根探测——
/// counter 是本仓库 moon.work 的成员,应探出仓库根(含 moon.work)。
/// 检出位置无关:CI/其他开发者用 MOUI_TEST_PROJECT_ROOT 指定仓库根,或
/// 依赖 CI 自动提供的 GITHUB_WORKSPACE;缺省回退本仓常用检出路径。
async test "workspace 根探测:counter 真工程" {
  let workspace_root = @env.get_env_var("MOUI_TEST_PROJECT_ROOT")
    .unwrap_or(
      @env.get_env_var("GITHUB_WORKSPACE").unwrap_or(
        "/Volumes/Data/Code/moon/MoUI",
      ),
    )
  let root = workspace_root_for(workspace_root + "/examples/counter")
  assert_true(
    root.has_prefix(workspace_root),
    msg="应探出仓库根,实际:\{root}",
  )
  assert_true(
    @fs.exists(root + "/moon.work"),
    msg="探出的根应有 moon.work",
  )
}
