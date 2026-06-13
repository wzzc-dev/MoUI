///|
test "markdown editor runtime inline keyboard shortcut toggles selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("Text bold")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(9, Some(@core.TextRange::new(start=5, end=9)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="b",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(app.document(), content="Text **bold**")
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="b",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(app.document(), content="Text bold")
}

///|
test "markdown editor runtime block editing shortcuts update document" {
  let app = MarkdownEditorApp::new()
  app.set_document("Alpha\nBeta\nGamma")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(8, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="d",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(app.document(), content="Alpha\nBeta\nBeta\nGamma")
  app.set_document("Alpha\nBeta\nGamma")
  app.set_selection(8, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="ArrowUp",
        modifiers=@core.KeyModifiers::new(alt=true),
      ),
    ),
  )
  inspect(app.document(), content="Beta\nAlpha\nGamma")
  app.set_selection(2, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="ArrowDown",
        modifiers=@core.KeyModifiers::new(alt=true),
      ),
    ),
  )
  inspect(app.document(), content="Alpha\nBeta\nGamma")
}

///|
test "markdown editor runtime ctrl inline shortcuts toggle selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("Text bold word")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(9, Some(@core.TextRange::new(start=5, end=9)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="b",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(app.document(), content="Text **bold** word")
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="b",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(app.document(), content="Text bold word")
  app.set_selection(14, Some(@core.TextRange::new(start=10, end=14)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="i",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(app.document(), content="Text bold *word*")
}

///|
test "markdown editor runtime ctrl code and strike shortcuts toggle selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("Text code old")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(9, Some(@core.TextRange::new(start=5, end=9)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="e",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(app.document(), content="Text `code` old")
  app.set_selection(11, Some(@core.TextRange::new(start=6, end=10)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="e",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(app.document(), content="Text code old")
  app.set_selection(13, Some(@core.TextRange::new(start=10, end=13)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="x",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(app.document(), content="Text code ~~old~~")
}

///|
test "markdown editor runtime typed marker wraps tracked selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("bold")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="a",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("**")),
  )
  inspect(app.document(), content="**bold**")
  let input = runtime.focused_text_input()
  inspect(input.caret, content="6")
  guard input.selection is Some(selection) else {
    fail("expected wrapped selection")
  }
  inspect(selection.start, content="2")
  inspect(selection.end, content="6")
}

///|
test "markdown editor runtime underscore marker wraps tracked selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("bold")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="a",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("__")),
  )
  inspect(app.document(), content="__bold__")
  let input = runtime.focused_text_input()
  inspect(input.caret, content="6")
  guard input.selection is Some(selection) else {
    fail("expected wrapped selection")
  }
  inspect(selection.start, content="2")
  inspect(selection.end, content="6")
}

///|
test "markdown editor runtime underline italic marker wraps tracked selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("old")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="a",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("_")),
  )
  inspect(app.document(), content="_old_")
  let input = runtime.focused_text_input()
  inspect(input.caret, content="4")
  guard input.selection is Some(selection) else {
    fail("expected wrapped selection")
  }
  inspect(selection.start, content="1")
  inspect(selection.end, content="4")
}

