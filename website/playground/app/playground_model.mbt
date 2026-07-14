///|
pub(all) enum PlaygroundFile {
  Main
  Package
} derive(Eq)

///|
pub(all) enum Msg {
  SourceChanged(String)
  PackageChanged(String)
  SelectFile(PlaygroundFile)
  SelectExample(String)
  SetFindQuery(String)
  SetReplaceText(String)
  EditorSelectionChanged(Int, @text.TextRange?)
  ReplaceAll
  FindNext
  Run
  Share
  Stop
  Reset
  LoadProject(String)
  CompilerStatus(String)
  CompileFinished(CompileResult)
}

///|
pub(all) struct Model {
  editor : @code_editor.EditorState
  editor_scroll : @state.ScrollState
  moon_pkg : String
  active_file : PlaygroundFile
  find_query : String
  replace_text : String
  show_find : Bool
  status : String
  preview_status : String
  lesson_id : String
  revision : Int
}

///|
pub fn Model::new() -> Model {
  let source = default_source()
  {
    editor: @code_editor.EditorState::new(source~),
    editor_scroll: @state.ScrollState::new(),
    moon_pkg: default_moon_pkg(),
    active_file: Main,
    find_query: "",
    replace_text: "",
    show_find: false,
    status: "Ready",
    preview_status: "Preview is idle",
    lesson_id: "01-hello-world",
    revision: 0,
  }
}

///|
pub fn update(model : Model, message : Msg) -> Model {
  match message {
    SourceChanged(source) => {
      let editor = match model.active_file {
        Main => model.editor.with_source(source)
        Package => model.editor
      }
      {
        ..model,
        editor,
        status: "Unsaved changes",
        preview_status: "Run to preview",
        revision: model.revision + 1,
      }
    }
    PackageChanged(value) =>
      {
        ..model,
        moon_pkg: value,
        status: "Package configuration edited",
        revision: model.revision + 1,
      }
    SelectFile(file) => { ..model, active_file: file, show_find: false }
    SelectExample(id) =>
      {
        ..model,
        lesson_id: id,
        active_file: Main,
        show_find: false,
        status: "Loading example",
        preview_status: "Waiting for example source",
        revision: model.revision + 1,
      }
    SetFindQuery(query) => {
      let source = current_source(model)
      let editor = { ..model.editor, find: { ..model.editor.find, query, } }
      let editor = { ..editor, find: editor.find.recompute(source) }
      { ..model, editor, find_query: query, show_find: true }
    }
    SetReplaceText(value) => { ..model, replace_text: value }
    EditorSelectionChanged(caret, selection) =>
      { ..model, editor: model.editor.with_selection(caret, selection) }
    ReplaceAll => {
      let source = current_source(model)
      let replaced = @code_editor.code_replace_all(
        source,
        model.find_query,
        model.replace_text,
      )
      update_source({ ..model, status: "Replaced all matches" }, replaced)
    }
    FindNext => {
      let matches = model.editor.find.matches
      let next = if matches.is_empty() {
        -1
      } else {
        (model.editor.find.active_index + 1) % matches.length()
      }
      {
        ..model,
        editor: {
          ..model.editor,
          find: { ..model.editor.find, active_index: next },
        },
      }
    }
    Run =>
      {
        ..model,
        status: "Compile requested",
        preview_status: "Waiting for compiler worker",
        revision: model.revision + 1,
      }
    Share => { ..model, status: "Share link requested" }
    Stop => { ..model, status: "Stopped", preview_status: "Preview stopped" }
    Reset => Model::new()
    LoadProject(value) => {
      let parsed = @json.parse(value) catch { _ => return model }
      let project : PlaygroundProject = @json.from_json(parsed) catch {
        _ => return model
      }
      if project.schema_version != 1 {
        return model
      }
      let source = project_file_source(
        project.files,
        "main.mbt",
        default_source(),
      )
      let package_source = project_file_source(
        project.files,
        "moon.pkg",
        default_moon_pkg(),
      )
      {
        ..model,
        editor: @code_editor.EditorState::new(source~),
        moon_pkg: package_source,
        lesson_id: project.lesson_id,
        active_file: Main,
        status: "Project loaded",
        preview_status: "Run to preview",
        revision: model.revision + 1,
      }
    }
    CompilerStatus(value) => { ..model, status: value }
    CompileFinished(result) =>
      if result.revision != model.revision {
        model
      } else {
        let source = model.editor.active_document().text
        let diagnostics = result.diagnostics.map(diagnostic => {
          compile_diagnostic_to_editor(source, diagnostic)
        })
        let editor = model.editor.with_diagnostics(diagnostics)
        match result.status {
          Success =>
            {
              ..model,
              editor,
              status: "Compilation succeeded",
              preview_status: "Preview running",
            }
          Failed =>
            {
              ..model,
              editor,
              status: "Compilation failed",
              preview_status: "Preview unavailable",
            }
          Unavailable =>
            {
              ..model,
              editor,
              status: "Compiler unavailable",
              preview_status: "Preview unavailable",
            }
        }
      }
  }
}

