///|
test "runtime inspector and frame profile expose devtool counters" {
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::TextSpec({
      key: None,
      text: "Inspect",
      size: Size::new(width=80.0, height=20.0),
      font: FontSpec::new(size=12.0, weight=400),
      color: Color::black(),
    }),
    size=Size::new(width=100.0, height=40.0),
  )
  runtime.dispatch_event(Redraw(Initial))
  let snapshot = RuntimeInspectorSnapshot::from_runtime(runtime)
  inspect(snapshot.draw_command_count, content="2")
  inspect(snapshot.rebuild_pass_count, content="0")
  inspect(snapshot.layout_pass_count, content="1")
  inspect(snapshot.paint_pass_count, content="1")
  inspect(snapshot.draw_command_build_count, content="0")
  inspect(snapshot.dirty_count, content="0")
  inspect(snapshot.dirty_element_ids.length(), content="0")
  inspect(snapshot.dirty_state.dirty_count, content="0")
  inspect(snapshot.dirty_state.dirty_element_ids.length(), content="0")
  assert_false(snapshot.dirty_state.has_pending_work)
  inspect(snapshot.dirty_state.reason, content="clean")
  inspect(snapshot.dirty_state.reasons.length(), content="0")
  inspect(snapshot.program_dispatched_count, content="0")
  inspect(snapshot.program_update_count, content="0")
  inspect(snapshot.ignored_program_dispatch_count, content="0")
  inspect(snapshot.program_message_enqueue_count, content="0")
  inspect(snapshot.program_message_drain_count, content="0")
  inspect(snapshot.program_pending_message_count, content="0")
  inspect(snapshot.program_max_pending_message_count, content="0")
  inspect(snapshot.program_effect_plan_count, content="0")
  inspect(snapshot.program_effect_count, content="0")
  inspect(snapshot.program_effect_send_count, content="0")
  inspect(snapshot.program_effect_dispatch_count, content="0")
  inspect(snapshot.program_effect_run_count, content="0")
  inspect(snapshot.duplicate_effect_descriptor_key_count, content="0")
  inspect(snapshot.last_effect_summary.max_depth, content="0")
  inspect(snapshot.last_scheduled_effect_summary.max_depth, content="0")
  inspect(snapshot.program_subscription_plan_count, content="0")
  inspect(snapshot.last_subscription_plan_summary.max_depth, content="0")
  inspect(
    snapshot.last_subscription_plan_summary.descriptors.length(),
    content="0",
  )
  inspect(snapshot.active_subscription_count, content="0")
  inspect(snapshot.reused_subscription_count, content="0")
  inspect(snapshot.duplicate_subscription_key_count, content="0")
  inspect(snapshot.rebuild_reason, content="clean")
  inspect(snapshot.dirty_reasons.length(), content="0")
  let inspector = runtime.inspector_snapshot()
  inspect(inspector.view_tree.node_count, content="1")
  inspect(inspector.view_tree.root_kind, content="Text")
  inspect(inspector.view_tree.nodes[0].kind, content="Text")
  inspect(inspector.view_tree.dirty_paint_count, content="0")
  let layout = LayoutInspectorSnapshot::from_runtime(runtime)
  inspect(layout.node_count, content="1")
  inspect(layout.leaf_count, content="1")
  inspect(layout.max_depth, content="1")
  inspect(layout.bounds.length(), content="1")
  inspect(layout.bounds[0].depth, content="0")
  let render = RenderInspectorSnapshot::from_runtime(runtime)
  inspect(render.command_count, content="2")
  inspect(render.text_count, content="1")
  inspect(render.clip_depth, content="0")
  inspect(render.open_clip_depth, content="0")
  inspect(render.unbalanced_pop_count, content="0")
  let semantics = SemanticsInspectorSnapshot::from_runtime(runtime)
  assert_true(semantics.root_role == SemanticsRole::Text)
  inspect(semantics.node_count, content="1")
  inspect(semantics.action_count, content="0")
  inspect(semantics.selected_count, content="0")
  inspect(semantics.described_count, content="0")
  runtime.dispatch_event(FrameTick(Frame::new(time_ms=16.0, delta_ms=16.0)))
  inspect(runtime.draw_commands().length(), content="2")
}

