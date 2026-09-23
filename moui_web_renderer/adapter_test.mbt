///|
test "wgpu web adapter is wasm-gc host-import only" {
  let info = @moui_web_renderer.adapter_info()
  assert_true(info.renderer().backend == WebGpuWasm)
  assert_true(info.renderer().status == Supported)
  inspect(info.renderer().can_render, content="true")
  inspect(info.renderer().can_resize, content="true")
  inspect(info.surface_contract().ready, content="true")
  inspect(info.imports().import_module(), content="webgpu")
  inspect(info.imports().target(), content="wasm-gc")
}

///|
test "browser Canvas2D fallback provider shares the browser host port" {
  let provider = @moui_web_renderer.create_browser_canvas2d_fallback_provider(bind=surface => {
    let renderer = try! @moui_web_renderer.create_renderer(
      canvas_id=surface.surface_id(),
      logical_size=surface.metrics().logical_size,
      scale_factor=surface.metrics().scale_factor,
      port=test_port(created=Ref(0)),
    )
    Bound(renderer.to_renderer_session())
  })
  inspect(provider.id, content="canvas2d")
  assert_true(provider.descriptor.backend == Canvas2DWasm)
  assert_true(provider.descriptor.family == Canvas2D)
  let surface = @render.HostSurface::new(
    surface_id="moui-fallback-canvas",
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=180.0),
      scale_factor=2.0,
    ),
  )
  match provider.bind_surface(surface) {
    Bound(session) => session.dispose()
    Rejected(message) => fail(message)
  }
}

///|
test "wgpu web surface must be created through host port" {
  let created = Ref(0)
  let port = test_port(created~)
  let surface = @moui_web_renderer.create_surface(
    canvas_id="moui-web-wasm",
    logical_size=@core.Size::new(width=320.0, height=180.0),
    scale_factor=1.5,
    port~,
  )
  inspect(created.val, content="1")
  inspect(surface.canvas_id(), content="moui-web-wasm")
  assert_true(
    surface.metrics().logical_size == @core.Size::new(width=320.0, height=180.0),
  )
  assert_true(
    surface.metrics().physical_size ==
    @core.Size::new(width=480.0, height=270.0),
  )
  inspect(surface.metrics().scale_factor, content="1.5")
}

///|
test "wgpu web renderer forwards resize render and dispose to host port" {
  let created = Ref(0)
  let resized = Ref(0)
  let submitted = Ref(0)
  let disposed = Ref(0)
  let last_calls : Array[@moui_web_renderer.WebGpuHostCall] = []
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
  let renderer = @moui_web_renderer.create_renderer(
    canvas_id="moui-web-wasm",
    logical_size=@core.Size::new(width=100.0, height=50.0),
    port~,
  )
  inspect(created.val, content="1")
  renderer.resize(
    @core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=200.0, height=100.0),
    ),
  )
  renderer.render([
    Clear(@core.Color::white()),
    FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
      @core.Color::blue(),
    ),
    DrawText({
      text: "Hello",
      frame: @core.Rect::new(x=0.0, y=0.0, width=40.0, height=20.0),
      font: @core.FontSpec::new(size=14.0),
      color: @core.Color::black(),
      align: TextCenter,
    }),
  ])
  renderer.dispose()
  inspect(resized.val, content="1")
  inspect(submitted.val, content="1")
  inspect(disposed.val, content="1")
  inspect(renderer.present_count(), content="1")
  inspect(last_calls.length(), content="5")
  assert_true(last_calls[0] is BeginFrame(_))
  assert_true(last_calls[1] is Clear(_))
  assert_true(last_calls[2] is FillRect(_, _))
  assert_true(last_calls[3] is DrawText(_))
  assert_true(last_calls[4] is Present)
}

