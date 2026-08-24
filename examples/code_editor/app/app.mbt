///|
using @views {
  button,
  column,
  container,
  expanded,
  row,
  stack,
  scroll_view,
  spacer,
  status_bar,
  text,
  text_field,
}

///|
pub(all) struct CodeEditorFeature {
  label : String
  detail : String
}

///|
pub(all) enum CodeEditorMode {
  SourceEditor
  DiffEditor
  ProviderLab
} derive(Eq)

///|
pub fn CodeEditorMode::label(self : CodeEditorMode) -> String {
  match self {
    SourceEditor => "Source Editor"
    DiffEditor => "Diff Editor"
    ProviderLab => "Provider Lab"
  }
}

///|
pub(all) enum CodeEditorSidePanel {
  CapabilitiesPanel
  IntelliSensePanel
}

///|
pub(all) struct CodeEditorModel {
  source : String
  original_source : String
  language_id : String
  mode : CodeEditorMode
  active_panel : CodeEditorSidePanel?
  editor_scroll : @geometry.Point
  find_visible : Bool
  completion_visible : Bool
  cursors : Array[CodeCursor]
  selection : @text.TextRange?
  find : CodeFindState
  registry : CodeLanguageRegistry
  completions : Array[CodeCompletionItem]
  diagnostics : Array[CodeDiagnostic]
  hover : CodeHover?
  definition : CodeDefinition?
  bracket_match : BracketMatch?
  status : String
}

///|
pub(all) enum CodeEditorMsg {
  SourceChanged(String)
  InsertText(String)
  SelectionChanged(Int, @text.TextRange?)
  EditorScrollChanged(@geometry.Point)
  SetFindQuery(String)
  SetReplaceText(String)
  FindNext
  ReplaceAll
  RunDiagnostics
  TriggerCompletion
  OpenCommandPalette
  ShowHover
  GoToDefinition
  ShowSource
  ShowDiff
  ShowProviders
  ToggleCapabilities
  ToggleIntelliSense
  ToggleDiffEditor
  ToggleFind
  CloseFind
  ApplyCompletion(Int)
  OpenPanel(CodeEditorSidePanel?)
  SetMode(CodeEditorMode)
  ChangeLanguage(String)
  RegisterSampleLanguage
  DemoMultiCursor
}

///|
pub fn CodeEditorModel::new() -> CodeEditorModel {
  let source = sample_source()
  {
    source,
    original_source: sample_original_source(),
    language_id: "moonbit",
    mode: SourceEditor,
    active_panel: None,
    editor_scroll: @geometry.Point::new(x=0.0, y=0.0),
    find_visible: false,
    completion_visible: false,
    cursors: [
      CodeCursor::new(position=code_editor_text_offset(source, "fn main {")),
    ],
    selection: None,
    find: CodeFindState::new(),
    registry: CodeLanguageRegistry::new(),
    completions: [],
    diagnostics: [],
    hover: None,
    definition: None,
    bracket_match: None,
    status: "Native editor ready",
  }
}

///|
pub fn CodeEditorModel::with_source(
  self : CodeEditorModel,
  source : String,
) -> CodeEditorModel {
  {
    ..self,
    source,
    find: self.find.recompute(source),
    bracket_match: self.primary_bracket_match(source),
  }
}

///|
pub fn CodeEditorModel::with_cursor(
  self : CodeEditorModel,
  position : Int,
) -> CodeEditorModel {
  self.with_cursors([CodeCursor::new(position~)])
}

///|
pub fn CodeEditorModel::with_cursors(
  self : CodeEditorModel,
  cursors : Array[CodeCursor],
) -> CodeEditorModel {
  { ..self, cursors, bracket_match: self.primary_bracket_match(self.source) }
}

///|
pub fn CodeEditorModel::with_find(
  self : CodeEditorModel,
  query : String,
) -> CodeEditorModel {
  let find = { ..self.find, query, active_index: -1 }.recompute(self.source)
  { ..self, find, }
}

///|
pub fn CodeEditorModel::with_replace(
  self : CodeEditorModel,
  replacement : String,
) -> CodeEditorModel {
  { ..self, find: { ..self.find, replacement, } }
}

///|
fn CodeEditorModel::primary_offset(self : CodeEditorModel) -> Int {
  match self.cursors {
    [cursor, ..] => cursor.position
    [] => 0
  }
}

///|
fn CodeEditorModel::primary_bracket_match(
  self : CodeEditorModel,
  source : String,
) -> BracketMatch? {
  code_bracket_match(source, self.primary_offset())
}

