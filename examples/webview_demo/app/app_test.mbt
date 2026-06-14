///|
test "webview demo omits platform view when host reports unavailable" {
  let runtime = test_runtime(
    program(
      commands=@host.HostWebViewCommandQueue::new(),
      capabilities=@host.HostWebViewCapabilities::unavailable(),
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
      commands=@host.HostWebViewCommandQueue::new(),
      capabilities=@host.HostWebViewCapabilities::native_available(),
    ),
    width=960.0,
    height=640.0,
  )
  let frame = runtime.draw_frame()
  inspect(frame.platform_views.length(), content="1")
  inspect(frame.platform_views[0].id, content="webview-demo-main")
  inspect(frame.platform_views[0].url, content=default_url)
}

///|
fn test_runtime(
  program : @core.Program[Model, Msg],
  width~ : Double,
  height~ : Double,
) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(program~, width~, height~)
}
