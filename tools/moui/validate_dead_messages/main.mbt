///|
/// Dead-message gate: every variant of a TEA `Msg` enum must have at least one
/// *construction site* somewhere outside the enum's own declaration file.
///
/// Why this gate exists: MoUI Studio has repeatedly shipped "dead UI" — a
/// message with a perfectly good `update` arm and a fully built view, but no
/// code path that ever constructs the message, so the feature is unreachable
/// at runtime while every unit test stays green (tests dispatch messages
/// directly, bypassing the missing UI entry point). Confirmed instances:
/// `Msg::Undo` / `Msg::Redo` (undo/redo unreachable in the v4 shell),
/// `studio_commands` (a 25-command table with zero callers),
/// `ToggleProviderSettings`, `CompileStopped`. See
/// `artifacts/studio-gap-analysis.md`.
///
/// Scan rules:
/// - Target enum: `<vis> enum <Name> {` where the name is listed in the
///   catalog (`checks/dead-message-catalog.json`), scanned under each listed
///   `scanRoot`. The declaration file is excluded from the construction scan.
/// - A variant counts as constructed when its identifier occurs outside its
///   declaration file as a standalone identifier that is NOT:
///     * a `match` arm head   (`Variant =>`, `Variant(...) =>`)
///     * a qualified reference (`@pkg.Variant`)
///     * a pattern position   (`is Variant`, `| Variant`)
///     * a `let`/`fn` binding or a type annotation position we cannot resolve
///   i.e. we require an occurrence that reads as an expression/constructor.
/// - A variant may be waived in the catalog with a reason (intentional
///   reserves such as the platform-owned `Window*` requests that must stay
///   declared for the message protocol but are deliberately not self-drawn).
///   Waivers are exact (variant name) and must stay live: a waiver whose
///   variant now has a construction site is reported as stale (ratchet down).
struct Catalog {
  enums : Array[EnumSpec]
}

///|
struct EnumSpec {
  name : String
  path : String
  scan_roots : Array[String]
  waivers : Array[Waiver]
}

///|
struct Waiver {
  variant : String
  reason : String
}

///|
struct ScanResult {
  enums : Int
  variants : Int
  violations : Array[Violation]
  stale_waivers : Array[Violation]
}

///|
struct Violation {
  path : String
  enum_name : String
  variant : String
  detail : String
}

///|
fn usage() -> String {
  (
    #|Usage: tools/moui/validate_dead_messages [--repo-root PATH] [--json]
    #|
    #|Every TEA Msg variant listed in checks/dead-message-catalog.json must
    #|have a construction site outside its declaration file (dead-UI gate).
    #|Waivers carry a reason and ratchet down.
    #|
  )
}

///|
struct CliOptions {
  repo_root : String
  json : Bool
  help : Bool
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let mut repo_root = "."
  let mut json = false
  let mut help = false
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--help" | "-h" => {
        help = true
        index += 1
      }
      "--json" => {
        json = true
        index += 1
      }
      "--repo-root" => {
        if index + 1 >= args.length() {
          return Err("missing value for --repo-root")
        }
        repo_root = args[index + 1]
        index += 2
      }
      value => return Err("Unknown argument: " + value)
    }
  }
  Ok({ repo_root, json, help, })
}

// ---------------------------------------------------------------------------
// Lexical helpers
// ---------------------------------------------------------------------------

///|
fn ident_char(ch : Char) -> Bool {
  ch == '_' ||
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= '0' && ch <= '9')
}

///|
fn ident_u16(code : UInt16) -> Bool {
  match code.to_char() {
    Some(ch) => ident_char(ch)
    None => false
  }
}

