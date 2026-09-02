///|
fn MarkdownEditorApp::new_document(self : MarkdownEditorApp) -> Unit {
  self.load_document("", path="")
}

///|
fn MarkdownEditorApp::load_document(
  self : MarkdownEditorApp,
  source : String,
  path~ : String,
) -> Unit {
  self.replace_document_source(source, reason=LoadDocument)
  self.document_path = path
  self.record_recent_document_path(path)
  self.saved_document = source
  self.selection = { caret: 0, selection: None }
  self.selection_engaged = false
  self.reset_find_session()
  self.reset_format_palette()
  self.transfer_status = TransferReady
  self.clear_history()
  self.sync_target_inputs()
}

///|
fn MarkdownEditorApp::mark_document_saved(self : MarkdownEditorApp) -> Unit {
  self.saved_document = self.document
}

///|
pub fn MarkdownEditorApp::save_document_as(
  self : MarkdownEditorApp,
  path : String,
) -> Unit {
  self.document_path = path
  self.record_recent_document_path(path)
  self.mark_document_saved()
}

///|
fn MarkdownEditorApp::record_recent_document_path(
  self : MarkdownEditorApp,
  path : String,
) -> Unit {
  if path.trim().to_owned() == "" {
    return
  }
  let existing = self.recent_document_paths
  let next : Array[String] = [path]
  for candidate in existing {
    if candidate != path && next.length() < 8 {
      next.push(candidate)
    }
  }
  self.recent_document_paths = next
}

///|

///|
fn MarkdownEditorApp::begin_transfer(
  self : MarkdownEditorApp,
  kind : MarkdownEditorTransferKind,
) -> Int {
  let generation = self.transfer_generation + 1
  self.transfer_generation = generation
  self.transfer_status = TransferRunning(kind)
  generation
}

///|
fn MarkdownEditorApp::transfer_is_current(
  self : MarkdownEditorApp,
  generation : Int,
) -> Bool {
  self.transfer_generation == generation
}

///|
fn MarkdownEditorApp::request_file_open(
  self : MarkdownEditorApp,
  services : @services.AppServices,
) -> @moui.Effect[MarkdownEditorMsg] {
  let generation = self.begin_transfer(FileOpen)
  services
  .files()
  .open_file(
    options=@services.FileDialogOptions::new(title="Open Markdown", filters=[
      "md", "markdown",
    ]),
  )
  .effect(map=result => ServiceCompleted(FileOpenPicked(generation, result)))
}

///|
fn MarkdownEditorApp::request_document_save(
  self : MarkdownEditorApp,
  services : @services.AppServices,
) -> @moui.Effect[MarkdownEditorMsg] {
  let path = self.document_path
  if path == "" {
    self.request_file_save_as(services)
  } else {
    let generation = self.begin_transfer(FileSave)
    self.request_text_file_write_at(generation, path, services, save_as=false)
  }
}

///|
fn MarkdownEditorApp::request_file_save_as(
  self : MarkdownEditorApp,
  services : @services.AppServices,
) -> @moui.Effect[MarkdownEditorMsg] {
  let generation = self.begin_transfer(FileSaveAs)
  services
  .files()
  .save_file(options=self.save_file_dialog_options())
  .effect(map=result => ServiceCompleted(FileSavePicked(generation, result)))
}

///|
fn MarkdownEditorApp::request_text_file_read(
  self : MarkdownEditorApp,
  path : String,
  services : @services.AppServices,
) -> @moui.Effect[MarkdownEditorMsg] {
  if path == "" {
    self.transfer_status = TransferUnavailable("recent file path is empty")
    return @moui.Effect::none()
  }
  let generation = self.begin_transfer(FileOpen)
  self.request_text_file_read_at(generation, path, services)
}

