///|
test "renderer backend info records unified renderer capability" {
  let info = @render.RendererBackendInfo::new(
    backend=@render.RendererBackendKind::WebGpuWasm,
    status=@render.RendererCapabilityStatus::Supported,
    can_render=true,
    can_resize=true,
    owns_surface=false,
    description="wasm-gc browser WebGPU host imports",
  )
  assert_true(info.backend == @render.RendererBackendKind::WebGpuWasm)
  assert_true(info.status == @render.RendererCapabilityStatus::Supported)
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
  assert_true(
    @render.RendererSelection::Family(@render.RendererFamily::Sun).matches_backend(
      @render.RendererBackendKind::SunRasterNative,
    ),
  )
  assert_true(
    @render.RendererBackendKind::SunRasterNative.family() ==
    @render.RendererFamily::Sun,
  )
  inspect(
    @render.RendererBackendKind::SunRasterNative.label(),
    content="sun-raster-native",
  )
  inspect(@render.RendererFamily::Sun.label(), content="sun")
  assert_true(
    @render.RendererSelection::native_default().matches_backend(
      @render.RendererBackendKind::SkiaRasterNative,
    ),
  )
  assert_true(
    @render.RendererSelection::web_default().matches_backend(
      @render.RendererBackendKind::WebGpuWasm,
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
    batches[0].rect() == @core.Rect::new(x=1.0, y=2.0, width=30.0, height=40.0),
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
    @core.DrawCommand::FillRoundedRectBrush(
      rounded,
      @core.Brush::radial_gradient(
        center=@core.Point::new(x=15.0, y=20.0),
        radius=24.0,
        center_color=@core.Color::rgba(r=0.8, g=0.1, b=0.1),
        edge_color=@core.Color::gray(),
      ),
    ),
    @core.DrawCommand::StrokeRoundedRectBrush(
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
  assert_true(batches[0].color().a > batches[2].color().a)
}

///|
test "render mailbox keeps one in-flight and latest pending frame" {
  let mailbox = @render.RenderFrameMailbox::new()
  let input = @render.RenderFrameInput::new(
    metrics=@render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=100.0, height=80.0),
    ),
    commands=[],
  )
  let first = mailbox.submit(input)
  match mailbox.begin_next() {
    Some(packet) => assert_true(packet.sequence == first)
    None => fail("expected first render packet")
  }
  ignore(mailbox.submit(input))
  let latest = mailbox.submit(input)
  assert_true(mailbox.begin_next() is None)
  assert_true(mailbox.complete(first))
  match mailbox.begin_next() {
    Some(packet) => assert_true(packet.sequence == latest)
    None => fail("expected latest pending render packet")
  }
  let diagnostics = mailbox.diagnostics()
  inspect(diagnostics.replaced_pending, content="1")
  inspect(diagnostics.submitted, content="3")
}

///|
/// Phase 2.1 (ADR 0006 § Renderer-thread ownership): control messages are
/// appended to an unbounded ordered queue and never dropped, even when the
/// runtime/UI thread floods frame submissions.
test "render mailbox control queue is ordered and never dropped" {
  let mailbox = @render.RenderFrameMailbox::new()
  assert_false(mailbox.has_control())
  inspect(mailbox.control_pending(), content="0")
  ignore(
    mailbox.submit_control(
      @render.RendererControlMessage::Resize(
        @core.Size::new(width=200.0, height=120.0),
      ),
    ),
  )
  ignore(mailbox.submit_control(@render.RendererControlMessage::Detach))
  ignore(
    mailbox.submit_control(
      @render.RendererControlMessage::ContextLoss("metal-device-lost"),
    ),
  )
  ignore(mailbox.submit_control(@render.RendererControlMessage::Shutdown))
  assert_true(mailbox.has_control())
  inspect(mailbox.control_pending(), content="4")
  let drained = mailbox.drain_control()
  inspect(drained.length(), content="4")
  // FIFO order preserved: Resize, Detach, ContextLoss, Shutdown.
  match drained[0] {
    Resize(size) => {
      inspect(size.width, content="200")
      inspect(size.height, content="120")
    }
    _ => fail("expected Resize as first control message")
  }
  assert_true(drained[1] is Detach)
  match drained[2] {
    ContextLoss(reason) => inspect(reason, content="metal-device-lost")
    _ => fail("expected ContextLoss as third control message")
  }
  assert_true(drained[3] is Shutdown)
  // Drain clears the queue.
  assert_false(mailbox.has_control())
  inspect(mailbox.control_pending(), content="0")
  let diagnostics = mailbox.diagnostics()
  inspect(diagnostics.control_submitted, content="4")
  inspect(diagnostics.control_drained, content="4")
  inspect(diagnostics.control_pending, content="0")
}

///|
/// Control messages must coexist with frame submissions: frames follow
/// capacity-two latest-wins (one in-flight + one pending), control messages
/// follow FIFO never-dropped. The renderer thread drains control before
/// beginning the next frame; neither queue interferes with the other.
test "render mailbox control and frame queues coexist without interference" {
  let mailbox = @render.RenderFrameMailbox::new()
  let input = @render.RenderFrameInput::new(
    metrics=@render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=64.0, height=64.0),
    ),
    commands=[],
  )
  // Submit a frame, then a Resize, then more frames. The Resize must
  // survive frame flooding and be drained in order.
  let first = mailbox.submit(input)
  ignore(
    mailbox.submit_control(
      @render.RendererControlMessage::Resize(
        @core.Size::new(width=128.0, height=128.0),
      ),
    ),
  )
  ignore(mailbox.submit(input))
  let latest = mailbox.submit(input)
  ignore(mailbox.submit_control(@render.RendererControlMessage::Shutdown))
  // Frames still behave as capacity-two latest-wins: pending now holds
  // `latest` and `first` was discarded when `latest` replaced the prior
  // pending entry.
  let diagnostics_before = mailbox.diagnostics()
  inspect(diagnostics_before.submitted, content="3")
  inspect(diagnostics_before.control_pending, content="2")
  // Drain control first (renderer thread policy).
  let controls = mailbox.drain_control()
  inspect(controls.length(), content="2")
  assert_true(controls[0] is Resize(_))
  assert_true(controls[1] is Shutdown)
  // Then drain frames. begin_next moves `latest` into in-flight; the
  // first frame was already replaced in the pending slot.
  match mailbox.begin_next() {
    Some(packet) => assert_true(packet.sequence == latest)
    None => fail("expected latest pending frame to survive control drain")
  }
  // in_flight occupied; no second frame to begin.
  assert_true(mailbox.begin_next() is None)
  // Releasing in_flight and beginning again should now return None.
  assert_true(mailbox.complete(latest))
  assert_true(mailbox.begin_next() is None)
  // The discarded `first` sequence must not reappear.
  ignore(first)
  let diagnostics_after = mailbox.diagnostics()
  inspect(diagnostics_after.control_drained, content="2")
  inspect(diagnostics_after.control_pending, content="0")
}

///|
/// A `Shutdown` does not implicitly drop pending control messages: the
/// renderer thread must observe every control message in order, including
/// any queued before the shutdown signal.
test "render mailbox shutdown does not drop earlier control messages" {
  let mailbox = @render.RenderFrameMailbox::new()
  ignore(
    mailbox.submit_control(
      @render.RendererControlMessage::ContextLoss("vulkan-device-lost"),
    ),
  )
  ignore(mailbox.submit_control(@render.RendererControlMessage::Detach))
  ignore(mailbox.submit_control(@render.RendererControlMessage::Shutdown))
  let drained = mailbox.drain_control()
  inspect(drained.length(), content="3")
  assert_true(drained[0] is ContextLoss(_))
  assert_true(drained[1] is Detach)
  assert_true(drained[2] is Shutdown)
}
