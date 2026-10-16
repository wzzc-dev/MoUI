///|
/// Headless runtime proofs for the two-pane demo. This is the same
/// `@moui.View[Msg]` tree a terminal renderer consumes, driven only through
/// `AppEvent`: layout results, the semantics tree and the draw-command stream
/// are the contract, so nothing here needs a pixel renderer or a real terminal.

///|
fn open_app(width~ : Double, height~ : Double) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(program=@app.program(), width~, height~)
}

///|
fn nodes(runtime : @runtime.AppRuntime) -> Array[@core.SemanticsNode] {
  let _ = runtime.layout()
  match runtime.read_semantics() {
    Ok(Full(snapshot)) => snapshot.nodes()
    _ => []
  }
}

///|
fn nodes_with_role(
  runtime : @runtime.AppRuntime,
  role : @core.SemanticsRole,
) -> Array[@core.SemanticsNode] {
  let out : Array[@core.SemanticsNode] = []
  for node in nodes(runtime) {
    if node.role == role {
      out.push(node)
    }
  }
  out
}

///|
fn row_ys(
  runtime : @runtime.AppRuntime,
  role : @core.SemanticsRole,
) -> Array[Double] {
  nodes_with_role(runtime, role).map(node => node.frame.origin.y)
}

///|
fn labels_with_state(
  runtime : @runtime.AppRuntime,
  role~ : @core.SemanticsRole,
  selected~ : Bool,
) -> Array[String] {
  let out : Array[String] = []
  for node in nodes_with_role(runtime, role) {
    if node.state.selected == selected {
      out.push(node.label)
    }
  }
  out
}

///|
fn focused_labels(runtime : @runtime.AppRuntime) -> Array[String] {
  let out : Array[String] = []
  for node in nodes(runtime) {
    if node.state.focused {
      out.push(node.label)
    }
  }
  out
}

///|
fn has_label(labels : Array[String], needle : String) -> Bool {
  labels.any(label => label.contains(needle))
}

///|
fn row_frame(
  runtime : @runtime.AppRuntime,
  role~ : @core.SemanticsRole,
  needle~ : String,
) -> @core.Rect raise {
  for node in nodes_with_role(runtime, role) {
    if node.label.contains(needle) {
      return node.frame
    }
  }
  // `SemanticsRole` has no `Show` instance, so the message names the needle
  // only rather than interpolating the role.
  fail("no row node labelled " + needle)
}

///|
/// The two scroll viewports, left one first.
fn boxes(
  runtime : @runtime.AppRuntime,
) -> (@core.SemanticsNode, @core.SemanticsNode) raise {
  let all = nodes_with_role(runtime, @core.SemanticsRole::ScrollView)
  if all.length() != 2 {
    fail("expected exactly two scroll viewports")
  }
  if all[0].frame.origin.x <= all[1].frame.origin.x {
    (all[0], all[1])
  } else {
    (all[1], all[0])
  }
}

///|
fn frame_bottom(frame : @core.Rect) -> Double {
  frame.origin.y + frame.size.height
}

///|
fn frame_right(frame : @core.Rect) -> Double {
  frame.origin.x + frame.size.width
}

///|
/// Rows keep their unclipped frames in the semantics tree, so "taller than the
/// viewport" is checkable from the projection alone. Every scroll assertion
/// starts with this, because a scroll test on a pane that fits is vacuously
/// true and would pass even if scrolling were broken.
fn content_overflows(
  runtime : @runtime.AppRuntime,
  role~ : @core.SemanticsRole,
  viewport~ : @core.SemanticsNode,
) -> Bool raise {
  let rows = nodes_with_role(runtime, role)
  if rows.length() == 0 {
    fail("no rows projected for this pane")
  }
  let mut bottom = 0.0
  for row in rows {
    if frame_bottom(row.frame) > bottom {
      bottom = frame_bottom(row.frame)
    }
  }
  bottom > frame_bottom(viewport.frame)
}

