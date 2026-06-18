using @moui_richtext {
  type MarkdownBlockKind,
  type MarkdownInlineKind,
  markdown_block_to_rich_text,
  markdown_editor_format,
  markdown_editor_format_for_selection,
  parse_markdown,
}

fn MarkdownEditorApp::document(self : MarkdownEditorApp) -> String {
  self.document.get()
}

///|
fn MarkdownEditorApp::set_document(
  self : MarkdownEditorApp,
  text : String,
) -> Unit {
  self.load_document(text, path="")
}

///|
fn MarkdownEditorApp::load_document_for_test(
  self : MarkdownEditorApp,
  text : String,
  path~ : String,
) -> Unit {
  self.load_document(text, path~)
}

///|
fn MarkdownEditorApp::edit_document(
  self : MarkdownEditorApp,
  text : String,
) -> Unit {
  self.set_document_from_input(text)
}

///|
fn MarkdownEditorApp::clear(self : MarkdownEditorApp) -> Unit {
  self.new_document()
}

///|
fn MarkdownEditorApp::apply_action(
  self : MarkdownEditorApp,
  action : String,
) -> Unit {
  ignore(self.apply_named_editor_action(action))
}

///|
fn MarkdownEditorApp::source_preview_visible(self : MarkdownEditorApp) -> Bool {
  self.source_preview_visible.get()
}

///|
fn MarkdownEditorApp::source_mode_enabled(self : MarkdownEditorApp) -> Bool {
  self.source_mode_enabled.get()
}

///|
fn MarkdownEditorApp::outline_visible(self : MarkdownEditorApp) -> Bool {
  self.outline_visible.get()
}

///|
fn MarkdownEditorApp::file_sidebar_visible(self : MarkdownEditorApp) -> Bool {
  self.file_sidebar_visible.get()
}

///|
fn MarkdownEditorApp::document_info_visible(self : MarkdownEditorApp) -> Bool {
  self.document_info_visible.get()
}

///|
fn MarkdownEditorApp::focus_mode_enabled(self : MarkdownEditorApp) -> Bool {
  self.focus_mode_enabled.get()
}

///|
fn MarkdownEditorApp::typewriter_mode_enabled(self : MarkdownEditorApp) -> Bool {
  self.typewriter_mode_enabled.get()
}

///|
fn MarkdownEditorApp::zen_mode_enabled(self : MarkdownEditorApp) -> Bool {
  self.zen_mode_enabled.get()
}

///|
fn MarkdownEditorApp::format_palette_visible(self : MarkdownEditorApp) -> Bool {
  self.format_palette_visible.get()
}

///|
fn MarkdownEditorApp::format_palette_query(self : MarkdownEditorApp) -> String {
  self.format_palette_query.get()
}

///|
fn MarkdownEditorApp::appearance_label_for_test(
  self : MarkdownEditorApp,
) -> String {
  self.appearance_label()
}

///|
fn MarkdownEditorApp::editor_font_size_for_test(
  self : MarkdownEditorApp,
) -> Double {
  self.appearance_spec().editor_font_size
}

///|
fn MarkdownEditorApp::editor_page_width_for_test(
  self : MarkdownEditorApp,
) -> Double {
  self.appearance_spec().page_width
}

///|
fn MarkdownEditorApp::find_visible(self : MarkdownEditorApp) -> Bool {
  self.find_visible.get()
}

///|
fn MarkdownEditorApp::find_query(self : MarkdownEditorApp) -> String {
  self.find_query.get()
}

///|
fn MarkdownEditorApp::replace_text(self : MarkdownEditorApp) -> String {
  self.replace_text.get()
}

///|
fn MarkdownEditorApp::transfer_status_label_for_test(
  self : MarkdownEditorApp,
) -> String {
  self.transfer_status_label()
}

