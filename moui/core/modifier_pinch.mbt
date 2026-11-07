///|
/// A two-finger pinch/rotation sample delivered by `View::on_pinch`.
///
/// The recognizer consumes the multi-pointer transport directly
/// (`PointerEvent.id`): it tracks the first two fingers that press inside the
/// view, and every movement of either finger produces one sample whose deltas
/// are measured since the previous sample — `scale_delta` is the span ratio
/// (1.0 = unchanged, > 1 = fingers apart) and `rotation_delta` is the angle
/// change in radians wrapped to (-π, π]. `focus` is the midpoint of the two
/// tracked pointers.
#derive(Eq, Debug, ToJson)
pub(all) struct PinchGestureEvent {
  phase : GesturePhase
  scale_delta : Double
  rotation_delta : Double
  focus : Point
}

///|
pub extend PinchGestureEvent with Debug::{to_repr}

///|
pub extend PinchGestureEvent with Eq::{not_equal, equal}

///|
pub extend PinchGestureEvent with ToJson::{to_json}

///|
/// Runtime-owned two-finger recognition state. The first two pointer ids
/// that press inside the view are tracked; further fingers are ignored until
/// the gesture ends. `span`/`angle` carry the last emitted geometry so each
/// sample measures the delta since the previous one.
#derive(Eq)
priv struct PinchRecognitionState {
  tracked : Int32
  pointer0_id : Int32
  pointer0 : Point
  pointer1_id : Int32
  pointer1 : Point
  span : Double
  angle : Double
}

///|
impl ViewStateValue for PinchRecognitionState with fn view_state_type_key() {
  DeclarationKey::string("moui.core.PinchRecognitionState.v1")
}

///|
impl ViewStateValue for PinchRecognitionState with fn encode_view_state(self) {
  let output = Buffer(size_hint=60)
  output.write_int_be(self.tracked)
  output.write_int_be(self.pointer0_id)
  output.write_double_be(self.pointer0.x)
  output.write_double_be(self.pointer0.y)
  output.write_int_be(self.pointer1_id)
  output.write_double_be(self.pointer1.x)
  output.write_double_be(self.pointer1.y)
  output.write_double_be(self.span)
  output.write_double_be(self.angle)
  output.to_bytes()
}

///|
impl ViewStateValue for PinchRecognitionState with fn decode_view_state(
  _self,
  bytes,
) {
  if bytes.length() != 60 {
    return None
  }
  let decode_int = fn(offset : Int32) -> Int32? {
    ViewStateValue::decode_view_state(0, bytes[offset:offset + 4].to_owned())
  }
  let decode_double = fn(offset : Int32) -> Double? {
    ViewStateValue::decode_view_state(0.0, bytes[offset:offset + 8].to_owned())
  }
  match
    (
      decode_int(0),
      decode_int(4),
      decode_double(8),
      decode_double(16),
      decode_int(24),
      decode_double(28),
      decode_double(36),
      decode_double(44),
      decode_double(52),
    ) {
    (
      Some(tracked),
      Some(pointer0_id),
      Some(p0x),
      Some(p0y),
      Some(pointer1_id),
      Some(p1x),
      Some(p1y),
      Some(span),
      Some(angle),
    ) =>
      Some({
        tracked,
        pointer0_id,
        pointer0: Point::new(x=p0x, y=p0y),
        pointer1_id,
        pointer1: Point::new(x=p1x, y=p1y),
        span,
        angle,
      })
    _ => None
  }
}

///|
fn pinch_recognition_state_slot() -> ViewStateSlot[PinchRecognitionState] {
  ViewStateSlot::new(
    key=DeclarationKey::string("moui.core.pinch-recognition"),
    initial={
      tracked: 0,
      pointer0_id: 0,
      pointer0: Point::new(x=0.0, y=0.0),
      pointer1_id: 0,
      pointer1: Point::new(x=0.0, y=0.0),
      span: 0.0,
      angle: 0.0,
    },
  )
}

///|
fn pinch_span(a : Point, b : Point) -> Double {
  let dx = b.x - a.x
  let dy = b.y - a.y
  (dx * dx + dy * dy).sqrt()
}

///|
fn pinch_angle(a : Point, b : Point) -> Double {
  @math.atan2(b.y - a.y, b.x - a.x)
}

///|
/// Wrap an angle difference into (-π, π] so a recognizer crossing the ±π
/// seam reports a small delta instead of a full turn.
fn pinch_wrap_angle(delta : Double) -> Double {
  let two_pi = 2.0 * @math.PI
  let mut wrapped = delta % two_pi
  if wrapped > @math.PI {
    wrapped = wrapped - two_pi
  }
  if wrapped <= 0.0 - @math.PI {
    wrapped = wrapped + two_pi
  }
  wrapped
}

///|
fn pinch_midpoint(a : Point, b : Point) -> Point {
  Point::new(x=(a.x + b.x) / 2.0, y=(a.y + b.y) / 2.0)
}

