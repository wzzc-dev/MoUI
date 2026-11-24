///|
/// A fixed-size, non-interactive box for drag geometry. `frame` is a
/// pass-through modifier, so the box and every wrapper above it share the
/// same screen frame.
fn drag_test_box(width : Double, height : Double) -> @core.View[String] {
  let box : @core.View[String] = @views.empty()
  box.frame(width~, height~)
}

///|
fn drag_test_payload(key : String) -> @core.DragPayload {
  @core.DragPayload::new(key~)
}

///|
fn drag_test_source(
  child : @core.View[String],
  key : String,
  min_distance~ : Double = 4.0,
) -> @core.View[String] {
  let payload = drag_test_payload(key)
  child.draggable(
    payload~,
    on_start=Some(fn(_payload, _position) { "source:started" }),
    on_move=Some(fn(_payload, _position) { "source:moved" }),
    on_end=Some(fn(end) {
      match end.target_key {
        Some(target) => "source:ended:\{target}"
        None => "source:ended:none"
      }
    }),
    min_distance~,
  )
}

///|
fn drag_test_target(
  child : @core.View[String],
  key : String,
  accepts~ : ((@core.DragPayload) -> Bool)? = None,
) -> @core.View[String] {
  child.drop_target(
    key~,
    on_enter=Some(fn(_payload, _position) { "target:entered:\{key}" }),
    on_move=Some(fn(_payload, _position) { "target:moved:\{key}" }),
    on_leave=Some(fn() { "target:left:\{key}" }),
    on_drop=Some(fn(_payload, _position) { "target:dropped:\{key}" }),
    accepts~,
  )
}

///|
fn drag_test_runtime(
  root : @core.View[String],
  received : Array[String],
  width~ : Double,
  height~ : Double,
) -> @runtime.AppRuntime {
  @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width~, height~),
    on_message=Some(message => received.push(message)),
  )
}

///|
fn drag_test_pointer(
  runtime : @runtime.AppRuntime,
  x : Double,
  y : Double,
  phase : @core.PointerPhase,
  button~ : Int32 = 0,
) -> Unit {
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x~, y~),
        phase~,
        button~,
      ),
    ),
  )
}

///|
test "view drag starts only after the source min_distance" {
  let received : Array[String] = []
  let root = @views.column(
    [drag_test_source(drag_test_box(100.0, 100.0), "item")],
    spacing=0.0,
  )
  let runtime = drag_test_runtime(root, received, width=200.0, height=200.0)
  ignore(runtime.layout())
  drag_test_pointer(runtime, 20.0, 20.0, Down)
  // 3 pt: below the 4 pt default.
  drag_test_pointer(runtime, 23.0, 20.0, Move)
  assert_true(received.is_empty())
  // 5 pt: the same sample starts the session; it is a `Started`, not a `Moved`.
  drag_test_pointer(runtime, 25.0, 20.0, Move)
  assert_eq(received, ["source:started"])
  drag_test_pointer(runtime, 26.0, 20.0, Move)
  assert_eq(received, ["source:started", "source:moved"])
  drag_test_pointer(runtime, 26.0, 20.0, Up)
  assert_eq(received, ["source:started", "source:moved", "source:ended:none"])
}

///|
test "view drag keeps delivering Moved outside the source frame" {
  let received : Array[String] = []
  let root = @views.column(
    [drag_test_source(drag_test_box(100.0, 100.0), "item")],
    spacing=0.0,
  )
  let runtime = drag_test_runtime(root, received, width=200.0, height=200.0)
  ignore(runtime.layout())
  drag_test_pointer(runtime, 90.0, 90.0, Down)
  drag_test_pointer(runtime, 95.0, 95.0, Move)
  assert_eq(received, ["source:started"])
  // The pointer is now outside the source's own 100x100 frame.
  drag_test_pointer(runtime, 180.0, 180.0, Move)
  assert_eq(received, ["source:started", "source:moved"])
  // A host pointer-stream cancel terminates the session with no target.
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x=180.0, y=180.0),
        phase=Cancel,
      ),
    ),
  )
  assert_eq(received, ["source:started", "source:moved", "source:ended:none"])
}