///|
/// Strip `//` line comments and string literals so identifier scans do not
/// match text inside prose or quotes. Blanked regions become spaces so byte
/// offsets stay comparable.
fn strip_comments_and_strings(text : String) -> String {
  let quote = '"'.to_int().to_uint16()
  let slash = '/'.to_int().to_uint16()
  let newline = '\n'.to_int().to_uint16()
  let backslash = '\\'.to_int().to_uint16()
  let buf = StringBuilder()
  let n = text.length()
  let mut i = 0
  let mut in_string = false
  let mut escaped = false
  while i < n {
    let c = text[i]
    if in_string {
      if escaped {
        escaped = false
        buf.write_char(' ')
      } else if c == backslash {
        escaped = true
        buf.write_char(' ')
      } else if c == quote {
        in_string = false
        buf.write_char(' ')
      } else {
        buf.write_char(' ')
      }
      i += 1
      continue
    }
    if c == quote {
      in_string = true
      buf.write_char(' ')
      i += 1
      continue
    }
    if c == slash && i + 1 < n && text[i + 1] == slash {
      while i < n && text[i] != newline {
        buf.write_char(' ')
        i += 1
      }
      continue
    }
    match c.to_char() {
      Some(ch) => buf.write_char(ch)
      None => buf.write_char(' ')
    }
    i += 1
  }
  buf.to_string()
}

// ---------------------------------------------------------------------------
// JSON catalog parsing
// ---------------------------------------------------------------------------

///|
fn json_string(obj : Json, key : String) -> String? {
  match obj {
    Object(fields) =>
      match fields.get(key) {
        Some(String(value)) => Some(value)
        _ => None
      }
    _ => None
  }
}

///|
fn json_array(obj : Json, key : String) -> Array[Json] {
  match obj {
    Object(fields) =>
      match fields.get(key) {
        Some(Array(items)) => items
        _ => []
      }
    _ => []
  }
}

///|
fn parse_catalog(text : String) -> Result[Catalog, String] {
  let parsed = @json.parse(text) catch {
    _ => return Err("catalog is not valid JSON")
  }
  let enums : Array[EnumSpec] = []
  for entry in json_array(parsed, "enums") {
    let name = match json_string(entry, "name") {
      Some(value) => value
      None => return Err("catalog entry missing \"name\"")
    }
    let path = match json_string(entry, "path") {
      Some(value) => value
      None => return Err("catalog entry \"" + name + "\" missing \"path\"")
    }
    let roots : Array[String] = []
    for root in json_array(entry, "scanRoots") {
      match root {
        String(value) => roots.push(value)
        _ => return Err("scanRoots entries must be strings (" + name + ")")
      }
    }
    if roots.is_empty() {
      return Err("catalog entry \"" + name + "\" has no scanRoots")
    }
    let waivers : Array[Waiver] = []
    for waiver in json_array(entry, "waivers") {
      let variant = match json_string(waiver, "variant") {
        Some(value) => value
        None => return Err("waiver in \"" + name + "\" missing \"variant\"")
      }
      let reason = json_string(waiver, "reason").unwrap_or("")
      if reason == "" {
        return Err(
          "waiver \"" + variant + "\" in \"" + name + "\" must carry a reason",
        )
      }
      waivers.push({ variant, reason, })
    }
    enums.push({ name, path, scan_roots: roots, waivers, })
  }
  if enums.is_empty() {
    return Err("catalog declares no enums")
  }
  Ok({ enums, })
}

// ---------------------------------------------------------------------------
// Enum body parsing
// ---------------------------------------------------------------------------

///|
/// Extract the `pub(all) enum <name> { ... }` body, using brace depth so nested
/// tuple payloads (`Variant(Array[Int], Msg)`) do not end the block early.
fn enum_body(source : String, name : String) -> String? {
  let needle = "enum " + name
  let mut start = -1
  let mut i = 0
  let n = source.length()
  while i < n {
    let mut matched = true
    let mut j = 0
    while matched && j < needle.length() {
      if i + j >= n || source[i + j] != needle[j] {
        matched = false
      }
      j += 1
    }
    if matched {
      let before_ok = i == 0 || !ident_u16(source[i - 1])
      if before_ok {
        start = i + needle.length()
        break
      }
    }
    i += 1
  }
  if start < 0 {
    return None
  }
  // find the opening brace
  let mut cursor = start
  while cursor < n && source[cursor] != '{' {
    cursor += 1
  }
  if cursor >= n {
    return None
  }
  let body_start = cursor + 1
  let mut depth = 1
  let mut k = body_start
  while k < n {
    let c = source[k]
    if c == '{' {
      depth += 1
    } else if c == '}' {
      depth -= 1
      if depth == 0 {
        return Some(source[body_start:k].to_owned())
      }
    }
    k += 1
  }
  None
}

