///|
/// P17 (ADR 0034): every field stored in a `ViewNode` struct must be
/// referenced by that node's `declaration()` body — or by `identity()` for
/// identity-only fields — or carry an explicit
/// `// declaration-exempt: <reason>` marker on its struct line. A stored
/// field that appears in no channel key can silently miss layout/paint/
/// semantics cache invalidation, so this gate turns that class of bug into a
/// PR-time error. Waivers live in `checks/viewnode-declaration-coverage.json`
/// and ratchet down as `moui/views` is cleared.
struct NodeField {
  name : String
  exempt : Bool
} derive(Eq, Debug)

///|
struct StructDef {
  name : String
  line : Int
  fields : Array[NodeField]
} derive(Eq, Debug)

///|
struct NodeImpl {
  has_view_node : Bool
  has_declaration : Bool
  declaration_body : String
  identity_body : String
} derive(Eq, Debug)

///|
struct Violation {
  path : String
  node : String
  field : String
} derive(Eq, Debug)

///|
struct Waiver {
  pkg : String
  node : String
  field : String
  reason : String
} derive(Eq, Debug)

///|
struct Baseline {
  waived : Array[Waiver]
} derive(Eq, Debug)

///|
struct Finding {
  violations : Array[Violation]
  stale_waivers : Array[Waiver]
  scanned_nodes : Int
}

///|
fn usage() -> String {
  (
    #|Usage: tools/moui/validate_viewnode_declaration_coverage [--repo-root PATH] [--json]
    #|
    #|P17 ViewNode declaration-key coverage (ADR 0034). Waivers:
    #|checks/viewnode-declaration-coverage.json (schema v1).
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
  Ok({ repo_root, json, help })
}

///|
fn ident_char(ch : Char) -> Bool {
  ch == '_' ||
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= '0' && ch <= '9')
}

///|
/// String indexing yields UInt16 code units in this toolchain; bridge them
/// through Char for identifier classification (ASCII-only in practice).
fn ident_u16(code : UInt16) -> Bool {
  match code.to_char() {
    Some(ch) => ident_char(ch)
    None => false
  }
}

///|
/// Read an identifier run starting at byte `from` (identifier starts must be
/// ASCII; scanning stops at the first non-identifier byte).
fn ident_at(line : String, from : Int) -> String? {
  let mut i = from
  let mut found = false
  let buf = StringBuilder()
  while i < line.length() {
    let ch = match line[i].to_char() {
      Some(ch) => ch
      None => break
    }
    if ident_char(ch) {
      buf.write_char(ch)
      found = true
    } else {
      break
    }
    i += 1
  }
  if found {
    Some(buf.to_string())
  } else {
    None
  }
}

///|
/// True when `ident` occurs in `text` as a standalone identifier token (the
/// surrounding bytes are not identifier characters). `text` identifiers are
/// ASCII by MoonBit syntax, so byte-boundary scanning is sound.
fn contains_identifier(text : String, ident : String) -> Bool {
  let m = ident.length()
  if m == 0 {
    return false
  }
  let n = text.length()
  let quote = '"'.to_int().to_uint16()
  let slash = '/'.to_int().to_uint16()
  let equals = '='.to_int().to_uint16()
  let newline = '\n'.to_int().to_uint16()
  let backslash = '\\'.to_int().to_uint16()
  let mut i = 0
  let mut in_string = false
  let mut escaped = false
  while i < n {
    let c = text[i]
    if in_string {
      if escaped {
        escaped = false
      } else if c == backslash {
        escaped = true
      } else if c == quote {
        in_string = false
      }
      i += 1
      continue
    }
    if c == quote {
      in_string = true
      i += 1
      continue
    }
    if c == slash && i + 1 < n && text[i + 1] == slash {
      while i < n && text[i] != newline {
        i += 1
      }
      continue
    }
    let mut matched = true
    let mut j = 0
    while matched && j < m {
      if i + j >= n || text[i + j] != ident[j] {
        matched = false
      }
      j += 1
    }
    if matched {
      let before_ok = i == 0 || !ident_u16(text[i - 1])
      let after = i + m
      // `name=...` is a labelled argument, not a reference to `self.name`,
      // so a field cannot be "covered" by the channel label it is passed to.
      let after_ok = after >= n ||
        (!ident_u16(text[after]) && !(text[after] == equals))
      if before_ok && after_ok {
        return true
      }
    }
    i += 1
  }
  false
}

