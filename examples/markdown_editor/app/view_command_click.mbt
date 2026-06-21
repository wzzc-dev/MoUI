///|
/// Handle a Cmd/Ctrl-click at a source offset. If the offset lands inside a
/// link or autolink, open the target via the host; if it lands on an image,
/// select it so the image target palette appears. Otherwise the click is a
/// no-op (the editor already skipped caret placement for modifier-held clicks).
fn MarkdownEditorApp::handle_command_click(
  self : MarkdownEditorApp,
  offset : Int,
) -> Unit {
  let source = self.document.get()
  let probe : MarkdownEditorSelection = { caret: offset, selection: None }
  match @moui_richtext.markdown_editor_selected_link_target(source, probe) {
    Some(target) => {
      // Open the link target through the host (URL open flow).
      self.link_target.set(target)
      let _ = self.update(OpenTarget)
    }
    None =>
      match
        @moui_richtext.markdown_editor_selected_image_target(source, probe) {
        Some(target) => {
          // Select the image inline and surface its target palette.
          self.image_target.set(target)
          self.target_kind.set(ImageTarget)
        }
        None => ()
      }
  }
}
