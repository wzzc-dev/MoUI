///|
fn contains_value(values : Array[String], value : String) -> Bool {
  for item in values {
    if item == value {
      return true
    }
  }
  false
}

///|
fn duplicate_values(values : Array[String]) -> Array[String] {
  let seen : Array[String] = []
  let duplicates : Array[String] = []
  for value in values {
    if seen.contains(value) {
      if !duplicates.contains(value) {
        duplicates.push(value)
      }
    } else {
      seen.push(value)
    }
  }
  duplicates
}

///|
fn parse_decimal(value : String) -> Int32 {
  if value.length() == 0 {
    return -1
  }
  let mut result = 0
  for char in value {
    if char < '0' || char > '9' {
      return -1
    }
    result = result * 10 + char.to_int() - '0'.to_int()
  }
  result
}

///|
fn valid_iso_date(value : String) -> Bool {
  let parts = value.split("-").map(part => part.to_owned()).to_array()
  if parts.length() != 3 ||
    parts[0].length() != 4 ||
    parts[1].length() != 2 ||
    parts[2].length() != 2 {
    return false
  }
  let year = parse_decimal(parts[0])
  let month = parse_decimal(parts[1])
  let day = parse_decimal(parts[2])
  if year < 1 || month < 1 || month > 12 || day < 1 {
    return false
  }
  let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
  let days = match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if leap { 29 } else { 28 }
    _ => 0
  }
  day <= days
}

///|
fn intent_expectation(intent : String) -> (String, Bool)? {
  match intent {
    "product" => Some(("committed", true))
    "diagnostic" => Some(("diagnostic", false))
    "lab" => Some(("experimental", false))
    _ => None
  }
}

///|
fn release_line_prefix(line : String) -> String? {
  if line.has_suffix(".x") {
    Some(line[:line.length() - 1].to_owned())
  } else if line.has_suffix("x") {
    Some(line[:line.length() - 1].to_owned())
  } else {
    None
  }
}

///|
fn version_matches_release_line(version : String, line : String) -> Bool {
  match release_line_prefix(line) {
    Some(prefix) => version.has_prefix(prefix)
    None => false
  }
}

///|
fn portfolio_route(catalog : PortfolioCatalog, id : String) -> PortfolioRoute? {
  for route in catalog.routes {
    if route.id == id {
      return Some(route)
    }
  }
  None
}

///|
fn portfolio_module(
  catalog : PortfolioCatalog,
  name : String,
) -> PortfolioModule? {
  for entry in catalog.modules {
    if entry.name == name {
      return Some(entry)
    }
  }
  None
}

///|
fn validate_intent_syntax(
  label : String,
  intent : String,
  failures : Array[String],
) -> Unit {
  if intent_expectation(intent) is None {
    failures.push(
      label +
      " has unsupported intent '" +
      intent +
      "' (expected product, lab, or diagnostic)",
    )
  }
}

///|
fn validate_lifecycle_text(
  label : String,
  field : String,
  value : String,
  failures : Array[String],
) -> Unit {
  if value.trim().to_owned() == "" {
    failures.push(label + " " + field + " must not be empty")
  }
}

///|
fn validate_portfolio_entries(
  catalog : PortfolioCatalog,
  failures : Array[String],
) -> Unit {
  if !valid_iso_date(catalog.reviewed_on) {
    failures.push(
      "checks/portfolio-governance.json.reviewedOn must be a valid ISO date",
    )
  }
  let route_ids = catalog.routes.map(route => route.id)
  for duplicate in duplicate_values(route_ids) {
    failures.push("portfolio governance has duplicate route id: " + duplicate)
  }
  for route in catalog.routes {
    let label = "portfolio route " + route.id
    if !valid_iso_date(route.review_date) {
      failures.push(label + " reviewDate must be a valid ISO date")
    }
    validate_intent_syntax(label, route.intent, failures)
    validate_lifecycle_text(
      label,
      "reviewTrigger",
      route.review_trigger,
      failures,
    )
    validate_lifecycle_text(label, "graduation", route.graduation, failures)
    validate_lifecycle_text(label, "retirement", route.retirement, failures)
  }
  let module_names = catalog.modules.map(entry => entry.name)
  for duplicate in duplicate_values(module_names) {
    failures.push("portfolio governance has duplicate module: " + duplicate)
  }
  for entry in catalog.modules {
    let label = "portfolio module " + entry.name
    if !valid_iso_date(entry.review_date) {
      failures.push(label + " reviewDate must be a valid ISO date")
    }
    validate_intent_syntax(label, entry.intent, failures)
    validate_lifecycle_text(
      label,
      "reviewTrigger",
      entry.review_trigger,
      failures,
    )
    validate_lifecycle_text(label, "evidence", entry.evidence, failures)
    validate_lifecycle_text(label, "graduation", entry.graduation, failures)
    validate_lifecycle_text(label, "retirement", entry.retirement, failures)
  }
}