///|
fn rects_of(runtime : @runtime.AppRuntime, clip~ : Bool) -> Array[@core.Rect] {
  let out : Array[@core.Rect] = []
  for command in runtime.draw_commands() {
    match command {
      @core.DrawCommand::PushClip(rect) => if clip { out.push(rect) }
      @core.DrawCommand::StrokeRect(rect, _, _) => if !clip { out.push(rect) }
      @core.DrawCommand::StrokeRoundedRect(shape, _, _) =>
        if !clip {
          out.push(shape.rect)
        }
      // A `container(border=...)` box is not stroked with a plain rect:
      // `layout_views.container_box` emits `StrokeRoundedRectBrush` even at
      // radius 0.0, so a border-aware reader must take all three variants.
      @core.DrawCommand::StrokeRoundedRectBrush(shape, _, _) =>
        if !clip {
          out.push(shape.rect)
        }
      _ => ()
    }
  }
  out
}

///|
/// True when some clip is contained by `viewport`. Since the two viewports do
/// not overlap, one such clip per pane can only mean per-pane clipping — the
/// content of one pane cannot be clipped away by the other pane's box.
fn has_clip_inside(rects : Array[@core.Rect], viewport~ : @core.Rect) -> Bool {
  rects.any(rect => {
    rect.size.width > 0.0 &&
    rect.size.height > 0.0 &&
    rect.origin.x >= viewport.origin.x - 1.0 &&
    frame_right(rect) <= frame_right(viewport) + 1.0 &&
    rect.origin.y >= viewport.origin.y - 1.0 &&
    frame_bottom(rect) <= frame_bottom(viewport) + 1.0
  })
}

///|
/// True when some stroked box surrounds `viewport`: that is the pane frame the
/// scroll box sits inside.
fn has_border_around(rects : Array[@core.Rect], viewport~ : @core.Rect) -> Bool {
  rects.any(rect => {
    rect.origin.x <= viewport.origin.x &&
    rect.origin.y <= viewport.origin.y &&
    frame_right(rect) >= frame_right(viewport) &&
    frame_bottom(rect) >= frame_bottom(viewport)
  })
}

///|
fn any_moved(before~ : Array[Double], after~ : Array[Double]) -> Bool {
  if before.length() != after.length() {
    return false
  }
  let mut i = 0
  let mut moved = false
  while i < before.length() {
    if before[i] != after[i] {
      moved = true
    }
    i = i + 1
  }
  moved
}

///|
fn press(
  runtime : @runtime.AppRuntime,
  key~ : String,
  shift? : Bool = false,
) -> Unit {
  runtime.dispatch_event(
    Keyboard(
      @core.KeyboardEvent::new(
        key~,
        pressed=true,
        repeat=false,
        modifiers=@core.KeyModifiers::new(shift~),
      ),
    ),
  )
}

///|
fn press_times(
  runtime : @runtime.AppRuntime,
  key~ : String,
  times~ : Int,
) -> Unit {
  let mut i = 0
  while i < times {
    press(runtime, key~)
    i = i + 1
  }
}

///|
fn point_click(runtime : @runtime.AppRuntime, at~ : @core.Point) -> Unit {
  runtime.dispatch_event(
    Pointer(@core.PointerEvent::new(position=at, phase=Down)),
  )
  runtime.dispatch_event(
    Pointer(@core.PointerEvent::new(position=at, phase=Up)),
  )
}

///|
fn wheel(
  runtime : @runtime.AppRuntime,
  at~ : @core.Point,
  dy~ : Double,
) -> Unit {
  runtime.dispatch_event(
    Pointer(
      @core.PointerEvent::new(
        position=at,
        phase=Move,
        wheel_delta=@core.Point::new(x=0.0, y=dy),
      ),
    ),
  )
}

///|
fn center(frame : @core.Rect) -> @core.Point {
  @core.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
}

///|
fn text_present(runtime : @runtime.AppRuntime, needle : String) -> Bool {
  let _ = runtime.layout()
  runtime
  .draw_commands()
  .any(command => {
    match command {
      @core.DrawCommand::DrawText({ text: value, .. }) => value.contains(needle)
      _ => false
    }
  })
}

