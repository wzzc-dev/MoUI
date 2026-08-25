///|
fn hex_char(char : Char) -> Bool {
  (char >= '0' && char <= '9') ||
  (char >= 'a' && char <= 'f') ||
  (char >= 'A' && char <= 'F')
}

///|
fn lowercase_hex_char(char : Char) -> Char {
  match char {
    'A' => 'a'
    'B' => 'b'
    'C' => 'c'
    'D' => 'd'
    'E' => 'e'
    'F' => 'f'
    _ => char
  }
}

///|
pub fn lowercase_hex(value : String) -> String {
  let builder = StringBuilder()
  for char in value {
    builder.write_char(lowercase_hex_char(char))
  }
  builder.to_string()
}

///|
pub fn full_hex_hash(value : String) -> Bool {
  if value.length() != 40 {
    return false
  }
  for char in value {
    if !hex_char(char) {
      return false
    }
  }
  true
}

///|
fn lines_from_text(text : String) -> Array[String] {
  let lines : Array[String] = []
  for line in text.split("\n") {
    lines.push(line.to_owned())
  }
  lines
}

///|
pub fn first_pinned_revision(text : String) -> String {
  for line in text.split("\n") {
    let trimmed = line.trim().to_owned()
    if trimmed != "" && !trimmed.has_prefix("#") {
      return lowercase_hex(trimmed)
    }
  }
  ""
}

///|
fn commit_from_line(line : String) -> String? {
  let prefix = "skia_commit="
  let trimmed = line.trim().to_owned()
  if !trimmed.has_prefix(prefix) {
    return None
  }
  let hash = trimmed[prefix.length():].to_owned()
  if !full_hex_hash(hash) {
    return None
  }
  Some(lowercase_hex(hash))
}

///|
fn has_required_field(lines : Array[String], field : String) -> Bool {
  lines.any(line => line.trim().to_owned() == field)
}

///|
pub fn verify_acceptance_log_text(
  text : String,
  require_commit : Bool,
) -> Result[Unit, String] {
  let lines = lines_from_text(text)
  for
    field in [
      "smoke_status=0", "native_smoke_marker=passed", "native_pkg_restore=passed",
    ] {
    if !has_required_field(lines, field) {
      return Err("acceptance log is missing required field: " + field)
    }
  }
  if require_commit && !lines.any(line => commit_from_line(line) is Some(_)) {
    return Err("acceptance log is missing a full 40-character skia_commit hash")
  }
  Ok(())
}

///|
pub fn accepted_commit_from_log_text(text : String) -> Result[String, String] {
  match verify_acceptance_log_text(text, true) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let accepted_commit = Ref("")
  for line in lines_from_text(text) {
    match commit_from_line(line) {
      Some(commit) => accepted_commit.val = commit
      None => ()
    }
  }
  if accepted_commit.val == "" {
    Err("acceptance log is missing a full 40-character skia_commit hash")
  } else {
    Ok(accepted_commit.val)
  }
}

///|
pub fn display_revision(value : String) -> String {
  if value == "" {
    "<empty>"
  } else {
    value
  }
}

///|
pub fn verify_revision_texts(
  revision_text : String,
  acceptance_text : String,
  skip_if_unpinned : Bool,
) -> Result[String, String] {
  let pinned_revision = first_pinned_revision(revision_text)
  if !full_hex_hash(pinned_revision) {
    if skip_if_unpinned {
      return Ok(
        "Skipping Skia revision pin check because revision is not pinned: " +
        display_revision(pinned_revision),
      )
    }
    return Err(
      "Skia revision is not pinned to a full 40-character commit: " +
      display_revision(pinned_revision),
    )
  }
  let accepted_commit = match accepted_commit_from_log_text(acceptance_text) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if pinned_revision != accepted_commit {
    return Err(
      "Skia revision pin does not match acceptance commit\n  pinned_revision=" +
      pinned_revision +
      "\n  acceptance_commit=" +
      accepted_commit,
    )
  }
  Ok(
    "Verified skia-revision.txt matches accepted Skia commit " +
    accepted_commit +
    ".",
  )
}
