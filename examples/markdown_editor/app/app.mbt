///|
using @views {
  button,
  column,
  container,
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
  document : @moui.State[String]
  document_session : @moui.State[MarkdownDocumentSession]
  selection : @moui.State[MarkdownEditorSelection]
  link_target : @moui.State[String]
  image_target : @moui.State[String]
  footnote_text : @moui.State[String]
  html_block_text : @moui.State[String]
  target_kind : @moui.State[MarkdownEditorTargetKind]
  block_label : @moui.State[String]
  source_preview_visible : @moui.State[Bool]
  source_mode_enabled : @moui.State[Bool]
  outline_visible : @moui.State[Bool]
  file_sidebar_visible : @moui.State[Bool]
  document_info_visible : @moui.State[Bool]
  focus_mode_enabled : @moui.State[Bool]
  typewriter_mode_enabled : @moui.State[Bool]
  zen_mode_enabled : @moui.State[Bool]
  format_palette_visible : @moui.State[Bool]
  format_palette_query : @moui.State[String]
  more_menu_visible : @moui.State[Bool]
  active_menu : @moui.State[String]
  toasts : @moui.State[@views.ToastQueue[MarkdownEditorMsg]]
  autosave_draft : @moui.State[String]
  dark_mode_enabled : @moui.State[Bool]
  font_family : @moui.State[MarkdownEditorFontFamily]
  folded_headings : @moui.State[Array[Int]]
  priv pending_confirm : @moui.State[MarkdownEditorConfirmRequest?]
  priv writing_appearance : @moui.State[MarkdownEditorAppearance]
  find_visible : @moui.State[Bool]
  find_query : @moui.State[String]
  find_options : @moui.State[MarkdownEditorFindOptions]
  replace_text : @moui.State[String]
  document_path : @moui.State[String]
  recent_document_paths : @moui.State[Array[String]]
  saved_document : @moui.State[String]
  priv transfer_status : @moui.State[MarkdownEditorTransferStatus]
  undo_stack : @moui.State[Array[MarkdownEditorHistoryEntry]]
  redo_stack : @moui.State[Array[MarkdownEditorHistoryEntry]]
  editor_scroll : @core.ScrollState
  file_tree_scroll : @core.ScrollState
  priv working_directory : @moui.State[String]
  priv expanded_tree_paths : @moui.State[Array[String]]
  priv directory_tree_items : @moui.State[Array[@views.TreeItem]]
  priv file_tree_expanded : @moui.State[Bool]
  priv selected_image_offset : @moui.State[Int?]
  priv image_centered : @moui.State[Bool]
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
  foreground : @core.Color
  placeholder : @core.Color
  page_background : @core.Color
  window_background : @core.Color
  page_border : @core.Color
  font_family : @core.FontFamilyStack
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
  TransferRequesting(MarkdownEditorTransferKind)
  TransferPending(@host.HostServiceRequestId, MarkdownEditorTransferKind)
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
pub enum MarkdownEditorMsg {
  NewDocument
  SaveDocument
  SaveDocumentAs
  OpenDocument
  ImportFromClipboard
  ExportToClipboard
  ExportHtmlToClipboard
  HostTransferCompleted(@host.HostCompletedServiceResponse)
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
  ToggleMenuBarMenu(String)
  CloseMenuBarMenu
  CloseMenuBarMenuAndRun(MarkdownEditorMsg)
  ToggleDarkMode
  CycleFontFamily
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
  SetSelection(Int, @core.TextRange?)
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
    document: @moui.State::new(document),
    document_session: @moui.State::new(MarkdownDocumentSession::new(document)),
    selection: @moui.State::new({ caret: 0, selection: None }),
    link_target: @moui.State::new("https://moui.dev"),
    image_target: @moui.State::new("assets/image.png"),
    footnote_text: @moui.State::new("Footnote text"),
    html_block_text: @moui.State::new("<div>HTML</div>"),
    target_kind: @moui.State::new(PlainSelection),
    block_label: @moui.State::new("Paragraph"),
    source_preview_visible: @moui.State::new(false),
    source_mode_enabled: @moui.State::new(false),
    outline_visible: @moui.State::new(false),
    file_sidebar_visible: @moui.State::new(false),
    working_directory: @moui.State::new(""),
    expanded_tree_paths: @moui.State::new([]),
    directory_tree_items: @moui.State::new([]),
    document_info_visible: @moui.State::new(false),
    focus_mode_enabled: @moui.State::new(false),
    typewriter_mode_enabled: @moui.State::new(false),
    zen_mode_enabled: @moui.State::new(false),
    format_palette_visible: @moui.State::new(false),
    format_palette_query: @moui.State::new(""),
    more_menu_visible: @moui.State::new(false),
    active_menu: @moui.State::new(""),
    toasts: @moui.State::new(@views.ToastQueue::new()),
    autosave_draft: @moui.State::new(""),
    dark_mode_enabled: @moui.State::new(false),
    font_family: @moui.State::new(SansFont),
    folded_headings: @moui.State::new([]),
    pending_confirm: @moui.State::new(None),
    writing_appearance: @moui.State::new(PaperAppearance),
    find_visible: @moui.State::new(false),
    find_query: @moui.State::new(""),
    find_options: @moui.State::new(MarkdownEditorFindOptions::default()),
    replace_text: @moui.State::new(""),
    document_path: @moui.State::new(""),
    recent_document_paths: @moui.State::new([]),
    saved_document: @moui.State::new(document),
    transfer_status: @moui.State::new(TransferReady),
    undo_stack: @moui.State::new([]),
    redo_stack: @moui.State::new([]),
    editor_scroll: @core.ScrollState::new(),
    file_tree_scroll: @core.ScrollState::new(),
    file_tree_expanded: @moui.State::new(true),
    selected_image_offset: @moui.State::new(None),
    image_centered: @moui.State::new(false),
  }
}

