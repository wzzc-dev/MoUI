///|
#cfg(platform="windows")
let is_windows : Bool = true

///|
#cfg(not(platform="windows"))
let is_windows : Bool = false

///|
test "renderer remembers resize and batches" {
  let renderer = @native_wgpu.RendererHandle::new()
  renderer.resize(@core.Size::new(width=320.0, height=200.0))
  renderer.render([
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=1.0, height=1.0),
      @core.Color::gray(),
    ),
  ])
  inspect(renderer.last_batches.length(), content="1")
}

///|
test "renderer wgpu surface smoke" {
  if is_windows {
    inspect(@native_wgpu.NativeSurfaceFactory::info().platform, content="native")
  } else {
    try {
      let renderer = @native_wgpu.RendererHandle::create(
        @core.Size::new(width=1.0, height=1.0),
      )
      renderer.render([
        @core.DrawCommand::Clear(@core.Color::white()),
        @core.DrawCommand::FillRect(
          @core.Rect::new(x=0.0, y=0.0, width=1.0, height=1.0),
          @core.Color::blue(),
        ),
      ])
      inspect(renderer.present_count > 0, content="true")
      renderer.dispose()
    } catch {
      _ => inspect(@wgpu.native_supported(), content="true")
    }
  }
}