///|
test "the list and the tree sit side by side in separate clipped, bordered boxes" {
  let runtime = open_app(width=960.0, height=480.0)
  let lists = nodes_with_role(runtime, @core.SemanticsRole::List)
  let trees = nodes_with_role(runtime, @core.SemanticsRole::Tree)
  inspect(lists.length(), content="1")
  inspect(trees.length(), content="1")
  // Two independent scroll boxes: their horizontal spans must not overlap.
  let (left, right) = boxes(runtime)
  assert_true(right.frame.origin.x >= frame_right(left.frame))
  assert_true(left.frame.size.height > 100.0 && right.frame.size.height > 100.0)
  // The panes are laid out side by side, not stacked: the tree's own box starts
  // right of the whole list.
  let list = lists[0]
  let tree = trees[0]
  assert_true(tree.frame.origin.x > frame_right(list.frame))
  // Each pane draws its own frame and clips its own content. This is the
  // projection the terminal renderer inherits: with no shared clip, scrolling
  // one pane can never wipe the other pane's cells.
  let borders = rects_of(runtime, clip=false)
  let clips = rects_of(runtime, clip=true)
  assert_true(has_border_around(borders, viewport=left.frame))
  assert_true(has_border_around(borders, viewport=right.frame))
  assert_true(has_clip_inside(clips, viewport=left.frame))
  assert_true(has_clip_inside(clips, viewport=right.frame))
  runtime.destroy()
}

///|
test "wheel over the list scrolls the list only" {
  let runtime = open_app(width=960.0, height=480.0)
  let (left, right) = boxes(runtime)
  // Preconditions, so neither half of the assertion below can pass by accident:
  // the list is taller than its viewport, the tree is not.
  assert_true(
    content_overflows(
      runtime,
      role=@core.SemanticsRole::ListItem,
      viewport=left,
    ),
  )
  assert_true(
    !content_overflows(
      runtime,
      role=@core.SemanticsRole::TreeItem,
      viewport=right,
    ),
  )
  let before_rows = row_ys(runtime, @core.SemanticsRole::ListItem)
  let before_tree = row_ys(runtime, @core.SemanticsRole::TreeItem)
  // Negative wheel delta moves the content up: the view stores `offset - delta`.
  wheel(runtime, at=center(left.frame), dy=0.0 - @app.scroll_line)
  let after_rows = row_ys(runtime, @core.SemanticsRole::ListItem)
  let after_tree = row_ys(runtime, @core.SemanticsRole::TreeItem)
  assert_true(before_rows.length() == after_rows.length())
  assert_true(any_moved(before=before_rows, after=after_rows))
  assert_true(before_tree == after_tree)
  assert_true(text_present(runtime, "list=1"))
  assert_true(text_present(runtime, "tree=0"))
  runtime.destroy()
}

///|
test "wheel over the tree scrolls the tree only" {
  // A short window so both panes overflow their own viewports.
  let runtime = open_app(width=960.0, height=280.0)
  let (_, right) = boxes(runtime)
  assert_true(
    content_overflows(
      runtime,
      role=@core.SemanticsRole::TreeItem,
      viewport=right,
    ),
  )
  let before_tree = row_ys(runtime, @core.SemanticsRole::TreeItem)
  let before_rows = row_ys(runtime, @core.SemanticsRole::ListItem)
  wheel(runtime, at=center(right.frame), dy=0.0 - @app.scroll_line)
  let after_tree = row_ys(runtime, @core.SemanticsRole::TreeItem)
  let after_rows = row_ys(runtime, @core.SemanticsRole::ListItem)
  assert_true(any_moved(before=before_tree, after=after_tree))
  assert_true(before_rows == after_rows)
  assert_true(text_present(runtime, "tree=1"))
  assert_true(text_present(runtime, "list=0"))
  runtime.destroy()
}

///|
test "instantaneous keypress reshapes the tree without a submit" {
  let runtime = open_app(width=960.0, height=480.0)
  assert_true(text_present(runtime, "Files 7"))
  press(runtime, key="a")
  assert_true(text_present(runtime, "Files 8"))
  assert_true(
    has_label(
      labels_of(nodes_with_role(runtime, @core.SemanticsRole::TreeItem)),
      "new-0",
    ),
  )
  runtime.destroy()
}

///|
test "arrows move the selection in the focused pane only" {
  let runtime = open_app(width=960.0, height=480.0)
  press(runtime, key="ArrowDown")
  assert_true(text_present(runtime, "sel=Entry 1"))
  press(runtime, key="Tab")
  assert_true(text_present(runtime, "focus: tree"))
  press(runtime, key="ArrowDown")
  assert_true(text_present(runtime, "node=core"))
  press(runtime, key="Tab", shift=true)
  assert_true(text_present(runtime, "focus: list"))
  runtime.destroy()
}

