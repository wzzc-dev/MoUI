///|
fn read_repo_text(repo_root : String, path : String) -> Result[String, String] {
  @tools.read_required_text(@tools.resolve_path(repo_root, path), path)
}

///|
fn collect_contract_files(
  repo_root : String,
  relative_dir : String,
  files : Array[String],
  failures : Array[String],
) -> Unit {
  let absolute = @tools.resolve_path(repo_root, relative_dir)
  if !@tools.directory_exists(absolute) {
    failures.push("source directory missing: " + relative_dir)
    return
  }
  let entries : Array[String] = @fs.read_dir(absolute) catch {
    _ => {
      failures.push("source directory unreadable: " + relative_dir)
      return
    }
  }
  entries.sort()
  for entry in entries {
    let relative = relative_dir + "/" + entry
    let child = @tools.resolve_path(repo_root, relative)
    if @tools.directory_exists(child) {
      if entry != "_build" {
        collect_contract_files(repo_root, relative, files, failures)
      }
    } else if @tools.file_exists(child) &&
      (relative.has_suffix(".mbt") || relative.has_suffix(".mbti")) {
      files.push(relative)
    }
  }
}
