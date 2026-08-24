///|
#borrow(path)
extern "C" fn readlink_bytes(path : Bytes, path_len : Int) -> Bytes = "moui_tools_guidance_readlink"

///|
fn push_file_exists_check(
  repo_root : String,
  path : String,
  failures : Array[String],
) -> Unit {
  if !@tools.file_exists(@tools.resolve_path(repo_root, path)) {
    failures.push(path + ": expected file to exist")
  }
}

///|
fn push_no_workflow_files_check(
  repo_root : String,
  path : String,
  failures : Array[String],
) -> Unit {
  let absolute = @tools.resolve_path(repo_root, path)
  if !@tools.directory_exists(absolute) {
    return
  }
  let entries : Array[String] = []
  match @tools.file_names_with_suffix(absolute, ".yml") {
    Ok(values) =>
      for value in values {
        entries.push(value)
      }
    Err(message) => {
      failures.push(message)
      return
    }
  }
  match @tools.file_names_with_suffix(absolute, ".yaml") {
    Ok(values) =>
      for value in values {
        entries.push(value)
      }
    Err(message) => {
      failures.push(message)
      return
    }
  }
  entries.sort()
  if !entries.is_empty() {
    failures.push(
      path +
      ": workflow files must live in root .github/workflows: " +
      @tools.comma_join(entries),
    )
  }
}

///|
fn native_readlink(path : String) -> String? {
  let bytes = @utf8.encode(path, bom=false)
  let target = readlink_bytes(bytes, bytes.length())
  if target.length() == 0 {
    None
  } else {
    Some(@utf8.decode_lossy(target[:], ignore_bom=false))
  }
}

///|
fn push_regular_file_check(
  repo_root : String,
  path : String,
  failures : Array[String],
) -> Unit {
  let resolved = @tools.resolve_path(repo_root, path)
  match native_readlink(resolved) {
    Some(_) => failures.push(path + ": expected a regular file, not a symlink")
    None => ()
  }
}
