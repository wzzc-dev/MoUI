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
  mut document : String
  mut document_session : MarkdownDocumentSession
  mut selection : MarkdownEditorSelection
  mut link_target : String
  mut image_target : String
  mut footnote_text : String
  mut html_block_text : String
  mut target_kind : MarkdownEditorTargetKind
  mut block_label : String
  mut source_preview_visible : Bool
  mut source_mode_enabled : Bool
  mut outline_visible : Bool
  mut file_sidebar_visible : Bool
  mut document_info_visible : Bool
  mut focus_mode_enabled : Bool
  mut typewriter_mode_enabled : Bool
  mut zen_mode_enabled : Bool
  mut format_palette_visible : Bool
  mut format_palette_query : String
  mut more_menu_visible : Bool
  mut active_menu : String
  mut toasts : @views.ToastQueue[MarkdownEditorMsg]
  mut autosave_draft : String
  mut dark_mode_enabled : Bool
  mut font_family : MarkdownEditorFontFamily
  mut folded_headings : Array[Int]
  priv mut pending_confirm : MarkdownEditorConfirmRequest?
  priv mut writing_appearance : MarkdownEditorAppearance
  mut find_visible : Bool
  mut find_query : String
  mut find_options : MarkdownEditorFindOptions
  priv mut find_matches : Array[@text.TextRange]
  mut replace_text : String
  mut document_path : String
  mut recent_document_paths : Array[String]
  mut saved_document : String
  priv mut transfer_status : MarkdownEditorTransferStatus
  priv mut transfer_generation : Int
  mut undo_stack : Array[MarkdownEditorHistoryEntry]
  mut redo_stack : Array[MarkdownEditorHistoryEntry]
  mut editor_scroll : @geometry.Point
  priv mut file_filter_query : String
  priv mut working_directory : String
  priv mut expanded_tree_paths : Array[String]
  priv mut directory_tree_items : Array[@views.TreeItem]
  priv mut file_tree_expanded : Bool
  priv mut image_centered : Bool
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
  EditorScrollChanged(@geometry.Point)
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
    document,
    document_session: MarkdownDocumentSession::new(document),
    selection: { caret: 0, selection: None },
    link_target: "https://wzzc-dev.github.io/MoUI",
    image_target: "assets/image.png",
    footnote_text: "Footnote text",
    html_block_text: "<div>HTML</div>",
    target_kind: PlainSelection,
    block_label: "Paragraph",
    source_preview_visible: false,
    source_mode_enabled: false,
    outline_visible: false,
    file_sidebar_visible: false,
    working_directory: "",
    expanded_tree_paths: [],
    directory_tree_items: [],
    document_info_visible: false,
    focus_mode_enabled: false,
    typewriter_mode_enabled: false,
    zen_mode_enabled: false,
    format_palette_visible: false,
    format_palette_query: "",
    more_menu_visible: false,
    active_menu: "",
    toasts: @views.ToastQueue::new(),
    autosave_draft: "",
    dark_mode_enabled: false,
    font_family: SansFont,
    folded_headings: [],
    pending_confirm: None,
    writing_appearance: PaperAppearance,
    find_visible: false,
    find_query: "",
    find_options: MarkdownEditorFindOptions::default(),
    find_matches: [],
    replace_text: "",
    document_path: "",
    recent_document_paths: [],
    saved_document: document,
    transfer_status: TransferReady,
    transfer_generation: 0,
    undo_stack: [],
    redo_stack: [],
    editor_scroll: @geometry.Point::new(x=0.0, y=0.0),
    file_filter_query: "",
    file_tree_expanded: true,
    image_centered: false,
  }
}

///|
fn MarkdownEditorApp::update(
  self : MarkdownEditorApp,
  message : MarkdownEditorMsg,
) -> MarkdownEditorApp {
  let next = self.detached()
  next.update_in_place(message)
  next
}

///|
fn MarkdownEditorApp::detached(self : MarkdownEditorApp) -> MarkdownEditorApp {
  {
    ..self,
    toasts: @views.ToastQueue::new(items=self.toasts.items.copy()),
    folded_headings: self.folded_headings.copy(),
    find_matches: self.find_matches.copy(),
    recent_document_paths: self.recent_document_paths.copy(),
    undo_stack: self.undo_stack.copy(),
    redo_stack: self.redo_stack.copy(),
    expanded_tree_paths: self.expanded_tree_paths.copy(),
    directory_tree_items: self.directory_tree_items.copy(),
  }
}

