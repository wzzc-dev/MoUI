///|
priv struct RuntimeEventOutcome {
  changed : Bool
  activated : Bool
  focused : Bool
  captured : Bool
  state : @core.ViewStateContext?
  text_control : @core.TextControlStateContext?
  dirty : @core.ViewDirtyHint
  deliveries : Array[() -> Unit]
}

///|
priv struct RuntimeTextCommandOutcome {
  result : @core.TextCommandResult
  text_control : @core.TextControlStateContext?
  deliveries : Array[() -> Unit]
}

///|
priv trait RuntimeViewNode {
  fn identity(Self) -> @core.ViewIdentity
  fn revision(Self) -> String
  fn paint_revision(Self) -> String
  fn children(Self) -> Array[&RuntimeViewNode]
  fn build_child(Self, @core.ComponentContext) -> &RuntimeViewNode?
  fn child_constraints(Self, Constraints) -> Constraints
  fn child_environment(Self, Environment) -> Environment
  fn child_style(Self, ViewStyle) -> ViewStyle
  fn layout(Self, @core.ViewLayoutContext) -> @core.ViewLayoutResult
  fn paint(Self, @core.ViewPaintContext) -> @core.ViewPaintPlan
  fn event(Self, @core.ViewEventContext) -> RuntimeEventOutcome
  fn text_input_state(Self, @core.ViewPaintContext) -> TextInputState?
  fn text_command(Self, @core.ViewEventContext, CommandIntent, String?) -> RuntimeTextCommandOutcome
  fn semantics(Self) -> @core.ViewSemanticsInfo
  fn focusable(Self) -> Bool
  fn flex_weight(Self) -> Double
  fn has_build_child(Self) -> Bool
}

///|
priv struct RuntimeViewAdapter[Msg] {
  view : @core.View[Msg]
  emit : (Msg) -> Unit
}

///|
fn[Msg] runtime_view_node(
  view : @core.View[Msg],
  emit : (Msg) -> Unit,
) -> &RuntimeViewNode {
  RuntimeViewAdapter::{ view, emit } as &RuntimeViewNode
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn identity(self) {
  self.view.identity()
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn revision(self) {
  self.view.revision()
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn paint_revision(
  self,
) {
  self.view.paint_revision()
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn children(self) {
  self.view.children().map(child => runtime_view_node(child, self.emit))
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn build_child(
  self,
  context,
) {
  match self.view.build_child() {
    Some(build) => Some(runtime_view_node(build(context), self.emit))
    None => None
  }
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn child_constraints(
  self,
  constraints,
) {
  self.view.child_constraints(constraints)
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn child_environment(
  self,
  environment,
) {
  self.view.child_environment(environment)
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn child_style(
  self,
  style,
) {
  self.view.child_style(style)
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn layout(
  self,
  context,
) {
  self.view.layout(context)
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn paint(
  self,
  context,
) {
  self.view.paint(context)
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn event(
  self,
  context,
) {
  let result = self.view.event(context)
  {
    changed: result.changed,
    activated: result.activated,
    focused: result.focused,
    captured: result.captured,
    state: result.state,
    text_control: result.text_control,
    dirty: result.dirty,
    deliveries: result.messages.map(message => () => (self.emit)(message)),
  }
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn text_input_state(
  self,
  context,
) {
  self.view.text_input_state(context)
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn text_command(
  self,
  context,
  intent,
  paste_text,
) {
  let result = self.view.text_command_result(context, intent, paste_text~)
  {
    result: result.result,
    text_control: result.text_control,
    deliveries: result.messages.map(message => () => (self.emit)(message)),
  }
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn semantics(self) {
  self.view.semantics()
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn focusable(self) {
  self.view.accepts_focus()
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn flex_weight(self) {
  self.view.flex_weight()
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn has_build_child(
  self,
) {
  self.view.build_child() is Some(_)
}

///|
fn deliver_runtime_messages(deliveries : Array[() -> Unit]) -> Unit {
  for deliver in deliveries {
    deliver()
  }
}

///|
priv struct EmptyCoreViewNode {}

///|
impl @core.ViewNode for EmptyCoreViewNode with fn identity(_self) {
  @core.ViewIdentity::new(kind="Empty")
}

///|
impl @core.ViewNode for EmptyCoreViewNode with fn layout(_self, context) {
  @core.ViewLayoutResult::new(
    size=context.constraints.constrain(@core.Size::new(width=0.0, height=0.0)),
  )
}

///|
fn empty_runtime_view_node() -> &RuntimeViewNode {
  let view : @core.View[Unit] = @core.View::from_node(EmptyCoreViewNode::{  })
  runtime_view_node(view, _message => ())
}