///|
fn MarkdownEditorApp::request_text_file_read_at(
  _self : MarkdownEditorApp,
  generation : Int,
  path : String,
  services : @services.AppServices,
) -> @moui.Effect[MarkdownEditorMsg] {
  services
  .files()
  .read_text(path)
  .effect(map=result => ServiceCompleted(TextFileRead(generation, path, result)))
}

///|
fn MarkdownEditorApp::request_pick_working_directory(
  _self : MarkdownEditorApp,
  services : @services.AppServices,
) -> @moui.Effect[MarkdownEditorMsg] {
  services
  .files()
  .pick_directory(
    options=@services.FileDialogOptions::new(title="Choose Markdown workspace"),
  )
  .effect(map=result => ServiceCompleted(DirectoryPicked(result)))
}

///|
fn MarkdownEditorApp::request_directory_listing(
  _self : MarkdownEditorApp,
  path : String,
  services : @services.AppServices,
) -> @moui.Effect[MarkdownEditorMsg] {
  services
  .files()
  .list_directory(path)
  .effect(map=result => ServiceCompleted(DirectoryListed(path, result)))
}

///|
fn MarkdownEditorApp::apply_directory_listing(
  self : MarkdownEditorApp,
  path : String,
  result : @services.ServiceTaskResult[Array[@services.DirectoryEntry]],
) -> Unit {
  match result {
    Success(entries) => {
      let next_children = markdown_editor_tree_children_from_listing(
        path, entries,
      )
      if self.working_directory == path ||
        self.directory_tree_items.length() == 0 {
        self.directory_tree_items = [
          markdown_editor_root_tree_item(path, next_children),
        ]
      } else {
        self.directory_tree_items = markdown_editor_replace_tree_item_children(
          self.directory_tree_items,
          path,
          next_children,
        )
      }
      let current = self.expanded_tree_paths
      if !markdown_editor_string_array_contains(current, path) {
        let next = current.copy()
        next.push(path)
        self.expanded_tree_paths = next
      }
    }
    Failure(error) =>
      self.transfer_status = TransferUnavailable(
        "directory listing unavailable: " + error.message,
      )
    Cancelled =>
      self.transfer_status = TransferUnavailable("directory listing cancelled")
  }
}

///|
fn markdown_editor_root_tree_item(
  path : String,
  children : Array[@views.TreeItem],
) -> @views.TreeItem {
  let root_name = markdown_editor_file_name(path)
  let label = if root_name == "" { path } else { root_name }
  @views.tree_item(id=path, label~, children~)
}

///|
fn markdown_editor_tree_children_from_listing(
  path : String,
  entries : Array[@services.DirectoryEntry],
) -> Array[@views.TreeItem] {
  let child_items : Array[@views.TreeItem] = []
  for entry in markdown_editor_sorted_directory_entries(entries) {
    if entry.is_directory {
      child_items.push(
        markdown_editor_directory_tree_item(path=entry.path, label=entry.name),
      )
    } else {
      child_items.push(@views.tree_item(id=entry.path, label=entry.name))
    }
  }
  if child_items.length() == 0 {
    child_items.push(
      @views.tree_item(
        id=markdown_editor_tree_empty_placeholder_id(path),
        label="Empty folder",
      ),
    )
  }
  child_items
}

///|
fn markdown_editor_sorted_directory_entries(
  entries : Array[@services.DirectoryEntry],
) -> Array[@services.DirectoryEntry] {
  let sorted : Array[@services.DirectoryEntry] = []
  for entry in entries {
    let mut inserted = false
    for index in 0..<sorted.length() {
      if markdown_editor_directory_entry_before(entry, sorted[index]) {
        sorted.insert(index, entry)
        inserted = true
        break
      }
    }
    if !inserted {
      sorted.push(entry)
    }
  }
  sorted
}

///|
fn markdown_editor_directory_entry_before(
  left : @services.DirectoryEntry,
  right : @services.DirectoryEntry,
) -> Bool {
  if left.is_directory != right.is_directory {
    left.is_directory
  } else {
    markdown_editor_case_insensitive_less(left.name, right.name)
  }
}

