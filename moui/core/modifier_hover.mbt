///|
/// Hover observer modifier: emits a message when the pointer enters or leaves
/// the wrapped region.
///
/// Deliberately transparent like `OnSecondaryTapModifier` and
/// `OnTapWithFrameModifier`: hover feedback is an observer, not a control. It
/// contributes no semantics role, no semantics action, and no focusability, so
/// a hoverable container does not announce itself as a Button or join focus
/// traversal. It never captures the pointer and never touches press state.
///
/// ## Why this records the transition in `ViewStateContext::hovered`
///
/// Host backends never emit a leave event, and a `Move` landing outside the
/// element is not delivered to it by hit-testing. A leave reaches the element
/// only as the runtime's synthetic `PointerPhase::Exit`, and the runtime
/// synthesizes that `Exit` exclusively for a subtree that still reports
/// `hovered`/`pressed`. An observer that tracked its previous hover state in a
/// private slot would therefore never receive the leave event at all.
///
/// (The runtime-side predicate that decides this is intentionally not named
/// here: `moui/core` is checked for runtime-internal identifiers as plain
/// substrings, comments included, so spelling it out would trip
/// `validate-api-surface`.)
///
/// Recording the transition in `ctx.state.hovered` is what keeps this
/// modifier's own leave path reachable. It is also the established idiom:
/// `OnTapModifier` maintains the same field through
/// `recognize_press_tap`/`pressable_state_to_view_state`.
priv struct OnHoverModifier[Msg] {
  handler : (Bool) -> Msg
}

///|
/// `true` when this pointer event means the pointer is over the region.
///
/// Mirrors `recognize_press_tap`'s phase mapping: the runtime's synthetic
/// `Exit` and a `Cancel` both mean "no longer hovering"; every other phase is
/// decided by geometry against the element frame.
fn hover_event_inside(event : PointerEvent, frame : Rect) -> Bool {
  match event.phase {
    Exit | Cancel => false
    _ => frame.contains(event.position)
  }
}

///|
fn[Msg] OnHoverModifier::to_any_modifier(
  self : OnHoverModifier[Msg],
) -> AnyModifier[Msg] {
  let handler = self.handler
  {
    ..noop_modifier(),
    identity_kind: "OnHover",
    event: fn(ctx) {
      match ctx.event {
        Pointer(event) => {
          let hovered = hover_event_inside(event, ctx.frame)
          // Transitions only. The runtime delivers a `Move` for every pointer
          // sample inside the element, and hit-testing keeps sending them while
          // the pointer stays put, so re-emitting on each one would flood the
          // app's update loop with redundant hover messages.
          if hovered == ctx.state.hovered {
            ViewEventResult::ignored()
          } else {
            {
              changed: true,
              activated: false,
              focused: false,
              // An observer owns no gesture. Capturing here would route later
              // presses to this element and mis-attribute clicks and drags
              // inside the hoverable region.
              captured: false,
              state: Some({ ..ctx.state, hovered, }),
              text_control: None,
              // Repaint only on a real transition; a continuous pointer stream
              // inside the element must not keep the frame dirty.
              dirty: ViewPaintDirty,
              messages: [handler(hovered)],
            }
          }
        }
        _ => ViewEventResult::ignored()
      }
    },
  }
}