///|
test "wgpu web render_frame materializes the frame clear color" {
  let last_calls : Array[@moui_web_renderer.WebGpuHostCall] = []
  let renderer = @moui_web_renderer.create_renderer(
    canvas_id="moui-web-wasm",
    logical_size=@core.Size::new(width=100.0, height=50.0),
    port=test_port(created=Ref(0), on_submit=calls => {
      last_calls.clear()
      last_calls.append(calls)
    }),
  )
  ignore(
    renderer.render_frame(
      @core.DrawFrame::new(
        commands=[
          FillRect(
            @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
            @core.Color::blue(),
          ),
        ],
        damage=@core.DamageRegion::full("web frame clear contract"),
        clear_color=@core.Color::gray(),
      ),
    ),
  )
  inspect(last_calls.length(), content="4")
  assert_true(last_calls[0] is BeginFrame(_))
  guard last_calls[1] is Clear(color) else { fail("expected frame clear call") }
  assert_true(color == @core.Color::gray())
  assert_true(last_calls[2] is FillRect(_, _))
  assert_true(last_calls[3] is Present)
}

///|
test "wgpu web renderer fails startup when host lacks capabilities" {
  let result = try
    @moui_web_renderer.create_renderer(
      canvas_id="moui-web-wasm",
      logical_size=@core.Size::new(width=100.0, height=50.0),
      port=test_port(
        created=Ref(0),
        capabilities=@moui_web_renderer.WebGpuHostCapabilities::new(
          webgpu_available=false,
          adapter_ready=true,
          can_render=true,
        ),
      ),
    )
  catch {
    e =>
      match e {
        Unavailable => Some(e)
        _ => fail("unexpected error type")
      }
  } noraise {
    _ => None
  }

  match result {
    Some(Unavailable) => ()
    None => fail("expected unavailable host error")
    _ => fail("unexpected error type")
  }
}

///|
test "wgpu web renderer exposes host backed text system" {
  let measured = Ref(0)
  let registered = Ref(0)
  let port = test_port(
    created=Ref(0),
    on_measure=input => {
      measured.val = measured.val + 1
      {
        size: @core.Size::new(
          width=input.text.to_array().length().to_double() * 9.0,
          height=18.0,
        ),
        baseline: 12.0,
        caret_positions: [0.0, 9.0, 18.0],
      }
    },
    on_register=(_family, _data) => registered.val = registered.val + 1,
  )
  let renderer = @moui_web_renderer.create_renderer(
    canvas_id="moui-web-wasm",
    logical_size=@core.Size::new(width=100.0, height=50.0),
    port~,
  )
  let result = renderer
    .text_system()
    .measure_text(
      @core.TextLayoutInput::new(text="hi", font=@core.FontSpec::new(size=14.0)),
    )
  inspect(renderer.text_system().id(), content="webgpu-wasm-host")
  inspect(measured.val, content="1")
  inspect(result.size.width, content="18")
  inspect(result.caret_positions.length(), content="3")
  renderer
  .text_system()
  .register_font_data(Name("Acme"), Bytes::make(4, b'\x00'))
  inspect(registered.val, content="1")
}

///|
fn web_adapter_carets_are_monotonic(carets : Array[Double]) -> Bool {
  if carets.length() <= 1 {
    return true
  }
  for index in 1..<carets.length() {
    if carets[index] < carets[index - 1] {
      return false
    }
  }
  true
}

///|
fn web_adapter_test_measure(
  input : @core.TextLayoutInput,
) -> @core.TextLayoutResult {
  let fallback = @core.TextSystem::fallback().measure_text(input)
  if input.text == "host-zero-fallback" {
    fallback
  } else {
    fallback
  }
}

