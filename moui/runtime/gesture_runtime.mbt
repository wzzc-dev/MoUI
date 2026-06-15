///|
priv struct TapGestureResult {
  next_state : ButtonState
  activated : Bool
}

///|
priv enum LongPressGesturePhase {
  Idle
  Pressing
  Recognized
  Cancelled
} derive(Eq)

///|
priv struct LongPressGestureState {
  phase : LongPressGesturePhase
  origin : Point?
  start_time_ms : Double
  duration_ms : Double
  max_movement : Double
}

///|
priv struct LongPressGestureResult {
  state : LongPressGestureState
  recognized : Bool
  cancelled : Bool
}

///|
priv struct DoubleTapGestureState {
  first_position : Point?
  first_time_ms : Double
  timeout_ms : Double
  max_distance : Double
}

///|
priv struct DoubleTapGestureResult {
  state : DoubleTapGestureState
  recognized : Bool
}

///|
priv struct DragGestureState {
  phase : DragGesturePhase
  origin : Point?
  last_position : Point?
  min_distance : Double
}

///|
priv struct DragGestureResult {
  state : DragGestureState
  event : DragGestureEvent?
}

///|
fn recognize_button_tap(
  current : ButtonState,
  inside : Bool,
  phase : PointerPhase,
) -> TapGestureResult {
  let next_state = match phase {
    Move =>
      if current == ButtonState::Pressed && inside {
        ButtonState::Pressed
      } else if inside {
        ButtonState::Hovered
      } else {
        ButtonState::Normal
      }
    Down => if inside { ButtonState::Pressed } else { ButtonState::Normal }
    Up => if inside { ButtonState::Hovered } else { ButtonState::Normal }
    Cancel => ButtonState::Normal
  }
  {
    next_state,
    activated: phase == Up && inside && current == ButtonState::Pressed,
  }
}

///|
fn LongPressGestureState::new(
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
fn LongPressGestureState::update(
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
fn DoubleTapGestureState::new(
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
fn DoubleTapGestureState::tap(
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
fn DoubleTapGestureState::update(
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
fn DragGestureState::new(min_distance? : Double = 3.0) -> DragGestureState {
  {
    phase: DragGesturePhase::Idle,
    origin: None,
    last_position: None,
    min_distance: max_double(0.0, min_distance),
  }
}

///|
fn DragGestureState::update(
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
            let drag_event = DragGestureEvent::{
              phase,
              start: origin,
              position: event.position,
              delta,
              translation,
            }
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
            Some(DragGestureEvent::{
              phase,
              start: origin,
              position: event.position,
              delta: point_delta(last, event.position),
              translation: point_delta(origin, event.position),
            })
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
            Some(DragGestureEvent::{
              phase: DragGesturePhase::Cancelled,
              start: origin,
              position: event.position,
              delta: point_delta(last, event.position),
              translation: point_delta(origin, event.position),
            })
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
