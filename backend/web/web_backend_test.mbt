///|
fn test_renderer() -> @webgpu.WebGpuRenderer {
  test_renderer_impl()
}

///|
extern "js" fn test_renderer_impl() -> @webgpu.WebGpuRenderer =
  #|() => ({
  #|  resize() {},
  #|  begin() {},
  #|  clear() {},
  #|  fillRect() {},
  #|  drawText() {},
  #|  pushClip() {},
  #|  popClip() {},
  #|  present() {},
  #|  dispose() {},
  #|})

///|
test "web app maps resize and schedules redraw" {
  let runtime = @web.runtime_for_canvas(
    root=@core.ViewNode::Empty,
    width=100.0,
    height=80.0,
  )
  let app = @web.WebApp::new(runtime~, renderer=test_renderer())
  let result = app.resize(320.0, 240.0)
  assert_true(runtime.size() == @core.Size::new(width=320.0, height=240.0))
  inspect(result.redraw_requested, content="true")
}

///|
test "web app maps pointer click, rebuilds dynamic root, and requests redraw" {
  let clicked = Ref::new(false)
  let runtime = @backend.AppRuntime::new_dynamic(
    root=() => {
      @core.ViewNode::Button({
        text: if clicked.val {
          "Tapped"
        } else {
          "Tap"
        },
        size: @core.Size::new(width=100.0, height=40.0),
        state: @core.ButtonState::Normal,
        on_click: Some(() => clicked.val = true),
      })
    },
    size=@core.Size::new(width=100.0, height=40.0),
  )
  let app = @web.WebApp::new(runtime~, renderer=test_renderer())
  ignore(app.pointer_down(10.0, 10.0))
  let result = app.pointer_up(10.0, 10.0)
  inspect(clicked.val, content="true")
  inspect(result.needs_rebuild, content="false")
  inspect(result.redraw_requested, content="true")
  guard runtime.draw_commands()
    is [
      _,
      @core.DrawCommand::FillRect(_, _),
      @core.DrawCommand::DrawText({ text: "Tapped", .. }),
    ] else {
    fail("expected dynamic runtime to rebuild clicked button text")
  }
}

///|
test "web boot context exposes renderer and size" {
  let context = test_boot_context_impl()
  ignore(context.renderer())
  inspect(context.width(), content="640")
  inspect(context.height(), content="480")
}

///|
extern "js" fn test_boot_context_impl() -> @web.WebBootContext =
  #|() => ({
  #|  renderer: {
  #|    resize() {},
  #|    begin() {},
  #|    clear() {},
  #|    fillRect() {},
  #|    drawText() {},
  #|    pushClip() {},
  #|    popClip() {},
  #|    present() {},
  #|    dispose() {},
  #|  },
  #|  width: () => 640,
  #|  height: () => 480,
  #|})
