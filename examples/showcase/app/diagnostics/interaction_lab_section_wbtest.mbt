///|
priv struct SelectionLab {
  runtime : @runtime.AppRuntime
  viewport : @core.Rect
}

///|
fn selection_lab_semantics_frame(
  runtime : @runtime.AppRuntime,
  id : String,
) -> @core.Rect {
  let mut found : @core.Rect? = None
  match runtime.read_semantics() {
    Ok(Full(snapshot)) =>
      for node in snapshot.nodes() {
        match node.semantic_id {
          Some(value) => if value.value() == id { found = Some(node.frame) }
          None => ()
        }
      }
    _ => abort("expected a full semantics snapshot")
  }
  found.unwrap_or_else(() => abort("missing semantic node: " + id))
}

///|
fn selection_lab() -> SelectionLab {
  let model = ShowcaseModel::new()
  let theme = @views.default_theme()
  let runtime = @runtime.AppRuntime::new_view(
    root=model.text_selection_card(theme, 300.0, model.selection_text),
    size=@geometry.Size::new(width=360.0, height=320.0),
  )
  ignore(runtime.draw_frame())
  {
    runtime,
    viewport: selection_lab_semantics_frame(
      runtime, "showcase.text-selection-viewport",
    ),
  }
}

///|
fn SelectionLab::point(
  self : SelectionLab,
  dx : Double,
  dy : Double,
) -> @core.Point {
  let viewport = self.viewport
  @core.Point::new(x=viewport.origin.x + dx, y=viewport.origin.y + dy)
}

///|
fn SelectionLab::tap(self : SelectionLab, dx : Double, dy : Double) -> Unit {
  let point = self.point(dx, dy)
  self.runtime.dispatch_event(
    Pointer(@core.PointerEvent::new(position=point, phase=Down)),
  )
  self.runtime.dispatch_event(
    Pointer(@core.PointerEvent::new(position=point, phase=Up)),
  )
  self.redraw()
}

///|
fn SelectionLab::press(self : SelectionLab, dx : Double, dy : Double) -> Unit {
  self.runtime.dispatch_event(
    Pointer(@core.PointerEvent::new(position=self.point(dx, dy), phase=Down)),
  )
  self.redraw()
}

///|
fn SelectionLab::drag_to(self : SelectionLab, dx : Double, dy : Double) -> Unit {
  let point = self.point(dx, dy)
  self.runtime.dispatch_event(
    Pointer(@core.PointerEvent::new(position=point, phase=Move)),
  )
  self.runtime.dispatch_event(
    Pointer(@core.PointerEvent::new(position=point, phase=Up)),
  )
  self.redraw()
}

///|
fn SelectionLab::wait(self : SelectionLab, time_ms : Double) -> Unit {
  self.runtime.advance_time(time_ms)
  self.redraw()
}

///|
fn SelectionLab::redraw(self : SelectionLab) -> Unit {
  ignore(self.runtime.draw_frame())
}

///|
fn SelectionLab::selected(self : SelectionLab) -> String {
  selected_text_of(self.runtime.focused_text_input())
}

///|
fn selected_text_of(state : @core.TextInputState) -> String {
  match state.selection {
    Some(range) =>
      String::from_array(state.text.to_array()[range.start:range.end])
    None => ""
  }
}

///|
/// The passage is app-owned and fixed, so a test can name its first line
/// without hard-coding how far the fallback text system measures each glyph.
fn selection_passage_first_line() -> String {
  showcase_selection_passage_lines()[0]
}

///|
test "Interaction Lab double-click selects the word under the pointer" {
  let lab = selection_lab()
  lab.tap(6.0, 6.0)
  assert_true(lab.runtime.focused_text_input().focused)
  lab.wait(120.0)
  lab.tap(6.0, 6.0)
  assert_eq(lab.selected(), "Pointer")
}

///|
test "Interaction Lab triple-click selects the whole line, not the paragraph" {
  let lab = selection_lab()
  lab.tap(6.0, 6.0)
  lab.wait(120.0)
  lab.tap(6.0, 6.0)
  lab.wait(120.0)
  lab.tap(6.0, 6.0)
  let selected = lab.selected()
  assert_eq(selected, selection_passage_first_line())
  assert_false(selected.contains("\n"))
}

///|
test "Interaction Lab caret drag extends the selection inside one line" {
  let lab = selection_lab()
  lab.press(6.0, 6.0)
  let anchor = lab.runtime.focused_text_input().caret
  lab.drag_to(lab.viewport.size.width - 12.0, 6.0)
  match lab.runtime.focused_text_input().selection {
    Some(range) => {
      assert_eq(range.start, anchor)
      assert_true(range.end > range.start)
      // A drag along the first row never spills across the hard line break.
      assert_true(range.end <= selection_passage_first_line().length())
    }
    None => fail("a pointer drag must leave a range, not a collapsed caret")
  }
}

///|
test "Interaction Lab scrolls the field to reveal a caret past its edge" {
  let lab = selection_lab()
  let before = selection_lab_semantics_frame(
    lab.runtime,
    "showcase.text-selection",
  )
  lab.tap(6.0, 6.0)
  // Walk to the end of the passage. The last rows sit below the viewport's
  // bottom edge, so only the scrolling ancestor can make them visible; the
  // field's own internal viewport is already at its limit there. The count is
  // deliberately generous because the field is narrow enough to wrap, and
  // extra presses clamp at the document end instead of overshooting.
  for i = 0; i < 30; i = i + 1 {
    lab.runtime.dispatch_event(
      Keyboard(@core.KeyboardEvent::new(key="ArrowDown")),
    )
  }
  lab.redraw()
  let after = selection_lab_semantics_frame(
    lab.runtime,
    "showcase.text-selection",
  )
  assert_true(after.origin.y < before.origin.y)
  let caret = lab.runtime.focused_text_input().caret_rect
  let viewport = lab.viewport
  let caret_bottom = caret.origin.y + caret.size.height
  let viewport_bottom = viewport.origin.y + viewport.size.height
  assert_true(caret.origin.y >= viewport.origin.y - 1.0)
  assert_true(caret_bottom <= viewport_bottom + 1.0)
}
