///|
test "renderer remembers resize and batches" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=200.0),
    ),
  )
  inspect(renderer.size.width, content="320")
  renderer.render([
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=1.0, height=1.0),
      @core.Color::gray(),
    ),
  ])
  inspect(renderer.last_batches.length(), content="1")
}

///|
test "native renderer tracks logical and physical resize metrics" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::new(
      logical_size=@core.Size::new(width=320.0, height=200.0),
      physical_size=@core.Size::new(width=640.0, height=400.0),
      scale_factor=2.0,
    ),
  )
  inspect(renderer.size.width, content="320")
  inspect(renderer.physical_size.width, content="640")
  inspect(renderer.scale_factor, content="2")
}

///|
test "native renderer default scissor uses physical surface size" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::new(
      logical_size=@core.Size::new(width=320.0, height=200.0),
      physical_size=@core.Size::new(width=640.0, height=400.0),
      scale_factor=2.0,
    ),
  )
  inspect(renderer.effective_physical_size().width, content="640")
  inspect(renderer.effective_physical_size().height, content="400")
}

///|
test "native renderer clipped scissor uses physical pixels" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::new(
      logical_size=@core.Size::new(width=320.0, height=200.0),
      physical_size=@core.Size::new(width=640.0, height=400.0),
      scale_factor=2.0,
    ),
  )
  renderer.render([
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=10.0, y=20.0, width=30.0, height=40.0),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::PopClip,
  ])
  match renderer.draw_items[0] {
    NativeDrawItem::NativeVisual(_, _, Some(scissor)) => {
      inspect(scissor.x, content="20")
      inspect(scissor.y, content="40")
      inspect(scissor.width, content="60")
      inspect(scissor.height, content="80")
    }
    _ => inspect("missing scissor", content="native visual scissor")
  }
}

///|
test "native renderer skips draw items for empty nested clip" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=100.0, height=100.0),
    ),
  )
  renderer.render([
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
    ),
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=20.0, y=20.0, width=10.0, height=10.0),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::PopClip,
    @core.DrawCommand::PopClip,
  ])
  inspect(renderer.draw_items.length(), content="0")
  inspect(renderer.visual_vertices.length(), content="0")
}

///|
test "native renderer skips clip that lands exactly on surface edge" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::new(
      logical_size=@core.Size::new(width=760.0, height=420.0),
      physical_size=@core.Size::new(width=1520.0, height=840.0),
      scale_factor=2.0,
    ),
  )
  renderer.render([
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=28.0, y=420.0, width=120.0, height=72.0),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=28.0, y=420.0, width=120.0, height=72.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::PopClip,
  ])
  inspect(renderer.draw_items.length(), content="0")
  inspect(renderer.visual_vertices.length(), content="0")
}

///|
test "native renderer transforms clip before computing scissor" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::new(
      logical_size=@core.Size::new(width=100.0, height=100.0),
      physical_size=@core.Size::new(width=200.0, height=200.0),
      scale_factor=2.0,
    ),
  )
  renderer.render([
    @core.DrawCommand::PushTransform(
      @core.Transform2D::translation(dx=5.0, dy=7.0),
    ),
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=10.0, y=10.0, width=20.0, height=20.0),
    ),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=40.0, height=40.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::PopClip,
    @core.DrawCommand::PopTransform,
  ])
  match renderer.draw_items[0] {
    NativeDrawItem::NativeVisual(_, _, Some(scissor)) => {
      inspect(scissor.x, content="30")
      inspect(scissor.y, content="34")
      inspect(scissor.width, content="40")
      inspect(scissor.height, content="40")
    }
    _ => fail("expected transformed native visual scissor")
  }
}

///|
test "native renderer plans visual primitives instead of fallback-only batches" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=200.0),
    ),
  )
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

///|
test "native renderer plans image clip transform and opacity commands" {
  let renderer = new_test_renderer_handle()
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=200.0),
    ),
  )
  renderer.render([
    @core.DrawCommand::PushOpacity(0.6),
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=0.0, y=0.0, width=20.0, height=20.0),
    ),
    @core.DrawCommand::PushTransform(
      @core.Transform2D::translation(dx=4.0, dy=8.0),
    ),
    @core.DrawCommand::DrawImage({
      source: "logo.png",
      frame: @core.Rect::new(x=0.0, y=0.0, width=20.0, height=20.0),
      opacity: 0.8,
      fit: @core.ImageFit::Contain,
    }),
    @core.DrawCommand::PopTransform,
    @core.DrawCommand::PopClip,
    @core.DrawCommand::PopOpacity,
  ])
  inspect(renderer.unsupported_command_count, content="0")
  inspect(renderer.draw_items.length(), content="1")
  match renderer.draw_items[0] {
    NativeDrawItem::NativeImage(_, _, Some(scissor), run) => {
      inspect(scissor.x, content="0")
      inspect(scissor.y, content="0")
      inspect(scissor.width, content="20")
      inspect(scissor.height, content="20")
      inspect(run.source, content="logo.png")
      assert_true(run.fit == @core.ImageFit::Contain)
      assert_true(run.opacity > 0.47)
      assert_true(run.opacity < 0.49)
      inspect(run.transform.tx, content="4")
      inspect(run.transform.ty, content="8")
    }
    _ => fail("expected native image item")
  }
}