///|
test "markdown editor runtime link strike and image shortcuts use tracked selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("Text link old logo")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(9, Some(@core.TextRange::new(start=5, end=9)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="l",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(app.document(), content="Text [link](https://example.com) old logo")
  app.set_selection(36, Some(@core.TextRange::new(start=33, end=36)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="x",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(
    app.document(),
    content="Text [link](https://example.com) ~~old~~ logo",
  )
  app.set_selection(45, Some(@core.TextRange::new(start=41, end=45)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="i",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(
    app.document(),
    content="Text [link](https://example.com) ~~old~~ ![logo](image.png)",
  )
}

///|
test "markdown editor runtime ctrl k wraps tracked selection as link" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit docs today")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(10, Some(@core.TextRange::new(start=6, end=10)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="k",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(app.document(), content="Visit [docs](https://example.com) today")
  let editor_selection = app.selection.get()
  inspect(editor_selection.caret, content="11")
  guard editor_selection.selection is Some(selection) else {
    fail("expected linked selection")
  }
  inspect(selection.start, content="7")
  inspect(selection.end, content="11")
}

///|
test "markdown editor runtime ctrl image shortcut wraps tracked selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("Insert logo")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="i",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  inspect(app.document(), content="Insert ![logo](image.png)")
}

///|
test "markdown editor runtime block keyboard shortcuts transform caret and selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("Intro\nTitle\nFirst\nSecond")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(8, None)
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
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(8, None)
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
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(8, None)
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
        position=@core.Point::new(x=28.0, y=112.0),
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
        position=@core.Point::new(x=28.0, y=84.0),
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
  guard app.selection.get().selection is Some(indented_selection) else {
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
test "markdown editor runtime backspace removes hidden heading marker" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  inspect(runtime.focused_text_input().caret, content="2")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Backspace")),
  )
  inspect(app.document(), content="Title")
  inspect(runtime.focused_text_input().caret, content="0")
}

///|
test "markdown editor runtime delete removes hidden block marker" {
  let heading_app = MarkdownEditorApp::new()
  heading_app.set_document("# Title")
  let heading_runtime = heading_app.runtime(width=980.0, height=640.0)
  heading_runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  heading_runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  inspect(heading_runtime.focused_text_input().caret, content="0")
  heading_runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Delete")),
  )
  inspect(heading_app.document(), content="Title")
  inspect(heading_runtime.focused_text_input().caret, content="0")

  let task_app = MarkdownEditorApp::new()
  task_app.set_document("- [x] done")
  let task_runtime = task_app.runtime(width=980.0, height=640.0)
  task_runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  task_runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  inspect(task_runtime.focused_text_input().caret, content="0")
  task_runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Delete")),
  )
  inspect(task_app.document(), content="done")
  inspect(task_runtime.focused_text_input().caret, content="0")
}

///|
test "markdown editor runtime backspace and delete exit empty continuation markers" {
  let app = MarkdownEditorApp::new()
  app.set_document("")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText(">>")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText(" ")),
  )
  inspect(app.document(), content="> > ")
  inspect(runtime.focused_text_input().caret, content="4")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Backspace")),
  )
  inspect(app.document(), content="> ")
  inspect(runtime.focused_text_input().caret, content="2")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Delete")),
  )
  inspect(app.document(), content="")
  inspect(runtime.focused_text_input().caret, content="0")
}

///|
test "markdown editor runtime backspace removes hidden inline marker" {
  let app = MarkdownEditorApp::new()
  app.set_document("Text **bold**")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  for _ in 0..<7 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowRight")),
    )
  }
  inspect(runtime.focused_text_input().caret, content="7")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Backspace")),
  )
  inspect(app.document(), content="Text bold")
}

///|
test "markdown editor runtime backspace removes hidden link marker" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://moui.dev)")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  for _ in 0..<7 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowRight")),
    )
  }
  inspect(runtime.focused_text_input().caret, content="7")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Backspace")),
  )
  inspect(app.document(), content="Visit MoUI")
  inspect(runtime.focused_text_input().caret, content="6")
}

///|
test "markdown editor runtime delete removes hidden link marker" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://moui.dev)")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  for _ in 0..<11 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowRight")),
    )
  }
  inspect(runtime.focused_text_input().caret, content="11")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Delete")),
  )
  inspect(app.document(), content="Visit MoUI")
  inspect(runtime.focused_text_input().caret, content="6")
}

///|
test "markdown editor runtime backspace merges visual blocks" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title\n- item")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  for _ in 0..<8 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowRight")),
    )
  }
  inspect(runtime.focused_text_input().caret, content="8")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Backspace")),
  )
  inspect(app.document(), content="Title item")
}

///|
test "markdown editor runtime delete merges visual blocks" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title\n- item")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  inspect(runtime.focused_text_input().caret, content="7")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Delete")),
  )
  inspect(app.document(), content="Title item")
  inspect(runtime.focused_text_input().caret, content="5")
}

