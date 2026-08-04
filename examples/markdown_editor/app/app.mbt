///|
using @views {
  button,
  clearable_text_field,
  column,
  container,
  custom_layout,
  empty,
  frame,
  padding_edges,
  row,
  scroll_view,
  spacer,
  text,
  text_field,
  tooltip,
}

///|
using @moui_richtext {
  type MarkdownDocumentSession,
  type MarkdownEditReason,
  type MarkdownEditTransaction,
  controlled_markdown_session_editor,
}

///|
pub struct MarkdownEditorApp {
  document : @state.State[String]
  document_session : @state.State[MarkdownDocumentSession]
  selection : @state.State[MarkdownEditorSelection]
  link_target : @state.State[String]
  image_target : @state.State[String]
  footnote_text : @state.State[String]
  html_block_text : @state.State[String]
  target_kind : @state.State[MarkdownEditorTargetKind]
  block_label : @state.State[String]
  source_preview_visible : @state.State[Bool]
  source_mode_enabled : @state.State[Bool]
  outline_visible : @state.State[Bool]
  file_sidebar_visible : @state.State[Bool]
  document_info_visible : @state.State[Bool]
  focus_mode_enabled : @state.State[Bool]
  typewriter_mode_enabled : @state.State[Bool]
  zen_mode_enabled : @state.State[Bool]
  format_palette_visible : @state.State[Bool]
  format_palette_query : @state.State[String]
  more_menu_visible : @state.State[Bool]
  active_menu : @state.State[String]
  toasts : @state.State[@views.ToastQueue[MarkdownEditorMsg]]
  autosave_draft : @state.State[String]
  dark_mode_enabled : @state.State[Bool]
  font_family : @state.State[MarkdownEditorFontFamily]
  folded_headings : @state.State[Array[Int]]
  priv pending_confirm : @state.State[MarkdownEditorConfirmRequest?]
  priv writing_appearance : @state.State[MarkdownEditorAppearance]
  find_visible : @state.State[Bool]
  find_query : @state.State[String]
  find_options : @state.State[MarkdownEditorFindOptions]
  priv find_matches : @state.State[Array[@text.TextRange]]
  replace_text : @state.State[String]
  document_path : @state.State[String]
  recent_document_paths : @state.State[Array[String]]
  saved_document : @state.State[String]
  priv transfer_status : @state.State[MarkdownEditorTransferStatus]
  priv transfer_generation : @state.State[Int]
  undo_stack : @state.State[Array[MarkdownEditorHistoryEntry]]
  redo_stack : @state.State[Array[MarkdownEditorHistoryEntry]]
  editor_scroll : @state.ScrollState
  file_tree_scroll : @state.ScrollState
  priv file_filter_query : @state.State[String]
  priv working_directory : @state.State[String]
  priv expanded_tree_paths : @state.State[Array[String]]
  priv directory_tree_items : @state.State[Array[@views.TreeItem]]
  priv file_tree_expanded : @state.State[Bool]
  priv selected_image_offset : @state.State[Int?]
  priv image_centered : @state.State[Bool]
}

///|
struct MarkdownEditorHistoryEntry {
  source : String
  selection : MarkdownEditorSelection
} derive(Eq, Debug, ToJson)

///|
priv struct MarkdownEditorFormatPaletteItem {
  action : String
  label : String
  group : String
  shortcut : String
}

///|
/// Find/replace options. Defaults are case-insensitive substring matching,
/// matching the original behavior.
pub struct MarkdownEditorFindOptions {
  case_sensitive : Bool
  whole_word : Bool
  regex : Bool
} derive(Eq, Debug, ToJson)

///|
fn MarkdownEditorFindOptions::default() -> MarkdownEditorFindOptions {
  { case_sensitive: false, whole_word: false, regex: false }
}

///|
/// A pending "unsaved changes" confirmation. The deferred message runs when the
/// user picks Save (after a successful save) or Discard; Cancel clears it.
pub struct MarkdownEditorConfirmRequest {
  title : String
  deferred : MarkdownEditorMsg
}

///|
/// The user's response to a pending confirmation dialog.
pub enum MarkdownEditorConfirmResolution {
  ConfirmSave
  ConfirmDiscard
  ConfirmCancel
}

