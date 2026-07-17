///|
fn require_path(
  repo_root : String,
  failures : Array[String],
  label : String,
  path : String,
) -> Unit {
  let absolute = @tools.resolve_path(repo_root, path)
  if !@tools.file_exists(absolute) && !@tools.directory_exists(absolute) {
    failures.push(label + " does not exist: " + path)
  }
}

///|
fn read_repo_text(repo_root : String, path : String) -> Result[String, String] {
  @tools.read_required_text(@tools.resolve_path(repo_root, path), path)
}

///|
fn require_tokens(
  failures : Array[String],
  label : String,
  source : String,
  tokens : Array[String],
) -> Unit {
  for token in tokens {
    if !source.contains(token) {
      failures.push(label + " is missing " + Json::string(token).stringify())
    }
  }
}

///|
fn index_of(text : String, needle : String) -> Int {
  match text.find(needle) {
    Some(offset) => offset
    None => -1
  }
}

///|
fn managed_moon_package(
  repo_root : String,
  app_id : String,
  platform : String,
) -> String {
  let preferred = "examples/" + app_id + "/" + platform + "_skia"
  let fallback = "examples/" + app_id + "/" + platform
  if @tools.file_exists(@tools.resolve_path(repo_root, preferred + "/moon.pkg")) ||
    @tools.directory_exists(@tools.resolve_path(repo_root, preferred)) {
    preferred
  } else {
    fallback
  }
}

///|
fn parse_json_object(text : String) -> Result[Map[String, Json], String] {
  let value = @json.parse(text) catch { _ => return Err("invalid JSON") }
  match value {
    Json::Object(fields) => Ok(fields)
    _ => Err("expected object")
  }
}

///|
fn discover_example_mobile_ids(repo_root : String) -> Array[String] {
  let ids : Array[String] = []
  let examples = @tools.resolve_path(repo_root, "examples")
  if !@tools.directory_exists(examples) {
    return ids
  }
  let entries : Array[String] = @fs.read_dir(examples) catch { _ => return ids }
  entries.sort_by((left, right) => left.lexical_compare(right))
  for name in entries {
    let mobile_json = "examples/" + name + "/mobile.json"
    if !@tools.file_exists(@tools.resolve_path(repo_root, mobile_json)) {
      continue
    }
    match read_repo_text(repo_root, mobile_json) {
      Ok(text) =>
        match parse_json_object(text) {
          Ok(fields) =>
            match fields.get("id") {
              Some(Json::String(id)) => ids.push(id)
              _ => ids.push(name)
            }
          Err(_) => ids.push(name)
        }
      Err(_) => ids.push(name)
    }
  } nobreak {
    ()
  }
  ids.sort_by((left, right) => left.lexical_compare(right))
  ids
}

///|
fn json_object(value : Json?) -> Map[String, Json]? {
  match value {
    Some(Json::Object(fields)) => Some(fields)
    _ => None
  }
}

///|
fn json_string(value : Json?) -> String? {
  match value {
    Some(Json::String(text)) => Some(text)
    _ => None
  }
}

///|
fn json_int(value : Json?) -> Int? {
  match value {
    Some(Json::Number(number, repr=_)) => Some(number.to_int())
    _ => None
  }
}
