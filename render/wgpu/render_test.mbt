///|
test "wgpu renderer package re-exports native renderer boundary" {
  let renderer = create_placeholder()
  renderer.resize(@core.Size::new(width=64.0, height=48.0))
  renderer.render([
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
      @core.Color::gray(),
    ),
  ])
  inspect(renderer.last_batch_count(), content="1")
}

///|
test "wgpu facade keeps legacy placeholder alias" {
  let renderer = create_renderer_placeholder()
  renderer.render([])
  inspect(renderer.last_batch_count(), content="0")
}
