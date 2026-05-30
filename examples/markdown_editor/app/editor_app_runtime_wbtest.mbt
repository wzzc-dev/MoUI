///|
test "markdown editor app emits primary wysiwyg commands" {
  let app = MarkdownEditorApp::new()
  let commands = app.runtime(width=980.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Editor notes", .. })
    }),
  )
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::DrawText(
        { text: "Editor notes", font: { weight: 700, .. }, .. }
      )
    }),
  )
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "• ", .. })
    }),
  )
  assert_false(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Markdown source", .. })
    }),
  )
}

///|
test "markdown editor page decoration keeps editor interactive" {
  let app = MarkdownEditorApp::new()
  app.set_document("")
  let runtime = app.runtime(width=980.0, height=640.0)
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => command is @core.DrawCommand::DrawShadow(_)),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=28.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("Hi")),
  )
  inspect(app.document(), content="Hi")
}

///|
test "markdown editor toggles source preview from action" {
  let app = MarkdownEditorApp::new()
  inspect(app.source_preview_visible(), content="false")
  app.apply_action("source-preview")
  inspect(app.source_preview_visible(), content="true")
  let commands = app.runtime(width=980.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Markdown source", .. })
    }),
  )
}

///|
test "markdown editor status reports active inline format" {
  inspect(
    markdown_editor_active_format_suffix(
      "Text **bold** and [MoUI](https://moui.dev)",
      { caret: 9, selection: None },
    ),
    content=" / Active: Bold",
  )
  inspect(
    markdown_editor_active_format_suffix(
      "Text **bold** and [MoUI](https://moui.dev)",
      { caret: 21, selection: None },
    ),
    content=" / Active: Link",
  )
  inspect(
    markdown_editor_active_format_suffix("Plain", { caret: 2, selection: None }),
    content="",
  )
}

///|
test "markdown editor toolbar active state follows caret context" {
  let source = "# Title\n\nText **bold** and [MoUI](https://moui.dev)\n- item\n> quote"
  inspect(
    markdown_editor_command_active(source, { caret: 17, selection: None }, Bold),
    content="true",
  )
  inspect(
    markdown_editor_command_active(source, { caret: 30, selection: None }, Link),
    content="true",
  )
  inspect(
    markdown_editor_command_active(
      source,
      { caret: 3, selection: None },
      Heading(1),
    ),
    content="true",
  )
  inspect(
    markdown_editor_command_active(
      source,
      { caret: 55, selection: None },
      BulletList,
    ),
    content="true",
  )
  inspect(
    markdown_editor_command_active(
      source,
      { caret: 63, selection: None },
      Quote,
    ),
    content="true",
  )
  inspect(
    markdown_editor_command_active(
      source,
      { caret: 17, selection: None },
      Italic,
    ),
    content="false",
  )
}

///|
test "markdown editor floats contextual palette over editor surface" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://moui.dev)")
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  let commands = app.runtime(width=980.0, height=700.0).draw_commands()
  guard markdown_editor_text_frame(commands, "Visit ") is Some(editor_text) else {
    fail("expected editor text frame")
  }
  guard markdown_editor_text_frame(commands, "Link target")
    is Some(palette_text) else {
    fail("expected floating palette text frame")
  }
  assert_true(palette_text.origin.y > editor_text.origin.y)
  assert_true(palette_text.origin.y - editor_text.origin.y < 80.0)
}

///|
test "markdown editor hides contextual palette in plain writing mode" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://moui.dev)\n\nTail")
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  let top_commands = app.runtime(width=980.0, height=700.0).draw_commands()
  guard markdown_editor_text_frame(top_commands, "Link target")
    is Some(top_palette) else {
    fail("expected top palette")
  }
  app.set_selection(35, None)
  let lower_commands = app.runtime(width=980.0, height=700.0).draw_commands()
  assert_false(
    markdown_editor_text_frame(lower_commands, "Link target") is Some(_),
  )
  assert_false(
    markdown_editor_text_frame(lower_commands, "Image src") is Some(_),
  )
  assert_true(top_palette.origin.y > 0.0)
}

///|
test "markdown editor app inline command uses tracked selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title")
  app.set_selection(7, Some(@core.TextRange::new(start=2, end=7)))
  app.apply_command_to_selection(Code)
  inspect(app.document(), content="# `Title`")
}

