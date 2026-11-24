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
  fn place_overlays(Self, @core.OverlayPlacementContext) -> Array[
    (Int32, @core.Rect),
  ]?
  fn paint(Self, @core.ViewPaintContext) -> @core.ViewPaintPlan
  fn platform_views(Self, @core.ViewPlatformContext) -> Array[
    PlatformViewPlacement,
  ]
  fn event(Self, @core.ViewEventContext) -> RuntimeEventOutcome
  fn text_input_state(Self, @core.ViewPaintContext) -> TextInputState?
  fn text_command(Self, @core.ViewEventContext, CommandIntent, String?) -> RuntimeTextCommandOutcome
  fn keyboard_policy(Self) -> @core.KeyboardPolicy
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
  /// Pointer shape this node declares; `Inherit` defers to an ancestor. Read
  /// live by the cursor resolver, never sampled into a snapshot.
  fn pointer_cursor(Self) -> @core.CursorStyle
}

///|
priv struct RuntimeViewAdapter[Msg] {
  view : @core.View[Msg]
  emit : (Msg) -> Unit
  /// F1: `View::identity()` is a construction-time snapshot (`from_node`
  /// samples it once), so a given adapter value's identity never changes.
  /// Reconcile reads it several times per node per pass (`have_same_identity`,
  /// the element key refresh, keyed-child lookups); cache it once here and
  /// serve every read from the field instead of re-dispatching through the
  /// core view.
  identity_snapshot : @core.ViewIdentity
  /// F1: memoized children wrappers. The adapter's view value is immutable,
  /// so the wrapped children are a pure function of the adapter; every
  /// `children()` call on the same adapter returns wrappers for the same
  /// child views and can share one computed array (copied on hand-out so a
  /// caller mutating the returned array cannot corrupt the memo).
  mut wrapped_children : Array[&RuntimeViewNode]?
  /// Host overlay layer slots (`AppRuntime::set_host_overlay`), set on the
  /// root adapter only. Every adapter the root builder produces shares one
  /// `HostOverlaySlot`, so the host layer can appear and disappear without
  /// changing the app root's identity — and therefore without remounting the
  /// app's subtree (`children()` reads the slot live, `layout()` appends the
  /// layer's frames).
  overlays : HostOverlaySlot?
}

///|
fn[Msg] runtime_view_node(
  view : @core.View[Msg],
  emit : (Msg) -> Unit,
) -> &RuntimeViewNode {
  adapt_view_for_runtime(view, emit)
}

///|
/// Root adapter variant that carries the host overlay layer. `overlays` is
/// `None` for every non-root adapter (they are ordinary runtime nodes).
fn[Msg] runtime_view_node_with_overlays(
  view : @core.View[Msg],
  emit : (Msg) -> Unit,
  overlays~ : HostOverlaySlot?,
) -> &RuntimeViewNode {
  let adapter : RuntimeViewAdapter[Msg] = {
    view,
    emit,
    identity_snapshot: view.identity(),
    wrapped_children: None,
    overlays,
  }
  adapter as &RuntimeViewNode
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn identity(self) {
  self.identity_snapshot
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn declaration(self) {
  self.view.declaration()
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn children(self) {
  // The memo lives on the adapter value itself, so it can only ever serve
  // wrappers for this adapter's own (immutable) view value — it cannot serve
  // a stale view across rebuilds, because each rebuild constructs fresh
  // adapters (`root_builder` re-runs `program.runtime_view`). Cross-rebuild
  // reuse keyed on identity alone is unsound: control declaration channels
  // key presence flags (e.g. `has_on_click`), not message payloads, so an
  // identity-equal view can carry a different model-captured event closure.
  let children = match self.wrapped_children {
    Some(wrapped) => wrapped.copy()
    None => {
      let wrapped : Array[&RuntimeViewNode] = []
      for child in self.view.children() {
        wrapped.push(runtime_view_node(child, self.emit))
      }
      self.wrapped_children = Some(wrapped)
      wrapped.copy()
    }
  }
  match self.overlays {
    Some(slot) =>
      // Read live: the slot is the one mutable piece of root structure, and
      // the host layer must mount/unmount without a new root adapter.
      for node in slot.nodes {
        children.push(node)
      }
    None => ()
  }
  children
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
  match self.overlays {
    Some(slot) =>
      if slot.nodes.length() == 0 {
        self.view.layout(context)
      } else {
        // The app's own children keep the sizes they were measured under; the
        // host layer is a surface-sized sibling appended after them, so the
        // placement pass places it at the origin and paints it last.
        let own = self.view.children().length()
        let surface = Size::new(
          width=context.constraints.max.width,
          height=context.constraints.max.height,
        )
        let result = self.view.layout({
          ..context,
          child_sizes: truncate_child_sizes(context.child_sizes, own),
          child_flex_weights: truncate_child_weights(
            context.child_flex_weights,
            own,
          ),
        })
        let frames = result.child_frames.copy()
        for _node in slot.nodes {
          frames.push(
            Rect::new(x=0.0, y=0.0, width=surface.width, height=surface.height),
          )
        }
        { ..result, child_frames: frames, }
      }
    None => self.view.layout(context)
  }
}

///|
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn place_overlays(
  self,
  context,
) {
  self.view.place_overlays(context)
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
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn keyboard_policy(
  self,
) {
  self.view.keyboard_policy()
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
impl[Msg] RuntimeViewNode for RuntimeViewAdapter[Msg] with fn pointer_cursor(
  self,
) {
  self.view.pointer_cursor()
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
  self.bump_overlay_input_generation()
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
  let view : @core.View[Unit] = @core.View::from_node(EmptyCoreViewNode::{ })
  runtime_view_node(view, _message => ())
}

///|
fn truncate_child_sizes(sizes : Array[Size], count : Int32) -> Array[Size] {
  let out : Array[Size] = []
  let mut index = 0
  while index < count && index < sizes.length() {
    out.push(sizes[index])
    index = index + 1
  }
  out
}

///|
fn truncate_child_weights(
  weights : Array[Double],
  count : Int32,
) -> Array[Double] {
  let out : Array[Double] = []
  let mut index = 0
  while index < count && index < weights.length() {
    out.push(weights[index])
    index = index + 1
  }
  out
}
