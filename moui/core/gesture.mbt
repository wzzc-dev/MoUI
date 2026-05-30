///|
pub(all) struct TapGestureResult {
  next_state : ButtonState
  activated : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) enum LongPressGesturePhase {
  Idle
  Pressing
  Recognized
  Cancelled
} derive(Eq, Debug, ToJson)

///|
pub(all) struct LongPressGestureState {
  phase : LongPressGesturePhase
  origin : Point?
  start_time_ms : Double
  duration_ms : Double
  max_movement : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct LongPressGestureResult {
  state : LongPressGestureState
  recognized : Bool
  cancelled : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DoubleTapGestureState {
  first_position : Point?
  first_time_ms : Double
  timeout_ms : Double
  max_distance : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DoubleTapGestureResult {
  state : DoubleTapGestureState
  recognized : Bool
} derive(Eq, Debug, ToJson)

///|
pub(all) enum DragGesturePhase {
  Idle
  Pending
  Started
  Changed
  Ended
  Cancelled
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DragGestureEvent {
  phase : DragGesturePhase
  start : Point
  position : Point
  delta : Point
  translation : Point
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DragGestureState {
  phase : DragGesturePhase
  origin : Point?
  last_position : Point?
  min_distance : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DragGestureResult {
  state : DragGestureState
  event : DragGestureEvent?
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
  group : String
  description : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct CommandBinding {
  command : ActionCommand
  handle : () -> Unit
}

///|
pub(all) struct ActionCommandMap {
  bindings : Array[CommandBinding]
}

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
pub fn LongPressGestureState::new(
  duration_ms? : Double = 500.0,
  max_movement? : Double = 8.0,
) -> LongPressGestureState {
  {
    phase: LongPressGesturePhase::Idle,
    origin: None,
    start_time_ms: 0.0,
    duration_ms: max_double(0.0, duration_ms),
    max_movement: max_double(0.0, max_movement),
  }
}

///|
pub fn LongPressGesturePhase::label(self : LongPressGesturePhase) -> String {
  match self {
    Idle => "Idle"
    Pressing => "Pressing"
    Recognized => "Recognized"
    Cancelled => "Cancelled"
  }
}

///|
pub fn LongPressGestureState::update(
  self : LongPressGestureState,
  event : PointerEvent,
  inside? : Bool = true,
) -> LongPressGestureResult {
  match event.phase {
    Down => {
      let next = {
        ..self,
        phase: if inside {
          LongPressGesturePhase::Pressing
        } else {
          LongPressGesturePhase::Idle
        },
        origin: if inside {
          Some(event.position)
        } else {
          None
        },
        start_time_ms: event.time_ms,
      }
      { state: next, recognized: false, cancelled: false }
    }
    Move =>
      match self.origin {
        Some(origin) => {
          let outside = !inside ||
            point_distance(origin, event.position) > self.max_movement
          let due = event.time_ms - self.start_time_ms >= self.duration_ms
          if outside {
            {
              state: { ..self, phase: LongPressGesturePhase::Cancelled },
              recognized: false,
              cancelled: true,
            }
          } else if self.phase == LongPressGesturePhase::Pressing && due {
            {
              state: { ..self, phase: LongPressGesturePhase::Recognized },
              recognized: true,
              cancelled: false,
            }
          } else {
            { state: self, recognized: false, cancelled: false }
          }
        }
        None => { state: self, recognized: false, cancelled: false }
      }
    Up | Cancel => {
      let cancelled = self.phase == LongPressGesturePhase::Pressing
      {
        state: LongPressGestureState::new(
          duration_ms=self.duration_ms,
          max_movement=self.max_movement,
        ),
        recognized: false,
        cancelled,
      }
    }
  }
}

///|
pub fn DoubleTapGestureState::new(
  timeout_ms? : Double = 300.0,
  max_distance? : Double = 18.0,
) -> DoubleTapGestureState {
  {
    first_position: None,
    first_time_ms: 0.0,
    timeout_ms: max_double(0.0, timeout_ms),
    max_distance: max_double(0.0, max_distance),
  }
}

///|
pub fn DoubleTapGestureState::tap(
  self : DoubleTapGestureState,
  position : Point,
  time_ms : Double,
) -> DoubleTapGestureResult {
  match self.first_position {
    Some(first) => {
      let close_enough = point_distance(first, position) <= self.max_distance
      let soon_enough = time_ms - self.first_time_ms <= self.timeout_ms
      if close_enough && soon_enough {
        {
          state: DoubleTapGestureState::new(
            timeout_ms=self.timeout_ms,
            max_distance=self.max_distance,
          ),
          recognized: true,
        }
      } else {
        {
          state: {
            ..self,
            first_position: Some(position),
            first_time_ms: time_ms,
          },
          recognized: false,
        }
      }
    }
    None =>
      {
        state: {
          ..self,
          first_position: Some(position),
          first_time_ms: time_ms,
        },
        recognized: false,
      }
  }
}

///|
pub fn DoubleTapGestureState::update(
  self : DoubleTapGestureState,
  event : PointerEvent,
  inside? : Bool = true,
) -> DoubleTapGestureResult {
  if inside && event.phase == PointerPhase::Up {
    self.tap(event.position, event.time_ms)
  } else {
    { state: self, recognized: false }
  }
}

///|
pub fn DragGestureEvent::new(
  phase~ : DragGesturePhase,
  start~ : Point,
  position~ : Point,
  delta~ : Point,
  translation~ : Point,
) -> DragGestureEvent {
  { phase, start, position, delta, translation }
}

///|
pub fn DragGesturePhase::label(self : DragGesturePhase) -> String {
  match self {
    Idle => "Idle"
    Pending => "Pending"
    Started => "Started"
    Changed => "Changed"
    Ended => "Ended"
    Cancelled => "Cancelled"
  }
}

///|
pub fn DragGestureState::new(min_distance? : Double = 3.0) -> DragGestureState {
  {
    phase: DragGesturePhase::Idle,
    origin: None,
    last_position: None,
    min_distance: max_double(0.0, min_distance),
  }
}

///|
pub fn DragGestureState::update(
  self : DragGestureState,
  event : PointerEvent,
  inside? : Bool = true,
) -> DragGestureResult {
  match event.phase {
    Down => {
      let next = if inside {
        {
          ..self,
          phase: DragGesturePhase::Pending,
          origin: Some(event.position),
          last_position: Some(event.position),
        }
      } else {
        DragGestureState::new(min_distance=self.min_distance)
      }
      { state: next, event: None }
    }
    Move =>
      match (self.origin, self.last_position) {
        (Some(origin), Some(last)) => {
          let translation = point_delta(origin, event.position)
          let delta = point_delta(last, event.position)
          let distance = point_distance(origin, event.position)
          if self.phase == DragGesturePhase::Pending &&
            distance < self.min_distance {
            {
              state: { ..self, last_position: Some(event.position) },
              event: None,
            }
          } else {
            let phase = if self.phase == DragGesturePhase::Pending {
              DragGesturePhase::Started
            } else {
              DragGesturePhase::Changed
            }
            let drag_event = DragGestureEvent::new(
              phase~,
              start=origin,
              position=event.position,
              delta~,
              translation~,
            )
            {
              state: { ..self, phase, last_position: Some(event.position) },
              event: Some(drag_event),
            }
          }
        }
        _ => { state: self, event: None }
      }
    Up =>
      match (self.origin, self.last_position) {
        (Some(origin), Some(last)) => {
          let phase = if self.phase == DragGesturePhase::Pending {
            DragGesturePhase::Cancelled
          } else {
            DragGesturePhase::Ended
          }
          let drag_event = if phase == DragGesturePhase::Ended {
            Some(
              DragGestureEvent::new(
                phase~,
                start=origin,
                position=event.position,
                delta=point_delta(last, event.position),
                translation=point_delta(origin, event.position),
              ),
            )
          } else {
            None
          }
          {
            state: DragGestureState::new(min_distance=self.min_distance),
            event: drag_event,
          }
        }
        _ =>
          {
            state: DragGestureState::new(min_distance=self.min_distance),
            event: None,
          }
      }
    Cancel => {
      let drag_event = match (self.origin, self.last_position) {
        (Some(origin), Some(last)) =>
          if self.phase == DragGesturePhase::Started ||
            self.phase == DragGesturePhase::Changed {
            Some(
              DragGestureEvent::new(
                phase=DragGesturePhase::Cancelled,
                start=origin,
                position=event.position,
                delta=point_delta(last, event.position),
                translation=point_delta(origin, event.position),
              ),
            )
          } else {
            None
          }
        _ => None
      }
      {
        state: DragGestureState::new(min_distance=self.min_distance),
        event: drag_event,
      }
    }
  }
}

///|
fn point_delta(from : Point, to : Point) -> Point {
  Point::new(x=to.x - from.x, y=to.y - from.y)
}

///|
fn point_distance(a : Point, b : Point) -> Double {
  let dx = a.x - b.x
  let dy = a.y - b.y
  (dx * dx + dy * dy).sqrt()
}

///|
pub fn GestureArenaMember::new(
  element_id~ : ElementId,
  kind~ : GestureKind,
  priority? : Int = 0,
) -> GestureArenaMember {
  { element_id, kind, priority, disposition: GestureArenaDisposition::Pending }
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
    Some(winner_member) =>
      for candidate in members {
        if candidate.element_id == winner_member.element_id &&
          candidate.kind == winner_member.kind {
          candidate.accept()
        } else {
          candidate.reject()
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
  group? : String = "",
  description? : String = "",
) -> ActionCommand {
  { intent, shortcut, label, enabled, group, description }
}

///|
pub fn ActionCommand::display_label(self : ActionCommand) -> String {
  if self.label != "" {
    self.label
  } else {
    self.intent.display_label()
  }
}

///|
pub fn ActionCommand::shortcut_label(self : ActionCommand) -> String {
  match self.shortcut {
    Some(shortcut) => shortcut.display_label()
    None => ""
  }
}

///|
pub fn CommandIntent::display_label(self : CommandIntent) -> String {
  match self {
    Activate => "Activate"
    Submit => "Submit"
    Cancel => "Cancel"
    Copy => "Copy"
    Cut => "Cut"
    Paste => "Paste"
    Undo => "Undo"
    Redo => "Redo"
    SelectAll => "Select All"
    OpenContextMenu => "Open Context Menu"
  }
}

///|
pub fn KeyboardShortcut::display_label(self : KeyboardShortcut) -> String {
  let parts : Array[String] = []
  if self.modifiers.control {
    parts.push("Ctrl")
  }
  if self.modifiers.alt {
    parts.push("Alt")
  }
  if self.modifiers.shift {
    parts.push("Shift")
  }
  if self.modifiers.meta {
    parts.push("Meta")
  }
  parts.push(keyboard_shortcut_key_label(self.key))
  parts.join("+")
}

///|
fn keyboard_shortcut_key_label(key : String) -> String {
  match key {
    " " => "Space"
    "Escape" => "Esc"
    "ArrowLeft" => "Left"
    "ArrowRight" => "Right"
    "ArrowUp" => "Up"
    "ArrowDown" => "Down"
    _ => key
  }
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
pub fn CommandBinding::new(
  command~ : ActionCommand,
  handle~ : () -> Unit,
) -> CommandBinding {
  { command, handle }
}

///|
pub fn ActionCommandMap::new(
  bindings? : Array[CommandBinding] = [],
) -> ActionCommandMap {
  { bindings, }
}

///|
pub fn ActionCommandMap::commands(
  self : ActionCommandMap,
) -> Array[ActionCommand] {
  self.bindings.map(binding => binding.command)
}

///|
pub fn ActionCommandMap::find_shortcut(
  self : ActionCommandMap,
  event : KeyboardEvent,
) -> ActionCommand? {
  for binding in self.bindings {
    if binding.command.matches(event) {
      return Some(binding.command)
    }
  }
  None
}

///|
pub fn ActionCommandMap::dispatch_shortcut(
  self : ActionCommandMap,
  event : KeyboardEvent,
) -> CommandIntent? {
  for binding in self.bindings {
    if binding.command.matches(event) {
      (binding.handle)()
      return Some(binding.command.intent)
    }
  }
  None
}

///|
pub fn ActionCommandMap::dispatch_intent(
  self : ActionCommandMap,
  intent : CommandIntent,
) -> Bool {
  for binding in self.bindings {
    if binding.command.enabled && binding.command.intent == intent {
      (binding.handle)()
      return true
    }
  }
  false
}

///|
pub fn default_text_commands() -> Array[ActionCommand] {
  [
    ActionCommand::new(
      intent=CommandIntent::Copy,
      label="Copy",
      group="Edit",
      description="Copy the current selection.",
      shortcut=Some(
        KeyboardShortcut::new(key="c", modifiers=KeyModifiers::new(meta=true)),
      ),
    ),
    ActionCommand::new(
      intent=CommandIntent::Cut,
      label="Cut",
      group="Edit",
      description="Cut the current selection.",
      shortcut=Some(
        KeyboardShortcut::new(key="x", modifiers=KeyModifiers::new(meta=true)),
      ),
    ),
    ActionCommand::new(
      intent=CommandIntent::Paste,
      label="Paste",
      group="Edit",
      description="Paste clipboard text.",
      shortcut=Some(
        KeyboardShortcut::new(key="v", modifiers=KeyModifiers::new(meta=true)),
      ),
    ),
    ActionCommand::new(
      intent=CommandIntent::Undo,
      label="Undo",
      group="Edit",
      description="Undo the last text edit.",
      shortcut=Some(
        KeyboardShortcut::new(key="z", modifiers=KeyModifiers::new(meta=true)),
      ),
    ),
    ActionCommand::new(
      intent=CommandIntent::Redo,
      label="Redo",
      group="Edit",
      description="Redo the last undone text edit.",
      shortcut=Some(
        KeyboardShortcut::new(
          key="z",
          modifiers=KeyModifiers::new(shift=true, meta=true),
        ),
      ),
    ),
    ActionCommand::new(
      intent=CommandIntent::SelectAll,
      label="Select All",
      group="Edit",
      description="Select all text in the focused input.",
      shortcut=Some(
        KeyboardShortcut::new(key="a", modifiers=KeyModifiers::new(meta=true)),
      ),
    ),
  ]
}
