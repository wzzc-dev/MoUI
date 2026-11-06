///|
fn custom_control_semantic_node(
  runtime : @runtime.AppRuntime,
  id : String,
) -> @core.SemanticsNode? {
  match runtime.read_semantics() {
    Ok(Full(snapshot)) => {
      let expected = @core.SemanticId::new(id)
      let mut found = None
      for node in snapshot.nodes() {
        if node.semantic_id == Some(expected) {
          found = Some(node)
        }
      }
      found
    }
    Ok(Delta(_)) | Ok(Unchanged(_)) | Err(_) => None
  }
}

///|
fn custom_control_counter_value(
  runtime : @runtime.AppRuntime,
  id : String,
) -> String raise {
  match custom_control_semantic_node(runtime, "custom.counter." + id) {
    Some(node) => node.value
    None => fail("custom counter semantics node not found: " + id)
  }
}

///|
priv enum CustomControlProbeMsg {
  ProbeEdited(String)
}

///|
fn custom_control_probe_program() -> @core.Program[
  String,
  CustomControlProbeMsg,
] {
  @core.Program::simple(
    init="5",
    update=(_model, message) => {
      match message {
        ProbeEdited(value) => value
      }
    },
    view=value => {
      @widgets.editable_counter(
        label="Counter quantity",
        value~,
        numeric_value=5.0,
        on_input=value => ProbeEdited(value),
        key="quantity",
      ).semantic_id("custom.counter.quantity")
    },
  )
}

///|
test "custom control publishes accessible text field and numeric actions" {
  let runtime = @runtime.new_program_with_dimensions(
    program=@app.program(),
    width=480.0,
    height=320.0,
  )
  ignore(runtime.layout())
  let node = match
    custom_control_semantic_node(runtime, "custom.counter.quantity") {
    Some(node) => node
    None => fail("custom counter semantics node not found")
  }
  assert_eq(node.role, @core.SemanticsRole::TextField)
  assert_eq(node.label, "Counter quantity")
  assert_eq(node.value, "5")
  assert_true(node.text is Some(_))
  assert_true(node.numeric is Some(_))
  assert_eq(node.actions.contains(SetText), true)
  assert_eq(node.actions.contains(Increment), true)
  assert_eq(node.actions.contains(Decrement), true)
  let second = match
    custom_control_semantic_node(runtime, "custom.counter.discount") {
    Some(node) => node
    None => fail("second custom counter semantics node not found")
  }
  assert_eq(second.label, "Counter discount")
  assert_eq(second.value, "10")
  runtime.destroy()
}

///|
test "custom control semantic actions stay on the typed TEA path" {
  let runtime = @runtime.new_program_with_dimensions(
    program=@app.program(),
    width=480.0,
    height=320.0,
  )
  ignore(runtime.layout())
  let target = @core.SemanticsTarget::BySemanticId(
    @core.SemanticId::new("custom.counter.quantity"),
  )
  guard runtime.perform_semantics_action({
      target,
      action: Increment,
      precondition: Latest,
    })
    is Ok(_) else {
    fail("increment action failed")
  }
  assert_eq(custom_control_counter_value(runtime, "quantity"), "6")
  assert_eq(custom_control_counter_value(runtime, "discount"), "10")
  guard runtime.perform_semantics_action({
      target,
      action: SetText("12"),
      precondition: Latest,
    })
    is Ok(_) else {
    fail("set-text action failed")
  }
  assert_eq(custom_control_counter_value(runtime, "quantity"), "12")
  assert_eq(custom_control_counter_value(runtime, "discount"), "10")
  guard runtime.perform_semantics_action({
      target,
      action: Decrement,
      precondition: Latest,
    })
    is Ok(_) else {
    fail("decrement action failed")
  }
  assert_eq(custom_control_counter_value(runtime, "quantity"), "11")
  assert_eq(custom_control_counter_value(runtime, "discount"), "10")
  runtime.destroy()
}

///|
test "custom control receives focus and ime composition" {
  let runtime = @runtime.new_program_with_dimensions(
    program=custom_control_probe_program(),
    width=220.0,
    height=40.0,
  )
  ignore(runtime.layout())
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=100.0, y=20.0),
        phase=Down,
      ),
    ),
  )
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=100.0, y=20.0),
        phase=Up,
      ),
    ),
  )
  assert_true(runtime.focused_text_input().focused)
  runtime.dispatch_event(TextInput(CompositionStart))
  runtime.dispatch_event(
    TextInput(CompositionUpdate(@core.CompositionUpdate::new(text="十"))),
  )
  let composing = runtime.focused_text_input()
  assert_eq(composing.composition, Some("十"))
  assert_true(composing.frame.size.width > 0.0)
  runtime.dispatch_event(TextInput(CompositionEnd("10")))
  assert_eq(custom_control_counter_value(runtime, "quantity"), "510")
  assert_eq(runtime.focused_text_input().composition, None)
  runtime.destroy()
}