///|
test "markdown editor runtime delete preserves same-list merge" {
  let app = MarkdownEditorApp::new()
  app.set_document("- first\n- second")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Home")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  inspect(runtime.focused_text_input().caret, content="7")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Delete")),
  )
  inspect(app.document(), content="- first second")
  inspect(runtime.focused_text_input().caret, content="7")
}

///|
test "markdown editor runtime undo restores input transform caret" {
  let app = MarkdownEditorApp::new()
  app.set_document("")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
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
  inspect(app.document(), content="#")
  inspect(runtime.focused_text_input().caret, content="1")
  let redo = runtime.dispatch_focused_text_command(@core.CommandIntent::Redo)
  assert_true(redo.handled)
  assert_true(redo.changed)
  inspect(app.document(), content="# ")
  inspect(runtime.focused_text_input().caret, content="2")
}

///|
test "markdown editor runtime prefix click toggles task checkbox" {
  let app = MarkdownEditorApp::new()
  app.set_document("- [ ] todo")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  inspect(app.document(), content="- [x] todo")
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  inspect(app.document(), content="- [ ] todo")
}

///|
test "markdown editor runtime task shortcut toggles current checkbox" {
  let app = MarkdownEditorApp::new()
  app.set_document("- [ ] todo")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(9, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="Enter",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  inspect(app.document(), content="- [x] todo")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="Enter",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  inspect(app.document(), content="- [ ] todo")
}

///|
test "markdown editor copy exports visual text without hidden markdown markers" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title\n\n- [ ] **bold**")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="a",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  let copied = runtime.dispatch_focused_text_command(@core.CommandIntent::Copy)
  assert_true(copied.handled)
  guard copied.clipboard_text is Some(text) else {
    fail("expected copied visual text")
  }
  inspect(text, content="Title\n\nbold")
}

///|
test "markdown editor cut exports visual text and deletes source selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title\n\n- [ ] **bold**")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="a",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  let cut = runtime.dispatch_focused_text_command(@core.CommandIntent::Cut)
  assert_true(cut.handled)
  assert_true(cut.changed)
  guard cut.clipboard_text is Some(text) else {
    fail("expected cut visual text")
  }
  inspect(text, content="Title\n\nbold")
  inspect(app.document(), content="")
  let undo = runtime.dispatch_focused_text_command(@core.CommandIntent::Undo)
  assert_true(undo.handled)
  assert_true(undo.changed)
  inspect(app.document(), content="# Title\n\n- [ ] **bold**")
  let redo = runtime.dispatch_focused_text_command(@core.CommandIntent::Redo)
  assert_true(redo.handled)
  assert_true(redo.changed)
  inspect(app.document(), content="")
}

///|
test "markdown editor paste command continues list context" {
  let app = MarkdownEditorApp::new()
  app.set_document("- one")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  let pasted = runtime.dispatch_focused_text_command(
    @core.CommandIntent::Paste,
    paste_text=Some(" two\nthree"),
  )
  assert_true(pasted.handled)
  assert_true(pasted.changed)
  inspect(app.document(), content="- one two\n- three")
}

///|
test "markdown editor runtime unicode paste participates in undo redo" {
  let app = MarkdownEditorApp::new()
  app.set_document("Note ")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  let pasted = runtime.dispatch_focused_text_command(
    @core.CommandIntent::Paste,
    paste_text=Some("你好 👩‍💻"),
  )
  assert_true(pasted.handled)
  assert_true(pasted.changed)
  inspect(app.document(), content="Note 你好 👩‍💻")
  let undo = runtime.dispatch_focused_text_command(@core.CommandIntent::Undo)
  assert_true(undo.handled)
  assert_true(undo.changed)
  inspect(app.document(), content="Note ")
  let redo = runtime.dispatch_focused_text_command(@core.CommandIntent::Redo)
  assert_true(redo.handled)
  assert_true(redo.changed)
  inspect(app.document(), content="Note 你好 👩‍💻")
}