///|
/// Variant names declared in an enum body: a line whose first non-space token
/// is an identifier followed by `(`, `//`, or end-of-line. Multi-line tuple
/// payloads are skipped because continuation lines do not start a new variant
/// at depth 0.
fn enum_variants(body : String) -> Array[String] {
  let names : Array[String] = []
  let mut depth = 0
  for raw in body.split("\n") {
    let line = raw.to_owned()
    let trimmed = line.trim_start().to_owned()
    if depth == 0 {
      match leading_ident(trimmed) {
        Some(name) => {
          // A variant line is `Name`, `Name(...)`, or `Name // comment`.
          // Lines like `mut x : Int` have a second token that is not `(`.
          let rest = trimmed[name.length():].trim_start()
          if rest == "" || rest.has_prefix("(") || rest.has_prefix("//") {
            names.push(name)
          }
        }
        None => ()
      }
    }
    depth += paren_delta(trimmed)
    if depth < 0 {
      depth = 0
    }
  }
  names
}

///|
fn leading_ident(line : String) -> String? {
  let mut i = 0
  let buf = StringBuilder()
  while i < line.length() {
    let ch = match line[i].to_char() {
      Some(ch) => ch
      None => break
    }
    if ident_char(ch) {
      buf.write_char(ch)
      i += 1
    } else {
      break
    }
  }
  let value = buf.to_string()
  if value == "" {
    None
  } else if is_upper_ident(value) {
    Some(value)
  } else {
    None
  }
}

///|
fn is_upper_ident(value : String) -> Bool {
  if value == "" {
    return false
  }
  match value[0].to_char() {
    Some(ch) => ch >= 'A' && ch <= 'Z'
    None => false
  }
}

///|
fn paren_delta(line : String) -> Int {
  let mut delta = 0
  for ch in line {
    if ch == '(' {
      delta += 1
    } else if ch == ')' {
      delta -= 1
    }
  }
  delta
}

// ---------------------------------------------------------------------------
// Construction-site detection
// ---------------------------------------------------------------------------

///|
/// True when some occurrence of `variant` in `text` reads as a construction
/// rather than a pattern/binding.
fn has_construction_site(text : String, variant : String) -> Bool {
  let m = variant.length()
  let n = text.length()
  let mut i = 0
  while i < n {
    let mut matched = true
    let mut j = 0
    while matched && j < m {
      if i + j >= n || text[i + j] != variant[j] {
        matched = false
      }
      j += 1
    }
    if !matched {
      i += 1
      continue
    }
    let before_ok = i == 0 || !ident_u16(text[i - 1])
    let after = i + m
    let after_ok = after >= n || !ident_u16(text[after])
    if !(before_ok && after_ok) {
      i += 1
      continue
    }
    // Reject qualified references: `@pkg.Variant`
    if i > 0 && text[i - 1] == '.' {
      i += 1
      continue
    }
    // Reject `Variant =>` and `Variant(...) =>` match arms.
    if arm_arrow_follows(text, after) {
      i += 1
      continue
    }
    // Reject pattern positions: `is Variant`, `| Variant`.
    if preceded_by_is_or_pipe(text, i) {
      i += 1
      continue
    }
    return true
  }
  false
}

///|
/// From `pos`, skip whitespace and an optional balanced `(...)` payload, then
/// report whether `=>` follows. `Variant =>` and `Variant(a) =>` are arms.
fn arm_arrow_follows(text : String, pos : Int) -> Bool {
  let n = text.length()
  let mut i = pos
  while i < n && is_space_u16(text[i]) {
    i += 1
  }
  if i < n && text[i] == '(' {
    let mut depth = 0
    while i < n {
      let c = text[i]
      if c == '(' {
        depth += 1
      } else if c == ')' {
        depth -= 1
        if depth == 0 {
          i += 1
          break
        }
      }
      i += 1
    }
    while i < n && is_space_u16(text[i]) {
      i += 1
    }
  }
  // Optional guard: `Variant if cond =>`
  if i + 2 < n &&
    text[i] == 'i' &&
    text[i + 1] == 'f' &&
    !ident_u16(text[i + 2]) {
    while i < n && text[i] != '=' && text[i] != '\n' {
      i += 1
    }
  }
  i + 1 < n && text[i] == '=' && text[i + 1] == '>'
}

