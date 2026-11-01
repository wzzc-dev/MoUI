///|
/// Shared pressable transition state: which visual state a control is
/// animating away from, and when the transition started. Paints inside the
/// motion window blend from that state to the control's current visual state.
/// Stored in a per-control view-state slot, which the reconciler preserves
/// while element identity is reused, so new controls adopt transitions without
/// re-implementing `ViewStateValue` encode/decode boilerplate.
pub(all) enum PressableTransition {
  Idle
  Active(@core.PressableState, Double)
} derive(Eq, Debug)

///|
pub extend PressableTransition with Debug::{to_repr}

///|
pub extend PressableTransition with Eq::{not_equal, equal}

///|
impl @core.ViewStateValue for PressableTransition with fn view_state_type_key() {
  @core.DeclarationKey::string("moui.views.PressableTransition.v1")
}

///|
impl @core.ViewStateValue for PressableTransition with fn encode_view_state(
  self,
) {
  match self {
    Idle => b"\x00"
    Active(from_state, start_ms) => {
      let output = Buffer(size_hint=10)
      output.write_byte(1)
      output.write_byte(
        match from_state {
          Normal => 0
          Hovered => 1
          Pressed => 2
        },
      )
      output.write_double_be(start_ms)
      output.to_bytes()
    }
  }
}

///|
impl @core.ViewStateValue for PressableTransition with fn decode_view_state(
  _self,
  bytes,
) {
  if bytes == b"\x00" {
    Some(Idle)
  } else if bytes.length() == 10 && bytes[0] == 1 {
    let from_state = match bytes[1] {
      0 => Some(@core.PressableState::Normal)
      1 => Some(Hovered)
      2 => Some(Pressed)
      _ => None
    }
    let start_ms = @core.ViewStateValue::decode_view_state(
      0.0,
      bytes[2:10].to_owned(),
    )
    match (from_state, start_ms) {
      (Some(from_state), Some(start_ms)) => Some(Active(from_state, start_ms))
      _ => None
    }
  } else {
    None
  }
}

///|
/// The view-state slot holding one control's pressable transition. `control`
/// is the control's kind string (e.g. `"button"`), so each control owns an
/// independent transition slot under a stable, namespaced key.
pub fn pressable_transition_slot(
  control : String,
) -> @core.ViewStateSlot[PressableTransition] {
  @core.ViewStateSlot::new(
    key=@core.DeclarationKey::string("moui.views.\{control}.transition"),
    initial=Idle,
  )
}

///|
/// Read the transition currently recorded for `control`: `Some` of the state
/// being animated away from and the transition start time, or `None` when the
/// control is at rest.
pub fn pressable_transition(
  state : @core.ViewStateContext,
  control~ : String,
) -> (@core.PressableState, Double)? {
  match state.read_slot(pressable_transition_slot(control)) {
    Active(from_state, start_ms) => Some((from_state, start_ms))
    Idle => None
  }
}

///|
/// Advance a pressable control's interaction state and record a transition
/// start when the visual state actually changes. The returned proposal carries
/// the pressed/hovered flags implied by `next`; when `from_state` equals
/// `next` (no visual change) no transition is recorded. Wraps `with_slot` so
/// callers outside common/ do not need the `ViewStateValue` impl to be
/// visible.
pub fn pressable_state_with_transition(
  state : @core.ViewStateContext,
  from_state : @core.PressableState,
  next : @core.PressableState,
  now_ms : Double,
  control~ : String,
) -> @core.ViewStateContext {
  let interaction_state = {
    ..state,
    hovered: next == Hovered,
    pressed: next == Pressed,
  }
  if from_state == next {
    interaction_state
  } else {
    interaction_state.with_slot(
      pressable_transition_slot(control),
      Active(from_state, now_ms),
    )
  }
}

///|
/// Pure pressable state machine: the next visual state for a pressable
/// control given the current state, whether the pointer is inside the
/// control's frame, and the pointer phase.
pub fn pressable_next_state(
  current : @core.PressableState,
  inside : Bool,
  phase : @core.PointerPhase,
) -> @core.PressableState {
  match phase {
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
    // Synthetic runtime phase: the pointer left the element. Drop any hover or
    // press state and return to rest. (`inside` is always false for an `Exit`,
    // but the branch is unconditional so the intent is explicit.)
    Exit | Cancel => Normal
  }
}

///|
/// Resolve the solid background color for a pressable state by reading the
/// brush's fallback color. All built-in pressable styles use `Brush::solid`,
/// so this is exact for them; gradient brushes degrade to their start color.
pub fn pressable_state_color(brush : @core.Brush) -> @core.Color {
  brush.fallback_color()
}

///|
/// Map a pressable visual state to its background brush.
pub fn pressable_state_brush(
  state : @core.PressableState,
  normal : @core.Brush,
  hovered : @core.Brush,
  pressed : @core.Brush,
) -> @core.Brush {
  match state {
    Normal => normal
    Hovered => hovered
    Pressed => pressed
  }
}
