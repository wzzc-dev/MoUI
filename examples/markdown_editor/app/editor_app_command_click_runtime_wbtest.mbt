///|
test "markdown editor command click opens a link target" {
  let app = MarkdownEditorApp::new()
  // Document with an autolink `<https://example.com>` starting at offset 0.
  // The autolink text occupies the first ~24 chars; clicking inside it should
  // resolve the link target via the command-click handler.
  app.set_document("<https://example.com>\n\nBody")
  // handle_command_click is a private method; exercise it through the update
  // message it is wired to, at an offset inside the autolink.
  let _ = app.update(CommandClickAt(5))
  // The handler sets link_target and dispatches OpenTarget; OpenTarget without
  // host services marks the transfer unavailable, but link_target must reflect
  // the resolved target.
  assert_true(app.link_target.get() == "https://example.com")
}

///|
test "markdown editor command click on plain text is a no-op" {
  let app = MarkdownEditorApp::new()
  app.set_document("Just plain text here")
  let before_kind = app.target_kind.get()
  let _ = app.update(CommandClickAt(5))
  // No link/image at offset 5: target kind unchanged.
  assert_true(app.target_kind.get() == before_kind)
}
