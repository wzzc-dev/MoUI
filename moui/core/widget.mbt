///|
pub(all) struct WidgetIdentity {
  kind : String
  key : Key?
} derive(Eq)

///|
pub(all) struct WidgetLayoutContext {
  constraints : Constraints
  child_sizes : Array[Size]
  text_system : TextSystem
  environment : Environment
}

///|
pub(all) struct WidgetLayoutResult {
  size : Size
  child_frames : Array[Rect]
} derive(Eq, Debug)

///|
pub(all) struct WidgetPaintContext {
  frame : Rect
  child_frames : Array[Rect]
  focused : Bool
  state : WidgetStateContext
  text_control : TextControlStateContext
  environment : Environment
  text_system : TextSystem
}

///|
pub(all) struct WidgetPaintPlan {
  commands : Array[DrawCommand]
  child_layers : Array[WidgetPaintLayer]
  post_commands : Array[DrawCommand]
  overlay_commands : Array[DrawCommand]
  platform_views : Array[PlatformViewPlacement]
  repaint_boundary : Bool
} derive(Eq, Debug)

///|
pub(all) struct WidgetPaintLayer {
  frame : Rect
  cache_key : String
  content_revision : Int
  commands : Array[DrawCommand]
  overlay_commands : Array[DrawCommand]
  platform_views : Array[PlatformViewPlacement]
} derive(Eq, Debug)

///|
pub(all) struct WidgetEventContext {
  frame : Rect
  child_frames : Array[Rect]
  event : AppEvent
  focused : Bool
  state : WidgetStateContext
  text_control : TextControlStateContext
  text_system : TextSystem
  environment : Environment
}

///|
pub(all) enum WidgetDirtyHint {
  WidgetClean
  WidgetPaintDirty
  WidgetLayoutDirty
  WidgetBuildDirty
} derive(Eq, Debug)

///|
pub(all) struct WidgetEventResult[Msg] {
  changed : Bool
  activated : Bool
  focused : Bool
  captured : Bool
  state : WidgetStateContext?
  text_control : TextControlStateContext?
  dirty : WidgetDirtyHint
  messages : Array[Msg]
} derive(Eq, Debug)

///|
pub(all) struct WidgetTextCommandResult[Msg] {
  result : TextCommandResult
  text_control : TextControlStateContext?
  messages : Array[Msg]
} derive(Eq, Debug)

///|
pub(all) struct WidgetSemanticsInfo {
  role : SemanticsRole
  label : String
  value : String
  description : String
  actions : Array[SemanticsAction]
} derive(Eq, Debug)

