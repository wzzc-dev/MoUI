///|
test "renderer remembers resize and batches" {
  let renderer = new_test_renderer_handle()
  renderer.resize(@core.Size::new(width=320.0, height=200.0))
  renderer.render([
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=1.0, height=1.0),
      @core.Color::gray(),
    ),
  ])
  inspect(renderer.last_batches.length(), content="1")
}