///|
fn validate_route_coverage(
  matrix : PlatformFacts,
  portfolio : PortfolioCatalog,
  failures : Array[String],
) -> Unit {
  let expected : Array[String] = []
  for route in matrix.routes {
    expected.push(route.id)
  }
  let actual = portfolio.routes.map(route => route.id)
  for duplicate in duplicate_values(expected) {
    failures.push("platform matrix has duplicate route id: " + duplicate)
  }
  for id in expected {
    if !contains_value(actual, id) {
      failures.push("portfolio governance is missing route: " + id)
    }
  }
  for id in actual {
    if !contains_value(expected, id) {
      failures.push("portfolio governance contains stale route: " + id)
    }
  }
}

///|
fn validate_route_intent(
  route : PlatformRouteFacts,
  governance : PortfolioRoute,
  failures : Array[String],
) -> Unit {
  let expected = intent_expectation(governance.intent)
  if expected is Some((product_class, ready)) {
    if route.product_class != product_class {
      failures.push(
        "route " +
        route.id +
        " intent '" +
        governance.intent +
        "' requires productClass '" +
        product_class +
        "', found '" +
        route.product_class +
        "'",
      )
    }
    if route.ready != ready {
      failures.push(
        "route " +
        route.id +
        " intent '" +
        governance.intent +
        "' requires ready=" +
        ready.to_string() +
        ", found " +
        route.ready.to_string(),
      )
    }
  }
}

///|
fn validate_route_facts(
  repo_root : String,
  matrix : PlatformFacts,
  portfolio : PortfolioCatalog,
  failures : Array[String],
) -> Unit {
  for route in matrix.routes {
    match portfolio_route(portfolio, route.id) {
      Some(governance) => validate_route_intent(route, governance, failures)
      None => ()
    }
    if !@tools.file_exists(@tools.resolve_path(repo_root, route.evidence_file)) {
      failures.push(
        "route " +
        route.id +
        " evidence file is missing: " +
        route.evidence_file,
      )
    }
  }
}

///|
fn validate_module_coverage(
  release : ReleaseFacts,
  portfolio : PortfolioCatalog,
  failures : Array[String],
) -> Unit {
  let expected : Array[String] = []
  for entry in release.modules {
    if entry.publication == "public" {
      expected.push(entry.name)
    }
  }
  let actual = portfolio.modules.map(entry => entry.name)
  for duplicate in duplicate_values(expected) {
    failures.push("release catalog has duplicate public module: " + duplicate)
  }
  for name in expected {
    if !contains_value(actual, name) {
      failures.push("portfolio governance is missing public module: " + name)
    }
  }
  for name in actual {
    if !contains_value(expected, name) {
      failures.push("portfolio governance contains non-public module: " + name)
    }
  }
}

