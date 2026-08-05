///|
test "surface detach cancels pending host service exactly once" {
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=120.0, height=80.0),
  )
  let runtime = @runtime.AppRuntime::new_view(
    root=(@views.empty() : @core.View[Unit]),
    size=metrics.logical_size,
  )
  let renderer = @render.WindowRenderer::new(
    resize=_ => (),
    render=_ => (),
    text_system=() => @core.TextSystem::fallback(),
    present_count=() => 0,
  )
  let core = EmbeddedRuntimeBackendCore::new(
    runtime~,
    renderer~,
    metrics~,
    surface_generation=1,
  )
  let request = @host.PlatformChannelRequest::new(
    channel="camera.control",
    operation="start",
  )
  let id = match
    core
    .host_service_bridge()
    .dispatch(@host.HostServiceRequest::PlatformChannel(request)) {
    @host.HostServiceResponse::Pending(id) => id
    _ => fail("expected pending platform channel request")
  }
  let completion_count = Ref(0)
  let cancellation_reason = Ref("")
  let unexpected_completion = Ref(false)
  guard core.host_bridge is Some(channel) else {
    fail("expected attached host channel")
  }
  assert_true(
    channel.services.on_completed(id, completion => {
      completion_count.val = completion_count.val + 1
      match completion.response {
        @host.HostServiceResponse::Unavailable(reason) =>
          cancellation_reason.val = reason
        _ => unexpected_completion.val = true
      }
    }),
  )
  assert_true(core.detach_surface())
  inspect(completion_count.val, content="1")
  assert_false(unexpected_completion.val)
  inspect(
    cancellation_reason.val,
    content="embedded runtime surface epoch detached",
  )
  assert_false(
    channel.services.complete(
      id,
      @host.HostServiceResponse::PlatformChannel(
        @host.PlatformChannelResponse::Ok("late"),
      ),
    ),
  )
  inspect(completion_count.val, content="1")
  core.dispose()
}

///|
priv enum EmbeddedRuntimeSemanticsMsg {
  Remove
}

///|
priv struct EmbeddedRuntimeSemanticsNode {
  visible : Bool
}

///|
impl @core.ViewNode for EmbeddedRuntimeSemanticsNode with fn identity(_self) {
  @core.ViewIdentity::new(kind="EmbeddedRuntimeSemanticsFixture")
}

///|
impl @core.ViewNode for EmbeddedRuntimeSemanticsNode with fn declaration(_self) {
  @core.ViewDeclaration::uncacheable()
}

///|
impl @core.ViewNode for EmbeddedRuntimeSemanticsNode with fn layout(
  _self,
  context,
) {
  @core.ViewLayoutResult::new(
    size=context.constraints.constrain(@core.Size::new(width=80.0, height=32.0)),
  )
}

///|
impl @core.ViewNode for EmbeddedRuntimeSemanticsNode with fn semantics(self) {
  if self.visible {
    @core.ViewSemanticsInfo::new(
      composition=@core.SemanticsComposition::Boundary,
      semantic_id=@core.SemanticId::parse("embedded-runtime.remove").unwrap(),
      role=@core.SemanticsRole::Button,
      label="Remove",
    )
  } else {
    @core.ViewSemanticsInfo::new(composition=@core.SemanticsComposition::Hidden)
  }
}

///|
fn embedded_runtime_semantics_view(
  visible : Bool,
) -> @core.View[EmbeddedRuntimeSemanticsMsg] {
  @core.View::from_node(EmbeddedRuntimeSemanticsNode::{ visible, }, semantics_actions=_node => {
    if visible {
      [
        @core.ViewSemanticsActionHandler::activate(_context => {
          @core.ViewSemanticsActionResult::accepted(messages=[Remove])
        }),
      ]
    } else {
      []
    }
  })
}

///|
test "mobile accessibility rejects stale session generation and removed node without messages" {
  let runtime = @runtime.AppRuntime::new_program(
    program=@core.Program::simple(
      init=true,
      update=(_visible, _message) => false,
      view=embedded_runtime_semantics_view,
    ),
    size=@core.Size::new(width=120.0, height=80.0),
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    ()
  })
  let bridge = EmbeddedRuntimeHostBridge::new(session_generation=17)
  let (node_id, initial_generation) = match runtime.read_semantics() {
    Ok(@runtime.SemanticsRead::Full(snapshot)) => {
      assert_eq(snapshot.nodes().length(), 1)
      (snapshot.nodes()[0].node_id, snapshot.generation())
    }
    _ => fail("expected initial committed semantics")
  }
  ignore(bridge.sync(runtime))
  let initial_wire = bridge.drain_update_envelope_json()
  assert_true(initial_wire.contains("\"kind\":\"semantics\""))
  assert_true(initial_wire.contains("\"generation\":\""))
  assert_false(initial_wire.contains("element_id"))

  let remove = embedded_accessibility_response(
    node_id,
    initial_generation,
    @core.SemanticsAction::Activate,
  )
  assert_true(
    bridge.dispatch_response_envelope(
      EmbeddedHostResponseEnvelope::new(session_generation=17, response=remove),
      driver,
    ),
  )
  let after_generation = match runtime.read_semantics() {
    Ok(@runtime.SemanticsRead::Full(snapshot)) => {
      assert_eq(snapshot.nodes().length(), 0)
      snapshot.generation()
    }
    _ => fail("expected semantics after removal")
  }
  let delivered = runtime.program_runtime_snapshot().update_count()
  assert_eq(delivered, 1)

  assert_false(
    bridge.dispatch_response(
      embedded_accessibility_response(
        node_id,
        initial_generation,
        @core.SemanticsAction::Activate,
      ),
      driver,
    ),
  )
  assert_false(
    bridge.dispatch_response(
      embedded_accessibility_response(
        node_id,
        after_generation,
        @core.SemanticsAction::Activate,
      ),
      driver,
    ),
  )
  assert_false(
    bridge.dispatch_response_envelope(
      EmbeddedHostResponseEnvelope::new(
        session_generation=18,
        response=embedded_accessibility_response(
          node_id,
          after_generation,
          @core.SemanticsAction::Activate,
        ),
      ),
      driver,
    ),
  )
  assert_eq(runtime.program_runtime_snapshot().update_count(), delivered)
}
