///|
test "markdown editor keeps the format bubble overlay detached" {
  // The selection-triggered format bubble is temporarily disabled (see the
  // disable note in `view_editor_surface`). While detached, its format glyphs
  // (H1/H2/❝, emitted only by the bubble) must not render even on a non-empty
  // selection. Restore the selection-gated rendering assertion here when the
  // overlay is re-enabled.
  let has_bubble_glyph = (commands : Array[@core.DrawCommand]) =>
    commands.any(command => {
      match command {
        @core.DrawCommand::DrawText({ text, .. }) => text == "H1"
        _ => false
      }
    })
  let app = MarkdownEditorApp::new()
  app.set_document("Some text to select")
  app.set_selection(5, Some(@core.TextRange::new(start=0, end=9)))
  assert_false(
    has_bubble_glyph(app.runtime(width=980.0, height=640.0).draw_commands()),
  )
  app.set_selection(5, None)
  assert_false(
    has_bubble_glyph(app.runtime(width=980.0, height=640.0).draw_commands()),
  )
}
