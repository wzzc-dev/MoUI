///|
/// Keyboard dispatch policy for a node.
///
/// `TopMostDismissal` marks an overlay host: it owns top-most-first dismissal
/// (Escape/Back) and receives keyboard events before its subtree, as
/// registered in the runtime layer stack. `ShortcutScope` marks a keyboard
/// shortcut wrapper whose own shortcut handling runs before children.
pub(all) enum KeyboardPolicy {
  Passthrough
  TopMostDismissal
  ShortcutScope
}

///|
/// Context for the post-layout overlay placement pass. Anchored overlay hosts
/// resolve their popup frames here — after base layout and anchor-registry
/// collection — instead of during layout, so anchoring never re-enters the
/// layout fixpoint nor keys layout caches.
pub(all) struct OverlayPlacementContext {
  viewport : Rect
  /// The host node's own placed frame. Base-sized hosts (control popups) use
  /// it as the default anchor for their popups.
  host_frame : Rect
  child_sizes : Array[Size]
  anchor_frames : Array[(String, Rect)]
  /// The host node's transient control state (e.g. `expanded` decides whether
  /// a control's popup participates in placement at all).
  state : ViewStateContext
}

///|
/// Message-independent behavior for a low-level custom view node.
///
/// The trait is open so downstream packages can define renderer-neutral
/// controls. Typed children and messages are attached with `View::from_node`.
/// `identity` controls element reuse: equal identities preserve transient
/// runtime control state, while a changed kind or key remounts the element.
/// `declaration` classifies immutable declaration data independently for
/// layout, paint, semantics, and platform work. Its conservative default marks
/// every channel uncacheable; performance-sensitive nodes opt into exact or
/// constant channels explicitly. Application state belongs in the TEA model
/// and transient interaction state belongs in runtime-owned element state
/// exposed through the typed adapters.
pub(open) trait ViewNode {
  fn identity(Self) -> ViewIdentity
  fn declaration(Self) -> ViewDeclaration = _
  fn child_constraints(Self, Constraints) -> Constraints = _
  fn child_environment(Self, Environment) -> Environment = _
  fn child_style(Self, ViewStyle) -> ViewStyle = _
  fn layout(Self, ViewLayoutContext) -> ViewLayoutResult
  /// Absolute frames for overlay-positioned children, indexed by child
  /// position. Layout positions these children provisionally (correct sizes,
  /// placeholder origins); the runtime re-places them at the returned frames
  /// after base layout. Returning `None` (the default) marks the node as
  /// having no overlay-positioned children.
  fn place_overlays(Self, OverlayPlacementContext) -> Array[(Int, Rect)]? = _
  fn paint(Self, ViewPaintContext) -> ViewPaintPlan = _
  fn platform_views(Self, ViewPlatformContext) -> Array[PlatformViewPlacement] = _
  fn text_input_state(Self, ViewPaintContext) -> TextInputState? = _
  fn semantics(Self) -> ViewSemanticsInfo = _
  fn focusable(Self) -> Bool = _
  fn focus_trap(Self) -> Bool = _
  fn keyboard_policy(Self) -> KeyboardPolicy = _
  fn flex_weight(Self) -> Double = _
}

// Future: when MoonBit supports blanket trait impls, decompose ViewNode into
// finer-grained traits: LayoutNode (identity, declaration, child_constraints,
// child_environment, child_style, layout, flex_weight), PaintNode (paint),
// SemanticsViewNode (semantics), FocusNode (focusable). This lets new controls
// implement only what they need. For now, all 14 methods live on ViewNode.

///|
impl ViewNode with fn declaration(_self) {
  ViewDeclaration::uncacheable()
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
impl ViewNode with fn place_overlays(_self, _context) {
  None
}

///|
impl ViewNode with fn paint(_self, _context) {
  ViewPaintPlan::empty()
}

///|
impl ViewNode with fn platform_views(_self, _context) {
  []
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
impl ViewNode with fn focus_trap(_self) {
  false
}

///|
impl ViewNode with fn keyboard_policy(_self) {
  KeyboardPolicy::Passthrough
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
impl ViewNode for EmptyViewNode with fn declaration(_self) {
  ViewDeclaration::constant()
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
  identity_snapshot : ViewIdentity
  declaration_snapshot : ViewDeclaration
  semantics_snapshot : ViewSemanticsInfo
  focusable_snapshot : Bool
  focus_trap_snapshot : Bool
  semantics_action_handlers : Array[ViewSemanticsActionHandler[Msg]]
  children_snapshot : Array[View[Msg]]
  event_fn : (ViewEventContext) -> ViewEventResult[Msg]
  text_command_fn : (ViewEventContext, CommandIntent, String?) -> ViewTextCommandResult[
    Msg,
  ]
}

///|
fn[Msg] ViewAdapter::new(
  node~ : &ViewNode,
  identity~ : ViewIdentity,
  declaration~ : ViewDeclaration,
  semantics~ : ViewSemanticsInfo,
  focusable~ : Bool,
  focus_trap~ : Bool,
  semantics_action_handlers~ : Array[ViewSemanticsActionHandler[Msg]],
  children~ : Array[View[Msg]],
  event~ : (ViewEventContext) -> ViewEventResult[Msg],
  text_command~ : (ViewEventContext, CommandIntent, String?) -> ViewTextCommandResult[
    Msg,
  ],
) -> ViewAdapter[Msg] {
  {
    node,
    identity_snapshot: identity,
    declaration_snapshot: declaration,
    semantics_snapshot: semantics,
    focusable_snapshot: focusable,
    focus_trap_snapshot: focus_trap,
    semantics_action_handlers: semantics_action_handlers.copy(),
    children_snapshot: children.copy(),
    event_fn: event,
    text_command_fn: text_command,
  }
}

///|
fn[Msg] ViewAdapter::children(self : ViewAdapter[Msg]) -> Array[View[Msg]] {
  self.children_snapshot.copy()
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
    identity=self.identity_snapshot,
    declaration=self.declaration_snapshot,
    semantics=self.semantics_snapshot,
    focusable=self.focusable_snapshot,
    focus_trap=self.focus_trap_snapshot,
    semantics_action_handlers=self.semantics_action_handlers.map(handler => {
      handler.map(map)
    }),
    children=self.children_snapshot.map(child => child.map(map)),
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

///|
fn[Msg] ViewAdapter::semantics_action_kinds(
  self : ViewAdapter[Msg],
) -> Array[SemanticsActionKind] {
  let kinds : Array[SemanticsActionKind] = []
  if self.focusable_snapshot {
    kinds.push(SemanticsActionKind::Focus)
  }
  for handler in self.semantics_action_handlers {
    if !kinds.contains(handler.kind()) {
      kinds.push(handler.kind())
    }
  }
  kinds
}

///|
fn[Msg] ViewAdapter::dispatch_semantics_action(
  self : ViewAdapter[Msg],
  context : ViewSemanticsActionContext,
  action : SemanticsAction,
) -> ViewSemanticsActionResult[Msg] {
  let kind = action.kind()
  for handler in self.semantics_action_handlers {
    if handler.kind() == kind {
      return handler.dispatch(context, action)
    }
  }
  ViewSemanticsActionResult::rejected()
}