///|
test "markdown editor app inline command toggles tracked formatted selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("Text **bold**")
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  app.apply_command_to_selection(Bold)
  inspect(app.document(), content="Text bold")
}

///|
test "markdown editor app reference commands toggle caret context" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://example.com) and ![logo](image.png)")
  app.set_selection(9, None)
  app.apply_command_to_selection(Link)
  inspect(app.document(), content="Visit MoUI and ![logo](image.png)")
  app.set_selection(20, None)
  app.apply_command_to_selection(Image)
  inspect(app.document(), content="Visit MoUI and logo")
}

///|
test "markdown editor app undo and redo structured formatting commands" {
  let app = MarkdownEditorApp::new()
  app.set_document("Text bold")
  app.set_selection(9, Some(@core.TextRange::new(start=5, end=9)))
  app.apply_command_to_selection(Bold)
  inspect(app.document(), content="Text **bold**")
  assert_true(app.can_undo())
  assert_false(app.can_redo())
  assert_true(app.undo())
  inspect(app.document(), content="Text bold")
  assert_true(app.can_redo())
  assert_true(app.redo())
  inspect(app.document(), content="Text **bold**")
}

///|
test "markdown editor app undo and redo target edits" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://old.example)")
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  app.set_link_target("https://moui.dev")
  app.apply_link_target()
  inspect(app.document(), content="Visit [MoUI](https://moui.dev)")
  assert_true(app.undo())
  inspect(app.document(), content="Visit [MoUI](https://old.example)")
  assert_true(app.redo())
  inspect(app.document(), content="Visit [MoUI](https://moui.dev)")
}

///|
test "markdown editor app clears command history on document reset" {
  let app = MarkdownEditorApp::new()
  app.set_document("Text bold")
  app.set_selection(9, Some(@core.TextRange::new(start=5, end=9)))
  app.apply_command_to_selection(Bold)
  assert_true(app.can_undo())
  app.set_document("Fresh")
  assert_false(app.can_undo())
  assert_false(app.undo())
  inspect(app.document(), content="Fresh")
  app.apply_command_to_selection(Bold)
  assert_true(app.can_undo())
  app.clear()
  assert_false(app.can_undo())
}

///|
test "markdown editor app target inputs sync from selection and apply edits" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://old.example) and ![logo](old.png)")
  inspect(app.block_label(), content="Paragraph")
  guard app.target_kind() is PlainSelection else {
    fail("expected plain target mode")
  }
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  guard app.target_kind() is LinkTarget else {
    fail("expected link target mode")
  }
  inspect(app.link_target(), content="https://old.example")
  app.set_link_target("https://moui.dev")
  app.apply_link_target()
  inspect(
    app.document(),
    content="Visit [MoUI](https://moui.dev) and ![logo](old.png)",
  )
  app.set_document("Mail <hello@example.dev>")
  app.set_selection(23, Some(@core.TextRange::new(start=6, end=23)))
  guard app.target_kind() is LinkTarget else {
    fail("expected email autolink target mode")
  }
  inspect(app.link_target(), content="hello@example.dev")
  app.set_link_target("team@example.dev")
  app.apply_link_target()
  inspect(app.document(), content="Mail <team@example.dev>")
  app.set_document("Visit [MoUI](https://moui.dev) and ![logo](old.png)")
  app.set_selection(41, Some(@core.TextRange::new(start=37, end=41)))
  guard app.target_kind() is ImageTarget else {
    fail("expected image target mode")
  }
  inspect(app.image_target(), content="old.png")
  app.set_image_target("assets/logo.png")
  app.apply_image_target()
  inspect(
    app.document(),
    content="Visit [MoUI](https://moui.dev) and ![logo](assets/logo.png)",
  )
  app.set_selection(5, Some(@core.TextRange::new(start=0, end=5)))
  guard app.target_kind() is PlainSelection else {
    fail("expected plain target mode after non-target selection")
  }
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  app.set_selection(26, None)
  guard app.target_kind() is TableTools else {
    fail("expected table tools mode")
  }
  app.set_document("```moonbit\nlet x = 1\n```")
  app.set_selection(15, None)
  guard app.target_kind() is PlainSelection else {
    fail("expected direct code source editing mode")
  }
  app.set_document("Note[^a]\n\n[^a]: Old text")
  app.set_selection(7, Some(@core.TextRange::new(start=6, end=7)))
  guard app.target_kind() is FootnoteTarget else {
    fail("expected footnote target mode")
  }
  inspect(app.footnote_text(), content="Old text")
  app.set_footnote_text("New text")
  app.apply_footnote_text()
  inspect(app.document(), content="Note[^a]\n\n[^a]: New text")
  app.set_document("Intro\n<div>Old</div>\nTail")
  app.set_selection(9, None)
  guard app.target_kind() is HtmlBlockTarget else {
    fail("expected html block target mode")
  }
  inspect(app.html_block_text(), content="<div>Old</div>")
  app.set_html_block_text("<section>New</section>")
  app.apply_html_block_text()
  inspect(app.document(), content="Intro\n<section>New</section>\nTail")
}

