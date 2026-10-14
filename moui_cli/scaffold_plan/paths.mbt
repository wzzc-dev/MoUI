///|
/// Pure path text helpers. `moui_cli/path_fs.mbt` delegates here so the plan
/// layer and the CLI share one normalisation rule without Studio pulling in the
/// native FS helpers.
pub fn normalized_path(path : String) -> String {
  path.replace_all(old="\\", new="/")
}

///|
pub fn base_name(path : String) -> String {
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
