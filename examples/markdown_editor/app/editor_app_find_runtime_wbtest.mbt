///|
test "markdown editor toggles find panel from action" {
  let app = MarkdownEditorApp::new()
  assert_false(app.find_visible())
  app.apply_action("find")
  assert_true(app.find_visible())
  let commands = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Replace", .. })
    }),
  )
  inspect(app.find_query(), content="")
  inspect(app.replace_text(), content="")
}

///|
test "markdown editor find opens with selected source text as query" {
  let app = MarkdownEditorApp::new()
  app.set_document("alpha beta gamma beta")
  app.set_selection(10, Some(@core.TextRange::new(start=6, end=10)))
  app.apply_action("find")
  assert_true(app.find_visible())
  inspect(app.find_query(), content="beta")
  guard app.selection.selection is Some(range) else {
    fail("expected original selection to remain active")
  }
  inspect(range.start, content="6")
  inspect(range.end, content="10")

  app.apply_action("find")
  assert_false(app.find_visible())
  app.set_find_query("old")
  app.edit_document("alpha beta\ngamma beta")
  app.set_selection(16, Some(@core.TextRange::new(start=6, end=16)))
  app.apply_action("find")
  inspect(app.find_query(), content="old")

  app.apply_action("find")
  assert_false(app.find_visible())
  app.set_find_query("stale")
  app.set_replace_text("replacement")
  app.set_document("fresh document")
  inspect(app.find_query(), content="")
  inspect(app.replace_text(), content="")
}

///|
test "markdown editor find opens with caret word as query" {
  let app = MarkdownEditorApp::new()
  app.set_document("alpha beta gamma beta")
  app.set_selection(8, None)
  app.apply_action("find")
  assert_true(app.find_visible())
  inspect(app.find_query(), content="beta")
  inspect(app.selection_caret(), content="10")
  guard app.selection.selection is Some(range) else {
    fail("expected caret word to become active match")
  }
  inspect(range.start, content="6")
  inspect(range.end, content="10")
  let matched = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    matched.any(command => {
      command is @core.DrawCommand::DrawText({ text: "1/2", .. })
    }),
  )

  app.apply_action("find")
  assert_false(app.find_visible())
  app.set_find_query("old")
  app.set_selection(10, None)
  app.apply_action("find")
  inspect(app.find_query(), content="beta")
  guard app.selection.selection is Some(end_range) else {
    fail("expected word-end caret to seed query")
  }
  inspect(end_range.start, content="6")
  inspect(end_range.end, content="10")

  app.apply_action("find")
  assert_false(app.find_visible())
  app.set_document("alpha, beta")
  app.set_find_query("stale")
  app.set_selection(6, None)
  app.apply_action("find")
  inspect(app.find_query(), content="stale")
  guard app.selection.selection is None else {
    fail("expected punctuation gap to keep selection collapsed")
  }
}

///|
test "markdown editor find caret word handles unicode neighbors" {
  let app = MarkdownEditorApp::new()
  app.set_document("alpha 🤣beta tail")
  app.set_selection(8, None)
  app.apply_action("find")
  inspect(app.find_query(), content="beta")
  inspect(app.selection_caret(), content="11")
  guard app.selection.selection is Some(range) else {
    fail("expected unicode-neighbor word to become active match")
  }
  inspect(range.start, content="7")
  inspect(range.end, content="11")

  let gap_app = MarkdownEditorApp::new()
  gap_app.set_document("alpha 🤣 beta")
  gap_app.set_selection(7, None)
  gap_app.apply_action("find")
  inspect(gap_app.find_query(), content="")
  guard gap_app.selection.selection is None else {
    fail("expected emoji/space gap to keep selection collapsed")
  }
}

///|
test "markdown editor find next selects match and scrolls into view" {
  let app = MarkdownEditorApp::new()
  let lead = "# First\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\n"
  let first = markdown_editor_text_length(lead)
  app.set_document(lead + "needle near end\nneedle tail")
  app.set_find_query("needle")

  app.find_next_for_test()
  assert_true(app.find_visible())
  let selection = app.selection
  inspect(selection.caret, content=(first + 6).to_string())
  guard selection.selection is Some(range) else {
    fail("expected selected first match")
  }
  inspect(range.start, content=first.to_string())
  inspect(range.end, content=(first + 6).to_string())
  assert_true(app.editor_scroll_y() > 0.0)

  app.find_next_for_test()
  let next_selection = app.selection
  guard next_selection.selection is Some(next_range) else {
    fail("expected selected next match")
  }
  inspect(next_range.start, content=(first + 16).to_string())
  inspect(next_range.end, content=(first + 22).to_string())
}