///|
test "wgpu web host text system conforms for mixed text carets and clamping" {
  let port = test_port(created=Ref(0), on_measure=web_adapter_test_measure)
  let renderer = @moui_web_renderer.create_renderer(
    canvas_id="moui-web-wasm",
    logical_size=@core.Size::new(width=100.0, height=50.0),
    port~,
  )
  let text = "a你🙂 אבג"
  let font = @core.FontSpec::new(size=16.0, weight=400)
  let result = renderer
    .text_system()
    .measure_text(@core.TextLayoutInput::new(text~, font~))
  inspect(result.size.width > 0.0, content="true")
  inspect(
    result.caret_positions.length(),
    content="\{text.to_array().length() + 1}",
  )
  inspect(
    web_adapter_carets_are_monotonic(result.caret_positions),
    content="true",
  )
  let clamped = renderer
    .text_system()
    .measure_text(@core.TextLayoutInput::new(text~, font~, max_width=24.0))
  inspect(clamped.size.width <= 24.0, content="true")
  inspect(
    web_adapter_carets_are_monotonic(clamped.caret_positions),
    content="true",
  )
  for caret in clamped.caret_positions {
    inspect(caret <= 24.0, content="true")
  }
  let fallback_text = "host-zero-fallback"
  let fallback = renderer
    .text_system()
    .measure_text(@core.TextLayoutInput::new(text=fallback_text, font~))
  inspect(fallback.size.width > 0.0, content="true")
  inspect(
    fallback.caret_positions.length(),
    content="\{fallback_text.to_array().length() + 1}",
  )
}

///|
test "wgpu web command bridge covers image command in host ABI" {
  let calls = @moui_web_renderer.draw_commands_to_host_calls(
    [
      DrawImage({
        source: "logo.png",
        frame: @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
        opacity: 1.0,
        fit: Contain,
      }),
    ],
    @core.Size::new(width=100.0, height=50.0),
  )
  inspect(calls.length(), content="3")
  assert_true(calls[0] is BeginFrame(_))
  assert_true(calls[1] is DrawImage(_))
  assert_true(calls[2] is Present)
}

///|
test "wgpu web command bridge forwards DrawPath to host ABI" {
  let path = @core.PathSpec::new(
    verbs=[
      MoveTo(@core.Point::new(x=0.0, y=0.0)),
      LineTo(@core.Point::new(x=10.0, y=0.0)),
      LineTo(@core.Point::new(x=0.0, y=10.0)),
      Close,
    ],
    fill=Some(@core.Brush::solid(@core.Color::blue())),
  )
  let calls = @moui_web_renderer.draw_commands_to_host_calls(
    [DrawPath(path)],
    @core.Size::new(width=100.0, height=50.0),
  )
  inspect(calls.length(), content="3")
  assert_true(calls[0] is BeginFrame(_))
  guard calls[1] is DrawPath(forwarded) else {
    fail("expected DrawPath host call")
  }
  inspect(
    @render_common.tessellate_path(forwarded).vertices().length(),
    content="3",
  )
  assert_true(calls[2] is Present)
}

///|
test "wgpu web command bridge preserves radial DrawPath shader payload" {
  let path = @core.PathSpec::new(
    verbs=[
      MoveTo(@core.Point::new(x=0.0, y=0.0)),
      LineTo(@core.Point::new(x=10.0, y=0.0)),
      LineTo(@core.Point::new(x=0.0, y=10.0)),
      Close,
    ],
    fill=Some(
      @core.Brush::radial_gradient(
        center=@core.Point::new(x=4.0, y=4.0),
        radius=8.0,
        center_color=@core.Color::blue(),
        edge_color=@core.Color::gray(),
      ),
    ),
  )
  let calls = @moui_web_renderer.draw_commands_to_host_calls(
    [DrawPath(path)],
    @core.Size::new(width=100.0, height=50.0),
  )
  guard calls[1] is DrawPath(forwarded) else {
    fail("expected DrawPath host call")
  }
  guard forwarded.fill is Some(RadialGradient(gradient)) else {
    fail("expected radial path brush to stay visible to the host bridge")
  }
  assert_true(gradient.center_color == @core.Color::blue())
  let mesh = @render_common.tessellate_path(forwarded)
  inspect(mesh.vertices().length(), content="3")
  for vertex in mesh.vertices() {
    let components = vertex.components()
    assert_true(components[2] == 1.0)
    assert_true(components[3] == 4.0)
    assert_true(components[4] == 4.0)
    assert_true(components[5] == 8.0)
    assert_true(components[7] == @core.Color::blue().r)
    assert_true(components[8] == @core.Color::blue().g)
    assert_true(components[9] == @core.Color::blue().b)
    assert_true(components[11] == @core.Color::gray().r)
    assert_true(components[12] == @core.Color::gray().g)
    assert_true(components[13] == @core.Color::gray().b)
  }
}

