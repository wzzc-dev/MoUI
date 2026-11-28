///|
/// End-to-end cursor resolution through the real runtime.
///
/// These tests go through `@runtime.AppRuntime::dispatch_event`, because the
/// behaviour under test is the collaboration between hit testing (which frames
/// contain the pointer), the declaration chain (which view said what), and the
/// pointer press state (which style survives a drag out of the declaring
/// region). Driving `View::pointer_cursor` directly would only re-test the
/// getter.

///|
fn[Msg] cursor_runtime_leaf(
  width~ : Double,
  height~ : Double,
) -> @core.View[Msg] {
  runtime_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="CursorLeaf"),
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width~, height~)),
      )
    },
  )
}

///|
/// Two 100x40 children at x=[0,100) and x=[200,300); the gap in between hits the
/// stage itself, which is what proves ancestor declarations still apply.
fn[Msg] cursor_runtime_stage(
  left~ : @core.View[Msg],
  right~ : @core.View[Msg],
) -> @core.View[Msg] {
  runtime_fixture_view(
    identity=() => @core.ViewIdentity::new(kind="CursorStage"),
    children=() => [left, right],
    child_constraints=_constraints => @core.Constraints::unbounded(),
    layout=ctx => {
      let frames : Array[@core.Rect] = []
      for index, _size in ctx.child_sizes {
        let x = if index == 0 { 0.0 } else { 200.0 }
        frames.push(@core.Rect::new(x~, y=0.0, width=100.0, height=40.0))
      }
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(
          @core.Size::new(width=300.0, height=40.0),
        ),
        child_frames=frames,
      )
    },
  )
}

///|
fn cursor_runtime_pointer(
  phase : @core.PointerPhase,
  x : Double,
  y : Double,
) -> @core.AppEvent {
  Pointer(@core.PointerEvent::new(position=@core.Point::new(x~, y~), phase~))
}

///|
fn cursor_runtime_resize() -> @core.CursorStyle {
  @core.CursorStyle::Icon(@core.CursorIcon::CursorColResize)
}

///|
fn cursor_runtime_hand() -> @core.CursorStyle {
  @core.CursorStyle::Icon(@core.CursorIcon::CursorPointer)
}

///|
test "runtime resolves the innermost cursor declaration and resets on leave" {
  let left : @core.View[Unit] = cursor_runtime_leaf(width=100.0, height=40.0).cursor(
    cursor_runtime_resize(),
  )
  let right : @core.View[Unit] = cursor_runtime_leaf(width=100.0, height=40.0).cursor(
    cursor_runtime_hand(),
  )
  let root = cursor_runtime_stage(left~, right~)
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=300.0, height=40.0),
  )

  // Before any pointer sample the host shows the arrow.
  assert_eq(runtime.pointer_cursor(), @core.CursorStyle::Default)

  ignore(runtime.dispatch_event(cursor_runtime_pointer(Move, 10.0, 10.0)))
  assert_eq(runtime.pointer_cursor(), cursor_runtime_resize())

  // The sibling declaration wins over the stage, which declares nothing.
  ignore(runtime.dispatch_event(cursor_runtime_pointer(Move, 250.0, 10.0)))
  assert_eq(runtime.pointer_cursor(), cursor_runtime_hand())

  // The gap hits the undeclared stage, so the arrow returns.
  ignore(runtime.dispatch_event(cursor_runtime_pointer(Move, 150.0, 10.0)))
  assert_eq(runtime.pointer_cursor(), @core.CursorStyle::Default)

  // A synthetic leave clears the declaration without another sample.
  ignore(runtime.dispatch_event(cursor_runtime_pointer(Exit, 350.0, 10.0)))
  assert_eq(runtime.pointer_cursor(), @core.CursorStyle::Default)
}

///|
test "runtime inherits an ancestor cursor but an explicit Default stops it" {
  let inheriting : @core.View[Unit] = cursor_runtime_leaf(
    width=100.0,
    height=40.0,
  ).cursor(@core.CursorStyle::Inherit)
  let filler = cursor_runtime_leaf(width=100.0, height=40.0)
  let stage = cursor_runtime_stage(left=inheriting, right=filler)
  let root : @core.View[Unit] = stage.cursor(cursor_runtime_resize())
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=300.0, height=40.0),
  )
  ignore(runtime.dispatch_event(cursor_runtime_pointer(Move, 10.0, 10.0)))
  // `Inherit` on the child climbs to the stage's resize declaration.
  assert_eq(runtime.pointer_cursor(), cursor_runtime_resize())

  let blocking : @core.View[Unit] = cursor_runtime_leaf(
    width=100.0,
    height=40.0,
  ).cursor(@core.CursorStyle::Default)
  let filler = cursor_runtime_leaf(width=100.0, height=40.0)
  let blocking_stage = cursor_runtime_stage(left=blocking, right=filler)
  let blocking_root : @core.View[Unit] = blocking_stage.cursor(
    cursor_runtime_resize(),
  )
  let blocking_runtime = @runtime.AppRuntime::new_view(
    root=blocking_root,
    size=@core.Size::new(width=300.0, height=40.0),
  )
  ignore(
    blocking_runtime.dispatch_event(cursor_runtime_pointer(Move, 10.0, 10.0)),
  )
  // An explicit `Default` is a stop, not an inherit.
  assert_eq(blocking_runtime.pointer_cursor(), @core.CursorStyle::Default)
}