///|
priv struct MarkdownEditorDocumentInfo {
  character_count : Int
  heading_count : Int
  paragraph_count : Int
  list_item_count : Int
  task_count : Int
  checked_task_count : Int
  quote_count : Int
  code_block_count : Int
  table_count : Int
  link_count : Int
  image_count : Int
  footnote_reference_count : Int
  footnote_definition_count : Int
}

///|
priv struct MarkdownEditorAppearanceSpec {
  label : String
  editor_font_size : Double
  page_width : Double
  side_editor_width : Double
  foreground : @graphics.Color
  placeholder : @graphics.Color
  page_background : @graphics.Color
  window_background : @graphics.Color
  font_family : @text.FontFamilyStack
}

///|
/// The editor's body font family, user-selectable (Typora offers serif/sans/
/// mono). Stored in settings so the choice survives restarts.
pub enum MarkdownEditorFontFamily {
  SansFont
  SerifFont
  MonoFont
} derive(Eq, Debug, ToJson)

///|
priv enum MarkdownEditorAppearance {
  PaperAppearance
  WarmAppearance
  WideAppearance
}

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
  ClipboardHtmlExport
  FileOpen
  FileSaveAs
  FileSave
  OpenTarget
}

///|
priv enum MarkdownEditorTransferStatus {
  TransferReady
  TransferRunning(MarkdownEditorTransferKind)
  TransferUnavailable(String)
  TransferCancelled(MarkdownEditorTransferKind)
  TransferCopied
  TransferHtmlCopied
  TransferImported
  TransferOpened(String)
  TransferSaved(String)
  TransferSavedAs(String)
  TransferTargetOpened
}

///|
pub enum MarkdownEditorServiceCompletion {
  FileOpenPicked(Int, @services.ServiceTaskResult[String])
  FileSavePicked(Int, @services.ServiceTaskResult[String])
  TextFileRead(Int, String, @services.ServiceTaskResult[String])
  TextFileWritten(Int, String, Bool, @services.ServiceTaskResult[Unit])
  ClipboardImported(Int, @services.ServiceTaskResult[String])
  ClipboardExported(Int, Bool, @services.ServiceTaskResult[Unit])
  TargetOpened(Int, @services.ServiceTaskResult[Unit])
  DirectoryPicked(@services.ServiceTaskResult[String])
  DirectoryListed(
    String,
    @services.ServiceTaskResult[Array[@services.DirectoryEntry]]
  )
  SettingsLoaded(@services.ServiceTaskResult[String?])
  SettingsSaved(@services.ServiceTaskResult[Unit])
}

///|
pub enum MarkdownEditorMsg {
  NewDocument
  SaveDocument
  SaveDocumentAs
  OpenDocument
  ImportFromClipboard
  ExportToClipboard
  ExportHtmlToClipboard
  ServiceCompleted(MarkdownEditorServiceCompletion)
  Undo
  Redo
  ToggleOutline
  ToggleFileSidebar
  ToggleDocumentInfo
  ToggleFind
  ToggleFocusMode
  ToggleTypewriterMode
  ToggleZenMode
  ToggleFormatPalette
  UpdateFormatPaletteQuery(String)
  ApplyFirstFormatPaletteAction
  ApplyFormatPaletteAction(String)
  CycleWritingAppearance
  OpenFind
  OpenFindReplace
  CloseFind
  DismissAuxiliaryPanels
  ToggleSourcePreview
  ToggleSourceMode
  DismissToastTick
  AutosaveTick
  ResolvePendingConfirm(MarkdownEditorConfirmResolution)
  ApplyEditorTransaction(MarkdownEditTransaction)
  UpdateFindQuery(String)
  UpdateReplaceText(String)
  ToggleFindCaseSensitive
  ToggleFindWholeWord
  ToggleFindRegex
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
  ToggleHeadingFold(Int)
  CommandClickAt(Int)
  SetSelection(Int, @text.TextRange?)
  OpenRecentDocument(String)
  JumpToOutline(Int)
  JumpToNextHeading
  JumpToPreviousHeading
  ToggleCurrentTask
  InsertHardBreak
  IndentLines
  OutdentLines
  ToggleTaskAt(Int)
  PickWorkingDirectory
  RefreshFileTree
  UpdateFileFilterQuery(String)
  SelectTreePath(String)
  ToggleTreePath(String)
  ToggleFileTree
  InsertMediaFromFileDrop(String)
  ToggleImageCenter
}

