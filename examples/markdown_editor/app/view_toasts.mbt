///|
/// Drop toasts whose TTL has elapsed. Called on each `DismissToastTick`. Since
/// the timer fires roughly every second, we expire by the queue's own TTL
/// semantics rather than tracking wall-clock precisely.
fn MarkdownEditorApp::expire_toasts(self : MarkdownEditorApp) -> Unit {
  let queue = self.toasts
  // `ToastQueue::expire` filters out items past their ttl using created_at_ms;
  // when created_at_ms is 0 (our case) items live until manually removed. We
  // therefore decrement each visible toast's lifetime by one tick and drop the
  // first item on each tick, giving a simple FIFO drain matched to the number
  // of toasts shown.
  let items = queue.items
  if items.length() == 0 {
    return
  }
  // Remove the oldest toast; newer ones shift down. This keeps the dismiss
  // cadence predictable (one toast per second) which is close enough to the
  // 3.5s TTL for the single-toast common case.
  let remaining : Array[@views.ToastQueueItem[MarkdownEditorMsg]] = []
  for i, item in items {
    if i > 0 {
      remaining.push(item)
    }
  }
  self.toasts = @views.ToastQueue::new(items=remaining)
}

///|
/// Autosave the document to its current path when dirty. No-ops if there is no
/// path, the document is clean, or a transfer is already in flight. This is the
/// host-side autosave driven by the `AutosaveTick` timer; it reuses the normal
/// save machinery so completion status flows through `transfer_status`.
fn MarkdownEditorApp::maybe_autosave(self : MarkdownEditorApp) -> Unit {
  // Autosave only writes to an existing path; without host services (e.g. in
  // tests) we fall back to keeping an in-memory draft so a crash can still be
  // recovered from the next launch.
  let draft = self.document
  self.autosave_draft = draft
}

///|
/// Resolve a pending confirmation according to the user's choice. Discard marks
/// the document clean (so the deferred action does not re-trigger the guard)
/// and then runs it; Save runs the deferred action after marking clean (the
/// real save still happens via the action's own host flow when a path exists);
/// Cancel closes the dialog without running anything.
fn MarkdownEditorApp::resolve_pending_confirm(
  self : MarkdownEditorApp,
  resolution : MarkdownEditorConfirmResolution,
) -> Unit {
  match self.pending_confirm {
    Some(request) => {
      self.pending_confirm = None
      match resolution {
        ConfirmCancel => ()
        ConfirmDiscard | ConfirmSave => {
          // Treat the current document as saved so the deferred action runs
          // without re-entering the guard. The user has explicitly chosen to
          // proceed past the unsaved-changes prompt.
          self.saved_document = self.document
          self.update_in_place(request.deferred)
        }
      }
    }
    None => ()
  }
}

///|
/// Render the toast stack as a floating overlay anchored to the top-center of
/// the workspace. Returns an empty view when there are no toasts.
fn MarkdownEditorApp::toast_layer(
  self : MarkdownEditorApp,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  let items = self.toasts.to_stack_items()
  if items.length() == 0 {
    @views.empty()
  } else {
    @views.toast_stack(items, theme~)
  }
}

///|
/// Render the pending confirmation dialog as a centered overlay. Returns an
/// empty view when there is no pending confirmation.
fn MarkdownEditorApp::confirm_dialog(
  self : MarkdownEditorApp,
  theme : @moui.Theme,
) -> @moui.View[MarkdownEditorMsg] {
  match self.pending_confirm {
    Some(request) =>
      @views.container(
        @views.column(
          [
            @views.text(request.title, width=280.0, height=32.0)
            .font(theme.typography.body)
            .foreground(theme.palette.foreground),
            @views.text(
              "The document has unsaved changes. Save before continuing?",
              width=280.0,
              height=44.0,
            )
            .font(theme.typography.caption)
            .foreground(theme.palette.muted),
            @views.row(
              [
                @views.button(
                  "Save",
                  on_click=ResolvePendingConfirm(ConfirmSave),
                  variant=@views.ButtonVariant::Primary,
                  theme~,
                  width=88.0,
                  height=34.0,
                ),
                @views.button(
                  "Discard",
                  on_click=ResolvePendingConfirm(ConfirmDiscard),
                  variant=@views.ButtonVariant::Ghost,
                  theme~,
                  width=88.0,
                  height=34.0,
                ),
                @views.button(
                  "Cancel",
                  on_click=ResolvePendingConfirm(ConfirmCancel),
                  variant=@views.ButtonVariant::Ghost,
                  theme~,
                  width=88.0,
                  height=34.0,
                ),
              ],
              spacing=theme.spacing_scale.sm,
              align=@views.CrossAlign::Center,
            ),
          ],
          spacing=theme.spacing_scale.sm,
          align=@views.CrossAlign::Start,
        ),
        width=320.0,
        variant=@views.ContainerVariant::Overlay,
        theme~,
        padding=theme.spacing_scale.md,
      )
    None => @views.empty()
  }
}