///|
test "wgpu web renderer submits DrawPath without fallback diagnostics" {
  let last_calls : Array[@moui_web_renderer.WebGpuHostCall] = []
  let renderer = @moui_web_renderer.create_renderer(
    canvas_id="moui-web-wasm",
    logical_size=@core.Size::new(width=100.0, height=50.0),
    port=test_port(created=Ref(0), on_submit=calls => {
      last_calls.clear()
      for call in calls {
        last_calls.push(call)
      }
    }),
  )
  renderer.render([
    DrawPath(
      @core.PathSpec::new(
        verbs=[
          MoveTo(@core.Point::new(x=0.0, y=0.0)),
          LineTo(@core.Point::new(x=10.0, y=0.0)),
          LineTo(@core.Point::new(x=0.0, y=10.0)),
          Close,
        ],
        fill=Some(@core.Brush::solid(@core.Color::blue())),
      ),
    ),
  ])
  inspect(renderer.last_fallback_plan().fallback_count(), content="0")
  inspect(last_calls.length(), content="3")
  assert_true(last_calls[1] is DrawPath(_))
}

///|
test "wgpu web renderer exposes submitted image lifecycle diagnostics" {
  let renderer = @moui_web_renderer.create_renderer(
    canvas_id="moui-web-wasm",
    logical_size=@core.Size::new(width=100.0, height=50.0),
    port=test_port(created=Ref(0)),
  )
  renderer.render([
    DrawImage({
      source: "logo.png",
      frame: @core.Rect::new(x=0.0, y=0.0, width=20.0, height=20.0),
      opacity: 0.75,
      fit: Contain,
    }),
  ])
  let resources = renderer.image_resources()
  inspect(resources.length(), content="1")
  inspect(resources[0].source, content="logo.png")
  assert_true(resources[0].status == ImageLoading)
}

///|
test "wgpu web renderer refreshes ready image lifecycle from host" {
  let renderer = @moui_web_renderer.create_renderer(
    canvas_id="moui-web-wasm",
    logical_size=@core.Size::new(width=100.0, height=50.0),
    port=test_port(created=Ref(0), on_image_resource=source => {
      Some(@render.ImageResourceRecord::ready(source, width=64, height=32))
    }),
  )
  renderer.render([
    DrawImage({
      source: "ready.png",
      frame: @core.Rect::new(x=0.0, y=0.0, width=20.0, height=20.0),
      opacity: 1.0,
      fit: Contain,
    }),
  ])
  let resources = renderer.image_resources()
  inspect(resources.length(), content="1")
  inspect(resources[0].source, content="ready.png")
  assert_true(resources[0].status == ImageReady)
  inspect(resources[0].width, content="64")
  inspect(resources[0].height, content="32")
  inspect(renderer.image_resources().length(), content="1")
}

///|
test "wgpu web renderer refreshes failed image lifecycle from host" {
  let renderer = @moui_web_renderer.create_renderer(
    canvas_id="moui-web-wasm",
    logical_size=@core.Size::new(width=100.0, height=50.0),
    port=test_port(created=Ref(0), on_image_resource=source => {
      Some(
        @render.ImageResourceRecord::failed(
          source,
          diagnostic="browser image load failed",
        ),
      )
    }),
  )
  renderer.render([
    DrawImage({
      source: "missing.png",
      frame: @core.Rect::new(x=0.0, y=0.0, width=20.0, height=20.0),
      opacity: 1.0,
      fit: Contain,
    }),
  ])
  let resources = renderer.image_resources()
  inspect(resources.length(), content="1")
  inspect(resources[0].source, content="missing.png")
  assert_true(resources[0].status == ImageFailed)
  inspect(resources[0].diagnostic, content="browser image load failed")
}

