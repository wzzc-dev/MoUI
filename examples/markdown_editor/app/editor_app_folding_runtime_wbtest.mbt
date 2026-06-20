///|
test "markdown editor outline folds nested headings on toggle" {
  let app = MarkdownEditorApp::new()
  app.set_document("# First\n\n## Second\n\n### Third\n\n## Fourth")
  app.set_outline_visible(true)
  // Initially all four headings are visible in the outline.
  let commands = app.runtime(width=1120.0, height=640.0).draw_commands()
  assert_true(
    commands.any(command => {
      match command {
        @core.DrawCommand::DrawText({ text, .. }) => text.contains("First")
        _ => false
      }
    }),
  )
  assert_true(
    commands.any(command => {
      match command {
        @core.DrawCommand::DrawText({ text, .. }) => text.contains("Third")
        _ => false
      }
    }),
  )
  // Toggle the fold on the H1 heading (source_start 0).
  let _ = app.update(ToggleHeadingFold(0))
  assert_true(app.heading_is_folded(0))
  // Toggling again unfolds it.
  let _ = app.update(ToggleHeadingFold(0))
  assert_true(!app.heading_is_folded(0))
}

///|
test "markdown editor folded outline hides nested children" {
  // Exercise the pure filter via the snapshot's outline. Folding a heading
  // hides its deeper-level children until the next same-or-higher heading.
  let app = MarkdownEditorApp::new()
  app.set_document("# First\n\n## Second\n\n### Third\n\n## Fourth")
  let snapshot = MarkdownEditorSnapshot::parse(app.document.get())
  let all = markdown_editor_folded_outline(snapshot.outline, [])
  assert_eq(all.length(), 4)
  // Fold the H2 "Second" (the second outline item): it hides H3 "Third", and
  // the sibling H2 "Fourth" reappears, so First + Second + Fourth = 3 visible.
  let second_start = snapshot.outline[1].source_start
  let folded = markdown_editor_folded_outline(
    snapshot.outline, [second_start],
  )
  assert_eq(folded.length(), 3)
  assert_true(folded[0].title == "First")
  assert_true(folded[1].title == "Second")
  assert_true(folded[2].title == "Fourth")
}
