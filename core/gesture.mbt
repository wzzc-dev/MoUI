///|
pub(all) struct TapGestureResult {
  next_state : ButtonState
  activated : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HitTestEntry {
  element_id : ElementId
  local_position : Point
  frame : Rect
} derive(Eq, Debug, ToJson)

///|
pub(all) struct HitTestResult {
  path : Array[HitTestEntry]
} derive(Eq, Debug, ToJson)

///|
pub(all) enum GestureKind {
  Tap
  Drag
  LongPress
  PanZoom
  Wheel
  Hover
} derive(Eq, Debug, ToJson)

///|
pub(all) enum GestureArenaDisposition {
  Pending
  Accepted
  Rejected
} derive(Eq, Debug, ToJson)

///|
pub(all) struct GestureArenaMember {
  element_id : ElementId
  kind : GestureKind
  priority : Int
  mut disposition : GestureArenaDisposition
} derive(Eq, Debug, ToJson)

///|
pub(all) struct GestureArenaResult {
  winner : GestureArenaMember?
  members : Array[GestureArenaMember]
} derive(Eq, Debug, ToJson)

///|
pub(all) enum CommandIntent {
  Activate
  Submit
  Cancel
  Copy
  Cut
  Paste
  Undo
  Redo
  SelectAll
  OpenContextMenu
} derive(Eq, Debug, ToJson)

///|
pub(all) struct ActionCommand {
  intent : CommandIntent
  shortcut : KeyboardShortcut?
  label : String
  enabled : Bool
} derive(Eq, Debug, ToJson)

///|
pub fn recognize_button_tap(
  current : ButtonState,
  inside : Bool,
  phase : PointerPhase,
) -> TapGestureResult {
  let next_state = match phase {
    Move =>
      if current == Pressed && inside {
        Pressed
      } else if inside {
        Hovered
      } else {
        Normal
      }
    Down => if inside { Pressed } else { Normal }
    Up => if inside { Hovered } else { Normal }
    Cancel => Normal
  }
  { next_state, activated: phase == Up && inside && current == Pressed }
}

///|
pub fn GestureArenaMember::new(
  element_id~ : ElementId,
  kind~ : GestureKind,
  priority? : Int = 0,
) -> GestureArenaMember {
  {
    element_id,
    kind,
    priority,
    disposition: GestureArenaDisposition::Pending,
  }
}

///|
pub fn GestureArenaMember::accept(self : GestureArenaMember) -> Unit {
  self.disposition = GestureArenaDisposition::Accepted
}

///|
pub fn GestureArenaMember::reject(self : GestureArenaMember) -> Unit {
  self.disposition = GestureArenaDisposition::Rejected
}

///|
pub fn GestureArenaMember::is_pending(self : GestureArenaMember) -> Bool {
  self.disposition == GestureArenaDisposition::Pending
}

///|
pub fn resolve_gesture_arena(
  members : Array[GestureArenaMember],
) -> GestureArenaResult {
  let mut winner : GestureArenaMember? = None
  for candidate in members {
    if candidate.disposition != GestureArenaDisposition::Rejected {
      match winner {
        Some(current) =>
          if candidate.priority > current.priority {
            winner = Some(candidate)
          }
        None => winner = Some(candidate)
      }
    }
  }
  match winner {
    Some(winner_member) => {
      for candidate in members {
        if candidate.element_id == winner_member.element_id &&
          candidate.kind == winner_member.kind {
          candidate.accept()
        } else {
          candidate.reject()
        }
      }
    }
    None => ()
  }
  { winner, members }
}

///|
pub fn ActionCommand::new(
  intent~ : CommandIntent,
  label? : String = "",
  shortcut? : KeyboardShortcut? = None,
  enabled? : Bool = true,
) -> ActionCommand {
  { intent, shortcut, label, enabled }
}

///|
pub fn ActionCommand::matches(
  self : ActionCommand,
  event : KeyboardEvent,
) -> Bool {
  if !self.enabled {
    false
  } else {
    match self.shortcut {
      Some(shortcut) => shortcut.matches(event)
      None => false
    }
  }
}

///|
pub fn default_text_commands() -> Array[ActionCommand] {
  [
    ActionCommand::new(
      intent=CommandIntent::Copy,
      label="Copy",
      shortcut=Some(
        KeyboardShortcut::new(key="c", modifiers=KeyModifiers::new(meta=true)),
      ),
    ),
    ActionCommand::new(
      intent=CommandIntent::Paste,
      label="Paste",
      shortcut=Some(
        KeyboardShortcut::new(key="v", modifiers=KeyModifiers::new(meta=true)),
      ),
    ),
    ActionCommand::new(
      intent=CommandIntent::Undo,
      label="Undo",
      shortcut=Some(
        KeyboardShortcut::new(key="z", modifiers=KeyModifiers::new(meta=true)),
      ),
    ),
    ActionCommand::new(
      intent=CommandIntent::Redo,
      label="Redo",
      shortcut=Some(
        KeyboardShortcut::new(
          key="z",
          modifiers=KeyModifiers::new(shift=true, meta=true),
        ),
      ),
    ),
  ]
}
