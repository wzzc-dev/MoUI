///|
pub(all) struct ViewIdentity {
  kind : String
  key : Key?
} derive(Eq)

///|
pub(all) struct ViewLayoutContext {
  constraints : Constraints
  child_sizes : Array[Size]
  child_flex_weights : Array[Double]
  state : ViewStateContext
  text_system : TextSystem
  environment : Environment
  style : ViewStyle
}

///|
pub(all) struct ViewLayoutResult {
  size : Size
  child_frames : Array[Rect]
  /// True when this node clips its children to its own frame (scroll
  /// containers, clip modifiers). The placement pass folds this into the
  /// accumulated clip so hit regions respect clipping without consulting
  /// paint output.
  clips_children : Bool
  /// True when the node's `child_frames` are final sizing constraints that
  /// may be tighter than the constraints a child was measured under (flex
  /// distributing main-axis slack by weight). The placement pass re-measures
  /// any child whose placed frame size differs from its measured size under
  /// tight constraints derived from that frame, so internal layout wraps to
  /// the extent the child actually occupies (ADR 0035).
  child_frames_tight : Bool
} derive(Eq, Debug, ToJson)

///|
/// Recursive layout tree produced by the layout pass. Unlike
/// `ViewLayoutResult` (a single node's measured size + child frames),
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
pub(all) struct ViewPaintContext {
  frame : Rect
  child_frames : Array[Rect]
  focused : Bool
  state : ViewStateContext
  text_control : TextControlStateContext
  environment : Environment
  style : ViewStyle
  text_system : TextSystem
  /// Current animation clock time in milliseconds, threaded from the runtime's
  /// `FrameTick`. Controls read this to compute transition `progress` between
  /// a state-change timestamp and `now_ms`. Stays 0.0 when no clock is active
  /// (e.g. the intrinsic-size layout path), which makes progress clamp to the
  /// terminal state so non-animated paint is unchanged.
  now_ms : Double
}

///|
/// Context for the platform-tree pass. Platform placements are produced
/// independently from paint so native child views can update without creating
/// draw commands or scheduling a renderer frame.
pub(all) struct ViewPlatformContext {
  frame : Rect
  child_frames : Array[Rect]
  environment : Environment
  style : ViewStyle
}

///|
pub(all) struct ViewPaintPlan {
  commands : Array[DrawCommand]
  child_layers : Array[ViewPaintLayer]
  post_commands : Array[DrawCommand]
  overlay_commands : Array[DrawCommand]
  repaint_boundary : Bool
  /// True when this paint pass is a mid-animation sample (progress < 1.0) and
  /// the runtime should keep requesting redraws until the animation settles.
  /// The runtime folds this across the painted tree to decide whether to keep
  /// ticking. Controls that hard-cut between states leave this false.
  animating : Bool
} derive(Eq, Debug)

///|
pub(all) struct ViewPaintLayer {
  frame : Rect
  cache_key : String
  content_revision : Int
  commands : Array[DrawCommand]
  overlay_commands : Array[DrawCommand]
} derive(Eq, Debug)

///|
pub(all) struct ViewEventContext {
  frame : Rect
  child_frames : Array[Rect]
  event : AppEvent
  focused : Bool
  state : ViewStateContext
  text_control : TextControlStateContext
  text_system : TextSystem
  environment : Environment
  style : ViewStyle
  /// Current animation clock time in ms, matching `ViewPaintContext.now_ms`.
  /// Event handlers read this to timestamp state transitions (e.g. recording
  /// when a button entered hover) so the next paint can interpolate progress.
  now_ms : Double
}

///|
pub(all) enum ViewDirtyHint {
  ViewClean
  ViewPaintDirty
  ViewLayoutDirty
  ViewBuildDirty
} derive(Eq, Debug)

///|
pub(all) struct ViewEventResult[Msg] {
  changed : Bool
  activated : Bool
  focused : Bool
  captured : Bool
  state : ViewStateContext?
  text_control : TextControlStateContext?
  dirty : ViewDirtyHint
  messages : Array[Msg]
} derive(Eq, Debug)

///|
pub(all) struct ViewTextCommandResult[Msg] {
  result : TextCommandResult
  text_control : TextControlStateContext?
  messages : Array[Msg]
} derive(Eq, Debug)

