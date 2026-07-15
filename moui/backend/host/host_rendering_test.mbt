///|
test "native accessibility bridge snapshots semantics recursively" {
  let child = @core.SemanticsNode::{
    element_id: @core.ElementId::new(2),
    role: @core.SemanticsRole::Heading,
    level: Some(2),
    url: "https://example.test/save",
    label: "Save",
    value: "",
    description: "Save current document",
    state: @core.SemanticsState::default(),
    actions: [@core.SemanticsAction::Focus, @core.SemanticsAction::Activate],
    focus_order: Some(0),
    frame: @core.Rect::new(x=8.0, y=8.0, width=80.0, height=32.0),
    children: [],
  }
  let root = @core.SemanticsNode::{
    element_id: @core.ElementId::new(1),
    role: @core.SemanticsRole::Group,
    level: None,
    url: "",
    label: "Root",
    value: "",
    description: "",
    state: @core.SemanticsState::default(),
    actions: [],
    focus_order: None,
    frame: @core.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
    children: [child],
  }
  let bridge = NativeAccessibilityBridge::new(
    kind=NativeAccessibilityBridgeKind::TestBridge,
  )
  match bridge.snapshot_semantics(root) {
    Some(snapshot) => {
      inspect(snapshot.nodes().length(), content="2")
      inspect(snapshot.tree() is Some(_), content="true")
      inspect(snapshot.focus(), content="NodeId(1)")
      let child_update = snapshot.nodes()[1]
      inspect(child_update.node().role(), content="Heading")
      assert_true(child_update.node().level() == Some(2))
      assert_true(
        child_update.node().url() == Some("https://example.test/save"),
      )
      match child_update.node().label() {
        Some(label) => inspect(label, content="Save")
        None => fail("expected child accessibility label")
      }
      match child_update.node().description() {
        Some(description) =>
          inspect(description, content="Save current document")
        None => fail("expected child accessibility description")
      }
      inspect(
        child_update.node().supports_action(@accesskit.Action::Click),
        content="true",
      )
    }
    None => fail("expected accessibility snapshot")
  }
}

///|
test "native accessibility bridge validates action roundtrip" {
  let invoked = Ref(0)
  let node = @core.SemanticsNode::{
    element_id: @core.ElementId::new(42),
    role: @core.SemanticsRole::TextField,
    level: None,
    url: "",
    label: "Name",
    value: "MoUI",
    description: "Required profile name",
    state: @core.SemanticsState::default(),
    actions: [@core.SemanticsAction::Focus, @core.SemanticsAction::SetText],
    focus_order: Some(0),
    frame: @core.Rect::new(x=0.0, y=0.0, width=200.0, height=40.0),
    children: [],
  }
  let bridge = NativeAccessibilityBridge::semantics_action_bridge(
    kind=NativeAccessibilityBridgeKind::TestBridge,
    root=node,
    dispatch=(element_id, action, value) => {
      if element_id == @core.ElementId::new(42) &&
        action == @core.SemanticsAction::SetText &&
        value == Some("Luna") {
        invoked.val = invoked.val + 1
        true
      } else {
        false
      }
    },
  )
  match
    bridge.perform_action(
      NativeAccessibilityActionRequest::new(
        element_id=@core.ElementId::new(42),
        action=@core.SemanticsAction::SetText,
        value=Some("Luna"),
      ),
    ) {
    NativeAccessibilityActionResult::Handled => ()
    _ => fail("expected handled action")
  }
  inspect(invoked.val, content="1")
  match
    bridge.perform_action(
      NativeAccessibilityActionRequest::new(
        element_id=@core.ElementId::new(42),
        action=@core.SemanticsAction::Submit,
      ),
    ) {
    NativeAccessibilityActionResult::Unsupported(message) =>
      inspect(message, content="semantics node does not expose action: submit")
    _ => fail("expected unsupported action")
  }
  match
    bridge.perform_action(
      NativeAccessibilityActionRequest::new(
        element_id=@core.ElementId::new(7),
        action=@core.SemanticsAction::Focus,
      ),
    ) {
    NativeAccessibilityActionResult::ElementNotFound(id) =>
      assert_true(id == @core.ElementId::new(7))
    _ => fail("expected missing element result")
  }
}

///|
test "native renderer auto mode requires availability and promotion" {
  let pending = @render.select_native_renderer(
    @render.NativeGpuPlatform::Macos,
    @render.NativeRendererMode::Auto,
    gpu_available=true,
    gpu_promoted=false,
  )
  assert_true(pending.selected == @render.RendererBackendKind::SkiaRasterNative)
  assert_true(pending.fallback_reason is Some(_))
  assert_true(
    pending.surface_route == @render.SkiaSurfaceRoute::RasterSurfaceRoute,
  )
  let promoted = @render.select_native_renderer(
    @render.NativeGpuPlatform::Macos,
    @render.NativeRendererMode::Auto,
    gpu_available=true,
    gpu_promoted=true,
  )
  assert_true(promoted.selected == @render.RendererBackendKind::SkiaGpuNative)
  assert_true(
    promoted.surface_route == @render.SkiaSurfaceRoute::MetalGpuSurfaceRoute,
  )
  let unavailable = @render.select_native_renderer(
    @render.NativeGpuPlatform::Android,
    @render.NativeRendererMode::SkiaGpu,
    gpu_available=false,
    gpu_promoted=false,
  )
  assert_true(
    unavailable.selected == @render.RendererBackendKind::SkiaRasterNative,
  )
  assert_true(
    unavailable.surface_route == @render.SkiaSurfaceRoute::RasterSurfaceRoute,
  )
}

