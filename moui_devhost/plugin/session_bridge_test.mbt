///|
/// End-to-end coverage for the platform state a plugin publishes across the
/// hot bridge: an IME composition sequence and a native accessibility action
/// enter the plugin as protocol JSON, reach the app runtime, and come back out
/// through the frame payload. The second runtime stands in for the next hot
/// generation: it starts from the transient snapshot the bridge flushes, so the
/// focused field and its in-progress preedit survive the swap.

///|
struct BridgeTestModel {
  text : String
  taps : Int32
}

///|
enum BridgeTestMsg {
  Edit(String)
  Tap
}

///|
fn bridge_test_program() -> @core.Program[BridgeTestModel, BridgeTestMsg] {
  @core.Program::simple(
    init={ text: "", taps: 0, },
    update=fn(model, message) {
      match message {
        Edit(text) => { ..model, text, }
        Tap => { ..model, taps: model.taps + 1, }
      }
    },
    view=fn(model) {
      @views.column([
        @views.text_field(
          model.text,
          on_input=value => Edit(value),
          width=200.0,
          height=40.0,
        ),
        @views.button("Tap", on_click=Tap),
        @views.text("Taps: \{model.taps}"),
      ])
    },
  )
}

///|
fn bridge_test_runtime(
  transient_transport : @core.ProgramStateTransport?,
) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(
    program=bridge_test_program(),
    width=200.0,
    height=120.0,
    transient_transport~,
  )
}

///|
fn bridge_test_event_json(event : @core.AppEvent) -> String raise {
  match @protocol.encode_event(event) {
    Some(payload) => payload
    None => fail("bridge event did not encode")
  }
}

///|
fn bridge_test_dispatch(
  session : @plugin.Session,
  event : @core.AppEvent,
) -> Unit raise {
  if !session.dispatch_json(bridge_test_event_json(event)) {
    fail("bridge rejected a valid event")
  }
}

///|
fn bridge_test_payload(
  session : @plugin.Session,
) -> @protocol.FramePayload raise {
  match @protocol.decode_frame_payload(session.frame_json()) {
    Some(payload) => payload
    None => fail("bridge frame did not decode")
  }
}

///|
fn bridge_test_text_input(
  session : @plugin.Session,
) -> @core.TextInputState raise {
  match bridge_test_payload(session).text_input() {
    Some(input) => input
    None => fail("bridge frame carried no text input state")
  }
}

///|
fn bridge_test_focus_field(session : @plugin.Session) -> Unit raise {
  ignore(bridge_test_payload(session))
  let point = @core.Point::new(x=12.0, y=20.0)
  bridge_test_dispatch(
    session,
    @core.Pointer(
      @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Down),
    ),
  )
  bridge_test_dispatch(
    session,
    @core.Pointer(
      @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Up),
    ),
  )
}

///|
fn bridge_test_composition_update(
  session : @plugin.Session,
  text : String,
  cursor : @core.TextRange,
) -> Unit raise {
  bridge_test_dispatch(
    session,
    @core.TextInput(
      @core.TextInputEvent::CompositionUpdate(
        @core.CompositionUpdate::new(text~, cursor=Some(cursor)),
      ),
    ),
  )
}

///|
fn bridge_test_semantics_node(
  payload : @protocol.FramePayload,
  role : @core.SemanticsRole,
) -> @core.SemanticsNode raise {
  let nodes = match payload.semantics() {
    Some(semantics) => semantics.nodes()
    None => fail("bridge frame carried no semantics")
  }
  for node in nodes {
    if node.role == role {
      return node
    }
  }
  fail("bridge frame had no node with the expected role")
}

///|
test "IME composition crosses the bridge and survives a generation swap" {
  let transient_slot : Ref[String?] = Ref(None)
  let transient_transport = @core.ProgramStateTransport::new(
    read=() => transient_slot.val,
    write=payload => transient_slot.val = Some(payload),
  )
  let runtime = bridge_test_runtime(Some(transient_transport))
  let session = @plugin.Session::new(runtime, None)
  assert_true(!bridge_test_text_input(session).focused)
  bridge_test_focus_field(session)
  assert_true(bridge_test_text_input(session).focused)
  bridge_test_dispatch(
    session,
    @core.TextInput(@core.TextInputEvent::CompositionStart),
  )
  bridge_test_composition_update(
    session,
    "世",
    @core.TextRange::new(start=0, end=1),
  )
  bridge_test_composition_update(
    session,
    "世界",
    @core.TextRange::new(start=0, end=2),
  )
  let preedit = bridge_test_text_input(session)
  assert_eq(preedit.text, "")
  assert_eq(preedit.composition, Some("世界"))
  // The bridge flushes this snapshot before unloading the plugin image; the
  // next generation restores it at runtime creation.
  transient_slot.val = Some(runtime.capture_dev_transient())
  let next_runtime = bridge_test_runtime(Some(transient_transport))
  let next_session = @plugin.Session::new(next_runtime, None)
  let restored = bridge_test_text_input(next_session)
  assert_true(restored.focused)
  assert_eq(restored.composition, Some("世界"))
  bridge_test_dispatch(
    next_session,
    @core.TextInput(@core.TextInputEvent::CompositionEnd("世界")),
  )
  let committed = bridge_test_text_input(next_session)
  assert_eq(committed.text, "世界")
  assert_eq(committed.caret, 2)
  assert_eq(committed.composition, None)
  let payload = bridge_test_payload(next_session)
  let field = bridge_test_semantics_node(
    payload,
    @core.SemanticsRole::TextField,
  )
  assert_eq(field.value, "世界")
}

///|
test "an accessibility action reaches the app and publishes a new frame" {
  let runtime = bridge_test_runtime(None)
  let session = @plugin.Session::new(runtime, None)
  let before = bridge_test_payload(session)
  let button = bridge_test_semantics_node(before, @core.SemanticsRole::Button)
  let request : @runtime.PerformSemanticsActionRequest = {
    target: @core.SemanticsTarget::ByNodeId(button.node_id),
    action: @core.SemanticsAction::Activate,
    precondition: @runtime.SemanticsGenerationPrecondition::Latest,
  }
  let response = match
    session.semantics_action_json(
      @protocol.encode_semantics_action_request(request),
    ) {
    Some(result) => result
    None => fail("semantics action request did not decode")
  }
  match response {
    Ok(_receipt) => ()
    Err(_) => fail("the button rejected its Activate action")
  }
  let after = bridge_test_payload(session)
  let nodes = match after.semantics() {
    Some(semantics) => semantics.nodes()
    None => fail("frame after the action carried no semantics")
  }
  let mut saw_tap_label = false
  for node in nodes {
    if node.label == "Taps: 1" {
      saw_tap_label = true
    }
  }
  assert_true(saw_tap_label)
}
