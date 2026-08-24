///|
struct DownstreamViewNode {
  kind : String
  message : String
  size : @core.Size
}

///|
impl @core.ViewNode for DownstreamViewNode with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind)
}

///|
impl @core.ViewNode for DownstreamViewNode with fn layout(self, context) {
  @core.ViewLayoutResult::new(size=context.constraints.constrain(self.size))
}

///|
fn downstream_event_context() -> @core.ViewEventContext {
  {
    frame: @core.Rect::new(x=0.0, y=0.0, width=40.0, height=20.0),
    child_frames: [],
    event: @core.AppEvent::CloseRequested,
    focused: false,
    state: {
      focused: false,
      hovered: false,
      pressed: false,
      selected: false,
      checked: false,
      expanded: false,
      disabled: false,
      slots: @core.ViewStateSlots::empty(),
    },
    text_control: {
      caret: 0,
      selection: None,
      text_selection_anchor: None,
      composition: None,
      composition_cursor: None,
      undo_stack: [],
      redo_stack: [],
    },
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
    now_ms: 0.0,
  }
}

///|
fn downstream_layout_context() -> @core.ViewLayoutContext {
  {
    constraints: @core.Constraints::tight(
      @core.Size::new(width=80.0, height=30.0),
    ),
    child_sizes: [],
    child_flex_weights: [],
    anchor_frames: [],
    state: {
      focused: false,
      hovered: false,
      pressed: false,
      selected: false,
      checked: false,
      expanded: false,
      disabled: false,
      slots: @core.ViewStateSlots::empty(),
    },
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
  }
}

///|
test "ViewNode: downstream implementation uses trait defaults" {
  let view : @core.View[String] = @core.View::from_node(DownstreamViewNode::{
    kind: "downstream",
    message: "activate",
    size: @core.Size::new(width=12.0, height=8.0),
  })
  inspect(view.identity().kind, content="downstream")
  inspect(
    view.declaration() == @core.ViewDeclaration::uncacheable(),
    content="true",
  )
  inspect(view.accepts_focus(), content="false")
  inspect(view.flex_weight(), content="0")
  debug_inspect(
    view.layout(downstream_layout_context()).size,
    content="{ width: 80, height: 30 }",
  )
}

///|
test "ViewNode: typed adapters map messages without replacing the node" {
  let child : @core.View[String] = @core.View::from_node(
    DownstreamViewNode::{
      kind: "child",
      message: "child-message",
      size: @core.Size::new(width=4.0, height=4.0),
    },
    event=(node, _context) => @core.ViewEventResult::message(node.message),
  )
  let parent : @core.View[String] = @core.View::from_node(
    DownstreamViewNode::{
      kind: "parent",
      message: "parent-message",
      size: @core.Size::new(width=8.0, height=8.0),
    },
    children=_node => [child],
    event=(node, _context) => @core.ViewEventResult::message(node.message),
  )
  let mapped = parent.map(message => message.length())
  inspect(mapped.identity().kind, content="parent")
  inspect(mapped.event(downstream_event_context()).messages[0], content="14")
  let mapped_child = mapped.children()[0]
  inspect(mapped_child.identity().kind, content="child")
  inspect(
    mapped_child.event(downstream_event_context()).messages[0],
    content="13",
  )
}

///|
struct SnapshotProbeNode {
  calls : Ref[Array[Int]]
}

///|
impl @core.ViewNode for SnapshotProbeNode with fn identity(self) {
  let next = self.calls.val.copy()
  next[0] = next[0] + 1
  self.calls.val = next
  @core.ViewIdentity::new(kind="snapshot-probe")
}

///|
impl @core.ViewNode for SnapshotProbeNode with fn declaration(self) {
  let next = self.calls.val.copy()
  next[1] = next[1] + 1
  self.calls.val = next
  @core.ViewDeclaration::constant()
}

