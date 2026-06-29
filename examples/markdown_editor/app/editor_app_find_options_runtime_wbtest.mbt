///|
test "markdown editor find options toggle and affect matching" {
  let app = MarkdownEditorApp::new()
  // Defaults: case-insensitive, substring.
  inspect(app.find_options.get().case_sensitive, content="false")
  inspect(app.find_options.get().whole_word, content="false")
  // Case-sensitive off: "Foo" matches "foo".
  let insensitive = markdown_editor_find_matches("foo Foo bar", "foo")
  inspect(insensitive.length(), content="2")
  // Toggle case-sensitive on: only "Foo" matches "Foo".
  let _ = app.update(ToggleFindCaseSensitive)
  assert_true(app.find_options.get().case_sensitive)
  let sensitive = markdown_editor_find_matches(
    "foo Foo bar",
    "Foo",
    options=app.find_options.get(),
  )
  inspect(sensitive.length(), content="1")
  // Whole-word: "cat" should not match inside "catalog".
  let _ = app.update(ToggleFindWholeWord)
  assert_true(app.find_options.get().whole_word)
  let whole = markdown_editor_find_matches(
    "cat catalog cat",
    "cat",
    options=app.find_options.get(),
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
test "markdown editor settings round-trip through JSON" {
  let app = MarkdownEditorApp::new()
  let _ = app.update(ToggleDarkMode)
  let _ = app.update(ToggleFocusMode)
  // Serialize to JSON and decode back; the decoded settings should reflect the
  // toggles. The host file I/O is bypassed by calling the decode helper on the
  // serialized text directly.
  let services = @host.HostAppServices::unavailable()
  app.save_settings(services)
  // save_settings writes through the host (unavailable here → no-op), so
  // instead verify the in-memory settings struct round-trips via JSON.
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
  let text = original.to_json().stringify(indent=2)
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
