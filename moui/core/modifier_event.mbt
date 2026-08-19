///|
/// Event modifiers: OnTap, OnSecondaryTap, OnLongPress, OnDoubleTap, OnDrag,
/// OnDragWithFrame, OnFileDrop, KeyboardShortcut.

///|
pub(all) struct OnTapModifier[Msg] {
  message : Msg
}

///|
/// Secondary mouse-button activation. Native desktop backends normalize the
/// context-menu button to `button == 1`; primary taps continue to use 0.
priv struct OnSecondaryTapModifier[Msg] {
  message : Msg
}

///|
fn[Msg] OnSecondaryTapModifier::to_any_modifier(
  self : OnSecondaryTapModifier[Msg],
) -> AnyModifier[Msg] {
  let message = self.message
  {
    ..noop_modifier(),
    identity_kind: "OnSecondaryTap",
    focusable: true,
    semantics: ViewSemanticsInfo::new(role=SemanticsRole::Button),
    event: fn(ctx) {
      match ctx.event {
        Pointer(event) if event.button == 1 => {
          let inside = ctx.frame.contains(event.position)
          let current = view_state_to_pressable_state(ctx.state)
          let tap = recognize_press_tap(current, inside, event.phase)
          let next_state = pressable_state_to_view_state(
            ctx.state,
            tap.next_state,
          )
          let changed = next_state != ctx.state || tap.activated
          {
            changed,
            activated: tap.activated,
            focused: false,
            captured: inside || current == PressableState::Pressed,
            state: Some(next_state),
            text_control: None,
            dirty: if changed {
              ViewDirtyHint::ViewPaintDirty
            } else {
              ViewDirtyHint::ViewClean
            },
            messages: if tap.activated {
              [message]
            } else {
              []
            },
          }
        }
        _ => ViewEventResult::ignored()
      }
    },
  }
}

///|
pub fn[Msg] OnTapModifier::to_any_modifier(
  self : OnTapModifier[Msg],
) -> AnyModifier[Msg] {
  let message = self.message
  {
    ..noop_modifier(),
    identity_kind: "OnTap",
    focusable: true,
    semantics: ViewSemanticsInfo::new(role=SemanticsRole::Button),
    semantics_actions: [
      ViewSemanticsActionHandler::activate(_ctx => {
        ViewSemanticsActionResult::message(message)
      }),
    ],
    event: fn(ctx) {
      match ctx.event {
        Pointer(event) => {
          let inside = ctx.frame.contains(event.position)
          let current = view_state_to_pressable_state(ctx.state)
          let tap = recognize_press_tap(current, inside, event.phase)
          let next_state = pressable_state_to_view_state(
            ctx.state,
            tap.next_state,
          )
          let changed = next_state != ctx.state || tap.activated
          {
            changed,
            activated: tap.activated,
            focused: false,
            captured: inside || current == PressableState::Pressed,
            state: Some(next_state),
            text_control: None,
            dirty: if changed {
              ViewDirtyHint::ViewPaintDirty
            } else {
              ViewDirtyHint::ViewClean
            },
            messages: if tap.activated {
              [message]
            } else {
              []
            },
          }
        }
        Keyboard(event) =>
          if event.pressed && (event.key == "Enter" || event.key == " ") {
            ViewEventResult::message(message)
          } else {
            ViewEventResult::ignored()
          }
        _ => ViewEventResult::ignored()
      }
    },
  }
}

///|
pub(all) struct OnLongPressModifier[Msg] {
  message : Msg
}

///|
pub fn[Msg] OnLongPressModifier::to_any_modifier(
  self : OnLongPressModifier[Msg],
) -> AnyModifier[Msg] {
  let message = self.message
  {
    ..noop_modifier(),
    identity_kind: "OnLongPress",
    focusable: true,
    semantics: ViewSemanticsInfo::new(role=SemanticsRole::Button),
    event: fn(ctx) {
      match ctx.event {
        Pointer(event) => {
          let result = LongPressGestureState::new().update(
            event,
            inside=ctx.frame.contains(event.position),
          )
          if result.recognized {
            ViewEventResult::message(message)
          } else {
            {
              ..ViewEventResult::ignored(),
              changed: result.cancelled,
              captured: result.cancelled,
              dirty: if result.cancelled {
                ViewDirtyHint::ViewPaintDirty
              } else {
                ViewDirtyHint::ViewClean
              },
            }
          }
        }
        _ => ViewEventResult::ignored()
      }
    },
  }
}

///|
pub(all) struct OnDoubleTapModifier[Msg] {
  message : Msg
}

///|
pub fn[Msg] OnDoubleTapModifier::to_any_modifier(
  self : OnDoubleTapModifier[Msg],
) -> AnyModifier[Msg] {
  let message = self.message
  {
    ..noop_modifier(),
    identity_kind: "OnDoubleTap",
    focusable: true,
    semantics: ViewSemanticsInfo::new(role=SemanticsRole::Button),
    event: fn(ctx) {
      match ctx.event {
        Pointer(event) => {
          let result = DoubleTapGestureState::new().update(
            event,
            inside=ctx.frame.contains(event.position),
          )
          if result.recognized {
            ViewEventResult::message(message)
          } else {
            ViewEventResult::ignored()
          }
        }
        _ => ViewEventResult::ignored()
      }
    },
  }
}

///|
pub(all) struct OnDragModifier[Msg] {
  handler : (DragGestureEvent) -> Msg
}

