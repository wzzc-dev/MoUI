///|
test "native code editor feature catalog covers requested capabilities" {
  let features = code_editor_features()
  assert_true(has_feature(features, "Code highlighting"))
  assert_true(has_feature(features, "Bracket matching"))
  assert_true(has_feature(features, "Auto indentation"))
  assert_true(has_feature(features, "Multi-cursor editing"))
  assert_true(has_feature(features, "Find and replace"))
  assert_true(has_feature(features, "Keyboard shortcuts"))
  assert_true(has_feature(features, "IntelliSense"))
  assert_true(has_feature(features, "Completion provider"))
  assert_true(has_feature(features, "Diagnostic provider"))
  assert_true(has_feature(features, "Diagnostics"))
  assert_true(has_feature(features, "Hover provider"))
  assert_true(has_feature(features, "Go to definition"))
  assert_true(has_feature(features, "Diff editor"))
  assert_true(has_feature(features, "Custom language"))
  assert_true(has_feature(features, "Tokenizer registration"))
  assert_true(has_feature(features, "Provider registration"))
}

///|
test "custom language registry invokes registered tokenizer and providers" {
  let registry = CodeLanguageRegistry::new().register_language(
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
        Some(
          CodeDefinition::new(symbol="let", file="calc.dsl", line=1, column=1),
        )
      },
    ),
  )
  let tokens = registry.tokenize("calc", "let total = 1")
  inspect(tokens.length(), content="1")
  inspect(tokens[0].kind, content="keyword")
  let completions = registry.completions("calc", "l", 1)
  inspect(completions.length(), content="1")
  inspect(completions[0].label, content="let")
  guard registry.hover("calc", "let total = 1", 1) is Some(hover) else {
    fail("expected registered hover provider")
  }
  inspect(hover.detail, content="Declares a Calc value.")
  guard registry.definition("calc", "let total = 1", 1) is Some(definition) else {
    fail("expected registered definition provider")
  }
  inspect(definition.file, content="calc.dsl")
}

///|
test "native code editor builds highlighted rich text document" {
  let registry = CodeLanguageRegistry::new().register_language(
    CodeLanguageProvider::new(
      id="calc",
      label="Calc DSL",
      tokenizer=_source => {
        [
          { text: "let", kind: "keyword" },
          { text: " total = 1", kind: "plain" },
        ]
      },
      completion_provider=(_source, _offset) => [],
      hover_provider=(_source, _offset) => None,
      definition_provider=(_source, _offset) => None,
    ),
  )
  let font = @text.FontSpec::new(
    families=@text.FontFamilyStack::monospace(),
    size=14.0,
  )
  let document = code_editor_document("let total = 1", "calc", registry, font)
  inspect(document.blocks.length(), content="1")
  inspect(document.blocks[0].runs.length(), content="2")
  inspect(document.blocks[0].runs[0].text, content="let")
  guard document.blocks[0].runs[0].color is Some(_) else {
    fail("expected keyword token to receive highlight color")
  }
  guard document.blocks[0].runs[0].source_range is Some(range) else {
    fail("expected keyword token to preserve source range")
  }
  inspect(range.start, content="0")
  inspect(range.end, content="3")
}

///|
test "native code editor document maps each source line to its own block" {
  let registry = CodeLanguageRegistry::new().register_language(
    CodeLanguageProvider::new(
      id="plain-code",
      label="Plain Code",
      tokenizer=source => [{ text: source, kind: "plain" }],
      completion_provider=(_source, _offset) => [],
      hover_provider=(_source, _offset) => None,
      definition_provider=(_source, _offset) => None,
    ),
  )
  let font = @text.FontSpec::new(
    families=@text.FontFamilyStack::monospace(),
    size=14.0,
  )
  let document = code_editor_document(
    "let a = 1\nlet b = 2", "plain-code", registry, font,
  )
  inspect(document.blocks.length(), content="2")
  inspect(document.blocks[0].runs[0].text, content="let a = 1")
  guard document.blocks[0].source_range is Some(first_source) else {
    fail("expected first line source range")
  }
  inspect(first_source.start, content="0")
  inspect(first_source.end, content="10")
  guard document.blocks[0].content_range is Some(first_content) else {
    fail("expected first line content range")
  }
  inspect(first_content.start, content="0")
  inspect(first_content.end, content="9")
  inspect(document.blocks[1].runs[0].text, content="let b = 2")
  guard document.blocks[1].source_range is Some(second_source) else {
    fail("expected second line source range")
  }
  inspect(second_source.start, content="10")
  inspect(second_source.end, content="19")
  guard document.blocks[1].content_range is Some(second_content) else {
    fail("expected second line content range")
  }
  inspect(second_content.start, content="10")
  inspect(second_content.end, content="19")
}

