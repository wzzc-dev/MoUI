///|
/// §4 multi-pointer evidence: capture and the frame-tick re-sample are keyed by
/// `PointerEvent.id`, while the single-owner concepts (hover, focus) stay with
/// the primary stream.
///
/// White-box on purpose: the assertions read `animfocus` and the element state
/// directly. Neither has a public accessor, and a test is not a reason to add
/// one.

///|
fn multi_pointer_phase_label(phase : @core.PointerPhase) -> String {
  match phase {
    Move => "move"
    Down => "down"
    Up => "up"
    Cancel => "cancel"
    Exit => "exit"
  }
}

///|
/// A 40x20 rect that records every pointer sample it receives as
/// `"<name>:<phase>:<id>"`, claims capture on `Down`, and mirrors the press into
/// its own view state so hover routing is observable.
fn multi_pointer_probe(
  name~ : String,
  log~ : Ref[Array[String]],
) -> @core.View[Unit] {
  runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind=name),
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=40.0, height=20.0)),
      )
    },
    paint=ctx => {
      @core.ViewPaintPlan::commands([FillRect(ctx.frame, @core.Color::blue())])
    },
    focusable=() => true,
    event=context => {
      match context.event {
        Pointer(event) => {
          log.val.push(
            "\{name}:\{multi_pointer_phase_label(event.phase)}:\{event.id}",
          )
          match event.phase {
            Down =>
              {
                ..@core.ViewEventResult::ignored(),
                changed: true,
                captured: true,
                dirty: ViewPaintDirty,
                state: Some({ ..context.state, hovered: true, pressed: true, }),
              }
            Move =>
              {
                ..@core.ViewEventResult::ignored(),
                changed: true,
                dirty: ViewPaintDirty,
                state: Some({ ..context.state, hovered: true, }),
              }
            _ =>
              {
                ..@core.ViewEventResult::ignored(),
                changed: true,
                dirty: ViewPaintDirty,
                state: Some({ ..context.state, hovered: false, pressed: false, }),
              }
          }
        }
        _ => @core.ViewEventResult::ignored()
      }
    },
  )
}

///|
/// Two probes stacked: `a` occupies y 0..20, `b` occupies y 20..40.
fn multi_pointer_tree(log~ : Ref[Array[String]]) -> @core.View[Unit] {
  runtime_wb_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="MultiPointerStack"),
    children=() => {
      [multi_pointer_probe(name="a", log~), multi_pointer_probe(name="b", log~)]
    },
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width=40.0, height=40.0)),
        child_frames=[
          @core.Rect::new(x=0.0, y=0.0, width=40.0, height=20.0),
          @core.Rect::new(x=0.0, y=20.0, width=40.0, height=20.0),
        ],
      )
    },
  )
}

///|
fn multi_pointer_runtime(log~ : Ref[Array[String]]) -> RuntimeState {
  RuntimeState::new_view(
    root=multi_pointer_tree(log~),
    size=@core.Size::new(width=40.0, height=40.0),
  )
}

///|
fn multi_pointer_send(
  runtime : RuntimeState,
  id~ : Int32,
  x~ : Double,
  y~ : Double,
  phase~ : @core.PointerPhase,
) -> Unit {
  ignore(
    runtime.dispatch_pointer_event(
      @core.PointerEvent::new(position=@core.Point::new(x~, y~), phase~, id~),
    ),
  )
}

///|
fn multi_pointer_probe_element(
  runtime : RuntimeState,
  index : Int32,
) -> ElementNode {
  runtime.element_tree.root.children[index]
}