///|
test "native renderer surface route reflects platform selection" {
  let android = @render.select_native_renderer(
    @render.NativeGpuPlatform::Android,
    @render.NativeRendererMode::SkiaGpu,
    gpu_available=true,
    gpu_promoted=false,
  )
  assert_true(
    android.surface_route == @render.SkiaSurfaceRoute::VulkanGpuSurfaceRoute,
  )
  let harmonyos = @render.select_native_renderer(
    @render.NativeGpuPlatform::HarmonyOs,
    @render.NativeRendererMode::SkiaGpu,
    gpu_available=true,
    gpu_promoted=false,
  )
  assert_true(
    harmonyos.surface_route == @render.SkiaSurfaceRoute::EglGpuSurfaceRoute,
  )
  let windows = @render.select_native_renderer(
    @render.NativeGpuPlatform::Windows,
    @render.NativeRendererMode::SkiaGpu,
    gpu_available=true,
    gpu_promoted=false,
  )
  assert_true(
    windows.surface_route == @render.SkiaSurfaceRoute::Direct3DGpuSurfaceRoute,
  )
}

///|
test "present completion helpers distinguish terminal outcomes" {
  let completion = status => {
    @render.RenderPresentCompletion::new(
      frame_sequence=1,
      surface_generation=1,
      image_resource_revision=0L,
      submitted_at_ms=1.0,
      completed_at_ms=2.0,
      presented_at_ms=if status is @render.RenderPresentStatus::Presented {
        2.0
      } else {
        0.0
      },
      status~,
      gpu_context_generation=1,
    )
  }
  let recorded = [completion(@render.RenderPresentStatus::Recorded)]
  assert_false(render_present_completions_have_terminal(recorded))
  assert_false(render_present_completions_have_presented(recorded))
  let dropped = [completion(@render.RenderPresentStatus::Dropped)]
  assert_true(render_present_completions_have_terminal(dropped))
  assert_false(render_present_completions_have_presented(dropped))
  let fallback = [completion(@render.RenderPresentStatus::FallbackToRaster)]
  assert_true(render_present_completions_have_terminal(fallback))
  assert_false(render_present_completions_have_presented(fallback))
  let presented = [completion(@render.RenderPresentStatus::Presented)]
  assert_true(render_present_completions_have_terminal(presented))
  assert_true(render_present_completions_have_presented(presented))
}

///|
test "host driver dispatches resize and deduplicates redraw requests" {
  let scheduled = Ref(0)
  let runtime = host_test_runtime(
    root=@views.empty(),
    size=@core.Size::new(width=10.0, height=10.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    scheduled.val = scheduled.val + 1
  })
  let metrics = HostSurfaceMetrics::from_logical(
    size=@core.Size::new(width=320.0, height=240.0),
  )
  let first = driver.dispatch(HostEvent::Resized(metrics))
  let second = driver.dispatch(HostEvent::Resized(metrics))
  assert_true(runtime.size() == @core.Size::new(width=320.0, height=240.0))
  inspect(first.redraw_requested, content="true")
  inspect(second.redraw_requested, content="true")
  inspect(scheduled.val, content="1")
  driver.begin_redraw()
  ignore(driver.dispatch(HostEvent::Resized(metrics)))
  inspect(scheduled.val, content="1")
  driver.finish_redraw()
  inspect(scheduled.val, content="2")
}

