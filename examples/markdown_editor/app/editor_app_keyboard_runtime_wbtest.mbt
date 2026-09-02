///|
test "markdown editor runtime block editing shortcuts update document" {
  let app = MarkdownEditorApp::new()
  app.set_document("Alpha\n\nBeta\n\nGamma")
  app.set_selection(8, None)
  inspect(app.document(), content="Alpha\n\nBeta\n\nGamma")
  let mut runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="d",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(app.document(), content="Alpha\n\nBeta\n\nBeta\n\nGamma")
  app.set_document("Alpha\n\nBeta\n\nGamma")
  app.set_selection(8, None)
  runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="ArrowUp",
        modifiers=@core.KeyModifiers::new(alt=true),
      ),
    ),
  )
  inspect(app.document(), content="Beta\n\nAlpha\n\nGamma")
  app.set_selection(2, None)
  runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="ArrowDown",
        modifiers=@core.KeyModifiers::new(alt=true),
      ),
    ),
  )
  inspect(app.document(), content="Alpha\n\nBeta\n\nGamma")
}

///|
test "markdown editor runtime block keyboard shortcuts transform caret and selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("Intro\nTitle\nFirst\nSecond")
  app.set_selection(8, None)
  let mut runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="2",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(app.document(), content="Intro\n## Title\nFirst\nSecond")
  app.set_selection(9, None)
  runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="6",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(app.document(), content="Intro\n###### Title\nFirst\nSecond")
  app.set_selection(30, Some(@core.TextRange::new(start=19, end=31)))
  runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="u",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(app.document(), content="Intro\n###### Title\n- First\n- Second")
}

///|
test "markdown editor runtime ctrl code block shortcut toggles current line" {
  let app = MarkdownEditorApp::new()
  app.set_document("Intro\nlet x = 1\nTail")
  app.set_selection(8, None)
  let mut runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="k",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(app.document(), content="Intro\n```\nlet x = 1\n```\nTail")
  app.set_selection(12, None)
  runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="k",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(app.document(), content="Intro\nlet x = 1\nTail")
}

///|
test "markdown editor runtime ctrl heading shortcuts transform caret" {
  let app = MarkdownEditorApp::new()
  app.set_document("Intro\nTitle")
  app.set_selection(8, None)
  let mut runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="1",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(app.document(), content="Intro\n# Title")
  app.set_selection(8, None)
  runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="3",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(app.document(), content="Intro\n### Title")
}

///|
test "markdown editor runtime paragraph and quote shortcuts transform blocks" {
  let meta_paragraph_app = MarkdownEditorApp::new()
  meta_paragraph_app.set_document("# Title")
  let meta_paragraph_runtime = meta_paragraph_app.runtime(
    width=980.0,
    height=640.0,
  )
  meta_paragraph_app.set_selection(3, None)
  meta_paragraph_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="0",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(meta_paragraph_app.document(), content="Title")
  let control_paragraph_app = MarkdownEditorApp::new()
  control_paragraph_app.set_document("# Title\n> Quote")
  let control_paragraph_runtime = control_paragraph_app.runtime(
    width=980.0,
    height=640.0,
  )
  control_paragraph_app.set_selection(
    15,
    Some(@core.TextRange::new(start=0, end=15)),
  )
  control_paragraph_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="0",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(control_paragraph_app.document(), content="Title\nQuote")
  let quote_app = MarkdownEditorApp::new()
  quote_app.set_document("First\nSecond")
  let quote_runtime = quote_app.runtime(width=980.0, height=640.0)
  quote_app.set_selection(12, Some(@core.TextRange::new(start=0, end=12)))
  quote_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="9",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(quote_app.document(), content="> First\n> Second")
  let shifted_quote_app = MarkdownEditorApp::new()
  shifted_quote_app.set_document("First\nSecond")
  let shifted_quote_runtime = shifted_quote_app.runtime(
    width=980.0,
    height=640.0,
  )
  shifted_quote_app.set_selection(
    12,
    Some(@core.TextRange::new(start=0, end=12)),
  )
  shifted_quote_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="(",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(shifted_quote_app.document(), content="> First\n> Second")
}

