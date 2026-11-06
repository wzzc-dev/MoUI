///|
test "renderer backend info records unified renderer capability" {
  let info = @render.RendererBackendInfo::new(
    backend=WebGpuWasm,
    status=Supported,
    can_render=true,
    can_resize=true,
    owns_surface=false,
    description="wasm-gc browser WebGPU host imports",
  )
  assert_true(info.backend == WebGpuWasm)
  assert_true(info.status == Supported)
  inspect(info.can_render, content="true")
  inspect(info.can_resize, content="true")
}

///|
test "renderer descriptor models backend family selection and presentation" {
  let descriptor = @render.RendererDescriptor::new(
    backend=SkiaRasterNative,
    family=Skia,
    presentation=CpuPixelFrame,
    supported_targets=[Native],
    capabilities=@render_common.renderer_provider_capabilities(
      provider_id="test-skia",
      backend=SkiaRasterNative,
      capability_for=_feature => (Supported, "test provider capability"),
    ),
    description="test skia raster descriptor",
  )
  assert_true(descriptor.backend.family() == Skia)
  assert_true(descriptor.presentation == CpuPixelFrame)
  assert_true(
    @render.RendererSelection::Backend(SkiaRasterNative).matches_backend(
      SkiaRasterNative,
    ),
  )
  assert_true(
    @render.RendererSelection::Family(Skia).matches_backend(SkiaRasterNative),
  )
  assert_true(
    @render.RendererSelection::Family(Sun).matches_backend(SunRasterNative),
  )
  assert_true(@render.RendererBackendKind::SunRasterNative.family() == Sun)
  inspect(
    @render.RendererBackendKind::SunRasterNative.label(),
    content="sun-raster-native",
  )
  inspect(@render.RendererFamily::Sun.label(), content="sun")
  assert_true(
    @render.RendererSelection::native_default().matches_backend(
      SkiaRasterNative,
    ),
  )
  assert_true(
    @render.RendererSelection::web_default().matches_backend(WebGpuWasm),
  )
  assert_false(
    @render.RendererSelection::Default.matches_backend(SkiaRasterNative),
  )
  inspect(descriptor.capabilities.length(), content="17")
}

///|
test "wgpu surface contract distinguishes native and web canvas sources" {
  let contract = @render.WgpuSurfaceContract::new(
    source=WebCanvasSurface,
    backend=WebGpuWasm,
    ready=false,
    description="browser WebGPU surface pending",
  )
  assert_true(contract.source == WebCanvasSurface)
  assert_true(contract.backend == WebGpuWasm)
  inspect(contract.ready, content="false")
}

///|
test "collect rect batches" {
  let commands : Array[@core.DrawCommand] = [
    Clear(@core.Color::white()),
    FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
      @core.Color::blue(),
    ),
  ]
  inspect(@render.collect_rect_batches(commands).length(), content="1")
}

///|
test "collect rect batches expands strokes into border rects" {
  let batches = @render.collect_rect_batches([
    StrokeRect(
      @core.Rect::new(x=2.0, y=3.0, width=10.0, height=8.0),
      @core.Color::blue(),
      1.0,
    ),
  ])
  inspect(batches.length(), content="4")
  assert_true(
    batches[0].rect() == @core.Rect::new(x=2.0, y=3.0, width=10.0, height=1.0),
  )
  assert_true(
    batches[1].rect() == @core.Rect::new(x=2.0, y=10.0, width=10.0, height=1.0),
  )
  assert_true(
    batches[2].rect() == @core.Rect::new(x=2.0, y=4.0, width=1.0, height=6.0),
  )
  assert_true(
    batches[3].rect() == @core.Rect::new(x=11.0, y=4.0, width=1.0, height=6.0),
  )
}

