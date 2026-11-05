///|
let generated_routes_begin = "<!-- BEGIN GENERATED ROUTE READINESS STATUS -->"

///|
let generated_routes_end = "<!-- END GENERATED ROUTE READINESS STATUS -->"

///|
let generated_modules_begin = "<!-- BEGIN GENERATED MODULE PORTFOLIO -->"

///|
let generated_modules_end = "<!-- END GENERATED MODULE PORTFOLIO -->"

///|
let generated_release_begin = "<!-- BEGIN GENERATED RELEASE COUPLING -->"

///|
let generated_release_end = "<!-- END GENERATED RELEASE COUPLING -->"

///|
fn short_module_name(name : String) -> String {
  let prefix = "wzzc-dev/"
  if name.has_prefix(prefix) {
    name[prefix.length():].to_owned()
  } else {
    name
  }
}

///|
fn generated_route_table(
  matrix : PlatformFacts,
  portfolio : PortfolioCatalog,
) -> String {
  let builder = StringBuilder()
  builder.write_string(
    "| Route / variant | Intent | Product class | Ready | Owner | Reviewed | Evidence |\n",
  )
  builder.write_string("|---|---|---|---|---|---|---|\n")
  for route in matrix.routes {
    let governance = match portfolio_route(portfolio, route.id) {
      Some(value) => value
      None =>
        {
          id: route.id,
          owner: "unassigned",
          intent: "unassigned",
          review_date: "unassigned",
          review_trigger: "",
          graduation: "",
          retirement: "",
        }
    }
    let kind = if route.architecture_variant {
      " (architecture variant)"
    } else {
      ""
    }
    builder.write_string(
      "| `" +
      route.id +
      "`" +
      kind +
      " | " +
      governance.intent +
      " | `" +
      route.product_class +
      "` | " +
      (if route.ready { "yes" } else { "no" }) +
      " | `" +
      governance.owner +
      "` | " +
      governance.review_date +
      " | `" +
      route.evidence_file +
      "` |\n",
    )
  }
  builder.write_string(
    "\nIntent, owner, and review dates come from " +
    "`checks/portfolio-governance.json`; product class, readiness, and evidence " +
    "paths stay owned by `checks/platform-matrix.json`.",
  )
  builder.to_string()
}

///|
fn generated_module_table(
  release : ReleaseFacts,
  portfolio : PortfolioCatalog,
) -> String {
  let builder = StringBuilder()
  builder.write_string("| Module | Owner | Intent | Release stage |\n")
  builder.write_string("|---|---|---|---|\n")
  for entry in release.modules {
    if entry.publication != "public" {
      continue
    }
    let governance = match portfolio_module(portfolio, entry.name) {
      Some(value) => value
      None =>
        {
          name: entry.name,
          owner: "unassigned",
          intent: "unassigned",
          review_date: "unassigned",
          review_trigger: "",
          evidence: "",
          graduation: "",
          retirement: "",
        }
    }
    builder.write_string(
      "| `" +
      short_module_name(entry.name) +
      "` | `" +
      governance.owner +
      "` | " +
      governance.intent +
      " | `" +
      entry.release_stage +
      "` |\n",
    )
  }
  builder.write_string(
    "\nOnly public release modules are listed; `moui_tests` is internal. " +
    "Source facts: `checks/release-modules.json`; ownership and intent: " +
    "`checks/portfolio-governance.json`.",
  )
  builder.to_string()
}

///|
fn generated_release_coupling(catalog : PortfolioCatalog) -> String {
  let coupling = catalog.release_coupling
  "Release line **`" +
  coupling.line +
  "`** uses **`" +
  coupling.mode +
  "`** coordination. A base-only patch path is **`" +
  coupling.base_only_patch +
  "`**, and a per-module compatibility matrix is **`" +
  coupling.compatibility_matrix +
  "`**. Renderers and addons keep their current version unless their own " +
  "contract changes; they do not receive a forced semantic bump for an " +
  "unrelated base change. Decision: `" +
  coupling.adr +
  "`. Evidence: " +
  coupling.evidence +
  "."
}

