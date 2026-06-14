///|
using @views {
  button,
  column,
  empty,
  frame,
  padding_edges,
  row,
  rich_text_editor,
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
  source_mode_enabled : @core.State[Bool]
  outline_visible : @core.State[Bool]
  file_sidebar_visible : @core.State[Bool]
  document_info_visible : @core.State[Bool]
  focus_mode_enabled : @core.State[Bool]
  typewriter_mode_enabled : @core.State[Bool]
  zen_mode_enabled : @core.State[Bool]
  format_palette_visible : @core.State[Bool]
  format_palette_query : @core.State[String]
  priv writing_appearance : @core.State[MarkdownEditorAppearance]
  find_visible : @core.State[Bool]
  find_query : @core.State[String]
  replace_text : @core.State[String]
  document_path : @core.State[String]
  recent_document_paths : @core.State[Array[String]]
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
priv struct MarkdownEditorFormatPaletteItem {
  action : String
  label : String
  group : String
  shortcut : String
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
}

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
priv enum MarkdownEditorMsg {
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
  OpenRecentDocument(String)
  JumpToOutline(Int)
  JumpToNextHeading
  JumpToPreviousHeading
  ToggleCurrentTask
  InsertHardBreak
  IndentLines
  OutdentLines
  ToggleTaskAt(Int)
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
    source_mode_enabled: @core.State::new(false),
    outline_visible: @core.State::new(false),
    file_sidebar_visible: @core.State::new(false),
    document_info_visible: @core.State::new(false),
    focus_mode_enabled: @core.State::new(false),
    typewriter_mode_enabled: @core.State::new(false),
    zen_mode_enabled: @core.State::new(false),
    format_palette_visible: @core.State::new(false),
    format_palette_query: @core.State::new(""),
    writing_appearance: @core.State::new(PaperAppearance),
    find_visible: @core.State::new(false),
    find_query: @core.State::new(""),
    replace_text: @core.State::new(""),
    document_path: @core.State::new(""),
    recent_document_paths: @core.State::new([]),
    saved_document: @core.State::new(document),
    transfer_status: @core.State::new(TransferReady),
    undo_stack: @core.State::new([]),
    redo_stack: @core.State::new([]),
    editor_scroll: @core.ScrollState::new(),
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
    OpenRecentDocument(path) =>
      self.transfer_status.set(
        TransferUnavailable(
          "opening " +
          markdown_editor_file_name(path) +
          " requires host text file services",
        ),
      )
    JumpToOutline(source_start) => self.jump_to_outline(source_start)
    JumpToNextHeading => self.jump_to_next_heading()
    JumpToPreviousHeading => self.jump_to_previous_heading()
    ToggleCurrentTask => self.toggle_current_task()
    InsertHardBreak => self.insert_hard_break()
    IndentLines => self.shift_current_lines(indent=true)
    OutdentLines => self.shift_current_lines(indent=false)
    ToggleTaskAt(offset) => self.toggle_task_at(offset)
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
    ExportHtmlToClipboard => (self, self.request_html_export(services))
    OpenTarget => (self, self.request_open_target(services))
    OpenRecentDocument(path) =>
      (self, self.request_text_file_read(path, services))
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

///|
pub fn MarkdownEditorApp::runtime(
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
pub fn MarkdownEditorApp::runtime_with_services(
  self : MarkdownEditorApp,
  services : @host.HostAppServices,
  width? : Double = 1120.0,
  height? : Double = 720.0,
) -> @runtime.AppRuntime {
  let runtime = @runtime.AppRuntime::new_program(
    program=@core.Program::new(
      init=() => (self, @core.Effect::none()),
      update=(app, message) => app.update_with_services(message, services),
      view=app => @views.component(ctx => app.reactive_root(ctx)),
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