///|
pub fn update(
  model : CodeEditorModel,
  message : CodeEditorMsg,
) -> CodeEditorModel {
  match message {
    SourceChanged(value) =>
      {
        ..model.with_source(value),
        status: "Source updated",
        diagnostics: [],
        hover: None,
        definition: None,
        completion_visible: false,
      }
    InsertText(inserted) => {
      let (source, cursors) = code_insert_text(
        model.source,
        model.cursors,
        inserted,
      )
      {
        ..model.with_source(source),
        cursors,
        selection: None,
        completion_visible: false,
        status: "Inserted at \{cursors.length()} cursor(s)",
      }
    }
    SelectionChanged(position, range) =>
      {
        ..model.with_cursors([CodeCursor::new(position~, selection=range)]),
        selection: range,
        bracket_match: code_bracket_match(model.source, position),
      }
    EditorScrollChanged(offset) => { ..model, editor_scroll: offset }
    SetFindQuery(value) => model.with_find(value)
    SetReplaceText(value) => model.with_replace(value)
    FindNext => model.select_next_match()
    ReplaceAll => model.replace_all_matches()
    RunDiagnostics =>
      {
        ..model,
        diagnostics: model.registry.diagnostics(model.language_id, model.source),
        status: "Diagnostics refreshed",
      }
    TriggerCompletion =>
      {
        ..model,
        completions: model.registry.completions(
          model.language_id,
          model.source,
          model.primary_offset(),
        ),
        completion_visible: true,
        active_panel: None,
        status: "Completion provider queried",
      }
    OpenCommandPalette =>
      {
        ..model,
        active_panel: Some(IntelliSensePanel),
        status: "Command palette opened",
      }
    ShowHover =>
      {
        ..model,
        hover: model.registry.hover(
          model.language_id,
          model.source,
          model.primary_offset(),
        ),
        status: "Hover provider queried",
      }
    GoToDefinition =>
      {
        ..model,
        definition: model.registry.definition(
          model.language_id,
          model.source,
          model.primary_offset(),
        ),
        status: "Definition provider queried",
      }
    ShowSource => { ..model, mode: SourceEditor, active_panel: None }
    ShowDiff => model.toggle_diff_mode()
    ShowProviders => model.toggle_side_panel(IntelliSensePanel)
    ToggleCapabilities => model.toggle_side_panel(CapabilitiesPanel)
    ToggleIntelliSense => model.toggle_side_panel(IntelliSensePanel)
    ToggleDiffEditor => model.toggle_diff_mode()
    ToggleFind => { ..model, find_visible: !model.find_visible }
    CloseFind => { ..model, find_visible: false }
    ApplyCompletion(index) => model.apply_completion(index)
    OpenPanel(panel) =>
      match panel {
        Some(value) => model.toggle_side_panel(value)
        None => { ..model, active_panel: None }
      }
    SetMode(mode) => { ..model, mode, active_panel: None }
    ChangeLanguage(id) =>
      {
        ..model,
        language_id: id,
        completions: [],
        completion_visible: false,
        hover: None,
        definition: None,
        status: "Language: " + id,
      }
    RegisterSampleLanguage =>
      {
        ..model,
        registry: model.registry.register_language(sample_provider()),
        language_id: "calc",
        mode: ProviderLab,
        active_panel: Some(IntelliSensePanel),
        status: "Registered calc language and providers",
      }
    DemoMultiCursor => {
      let demo = {
        ..model,
        source: "alpha\nbeta\n",
        cursors: [CodeCursor::new(position=0), CodeCursor::new(position=6)],
      }
      update(demo, InsertText("// "))
    }
  }
}

///|
fn CodeEditorModel::toggle_side_panel(
  self : CodeEditorModel,
  panel : CodeEditorSidePanel,
) -> CodeEditorModel {
  if side_panel_matches(self.active_panel, panel) {
    { ..self, active_panel: None }
  } else {
    {
      ..self,
      active_panel: Some(panel),
      mode: match panel {
        IntelliSensePanel => ProviderLab
        CapabilitiesPanel => SourceEditor
      },
      status: panel_status(panel),
    }
  }
}

///|
fn CodeEditorModel::toggle_diff_mode(self : CodeEditorModel) -> CodeEditorModel {
  if self.mode == DiffEditor {
    {
      ..self,
      mode: SourceEditor,
      active_panel: None,
      status: "Source editor active",
    }
  } else {
    {
      ..self,
      mode: DiffEditor,
      active_panel: None,
      status: "Diff editor active",
    }
  }
}

