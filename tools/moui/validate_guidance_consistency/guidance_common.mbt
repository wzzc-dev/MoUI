///|
struct TextRule {
  path : String
  token : String
}

///|
fn read_repo_text(repo_root : String, path : String) -> Result[String, String] {
  @tools.read_required_text(@tools.resolve_path(repo_root, path), path)
}

///|
fn include_failure(path : String, text : String, token : String) -> String? {
  if text.contains(token) {
    None
  } else {
    Some(path + ": expected to include '" + token + "'")
  }
}

///|
fn absent_failure(path : String, text : String, token : String) -> String? {
  if text.contains(token) {
    Some(path + ": stale guidance token '" + token + "'")
  } else {
    None
  }
}

///|
fn push_include_check(
  repo_root : String,
  path : String,
  token : String,
  failures : Array[String],
) -> Unit {
  match read_repo_text(repo_root, path) {
    Ok(text) =>
      match include_failure(path, text, token) {
        Some(message) => failures.push(message)
        None => ()
      }
    Err(message) => failures.push(message)
  }
}

///|
fn push_absent_check(
  repo_root : String,
  path : String,
  token : String,
  failures : Array[String],
) -> Unit {
  match read_repo_text(repo_root, path) {
    Ok(text) =>
      match absent_failure(path, text, token) {
        Some(message) => failures.push(message)
        None => ()
      }
    Err(message) => failures.push(message)
  }
}

///|
fn quoted_strings(text : String) -> Array[String] {
  let values : Array[String] = []
  let mut index = 0
  while index < text.length() {
    if text[index] == '"' {
      let builder = StringBuilder::new()
      index += 1
      while index < text.length() && text[index] != '"' {
        builder.write_char(Int::unsafe_to_char(text[index].to_int()))
        index += 1
      }
      if index < text.length() {
        values.push(builder.to_string())
      }
    }
    index += 1
  }
  values
}

///|
fn duplicate_values(values : Array[String]) -> Array[String] {
  let seen : Array[String] = []
  let duplicates : Array[String] = []
  for value in values {
    if seen.contains(value) {
      if !duplicates.contains(value) {
        duplicates.push(value)
      }
    } else {
      seen.push(value)
    }
  }
  duplicates
}

///|
fn unique_values(values : Array[String]) -> Array[String] {
  let unique : Array[String] = []
  for value in values {
    if !unique.contains(value) {
      unique.push(value)
    }
  }
  unique
}
