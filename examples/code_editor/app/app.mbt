///|
using @views {
  button,
  column,
  container,
  expanded,
  overlay,
  row,
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
  editor_scroll : @state.ScrollState
  diff_scroll : @state.ScrollState
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
  SetFindQuery(String)
  SetReplaceText(String)
  FindNext
  ReplaceAll
  RunDiagnostics
  TriggerCompletion
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
    editor_scroll: @state.ScrollState::new(),
    diff_scroll: @state.ScrollState::new(),
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
pub fn code_editor_action_command_map() -> @views.ActionCommandMap {
  @views.ActionCommandMap::new(
    bindings=code_editor_action_commands().map(command => {
      @views.CommandBinding::new(command~, handle=() => ())
    }),
  )
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

///|
pub fn view(model : CodeEditorModel) -> @moui.View[CodeEditorMsg] {
  let theme = editor_theme()
  let editor_font = @text.FontSpec::new(
    families=@text.FontFamilyStack::monospace(),
    size=14.0,
  )
  let workspace : Array[@moui.View[CodeEditorMsg]] = [
    activity_rail(model, theme),
    expanded(editor_shell(model, theme, editor_font)),
  ]
  match model.active_panel {
    Some(panel) => workspace.push(side_panel_view(model, panel, theme))
    None => ()
  }
  row(workspace, spacing=0.0, align=@views.CrossAlign::Stretch)
  .padding(0.0)
  .background(editor_chrome_background())
}

///|
fn editor_theme() -> @moui.Theme {
  @views.dark_theme()
}

///|
fn activity_rail(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  container(
    column(
      [
        panel_button(
          "C",
          ToggleCapabilities,
          side_panel_matches(model.active_panel, CapabilitiesPanel),
          theme,
        ),
        panel_button(
          "I",
          ToggleIntelliSense,
          side_panel_matches(model.active_panel, IntelliSensePanel),
          theme,
        ),
        panel_button("D", ToggleDiffEditor, model.mode == DiffEditor, theme),
        panel_button("F", ToggleFind, model.find_visible, theme),
      ],
      spacing=8.0,
      align=@views.CrossAlign::Center,
    ),
    width=54.0,
    background=editor_rail_background(),
    padding=8.0,
  )
}

///|
fn panel_button(
  label : String,
  message : CodeEditorMsg,
  active : Bool,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  button(
    label,
    on_click=message,
    variant=if active {
      @views.ButtonVariant::Primary
    } else {
      @views.ButtonVariant::Tonal
    },
    theme~,
    width=38.0,
    height=34.0,
  )
}

///|
fn side_panel_view(
  model : CodeEditorModel,
  panel : CodeEditorSidePanel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  match panel {
    CapabilitiesPanel => capabilities_panel(model, theme)
    IntelliSensePanel => intellisense_panel(model, theme)
  }
}

///|
fn editor_shell(
  model : CodeEditorModel,
  theme : @moui.Theme,
  editor_font : @text.FontSpec,
) -> @moui.View[CodeEditorMsg] {
  column(
    [
      editor_tab_bar(model, theme),
      expanded(
        match model.mode {
          DiffEditor => diff_editor_main(model, theme)
          _ => code_editor_surface(model, theme, editor_font)
        },
      ),
      editor_status(model, theme),
    ],
    spacing=0.0,
  ).background(editor_panel_background())
}

///|
fn editor_tab_bar(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  container(
    row(
      [
        button(
          "main.mbt",
          on_click=SetMode(SourceEditor),
          variant=if model.mode == SourceEditor {
            @views.ButtonVariant::Primary
          } else {
            @views.ButtonVariant::Ghost
          },
          theme~,
          width=116.0,
          height=34.0,
        ),
        button(
          "diff",
          on_click=ToggleDiffEditor,
          variant=if model.mode == DiffEditor {
            @views.ButtonVariant::Primary
          } else {
            @views.ButtonVariant::Ghost
          },
          theme~,
          width=78.0,
          height=34.0,
        ),
        spacer(min_length=12.0),
        button(
          "Search",
          on_click=ToggleFind,
          variant=@views.ButtonVariant::Ghost,
          theme~,
          width=86.0,
          height=34.0,
        ),
        button(
          "Complete",
          on_click=TriggerCompletion,
          variant=@views.ButtonVariant::Ghost,
          theme~,
          width=96.0,
          height=34.0,
        ),
        button(
          "Problems",
          on_click=ToggleIntelliSense,
          variant=@views.ButtonVariant::Ghost,
          theme~,
          width=98.0,
          height=34.0,
        ),
        button(
          "Info",
          on_click=ToggleCapabilities,
          variant=@views.ButtonVariant::Ghost,
          theme~,
          width=70.0,
          height=34.0,
        ),
      ],
      spacing=4.0,
      align=@views.CrossAlign::Center,
    ),
    height=44.0,
    background=editor_tab_background(),
    padding=5.0,
  )
}

///|
fn code_editor_surface(
  model : CodeEditorModel,
  theme : @moui.Theme,
  editor_font : @text.FontSpec,
) -> @moui.View[CodeEditorMsg] {
  let viewport_height = 520.0
  let editor = @moui_richtext.controlled_rich_text_editor(
    value=model.source,
    on_input=value => SourceChanged(value),
    placeholder="Write native code",
    size=@geometry.Size::new(width=850.0, height=viewport_height),
    format=source => {
      code_editor_document(
        source,
        model.language_id,
        model.registry,
        editor_font,
      )
    },
    font=editor_font,
    foreground=editor_text_color(),
    placeholder_color=theme.palette.muted,
    background=@graphics.Brush::solid(editor_surface_background()),
    cursor_color=theme.palette.primary,
    corner_radius=0.0,
    on_selection_change=Some((caret, range) => SelectionChanged(caret, range)),
    input_transform=Some((source, caret, selection, inserted) => {
      if inserted == "\n" {
        let (text, cursors) = code_insert_text(
          source,
          [CodeCursor::new(position=caret, selection~)],
          inserted,
        )
        let next_caret = match cursors {
          [cursor, ..] => cursor.position
          [] => caret
        }
        Some(
          @moui_richtext.RichTextInputTransform::new(
            text~,
            caret=next_caret,
            selection=None,
          ),
        )
      } else {
        None
      }
    }),
    accepts_tab_input=true,
    visible_scroll_state=Some(model.editor_scroll),
    visible_viewport_height=viewport_height,
    visible_overscan=160.0,
    selection_caret=model.primary_offset(),
    selection_range=model.selection,
    kind="NativeCodeEditor",
    key=Some("native-code-editor"),
  )
  let base = container(
    row(
      [line_number_gutter(model, theme, viewport_height), editor],
      spacing=0.0,
      align=@views.CrossAlign::Stretch,
    ),
    background=editor_surface_background(),
  )
  let with_completion = if model.completion_visible {
    overlay(
      base,
      completion_overlay(model, theme).offset(
        dx=completion_overlay_x(model),
        dy=completion_overlay_y(model),
      ),
    )
  } else {
    base
  }
  if model.find_visible {
    overlay(
      with_completion,
      find_overlay(model, theme).offset(dx=430.0, dy=14.0),
    )
  } else {
    with_completion
  }
}

///|
fn line_number_gutter(
  model : CodeEditorModel,
  theme : @moui.Theme,
  viewport_height : Double,
) -> @moui.View[CodeEditorMsg] {
  let active = code_editor_caret_position(model.source, model.primary_offset()).line
  let diagnostic_lines = code_editor_diagnostic_lines(
    model.source,
    model.diagnostics,
  )
  let rows : Array[@moui.View[CodeEditorMsg]] = []
  for line in code_editor_source_lines(model.source) {
    let marker = if diagnostic_lines.contains(line.number) { "!" } else { " " }
    rows.push(
      container(
        text(
          marker + " " + line.number.to_string(),
          role=@views.TextRole::Mono,
          theme~,
          width=48.0,
          height=20.0,
        ).foreground(
          if line.number == active {
            theme.palette.foreground
          } else {
            theme.palette.muted
          },
        ),
        width=56.0,
        height=20.0,
        background=if line.number == active {
          editor_active_line_background()
        } else {
          editor_gutter_background()
        },
      ),
    )
  }
  scroll_view(
    column(rows, spacing=0.0),
    width=58.0,
    height=viewport_height,
    state=Some(model.editor_scroll),
  )
}

///|
fn completion_overlay(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  let rows : Array[@moui.View[CodeEditorMsg]] = []
  if model.completions.is_empty() {
    rows.push(
      text("No completions", role=@views.TextRole::Caption, theme~, width=240.0),
    )
  } else {
    for index in 0..<model.completions.length() {
      let item = model.completions[index]
      rows.push(
        button(
          item.label,
          on_click=ApplyCompletion(index),
          variant=if index == 0 {
            @views.ButtonVariant::Primary
          } else {
            @views.ButtonVariant::Ghost
          },
          theme~,
          width=240.0,
          height=30.0,
        ),
      )
    }
  }
  container(
    column(rows, spacing=2.0),
    width=260.0,
    background=editor_popup_background(),
    padding=8.0,
  ).border(
    @graphics.BorderStyle::new(
      brush=@graphics.Brush::solid(theme.palette.outline),
    ),
  )
}

///|
fn find_overlay(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  container(
    row(
      [
        text(
          "Find",
          role=@views.TextRole::Caption,
          theme~,
          width=38.0,
          height=30.0,
        ),
        text_field(
          model.find.query,
          on_input=value => SetFindQuery(value),
          placeholder="Find",
          variant=@views.TextFieldVariant::Outline,
          theme~,
          width=150.0,
          height=32.0,
        ),
        text(
          "Replace",
          role=@views.TextRole::Caption,
          theme~,
          width=58.0,
          height=30.0,
        ),
        text_field(
          model.find.replacement,
          on_input=value => SetReplaceText(value),
          placeholder="Replace",
          variant=@views.TextFieldVariant::Outline,
          theme~,
          width=150.0,
          height=32.0,
        ),
        button(
          "Next",
          on_click=FindNext,
          variant=@views.ButtonVariant::Tonal,
          theme~,
          width=68.0,
          height=32.0,
        ),
        button(
          "All",
          on_click=ReplaceAll,
          variant=@views.ButtonVariant::Outline,
          theme~,
          width=62.0,
          height=32.0,
        ),
        button(
          "x",
          on_click=CloseFind,
          variant=@views.ButtonVariant::Ghost,
          theme~,
          width=36.0,
          height=32.0,
        ),
      ],
      spacing=6.0,
      align=@views.CrossAlign::Center,
    ),
    background=editor_popup_background(),
    padding=8.0,
  ).border(
    @graphics.BorderStyle::new(
      brush=@graphics.Brush::solid(theme.palette.outline),
    ),
  )
}

///|
fn editor_status(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  let position = code_editor_caret_position(
    model.source,
    model.primary_offset(),
  )
  status_bar(
    [
      "Ln \{position.line}, Col \{position.column}",
      code_editor_language_label(model.language_id),
      "\{model.cursors.length()} cursor(s)",
      "\{model.diagnostics.length()} diagnostic(s)",
      model.status,
    ],
    theme~,
    width=1080.0,
    height=30.0,
  )
}

///|
fn diff_editor_main(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  let diff = code_diff(model.original_source, model.source)
  container(
    row(
      [
        diff_column("Original", diff, old=true, theme, model.diff_scroll),
        diff_column("Modified", diff, old=false, theme, model.diff_scroll),
      ],
      spacing=1.0,
      align=@views.CrossAlign::Stretch,
    ),
    background=editor_surface_background(),
    padding=12.0,
  )
}

///|
fn diff_column(
  title : String,
  diff : CodeDiff,
  old~ : Bool,
  theme : @moui.Theme,
  scroll : @state.ScrollState,
) -> @moui.View[CodeEditorMsg] {
  let rows : Array[@moui.View[CodeEditorMsg]] = [
    container(
      text(
        title,
        role=@views.TextRole::Control,
        theme~,
        width=420.0,
        height=28.0,
      ),
      background=editor_tab_background(),
      padding=4.0,
    ),
  ]
  for line in diff.lines {
    let number = if old { line.old_line } else { line.new_line }
    let visible = match line.kind {
      Added => !old
      Removed => old
      Context => true
    }
    let label = match number {
      Some(value) => value.to_string()
      None => ""
    }
    let content = if visible { diff_prefix(line.kind) + line.text } else { "" }
    rows.push(
      container(
        row(
          [
            text(
              label,
              role=@views.TextRole::Mono,
              theme~,
              width=42.0,
              height=22.0,
            ).foreground(theme.palette.muted),
            text(
              content,
              role=@views.TextRole::Mono,
              theme~,
              width=370.0,
              height=22.0,
            ).foreground(diff_color(line.kind, theme)),
          ],
          spacing=4.0,
          align=@views.CrossAlign::Center,
        ),
        background=diff_line_background(line.kind, old, visible),
      ),
    )
  }
  scroll_view(
    column(rows, spacing=0.0),
    width=470.0,
    height=520.0,
    state=Some(scroll),
  )
}

///|
fn completion_overlay_x(model : CodeEditorModel) -> Double {
  let position = code_editor_caret_position(
    model.source,
    model.primary_offset(),
  )
  let raw = 68.0 + (position.column - 1).to_double() * 8.4
  if raw > 680.0 {
    680.0
  } else {
    raw
  }
}

///|
fn completion_overlay_y(model : CodeEditorModel) -> Double {
  let position = code_editor_caret_position(
    model.source,
    model.primary_offset(),
  )
  let raw = 46.0 +
    (position.line - 1).to_double() * 20.0 -
    model.editor_scroll.offset().y
  if raw < 34.0 {
    34.0
  } else {
    raw
  }
}

///|
fn code_editor_language_label(language_id : String) -> String {
  match language_id {
    "moonbit" => "MoonBit"
    "moui-script" => "MoUI Script"
    "calc" => "Calc DSL"
    _ => language_id
  }
}

///|
fn editor_chrome_background() -> @graphics.Color {
  @graphics.Color::rgba(r=0.10, g=0.11, b=0.13, a=1.0)
}

///|
fn editor_rail_background() -> @graphics.Color {
  @graphics.Color::rgba(r=0.08, g=0.09, b=0.10, a=1.0)
}

///|
fn editor_panel_background() -> @graphics.Color {
  @graphics.Color::rgba(r=0.12, g=0.13, b=0.15, a=1.0)
}

///|
fn editor_tab_background() -> @graphics.Color {
  @graphics.Color::rgba(r=0.16, g=0.17, b=0.19, a=1.0)
}

///|
fn editor_surface_background() -> @graphics.Color {
  @graphics.Color::rgba(r=0.11, g=0.12, b=0.14, a=1.0)
}

///|
fn editor_gutter_background() -> @graphics.Color {
  @graphics.Color::rgba(r=0.10, g=0.11, b=0.13, a=1.0)
}

///|
fn editor_active_line_background() -> @graphics.Color {
  @graphics.Color::rgba(r=0.18, g=0.19, b=0.20, a=1.0)
}

///|
fn editor_popup_background() -> @graphics.Color {
  @graphics.Color::rgba(r=0.18, g=0.19, b=0.22, a=1.0)
}

///|
fn editor_text_color() -> @graphics.Color {
  @graphics.Color::rgba(r=0.86, g=0.88, b=0.86, a=1.0)
}

///|
fn diff_line_background(
  kind : CodeDiffLineKind,
  old : Bool,
  visible : Bool,
) -> @graphics.Color {
  if !visible {
    return editor_surface_background()
  }
  match (kind, old) {
    (Removed, true) => @graphics.Color::rgba(r=0.27, g=0.10, b=0.11, a=1.0)
    (Added, false) => @graphics.Color::rgba(r=0.09, g=0.22, b=0.15, a=1.0)
    _ => editor_surface_background()
  }
}

///|
fn capabilities_panel(
  _model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  let rows : Array[@moui.View[CodeEditorMsg]] = [
    text("Capabilities", role=@views.TextRole::Control, theme~, width=232.0),
  ]
  for item in code_editor_features() {
    rows.push(
      column(
        [
          text(
            item.label,
            role=@views.TextRole::Caption,
            theme~,
            width=232.0,
            height=22.0,
          ),
          text(
            item.detail,
            role=@views.TextRole::Caption,
            theme~,
            width=232.0,
            height=30.0,
          ).foreground(theme.palette.muted),
        ],
        spacing=0.0,
      ),
    )
  }
  container(
    scroll_view(column(rows, spacing=8.0), width=252.0, height=438.0),
    width=268.0,
    padding=12.0,
  ).border(
    @graphics.BorderStyle::new(
      brush=@graphics.Brush::solid(theme.palette.outline),
    ),
  )
}

///|
fn intellisense_panel(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  container(
    column(
      [
        text("IntelliSense", role=@views.TextRole::Control, theme~, width=260.0),
        text(
          "Completion provider",
          role=@views.TextRole::Caption,
          theme~,
          width=260.0,
        ),
        completion_list(model, theme),
        text("Diagnostics", role=@views.TextRole::Caption, theme~, width=260.0),
        diagnostic_list(model, theme),
        text(
          "Bracket Match",
          role=@views.TextRole::Caption,
          theme~,
          width=260.0,
        ),
        bracket_match_view(model, theme),
        text("Hover", role=@views.TextRole::Caption, theme~, width=260.0),
        hover_view(model, theme),
        text("Definition", role=@views.TextRole::Caption, theme~, width=260.0),
        definition_view(model, theme),
        button(
          "Go to Definition",
          on_click=GoToDefinition,
          variant=@views.ButtonVariant::Tonal,
          theme~,
          width=160.0,
        ),
        button(
          "Register Custom Language",
          on_click=RegisterSampleLanguage,
          variant=@views.ButtonVariant::Outline,
          theme~,
          width=220.0,
        ),
      ],
      spacing=8.0,
    ),
    width=292.0,
    padding=12.0,
  ).border(
    @graphics.BorderStyle::new(
      brush=@graphics.Brush::solid(theme.palette.outline),
    ),
  )
}

///|
fn completion_list(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  let rows : Array[@moui.View[CodeEditorMsg]] = []
  if model.completions.is_empty() {
    rows.push(
      text(
        "No completions yet",
        role=@views.TextRole::Caption,
        theme~,
        width=252.0,
      ).foreground(theme.palette.muted),
    )
  } else {
    for item in model.completions {
      rows.push(
        text(
          item.label + " - " + item.detail,
          role=@views.TextRole::Caption,
          theme~,
          width=252.0,
          height=24.0,
        ),
      )
    }
  }
  column(rows, spacing=4.0)
}

///|
fn diagnostic_list(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  let rows : Array[@moui.View[CodeEditorMsg]] = []
  if model.diagnostics.is_empty() {
    rows.push(
      text("No diagnostics", role=@views.TextRole::Caption, theme~, width=252.0).foreground(
        theme.palette.muted,
      ),
    )
  } else {
    for item in model.diagnostics {
      rows.push(
        text(
          item.severity.label() + ": " + item.message,
          role=@views.TextRole::Caption,
          theme~,
          width=252.0,
          height=28.0,
        ),
      )
    }
  }
  column(rows, spacing=4.0)
}

///|
fn bracket_match_view(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  let detail = match model.bracket_match {
    Some(value) => "open \{value.open}, close \{value.close}"
    None => "No active bracket pair"
  }
  text(detail, role=@views.TextRole::Caption, theme~, width=252.0, height=28.0).foreground(
    if model.bracket_match is Some(_) {
      theme.palette.foreground
    } else {
      theme.palette.muted
    },
  )
}

///|
fn hover_view(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  let detail = match model.hover {
    Some(value) => value.detail
    None => "No hover result"
  }
  text(detail, role=@views.TextRole::Caption, theme~, width=252.0, height=38.0).foreground(
    if model.hover is Some(_) {
      theme.palette.foreground
    } else {
      theme.palette.muted
    },
  )
}

///|
fn definition_view(
  model : CodeEditorModel,
  theme : @moui.Theme,
) -> @moui.View[CodeEditorMsg] {
  let detail = match model.definition {
    Some(value) =>
      value.symbol + " -> " + value.file + ":\{value.line}:\{value.column}"
    None => "No definition result"
  }
  text(detail, role=@views.TextRole::Caption, theme~, width=252.0, height=38.0).foreground(
    if model.definition is Some(_) {
      theme.palette.foreground
    } else {
      theme.palette.muted
    },
  )
}

///|
fn diff_prefix(kind : CodeDiffLineKind) -> String {
  match kind {
    Context => "  "
    Added => "+ "
    Removed => "- "
  }
}

///|
fn diff_color(kind : CodeDiffLineKind, theme : @moui.Theme) -> @graphics.Color {
  match kind {
    Context => theme.palette.foreground
    Added => @graphics.Color::rgba(r=0.10, g=0.50, b=0.25, a=1.0)
    Removed => @graphics.Color::rgba(r=0.72, g=0.16, b=0.16, a=1.0)
  }
}

///|
pub fn program() -> @moui.Program[CodeEditorModel, CodeEditorMsg] {
  @moui.Program::simple(init=CodeEditorModel::new(), update~, view~)
}

///|
fn sample_original_source() -> String {
  "fn add(a, b) {\n  a + b\n}\n"
}

///|
fn sample_source() -> String {
  "fn add(a, b) {\n  return a + b\n}\n\nfn main {\n  println(add(1, 2))\n}\n"
}

///|
fn sample_provider() -> CodeLanguageProvider {
  CodeLanguageProvider::new(
    id="calc",
    label="Calc DSL",
    tokenizer=source => {
      [
        {
          text: source,
          kind: if source.contains("let") {
            "keyword"
          } else {
            "plain"
          },
        },
      ]
    },
    completion_provider=(_source, _offset) => {
      [CodeCompletionItem::new(label="let", insert_text="let value = ")]
    },
    hover_provider=(_source, _offset) => {
      Some(CodeHover::new(symbol="let", detail="Declares a Calc value."))
    },
    definition_provider=(_source, _offset) => {
      Some(CodeDefinition::new(symbol="let", file="calc.dsl", line=1, column=1))
    },
  )
}