///|
test "native code editor exposes shortcut metadata for native hosts" {
  let commands = code_editor_action_commands()
  inspect(commands.length(), content="3")
  assert_true(has_shortcut(commands, "Command Palette", "k", meta=true))
  assert_true(has_shortcut(commands, "Run Diagnostics", "b", meta=true))
  assert_true(
    has_shortcut(commands, "Trigger Completion", "Space", control=true),
  )
  let map_commands = code_editor_action_command_map().commands()
  inspect(map_commands.length(), content="3")
}

///|
test "native code editor supports auto indent and multi-cursor edits" {
  let model = CodeEditorModel::new().with_source("fn main {").with_cursor(9)
  let indented = update(model, InsertText("\n"))
  inspect(indented.source, content="fn main {\n  ")
  inspect(indented.cursors.length(), content="1")
  inspect(indented.cursors[0].position, content="12")

  let multicursor = CodeEditorModel::new()
    .with_source("alpha\nbeta\n")
    .with_cursors([CodeCursor::new(position=0), CodeCursor::new(position=6)])
  let edited = update(multicursor, InsertText("// "))
  inspect(edited.source, content="// alpha\n// beta\n")
  inspect(edited.cursors.length(), content="2")
  inspect(edited.cursors[0].position, content="3")
  inspect(edited.cursors[1].position, content="12")

  let selected = CodeEditorModel::new()
    .with_source("alpha beta")
    .with_cursors([
      CodeCursor::new(
        position=5,
        selection=Some(@text.TextRange::new(start=0, end=5)),
      ),
      CodeCursor::new(
        position=10,
        selection=Some(@text.TextRange::new(start=6, end=10)),
      ),
    ])
  let replaced = update(selected, InsertText("x"))
  inspect(replaced.source, content="x x")
  inspect(replaced.cursors.length(), content="2")
  inspect(replaced.cursors[0].position, content="1")
  inspect(replaced.cursors[1].position, content="3")
}

///|
test "native code editor finds replaces and builds review diffs" {
  let model = CodeEditorModel::new()
    .with_source("let count = 1\nlet total = count + 1\n")
    .with_find("count")
    .with_replace("value")
  let found = update(model, FindNext)
  inspect(found.find.matches.length(), content="2")
  guard found.selection is Some(range) else {
    fail("expected first find match to be selected")
  }
  inspect(range.start, content="4")
  inspect(range.end, content="9")
  let replaced = update(found, ReplaceAll)
  inspect(replaced.source, content="let value = 1\nlet total = value + 1\n")
  inspect(replaced.find.matches.length(), content="0")

  let diff = code_diff(
    "fn add(a, b) {\n  a + b\n}\n", "fn add(a, b) {\n  return a + b\n}\n",
  )
  inspect(diff.lines.length(), content="4")
  inspect(diff.lines[1].kind.label(), content="Removed")
  inspect(diff.lines[2].kind.label(), content="Added")

  let inserted = code_diff("a\nb\nc\n", "a\nx\nb\nc\n")
  inspect(inserted.lines.length(), content="4")
  inspect(inserted.lines[0].kind.label(), content="Context")
  inspect(inserted.lines[1].kind.label(), content="Added")
  inspect(inserted.lines[2].kind.label(), content="Context")
  inspect(inserted.lines[3].kind.label(), content="Context")
  guard inserted.lines[1].old_line is None else {
    fail("expected inserted line to have no old line")
  }
  guard inserted.lines[1].new_line is Some(inserted_new_line) else {
    fail("expected inserted line to have a new line")
  }
  inspect(inserted_new_line, content="2")
  guard inserted.lines[2].old_line is Some(context_old_line) else {
    fail("expected aligned context line to have an old line")
  }
  inspect(context_old_line, content="2")
  guard inserted.lines[2].new_line is Some(context_new_line) else {
    fail("expected aligned context line to have a new line")
  }
  inspect(context_new_line, content="3")
}

///|
test "native code editor produces diagnostics hover definitions and completions" {
  let model = CodeEditorModel::new()
    .with_source("fn main {\n  print(unknown)\n}\n")
    .with_cursor(14)
  let diagnosed = update(model, RunDiagnostics)
  inspect(diagnosed.diagnostics.length(), content="1")
  inspect(diagnosed.diagnostics[0].severity.label(), content="Error")
  let completed = update(diagnosed, TriggerCompletion)
  assert_true(completed.completions.any(item => item.label == "println"))
  let hovered = update(completed, ShowHover)
  guard hovered.hover is Some(hover) else { fail("expected hover result") }
  assert_true(hover.detail.contains("Print"))
  let jumped = update(hovered, GoToDefinition)
  guard jumped.definition is Some(definition) else {
    fail("expected definition result")
  }
  inspect(definition.symbol, content="print")
}

