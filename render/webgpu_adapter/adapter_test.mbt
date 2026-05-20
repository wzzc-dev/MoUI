///|
test "wgpu web adapter is wasm-gc host-import only" {
  let info = adapter_info()
  assert_true(info.renderer.backend == @render.RendererBackendKind::WebGpuWasm)
  assert_true(info.renderer.status == @render.RendererCapabilityStatus::Ready)
  inspect(info.renderer.can_render, content="true")
  inspect(info.renderer.can_resize, content="true")
  inspect(info.surface_contract.ready, content="true")
  inspect(info.imports.import_module, content="webgpu")
  inspect(info.imports.target, content="wasm-gc")
}

///|
test "wgpu web surface must be created through host port" {
  let created = Ref(0)
  let port = test_port(created~)
  let surface = create_surface(
    canvas_id="moui-web-wasm",
    logical_size=@core.Size::new(width=320.0, height=180.0),
    scale_factor=1.5,
    port~,
  )
  inspect(created.val, content="1")
  inspect(surface.canvas_id, content="moui-web-wasm")
  assert_true(
    surface.metrics.logical_size == @core.Size::new(width=320.0, height=180.0),
  )
  assert_true(
    surface.metrics.physical_size == @core.Size::new(width=480.0, height=270.0),
  )
  inspect(surface.metrics.scale_factor, content="1.5")
}

///|
test "wgpu web renderer forwards resize render and dispose to host port" {
  let created = Ref(0)
  let resized = Ref(0)
  let submitted = Ref(0)
  let disposed = Ref(0)
  let last_calls : Array[WebGpuHostCall] = []
  let port = test_port(
    created~,
    on_resize=() => resized.val = resized.val + 1,
    on_submit=calls => {
      submitted.val = submitted.val + 1
      last_calls.clear()
      for call in calls {
        last_calls.push(call)
      }
    },
    on_dispose=() => disposed.val = disposed.val + 1,
  )
  let renderer = create_renderer(
    canvas_id="moui-web-wasm",
    logical_size=@core.Size::new(width=100.0, height=50.0),
    port~,
  )
  inspect(created.val, content="1")
  renderer.resize(
    @render.RendererSurfaceMetrics::from_logical(
      size=@core.Size::new(width=200.0, height=100.0),
    ),
  )
  renderer.render([
    @core.DrawCommand::Clear(@core.Color::white()),
    @core.DrawCommand::FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
      @core.Color::blue(),
    ),
    @core.DrawCommand::DrawText({
      text: "Hello",
      frame: @core.Rect::new(x=0.0, y=0.0, width=40.0, height=20.0),
      font: @core.FontSpec::new(size=14.0),
      color: @core.Color::black(),
      align: @core.TextAlign::TextCenter,
    }),
  ])
  renderer.dispose()
  inspect(resized.val, content="1")
  inspect(submitted.val, content="1")
  inspect(disposed.val, content="1")
  inspect(renderer.present_count(), content="1")
  inspect(last_calls.length(), content="5")
  assert_true(last_calls[0] is WebGpuHostCall::BeginFrame(_))
  assert_true(last_calls[1] is WebGpuHostCall::Clear(_))
  assert_true(last_calls[2] is WebGpuHostCall::FillRect(_, _))
  assert_true(last_calls[3] is WebGpuHostCall::DrawText(_))
  assert_true(last_calls[4] is WebGpuHostCall::Present)
}

///|
test "wgpu web renderer fails startup when host lacks capabilities" {
  let result = try? create_renderer(
    canvas_id="moui-web-wasm",
    logical_size=@core.Size::new(width=100.0, height=50.0),
    port=test_port(created=Ref(0), capabilities={
      webgpu_available: false,
      adapter_ready: true,
      can_render: true,
    }),
  )
  match result {
    Err(WebGpuHostError::Unavailable) => ()
    _ => fail("expected unavailable host error")
  }
}

///|
test "wgpu web command bridge covers image command in host ABI" {
  let calls = draw_commands_to_host_calls(
    [
      @core.DrawCommand::DrawImage({
        source: "logo.png",
        frame: @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
        opacity: 1.0,
        fit: @core.ImageFit::Contain,
      }),
    ],
    @core.Size::new(width=100.0, height=50.0),
  )
  inspect(calls.length(), content="3")
  assert_true(calls[0] is WebGpuHostCall::BeginFrame(_))
  assert_true(calls[1] is WebGpuHostCall::DrawImage(_))
  assert_true(calls[2] is WebGpuHostCall::Present)
}