///|
test "host driver coalesces dirty redraw while previous redraw is pending" {
  let scheduled = Ref(0)
  let text = @core.State::new("")
  let runtime = host_test_runtime(
    root=host_test_text_field(text, width=240.0, height=40.0),
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    scheduled.val = scheduled.val + 1
  })
  ignore(
    driver.dispatch(
      HostEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  inspect(scheduled.val, content="1")
  let pending = driver.dispatch(
    HostEvent::TextInput(@core.TextInputEvent::InsertText("a")),
  )
  inspect(text.get(), content="a")
  inspect(pending.redraw_requested, content="true")
  inspect(scheduled.val, content="1")
  driver.begin_redraw()
  ignore(
    driver.dispatch(HostEvent::TextInput(@core.TextInputEvent::InsertText("b"))),
  )
  inspect(text.get(), content="ab")
  inspect(scheduled.val, content="1")
  driver.finish_redraw()
  inspect(scheduled.val, content="2")
}

///|
test "host renderer expands cached layer updates and replays cached hits" {
  let rendered : Array[Array[@core.DrawCommand]] = []
  let renderer = HostWindowRenderer::new(
    resize=_ => (),
    render=commands => rendered.push(commands.copy()),
    text_system=() => @core.TextSystem::fallback(),
  )
  let spec = @core.CachedLayerSpec::new(
    key="layer:1",
    frame=@core.Rect::new(x=0.0, y=0.0, width=80.0, height=24.0),
    content_revision=1,
  )
  let text = @core.DrawCommand::DrawText(
    @core.TextRun::new(
      text="cached",
      frame=@core.Rect::new(x=0.0, y=0.0, width=80.0, height=24.0),
      font=@core.FontSpec::new(size=12.0),
      color=@core.Color::black(),
    ),
  )
  let first = renderer.render_frame(
    @core.DrawFrame::new(
      commands=[
        @core.DrawCommand::BeginCachedLayer(spec),
        text,
        @core.DrawCommand::EndCachedLayer(spec.key),
      ],
      damage=@core.DamageRegion::full("test"),
    ),
  )
  inspect(first.cache_update_count, content="1")
  inspect(first.cache_hit_count, content="0")
  let second = renderer.render_frame(
    @core.DrawFrame::new(
      commands=[@core.DrawCommand::DrawCachedLayer(spec)],
      damage=@core.DamageRegion::empty(),
    ),
  )
  inspect(second.cache_hit_count, content="1")
  inspect(second.cache_miss_count, content="0")
  inspect(rendered.length(), content="2")
  assert_true(rendered[0][0] is @core.DrawCommand::Clear(_))
  assert_true(rendered[1][0] is @core.DrawCommand::Clear(_))
  assert_true(
    rendered[1].any(command => {
      command is @core.DrawCommand::DrawText({ text: "cached", .. })
    }),
  )
}

///|
test "host renderer capability records preserve optional callback behavior" {
  let platform_draws = Ref(0)
  let platform_callbacks = Ref(0)
  let context_losses = Ref(0)
  let renderer = HostWindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    image=HostRendererImageCapability::new(image_resources=() => {
      [@render.ImageResourceRecord::loading("pending.png")]
    }),
    platform_view=HostRendererPlatformViewCapability::new(
      draw_platform_view_pixels=fn(
        _pixels,
        _src_width,
        _src_height,
        _src_stride,
        _dst_x,
        _dst_y,
        _dst_width,
        _dst_height,
      ) {
        platform_draws.val = platform_draws.val + 1
      },
      set_platform_view_draw_fn=draw_fn => {
        match draw_fn {
          Some(draw) => {
            platform_callbacks.val = platform_callbacks.val + 1
            draw()
          }
          None => ()
        }
      },
    ),
    gpu_recovery=HostRendererGpuRecoveryCapability::new(
      inject_context_loss=() => context_losses.val = context_losses.val + 1,
      gpu_recovery_count=() => 3,
      gpu_fallback_active=() => true,
    ),
  )
  inspect(renderer.image_resources().length(), content="1")
  inspect(renderer.image_resource_snapshot().records.length(), content="1")
  renderer.draw_platform_view_pixels(b"", 0, 0, 0, 0.0, 0.0, 0.0, 0.0)
  renderer.set_platform_view_draw_fn(
    Some(() => platform_draws.val = platform_draws.val + 1),
  )
  renderer.inject_context_loss()
  inspect(platform_draws.val, content="2")
  inspect(platform_callbacks.val, content="1")
  inspect(context_losses.val, content="1")
  inspect(renderer.gpu_recovery_count(), content="3")
  assert_true(renderer.gpu_fallback_active())
}

///|
test "host renderer absent capabilities keep no-op defaults" {
  let platform_draws = Ref(0)
  let renderer = HostWindowRenderer::new(resize=_ => (), render=_ => (), text_system=() => {
    @core.TextSystem::fallback()
  })
  inspect(renderer.image_resources().length(), content="0")
  inspect(renderer.image_resource_snapshot().records.length(), content="0")
  renderer.draw_platform_view_pixels(b"", 0, 0, 0, 0.0, 0.0, 0.0, 0.0)
  renderer.set_platform_view_draw_fn(
    Some(() => platform_draws.val = platform_draws.val + 1),
  )
  renderer.inject_context_loss()
  inspect(renderer.gpu_recovery_count(), content="0")
  inspect(platform_draws.val, content="0")
  assert_false(renderer.gpu_fallback_active())
}

///|
test "redraw scheduler schedules follow-up requested during frame" {
  let scheduled = Ref(0)
  let runtime = host_test_runtime(
    root=@views.empty(),
    size=@core.Size::new(width=10.0, height=10.0),
  )
  let driver = HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    scheduled.val = scheduled.val + 1
  })
  driver.request_redraw()
  inspect(scheduled.val, content="1")
  driver.begin_redraw()
  driver.request_redraw()
  inspect(scheduled.val, content="1")
  driver.finish_redraw()
  inspect(scheduled.val, content="2")
  assert_true(driver.event_result().redraw_requested)
}
