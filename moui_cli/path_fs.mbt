///|
fn normalized_path(path : String) -> String {
  path.replace_all(old="\\", new="/")
}

///|
fn path_is_absolute(path : String) -> Bool {
  let path = normalized_path(path)
  path.has_prefix("/") ||
  (path.length() >= 3 && path[1] == ':' && path[2] == '/')
}

///|
fn join_path(root : String, child : String) -> String {
  if root == "" || path_is_absolute(child) {
    child
  } else if root.has_suffix("/") || root.has_suffix("\\") {
    root + child
  } else {
    root + "/" + child
  }
}

///|
fn parent_dir(path : String) -> String {
  let path = normalized_path(path)
  let mut slash = -1
  for index in 0..<path.length() {
    if path[index] == '/' {
      slash = index
    }
  }
  if slash < 0 {
    "."
  } else if slash == 0 {
    "/"
  } else {
    path[:slash].to_owned()
  }
}

///|
fn base_name(path : String) -> String {
  let path = normalized_path(path)
  let trimmed = if path.length() > 1 && path.has_suffix("/") {
    path[:path.length() - 1].to_owned()
  } else {
    path
  }
  let mut slash = -1
  for index in 0..<trimmed.length() {
    if trimmed[index] == '/' {
      slash = index
    }
  }
  if slash < 0 {
    trimmed
  } else {
    trimmed[slash + 1:].to_owned()
  }
}

///|
fn resolve_path(root : String, path : String) -> String {
  if path_is_absolute(path) {
    path
  } else {
    join_path(root, path)
  }
}

///|
fn validate_relative_path(path : String) -> Result[Unit, String] {
  let normalized = normalized_path(path)
  if normalized == "" || path_is_absolute(normalized) {
    return Err("generated file path must be a non-empty relative path: " + path)
  }
  for part in normalized.split("/") {
    if part == "" || part == "." || part == ".." {
      return Err("generated file path contains an unsafe segment: " + path)
    }
  }
  Ok(())
}

///|
fn create_dir_if_missing(path : String) -> Result[Unit, String] {
  if path == "" || path == "." || @fs.path_exists(path) {
    return if path == "" ||
      path == "." ||
      (@fs.is_dir(path) catch { _ => false }) {
      Ok(())
    } else {
      Err("path exists and is not a directory: " + path)
    }
  }
  @fs.create_dir(path) catch {
    _ => return Err("could not create directory: " + path)
  }
  Ok(())
}

