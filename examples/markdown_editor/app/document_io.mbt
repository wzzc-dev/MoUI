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
  self.document.set(source)
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
/// Whether the undo history has an entry to restore.
fn MarkdownEditorApp::can_undo(self : MarkdownEditorApp) -> Bool {
  self.undo_stack.get().length() > 0
}

///|
/// Whether the redo history has an entry to restore.
fn MarkdownEditorApp::can_redo(self : MarkdownEditorApp) -> Bool {
  self.redo_stack.get().length() > 0
}

///|
fn MarkdownEditorApp::transfer_status_label(self : MarkdownEditorApp) -> String {
  markdown_editor_transfer_status_label(self.transfer_status.get())
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
    }
    @host.HostServiceResponse::ClipboardWritten =>
      match markdown_editor_active_transfer_kind(self.transfer_status.get()) {
        Some(ClipboardHtmlExport) =>
          self.transfer_status.set(TransferHtmlCopied)
        _ => self.transfer_status.set(TransferCopied)
      }
    @host.HostServiceResponse::FileDialogSelection(paths) =>
      self.apply_file_dialog_selection(completion.request, paths)
    @host.HostServiceResponse::TextFileContent(path, text) => {
      self.load_document(text, path~)
      self.transfer_status.set(TransferOpened(path))
    }
    @host.HostServiceResponse::TextFileWritten(path) => {
      self.save_document_as(path)
      match markdown_editor_active_transfer_kind(self.transfer_status.get()) {
        Some(FileSaveAs) => self.transfer_status.set(TransferSavedAs(path))
        _ => self.transfer_status.set(TransferSaved(path))
      }
    }
    @host.HostServiceResponse::UrlOpened =>
      self.transfer_status.set(TransferTargetOpened)
    @host.HostServiceResponse::Unavailable(reason) =>
      self.transfer_status.set(TransferUnavailable(reason))
    _ =>
      self.transfer_status.set(
        TransferUnavailable(
          "clipboard service returned an unsupported response",
        ),
      )
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
fn markdown_editor_status_label(
  block_label : String,
  snapshot : MarkdownEditorSnapshot,
  selection : MarkdownEditorSelection,
) -> String {
  let section = markdown_editor_active_section_suffix(snapshot, selection)
  block_label + section + " / " + markdown_editor_reading_label(snapshot)
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