///|
/// If `line` opens a struct definition at column 0, return (name, true) for a
/// multi-line body or (name, false) when braces close on the same line.
fn struct_open(line : String) -> (String, Bool)? {
  let t = line.trim_end().to_owned()
  if !(t.has_prefix("struct ") ||
    t.has_prefix("priv struct ") ||
    t.has_prefix("pub struct ") ||
    (t.has_prefix("pub(") && t.contains(") struct "))) {
    return None
  }
  match t.find(" struct ") {
    None => None
    Some(idx) =>
      match ident_at(t, idx + 8) {
        None => None
        Some(name) => {
          let has_body = t.contains("{")
          let same_line_close = match t.find("{") {
            Some(open) =>
              match t.find("}") {
                Some(close) => close > open
                None => false
              }
            None => true
          }
          if !has_body {
            None
          } else if same_line_close {
            Some((name, false))
          } else {
            Some((name, true))
          }
        }
      }
  }
}

///|
/// Collect struct fields from the lines after a multi-line struct open, until
/// the closing brace at column 0. A field line is `name : Type` (single-line
/// types only; continuation lines are skipped). A trailing
/// `// declaration-exempt:` comment marks an intentional exclusion.
fn struct_fields(lines : Array[String], start : Int) -> (Array[NodeField], Int) {
  let fields : Array[NodeField] = []
  let mut index = start
  while index < lines.length() {
    let raw = lines[index]
    let line = raw.trim().to_owned()
    if line.is_empty() {
      index += 1
    } else if raw.has_prefix("}") {
      index += 1
      break
    } else {
      match ident_at(line, 0) {
        Some(name) => {
          let head = line[:name.length()].to_owned()
          let rest = line[name.length():]
          if head == name && rest.trim_start().has_prefix(":") {
            fields.push({ name, exempt: raw.contains("// declaration-exempt:") })
          }
          index += 1
        }
        None => index += 1
      }
    }
  }
  (fields, index)
}

///|
/// If `line` opens an `impl ... ViewNode for X with fn method` block, return
/// (node, method). Trait default impls (`impl ViewNode with fn ...`, no
/// `for Type`) are skipped.
fn impl_view_node_open(line : String) -> (String, String)? {
  let t = line.trim_end().to_owned()
  if !t.has_prefix("impl ") || !t.contains("ViewNode for ") {
    return None
  }
  match t.find("ViewNode for ") {
    None => None
    Some(node_at) =>
      match ident_at(t, node_at + 13) {
        None => None
        Some(node) =>
          match t.find("fn ") {
            None => None
            Some(fn_at) =>
              match ident_at(t, fn_at + 3) {
                None => None
                Some(fname) => Some((node, fname))
              }
          }
      }
  }
}

///|
/// Body text of the block opened at `start` (line after the open line),
/// ending at the closing brace at column 0. Single-line bodies return the
/// open line itself.
fn block_body(lines : Array[String], start : Int) -> (String, Int) {
  let mut index = start
  let buf = StringBuilder()
  if index >= lines.length() {
    return ("", index)
  }
  let head = lines[index].trim().to_owned()
  if head.has_prefix("}") {
    return ("", index)
  }
  let mut started = false
  while index < lines.length() {
    let raw = lines[index]
    if raw.has_prefix("}") {
      break
    }
    if started {
      buf.write_char('\n')
    }
    started = true
    buf.write_string(raw)
    index += 1
  }
  (buf.to_string(), index)
}

///|
/// Scan one file's lines into structs and aggregated ViewNode impl bodies.
/// Aggregation is keyed by (package_dir, node name) because `priv` structs and
/// their `impl @core.ViewNode for X` blocks may be split across sibling files
/// of the same package (views/text splits node structs and method impls).
fn scan_file_lines(
  pkg : String,
  lines : Array[String],
) -> (Map[String, StructDef], Map[String, NodeImpl]) {
  let structs : Map[String, StructDef] = Map([])
  let impls : Map[String, NodeImpl] = Map([])
  let mut index = 0
  while index < lines.length() {
    let line = lines[index]
    match struct_open(line) {
      Some((name, multi_line)) =>
        if multi_line {
          let (fields, next) = struct_fields(lines, index + 1)
          if fields.length() > 0 && !structs.contains(name) {
            structs[name] = { name, line: index + 1, fields }
          }
          index = next
        } else {
          index += 1
        }
      None =>
        match impl_view_node_open(line) {
          Some((node, fname)) => {
            let key = pkg + "|" + node
            let existing = match impls.get(key) {
              Some(e) => e
              None =>
                {
                  has_view_node: false,
                  has_declaration: false,
                  declaration_body: "",
                  identity_body: "",
                }
            }
            let (body, next) = block_body(lines, index + 1)
            let is_declaration = fname == "declaration"
            let is_identity = fname == "identity"
            impls[key] = {
              has_view_node: true,
              has_declaration: existing.has_declaration || is_declaration,
              declaration_body: if is_declaration {
                existing.declaration_body + "\n" + body
              } else {
                existing.declaration_body
              },
              identity_body: if is_identity {
                existing.identity_body + "\n" + body
              } else {
                existing.identity_body
              },
            }
            index = next
          }
          None => index += 1
        }
    }
  }
  (structs, impls)
}

