///|
pub fn args_without_program(args : Array[String]) -> Array[String] {
  if args.is_empty() {
    []
  } else {
    args[1:].to_owned()
  }
}

///|
pub fn path_is_rooted(path : String) -> Bool {
  path.has_prefix("/") ||
  path.has_prefix("\\") ||
  (path.length() >= 3 && path[1] == ':' && (path[2] == '/' || path[2] == '\\'))
}

///|
pub fn join_path(root : String, path : String) -> String {
  if root == "" || path_is_rooted(path) {
    path
  } else if root.has_suffix("/") || root.has_suffix("\\") {
    root + path
  } else {
    root + "/" + path
  }
}

///|
pub fn resolve_path(root : String, path : String) -> String {
  if path_is_rooted(path) {
    path
  } else {
    join_path(root, path)
  }
}

///|
pub fn strip_suffix(value : String, suffix : String) -> String? {
  if value.has_suffix(suffix) {
    Some(value[:value.length() - suffix.length()].to_owned())
  } else {
    None
  }
}

///|
pub fn[V] sorted_map_keys(map : Map[String, V]) -> Array[String] {
  let keys = map.keys().collect()
  keys.sort()
  keys
}

///|
pub fn comma_join(values : Array[String]) -> String {
  let builder = StringBuilder()
  for index in 0..<values.length() {
    if index > 0 {
      builder.write_string(", ")
    }
    builder.write_string(values[index])
  }
  builder.to_string()
}

///|
pub fn read_required_text(
  path : String,
  label : String,
) -> Result[String, String] {
  if !file_exists(path) {
    return Err(label + " is missing: " + path)
  }
  let text = @fs.read_file_to_string(path) catch {
    _ => return Err(label + " could not be read: " + path)
  }
  Ok(text)
}

///|
pub fn write_text_file(
  path : String,
  text : String,
  label : String,
) -> Result[Unit, String] {
  let bytes = @utf8.encode(text[:], bom=false)
  @fs.write_bytes_to_file(path, bytes) catch {
    _ => return Err(label + " could not be written: " + path)
  }
  Ok(())
}

///|
pub fn file_exists(path : String) -> Bool {
  @fs.is_file(path) catch {
    _ => false
  }
}

///|
pub fn directory_exists(path : String) -> Bool {
  @fs.is_dir(path) catch {
    _ => false
  }
}

///|
pub fn file_names_with_suffix(
  directory : String,
  suffix : String,
) -> Result[Array[String], String] {
  if !directory_exists(directory) {
    return Err("directory is missing: " + directory)
  }
  let entries : Array[String] = @fs.read_dir(directory) catch {
    _ => return Err("directory could not be read: " + directory)
  }
  let names : Array[String] = []
  for entry in entries {
    if entry.has_suffix(suffix) && file_exists(join_path(directory, entry)) {
      names.push(entry)
    }
  }
  names.sort()
  Ok(names)
}

///|
pub fn read_file_or_directory_text(
  path : String,
  suffix : String,
  missing_message : String,
  empty_directory_message : String,
) -> Result[String, String] {
  if file_exists(path) {
    return read_required_text(path, "required capability smoke input")
  }
  if !directory_exists(path) {
    return Err(missing_message + path)
  }
  let files = match file_names_with_suffix(path, suffix) {
    Ok(values) => values
    Err(message) => return Err(message)
  }
  if files.is_empty() {
    return Err(empty_directory_message + path)
  }
  let builder = StringBuilder()
  for index in 0..<files.length() {
    if index > 0 {
      builder.write_char('\n')
    }
    let file_path = join_path(path, files[index])
    match read_required_text(file_path, "required capability smoke input") {
      Ok(text) => builder.write_string(text)
      Err(message) => return Err(message)
    }
  }
  Ok(builder.to_string())
}
