///|
using @moui_richtext {
  type MarkdownBlockKind,
  type MarkdownInlineKind,
  markdown_block_to_rich_text,
  markdown_editor_format,
  markdown_editor_format_for_writing_mode,
  markdown_editor_format_for_selection,
  markdown_editor_transform_input,
  parse_markdown,
}

///|
fn MarkdownEditorApp::document(self : MarkdownEditorApp) -> String {
  self.document_session.source()
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
fn MarkdownEditorApp::set_document_from_input(
  self : MarkdownEditorApp,
  value : String,
) -> Unit {
  let selection = self.selection
  self.apply_editor_transaction(
    MarkdownEditTransaction::from_sources(
      self.document_session.source(),
      value,
      caret=selection.caret,
      selection=selection.selection,
      reason=TextInput,
    ),
  )
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
  self.source_preview_visible
}

///|
fn MarkdownEditorApp::source_mode_enabled(self : MarkdownEditorApp) -> Bool {
  self.source_mode_enabled
}

///|
fn MarkdownEditorApp::outline_visible(self : MarkdownEditorApp) -> Bool {
  self.outline_visible
}

///|
fn MarkdownEditorApp::file_sidebar_visible(self : MarkdownEditorApp) -> Bool {
  self.file_sidebar_visible
}

///|
fn MarkdownEditorApp::document_info_visible(self : MarkdownEditorApp) -> Bool {
  self.document_info_visible
}

///|
fn MarkdownEditorApp::focus_mode_enabled(self : MarkdownEditorApp) -> Bool {
  self.focus_mode_enabled
}

///|
fn MarkdownEditorApp::typewriter_mode_enabled(self : MarkdownEditorApp) -> Bool {
  self.typewriter_mode_enabled
}

///|
fn MarkdownEditorApp::zen_mode_enabled(self : MarkdownEditorApp) -> Bool {
  self.zen_mode_enabled
}

///|
fn MarkdownEditorApp::format_palette_visible(self : MarkdownEditorApp) -> Bool {
  self.format_palette_visible
}

///|
fn MarkdownEditorApp::format_palette_query(self : MarkdownEditorApp) -> String {
  self.format_palette_query
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
  self.find_visible
}

///|
fn MarkdownEditorApp::find_query(self : MarkdownEditorApp) -> String {
  self.find_query
}

///|
fn MarkdownEditorApp::find_match_count(self : MarkdownEditorApp) -> Int {
  self.find_matches.length()
}

///|
fn MarkdownEditorApp::replace_text(self : MarkdownEditorApp) -> String {
  self.replace_text
}

///|
fn MarkdownEditorApp::transfer_status_label_for_test(
  self : MarkdownEditorApp,
) -> String {
  markdown_editor_transfer_status_label(self.transfer_status)
}

///|
fn MarkdownEditorApp::overwrite_from_for_test(
  self : MarkdownEditorApp,
  latest : MarkdownEditorApp,
) -> Unit {
  self.document = latest.document
  self.document_session = latest.document_session
  self.selection = latest.selection
  self.link_target = latest.link_target
  self.image_target = latest.image_target
  self.footnote_text = latest.footnote_text
  self.html_block_text = latest.html_block_text
  self.target_kind = latest.target_kind
  self.block_label = latest.block_label
  self.source_preview_visible = latest.source_preview_visible
  self.source_mode_enabled = latest.source_mode_enabled
  self.outline_visible = latest.outline_visible
  self.file_sidebar_visible = latest.file_sidebar_visible
  self.document_info_visible = latest.document_info_visible
  self.focus_mode_enabled = latest.focus_mode_enabled
  self.typewriter_mode_enabled = latest.typewriter_mode_enabled
  self.zen_mode_enabled = latest.zen_mode_enabled
  self.format_palette_visible = latest.format_palette_visible
  self.format_palette_query = latest.format_palette_query
  self.more_menu_visible = latest.more_menu_visible
  self.active_menu = latest.active_menu
  self.toasts = latest.toasts
  self.autosave_draft = latest.autosave_draft
  self.dark_mode_enabled = latest.dark_mode_enabled
  self.font_family = latest.font_family
  self.folded_headings = latest.folded_headings
  self.pending_confirm = latest.pending_confirm
  self.writing_appearance = latest.writing_appearance
  self.find_visible = latest.find_visible
  self.find_query = latest.find_query
  self.find_options = latest.find_options
  self.find_matches = latest.find_matches
  self.replace_text = latest.replace_text
  self.document_path = latest.document_path
  self.recent_document_paths = latest.recent_document_paths
  self.saved_document = latest.saved_document
  self.transfer_status = latest.transfer_status
  self.transfer_generation = latest.transfer_generation
  self.undo_stack = latest.undo_stack
  self.redo_stack = latest.redo_stack
  self.editor_scroll = latest.editor_scroll
  self.file_filter_query = latest.file_filter_query
  self.working_directory = latest.working_directory
  self.expanded_tree_paths = latest.expanded_tree_paths
  self.directory_tree_items = latest.directory_tree_items
  self.file_tree_expanded = latest.file_tree_expanded
  self.image_centered = latest.image_centered
}

///|
fn MarkdownEditorApp::tracked_program_for_test(
  self : MarkdownEditorApp,
  services : @services.AppServices,
) -> @moui.Program[MarkdownEditorApp, MarkdownEditorMsg] {
  @moui.Program::new_with_environment(
    init=() => (self, @moui.Effect::none()),
    update=(app, message) => {
      let (next, effect) = app.update_with_services(message, services)
      self.overwrite_from_for_test(next)
      (next, effect)
    },
    view=(app, view_environment) => {
      self.overwrite_from_for_test(app)
      app.root_with_environment(view_environment)
    },
  ).with_commands(commands=_ => markdown_editor_program_commands())
}

///|
fn MarkdownEditorApp::dispatch_message_for_test(
  self : MarkdownEditorApp,
  services : @services.AppServices,
  message : MarkdownEditorMsg,
) -> Unit {
  let program = self
    .tracked_program_for_test(services)
    .with_commands(commands=_ => {
      [
        @moui.ProgramCommand::new(
          command=@core.ActionCommand::new(intent=@core.CommandIntent::Activate),
          message~,
        ),
      ]
    })
  let runtime = @runtime.new_program_with_dimensions(
    program~,
    width=1120.0,
    height=720.0,
  )
  ignore(runtime.dispatch_command(@core.CommandIntent::Activate))
}

///|
fn MarkdownEditorApp::import_clipboard_for_test(
  self : MarkdownEditorApp,
  services : @services.AppServices,
) -> Unit {
  self.dispatch_message_for_test(services, ImportFromClipboard)
}

///|
fn MarkdownEditorApp::export_clipboard_for_test(
  self : MarkdownEditorApp,
  services : @services.AppServices,
) -> Unit {
  self.dispatch_message_for_test(services, ExportToClipboard)
}

///|
fn MarkdownEditorApp::export_html_for_test(
  self : MarkdownEditorApp,
  services : @services.AppServices,
) -> Unit {
  self.dispatch_message_for_test(services, ExportHtmlToClipboard)
}

///|
fn MarkdownEditorApp::html_export_for_test(self : MarkdownEditorApp) -> String {
  self.html_export_document()
}

///|
fn MarkdownEditorApp::save_as_dialog_for_test(
  self : MarkdownEditorApp,
  services : @services.AppServices,
) -> Unit {
  self.dispatch_message_for_test(services, SaveDocumentAs)
}

///|
fn MarkdownEditorApp::open_target_for_test(
  self : MarkdownEditorApp,
  services : @services.AppServices,
) -> Unit {
  self.dispatch_message_for_test(services, OpenTarget)
}

///|
fn MarkdownEditorApp::open_recent_for_test(
  self : MarkdownEditorApp,
  path : String,
  services : @services.AppServices,
) -> Unit {
  self.dispatch_message_for_test(services, OpenRecentDocument(path))
}

///|
fn MarkdownEditorApp::pick_working_directory_for_test(
  self : MarkdownEditorApp,
  services : @services.AppServices,
) -> Unit {
  self.dispatch_message_for_test(services, PickWorkingDirectory)
}

///|
fn MarkdownEditorApp::working_directory(self : MarkdownEditorApp) -> String {
  self.working_directory
}

///|
fn MarkdownEditorApp::expanded_tree_paths(
  self : MarkdownEditorApp,
) -> Array[String] {
  self.expanded_tree_paths
}

///|
fn MarkdownEditorApp::set_find_query(
  self : MarkdownEditorApp,
  query : String,
) -> Unit {
  self.find_query = query
}

///|
fn MarkdownEditorApp::update_find_query_for_test(
  self : MarkdownEditorApp,
  query : String,
) -> Unit {
  self.update_in_place(UpdateFindQuery(query))
}

///|
fn MarkdownEditorApp::set_replace_text(
  self : MarkdownEditorApp,
  replacement : String,
) -> Unit {
  self.replace_text = replacement
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
  self.outline_visible = visible
}

///|
fn MarkdownEditorApp::set_file_sidebar_visible(
  self : MarkdownEditorApp,
  visible : Bool,
) -> Unit {
  self.file_sidebar_visible = visible
}

///|
fn MarkdownEditorApp::set_document_info_visible(
  self : MarkdownEditorApp,
  visible : Bool,
) -> Unit {
  self.document_info_visible = visible
}

///|
fn MarkdownEditorApp::set_format_palette_visible(
  self : MarkdownEditorApp,
  visible : Bool,
) -> Unit {
  self.format_palette_visible = visible
}

///|
fn MarkdownEditorApp::set_format_palette_query(
  self : MarkdownEditorApp,
  query : String,
) -> Unit {
  self.format_palette_query = query
}

///|
fn MarkdownEditorApp::set_source_preview_visible(
  self : MarkdownEditorApp,
  visible : Bool,
) -> Unit {
  self.source_preview_visible = visible
}

///|
fn MarkdownEditorApp::document_info_for_test(
  self : MarkdownEditorApp,
) -> MarkdownEditorDocumentInfo {
  markdown_editor_document_info(self.document_session.snapshot())
}

///|
fn MarkdownEditorApp::set_link_target(
  self : MarkdownEditorApp,
  target : String,
) -> Unit {
  self.link_target = target
}

///|
fn MarkdownEditorApp::set_image_target(
  self : MarkdownEditorApp,
  target : String,
) -> Unit {
  self.image_target = target
}

///|
fn MarkdownEditorApp::set_footnote_text(
  self : MarkdownEditorApp,
  text : String,
) -> Unit {
  self.footnote_text = text
}

///|
fn MarkdownEditorApp::set_html_block_text(
  self : MarkdownEditorApp,
  text : String,
) -> Unit {
  self.html_block_text = text
}

///|
fn MarkdownEditorApp::link_target(self : MarkdownEditorApp) -> String {
  self.link_target
}

///|
fn MarkdownEditorApp::image_target(self : MarkdownEditorApp) -> String {
  self.image_target
}

///|
fn MarkdownEditorApp::footnote_text(self : MarkdownEditorApp) -> String {
  self.footnote_text
}

///|
fn MarkdownEditorApp::html_block_text(self : MarkdownEditorApp) -> String {
  self.html_block_text
}

///|
fn MarkdownEditorApp::target_kind(
  self : MarkdownEditorApp,
) -> MarkdownEditorTargetKind {
  self.target_kind
}

///|
fn MarkdownEditorApp::block_label(self : MarkdownEditorApp) -> String {
  self.block_label
}

///|
fn MarkdownEditorApp::selection_caret(self : MarkdownEditorApp) -> Int {
  self.selection.caret
}

///|
fn MarkdownEditorApp::editor_scroll_y(self : MarkdownEditorApp) -> Double {
  self.editor_scroll.y
}

///|
fn MarkdownEditorApp::document_path(self : MarkdownEditorApp) -> String {
  self.document_path
}

///|
fn MarkdownEditorApp::recent_document_paths(
  self : MarkdownEditorApp,
) -> Array[String] {
  self.recent_document_paths
}

///|
fn MarkdownEditorApp::saved_document(self : MarkdownEditorApp) -> String {
  self.saved_document
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
  let snapshot = self.document_session.snapshot()
  let block_label = self.block_label
  let selection = self.selection
  let title = markdown_editor_document_title(
    path=self.document_path,
    fallback=snapshot.active_heading,
  )
  let save_state = if self.is_dirty() { "Unsaved" } else { "Saved" }
  let transfer = markdown_editor_transfer_status_label(self.transfer_status)
  let transfer_suffix = if transfer == "" { "" } else { " / " + transfer }
  let mode_suffix = self.writing_mode_status_suffix()
  let look_suffix = self.appearance_status_suffix()
  let source_suffix = self.source_mode_status_suffix()
  title +
  " / " +
  save_state +
  " / " +
  markdown_editor_status_label(block_label, snapshot, selection) +
  mode_suffix +
  source_suffix +
  look_suffix +
  transfer_suffix
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
    @services.AppServices::unavailable(),
    width~,
    height~,
  )
}