///|
/// Coverage rule for one struct against its aggregated ViewNode impl:
/// a struct whose node never overrides `declaration()` relies on the
/// conservative uncacheable trait default and is safe by construction.
fn struct_violations(
  path : String,
  struct_def : StructDef,
  impl_entry : NodeImpl,
) -> Array[Violation] {
  let violations : Array[Violation] = []
  if !impl_entry.has_view_node || !impl_entry.has_declaration {
    return violations
  }
  for field in struct_def.fields {
    let covered = field.exempt ||
      contains_identifier(impl_entry.declaration_body, field.name) ||
      contains_identifier(impl_entry.identity_body, field.name)
    if !covered {
      violations.push({ path, node: struct_def.name, field: field.name })
    }
  }
  violations
}

///|
fn json_object_field(json : Json) -> Map[String, Json]? {
  match json {
    Json::Object(fields) => Some(fields)
    _ => None
  }
}

///|
fn json_string_field(json : Json?) -> String? {
  match json {
    Some(Json::String(value)) => Some(value)
    _ => None
  }
}

///|
fn json_array_items(json : Json?) -> Array[Json]? {
  match json {
    Some(Json::Array(items)) => Some(items)
    _ => None
  }
}

///|
/// Load the waiver baseline. A missing file is allowed (zero waivers) only
/// before the catalog is first checked in; parse errors fail loudly.
fn load_baseline(path : String) -> Result[Baseline, String] {
  if !@tools.file_exists(path) {
    return Ok({ waived: [] })
  }
  let text = match @tools.read_required_text(path, "coverage baseline") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let parsed = @json.parse(text) catch {
    _ => return Err("coverage baseline is not valid JSON: " + path)
  }
  let root = match json_object_field(parsed) {
    Some(fields) => fields
    None => return Err("coverage baseline must be a JSON object")
  }
  match root.get("schemaVersion") {
    Some(Json::Number(v, repr=_)) =>
      if v != 1.0 {
        return Err("coverage baseline schemaVersion must be 1")
      }
    _ => return Err("coverage baseline requires schemaVersion: 1")
  }
  let items = match json_array_items(root.get("waived")) {
    Some(items) => items
    None => return Err("coverage baseline requires a waived array")
  }
  let waived : Array[Waiver] = []
  for item in items {
    let fields = match json_object_field(item) {
      Some(fields) => fields
      None => return Err("coverage waiver entry must be an object")
    }
    let pkg = match json_string_field(fields.get("package")) {
      Some(v) => v
      None => return Err("coverage waiver requires package")
    }
    let node = match json_string_field(fields.get("node")) {
      Some(v) => v
      None => return Err("coverage waiver requires node")
    }
    let field = match json_string_field(fields.get("field")) {
      Some(v) => v
      None => return Err("coverage waiver requires field")
    }
    let reason = match json_string_field(fields.get("reason")) {
      Some(v) => v
      None => return Err("coverage waiver requires reason")
    }
    waived.push({ pkg, node, field, reason })
  }
  Ok({ waived, })
}

///|
fn skipped_directory(name : String) -> Bool {
  name == ".git" ||
  name == "node_modules" ||
  name == "_build" ||
  name == "build" ||
  name == "target" ||
  name == ".moon" ||
  name == ".mooncakes"
}

///|
fn is_non_test_mbt(name : String) -> Bool {
  name.has_suffix(".mbt") &&
  !name.has_suffix("_test.mbt") &&
  !name.has_suffix("_wbtest.mbt")
}

///|
fn collect_mbt(
  repo_root : String,
  relative_dir : String,
  files : Array[(String, String)],
) -> Unit {
  let absolute = @tools.resolve_path(repo_root, relative_dir)
  if !@tools.directory_exists(absolute) {
    return
  }
  let entries : Array[String] = @fs.read_dir(absolute) catch { _ => return }
  entries.sort_by((left, right) => left.lexical_compare(right))
  for entry in entries {
    if skipped_directory(entry) {
      continue
    }
    let relative = relative_dir + "/" + entry
    let full = @tools.resolve_path(repo_root, relative)
    if @tools.directory_exists(full) {
      collect_mbt(repo_root, relative, files)
    } else if @tools.file_exists(full) && is_non_test_mbt(entry) {
      files.push((relative, entry))
    }
  }
}

///|
fn package_of(relative : String) -> String {
  let mut last = -1
  let mut index = 0
  while index < relative.length() {
    if relative[index] == '/' {
      last = index
    }
    index += 1
  }
  if last >= 0 {
    relative[:last].to_owned()
  } else {
    "."
  }
}

