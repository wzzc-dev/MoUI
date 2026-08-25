///|
let generated_begin = "<!-- BEGIN GENERATED PLATFORM TIER MATRIX -->"

///|
let generated_end = "<!-- END GENERATED PLATFORM TIER MATRIX -->"

///|
fn tier_labels(routes : Array[PlatformRoute], tier : Int) -> String {
  let labels : Array[String] = []
  for route in routes {
    if route.tier == tier {
      labels.push("`" + route.label + "`")
    }
  }
  @tools.comma_join(labels)
}

///|
fn generated_tier_table(matrix : PlatformMatrix) -> String {
  let builder = StringBuilder()
  builder.write_string("| Tier | Canonical routes | Gate |\n|---|---|---|\n")
  builder.write_string(
    "| Tier 1 | " +
    tier_labels(matrix.routes, 1) +
    " | Blocking: PR build/test, daily presentation, and release evidence |\n",
  )
  builder.write_string(
    "| Tier 2 | " +
    tier_labels(matrix.routes, 2) +
    " | Blocking: L0-L2 and first frame; complete L3 may remain partial |\n",
  )
  builder.write_string(
    "| Tier 3 | " +
    tier_labels(matrix.routes, 3) +
    " | Non-blocking: scheduled/manual build, run, and evidence |\n\n",
  )
  builder.write_string(
    "Tier, L0-L3 evidence, and `product_class`/`ready` are independent. " +
    "Source: `checks/platform-matrix.json`; actual observations remain in " +
    "`checks/platforms/*.json`.",
  )
  builder.to_string()
}

///|
fn replace_generated_table(text : String, table : String) -> String? {
  let begin_at = match text.find(generated_begin) {
    Some(index) => index
    None => return None
  }
  let content_at = begin_at + generated_begin.length()
  let after_begin = text[content_at:]
  let relative_end = match after_begin.find(generated_end) {
    Some(index) => index
    None => return None
  }
  let end_at = content_at + relative_end + generated_end.length()
  Some(
    text[:begin_at].to_owned() +
    generated_begin +
    "\n" +
    table +
    "\n" +
    generated_end +
    text[end_at:].to_owned(),
  )
}

///|
fn generated_doc_paths() -> Array[String] {
  [
    "docs/platform-readiness-declaration.md", "docs/maintenance.md", "docs/testing.md",
    "docs/examples.md", "docs/release-readiness.md",
  ]
}

///|
fn sync_generated_docs(
  repo_root : String,
  matrix : PlatformMatrix,
  write : Bool,
) -> Array[String] {
  let failures : Array[String] = []
  let table = generated_tier_table(matrix)
  for path in generated_doc_paths() {
    let absolute = @tools.resolve_path(repo_root, path)
    let current = match @tools.read_required_text(absolute, path) {
      Ok(text) => text
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    let expected = match replace_generated_table(current, table) {
      Some(text) => text
      None => {
        failures.push(path + ": missing generated platform tier markers")
        continue
      }
    }
    if current != expected {
      if write {
        match @tools.write_text_file(absolute, expected, path) {
          Ok(_) => ()
          Err(message) => failures.push(message)
        }
      } else {
        failures.push(
          path +
          ": generated platform tier table is stale; run `node scripts/sync-platform-matrix-docs.mjs`",
        )
      }
    }
  }
  failures
}