///|
test "markdown editor find query input selects live match" {
  let app = MarkdownEditorApp::new()
  let lead = "# First\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\nParagraph\n\n"
  let first = markdown_editor_text_length(lead)
  app.set_document(lead + "needle near end\nneedle tail")
  app.apply_action("find")

  app.update_find_query_for_test("n")
  let first_selection = app.selection
  guard first_selection.selection is Some(first_range) else {
    fail("expected live first-character match")
  }
  inspect(first_range.start, content=first.to_string())
  inspect(first_range.end, content=(first + 1).to_string())
  assert_true(app.editor_scroll_y() > 0.0)

  app.update_find_query_for_test("needle")
  let refined_selection = app.selection
  guard refined_selection.selection is Some(refined_range) else {
    fail("expected refined query to keep active match")
  }
  inspect(refined_range.start, content=first.to_string())
  inspect(refined_range.end, content=(first + 6).to_string())
}

///|
test "markdown editor clearing find query collapses active match selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("alpha needle beta")
  app.apply_action("find")
  app.update_find_query_for_test("needle")
  guard app.selection.selection is Some(match_range) else {
    fail("expected live match selection")
  }
  inspect(match_range.start, content="6")
  inspect(match_range.end, content="12")

  app.update_find_query_for_test("")
  inspect(app.find_query(), content="")
  inspect(app.selection_caret(), content="12")
  guard app.selection.selection is None else {
    fail("expected cleared find query to collapse selection")
  }
  let commands = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Ready", .. })
    }),
  )
}

///|
test "markdown editor unmatched find query collapses stale match selection" {
  let app = MarkdownEditorApp::new()
  app.set_document("alpha needle beta")
  app.apply_action("find")
  app.update_find_query_for_test("needle")
  guard app.selection.selection is Some(match_range) else {
    fail("expected live match selection")
  }
  inspect(match_range.start, content="6")
  inspect(match_range.end, content="12")

  app.update_find_query_for_test("missing")
  inspect(app.find_query(), content="missing")
  inspect(app.selection_caret(), content="12")
  guard app.selection.selection is None else {
    fail("expected unmatched query to collapse stale find selection")
  }
  let commands = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "No match", .. })
    }),
  )
}

///|
test "markdown editor find ignores ascii case while preserving source range" {
  let app = MarkdownEditorApp::new()
  app.set_document("Needle first\nmiddle\nNEEDLE last")
  app.apply_action("find")

  app.update_find_query_for_test("needle")
  let selection = app.selection
  guard selection.selection is Some(range) else {
    fail("expected case-insensitive live match")
  }
  inspect(range.start, content="0")
  inspect(range.end, content="6")

  app.find_next_for_test()
  guard app.selection.selection is Some(next_range) else {
    fail("expected second case-insensitive match")
  }
  inspect(next_range.start, content="20")
  inspect(next_range.end, content="26")
}

///|
test "markdown editor find bar reports ready no match and match count" {
  let app = MarkdownEditorApp::new()
  app.set_document("alpha, beta")
  app.set_selection(6, None)
  app.apply_action("find")
  let ready = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    ready.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Ready", .. })
    }),
  )

  app.update_find_query_for_test("missing")
  let missing = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    missing.any(command => {
      command is @core.DrawCommand::DrawText({ text: "No match", .. })
    }),
  )

  app.update_find_query_for_test("beta")
  let matched = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    matched.any(command => {
      command is @core.DrawCommand::DrawText({ text: "1/1", .. })
    }),
  )
}

///|
test "markdown editor find match cache refreshes outside view rebuild" {
  let app = MarkdownEditorApp::new()
  app.set_document("needle one\nneedle two")
  app.apply_action("find")

  app.update_find_query_for_test("needle")
  inspect(app.find_match_count(), content="2")
  let matched = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    matched.any(command => {
      command is @core.DrawCommand::DrawText({ text: "1/2", .. })
    }),
  )

  app.edit_document("needle one")
  inspect(app.find_match_count(), content="1")
  let refreshed = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    refreshed.any(command => {
      command is @core.DrawCommand::DrawText({ text: "1/1", .. })
    }),
  )

  app.close_find()
  inspect(app.find_match_count(), content="0")
}

///|
test "markdown editor find previous wraps from caret" {
  let app = MarkdownEditorApp::new()
  app.set_document("needle first\nmiddle\nneedle last")
  app.set_find_query("needle")
  app.set_selection(0, None)
  app.find_previous_for_test()
  let selection = app.selection
  guard selection.selection is Some(range) else {
    fail("expected wrapped previous match")
  }
  inspect(range.start, content="20")
  inspect(range.end, content="26")
}