///|
test "wgpu web renderer applies image load completions" {
  let renderer = @moui_web_renderer.create_renderer(
    canvas_id="moui-web-wasm",
    logical_size=@core.Size::new(width=100.0, height=50.0),
    port=test_port(created=Ref(0)),
  )
  renderer.render([
    DrawImage({
      source: "async.png",
      frame: @core.Rect::new(x=0.0, y=0.0, width=20.0, height=20.0),
      opacity: 1.0,
      fit: Contain,
    }),
  ])
  let ready = renderer.apply_image_resource_load_completion(
    @render.ImageResourceLoadCompletion::ready("async.png", width=90, height=45),
  )
  assert_true(ready)
  let resources = renderer.image_resources()
  inspect(resources.length(), content="1")
  assert_true(resources[0].status == ImageReady)
  inspect(resources[0].width, content="90")
  inspect(resources[0].height, content="45")
  let stale = renderer.apply_image_resource_load_completion(
    @render.ImageResourceLoadCompletion::failed(
      "async.png",
      diagnostic="late failure",
    ),
  )
  assert_true(!stale)
  assert_true(renderer.image_resources()[0].status == ImageReady)
}

///|
test "wgpu web command bridge preserves full draw command parity order" {
  let rect = @core.Rect::new(x=1.0, y=2.0, width=30.0, height=40.0)
  let rounded = @core.RoundedRect::new(rect~, radius=6.0)
  let calls = @moui_web_renderer.draw_commands_to_host_calls(
    [
      Clear(@core.Color::white()),
      FillRect(rect, @core.Color::blue()),
      StrokeRect(rect, @core.Color::gray(), 1.0),
      FillRoundedRect(rounded, @core.Color::gray()),
      StrokeRoundedRect(rounded, @core.Color::blue(), 2.0),
      FillRoundedRectBrush(
        rounded,
        @core.Brush::linear_gradient(
          start=@core.Point::new(x=0.0, y=0.0),
          end=@core.Point::new(x=1.0, y=1.0),
          start_color=@core.Color::blue(),
          end_color=@core.Color::gray(),
        ),
      ),
      StrokeRoundedRectBrush(
        rounded,
        @core.Brush::solid(@core.Color::gray()),
        1.0,
      ),
      DrawShadow(
        @core.ShadowSpec::new(
          rect=rounded,
          color=@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.4),
        ),
      ),
      DrawText({
        text: "Hello",
        frame: rect,
        font: @core.FontSpec::new(size=14.0),
        color: @core.Color::black(),
        align: TextStart,
      }),
      DrawImage({
        source: "logo.png",
        frame: rect,
        opacity: 0.75,
        fit: Contain,
      }),
      PushClip(rect),
      PushRoundedClip(rounded),
      PushTransform(@core.Transform2D::identity()),
      PushOpacity(0.5),
      PopOpacity,
      PopTransform,
      PopRoundedClip,
      PopClip,
    ],
    @core.Size::new(width=100.0, height=50.0),
  )
  inspect(calls.length(), content="20")
  assert_true(calls[0] is BeginFrame(_))
  assert_true(calls[1] is Clear(_))
  assert_true(calls[2] is FillRect(_, _))
  assert_true(calls[3] is StrokeRect(_, _, _))
  assert_true(calls[4] is FillRoundedRect(_, _))
  assert_true(calls[5] is StrokeRoundedRect(_, _, _))
  assert_true(calls[6] is FillRoundedRectBrush(_, _))
  assert_true(calls[7] is StrokeRoundedRectBrush(_, _, _))
  assert_true(calls[8] is DrawShadow(_))
  guard calls[9] is DrawText({ align, .. }) else { fail("expected text call") }
  assert_true(align == TextStart)
  assert_true(calls[10] is DrawImage(_))
  assert_true(calls[11] is PushClip(_))
  assert_true(calls[12] is PushRoundedClip(_))
  assert_true(calls[13] is PushTransform(_))
  assert_true(calls[14] is PushOpacity(_))
  assert_true(calls[15] is PopOpacity)
  assert_true(calls[16] is PopTransform)
  assert_true(calls[17] is PopRoundedClip)
  assert_true(calls[18] is PopClip)
  assert_true(calls[19] is Present)
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
  let radial = @core.Brush::radial_gradient(
    center=@core.Point::new(x=42.0, y=38.0),
    radius=28.0,
    center_color=@core.Color::blue(),
    edge_color=@core.Color::gray(),
  )
  let shadow = @core.ShadowSpec::new(
    rect=rounded,
    color=@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.4),
    blur_radius=12.0,
    spread=2.0,
  )
  let calls = @moui_web_renderer.draw_commands_to_host_calls(
    [
      FillRoundedRectBrush(rounded, gradient),
      StrokeRoundedRectBrush(rounded, gradient, 2.0),
      FillRoundedRectBrush(rounded, radial),
      StrokeRoundedRectBrush(rounded, radial, 3.0),
      DrawShadow(shadow),
    ],
    @core.Size::new(width=120.0, height=80.0),
  )
  inspect(calls.length(), content="7")
  assert_true(calls[1] is FillRoundedRectBrush(_, LinearGradient(_)))
  assert_true(calls[2] is StrokeRoundedRectBrush(_, LinearGradient(_), _))
  assert_true(calls[3] is FillRoundedRectBrush(_, RadialGradient(_)))
  assert_true(calls[4] is StrokeRoundedRectBrush(_, RadialGradient(_), 3.0))
  assert_true(calls[5] is DrawShadow({ blur_radius: 12.0, spread: 2.0, .. }))
}