///|
/// One pointer event through the pinch recognizer. Returns the recognition
/// state to store and, when the state machine produces one, the gesture
/// sample to deliver.
fn[Msg] pinch_recognize(
  state : PinchRecognitionState,
  event : PointerEvent,
  inside~ : Bool,
  handler~ : (PinchGestureEvent) -> Msg,
) -> (PinchRecognitionState, Array[Msg]) {
  match event.phase {
    Down =>
      if !inside {
        (state, [])
      } else if state.tracked == 0 {
        (
          {
            ..state,
            tracked: 1,
            pointer0_id: event.id,
            pointer0: event.position,
          },
          [],
        )
      } else if state.tracked == 1 && event.id != state.pointer0_id {
        // The second finger arms the gesture: one Started sample with
        // identity deltas.
        let pointer1 = event.position
        let span = pinch_span(state.pointer0, pointer1)
        let angle = pinch_angle(state.pointer0, pointer1)
        (
          { ..state, tracked: 2, pointer1_id: event.id, pointer1, span, angle, },
          [
            handler({
              phase: Started,
              scale_delta: 1.0,
              rotation_delta: 0.0,
              focus: pinch_midpoint(state.pointer0, pointer1),
            }),
          ],
        )
      } else {
        // A third finger (or a duplicate stream) never joins the gesture.
        (state, [])
      }
    Move =>
      if state.tracked == 2 && event.id == state.pointer0_id {
        let pointer0 = event.position
        let span = pinch_span(pointer0, state.pointer1)
        let angle = pinch_angle(pointer0, state.pointer1)
        let scale_delta = if state.span > 0.0 { span / state.span } else { 1.0 }
        (
          { ..state, pointer0, span, angle, },
          [
            handler({
              phase: Moved,
              scale_delta,
              rotation_delta: pinch_wrap_angle(angle - state.angle),
              focus: pinch_midpoint(pointer0, state.pointer1),
            }),
          ],
        )
      } else if state.tracked == 2 && event.id == state.pointer1_id {
        let pointer1 = event.position
        let span = pinch_span(state.pointer0, pointer1)
        let angle = pinch_angle(state.pointer0, pointer1)
        let scale_delta = if state.span > 0.0 { span / state.span } else { 1.0 }
        (
          { ..state, pointer1, span, angle, },
          [
            handler({
              phase: Moved,
              scale_delta,
              rotation_delta: pinch_wrap_angle(angle - state.angle),
              focus: pinch_midpoint(state.pointer0, pointer1),
            }),
          ],
        )
      } else {
        (state, [])
      }
    Up =>
      if state.tracked == 2 &&
        (event.id == state.pointer0_id || event.id == state.pointer1_id) {
        // A finger lift ends the gesture with identity deltas focused on the
        // last midpoint; the state clears so the next pair starts fresh.
        (
          {
            tracked: 0,
            pointer0_id: 0,
            pointer0: Point::new(x=0.0, y=0.0),
            pointer1_id: 0,
            pointer1: Point::new(x=0.0, y=0.0),
            span: 0.0,
            angle: 0.0,
          },
          [
            handler({
              phase: Ended,
              scale_delta: 1.0,
              rotation_delta: 0.0,
              focus: pinch_midpoint(state.pointer0, state.pointer1),
            }),
          ],
        )
      } else if state.tracked == 1 && event.id == state.pointer0_id {
        // The lone finger lifted before a second ever joined: nothing armed.
        (
          {
            tracked: 0,
            pointer0_id: 0,
            pointer0: Point::new(x=0.0, y=0.0),
            pointer1_id: 0,
            pointer1: Point::new(x=0.0, y=0.0),
            span: 0.0,
            angle: 0.0,
          },
          [],
        )
      } else {
        (state, [])
      }
    // An explicit cancel or hover exit tears the recognition down silently:
    // no sample, no arithmetic, the next pair starts fresh.
    Cancel | Exit =>
      (
        {
          tracked: 0,
          pointer0_id: 0,
          pointer0: Point::new(x=0.0, y=0.0),
          pointer1_id: 0,
          pointer1: Point::new(x=0.0, y=0.0),
          span: 0.0,
          angle: 0.0,
        },
        [],
      )
  }
}

///|
priv struct OnPinchModifier[Msg] {
  handler : (PinchGestureEvent) -> Msg
}

///|
fn[Msg] OnPinchModifier::to_any_modifier(
  self : OnPinchModifier[Msg],
) -> AnyModifier[Msg] {
  let handler = self.handler
  {
    ..noop_modifier(),
    identity_kind: "OnPinch",
    event: fn(ctx) {
      match ctx.event {
        Pointer(event) if event.button == 0 => {
          let slot = pinch_recognition_state_slot()
          let state = ctx.state.read_slot(slot)
          let (next, samples) = pinch_recognize(
            state,
            event,
            inside=ctx.frame.contains(event.position),
            handler~,
          )
          let messages = samples
          if messages.is_empty() {
            // State-only changes (arming, clearing) still commit: the arena
            // arms candidates from slots_changed, and terminal cleanup must
            // not leave a stale pair behind.
            let changed = next != state
            {
              ..ViewEventResult::ignored(),
              changed,
              captured: state.tracked > 0 && next.tracked > 0,
              state: Some(
                if next.tracked == 0 && state.tracked > 0 {
                  ctx.state.without_slot(slot)
                } else {
                  ctx.state.with_slot(slot, next)
                },
              ),
              dirty: if changed {
                ViewPaintDirty
              } else {
                ViewClean
              },
            }
          } else {
            {
              ..ViewEventResult::ignored(),
              changed: true,
              activated: true,
              captured: true,
              state: Some(ctx.state.with_slot(slot, next)),
              dirty: ViewPaintDirty,
              messages,
            }
          }
        }
        _ => ViewEventResult::ignored()
      }
    },
  }
}