///|
test "runtime pipeline counters track layout paint and draw command work" {
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::TextSpec({
      key: None,
      text: "Counters",
      size: Size::new(width=80.0, height=20.0),
      font: FontSpec::new(size=12.0, weight=400),
      color: Color::black(),
    }),
    size=Size::new(width=100.0, height=40.0),
  )
  inspect(runtime.rebuild_pass_count, content="0")
  inspect(runtime.layout_pass_count, content="1")
  inspect(runtime.paint_pass_count, content="1")
  inspect(runtime.draw_command_build_count, content="0")
  ignore(runtime.draw_commands())
  inspect(runtime.draw_command_build_count, content="1")
  runtime.dispatch_event(Redraw(Initial))
  runtime.dispatch_event(AppEvent::Resize(Size::new(width=140.0, height=60.0)))
  ignore(runtime.draw_commands())
  inspect(runtime.layout_pass_count, content="2")
  inspect(runtime.paint_pass_count, content="2")
  inspect(runtime.draw_command_build_count, content="2")
}

///|
test "inspector snapshot captures semantic states and dirty reasons" {
  let runtime = RuntimeState::new_spec(
    root=ViewSpec::ModifiedSpec({
      key: None,
      child: ViewSpec::TextSpec({
        key: None,
        text: "Invalid field",
        size: Size::new(width=120.0, height=28.0),
        font: FontSpec::new(size=12.0, weight=400),
        color: Color::black(),
      }),
      modifier: SemanticsInvalidModifier(true),
    }),
    size=Size::new(width=160.0, height=60.0),
  )
  runtime.mark_dirty(runtime.element_tree.id())
  let dirty_ids = runtime.dirty_element_ids()
  inspect(dirty_ids.length(), content="1")
  inspect(dirty_ids[0].value(), content="1")
  dirty_ids.clear()
  inspect(runtime.dirty_count(), content="1")
  let snapshot = runtime.inspector_snapshot()
  inspect(snapshot.runtime.rebuild_reason, content="paint requested")
  assert_true(snapshot.runtime.dirty_reasons.any(reason => reason == "paint"))
  inspect(snapshot.runtime.dirty_count, content="1")
  inspect(snapshot.runtime.dirty_element_ids.length(), content="1")
  inspect(snapshot.runtime.dirty_element_ids[0].value(), content="1")
  inspect(snapshot.runtime.dirty_state.reason, content="paint requested")
  assert_true(snapshot.runtime.dirty_state.has_pending_work)
  assert_true(
    snapshot.runtime.dirty_state.reasons.any(reason => reason == "paint"),
  )
  inspect(snapshot.runtime.dirty_state.dirty_count, content="1")
  inspect(snapshot.runtime.dirty_state.dirty_element_ids.length(), content="1")
  inspect(
    snapshot.runtime.dirty_state.dirty_element_ids[0].value(),
    content="1",
  )
  assert_true(snapshot.runtime.dirty_state.needs_paint)
  assert_true(snapshot.runtime.dirty_state.needs_redraw)
  inspect(runtime.dirty_count(), content="1")
  inspect(runtime.layout_pass_count, content="1")
  inspect(runtime.paint_pass_count, content="1")
  inspect(runtime.draw_command_build_count, content="0")
  assert_true(runtime.needs_paint())
  assert_true(runtime.needs_redraw())
  inspect(snapshot.view_tree.node_count, content="2")
  inspect(snapshot.view_tree.modified_count, content="1")
  inspect(snapshot.view_tree.dirty_paint_count, content="1")
  inspect(snapshot.layout.bounds.length(), content="2")
  inspect(snapshot.semantics.invalid_count, content="1")
}

///|
test "render inspector reports open scopes and unbalanced pops" {
  let inspected = RenderInspectorSnapshot::from_commands([
    DrawCommand::PopClip,
    DrawCommand::PushClip(Rect::new(x=0.0, y=0.0, width=20.0, height=20.0)),
    DrawCommand::PushLayer(LayerSpec::new(opacity=0.5, offscreen=true)),
    DrawCommand::PopFilter,
    DrawCommand::DrawText(
      TextRun::new(
        text="One",
        frame=Rect::new(x=0.0, y=0.0, width=60.0, height=20.0),
        font=FontSpec::new(size=12.0, weight=400),
        color=Color::black(),
        align=TextAlign::TextStart,
      ),
    ),
  ])
  inspect(inspected.clip_depth, content="1")
  inspect(inspected.open_clip_depth, content="1")
  inspect(inspected.layer_depth, content="1")
  inspect(inspected.open_layer_depth, content="1")
  inspect(inspected.filter_depth, content="0")
  inspect(inspected.open_filter_depth, content="0")
  inspect(inspected.unbalanced_pop_count, content="2")
}
