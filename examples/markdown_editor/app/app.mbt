///|
using @views {
  button,
  column,
  empty,
  frame,
  padding_edges,
  row,
  scroll_view,
  spacer,
  surface,
  text,
  text_field,
}

///|
pub struct MarkdownEditorApp {
  document : @core.State[String]
  selection : @core.State[MarkdownEditorSelection]
  link_target : @core.State[String]
  image_target : @core.State[String]
  footnote_text : @core.State[String]
  html_block_text : @core.State[String]
  target_kind : @core.State[MarkdownEditorTargetKind]
  block_label : @core.State[String]
  source_preview_visible : @core.State[Bool]
  outline_visible : @core.State[Bool]
  find_visible : @core.State[Bool]
  find_query : @core.State[String]
  replace_text : @core.State[String]
  document_path : @core.State[String]
  saved_document : @core.State[String]
  priv transfer_status : @core.State[MarkdownEditorTransferStatus]
  undo_stack : @core.State[Array[MarkdownEditorHistoryEntry]]
  redo_stack : @core.State[Array[MarkdownEditorHistoryEntry]]
  editor_scroll : @core.ScrollState
}

///|
struct MarkdownEditorHistoryEntry {
  source : String
  selection : MarkdownEditorSelection
} derive(Eq, Debug, ToJson)

///|
enum MarkdownEditorTargetKind {
  PlainSelection
  LinkTarget
  ImageTarget
  FootnoteTarget
  HtmlBlockTarget
  TableTools
} derive(Eq, Debug, ToJson)

///|
priv enum MarkdownEditorTransferKind {
  ClipboardImport
  ClipboardExport
  FileOpen
  FileSaveAs
  FileSave
  OpenTarget
}

///|
priv enum MarkdownEditorTransferStatus {
  TransferReady
  TransferRequesting(MarkdownEditorTransferKind)
  TransferPending(@host.HostServiceRequestId, MarkdownEditorTransferKind)
  TransferUnavailable(String)
  TransferCancelled(MarkdownEditorTransferKind)
  TransferCopied
  TransferImported
  TransferOpened(String)
  TransferSaved(String)
  TransferSavedAs(String)
  TransferTargetOpened
}

///|
priv enum MarkdownEditorMsg {
  NewDocument
  SaveDocument
  SaveDocumentAs
  OpenDocument
  ImportFromClipboard
  ExportToClipboard
  HostTransferCompleted(@host.HostCompletedServiceResponse)
  Undo
  Redo
  ToggleOutline
  ToggleFind
  OpenFind
  OpenFindReplace
  CloseFind
  DismissAuxiliaryPanels
  ToggleSourcePreview
  UpdateDocument(String)
  UpdateFindQuery(String)
  UpdateReplaceText(String)
  UpdateLinkTarget(String)
  UpdateImageTarget(String)
  UpdateFootnoteText(String)
  UpdateHtmlBlockText(String)
  ApplyLinkTarget
  OpenTarget
  ApplyImageTarget
  ApplyFootnoteText
  ApplyHtmlBlockText
  FindNext
  FindPrevious
  ReplaceFindCurrent
  ReplaceFindAll
  ApplyCommand(MarkdownEditorCommand)
  SetSelection(Int, @core.TextRange?)
  JumpToOutline(Int)
  JumpToNextHeading
  JumpToPreviousHeading
  ToggleCurrentTask
  InsertHardBreak
  IndentLines
  OutdentLines
  ToggleTaskAt(Int)
  EditorScrollTo(Double)
}

///|
pub fn MarkdownEditorApp::new() -> MarkdownEditorApp {
  let document = sample_markdown()
  {
    document: @core.State::new(document),
    selection: @core.State::new({ caret: 0, selection: None }),
    link_target: @core.State::new("https://moui.dev"),
    image_target: @core.State::new("assets/image.png"),
    footnote_text: @core.State::new("Footnote text"),
    html_block_text: @core.State::new("<div>HTML</div>"),
    target_kind: @core.State::new(PlainSelection),
    block_label: @core.State::new("Paragraph"),
    source_preview_visible: @core.State::new(false),
    outline_visible: @core.State::new(false),
    find_visible: @core.State::new(false),
    find_query: @core.State::new(""),
    replace_text: @core.State::new(""),
    document_path: @core.State::new(""),
    saved_document: @core.State::new(document),
    transfer_status: @core.State::new(TransferReady),
    undo_stack: @core.State::new([]),
    redo_stack: @core.State::new([]),
    editor_scroll: @core.ScrollState::new(),
  }
}

///|
fn MarkdownEditorApp::toggle_source_preview(self : MarkdownEditorApp) -> Unit {
  self.source_preview_visible.set(!self.source_preview_visible.get())
}

///|
fn MarkdownEditorApp::toggle_outline(self : MarkdownEditorApp) -> Unit {
  self.outline_visible.set(!self.outline_visible.get())
}

///|
fn MarkdownEditorApp::toggle_find(self : MarkdownEditorApp) -> Unit {
  if self.find_visible.get() {
    self.find_visible.set(false)
  } else {
    self.open_find()
  }
}

///|
fn MarkdownEditorApp::open_find(self : MarkdownEditorApp) -> Unit {
  self.find_visible.set(true)
  match
    markdown_editor_find_query_from_selection(
      self.document.get(),
      self.selection.get(),
    ) {
    Some(query) => self.find_query.set(query)
    None =>
      match
        markdown_editor_find_seed_from_caret_word(
          self.document.get(),
          self.selection.get(),
        ) {
        Some(seed) => {
          self.find_query.set(seed.query)
          self.select_find_match(seed.range)
        }
        None => ()
      }
  }
}

///|
fn MarkdownEditorApp::close_find(self : MarkdownEditorApp) -> Unit {
  self.find_visible.set(false)
}

///|
fn MarkdownEditorApp::reset_find_session(self : MarkdownEditorApp) -> Unit {
  self.find_visible.set(false)
  self.find_query.set("")
  self.replace_text.set("")
}

///|
fn MarkdownEditorApp::dismiss_auxiliary_panels(
  self : MarkdownEditorApp,
) -> Unit {
  if self.find_visible.get() {
    self.close_find()
  } else if self.outline_visible.get() || self.source_preview_visible.get() {
    self.outline_visible.set(false)
    self.source_preview_visible.set(false)
  } else {
    let selection = self.selection.get()
    if selection.selection is Some(_) {
      self.selection.set({ caret: selection.caret, selection: None })
      self.sync_target_inputs()
    }
  }
}

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
  self.saved_document.set(source)
  self.selection.set({ caret: 0, selection: None })
  self.reset_find_session()
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
  self.mark_document_saved()
}

