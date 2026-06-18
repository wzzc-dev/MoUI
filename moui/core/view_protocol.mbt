///|
pub(all) struct ViewIdentity {
  kind : String
  key : Key?
} derive(Eq)

///|
pub(all) struct ViewLayoutContext {
  constraints : Constraints
  child_sizes : Array[Size]
  text_system : TextSystem
  environment : Environment
}

///|
pub(all) struct ViewLayoutResult {
  size : Size
  child_frames : Array[Rect]
} derive(Eq, Debug)

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
  text_system : TextSystem
}

///|
pub(all) struct ViewPaintPlan {
  commands : Array[DrawCommand]
  child_layers : Array[ViewPaintLayer]
  post_commands : Array[DrawCommand]
  overlay_commands : Array[DrawCommand]
  platform_views : Array[PlatformViewPlacement]
  repaint_boundary : Bool
} derive(Eq, Debug)

///|
pub(all) struct ViewPaintLayer {
  frame : Rect
  cache_key : String
  content_revision : Int
  commands : Array[DrawCommand]
  overlay_commands : Array[DrawCommand]
  platform_views : Array[PlatformViewPlacement]
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
  role : SemanticsRole
  label : String
  value : String
  description : String
  actions : Array[SemanticsAction]
} derive(Eq, Debug)

///|
pub(all) struct ViewStateContext {
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
priv struct ViewNode[Msg] {
  identity_fn : () -> ViewIdentity
  revision_fn : () -> String
  children_fn : () -> Array[View[Msg]]
  build_child_fn : ((ComponentContext) -> View[Msg])?
  child_constraints_fn : (Constraints) -> Constraints
  layout_fn : (ViewLayoutContext) -> ViewLayoutResult
  paint_fn : (ViewPaintContext) -> ViewPaintPlan
  event_fn : (ViewEventContext) -> ViewEventResult[Msg]
  text_input_state_fn : (ViewPaintContext) -> TextInputState?
  text_command_fn : (ViewEventContext, CommandIntent, String?) -> ViewTextCommandResult[
    Msg,
  ]
  semantics_fn : () -> ViewSemanticsInfo
  focusable_fn : () -> Bool
}

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
) -> ViewLayoutResult {
  { size, child_frames }
}

