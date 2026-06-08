///|
fn text_conformance_carets_are_monotonic(carets : Array[Double]) -> Bool {
  if carets.length() <= 1 {
    return true
  }
  for index in 1..<carets.length() {
    if carets[index] < carets[index - 1] {
      return false
    }
  }
  true
}

///|
fn assert_text_layout_invariants(
  system : TextSystem,
  text : String,
  font : FontSpec,
) -> Unit raise {
  let layout = system.measure_text(TextLayoutInput::new(text~, font~))
  inspect(
    layout.caret_positions.length(),
    content="\{text.to_array().length() + 1}",
  )
  inspect(
    text_conformance_carets_are_monotonic(layout.caret_positions),
    content="true",
  )
  if text == "" {
    inspect(layout.size.width, content="0")
  } else {
    inspect(layout.size.width > 0.0, content="true")
  }
  inspect(layout.size.height > 0.0, content="true")
  inspect(layout.baseline > 0.0, content="true")
  let clamped = system.measure_text(
    TextLayoutInput::new(text~, font~, max_width=18.0),
  )
  inspect(clamped.size.width <= 18.0, content="true")
  inspect(
    clamped.caret_positions.length(),
    content="\{text.to_array().length() + 1}",
  )
  inspect(
    text_conformance_carets_are_monotonic(clamped.caret_positions),
    content="true",
  )
  for caret in clamped.caret_positions {
    inspect(caret <= 18.0, content="true")
  }
}

///|
fn assert_fallback_cluster_carets(
  text : String,
  start : Int,
  end : Int,
) -> Unit raise {
  let font = FontSpec::new(size=16.0, weight=400)
  let layout = TextSystem::fallback().measure_text(
    TextLayoutInput::new(text~, font~),
  )
  inspect(
    layout.caret_positions.length(),
    content="\{text.to_array().length() + 1}",
  )
  assert_true(text_conformance_carets_are_monotonic(layout.caret_positions))
  assert_true(start >= 0)
  assert_true(end > start + 1)
  assert_true(end < layout.caret_positions.length())
  let anchor = layout.caret_positions[start]
  for index in (start + 1)..<end {
    assert_true(layout.caret_positions[index] == anchor)
  }
  assert_true(layout.caret_positions[end] > anchor)
}

///|
fn assert_cluster_caret_movement(
  text : String,
  start : Int,
  end : Int,
) -> Unit raise {
  let from_end = move_text_caret(text, end, None, MoveLeft, extend=false)
  inspect(from_end.caret, content="\{start}")
  assert_true(from_end.selection is None)
  let from_start = move_text_caret(text, start, None, MoveRight, extend=false)
  inspect(from_start.caret, content="\{end}")
  assert_true(from_start.selection is None)
  let from_inside_left = move_text_caret(
    text,
    start + 1,
    None,
    MoveLeft,
    extend=false,
  )
  inspect(from_inside_left.caret, content="\{start}")
  let from_inside_right = move_text_caret(
    text,
    end - 1,
    None,
    MoveRight,
    extend=false,
  )
  inspect(from_inside_right.caret, content="\{end}")
  let extended = move_text_caret(text, start, None, MoveRight, extend=true)
  inspect(extended.caret, content="\{end}")
  guard extended.selection is Some(selection) else {
    fail("expected cluster selection")
  }
  let selection = selection.normalized()
  inspect(selection.start, content="\{start}")
  inspect(selection.end, content="\{end}")
}

///|
fn fixed_advance_text_system(advance : Double) -> TextSystem {
  TextSystem::new(id="test-fixed-advance-conformance", measure=input => {
    let carets : Array[Double] = [0.0]
    let mut cursor = 0.0
    for _ in input.text {
      cursor = cursor + advance
      carets.push(cursor)
    }
    let width = match input.max_width {
      Some(max_width) => cursor.min(max_width)
      None => cursor
    }
    match input.max_width {
      Some(max_width) =>
        for index in 0..<carets.length() {
          carets[index] = carets[index].min(max_width)
        }
      None => ()
    }
    {
      size: Size::new(width~, height=input.font.size * 1.25),
      baseline: input.font.size * 0.8,
      caret_positions: carets,
    }
  })
}

///|
fn focus_text_conformance_field(runtime : RuntimeState) -> Unit {
  runtime.dispatch_event(
    Pointer(
      PointerEvent::new(
        position=Point::new(x=10.0, y=10.0),
        phase=PointerPhase::Down,
      ),
    ),
  )
}

