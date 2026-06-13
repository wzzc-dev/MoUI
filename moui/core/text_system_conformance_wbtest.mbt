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
test "paragraph layout contract exposes line metrics selection rects and hit testing" {
  let text = "alpha beta gamma"
  let font = FontSpec::new(size=16.0, weight=400)
  let system = fixed_advance_text_system(10.0)
  let layout = system.layout_paragraph(
    TextLayoutInput::new(text~, font~, max_width=60.0),
  )
  assert_true(layout.metadata.paragraph_layout_available)
  assert_true(layout.metadata.line_metrics_available)
  assert_true(layout.metadata.selection_rects_available)
  assert_true(layout.metadata.hit_test_available)
  assert_false(layout.metadata.native_paragraph_ready)
  assert_false(layout.metadata.bidi_visual_order_ready)
  inspect(layout.line_count(), content="3")
  inspect(
    layout.caret_rects.length(),
    content="\{text.to_array().length() + 1}",
  )
  assert_true(layout.size.height > font.size * 2.0)
  assert_true(layout.lines[0].text_range.start == 0)
  assert_true(layout.lines[0].text_range.end < text.to_array().length())
  assert_true(layout.lines[1].origin.y > layout.lines[0].origin.y)
  assert_true(layout.lines[1].baseline > layout.lines[0].baseline)

  let rects = layout.selection_rects(
    TextRange::new(start=0, end=text.to_array().length()),
  )
  assert_true(rects.length() >= 3)
  for rect in rects {
    assert_true(rect.size.width > 0.0)
    assert_true(rect.size.height > 0.0)
  }
  let second_line_y = layout.lines[1].origin.y + 1.0
  let hit = layout.hit_test(Point::new(x=999.0, y=second_line_y))
  inspect(hit.line_index, content="1")
  assert_true(hit.offset >= layout.lines[1].text_range.start)
  assert_true(hit.offset <= layout.lines[1].text_range.end)
  let collapsed = layout.selection_rects(TextRange::collapsed(hit.offset))
  inspect(collapsed.length(), content="1")
}