///|
test "wgpu web renderer forwards advanced layer filter and shader commands" {
  let last_calls : Array[@moui_web_renderer.WebGpuHostCall] = []
  let renderer = @moui_web_renderer.create_renderer(
    canvas_id="moui-web-wasm",
    logical_size=@core.Size::new(width=100.0, height=50.0),
    port=test_port(created=Ref(0), on_submit=calls => {
      last_calls.clear()
      for call in calls {
        last_calls.push(call)
      }
    }),
  )
  renderer.render([
    PushLayer(
      @core.LayerSpec::new(
        opacity=0.5,
        blend_mode=Screen,
        mask=RoundedMask(
          @core.RoundedRect::new(
            rect=@core.Rect::new(x=1.0, y=2.0, width=30.0, height=20.0),
            radius=4.0,
          ),
        ),
        offscreen=true,
      ),
    ),
    PushFilter(
      ColorMatrix([
        1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0,
        1.0, 0.0, 0.0, 0.0, 0.0,
      ]),
    ),
    DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="checker",
        frame=@core.Rect::new(x=0.0, y=0.0, width=20.0, height=20.0),
      ),
    ),
    PopFilter,
    PopLayer,
  ])
  let plan = renderer.last_fallback_plan()
  inspect(plan.fallback_count(), content="0")
  inspect(last_calls.length(), content="7")
  assert_true(last_calls[0] is BeginFrame(_))
  assert_true(last_calls[1] is PushLayer(_))
  assert_true(last_calls[2] is PushFilter(_))
  assert_true(last_calls[3] is DrawShaderEffect(_))
  assert_true(last_calls[4] is PopFilter)
  assert_true(last_calls[5] is PopLayer)
  assert_true(last_calls[6] is Present)
}