///|
pub(all) struct ViewSemanticsInfo {
  composition : SemanticsComposition
  semantic_id : SemanticId?
  role : SemanticsRole?
  level : Int?
  url : String?
  label : String?
  value : String?
  description : String?
  disabled : Bool?
  selected : Bool?
  pressed : Bool?
  checked : SemanticsCheckedState?
  expanded : Bool?
  invalid : Bool?
  required : Bool?
  read_only : Bool?
  busy : Bool?
  multiline : Bool?
  password : Bool?
  modal : Bool?
  numeric : SemanticsNumericValue?
  text : SemanticsTextValue?
  collection : SemanticsCollectionInfo?
  relations : SemanticsRelationsDeclaration?
  live : SemanticsLive?
  live_atomic : Bool?
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ViewStateContext {
  focused : Bool
  hovered : Bool
  pressed : Bool
  selected : Bool
  checked : Bool
  expanded : Bool
  disabled : Bool
  slots : ViewStateSlots
} derive(Eq, Debug)

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
pub fn ViewIdentity::new(kind~ : String, key? : String? = None) -> ViewIdentity {
  {
    kind,
    key: match key {
      Some(value) => Some(Key::new(value))
      None => None
    },
  }
}

///|
pub fn ViewLayoutResult::new(
  size~ : Size,
  child_frames? : Array[Rect] = [],
  clips_children? : Bool = false,
  child_frames_tight? : Bool = false,
) -> ViewLayoutResult {
  { size, child_frames, clips_children, child_frames_tight }
}

///|
pub fn ViewPaintPlan::empty() -> ViewPaintPlan {
  {
    commands: [],
    child_layers: [],
    post_commands: [],
    overlay_commands: [],
    repaint_boundary: false,
    animating: false,
  }
}

///|
pub fn ViewPaintPlan::commands(commands : Array[DrawCommand]) -> ViewPaintPlan {
  {
    commands,
    child_layers: [],
    post_commands: [],
    overlay_commands: [],
    repaint_boundary: false,
    animating: false,
  }
}

///|
/// Like `ViewPaintPlan::commands` but flags the paint as a mid-animation
/// sample. The runtime keeps requesting redraws while any painted plan in the
/// tree reports `animating=true`. Controls set this when their transition
/// `progress < 1.0` (and `reduced_motion` is not in effect).
pub fn ViewPaintPlan::animating_commands(
  commands : Array[DrawCommand],
) -> ViewPaintPlan {
  { ..ViewPaintPlan::commands(commands), animating: true }
}

///|
pub fn ViewPaintLayer::new(
  frame~ : Rect,
  cache_key~ : String,
  content_revision~ : Int,
  commands? : Array[DrawCommand] = [],
  overlay_commands? : Array[DrawCommand] = [],
) -> ViewPaintLayer {
  { frame, cache_key, content_revision, commands, overlay_commands }
}

///|
pub fn[Msg] ViewEventResult::ignored() -> ViewEventResult[Msg] {
  {
    changed: false,
    activated: false,
    focused: false,
    captured: false,
    state: None,
    text_control: None,
    dirty: ViewClean,
    messages: [],
  }
}

///|
pub fn[Msg] ViewEventResult::message(message : Msg) -> ViewEventResult[Msg] {
  {
    changed: true,
    activated: true,
    focused: false,
    captured: true,
    state: None,
    text_control: None,
    dirty: ViewPaintDirty,
    messages: [message],
  }
}

///|
pub fn[Msg] ViewTextCommandResult::ignored() -> ViewTextCommandResult[Msg] {
  { result: TextCommandResult::ignored(), text_control: None, messages: [] }
}

///|
pub fn[Msg] ViewTextCommandResult::new(
  result~ : TextCommandResult,
  text_control? : TextControlStateContext? = None,
  messages? : Array[Msg] = [],
) -> ViewTextCommandResult[Msg] {
  { result, text_control, messages }
}

///|
pub fn ViewSemanticsInfo::new(
  composition? : SemanticsComposition = SemanticsComposition::Transparent,
  semantic_id? : SemanticId,
  role? : SemanticsRole,
  level? : Int,
  url? : String,
  label? : String,
  value? : String,
  description? : String,
  disabled? : Bool,
  selected? : Bool,
  pressed? : Bool,
  checked? : SemanticsCheckedState,
  expanded? : Bool,
  invalid? : Bool,
  required? : Bool,
  read_only? : Bool,
  busy? : Bool,
  multiline? : Bool,
  password? : Bool,
  modal? : Bool,
  numeric? : SemanticsNumericValue,
  text? : SemanticsTextValue,
  collection? : SemanticsCollectionInfo,
  relations? : SemanticsRelationsDeclaration,
  live? : SemanticsLive,
  live_atomic? : Bool,
) -> ViewSemanticsInfo {
  {
    composition,
    semantic_id,
    role,
    level,
    url,
    label,
    value,
    description,
    disabled,
    selected,
    pressed,
    checked,
    expanded,
    invalid,
    required,
    read_only,
    busy,
    multiline,
    password,
    modal,
    numeric,
    text,
    collection,
    relations,
    live,
    live_atomic,
  }
}

///|
pub struct View[Msg] {
  priv adapter : ViewAdapter[Msg]
}

///|
/// Construct a typed view from a concrete message-independent node.
///
/// The node supplies layout, paint, semantics, focus, and reconciliation
/// behavior through `ViewNode`. Optional adapters attach typed children,
/// events, and text commands without erasing `Msg` from the
/// public view. Identity, declaration, semantics metadata, and static children
/// are sampled exactly once here. `View::map` maps only typed adapters and
/// preserves those frozen snapshots.
pub fn[Node : ViewNode, Msg] View::from_node(
  node : Node,
  children? : (Node) -> Array[View[Msg]] = _node => [],
  event? : (Node, ViewEventContext) -> ViewEventResult[Msg] = (_node, _context) => {
    ViewEventResult::ignored()
  },
  text_command? : (Node, ViewEventContext, CommandIntent, String?) -> ViewTextCommandResult[
    Msg,
  ] = (_node, _context, _intent, _paste_text) => {
    ViewTextCommandResult::ignored()
  },
  semantics_actions? : (Node) -> Array[ViewSemanticsActionHandler[Msg]] = _node => {
    []
  },
) -> View[Msg] {
  let identity_snapshot = node.identity()
  let declaration_snapshot = node.declaration()
  let semantics_snapshot = node.semantics()
  let focusable_snapshot = node.focusable()
  let focus_trap_snapshot = node.focus_trap()
  let semantics_action_handlers = semantics_actions(node)
  let children_snapshot = children(node)
  {
    adapter: ViewAdapter::new(
      node=node as &ViewNode,
      identity=identity_snapshot,
      declaration=declaration_snapshot,
      semantics=semantics_snapshot,
      focusable=focusable_snapshot,
      focus_trap=focus_trap_snapshot,
      semantics_action_handlers~,
      children=children_snapshot,
      event=context => event(node, context),
      text_command=(context, intent, paste_text) => {
        text_command(node, context, intent, paste_text)
      },
    ),
  }
}

///|
pub fn[Msg] View::identity(self : View[Msg]) -> ViewIdentity {
  self.adapter.identity_snapshot
}

///|
pub fn[Msg] View::declaration(self : View[Msg]) -> ViewDeclaration {
  self.adapter.declaration_snapshot
}

///|
pub fn[Msg] View::children(self : View[Msg]) -> Array[View[Msg]] {
  self.adapter.children()
}

///|
pub fn[Msg] View::child_constraints(
  self : View[Msg],
  constraints : Constraints,
) -> Constraints {
  self.adapter.node.child_constraints(constraints)
}

///|
pub fn[Msg] View::child_environment(
  self : View[Msg],
  environment : Environment,
) -> Environment {
  self.adapter.node.child_environment(environment)
}

///|
pub fn[Msg] View::child_style(self : View[Msg], style : ViewStyle) -> ViewStyle {
  self.adapter.node.child_style(style)
}

///|
pub fn[Msg] View::layout(
  self : View[Msg],
  context : ViewLayoutContext,
) -> ViewLayoutResult {
  self.adapter.node.layout(context)
}

///|
pub fn[Msg] View::place_overlays(
  self : View[Msg],
  context : OverlayPlacementContext,
) -> Array[(Int, Rect)]? {
  self.adapter.node.place_overlays(context)
}

///|
pub fn[Msg] View::paint(
  self : View[Msg],
  context : ViewPaintContext,
) -> ViewPaintPlan {
  self.adapter.node.paint(context)
}

///|
pub fn[Msg] View::platform_views(
  self : View[Msg],
  context : ViewPlatformContext,
) -> Array[PlatformViewPlacement] {
  self.adapter.node.platform_views(context)
}

///|
pub fn[Msg] View::event(
  self : View[Msg],
  context : ViewEventContext,
) -> ViewEventResult[Msg] {
  self.adapter.event(context)
}

///|
pub fn[Msg] View::text_input_state(
  self : View[Msg],
  context : ViewPaintContext,
) -> TextInputState? {
  self.adapter.node.text_input_state(context)
}

///|
pub fn[Msg] View::text_command(
  self : View[Msg],
  context : ViewEventContext,
  intent : CommandIntent,
  paste_text? : String? = None,
) -> TextCommandResult {
  self.adapter.text_command_result(context, intent, paste_text~).result
}

///|
pub fn[Msg] View::text_command_result(
  self : View[Msg],
  context : ViewEventContext,
  intent : CommandIntent,
  paste_text? : String? = None,
) -> ViewTextCommandResult[Msg] {
  self.adapter.text_command_result(context, intent, paste_text~)
}

///|
pub fn[Msg] View::semantics(self : View[Msg]) -> ViewSemanticsInfo {
  self.adapter.semantics_snapshot
}

///|
pub fn[Msg] View::keyboard_policy(self : View[Msg]) -> KeyboardPolicy {
  self.adapter.node.keyboard_policy()
}

///|
pub fn[Msg] View::accepts_focus(self : View[Msg]) -> Bool {
  self.adapter.focusable_snapshot
}

///|
pub fn[Msg] View::traps_focus(self : View[Msg]) -> Bool {
  self.adapter.focus_trap_snapshot
}

///|
pub fn[Msg] View::semantics_action_kinds(
  self : View[Msg],
) -> Array[SemanticsActionKind] {
  self.adapter.semantics_action_kinds()
}

///|
pub fn[Msg] View::dispatch_semantics_action(
  self : View[Msg],
  context : ViewSemanticsActionContext,
  action : SemanticsAction,
) -> ViewSemanticsActionResult[Msg] {
  self.adapter.dispatch_semantics_action(context, action)
}

///|
pub fn[Msg] View::flex_weight(self : View[Msg]) -> Double {
  self.adapter.node.flex_weight()
}