///|
pub fn[Msg] OnDragModifier::to_any_modifier(
  self : OnDragModifier[Msg],
) -> AnyModifier[Msg] {
  let handler = self.handler
  {
    ..noop_modifier(),
    identity_kind: "OnDrag",
    semantics: ViewSemanticsInfo::new(role=SemanticsRole::Button),
    event: fn(ctx) {
      handle_drag_modifier_event(ctx, handler=fn(event, _frame) {
        handler(event)
      })
    },
  }
}

///|
pub(all) struct OnDragWithFrameModifier[Msg] {
  handler : (DragGestureEvent, Rect) -> Msg
}

///|
pub fn[Msg] OnDragWithFrameModifier::to_any_modifier(
  self : OnDragWithFrameModifier[Msg],
) -> AnyModifier[Msg] {
  let handler = self.handler
  {
    ..noop_modifier(),
    identity_kind: "OnDragWithFrame",
    semantics: ViewSemanticsInfo::new(role=SemanticsRole::Button),
    event: fn(ctx) { handle_drag_modifier_event(ctx, handler~) },
  }
}

///|
fn[Msg] handle_drag_modifier_event(
  ctx : ViewEventContext,
  handler~ : (DragGestureEvent, Rect) -> Msg,
) -> ViewEventResult[Msg] {
  match ctx.event {
    Pointer(event) => {
      let slot = drag_gesture_view_state_slot()
      let gesture = ctx.state.read_slot(slot)
      let result = gesture.update(
        event,
        inside=ctx.frame.contains(event.position),
      )
      let active = result.state.phase != DragGesturePhase::Idle
      let next_state = if active {
        ctx.state.with_slot(slot, result.state)
      } else {
        ctx.state.without_slot(slot)
      }
      match result.event {
        Some(drag_event) => {
          let frame = match ctx.child_frames {
            [cf, ..] => cf
            [] => ctx.frame
          }
          {
            changed: true,
            activated: true,
            focused: false,
            captured: true,
            state: Some(next_state),
            text_control: None,
            dirty: ViewDirtyHint::ViewPaintDirty,
            messages: [handler(drag_event, frame)],
          }
        }
        None =>
          if active {
            {
              changed: next_state != ctx.state,
              activated: false,
              focused: false,
              captured: true,
              state: Some(next_state),
              text_control: None,
              dirty: if next_state != ctx.state {
                ViewDirtyHint::ViewPaintDirty
              } else {
                ViewDirtyHint::ViewClean
              },
              messages: [],
            }
          } else {
            // Terminal pointer phases must commit the reset even when the
            // gesture did not cross the drag slop.  In particular, a simple
            // click leaves the recognizer in `Pending`; returning `ignored`
            // here would preserve that slot forever and the next Move could
            // be interpreted as a drag from the old click.
            {
              // State is still committed, but terminal cleanup is transparent
              // to parent tap modifiers so they can observe the same Up.
              changed: false,
              activated: false,
              focused: false,
              captured: false,
              state: Some(next_state),
              text_control: None,
              dirty: if next_state != ctx.state {
                ViewDirtyHint::ViewPaintDirty
              } else {
                ViewDirtyHint::ViewClean
              },
              messages: [],
            }
          }
      }
    }
    _ => ViewEventResult::ignored()
  }
}

///|
pub(all) struct OnFileDropModifier[Msg] {
  handler : (Array[String], Point) -> Msg
}

///|
pub fn[Msg] OnFileDropModifier::to_any_modifier(
  self : OnFileDropModifier[Msg],
) -> AnyModifier[Msg] {
  let handler = self.handler
  {
    ..noop_modifier(),
    identity_kind: "OnFileDrop",
    event: fn(ctx) {
      match ctx.event {
        DragDrop(event) =>
          match (event.phase, event.position) {
            (Dropped, Some(position)) =>
              if ctx.frame.contains(position) && event.paths.length() > 0 {
                {
                  changed: true,
                  activated: true,
                  focused: false,
                  captured: true,
                  state: None,
                  text_control: None,
                  dirty: ViewDirtyHint::ViewPaintDirty,
                  messages: [handler(event.paths, position)],
                }
              } else {
                ViewEventResult::ignored()
              }
            _ => ViewEventResult::ignored()
          }
        _ => ViewEventResult::ignored()
      }
    },
  }
}

///|
pub(all) struct KeyboardShortcutModifier {
  shortcut : KeyboardShortcut
}

///|
pub fn[Msg] KeyboardShortcutModifier::to_any_modifier(
  self : KeyboardShortcutModifier,
) -> AnyModifier[Msg] {
  let shortcut = self.shortcut
  {
    ..noop_modifier(),
    identity_kind: "KeyboardShortcut",
    focusable: true,
    semantics: ViewSemanticsInfo::new(role=SemanticsRole::Button),
    event: fn(ctx) { handle_keyboard_shortcut_modifier(shortcut, ctx) },
  }
}

///|
fn[Msg] handle_keyboard_shortcut_modifier(
  shortcut : KeyboardShortcut,
  ctx : ViewEventContext,
) -> ViewEventResult[Msg] {
  match ctx.event {
    Keyboard(event) =>
      if shortcut.matches(event) {
        { ..ViewEventResult::ignored(), activated: true, captured: true }
      } else {
        ViewEventResult::ignored()
      }
    _ => ViewEventResult::ignored()
  }
}