///|
test "wgpu web renderer keeps transform scope around layer commands" {
  let last_calls : Array[@moui_web_renderer.WebGpuHostCall] = []
  let renderer = @moui_web_renderer.create_renderer(
    canvas_id="moui-web-wasm",
    logical_size=@core.Size::new(width=100.0, height=50.0),
    port=test_port(created=Ref(0), on_submit=calls => {
      last_calls.clear()
      for call in calls {
        last_calls.push(call)
      }
    }),
  )
  renderer.render([
    PushTransform(@core.Transform2D::translation(dx=10.0, dy=20.0)),
    PushLayer(@core.LayerSpec::new(opacity=0.75, offscreen=true)),
    FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
      @core.Color::blue(),
    ),
    PopLayer,
    PopTransform,
  ])
  inspect(last_calls.length(), content="7")
  assert_true(last_calls[0] is BeginFrame(_))
  assert_true(last_calls[1] is PushTransform(_))
  assert_true(last_calls[2] is PushLayer(_))
  assert_true(last_calls[3] is FillRect(_, _))
  assert_true(last_calls[4] is PopLayer)
  assert_true(last_calls[5] is PopTransform)
  assert_true(last_calls[6] is Present)
}

///|
test "wgpu web renderer keeps transform scope around filter commands" {
  let last_calls : Array[@moui_web_renderer.WebGpuHostCall] = []
  let renderer = @moui_web_renderer.create_renderer(
    canvas_id="moui-web-wasm",
    logical_size=@core.Size::new(width=100.0, height=50.0),
    port=test_port(created=Ref(0), on_submit=calls => {
      last_calls.clear()
      for call in calls {
        last_calls.push(call)
      }
    }),
  )
  renderer.render([
    PushTransform(@core.Transform2D::translation(dx=10.0, dy=20.0)),
    PushFilter(Blur(2.0)),
    FillRect(
      @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
      @core.Color::blue(),
    ),
    PopFilter,
    PopTransform,
  ])
  inspect(last_calls.length(), content="7")
  assert_true(last_calls[0] is BeginFrame(_))
  guard last_calls[1] is PushTransform(transform) else {
    fail("expected push transform")
  }
  inspect(transform.tx, content="10")
  inspect(transform.ty, content="20")
  assert_true(last_calls[2] is PushFilter(_))
  assert_true(last_calls[3] is FillRect(_, _))
  assert_true(last_calls[4] is PopFilter)
  assert_true(last_calls[5] is PopTransform)
  assert_true(last_calls[6] is Present)
}

///|
test "wgpu web renderer keeps transform scope around shader effects" {
  let last_calls : Array[@moui_web_renderer.WebGpuHostCall] = []
  let renderer = @moui_web_renderer.create_renderer(
    canvas_id="moui-web-wasm",
    logical_size=@core.Size::new(width=100.0, height=50.0),
    port=test_port(created=Ref(0), on_submit=calls => {
      last_calls.clear()
      for call in calls {
        last_calls.push(call)
      }
    }),
  )
  renderer.render([
    PushTransform(@core.Transform2D::translation(dx=10.0, dy=20.0)),
    DrawShaderEffect(
      @core.ShaderEffectSpec::new(
        name="checker",
        frame=@core.Rect::new(x=0.0, y=0.0, width=20.0, height=20.0),
      ),
    ),
    PopTransform,
  ])
  inspect(last_calls.length(), content="5")
  assert_true(last_calls[0] is BeginFrame(_))
  guard last_calls[1] is PushTransform(transform) else {
    fail("expected push transform")
  }
  inspect(transform.tx, content="10")
  inspect(transform.ty, content="20")
  assert_true(last_calls[2] is DrawShaderEffect(_))
  assert_true(last_calls[3] is PopTransform)
  assert_true(last_calls[4] is Present)
}

