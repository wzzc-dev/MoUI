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
priv struct RuntimeSemanticsActionOutcome {
  accepted : Bool
  state : @core.ViewStateContext?
  text_control : @core.TextControlStateContext?
  dirty : @core.ViewDirtyHint
  deliveries : Array[() -> Unit]
  deferred_commits : Array[() -> Unit]
}

///|
priv trait RuntimeViewNode {
  fn identity(Self) -> @core.ViewIdentity
  fn declaration(Self) -> @core.ViewDeclaration
  fn children(Self) -> Array[&RuntimeViewNode]
  fn child_constraints(Self, Constraints) -> Constraints
  fn child_environment(Self, Environment) -> Environment
  fn child_style(Self, ViewStyle) -> ViewStyle
  fn layout(Self, @core.ViewLayoutContext) -> @core.ViewLayoutResult
  fn paint(Self, @core.ViewPaintContext) -> @core.ViewPaintPlan
  fn platform_views(Self, @core.ViewPlatformContext) -> Array[
    PlatformViewPlacement,
  ]
  fn event(Self, @core.ViewEventContext) -> RuntimeEventOutcome
  fn text_input_state(Self, @core.ViewPaintContext) -> TextInputState?
  fn text_command(Self, @core.ViewEventContext, CommandIntent, String?) -> RuntimeTextCommandOutcome
  fn semantics(Self) -> @core.ViewSemanticsInfo
  fn semantics_action_kinds(Self) -> Array[@core.SemanticsActionKind]
  fn semantics_action(
    Self,
    @core.ViewSemanticsActionContext,
    @core.SemanticsAction,
  ) -> RuntimeSemanticsActionOutcome
  fn focusable(Self) -> Bool
  fn focus_trap(Self) -> Bool
  fn flex_weight(Self) -> Double
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
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn declaration(self) {
  self.view.declaration()
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn children(self) {
  self.view.children().map(child => runtime_view_node(child, self.emit))
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
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn platform_views(
  self,
  context,
) {
  self.view.platform_views(context)
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
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn semantics_action_kinds(
  self,
) {
  self.view.semantics_action_kinds()
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn semantics_action(
  self,
  context,
  action,
) {
  let result = self.view.dispatch_semantics_action(context, action)
  {
    accepted: result.accepted,
    state: result.state,
    text_control: result.text_control,
    dirty: result.dirty,
    deliveries: result.messages.map(message => () => (self.emit)(message)),
    deferred_commits: result.deferred_commits,
  }
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn focusable(self) {
  self.view.accepts_focus()
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn focus_trap(self) {
  self.view.traps_focus()
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn flex_weight(self) {
  self.view.flex_weight()
}

///|
fn RuntimeState::deliver_messages(
  self : RuntimeState,
  deliveries : Array[() -> Unit],
) -> Unit {
  (self.begin_message_batch)()
  for deliver in deliveries {
    deliver()
  }
  (self.end_message_batch)()
  // `end_message_batch` drains synchronous TEA messages. Reconcile only
  // after that drain so immutable view snapshots observe the updated model.
  self.rebuild_if_possible()
}

///|
priv struct EmptyCoreViewNode {}

///|
impl @core.ViewNode for EmptyCoreViewNode with fn identity(_self) {
  @core.ViewIdentity::new(kind="Empty")
}

///|
impl @core.ViewNode for EmptyCoreViewNode with fn declaration(_self) {
  @core.ViewDeclaration::constant()
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