///|
test "markdown editor app target inputs sync from caret context" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://old.example) and ![logo](old.png)")
  app.set_selection(9, None)
  guard app.target_kind() is LinkTarget else {
    fail("expected link target mode at caret")
  }
  inspect(app.link_target(), content="https://old.example")
  app.set_link_target("https://moui.dev")
  app.apply_link_target()
  inspect(
    app.document(),
    content="Visit [MoUI](https://moui.dev) and ![logo](old.png)",
  )

  app.set_selection(39, None)
  guard app.target_kind() is ImageTarget else {
    fail("expected image target mode at caret")
  }
  inspect(app.image_target(), content="old.png")
  app.set_image_target("assets/logo.png")
  app.apply_image_target()
  inspect(
    app.document(),
    content="Visit [MoUI](https://moui.dev) and ![logo](assets/logo.png)",
  )

  app.set_document("Mail <hello@example.dev>")
  app.set_selection(12, None)
  guard app.target_kind() is LinkTarget else {
    fail("expected autolink target mode at caret")
  }
  inspect(app.link_target(), content="hello@example.dev")
}

///|
test "markdown editor app block label syncs from selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("# Title\n- item\nPlain")
  app.set_selection(3, None)
  inspect(app.block_label(), content="Heading 1")
  app.set_selection(10, None)
  inspect(app.block_label(), content="Bullet list")
  app.apply_command_to_selection(Paragraph)
  inspect(app.document(), content="# Title\nitem\nPlain")
  inspect(app.block_label(), content="Paragraph")
}

///|
test "markdown editor target bar renders contextual controls" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://old.example) and ![logo](old.png)")
  let plain = app.runtime(width=980.0, height=700.0).draw_commands()
  assert_false(
    plain.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Link target", .. })
    }),
  )
  assert_false(
    plain.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Image src", .. })
    }),
  )
  assert_false(
    plain.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Table tools", .. })
    }),
  )
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  let link = app.runtime(width=980.0, height=700.0).draw_commands()
  assert_true(
    link.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Link target", .. })
    }),
  )
  assert_false(
    link.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Image src", .. })
    }),
  )
  app.set_selection(44, Some(@core.TextRange::new(start=40, end=44)))
  let image = app.runtime(width=980.0, height=700.0).draw_commands()
  assert_true(
    image.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Image src", .. })
    }),
  )
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  app.set_selection(26, None)
  let table = app.runtime(width=980.0, height=700.0).draw_commands()
  assert_true(
    table.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Table tools", .. })
    }),
  )
  assert_true(
    table.any(command => {
      command is @core.DrawCommand::DrawText({ text: "+Row", .. })
    }),
  )
  assert_true(
    table.any(command => {
      command is @core.DrawCommand::DrawText({ text: "+Col", .. })
    }),
  )
  assert_true(
    table.any(command => {
      command is @core.DrawCommand::DrawText({ text: "-Col", .. })
    }),
  )
  assert_true(
    table.any(command => {
      command is @core.DrawCommand::DrawText({ text: "-Row", .. })
    }),
  )
  assert_true(
    table.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Center", .. })
    }),
  )
  assert_true(
    table.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Auto", .. })
    }),
  )
  app.set_document("```moonbit\nlet x = 1\n```")
  app.set_selection(15, None)
  let code = app.runtime(width=980.0, height=700.0).draw_commands()
  assert_true(
    code.any(command => {
      command is @core.DrawCommand::DrawText({ text: "```moonbit", .. })
    }),
  )
  assert_true(
    code.any(command => {
      command is @core.DrawCommand::DrawText({ text: "```", .. })
    }),
  )
  assert_false(
    code.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Code lang", .. })
    }),
  )
  app.set_document("Intro\n<div>Old</div>\nTail")
  app.set_selection(9, None)
  let html = app.runtime(width=980.0, height=700.0).draw_commands()
  assert_true(
    html.any(command => {
      command is @core.DrawCommand::DrawText({ text: "HTML block", .. })
    }),
  )
}

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
test "markdown editor runtime enter continues bullet list" {
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
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="End")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  inspect(app.document(), content="- item\n- ")
}

