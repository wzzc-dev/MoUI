///|
test "native accessibility bridge snapshots semantics recursively" {
  let child = @core.SemanticsNode::{
    element_id: @core.ElementId::new(2),
    role: @core.SemanticsRole::Button,
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
      inspect(child_update.node().role(), content="Button")
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
        @core.DrawCommand::Clear(@core.Color::white()),
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
      commands=[
        @core.DrawCommand::Clear(@core.Color::white()),
        @core.DrawCommand::DrawCachedLayer(spec),
      ],
      damage=@core.DamageRegion::empty(),
    ),
  )
  inspect(second.cache_hit_count, content="1")
  inspect(second.cache_miss_count, content="0")
  inspect(rendered.length(), content="2")
  assert_true(
    rendered[1].any(command => {
      command is @core.DrawCommand::DrawText({ text: "cached", .. })
    }),
  )
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