///|
fn find_from(text : String, needle : String, start : Int32) -> Int32? {
  if start >= text.length() {
    return None
  }
  let tail = text[start:].to_owned()
  match tail.find(needle) {
    Some(index) => Some(start + index)
    None => None
  }
}

///|
fn count_occurrences(text : String, needle : String) -> Int32 {
  let mut count = 0
  let mut start = 0
  let mut done = false
  while !done {
    match find_from(text, needle, start) {
      Some(index) => {
        count += 1
        start = index + needle.length()
      }
      None => done = true
    }
  }
  count
}

///|
fn replace_generated_block(
  text : String,
  begin : String,
  end : String,
  content : String,
) -> Result[String, String] {
  if count_occurrences(text, begin) != 1 || count_occurrences(text, end) != 1 {
    return Err("expected exactly one generated block marker pair")
  }
  let begin_at = match text.find(begin) {
    Some(index) => index
    None => return Err("missing generated block begin marker")
  }
  let content_at = begin_at + begin.length()
  let after_begin = text[content_at:]
  let relative_end = match after_begin.find(end) {
    Some(index) => index
    None => return Err("missing generated block end marker")
  }
  let end_at = content_at + relative_end + end.length()
  Ok(
    text[:begin_at].to_owned() +
    begin +
    "\n" +
    content +
    "\n" +
    end +
    text[end_at:].to_owned(),
  )
}

///|
struct GeneratedBlockTarget {
  path : String
  begin : String
  end : String
  content : String
}

///|
fn generated_block_targets(
  portfolio : PortfolioCatalog,
  matrix : PlatformFacts,
  release : ReleaseFacts,
) -> Array[GeneratedBlockTarget] {
  let routes = generated_route_table(matrix, portfolio)
  [
    {
      path: "docs/platform-readiness-declaration.md",
      begin: generated_routes_begin,
      end: generated_routes_end,
      content: routes,
    },
    {
      path: "docs/feature-status-dashboard.md",
      begin: generated_routes_begin,
      end: generated_routes_end,
      content: routes,
    },
    {
      path: "docs/architecture.md",
      begin: generated_modules_begin,
      end: generated_modules_end,
      content: generated_module_table(release, portfolio),
    },
    {
      path: "docs/architecture.md",
      begin: generated_release_begin,
      end: generated_release_end,
      content: generated_release_coupling(portfolio),
    },
  ]
}

///|
fn sync_generated_docs(
  repo_root : String,
  portfolio : PortfolioCatalog,
  matrix : PlatformFacts,
  release : ReleaseFacts,
  write : Bool,
) -> Array[String] {
  let failures : Array[String] = []
  let targets = generated_block_targets(portfolio, matrix, release)
  let grouped_paths : Array[String] = []
  for target in targets {
    if !grouped_paths.contains(target.path) {
      grouped_paths.push(target.path)
    }
  }
  for path in grouped_paths {
    let absolute = @tools.resolve_path(repo_root, path)
    let current = match @tools.read_required_text(absolute, path) {
      Ok(text) => text
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    let mut expected = current
    let mut path_ok = true
    for target in targets {
      if target.path != path {
        continue
      }
      expected = match
        replace_generated_block(
          expected,
          target.begin,
          target.end,
          target.content,
        ) {
        Ok(text) => text
        Err(message) => {
          failures.push(path + ": " + message)
          path_ok = false
          break
        }
      }
    }
    if !path_ok || current == expected {
      continue
    }
    if write {
      match @tools.write_text_file(absolute, expected, path) {
        Ok(_) => ()
        Err(message) => failures.push(message)
      }
    } else {
      failures.push(
        path +
        ": generated portfolio status block is stale; run `node scripts/validate-portfolio-governance.mjs --write-docs`",
      )
    }
  }
  failures
}