///|
pub fn MarkdownEditorApp::new() -> MarkdownEditorApp {
  let document = sample_markdown()
  {
    document: @state.State::new(document),
    document_session: @state.State::new(MarkdownDocumentSession::new(document)),
    selection: @state.State::new({ caret: 0, selection: None }),
    link_target: @state.State::new("https://moui.dev"),
    image_target: @state.State::new("assets/image.png"),
    footnote_text: @state.State::new("Footnote text"),
    html_block_text: @state.State::new("<div>HTML</div>"),
    target_kind: @state.State::new(PlainSelection),
    block_label: @state.State::new("Paragraph"),
    source_preview_visible: @state.State::new(false),
    source_mode_enabled: @state.State::new(false),
    outline_visible: @state.State::new(false),
    file_sidebar_visible: @state.State::new(false),
    working_directory: @state.State::new(""),
    expanded_tree_paths: @state.State::new([]),
    directory_tree_items: @state.State::new([]),
    document_info_visible: @state.State::new(false),
    focus_mode_enabled: @state.State::new(false),
    typewriter_mode_enabled: @state.State::new(false),
    zen_mode_enabled: @state.State::new(false),
    format_palette_visible: @state.State::new(false),
    format_palette_query: @state.State::new(""),
    more_menu_visible: @state.State::new(false),
    active_menu: @state.State::new(""),
    toasts: @state.State::new(@views.ToastQueue::new()),
    autosave_draft: @state.State::new(""),
    dark_mode_enabled: @state.State::new(false),
    font_family: @state.State::new(SansFont),
    folded_headings: @state.State::new([]),
    pending_confirm: @state.State::new(None),
    writing_appearance: @state.State::new(PaperAppearance),
    find_visible: @state.State::new(false),
    find_query: @state.State::new(""),
    find_options: @state.State::new(MarkdownEditorFindOptions::default()),
    find_matches: @state.State::new([]),
    replace_text: @state.State::new(""),
    document_path: @state.State::new(""),
    recent_document_paths: @state.State::new([]),
    saved_document: @state.State::new(document),
    transfer_status: @state.State::new(TransferReady),
    transfer_generation: @state.State::new(0),
    undo_stack: @state.State::new([]),
    redo_stack: @state.State::new([]),
    editor_scroll: @state.ScrollState::new(),
    file_tree_scroll: @state.ScrollState::new(),
    file_filter_query: @state.State::new(""),
    file_tree_expanded: @state.State::new(true),
    selected_image_offset: @state.State::new(None),
    image_centered: @state.State::new(false),
  }
}

