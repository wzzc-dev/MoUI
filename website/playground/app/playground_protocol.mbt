///|
#derive(ToJson, FromJson)
pub(all) struct CompileFile {
  path : String
  source : String
}

///|
pub extend CompileFile with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend CompileFile with ToJson::{to_json}

///|
#derive(ToJson, FromJson)
pub(all) struct CompileRequest {
  revision : Int32
  files : Array[CompileFile]
  lesson_id : String
}

///|
pub extend CompileRequest with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend CompileRequest with ToJson::{to_json}

///|
#derive(ToJson, FromJson)
pub(all) struct PlaygroundProject {
  schema_version : Int32
  files : Array[CompileFile]
  lesson_id : String
}

///|
pub extend PlaygroundProject with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend PlaygroundProject with ToJson::{to_json}

///|
#derive(Eq, ToJson, FromJson)
pub(all) enum CompileStatus {
  Success
  Failed
  Unavailable
}

///|
pub extend CompileStatus with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend CompileStatus with Eq::{not_equal, equal}

///|
pub extend CompileStatus with ToJson::{to_json}

///|
#derive(ToJson, FromJson)
pub(all) struct CompileDiagnostic {
  severity : String
  message : String
  file : String
  line : Int32
  column : Int32
  end_line : Int32
  end_column : Int32
}

///|
pub extend CompileDiagnostic with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend CompileDiagnostic with ToJson::{to_json}

///|
#derive(ToJson, FromJson)
pub(all) struct CompileResult {
  revision : Int32
  status : CompileStatus
  diagnostics : Array[CompileDiagnostic]
}

///|
pub extend CompileResult with @moonbitlang/core/json.FromJson::{from_json}

///|
pub extend CompileResult with ToJson::{to_json}

///|
pub fn CompileRequest::new(model : Model) -> CompileRequest {
  {
    revision: model.revision,
    files: [
      { path: "main.mbt", source: model.editor.active_document().text, },
      { path: "moon.pkg", source: model.moon_pkg, },
    ],
    lesson_id: model.lesson_id,
  }
}

///|
pub fn PlaygroundProject::new(model : Model) -> PlaygroundProject {
  {
    schema_version: 1,
    files: [
      { path: "main.mbt", source: model.editor.active_document().text, },
      { path: "moon.pkg", source: model.moon_pkg, },
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
