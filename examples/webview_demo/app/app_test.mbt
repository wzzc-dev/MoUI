///|
test "webview demo omits platform view when host reports unavailable" {
  let runtime = test_runtime(
    program(
      commands=@webview_host.HostWebViewCommandQueue::new(),
      capabilities=@webview_host.HostWebViewCapabilities::unavailable(),
    ),
    width=960.0,
    height=640.0,
  )
  let frame = runtime.draw_frame()
  inspect(frame.platform_views.length(), content="0")
}

///|
test "webview demo emits native placement with default url when available" {
  let runtime = test_runtime(
    program(
      commands=@webview_host.HostWebViewCommandQueue::new(),
      capabilities=@webview_host.HostWebViewCapabilities::native_available(),
    ),
    width=960.0,
    height=640.0,
  )
  let frame = runtime.draw_frame()
  inspect(frame.platform_views.length(), content="1")
  inspect(frame.platform_views[0].id, content="webview-demo-main")
  inspect(frame.platform_views[0].property_or("url", ""), content=default_url)
}

///|
/// Regression: `expanded(browser_surface)` must share the row with the
/// `status_panel` instead of letting the greedy `web_view` consume the full
/// width. Before the fix `web_view` measured the whole row width (greedy
/// `unwrap_or(max)`), `expanded` had no slack to grow into, and the
/// `status_panel` was pushed off-screen.
test "webview demo keeps web view and status panel side by side" {
  let runtime = test_runtime(
    program(
      commands=@webview_host.HostWebViewCommandQueue::new(),
      capabilities=@webview_host.HostWebViewCapabilities::native_available(),
    ),
    width=960.0,
    height=640.0,
  )
  let frame = runtime.draw_frame()
  inspect(frame.platform_views.length(), content="1")
  let web = frame.platform_views[0].frame
  // The web view must stay inside the browser surface (left of the status
  // panel) rather than spanning the whole window width.
  inspect(web.size.width, content="908")
  inspect(web.size.height, content="588")
}

///|
fn test_runtime(
  program : @moui.Program[Model, Msg],
  width~ : Double,
  height~ : Double,
) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(program~, width~, height~)
}