///|
test "runtime keeps pointer capture per stream" {
  let log : Ref[Array[String]] = Ref([])
  let runtime = multi_pointer_runtime(log~)
  multi_pointer_send(runtime, id=0, x=10.0, y=10.0, phase=Down)
  multi_pointer_send(runtime, id=1, x=10.0, y=30.0, phase=Down)
  let a = multi_pointer_probe_element(runtime, 0)
  let b = multi_pointer_probe_element(runtime, 1)
  assert_true(runtime.animfocus.pointer_captures.get(0) == Some(a.id))
  assert_true(runtime.animfocus.pointer_captures.get(1) == Some(b.id))
  assert_true(runtime.animfocus.pointer_presses.length() == 2)
  log.val.clear()
  // Finger 0 drags into `b`: its own capture keeps it on `a`, and `b` must not
  // see a second stream it never pressed.
  multi_pointer_send(runtime, id=0, x=10.0, y=30.0, phase=Move)
  assert_eq(log.val, ["a:move:0"])
  log.val.clear()
  // Releasing finger 1 must not release the gesture finger 0 is still dragging.
  multi_pointer_send(runtime, id=1, x=10.0, y=30.0, phase=Up)
  assert_eq(log.val, ["b:up:1"])
  assert_true(runtime.animfocus.pointer_captures.get(0) == Some(a.id))
  assert_false(runtime.animfocus.pointer_presses.contains(1))
  multi_pointer_send(runtime, id=0, x=10.0, y=30.0, phase=Up)
  assert_false(runtime.animfocus.pointer_captures.contains(0))
  assert_true(runtime.animfocus.pointer_presses.length() == 0)
}

///|
test "a secondary stream does not clear the primary hover" {
  let log : Ref[Array[String]] = Ref([])
  let runtime = multi_pointer_runtime(log~)
  multi_pointer_send(runtime, id=0, x=10.0, y=10.0, phase=Move)
  assert_true(
    multi_pointer_probe_element(runtime, 0).control.view_state.hovered,
  )
  log.val.clear()
  // A second finger moving over `b` synthesises no `Exit` into `a`: hover is
  // per element, not per pointer, so the other stream would cancel it.
  multi_pointer_send(runtime, id=1, x=10.0, y=30.0, phase=Move)
  assert_eq(log.val, ["b:move:1"])
  assert_true(
    multi_pointer_probe_element(runtime, 0).control.view_state.hovered,
  )
  log.val.clear()
  // The primary stream moving away still does clear it.
  multi_pointer_send(runtime, id=0, x=10.0, y=30.0, phase=Move)
  assert_eq(log.val, ["b:move:0", "a:exit:0"])
  assert_false(
    multi_pointer_probe_element(runtime, 0).control.view_state.hovered,
  )
}

///|
test "a secondary stream does not move focus" {
  let log : Ref[Array[String]] = Ref([])
  let runtime = multi_pointer_runtime(log~)
  multi_pointer_send(runtime, id=0, x=10.0, y=10.0, phase=Down)
  let a = multi_pointer_probe_element(runtime, 0)
  assert_true(runtime.animfocus.focused_element == Some(a.id))
  log.val.clear()
  multi_pointer_send(runtime, id=1, x=10.0, y=30.0, phase=Down)
  assert_eq(log.val, ["b:down:1"])
  assert_true(runtime.animfocus.focused_element == Some(a.id))
  assert_true(a.control.view_state.pressed)
}

///|
test "the frame tick re-samples every pressed stream" {
  let log : Ref[Array[String]] = Ref([])
  let runtime = multi_pointer_runtime(log~)
  multi_pointer_send(runtime, id=0, x=10.0, y=10.0, phase=Down)
  multi_pointer_send(runtime, id=1, x=10.0, y=30.0, phase=Down)
  multi_pointer_send(runtime, id=0, x=10.0, y=30.0, phase=Move)
  // A hold produces no host sample; the latch is what an animating subtree
  // leaves set, so it is declared instead of waited for.
  runtime.animfocus.active_animations = true
  log.val.clear()
  runtime.advance_time(16.0)
  // Each stream is re-emitted with its own id at its own pressed position, so
  // the primary sample still lands on the control it captured inside `b`.
  assert_eq(log.val, ["a:move:0", "b:move:1"])
}
