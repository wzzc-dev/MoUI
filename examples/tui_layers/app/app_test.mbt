///|
/// Headless runtime proofs for the eight-item demo. This is the same
/// `@moui.View[Msg]` tree a terminal renderer consumes, driven only through
/// `AppEvent`: layout results, the semantics tree and the draw-command stream are
/// the contract, so nothing here needs a pixel renderer or a real terminal.

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
fn labels_of(nodes : Array[@core.SemanticsNode]) -> Array[String] {
  nodes.map(node => node.label)
}

///|
fn has_label(labels : Array[String], needle : String) -> Bool {
  labels.any(label => label.contains(needle))
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
/// The only node with this role, when the demo projects exactly one (the filter
/// field, the only-visible box, the scroll viewports).
fn only_frame(
  runtime : @runtime.AppRuntime,
  role~ : @core.SemanticsRole,
) -> @core.Rect raise {
  let all = nodes_with_role(runtime, role)
  if all.length() != 1 {
    fail("expected one node with this role, got " + all.length().to_string())
  }
  all[0].frame
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
/// starts with this, because a scroll test on a pane that fits is vacuously true
/// and would pass even if scrolling were broken.
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
  control? : Bool = false,
) -> Unit {
  runtime.dispatch_event(
    Keyboard(
      @core.KeyboardEvent::new(
        key~,
        pressed=true,
        repeat=false,
        modifiers=@core.KeyModifiers::new(shift~, control~),
      ),
    ),
  )
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
/// Right button, pressed only: `View::on_secondary_tap` fires on the host's press
/// phase, and that is the only mouse gesture the tree exposes for folding.
fn right_click(runtime : @runtime.AppRuntime, at~ : @core.Point) -> Unit {
  runtime.dispatch_event(
    Pointer(@core.PointerEvent::new(position=at, phase=Down, button=1)),
  )
  runtime.dispatch_event(
    Pointer(@core.PointerEvent::new(position=at, phase=Up, button=1)),
  )
}

///|
fn click_frame(runtime : @runtime.AppRuntime, frame : @core.Rect) -> Unit {
  point_click(runtime, at=center(frame))
}

///|
fn click_row(
  runtime : @runtime.AppRuntime,
  role~ : @core.SemanticsRole,
  needle~ : String,
) -> Unit raise {
  click_frame(runtime, row_frame(runtime, role~, needle~))
}

///|
/// Fold, then fold back, reading the row's frame again in between. A cached frame
/// is wrong here: a `scroll_view` with no explicit viewport sizes to its content
/// and the pane container centres that content, so closing a subtree moves every
/// remaining row — the second press would otherwise land in empty space above the
/// tree and the test would read as a broken toggle.
fn right_click_row(
  runtime : @runtime.AppRuntime,
  role~ : @core.SemanticsRole,
  needle~ : String,
) -> Unit raise {
  right_click(runtime, at=center(row_frame(runtime, role~, needle~)))
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
/// One keystroke, the way the terminal decoder delivers a printable byte: a
/// `TextInput`, not a `Keyboard`. The decoder emits both for real input; here the
/// text channel is what the field listens to.
fn type_char(runtime : @runtime.AppRuntime, text : String) -> Unit {
  runtime.dispatch_event(TextInput(@core.TextInputEvent::InsertText(text)))
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
/// A window short enough that both panes overflow their own viewports: the chrome
/// (title line, filter line, two pane titles, three status lines) is ~160px, so at
/// 280px each viewport is ~120px against 348px of list rows and 396px of tree
/// rows. Any taller and the list fits, which would let a broken scroll pass.
fn short_app() -> @runtime.AppRuntime {
  open_app(width=960.0, height=280.0)
}

///|
test "the layer list and the file tree sit side by side in separate clipped, bordered boxes" {
  let runtime = open_app(width=960.0, height=480.0)
  let lists = nodes_with_role(runtime, @core.SemanticsRole::List)
  let trees = nodes_with_role(runtime, @core.SemanticsRole::Tree)
  inspect(lists.length(), content="1")
  inspect(trees.length(), content="1")
  // Two independent scroll boxes whose horizontal spans do not overlap.
  let (left, right) = boxes(runtime)
  assert_true(right.frame.origin.x >= frame_right(left.frame))
  assert_true(left.frame.size.height > 50.0 && right.frame.size.height > 50.0)
  // The panes are laid out side by side, not stacked: the tree's own box starts
  // right of the whole list.
  assert_true(trees[0].frame.origin.x > frame_right(lists[0].frame))
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
test "Tab walks the three panes and the arrows follow the border" {
  let runtime = open_app(width=960.0, height=480.0)
  assert_true(text_present(runtime, "focus: layers"))
  press(runtime, key="ArrowDown")
  assert_true(text_present(runtime, "sel=Grid"))
  press(runtime, key="Tab")
  assert_true(text_present(runtime, "focus: files"))
  press(runtime, key="ArrowDown")
  assert_true(text_present(runtime, "node=core"))
  press(runtime, key="Tab")
  // The third stop is the filter line, where the arrows still move the list:
  // the caret does not move, because program commands keep the arrows claimed.
  assert_true(text_present(runtime, "focus: filter"))
  press(runtime, key="ArrowDown")
  assert_true(text_present(runtime, "sel=Strokes"))
  press(runtime, key="Tab")
  assert_true(text_present(runtime, "focus: layers"))
  // Shift-Tab is the same command with a sign, so it wraps backwards past the
  // first pane instead of stopping at it.
  press(runtime, key="Tab", shift=true)
  assert_true(text_present(runtime, "focus: filter"))
  runtime.destroy()
}

///|
test "wheel over one pane scrolls that pane only" {
  let runtime = short_app()
  let (left, right) = boxes(runtime)
  // Preconditions, so neither half of the assertion can pass by accident: at
  // eleven rows both panes are taller than their own viewport.
  assert_true(
    content_overflows(
      runtime,
      role=@core.SemanticsRole::ListItem,
      viewport=left,
    ),
  )
  assert_true(
    content_overflows(
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
  assert_true(text_present(runtime, "row=1  file=0"))
  wheel(runtime, at=center(right.frame), dy=0.0 - @app.scroll_line)
  assert_true(text_present(runtime, "row=1  file=1"))
  runtime.destroy()
}

///|
test "a click on a bordered row selects it and a right click folds a folder" {
  let runtime = open_app(width=960.0, height=480.0)
  assert_true(text_present(runtime, "Layers 8/8"))
  // The marker is part of the row label, so the visible "[x]" state is what the
  // click was checked against — not a second hit box the layout could hide.
  click_row(runtime, role=@core.SemanticsRole::ListItem, needle="Labels")
  assert_true(text_present(runtime, "sel=Labels"))
  let selected = labels_with_state(
    runtime,
    role=@core.SemanticsRole::ListItem,
    selected=true,
  )
  assert_true(has_label(selected, "Labels"))
  assert_true(!has_label(selected, "Shadows"))
  assert_true(text_present(runtime, "Files 10"))
  right_click_row(runtime, role=@core.SemanticsRole::TreeItem, needle="src")
  assert_true(text_present(runtime, "Files 5"))
  assert_true(!text_present(runtime, "program.mbt"))
  right_click_row(runtime, role=@core.SemanticsRole::TreeItem, needle="src")
  assert_true(text_present(runtime, "Files 10"))
  assert_true(text_present(runtime, "program.mbt"))
  runtime.destroy()
}

///|
test "a click on the only-visible box and on the add buttons reaches the model" {
  let runtime = open_app(width=960.0, height=480.0)
  assert_true(text_present(runtime, "only=0"))
  let box = only_frame(runtime, role=@core.SemanticsRole::Checkbox)
  click_frame(runtime, box)
  assert_true(text_present(runtime, "only=1"))
  assert_true(text_present(runtime, "rows=6"))
  // The box filters by rule: the two off layers leave the rows, but their own
  // `visible` facts are untouched, so `hide=` must not move.
  assert_true(text_present(runtime, "hide=2"))
  assert_true(!text_present(runtime, "[ ] Fills"))
  // The same box is a toggle, not a one-shot: the second press is a different
  // message, so `rows=` must come back to the unfiltered count.
  click_frame(runtime, box)
  assert_true(text_present(runtime, "only=0"))
  assert_true(text_present(runtime, "rows=8"))
  assert_true(text_present(runtime, "[ ] Fills"))
  // The two buttons share the filter line: a click there is a command, not text.
  click_row(runtime, role=@core.SemanticsRole::Button, needle="layer")
  assert_true(text_present(runtime, "Layers 9/9"))
  click_row(runtime, role=@core.SemanticsRole::Button, needle="folder")
  assert_true(text_present(runtime, "Files 11"))
  runtime.destroy()
}

///|
test "typing in the field reshapes the list without waiting for Enter" {
  let runtime = open_app(width=960.0, height=480.0)
  click_frame(runtime, only_frame(runtime, role=@core.SemanticsRole::TextField))
  type_char(runtime, "s")
  assert_true(text_present(runtime, "filter=s  rows=6"))
  assert_true(text_present(runtime, "focus: filter"))
  type_char(runtime, "t")
  assert_true(text_present(runtime, "filter=st  rows=2"))
  type_char(runtime, "r")
  type_char(runtime, "o")
  assert_true(text_present(runtime, "filter=stro  rows=1"))
  // Space is the layer-toggle command while a pane owns the keys. Released here,
  // the press must not hide a layer: the same byte would otherwise be a command
  // and a character at once.
  press(runtime, key=" ")
  assert_true(text_present(runtime, "rows=1"))
  assert_true(!text_present(runtime, "hide=3"))
  runtime.destroy()
}

///|
test "Space means fold in the tree and hide in the list" {
  let runtime = open_app(width=960.0, height=480.0)
  assert_true(text_present(runtime, "hide=2"))
  press(runtime, key=" ")
  assert_true(text_present(runtime, "hide=3"))
  assert_true(text_present(runtime, "[ ] Background"))
  press(runtime, key=" ")
  assert_true(text_present(runtime, "hide=2"))
  // Same key, other pane, other verb: the border says which one is answering.
  press(runtime, key="Tab")
  assert_true(text_present(runtime, "focus: files"))
  assert_true(text_present(runtime, "Files 10"))
  press(runtime, key=" ")
  assert_true(text_present(runtime, "Files 5"))
  press(runtime, key="Enter")
  assert_true(text_present(runtime, "Files 10"))
  runtime.destroy()
}

///|
test "Ctrl chords are the structural commands and no letter is claimed" {
  let runtime = open_app(width=960.0, height=480.0)
  press(runtime, key="n", control=true)
  assert_true(text_present(runtime, "Layers 9/9"))
  press(runtime, key="a", control=true)
  assert_true(text_present(runtime, "Files 11"))
  press(runtime, key="x", control=true)
  assert_true(text_present(runtime, "Layers 8/8"))
  // A bare letter must reach the field, not the model. Nothing claims `n`, so the
  // only way a plain press could change the list is by firing a command.
  press(runtime, key="n")
  assert_true(text_present(runtime, "Layers 8/8"))
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
test "shrinking the window keeps both panes and their row counts" {
  let runtime = open_app(width=960.0, height=480.0)
  runtime.dispatch_event(Resize(@core.Size::new(width=640.0, height=280.0)))
  let (left, right) = boxes(runtime)
  assert_true(left.frame.size.width > 0.0 && right.frame.size.width > 0.0)
  assert_true(right.frame.origin.x >= frame_right(left.frame))
  assert_true(frame_right(right.frame) <= 640.0)
  // The row count in the pane titles is the layout-independent fact: eight layers
  // are still eight layers in a half-width window, so nothing was dropped to fit.
  assert_true(text_present(runtime, "Layers 8/8"))
  assert_true(text_present(runtime, "Files 10"))
  runtime.destroy()
}

///|
test "a keyed row keeps keyboard focus across a head insert" {
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
  press(runtime, key="a", control=true)
  assert_true(
    has_label(
      labels_of(nodes_with_role(runtime, @core.SemanticsRole::TreeItem)),
      "new-0",
    ),
  )
  assert_true(focused_labels(runtime) == before)
  runtime.destroy()
}