///|
fn CodeEditorModel::apply_completion(
  self : CodeEditorModel,
  index : Int,
) -> CodeEditorModel {
  if index < 0 || index >= self.completions.length() {
    return { ..self, completion_visible: false, status: "Completion dismissed" }
  }
  let item = self.completions[index]
  let caret = self.primary_offset()
  let start = code_editor_word_prefix_start(self.source, caret)
  let (source, cursors) = code_insert_text(
    self.source,
    [
      CodeCursor::new(
        position=caret,
        selection=Some(@text.TextRange::new(start~, end=caret)),
      ),
    ],
    item.insert_text,
  )
  {
    ..self.with_source(source),
    cursors,
    selection: None,
    completion_visible: false,
    status: "Inserted completion " + item.label,
  }
}

///|
fn side_panel_matches(
  current : CodeEditorSidePanel?,
  panel : CodeEditorSidePanel,
) -> Bool {
  match (current, panel) {
    (Some(CapabilitiesPanel), CapabilitiesPanel) => true
    (Some(IntelliSensePanel), IntelliSensePanel) => true
    _ => false
  }
}

///|
fn panel_status(panel : CodeEditorSidePanel) -> String {
  match panel {
    CapabilitiesPanel => "Capabilities panel active"
    IntelliSensePanel => "IntelliSense panel active"
  }
}

///|
fn CodeEditorModel::select_next_match(
  self : CodeEditorModel,
) -> CodeEditorModel {
  let find = self.find.recompute(self.source)
  if find.matches.is_empty() {
    return { ..self, find, selection: None, status: "No matches" }
  }
  let next_index = if find.active_index + 1 >= find.matches.length() {
    0
  } else {
    find.active_index + 1
  }
  let range = find.matches[next_index]
  {
    ..self,
    find: { ..find, active_index: next_index },
    selection: Some(range),
    cursors: [CodeCursor::new(position=range.end, selection=Some(range))],
    status: "Match \{next_index + 1}/\{find.matches.length()}",
  }
}

///|
fn CodeEditorModel::replace_all_matches(
  self : CodeEditorModel,
) -> CodeEditorModel {
  let find = self.find.recompute(self.source)
  let source = code_replace_all(self.source, find.query, find.replacement)
  let next_find = { ..find, active_index: -1 }.recompute(source)
  {
    ..self.with_source(source),
    find: next_find,
    selection: None,
    cursors: [CodeCursor::new(position=source.length())],
    status: "Replaced \{find.matches.length()} match(es)",
  }
}

///|
fn code_diagnostics(source : String) -> Array[CodeDiagnostic] {
  let diagnostics : Array[CodeDiagnostic] = []
  for range in code_find_matches(source, "unknown") {
    diagnostics.push({
      range,
      severity: Error,
      message: "Unresolved symbol `unknown`",
    })
  }
  if code_bracket_match(source, 0) is None &&
    source.contains("{") &&
    !source.contains("}") {
    diagnostics.push({
      range: @text.TextRange::collapsed(source.length()),
      severity: Warning,
      message: "Missing closing brace",
    })
  }
  diagnostics
}

///|
pub fn code_editor_features() -> Array[CodeEditorFeature] {
  [
    feature("Code highlighting", "Native tokenizer-backed rich text runs"),
    feature("Bracket matching", "Paired bracket lookup in the editor model"),
    feature(
      "Auto indentation", "Newline insertion preserves and extends indentation",
    ),
    feature(
      "Multi-cursor editing", "Batch insertion through sorted cursor positions",
    ),
    feature(
      "Find and replace", "Model-owned find panel and replace-all operation",
    ),
    feature("Keyboard shortcuts", "ActionCommand metadata for native hosts"),
    feature("IntelliSense", "Completion, hover, diagnostics, and definitions"),
    feature("Completion provider", "Per-language completion provider callback"),
    feature("Diagnostic provider", "Per-language diagnostics provider callback"),
    feature("Diagnostics", "Native diagnostics list with severity"),
    feature("Hover provider", "Per-language hover callback"),
    feature("Go to definition", "Per-language definition callback"),
    feature("Diff editor", "Line-based review and patch preview"),
    feature("Custom language", "Register calc or moui-script language ids"),
    feature(
      "Tokenizer registration", "Language provider owns tokenizer callback",
    ),
    feature(
      "Provider registration", "Completion/diagnostic/hover/definition provider callbacks",
    ),
  ]
}

