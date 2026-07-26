///|
priv struct RuntimeStateProbeNode {
  kind : String
  revision : String
}

///|
impl @core.ViewNode for RuntimeStateProbeNode with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind)
}

///|
impl @core.ViewNode for RuntimeStateProbeNode with fn revision(self) {
  self.revision
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
  revision~ : String,
) -> @core.View[Unit] {
  @core.View::from_node(RuntimeStateProbeNode::{ kind, revision })
}

///|
test "RuntimeViewNode: same identity preserves state and remount resets it" {
  let current = adapt_view_for_runtime(
    runtime_state_probe_view(kind="probe", revision="one"),
    _message => (),
  )
  let mounted = mount_runtime_view_node_with_next(current, 1)
  mounted.node.control.apply_view_context({
    ..mounted.node.control.view_state,
    hovered: true,
    scratch: "preserved",
  })
  let same_identity = adapt_view_for_runtime(
    runtime_state_probe_view(kind="probe", revision="two"),
    _message => (),
  )
  let reconciled = reconcile_element_for_runtime(
    mounted.node,
    same_identity,
    None,
    mounted.next_id,
  )
  inspect(reconciled.node.control.view_state.scratch, content="preserved")
  inspect(reconciled.node.control.view_state.hovered, content="true")
  let remounted = reconcile_element_for_runtime(
    reconciled.node,
    adapt_view_for_runtime(
      runtime_state_probe_view(kind="replacement", revision="one"),
      _message => (),
    ),
    None,
    reconciled.next_id,
  )
  inspect(remounted.node.control.view_state.scratch, content="")
  inspect(remounted.node.control.view_state.hovered, content="false")
}

///|
test "RuntimeViewNode: colliding legacy kind hashes do not reuse state" {
  let current = adapt_view_for_runtime(
    runtime_state_probe_view(kind="Aa", revision="one"),
    _message => (),
  )
  let mounted = mount_runtime_view_node_with_next(current, 1)
  mounted.node.control.apply_view_context({
    ..mounted.node.control.view_state,
    scratch: "must-reset",
  })
  let remounted = reconcile_element_for_runtime(
    mounted.node,
    adapt_view_for_runtime(
      runtime_state_probe_view(kind="BB", revision="one"),
      _message => (),
    ),
    None,
    mounted.next_id,
  )
  inspect(remounted.node.control.view_state.scratch, content="")
}

///|
test "RuntimeViewNode: event state and routing commit before message delivery" {
  let runtime_slot : Ref[RuntimeState?] = Ref(None)
  let observed_state = Ref("")
  let observed_focus = Ref(false)
  let observed_capture = Ref(false)
  let observed_dirty = Ref(false)
  let view : @core.View[Unit] = @core.View::from_node(
    RuntimeStateProbeNode::{ kind: "commit-order", revision: "one" },
    event=(_node, context) => {
      match context.event {
        @core.AppEvent::Pointer(event) =>
          if event.phase == @core.PointerPhase::Down {
            {
              ..@core.ViewEventResult::message(()),
              focused: true,
              captured: true,
              state: Some({ ..context.state, scratch: "committed" }),
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
          observed_state.val = state.element_tree.root.control.view_state.scratch
          observed_focus.val = state.focused_element ==
            Some(state.element_tree.id())
          observed_capture.val = state.active_pointer_capture ==
            Some(state.element_tree.id())
          observed_dirty.val = state.needs_paint
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
  inspect(observed_state.val, content="committed")
  inspect(observed_focus.val, content="true")
  inspect(observed_capture.val, content="true")
  inspect(observed_dirty.val, content="true")
}
