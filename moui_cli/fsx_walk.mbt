///|
/// Recursively collect all files under `root` (sorted lexically by relative
/// path). Each result is a `PlannedFile` whose `path` is relative to `root`
/// and whose `bytes` is the file content. The optional `relative` anchor is
/// used internally for recursion.
fn collect_template_files(
  root : String,
  relative? : String = "",
) -> Result[Array[PlannedFile], String] {
  let directory = if relative == "" { root } else { join_path(root, relative) }
  let entries : Array[String] = @fs.read_dir(directory) catch {
    _ => return Err("could not read shell template directory: " + directory)
  }
  entries.sort_by((left, right) => left.lexical_compare(right))
  let files : Array[PlannedFile] = []
  for name in entries {
    let child_relative = if relative == "" {
      name
    } else {
      relative + "/" + name
    }
    let child = join_path(root, child_relative)
    if path_is_dir(child) {
      match collect_template_files(root, relative=child_relative) {
        Ok(children) =>
          for file in children {
            files.push(file)
          }
        Err(message) => return Err(message)
      }
    } else if path_is_file(child) {
      let bytes = @fs.read_file_to_bytes(child) catch {
        _ => return Err("could not read shell template file: " + child)
      }
      files.push({ path: child_relative, bytes })
    }
  }
  Ok(files)
}

///|
/// Recursively walk `root` and collect relative paths (using `/` separator)
/// of files for which `predicate` returns true. Returns paths relative to
/// `root`, sorted lexically. Useful for discovering artifacts by extension.
fn collect_files_with_predicate(
  root : String,
  predicate : (String) -> Bool,
) -> Array[String] {
  let entries : Array[String] = @fs.read_dir(root) catch { _ => return [] }
  entries.sort_by((left, right) => left.lexical_compare(right))
  let result : Array[String] = []
  for name in entries {
    let child = join_path(root, name)
    if path_is_dir(child) {
      for sub in collect_files_with_predicate(child, predicate) {
        result.push(name + "/" + sub)
      }
    } else if path_is_file(child) && predicate(name) {
      result.push(name)
    }
  }
  result
}