///|
fn feature(label : String, detail : String) -> CodeEditorFeature {
  { label, detail }
}

///|
pub fn code_editor_action_commands() -> Array[@views.ActionCommand] {
  [
    @views.ActionCommand::new(
      intent=@views.CommandIntent::OpenContextMenu,
      label="Command Palette",
      shortcut=Some(
        @views.KeyboardShortcut::new(
          key="k",
          modifiers=@views.KeyModifiers::new(meta=true),
        ),
      ),
      group="Editor",
      description="Open native command palette metadata.",
    ),
    @views.ActionCommand::new(
      intent=@views.CommandIntent::Submit,
      label="Run Diagnostics",
      shortcut=Some(
        @views.KeyboardShortcut::new(
          key="b",
          modifiers=@views.KeyModifiers::new(meta=true),
        ),
      ),
      group="Code",
      description="Refresh diagnostics for the active document.",
    ),
    @views.ActionCommand::new(
      intent=@views.CommandIntent::Activate,
      label="Trigger Completion",
      shortcut=Some(
        @views.KeyboardShortcut::new(
          key="Space",
          modifiers=@views.KeyModifiers::new(control=true),
        ),
      ),
      group="Code",
      description="Ask the registered completion provider.",
    ),
  ]
}

///|
pub fn code_editor_document(
  source : String,
  language_id : String,
  registry : CodeLanguageRegistry,
  font : @text.FontSpec,
) -> @moui_richtext.RichTextDocument {
  let blocks : Array[@moui_richtext.RichTextBlock] = []
  let chars = source.to_array()
  let mut line_start = 0
  let mut index = 0
  while index < chars.length() {
    if chars[index] == '\n' {
      blocks.push(
        code_editor_line_block(
          String::from_array(chars[line_start:index]),
          line_start~,
          content_end=index,
          source_end=index + 1,
          language_id~,
          registry~,
          font~,
        ),
      )
      line_start = index + 1
    }
    index = index + 1
  }
  blocks.push(
    code_editor_line_block(
      String::from_array(chars[line_start:chars.length()]),
      line_start~,
      content_end=chars.length(),
      source_end=chars.length(),
      language_id~,
      registry~,
      font~,
    ),
  )
  @moui_richtext.RichTextDocument::new(blocks~)
}

///|
fn code_editor_line_block(
  line : String,
  line_start~ : Int,
  content_end~ : Int,
  source_end~ : Int,
  language_id~ : String,
  registry~ : CodeLanguageRegistry,
  font~ : @text.FontSpec,
) -> @moui_richtext.RichTextBlock {
  let runs : Array[@moui_richtext.RichTextRun] = []
  let mut start = line_start
  for token in registry.tokenize(language_id, line) {
    let end = start + token.text.length()
    runs.push(
      @moui_richtext.RichTextRun::new(
        text=token.text,
        font=Some(font),
        color=token_color(token.kind),
        source_range=Some({ start, end }),
      ),
    )
    start = end
  }
  if runs.is_empty() {
    runs.push(
      @moui_richtext.RichTextRun::new(
        text="",
        font=Some(font),
        source_range=Some({ start: line_start, end: line_start }),
      ),
    )
  }
  @moui_richtext.RichTextBlock::new(
    runs~,
    font=Some(font),
    source_range=Some({ start: line_start, end: source_end }),
    content_range=Some({ start: line_start, end: content_end }),
    line_height=Some(font.size * 1.42),
  )
}

///|
fn token_color(kind : String) -> @graphics.Color? {
  match kind {
    "keyword" => Some(@graphics.Color::rgba(r=0.36, g=0.32, b=0.78, a=1.0))
    "string" => Some(@graphics.Color::rgba(r=0.20, g=0.62, b=0.36, a=1.0))
    "comment" => Some(@graphics.Color::rgba(r=0.45, g=0.48, b=0.52, a=1.0))
    "number" => Some(@graphics.Color::rgba(r=0.78, g=0.52, b=0.18, a=1.0))
    "function" => Some(@graphics.Color::rgba(r=0.27, g=0.42, b=0.70, a=1.0))
    "type" => Some(@graphics.Color::rgba(r=0.22, g=0.63, b=0.58, a=1.0))
    "operator" => Some(@graphics.Color::rgba(r=0.78, g=0.22, b=0.22, a=1.0))
    "annotation" => Some(@graphics.Color::rgba(r=0.68, g=0.25, b=0.58, a=1.0))
    _ => None
  }
}