///|
fn mixed_rich_text_conformance_editor(value : Binding[String]) -> ViewSpec {
  ViewSpec::RichTextEditorSpec({
    key: None,
    value,
    placeholder: "Write",
    size: Size::new(width=320.0, height=220.0),
    format: _text => {
      RichTextDocument::new(blocks=[
        RichTextBlock::new(
          runs=[
            RichTextRun::new(
              text="你🙂 אבג",
              source_range=Some({ start: 2, end: 8 }),
            ),
          ],
          source_range=Some({ start: 0, end: 8 }),
          content_range=Some({ start: 2, end: 8 }),
        ),
      ])
    },
    font: FontSpec::new(size=16.0, weight=400),
    foreground: Color::black(),
    placeholder_color: Color::gray(),
    background: Brush::solid(Color::white()),
    border: None,
    focused_border: None,
    cursor_color: Color::blue(),
    corner_radius: 4.0,
    on_selection_change: None,
    on_prefix_click: None,
    input_transform: None,
    accepts_tab_input: false,
  })
}

///|
test "fallback text system conforms for unicode samples" {
  let system = TextSystem::fallback()
  let font = FontSpec::new(size=16.0, weight=400)
  assert_text_layout_invariants(system, "", font)
  assert_text_layout_invariants(system, "abc", font)
  assert_text_layout_invariants(system, "你好", font)
  assert_text_layout_invariants(system, "🙂", font)
  assert_text_layout_invariants(system, "☕", font)
  assert_text_layout_invariants(system, "☕️", font)
  assert_text_layout_invariants(system, "👩‍💻", font)
  assert_text_layout_invariants(system, "a你🙂b", font)
  assert_text_layout_invariants(system, "text 👩‍💻 🙂", font)
  assert_text_layout_invariants(system, "abc אבג def", font)
}

///|
test "fallback text system stabilizes representative cluster carets" {
  assert_fallback_cluster_carets("e\u{0301}", 0, 2)
  assert_fallback_cluster_carets("☕️", 0, 2)
  assert_fallback_cluster_carets("👩‍💻", 0, 3)
  assert_fallback_cluster_carets("👍🏽", 0, 2)
  assert_fallback_cluster_carets("1️⃣", 0, 3)
  assert_fallback_cluster_carets("\u{1F1FA}\u{1F1F8}", 0, 2)
  assert_fallback_cluster_carets("\u{1F3F4}\u{E0067}\u{E0062}\u{E007F}", 0, 4)
  assert_fallback_cluster_carets("\u{0600}\u{0628}\u{0651}", 0, 3)
  assert_fallback_cluster_carets("\u{0E01}\u{0E34}", 0, 2)
  assert_fallback_cluster_carets("\u{0D9A}\u{0DCF}", 0, 2)
  assert_fallback_cluster_carets("\u{1000}\u{1039}\u{1001}", 0, 3)
  assert_fallback_cluster_carets("\u{1100}\u{1161}\u{11A8}", 0, 3)
  assert_fallback_cluster_carets("A\u{1F1FA}\u{1F1F8}B", 1, 3)
}

///|
test "text caret movement skips representative cluster interiors" {
  assert_cluster_caret_movement("e\u{0301}", 0, 2)
  assert_cluster_caret_movement("A☕️B", 1, 3)
  assert_cluster_caret_movement("A👩‍💻B", 1, 4)
  assert_cluster_caret_movement("A👍🏽B", 1, 3)
  assert_cluster_caret_movement("A1️⃣B", 1, 4)
  assert_cluster_caret_movement("A\u{1F1FA}\u{1F1F8}B", 1, 3)
  assert_cluster_caret_movement("A\u{1F3F4}\u{E0067}\u{E0062}\u{E007F}B", 1, 5)
  assert_cluster_caret_movement("A\u{0600}\u{0628}\u{0651}B", 1, 4)
  assert_cluster_caret_movement("A\u{0E01}\u{0E34}B", 1, 3)
  assert_cluster_caret_movement("A\u{1100}\u{1161}\u{11A8}B", 1, 4)
}