///|
test "markdown editor runtime ctrl shift list shortcuts transform selection" {
  let bullet_app = MarkdownEditorApp::new()
  bullet_app.set_document("First\nSecond")
  let bullet_runtime = bullet_app.runtime(width=980.0, height=640.0)
  bullet_app.set_selection(12, Some(@core.TextRange::new(start=0, end=12)))
  bullet_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="8",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(bullet_app.document(), content="- First\n- Second")
  let shifted_bullet_app = MarkdownEditorApp::new()
  shifted_bullet_app.set_document("First\nSecond")
  let shifted_bullet_runtime = shifted_bullet_app.runtime(
    width=980.0,
    height=640.0,
  )
  shifted_bullet_app.set_selection(
    12,
    Some(@core.TextRange::new(start=0, end=12)),
  )
  shifted_bullet_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="*",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(shifted_bullet_app.document(), content="- First\n- Second")
  let ordered_app = MarkdownEditorApp::new()
  ordered_app.set_document("First\nSecond")
  let ordered_runtime = ordered_app.runtime(width=980.0, height=640.0)
  ordered_app.set_selection(12, Some(@core.TextRange::new(start=0, end=12)))
  ordered_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="7",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(ordered_app.document(), content="1. First\n2. Second")
  let shifted_ordered_app = MarkdownEditorApp::new()
  shifted_ordered_app.set_document("First\nSecond")
  let shifted_ordered_runtime = shifted_ordered_app.runtime(
    width=980.0,
    height=640.0,
  )
  shifted_ordered_app.set_selection(
    12,
    Some(@core.TextRange::new(start=0, end=12)),
  )
  shifted_ordered_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="&",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(shifted_ordered_app.document(), content="1. First\n2. Second")
}

///|
test "markdown editor runtime enter outdents nested empty list marker" {
  let app = MarkdownEditorApp::new()
  app.set_document("- parent\n  - ")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=2.0),
          y=112.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  inspect(app.document(), content="- parent\n- ")
  inspect(runtime.focused_text_input().caret, content="11")
}

///|
test "markdown editor runtime tab indents focused line" {
  let app = MarkdownEditorApp::new()
  app.set_document("- item")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=2.0),
          y=84.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Tab")),
  )
  inspect(app.document(), content="  - item")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="Tab",
        modifiers=@core.KeyModifiers::new(shift=true),
      ),
    ),
  )
  inspect(app.document(), content="- item")
}

///|
test "markdown editor indent and outdent actions preserve history" {
  let app = MarkdownEditorApp::new()
  app.set_document("Intro\n- one\n- two\nTail")
  app.set_selection(17, Some(@core.TextRange::new(start=6, end=17)))
  app.apply_action("indent-lines")
  inspect(app.document(), content="Intro\n  - one\n  - two\nTail")
  guard app.selection.selection is Some(indented_selection) else {
    fail("expected indented line selection")
  }
  inspect(indented_selection.start, content="6")
  inspect(indented_selection.end, content="21")
  assert_true(app.undo())
  inspect(app.document(), content="Intro\n- one\n- two\nTail")
  assert_true(app.redo())
  inspect(app.document(), content="Intro\n  - one\n  - two\nTail")

  app.apply_action("outdent-lines")
  inspect(app.document(), content="Intro\n- one\n- two\nTail")
}

///|
test "markdown editor runtime bracket shortcuts indent and outdent lines" {
  let meta_app = MarkdownEditorApp::new()
  meta_app.set_document("- item")
  meta_app.set_selection(2, None)
  let meta_runtime = meta_app.runtime(width=980.0, height=640.0)
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="]",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(meta_app.document(), content="  - item")
  inspect(meta_app.selection_caret(), content="4")
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="[",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(meta_app.document(), content="- item")
  inspect(meta_app.selection_caret(), content="2")

  let control_app = MarkdownEditorApp::new()
  control_app.set_document("Alpha\nBeta")
  control_app.set_selection(10, Some(@core.TextRange::new(start=0, end=10)))
  let control_runtime = control_app.runtime(width=980.0, height=640.0)
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="]",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(control_app.document(), content="  Alpha\n  Beta")
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="[",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(control_app.document(), content="Alpha\nBeta")
}

///|
test "markdown editor runtime undo restores input transform caret" {
  let app = MarkdownEditorApp::new()
  app.set_document("")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(
          x=app.editor_content_x(980.0, inner_x=2.0),
          y=84.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("#")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText(" ")),
  )
  inspect(app.document(), content="# ")
  inspect(runtime.focused_text_input().caret, content="2")
  let undo = runtime.dispatch_focused_text_command(@core.CommandIntent::Undo)
  assert_true(undo.handled)
  assert_true(undo.changed)
  // The merge window groups the two contiguous keystrokes, so one undo
  // reverts the whole typed run.
  inspect(app.document(), content="")
  inspect(runtime.focused_text_input().caret, content="0")
  let redo = runtime.dispatch_focused_text_command(@core.CommandIntent::Redo)
  assert_true(redo.handled)
  assert_true(redo.changed)
  inspect(app.document(), content="# ")
  inspect(runtime.focused_text_input().caret, content="2")
}

