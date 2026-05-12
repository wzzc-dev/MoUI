///|
test "collect rect batches" {
  let commands : Array[@core.DrawCommand] = [
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
      @core.Color::blue(),
    ),
  ]
  inspect(@render.collect_rect_batches(commands).length(), content="1")
}

///|
test "renderer remembers resize and batches" {
  let renderer = @render.RendererHandle::new()
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
  try {
    let renderer = @render.RendererHandle::create(
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
