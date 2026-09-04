///|
priv enum EffectTaskSupersessionMsg {
  Tap
}

///|
/// Last-writer supersession of a live effect task keeps its cancel semantics,
/// but reusing a key for a different kind/label is a collision worth surfacing:
/// the runtime records it once per distinct shape in the program diagnostics
/// snapshot so apps can catch accidental key reuse without any behavior change.
test "runtime records effect task key supersession in diagnostics" {
  let cancelled : Array[String] = []
  let program = @core.Program::new(
    init=() => (0, @core.Effect::none()),
    update=(model, message) => {
      let (kind, label) = match (model, message) {
        // First and third taps use the same key with the same descriptor: the
        // second tap must cancel the first task, but no collision is recorded.
        (0, _) => ("sync", "")
        (1, _) => ("sync", "")
        (2, _) => ("fetch", "retry")
        (_, _) => ("sync", "")
      }
      (
        model + 1,
        @core.Effect::task(key="download", kind~, label~, start=_dispatch => {
          Some(() => cancelled.push(kind))
        }),
      )
    },
    view=_model => {
      runtime_test_rect(
        width=20.0,
        height=20.0,
        color=@core.Color::blue(),
        on_tap=Some(Tap),
      )
    },
  )
  let runtime = AppRuntime::new_program(
    program~,
    size=@core.Size::new(width=100.0, height=100.0),
  )
  let tap = () => {
    runtime.dispatch_event(
      @core.AppEvent::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=5.0, y=5.0),
          phase=@core.PointerPhase::Up,
        ),
      ),
    )
  }
  tap()
  let started = runtime.program_runtime_snapshot()
  inspect(started.started_effect_task_count(), content="1")
  inspect(started.active_effect_task_count(), content="1")
  inspect(started.superseded_effect_task_key_count(), content="0")
  tap()
  let restarted = runtime.program_runtime_snapshot()
  inspect(restarted.started_effect_task_count(), content="2")
  inspect(restarted.cancelled_effect_task_count(), content="1")
  // Supersession with the identical kind and label is the intended restart
  // pattern, so it stays silent.
  inspect(restarted.superseded_effect_task_key_count(), content="0")
  tap()
  let superseded = runtime.program_runtime_snapshot()
  inspect(superseded.started_effect_task_count(), content="3")
  inspect(superseded.cancelled_effect_task_count(), content="2")
  inspect(superseded.superseded_effect_task_key_count(), content="1")
  let records = superseded.superseded_effect_task_keys()
  if records.length() != 1 ||
    !records.any(record => record == "download (kind: sync -> fetch)") {
    fail("expected exactly one supersession record for the kind swap")
  }
  inspect(cancelled.length(), content="2")
  inspect(
    superseded
    .effect_task_lifecycle()
    .any(entry => {
      entry.status() == EffectTaskLifecycleStatus::EffectTaskCancelled &&
      entry.cancel_reason() ==
      Some(EffectTaskCancelReason::EffectTaskKindChanged)
    }),
    content="true",
  )
}