///|
impl @core.ViewNode for SnapshotProbeNode with fn semantics(self) {
  let next = self.calls.val.copy()
  next[2] = next[2] + 1
  self.calls.val = next
  @core.ViewSemanticsInfo::new(label="snapshot")
}

///|
impl @core.ViewNode for SnapshotProbeNode with fn layout(_self, context) {
  @core.ViewLayoutResult::new(size=context.constraints.min)
}

///|
test "View::from_node freezes declarations semantics and static children" {
  let calls = Ref([0, 0, 0, 0, 0])
  let view : @core.View[String] = @core.View::from_node(
    SnapshotProbeNode::{ calls, },
    children=node => {
      let next = node.calls.val.copy()
      next[3] = next[3] + 1
      node.calls.val = next
      []
    },
    semantics_actions=node => {
      let next = node.calls.val.copy()
      next[4] = next[4] + 1
      node.calls.val = next
      [
        @core.ViewSemanticsActionHandler::activate(_context => {
          @core.ViewSemanticsActionResult::message("activate")
        }),
      ]
    },
  )
  debug_inspect(calls.val, content="[1, 1, 1, 1, 1]")
  ignore(view.identity())
  ignore(view.declaration())
  ignore(view.semantics())
  ignore(view.children())
  let mapped = view.map(message => message.length())
  ignore(mapped.identity())
  ignore(mapped.declaration())
  ignore(mapped.semantics())
  ignore(mapped.children())
  inspect(
    mapped.semantics_action_kinds() == [@core.SemanticsActionKind::Activate],
    content="true",
  )
  let event_context = downstream_event_context()
  let result = mapped.dispatch_semantics_action(
    {
      frame: event_context.frame,
      child_frames: event_context.child_frames,
      focused: event_context.focused,
      state: event_context.state,
      text_control: event_context.text_control,
      text_system: event_context.text_system,
      environment: event_context.environment,
      style: event_context.style,
    },
    @core.SemanticsAction::Activate,
  )
  inspect(result.accepted, content="true")
  debug_inspect(result.messages, content="[8]")
  debug_inspect(calls.val, content="[1, 1, 1, 1, 1]")
}

///|
test "View::from_node snapshots producer-owned child and action arrays" {
  let child : @core.View[String] = @core.View::from_node(DownstreamViewNode::{
    kind: "aliased-child",
    message: "child-message",
    size: @core.Size::new(width=4.0, height=4.0),
  })
  let children = [child]
  let handlers = [
    @core.ViewSemanticsActionHandler::activate(_context => {
      @core.ViewSemanticsActionResult::message("activate")
    }),
  ]
  let view : @core.View[String] = @core.View::from_node(
    DownstreamViewNode::{
      kind: "alias-snapshot",
      message: "parent-message",
      size: @core.Size::new(width=8.0, height=8.0),
    },
    children=_node => children,
    semantics_actions=_node => handlers,
  )
  children.clear()
  handlers.clear()
  assert_eq(view.children().length(), 1)
  inspect(view.children()[0].identity().kind, content="aliased-child")
  assert_true(
    view.semantics_action_kinds() == [@core.SemanticsActionKind::Activate],
  )
  let mapped = view.map(message => message.length())
  assert_eq(mapped.children().length(), 1)
  assert_true(
    mapped.semantics_action_kinds() == [@core.SemanticsActionKind::Activate],
  )
}

///|
test "semantic modifiers do not invalidate layout paint or platform" {
  let base : @core.View[Unit] = @core.View::from_node(DownstreamViewNode::{
    kind: "semantic-declaration",
    message: "",
    size: @core.Size::new(width=8.0, height=8.0),
  })
  let previous = base.accessibility_label("before").declaration()
  let next = base.accessibility_label("after").declaration()
  let changes = next.changes_from(previous)
  assert_false(changes.layout())
  assert_false(changes.paint())
  assert_true(changes.semantics())
  assert_false(changes.platform())
}