///|
fn MarkdownEditorApp::import_clipboard_for_test(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> Unit {
  self.perform_clipboard_import(services)
}

///|
fn MarkdownEditorApp::export_clipboard_for_test(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> Unit {
  self.perform_clipboard_export(services)
}

///|
fn MarkdownEditorApp::export_html_for_test(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> Unit {
  self.perform_html_export(services)
}

///|
fn MarkdownEditorApp::html_export_for_test(self : MarkdownEditorApp) -> String {
  self.html_export_document()
}

///|
fn MarkdownEditorApp::save_as_dialog_for_test(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> Unit {
  self.perform_file_save_as(services)
}

///|
fn MarkdownEditorApp::open_target_for_test(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> Unit {
  self.perform_open_target(services)
}

///|
fn MarkdownEditorApp::open_recent_for_test(
  self : MarkdownEditorApp,
  path : String,
  services : @host.HostAppServices,
) -> Unit {
  self.perform_text_file_read(path, services)
}

///|
fn MarkdownEditorApp::set_find_query(
  self : MarkdownEditorApp,
  query : String,
) -> Unit {
  self.find_query.set(query)
}

///|
fn MarkdownEditorApp::update_find_query_for_test(
  self : MarkdownEditorApp,
  query : String,
) -> Unit {
  ignore(self.update(UpdateFindQuery(query)))
}

///|
fn MarkdownEditorApp::set_replace_text(
  self : MarkdownEditorApp,
  replacement : String,
) -> Unit {
  self.replace_text.set(replacement)
}

///|
fn MarkdownEditorApp::find_next_for_test(self : MarkdownEditorApp) -> Unit {
  self.find_next()
}

///|
fn MarkdownEditorApp::find_previous_for_test(self : MarkdownEditorApp) -> Unit {
  self.find_previous()
}

///|
fn MarkdownEditorApp::replace_current_find_match_for_test(
  self : MarkdownEditorApp,
) -> Unit {
  self.replace_current_find_match()
}

///|
fn MarkdownEditorApp::replace_all_find_matches_for_test(
  self : MarkdownEditorApp,
) -> Unit {
  self.replace_all_find_matches()
}

///|
fn MarkdownEditorApp::set_outline_visible(
  self : MarkdownEditorApp,
  visible : Bool,
) -> Unit {
  self.outline_visible.set(visible)
}

///|
fn MarkdownEditorApp::set_file_sidebar_visible(
  self : MarkdownEditorApp,
  visible : Bool,
) -> Unit {
  self.file_sidebar_visible.set(visible)
}

///|
fn MarkdownEditorApp::set_document_info_visible(
  self : MarkdownEditorApp,
  visible : Bool,
) -> Unit {
  self.document_info_visible.set(visible)
}

///|
fn MarkdownEditorApp::set_format_palette_visible(
  self : MarkdownEditorApp,
  visible : Bool,
) -> Unit {
  self.format_palette_visible.set(visible)
}

///|
fn MarkdownEditorApp::set_format_palette_query(
  self : MarkdownEditorApp,
  query : String,
) -> Unit {
  self.format_palette_query.set(query)
}

///|
fn MarkdownEditorApp::set_source_preview_visible(
  self : MarkdownEditorApp,
  visible : Bool,
) -> Unit {
  self.source_preview_visible.set(visible)
}

///|
fn MarkdownEditorApp::document_info_for_test(
  self : MarkdownEditorApp,
) -> MarkdownEditorDocumentInfo {
  markdown_editor_document_info(
    MarkdownEditorSnapshot::parse(self.document.get()),
  )
}

///|
fn MarkdownEditorApp::can_undo(self : MarkdownEditorApp) -> Bool {
  self.undo_stack.get().length() > 0
}

///|
fn MarkdownEditorApp::can_redo(self : MarkdownEditorApp) -> Bool {
  self.redo_stack.get().length() > 0
}

///|
fn MarkdownEditorApp::set_link_target(
  self : MarkdownEditorApp,
  target : String,
) -> Unit {
  self.link_target.set(target)
}

///|
fn MarkdownEditorApp::set_image_target(
  self : MarkdownEditorApp,
  target : String,
) -> Unit {
  self.image_target.set(target)
}

///|
fn MarkdownEditorApp::set_footnote_text(
  self : MarkdownEditorApp,
  text : String,
) -> Unit {
  self.footnote_text.set(text)
}

///|
fn MarkdownEditorApp::set_html_block_text(
  self : MarkdownEditorApp,
  text : String,
) -> Unit {
  self.html_block_text.set(text)
}

///|
fn MarkdownEditorApp::link_target(self : MarkdownEditorApp) -> String {
  self.link_target.get()
}

///|
fn MarkdownEditorApp::image_target(self : MarkdownEditorApp) -> String {
  self.image_target.get()
}

///|
fn MarkdownEditorApp::footnote_text(self : MarkdownEditorApp) -> String {
  self.footnote_text.get()
}

///|
fn MarkdownEditorApp::html_block_text(self : MarkdownEditorApp) -> String {
  self.html_block_text.get()
}

///|
fn MarkdownEditorApp::target_kind(
  self : MarkdownEditorApp,
) -> MarkdownEditorTargetKind {
  self.target_kind.get()
}

///|
fn MarkdownEditorApp::block_label(self : MarkdownEditorApp) -> String {
  self.block_label.get()
}

///|
fn MarkdownEditorApp::selection_caret(self : MarkdownEditorApp) -> Int {
  self.selection.get().caret
}

///|
fn MarkdownEditorApp::editor_scroll_y(self : MarkdownEditorApp) -> Double {
  self.editor_scroll.offset().y
}

///|
fn MarkdownEditorApp::document_path(self : MarkdownEditorApp) -> String {
  self.document_path.get()
}

///|
fn MarkdownEditorApp::recent_document_paths(
  self : MarkdownEditorApp,
) -> Array[String] {
  self.recent_document_paths.get()
}

///|
fn MarkdownEditorApp::saved_document(self : MarkdownEditorApp) -> String {
  self.saved_document.get()
}

///|
fn MarkdownEditorApp::dirty(self : MarkdownEditorApp) -> Bool {
  self.is_dirty()
}

///|
fn MarkdownEditorApp::mark_saved_for_test(self : MarkdownEditorApp) -> Unit {
  self.mark_document_saved()
}

///|
fn MarkdownEditorApp::save_as_for_test(
  self : MarkdownEditorApp,
  path : String,
) -> Unit {
  self.save_document_as(path)
}

///|
fn MarkdownEditorApp::document_status_label_for_test(
  self : MarkdownEditorApp,
) -> String {
  let snapshot = MarkdownEditorSnapshot::parse(self.document.get())
  self.document_status_label(
    snapshot,
    self.block_label.get(),
    self.selection.get(),
  )
}

///|
fn MarkdownEditorApp::jump_to_outline_for_test(
  self : MarkdownEditorApp,
  source_start : Int,
) -> Unit {
  self.jump_to_outline(source_start)
}

///|
fn MarkdownEditorApp::runtime(
  self : MarkdownEditorApp,
  width? : Double = 1120.0,
  height? : Double = 720.0,
) -> @runtime.AppRuntime {
  self.runtime_with_services(
    @host.HostAppServices::unavailable(),
    width~,
    height~,
  )
}

///|
fn MarkdownEditorApp::runtime_with_services(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
  width? : Double = 1120.0,
  height? : Double = 720.0,
) -> @runtime.AppRuntime {
  let runtime = @runtime.new_program_with_dimensions(
    program=self.program_with_services(services),
    width~,
    height~,
  )
  runtime.set_action_commands(self.action_commands(services~))
  runtime
}

///|
fn markdown_editor_apply_command(
  source : String,
  command : MarkdownEditorCommand,
) -> String {
  markdown_editor_apply_command_at(source, command, None).source
}

///|
fn markdown_to_rich_text(text : String) -> @moui_richtext.RichTextDocument {
  let blocks : Array[@moui_richtext.RichTextBlock] = []
  let base = @core.FontSpec::new()
  for block in parse_markdown(text) {
    blocks.push(markdown_block_to_rich_text(block, base))
  }
  @moui_richtext.RichTextDocument::new(blocks~)
}
