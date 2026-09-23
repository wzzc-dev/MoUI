///|
test "webview demo omits platform view without a composition-root controller" {
  let runtime = test_runtime(
    @app.program(capability=@app.WebViewCapability::unavailable()),
    width=960.0,
    height=640.0,
  )
  let frame = runtime.draw_frame()
  inspect(frame.platform_views.length(), content="0")
}

///|
test "webview demo keeps pure app tests independent of native controller" {
  let runtime = test_runtime(
    @app.program(capability=@app.WebViewCapability::available()),
    width=960.0,
    height=640.0,
  )
  let frame = runtime.draw_frame()
  inspect(frame.platform_views.length(), content="0")
}

///|
test "webview commands have no effect without an injected controller" {
  let program = @app.program(capability=@app.WebViewCapability::available())
  let (model, _effect) = program.runtime_init()
  let (_next, effect) = program.runtime_update(model, Reload)
  inspect(@runtime.effect_plan_summary(effect).run_count(), content="0")
}

///|
fn test_runtime(
  program : @moui.Program[@app.Model, @app.Msg],
  width~ : Double,
  height~ : Double,
) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(program~, width~, height~)
}
