///|
test "renderer backend info records unified renderer capability" {
  let info = @render.RendererBackendInfo::new(
    backend=@render.RendererBackendKind::WebGpuWasm,
    status=@render.RendererCapabilityStatus::Ready,
    can_render=true,
    can_resize=true,
    owns_surface=false,
    description="wasm-gc browser WebGPU host imports",
  )
  assert_true(info.backend == @render.RendererBackendKind::WebGpuWasm)
  assert_true(info.status == @render.RendererCapabilityStatus::Ready)
  inspect(info.can_render, content="true")
  inspect(info.can_resize, content="true")
}

///|
test "renderer descriptor models backend family selection and presentation" {
  let descriptor = @render.RendererDescriptor::new(
    backend=@render.RendererBackendKind::SkiaRasterNative,
    family=@render.RendererFamily::Skia,
    presentation=@render.RendererPresentationModel::CpuPixelFrame,
    supported_targets=[@render.RendererTarget::Native],
    capabilities=@render.renderer_backend_capabilities(
      @render.RendererBackendKind::SkiaRasterNative,
    ),
    description="test skia raster descriptor",
  )
  assert_true(descriptor.backend.family() == @render.RendererFamily::Skia)
  assert_true(
    descriptor.presentation == @render.RendererPresentationModel::CpuPixelFrame,
  )
  assert_true(
    @render.RendererSelection::Backend(
      @render.RendererBackendKind::SkiaRasterNative,
    ).matches_backend(@render.RendererBackendKind::SkiaRasterNative),
  )
  assert_true(
    @render.RendererSelection::Family(@render.RendererFamily::Skia).matches_backend(
      @render.RendererBackendKind::SkiaRasterNative,
    ),
  )
  assert_false(
    @render.RendererSelection::Default.matches_backend(
      @render.RendererBackendKind::SkiaRasterNative,
    ),
  )
  inspect(descriptor.capabilities.length(), content="17")
}

///|
test "wgpu surface contract distinguishes native and web canvas sources" {
  let contract = @render.WgpuSurfaceContract::new(
    source=@render.WgpuSurfaceSourceKind::WebCanvasSurface,
    backend=@render.RendererBackendKind::WebGpuWasm,
    ready=false,
    description="browser WebGPU surface pending",
  )
  assert_true(
    contract.source == @render.WgpuSurfaceSourceKind::WebCanvasSurface,
  )
  assert_true(contract.backend == @render.RendererBackendKind::WebGpuWasm)
  inspect(contract.ready, content="false")
}

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
test "collect rect batches expands strokes into border rects" {
  let batches = @render.collect_rect_batches([
    @core.DrawCommand::StrokeRect(
      @core.Rect::new(x=2.0, y=3.0, width=10.0, height=8.0),
      @core.Color::blue(),
      1.0,
    ),
  ])
  inspect(batches.length(), content="4")
  assert_true(
    batches[0].rect == @core.Rect::new(x=2.0, y=3.0, width=10.0, height=1.0),
  )
  assert_true(
    batches[1].rect == @core.Rect::new(x=2.0, y=10.0, width=10.0, height=1.0),
  )
  assert_true(
    batches[2].rect == @core.Rect::new(x=2.0, y=4.0, width=1.0, height=6.0),
  )
  assert_true(
    batches[3].rect == @core.Rect::new(x=11.0, y=4.0, width=1.0, height=6.0),
  )
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
test "rounded rects are collectable as rect batches for simple renderers" {
  let batches = @render.collect_rect_batches([
    @core.DrawCommand::FillRoundedRect(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=1.0, y=2.0, width=30.0, height=40.0),
        radius=6.0,
      ),
      @core.Color::gray(),
    ),
  ])
  inspect(batches.length(), content="1")
  assert_true(
    batches[0].rect == @core.Rect::new(x=1.0, y=2.0, width=30.0, height=40.0),
  )
}

///|
test "stroke rounded rects use the same fallback batch geometry as stroke rects" {
  let rounded = @render.collect_rect_batches([
    @core.DrawCommand::StrokeRoundedRect(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=2.0, y=3.0, width=10.0, height=8.0),
        radius=5.0,
      ),
      @core.Color::blue(),
      1.0,
    ),
  ])
  let square = @render.collect_rect_batches([
    @core.DrawCommand::StrokeRect(
      @core.Rect::new(x=2.0, y=3.0, width=10.0, height=8.0),
      @core.Color::blue(),
      1.0,
    ),
  ])
  assert_true(rounded == square)
}

///|
test "non-rect commands do not leak into native rect batches" {
  let batches = @render.collect_rect_batches([
    @core.DrawCommand::DrawText({
      text: "Hello",
      frame: @core.Rect::new(x=0.0, y=0.0, width=40.0, height=20.0),
      font: @core.FontSpec::new(size=14.0),
      color: @core.Color::black(),
      align: @core.TextAlign::TextCenter,
    }),
    @core.DrawCommand::DrawImage({
      source: "logo.png",
      frame: @core.Rect::new(x=0.0, y=0.0, width=40.0, height=20.0),
      opacity: 0.8,
      fit: @core.ImageFit::Contain,
    }),
    @core.DrawCommand::PushClip(
      @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
    ),
    @core.DrawCommand::PushTransform(@core.Transform2D::identity()),
    @core.DrawCommand::PushOpacity(0.5),
    @core.DrawCommand::PopOpacity,
    @core.DrawCommand::PopTransform,
    @core.DrawCommand::PopClip,
  ])
  inspect(batches.length(), content="0")
}

///|
test "brush commands degrade to deterministic rect batches" {
  let rounded = @core.RoundedRect::new(
    rect=@core.Rect::new(x=1.0, y=2.0, width=30.0, height=40.0),
    radius=6.0,
  )
  let batches = @render.collect_rect_batches([
    @core.DrawCommand::FillRoundedRectBrush(
      rounded,
      @core.Brush::linear_gradient(
        start=@core.Point::new(x=0.0, y=0.0),
        end=@core.Point::new(x=1.0, y=1.0),
        start_color=@core.Color::blue(),
        end_color=@core.Color::gray(),
      ),
    ),
    @core.DrawCommand::StrokeRoundedRectBrush(
      rounded,
      @core.Brush::solid(@core.Color::gray()),
      1.0,
    ),
  ])
  inspect(batches.length(), content="5")
  assert_true(batches[0].color == @core.Color::blue())
  assert_true(batches[1].color == @core.Color::gray())
}

///|
test "shadow command degrades to layered rect batches" {
  let batches = @render.collect_rect_batches([
    @core.DrawCommand::DrawShadow(
      @core.ShadowSpec::new(
        rect=@core.RoundedRect::new(
          rect=@core.Rect::new(x=10.0, y=10.0, width=20.0, height=20.0),
          radius=4.0,
        ),
        color=@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.6),
        blur_radius=6.0,
      ),
    ),
  ])
  inspect(batches.length(), content="3")
  assert_true(batches[0].color.a > batches[2].color.a)
}
