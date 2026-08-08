///|
test "host window registry tracks primary focus resize and close lifecycle" {
  let registry = WindowRegistry::new()
  let first = registry.open(
    title="Main",
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=640.0, height=480.0),
    ),
  )
  let second = registry.open(
    title="Inspector",
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=480.0),
    ),
  )
  inspect(registry.open_window_count(), content="2")
  match registry.primary_window() {
    Some({ id, title, .. }) => {
      assert_true(id == first)
      inspect(title, content="Main")
    }
    None => fail("expected first window to become primary")
  }
  assert_true(registry.focus(second))
  match registry.focused_window() {
    Some({ id, phase, .. }) => {
      assert_true(id == second)
      assert_true(phase == @backend_host.WindowLifecyclePhase::WindowFocused)
    }
    None => fail("expected focused window")
  }
  assert_true(
    registry.resize(
      second,
      @core.SurfaceMetrics::from_logical(
        size=@core.Size::new(width=400.0, height=500.0),
        scale_factor=2.0,
      ),
    ),
  )
  match registry.lookup(second) {
    Some({ metrics, .. }) => {
      assert_true(
        metrics.logical_size == @core.Size::new(width=400.0, height=500.0),
      )
      assert_true(
        metrics.physical_size == @core.Size::new(width=800.0, height=1000.0),
      )
    }
    None => fail("expected resized window")
  }
  assert_true(registry.close(first))
  match registry.primary_window() {
    Some({ id, .. }) => assert_true(id == second)
    None => fail("expected primary reassigned after close")
  }
  inspect(registry.remove_closed(), content="1")
  inspect(registry.open_window_count(), content="1")
  inspect(
    registry.resize(
      first,
      @core.SurfaceMetrics::from_logical(
        size=@core.Size::new(width=1.0, height=1.0),
      ),
    ),
    content="false",
  )
  inspect(registry.close(first), content="false")
}

///|
test "host window registry applies shared lifecycle host events" {
  let registry = WindowRegistry::new()
  let window_id = registry.open(
    title="Main",
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  assert_true(
    registry.apply_host_event(
      window_id,
      @backend_host.Event::Resized(
        @core.SurfaceMetrics::from_logical(
          size=@core.Size::new(width=640.0, height=480.0),
          scale_factor=2.0,
        ),
      ),
    ),
  )
  match registry.lookup(window_id) {
    Some({ metrics, .. }) => {
      assert_true(
        metrics.logical_size == @core.Size::new(width=640.0, height=480.0),
      )
      assert_true(
        metrics.physical_size == @core.Size::new(width=1280.0, height=960.0),
      )
    }
    None => fail("expected lifecycle window")
  }
  assert_true(
    registry.apply_host_event(
      window_id,
      @backend_host.Event::Focus(
        @backend_host.HostFocusEvent::new(focused=true),
      ),
    ),
  )
  match registry.focused_window() {
    Some({ id, .. }) => assert_true(id == window_id)
    None => fail("expected focused window")
  }
  assert_true(
    registry.apply_host_event(
      window_id,
      @backend_host.Event::Focus(
        @backend_host.HostFocusEvent::new(focused=false),
      ),
    ),
  )
  match registry.lookup(window_id) {
    Some({ phase, .. }) =>
      assert_true(phase == @backend_host.WindowLifecyclePhase::WindowVisible)
    None => fail("expected blurred window")
  }
  assert_true(
    registry.apply_host_event(window_id, @backend_host.Event::CloseRequested),
  )
  match registry.lookup(window_id) {
    Some({ phase, .. }) =>
      assert_true(
        phase == @backend_host.WindowLifecyclePhase::WindowCloseRequested,
      )
    None => fail("expected close-requested window")
  }
  inspect(
    registry.apply_host_event(window_id, @backend_host.Event::RedrawRequested),
    content="false",
  )
}

///|
test "host platform window map routes platform window ids" {
  let map = PlatformWindowMap::new()
  inspect(map.is_empty(), content="true")
  let platform_main = @window_core.WindowId::from_raw(11)
  let platform_inspector = @window_core.WindowId::from_raw(12)
  let main = @backend_host.WindowId::new(1)
  let inspector = @backend_host.WindowId::new(2)
  assert_true(map.bind(platform_id=platform_main, host_id=main))
  inspect(
    map.bind(platform_id=platform_main, host_id=inspector),
    content="false",
  )
  inspect(
    map.bind(platform_id=platform_inspector, host_id=main),
    content="false",
  )
  assert_true(map.bind(platform_id=platform_inspector, host_id=inspector))
  inspect(map.count(), content="2")
  match map.lookup_host(platform_main) {
    Some(id) => assert_true(id == main)
    None => fail("expected main host id")
  }
  match map.lookup_platform(inspector) {
    Some(id) => assert_true(id == platform_inspector)
    None => fail("expected inspector platform id")
  }
  match map.remove_host(main) {
    Some(id) => assert_true(id == platform_main)
    None => fail("expected removed main platform id")
  }
  match map.lookup_host(platform_main) {
    Some(_) => fail("expected removed main host lookup")
    None => ()
  }
  match map.remove_platform(platform_inspector) {
    Some(id) => assert_true(id == inspector)
    None => fail("expected removed inspector host id")
  }
  inspect(map.is_empty(), content="true")
}

///|
test "host window scene resolver maps open requests to runtimes" {
  let resolver = @runtime.WindowSceneResolver::new(resolve=request => {
    if request.scene.scene_id == "inspector" {
      @runtime.WindowSceneResolution::SceneResolved(
        @runtime.WindowSceneInstance::new(
          request~,
          runtime=window_test_runtime(
            root=@views.empty(),
            size=request.metrics.logical_size,
          ),
        ),
      )
    } else {
      @runtime.WindowSceneResolution::SceneRejected(
        "unknown window scene: " + request.scene.scene_id,
      )
    }
  })
  let request = @backend_host.WindowOpenRequest::new(
    title="Inspector",
    scene=@backend_host.WindowScene::new(
      scene_id="inspector",
      payload="outline",
    ),
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=360.0, height=480.0),
    ),
  )
  match resolver.resolve(request) {
    @runtime.WindowSceneResolution::SceneResolved({ request, runtime }) => {
      inspect(request.title, content="Inspector")
      inspect(request.scene.payload, content="outline")
      assert_true(runtime.size() == @core.Size::new(width=360.0, height=480.0))
    }
    _ => fail("expected resolved inspector scene")
  }
  let unknown = @backend_host.WindowOpenRequest::new(
    title="Unknown",
    scene=@backend_host.WindowScene::new(scene_id="unknown"),
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  match resolver.resolve(unknown) {
    @runtime.WindowSceneResolution::SceneRejected(message) =>
      inspect(message, content="unknown window scene: unknown")
    _ => fail("expected unknown scene rejection")
  }
  match @runtime.WindowSceneResolver::unavailable().resolve(request) {
    @runtime.WindowSceneResolution::SceneRejected(message) =>
      inspect(message, content="window scene resolver is unavailable")
    _ => fail("expected unavailable resolver rejection")
  }
}

