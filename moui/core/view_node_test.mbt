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
      scratch: "",
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
  inspect(view.revision(), content="")
  inspect(view.paint_revision(), content="")
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
