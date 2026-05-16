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

///|
test "native renderer plans visual primitives instead of fallback-only batches" {
  let renderer = new_test_renderer_handle()
  renderer.resize(@core.Size::new(width=320.0, height=200.0))
  let rounded = @core.RoundedRect::new(
    rect=@core.Rect::new(x=10.0, y=20.0, width=80.0, height=40.0),
    radius=8.0,
  )
  renderer.render([
    @core.DrawCommand::FillRoundedRectBrush(
      rounded,
      @core.Brush::linear_gradient(
        start=@core.Point::new(x=10.0, y=20.0),
        end=@core.Point::new(x=90.0, y=60.0),
        start_color=@core.Color::blue(),
        end_color=@core.Color::gray(),
      ),
    ),
    @core.DrawCommand::DrawShadow(
      @core.ShadowSpec::new(
        rect=rounded,
        color=@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.35),
        blur_radius=12.0,
        spread=2.0,
      ),
    ),
  ])
  inspect(renderer.visual_vertices.length(), content="12")
  inspect(renderer.draw_items.length(), content="2")
  assert_true(renderer.visual_vertices[0].r0 == @core.Color::blue().r)
  assert_true(renderer.visual_vertices[0].r1 == @core.Color::gray().r)
  assert_true(renderer.visual_vertices[6].mode == visual_mode_shadow)
  assert_true(renderer.visual_vertices[6].blur_radius == 12.0)
}