///|
fn markdown_editor_case_insensitive_less(left : String, right : String) -> Bool {
  let left_key = left.to_lower()
  let right_key = right.to_lower()
  if left_key == right_key {
    markdown_editor_ascii_lex_less(left, right)
  } else {
    markdown_editor_ascii_lex_less(left_key, right_key)
  }
}

///|
fn markdown_editor_ascii_lex_less(left : String, right : String) -> Bool {
  let left_chars = left.to_array()
  let right_chars = right.to_array()
  let count = if left_chars.length() < right_chars.length() {
    left_chars.length()
  } else {
    right_chars.length()
  }
  for index in 0..<count {
    let left_char = left_chars[index]
    let right_char = right_chars[index]
    if left_char != right_char {
      return left_char < right_char
    }
  }
  left_chars.length() < right_chars.length()
}

///|
fn markdown_editor_directory_tree_item(
  path~ : String,
  label~ : String,
) -> @views.TreeItem {
  @views.tree_item(id=path, label~, children=[
    @views.tree_item(
      id=markdown_editor_tree_loading_placeholder_id(path),
      label="Loading...",
    ),
  ])
}

///|
fn markdown_editor_tree_loading_placeholder_id(path : String) -> String {
  path + "#moui-loading"
}

///|
fn markdown_editor_tree_empty_placeholder_id(path : String) -> String {
  path + "#moui-empty"
}

///|
fn markdown_editor_tree_path_is_placeholder(path : String) -> Bool {
  path.has_suffix("#moui-loading") || path.has_suffix("#moui-empty")
}

///|
fn markdown_editor_string_array_contains(
  items : Array[String],
  value : String,
) -> Bool {
  items.any(item => item == value)
}

///|
fn MarkdownEditorApp::toggle_tree_path(
  self : MarkdownEditorApp,
  id : String,
) -> Bool {
  let expanded = self.expanded_tree_paths
  let next : Array[String] = []
  let mut removed = false
  for path in expanded {
    if path == id {
      removed = true
    } else {
      next.push(path)
    }
  }
  if !removed {
    next.push(id)
  }
  self.expanded_tree_paths = next
  !removed
}

///|
fn MarkdownEditorApp::tree_path_is_directory(
  self : MarkdownEditorApp,
  path : String,
) -> Bool {
  match markdown_editor_find_tree_item(self.directory_tree_items, path) {
    Some(item) => item.children.length() > 0
    None => false
  }
}

///|
fn MarkdownEditorApp::tree_path_needs_load(
  self : MarkdownEditorApp,
  path : String,
) -> Bool {
  match markdown_editor_find_tree_item(self.directory_tree_items, path) {
    Some(item) =>
      item.children.length() == 1 &&
      item.children[0].id == markdown_editor_tree_loading_placeholder_id(path)
    None => false
  }
}