///|
fn MarkdownEditorApp::update(
  self : MarkdownEditorApp,
  message : MarkdownEditorMsg,
) -> MarkdownEditorApp {
  match message {
    NewDocument =>
      if self.is_dirty() && self.pending_confirm.get() is None {
        self.pending_confirm.set(
          Some({ title: "Unsaved changes", deferred: NewDocument }),
        )
      } else {
        self.new_document()
      }
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
      if self.is_dirty() && self.pending_confirm.get() is None {
        self.pending_confirm.set(
          Some({ title: "Unsaved changes", deferred: OpenDocument }),
        )
      } else {
        self.transfer_status.set(
          TransferUnavailable("open requires host file dialog services"),
        )
      }
    ImportFromClipboard =>
      self.transfer_status.set(
        TransferUnavailable("clipboard import requires host services"),
      )
    ExportToClipboard =>
      self.transfer_status.set(
        TransferUnavailable("clipboard export requires host services"),
      )
    ExportHtmlToClipboard =>
      self.transfer_status.set(
        TransferUnavailable("html export requires host services"),
      )
    ServiceCompleted(_) => ()
    Undo => ignore(self.undo())
    Redo => ignore(self.redo())
    ToggleOutline => self.toggle_outline()
    ToggleFileSidebar => self.toggle_file_sidebar()
    ToggleFileTree =>
      self.file_tree_expanded.set(!self.file_tree_expanded.get())
    ToggleDocumentInfo => self.toggle_document_info()
    ToggleFind => self.toggle_find()
    ToggleFocusMode => self.toggle_focus_mode()
    ToggleTypewriterMode => self.toggle_typewriter_mode()
    ToggleZenMode => self.toggle_zen_mode()
    ToggleFormatPalette => self.toggle_format_palette()
    UpdateFormatPaletteQuery(value) => self.format_palette_query.set(value)
    ApplyFirstFormatPaletteAction => self.apply_first_format_palette_action()
    ApplyFormatPaletteAction(action) => self.apply_format_palette_action(action)
    CycleWritingAppearance => self.cycle_writing_appearance()
    OpenFind => self.open_find()
    OpenFindReplace => self.open_find()
    CloseFind => self.close_find()
    DismissAuxiliaryPanels => self.dismiss_auxiliary_panels()
    ToggleSourcePreview => self.toggle_source_preview()
    ToggleSourceMode => self.toggle_source_mode()
    DismissToastTick => self.expire_toasts()
    AutosaveTick => self.maybe_autosave()
    ResolvePendingConfirm(resolution) =>
      self.resolve_pending_confirm(resolution)
    ApplyEditorTransaction(transaction) =>
      self.apply_editor_transaction(transaction)
    UpdateFindQuery(value) => self.update_find_query(value)
    UpdateReplaceText(value) => self.replace_text.set(value)
    ToggleFindCaseSensitive => self.toggle_find_option(field="case_sensitive")
    ToggleFindWholeWord => self.toggle_find_option(field="whole_word")
    ToggleFindRegex => self.toggle_find_option(field="regex")
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
    ToggleHeadingFold(source_start) => self.toggle_heading_fold(source_start)
    CommandClickAt(offset) => self.handle_command_click(offset)
    SetSelection(caret, selection) => self.set_selection(caret, selection)
    OpenRecentDocument(path) =>
      self.transfer_status.set(
        TransferUnavailable(
          "opening " +
          markdown_editor_file_name(path) +
          " requires host text file services",
        ),
      )
    PickWorkingDirectory => ()
    RefreshFileTree =>
      if self.working_directory.get() == "" {
        self.transfer_status.set(
          TransferUnavailable("refresh requires a picked working folder"),
        )
      }
    UpdateFileFilterQuery(value) => self.file_filter_query.set(value)
    SelectTreePath(_) => ()
    ToggleTreePath(id) => ignore(self.toggle_tree_path(id))
    JumpToOutline(source_start) => self.jump_to_outline(source_start)
    JumpToNextHeading => self.jump_to_next_heading()
    JumpToPreviousHeading => self.jump_to_previous_heading()
    ToggleCurrentTask => self.toggle_current_task()
    InsertHardBreak => self.insert_hard_break()
    IndentLines => self.shift_current_lines(indent=true)
    OutdentLines => self.shift_current_lines(indent=false)
    ToggleTaskAt(offset) => self.toggle_task_at(offset)
    InsertMediaFromFileDrop(path) => self.insert_media_from_path(path)
    ToggleImageCenter => {
      let doc = self.document.get()
      let centered = !self.image_centered.get()
      let next = markdown_editor_toggle_image_center(doc, centered)
      self.replace_document_source(next, reason=MediaEdit)
      self.image_centered.set(centered)
      self.sync_target_inputs()
    }
  }
  self
}

///|

