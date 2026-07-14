///|
pub(all) struct CompileFile {
  path : String
  source : String
} derive(ToJson, FromJson)

///|
pub(all) struct CompileRequest {
  revision : Int
  files : Array[CompileFile]
  lesson_id : String
} derive(ToJson, FromJson)

///|
pub(all) struct PlaygroundProject {
  schema_version : Int
  files : Array[CompileFile]
  lesson_id : String
} derive(ToJson, FromJson)

///|
pub(all) enum CompileStatus {
  Success
  Failed
  Unavailable
} derive(Eq, ToJson, FromJson)

///|
pub(all) struct CompileDiagnostic {
  severity : String
  message : String
  file : String
  line : Int
  column : Int
  end_line : Int
  end_column : Int
} derive(ToJson, FromJson)

///|
pub(all) struct CompileResult {
  revision : Int
  status : CompileStatus
  diagnostics : Array[CompileDiagnostic]
} derive(ToJson, FromJson)

///|
pub fn CompileRequest::new(model : Model) -> CompileRequest {
  {
    revision: model.revision,
    files: [
      { path: "main.mbt", source: model.editor.active_document().text },
      { path: "moon.pkg", source: model.moon_pkg },
    ],
    lesson_id: model.lesson_id,
  }
}

///|
pub fn PlaygroundProject::new(model : Model) -> PlaygroundProject {
  {
    schema_version: 1,
    files: [
      { path: "main.mbt", source: model.editor.active_document().text },
      { path: "moon.pkg", source: model.moon_pkg },
    ],
    lesson_id: model.lesson_id,
  }
}

///|
pub fn CompileRequest::to_json_line(self : CompileRequest) -> String {
  self.to_json().stringify()
}

///|
pub fn PlaygroundProject::to_json_line(self : PlaygroundProject) -> String {
  self.to_json().stringify()
}
