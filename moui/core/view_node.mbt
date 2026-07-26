///|
/// Message-independent behavior for a low-level custom view node.
///
/// The trait is open so downstream packages can define renderer-neutral
/// controls. Typed children and messages are attached with `View::from_node`.
/// `identity` controls element reuse: equal identities preserve transient
/// runtime control state, while a changed kind or key remounts the element.
/// A non-empty `revision` enables clean/layout reconciliation, and a changed
/// non-empty `paint_revision` requests paint without invalidating layout.
/// Implementations should contain immutable declaration data; application
/// state belongs in the TEA model and transient interaction state belongs in
/// `ViewEventContext.state` / `ViewEventResult.state`.
pub(open) trait ViewNode {
  fn identity(Self) -> ViewIdentity
  fn revision(Self) -> String = _
  fn paint_revision(Self) -> String = _
  fn child_constraints(Self, Constraints) -> Constraints = _
  fn child_environment(Self, Environment) -> Environment = _
  fn child_style(Self, ViewStyle) -> ViewStyle = _
  fn layout(Self, ViewLayoutContext) -> ViewLayoutResult
  fn paint(Self, ViewPaintContext) -> ViewPaintPlan = _
  fn text_input_state(Self, ViewPaintContext) -> TextInputState? = _
  fn semantics(Self) -> ViewSemanticsInfo = _
  fn focusable(Self) -> Bool = _
  fn flex_weight(Self) -> Double = _
}

///|
impl ViewNode with fn revision(_self) {
  ""
}

///|
impl ViewNode with fn paint_revision(_self) {
  ""
}

///|
impl ViewNode with fn child_constraints(_self, constraints) {
  constraints.loosen()
}

///|
impl ViewNode with fn child_environment(_self, environment) {
  environment
}

///|
impl ViewNode with fn child_style(_self, style) {
  style
}

///|
impl ViewNode with fn paint(_self, _context) {
  ViewPaintPlan::empty()
}

///|
impl ViewNode with fn text_input_state(_self, _context) {
  None
}

///|
impl ViewNode with fn semantics(_self) {
  ViewSemanticsInfo::new()
}

///|
impl ViewNode with fn focusable(_self) {
  false
}

///|
impl ViewNode with fn flex_weight(_self) {
  0.0
}

///|
priv struct EmptyViewNode {}

///|
impl ViewNode for EmptyViewNode with fn identity(_self) {
  ViewIdentity::new(kind="Empty")
}

///|
impl ViewNode for EmptyViewNode with fn revision(_self) {
  "empty"
}

///|
impl ViewNode for EmptyViewNode with fn layout(_self, context) {
  ViewLayoutResult::new(
    size=context.constraints.constrain(Size::new(width=0.0, height=0.0)),
  )
}

///|
fn[Msg] empty_view() -> View[Msg] {
  View::from_node(EmptyViewNode::{  })
}

///|
priv struct ViewAdapter[Msg] {
  node : &ViewNode
  children_fn : () -> Array[View[Msg]]
  build_child_fn : ((ComponentContext) -> View[Msg])?
  event_fn : (ViewEventContext) -> ViewEventResult[Msg]
  text_command_fn : (ViewEventContext, CommandIntent, String?) -> ViewTextCommandResult[
    Msg,
  ]
}

///|
fn[Msg] ViewAdapter::new(
  node~ : &ViewNode,
  children~ : () -> Array[View[Msg]],
  build_child~ : ((ComponentContext) -> View[Msg])?,
  event~ : (ViewEventContext) -> ViewEventResult[Msg],
  text_command~ : (ViewEventContext, CommandIntent, String?) -> ViewTextCommandResult[
    Msg,
  ],
) -> ViewAdapter[Msg] {
  {
    node,
    children_fn: children,
    build_child_fn: build_child,
    event_fn: event,
    text_command_fn: text_command,
  }
}

///|
fn[Msg] ViewAdapter::children(self : ViewAdapter[Msg]) -> Array[View[Msg]] {
  (self.children_fn)()
}

///|
fn[Msg] ViewAdapter::build_child(
  self : ViewAdapter[Msg],
) -> ((ComponentContext) -> View[Msg])? {
  self.build_child_fn
}

///|
fn[Msg] ViewAdapter::event(
  self : ViewAdapter[Msg],
  context : ViewEventContext,
) -> ViewEventResult[Msg] {
  (self.event_fn)(context)
}

///|
fn[Msg] ViewAdapter::text_command_result(
  self : ViewAdapter[Msg],
  context : ViewEventContext,
  intent : CommandIntent,
  paste_text? : String? = None,
) -> ViewTextCommandResult[Msg] {
  (self.text_command_fn)(context, intent, paste_text)
}

///|
fn[Msg, NextMsg] ViewAdapter::map(
  self : ViewAdapter[Msg],
  map : (Msg) -> NextMsg,
) -> ViewAdapter[NextMsg] {
  ViewAdapter::new(
    node=self.node,
    children=() => self.children().map(child => child.map(map)),
    build_child=match self.build_child() {
      Some(build) => Some(ctx => build(ctx).map(map))
      None => None
    },
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
    text_command=(context, intent, paste_text) => {
      let result = self.text_command_result(context, intent, paste_text~)
      {
        result: result.result,
        text_control: result.text_control,
        messages: result.messages.map(message => map(message)),
      }
    },
  )
}
