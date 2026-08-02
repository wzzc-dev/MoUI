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
    _ => return Err("could not read mobile template directory: " + directory)
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
        _ => return Err("could not read mobile template file: " + child)
      }
      files.push({ path: child_relative, bytes })
    }
  }
  Ok(files)
}