///|
fn compile_diagnostic_to_editor(
  source : String,
  diagnostic : CompileDiagnostic,
) -> @code_editor.CodeDiagnostic {
  let severity = match diagnostic.severity.to_lower() {
    "warning" => @code_editor.CodeDiagnosticSeverity::Warning
    "info" => @code_editor.CodeDiagnosticSeverity::Info
    _ => @code_editor.CodeDiagnosticSeverity::Error
  }
  @code_editor.CodeDiagnostic::new(
    range=@text.TextRange::new(
      start=compile_diagnostic_offset(
        source,
        diagnostic.line,
        diagnostic.column,
      ),
      end=compile_diagnostic_offset(
        source,
        diagnostic.end_line,
        diagnostic.end_column,
      ),
    ),
    severity~,
    message=diagnostic.message,
  )
}

///|
fn compile_diagnostic_offset(source : String, line : Int, column : Int) -> Int {
  let lines = @code_editor.code_editor_source_lines(source)
  if lines.is_empty() {
    return 0
  }
  let line_index = clamp_playground_int(line - 1, 0, lines.length() - 1)
  let current = lines[line_index]
  current.start + clamp_playground_int(column - 1, 0, current.text.length())
}

///|
fn clamp_playground_int(value : Int, lower : Int, upper : Int) -> Int {
  if value < lower {
    lower
  } else if value > upper {
    upper
  } else {
    value
  }
}

///|
pub fn current_source(model : Model) -> String {
  match model.active_file {
    Main => model.editor.active_document().text
    Package => model.moon_pkg
  }
}

///|
fn update_source(model : Model, source : String) -> Model {
  match model.active_file {
    Main => { ..model, editor: model.editor.with_source(source) }
    Package => { ..model, moon_pkg: source }
  }
}

///|
fn default_source() -> String {
  "struct Model {\n  count : Int\n}\n\nfn view(model : Model) -> @moui.View[Unit] {\n  @views.column([\n    @views.text(\"Hello, MoUI!\"),\n    @views.text(\"Count: \\{model.count}\"),\n  ])\n}\n\npub fn program() -> @moui.Program[Model, Unit] {\n  @moui.Program::simple(\n    init={ count: 0 },\n    update=(model, _message) => model,\n    view~,\n  )\n}\n"
}

///|
fn default_moon_pkg() -> String {
  "import {\n  \"wzzc-dev/moui\",\n  \"wzzc-dev/moui/views\",\n}\n\nsupported_targets = \"wasm-gc\"\n"
}

///|
fn project_file_source(
  files : Array[CompileFile],
  path : String,
  fallback : String,
) -> String {
  for file in files {
    if file.path == path {
      return file.source
    }
  }
  fallback
}
