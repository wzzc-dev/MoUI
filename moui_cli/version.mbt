///|
fn cli_version_from_manifest(manifest : String) -> String {
  for line in manifest.split("\n") {
    let line = line.to_owned()
    if line.trim().has_prefix("version") {
      match line.find("\"") {
        Some(open) =>
          match line[open + 1:].find("\"") {
            Some(close_rel) =>
              if close_rel > 0 {
                return line[open + 1:open + 1 + close_rel].to_owned()
              }
            None => ()
          }
        None => ()
      }
    }
  }
  "0.0.0"
}

///|
fn cli_version() -> String {
  cli_version_from_manifest(embedded_module_manifest)
}