///|
test "markdown editor replace current pushes undo and redo history" {
  let app = MarkdownEditorApp::new()
  app.set_document("one Needle two needle")
  app.set_find_query("needle")
  app.set_replace_text("pin")

  app.find_next_for_test()
  app.replace_current_find_match_for_test()
  inspect(app.document(), content="one pin two needle")
  assert_true(app.dirty())
  let selection = app.selection
  guard selection.selection is Some(range) else {
    fail("expected selected next match")
  }
  inspect(range.start, content="12")
  inspect(range.end, content="18")

  assert_true(app.undo())
  inspect(app.document(), content="one Needle two needle")
  assert_false(app.dirty())
  assert_true(app.redo())
  inspect(app.document(), content="one pin two needle")
}

///|
test "markdown editor replace current preserves unicode around match" {
  let app = MarkdownEditorApp::new()
  app.set_document("a🤣 needle 尾")
  app.set_find_query("needle")
  app.set_replace_text("pin")

  app.replace_current_find_match_for_test()
  inspect(app.document(), content="a🤣 pin 尾")
  guard app.selection.selection is Some(range) else {
    fail("expected selected replacement")
  }
  inspect(range.start, content="3")
  inspect(range.end, content="6")
}

///|
test "markdown editor replace current wraps to previous remaining match" {
  let app = MarkdownEditorApp::new()
  app.set_document("needle first\nmiddle\nneedle last")
  app.set_find_query("needle")
  app.set_replace_text("pin")
  app.set_selection(26, Some(@core.TextRange::new(start=20, end=26)))

  app.replace_current_find_match_for_test()
  inspect(app.document(), content="needle first\nmiddle\npin last")
  let selection = app.selection
  guard selection.selection is Some(range) else {
    fail("expected wrapped remaining match")
  }
  inspect(range.start, content="0")
  inspect(range.end, content="6")
}

///|
test "markdown editor replace all updates non-overlapping source matches" {
  let app = MarkdownEditorApp::new()
  app.set_document("aa aa aaa")
  app.set_find_query("aa")
  app.set_replace_text("b")

  app.replace_all_find_matches_for_test()
  inspect(app.document(), content="b b ba")
  assert_true(app.dirty())
  guard app.selection.selection is Some(range) else {
    fail("expected selected first replacement")
  }
  inspect(range.start, content="0")
  inspect(range.end, content="1")

  assert_true(app.undo())
  inspect(app.document(), content="aa aa aaa")
}

///|
test "markdown editor replace all preserves unicode scalar ranges" {
  let app = MarkdownEditorApp::new()
  app.set_document("x🤣 needle y needle 尾")
  app.set_find_query("needle")
  app.set_replace_text("针")

  app.replace_all_find_matches_for_test()
  inspect(app.document(), content="x🤣 针 y 针 尾")
  guard app.selection.selection is Some(range) else {
    fail("expected selected first unicode replacement")
  }
  inspect(range.start, content="3")
  inspect(range.end, content="4")

  assert_true(app.undo())
  inspect(app.document(), content="x🤣 needle y needle 尾")
}

///|
test "markdown editor runtime find shortcuts open panel" {
  let meta_app = MarkdownEditorApp::new()
  meta_app.set_document("Find selected text")
  meta_app.set_selection(13, Some(@core.TextRange::new(start=5, end=13)))
  let meta_runtime = meta_app.runtime(width=980.0, height=640.0)
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="f",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  assert_true(meta_app.find_visible())
  inspect(meta_app.find_query(), content="selected")
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="f",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  assert_true(meta_app.find_visible())

  let control_app = MarkdownEditorApp::new()
  control_app.set_document("Find control text")
  control_app.set_selection(12, Some(@core.TextRange::new(start=5, end=12)))
  let control_runtime = control_app.runtime(width=980.0, height=640.0)
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="f",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  assert_true(control_app.find_visible())
  inspect(control_app.find_query(), content="control")
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="f",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  assert_true(control_app.find_visible())
}

///|
test "markdown editor runtime find replace shortcuts open panel" {
  let meta_app = MarkdownEditorApp::new()
  meta_app.set_document("Find replace selected text")
  meta_app.set_selection(21, Some(@core.TextRange::new(start=13, end=21)))
  let meta_runtime = meta_app.runtime(width=980.0, height=640.0)
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="f",
        modifiers=@core.KeyModifiers::new(meta=true, alt=true),
      ),
    ),
  )
  assert_true(meta_app.find_visible())
  inspect(meta_app.find_query(), content="selected")
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="f",
        modifiers=@core.KeyModifiers::new(meta=true, alt=true),
      ),
    ),
  )
  assert_true(meta_app.find_visible())

  let control_app = MarkdownEditorApp::new()
  control_app.set_document("alpha beta gamma")
  control_app.set_selection(8, None)
  let control_runtime = control_app.runtime(width=980.0, height=640.0)
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="h",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  assert_true(control_app.find_visible())
  inspect(control_app.find_query(), content="beta")
  guard control_app.selection.selection is Some(range) else {
    fail("expected control find-replace shortcut to select caret word")
  }
  inspect(range.start, content="6")
  inspect(range.end, content="10")
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="h",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  assert_true(control_app.find_visible())
}