///|
test "markdown editor runtime arrow up down moves caret across lines" {
  let app = MarkdownEditorApp::new()
  app.set_document("- Alpha\n- Beta\n- Gamma")
  let runtime = app.runtime(width=980.0, height=640.0)
  // 点击 "Beta" 行设置 focus 和 caret
  guard markdown_editor_text_frame(runtime.draw_commands(), "Beta")
    is Some(frame) else {
    fail("expected rendered Beta text")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(
          x=frame.origin.x + frame.size.width / 2.0,
          y=frame.origin.y + frame.size.height / 2.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  let clicked_caret = app.selection_caret()
  // 点击后 caret 应在 "Beta" block 范围内（source 8..14）
  inspect(clicked_caret >= 8 && clicked_caret <= 14, content="true")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowUp")),
  )
  // ArrowUp 后 caret 应该移到 "Alpha" block（source 0..7）
  let up_caret = app.selection_caret()
  inspect(up_caret <= 7, content="true")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowDown")),
  )
  // ArrowDown 后 caret 应该回到 "Beta" block（source 8..14）
  let down_caret = app.selection_caret()
  inspect(down_caret >= 8 && down_caret <= 14, content="true")
}

///|
test "markdown editor arrow keys navigate across empty line heading and code block" {
  let sample = "# Editor notes\n\nThis **WYSIWYG** surface keeps `Markdown` as the saved value.\n\n## Today\n- Type into the formatted page\n- Use shortcuts or contextual controls\n- Open source only when needed\n\n> Unsupported syntax stays editable as plain text.\n\n```\nlet saved = markdown\n```\n\n---"
  let app = MarkdownEditorApp::new()
  app.set_document(sample)
  let runtime = app.runtime(width=980.0, height=640.0)
  // 场景2: 点击 "Today" 标题文本，ArrowUp 应该能移到上方
  guard markdown_editor_text_frame(runtime.draw_commands(), "Today")
    is Some(today_frame) else {
    fail("expected rendered Today text")
  }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(
          x=today_frame.origin.x + 2.0,
          y=today_frame.origin.y + today_frame.size.height / 2.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  let today_caret = runtime.focused_text_input().caret
  inspect(today_caret > 70, content="true")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowUp")),
  )
  let up_from_today = runtime.focused_text_input().caret
  inspect(up_from_today < today_caret, content="true")

  // 场景1: 光标在空行时 ArrowDown 应该能移到下一个 block
  // 空行位于 "# Editor notes" 和 "This WYSIWYG..." 之间
  // 先点击 "Editor notes" 标题，End 到行尾，ArrowDown 到空行，再 ArrowDown 到段落
  let app2 = MarkdownEditorApp::new()
  app2.set_document(sample)
  let runtime2 = app2.runtime(width=980.0, height=640.0)
  guard markdown_editor_text_frame(runtime2.draw_commands(), "Editor notes")
    is Some(h1_frame) else {
    fail("expected rendered Editor notes text")
  }
  runtime2.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(
          x=h1_frame.origin.x + 2.0,
          y=h1_frame.origin.y + h1_frame.size.height / 2.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime2.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  let h1_end_caret = runtime2.focused_text_input().caret
  // ArrowDown 到空行
  runtime2.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowDown")),
  )
  let empty_line_caret = runtime2.focused_text_input().caret
  inspect(empty_line_caret > h1_end_caret, content="true")
  // ArrowDown 从空行移到下一个段落
  runtime2.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowDown")),
  )
  let down_from_empty = runtime2.focused_text_input().caret
  inspect(down_from_empty > empty_line_caret, content="true")

  // 场景3: 点击代码块区域（"let saved = markdown"），ArrowUp 应该能移到上方
  let app3 = MarkdownEditorApp::new()
  app3.set_document(sample)
  let runtime3 = app3.runtime(width=980.0, height=640.0)
  guard markdown_editor_text_frame(
      runtime3.draw_commands(),
      "let saved = markdown",
    )
    is Some(code_frame) else {
    fail("expected rendered code block text")
  }
  runtime3.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@geometry.Point::new(
          x=code_frame.origin.x + 2.0,
          y=code_frame.origin.y + code_frame.size.height / 2.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  let code_caret = runtime3.focused_text_input().caret
  runtime3.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowUp")),
  )
  let up_from_code = runtime3.focused_text_input().caret
  // ArrowUp 后 caret 应该变化（从代码块移到上方的引用块或空行）
  inspect(up_from_code < code_caret, content="true")
}