///|
test "markdown editor runtime enter inserts table row" {
  let app = MarkdownEditorApp::new()
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  let runtime = app.runtime(width=980.0, height=640.0)
  let mut target : @core.Rect? = None
  for command in runtime.draw_commands() {
    match command {
      @core.DrawCommand::DrawText({ text: "2", frame, .. }) =>
        target = Some(frame)
      _ => ()
    }
  }
  guard target is Some(frame) else { fail("expected rendered table cell") }
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(
          x=frame.origin.x + frame.size.width / 2.0,
          y=frame.origin.y + frame.size.height / 2.0,
        ),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  inspect(
    app.document(),
    content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |",
  )
  inspect(runtime.focused_text_input().caret, content="39")
}

///|
test "markdown editor runtime shortcut inserts table column" {
  let app = MarkdownEditorApp::new()
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(30, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="=",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(
    app.document(),
    content="| A | B |  |\n| --- | --- | --- |\n| 1 | 2 |  |",
  )
}

///|
test "markdown editor runtime shortcut inserts table row" {
  let app = MarkdownEditorApp::new()
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(30, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="Enter",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(
    app.document(),
    content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |",
  )
}

///|
test "markdown editor runtime shortcut deletes table row" {
  let app = MarkdownEditorApp::new()
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(30, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="-",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(app.document(), content="| A | B |\n| --- | --- |\n| 3 | 4 |")
}

///|
test "markdown editor runtime shortcut deletes table column" {
  let app = MarkdownEditorApp::new()
  app.set_document("| A | B | C |\n| --- | --- | --- |\n| 1 | 2 | 3 |")
  let runtime = app.runtime(width=980.0, height=640.0)
  app.set_selection(40, None)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="_",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  inspect(app.document(), content="| A | C |\n| --- | --- |\n| 1 | 3 |")
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
}

///|
test "markdown editor actions update canonical markdown" {
  let app = MarkdownEditorApp::new()
  app.clear()
  app.apply_action("h1")
  inspect(app.document(), content="# Heading")
  app.clear()
  app.apply_action("h6")
  inspect(app.document(), content="###### Caption")
  app.clear()
  app.apply_action("bold")
  assert_true(app.document().contains("**bold text**"))
  app.apply_action("strike")
  assert_true(app.document().contains("~~old text~~"))
  app.apply_action("link")
  assert_true(app.document().contains("[link text](https://example.com)"))
  app.apply_action("link-target")
  assert_true(app.document().contains("[link text](https://moui.dev)"))
  app.apply_action("image")
  assert_true(app.document().contains("![image alt](image.png)"))
  app.apply_action("image-target")
  assert_true(app.document().contains("![image alt](assets/image.png)"))
  app.apply_action("code-language")
  assert_true(app.document().contains("```moonbit\ncode block\n```"))
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  app.set_selection(30, None)
  app.apply_action("table-row")
  inspect(
    app.document(),
    content="| A | B |\n| --- | --- |\n| 1 | 2 |\n|  |  |",
  )
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |")
  app.set_selection(30, None)
  app.apply_action("table-column")
  inspect(
    app.document(),
    content="| A | B |  |\n| --- | --- | --- |\n| 1 | 2 |  |",
  )
  app.set_document("| A | B |\n| --- | --- |\n| 1 | 2 |\n| 3 | 4 |")
  app.set_selection(30, None)
  app.apply_action("table-row-delete")
  inspect(app.document(), content="| A | B |\n| --- | --- |\n| 3 | 4 |")
  app.set_document("| A | B | C |\n| --- | --- | --- |\n| 1 | 2 | 3 |")
  app.set_selection(40, None)
  app.apply_action("table-column-delete")
  inspect(app.document(), content="| A | C |\n| --- | --- |\n| 1 | 3 |")
  app.set_document("# Heading")
  app.set_selection(4, None)
  app.apply_action("paragraph")
  inspect(app.document(), content="Heading")
}

///|
test "markdown editor actions seed every supported action from empty document" {
  for
    expected in [
      "**bold text**", "*italic text*", "`code`", "~~old text~~", "[link text](https://example.com)",
      "[link text](https://moui.dev)", "![image alt](image.png)", "![image alt](assets/image.png)",
      "Paragraph", "# Heading", "## Section", "### Detail", "#### Subdetail", "##### Note",
      "###### Caption", "- List item", "- [ ] Task item", "1. List item", "> Quote",
      "---", "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |", "```\ncode block\n```",
    ] {
    let app = MarkdownEditorApp::new()
    app.clear()
    app.apply_action(markdown_action_from_seed(expected))
    inspect(app.document(), content=expected)
  }
}

///|
test "markdown editor actions apply actions at current caret context" {
  let app = MarkdownEditorApp::new()
  app.set_document("Base")
  for
    action in [
      "bold", "italic", "code", "strike", "link", "image", "h1", "h2", "h3", "h4",
      "h5", "h6", "ul", "task", "ol", "quote", "codeblock",
    ] {
    app.apply_action(action)
  }
  let document = app.document()
  inspect(
    document,
    content="Base\n\n**bold text**\n\n*italic text*\n\n`code`\n\n~~old text~~\n\n[link text](https://example.com)\n\n```\n> ![image alt](image.png)\n```",
  )
  app.apply_action("unknown")
  inspect(app.document(), content=document)
}

///|
fn markdown_action_from_seed(expected : String) -> String {
  if expected == "**bold text**" {
    "bold"
  } else if expected == "*italic text*" {
    "italic"
  } else if expected == "`code`" {
    "code"
  } else if expected == "~~old text~~" {
    "strike"
  } else if expected == "[link text](https://example.com)" {
    "link"
  } else if expected == "[link text](https://moui.dev)" {
    "link-target"
  } else if expected == "![image alt](image.png)" {
    "image"
  } else if expected == "![image alt](assets/image.png)" {
    "image-target"
  } else if expected == "Paragraph" {
    "paragraph"
  } else if expected == "# Heading" {
    "h1"
  } else if expected == "## Section" {
    "h2"
  } else if expected == "### Detail" {
    "h3"
  } else if expected == "#### Subdetail" {
    "h4"
  } else if expected == "##### Note" {
    "h5"
  } else if expected == "###### Caption" {
    "h6"
  } else if expected == "- List item" {
    "ul"
  } else if expected == "- [ ] Task item" {
    "task"
  } else if expected == "1. List item" {
    "ol"
  } else if expected == "> Quote" {
    "quote"
  } else if expected == "---" {
    "rule"
  } else if expected ==
    "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |" {
    "table"
  } else {
    "codeblock"
  }
}

///|
test "markdown editor runtime typing updates document" {
  let app = MarkdownEditorApp::new()
  app.clear()
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=32.0, y=84.0),
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
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("Hi")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("- item")),
  )
  inspect(app.document(), content="# Hi\n- item")
}