///|
fn is_space_u16(code : UInt16) -> Bool {
  code == ' '.to_int().to_uint16() ||
  code == '\t'.to_int().to_uint16() ||
  code == '\n'.to_int().to_uint16() ||
  code == '\r'.to_int().to_uint16()
}

///|
/// True when the token immediately before `pos` is `is` or `|` (pattern use).
fn preceded_by_is_or_pipe(text : String, pos : Int) -> Bool {
  let mut i = pos
  while i > 0 && is_space_u16(text[i - 1]) {
    i -= 1
  }
  if i == 0 {
    return false
  }
  if text[i - 1] == '|' {
    return true
  }
  // `is` immediately before
  if i >= 2 && text[i - 1] == 's' && text[i - 2] == 'i' {
    let ok = i - 2 == 0 || !ident_u16(text[i - 3])
    if ok {
      return true
    }
  }
  false
}

// ---------------------------------------------------------------------------
// Filesystem scan
// ---------------------------------------------------------------------------

///|
fn is_mbt(path : String) -> Bool {
  path.has_suffix(".mbt")
}

///|
fn is_test_file(path : String) -> Bool {
  path.has_suffix("_test.mbt") || path.has_suffix("_wbtest.mbt")
}

///|
fn is_generated(path : String) -> Bool {
  path.has_suffix("_generated.mbt")
}

///|
/// Collect `.mbt` sources under `dir`, relative to `repo_root`, skipping
/// `_build`, dot-directories, and test/generated files.
fn collect_sources(root : String, dir : String, out : Array[String]) -> Unit {
  let full = @tools.resolve_path(root, dir)
  if !@tools.directory_exists(full) {
    return
  }
  let dir_view = @fs.read_dir(full) catch { _ => return }
  let entries : Array[String] = []
  for entry in dir_view {
    entries.push(entry)
  }
  entries.sort_by((left, right) => left.lexical_compare(right))
  for entry in entries {
    let name = entry
    if name == "_build" || name.has_prefix(".") || name == "node_modules" {
      continue
    }
    let child = if dir == "" { name } else { dir + "/" + name }
    let child_full = @tools.resolve_path(root, child)
    if @tools.directory_exists(child_full) {
      collect_sources(root, child, out)
    } else if @tools.file_exists(child_full) &&
      is_mbt(child) &&
      !is_test_file(child) &&
      !is_generated(child) {
      out.push(child)
    }
  }
}

///|
fn read_text(path : String) -> String? {
  match @tools.read_required_text(path, "scan input") {
    Ok(value) => Some(value)
    Err(_) => None
  }
}