///|
test "markdown editor runtime find navigation shortcuts move and close panel" {
  let meta_app = MarkdownEditorApp::new()
  meta_app.set_document("needle first\nmiddle\nneedle last")
  meta_app.set_find_query("needle")
  let meta_runtime = meta_app.runtime(width=980.0, height=640.0)
  meta_app.set_selection(0, None)
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="g",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  assert_true(meta_app.find_visible())
  guard meta_app.selection.selection is Some(first_range) else {
    fail("expected meta find-next selection")
  }
  inspect(first_range.start, content="0")
  inspect(first_range.end, content="6")
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="g",
        modifiers=@core.KeyModifiers::new(meta=true),
      ),
    ),
  )
  guard meta_app.selection.selection is Some(next_range) else {
    fail("expected second meta find-next selection")
  }
  inspect(next_range.start, content="20")
  inspect(next_range.end, content="26")
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="g",
        modifiers=@core.KeyModifiers::new(meta=true, shift=true),
      ),
    ),
  )
  guard meta_app.selection.selection is Some(previous_range) else {
    fail("expected meta find-previous selection")
  }
  inspect(previous_range.start, content="0")
  inspect(previous_range.end, content="6")
  meta_runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Escape")),
  )
  assert_false(meta_app.find_visible())

  let control_app = MarkdownEditorApp::new()
  control_app.set_document("one hit two hit")
  control_app.set_find_query("hit")
  let control_runtime = control_app.runtime(width=980.0, height=640.0)
  control_app.set_selection(0, None)
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="g",
        modifiers=@core.KeyModifiers::new(control=true),
      ),
    ),
  )
  guard control_app.selection.selection is Some(control_range) else {
    fail("expected control find-next selection")
  }
  inspect(control_range.start, content="4")
  inspect(control_range.end, content="7")
  control_runtime.dispatch_event(
    @core.AppEvent::Keyboard(
      @core.KeyboardEvent::new(
        key="g",
        modifiers=@core.KeyModifiers::new(control=true, shift=true),
      ),
    ),
  )
  guard control_app.selection.selection is Some(wrapped_range) else {
    fail("expected control find-previous wrap selection")
  }
  inspect(wrapped_range.start, content="12")
  inspect(wrapped_range.end, content="15")
}

///|
test "markdown editor runtime escape dismisses auxiliary panels after find" {
  let app = MarkdownEditorApp::new()
  app.set_source_preview_visible(true)
  app.set_outline_visible(true)
  app.set_file_sidebar_visible(true)
  app.set_document_info_visible(true)
  app.set_format_palette_visible(true)
  app.set_selection(8, Some(@core.TextRange::new(start=0, end=8)))
  app.apply_action("find")
  assert_true(app.find_visible())
  assert_true(app.source_preview_visible())
  assert_true(app.outline_visible())
  assert_true(app.file_sidebar_visible())
  assert_true(app.document_info_visible())
  assert_true(app.format_palette_visible())
  let runtime = app.runtime(width=1180.0, height=680.0)

  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Escape")),
  )
  assert_false(app.find_visible())
  assert_true(app.source_preview_visible())
  assert_true(app.outline_visible())
  assert_true(app.file_sidebar_visible())
  assert_true(app.document_info_visible())
  assert_true(app.format_palette_visible())
  guard app.selection.selection is Some(find_range) else {
    fail("expected selection to survive find dismissal")
  }
  inspect(find_range.start, content="0")
  inspect(find_range.end, content="8")

  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Escape")),
  )
  assert_false(app.source_preview_visible())
  assert_false(app.outline_visible())
  assert_false(app.file_sidebar_visible())
  assert_false(app.document_info_visible())
  assert_false(app.format_palette_visible())
  guard app.selection.selection is Some(panel_range) else {
    fail("expected selection to survive panel dismissal")
  }
  inspect(panel_range.start, content="0")
  inspect(panel_range.end, content="8")
}

///|
test "markdown editor runtime escape collapses selection when panels are gone" {
  let app = MarkdownEditorApp::new()
  app.set_document("Selected text")
  app.set_selection(8, Some(@core.TextRange::new(start=0, end=8)))
  let runtime = app.runtime(width=980.0, height=640.0)
  runtime.dispatch_event(
    @core.AppEvent::Keyboard(@core.KeyboardEvent::new(key="Escape")),
  )
  inspect(app.selection_caret(), content="8")
  guard app.selection.selection is None else {
    fail("expected selection to collapse")
  }
}