///|
test "host window registry resolves scenes before registering opened windows" {
  let registry = WindowRegistry::new()
  let resolver = @runtime.WindowSceneResolver::new(resolve=request => {
    if request.scene.scene_id == "inspector" {
      @runtime.WindowSceneResolution::SceneResolved(
        @runtime.WindowSceneInstance::new(
          request~,
          runtime=window_test_runtime(
            root=@views.empty(),
            size=request.metrics.logical_size,
          ),
        ),
      )
    } else {
      @runtime.WindowSceneResolution::SceneRejected(
        "unknown window scene: " + request.scene.scene_id,
      )
    }
  })
  let rejected = @backend_host.WindowOpenRequest::new(
    title="Unknown",
    scene=@backend_host.WindowScene::new(scene_id="unknown"),
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  match resolve_open_request(registry, rejected, resolver) {
    @runtime.WindowOpenResolution::OpenRejected(message) =>
      inspect(message, content="unknown window scene: unknown")
    _ => fail("expected rejected window scene")
  }
  inspect(registry.open_window_count(), content="0")

  let request = @backend_host.WindowOpenRequest::new(
    title="Inspector",
    scene=@backend_host.WindowScene::new(
      scene_id="inspector",
      payload="outline",
    ),
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=360.0, height=480.0),
    ),
    primary=true,
  )
  match resolve_open_request(registry, request, resolver) {
    @runtime.WindowOpenResolution::OpenResolved({ id, record, instance }) => {
      assert_true(id == record.id)
      inspect(record.title, content="Inspector")
      inspect(record.scene.scene_id, content="inspector")
      inspect(record.primary, content="true")
      assert_true(
        instance.runtime.size() == @core.Size::new(width=360.0, height=480.0),
      )
      let redraws = Ref(0)
      let slot = WindowRuntimeSlot::from_resolved_open(
        { id, record, instance },
        schedule_redraw=() => redraws.val = redraws.val + 1,
      )
      assert_true(slot.id == id)
      inspect(slot.record.scene.payload, content="outline")
      assert_true(
        slot.driver.size() == @core.Size::new(width=360.0, height=480.0),
      )
      slot.driver.request_redraw()
      inspect(redraws.val, content="1")
      let driver_backed = WindowRuntimeSlot::from_driver(
        record~,
        driver=slot.driver,
      )
      assert_true(driver_backed.id == id)
      assert_true(driver_backed.driver.size() == slot.driver.size())
    }
    _ => fail("expected resolved open window")
  }
  inspect(registry.open_window_count(), content="1")
}