///|
fn MarkdownEditorApp::request_file_open(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> @core.Effect[MarkdownEditorMsg] {
  self.transfer_status.set(TransferRequesting(FileOpen))
  let options = @host.HostFileDialogOptions::new(
    kind=@host.HostFileDialogKind::OpenFile,
    title="Open Markdown",
    filters=["md", "markdown"],
  )
  @core.Effect::host_service(
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
) -> @core.Effect[MarkdownEditorMsg] {
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
) -> @core.Effect[MarkdownEditorMsg] {
  self.transfer_status.set(TransferRequesting(FileSaveAs))
  let options = self.save_file_dialog_options()
  @core.Effect::host_service(
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
fn MarkdownEditorApp::request_text_file_write(
  self : MarkdownEditorApp,
  path : String,
  services : @host.HostAppServices,
  kind~ : MarkdownEditorTransferKind,
) -> @core.Effect[MarkdownEditorMsg] {
  self.transfer_status.set(TransferRequesting(kind))
  @core.Effect::host_service(
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
fn MarkdownEditorApp::transfer_status_label(self : MarkdownEditorApp) -> String {
  markdown_editor_transfer_status_label(self.transfer_status.get())
}

///|
fn MarkdownEditorApp::request_clipboard_import(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> @core.Effect[MarkdownEditorMsg] {
  self.transfer_status.set(TransferRequesting(ClipboardImport))
  @core.Effect::host_service(
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
) -> @core.Effect[MarkdownEditorMsg] {
  self.transfer_status.set(TransferRequesting(ClipboardExport))
  @core.Effect::host_service(
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
fn MarkdownEditorApp::request_open_target(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> @core.Effect[MarkdownEditorMsg] {
  let target = match self.open_target_value() {
    Some(target) => target
    None => {
      self.transfer_status.set(
        TransferUnavailable(
          "open target requires an active link or image target",
        ),
      )
      return @core.Effect::none()
    }
  }
  self.transfer_status.set(TransferRequesting(OpenTarget))
  @core.Effect::host_service(
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
      self.transfer_status.set(TransferCopied)
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
fn MarkdownEditorApp::clear_history(self : MarkdownEditorApp) -> Unit {
  self.undo_stack.set([])
  self.redo_stack.set([])
}

///|
fn MarkdownEditorApp::apply_command_to_selection(
  self : MarkdownEditorApp,
  command : MarkdownEditorCommand,
) -> Unit {
  let before = self.history_entry()
  let result = markdown_editor_apply_command_at(
    before.source,
    command,
    Some(before.selection),
  )
  if result.source == before.source &&
    result.selection == before.selection.selection &&
    result.caret == before.selection.caret {
    return
  }
  self.push_undo(before)
  self.redo_stack.set([])
  self.document.set(result.source)
  self.selection.set({ caret: result.caret, selection: result.selection })
  self.sync_target_inputs()
}

///|
fn MarkdownEditorApp::apply_text_transform(
  self : MarkdownEditorApp,
  transform : @core.RichTextInputTransform,
) -> Unit {
  let before = self.history_entry()
  if transform.text == before.source &&
    transform.selection == before.selection.selection &&
    transform.caret == before.selection.caret {
    return
  }
  self.push_undo(before)
  self.redo_stack.set([])
  self.document.set(transform.text)
  self.selection.set({ caret: transform.caret, selection: transform.selection })
  self.sync_target_inputs()
}

///|
fn MarkdownEditorApp::shift_current_lines(
  self : MarkdownEditorApp,
  indent~ : Bool,
) -> Unit {
  let selection = self.selection.get()
  if indent {
    self.apply_text_transform(
      markdown_editor_indent_lines(
        self.document.get(),
        selection.caret,
        selection.selection,
      ),
    )
  } else {
    match
      markdown_editor_outdent_lines(
        self.document.get(),
        selection.caret,
        selection.selection,
      ) {
      Some(transform) => self.apply_text_transform(transform)
      None => ()
    }
  }
}

///|
fn MarkdownEditorApp::insert_hard_break(self : MarkdownEditorApp) -> Unit {
  let selection = self.selection.get()
  match
    markdown_editor_insert_hard_break(
      self.document.get(),
      selection.caret,
      selection.selection,
    ) {
    Some(transform) => self.apply_text_transform(transform)
    None => ()
  }
}

///|
fn MarkdownEditorApp::undo(self : MarkdownEditorApp) -> Bool {
  self.restore_history(undo=true)
}

///|
fn MarkdownEditorApp::redo(self : MarkdownEditorApp) -> Bool {
  self.restore_history(undo=false)
}

///|
fn MarkdownEditorApp::set_selection(
  self : MarkdownEditorApp,
  caret : Int,
  selection : @core.TextRange?,
) -> Unit {
  self.selection.set({ caret, selection })
  self.sync_target_inputs()
}

///|
fn MarkdownEditorApp::jump_to_outline(
  self : MarkdownEditorApp,
  source_start : Int,
) -> Unit {
  let caret = markdown_editor_clamp_int(
    source_start,
    0,
    markdown_editor_text_length(self.document.get()),
  )
  self.selection.set({ caret, selection: None })
  self.sync_target_inputs()
  self.scroll_to_source(caret)
}

///|
fn MarkdownEditorApp::jump_to_next_heading(self : MarkdownEditorApp) -> Unit {
  let snapshot = MarkdownEditorSnapshot::parse(self.document.get())
  match
    markdown_editor_next_outline_start(
      snapshot.outline,
      self.selection.get().caret,
    ) {
    Some(source_start) => self.jump_to_outline(source_start)
    None => ()
  }
}

///|
fn MarkdownEditorApp::jump_to_previous_heading(
  self : MarkdownEditorApp,
) -> Unit {
  let snapshot = MarkdownEditorSnapshot::parse(self.document.get())
  match
    markdown_editor_previous_outline_start(
      snapshot.outline,
      self.selection.get().caret,
    ) {
    Some(source_start) => self.jump_to_outline(source_start)
    None => ()
  }
}

///|
fn markdown_editor_next_outline_start(
  outline : Array[MarkdownEditorOutlineItem],
  caret : Int,
) -> Int? {
  if outline.length() == 0 {
    return None
  }
  for item in outline {
    if item.source_start > caret {
      return Some(item.source_start)
    }
  }
  Some(outline[0].source_start)
}

///|
fn markdown_editor_previous_outline_start(
  outline : Array[MarkdownEditorOutlineItem],
  caret : Int,
) -> Int? {
  if outline.length() == 0 {
    return None
  }
  let mut previous : Int? = None
  for item in outline {
    if item.source_start < caret {
      previous = Some(item.source_start)
    }
  }
  match previous {
    Some(source_start) => Some(source_start)
    None => Some(outline[outline.length() - 1].source_start)
  }
}

///|
fn MarkdownEditorApp::scroll_to_source(
  self : MarkdownEditorApp,
  source_start : Int,
) -> Unit {
  let snapshot = MarkdownEditorSnapshot::parse(self.document.get())
  let editor_font = @core.FontSpec::new(size=17.0)
  let editor_width = markdown_editor_primary_editor_width(
    self.source_preview_visible.get(),
    self.outline_visible.get(),
  )
  let viewport_height = markdown_editor_viewport_height()
  let content_height = markdown_editor_max_double(
    viewport_height,
    @core.rich_text_document_height(snapshot.rich_text, editor_font) + 96.0,
  )
  let max_scroll = markdown_editor_max_double(
    0.0,
    content_height - viewport_height,
  )
  let editor_frame = @core.Rect::new(
    x=0.0,
    y=0.0,
    width=editor_width,
    height=content_height,
  )
  let content = @core.rich_text_editor_content_rect(editor_frame)
  match
    @core.rich_text_document_caret_rect_at_source(
      snapshot.rich_text,
      source_start,
      content,
      editor_font,
    ) {
    Some(rect) =>
      self.editor_scroll.scroll_to(
        x=0.0,
        y=markdown_editor_clamp_double(rect.origin.y - 48.0, 0.0, max_scroll),
      )
    None => self.editor_scroll.scroll_to(x=0.0, y=0.0)
  }
}

///|
fn MarkdownEditorApp::find_next(self : MarkdownEditorApp) -> Unit {
  self.find_visible.set(true)
  let matches = markdown_editor_find_matches(
    self.document.get(),
    self.find_query.get(),
  )
  if matches.length() == 0 {
    return
  }
  let index = markdown_editor_find_next_index(matches, self.selection.get())
  self.select_find_match(matches[index])
}

///|
fn MarkdownEditorApp::find_previous(self : MarkdownEditorApp) -> Unit {
  self.find_visible.set(true)
  let matches = markdown_editor_find_matches(
    self.document.get(),
    self.find_query.get(),
  )
  if matches.length() == 0 {
    return
  }
  let index = markdown_editor_find_previous_index(matches, self.selection.get())
  self.select_find_match(matches[index])
}

///|
fn MarkdownEditorApp::update_find_query(
  self : MarkdownEditorApp,
  query : String,
) -> Unit {
  self.find_query.set(query)
  if !self.find_visible.get() {
    return
  }
  if query == "" {
    let selection = self.selection.get()
    if selection.selection is Some(_) {
      self.selection.set({ caret: selection.caret, selection: None })
      self.sync_target_inputs()
    }
    return
  }
  let matches = markdown_editor_find_matches(self.document.get(), query)
  if matches.length() == 0 {
    let selection = self.selection.get()
    if selection.selection is Some(_) {
      self.selection.set({ caret: selection.caret, selection: None })
      self.sync_target_inputs()
    }
    return
  }
  let index = markdown_editor_find_live_update_index(
    matches,
    self.selection.get(),
  )
  if index >= 0 {
    self.select_find_match(matches[index])
  }
}

///|
fn MarkdownEditorApp::select_find_match(
  self : MarkdownEditorApp,
  range : @core.TextRange,
) -> Unit {
  self.selection.set({ caret: range.end, selection: Some(range) })
  self.sync_target_inputs()
  self.scroll_to_source(range.start)
}

///|
fn MarkdownEditorApp::replace_current_find_match(
  self : MarkdownEditorApp,
) -> Unit {
  let source = self.document.get()
  let query = self.find_query.get()
  let replacement = self.replace_text.get()
  let matches = markdown_editor_find_matches(source, query)
  if matches.length() == 0 {
    return
  }
  let active = markdown_editor_find_active_index(matches, self.selection.get())
  let index = if active >= 0 {
    active
  } else {
    markdown_editor_find_next_index(matches, self.selection.get())
  }
  let range = matches[index]
  let before = self.history_entry()
  let next_source = markdown_editor_replace_source_range(
    source, range, replacement,
  )
  if next_source == source {
    return
  }
  self.push_undo(before)
  self.redo_stack.set([])
  self.document.set(next_source)
  let end = range.start + markdown_editor_text_length(replacement)
  let next_matches = markdown_editor_find_matches(next_source, query)
  match
    markdown_editor_next_match_after_replacement(next_matches, range.start, end) {
    Some(next_range) => self.select_find_match(next_range)
    None => {
      self.selection.set({
        caret: end,
        selection: markdown_editor_replacement_selection(range.start, end),
      })
      self.sync_target_inputs()
      self.scroll_to_source(range.start)
    }
  }
}

///|
fn MarkdownEditorApp::replace_all_find_matches(
  self : MarkdownEditorApp,
) -> Unit {
  let source = self.document.get()
  let query = self.find_query.get()
  let replacement = self.replace_text.get()
  let matches = markdown_editor_find_matches(source, query)
  if matches.length() == 0 {
    return
  }
  let next_source = markdown_editor_replace_all_matches(
    source, matches, replacement,
  )
  if next_source == source {
    return
  }
  let before = self.history_entry()
  self.push_undo(before)
  self.redo_stack.set([])
  self.document.set(next_source)
  let start = matches[0].start
  let end = start + markdown_editor_text_length(replacement)
  self.selection.set({
    caret: end,
    selection: markdown_editor_replacement_selection(start, end),
  })
  self.sync_target_inputs()
  self.scroll_to_source(start)
}

///|
fn MarkdownEditorApp::set_document_from_input(
  self : MarkdownEditorApp,
  value : String,
) -> Unit {
  self.document.set(value)
  self.sync_target_inputs()
}

///|
fn MarkdownEditorApp::apply_link_target(self : MarkdownEditorApp) -> Unit {
  self.apply_command_to_selection(SetLinkTarget(self.link_target.get()))
}

///|
fn MarkdownEditorApp::apply_image_target(self : MarkdownEditorApp) -> Unit {
  self.apply_command_to_selection(SetImageTarget(self.image_target.get()))
}

///|
fn MarkdownEditorApp::apply_footnote_text(self : MarkdownEditorApp) -> Unit {
  self.apply_command_to_selection(SetFootnoteText(self.footnote_text.get()))
}

///|
fn MarkdownEditorApp::apply_html_block_text(self : MarkdownEditorApp) -> Unit {
  self.apply_command_to_selection(SetHtmlBlockText(self.html_block_text.get()))
}

///|
fn MarkdownEditorApp::history_entry(
  self : MarkdownEditorApp,
) -> MarkdownEditorHistoryEntry {
  { source: self.document.get(), selection: self.selection.get() }
}

///|
fn MarkdownEditorApp::push_undo(
  self : MarkdownEditorApp,
  entry : MarkdownEditorHistoryEntry,
) -> Unit {
  let stack = self.undo_stack.get()
  stack.push(entry)
  self.undo_stack.set(stack)
}

///|
fn MarkdownEditorApp::push_redo(
  self : MarkdownEditorApp,
  entry : MarkdownEditorHistoryEntry,
) -> Unit {
  let stack = self.redo_stack.get()
  stack.push(entry)
  self.redo_stack.set(stack)
}

///|
fn MarkdownEditorApp::restore_history(
  self : MarkdownEditorApp,
  undo~ : Bool,
) -> Bool {
  let stack = if undo { self.undo_stack.get() } else { self.redo_stack.get() }
  if stack.length() == 0 {
    return false
  }
  let entry = stack[stack.length() - 1]
  ignore(stack.pop())
  if undo {
    self.undo_stack.set(stack)
    self.push_redo(self.history_entry())
  } else {
    self.redo_stack.set(stack)
    self.push_undo(self.history_entry())
  }
  self.document.set(entry.source)
  self.selection.set(entry.selection)
  self.sync_target_inputs()
  true
}

///|
fn MarkdownEditorApp::sync_target_inputs(self : MarkdownEditorApp) -> Unit {
  let selection = self.selection.get()
  let block_label = markdown_editor_active_block_label(
    self.document.get(),
    selection,
  )
  self.block_label.set(block_label)
  match markdown_editor_selected_link_target(self.document.get(), selection) {
    Some(target) => {
      self.link_target.set(target)
      self.target_kind.set(LinkTarget)
      return
    }
    None => ()
  }
  match markdown_editor_selected_image_target(self.document.get(), selection) {
    Some(target) => {
      self.image_target.set(target)
      self.target_kind.set(ImageTarget)
    }
    None =>
      match
        markdown_editor_selected_footnote_text(self.document.get(), selection) {
        Some(text) => {
          self.footnote_text.set(text)
          self.target_kind.set(FootnoteTarget)
        }
        None =>
          match
            markdown_editor_selected_html_block_text(
              self.document.get(),
              selection,
            ) {
            Some(text) => {
              self.html_block_text.set(text)
              self.target_kind.set(HtmlBlockTarget)
            }
            None =>
              if block_label == "Table" {
                self.target_kind.set(TableTools)
              } else {
                self.target_kind.set(PlainSelection)
              }
          }
      }
  }
}

///|
fn MarkdownEditorApp::toggle_task_at(
  self : MarkdownEditorApp,
  content_offset : Int,
) -> Unit {
  match markdown_editor_toggle_task_at(self.document.get(), content_offset) {
    Some(result) => {
      self.push_undo(self.history_entry())
      self.redo_stack.set([])
      self.document.set(result.source)
      self.selection.set({ caret: result.caret, selection: result.selection })
      self.sync_target_inputs()
    }
    None => ()
  }
}

///|
fn MarkdownEditorApp::toggle_current_task(self : MarkdownEditorApp) -> Unit {
  match
    markdown_editor_toggle_current_task(
      self.document.get(),
      self.selection.get(),
    ) {
    Some(result) => {
      self.push_undo(self.history_entry())
      self.redo_stack.set([])
      self.document.set(result.source)
      self.selection.set({ caret: result.caret, selection: result.selection })
      self.sync_target_inputs()
    }
    None => ()
  }
}

///|
fn MarkdownEditorApp::update(
  self : MarkdownEditorApp,
  message : MarkdownEditorMsg,
) -> MarkdownEditorApp {
  match message {
    NewDocument => self.new_document()
    SaveDocument =>
      if self.document_path.get() == "" {
        self.transfer_status.set(
          TransferUnavailable(
            "save requires host file dialog services for unnamed documents",
          ),
        )
      } else {
        self.transfer_status.set(
          TransferUnavailable("save requires host text file services"),
        )
      }
    SaveDocumentAs =>
      self.transfer_status.set(
        TransferUnavailable("save as requires host file dialog services"),
      )
    OpenDocument =>
      self.transfer_status.set(
        TransferUnavailable("open requires host file dialog services"),
      )
    ImportFromClipboard =>
      self.transfer_status.set(
        TransferUnavailable("clipboard import requires host services"),
      )
    ExportToClipboard =>
      self.transfer_status.set(
        TransferUnavailable("clipboard export requires host services"),
      )
    HostTransferCompleted(completion) =>
      self.apply_transfer_completion(completion)
    Undo => ignore(self.undo())
    Redo => ignore(self.redo())
    ToggleOutline => self.toggle_outline()
    ToggleFind => self.toggle_find()
    OpenFind => self.open_find()
    OpenFindReplace => self.open_find()
    CloseFind => self.close_find()
    DismissAuxiliaryPanels => self.dismiss_auxiliary_panels()
    ToggleSourcePreview => self.toggle_source_preview()
    UpdateDocument(value) => self.set_document_from_input(value)
    UpdateFindQuery(value) => self.update_find_query(value)
    UpdateReplaceText(value) => self.replace_text.set(value)
    UpdateLinkTarget(value) => self.link_target.set(value)
    UpdateImageTarget(value) => self.image_target.set(value)
    UpdateFootnoteText(value) => self.footnote_text.set(value)
    UpdateHtmlBlockText(value) => self.html_block_text.set(value)
    ApplyLinkTarget => self.apply_link_target()
    OpenTarget =>
      self.transfer_status.set(
        TransferUnavailable("open target requires host services"),
      )
    ApplyImageTarget => self.apply_image_target()
    ApplyFootnoteText => self.apply_footnote_text()
    ApplyHtmlBlockText => self.apply_html_block_text()
    FindNext => self.find_next()
    FindPrevious => self.find_previous()
    ReplaceFindCurrent => self.replace_current_find_match()
    ReplaceFindAll => self.replace_all_find_matches()
    ApplyCommand(command) => self.apply_command_to_selection(command)
    SetSelection(caret, selection) => self.set_selection(caret, selection)
    JumpToOutline(source_start) => self.jump_to_outline(source_start)
    JumpToNextHeading => self.jump_to_next_heading()
    JumpToPreviousHeading => self.jump_to_previous_heading()
    ToggleCurrentTask => self.toggle_current_task()
    InsertHardBreak => self.insert_hard_break()
    IndentLines => self.shift_current_lines(indent=true)
    OutdentLines => self.shift_current_lines(indent=false)
    ToggleTaskAt(offset) => self.toggle_task_at(offset)
    EditorScrollTo(y) => self.editor_scroll.scroll_to(x=0.0, y~)
  }
  self
}

///|
fn MarkdownEditorApp::update_with_services(
  self : MarkdownEditorApp,
  message : MarkdownEditorMsg,
  services : @host.HostAppServices,
) -> (MarkdownEditorApp, @core.Effect[MarkdownEditorMsg]) {
  match message {
    SaveDocument => (self, self.request_document_save(services))
    SaveDocumentAs => (self, self.request_file_save_as(services))
    OpenDocument => (self, self.request_file_open(services))
    ImportFromClipboard => (self, self.request_clipboard_import(services))
    ExportToClipboard => (self, self.request_clipboard_export(services))
    OpenTarget => (self, self.request_open_target(services))
    HostTransferCompleted(completion) => {
      self.apply_transfer_completion_with_services(completion, services)
      (self, @core.Effect::none())
    }
    _ => (self.update(message), @core.Effect::none())
  }
}

///|
fn MarkdownEditorApp::subscriptions(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> @core.Subscription[MarkdownEditorMsg] {
  match self.transfer_status.get() {
    TransferPending(id, kind) =>
      services.completion_subscription(
        id,
        map=completion => HostTransferCompleted(completion),
        key="markdown-editor:transfer:" +
          markdown_editor_transfer_kind_key(kind) +
          ":" +
          id.value.to_string(),
        label="Markdown editor transfer completion",
      )
    _ => @core.Subscription::none()
  }
}

///|
fn MarkdownEditorApp::root(
  self : MarkdownEditorApp,
) -> @core.View[MarkdownEditorMsg] {
  let theme = @core.Theme::light()
  let document = self.document.get()
  let snapshot = MarkdownEditorSnapshot::parse(document)
  let editor_font = @core.FontSpec::new(size=17.0)
  let show_source = self.source_preview_visible.get()
  let show_outline = self.outline_visible.get()
  let workspace_width = markdown_editor_workspace_width(
    show_source, show_outline,
  )
  let target_bar = self.target_bar(theme)
  let selection = self.selection.get()
  let target_kind = self.target_kind.get()
  let block_label = self.block_label.get()
  let scroll_offset = self.editor_scroll.offset()
  let children : Array[@core.View[MarkdownEditorMsg]] = [
    self.chrome(
      theme, snapshot, block_label, document, selection, workspace_width,
    ),
  ]
  if self.find_visible.get() {
    children.push(self.find_bar(theme, document, selection, workspace_width))
  }
  children.push(
    row(
      [
        editor_source_layout(
          self,
          document,
          snapshot,
          editor_font,
          theme,
          show_source,
          show_outline,
          target_bar,
          selection,
          target_kind,
          scroll_offset,
          (caret, selection) => SetSelection(caret, selection),
          offset => ToggleTaskAt(offset),
        ),
      ],
      spacing=theme.spacing_scale.lg,
      align=@views.CrossAlign::Start,
    ),
  )
  let workspace = column(
    children,
    spacing=theme.spacing_scale.sm,
    align=@views.CrossAlign::Start,
  )
  markdown_editor_centered_workspace(
    padding_edges(
      workspace,
      top=theme.spacing_scale.md,
      right=theme.spacing_scale.xl,
      bottom=theme.spacing_scale.xl,
      left=theme.spacing_scale.md,
    ),
  )
}

///|
fn MarkdownEditorApp::reactive_root(
  self : MarkdownEditorApp,
  ctx : @core.BuildContext,
) -> @core.View[MarkdownEditorMsg] {
  ignore(ctx.watch(self.document))
  ignore(ctx.watch(self.selection))
  ignore(ctx.watch(self.link_target))
  ignore(ctx.watch(self.image_target))
  ignore(ctx.watch(self.footnote_text))
  ignore(ctx.watch(self.html_block_text))
  ignore(ctx.watch(self.target_kind))
  ignore(ctx.watch(self.block_label))
  ignore(ctx.watch(self.source_preview_visible))
  ignore(ctx.watch(self.outline_visible))
  ignore(ctx.watch(self.find_visible))
  ignore(ctx.watch(self.find_query))
  ignore(ctx.watch(self.replace_text))
  ignore(ctx.watch(self.document_path))
  ignore(ctx.watch(self.saved_document))
  ignore(ctx.watch(self.transfer_status))
  ignore(ctx.watch_scroll(self.editor_scroll))
  self.root()
}

///|
fn markdown_editor_workspace_width(
  show_source : Bool,
  show_outline : Bool,
) -> Double {
  let mut width = markdown_editor_primary_editor_width(
    show_source, show_outline,
  )
  let mut gaps = 0
  if show_outline {
    width = width + markdown_editor_outline_inspector_width()
    gaps = gaps + 1
  }
  if show_source {
    width = width + markdown_editor_source_inspector_width()
    gaps = gaps + 1
  }
  width + @core.Theme::light().spacing_scale.lg * gaps.to_double()
}

///|
fn markdown_editor_centered_workspace(
  child : @core.View[MarkdownEditorMsg],
) -> @core.View[MarkdownEditorMsg] {
  @views.custom_children_layout(
    children=[child],
    measure=ctx => ctx.constraints.max,
    place=ctx => {
      let child_size = ctx.child_sizes[0]
      let x = if ctx.frame.size.width >= 1100.0 {
        ctx.frame.origin.x +
        markdown_editor_max_double(
          0.0,
          (ctx.frame.size.width - child_size.width) / 2.0,
        )
      } else {
        ctx.frame.origin.x
      }
      let y = ctx.frame.origin.y
      [
        @core.Rect::new(
          x~,
          y~,
          width=child_size.width,
          height=child_size.height,
        ),
      ]
    },
    paint=bounds => {
      [@core.DrawCommand::FillRect(bounds, markdown_editor_window_background())]
    },
    semantics_label="Markdown editor workspace",
  )
}

///|
fn MarkdownEditorApp::chrome(
  self : MarkdownEditorApp,
  theme : @core.Theme,
  snapshot : MarkdownEditorSnapshot,
  block_label : String,
  source : String,
  selection : MarkdownEditorSelection,
  width : Double,
) -> @core.View[MarkdownEditorMsg] {
  frame(
    row(
      [
        text(
          self.document_status_label(snapshot, block_label, selection) +
          markdown_editor_active_format_suffix(source, selection),
          width=300.0,
          height=28.0,
        )
        .font(theme.typography.caption)
        .foreground(@core.Color::black().multiply_alpha(0.42)),
        spacer(),
        editor_chrome_button("New", NewDocument, theme),
        editor_chrome_button("Open", OpenDocument, theme),
        editor_chrome_button("Save", SaveDocument, theme),
        editor_chrome_button("Save As", SaveDocumentAs, theme),
        editor_chrome_button("Import", ImportFromClipboard, theme),
        editor_chrome_button("Export", ExportToClipboard, theme),
        editor_chrome_button("Undo", Undo, theme),
        editor_chrome_button("Redo", Redo, theme),
        editor_chrome_button("Find", ToggleFind, theme),
        editor_chrome_button("Nav", ToggleOutline, theme),
        editor_chrome_button("Src", ToggleSourcePreview, theme),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height=34.0,
  )
}

///|
fn MarkdownEditorApp::find_bar(
  self : MarkdownEditorApp,
  theme : @core.Theme,
  source : String,
  selection : MarkdownEditorSelection,
  width : Double,
) -> @core.View[MarkdownEditorMsg] {
  let query = self.find_query.get()
  let matches = markdown_editor_find_matches(source, query)
  frame(
    row(
      [
        text("Find", width=44.0, height=34.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        text_field(
          query,
          on_input=value => UpdateFindQuery(value),
          on_submit=Some(FindNext),
          placeholder="Search Markdown",
          variant=@views.TextFieldVariant::Outline,
          theme~,
          width=196.0,
          height=34.0,
        ).key("markdown-find-query"),
        text("Replace", width=64.0, height=34.0)
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        text_field(
          self.replace_text.get(),
          on_input=value => UpdateReplaceText(value),
          on_submit=Some(ReplaceFindCurrent),
          placeholder="Replacement",
          variant=@views.TextFieldVariant::Outline,
          theme~,
          width=196.0,
          height=34.0,
        ).key("markdown-replace-text"),
        text(
          markdown_editor_find_status_label(query, matches, selection),
          width=72.0,
          height=34.0,
        )
        .font(theme.typography.caption)
        .foreground(theme.palette.muted),
        editor_button("Prev", FindPrevious, @views.ButtonVariant::Ghost, theme),
        editor_button("Next", FindNext, @views.ButtonVariant::Ghost, theme),
        editor_button(
          "Replace",
          ReplaceFindCurrent,
          @views.ButtonVariant::Tonal,
          theme,
        ),
        editor_button("All", ReplaceFindAll, @views.ButtonVariant::Tonal, theme),
        editor_button("Done", CloseFind, @views.ButtonVariant::Ghost, theme),
      ],
      spacing=theme.spacing_scale.xs,
      align=@views.CrossAlign::Center,
    ),
    width~,
    height=42.0,
  )
}

///|
fn MarkdownEditorApp::document_status_label(
  self : MarkdownEditorApp,
  snapshot : MarkdownEditorSnapshot,
  block_label : String,
  selection : MarkdownEditorSelection,
) -> String {
  let title = markdown_editor_document_title(
    path=self.document_path.get(),
    fallback=snapshot.active_heading,
  )
  let save_state = if self.is_dirty() { "Unsaved" } else { "Saved" }
  let transfer = self.transfer_status_label()
  let transfer_suffix = if transfer == "" { "" } else { " / " + transfer }
  title +
  " / " +
  save_state +
  " / " +
  markdown_editor_status_label(block_label, snapshot, selection) +
  transfer_suffix
}

///|
fn markdown_editor_transfer_status_label(
  status : MarkdownEditorTransferStatus,
) -> String {
  match status {
    TransferReady => ""
    TransferRequesting(ClipboardImport) => "Importing clipboard"
    TransferRequesting(ClipboardExport) => "Exporting Markdown"
    TransferRequesting(FileOpen) => "Opening file"
    TransferRequesting(FileSaveAs) => "Choosing save location"
    TransferRequesting(FileSave) => "Saving file"
    TransferRequesting(OpenTarget) => "Opening target"
    TransferPending(_, ClipboardImport) => "Waiting for clipboard"
    TransferPending(_, ClipboardExport) => "Waiting for export"
    TransferPending(_, FileOpen) => "Waiting for file"
    TransferPending(_, FileSaveAs) => "Waiting for save location"
    TransferPending(_, FileSave) => "Waiting for save"
    TransferPending(_, OpenTarget) => "Waiting for target"
    TransferUnavailable(reason) => "Transfer unavailable: " + reason
    TransferCancelled(ClipboardImport) => "Import cancelled"
    TransferCancelled(ClipboardExport) => "Export cancelled"
    TransferCancelled(FileOpen) => "Open cancelled"
    TransferCancelled(FileSaveAs) => "Save cancelled"
    TransferCancelled(FileSave) => "Save cancelled"
    TransferCancelled(OpenTarget) => "Open target cancelled"
    TransferCopied => "Markdown copied"
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

///|
fn MarkdownEditorApp::target_bar(
  self : MarkdownEditorApp,
  theme : @core.Theme,
) -> @core.View[MarkdownEditorMsg] {
  let kind = self.target_kind.get()
  let block_label = self.block_label.get()
  let block_badge = text("Block: " + block_label, width=132.0, height=34.0)
    .font(theme.typography.caption)
    .foreground(theme.palette.muted)
  match kind {
    LinkTarget =>
      row(
        [
          block_badge,
          text("Link target", width=88.0, height=34.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          text_field(
            self.link_target.get(),
            on_input=value => UpdateLinkTarget(value),
            on_submit=Some(ApplyLinkTarget),
            placeholder="https://example.com",
            variant=@views.TextFieldVariant::Outline,
            theme~,
            width=360.0,
            height=34.0,
          ).key("markdown-link-target"),
          editor_button(
            "Apply",
            ApplyLinkTarget,
            @views.ButtonVariant::Tonal,
            theme,
          ),
          editor_button("Open", OpenTarget, @views.ButtonVariant::Ghost, theme),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      )
    ImageTarget =>
      row(
        [
          block_badge,
          text("Image src", width=88.0, height=34.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          text_field(
            self.image_target.get(),
            on_input=value => UpdateImageTarget(value),
            on_submit=Some(ApplyImageTarget),
            placeholder="assets/image.png",
            variant=@views.TextFieldVariant::Outline,
            theme~,
            width=360.0,
            height=34.0,
          ).key("markdown-image-target"),
          editor_button(
            "Apply",
            ApplyImageTarget,
            @views.ButtonVariant::Tonal,
            theme,
          ),
          editor_button("Open", OpenTarget, @views.ButtonVariant::Ghost, theme),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      )
    FootnoteTarget =>
      row(
        [
          block_badge,
          text("Footnote", width=88.0, height=34.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          text_field(
            self.footnote_text.get(),
            on_input=value => UpdateFootnoteText(value),
            on_submit=Some(ApplyFootnoteText),
            placeholder="Footnote text",
            variant=@views.TextFieldVariant::Outline,
            theme~,
            width=360.0,
            height=34.0,
          ).key("markdown-footnote-text"),
          editor_button(
            "Apply",
            ApplyFootnoteText,
            @views.ButtonVariant::Tonal,
            theme,
          ),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      )
    HtmlBlockTarget =>
      row(
        [
          block_badge,
          text("HTML block", width=88.0, height=34.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          text_field(
            self.html_block_text.get(),
            on_input=value => UpdateHtmlBlockText(value),
            on_submit=Some(ApplyHtmlBlockText),
            placeholder="<div>HTML</div>",
            variant=@views.TextFieldVariant::Outline,
            theme~,
            width=360.0,
            height=34.0,
          ).key("markdown-html-block-text"),
          editor_button(
            "Apply",
            ApplyHtmlBlockText,
            @views.ButtonVariant::Tonal,
            theme,
          ),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      )
    TableTools =>
      row(
        [
          block_badge,
          text("Table tools", width=92.0, height=34.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          editor_button(
            "+Row",
            ApplyCommand(InsertTableRow),
            @views.ButtonVariant::Tonal,
            theme,
          ),
          editor_button(
            "+Col",
            ApplyCommand(InsertTableColumn),
            @views.ButtonVariant::Tonal,
            theme,
          ),
          editor_button(
            "-Col",
            ApplyCommand(DeleteTableColumn),
            @views.ButtonVariant::Tonal,
            theme,
          ),
          editor_button(
            "-Row",
            ApplyCommand(DeleteTableRow),
            @views.ButtonVariant::Tonal,
            theme,
          ),
          editor_button(
            "Left",
            ApplyCommand(
              MarkdownEditorCommand::SetTableColumnAlignment(
                Some(@core.TextAlign::TextStart),
              ),
            ),
            @views.ButtonVariant::Tonal,
            theme,
          ),
          editor_button(
            "Center",
            ApplyCommand(
              MarkdownEditorCommand::SetTableColumnAlignment(
                Some(@core.TextAlign::TextCenter),
              ),
            ),
            @views.ButtonVariant::Tonal,
            theme,
          ),
          editor_button(
            "Right",
            ApplyCommand(
              MarkdownEditorCommand::SetTableColumnAlignment(
                Some(@core.TextAlign::TextEnd),
              ),
            ),
            @views.ButtonVariant::Tonal,
            theme,
          ),
          editor_button(
            "Auto",
            ApplyCommand(SetTableColumnAlignment(None)),
            @views.ButtonVariant::Tonal,
            theme,
          ),
        ],
        spacing=theme.spacing_scale.xs,
        align=@views.CrossAlign::Center,
      )
    PlainSelection => empty()
  }
}

///|
fn markdown_editor_command_active(
  source : String,
  selection : MarkdownEditorSelection,
  command : MarkdownEditorCommand,
) -> Bool {
  match command {
    Bold | Italic | Code | Strikethrough =>
      markdown_editor_inline_command_active(source, selection, command)
    Link => markdown_editor_link_context(source, selection) is Some(_)
    Image => markdown_editor_image_context(source, selection) is Some(_)
    Heading(level) =>
      markdown_editor_active_block_label(source, selection) ==
      "Heading " + level.to_string()
    BulletList =>
      markdown_editor_active_block_label(source, selection) == "Bullet list"
    TaskList =>
      markdown_editor_active_block_label(source, selection) == "Task list"
    OrderedList =>
      markdown_editor_active_block_label(source, selection) == "Ordered list"
    Quote => markdown_editor_active_block_label(source, selection) == "Quote"
    CodeBlock =>
      markdown_editor_active_block_label(source, selection) == "Code block"
    HorizontalRule =>
      markdown_editor_active_block_label(source, selection) == "Rule"
    Table => markdown_editor_active_block_label(source, selection) == "Table"
    _ => false
  }
}

///|
fn markdown_editor_active_format_suffix(
  source : String,
  selection : MarkdownEditorSelection,
) -> String {
  let labels : Array[String] = []
  if markdown_editor_command_active(source, selection, Bold) {
    labels.push("Bold")
  }
  if markdown_editor_command_active(source, selection, Italic) {
    labels.push("Italic")
  }
  if markdown_editor_command_active(source, selection, Code) {
    labels.push("Code")
  }
  if markdown_editor_command_active(source, selection, Strikethrough) {
    labels.push("Strike")
  }
  if markdown_editor_command_active(source, selection, Link) {
    labels.push("Link")
  }
  if markdown_editor_command_active(source, selection, Image) {
    labels.push("Image")
  }
  if labels.length() == 0 {
    ""
  } else {
    " / Active: " + labels.join(", ")
  }
}

///|
fn markdown_editor_inline_command_active(
  source : String,
  selection : MarkdownEditorSelection,
  command : MarkdownEditorCommand,
) -> Bool {
  let marker = markdown_editor_inline_marker(command)
  match markdown_editor_active_selection(selection.selection) {
    Some(range) =>
      markdown_editor_range_has_inline_marker(
        source,
        range.normalized(),
        marker,
      ) &&
      markdown_editor_inline_active_marker_supported(
        source,
        range.normalized(),
        marker,
      )
    None =>
      markdown_editor_inline_marker_pair_at_caret(
        source,
        selection.caret,
        marker,
      )
      is Some(range) &&
      markdown_editor_inline_active_marker_supported(source, range, marker)
  }
}

///|
fn markdown_editor_inline_active_marker_supported(
  source : String,
  range : @core.TextRange,
  marker : String,
) -> Bool {
  if marker != "*" {
    return true
  }
  let chars = source.to_array()
  let open = range.start - 1
  let close = range.end
  let doubled_open = open > 0 && chars[open - 1] == '*'
  let doubled_close = close + 1 < chars.length() && chars[close + 1] == '*'
  !doubled_open && !doubled_close
}

///|
fn floating_target_palette(
  editor : @core.View[MarkdownEditorMsg],
  target_bar : @core.View[MarkdownEditorMsg],
  snapshot : MarkdownEditorSnapshot,
  selection : MarkdownEditorSelection,
  target_kind : MarkdownEditorTargetKind,
  editor_font : @core.FontSpec,
  theme : @core.Theme,
  scroll_offset : @core.Point,
  width : Double,
  height : Double,
) -> @core.View[MarkdownEditorMsg] {
  let palette = if target_kind == PlainSelection {
    empty()
  } else {
    surface(
      target_bar,
      variant=@views.SurfaceVariant::Raised,
      theme~,
      padding=theme.spacing_scale.xs,
    )
  }
  @views.custom_children_layout(
    children=[editor, palette],
    measure=_ => @core.Size::new(width~, height~),
    place=ctx => {
      let palette_size = if ctx.child_sizes.length() > 1 {
        ctx.child_sizes[1]
      } else {
        @core.Size::new(width=0.0, height=0.0)
      }
      let editor_frame = @core.Rect::new(
        x=ctx.frame.origin.x,
        y=ctx.frame.origin.y,
        width=ctx.frame.size.width,
        height~,
      )
      let palette_width = markdown_editor_min_double(palette_size.width, width)
      let anchor = markdown_editor_palette_anchor(
        snapshot,
        selection,
        target_kind,
        editor_frame,
        editor_font,
        palette_width,
        palette_size.height,
        scroll_offset,
        theme,
      )
      let palette_x = ctx.frame.origin.x +
        markdown_editor_max_double(
          0.0,
          markdown_editor_min_double(
            ctx.frame.size.width - palette_width,
            anchor.x - ctx.frame.origin.x,
          ),
        )
      let palette_y = ctx.frame.origin.y +
        markdown_editor_max_double(
          0.0,
          markdown_editor_min_double(
            ctx.frame.size.height - palette_size.height,
            anchor.y - ctx.frame.origin.y,
          ),
        )
      [
        editor_frame,
        @core.Rect::new(
          x=palette_x,
          y=palette_y,
          width=palette_width,
          height=palette_size.height,
        ),
      ]
    },
    semantics_label="Markdown editor floating target palette",
  )
}

///|
fn markdown_editor_palette_anchor(
  snapshot : MarkdownEditorSnapshot,
  selection : MarkdownEditorSelection,
  target_kind : MarkdownEditorTargetKind,
  editor_frame : @core.Rect,
  editor_font : @core.FontSpec,
  palette_width : Double,
  palette_height : Double,
  scroll_offset : @core.Point,
  theme : @core.Theme,
) -> @core.Point {
  if target_kind == PlainSelection {
    return @core.Point::new(
      x=editor_frame.origin.x + (editor_frame.size.width - palette_width) / 2.0,
      y=editor_frame.origin.y +
        markdown_editor_max_double(
          0.0,
          editor_frame.size.height - palette_height - theme.spacing_scale.sm,
        ),
    )
  }
  let caret = match selection.selection {
    Some(range) => range.normalized().start
    None => selection.caret
  }
  let content = @core.rich_text_editor_content_rect(editor_frame).offset(
    dx=0.0,
    dy=-scroll_offset.y,
  )
  match
    @core.rich_text_document_caret_rect_at_source(
      snapshot.rich_text,
      caret,
      content,
      editor_font,
    ) {
    Some(rect) => {
      let x = rect.origin.x + rect.size.width / 2.0 - palette_width / 2.0
      let preferred_above = rect.origin.y -
        palette_height -
        theme.spacing_scale.sm
      let y = if preferred_above >= editor_frame.origin.y {
        preferred_above
      } else if target_kind == TableTools {
        editor_frame.origin.y +
        markdown_editor_max_double(
          0.0,
          editor_frame.size.height - palette_height - theme.spacing_scale.sm,
        )
      } else {
        rect.origin.y + rect.size.height + theme.spacing_scale.sm
      }
      @core.Point::new(x~, y~)
    }
    None =>
      @core.Point::new(
        x=editor_frame.origin.x +
          (editor_frame.size.width - palette_width) / 2.0,
        y=editor_frame.origin.y +
          markdown_editor_max_double(
            0.0,
            editor_frame.size.height - palette_height - theme.spacing_scale.sm,
          ),
      )
  }
}

///|
fn editor_button(
  label : String,
  message : MarkdownEditorMsg,
  variant : @views.ButtonVariant,
  theme : @core.Theme,
) -> @core.View[MarkdownEditorMsg] {
  let width = if markdown_editor_text_length(label) > 5 { 78.0 } else { 64.0 }
  button(label, on_click=message, variant~, theme~, width~, height=34.0)
}

///|
fn editor_chrome_button(
  label : String,
  message : MarkdownEditorMsg,
  theme : @core.Theme,
) -> @core.View[MarkdownEditorMsg] {
  let width = if label == "Src" || label == "Nav" {
    42.0
  } else if label == "Save As" {
    76.0
  } else if label == "Open" {
    54.0
  } else if label == "Import" || label == "Export" {
    66.0
  } else if label == "New" {
    48.0
  } else if label == "Save" {
    52.0
  } else {
    54.0
  }
  button(
    label,
    on_click=message,
    variant=@views.ButtonVariant::Ghost,
    theme~,
    width~,
    height=30.0,
  )
}

///|
fn markdown_editor_page_width() -> Double {
  780.0
}

///|
fn markdown_editor_primary_editor_width(
  show_source : Bool,
  show_outline : Bool,
) -> Double {
  if show_source || show_outline {
    markdown_editor_source_editor_width()
  } else {
    markdown_editor_page_width()
  }
}

///|
fn markdown_editor_source_editor_width() -> Double {
  640.0
}

///|
fn markdown_editor_outline_inspector_width() -> Double {
  240.0
}

///|
fn markdown_editor_outline_content_width() -> Double {
  212.0
}

///|
fn markdown_editor_source_inspector_width() -> Double {
  292.0
}

///|
fn markdown_editor_viewport_height() -> Double {
  520.0
}

///|
fn markdown_editor_window_background() -> @core.Color {
  @core.Color::rgba(r=0.992, g=0.992, b=0.99)
}

///|
fn markdown_editor_page_shadow() -> @core.ShadowStyle {
  @core.ShadowStyle::new(
    color=@core.Color::black().multiply_alpha(0.12),
    offset=@core.Point::new(x=0.0, y=2.0),
    blur_radius=18.0,
  )
}

///|
fn markdown_editor_min_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn markdown_editor_max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn markdown_editor_clamp_double(
  value : Double,
  min : Double,
  max : Double,
) -> Double {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
fn markdown_editor_shortcut(key : String) -> @core.KeyboardShortcut {
  @core.KeyboardShortcut::new(
    key~,
    modifiers=@core.KeyModifiers::new(meta=true),
  )
}

///|
fn markdown_editor_plain_shortcut(key : String) -> @core.KeyboardShortcut {
  @core.KeyboardShortcut::new(key~)
}

///|
fn markdown_editor_plain_shift_shortcut(key : String) -> @core.KeyboardShortcut {
  @core.KeyboardShortcut::new(
    key~,
    modifiers=@core.KeyModifiers::new(shift=true),
  )
}

///|
fn markdown_editor_shift_shortcut(key : String) -> @core.KeyboardShortcut {
  @core.KeyboardShortcut::new(
    key~,
    modifiers=@core.KeyModifiers::new(meta=true, shift=true),
  )
}

///|
fn markdown_editor_control_shortcut(key : String) -> @core.KeyboardShortcut {
  @core.KeyboardShortcut::new(
    key~,
    modifiers=@core.KeyModifiers::new(control=true),
  )
}

///|
fn markdown_editor_control_shift_shortcut(
  key : String,
) -> @core.KeyboardShortcut {
  @core.KeyboardShortcut::new(
    key~,
    modifiers=@core.KeyModifiers::new(control=true, shift=true),
  )
}

///|
fn markdown_editor_alt_shortcut(key : String) -> @core.KeyboardShortcut {
  @core.KeyboardShortcut::new(key~, modifiers=@core.KeyModifiers::new(alt=true))
}

///|
fn markdown_editor_meta_alt_shortcut(key : String) -> @core.KeyboardShortcut {
  @core.KeyboardShortcut::new(
    key~,
    modifiers=@core.KeyModifiers::new(meta=true, alt=true),
  )
}

///|
fn markdown_editor_control_alt_shortcut(key : String) -> @core.KeyboardShortcut {
  @core.KeyboardShortcut::new(
    key~,
    modifiers=@core.KeyModifiers::new(control=true, alt=true),
  )
}

///|
fn markdown_editor_command_binding(
  label : String,
  shortcut : @core.KeyboardShortcut,
  action : () -> Unit,
) -> @core.CommandBinding {
  @core.CommandBinding::new(
    command=@core.ActionCommand::new(
      intent=@core.CommandIntent::Activate,
      label~,
      shortcut=Some(shortcut),
    ),
    handle=action,
  )
}

///|
fn MarkdownEditorApp::action_commands(
  self : MarkdownEditorApp,
  services? : @host.HostAppServices = @host.HostAppServices::unavailable(),
) -> @core.ActionCommandMap {
  @core.ActionCommandMap::new(bindings=[
    markdown_editor_command_binding(
      "New Document",
      markdown_editor_shortcut("n"),
      () => ignore(self.update(NewDocument)),
    ),
    markdown_editor_command_binding(
      "New Document",
      markdown_editor_control_shortcut("n"),
      () => ignore(self.update(NewDocument)),
    ),
    markdown_editor_command_binding(
      "Open Document",
      markdown_editor_shortcut("o"),
      () => self.perform_file_open(services),
    ),
    markdown_editor_command_binding(
      "Open Document",
      markdown_editor_control_shortcut("o"),
      () => self.perform_file_open(services),
    ),
    markdown_editor_command_binding("Save", markdown_editor_shortcut("s"), () => {
      self.perform_document_save(services)
    }),
    markdown_editor_command_binding(
      "Save",
      markdown_editor_control_shortcut("s"),
      () => self.perform_document_save(services),
    ),
    markdown_editor_command_binding(
      "Save As",
      markdown_editor_shift_shortcut("s"),
      () => self.perform_file_save_as(services),
    ),
    markdown_editor_command_binding(
      "Save As",
      markdown_editor_control_shift_shortcut("s"),
      () => self.perform_file_save_as(services),
    ),
    markdown_editor_command_binding(
      "Import Markdown from Clipboard",
      markdown_editor_meta_alt_shortcut("i"),
      () => self.perform_clipboard_import(services),
    ),
    markdown_editor_command_binding(
      "Import Markdown from Clipboard",
      markdown_editor_control_alt_shortcut("i"),
      () => self.perform_clipboard_import(services),
    ),
    markdown_editor_command_binding(
      "Export Markdown",
      markdown_editor_meta_alt_shortcut("s"),
      () => self.perform_clipboard_export(services),
    ),
    markdown_editor_command_binding(
      "Export Markdown",
      markdown_editor_control_alt_shortcut("s"),
      () => self.perform_clipboard_export(services),
    ),
    markdown_editor_command_binding("Find", markdown_editor_shortcut("f"), () => {
      ignore(self.update(OpenFind))
    }),
    markdown_editor_command_binding(
      "Find",
      markdown_editor_control_shortcut("f"),
      () => ignore(self.update(OpenFind)),
    ),
    markdown_editor_command_binding(
      "Find/Replace",
      markdown_editor_meta_alt_shortcut("f"),
      () => ignore(self.update(OpenFindReplace)),
    ),
    markdown_editor_command_binding(
      "Find/Replace",
      markdown_editor_control_shortcut("h"),
      () => ignore(self.update(OpenFindReplace)),
    ),
    markdown_editor_command_binding(
      "Find Next",
      markdown_editor_shortcut("g"),
      () => ignore(self.update(FindNext)),
    ),
    markdown_editor_command_binding(
      "Find Next",
      markdown_editor_control_shortcut("g"),
      () => ignore(self.update(FindNext)),
    ),
    markdown_editor_command_binding(
      "Find Previous",
      markdown_editor_shift_shortcut("g"),
      () => ignore(self.update(FindPrevious)),
    ),
    markdown_editor_command_binding(
      "Find Previous",
      markdown_editor_control_shift_shortcut("g"),
      () => ignore(self.update(FindPrevious)),
    ),
    markdown_editor_command_binding(
      "Dismiss Panels",
      markdown_editor_plain_shortcut("Escape"),
      () => ignore(self.update(DismissAuxiliaryPanels)),
    ),
    markdown_editor_command_binding(
      "Toggle Source Preview",
      markdown_editor_shortcut("/"),
      () => ignore(self.update(ToggleSourcePreview)),
    ),
    markdown_editor_command_binding(
      "Toggle Source Preview",
      markdown_editor_control_shortcut("/"),
      () => ignore(self.update(ToggleSourcePreview)),
    ),
    markdown_editor_command_binding(
      "Indent Lines",
      markdown_editor_shortcut("]"),
      () => ignore(self.update(IndentLines)),
    ),
    markdown_editor_command_binding(
      "Indent Lines",
      markdown_editor_control_shortcut("]"),
      () => ignore(self.update(IndentLines)),
    ),
    markdown_editor_command_binding(
      "Outdent Lines",
      markdown_editor_shortcut("["),
      () => ignore(self.update(OutdentLines)),
    ),
    markdown_editor_command_binding(
      "Outdent Lines",
      markdown_editor_control_shortcut("["),
      () => ignore(self.update(OutdentLines)),
    ),
    markdown_editor_command_binding(
      "Toggle Outline",
      markdown_editor_meta_alt_shortcut("o"),
      () => ignore(self.update(ToggleOutline)),
    ),
    markdown_editor_command_binding(
      "Toggle Outline",
      markdown_editor_control_alt_shortcut("o"),
      () => ignore(self.update(ToggleOutline)),
    ),
    markdown_editor_command_binding(
      "Next Heading",
      markdown_editor_meta_alt_shortcut("ArrowDown"),
      () => ignore(self.update(JumpToNextHeading)),
    ),
    markdown_editor_command_binding(
      "Next Heading",
      markdown_editor_control_alt_shortcut("ArrowDown"),
      () => ignore(self.update(JumpToNextHeading)),
    ),
    markdown_editor_command_binding(
      "Previous Heading",
      markdown_editor_meta_alt_shortcut("ArrowUp"),
      () => ignore(self.update(JumpToPreviousHeading)),
    ),
    markdown_editor_command_binding(
      "Previous Heading",
      markdown_editor_control_alt_shortcut("ArrowUp"),
      () => ignore(self.update(JumpToPreviousHeading)),
    ),
    markdown_editor_command_binding(
      "Open Target",
      markdown_editor_shift_shortcut("o"),
      () => self.perform_open_target(services),
    ),
    markdown_editor_command_binding(
      "Open Target",
      markdown_editor_control_shift_shortcut("o"),
      () => self.perform_open_target(services),
    ),
    markdown_editor_command_binding("Bold", markdown_editor_shortcut("b"), () => {
      ignore(self.update(ApplyCommand(Bold)))
    }),
    markdown_editor_command_binding(
      "Bold",
      markdown_editor_control_shortcut("b"),
      () => ignore(self.update(ApplyCommand(Bold))),
    ),
    markdown_editor_command_binding("Italic", markdown_editor_shortcut("i"), () => {
      ignore(self.update(ApplyCommand(Italic)))
    }),
    markdown_editor_command_binding(
      "Italic",
      markdown_editor_control_shortcut("i"),
      () => ignore(self.update(ApplyCommand(Italic))),
    ),
    markdown_editor_command_binding(
      "Inline Code",
      markdown_editor_shortcut("e"),
      () => ignore(self.update(ApplyCommand(Code))),
    ),
    markdown_editor_command_binding(
      "Inline Code",
      markdown_editor_control_shortcut("e"),
      () => ignore(self.update(ApplyCommand(Code))),
    ),
    markdown_editor_command_binding(
      "Strikethrough",
      markdown_editor_shift_shortcut("x"),
      () => ignore(self.update(ApplyCommand(Strikethrough))),
    ),
    markdown_editor_command_binding(
      "Strikethrough",
      markdown_editor_control_shift_shortcut("x"),
      () => ignore(self.update(ApplyCommand(Strikethrough))),
    ),
    markdown_editor_command_binding("Link", markdown_editor_shortcut("l"), () => {
      ignore(self.update(ApplyCommand(Link)))
    }),
    markdown_editor_command_binding(
      "Link",
      markdown_editor_control_shortcut("k"),
      () => ignore(self.update(ApplyCommand(Link))),
    ),
    markdown_editor_command_binding(
      "Image",
      markdown_editor_shift_shortcut("i"),
      () => ignore(self.update(ApplyCommand(Image))),
    ),
    markdown_editor_command_binding(
      "Image",
      markdown_editor_control_shift_shortcut("i"),
      () => ignore(self.update(ApplyCommand(Image))),
    ),
    markdown_editor_command_binding(
      "Paragraph",
      markdown_editor_shortcut("0"),
      () => ignore(self.update(ApplyCommand(Paragraph))),
    ),
    markdown_editor_command_binding(
      "Paragraph",
      markdown_editor_control_shortcut("0"),
      () => ignore(self.update(ApplyCommand(Paragraph))),
    ),
    markdown_editor_command_binding(
      "Heading 1",
      markdown_editor_shortcut("1"),
      () => ignore(self.update(ApplyCommand(Heading(1)))),
    ),
    markdown_editor_command_binding(
      "Heading 1",
      markdown_editor_control_shortcut("1"),
      () => ignore(self.update(ApplyCommand(Heading(1)))),
    ),
    markdown_editor_command_binding(
      "Heading 2",
      markdown_editor_shortcut("2"),
      () => ignore(self.update(ApplyCommand(Heading(2)))),
    ),
    markdown_editor_command_binding(
      "Heading 2",
      markdown_editor_control_shortcut("2"),
      () => ignore(self.update(ApplyCommand(Heading(2)))),
    ),
    markdown_editor_command_binding(
      "Heading 3",
      markdown_editor_shortcut("3"),
      () => ignore(self.update(ApplyCommand(Heading(3)))),
    ),
    markdown_editor_command_binding(
      "Heading 3",
      markdown_editor_control_shortcut("3"),
      () => ignore(self.update(ApplyCommand(Heading(3)))),
    ),
    markdown_editor_command_binding(
      "Heading 4",
      markdown_editor_shortcut("4"),
      () => ignore(self.update(ApplyCommand(Heading(4)))),
    ),
    markdown_editor_command_binding(
      "Heading 4",
      markdown_editor_control_shortcut("4"),
      () => ignore(self.update(ApplyCommand(Heading(4)))),
    ),
    markdown_editor_command_binding(
      "Heading 5",
      markdown_editor_shortcut("5"),
      () => ignore(self.update(ApplyCommand(Heading(5)))),
    ),
    markdown_editor_command_binding(
      "Heading 5",
      markdown_editor_control_shortcut("5"),
      () => ignore(self.update(ApplyCommand(Heading(5)))),
    ),
    markdown_editor_command_binding(
      "Heading 6",
      markdown_editor_shortcut("6"),
      () => ignore(self.update(ApplyCommand(Heading(6)))),
    ),
    markdown_editor_command_binding(
      "Heading 6",
      markdown_editor_control_shortcut("6"),
      () => ignore(self.update(ApplyCommand(Heading(6)))),
    ),
    markdown_editor_command_binding(
      "Bullet List",
      markdown_editor_shortcut("u"),
      () => ignore(self.update(ApplyCommand(BulletList))),
    ),
    markdown_editor_command_binding(
      "Bullet List",
      markdown_editor_control_shift_shortcut("8"),
      () => ignore(self.update(ApplyCommand(BulletList))),
    ),
    markdown_editor_command_binding(
      "Bullet List",
      markdown_editor_control_shift_shortcut("*"),
      () => ignore(self.update(ApplyCommand(BulletList))),
    ),
    markdown_editor_command_binding(
      "Task List",
      markdown_editor_shortcut("t"),
      () => ignore(self.update(ApplyCommand(TaskList))),
    ),
    markdown_editor_command_binding(
      "Toggle Task",
      markdown_editor_shortcut("Enter"),
      () => ignore(self.update(ToggleCurrentTask)),
    ),
    markdown_editor_command_binding(
      "Toggle Task",
      markdown_editor_control_shortcut("Enter"),
      () => ignore(self.update(ToggleCurrentTask)),
    ),
    markdown_editor_command_binding(
      "Hard Line Break",
      markdown_editor_plain_shift_shortcut("Enter"),
      () => ignore(self.update(InsertHardBreak)),
    ),
    markdown_editor_command_binding(
      "Ordered List",
      markdown_editor_shortcut("o"),
      () => ignore(self.update(ApplyCommand(OrderedList))),
    ),
    markdown_editor_command_binding(
      "Ordered List",
      markdown_editor_control_shift_shortcut("7"),
      () => ignore(self.update(ApplyCommand(OrderedList))),
    ),
    markdown_editor_command_binding(
      "Ordered List",
      markdown_editor_control_shift_shortcut("&"),
      () => ignore(self.update(ApplyCommand(OrderedList))),
    ),
    markdown_editor_command_binding("Quote", markdown_editor_shortcut("q"), () => {
      ignore(self.update(ApplyCommand(Quote)))
    }),
    markdown_editor_command_binding(
      "Quote",
      markdown_editor_control_shift_shortcut("9"),
      () => ignore(self.update(ApplyCommand(Quote))),
    ),
    markdown_editor_command_binding(
      "Quote",
      markdown_editor_control_shift_shortcut("("),
      () => ignore(self.update(ApplyCommand(Quote))),
    ),
    markdown_editor_command_binding(
      "Code Block",
      markdown_editor_shortcut("k"),
      () => ignore(self.update(ApplyCommand(CodeBlock))),
    ),
    markdown_editor_command_binding(
      "Code Block",
      markdown_editor_control_shift_shortcut("k"),
      () => ignore(self.update(ApplyCommand(CodeBlock))),
    ),
    markdown_editor_command_binding(
      "Duplicate Block",
      markdown_editor_shift_shortcut("d"),
      () => ignore(self.update(ApplyCommand(DuplicateBlock))),
    ),
    markdown_editor_command_binding(
      "Duplicate Block",
      markdown_editor_control_shift_shortcut("d"),
      () => ignore(self.update(ApplyCommand(DuplicateBlock))),
    ),
    markdown_editor_command_binding(
      "Move Block Up",
      markdown_editor_alt_shortcut("ArrowUp"),
      () => ignore(self.update(ApplyCommand(MoveBlockUp))),
    ),
    markdown_editor_command_binding(
      "Move Block Down",
      markdown_editor_alt_shortcut("ArrowDown"),
      () => ignore(self.update(ApplyCommand(MoveBlockDown))),
    ),
    markdown_editor_command_binding(
      "Insert Table Column",
      markdown_editor_shift_shortcut("="),
      () => ignore(self.update(ApplyCommand(InsertTableColumn))),
    ),
    markdown_editor_command_binding(
      "Insert Table Column",
      markdown_editor_shift_shortcut("+"),
      () => ignore(self.update(ApplyCommand(InsertTableColumn))),
    ),
    markdown_editor_command_binding(
      "Insert Table Column",
      markdown_editor_control_shift_shortcut("="),
      () => ignore(self.update(ApplyCommand(InsertTableColumn))),
    ),
    markdown_editor_command_binding(
      "Insert Table Column",
      markdown_editor_control_shift_shortcut("+"),
      () => ignore(self.update(ApplyCommand(InsertTableColumn))),
    ),
    markdown_editor_command_binding(
      "Insert Table Row",
      markdown_editor_shift_shortcut("Enter"),
      () => ignore(self.update(ApplyCommand(InsertTableRow))),
    ),
    markdown_editor_command_binding(
      "Insert Table Row",
      markdown_editor_control_shift_shortcut("Enter"),
      () => ignore(self.update(ApplyCommand(InsertTableRow))),
    ),
    markdown_editor_command_binding(
      "Delete Table Row",
      markdown_editor_shift_shortcut("-"),
      () => ignore(self.update(ApplyCommand(DeleteTableRow))),
    ),
    markdown_editor_command_binding(
      "Delete Table Row",
      markdown_editor_control_shift_shortcut("-"),
      () => ignore(self.update(ApplyCommand(DeleteTableRow))),
    ),
    markdown_editor_command_binding(
      "Delete Table Column",
      markdown_editor_shift_shortcut("_"),
      () => ignore(self.update(ApplyCommand(DeleteTableColumn))),
    ),
    markdown_editor_command_binding(
      "Delete Table Column",
      markdown_editor_control_shift_shortcut("_"),
      () => ignore(self.update(ApplyCommand(DeleteTableColumn))),
    ),
    markdown_editor_command_binding(
      "Table Align Left",
      markdown_editor_shift_shortcut("l"),
      () => {
        ignore(
          self.update(
            ApplyCommand(
              SetTableColumnAlignment(Some(@core.TextAlign::TextStart)),
            ),
          ),
        )
      },
    ),
    markdown_editor_command_binding(
      "Table Align Left",
      markdown_editor_control_shift_shortcut("l"),
      () => {
        ignore(
          self.update(
            ApplyCommand(
              SetTableColumnAlignment(Some(@core.TextAlign::TextStart)),
            ),
          ),
        )
      },
    ),
    markdown_editor_command_binding(
      "Table Align Center",
      markdown_editor_shift_shortcut("e"),
      () => {
        ignore(
          self.update(
            ApplyCommand(
              SetTableColumnAlignment(Some(@core.TextAlign::TextCenter)),
            ),
          ),
        )
      },
    ),
    markdown_editor_command_binding(
      "Table Align Center",
      markdown_editor_control_shift_shortcut("e"),
      () => {
        ignore(
          self.update(
            ApplyCommand(
              SetTableColumnAlignment(Some(@core.TextAlign::TextCenter)),
            ),
          ),
        )
      },
    ),
    markdown_editor_command_binding(
      "Table Align Right",
      markdown_editor_shift_shortcut("r"),
      () => {
        ignore(
          self.update(
            ApplyCommand(
              SetTableColumnAlignment(Some(@core.TextAlign::TextEnd)),
            ),
          ),
        )
      },
    ),
    markdown_editor_command_binding(
      "Table Align Right",
      markdown_editor_control_shift_shortcut("r"),
      () => {
        ignore(
          self.update(
            ApplyCommand(
              SetTableColumnAlignment(Some(@core.TextAlign::TextEnd)),
            ),
          ),
        )
      },
    ),
    markdown_editor_command_binding(
      "Table Align Auto",
      markdown_editor_shift_shortcut("0"),
      () => ignore(self.update(ApplyCommand(SetTableColumnAlignment(None)))),
    ),
    markdown_editor_command_binding(
      "Table Align Auto",
      markdown_editor_control_shift_shortcut("0"),
      () => ignore(self.update(ApplyCommand(SetTableColumnAlignment(None)))),
    ),
  ])
}

///|
fn markdown_editor_reading_label(snapshot : MarkdownEditorSnapshot) -> String {
  let minutes = if snapshot.reading_minutes == 0 {
    "less than 1 min"
  } else if snapshot.reading_minutes == 1 {
    "1 min"
  } else {
    snapshot.reading_minutes.to_string() + " min"
  }
  "\{snapshot.word_count} words / \{snapshot.line_count} lines / " + minutes
}

///|
fn source_preview(
  text : String,
  theme : @core.Theme,
  height~ : Double,
) -> @core.View[MarkdownEditorMsg] {
  scroll_view(source_preview_lines(text, theme), width=260.0, height~)
}

///|
fn source_inspector(
  source : String,
  theme : @core.Theme,
  height~ : Double,
) -> @core.View[MarkdownEditorMsg] {
  surface(
    padding_edges(
      column(
        [
          text("Markdown source", width=260.0, height=24.0)
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          source_preview(
            source,
            theme,
            height=markdown_editor_max_double(0.0, height - 52.0),
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Start,
      ),
      top=theme.spacing_scale.md,
      right=theme.spacing_scale.sm,
      bottom=theme.spacing_scale.md,
      left=theme.spacing_scale.sm,
    ),
    width=markdown_editor_source_inspector_width(),
    height~,
    variant=@views.SurfaceVariant::Base,
    theme~,
    background=@core.Color::rgba(r=0.975, g=0.975, b=0.972),
    corner_radius=theme.radius_scale.sm,
    padding=0.0,
  )
}

///|
fn outline_inspector(
  snapshot : MarkdownEditorSnapshot,
  selection : MarkdownEditorSelection,
  theme : @core.Theme,
  height~ : Double,
) -> @core.View[MarkdownEditorMsg] {
  let active_index = markdown_editor_active_outline_index(
    snapshot.outline,
    selection.caret,
  )
  let content = if snapshot.outline.length() == 0 {
    text(
      "No headings",
      width=markdown_editor_outline_content_width(),
      height=28.0,
    )
    .font(theme.typography.caption)
    .foreground(theme.palette.muted)
  } else {
    scroll_view(
      outline_rows(snapshot.outline, active_index, theme),
      width=markdown_editor_outline_content_width(),
      height=markdown_editor_max_double(0.0, height - 52.0),
    )
  }
  surface(
    padding_edges(
      column(
        [
          text(
            "Outline",
            width=markdown_editor_outline_content_width(),
            height=24.0,
          )
          .font(theme.typography.caption)
          .foreground(theme.palette.muted),
          content,
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Start,
      ),
      top=theme.spacing_scale.md,
      right=theme.spacing_scale.sm,
      bottom=theme.spacing_scale.md,
      left=theme.spacing_scale.sm,
    ),
    width=markdown_editor_outline_inspector_width(),
    height~,
    variant=@views.SurfaceVariant::Base,
    theme~,
    background=@core.Color::rgba(r=0.975, g=0.975, b=0.972),
    corner_radius=theme.radius_scale.sm,
    padding=0.0,
  )
}

///|
fn outline_rows(
  outline : Array[MarkdownEditorOutlineItem],
  active_index : Int,
  theme : @core.Theme,
) -> @core.View[MarkdownEditorMsg] {
  let rows : Array[@core.View[MarkdownEditorMsg]] = []
  for index in 0..<outline.length() {
    rows.push(outline_row(outline[index], active=index == active_index, theme))
  }
  column(rows, spacing=theme.spacing_scale.xs, align=@views.CrossAlign::Start)
}

///|
fn outline_row(
  item : MarkdownEditorOutlineItem,
  active~ : Bool,
  theme : @core.Theme,
) -> @core.View[MarkdownEditorMsg] {
  let indent = markdown_editor_outline_indent_width(item.level)
  padding_edges(
    button(
      markdown_editor_outline_label(item),
      on_click=JumpToOutline(item.source_start),
      variant=if active {
        @views.ButtonVariant::Tonal
      } else {
        @views.ButtonVariant::Ghost
      },
      theme~,
      width=markdown_editor_max_double(
        96.0,
        markdown_editor_outline_content_width() - indent,
      ),
      height=30.0,
    ),
    left=indent,
  )
}

///|
fn markdown_editor_outline_indent_width(level : Int) -> Double {
  markdown_editor_max_int(0, level - 1).to_double() * 12.0
}

///|
fn markdown_editor_outline_label(item : MarkdownEditorOutlineItem) -> String {
  let title = if item.title == "" { "Untitled" } else { item.title }
  "H" + item.level.to_string() + " " + markdown_editor_outline_title(title)
}

///|
fn markdown_editor_outline_title(title : String) -> String {
  if markdown_editor_text_length(title) <= 24 {
    title
  } else {
    markdown_editor_substring(title, 0, 21) + "..."
  }
}

///|
fn markdown_editor_active_outline_index(
  outline : Array[MarkdownEditorOutlineItem],
  caret : Int,
) -> Int {
  let mut active = -1
  for index in 0..<outline.length() {
    if outline[index].source_start <= caret {
      active = index
    }
  }
  active
}

///|
fn editor_source_layout(
  _app : MarkdownEditorApp,
  source : String,
  snapshot : MarkdownEditorSnapshot,
  editor_font : @core.FontSpec,
  theme : @core.Theme,
  show_source : Bool,
  show_outline : Bool,
  target_bar : @core.View[MarkdownEditorMsg],
  selection : MarkdownEditorSelection,
  target_kind : MarkdownEditorTargetKind,
  scroll_offset : @core.Point,
  on_selection_change : (Int, @core.TextRange?) -> MarkdownEditorMsg,
  on_prefix_click : (Int) -> MarkdownEditorMsg,
) -> @core.View[MarkdownEditorMsg] {
  let editor_width = markdown_editor_primary_editor_width(
    show_source, show_outline,
  )
  let viewport_height = markdown_editor_viewport_height()
  let content_height = markdown_editor_max_double(
    viewport_height,
    @core.rich_text_document_height(snapshot.rich_text, editor_font) + 96.0,
  )
  let max_scroll = markdown_editor_max_double(
    0.0,
    content_height - viewport_height,
  )
  let normalized_offset = @core.Point::new(
    x=0.0,
    y=markdown_editor_clamp_double(scroll_offset.y, 0.0, max_scroll),
  )
  let editor_control = @core.View::controlled_rich_text_editor(
    value=source,
    on_input=value => UpdateDocument(value),
    placeholder="Start writing Markdown",
    size=@core.Size::new(width=editor_width, height=content_height),
    format=source => markdown_editor_format_for_selection(source, selection),
    font=editor_font,
    foreground=@core.Color::rgba(r=0.12, g=0.12, b=0.12),
    placeholder_color=@core.Color::black().multiply_alpha(0.35),
    background=@core.Brush::solid(@core.Color::white()),
    border=None,
    focused_border=None,
    cursor_color=theme.palette.primary,
    corner_radius=theme.radius_scale.sm,
    on_selection_change=Some(on_selection_change),
    on_prefix_click=Some(on_prefix_click),
    input_transform=Some(markdown_editor_transform_input),
    accepts_tab_input=true,
  ).key("markdown-editor")
  let editor = scroll_view(
    editor_page(editor_control, theme),
    offset=normalized_offset,
    width=editor_width,
    height=viewport_height,
    on_scroll=Some(delta => {
      EditorScrollTo(
        markdown_editor_clamp_double(
          normalized_offset.y - delta.y,
          0.0,
          max_scroll,
        ),
      )
    }),
  )
  let editor_view = if !show_source {
    floating_target_palette(
      editor, target_bar, snapshot, selection, target_kind, editor_font, theme, normalized_offset,
      editor_width, viewport_height,
    )
  } else {
    editor
  }
  if !show_source && !show_outline {
    editor_view
  } else {
    let side_children : Array[@core.View[MarkdownEditorMsg]] = [editor_view]
    if show_outline {
      side_children.push(
        outline_inspector(snapshot, selection, theme, height=viewport_height),
      )
    }
    if show_source {
      side_children.push(
        source_inspector(snapshot.source, theme, height=viewport_height),
      )
    }
    let editor_and_sidebars = row(
      side_children,
      spacing=theme.spacing_scale.lg,
      align=@views.CrossAlign::Start,
    )
    column(
      if target_kind == PlainSelection || !show_source {
        [editor_and_sidebars]
      } else {
        [editor_and_sidebars, target_bar]
      },
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Start,
    )
  }
}

///|
fn editor_page(
  editor : @core.View[MarkdownEditorMsg],
  theme : @core.Theme,
) -> @core.View[MarkdownEditorMsg] {
  editor
  .shadow(markdown_editor_page_shadow())
  .border(
    @core.BorderStyle::new(
      brush=@core.Brush::solid(@core.Color::black().multiply_alpha(0.10)),
      width=1.0,
    ),
  )
  .corner_radius(theme.radius_scale.sm)
}

///|
fn source_preview_lines(
  text : String,
  theme : @core.Theme,
) -> @core.View[MarkdownEditorMsg] {
  let font = @core.FontSpec::new(
    families=@core.FontFamilyStack::named("SFMono-Regular")
      .with_fallback(@core.FontFamily::UiMonospace)
      .with_fallback(@core.FontFamily::Monospace),
    size=12.0,
    weight=400,
  )
  let children : Array[@core.View[MarkdownEditorMsg]] = []
  for line in markdown_split_lines(markdown_editor_preview_text(text)) {
    children.push(source_preview_line(line, font, theme.palette.foreground))
  }
  column(children, spacing=0.0, align=@views.CrossAlign::Start)
}

///|
fn source_preview_line(
  line : String,
  font : @core.FontSpec,
  color : @core.Color,
) -> @core.View[MarkdownEditorMsg] {
  @views.custom_layout(
    measure=_ => @core.Size::new(width=260.0, height=18.0),
    paint=bounds => {
      [
        @core.DrawCommand::DrawText(
          @core.TextRun::new(
            text=line,
            frame=bounds,
            font~,
            color~,
            align=@core.TextAlign::TextStart,
          ),
        ),
      ]
    },
    semantics_label=line,
  )
}

///|
pub fn MarkdownEditorApp::runtime(
  self : MarkdownEditorApp,
  width? : Double = 1120.0,
  height? : Double = 720.0,
) -> @core.AppRuntime {
  self.runtime_with_services(
    @host.HostAppServices::unavailable(),
    width~,
    height~,
  )
}

///|
pub fn MarkdownEditorApp::runtime_with_services(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
  width? : Double = 1120.0,
  height? : Double = 720.0,
) -> @core.AppRuntime {
  let runtime = @core.AppRuntime::new_program(
    program=@core.Program::new(
      init=() => (self, @core.Effect::none()),
      update=(app, message) => app.update_with_services(message, services),
      view=app => @core.View::component(ctx => app.reactive_root(ctx)),
      subscriptions=app => app.subscriptions(services),
    ),
    size=@core.Size::new(width~, height~),
  )
  runtime.set_action_commands(self.action_commands(services~))
  runtime
}

///|
fn sample_markdown() -> String {
  "# Editor notes\n\nThis **WYSIWYG** surface keeps `Markdown` as the saved value.\n\n## Today\n- Type into the formatted page\n- Use shortcuts or contextual controls\n- Open source only when needed\n\n> Unsupported syntax stays editable as plain text.\n\n```\nlet saved = markdown\n```\n\n---"
}

///|
fn clamp_example_int(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}
