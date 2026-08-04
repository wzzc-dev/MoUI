///|
fn MarkdownEditorApp::push_toast_for_test(
  self : MarkdownEditorApp,
  message : String,
  tone? : @views.FeedbackTone = @views.FeedbackTone::Neutral,
) -> Unit {
  let queue = self.toasts.get()
  let serial = queue.items.length()
  self.toasts.set(
    queue.push(
      @views.ToastQueueItem::new(
        id="toast-" + serial.to_string(),
        message~,
        tone~,
        dismiss=Some(DismissToastTick),
      ),
    ),
  )
}

///|
test "markdown editor push_toast renders a toast layer message" {
  let app = MarkdownEditorApp::new()
  // No toasts initially: the toast layer renders nothing relevant.
  let before = app.runtime(width=980.0, height=640.0).draw_commands()
  let before_has = before.any(command => {
    match command {
      @core.DrawCommand::DrawText({ text, .. }) =>
        text.contains("Saved draft.md")
      _ => false
    }
  })
  assert_true(!before_has)
  // Push a toast and confirm the layer now renders its message.
  app.push_toast_for_test("Saved draft.md", tone=@views.FeedbackTone::Success)
  let after = app.runtime(width=980.0, height=640.0).draw_commands()
  let after_has = after.any(command => {
    match command {
      @core.DrawCommand::DrawText({ text, .. }) =>
        text.contains("Saved draft.md")
      _ => false
    }
  })
  assert_true(after_has)
}

///|
test "markdown editor confirm dialog guards dirty New Document" {
  let app = MarkdownEditorApp::new()
  app.load_document_for_test("# Plan", path="/tmp/plan.md")
  app.edit_document("# Plan\n\nMore")
  assert_true(app.is_dirty())
  // A New Document on a dirty document should stage a confirm request instead
  // of clearing the document.
  let _ = app.update(NewDocument)
  assert_true(app.pending_confirm.get() is Some(_))
  // The document is still intact (not cleared) while the confirm is pending.
  assert_true(app.document.get().contains("Plan"))
}

///|
test "markdown editor confirm cancel keeps the document" {
  let app = MarkdownEditorApp::new()
  app.load_document_for_test("# Plan", path="/tmp/plan.md")
  app.edit_document("# Plan\n\nMore")
  let _ = app.update(NewDocument)
  assert_true(app.pending_confirm.get() is Some(_))
  let _ = app.update(ResolvePendingConfirm(ConfirmCancel))
  assert_true(app.pending_confirm.get() is None)
  assert_true(app.document.get().contains("Plan"))
}

///|
test "markdown editor confirm discard runs the deferred action" {
  let app = MarkdownEditorApp::new()
  app.load_document_for_test("# Plan", path="/tmp/plan.md")
  app.edit_document("# Plan\n\nMore")
  let _ = app.update(NewDocument)
  assert_true(app.pending_confirm.get() is Some(_))
  // Discard should run the deferred NewDocument, clearing the editor content.
  let _ = app.update(ResolvePendingConfirm(ConfirmDiscard))
  assert_true(app.pending_confirm.get() is None)
  assert_true(!app.document.get().contains("Plan"))
}

///|
test "markdown editor dark mode toggle switches chrome theme" {
  let app = MarkdownEditorApp::new()
  // Light by default.
  assert_true(!app.dark_mode_enabled.get())
  // Toggling flips to dark.
  app.dark_mode_enabled.set(true)
  assert_true(app.dark_mode_enabled.get())
  // The chrome theme helper reflects the toggle.
  let light_palette = @views.light_theme().palette.background
  let dark_palette = @views.dark_theme().palette.background
  let resolved = app.chrome_theme().palette.background
  assert_true(resolved == dark_palette && resolved != light_palette)
  // The editor appearance now follows dark mode: page background flips from
  // white to dark, so the editor body is no longer a white island in a dark
  // chrome.
  let light_spec = MarkdownEditorApp::new().appearance_spec()
  let dark_spec = app.appearance_spec()
  assert_true(dark_spec.page_background != light_spec.page_background)
  assert_true(dark_spec.foreground != light_spec.foreground)
}

///|
test "markdown editor confirm dialog renders when pending" {
  let app = MarkdownEditorApp::new()
  app.load_document_for_test("# Plan", path="/tmp/plan.md")
  app.edit_document("# Plan\n\nMore")
  let _ = app.update(NewDocument)
  let commands = app.runtime(width=980.0, height=640.0).draw_commands()
  let has_dialog = commands.any(command => {
    match command {
      @core.DrawCommand::DrawText({ text, .. }) =>
        text.contains("Unsaved changes")
      _ => false
    }
  })
  assert_true(has_dialog)
}