///|
pub(all) struct WidgetStateContext {
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
pub struct WidgetOps[Msg] {
  priv identity_fn : () -> WidgetIdentity
  priv revision_fn : () -> String
  priv children_fn : () -> Array[View[Msg]]
  priv build_child_fn : ((BuildContext) -> View[Msg])?
  priv child_constraints_fn : (Constraints) -> Constraints
  priv layout_fn : (WidgetLayoutContext) -> WidgetLayoutResult
  priv paint_fn : (WidgetPaintContext) -> WidgetPaintPlan
  priv event_fn : (WidgetEventContext) -> WidgetEventResult[Msg]
  priv text_input_state_fn : (WidgetPaintContext) -> TextInputState?
  priv text_command_fn : (WidgetEventContext, CommandIntent, String?) -> WidgetTextCommandResult[
    Msg,
  ]
  priv semantics_fn : () -> WidgetSemanticsInfo
  priv focusable_fn : () -> Bool
}

///|
pub fn WidgetIdentity::new(
  kind~ : String,
  key? : String? = None,
) -> WidgetIdentity {
  {
    kind,
    key: match key {
      Some(value) => Some(Key::new(value))
      None => None
    },
  }
}

///|
pub fn WidgetLayoutResult::new(
  size~ : Size,
  child_frames? : Array[Rect] = [],
) -> WidgetLayoutResult {
  { size, child_frames }
}

///|
pub fn WidgetPaintPlan::empty() -> WidgetPaintPlan {
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
pub fn WidgetPaintPlan::commands(
  commands : Array[DrawCommand],
) -> WidgetPaintPlan {
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
pub fn WidgetPaintLayer::new(
  frame~ : Rect,
  cache_key~ : String,
  content_revision~ : Int,
  commands? : Array[DrawCommand] = [],
  overlay_commands? : Array[DrawCommand] = [],
  platform_views? : Array[PlatformViewPlacement] = [],
) -> WidgetPaintLayer {
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
pub fn[Msg] WidgetEventResult::ignored() -> WidgetEventResult[Msg] {
  {
    changed: false,
    activated: false,
    focused: false,
    captured: false,
    state: None,
    text_control: None,
    dirty: WidgetClean,
    messages: [],
  }
}

///|
pub fn[Msg] WidgetEventResult::message(message : Msg) -> WidgetEventResult[Msg] {
  {
    changed: true,
    activated: true,
    focused: false,
    captured: true,
    state: None,
    text_control: None,
    dirty: WidgetPaintDirty,
    messages: [message],
  }
}

///|
pub fn[Msg] WidgetTextCommandResult::ignored() -> WidgetTextCommandResult[Msg] {
  { result: TextCommandResult::ignored(), text_control: None, messages: [] }
}

///|
pub fn[Msg] WidgetTextCommandResult::new(
  result~ : TextCommandResult,
  text_control? : TextControlStateContext? = None,
  messages? : Array[Msg] = [],
) -> WidgetTextCommandResult[Msg] {
  { result, text_control, messages }
}

///|
pub fn WidgetSemanticsInfo::new(
  role? : SemanticsRole = SemanticsRole::Group,
  label? : String = "",
  value? : String = "",
  description? : String = "",
  actions? : Array[SemanticsAction] = [],
) -> WidgetSemanticsInfo {
  { role, label, value, description, actions }
}

///|
pub fn[Msg] WidgetOps::new(
  identity~ : () -> WidgetIdentity,
  revision? : () -> String = () => "",
  children? : () -> Array[View[Msg]] = () => [],
  build_child? : ((BuildContext) -> View[Msg])? = None,
  child_constraints? : (Constraints) -> Constraints = constraints => {
    constraints.loosen()
  },
  layout~ : (WidgetLayoutContext) -> WidgetLayoutResult,
  paint? : (WidgetPaintContext) -> WidgetPaintPlan = _ctx => {
    WidgetPaintPlan::empty()
  },
  event? : (WidgetEventContext) -> WidgetEventResult[Msg] = _ctx => {
    WidgetEventResult::ignored()
  },
  text_input_state? : (WidgetPaintContext) -> TextInputState? = _ctx => None,
  text_command? : (WidgetEventContext, CommandIntent, String?) -> WidgetTextCommandResult[
    Msg,
  ] = (_ctx, _intent, _paste_text) => WidgetTextCommandResult::ignored(),
  semantics? : () -> WidgetSemanticsInfo = () => WidgetSemanticsInfo::new(),
  focusable? : () -> Bool = () => false,
) -> WidgetOps[Msg] {
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
pub fn[Msg] WidgetOps::identity(self : WidgetOps[Msg]) -> WidgetIdentity {
  (self.identity_fn)()
}

///|
pub fn[Msg] WidgetOps::revision(self : WidgetOps[Msg]) -> String {
  (self.revision_fn)()
}

///|
pub fn[Msg] WidgetOps::children(self : WidgetOps[Msg]) -> Array[View[Msg]] {
  (self.children_fn)()
}

///|
pub fn[Msg] WidgetOps::build_child(
  self : WidgetOps[Msg],
) -> ((BuildContext) -> View[Msg])? {
  self.build_child_fn
}

///|
pub fn[Msg] WidgetOps::child_constraints(
  self : WidgetOps[Msg],
  constraints : Constraints,
) -> Constraints {
  (self.child_constraints_fn)(constraints)
}

///|
pub fn[Msg] WidgetOps::layout(
  self : WidgetOps[Msg],
  context : WidgetLayoutContext,
) -> WidgetLayoutResult {
  (self.layout_fn)(context)
}

///|
pub fn[Msg] WidgetOps::paint(
  self : WidgetOps[Msg],
  context : WidgetPaintContext,
) -> WidgetPaintPlan {
  (self.paint_fn)(context)
}

///|
pub fn[Msg] WidgetOps::event(
  self : WidgetOps[Msg],
  context : WidgetEventContext,
) -> WidgetEventResult[Msg] {
  (self.event_fn)(context)
}

///|
pub fn[Msg] WidgetOps::text_input_state(
  self : WidgetOps[Msg],
  context : WidgetPaintContext,
) -> TextInputState? {
  (self.text_input_state_fn)(context)
}

///|
pub fn[Msg] WidgetOps::text_command(
  self : WidgetOps[Msg],
  context : WidgetEventContext,
  intent : CommandIntent,
  paste_text? : String? = None,
) -> TextCommandResult {
  (self.text_command_fn)(context, intent, paste_text).result
}

///|
pub fn[Msg] WidgetOps::text_command_result(
  self : WidgetOps[Msg],
  context : WidgetEventContext,
  intent : CommandIntent,
  paste_text? : String? = None,
) -> WidgetTextCommandResult[Msg] {
  (self.text_command_fn)(context, intent, paste_text)
}

///|
pub fn[Msg] WidgetOps::semantics(self : WidgetOps[Msg]) -> WidgetSemanticsInfo {
  (self.semantics_fn)()
}

///|
pub fn[Msg] WidgetOps::focusable(self : WidgetOps[Msg]) -> Bool {
  (self.focusable_fn)()
}

///|
pub fn[Msg, NextMsg] WidgetOps::map(
  self : WidgetOps[Msg],
  map : (Msg) -> NextMsg,
) -> WidgetOps[NextMsg] {
  WidgetOps::new(
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
