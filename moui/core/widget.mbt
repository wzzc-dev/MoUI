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
  environment : Environment
  text_system : TextSystem
}

///|
pub(all) struct WidgetPaintPlan {
  commands : Array[DrawCommand]
  post_commands : Array[DrawCommand]
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
  dirty : WidgetDirtyHint
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
} derive(Eq, Debug)

///|
pub struct WidgetOps[Msg] {
  priv identity_fn : () -> WidgetIdentity
  priv revision_fn : () -> String
  priv children_fn : () -> Array[View[Msg]]
  priv child_constraints_fn : (Constraints) -> Constraints
  priv layout_fn : (WidgetLayoutContext) -> WidgetLayoutResult
  priv paint_fn : (WidgetPaintContext) -> WidgetPaintPlan
  priv event_fn : (WidgetEventContext) -> WidgetEventResult[Msg]
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
  { commands: [], post_commands: [], overlay_commands: [], platform_views: [] }
}

///|
pub fn WidgetPaintPlan::commands(
  commands : Array[DrawCommand],
) -> WidgetPaintPlan {
  { commands, post_commands: [], overlay_commands: [], platform_views: [] }
}

///|
pub fn[Msg] WidgetEventResult::ignored() -> WidgetEventResult[Msg] {
  {
    changed: false,
    activated: false,
    focused: false,
    captured: false,
    state: None,
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
    dirty: WidgetPaintDirty,
    messages: [message],
  }
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
  semantics? : () -> WidgetSemanticsInfo = () => WidgetSemanticsInfo::new(),
  focusable? : () -> Bool = () => false,
) -> WidgetOps[Msg] {
  {
    identity_fn: identity,
    revision_fn: revision,
    children_fn: children,
    child_constraints_fn: child_constraints,
    layout_fn: layout,
    paint_fn: paint,
    event_fn: event,
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
        dirty: result.dirty,
        messages: result.messages.map(message => map(message)),
      }
    },
    semantics=() => self.semantics(),
    focusable=() => self.focusable(),
  )
}
