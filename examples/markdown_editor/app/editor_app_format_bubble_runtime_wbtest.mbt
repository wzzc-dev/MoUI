///|
test "markdown editor format bubble appears on non-empty selection" {
  if !markdown_editor_floating_overlays_enabled {
    // Format bubble is temporarily disabled; see
    // markdown_editor_floating_overlays_enabled in view_editor_surface.mbt.
    return
  }
  let app = MarkdownEditorApp::new()
  app.set_document("Some text to select")
  // No selection → no bubble (no "Bold" glyph rendered).
  let before = app.runtime(width=980.0, height=640.0).draw_commands()
  let before_has_bubble = before.any(command => {
    match command {
      @core.DrawCommand::DrawText({ text, .. }) => text == "B"
      _ => false
    }
  })
  // "B" may appear elsewhere; the real guarantee is the bubble is gated on a
  // non-empty selection. Set a non-empty selection and confirm the bubble's
  // format glyphs (H1/H2/❝) render, which only the bubble emits.
  app.set_selection(5, Some(@core.TextRange::new(start=0, end=9)))
  let after = app.runtime(width=980.0, height=640.0).draw_commands()
  let after_has_h1 = after.any(command => {
    match command {
      @core.DrawCommand::DrawText({ text, .. }) => text == "H1"
      _ => false
    }
  })
  assert_true(after_has_h1)
  // Collapsing the selection hides the bubble.
  app.set_selection(5, None)
  let collapsed = app.runtime(width=980.0, height=640.0).draw_commands()
  let collapsed_has_h1 = collapsed.any(command => {
    match command {
      @core.DrawCommand::DrawText({ text, .. }) => text == "H1"
      _ => false
    }
  })
  assert_true(!collapsed_has_h1)
  ignore(before_has_bubble)
}