///|
test "runtime keeps the pressed element cursor while a drag leaves the region" {
  let left : @core.View[Unit] = cursor_runtime_leaf(width=100.0, height=40.0).cursor(
    cursor_runtime_resize(),
  )
  let right = cursor_runtime_leaf(width=100.0, height=40.0)
  let root = cursor_runtime_stage(left~, right~)
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=300.0, height=40.0),
  )

  ignore(runtime.dispatch_event(cursor_runtime_pointer(Move, 10.0, 10.0)))
  ignore(runtime.dispatch_event(cursor_runtime_pointer(Down, 10.0, 10.0)))
  assert_eq(runtime.pointer_cursor(), cursor_runtime_resize())

  // Dragging out of the gutter keeps the resize cursor: a splitter drag must
  // not flicker back to the arrow mid-gesture.
  ignore(runtime.dispatch_event(cursor_runtime_pointer(Move, 250.0, 10.0)))
  assert_eq(runtime.pointer_cursor(), cursor_runtime_resize())

  // Releasing re-resolves against the pointer, which is now over a region with
  // no declaration.
  ignore(runtime.dispatch_event(cursor_runtime_pointer(Up, 250.0, 10.0)))
  assert_eq(runtime.pointer_cursor(), @core.CursorStyle::Default)
}

///|
/// A rebuilt declaration must reach the host without a remount: the element
/// keeps its identity, so `reconcile` swaps `view_node` and the resolver reads
/// the new style on the next pointer sample.
test "runtime cursor follows a rebuilt declaration" {
  let program = @core.Program::simple(
    init=cursor_runtime_resize(),
    update=fn(_style, _message) { cursor_runtime_hand() },
    view=fn(style) {
      let left : @core.View[Unit] = cursor_runtime_leaf(
        width=100.0,
        height=40.0,
      ).cursor(style)
      let right = cursor_runtime_leaf(width=100.0, height=40.0).on_tap(())
      cursor_runtime_stage(left~, right~)
    },
  )
  let runtime = @runtime.AppRuntime::new_program(
    program~,
    size=@core.Size::new(width=300.0, height=40.0),
  )
  ignore(runtime.draw_frame())
  ignore(runtime.dispatch_event(cursor_runtime_pointer(Move, 10.0, 10.0)))
  assert_eq(runtime.pointer_cursor(), cursor_runtime_resize())

  // Tap the toggling leaf: the model becomes the hand style and the view is
  // rebuilt. The element under the pointer keeps its identity, so the next
  // sample alone must pick the new declaration up.
  ignore(runtime.dispatch_event(cursor_runtime_pointer(Down, 250.0, 10.0)))
  ignore(runtime.dispatch_event(cursor_runtime_pointer(Up, 250.0, 10.0)))
  ignore(runtime.draw_frame())
  ignore(runtime.dispatch_event(cursor_runtime_pointer(Move, 10.0, 10.0)))
  assert_eq(runtime.pointer_cursor(), cursor_runtime_hand())
}

///|
/// Regression for the macOS Manage dropdown freeze: cursor resolution runs on
/// every presented frame, so a popup must not make it re-walk every non-overlay
/// subtree in the page. The timing bound is deliberately generous; the old
/// implementation took orders of magnitude longer on this shape because each
/// node re-scanned its descendants for overlays.
test "cursor resolution skips overlay prepass over large non-overlay bases" {
  let rows : Array[@core.View[Unit]] = []
  for index in 0..<12000 {
    rows.push(
      @views.row(
        [
          @views.text("row \{index} a").frame(width=80.0, height=8.0),
          @views.text("row \{index} b").frame(width=80.0, height=8.0),
          @views.text("row \{index} c").frame(width=80.0, height=8.0),
          @views.text("row \{index} d").frame(width=80.0, height=8.0),
        ],
        spacing=0.0,
      ),
    )
  }
  let root = @views.popup_host(@views.column(rows, spacing=0.0), [
    @views.PresentationSpec::new(
      id="menu",
      kind=Popover,
      anchor=HostBase,
      content=@views.frame(@views.text("Item"), width=40.0, height=20.0),
    ),
  ])
  let runtime = @runtime.AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=400.0, height=1200.0),
  )
  ignore(runtime.layout())
  ignore(runtime.dispatch_event(cursor_runtime_pointer(Move, 2.0, 2.0)))
  let started = @async.now()
  for _ in 0..<20 {
    ignore(runtime.pointer_cursor())
  }
  let elapsed_ms = @async.now() - started
  assert_true(elapsed_ms < 500L)
}