///|
test "grapheme boundary contract covers ranges deletes and utf8 offsets" {
  let text = "A👩‍💻B"
  let boundaries = TextGraphemeBoundaries::new(text~)
  inspect(boundaries.length(), content="5")
  inspect(boundaries.cluster_count(), content="3")
  inspect(boundaries.is_boundary(1), content="true")
  inspect(boundaries.is_boundary(2), content="false")
  inspect(boundaries.previous_boundary(4), content="1")
  inspect(boundaries.next_boundary(1), content="4")
  inspect(boundaries.floor_boundary(3), content="1")
  inspect(boundaries.ceil_boundary(2), content="4")
  inspect(boundaries.nearest_boundary(2), content="1")
  inspect(boundaries.nearest_boundary(3), content="4")
  let expanded = boundaries.normalize_range(TextRange::new(start=2, end=3))
  inspect(expanded.start, content="1")
  inspect(expanded.end, content="4")
  let collapsed = boundaries.normalize_range(TextRange::collapsed(3))
  inspect(collapsed.start, content="4")
  inspect(collapsed.end, content="4")
  let delete = boundaries.delete_range(4, 1, 0)
  inspect(delete.start, content="1")
  inspect(delete.end, content="4")
  inspect(boundaries.utf8_offset(4), content="12")
  inspect(boundaries.utf8_offset(5), content="13")
}

///|
test "text field deletion respects grapheme boundaries" {
  let backward = State::new("A👩‍💻B")
  let backward_runtime = RuntimeState::new_spec(
    root=test_text_field(backward.binding()),
    size=Size::new(width=220.0, height=60.0),
  )
  focus_text_conformance_field(backward_runtime)
  backward_runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="ArrowLeft")))
  inspect(backward_runtime.focused_text_input().caret, content="4")
  backward_runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Backspace")))
  inspect(backward.get(), content="AB")
  inspect(backward_runtime.focused_text_input().caret, content="1")

  let forward = State::new("A👩‍💻B")
  let forward_runtime = RuntimeState::new_spec(
    root=test_text_field(forward.binding()),
    size=Size::new(width=220.0, height=60.0),
  )
  focus_text_conformance_field(forward_runtime)
  forward_runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Home")))
  forward_runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="ArrowRight")))
  inspect(forward_runtime.focused_text_input().caret, content="1")
  forward_runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Delete")))
  inspect(forward.get(), content="AB")
  inspect(forward_runtime.focused_text_input().caret, content="1")
}

///|
test "rich text hit testing snaps grapheme cluster interiors" {
  let font = FontSpec::new(size=16.0, weight=400)
  let system = fixed_advance_text_system(10.0)
  inspect(
    rich_text_run_visual_offset_at_x("A👩‍💻B", font, 22.0, 0.0, system),
    content="1",
  )
  inspect(
    rich_text_run_visual_offset_at_x("A👩‍💻B", font, 33.0, 0.0, system),
    content="4",
  )
}

///|
test "text field conformance covers cjk emoji replacement and deletion" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=180.0, height=60.0),
  )
  focus_text_conformance_field(runtime)
  runtime.dispatch_event(TextInput(InsertText("a你🙂b")))
  inspect(state.get(), content="a你🙂b")
  inspect(runtime.focused_text_input().caret, content="4")
  runtime.dispatch_event(TextInput(DeleteRange(TextRange::new(start=1, end=3))))
  inspect(state.get(), content="ab")
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Home")))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(key="End", modifiers=KeyModifiers::new(shift=true)),
    ),
  )
  runtime.dispatch_event(TextInput(InsertText("你好🙂")))
  inspect(state.get(), content="你好🙂")
  inspect(runtime.focused_text_input().caret, content="3")
}

///|
test "text field conformance covers unicode undo redo history" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=220.0, height=60.0),
  )
  focus_text_conformance_field(runtime)
  runtime.dispatch_event(TextInput(InsertText("你")))
  runtime.dispatch_event(TextInput(InsertText("☕️")))
  runtime.dispatch_event(TextInput(InsertText("👩‍💻")))
  inspect(state.get(), content="你☕️👩‍💻")
  inspect(runtime.focused_text_input().caret, content="6")
  let undo = runtime.dispatch_focused_text_command(Undo)
  assert_true(undo.handled)
  assert_true(undo.changed)
  inspect(state.get(), content="你☕️")
  inspect(runtime.focused_text_input().caret, content="3")
  let redo = runtime.dispatch_focused_text_command(Redo)
  assert_true(redo.handled)
  assert_true(redo.changed)
  inspect(state.get(), content="你☕️👩‍💻")
  inspect(runtime.focused_text_input().caret, content="6")
}