///|
fn MarkdownEditorApp::runtime_with_services(
  self : MarkdownEditorApp,
  services : @services.AppServices,
  width? : Double = 1120.0,
  height? : Double = 720.0,
) -> @runtime.AppRuntime {
  let runtime = @runtime.new_program_with_dimensions(
    program=self.tracked_program_for_test(services),
    width~,
    height~,
  )
  runtime.set_event_observer(_event => {
    ignore(runtime.draw_frame())
    if !runtime.focused_text_input().focused {
      ignore(runtime.focus_key("markdown-editor"))
    }
  })
  runtime
}

///|
/// The horizontal origin of the editor's text content. The chrome has no
/// left/right padding; the workspace fills the window width; the editor is
/// centered between two equal-weight spacers in the row, with left/right
/// inspectors (files on the left; info/outline/source on the right) pushing
/// it toward the center of the remaining space. `inner_x` is the offset from
/// the content's left edge (the editor content rect has a 14px horizontal
/// inset).
fn MarkdownEditorApp::editor_content_x(
  self : MarkdownEditorApp,
  window_width : Double,
  inner_x? : Double = 4.0,
) -> Double {
  let appearance = self.appearance_spec()
  let show_files = self.file_sidebar_visible
  let show_info = self.document_info_visible
  let show_outline = self.outline_visible
  let show_source = self.source_preview_visible
  let editor_width = markdown_editor_primary_editor_width_for_viewport(
    show_source,
    show_outline,
    show_files,
    show_info,
    appearance,
    viewport_width=window_width,
  )
  let left_width = if show_files {
    markdown_editor_file_sidebar_width()
  } else {
    0.0
  }
  let right_width = markdown_editor_sidebar_total_width(
    show_source, show_outline, false, show_info,
  )
  let available = window_width - left_width - right_width
  let editor_x = left_width +
    markdown_editor_max_double(0.0, (available - editor_width) / 2.0)
  editor_x + 14.0 + inner_x
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

///|
fn MarkdownEditorApp::document_session_parse_count(
  self : MarkdownEditorApp,
) -> Int {
  self.document_session.parse_count
}
