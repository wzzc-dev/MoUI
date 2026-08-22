///|
priv struct RuntimeStateProbeNode {
  kind : String
  declaration : @core.ViewDeclaration
}

///|
impl @core.ViewNode for RuntimeStateProbeNode with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind)
}

///|
impl @core.ViewNode for RuntimeStateProbeNode with fn declaration(self) {
  self.declaration
}

///|
impl @core.ViewNode for RuntimeStateProbeNode with fn layout(_self, context) {
  @core.ViewLayoutResult::new(
    size=context.constraints.constrain(@core.Size::new(width=40.0, height=20.0)),
  )
}

///|
fn runtime_state_probe_view(
  kind~ : String,
  declaration_token~ : String,
) -> @core.View[Unit] {
  @core.View::from_node(RuntimeStateProbeNode::{
    kind,
    declaration: runtime_wb_fixture_exact_declaration("RuntimeStateProbe", [
      ("value", @core.DeclarationKey::string(declaration_token)),
    ]),
  })
}

///|
fn runtime_probe_state_slot() -> @core.ViewStateSlot[Int] {
  @core.ViewStateSlot::new(
    key=@core.DeclarationKey::string("moui.runtime.test.probe"),
    initial=0,
  )
}

///|
test "RuntimeViewNode: direct mount leaves no pending build" {
  let runtime = RuntimeState::new_view(
    root=runtime_state_probe_view(kind="mounted-child", declaration_token="one"),
    size=@core.Size::new(width=40.0, height=20.0),
  )
  assert_false(runtime.element_tree.root.dirty.has_build())
  ignore(runtime.build_draw_frame())
  assert_false(runtime.element_tree.root.dirty.has_build())
}

///|
test "Inspector: records cache reuse and pointer hit paths" {
  let app = AppRuntime::new_view(
    root=runtime_state_probe_view(kind="inspector", declaration_token="one"),
    size=@core.Size::new(width=40.0, height=20.0),
  )
  let initial = app.inspector_snapshot().runtime()
  assert_true(initial.layout_cache_miss_count() > 0)
  assert_true(initial.render_cache_miss_count() > 0)
  app.state.layout_current_tree()
  app.state.render_current_tree()
  ignore(
    app.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Move,
      ),
    ),
  )
  let snapshot = app.inspector_snapshot().runtime()
  assert_true(snapshot.layout_cache_hit_count() > 0)
  assert_true(snapshot.render_cache_hit_count() > 0)
  inspect(snapshot.last_event_hit_path().length(), content="1")
}

///|
test "RuntimeViewNode: same identity preserves state and remount resets it" {
  let current = adapt_view_for_runtime(
    runtime_state_probe_view(kind="probe", declaration_token="one"),
    _message => (),
  )
  let mounted = mount_runtime_view_node_with_next(current, 1)
  mounted.node.control.apply_view_context(
    { ..mounted.node.control.view_state, hovered: true }.with_slot(
      runtime_probe_state_slot(),
      7,
    ),
  )
  let same_identity = adapt_view_for_runtime(
    runtime_state_probe_view(kind="probe", declaration_token="two"),
    _message => (),
  )
  let reconciled = reconcile_element_for_runtime(
    mounted.node,
    same_identity,
    None,
    mounted.next_id,
  )
  inspect(
    reconciled.node.control.view_state.read_slot(runtime_probe_state_slot()),
    content="7",
  )
  inspect(reconciled.node.control.view_state.hovered, content="true")
  let remounted = reconcile_element_for_runtime(
    reconciled.node,
    adapt_view_for_runtime(
      runtime_state_probe_view(kind="replacement", declaration_token="one"),
      _message => (),
    ),
    None,
    reconciled.next_id,
  )
  inspect(
    remounted.node.control.view_state.read_slot(runtime_probe_state_slot()),
    content="0",
  )
  inspect(remounted.node.control.view_state.hovered, content="false")
}

///|
test "RuntimeViewNode: colliding legacy kind hashes do not reuse state" {
  let current = adapt_view_for_runtime(
    runtime_state_probe_view(kind="Aa", declaration_token="one"),
    _message => (),
  )
  let mounted = mount_runtime_view_node_with_next(current, 1)
  mounted.node.control.apply_view_context(
    mounted.node.control.view_state.with_slot(runtime_probe_state_slot(), 9),
  )
  let remounted = reconcile_element_for_runtime(
    mounted.node,
    adapt_view_for_runtime(
      runtime_state_probe_view(kind="BB", declaration_token="one"),
      _message => (),
    ),
    None,
    mounted.next_id,
  )
  inspect(
    remounted.node.control.view_state.read_slot(runtime_probe_state_slot()),
    content="0",
  )
}

///|
test "RuntimeViewNode: event state and routing commit before message delivery" {
  let runtime_slot : Ref[RuntimeState?] = Ref(None)
  let observed_state = Ref(0)
  let observed_focus = Ref(false)
  let observed_capture = Ref(false)
  let observed_dirty = Ref(false)
  let view : @core.View[Unit] = @core.View::from_node(
    RuntimeStateProbeNode::{
      kind: "commit-order",
      declaration: @core.ViewDeclaration::constant(),
    },
    event=(_node, context) => {
      match context.event {
        @core.AppEvent::Pointer(event) =>
          if event.phase == @core.PointerPhase::Down {
            {
              ..@core.ViewEventResult::message(()),
              focused: true,
              captured: true,
              state: Some(
                context.state.with_slot(runtime_probe_state_slot(), 11),
              ),
              dirty: @core.ViewDirtyHint::ViewPaintDirty,
            }
          } else {
            @core.ViewEventResult::ignored()
          }
        _ => @core.ViewEventResult::ignored()
      }
    },
  )
  let runtime = RuntimeState::new_view(
    root=view,
    size=@core.Size::new(width=40.0, height=20.0),
    on_message=Some(_message => {
      match runtime_slot.val {
        Some(state) => {
          observed_state.val = state.element_tree.root.control.view_state.read_slot(
            runtime_probe_state_slot(),
          )
          observed_focus.val = state.animfocus.focused_element ==
            Some(state.element_tree.id())
          observed_capture.val = state.animfocus.active_pointer_capture ==
            Some(state.element_tree.id())
          observed_dirty.val = state.dirty.needs_paint
        }
        None => ()
      }
    }),
  )
  runtime_slot.val = Some(runtime)
  ignore(
    runtime.dispatch_pointer_event(
      @core.PointerEvent::new(
        position=@core.Point::new(x=10.0, y=10.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  inspect(observed_state.val, content="11")
  inspect(observed_focus.val, content="true")
  inspect(observed_capture.val, content="true")
  inspect(observed_dirty.val, content="true")
}