///|
test "markdown editor paste command links selected text with url" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit MoUI")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  for _ in 0..<6 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowRight")),
    )
  }
  for _ in 0..<4 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(
        @core.KeyboardEvent::new(
          key="ArrowRight",
          modifiers=@core.KeyModifiers::new(shift=true),
        ),
      ),
    )
  }
  let pasted = runtime.dispatch_focused_text_command(
    @core.CommandIntent::Paste,
    paste_text=Some("https://moui.dev"),
  )
  assert_true(pasted.handled)
  assert_true(pasted.changed)
  inspect(app.document(), content="Visit [MoUI](https://moui.dev)")
  let input = runtime.focused_text_input()
  inspect(input.caret, content="11")
  guard input.selection is Some(selection) else {
    fail("expected linked selection")
  }
  inspect(selection.start, content="7")
  inspect(selection.end, content="11")
}

///|
test "markdown editor paste command links selected text with email" {
  let app = MarkdownEditorApp::new()
  app.set_document("Email team")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  for _ in 0..<6 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowRight")),
    )
  }
  for _ in 0..<4 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(
        @core.KeyboardEvent::new(
          key="ArrowRight",
          modifiers=@core.KeyModifiers::new(shift=true),
        ),
      ),
    )
  }
  let pasted = runtime.dispatch_focused_text_command(
    @core.CommandIntent::Paste,
    paste_text=Some("team@example.dev"),
  )
  assert_true(pasted.handled)
  assert_true(pasted.changed)
  inspect(app.document(), content="Email [team](team@example.dev)")
  let input = runtime.focused_text_input()
  inspect(input.caret, content="11")
  guard input.selection is Some(selection) else {
    fail("expected email linked selection")
  }
  inspect(selection.start, content="7")
  inspect(selection.end, content="11")
}

///|
test "markdown editor paste command inserts image from selected alt text" {
  let app = MarkdownEditorApp::new()
  app.set_document("Insert logo")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  for _ in 0..<7 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="ArrowRight")),
    )
  }
  for _ in 0..<4 {
    runtime.dispatch_event(
      @core.AppEvent::Keyboard(
        @core.KeyboardEvent::new(
          key="ArrowRight",
          modifiers=@core.KeyModifiers::new(shift=true),
        ),
      ),
    )
  }
  let pasted = runtime.dispatch_focused_text_command(
    @core.CommandIntent::Paste,
    paste_text=Some("assets/logo.png"),
  )
  assert_true(pasted.handled)
  assert_true(pasted.changed)
  inspect(app.document(), content="Insert ![logo](assets/logo.png)")
  let input = runtime.focused_text_input()
  inspect(input.caret, content="13")
  guard input.selection is Some(selection) else {
    fail("expected image alt selection")
  }
  inspect(selection.start, content="9")
  inspect(selection.end, content="13")
}

///|
test "markdown editor runtime paste and typing complete autolinks" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit ")
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  let pasted = runtime.dispatch_focused_text_command(
    @core.CommandIntent::Paste,
    paste_text=Some("https://moui.dev"),
  )
  assert_true(pasted.handled)
  assert_true(pasted.changed)
  inspect(app.document(), content="Visit <https://moui.dev>")

  app.set_document("Visit https://moui.dev")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText(" ")),
  )
  inspect(app.document(), content="Visit <https://moui.dev> ")

  app.set_document("Mail ")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  let pasted_email = runtime.dispatch_focused_text_command(
    @core.CommandIntent::Paste,
    paste_text=Some("hello@example.dev"),
  )
  assert_true(pasted_email.handled)
  assert_true(pasted_email.changed)
  inspect(app.document(), content="Mail <hello@example.dev>")

  app.set_document("Mail hello@example.dev")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText(" ")),
  )
  inspect(app.document(), content="Mail <hello@example.dev> ")

  app.set_document("Visit https://moui.dev")
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  inspect(app.document(), content="Visit <https://moui.dev>\n")
}
