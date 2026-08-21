///|
test "markdown editor find options toggle and affect matching" {
  let app = MarkdownEditorApp::new()
  // Defaults: case-insensitive, substring.
  inspect(app.find_options.case_sensitive, content="false")
  inspect(app.find_options.whole_word, content="false")
  // Case-sensitive off: "Foo" matches "foo".
  let insensitive = markdown_editor_find_matches("foo Foo bar", "foo")
  inspect(insensitive.length(), content="2")
  // Toggle case-sensitive on: only "Foo" matches "Foo".
  app.update_in_place(ToggleFindCaseSensitive)
  assert_true(app.find_options.case_sensitive)
  let sensitive = markdown_editor_find_matches(
    "foo Foo bar",
    "Foo",
    options=app.find_options,
  )
  inspect(sensitive.length(), content="1")
  // Whole-word: "cat" should not match inside "catalog".
  app.update_in_place(ToggleFindWholeWord)
  assert_true(app.find_options.whole_word)
  let whole = markdown_editor_find_matches(
    "cat catalog cat",
    "cat",
    options=app.find_options,
  )
  inspect(whole.length(), content="2")
}

///|
test "markdown editor find matching preserves unicode ranges" {
  let unicode = markdown_editor_find_matches("a🤣needle needle", "needle")
  inspect(unicode.length(), content="2")
  inspect(unicode[0].start, content="2")
  inspect(unicode[0].end, content="8")
  inspect(unicode[1].start, content="9")
  inspect(unicode[1].end, content="15")

  let overlapping = markdown_editor_find_matches("aaaa", "aa")
  inspect(overlapping.length(), content="2")
  inspect(overlapping[0].start, content="0")
  inspect(overlapping[0].end, content="2")
  inspect(overlapping[1].start, content="2")
  inspect(overlapping[1].end, content="4")

  let options = { ..MarkdownEditorFindOptions::default(), whole_word: true }
  let whole = markdown_editor_find_matches(
    "🤣cat catalog cat_ cat",
    "cat",
    options~,
  )
  inspect(whole.length(), content="2")
  inspect(whole[0].start, content="1")
  inspect(whole[0].end, content="4")
  inspect(whole[1].start, content="18")
  inspect(whole[1].end, content="21")
}

///|
test "markdown editor regex find uses pattern semantics and stable source ranges" {
  let options = { ..MarkdownEditorFindOptions::default(), regex: true }
  let matches = markdown_editor_find_matches(
    "a🤣foo-42 foo-7",
    "foo-[[:digit:]]+",
    options~,
  )
  inspect(matches.length(), content="2")
  inspect(matches[0].start, content="2")
  inspect(matches[0].end, content="8")
  inspect(matches[1].start, content="9")
  inspect(matches[1].end, content="14")

  let insensitive = markdown_editor_find_matches("Cat cat", "cat", options~)
  inspect(insensitive.length(), content="2")

  let whole_word = { ..options, case_sensitive: true, whole_word: true }
  let whole_matches = markdown_editor_find_matches(
    "Cat catalog cat",
    "cat",
    options=whole_word,
  )
  inspect(whole_matches.length(), content="1")
  inspect(whole_matches[0].start, content="12")
  inspect(whole_matches[0].end, content="15")

  let zero_width = markdown_editor_find_matches("foo", "^", options~)
  inspect(zero_width.length(), content="0")
}

///|
test "markdown editor regex find reports invalid syntax and replaces literal matches" {
  let app = MarkdownEditorApp::new()
  app.set_document("task-12 task-34")
  app.apply_action("find")
  app.update_in_place(ToggleFindRegex)
  app.update_find_query_for_test("[")
  inspect(app.find_match_count(), content="0")
  guard app.selection.selection is None else {
    fail("expected invalid regex to clear the stale match selection")
  }
  let invalid_commands = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    invalid_commands.any(command => {
      command is @core.DrawCommand::DrawText({ text: "Invalid regex", .. })
    }),
  )

  app.update_find_query_for_test("task-([[:digit:]]+)")
  inspect(app.find_match_count(), content="2")
  app.set_replace_text("$1")
  app.replace_all_find_matches_for_test()
  inspect(app.document(), content="$1 $1")
  assert_true(app.undo())
  inspect(app.document(), content="task-12 task-34")
}

///|
test "markdown editor settings round-trip through JSON" {
  let app = MarkdownEditorApp::new()
  app.dark_mode_enabled = true
  app.update_in_place(ToggleFocusMode)
  // Serialize to JSON and decode back; the decoded settings should reflect the
  // toggles. The host file I/O is bypassed by calling the decode helper on the
  // serialized text directly.
  // Verify the persisted value shape independently of a platform adapter.
  let original : MarkdownEditorSettings = {
    dark_mode: true,
    font_family: "Serif",
    writing_appearance: "Warm",
    focus_mode: true,
    typewriter_mode: false,
    zen_mode: false,
    source_preview: true,
    outline: false,
    files: true,
    document_info: false,
  }
  let text = ToJson::to_json(original).stringify(indent=2)
  let decoded = markdown_editor_decode_settings(text)
  assert_true(decoded.dark_mode)
  assert_true(decoded.focus_mode)
  assert_true(decoded.source_preview)
  assert_true(decoded.files)
  assert_true(decoded.writing_appearance == "Warm")
}

///|
test "markdown editor settings decode falls back to defaults on bad JSON" {
  let decoded = markdown_editor_decode_settings("not valid json {")
  assert_true(!decoded.dark_mode)
  assert_true(decoded.writing_appearance == "Paper")
}
