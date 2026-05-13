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
test "rect batches convert to colored vertices" {
  let batches : Array[@render.RectBatch] = [
    {
      rect: @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
      color: @core.Color::blue(),
    },
  ]
  let vertices = @render.rect_batches_to_vertices(
    batches,
    @core.Size::new(width=100.0, height=100.0),
  )
  inspect(vertices.length(), content="6")
  assert_true(
    vertices[0] == { x: -1.0, y: 1.0, r: 0.12, g: 0.36, b: 0.95, a: 1.0 },
  )
  assert_true(vertices[2].x == -0.8)
  assert_true(vertices[2].y == 0.8)
  inspect(@render.rect_vertices_to_bytes(vertices).length(), content="144")
}

///|
test "clear only commands produce empty rect vertices" {
  let batches = @render.collect_rect_batches([
    @core.DrawCommand::Clear(@core.Color::white()),
  ])
  inspect(batches.length(), content="0")
  inspect(
    @render.rect_batches_to_vertices(
      batches,
      @core.Size::new(width=100.0, height=100.0),
    ).length(),
    content="0",
  )
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