///|
test "native code editor matches brackets around the caret" {
  guard code_bracket_match("fn main {\n  value\n}\n", 9) is Some(after_open) else {
    fail("expected bracket match when caret is after opening brace")
  }
  inspect(after_open.open, content="8")
  inspect(after_open.close, content="18")
  guard code_bracket_match("fn main {\n  value\n}\n", 18) is Some(on_close) else {
    fail("expected bracket match when caret is on closing brace")
  }
  inspect(on_close.open, content="8")
  inspect(on_close.close, content="18")
}

///|
test "registered language provider can supply diagnostics" {
  let registry = CodeLanguageRegistry::new().register_language(
    CodeLanguageProvider::new(
      id="calc",
      label="Calc DSL",
      tokenizer=source => [{ text: source, kind: "plain" }],
      completion_provider=(_source, _offset) => [],
      hover_provider=(_source, _offset) => None,
      definition_provider=(_source, _offset) => None,
      diagnostic_provider=source => {
        code_find_matches(source, "todo").map(range => {
          range,
          severity: Warning,
          message: "Calc todo marker",
        })
      },
    ),
  )
  let model = {
    ..CodeEditorModel::new().with_source("let todo = 1"),
    registry,
    language_id: "calc",
  }
  let diagnosed = update(model, RunDiagnostics)
  inspect(diagnosed.diagnostics.length(), content="1")
  inspect(diagnosed.diagnostics[0].severity.label(), content="Warning")
  inspect(diagnosed.diagnostics[0].message, content="Calc todo marker")
}

///|
test "native code editor computes line column and line metadata" {
  let source = "fn add(a, b) {\n  a + b\n}\n"
  let lines = code_editor_source_lines(source)
  inspect(lines.length(), content="3")
  inspect(lines[0].number, content="1")
  inspect(lines[0].start, content="0")
  inspect(lines[0].end, content="15")
  inspect(lines[1].number, content="2")
  inspect(lines[1].start, content="15")
  inspect(lines[1].end, content="23")
  let at_start = code_editor_caret_position(source, 0)
  inspect(at_start.line, content="1")
  inspect(at_start.column, content="1")
  let second_line = code_editor_caret_position(source, 17)
  inspect(second_line.line, content="2")
  inspect(second_line.column, content="3")
}

///|
test "native code editor maps diagnostics to one based source lines" {
  let diagnostics : Array[CodeDiagnostic] = [
    {
      range: @text.TextRange::new(start=17, end=22),
      severity: Error,
      message: "bad value",
    },
  ]
  let lines = code_editor_diagnostic_lines(
    "fn main {\n  bad()\n}\n", diagnostics,
  )
  inspect(lines.length(), content="1")
  inspect(lines[0], content="2")
}

///|
test "native code editor ui state toggles editor panels and modes" {
  let model = CodeEditorModel::new()
  guard model.active_panel is None else {
    fail("expected side panels to be hidden by default")
  }
  inspect(model.mode.label(), content="Source Editor")
  inspect(model.find_visible, content="false")
  inspect(model.completion_visible, content="false")

  let finding = update(model, ToggleFind)
  inspect(finding.find_visible, content="true")
  inspect(update(finding, CloseFind).find_visible, content="false")

  let capabilities = update(model, ToggleCapabilities)
  inspect(capabilities.active_panel is Some(CapabilitiesPanel), content="true")
  guard update(capabilities, ToggleCapabilities).active_panel is None else {
    fail("expected clicking the active capabilities button to hide the panel")
  }
  let intellisense = update(model, ToggleIntelliSense)
  inspect(intellisense.active_panel is Some(IntelliSensePanel), content="true")
  let diff = update(model, ToggleDiffEditor)
  inspect(diff.mode.label(), content="Diff Editor")
  guard diff.active_panel is None else {
    fail("expected diff to be a main editor mode, not a side panel")
  }
}

///|
test "native code editor applies completion item and closes overlay" {
  let model = CodeEditorModel::new()
    .with_source("fn main {\n  prin\n}\n")
    .with_cursor(16)
  let completed = update(model, TriggerCompletion)
  inspect(completed.completion_visible, content="true")
  assert_true(completed.completions.any(item => item.label == "println"))

  let applied = update(completed, ApplyCompletion(0))
  inspect(applied.completion_visible, content="false")
  assert_true(applied.source.contains("println"))
}

