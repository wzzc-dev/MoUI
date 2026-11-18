///|
/// Cursor declaration modifier: marks the region this view occupies with a
/// pointer shape.
///
/// Deliberately transparent like `OnHoverModifier` and `OnSecondaryTapModifier`:
/// it adds no semantics role, no semantics action, and no focus stop, and it
/// never captures the pointer or touches press state. A draggable splitter
/// gutter therefore stays a plain region that can also be clicked, hovered, or
/// scrolled; the cursor is a declaration the runtime resolves against the hit
/// chain, not a gesture.
///
/// ## Why the style is not per-event state
///
/// `on_hover` has to record its transition in `ctx.state.hovered` because the
/// runtime only synthesizes a leave `Exit` for a subtree that still reports
/// hover. A cursor needs none of that: the runtime resolves the chain under the
/// pointer on demand, so an unmount, an overlay, or a pointer that leaves the
/// window all resolve to the next declaration (or `Default`) without the
/// modifier observing anything. That also keeps pointer movement out of the
/// dirty/repart path: resolving a cursor never changes a view event result.
priv struct CursorModifier {
  style : CursorStyle
}

///|
fn[Msg] CursorModifier::to_any_modifier(
  self : CursorModifier,
) -> AnyModifier[Msg] {
  { ..noop_modifier(), identity_kind: "Cursor", pointer_cursor: self.style, }
}