///|
test "keyed counter updates are isolated and copy-on-write" {
  let base = @app.Model::new()
  let edited = base
    .update(@app.Counter("quantity", @app.Step(2)))
    .update(@app.Counter("discount", @app.Edited("7")))
  assert_eq(base.counter_ids(), ["quantity", "discount"])
  assert_eq(base.counters[0].value, "5")
  assert_eq(edited.counter_ids(), ["quantity", "discount"])
  assert_eq(edited.counters[0].value, "7")
  assert_eq(edited.counters[0].edits, 1)
  assert_eq(edited.counters[1].value, "7")
  assert_eq(edited.counters[1].edits, 1)

  let reordered = edited.update(@app.MoveCounter("discount", -1))
  assert_eq(reordered.counter_ids(), ["discount", "quantity"])
  assert_eq(reordered.counters[0].value, "7")
  assert_eq(reordered.counters[1].value, "7")

  let removed = reordered.update(@app.RemoveCounter("quantity"))
  assert_eq(removed.counter_ids(), ["discount"])
  let stale = removed.update(@app.Counter("quantity", @app.Step(1)))
  assert_eq(stale.counter_ids(), ["discount"])

  let added = removed.update(@app.AddCounter)
  assert_eq(added.counter_ids(), ["discount", "counter-1"])
  let added_again = added.update(@app.AddCounter)
  assert_eq(added_again.counter_ids(), ["discount", "counter-1", "counter-2"])
}

///|
test "snapshot restores keyed counters, ordering, edits, and auto state" {
  let model = @app.Model::new()
    .update(@app.Counter("quantity", @app.Step(2)))
    .update(@app.Counter("discount", @app.Edited("7")))
    .update(@app.Counter("discount", @app.ToggleAuto))
    .update(@app.MoveCounter("discount", -1))
    .update(@app.AddCounter)
  let snapshot = model.save_snapshot()
  let later = model.update(@app.Counter("counter-1", @app.Step(4)))
  assert_eq(later.counters[2].value, "4")

  let restored = @app.Model::restore_from_snapshot(snapshot)
  assert_eq(restored.counter_ids(), ["discount", "quantity", "counter-1"])
  assert_eq(restored.counters[0].value, "7")
  assert_eq(restored.counters[0].edits, 1)
  assert_true(restored.counters[0].auto)
  assert_eq(restored.counters[1].value, "7")
  assert_eq(restored.counters[1].edits, 1)
  assert_eq(restored.counters[2].value, "0")
  assert_eq(restored.counters[2].edits, 0)

  let added = restored.update(@app.AddCounter)
  assert_eq(added.counter_ids(), [
    "discount", "quantity", "counter-1", "counter-2",
  ])
}

///|
test "keyed counters isolate duplicate local subscription keys" {
  let starts : Array[(@core.Frame) -> Unit] = []
  let timer = @services.TimerSource::new(start=(_interval, dispatch) => {
    starts.push(dispatch)
    None
  })
  let model = @app.Model::new()
    .update(@app.Counter("quantity", @app.ToggleAuto))
    .update(@app.Counter("discount", @app.ToggleAuto))
  let runtime = @runtime.new_program_with_dimensions(
    program=model.program(timer_source=Some(timer)),
    width=480.0,
    height=640.0,
  )
  ignore(runtime.layout())
  assert_eq(starts.length(), 2)
  let active = runtime.program_runtime_snapshot()
  assert_eq(active.active_subscription_count(), 2)
  assert_eq(active.duplicate_subscription_key_count(), 0)
  assert_eq(active.active_subscriptions().map(descriptor => descriptor.key()), [
    "custom-control%2Fquantity/counter/auto", "custom-control%2Fdiscount/counter/auto",
  ])

  starts[0](@core.Frame::new(time_ms=1000.0, delta_ms=1000.0))
  starts[1](@core.Frame::new(time_ms=1000.0, delta_ms=1000.0))
  ignore(runtime.layout())
  assert_eq(custom_control_counter_value(runtime, "quantity"), "6")
  assert_eq(custom_control_counter_value(runtime, "discount"), "11")

  guard runtime.perform_semantics_action({
      target: @core.SemanticsTarget::BySemanticId(
        @core.SemanticId::new("custom.remove.discount"),
      ),
      action: Activate,
      precondition: Latest,
    })
    is Ok(_) else {
    fail("remove counter action failed")
  }
  ignore(runtime.layout())
  let removed = runtime.program_runtime_snapshot()
  assert_eq(removed.active_subscription_count(), 1)
  assert_eq(
    removed.active_subscriptions().map(descriptor => descriptor.key()),
    ["custom-control%2Fquantity/counter/auto"],
  )
  starts[1](@core.Frame::new(time_ms=2000.0, delta_ms=1000.0))
  let stale = runtime.program_runtime_snapshot()
  assert_eq(stale.ignored_subscription_dispatch_count(), 1)
  assert_eq(custom_control_counter_value(runtime, "quantity"), "6")
  runtime.destroy()
}