///|
test "rect batches convert to colored vertices" {
  let batches : Array[@render.RectBatch] = [
    @render.RectBatch::new(
      rect=@core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
      color=@core.Color::blue(),
    ),
  ]
  let vertices = @render.rect_batches_to_vertices(
    batches,
    @core.Size::new(width=100.0, height=100.0),
  )
  inspect(vertices.length(), content="6")
  assert_true(vertices[0].x() == -1.0)
  assert_true(vertices[0].y() == 1.0)
  assert_true(vertices[0].r() == 0.12)
  assert_true(vertices[0].g() == 0.36)
  assert_true(vertices[0].b() == 0.95)
  assert_true(vertices[0].a() == 1.0)
  assert_true(vertices[2].x() == -0.8)
  assert_true(vertices[2].y() == 0.8)
  inspect(@render.rect_vertices_to_bytes(vertices).length(), content="144")
}

///|
test "clear only commands produce empty rect vertices" {
  let batches = @render.collect_rect_batches([Clear(@core.Color::white())])
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
    FillRoundedRect(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=1.0, y=2.0, width=30.0, height=40.0),
        radius=6.0,
      ),
      @core.Color::gray(),
    ),
  ])
  inspect(batches.length(), content="1")
  assert_true(
    batches[0].rect() == @core.Rect::new(x=1.0, y=2.0, width=30.0, height=40.0),
  )
}

///|
test "stroke rounded rects use the same fallback batch geometry as stroke rects" {
  let rounded = @render.collect_rect_batches([
    StrokeRoundedRect(
      @core.RoundedRect::new(
        rect=@core.Rect::new(x=2.0, y=3.0, width=10.0, height=8.0),
        radius=5.0,
      ),
      @core.Color::blue(),
      1.0,
    ),
  ])
  let square = @render.collect_rect_batches([
    StrokeRect(
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
    DrawText({
      text: "Hello",
      frame: @core.Rect::new(x=0.0, y=0.0, width=40.0, height=20.0),
      font: @core.FontSpec::new(size=14.0),
      color: @core.Color::black(),
      align: TextCenter,
    }),
    DrawImage({
      source: "logo.png",
      frame: @core.Rect::new(x=0.0, y=0.0, width=40.0, height=20.0),
      opacity: 0.8,
      fit: Contain,
      src_rect: None,
    }),
    PushClip(@core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0)),
    PushTransform(@core.Transform2D::identity()),
    PushOpacity(0.5),
    PopOpacity,
    PopTransform,
    PopClip,
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
    FillRoundedRectBrush(
      rounded,
      @core.Brush::linear_gradient(
        start=@core.Point::new(x=0.0, y=0.0),
        end=@core.Point::new(x=1.0, y=1.0),
        start_color=@core.Color::blue(),
        end_color=@core.Color::gray(),
      ),
    ),
    FillRoundedRectBrush(
      rounded,
      @core.Brush::radial_gradient(
        center=@core.Point::new(x=15.0, y=20.0),
        radius=24.0,
        center_color=@core.Color::rgba(r=0.8, g=0.1, b=0.1),
        edge_color=@core.Color::gray(),
      ),
    ),
    StrokeRoundedRectBrush(
      rounded,
      @core.Brush::solid(@core.Color::gray()),
      1.0,
    ),
  ])
  inspect(batches.length(), content="6")
  assert_true(batches[0].color() == @core.Color::blue())
  assert_true(batches[1].color() == @core.Color::rgba(r=0.8, g=0.1, b=0.1))
  assert_true(batches[2].color() == @core.Color::gray())
}

///|
test "shadow command degrades to layered rect batches" {
  let batches = @render.collect_rect_batches([
    DrawShadow(
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
  assert_true(batches[0].color().a > batches[2].color().a)
}

///|
test "render frame result carries diagnostic events" {
  let event = @diagnostics.DiagnosticEvent::new(
    code="renderer.feature.gap",
    severity=@diagnostics.DiagnosticSeverity::Warning,
    domain=@diagnostics.DiagnosticDomain::Render,
    message="text is partial",
  )
  let result = @render.RenderFrameResult::new(presented=true, diagnostics=[
    event,
  ])
  inspect(result.diagnostics.length(), content="1")
  inspect(result.diagnostics[0].code, content="renderer.feature.gap")
}