///|
test "view drag target enter move leave and drop" {
  let received : Array[String] = []
  let root = @views.column(
    [
      drag_test_source(drag_test_box(100.0, 100.0), "item"),
      drag_test_target(drag_test_box(100.0, 100.0), "a"),
      drag_test_target(drag_test_box(100.0, 100.0), "b"),
    ],
    spacing=0.0,
  )
  let runtime = drag_test_runtime(root, received, width=200.0, height=400.0)
  ignore(runtime.layout())
  drag_test_pointer(runtime, 50.0, 50.0, Down)
  drag_test_pointer(runtime, 50.0, 150.0, Move)
  assert_eq(received, ["source:started", "target:entered:a"])
  drag_test_pointer(runtime, 50.0, 160.0, Move)
  assert_eq(received, [
    "source:started", "target:entered:a", "target:moved:a", "source:moved",
  ])
  drag_test_pointer(runtime, 50.0, 250.0, Move)
  assert_eq(received, [
    "source:started", "target:entered:a", "target:moved:a", "source:moved", "target:left:a",
    "target:entered:b", "source:moved",
  ])
  drag_test_pointer(runtime, 50.0, 250.0, Up)
  assert_eq(received, [
    "source:started", "target:entered:a", "target:moved:a", "source:moved", "target:left:a",
    "target:entered:b", "source:moved", "target:dropped:b", "source:ended:b",
  ])
}

///|
test "nested drop targets resolve to the innermost accepting target" {
  let received : Array[String] = []
  let inner = drag_test_target(drag_test_box(100.0, 50.0), "inner")
  let outer = drag_test_target(
    @views.column([inner], spacing=0.0).frame(width=100.0, height=100.0),
    "outer",
  )
  let root = @views.column(
    [drag_test_source(drag_test_box(100.0, 100.0), "item"), outer],
    spacing=0.0,
  )
  let runtime = drag_test_runtime(root, received, width=200.0, height=300.0)
  ignore(runtime.layout())
  drag_test_pointer(runtime, 50.0, 50.0, Down)
  // y = 125 is inside the inner 50 pt target (outer starts at y = 100).
  drag_test_pointer(runtime, 50.0, 125.0, Move)
  assert_eq(received, ["source:started", "target:entered:inner"])
  // y = 175 is only inside the outer target.
  drag_test_pointer(runtime, 50.0, 175.0, Move)
  assert_eq(received, [
    "source:started", "target:entered:inner", "target:left:inner", "target:entered:outer",
    "source:moved",
  ])
}

///|
test "a rejecting drop target never becomes hovered" {
  let received : Array[String] = []
  let root = @views.column(
    [
      drag_test_source(drag_test_box(100.0, 100.0), "item"),
      drag_test_target(
        drag_test_box(100.0, 100.0),
        "strict",
        accepts=Some(fn(payload) { payload.key == "other" }),
      ),
    ],
    spacing=0.0,
  )
  let runtime = drag_test_runtime(root, received, width=200.0, height=300.0)
  ignore(runtime.layout())
  drag_test_pointer(runtime, 50.0, 50.0, Down)
  drag_test_pointer(runtime, 50.0, 150.0, Move)
  drag_test_pointer(runtime, 50.0, 160.0, Move)
  drag_test_pointer(runtime, 50.0, 160.0, Up)
  assert_eq(received, ["source:started", "source:moved", "source:ended:none"])
}

///|
test "escape cancels an active view drag" {
  let received : Array[String] = []
  let root = @views.column(
    [
      drag_test_source(drag_test_box(100.0, 100.0), "item"),
      drag_test_target(drag_test_box(100.0, 100.0), "a"),
    ],
    spacing=0.0,
  )
  let runtime = drag_test_runtime(root, received, width=200.0, height=300.0)
  ignore(runtime.layout())
  drag_test_pointer(runtime, 50.0, 50.0, Down)
  drag_test_pointer(runtime, 50.0, 150.0, Move)
  assert_eq(received, ["source:started", "target:entered:a"])
  runtime.dispatch_event(Keyboard(@core.KeyboardEvent::new(key="Escape")))
  assert_eq(received, [
    "source:started", "target:entered:a", "target:left:a", "source:ended:none",
  ])
  // The session is gone: later pointer samples produce nothing.
  drag_test_pointer(runtime, 50.0, 160.0, Move)
  drag_test_pointer(runtime, 50.0, 160.0, Up)
  assert_eq(received, [
    "source:started", "target:entered:a", "target:left:a", "source:ended:none",
  ])
}

///|
test "disabled drag source and target stay inert" {
  let received : Array[String] = []
  let source = drag_test_source(drag_test_box(100.0, 100.0), "item").disabled()
  let target = drag_test_target(drag_test_box(100.0, 100.0), "a").disabled()
  let root = @views.column([source, target], spacing=0.0)
  let runtime = drag_test_runtime(root, received, width=200.0, height=300.0)
  ignore(runtime.layout())
  drag_test_pointer(runtime, 50.0, 50.0, Down)
  drag_test_pointer(runtime, 50.0, 150.0, Move)
  drag_test_pointer(runtime, 50.0, 150.0, Up)
  assert_true(received.is_empty())
}