///|
fn scan_repo(repo_root : String) -> Result[ScanResult, String] {
  let catalog_path = @tools.resolve_path(
    repo_root, "checks/dead-message-catalog.json",
  )
  let catalog_text = match read_text(catalog_path) {
    Some(value) => value
    None => return Err("cannot read checks/dead-message-catalog.json")
  }
  let catalog = match parse_catalog(catalog_text) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let violations : Array[Violation] = []
  let stale : Array[Violation] = []
  let mut variant_total = 0
  for spec in catalog.enums {
    let decl_path = spec.path
    let decl_full = @tools.resolve_path(repo_root, decl_path)
    let decl_source = match read_text(decl_full) {
      Some(value) => value
      None => return Err("catalog enum file not found: " + decl_path)
    }
    let body = match
      enum_body(strip_comments_and_strings(decl_source), spec.name) {
      Some(value) => value
      None => return Err("enum " + spec.name + " not found in " + decl_path)
    }
    let variants = enum_variants(body)
    if variants.is_empty() {
      return Err("enum " + spec.name + " declared no variants")
    }
    // Gather construction-scan text: every source under every scanRoot,
    // excluding the declaration file itself.
    let files : Array[String] = []
    for scan_root in spec.scan_roots {
      collect_sources(repo_root, scan_root, files)
    }
    let scanned = StringBuilder()
    for file in files {
      if file == decl_path {
        continue
      }
      match read_text(@tools.resolve_path(repo_root, file)) {
        Some(text) => {
          scanned.write_string(strip_comments_and_strings(text))
          scanned.write_string("\n")
        }
        None => ()
      }
    }
    let haystack = scanned.to_string()
    for variant in variants {
      variant_total += 1
      let constructed = has_construction_site(haystack, variant)
      let waiver = find_waiver(spec.waivers, variant)
      if constructed {
        match waiver {
          Some(found) =>
            stale.push({
              path: decl_path,
              enum_name: spec.name,
              variant,
              detail: "waived (" + found.reason + ") but now constructed",
            })
          None => ()
        }
      } else {
        match waiver {
          Some(_) => ()
          None =>
            violations.push({
              path: decl_path,
              enum_name: spec.name,
              variant,
              detail: "no construction site under " +
              @tools.comma_join(spec.scan_roots),
            })
        }
      }
    }
  }
  Ok({
    enums: catalog.enums.length(),
    variants: variant_total,
    violations,
    stale_waivers: stale,
  })
}

///|
fn find_waiver(waivers : Array[Waiver], variant : String) -> Waiver? {
  for waiver in waivers {
    if waiver.variant == variant {
      return Some(waiver)
    }
  }
  None
}

// ---------------------------------------------------------------------------
// Reporting
// ---------------------------------------------------------------------------

///|
fn violation_json(item : Violation) -> Json {
  Json::object(
    Map([
      ("path", Json::string(item.path)),
      ("enum", Json::string(item.enum_name)),
      ("variant", Json::string(item.variant)),
      ("detail", Json::string(item.detail)),
    ]),
  )
}

///|
fn result_to_json(result : ScanResult) -> Json {
  let items : Array[Json] = []
  for violation in result.violations {
    items.push(violation_json(violation))
  }
  let stale : Array[Json] = []
  for waiver in result.stale_waivers {
    stale.push(violation_json(waiver))
  }
  Json::object(
    Map([
      ("enums", Json::number(result.enums.to_double())),
      ("variants", Json::number(result.variants.to_double())),
      ("violations", Json::array(items)),
      ("stale_waivers", Json::array(stale)),
    ]),
  )
}

///|
fn run(args : Array[String]) -> Int {
  let options = match parse_cli(args) {
    Ok(value) => value
    Err(message) => {
      println(message)
      println(usage())
      return 2
    }
  }
  if options.help {
    println(usage())
    return 0
  }
  let result = match scan_repo(options.repo_root) {
    Ok(value) => value
    Err(message) => {
      println("validate-dead-messages: ERROR " + message)
      return 1
    }
  }
  let clean = result.violations.is_empty() && result.stale_waivers.is_empty()
  if options.json {
    println(result_to_json(result).stringify(indent=2))
  } else if clean {
    println(
      "validate-dead-messages: OK (" +
      result.variants.to_string() +
      " Msg variants across " +
      result.enums.to_string() +
      " enums, all constructed; dead-UI gate)",
    )
  } else {
    println("validate-dead-messages: FAIL")
    for violation in result.violations {
      println(
        "[dead-msg] " +
        violation.enum_name +
        "::" +
        violation.variant +
        " (" +
        violation.path +
        ")",
      )
      println("    " + violation.detail)
      println(
        "    hint: construct the message from a view/update path, delete the " +
        "dead variant, or waive it in checks/dead-message-catalog.json with a reason.",
      )
    }
    for waiver in result.stale_waivers {
      println(
        "[dead-msg-stale] " +
        waiver.enum_name +
        "::" +
        waiver.variant +
        " (" +
        waiver.path +
        ")",
      )
      println("    " + waiver.detail)
      println("    hint: delete the waiver entry (ratchet down).")
    }
  }
  if clean {
    0
  } else {
    1
  }
}

///|
fn main {
  let code = run(@tools.args_without_program(@env.args()))
  if code != 0 {
    @sys.exit(code)
  }
}