///|
fn mkdir_p(path : String) -> Result[Unit, String] {
  let normalized = normalized_path(path)
  if normalized == "" || normalized == "." || @fs.path_exists(normalized) {
    return create_dir_if_missing(normalized)
  }
  let rooted = normalized.has_prefix("/")
  let has_drive = normalized.length() >= 3 &&
    normalized[1] == ':' &&
    normalized[2] == '/'
  let current = Ref(
    if rooted {
      "/"
    } else if has_drive {
      normalized[:2].to_owned()
    } else {
      ""
    },
  )
  for part_index, part_view in normalized.split("/") {
    let part = part_view.to_owned()
    if part == "" || (has_drive && part_index == 0) {
      continue
    }
    current.val = if current.val == "" {
      part
    } else if current.val == "/" || current.val.has_suffix(":") {
      current.val + (if current.val.has_suffix(":") { "/" } else { "" }) + part
    } else {
      current.val + "/" + part
    }
    match create_dir_if_missing(current.val) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///|
fn nul_terminated(value : String) -> Bytes {
  let source = @utf8.encode(value[:], bom=false)
  source + b"\x00"
}

///|
#borrow(source, destination)
extern "C" fn rename_path_native(source : Bytes, destination : Bytes) -> Int = "moui_cli_rename_path"

///|
#borrow(source, destination)
extern "C" fn replace_path_native(source : Bytes, destination : Bytes) -> Int = "moui_cli_replace_path"

///|
#borrow(path)
extern "C" fn path_is_executable_native(path : Bytes) -> Int = "moui_cli_path_is_executable"

///|
#borrow(path)
extern "C" fn remove_tree_native(path : Bytes) -> Int = "moui_cli_remove_tree"

///|
#borrow(path)
extern "C" fn path_is_symlink_native(path : Bytes) -> Int = "moui_cli_path_is_symlink"

///|
#borrow(root, candidate)
extern "C" fn path_resolves_within_native(
  root : Bytes,
  candidate : Bytes,
) -> Int = "moui_cli_path_resolves_within"

///|
fn path_is_executable(path : String) -> Bool {
  path_is_executable_native(nul_terminated(path)) == 1
}

///|
fn path_is_symlink(path : String) -> Bool {
  path_is_symlink_native(nul_terminated(path)) == 1
}

///|
fn path_resolves_within(root : String, candidate : String) -> Bool {
  path_resolves_within_native(nul_terminated(root), nul_terminated(candidate)) ==
  1
}

///|
fn rename_path(source : String, destination : String) -> Result[Unit, String] {
  if rename_path_native(nul_terminated(source), nul_terminated(destination)) ==
    0 {
    Ok(())
  } else {
    Err("could not move generated directory into place: " + destination)
  }
}

///|
fn remove_tree(path : String) -> Unit {
  ignore(remove_tree_native(nul_terminated(path)))
}

///|
fn replace_file_atomic(path : String, bytes : Bytes) -> Result[Unit, String] {
  let temp = path + ".moui-tmp-" + @env.now().to_string()
  if @fs.path_exists(temp) {
    return Err("temporary config path already exists: " + temp)
  }
  @fs.write_bytes_to_file(temp, bytes) catch {
    _ => return Err("could not write temporary config file: " + temp)
  }
  if replace_path_native(nul_terminated(temp), nul_terminated(path)) == 0 {
    Ok(())
  } else {
    @fs.remove_file(temp) catch {
      _ => ()
    }
    Err("could not atomically update config file: " + path)
  }
}

///|
fn validate_file_plan(files : Array[PlannedFile]) -> Result[Unit, String] {
  let paths : Map[String, Bool] = Map([])
  for file in files {
    match validate_relative_path(file.path) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    if paths.contains(file.path) {
      return Err("duplicate generated file path: " + file.path)
    }
    paths[file.path] = true
  }
  Ok(())
}

///|
fn stage_file_plan(
  target : String,
  files : Array[PlannedFile],
) -> Result[String, String] {
  if @fs.path_exists(target) {
    return Err("target already exists: " + target)
  }
  match validate_file_plan(files) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match mkdir_p(parent_dir(target)) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let temp = target + ".moui-tmp-" + @env.now().to_string()
  if @fs.path_exists(temp) {
    return Err("temporary generation path already exists: " + temp)
  }
  match mkdir_p(temp) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let sorted = files.copy()
  sorted.sort_by((left, right) => left.path.lexical_compare(right.path))
  for file in sorted {
    let destination = join_path(temp, file.path)
    match mkdir_p(parent_dir(destination)) {
      Ok(_) => ()
      Err(message) => {
        remove_tree(temp)
        return Err(message)
      }
    }
    @fs.write_bytes_to_file(destination, file.bytes) catch {
      _ => {
        remove_tree(temp)
        return Err("could not write generated file: " + file.path)
      }
    }
  }
  Ok(temp)
}

///|
fn commit_staged_file_plan(
  temp : String,
  target : String,
) -> Result[Unit, String] {
  match rename_path(temp, target) {
    Ok(_) => Ok(())
    Err(message) => {
      remove_tree(temp)
      Err(message)
    }
  }
}

///|
fn write_file_plan_atomic(
  target : String,
  files : Array[PlannedFile],
) -> Result[Unit, String] {
  let temp = match stage_file_plan(target, files) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  commit_staged_file_plan(temp, target)
}

///|
fn text_file(path : String, text : String) -> PlannedFile {
  {
    path,
    bytes: @utf8.encode(
      (if text.has_suffix("\n") { text } else { text + "\n" })[:],
      bom=false,
    ),
  }
}

///|
fn sha256_hex(bytes : Bytes) -> String {
  @crypto.bytes_to_hex_string(@crypto.sha256(bytes))
}

///|
fn file_plan_digest(files : Array[PlannedFile]) -> String {
  let hasher = @crypto.SHA256::new()
  let sorted = files.copy()
  sorted.sort_by((left, right) => left.path.lexical_compare(right.path))
  for file in sorted {
    hasher.update(@utf8.encode(file.path[:], bom=false))
    hasher.update(b"\x00")
    hasher.update(file.bytes)
    hasher.update(b"\x00")
  }
  @crypto.bytes_to_hex_string(hasher.finalize())
}