///|
test "markdown editor runtime enter completes fenced code block" {
  let app = MarkdownEditorApp::new()
  app.clear()
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=32.0, y=84.0),
        phase=@core.PointerPhase::Down,
      ),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("```moonbit")),
  )
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Enter")),
  )
  inspect(app.document(), content="```moonbit\n\n```")
  inspect(runtime.focused_text_input().caret, content="11")
  runtime.dispatch_event(
    @core.AppEvent::TextInput(@core.TextInputEvent::InsertText("let x = 1")),
  )
  inspect(app.document(), content="```moonbit\nlet x = 1\n```")
}

///|
test "markdown editor clear redraws placeholder and optional empty source preview" {
  let app = MarkdownEditorApp::new()
  let runtime = app.runtime(width=980.0, height=640.0)
  app.clear()
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let commands = runtime.draw_commands()
  assert_true(
    commands.any(command => {
      command
      is @core.DrawCommand::DrawText({ text: "Start writing Markdown", .. })
    }),
  )
  assert_false(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "(empty)", .. })
    }),
  )
  app.set_source_preview_visible(true)
  runtime.dispatch_event(@core.AppEvent::Redraw(@core.RedrawReason::Explicit))
  let source_commands = runtime.draw_commands()
  assert_true(
    source_commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "(empty)", .. })
    }),
  )
}

///|
fn markdown_editor_text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Rect? {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}
