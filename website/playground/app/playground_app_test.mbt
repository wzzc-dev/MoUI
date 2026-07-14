///|
test "playground source updates are tracked" {
  let model = update(Model::new(), SourceChanged("fn main { }"))
  inspect(model.status, content="Unsaved changes")
  inspect(current_source(model), content="fn main { }")
}

///|
test "playground can switch between controlled files" {
  let original_main = current_source(Model::new())
  let model = update(Model::new(), SelectFile(Package))
  let package_active = match model.active_file {
    Package => true
    Main => false
  }
  inspect(package_active, content="true")
  let model = update(
    model,
    PackageChanged("supported_targets = \\\"wasm-gc\\\""),
  )
  inspect(current_source(model), content="supported_targets = \\\"wasm-gc\\\"")
  let model = update(model, SelectFile(Main))
  inspect(current_source(model), content=original_main)
}

///|
test "playground loads a serialized project" {
  let project = PlaygroundProject::{
    schema_version: 1,
    files: [
      { path: "main.mbt", source: "pub fn program() { }" },
      { path: "moon.pkg", source: "supported_targets = \\\"wasm-gc\\\"" },
    ],
    lesson_id: "03-state-events",
  }
  let model = update(Model::new(), LoadProject(project.to_json_line()))
  inspect(current_source(model), content="pub fn program() { }")
  inspect(model.lesson_id, content="03-state-events")
}

///|
test "playground example selection invalidates stale work while loading" {
  let initial = Model::new()
  let model = update(initial, SelectExample("04-theme-styling"))
  inspect(model.lesson_id, content="04-theme-styling")
  inspect(model.status, content="Loading example")
  inspect(model.preview_status, content="Waiting for example source")
  inspect(model.revision, content="1")
  assert_true(model.active_file == Main)
}

///|
test "playground ignores stale compiler results" {
  let model = update(Model::new(), Run)
  let stale = CompileResult::{
    revision: model.revision - 1,
    status: Success,
    diagnostics: [],
  }
  let next = update(model, CompileFinished(stale))
  inspect(next.status, content="Compile requested")
}

///|
test "playground leaves the building state after compilation" {
  let building = update(Model::new(), Run)
  inspect(building.status, content="Compile requested")
  let completed = update(
    building,
    CompileFinished({
      revision: building.revision,
      status: Success,
      diagnostics: [],
    }),
  )
  inspect(completed.status, content="Compilation succeeded")
}

///|
test "playground tracks the editor caret" {
  let model = update(
    Model::new(),
    EditorSelectionChanged(7, Some(@text.TextRange::new(start=3, end=7))),
  )
  inspect(model.editor.cursors[0].position, content="7")
  let (start, end) = match model.editor.selection {
    Some(selection) => (selection.start, selection.end)
    None => (-1, -1)
  }
  inspect(start, content="3")
  inspect(end, content="7")
}