///|
test "text field conformance keeps mixed bidi caret movement logical" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=240.0, height=60.0),
  )
  focus_text_conformance_field(runtime)
  runtime.dispatch_event(TextInput(InsertText("abc אבג def")))
  inspect(runtime.focused_text_input().caret, content="11")
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="ArrowLeft")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="ArrowLeft")))
  inspect(runtime.focused_text_input().caret, content="9")
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowLeft",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowLeft",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  let input = runtime.focused_text_input()
  inspect(input.caret, content="7")
  guard input.selection is Some(selection) else {
    fail("expected bidi logical selection")
  }
  inspect(selection.normalized().start, content="7")
  inspect(selection.normalized().end, content="9")
  runtime.dispatch_event(TextInput(InsertText("ZZ")))
  inspect(state.get(), content="abc אבגZZef")
}

///|
test "text field conformance commits unicode composition over selection" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=220.0, height=60.0),
  )
  focus_text_conformance_field(runtime)
  runtime.dispatch_event(TextInput(InsertText("abc🙂def")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="Home")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="ArrowRight")))
  runtime.dispatch_event(Keyboard(KeyboardEvent::new(key="ArrowRight")))
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowRight",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowRight",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  runtime.dispatch_event(TextInput(CompositionStart))
  runtime.dispatch_event(
    TextInput(
      CompositionUpdate(
        CompositionUpdate::new(
          text="你☕️",
          cursor=Some(TextRange::new(start=3, end=3)),
        ),
      ),
    ),
  )
  let composing = runtime.focused_text_input()
  guard composing.composition is Some(composition) else {
    fail("expected unicode composition preview")
  }
  inspect(composition, content="你☕️")
  runtime.dispatch_event(TextInput(CompositionEnd("你☕️")))
  inspect(state.get(), content="ab你☕️def")
  inspect(runtime.focused_text_input().caret, content="5")
  let undo = runtime.dispatch_focused_text_command(Undo)
  assert_true(undo.handled)
  inspect(state.get(), content="abc🙂def")
}

///|
test "text field ime anchor follows unicode composition cursor" {
  let state = State::new("")
  let runtime = RuntimeState::new_spec(
    root=test_text_field(state.binding()),
    size=Size::new(width=200.0, height=60.0),
  )
  runtime.set_text_system(fixed_advance_text_system(7.0))
  focus_text_conformance_field(runtime)
  runtime.dispatch_event(TextInput(CompositionStart))
  runtime.dispatch_event(
    TextInput(
      CompositionUpdate(
        CompositionUpdate::new(
          text="你🙂a",
          cursor=Some(TextRange::new(start=2, end=2)),
        ),
      ),
    ),
  )
  let input = runtime.focused_text_input()
  guard input.composition is Some(composition) else {
    fail("expected unicode composition")
  }
  inspect(composition, content="你🙂a")
  inspect(input.caret_rect.origin.x, content="24")
}

///|
test "rich text conformance maps unicode source carets and selections" {
  let source = State::new("# 你🙂 אבג")
  let runtime = RuntimeState::new_spec(
    root=mixed_rich_text_conformance_editor(source.binding()),
    size=Size::new(width=320.0, height=220.0),
  )
  runtime.set_text_system(fixed_advance_text_system(8.0))
  focus_text_conformance_field(runtime)
  let input = runtime.focused_text_input()
  inspect(input.caret, content="2")
  inspect(input.caret_rect.origin.x, content="14")
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowRight",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  runtime.dispatch_event(
    Keyboard(
      KeyboardEvent::new(
        key="ArrowRight",
        modifiers=KeyModifiers::new(shift=true),
      ),
    ),
  )
  let selected = runtime.focused_text_input()
  guard selected.selection is Some(selection) else {
    fail("expected rich text unicode selection")
  }
  inspect(selection.normalized().start, content="2")
  inspect(selection.normalized().end, content="4")
  let commands = runtime.build_draw_commands()
  assert_true(
    commands.any(command => {
      match command {
        FillRect(_, color) => color == Color::blue().with_alpha(0.18)
        _ => false
      }
    }),
  )
  let content = rich_text_editor_content_rect(
    Rect::new(x=0.0, y=0.0, width=320.0, height=220.0),
  )
  let document = RichTextDocument::new(blocks=[
    RichTextBlock::new(
      runs=[
        RichTextRun::new(
          text="你🙂 אבג",
          source_range=Some({ start: 2, end: 8 }),
        ),
      ],
      source_range=Some({ start: 0, end: 8 }),
      content_range=Some({ start: 2, end: 8 }),
    ),
  ])
  guard rich_text_document_caret_rect_at_source(
      document,
      8,
      content,
      FontSpec::new(size=16.0, weight=400),
      text_system=fixed_advance_text_system(8.0),
    )
    is Some(end_rect) else {
    fail("expected mapped unicode rich text caret")
  }
  inspect(end_rect.origin.x, content="62")
}
