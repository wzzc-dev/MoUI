///|
pub(all) struct VirtualNodeIdentity {
  kind : String
  key : Key?
} derive(Eq)

///|
pub(all) struct VirtualNodeLayoutContext {
  constraints : Constraints
  child_sizes : Array[Size]
  text_system : TextSystem
  environment : Environment
}

///|
pub(all) struct VirtualNodeLayoutResult {
  size : Size
  child_frames : Array[Rect]
} derive(Eq, Debug)

///|
/// Recursive layout tree produced by the layout pass. Unlike
/// `VirtualNodeLayoutResult` (a single node's measured size + child frames),
/// `LayoutResult` is the fully-nested tree emitted by `AppRuntime::layout`.
pub(all) struct LayoutResult {
  frame : Rect
  children : Array[LayoutResult]
} derive(Eq, Debug, ToJson)

///|
pub fn hit_test(layout : LayoutResult, point : Point) -> Bool {
  if !layout.frame.contains(point) {
    false
  } else if layout.children.length() == 0 {
    true
  } else {
    layout.children.any(child => hit_test(child, point))
  }
}

///|
pub(all) struct VirtualNodePaintContext {
  frame : Rect
  child_frames : Array[Rect]
  focused : Bool
  state : VirtualNodeStateContext
  text_control : TextControlStateContext
  environment : Environment
  text_system : TextSystem
}

///|
pub(all) struct VirtualNodePaintPlan {
  commands : Array[DrawCommand]
  child_layers : Array[VirtualNodePaintLayer]
  post_commands : Array[DrawCommand]
  overlay_commands : Array[DrawCommand]
  platform_views : Array[PlatformViewPlacement]
  repaint_boundary : Bool
} derive(Eq, Debug)

///|
pub(all) struct VirtualNodePaintLayer {
  frame : Rect
  cache_key : String
  content_revision : Int
  commands : Array[DrawCommand]
  overlay_commands : Array[DrawCommand]
  platform_views : Array[PlatformViewPlacement]
} derive(Eq, Debug)

///|
pub(all) struct VirtualNodeEventContext {
  frame : Rect
  child_frames : Array[Rect]
  event : AppEvent
  focused : Bool
  state : VirtualNodeStateContext
  text_control : TextControlStateContext
  text_system : TextSystem
  environment : Environment
}

///|
pub(all) enum VirtualNodeDirtyHint {
  VirtualNodeClean
  VirtualNodePaintDirty
  VirtualNodeLayoutDirty
  VirtualNodeBuildDirty
} derive(Eq, Debug)

///|
pub(all) struct VirtualNodeEventResult[Msg] {
  changed : Bool
  activated : Bool
  focused : Bool
  captured : Bool
  state : VirtualNodeStateContext?
  text_control : TextControlStateContext?
  dirty : VirtualNodeDirtyHint
  messages : Array[Msg]
} derive(Eq, Debug)

///|
pub(all) struct VirtualNodeTextCommandResult[Msg] {
  result : TextCommandResult
  text_control : TextControlStateContext?
  messages : Array[Msg]
} derive(Eq, Debug)

///|
pub(all) struct VirtualNodeSemanticsInfo {
  role : SemanticsRole
  label : String
  value : String
  description : String
  actions : Array[SemanticsAction]
} derive(Eq, Debug)

///|
pub(all) struct VirtualNodeStateContext {
  focused : Bool
  hovered : Bool
  pressed : Bool
  selected : Bool
  checked : Bool
  expanded : Bool
  disabled : Bool
  scratch : String
} derive(Eq, Debug)