///|
fn markdown_editor_find_tree_item(
  items : Array[@views.TreeItem],
  path : String,
) -> @views.TreeItem? {
  for item in items {
    if item.id == path {
      return Some(item)
    }
    match markdown_editor_find_tree_item(item.children, path) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
fn markdown_editor_replace_tree_item_children(
  items : Array[@views.TreeItem],
  path : String,
  children : Array[@views.TreeItem],
) -> Array[@views.TreeItem] {
  let next : Array[@views.TreeItem] = []
  for item in items {
    if item.id == path {
      next.push(@views.tree_item(id=item.id, label=item.label, children~))
    } else {
      next.push(
        @views.tree_item(
          id=item.id,
          label=item.label,
          children=markdown_editor_replace_tree_item_children(
            item.children,
            path,
            children,
          ),
        ),
      )
    }
  }
  next
}

///|

///|
fn MarkdownEditorApp::request_text_file_write_at(
  self : MarkdownEditorApp,
  generation : Int,
  path : String,
  services : @services.AppServices,
  save_as~ : Bool,
) -> @moui.Effect[MarkdownEditorMsg] {
  services
  .files()
  .write_text(path, self.document)
  .effect(map=result => {
    ServiceCompleted(TextFileWritten(generation, path, save_as, result))
  })
}

///|
fn MarkdownEditorApp::save_file_dialog_options(
  self : MarkdownEditorApp,
) -> @services.FileDialogOptions {
  @services.FileDialogOptions::new(
    title="Save Markdown",
    filters=["md", "markdown"],
    default_name=Some(
      markdown_editor_default_save_name(
        source=self.document,
        path=self.document_path,
      ),
    ),
  )
}

///|
fn MarkdownEditorApp::is_dirty(self : MarkdownEditorApp) -> Bool {
  self.document != self.saved_document
}

///|
/// True while a host file/clipboard transfer is in flight, so toolbar actions
/// that would start another transfer can disable themselves.
fn MarkdownEditorApp::transfer_in_progress(self : MarkdownEditorApp) -> Bool {
  match self.transfer_status {
    TransferRunning(_) => true
    _ => false
  }
}

///|
/// Derive the directory of the open document, used to resolve relative image
/// sources against the document's location rather than the process cwd. Returns
/// None (no re-rooting) when there is no path.
fn markdown_editor_document_base_dir(path : String) -> String? {
  if path == "" {
    None
  } else {
    let chars = path.to_array()
    let mut last_sep = -1
    for i, ch in chars {
      if ch == '/' || ch == '\\' {
        last_sep = i
      }
    }
    if last_sep <= 0 {
      None
    } else {
      Some(String::from_array(chars[0:last_sep]))
    }
  }
}

///|

///|
fn MarkdownEditorApp::request_clipboard_import(
  self : MarkdownEditorApp,
  services : @services.AppServices,
) -> @moui.Effect[MarkdownEditorMsg] {
  let generation = self.begin_transfer(ClipboardImport)
  services
  .clipboard()
  .read_text()
  .effect(map=result => ServiceCompleted(ClipboardImported(generation, result)))
}

///|
fn MarkdownEditorApp::insert_media_from_path(
  self : MarkdownEditorApp,
  path : String,
) -> Unit {
  let file_name = markdown_editor_file_name(path)
  let alt = markdown_editor_image_alt_from_filename(file_name)
  let image_md = "![" + alt + "](" + path + ")"
  self.insert_text_at_cursor(image_md)
}

///|
fn markdown_editor_image_alt_from_filename(file_name : String) -> String {
  let chars = file_name.to_array()
  let dot_pos = markdown_editor_last_dot_position(chars)
  let no_ext = match dot_pos {
    Some(dot) => String::from_array(chars[:dot])
    None => file_name
  }
  let result : Array[Char] = []
  for ch in no_ext {
    result.push(
      match ch {
        '-' | '_' => ' '
        _ => ch
      },
    )
  }
  String::from_array(result).trim().to_owned()
}

///|
fn markdown_editor_last_dot_position(chars : Array[Char]) -> Int? {
  let mut pos : Int? = None
  for index, ch in chars {
    if ch == '.' {
      pos = Some(index)
    }
  }
  pos
}

///|
fn MarkdownEditorApp::insert_text_at_cursor(
  self : MarkdownEditorApp,
  text : String,
) -> Unit {
  let doc = self.document
  let sel = self.selection
  let caret = sel.caret
  let range = sel.selection
  let (before, after) = match range {
    Some(r) => (doc[:r.start].to_owned(), doc[r.end:].to_owned())
    None => (doc[:caret].to_owned(), doc[caret:].to_owned())
  }
  let new_caret = before.length() + text.length()
  self.apply_editor_transaction(
    MarkdownEditTransaction::from_sources(
      doc,
      before + text + after,
      caret=new_caret,
      selection=None,
      reason=MediaEdit,
    ),
  )
  self.selection = { caret: new_caret, selection: None }
  self.sync_target_inputs()
  self.maybe_center_typewriter_selection()
}

///|

///|
fn MarkdownEditorApp::request_clipboard_export(
  self : MarkdownEditorApp,
  services : @services.AppServices,
) -> @moui.Effect[MarkdownEditorMsg] {
  let generation = self.begin_transfer(ClipboardExport)
  services
  .clipboard()
  .write_text(self.document)
  .effect(map=result => {
    ServiceCompleted(ClipboardExported(generation, false, result))
  })
}

///|
fn MarkdownEditorApp::request_html_export(
  self : MarkdownEditorApp,
  services : @services.AppServices,
) -> @moui.Effect[MarkdownEditorMsg] {
  let generation = self.begin_transfer(ClipboardHtmlExport)
  services
  .clipboard()
  .write_text(self.html_export_document())
  .effect(map=result => {
    ServiceCompleted(ClipboardExported(generation, true, result))
  })
}

///|
fn MarkdownEditorApp::request_open_target(
  self : MarkdownEditorApp,
  services : @services.AppServices,
) -> @moui.Effect[MarkdownEditorMsg] {
  let target = match self.open_target_value() {
    Some(target) => target
    None => {
      self.transfer_status = TransferUnavailable(
        "open target requires an active link or image target",
      )

      return @moui.Effect::none()
    }
  }
  let generation = self.begin_transfer(OpenTarget)
  services
  .urls()
  .open(target)
  .effect(map=result => ServiceCompleted(TargetOpened(generation, result)))
}

///|
fn MarkdownEditorApp::open_target_value(self : MarkdownEditorApp) -> String? {
  match self.target_kind {
    LinkTarget => {
      let target = self.link_target.trim().to_owned()
      if target != "" {
        return Some(target)
      }
    }
    ImageTarget => {
      let target = self.image_target.trim().to_owned()
      if target != "" {
        return Some(target)
      }
    }
    _ => ()
  }
  match markdown_editor_selected_link_target(self.document, self.selection) {
    Some(target) =>
      if target.trim().to_owned() == "" {
        None
      } else {
        Some(target)
      }
    None =>
      match
        markdown_editor_selected_image_target(self.document, self.selection) {
        Some(target) =>
          if target.trim().to_owned() == "" {
            None
          } else {
            Some(target)
          }
        None => None
      }
  }
}

///|

///|
fn MarkdownEditorApp::apply_service_completion(
  self : MarkdownEditorApp,
  completion : MarkdownEditorServiceCompletion,
  services : @services.AppServices,
) -> @moui.Effect[MarkdownEditorMsg] {
  match completion {
    FileOpenPicked(generation, result) => {
      if !self.transfer_is_current(generation) {
        return @moui.Effect::none()
      }
      match result {
        Success(path) =>
          self.request_text_file_read_at(generation, path, services)
        Failure(error) => {
          self.transfer_status = TransferUnavailable(error.message)
          @moui.Effect::none()
        }
        Cancelled => {
          self.transfer_status = TransferCancelled(FileOpen)
          @moui.Effect::none()
        }
      }
    }
    FileSavePicked(generation, result) => {
      if !self.transfer_is_current(generation) {
        return @moui.Effect::none()
      }
      match result {
        Success(path) =>
          self.request_text_file_write_at(
            generation,
            path,
            services,
            save_as=true,
          )
        Failure(error) => {
          self.transfer_status = TransferUnavailable(error.message)
          @moui.Effect::none()
        }
        Cancelled => {
          self.transfer_status = TransferCancelled(FileSaveAs)
          @moui.Effect::none()
        }
      }
    }
    TextFileRead(generation, path, result) => {
      if !self.transfer_is_current(generation) {
        return @moui.Effect::none()
      }
      match result {
        Success(text) => {
          self.load_document(text, path~)
          self.transfer_status = TransferOpened(path)
        }
        Failure(error) =>
          self.transfer_status = TransferUnavailable(error.message)
        Cancelled => self.transfer_status = TransferCancelled(FileOpen)
      }
      @moui.Effect::none()
    }
    TextFileWritten(generation, path, save_as, result) => {
      if !self.transfer_is_current(generation) {
        return @moui.Effect::none()
      }
      match result {
        Success(_) => {
          self.document_path = path
          self.mark_document_saved()
          self.record_recent_document_path(path)
          self.transfer_status = if save_as {
            TransferSavedAs(path)
          } else {
            TransferSaved(path)
          }
        }
        Failure(error) =>
          self.transfer_status = TransferUnavailable(error.message)
        Cancelled =>
          self.transfer_status = TransferCancelled(
            if save_as {
              FileSaveAs
            } else {
              FileSave
            },
          )
      }
      @moui.Effect::none()
    }
    ClipboardImported(generation, result) => {
      if !self.transfer_is_current(generation) {
        return @moui.Effect::none()
      }
      match result {
        Success(text) => {
          self.load_document(text, path="")
          self.transfer_status = TransferImported
        }
        Failure(error) =>
          self.transfer_status = TransferUnavailable(error.message)
        Cancelled => self.transfer_status = TransferCancelled(ClipboardImport)
      }
      @moui.Effect::none()
    }
    ClipboardExported(generation, html, result) => {
      if !self.transfer_is_current(generation) {
        return @moui.Effect::none()
      }
      match result {
        Success(_) =>
          self.transfer_status = if html {
            TransferHtmlCopied
          } else {
            TransferCopied
          }
        Failure(error) =>
          self.transfer_status = TransferUnavailable(error.message)
        Cancelled =>
          self.transfer_status = TransferCancelled(
            if html {
              ClipboardHtmlExport
            } else {
              ClipboardExport
            },
          )
      }
      @moui.Effect::none()
    }
    TargetOpened(generation, result) => {
      if !self.transfer_is_current(generation) {
        return @moui.Effect::none()
      }
      match result {
        Success(_) => self.transfer_status = TransferTargetOpened
        Failure(error) =>
          self.transfer_status = TransferUnavailable(error.message)
        Cancelled => self.transfer_status = TransferCancelled(OpenTarget)
      }
      @moui.Effect::none()
    }
    DirectoryPicked(result) =>
      match result {
        Success(path) => {
          self.working_directory = path
          self.request_directory_listing(path, services)
        }
        Failure(error) => {
          self.transfer_status = TransferUnavailable(error.message)
          @moui.Effect::none()
        }
        Cancelled => @moui.Effect::none()
      }
    DirectoryListed(path, result) => {
      self.apply_directory_listing(path, result)
      @moui.Effect::none()
    }
    SettingsLoaded(result) => {
      match result {
        Success(Some(text)) =>
          self.apply_settings(markdown_editor_decode_settings(text))
        Success(None) | Cancelled => ()
        Failure(_) => ()
      }
      @moui.Effect::none()
    }
    SettingsSaved(_) => @moui.Effect::none()
  }
}

///|
fn markdown_editor_transfer_status_label(
  status : MarkdownEditorTransferStatus,
) -> String {
  match status {
    TransferReady => ""
    TransferRunning(ClipboardImport) => "Waiting for clipboard"
    TransferRunning(ClipboardExport) => "Exporting Markdown"
    TransferRunning(ClipboardHtmlExport) => "Exporting HTML"
    TransferRunning(FileOpen) => "Opening file"
    TransferRunning(FileSaveAs) => "Waiting for save location"
    TransferRunning(FileSave) => "Saving file"
    TransferRunning(OpenTarget) => "Opening target"
    TransferUnavailable(reason) => "Transfer unavailable: " + reason
    TransferCancelled(ClipboardImport) => "Import cancelled"
    TransferCancelled(ClipboardExport) => "Export cancelled"
    TransferCancelled(ClipboardHtmlExport) => "HTML export cancelled"
    TransferCancelled(FileOpen) => "Open cancelled"
    TransferCancelled(FileSaveAs) => "Save cancelled"
    TransferCancelled(FileSave) => "Save cancelled"
    TransferCancelled(OpenTarget) => "Open target cancelled"
    TransferCopied => "Markdown copied"
    TransferHtmlCopied => "HTML copied"
    TransferImported => "Clipboard imported"
    TransferOpened(path) => "Opened " + markdown_editor_file_name(path)
    TransferSaved(path) => "Saved " + markdown_editor_file_name(path)
    TransferSavedAs(path) => "Saved as " + markdown_editor_file_name(path)
    TransferTargetOpened => "Target opened"
  }
}

///|
#warnings("-unused_value")
fn markdown_editor_status_label(
  block_label : String,
  snapshot : MarkdownEditorSnapshot,
  selection : MarkdownEditorSelection,
) -> String {
  let section = markdown_editor_active_section_suffix(snapshot, selection)
  block_label + section + " / " + markdown_editor_reading_label(snapshot)
}

///|
fn markdown_editor_session_status_label(
  block_label : String,
  session : MarkdownDocumentSession,
  selection : MarkdownEditorSelection,
) -> String {
  let section = markdown_editor_session_active_section_suffix(
    session, selection,
  )
  block_label + section + " / " + markdown_editor_session_reading_label(session)
}

///|
fn markdown_editor_active_section_suffix(
  snapshot : MarkdownEditorSnapshot,
  selection : MarkdownEditorSelection,
) -> String {
  let index = markdown_editor_active_outline_index(
    snapshot.outline,
    selection.caret,
  )
  if index < 0 {
    ""
  } else {
    let title = markdown_editor_outline_title(
      if snapshot.outline[index].title == "" {
        "Untitled"
      } else {
        snapshot.outline[index].title
      },
    )
    " / Section: " + title
  }
}

///|
fn markdown_editor_session_active_section_suffix(
  session : MarkdownDocumentSession,
  selection : MarkdownEditorSelection,
) -> String {
  let index = markdown_editor_active_outline_index(
    session.outline,
    selection.caret,
  )
  if index < 0 {
    ""
  } else {
    let title = markdown_editor_outline_title(
      if session.outline[index].title == "" {
        "Untitled"
      } else {
        session.outline[index].title
      },
    )
    " / Section: " + title
  }
}

///|
fn markdown_editor_document_title(path~ : String, fallback~ : String) -> String {
  let file = markdown_editor_file_name(path)
  if file != "" {
    file
  } else if fallback != "" {
    fallback
  } else {
    "Untitled"
  }
}

///|
fn markdown_editor_default_save_name(
  source~ : String,
  path~ : String,
) -> String {
  let file = markdown_editor_file_name(path)
  if file != "" {
    file
  } else {
    let snapshot = MarkdownEditorSnapshot::parse(source)
    let title = snapshot.active_heading.trim().to_owned()
    if title != "" {
      title + ".md"
    } else {
      "Untitled.md"
    }
  }
}

///|
fn markdown_editor_file_name(path : String) -> String {
  let chars = path.to_array()
  let mut start = 0
  for index in 0..<chars.length() {
    if chars[index] == '/' || chars[index] == '\\' {
      start = index + 1
    }
  }
  String::from_array(chars[start:]).trim().to_owned()
}

///|
fn markdown_editor_parent_directory(path : String) -> String {
  let chars = path.to_array()
  let mut last_slash : Int = -1
  for index in 0..<chars.length() {
    if chars[index] == '/' {
      last_slash = index
    }
  }
  if last_slash <= 0 {
    ""
  } else {
    String::from_array(chars[:last_slash])
  }
}