///|
test "wgpu web command bridge preserves full draw command parity order" {
  let rect = @core.Rect::new(x=1.0, y=2.0, width=30.0, height=40.0)
  let rounded = @core.RoundedRect::new(rect~, radius=6.0)
  let calls = draw_commands_to_host_calls(
    [
      @core.DrawCommand::Clear(@core.Color::white()),
      @core.DrawCommand::FillRect(rect, @core.Color::blue()),
      @core.DrawCommand::StrokeRect(rect, @core.Color::gray(), 1.0),
      @core.DrawCommand::FillRoundedRect(rounded, @core.Color::gray()),
      @core.DrawCommand::StrokeRoundedRect(rounded, @core.Color::blue(), 2.0),
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
      @core.DrawCommand::DrawShadow(
        @core.ShadowSpec::new(
          rect=rounded,
          color=@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.4),
        ),
      ),
      @core.DrawCommand::DrawText({
        text: "Hello",
        frame: rect,
        font: @core.FontSpec::new(size=14.0),
        color: @core.Color::black(),
        align: @core.TextAlign::TextStart,
      }),
      @core.DrawCommand::DrawImage({
        source: "logo.png",
        frame: rect,
        opacity: 0.75,
        fit: @core.ImageFit::Contain,
      }),
      @core.DrawCommand::PushClip(rect),
      @core.DrawCommand::PushTransform(@core.Transform2D::identity()),
      @core.DrawCommand::PushOpacity(0.5),
      @core.DrawCommand::PopOpacity,
      @core.DrawCommand::PopTransform,
      @core.DrawCommand::PopClip,
    ],
    @core.Size::new(width=100.0, height=50.0),
  )
  inspect(calls.length(), content="18")
  assert_true(calls[0] is WebGpuHostCall::BeginFrame(_))
  assert_true(calls[1] is WebGpuHostCall::Clear(_))
  assert_true(calls[2] is WebGpuHostCall::FillRect(_, _))
  assert_true(calls[3] is WebGpuHostCall::StrokeRect(_, _, _))
  assert_true(calls[4] is WebGpuHostCall::FillRoundedRect(_, _))
  assert_true(calls[5] is WebGpuHostCall::StrokeRoundedRect(_, _, _))
  assert_true(calls[6] is WebGpuHostCall::FillRoundedRectBrush(_, _))
  assert_true(calls[7] is WebGpuHostCall::StrokeRoundedRectBrush(_, _, _))
  assert_true(calls[8] is WebGpuHostCall::DrawShadow(_))
  guard calls[9] is WebGpuHostCall::DrawText({ align, .. }) else {
    fail("expected text call")
  }
  assert_true(align == @core.TextAlign::TextStart)
  assert_true(calls[10] is WebGpuHostCall::DrawImage(_))
  assert_true(calls[11] is WebGpuHostCall::PushClip(_))
  assert_true(calls[12] is WebGpuHostCall::PushTransform(_))
  assert_true(calls[13] is WebGpuHostCall::PushOpacity(_))
  assert_true(calls[14] is WebGpuHostCall::PopOpacity)
  assert_true(calls[15] is WebGpuHostCall::PopTransform)
  assert_true(calls[16] is WebGpuHostCall::PopClip)
  assert_true(calls[17] is WebGpuHostCall::Present)
}

///|
test "wgpu web command bridge preserves gradient and shadow command payloads" {
  let rounded = @core.RoundedRect::new(
    rect=@core.Rect::new(x=10.0, y=20.0, width=80.0, height=40.0),
    radius=8.0,
  )
  let gradient = @core.Brush::linear_gradient(
    start=@core.Point::new(x=10.0, y=20.0),
    end=@core.Point::new(x=90.0, y=60.0),
    start_color=@core.Color::blue(),
    end_color=@core.Color::gray(),
  )
  let shadow = @core.ShadowSpec::new(
    rect=rounded,
    color=@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.4),
    blur_radius=12.0,
    spread=2.0,
  )
  let calls = draw_commands_to_host_calls(
    [
      @core.DrawCommand::FillRoundedRectBrush(rounded, gradient),
      @core.DrawCommand::StrokeRoundedRectBrush(rounded, gradient, 2.0),
      @core.DrawCommand::DrawShadow(shadow),
    ],
    @core.Size::new(width=120.0, height=80.0),
  )
  inspect(calls.length(), content="5")
  assert_true(
    calls[1]
    is WebGpuHostCall::FillRoundedRectBrush(_, @core.Brush::LinearGradient(_)),
  )
  assert_true(
    calls[2]
    is WebGpuHostCall::StrokeRoundedRectBrush(
      _,
      @core.Brush::LinearGradient(_),
      _
    ),
  )
  assert_true(
    calls[3]
    is WebGpuHostCall::DrawShadow({ blur_radius: 12.0, spread: 2.0, .. }),
  )
}

///|
fn test_port(
  created~ : Ref[Int],
  capabilities? : WebGpuHostCapabilities = required_capabilities(),
  on_resize? : () -> Unit = () => (),
  on_submit? : (Array[WebGpuHostCall]) -> Unit = _ => (),
  on_dispose? : () -> Unit = () => (),
) -> WebGpuHostRendererPort {
  {
    capabilities: () => capabilities,
    create_surface: (canvas_id, metrics) => {
      created.val = created.val + 1
      { canvas_id, metrics }
    },
    create_renderer: _surface => (),
    resize: _metrics => on_resize(),
    submit: calls => on_submit(calls),
    dispose: on_dispose,
  }
}