///|
pub(all) struct TextHistoryEntryContext {
  text : String
  caret : Int
  selection : TextRange?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct TextControlStateContext {
  caret : Int
  selection : TextRange?
  text_selection_anchor : Int?
  composition : String?
  composition_cursor : TextRange?
  undo_stack : Array[TextHistoryEntryContext]
  redo_stack : Array[TextHistoryEntryContext]
} derive(Eq, Debug, ToJson)

///|
pub struct VirtualNode[Msg] {
  priv identity_fn : () -> VirtualNodeIdentity
  priv revision_fn : () -> String
  priv children_fn : () -> Array[View[Msg]]
  priv build_child_fn : ((ComponentContext) -> View[Msg])?
  priv child_constraints_fn : (Constraints) -> Constraints
  priv layout_fn : (VirtualNodeLayoutContext) -> VirtualNodeLayoutResult
  priv paint_fn : (VirtualNodePaintContext) -> VirtualNodePaintPlan
  priv event_fn : (VirtualNodeEventContext) -> VirtualNodeEventResult[Msg]
  priv text_input_state_fn : (VirtualNodePaintContext) -> TextInputState?
  priv text_command_fn : (VirtualNodeEventContext, CommandIntent, String?) -> VirtualNodeTextCommandResult[
    Msg,
  ]
  priv semantics_fn : () -> VirtualNodeSemanticsInfo
  priv focusable_fn : () -> Bool
}

///|
pub fn VirtualNodeIdentity::new(
  kind~ : String,
  key? : String? = None,
) -> VirtualNodeIdentity {
  {
    kind,
    key: match key {
      Some(value) => Some(Key::new(value))
      None => None
    },
  }
}

///|
pub fn VirtualNodeLayoutResult::new(
  size~ : Size,
  child_frames? : Array[Rect] = [],
) -> VirtualNodeLayoutResult {
  { size, child_frames }
}

///|
pub fn VirtualNodePaintPlan::empty() -> VirtualNodePaintPlan {
  {
    commands: [],
    child_layers: [],
    post_commands: [],
    overlay_commands: [],
    platform_views: [],
    repaint_boundary: false,
  }
}

///|
pub fn VirtualNodePaintPlan::commands(
  commands : Array[DrawCommand],
) -> VirtualNodePaintPlan {
  {
    commands,
    child_layers: [],
    post_commands: [],
    overlay_commands: [],
    platform_views: [],
    repaint_boundary: false,
  }
}

///|
pub fn VirtualNodePaintLayer::new(
  frame~ : Rect,
  cache_key~ : String,
  content_revision~ : Int,
  commands? : Array[DrawCommand] = [],
  overlay_commands? : Array[DrawCommand] = [],
  platform_views? : Array[PlatformViewPlacement] = [],
) -> VirtualNodePaintLayer {
  {
    frame,
    cache_key,
    content_revision,
    commands,
    overlay_commands,
    platform_views,
  }
}

///|
pub fn[Msg] VirtualNodeEventResult::ignored() -> VirtualNodeEventResult[Msg] {
  {
    changed: false,
    activated: false,
    focused: false,
    captured: false,
    state: None,
    text_control: None,
    dirty: VirtualNodeClean,
    messages: [],
  }
}

///|
pub fn[Msg] VirtualNodeEventResult::message(message : Msg) -> VirtualNodeEventResult[Msg] {
  {
    changed: true,
    activated: true,
    focused: false,
    captured: true,
    state: None,
    text_control: None,
    dirty: VirtualNodePaintDirty,
    messages: [message],
  }
}

///|
pub fn[Msg] VirtualNodeTextCommandResult::ignored() -> VirtualNodeTextCommandResult[Msg] {
  { result: TextCommandResult::ignored(), text_control: None, messages: [] }
}

///|
pub fn[Msg] VirtualNodeTextCommandResult::new(
  result~ : TextCommandResult,
  text_control? : TextControlStateContext? = None,
  messages? : Array[Msg] = [],
) -> VirtualNodeTextCommandResult[Msg] {
  { result, text_control, messages }
}

///|
pub fn VirtualNodeSemanticsInfo::new(
  role? : SemanticsRole = SemanticsRole::Group,
  label? : String = "",
  value? : String = "",
  description? : String = "",
  actions? : Array[SemanticsAction] = [],
) -> VirtualNodeSemanticsInfo {
  { role, label, value, description, actions }
}

///|
pub fn[Msg] VirtualNode::new(
  identity~ : () -> VirtualNodeIdentity,
  revision? : () -> String = () => "",
  children? : () -> Array[View[Msg]] = () => [],
  build_child? : ((ComponentContext) -> View[Msg])? = None,
  child_constraints? : (Constraints) -> Constraints = constraints => {
    constraints.loosen()
  },
  layout~ : (VirtualNodeLayoutContext) -> VirtualNodeLayoutResult,
  paint? : (VirtualNodePaintContext) -> VirtualNodePaintPlan = _ctx => {
    VirtualNodePaintPlan::empty()
  },
  event? : (VirtualNodeEventContext) -> VirtualNodeEventResult[Msg] = _ctx => {
    VirtualNodeEventResult::ignored()
  },
  text_input_state? : (VirtualNodePaintContext) -> TextInputState? = _ctx => None,
  text_command? : (VirtualNodeEventContext, CommandIntent, String?) -> VirtualNodeTextCommandResult[
    Msg,
  ] = (_ctx, _intent, _paste_text) => VirtualNodeTextCommandResult::ignored(),
  semantics? : () -> VirtualNodeSemanticsInfo = () => VirtualNodeSemanticsInfo::new(),
  focusable? : () -> Bool = () => false,
) -> VirtualNode[Msg] {
  {
    identity_fn: identity,
    revision_fn: revision,
    children_fn: children,
    build_child_fn: build_child,
    child_constraints_fn: child_constraints,
    layout_fn: layout,
    paint_fn: paint,
    event_fn: event,
    text_input_state_fn: text_input_state,
    text_command_fn: text_command,
    semantics_fn: semantics,
    focusable_fn: focusable,
  }
}

///|
pub fn[Msg] VirtualNode::identity(self : VirtualNode[Msg]) -> VirtualNodeIdentity {
  (self.identity_fn)()
}

///|
pub fn[Msg] VirtualNode::revision(self : VirtualNode[Msg]) -> String {
  (self.revision_fn)()
}

///|
pub fn[Msg] VirtualNode::children(self : VirtualNode[Msg]) -> Array[View[Msg]] {
  (self.children_fn)()
}

///|
pub fn[Msg] VirtualNode::build_child(
  self : VirtualNode[Msg],
) -> ((ComponentContext) -> View[Msg])? {
  self.build_child_fn
}

///|
pub fn[Msg] VirtualNode::child_constraints(
  self : VirtualNode[Msg],
  constraints : Constraints,
) -> Constraints {
  (self.child_constraints_fn)(constraints)
}

///|
pub fn[Msg] VirtualNode::layout(
  self : VirtualNode[Msg],
  context : VirtualNodeLayoutContext,
) -> VirtualNodeLayoutResult {
  (self.layout_fn)(context)
}

///|
pub fn[Msg] VirtualNode::paint(
  self : VirtualNode[Msg],
  context : VirtualNodePaintContext,
) -> VirtualNodePaintPlan {
  (self.paint_fn)(context)
}

///|
pub fn[Msg] VirtualNode::event(
  self : VirtualNode[Msg],
  context : VirtualNodeEventContext,
) -> VirtualNodeEventResult[Msg] {
  (self.event_fn)(context)
}

///|
pub fn[Msg] VirtualNode::text_input_state(
  self : VirtualNode[Msg],
  context : VirtualNodePaintContext,
) -> TextInputState? {
  (self.text_input_state_fn)(context)
}

///|
pub fn[Msg] VirtualNode::text_command(
  self : VirtualNode[Msg],
  context : VirtualNodeEventContext,
  intent : CommandIntent,
  paste_text? : String? = None,
) -> TextCommandResult {
  (self.text_command_fn)(context, intent, paste_text).result
}

///|
pub fn[Msg] VirtualNode::text_command_result(
  self : VirtualNode[Msg],
  context : VirtualNodeEventContext,
  intent : CommandIntent,
  paste_text? : String? = None,
) -> VirtualNodeTextCommandResult[Msg] {
  (self.text_command_fn)(context, intent, paste_text)
}

///|
pub fn[Msg] VirtualNode::semantics(self : VirtualNode[Msg]) -> VirtualNodeSemanticsInfo {
  (self.semantics_fn)()
}

///|
pub fn[Msg] VirtualNode::focusable(self : VirtualNode[Msg]) -> Bool {
  (self.focusable_fn)()
}

///|
pub fn[Msg, NextMsg] VirtualNode::map(
  self : VirtualNode[Msg],
  map : (Msg) -> NextMsg,
) -> VirtualNode[NextMsg] {
  VirtualNode::new(
    identity=() => self.identity(),
    revision=() => self.revision(),
    children=() => self.children().map(child => child.map(map)),
    build_child=match self.build_child() {
      Some(build) => Some(ctx => build(ctx).map(map))
      None => None
    },
    child_constraints=constraints => self.child_constraints(constraints),
    layout=context => self.layout(context),
    paint=context => self.paint(context),
    event=context => {
      let result = self.event(context)
      {
        changed: result.changed,
        activated: result.activated,
        focused: result.focused,
        captured: result.captured,
        state: result.state,
        text_control: result.text_control,
        dirty: result.dirty,
        messages: result.messages.map(message => map(message)),
      }
    },
    text_input_state=context => self.text_input_state(context),
    text_command=(context, intent, paste_text) => {
      let result = self.text_command_result(context, intent, paste_text~)
      {
        result: result.result,
        text_control: result.text_control,
        messages: result.messages.map(message => map(message)),
      }
    },
    semantics=() => self.semantics(),
    focusable=() => self.focusable(),
  )
}

///|
pub struct View[Msg] {
  priv virtual_node : VirtualNode[Msg]
}

///|
fn[Msg] view_from_virtual_node(virtual_node : VirtualNode[Msg]) -> View[Msg] {
  { virtual_node, }
}

///|
pub fn[Msg] View::virtual_node(virtual_node : VirtualNode[Msg]) -> View[Msg] {
  view_from_virtual_node(virtual_node)
}

///|
pub fn[Msg] View::virtual_node_ops(self : View[Msg]) -> VirtualNode[Msg]? {
  Some(self.virtual_node)
}

///|
pub fn[Msg] View::ops(self : View[Msg]) -> VirtualNode[Msg] {
  self.virtual_node
}