///|
/// Cached rich-text block layers keep stable keys while their paint frames move
/// on scroll. The WebGPU command cache must re-place stored geometry at the
/// retained declaration frame origin; replaying absolute capture coordinates
/// leaves text outside the editor clip or stacked with a later paint.
test "wgpu web retained layer hit repositions geometry for scroll moves" {
  let last_calls : Array[@moui_web_renderer.WebGpuHostCall] = []
  let renderer = @moui_web_renderer.create_renderer(
    canvas_id="moui-web-wasm",
    logical_size=@core.Size::new(width=320.0, height=200.0),
    port=test_port(created=Ref(0), on_submit=calls => {
      last_calls.clear()
      for call in calls {
        last_calls.push(call)
      }
    }),
  )
  let capture_frame = @core.Rect::new(x=8.0, y=120.0, width=200.0, height=20.0)
  let replay_frame = @core.Rect::new(x=8.0, y=20.0, width=200.0, height=20.0)
  let capture_spec = @core.RetainedLayerSpec::new(
    key="rich-text-block;line=3",
    frame=capture_frame,
    content_revision=1,
  )
  let replay_spec = @core.RetainedLayerSpec::new(
    key="rich-text-block;line=3",
    frame=replay_frame,
    content_revision=1,
  )
  // Warm the command cache at the capture origin. Layer expansion only runs on
  // the DrawFrame path used by the web host / Playground.
  ignore(
    renderer.render_frame(
      @core.DrawFrame::new(
        commands=[
          BeginRetainedLayer(capture_spec),
          DrawText(
            @core.TextRun::new(
              text="line three",
              frame=capture_frame,
              font=@core.FontSpec::new(size=13.0),
              color=@core.Color::black(),
            ),
          ),
          EndRetainedLayer(capture_spec.key),
        ],
        damage=@core.DamageRegion::full("capture"),
        clear_color=@core.Color::white(),
      ),
    ),
  )
  // The second frame remains self-contained. The renderer may skip its full
  // payload after matching the retained declaration against its local cache.
  let replay = renderer.render_frame(
    @core.DrawFrame::new(
      commands=[
        BeginRetainedLayer(replay_spec),
        DrawText(
          @core.TextRun::new(
            text="line three",
            frame=replay_frame,
            font=@core.FontSpec::new(size=13.0),
            color=@core.Color::black(),
          ),
        ),
        EndRetainedLayer(replay_spec.key),
      ],
      damage=@core.DamageRegion::full("replay"),
      clear_color=@core.Color::white(),
    ),
  )
  inspect(replay.cache_hit_count, content="1")
  let mut text_y : Double? = None
  for call in last_calls {
    match call {
      DrawText(run) => text_y = Some(run.frame.origin.y)
      _ => ()
    }
  }
  guard text_y is Some(y) else {
    fail("expected DrawText from cached layer replay")
  }
  inspect(y, content="20")
}

///|
fn test_port(
  created~ : Ref[Int],
  capabilities? : @moui_web_renderer.WebGpuHostCapabilities = @moui_web_renderer.required_capabilities(),
  on_resize? : () -> Unit = () => (),
  on_measure? : (@core.TextLayoutInput) -> @core.TextLayoutResult = input => {
    @core.TextSystem::fallback().measure_text(input)
  },
  on_register? : (@core.FontFamily, Bytes) -> Unit = (_family, _data) => (),
  on_image_resource? : (String) -> @render.ImageResourceRecord? = _ => None,
  on_submit? : (Array[@moui_web_renderer.WebGpuHostCall]) -> Unit = _ => (),
  on_dispose? : () -> Unit = () => (),
) -> @moui_web_renderer.WebGpuHostRendererPort {
  @moui_web_renderer.WebGpuHostRendererPort::new(
    capabilities=() => capabilities,
    create_surface=(canvas_id, metrics) => {
      created.val = created.val + 1
      @moui_web_renderer.WebGpuHostSurface::new(canvas_id~, metrics~)
    },
    create_renderer=_surface => (),
    resize=_metrics => on_resize(),
    measure_text=on_measure,
    register_font_data=on_register,
    image_resource=on_image_resource,
    submit=calls => on_submit(calls),
    dispose=on_dispose,
  )
}
