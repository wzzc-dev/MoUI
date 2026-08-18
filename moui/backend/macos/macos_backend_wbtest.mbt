///|
test "macos startup surface size preserves runtime logical dimensions" {
  let size = @window_input.core_size_to_window_surface_size(
    @core.Size::new(width=800.0, height=600.0),
  )
  assert_eq(size.to_logical(2.0), @dpi.LogicalSize::LogicalSize(800.0, 600.0))
  assert_eq(size.to_physical(2.0), @dpi.PhysicalSize::PhysicalSize(1600, 1200))
}

///|
test "macos menu command payload records utf8 byte lengths" {
  let encoded = @utf8.decode_lossy(
    @host_services_desktop.encode_menu_commands([
      @core.ActionCommand::new(intent=@core.CommandIntent::Copy, label="Copy"),
      @core.ActionCommand::new(
        intent=@core.CommandIntent::Paste,
        label="粘贴",
        enabled=false,
      ),
    ])[:],
    ignore_bom=false,
  )
  inspect(encoded, content="1:4:Copy\n0:6:粘贴")
}

///|
test "macos host options carry optional scene resolver and smoke options stay separate" {
  assert_true(MacosHostAppOptions::new().show_after_first_present)
  let request = @host.WindowOpenRequest::new(
    title="Inspector",
    scene=@host.WindowScene::new(scene_id="inspector"),
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  match MacosHostAppOptions::new().scene_resolver.resolve(request) {
    @runtime.WindowSceneResolution::SceneRejected(message) =>
      inspect(message, content="window scene resolver is unavailable")
    _ => fail("expected default macOS scene resolver rejection")
  }
  let resolver = @runtime.WindowSceneResolver::new(resolve=request => {
    @runtime.WindowSceneResolution::SceneResolved(
      @runtime.WindowSceneInstance::new(
        request~,
        runtime=@runtime.AppRuntime::new_view(
          root=(@views.empty() : @core.View[Unit]),
          size=request.metrics.logical_size,
        ),
      ),
    )
  })
  let options = MacosHostAppOptions::new(
    scene_resolver=resolver,
    event_sources=Some(@runtime.HostPlatformEventSources::new()),
    show_after_first_present=false,
  )
  let smoke_options = MacosHostSmokeOptions::new(
    first_frame_smoke_auto_exit=true,
    native_ime_runtime_smoke=true,
  )
  assert_true(smoke_options.first_frame_smoke_auto_exit)
  assert_true(smoke_options.native_ime_runtime_smoke)
  assert_false(options.show_after_first_present)
  match options.event_sources {
    Some(sources) => {
      inspect(sources.host_events().active_handler_count(), content="0")
      inspect(sources.window_events().active_handler_count(), content="0")
    }
    None => fail("expected configured macOS platform event sources")
  }
  match options.scene_resolver.resolve(request) {
    @runtime.WindowSceneResolution::SceneResolved({ runtime, .. }) =>
      assert_true(runtime.size() == @core.Size::new(width=320.0, height=240.0))
    _ => fail("expected configured macOS scene resolver")
  }
}

///|
extern "C" fn macos_gpu_surface_presenter_test() -> Int = "moui_macos_gpu_surface_presenter_test"

///|
test "macOS GPU surface uses a transparent reorderable presenter sibling" {
  assert_eq(macos_gpu_surface_presenter_test(), 1)
}

///|
test "macOS platform view sync brackets native overlay transitions" {
  let regular = @core.DrawFrame::new(
    commands=[],
    damage=@core.DamageRegion::empty(),
  )
  assert_true(macos_platform_views_sync_before_render(regular))
  let overlay = @core.DrawFrame::new(
    commands=[],
    overlay_bounds=Some(
      @core.Rect::new(x=0.0, y=0.0, width=320.0, height=200.0),
    ),
    damage=@core.DamageRegion::empty(),
  )
  assert_false(macos_platform_views_sync_before_render(overlay))
}