///|
test "native code editor runtime renders editor shell by default without platform views" {
  let runtime = test_runtime(program(), width=1180.0, height=760.0)
  let frame = runtime.draw_frame()
  inspect(frame.platform_views.length(), content="0")
  assert_true(has_draw_text(frame.commands, "main.mbt"))
  assert_true(has_draw_text(frame.commands, "1"))
  assert_true(has_draw_text(frame.commands, "Ln 5, Col 1"))
  assert_true(has_draw_text(frame.commands, "MoonBit"))
  guard draw_text_color(frame.commands, "Search") is Some(search_color) else {
    fail("expected Search toolbar text to render")
  }
  assert_true(code_editor_test_is_light_text(search_color))
  assert_false(has_draw_text(frame.commands, "Code highlighting"))
  assert_false(has_draw_text(frame.commands, "Completion provider"))
  assert_false(has_draw_text(frame.commands, "Multi Cursor"))
}

///|
test "native code editor runtime renders find and completion overlays on demand" {
  let find_runtime = test_runtime(
    @moui.Program::simple(
      init=update(CodeEditorModel::new(), ToggleFind),
      update~,
      view~,
    ),
    width=1180.0,
    height=760.0,
  )
  let find_frame = find_runtime.draw_frame()
  assert_true(has_draw_text(find_frame.commands, "Find"))
  assert_true(has_draw_text(find_frame.commands, "Replace"))

  let completion_runtime = test_runtime(
    @moui.Program::simple(
      init=update(CodeEditorModel::new(), TriggerCompletion),
      update~,
      view~,
    ),
    width=1180.0,
    height=760.0,
  )
  let completion_frame = completion_runtime.draw_frame()
  assert_true(has_draw_text(completion_frame.commands, "println"))
  assert_false(has_draw_text(completion_frame.commands, "Completion provider"))
}

///|
test "native code editor runtime renders panels and diff as editor mode" {
  let capabilities_runtime = test_runtime(
    @moui.Program::simple(
      init=update(CodeEditorModel::new(), ToggleCapabilities),
      update~,
      view~,
    ),
    width=1180.0,
    height=760.0,
  )
  let capabilities_frame = capabilities_runtime.draw_frame()
  assert_true(has_draw_text(capabilities_frame.commands, "Code highlighting"))
  assert_true(has_draw_text(capabilities_frame.commands, "main.mbt"))

  let intellisense_runtime = test_runtime(
    @moui.Program::simple(
      init=update(CodeEditorModel::new(), ToggleIntelliSense),
      update~,
      view~,
    ),
    width=1180.0,
    height=760.0,
  )
  let intellisense_frame = intellisense_runtime.draw_frame()
  assert_true(has_draw_text(intellisense_frame.commands, "Completion provider"))
  assert_true(has_draw_text(intellisense_frame.commands, "main.mbt"))

  let diff_runtime = test_runtime(
    @moui.Program::simple(
      init=update(CodeEditorModel::new(), ToggleDiffEditor),
      update~,
      view~,
    ),
    width=1180.0,
    height=760.0,
  )
  let diff_frame = diff_runtime.draw_frame()
  assert_true(has_draw_text(diff_frame.commands, "Original"))
  assert_true(has_draw_text(diff_frame.commands, "Modified"))
  assert_true(has_draw_text(diff_frame.commands, "+   return a + b"))
  assert_true(has_draw_text(diff_frame.commands, "+ fn main {"))
}

///|
fn has_feature(features : Array[CodeEditorFeature], label : String) -> Bool {
  features.any(feature => feature.label == label)
}

///|
fn has_shortcut(
  commands : Array[@views.ActionCommand],
  label : String,
  key : String,
  meta? : Bool = false,
  control? : Bool = false,
) -> Bool {
  commands.any(command => {
    command.label == label &&
    command.shortcut is Some(shortcut) &&
    shortcut.key == key &&
    shortcut.modifiers.meta == meta &&
    shortcut.modifiers.control == control
  })
}

///|
fn has_draw_text(commands : Array[@core.DrawCommand], text : String) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) && value == text
  })
}

///|
fn draw_text_color(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Color? {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, color, .. }) =>
        if value == text {
          return Some(color)
        }
      _ => ()
    }
  }
  None
}

///|
fn code_editor_test_is_light_text(color : @core.Color) -> Bool {
  color.a > 0.9 && (color.r + color.g + color.b) / 3.0 > 0.65
}

///|
fn test_runtime(
  program : @moui.Program[CodeEditorModel, CodeEditorMsg],
  width~ : Double,
  height~ : Double,
) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(program~, width~, height~)
}