///|
test "folding a folder removes its rows from the projection" {
  let runtime = open_app(width=960.0, height=480.0)
  assert_true(text_present(runtime, "program.mbt"))
  press(runtime, key="Tab")
  press(runtime, key="Enter")
  assert_true(!text_present(runtime, "program.mbt"))
  assert_true(!text_present(runtime, "runtime.mbt"))
  assert_true(text_present(runtime, "Files 2"))
  press(runtime, key="Enter")
  assert_true(text_present(runtime, "program.mbt"))
  assert_true(text_present(runtime, "Files 7"))
  runtime.destroy()
}

///|
test "a mouse click on a bordered row selects it" {
  let runtime = open_app(width=960.0, height=480.0)
  let frame = row_frame(
    runtime,
    role=@core.SemanticsRole::ListItem,
    needle="Entry 3",
  )
  point_click(runtime, at=center(frame))
  assert_true(text_present(runtime, "sel=Entry 3"))
  runtime.destroy()
}

///|
test "a mouse click on a tree row activates the tree pane" {
  let runtime = open_app(width=960.0, height=480.0)
  let frame = row_frame(
    runtime,
    role=@core.SemanticsRole::TreeItem,
    needle="runtime.mbt",
  )
  point_click(runtime, at=center(frame))
  assert_true(text_present(runtime, "focus: tree"))
  assert_true(text_present(runtime, "node=runtime"))
  runtime.destroy()
}

///|
test "resize reflows both panes instead of repainting the old boxes" {
  let runtime = open_app(width=960.0, height=480.0)
  let (before_left, before_right) = boxes(runtime)
  runtime.dispatch_event(Resize(@core.Size::new(width=1600.0, height=480.0)))
  let (after_left, after_right) = boxes(runtime)
  // Each pane's content is a fixed-width box centred inside its `expanded` half,
  // so widening the window by 640px shifts the left box by half the extra room
  // and the right box by the whole extra half plus its own centring. Both must
  // move: a backend that only repaints internally would report the old frames.
  assert_true(after_left.frame.origin.x > before_left.frame.origin.x)
  assert_true(after_right.frame.origin.x > before_right.frame.origin.x + 300.0)
  assert_true(after_right.frame.origin.x > frame_right(after_left.frame))
  assert_true(frame_right(after_right.frame) <= 1600.0)
  assert_true(after_left.frame.size.height == before_left.frame.size.height)
  // New window, same content: the per-pane clips follow the new layout, so the
  // old boxes cannot leave a damaged-but-never-repainted region behind.
  let clips = rects_of(runtime, clip=true)
  assert_true(has_clip_inside(clips, viewport=after_left.frame))
  assert_true(has_clip_inside(clips, viewport=after_right.frame))
  runtime.destroy()
}

///|
test "focus and selection follow their row across a head insert" {
  let runtime = open_app(width=960.0, height=480.0)
  press_times(runtime, key="ArrowDown", times=3)
  assert_true(text_present(runtime, "sel=Entry 3"))
  press(runtime, key="n")
  let selected = labels_with_state(
    runtime,
    role=@core.SemanticsRole::ListItem,
    selected=true,
  )
  assert_true(has_label(selected, "Entry 3"))
  assert_true(!has_label(selected, "Entry 2"))
  runtime.destroy()
}

///|
test "a keyed tree row keeps keyboard focus across a node insert" {
  let runtime = open_app(width=960.0, height=480.0)
  // Walk the traversal chain until a row of the tree holds focus: the demo
  // claims Tab for pane switching, so traversal is driven through the runtime.
  let mut hops = 0
  while hops < 200 && !has_label(focused_labels(runtime), "program.mbt") {
    ignore(runtime.focus_next())
    hops = hops + 1
  }
  assert_true(has_label(focused_labels(runtime), "program.mbt"))
  let before = focused_labels(runtime)
  // Prepending a root row shifts every existing row one slot down. Rows are
  // keyed by item id, so focus must stay on the item, not on the slot.
  press(runtime, key="a")
  assert_true(
    has_label(
      labels_of(nodes_with_role(runtime, @core.SemanticsRole::TreeItem)),
      "new-0",
    ),
  )
  assert_true(focused_labels(runtime) == before)
  runtime.destroy()
}

///|
fn labels_of(nodes : Array[@core.SemanticsNode]) -> Array[String] {
  nodes.map(node => node.label)
}
