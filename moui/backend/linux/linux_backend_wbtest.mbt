///|
test "linux host options carry optional scene resolver and smoke options stay separate" {
  let request = @host.WindowOpenRequest::new(
    title="Inspector",
    scene=@host.WindowScene::new(scene_id="inspector"),
    metrics=@core.SurfaceMetrics::from_logical(
      size=@core.Size::new(width=320.0, height=240.0),
    ),
  )
  match LinuxHostAppOptions::new().scene_resolver.resolve(request) {
    @runtime.WindowSceneResolution::SceneRejected(message) =>
      inspect(message, content="window scene resolver is unavailable")
    _ => fail("expected default Linux scene resolver rejection")
  }
  assert_false(LinuxHostSmokeOptions::new().first_frame_smoke_auto_exit)
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
  let options = LinuxHostAppOptions::new(
    scene_resolver=resolver,
    event_sources=Some(@runtime.HostPlatformEventSources::new()),
  )
  let smoke_options = LinuxHostSmokeOptions::new(
    first_frame_smoke_auto_exit=true,
  )
  assert_true(smoke_options.first_frame_smoke_auto_exit)
  match options.event_sources {
    Some(sources) => {
      inspect(sources.host_events().active_handler_count(), content="0")
      inspect(sources.window_events().active_handler_count(), content="0")
    }
    None => fail("expected configured Linux platform event sources")
  }
  match options.scene_resolver.resolve(request) {
    @runtime.WindowSceneResolution::SceneResolved({ runtime, .. }) =>
      assert_true(runtime.size() == @core.Size::new(width=320.0, height=240.0))
    _ => fail("expected configured Linux scene resolver")
  }
}

///|
test "linux at-spi binding publishes semantics dispatches actions and disposes" {
  let invoked = Ref(0)
  let runtime = @runtime.AppRuntime::new_view(
    root=(@views.button("Apply", on_click=()) : @core.View[Unit]),
    size=@core.Size::new(width=120.0, height=80.0),
  )
  let snapshot = match runtime.read_semantics() {
    Ok(@runtime.SemanticsRead::Full(snapshot)) => snapshot
    _ => abort("expected full committed semantics")
  }
  let mut target : @core.SemanticsNode? = None
  for node in snapshot.nodes() {
    if node.actions.any(action => action == @core.SemanticsActionKind::Activate) {
      target = Some(node)
    }
  }
  let target = target.unwrap()
  let binding = LinuxATSPIBinding::new(dispatch=request => {
    if request.target == @core.SemanticsTarget::ByNodeId(target.node_id) &&
      request.precondition ==
      @runtime.SemanticsGenerationPrecondition::Exact(snapshot.generation()) &&
      request.action == @core.SemanticsAction::Activate {
      invoked.val = invoked.val + 1
      @accesskit_bridge.AccessKitActionResult::Handled({
        before: snapshot.generation(),
        after: snapshot.generation(),
        pending_work: false,
      })
    } else {
      @accesskit_bridge.AccessKitActionResult::Rejected(
        @runtime.SemanticsActionDispatchError::TargetNotFound(request.target),
      )
    }
  })
  let published = binding.publish_semantics(
    @runtime.SemanticsRead::Full(snapshot),
  )
  inspect(published.native_binding_ready, content="false")
  assert_true(published.published_node_count >= 1)
  inspect(published.disposed, content="false")
  match
    binding.perform_action(
      @accesskit_bridge.accesskit_semantics_action_request(
        node_id=target.node_id,
        generation=snapshot.generation(),
        action=@core.SemanticsAction::Activate,
      ),
    ) {
    @accesskit_bridge.AccessKitActionResult::Handled(_) => ()
    _ => fail("expected Linux AT-SPI action dispatch")
  }
  inspect(invoked.val, content="1")
  inspect(binding.diagnostics().action_dispatch_count, content="1")
  let disposed = binding.dispose()
  inspect(disposed.published_node_count, content="0")
  inspect(disposed.disposed, content="true")
  match
    binding.perform_action(
      @accesskit_bridge.accesskit_semantics_action_request(
        node_id=target.node_id,
        generation=snapshot.generation(),
        action=@core.SemanticsAction::Activate,
      ),
    ) {
    @accesskit_bridge.AccessKitActionResult::BridgeUnavailable(message) =>
      inspect(message, content="Linux AT-SPI binding is disposed")
    _ => fail("expected disposed Linux AT-SPI binding to reject actions")
  }
}

///|
test "linux native at-spi actions preserve identity generation and payload" {
  let numeric = linux_atspi_decode_action(
    b"{\"node_id\":\"42\",\"generation\":\"7\",\"kind\":\"set_numeric_value\",\"value\":\"37.5\"}",
  )
  guard numeric
    is Some(
      {
        target: @core.SemanticsTarget::ByNodeId(node_id),
        action: @core.SemanticsAction::SetNumericValue(value),
        precondition: @runtime.SemanticsGenerationPrecondition::Exact(
          generation
        ),
      }
    ) else {
    fail("expected decoded AT-SPI numeric action")
  }
  inspect(node_id.to_wire(), content="42")
  inspect(generation.to_wire(), content="7")
  inspect(value, content="37.5")

  let selection = linux_atspi_decode_action(
    b"{\"node_id\":\"43\",\"generation\":\"8\",\"kind\":\"set_selection\",\"value\":\"3,9\"}",
  )
  guard selection
    is Some({ action: @core.SemanticsAction::SetSelection(range), .. }) else {
    fail("expected decoded AT-SPI selection action")
  }
  inspect(range.start, content="3")
  inspect(range.end, content="9")
}

///|
test "linux native at-spi action decoder rejects stale wire shapes" {
  assert_eq(linux_atspi_decode_action(b""), None)
  assert_eq(
    linux_atspi_decode_action(
      b"{\"node_id\":\"x\",\"generation\":\"7\",\"kind\":\"activate\",\"value\":\"\"}",
    ),
    None,
  )
  assert_eq(
    linux_atspi_decode_action(
      b"{\"node_id\":\"42\",\"generation\":\"7\",\"kind\":\"set_selection\",\"value\":\"9,3,1\"}",
    ),
    None,
  )
  assert_eq(
    linux_atspi_decode_action(
      b"{\"node_id\":\"42\",\"generation\":\"7\",\"kind\":\"unknown\",\"value\":\"\"}",
    ),
    None,
  )
}
