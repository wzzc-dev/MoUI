///|
fn plan_status_line(text : String) -> String? {
  let mut line_number = 0
  for line in text.split("\n") {
    line_number += 1
    if line_number > 24 {
      break
    }
    let value = line.to_owned().trim().to_owned()
    if value.contains("Status") || value.contains("状态") {
      return Some(value.to_lower())
    }
  }
  None
}

///|
fn status_matches_plan_directory(directory : String, text : String) -> Bool {
  match plan_status_line(text) {
    None => false
    Some(status) =>
      if directory == "active" {
        status.contains("active") &&
        !status.contains("done") &&
        !status.contains("complete") &&
        !status.contains("superseded") &&
        !status.contains("archived")
      } else {
        status.contains("done") ||
        status.contains("complete") ||
        status.contains("superseded") ||
        status.contains("archived") ||
        status.contains("完成") ||
        status.contains("归档") ||
        status.contains("取代") ||
        status.contains("作废")
      }
  }
}

///|
fn markdown_plan_links(readme : String, directory : String) -> Array[String] {
  let marker = "(" + directory + "/"
  let links : Array[String] = []
  for line in readme.split("\n") {
    let value = line.to_owned()
    match value.find(marker) {
      Some(start) => {
        let path_start = start + 1
        let rest = value[path_start:]
        match rest.find(")") {
          Some(path_end) => {
            let path = rest[:path_end].to_owned()
            if path.has_suffix(".md") {
              links.push(path)
            }
          }
          None => ()
        }
      }
      None => ()
    }
  }
  links
}

///|
fn plan_files(
  repo_root : String,
  directory : String,
  failures : Array[String],
) -> Array[String] {
  let relative_dir = "docs/plans/" + directory
  let absolute_dir = @tools.resolve_path(repo_root, relative_dir)
  let entries : Array[String] = @fs.read_dir(absolute_dir) catch {
    _ => {
      failures.push(relative_dir + ": directory could not be read")
      return []
    }
  }
  let files : Array[String] = []
  for entry in entries {
    if entry.has_suffix(".md") &&
      @tools.file_exists(
        @tools.resolve_path(repo_root, relative_dir + "/" + entry),
      ) {
      files.push(directory + "/" + entry)
    }
  }
  files.sort()
  files
}

///|
fn push_plan_index_checks(repo_root : String, failures : Array[String]) -> Unit {
  let readme = match read_repo_text(repo_root, "docs/plans/README.md") {
    Ok(value) => value
    Err(message) => {
      failures.push(message)
      return
    }
  }
  for directory in ["active", "done"] {
    let files = plan_files(repo_root, directory, failures)
    let links = markdown_plan_links(readme, directory)
    for file in files {
      if !links.contains(file) {
        failures.push("docs/plans/README.md: missing index entry for " + file)
      }
      match read_repo_text(repo_root, "docs/plans/" + file) {
        Ok(text) =>
          if !status_matches_plan_directory(directory, text) {
            failures.push(
              "docs/plans/" +
              file +
              ": status does not match " +
              directory +
              "/",
            )
          }
        Err(message) => failures.push(message)
      }
    }
    for link in links {
      if !files.contains(link) {
        failures.push("docs/plans/README.md: stale index entry " + link)
      }
    }
  }
}
