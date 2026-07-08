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
  self.document_path.set(path)
  self.record_recent_document_path(path)
  self.saved_document.set(source)
  self.selection.set({ caret: 0, selection: None })
  self.reset_find_session()
  self.reset_format_palette()
  self.transfer_status.set(TransferReady)
  self.clear_history()
  self.sync_target_inputs()
}

///|
fn MarkdownEditorApp::mark_document_saved(self : MarkdownEditorApp) -> Unit {
  self.saved_document.set(self.document.get())
}

///|
pub fn MarkdownEditorApp::save_document_as(
  self : MarkdownEditorApp,
  path : String,
) -> Unit {
  self.document_path.set(path)
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
  let existing = self.recent_document_paths.get()
  let next : Array[String] = [path]
  for candidate in existing {
    if candidate != path && next.length() < 8 {
      next.push(candidate)
    }
  }
  self.recent_document_paths.set(next)
}

///|
fn MarkdownEditorApp::request_file_open(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> @moui.Effect[MarkdownEditorMsg] {
  self.transfer_status.set(TransferRequesting(FileOpen))
  let options = @host.HostFileDialogOptions::new(
    kind=@host.HostFileDialogKind::OpenFile,
    title="Open Markdown",
    filters=["md", "markdown"],
  )
  @moui.Effect::host_service(
    key="markdown-editor:file-open",
    label="Choose Markdown file",
    run=dispatch => {
      let request = @host.HostServiceRequest::FileDialog(options)
      let response = services.file_dialog(options)
      dispatch(
        HostTransferCompleted(
          markdown_editor_host_completion_for_response(request, response),
        ),
      )
    },
  )
}

///|
fn MarkdownEditorApp::perform_file_open(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> Unit {
  self.transfer_status.set(TransferRequesting(FileOpen))
  let options = @host.HostFileDialogOptions::new(
    kind=@host.HostFileDialogKind::OpenFile,
    title="Open Markdown",
    filters=["md", "markdown"],
  )
  let request = @host.HostServiceRequest::FileDialog(options)
  let response = services.file_dialog(options)
  match response {
    @host.HostServiceResponse::Pending(id) =>
      ignore(
        services.on_completed(id, completion => {
          ignore(
            self.apply_transfer_completion_with_services(completion, services),
          )
        }),
      )
    _ => ()
  }
  ignore(
    self.apply_transfer_completion_with_services(
      markdown_editor_host_completion_for_response(request, response),
      services,
    ),
  )
}

///|
fn MarkdownEditorApp::request_document_save(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> @moui.Effect[MarkdownEditorMsg] {
  let path = self.document_path.get()
  if path == "" {
    self.request_file_save_as(services)
  } else {
    self.request_text_file_write(path, services, kind=FileSave)
  }
}

///|
fn MarkdownEditorApp::perform_document_save(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> Unit {
  let path = self.document_path.get()
  if path == "" {
    self.perform_file_save_as(services)
  } else {
    self.perform_text_file_write(path, services, kind=FileSave)
  }
}

///|
fn MarkdownEditorApp::request_file_save_as(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> @moui.Effect[MarkdownEditorMsg] {
  self.transfer_status.set(TransferRequesting(FileSaveAs))
  let options = self.save_file_dialog_options()
  @moui.Effect::host_service(
    key="markdown-editor:file-save-as",
    label="Choose Markdown save location",
    run=dispatch => {
      let request = @host.HostServiceRequest::FileDialog(options)
      let response = services.file_dialog(options)
      dispatch(
        HostTransferCompleted(
          markdown_editor_host_completion_for_response(request, response),
        ),
      )
    },
  )
}

///|
fn MarkdownEditorApp::perform_file_save_as(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> Unit {
  self.transfer_status.set(TransferRequesting(FileSaveAs))
  let options = self.save_file_dialog_options()
  let request = @host.HostServiceRequest::FileDialog(options)
  let response = services.file_dialog(options)
  match response {
    @host.HostServiceResponse::Pending(id) =>
      ignore(
        services.on_completed(id, completion => {
          ignore(
            self.apply_transfer_completion_with_services(completion, services),
          )
        }),
      )
    _ => ()
  }
  ignore(
    self.apply_transfer_completion_with_services(
      markdown_editor_host_completion_for_response(request, response),
      services,
    ),
  )
}

///|
fn MarkdownEditorApp::perform_text_file_read(
  self : MarkdownEditorApp,
  path : String,
  services : @host.HostAppServices,
) -> Unit {
  self.transfer_status.set(TransferRequesting(FileOpen))
  let request = @host.HostServiceRequest::TextFile(
    @host.HostTextFileRequest::ReadText(path),
  )
  let response = services.read_text_file(path)
  match response {
    @host.HostServiceResponse::Pending(id) =>
      ignore(
        services.on_completed(id, completion => {
          ignore(
            self.apply_transfer_completion_with_services(completion, services),
          )
        }),
      )
    _ => ()
  }
  ignore(
    self.apply_transfer_completion_with_services(
      markdown_editor_host_completion_for_response(request, response),
      services,
    ),
  )
}

///|
fn MarkdownEditorApp::request_text_file_read(
  self : MarkdownEditorApp,
  path : String,
  services : @host.HostAppServices,
) -> @moui.Effect[MarkdownEditorMsg] {
  if path.trim().to_owned() == "" {
    self.transfer_status.set(TransferUnavailable("recent file path is empty"))
    return @moui.Effect::none()
  }
  self.transfer_status.set(TransferRequesting(FileOpen))
  @moui.Effect::host_service(
    key="markdown-editor:file-open-recent",
    label="Open recent Markdown file",
    run=dispatch => {
      let request = @host.HostServiceRequest::TextFile(
        @host.HostTextFileRequest::ReadText(path),
      )
      let response = services.read_text_file(path)
      dispatch(
        HostTransferCompleted(
          markdown_editor_host_completion_for_response(request, response),
        ),
      )
    },
  )
}

///|
fn MarkdownEditorApp::request_pick_working_directory(
  _self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> @moui.Effect[MarkdownEditorMsg] {
  @moui.Effect::host_service(
    key="markdown-editor:pick-working-directory",
    label="Pick working directory",
    run=dispatch => {
      let request = @host.HostServiceRequest::FileDialog(
        @host.HostFileDialogOptions::new(
          kind=@host.HostFileDialogKind::PickDirectory,
          title="Choose folder",
        ),
      )
      let response = services.pick_directory(title="Choose folder")
      dispatch(
        HostTransferCompleted(
          markdown_editor_host_completion_for_response(request, response),
        ),
      )
    },
  )
}

///|
fn MarkdownEditorApp::load_tree_from_directory(
  self : MarkdownEditorApp,
  path : String,
  services : @host.HostAppServices,
) -> Unit {
  self.working_directory.set(path)
  let response = services.list_directory(path)
  self.apply_directory_listing(path, response)
}

///|
fn MarkdownEditorApp::apply_directory_listing(
  self : MarkdownEditorApp,
  path : String,
  response : @host.HostServiceResponse,
) -> Unit {
  match response {
    @host.HostServiceResponse::DirectoryListing(_path, entries) => {
      let next_children = markdown_editor_tree_children_from_listing(
        path, entries,
      )
      if self.working_directory.get() == path ||
        self.directory_tree_items.get().length() == 0 {
        self.directory_tree_items.set([
          markdown_editor_root_tree_item(path, next_children),
        ])
      } else {
        self.directory_tree_items.set(
          markdown_editor_replace_tree_item_children(
            self.directory_tree_items.get(),
            path,
            next_children,
          ),
        )
      }
      let current = self.expanded_tree_paths.get()
      if !markdown_editor_string_array_contains(current, path) {
        let next = current.copy()
        next.push(path)
        self.expanded_tree_paths.set(next)
      }
      self.transfer_status.set(TransferReady)
    }
    @host.HostServiceResponse::Pending(_) => ()
    @host.HostServiceResponse::Unavailable(reason) =>
      self.transfer_status.set(
        TransferUnavailable("directory listing unavailable: " + reason),
      )
    _ =>
      self.transfer_status.set(
        TransferUnavailable("unsupported directory listing response"),
      )
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
  entries : Array[@host.HostDirectoryEntry],
) -> Array[@views.TreeItem] {
  let child_items : Array[@views.TreeItem] = []
  for entry in markdown_editor_sorted_directory_entries(entries) {
    if entry.is_directory() {
      child_items.push(
        markdown_editor_directory_tree_item(
          path=entry.path(),
          label=entry.name(),
        ),
      )
    } else {
      child_items.push(@views.tree_item(id=entry.path(), label=entry.name()))
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
  entries : Array[@host.HostDirectoryEntry],
) -> Array[@host.HostDirectoryEntry] {
  let sorted : Array[@host.HostDirectoryEntry] = []
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
  left : @host.HostDirectoryEntry,
  right : @host.HostDirectoryEntry,
) -> Bool {
  if left.is_directory() != right.is_directory() {
    left.is_directory()
  } else {
    markdown_editor_case_insensitive_less(left.name(), right.name())
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
  let expanded = self.expanded_tree_paths.get()
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
  self.expanded_tree_paths.set(next)
  !removed
}

///|
fn MarkdownEditorApp::tree_path_is_directory(
  self : MarkdownEditorApp,
  path : String,
) -> Bool {
  match markdown_editor_find_tree_item(self.directory_tree_items.get(), path) {
    Some(item) => item.children.length() > 0
    None => false
  }
}

///|
fn MarkdownEditorApp::tree_path_needs_load(
  self : MarkdownEditorApp,
  path : String,
) -> Bool {
  match markdown_editor_find_tree_item(self.directory_tree_items.get(), path) {
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
fn MarkdownEditorApp::request_text_file_write(
  self : MarkdownEditorApp,
  path : String,
  services : @host.HostAppServices,
  kind~ : MarkdownEditorTransferKind,
) -> @moui.Effect[MarkdownEditorMsg] {
  self.transfer_status.set(TransferRequesting(kind))
  @moui.Effect::host_service(
    key="markdown-editor:file-write:" + markdown_editor_transfer_kind_key(kind),
    label="Write Markdown file",
    run=dispatch => {
      let source = self.document.get()
      let request = @host.HostServiceRequest::TextFile(
        @host.HostTextFileRequest::WriteText(path, source),
      )
      let response = services.write_text_file(path, source)
      dispatch(
        HostTransferCompleted(
          markdown_editor_host_completion_for_response(request, response),
        ),
      )
    },
  )
}

///|
fn MarkdownEditorApp::perform_text_file_write(
  self : MarkdownEditorApp,
  path : String,
  services : @host.HostAppServices,
  kind~ : MarkdownEditorTransferKind,
) -> Unit {
  self.transfer_status.set(TransferRequesting(kind))
  let source = self.document.get()
  let request = @host.HostServiceRequest::TextFile(
    @host.HostTextFileRequest::WriteText(path, source),
  )
  let response = services.write_text_file(path, source)
  match response {
    @host.HostServiceResponse::Pending(id) =>
      ignore(
        services.on_completed(id, completion => {
          ignore(
            self.apply_transfer_completion_with_services(completion, services),
          )
        }),
      )
    _ => ()
  }
  ignore(
    self.apply_transfer_completion_with_services(
      markdown_editor_host_completion_for_response(request, response),
      services,
    ),
  )
}

///|
fn MarkdownEditorApp::save_file_dialog_options(
  self : MarkdownEditorApp,
) -> @host.HostFileDialogOptions {
  @host.HostFileDialogOptions::new(
    kind=@host.HostFileDialogKind::SaveFile,
    title="Save Markdown",
    filters=["md", "markdown"],
    default_name=Some(
      markdown_editor_default_save_name(
        source=self.document.get(),
        path=self.document_path.get(),
      ),
    ),
  )
}

///|
fn MarkdownEditorApp::is_dirty(self : MarkdownEditorApp) -> Bool {
  self.document.get() != self.saved_document.get()
}

///|
/// True while a host file/clipboard transfer is in flight, so toolbar actions
/// that would start another transfer can disable themselves.
fn MarkdownEditorApp::transfer_in_progress(self : MarkdownEditorApp) -> Bool {
  match self.transfer_status.get() {
    TransferRequesting(_) | TransferPending(_, _) => true
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
fn MarkdownEditorApp::request_clipboard_import(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> @moui.Effect[MarkdownEditorMsg] {
  self.transfer_status.set(TransferRequesting(ClipboardImport))
  @moui.Effect::host_service(
    key="markdown-editor:clipboard-import",
    label="Import Markdown from clipboard",
    run=dispatch => {
      let request = @host.HostServiceRequest::Clipboard(
        @host.HostClipboardRequest::ReadText,
      )
      let response = services.read_clipboard_text()
      dispatch(
        HostTransferCompleted(
          markdown_editor_host_completion_for_response(request, response),
        ),
      )
    },
  )
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
  let doc = self.document.get()
  let sel = self.selection.get()
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
  self.selection.set({ caret: new_caret, selection: None })
  self.sync_target_inputs()
  self.maybe_center_typewriter_selection()
}

///|
fn MarkdownEditorApp::perform_clipboard_import(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> Unit {
  self.transfer_status.set(TransferRequesting(ClipboardImport))
  let request = @host.HostServiceRequest::Clipboard(
    @host.HostClipboardRequest::ReadText,
  )
  let response = services.read_clipboard_text()
  match response {
    @host.HostServiceResponse::Pending(id) =>
      ignore(
        services.on_completed(id, completion => {
          self.apply_transfer_completion(completion)
        }),
      )
    _ => ()
  }
  self.apply_transfer_completion(
    markdown_editor_host_completion_for_response(request, response),
  )
}

///|
fn MarkdownEditorApp::request_clipboard_export(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> @moui.Effect[MarkdownEditorMsg] {
  self.transfer_status.set(TransferRequesting(ClipboardExport))
  @moui.Effect::host_service(
    key="markdown-editor:clipboard-export",
    label="Export Markdown to clipboard",
    run=dispatch => {
      let request = @host.HostServiceRequest::Clipboard(
        @host.HostClipboardRequest::WriteText(self.document.get()),
      )
      let response = services.write_clipboard_text(self.document.get())
      dispatch(
        HostTransferCompleted(
          markdown_editor_host_completion_for_response(request, response),
        ),
      )
    },
  )
}

///|
fn MarkdownEditorApp::perform_clipboard_export(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> Unit {
  self.transfer_status.set(TransferRequesting(ClipboardExport))
  let request = @host.HostServiceRequest::Clipboard(
    @host.HostClipboardRequest::WriteText(self.document.get()),
  )
  let response = services.write_clipboard_text(self.document.get())
  match response {
    @host.HostServiceResponse::Pending(id) =>
      ignore(
        services.on_completed(id, completion => {
          self.apply_transfer_completion(completion)
        }),
      )
    _ => ()
  }
  self.apply_transfer_completion(
    markdown_editor_host_completion_for_response(request, response),
  )
}

///|
fn MarkdownEditorApp::request_html_export(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> @moui.Effect[MarkdownEditorMsg] {
  let html = self.html_export_document()
  self.transfer_status.set(TransferRequesting(ClipboardHtmlExport))
  @moui.Effect::host_service(
    key="markdown-editor:html-export",
    label="Export HTML to clipboard",
    run=dispatch => {
      let request = @host.HostServiceRequest::Clipboard(
        @host.HostClipboardRequest::WriteText(html),
      )
      let response = services.write_clipboard_text(html)
      dispatch(
        HostTransferCompleted(
          markdown_editor_host_completion_for_response(request, response),
        ),
      )
    },
  )
}

///|
fn MarkdownEditorApp::perform_html_export(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> Unit {
  let html = self.html_export_document()
  self.transfer_status.set(TransferRequesting(ClipboardHtmlExport))
  let request = @host.HostServiceRequest::Clipboard(
    @host.HostClipboardRequest::WriteText(html),
  )
  let response = services.write_clipboard_text(html)
  match response {
    @host.HostServiceResponse::Pending(id) =>
      ignore(
        services.on_completed(id, completion => {
          self.apply_transfer_completion(completion)
        }),
      )
    _ => ()
  }
  self.apply_transfer_completion(
    markdown_editor_host_completion_for_response(request, response),
  )
}

///|
fn MarkdownEditorApp::request_open_target(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> @moui.Effect[MarkdownEditorMsg] {
  let target = match self.open_target_value() {
    Some(target) => target
    None => {
      self.transfer_status.set(
        TransferUnavailable(
          "open target requires an active link or image target",
        ),
      )
      return @moui.Effect::none()
    }
  }
  self.transfer_status.set(TransferRequesting(OpenTarget))
  @moui.Effect::host_service(
    key="markdown-editor:open-target",
    label="Open Markdown link or image target",
    run=dispatch => {
      let request = @host.HostServiceRequest::OpenUrl(target)
      let response = services.open_url(target)
      dispatch(
        HostTransferCompleted(
          markdown_editor_host_completion_for_response(request, response),
        ),
      )
    },
  )
}

///|
fn MarkdownEditorApp::perform_open_target(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> Unit {
  let target = match self.open_target_value() {
    Some(target) => target
    None => {
      self.transfer_status.set(
        TransferUnavailable(
          "open target requires an active link or image target",
        ),
      )
      return
    }
  }
  self.transfer_status.set(TransferRequesting(OpenTarget))
  let request = @host.HostServiceRequest::OpenUrl(target)
  let response = services.open_url(target)
  match response {
    @host.HostServiceResponse::Pending(id) =>
      ignore(
        services.on_completed(id, completion => {
          self.apply_transfer_completion(completion)
        }),
      )
    _ => ()
  }
  self.apply_transfer_completion(
    markdown_editor_host_completion_for_response(request, response),
  )
}

///|
fn MarkdownEditorApp::open_target_value(self : MarkdownEditorApp) -> String? {
  match self.target_kind.get() {
    LinkTarget => {
      let target = self.link_target.get().trim().to_owned()
      if target != "" {
        return Some(target)
      }
    }
    ImageTarget => {
      let target = self.image_target.get().trim().to_owned()
      if target != "" {
        return Some(target)
      }
    }
    _ => ()
  }
  match
    markdown_editor_selected_link_target(
      self.document.get(),
      self.selection.get(),
    ) {
    Some(target) =>
      if target.trim().to_owned() == "" {
        None
      } else {
        Some(target)
      }
    None =>
      match
        markdown_editor_selected_image_target(
          self.document.get(),
          self.selection.get(),
        ) {
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
fn MarkdownEditorApp::apply_transfer_completion(
  self : MarkdownEditorApp,
  completion : @host.HostCompletedServiceResponse,
) -> Unit {
  match completion.response {
    @host.HostServiceResponse::Pending(id) =>
      self.transfer_status.set(
        TransferPending(
          id,
          markdown_editor_completion_transfer_kind(
            self.transfer_status.get(),
            completion.request,
          ),
        ),
      )
    @host.HostServiceResponse::ClipboardText(text) => {
      self.load_document(text, path="")
      self.transfer_status.set(TransferImported)
      self.push_toast("Markdown imported", tone=@views.FeedbackTone::Success)
    }
    @host.HostServiceResponse::ClipboardImage(bytes) => {
      let base64_data = @base64.encode(bytes[:])
      let image_md = "![pasted image](data:image/png;base64," +
        base64_data +
        ")"
      self.insert_text_at_cursor(image_md)
      self.transfer_status.set(TransferImported)
      self.push_toast("Image pasted", tone=@views.FeedbackTone::Success)
    }
    @host.HostServiceResponse::ClipboardWritten =>
      match markdown_editor_active_transfer_kind(self.transfer_status.get()) {
        Some(ClipboardHtmlExport) => {
          self.transfer_status.set(TransferHtmlCopied)
          self.push_toast("HTML copied", tone=@views.FeedbackTone::Success)
        }
        _ => {
          self.transfer_status.set(TransferCopied)
          self.push_toast("Markdown copied", tone=@views.FeedbackTone::Success)
        }
      }
    @host.HostServiceResponse::FileDialogSelection(paths) =>
      self.apply_file_dialog_selection(completion.request, paths)
    @host.HostServiceResponse::TextFileContent(path, text) => {
      self.load_document(text, path~)
      self.transfer_status.set(TransferOpened(path))
      self.push_toast("Opened " + path, tone=@views.FeedbackTone::Success)
    }
    @host.HostServiceResponse::TextFileWritten(path) => {
      self.save_document_as(path)
      match markdown_editor_active_transfer_kind(self.transfer_status.get()) {
        Some(FileSaveAs) => {
          self.transfer_status.set(TransferSavedAs(path))
          self.push_toast("Saved " + path, tone=@views.FeedbackTone::Success)
        }
        _ => {
          self.transfer_status.set(TransferSaved(path))
          self.push_toast("Saved " + path, tone=@views.FeedbackTone::Success)
        }
      }
    }
    @host.HostServiceResponse::UrlOpened =>
      self.transfer_status.set(TransferTargetOpened)
    @host.HostServiceResponse::DirectoryListing(path, entries) =>
      self.apply_directory_listing(
        path,
        @host.HostServiceResponse::DirectoryListing(path, entries),
      )
    @host.HostServiceResponse::Unavailable(reason) => {
      self.transfer_status.set(TransferUnavailable(reason))
      self.push_toast(
        "Action unavailable: " + reason,
        tone=@views.FeedbackTone::Danger,
      )
    }
    _ => {
      self.transfer_status.set(
        TransferUnavailable(
          "clipboard service returned an unsupported response",
        ),
      )
      self.push_toast("Unsupported response", tone=@views.FeedbackTone::Danger)
    }
  }
}

///|
fn MarkdownEditorApp::apply_transfer_completion_with_services(
  self : MarkdownEditorApp,
  completion : @host.HostCompletedServiceResponse,
  services : @host.HostAppServices,
) -> Unit {
  match completion.response {
    @host.HostServiceResponse::Pending(id) =>
      self.transfer_status.set(
        TransferPending(
          id,
          markdown_editor_completion_transfer_kind(
            self.transfer_status.get(),
            completion.request,
          ),
        ),
      )
    @host.HostServiceResponse::FileDialogSelection(paths) =>
      self.apply_file_dialog_selection_with_services(
        completion.request,
        paths,
        services,
      )
    @host.HostServiceResponse::DirectoryListing(path, _entries) =>
      self.apply_directory_listing(path, completion.response)
    _ => self.apply_transfer_completion(completion)
  }
}

///|
fn markdown_editor_active_transfer_kind(
  status : MarkdownEditorTransferStatus,
) -> MarkdownEditorTransferKind? {
  match status {
    TransferRequesting(kind) => Some(kind)
    TransferPending(_, kind) => Some(kind)
    _ => None
  }
}

///|
fn markdown_editor_completion_transfer_kind(
  status : MarkdownEditorTransferStatus,
  request : @host.HostServiceRequest,
) -> MarkdownEditorTransferKind {
  match markdown_editor_active_transfer_kind(status) {
    Some(kind) => kind
    None => markdown_editor_transfer_kind(request)
  }
}

///|
fn MarkdownEditorApp::apply_file_dialog_selection(
  self : MarkdownEditorApp,
  request : @host.HostServiceRequest,
  paths : Array[String],
) -> Unit {
  let kind = markdown_editor_transfer_kind(request)
  if paths.length() == 0 {
    self.transfer_status.set(TransferCancelled(kind))
    return
  }
  let path = paths[0]
  match request {
    @host.HostServiceRequest::FileDialog(
      { kind: @host.HostFileDialogKind::SaveFile, .. }
    ) =>
      self.transfer_status.set(
        TransferUnavailable(
          "save as selected " +
          markdown_editor_file_name(path) +
          ", but text file writing requires host services",
        ),
      )
    @host.HostServiceRequest::FileDialog(
      { kind: @host.HostFileDialogKind::OpenFile, .. }
    ) =>
      self.transfer_status.set(
        TransferUnavailable(
          "file open selected " +
          markdown_editor_file_name(path) +
          ", but text file reading requires host services",
        ),
      )
    _ =>
      self.transfer_status.set(
        TransferUnavailable("unsupported file dialog response"),
      )
  }
}

///|
fn MarkdownEditorApp::apply_file_dialog_selection_with_services(
  self : MarkdownEditorApp,
  request : @host.HostServiceRequest,
  paths : Array[String],
  services : @host.HostAppServices,
) -> Unit {
  let kind = markdown_editor_transfer_kind(request)
  if paths.length() == 0 {
    self.transfer_status.set(TransferCancelled(kind))
    return
  }
  let path = paths[0]
  match request {
    @host.HostServiceRequest::FileDialog(
      { kind: @host.HostFileDialogKind::SaveFile, .. }
    ) => self.perform_text_file_write(path, services, kind=FileSaveAs)
    @host.HostServiceRequest::FileDialog(
      { kind: @host.HostFileDialogKind::OpenFile, .. }
    ) => self.perform_text_file_read(path, services)
    @host.HostServiceRequest::FileDialog(
      { kind: @host.HostFileDialogKind::PickDirectory, .. }
    ) => self.load_tree_from_directory(path, services)
    _ =>
      self.transfer_status.set(
        TransferUnavailable("unsupported file dialog response"),
      )
  }
}

///|
fn markdown_editor_transfer_status_label(
  status : MarkdownEditorTransferStatus,
) -> String {
  match status {
    TransferReady => ""
    TransferRequesting(ClipboardImport) => "Importing clipboard"
    TransferRequesting(ClipboardExport) => "Exporting Markdown"
    TransferRequesting(ClipboardHtmlExport) => "Exporting HTML"
    TransferRequesting(FileOpen) => "Opening file"
    TransferRequesting(FileSaveAs) => "Choosing save location"
    TransferRequesting(FileSave) => "Saving file"
    TransferRequesting(OpenTarget) => "Opening target"
    TransferPending(_, ClipboardImport) => "Waiting for clipboard"
    TransferPending(_, ClipboardExport) => "Waiting for export"
    TransferPending(_, ClipboardHtmlExport) => "Waiting for HTML export"
    TransferPending(_, FileOpen) => "Waiting for file"
    TransferPending(_, FileSaveAs) => "Waiting for save location"
    TransferPending(_, FileSave) => "Waiting for save"
    TransferPending(_, OpenTarget) => "Waiting for target"
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
fn markdown_editor_transfer_kind(
  request : @host.HostServiceRequest,
) -> MarkdownEditorTransferKind {
  match request {
    @host.HostServiceRequest::Clipboard(@host.HostClipboardRequest::ReadText) =>
      ClipboardImport
    @host.HostServiceRequest::Clipboard(
      @host.HostClipboardRequest::WriteText(_)
    ) => ClipboardExport
    @host.HostServiceRequest::FileDialog(
      { kind: @host.HostFileDialogKind::OpenFile, .. }
    ) => FileOpen
    @host.HostServiceRequest::FileDialog(
      { kind: @host.HostFileDialogKind::SaveFile, .. }
    ) => FileSaveAs
    @host.HostServiceRequest::TextFile(@host.HostTextFileRequest::ReadText(_)) =>
      FileOpen
    @host.HostServiceRequest::TextFile(
      @host.HostTextFileRequest::WriteText(_, _)
    ) => FileSave
    @host.HostServiceRequest::OpenUrl(_) => OpenTarget
    _ => ClipboardExport
  }
}

///|
fn markdown_editor_transfer_kind_key(
  kind : MarkdownEditorTransferKind,
) -> String {
  match kind {
    ClipboardImport => "clipboard-import"
    ClipboardExport => "clipboard-export"
    ClipboardHtmlExport => "html-export"
    FileOpen => "file-open"
    FileSaveAs => "file-save-as"
    FileSave => "file-save"
    OpenTarget => "open-target"
  }
}

///|
fn markdown_editor_host_completion_for_response(
  request : @host.HostServiceRequest,
  response : @host.HostServiceResponse,
) -> @host.HostCompletedServiceResponse {
  let id = match response {
    @host.HostServiceResponse::Pending(id) => id
    _ => @host.HostServiceRequestId::new(0)
  }
  { id, request, response }
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
