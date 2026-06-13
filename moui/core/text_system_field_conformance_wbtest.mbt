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