///|
fn MarkdownEditorApp::update_with_services(
  self : MarkdownEditorApp,
  message : MarkdownEditorMsg,
  services : @services.AppServices,
) -> (MarkdownEditorApp, @moui.Effect[MarkdownEditorMsg]) {
  match message {
    SaveDocument => (self, self.request_document_save(services))
    SaveDocumentAs => (self, self.request_file_save_as(services))
    OpenDocument =>
      if self.is_dirty() && self.pending_confirm.get() is None {
        self.pending_confirm.set(
          Some({ title: "Unsaved changes", deferred: OpenDocument }),
        )
        (self, @moui.Effect::none())
      } else {
        (self, self.request_file_open(services))
      }
    ImportFromClipboard => (self, self.request_clipboard_import(services))
    ExportToClipboard => (self, self.request_clipboard_export(services))
    ExportHtmlToClipboard => (self, self.request_html_export(services))
    OpenTarget => (self, self.request_open_target(services))
    OpenRecentDocument(path) => {
      let effects : Array[@moui.Effect[MarkdownEditorMsg]] = [
        self.request_text_file_read(path, services),
      ]
      if self.working_directory.get() == "" {
        let parent = markdown_editor_parent_directory(path)
        if parent != "" {
          self.working_directory.set(parent)
          effects.push(self.request_directory_listing(parent, services))
        }
      }
      (self, @moui.Effect::batch(effects))
    }
    PickWorkingDirectory =>
      (self, self.request_pick_working_directory(services))
    RefreshFileTree => {
      let path = self.working_directory.get()
      if path == "" {
        self.transfer_status.set(
          TransferUnavailable("refresh requires a picked working folder"),
        )
        (self, @moui.Effect::none())
      } else {
        (self, self.request_directory_listing(path, services))
      }
    }
    ToggleTreePath(id) => {
      let expanded = self.toggle_tree_path(id)
      let effect = if expanded && self.tree_path_needs_load(id) {
        self.request_directory_listing(id, services)
      } else {
        @moui.Effect::none()
      }
      (self, effect)
    }
    SelectTreePath(path) => {
      if markdown_editor_tree_path_is_placeholder(path) {
        return (self, @moui.Effect::none())
      }
      if self.tree_path_is_directory(path) {
        let expanded = self.toggle_tree_path(path)
        let effect = if expanded && self.tree_path_needs_load(path) {
          self.request_directory_listing(path, services)
        } else {
          @moui.Effect::none()
        }
        return (self, effect)
      }
      let effects : Array[@moui.Effect[MarkdownEditorMsg]] = [
        self.request_text_file_read(path, services),
      ]
      if self.working_directory.get() == "" {
        let parent = markdown_editor_parent_directory(path)
        if parent != "" {
          self.working_directory.set(parent)
          effects.push(self.request_directory_listing(parent, services))
        }
      }
      (self, @moui.Effect::batch(effects))
    }
    ServiceCompleted(completion) =>
      (self, self.apply_service_completion(completion, services))
    ToggleOutline
    | ToggleFileSidebar
    | ToggleDocumentInfo
    | ToggleFocusMode
    | ToggleTypewriterMode
    | ToggleZenMode
    | CycleWritingAppearance
    | ToggleSourcePreview => {
      ignore(self.update(message))
      (self, self.request_settings_save(services))
    }
    _ => (self.update(message), @moui.Effect::none())
  }
}

///|
fn MarkdownEditorApp::subscriptions(
  self : MarkdownEditorApp,
  timer_source : @services.TimerSource?,
) -> @moui.Subscription[MarkdownEditorMsg] {
  let subscriptions : Array[@moui.Subscription[MarkdownEditorMsg]] = []
  match timer_source {
    Some(source) => {
      if self.toasts.get().items.length() > 0 {
        subscriptions.push(
          source.subscription(
            interval_ms=1000.0,
            key="markdown-editor:toast-dismiss",
            label="Markdown editor toast dismiss tick",
            map=_ => DismissToastTick,
          ),
        )
      }
      if self.is_dirty() &&
        self.document_path.get() != "" &&
        !self.transfer_in_progress() {
        subscriptions.push(
          source.subscription(
            interval_ms=5000.0,
            key="markdown-editor:autosave",
            label="Markdown editor autosave tick",
            map=_ => AutosaveTick,
          ),
        )
      }
    }
    None => ()
  }
  @moui.Subscription::batch(subscriptions)
}

///|
pub fn MarkdownEditorApp::program(
  self : MarkdownEditorApp,
  environment? : @services.AppEnvironment = @services.AppEnvironment::new(),
) -> @moui.Program[MarkdownEditorApp, MarkdownEditorMsg] {
  let services = environment.services()
  let timer_source = environment.timer()
  @moui.Program::new(
    init=() => (self, markdown_editor_request_settings_load(services)),
    update=(app, message) => app.update_with_services(message, services),
    view=app => @views.component(ctx => app.reactive_root(ctx)),
    subscriptions=app => app.subscriptions(timer_source),
  ).with_commands(commands=_app => markdown_editor_program_commands())
}

///|
fn sample_markdown() -> String {
  "# Editor notes\n\nThis **WYSIWYG** surface keeps `Markdown` as the saved value.\n\n## Today\n- Type into the formatted page\n- Use shortcuts or contextual controls\n- Open source only when needed\n\n> Unsupported syntax stays editable as plain text.\n\n```\nlet saved = markdown\n```\n\n---"
}