///|
fn MarkdownEditorApp::update_in_place(
  self : MarkdownEditorApp,
  message : MarkdownEditorMsg,
) -> Unit {
  match message {
    NewDocument =>
      if self.is_dirty() && self.pending_confirm is None {
        self.pending_confirm = Some({
          title: "Unsaved changes",
          deferred: NewDocument,
        })
      } else {
        self.new_document()
      }
    SaveDocument =>
      if self.document_path == "" {
        self.transfer_status = TransferUnavailable(
          "save requires host file dialog services for unnamed documents",
        )
      } else {
        self.transfer_status = TransferUnavailable(
          "save requires host text file services",
        )
      }
    SaveDocumentAs =>
      self.transfer_status = TransferUnavailable(
        "save as requires host file dialog services",
      )
    OpenDocument =>
      if self.is_dirty() && self.pending_confirm is None {
        self.pending_confirm = Some({
          title: "Unsaved changes",
          deferred: OpenDocument,
        })
      } else {
        self.transfer_status = TransferUnavailable(
          "open requires host file dialog services",
        )
      }
    ImportFromClipboard =>
      self.transfer_status = TransferUnavailable(
        "clipboard import requires host services",
      )
    ExportToClipboard =>
      self.transfer_status = TransferUnavailable(
        "clipboard export requires host services",
      )
    ExportHtmlToClipboard =>
      self.transfer_status = TransferUnavailable(
        "html export requires host services",
      )
    ServiceCompleted(_) => ()
    Undo => ignore(self.undo())
    Redo => ignore(self.redo())
    ToggleOutline => self.toggle_outline()
    ToggleFileSidebar => self.toggle_file_sidebar()
    ToggleFileTree => self.file_tree_expanded = !self.file_tree_expanded
    ToggleDocumentInfo => self.toggle_document_info()
    ToggleFind => self.toggle_find()
    ToggleFocusMode => self.toggle_focus_mode()
    ToggleTypewriterMode => self.toggle_typewriter_mode()
    ToggleZenMode => self.toggle_zen_mode()
    ToggleFormatPalette => self.toggle_format_palette()
    UpdateFormatPaletteQuery(value) => self.format_palette_query = value
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
    UpdateReplaceText(value) => self.replace_text = value
    ToggleFindCaseSensitive => self.toggle_find_option(field="case_sensitive")
    ToggleFindWholeWord => self.toggle_find_option(field="whole_word")
    ToggleFindRegex => self.toggle_find_option(field="regex")
    UpdateLinkTarget(value) => self.link_target = value
    UpdateImageTarget(value) => self.image_target = value
    UpdateFootnoteText(value) => self.footnote_text = value
    UpdateHtmlBlockText(value) => self.html_block_text = value
    ApplyLinkTarget => self.apply_link_target()
    OpenTarget =>
      self.transfer_status = TransferUnavailable(
        "open target requires host services",
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
    EditorScrollChanged(offset) => self.editor_scroll = offset
    OpenRecentDocument(path) =>
      self.transfer_status = TransferUnavailable(
        "opening " +
        markdown_editor_file_name(path) +
        " requires host text file services",
      )
    PickWorkingDirectory => ()
    RefreshFileTree =>
      if self.working_directory == "" {
        self.transfer_status = TransferUnavailable(
          "refresh requires a picked working folder",
        )
      }
    UpdateFileFilterQuery(value) => self.file_filter_query = value
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
      let doc = self.document
      let centered = !self.image_centered
      let next = markdown_editor_toggle_image_center(doc, centered)
      self.replace_document_source(next, reason=MediaEdit)
      self.image_centered = centered
      self.sync_target_inputs()
    }
  }
}

///|

///|
fn MarkdownEditorApp::update_with_services(
  self : MarkdownEditorApp,
  message : MarkdownEditorMsg,
  services : @services.AppServices,
) -> (MarkdownEditorApp, @moui.Effect[MarkdownEditorMsg]) {
  let self = self.detached()
  match message {
    SaveDocument => (self, self.request_document_save(services))
    SaveDocumentAs => (self, self.request_file_save_as(services))
    OpenDocument =>
      if self.is_dirty() && self.pending_confirm is None {
        self.pending_confirm = Some({
          title: "Unsaved changes",
          deferred: OpenDocument,
        })

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
      if self.working_directory == "" {
        let parent = markdown_editor_parent_directory(path)
        if parent != "" {
          self.working_directory = parent
          effects.push(self.request_directory_listing(parent, services))
        }
      }
      (self, @moui.Effect::batch(effects))
    }
    PickWorkingDirectory =>
      (self, self.request_pick_working_directory(services))
    RefreshFileTree => {
      let path = self.working_directory
      if path == "" {
        self.transfer_status = TransferUnavailable(
          "refresh requires a picked working folder",
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
      if self.working_directory == "" {
        let parent = markdown_editor_parent_directory(path)
        if parent != "" {
          self.working_directory = parent
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
      self.update_in_place(message)
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
      if self.toasts.items.length() > 0 {
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
        self.document_path != "" &&
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
  @moui.Program::new_with_environment(
    init=() => (self, markdown_editor_request_settings_load(services)),
    update=(app, message) => app.update_with_services(message, services),
    view=(app, view_environment) => app.root_with_environment(view_environment),
    subscriptions=app => app.subscriptions(timer_source),
  ).with_commands(commands=_app => markdown_editor_program_commands())
}

///|
fn sample_markdown() -> String {
  "# Editor notes\n\nThis **WYSIWYG** surface keeps `Markdown` as the saved value.\n\n## Today\n- Type into the formatted page\n- Use shortcuts or contextual controls\n- Open source only when needed\n\n> Unsupported syntax stays editable as plain text.\n\n```\nlet saved = markdown\n```\n\n---"
}