///|
test "view drag reports changed and delivers messages through the runtime" {
  let received : Array[String] = []
  let root = @views.column(
    [drag_test_source(drag_test_box(100.0, 100.0), "item")],
    spacing=0.0,
  )
  let runtime = drag_test_runtime(root, received, width=200.0, height=200.0)
  ignore(runtime.layout())
  assert_false(runtime.needs_paint())
  drag_test_pointer(runtime, 20.0, 20.0, Down)
  assert_true(received.is_empty() && !runtime.needs_paint())
  drag_test_pointer(runtime, 30.0, 20.0, Move)
  assert_eq(received, ["source:started"])
  assert_true(runtime.needs_paint())
}

///|
test "draggable coexists with on_drag on one view" {
  let received : Array[String] = []
  let box = drag_test_box(100.0, 100.0)
  let with_gesture = box.on_drag(fn(event) {
    match event.phase {
      @core.DragGesturePhase::Started => "gesture:started"
      @core.DragGesturePhase::Changed => "gesture:changed"
      @core.DragGesturePhase::Ended => "gesture:ended"
      @core.DragGesturePhase::Cancelled => "gesture:cancelled"
      _ => "gesture:other"
    }
  })
  let source = drag_test_source(with_gesture, "item")
  let root = @views.column([source], spacing=0.0)
  let runtime = drag_test_runtime(root, received, width=200.0, height=200.0)
  ignore(runtime.layout())
  drag_test_pointer(runtime, 20.0, 20.0, Down)
  drag_test_pointer(runtime, 25.0, 20.0, Move)
  // Both recognizers fire on the same sample; the drag session delivers first.
  assert_eq(received, ["source:started", "gesture:started"])
  drag_test_pointer(runtime, 30.0, 20.0, Move)
  assert_eq(received, [
    "source:started", "gesture:started", "source:moved", "gesture:changed",
  ])
  drag_test_pointer(runtime, 30.0, 20.0, Up)
  assert_eq(received, [
    "source:started", "gesture:started", "source:moved", "gesture:changed", "source:ended:none",
    "gesture:ended",
  ])
}

///|
test "file drop delivery is unchanged by the declarative drag session" {
  let received : Array[String] = []
  let root : @core.View[String] = @views.empty()
    .frame(width=100.0, height=100.0)
    .on_file_drop(fn(paths, _position) { "files:\{paths.length()}" })
  let runtime = drag_test_runtime(root, received, width=200.0, height=200.0)
  ignore(runtime.layout())
  runtime.dispatch_event(
    DragDrop(
      @core.DragDropEvent::new(
        phase=@core.DragDropPhase::Dropped,
        paths=["/tmp/a.txt"],
        position=Some(@core.Point::new(x=20.0, y=20.0)),
      ),
    ),
  )
  assert_eq(received, ["files:1"])
}

///|
/// Probe node that records the drag context geometry the runtime hands to a
/// declaring view. The declarative API's modifier wrappers intentionally do
/// not surface the frame, so this pins the runtime contract directly.
struct DragProbeNode {
  frames : Array[@core.Rect]
  positions : Array[@core.Point]
}

///|
impl @core.ViewNode for DragProbeNode with fn identity(_self) {
  @core.ViewIdentity::new(kind="DragProbe")
}

///|
impl @core.ViewNode for DragProbeNode with fn layout(_self, context) {
  @core.ViewLayoutResult::new(
    size=context.constraints.constrain(
      @core.Size::new(width=100.0, height=50.0),
    ),
  )
}

///|
impl @core.ViewNode for DragProbeNode with fn drag_declaration(_self) {
  @core.DragDeclaration::new(target=Some(@core.DropTarget::new(key="probe")))
}

///|
test "view drag dispatches the declaring view's own screen frame and position" {
  let received : Array[String] = []
  let frames : Array[@core.Rect] = []
  let positions : Array[@core.Point] = []
  let probe : @core.View[String] = @core.View::from_node(
    DragProbeNode::{ frames, positions, },
    drag=fn(node, context) {
      node.frames.push(context.frame)
      node.positions.push(context.position)
      @core.ViewDragResult::none()
    },
  ).frame(width=100.0, height=50.0)
  let root = @views.column(
    [drag_test_source(drag_test_box(100.0, 100.0), "item"), probe],
    spacing=0.0,
  )
  let runtime = drag_test_runtime(root, received, width=200.0, height=300.0)
  ignore(runtime.layout())
  drag_test_pointer(runtime, 50.0, 50.0, Down)
  drag_test_pointer(runtime, 50.0, 125.0, Move)
  assert_eq(frames.length(), 1)
  assert_eq(
    frames[0],
    @core.Rect::new(x=0.0, y=100.0, width=100.0, height=50.0),
  )
  assert_eq(positions[0], @core.Point::new(x=50.0, y=125.0))
  drag_test_pointer(runtime, 50.0, 130.0, Up)
  // Entered and Dropped both carry this view's own frame, not the root's.
  assert_eq(frames.length(), 2)
  for frame in frames {
    assert_eq(frame, @core.Rect::new(x=0.0, y=100.0, width=100.0, height=50.0))
  }
}