///|
pub fn ViewPaintPlan::empty() -> ViewPaintPlan {
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
pub fn ViewPaintPlan::commands(commands : Array[DrawCommand]) -> ViewPaintPlan {
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
pub fn ViewPaintLayer::new(
  frame~ : Rect,
  cache_key~ : String,
  content_revision~ : Int,
  commands? : Array[DrawCommand] = [],
  overlay_commands? : Array[DrawCommand] = [],
  platform_views? : Array[PlatformViewPlacement] = [],
) -> ViewPaintLayer {
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
  role? : SemanticsRole = SemanticsRole::Group,
  label? : String = "",
  value? : String = "",
  description? : String = "",
  actions? : Array[SemanticsAction] = [],
) -> ViewSemanticsInfo {
  { role, label, value, description, actions }
}

///|
fn[Msg] ViewNode::new(
  identity~ : () -> ViewIdentity,
  revision? : () -> String = () => "",
  children? : () -> Array[View[Msg]] = () => [],
  build_child? : ((ComponentContext) -> View[Msg])? = None,
  child_constraints? : (Constraints) -> Constraints = constraints => {
    constraints.loosen()
  },
  layout~ : (ViewLayoutContext) -> ViewLayoutResult,
  paint? : (ViewPaintContext) -> ViewPaintPlan = _ctx => ViewPaintPlan::empty(),
  event? : (ViewEventContext) -> ViewEventResult[Msg] = _ctx => {
    ViewEventResult::ignored()
  },
  text_input_state? : (ViewPaintContext) -> TextInputState? = _ctx => None,
  text_command? : (ViewEventContext, CommandIntent, String?) -> ViewTextCommandResult[
    Msg,
  ] = (_ctx, _intent, _paste_text) => ViewTextCommandResult::ignored(),
  semantics? : () -> ViewSemanticsInfo = () => ViewSemanticsInfo::new(),
  focusable? : () -> Bool = () => false,
) -> ViewNode[Msg] {
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
fn[Msg] ViewNode::identity(self : ViewNode[Msg]) -> ViewIdentity {
  (self.identity_fn)()
}

///|
fn[Msg] ViewNode::revision(self : ViewNode[Msg]) -> String {
  (self.revision_fn)()
}

///|
fn[Msg] ViewNode::children(self : ViewNode[Msg]) -> Array[View[Msg]] {
  (self.children_fn)()
}

///|
fn[Msg] ViewNode::build_child(
  self : ViewNode[Msg],
) -> ((ComponentContext) -> View[Msg])? {
  self.build_child_fn
}

///|
fn[Msg] ViewNode::child_constraints(
  self : ViewNode[Msg],
  constraints : Constraints,
) -> Constraints {
  (self.child_constraints_fn)(constraints)
}

///|
fn[Msg] ViewNode::layout(
  self : ViewNode[Msg],
  context : ViewLayoutContext,
) -> ViewLayoutResult {
  (self.layout_fn)(context)
}

///|
fn[Msg] ViewNode::paint(
  self : ViewNode[Msg],
  context : ViewPaintContext,
) -> ViewPaintPlan {
  (self.paint_fn)(context)
}

///|
fn[Msg] ViewNode::event(
  self : ViewNode[Msg],
  context : ViewEventContext,
) -> ViewEventResult[Msg] {
  (self.event_fn)(context)
}

///|
fn[Msg] ViewNode::text_input_state(
  self : ViewNode[Msg],
  context : ViewPaintContext,
) -> TextInputState? {
  (self.text_input_state_fn)(context)
}

///|
fn[Msg] ViewNode::text_command(
  self : ViewNode[Msg],
  context : ViewEventContext,
  intent : CommandIntent,
  paste_text? : String? = None,
) -> TextCommandResult {
  (self.text_command_fn)(context, intent, paste_text).result
}

///|
fn[Msg] ViewNode::text_command_result(
  self : ViewNode[Msg],
  context : ViewEventContext,
  intent : CommandIntent,
  paste_text? : String? = None,
) -> ViewTextCommandResult[Msg] {
  (self.text_command_fn)(context, intent, paste_text)
}

///|
fn[Msg] ViewNode::semantics(self : ViewNode[Msg]) -> ViewSemanticsInfo {
  (self.semantics_fn)()
}

///|
fn[Msg] ViewNode::focusable(self : ViewNode[Msg]) -> Bool {
  (self.focusable_fn)()
}

///|
fn[Msg, NextMsg] ViewNode::map(
  self : ViewNode[Msg],
  map : (Msg) -> NextMsg,
) -> ViewNode[NextMsg] {
  ViewNode::new(
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
  priv node : ViewNode[Msg]
}

///|
pub fn[Msg] View::node(
  identity~ : () -> ViewIdentity,
  revision? : () -> String = () => "",
  children? : () -> Array[View[Msg]] = () => [],
  build_child? : ((ComponentContext) -> View[Msg])? = None,
  child_constraints? : (Constraints) -> Constraints = constraints => {
    constraints.loosen()
  },
  layout~ : (ViewLayoutContext) -> ViewLayoutResult,
  paint? : (ViewPaintContext) -> ViewPaintPlan = _ctx => ViewPaintPlan::empty(),
  event? : (ViewEventContext) -> ViewEventResult[Msg] = _ctx => {
    ViewEventResult::ignored()
  },
  text_input_state? : (ViewPaintContext) -> TextInputState? = _ctx => None,
  text_command? : (ViewEventContext, CommandIntent, String?) -> ViewTextCommandResult[
    Msg,
  ] = (_ctx, _intent, _paste_text) => ViewTextCommandResult::ignored(),
  semantics? : () -> ViewSemanticsInfo = () => ViewSemanticsInfo::new(),
  focusable? : () -> Bool = () => false,
) -> View[Msg] {
  {
    node: ViewNode::new(
      identity~,
      revision~,
      children~,
      build_child~,
      child_constraints~,
      layout~,
      paint~,
      event~,
      text_input_state~,
      text_command~,
      semantics~,
      focusable~,
    ),
  }
}

///|
pub fn[Msg] View::identity(self : View[Msg]) -> ViewIdentity {
  self.node.identity()
}

///|
pub fn[Msg] View::revision(self : View[Msg]) -> String {
  self.node.revision()
}

///|
pub fn[Msg] View::children(self : View[Msg]) -> Array[View[Msg]] {
  self.node.children()
}

///|
pub fn[Msg] View::build_child(
  self : View[Msg],
) -> ((ComponentContext) -> View[Msg])? {
  self.node.build_child()
}

///|
pub fn[Msg] View::child_constraints(
  self : View[Msg],
  constraints : Constraints,
) -> Constraints {
  self.node.child_constraints(constraints)
}

///|
pub fn[Msg] View::layout(
  self : View[Msg],
  context : ViewLayoutContext,
) -> ViewLayoutResult {
  self.node.layout(context)
}

///|
pub fn[Msg] View::paint(
  self : View[Msg],
  context : ViewPaintContext,
) -> ViewPaintPlan {
  self.node.paint(context)
}

///|
pub fn[Msg] View::event(
  self : View[Msg],
  context : ViewEventContext,
) -> ViewEventResult[Msg] {
  self.node.event(context)
}

///|
pub fn[Msg] View::text_input_state(
  self : View[Msg],
  context : ViewPaintContext,
) -> TextInputState? {
  self.node.text_input_state(context)
}

///|
pub fn[Msg] View::text_command(
  self : View[Msg],
  context : ViewEventContext,
  intent : CommandIntent,
  paste_text? : String? = None,
) -> TextCommandResult {
  self.node.text_command(context, intent, paste_text~)
}

///|
pub fn[Msg] View::text_command_result(
  self : View[Msg],
  context : ViewEventContext,
  intent : CommandIntent,
  paste_text? : String? = None,
) -> ViewTextCommandResult[Msg] {
  self.node.text_command_result(context, intent, paste_text~)
}

///|
pub fn[Msg] View::semantics(self : View[Msg]) -> ViewSemanticsInfo {
  self.node.semantics()
}

///|
pub fn[Msg] View::accepts_focus(self : View[Msg]) -> Bool {
  self.node.focusable()
}