///|
fn validate_module_facts(
  repo_root : String,
  release : ReleaseFacts,
  portfolio : PortfolioCatalog,
  failures : Array[String],
) -> Unit {
  let prefix = release_line_prefix(portfolio.release_coupling.line)
  if prefix is None {
    failures.push("releaseCoupling.line must end in 'x', for example '0.3.x'")
  }
  for entry in release.modules {
    if entry.publication != "public" {
      continue
    }
    if !contains_value(release.release_stages, entry.release_stage) {
      failures.push(
        "release module " + entry.name + " has unknown releaseStage",
      )
    }
    if portfolio_module(portfolio, entry.name) is None {
      continue
    }
    let manifest_path = entry.directory + "/moon.mod"
    let text = match
      @tools.read_required_text(
        @tools.resolve_path(repo_root, manifest_path),
        manifest_path,
      ) {
      Ok(text) => text
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    if manifest_field(text, "name") != entry.name {
      failures.push(
        "release module " +
        entry.name +
        " does not match manifest name in " +
        manifest_path,
      )
    }
    let version = manifest_field(text, "version")
    if prefix is Some(_) &&
      !version_matches_release_line(version, portfolio.release_coupling.line) {
      failures.push(
        "release module " +
        entry.name +
        " version '" +
        version +
        "' is outside synchronized line " +
        portfolio.release_coupling.line,
      )
    }
  }
}

///|
fn validate_release_coupling(
  repo_root : String,
  catalog : PortfolioCatalog,
  failures : Array[String],
) -> Unit {
  let coupling = catalog.release_coupling
  if coupling.mode != "synchronized-line" {
    failures.push("releaseCoupling.mode must be 'synchronized-line'")
  }
  if coupling.base_only_patch != "not-offered" {
    failures.push("releaseCoupling.baseOnlyPatch must be 'not-offered'")
  }
  if coupling.compatibility_matrix != "deferred" {
    failures.push("releaseCoupling.compatibilityMatrix must be 'deferred'")
  }
  if !@tools.file_exists(@tools.resolve_path(repo_root, coupling.adr)) {
    failures.push("releaseCoupling.adr is missing: " + coupling.adr)
  }
}

///|
fn component_api_tokens() -> Array[String] {
  [
    "componentcontext", "saveablestatestore", "@core.component::new", "@views.component",
    "component state subscriptions", "component-scoped effects", "scoped saveable",
  ]
}

///|
fn negation_markers() -> Array[String] {
  [
    "no ", "no `", "not ", "never ", "without ", "instead ", "removed", "does not",
    "do not", "is not", "are not", "rather than", "cannot ", "eliminated", "不再",
    "不是", "没有", "而不是", "避免", "不得", "不要", "未提供", "不提供",
    "已移除", "不暴露",
  ]
}

///|
fn contains_any(text : String, needles : Array[String]) -> Bool {
  for needle in needles {
    if text.contains(needle) {
      return true
    }
  }
  false
}

///|
fn stale_component_api(line : String) -> String? {
  let lower = line.to_lower()
  for token in component_api_tokens() {
    match lower.find(token) {
      Some(index) => {
        let context_start = if index > 80 { index - 80 } else { 0 }
        let prefix = lower[context_start:index].to_owned()
        if !contains_any(prefix, negation_markers()) {
          return Some(token)
        }
      }
      None => ()
    }
  }
  None
}

///|
fn harmonyos_status_conflict(line : String) -> Bool {
  let lower = line.to_lower()
  lower.contains("harmonyos") &&
  lower.contains("experimental") &&
  !lower.contains("committed")
}

///|
fn markdown_scan_skipped_directory(name : String) -> Bool {
  name == "decisions" ||
  name == "plans" ||
  name == "ai-sessions" ||
  name == "release-notes" ||
  name == ".git" ||
  name == "_build" ||
  name == "artifacts" ||
  name == ".mooncakes" ||
  name == "website" ||
  name == "window"
}

///|
fn collect_markdown_files(
  repo_root : String,
  relative_dir : String,
  files : Array[String],
  failures : Array[String],
) -> Unit {
  let absolute_dir = @tools.resolve_path(repo_root, relative_dir)
  if !@tools.directory_exists(absolute_dir) {
    failures.push(relative_dir + ": markdown scan root is missing")
    return
  }
  let entries = @fs.read_dir(absolute_dir) catch {
    _ => {
      failures.push(relative_dir + ": markdown scan root could not be read")
      return
    }
  }
  for entry in entries {
    let relative = relative_dir + "/" + entry
    let absolute = @tools.resolve_path(repo_root, relative)
    if @tools.directory_exists(absolute) {
      if !markdown_scan_skipped_directory(entry) {
        collect_markdown_files(repo_root, relative, files, failures)
      }
    } else if @tools.file_exists(absolute) && entry.has_suffix(".md") {
      files.push(relative)
    }
  }
}

///|
fn markdown_surface_files(
  repo_root : String,
  failures : Array[String],
) -> Array[String] {
  let files : Array[String] = []
  for root in ["docs", "skills", "examples/momark/docs"] {
    collect_markdown_files(repo_root, root, files, failures)
  }
  for
    path in [
      "README.md", "README.zh-CN.md", "AGENTS.md", "CONTRIBUTING.md", "GOVERNANCE.md",
      "moui/README.mbt.md",
    ] {
    if @tools.file_exists(@tools.resolve_path(repo_root, path)) {
      files.push(path)
    } else {
      failures.push(path + ": markdown surface file is missing")
    }
  }
  files.sort()
  files
}

///|
fn validate_document_semantics(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  for path in markdown_surface_files(repo_root, failures) {
    let text = match
      @tools.read_required_text(@tools.resolve_path(repo_root, path), path) {
      Ok(text) => text
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    for index, line_view in text.split("\n") {
      let line = line_view.to_owned()
      match stale_component_api(line) {
        Some(token) =>
          failures.push(
            path +
            ":" +
            (index + 1).to_string() +
            ": stale component API guidance '" +
            token +
            "'",
          )
        None => ()
      }
      if harmonyos_status_conflict(line) {
        failures.push(
          path +
          ":" +
          (index + 1).to_string() +
          ": HarmonyOS is committed; remove the experimental product-class claim",
        )
      }
    }
  }
}

///|
fn validate_portfolio_governance(
  repo_root : String,
  portfolio : PortfolioCatalog,
  matrix : PlatformFacts,
  release : ReleaseFacts,
) -> Array[String] {
  let failures : Array[String] = []
  validate_portfolio_entries(portfolio, failures)
  validate_route_coverage(matrix, portfolio, failures)
  validate_route_facts(repo_root, matrix, portfolio, failures)
  validate_module_coverage(release, portfolio, failures)
  validate_module_facts(repo_root, release, portfolio, failures)
  validate_release_coupling(repo_root, portfolio, failures)
  validate_document_semantics(repo_root, failures)
  failures
}