///|
/// Construct the editor and apply persisted settings when host services are
/// available. Backends that want settings to survive restarts should call this
/// instead of `new()`.
pub fn MarkdownEditorApp::new_with_services(
  services : @host.HostAppServices,
) -> MarkdownEditorApp {
  let app = MarkdownEditorApp::new()
  let settings = markdown_editor_load_settings(services)
  app.apply_settings(settings)
  app
}

///|
/// Persist the current preferences. Backends can call this on shutdown or on a
/// timer so settings survive the next launch.
pub fn MarkdownEditorApp::persist_settings(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
) -> Unit {
  self.save_settings(services)
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
    HostTransferCompleted(completion) =>
      self.apply_transfer_completion(completion)
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
    ToggleDarkMode => self.dark_mode_enabled.set(!self.dark_mode_enabled.get())
    CycleFontFamily => {
      let next = match self.font_family.get() {
        SansFont => SerifFont
        SerifFont => MonoFont
        MonoFont => SansFont
      }
      self.font_family.set(next)
    }
    ToggleMenuBarMenu(menu_id) =>
      if self.active_menu.get() == menu_id {
        self.active_menu.set("")
      } else {
        self.active_menu.set(menu_id)
      }
    CloseMenuBarMenu => self.active_menu.set("")
    CloseMenuBarMenuAndRun(message) => {
      self.active_menu.set("")
      let _ = self.update(message)
    }
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
    SelectTreePath(_) => ()
    ToggleTreePath(id) => {
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
    }
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
fn MarkdownEditorApp::update_with_services(
  self : MarkdownEditorApp,
  message : MarkdownEditorMsg,
  services : @host.HostAppServices,
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
      // Auto-set working directory from file's parent when none is set
      if self.working_directory.get() == "" {
        let parent = markdown_editor_parent_directory(path)
        if parent != "" {
          ignore(self.load_tree_from_directory(parent, services))
        }
      }
      (self, self.request_text_file_read(path, services))
    }
    PickWorkingDirectory =>
      (self, self.request_pick_working_directory(services))
    SelectTreePath(path) => {
      if self.working_directory.get() == "" {
        let parent = markdown_editor_parent_directory(path)
        if parent != "" {
          ignore(self.load_tree_from_directory(parent, services))
        }
      }
      (self, self.request_text_file_read(path, services))
    }
    HostTransferCompleted(completion) => {
      self.apply_transfer_completion_with_services(completion, services)
      (self, @moui.Effect::none())
    }
    _ => (self.update(message), @moui.Effect::none())
  }
}

///|
fn MarkdownEditorApp::subscriptions(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
  timer_source? : @host.HostTimerSource? = None,
) -> @moui.Subscription[MarkdownEditorMsg] {
  // The transfer completion subscription always wins while a host transfer is
  // pending, since it owns the lifecycle of that async work.
  let transfer_sub = match self.transfer_status.get() {
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
    _ => @moui.Subscription::none()
  }
  let subs : Array[@moui.Subscription[MarkdownEditorMsg]] = [transfer_sub]
  // A repeating timer dismisses toasts once their TTL elapses. Only active
  // while toasts are on screen, and only when a host timer source exists.
  match timer_source {
    Some(source) => {
      if self.toasts.get().items.length() > 0 {
        subs.push(
          source.subscription(
            interval_ms=1000.0,
            key="markdown-editor:toast-dismiss",
            label="Markdown editor toast dismiss tick",
            map=_ => DismissToastTick,
          ),
        )
      }
      // Autosave every 5s when the document is dirty and has a path.
      if self.is_dirty() &&
        self.document_path.get() != "" &&
        !self.transfer_in_progress() {
        subs.push(
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
  @moui.Subscription::batch(subs)
}

///|

///|
pub fn MarkdownEditorApp::program(
  self : MarkdownEditorApp,
) -> @moui.Program[MarkdownEditorApp, MarkdownEditorMsg] {
  self.program_with_services(@host.HostAppServices::unavailable())
}

///|
pub fn MarkdownEditorApp::program_with_services(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
  timer_source? : @host.HostTimerSource? = None,
) -> @moui.Program[MarkdownEditorApp, MarkdownEditorMsg] {
  @moui.Program::new(
    init=() => (self, @moui.Effect::none()),
    update=(app, message) => app.update_with_services(message, services),
    view=app => @views.component(ctx => app.reactive_root(ctx)),
    subscriptions=app => app.subscriptions(services, timer_source~),
  )
}

///|
fn sample_markdown() -> String {
  "# Editor notes\n\nThis **WYSIWYG** surface keeps `Markdown` as the saved value.\n\n## Today\n- Type into the formatted page\n- Use shortcuts or contextual controls\n- Open source only when needed\n\n> Unsupported syntax stays editable as plain text.\n\n```\nlet saved = markdown\n```\n\n---"
}
