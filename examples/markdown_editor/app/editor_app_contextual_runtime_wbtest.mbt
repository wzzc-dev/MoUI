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
test "markdown editor app undo and redo block duplicate command" {
  let app = MarkdownEditorApp::new()
  app.set_document("Alpha\nBeta")
  app.set_selection(8, None)
  app.apply_action("duplicate-block")
  inspect(app.document(), content="Alpha\nBeta\nBeta")
  inspect(app.selection_caret(), content="13")
  assert_true(app.can_undo())
  assert_true(app.undo())
  inspect(app.document(), content="Alpha\nBeta")
  assert_true(app.redo())
  inspect(app.document(), content="Alpha\nBeta\nBeta")
}

///|
test "markdown editor app undo and redo selected block range move command" {
  let app = MarkdownEditorApp::new()
  app.set_document("Alpha\nBeta\nGamma")
  app.set_selection(8, Some(@core.TextRange::new(start=1, end=10)))
  app.apply_action("move-block-down")
  inspect(app.document(), content="Gamma\nAlpha\nBeta")
  inspect(app.selection_caret(), content="14")
  guard app.selection.get().selection is Some(moved_selection) else {
    fail("expected moved block range selection")
  }
  inspect(moved_selection.start, content="7")
  inspect(moved_selection.end, content="16")
  assert_true(app.can_undo())
  assert_true(app.undo())
  inspect(app.document(), content="Alpha\nBeta\nGamma")
  assert_true(app.redo())
  inspect(app.document(), content="Gamma\nAlpha\nBeta")
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
test "markdown editor link and image target bars show open action" {
  let app = MarkdownEditorApp::new()
  app.set_document("Visit [MoUI](https://moui.dev)")
  app.set_selection(11, Some(@core.TextRange::new(start=7, end=11)))
  let link_commands = app.runtime(width=980.0, height=640.0).draw_commands()
  assert_true(
    link_commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Open", .. })
    }),
  )
  app.set_document("Logo ![mark](https://moui.dev/logo.png)")
  app.set_selection(9, None)
  let image_commands = app.runtime(width=980.0, height=640.0).draw_commands()
  assert_true(
    image_commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Open", .. })
    }),
  )
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
