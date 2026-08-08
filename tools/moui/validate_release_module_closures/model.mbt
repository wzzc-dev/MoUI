///|
struct ReleaseModule {
  name : String
  directory : String
  publication : String
  role : String
  release_stage : String
}

///|
struct ReleaseCatalog {
  release_stages : Array[String]
  modules : Array[ReleaseModule]
}

///|
struct ModuleManifest {
  name : String
  version : String
  imports : Array[(String, String)]
}

///|
fn json_object(value : Json) -> Map[String, Json]? {
  match value {
    Json::Object(fields) => Some(fields)
    _ => None
  }
}

///|
fn json_string(
  fields : Map[String, Json],
  key : String,
  label : String,
  failures : Array[String],
) -> String {
  match fields.get(key) {
    Some(Json::String(value)) if value.trim().to_owned() != "" => value
    _ => {
      failures.push(label + "." + key + " must be a non-empty string")
      ""
    }
  }
}

///|
fn json_array(
  fields : Map[String, Json],
  key : String,
  label : String,
  failures : Array[String],
) -> Array[Json] {
  match fields.get(key) {
    Some(Json::Array(values)) => values
    _ => {
      failures.push(label + "." + key + " must be an array")
      []
    }
  }
}

///|
fn parse_catalog(text : String) -> Result[ReleaseCatalog, Array[String]] {
  let failures : Array[String] = []
  let parsed = @json.parse(text) catch {
    _ => return Err(["checks/release-modules.json: invalid JSON"])
  }
  let root = match parsed {
    Json::Object(fields) => fields
    _ => return Err(["checks/release-modules.json must be an object"])
  }
  match root.get("schemaVersion") {
    Some(Json::Number(value, repr=_)) if value == 1.0 => ()
    _ => failures.push("checks/release-modules.json.schemaVersion must be 1")
  }
  let stage_values = json_array(
    root, "releaseStages", "checks/release-modules.json", failures,
  )
  let release_stages : Array[String] = []
  for index, value in stage_values {
    match value {
      Json::String(stage) if stage.trim().to_owned() != "" =>
        release_stages.push(stage)
      _ =>
        failures.push(
          "checks/release-modules.json.releaseStages[" +
          index.to_string() +
          "] must be a non-empty string",
        )
    }
  }
  let modules : Array[ReleaseModule] = []
  for
    index, value in json_array(
      root, "modules", "checks/release-modules.json", failures,
    ) {
    let label = "checks/release-modules.json.modules[" + index.to_string() + "]"
    let fields = match json_object(value) {
      Some(fields) => fields
      None => {
        failures.push(label + " must be an object")
        continue
      }
    }
    let publication = json_string(fields, "publication", label, failures)
    let role = json_string(fields, "role", label, failures)
    let release_stage = match fields.get("releaseStage") {
      Some(Json::String(value)) => value
      _ => ""
    }
    modules.push({
      name: json_string(fields, "name", label, failures),
      directory: json_string(fields, "directory", label, failures),
      publication,
      role,
      release_stage,
    })
  }
  if failures.is_empty() {
    Ok({ release_stages, modules })
  } else {
    Err(failures)
  }
}

///|
fn first_quoted(line : String) -> String? {
  match line.find("\"") {
    Some(start) => {
      let rest = line[start + 1:]
      match rest.find("\"") {
        Some(end) => Some(rest[:end].to_owned())
        None => None
      }
    }
    None => None
  }
}

///|
fn manifest_key(text : String, key : String) -> String {
  let prefix = key + " ="
  for line_view in text.split("\n") {
    let line = line_view.to_owned().trim().to_owned()
    if line.has_prefix(prefix) {
      match first_quoted(line) {
        Some(value) => return value
        None => return ""
      }
    }
  }
  ""
}

///|
fn module_imports(text : String) -> Array[(String, String)] {
  let imports : Array[(String, String)] = []
  let mut in_imports = false
  for line_view in text.split("\n") {
    let line = line_view.to_owned().trim().to_owned()
    if line == "import {" {
      in_imports = true
      continue
    }
    if in_imports && line == "}" {
      in_imports = false
      continue
    }
    if !in_imports {
      continue
    }
    match first_quoted(line) {
      Some(value) =>
        match value.find("@") {
          Some(at) =>
            imports.push((value[:at].to_owned(), value[at + 1:].to_owned()))
          None => imports.push((value, ""))
        }
      None => ()
    }
  }
  imports
}

///|
fn parse_module_manifest(text : String) -> ModuleManifest {
  {
    name: manifest_key(text, "name"),
    version: manifest_key(text, "version"),
    imports: module_imports(text),
  }
}

///|
fn catalog_module(catalog : ReleaseCatalog, name : String) -> ReleaseModule? {
  for entry in catalog.modules {
    if entry.name == name {
      return Some(entry)
    }
  }
  None
}

///|
fn release_stage_index(catalog : ReleaseCatalog, stage : String) -> Int {
  for index, value in catalog.release_stages {
    if value == stage {
      return index
    }
  }
  -1
}