///|
/// Split raw violations into (not waived, stale waivers). A waiver whose
/// violation no longer reproduces must be deleted (ratchet-down hygiene).
fn apply_waivers(
  violations : Array[Violation],
  baseline : Baseline,
) -> (Array[Violation], Array[Waiver]) {
  let waived_keys : Set[String] = Set([])
  for waiver in baseline.waived {
    waived_keys.add(waiver.pkg + "|" + waiver.node + "|" + waiver.field)
  }
  let violation_keys : Set[String] = Set([])
  for violation in violations {
    violation_keys.add(
      package_of(violation.path) + "|" + violation.node + "|" + violation.field,
    )
  }
  let active : Array[Violation] = []
  for violation in violations {
    let key = package_of(violation.path) +
      "|" +
      violation.node +
      "|" +
      violation.field
    if !waived_keys.contains(key) {
      active.push(violation)
    }
  }
  let stale_waivers : Array[Waiver] = []
  for waiver in baseline.waived {
    let key = waiver.pkg + "|" + waiver.node + "|" + waiver.field
    if !violation_keys.contains(key) {
      stale_waivers.push(waiver)
    }
  }
  (active, stale_waivers)
}

///|
/// Scan framework packages and compare against the waiver baseline.
fn scan_repo(repo_root : String) -> Result[Finding, String] {
  let baseline_path = @tools.resolve_path(
    repo_root, "checks/viewnode-declaration-coverage.json",
  )
  let baseline = match load_baseline(baseline_path) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let files : Array[(String, String)] = []
  collect_mbt(repo_root, "moui", files)
  let violations : Array[Violation] = []
  let mut scanned_nodes = 0
  for item in files {
    let (relative, _name) = item
    let pkg = package_of(relative)
    let text = match
      @tools.read_required_text(
        @tools.resolve_path(repo_root, relative),
        "scanned source",
      ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let lines = text.split("\n").map(v => v.to_owned()).collect()
    let (structs, impls) = scan_file_lines(pkg, lines)
    for name, struct_def in structs {
      match impls.get(pkg + "|" + name) {
        Some(entry) => {
          if entry.has_view_node && entry.has_declaration {
            scanned_nodes += 1
          }
          for violation in struct_violations(relative, struct_def, entry) {
            violations.push(violation)
          }
        }
        None => ()
      }
    }
  }
  let (active, stale_waivers) = apply_waivers(violations, baseline)
  Ok({ violations: active, stale_waivers, scanned_nodes })
}

///|
fn violations_to_json(finding : Finding) -> Json {
  let items : Array[Json] = []
  for violation in finding.violations {
    items.push(
      Json::object(
        Map([
          ("path", Json::string(violation.path)),
          ("node", Json::string(violation.node)),
          ("field", Json::string(violation.field)),
        ]),
      ),
    )
  }
  let stale : Array[Json] = []
  for waiver in finding.stale_waivers {
    stale.push(
      Json::object(
        Map([
          ("package", Json::string(waiver.pkg)),
          ("node", Json::string(waiver.node)),
          ("field", Json::string(waiver.field)),
        ]),
      ),
    )
  }
  let ok = finding.violations.is_empty() && finding.stale_waivers.is_empty()
  Json::object(
    Map([
      ("ok", Json::boolean(ok)),
      (
        "scanned_nodes",
        Json::number(
          finding.scanned_nodes.to_double(),
          repr=finding.scanned_nodes.to_string(),
        ),
      ),
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
  let finding = match scan_repo(options.repo_root) {
    Ok(value) => value
    Err(message) => {
      println("validate-viewnode-declaration-coverage: ERROR " + message)
      return 1
    }
  }
  let clean = finding.violations.is_empty() && finding.stale_waivers.is_empty()
  if options.json {
    println(violations_to_json(finding).stringify(indent=2))
  } else if clean {
    println(
      "validate-viewnode-declaration-coverage: OK (" +
      finding.scanned_nodes.to_string() +
      " ViewNode nodes with declaration() overrides; rule P17)",
    )
  } else {
    println("validate-viewnode-declaration-coverage: FAIL")
    for violation in finding.violations {
      println(
        "[P17] " +
        violation.path +
        " — " +
        violation.node +
        "." +
        violation.field,
      )
      println(
        "    hint: add the field to the relevant channel key in " +
        "declaration(), to identity() for identity-only fields, or mark " +
        "the struct line with `// declaration-exempt: <reason>`.",
      )
    }
    for waiver in finding.stale_waivers {
      println(
        "[P17-stale] waived but no longer violating: " +
        waiver.pkg +
        "." +
        waiver.node +
        "." +
        waiver.field,
      )
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
