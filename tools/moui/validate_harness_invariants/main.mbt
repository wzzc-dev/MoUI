///|
struct HarnessFinding {
  rule : String
  ok : Bool
  path : String
  hint : String
}

///|
struct Entrypoint {
  example : String
  path : String
  mobile : Bool
}

///|
fn usage() -> String {
  (
    #|Usage: tools/moui/validate_harness_invariants [--repo-root PATH] [--json]
    #|
    #|Harness batch-1 structural invariants: P1/P2/R3/G1.
    #|
  )
}

///|
fn entry_suffixes() -> Array[String] {
  [
    "web_wasm", "macos_skia", "windows_skia", "linux_skia", "android_skia", "ios_skia",
    "harmonyos_skia",
  ]
}

///|
fn is_mobile_suffix(suffix : String) -> Bool {
  suffix == "android_skia" || suffix == "ios_skia" || suffix == "harmonyos_skia"
}

///|
fn max_lines_for(mobile : Bool) -> Int {
  if mobile {
    500
  } else {
    320
  }
}

///|
fn max_non_test_mbt() -> Int {
  3
}

///|
fn core_control_fns() -> Array[String] {
  [
    "button", "checkbox", "toggle", "switch", "slider", "text_field", "textfield",
    "text_input", "radio", "picker", "menu_bar", "menu_item", "dialog", "alert",
    "sheet", "tab_view", "tabs", "navigation_stack", "navigation_view", "list_row",
    "table_view", "progress_bar", "progress_view", "scroll_view", "form", "section",
    "label", "image_view", "webview",
  ]
}

///|
fn desktop_skia_providers() -> Array[String] {
  [
    "moui/backend/macos/skia/macos_skia_provider.mbt", "moui/backend/windows/skia/windows_skia_provider.mbt",
    "moui/backend/linux/skia/linux_skia_provider.mbt",
  ]
}

///|
fn drop_prefix(text : String, prefix : String) -> String {
  if text.has_prefix(prefix) {
    text[prefix.length():].to_owned()
  } else {
    text
  }
}

///|
fn product_logic_label(line : String) -> String? {
  let trimmed = line.trim().to_owned()
  let body = drop_prefix(trimmed, "pub ")
  if body.has_prefix("fn update") {
    Some("fn update")
  } else if body.has_prefix("fn view") {
    Some("fn view")
  } else if body.has_prefix("struct Model") || body.has_prefix("enum Model") {
    Some("Model type")
  } else if body.has_prefix("enum Msg") {
    Some("enum Msg")
  } else if body.has_prefix("struct Msg") {
    Some("struct Msg")
  } else {
    None
  }
}

///|
fn line_count(text : String) -> Int {
  if text == "" {
    return 0
  }
  let mut lines = 1
  for ch in text {
    if ch == '\n' {
      lines += 1
    }
  }
  lines
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
fn collect_files_with_suffix(
  repo_root : String,
  relative_dir : String,
  keep : (String) -> Bool,
  files : Array[String],
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
      collect_files_with_suffix(repo_root, relative, keep, files)
    } else if @tools.file_exists(full) && keep(entry) {
      files.push(relative)
    }
  }
}

///|
fn list_example_entrypoints(repo_root : String) -> Array[Entrypoint] {
  let found : Array[Entrypoint] = []
  let examples_root = @tools.resolve_path(repo_root, "examples")
  if !@tools.directory_exists(examples_root) {
    return found
  }
  let examples : Array[String] = @fs.read_dir(examples_root) catch {
    _ => return found
  }
  examples.sort_by((left, right) => left.lexical_compare(right))
  for name in examples {
    let ex_dir = @tools.resolve_path(repo_root, "examples/" + name)
    if !@tools.directory_exists(ex_dir) {
      continue
    }
    for suffix in entry_suffixes() {
      let path = "examples/" + name + "/" + suffix
      if @tools.directory_exists(@tools.resolve_path(repo_root, path)) {
        found.push({ example: name, path, mobile: is_mobile_suffix(suffix) })
      }
    }
  }
  found
}

///|
fn push_ok(
  results : Array[HarnessFinding],
  rule : String,
  path : String,
) -> Unit {
  results.push({ rule, ok: true, path, hint: "" })
}

///|
fn push_fail(
  results : Array[HarnessFinding],
  rule : String,
  path : String,
  hint : String,
) -> Unit {
  results.push({ rule, ok: false, path, hint })
}

///|
fn check_p1_entry_texts(
  entry : Entrypoint,
  has_app_package : Bool,
  has_root_app : Bool,
  mbt_files : Array[String],
  file_texts : Map[String, String],
) -> Array[HarnessFinding] {
  let results : Array[HarnessFinding] = []
  let mut failed = false
  if !has_app_package && !has_root_app {
    failed = true
    push_fail(
      results,
      "P1",
      entry.path,
      "missing examples/" +
      entry.example +
      "/app (or root app.mbt). Fix: keep product logic out of platform entrypoints. See docs/invariants.md#P1",
    )
  }
  if mbt_files.is_empty() {
    push_fail(
      results,
      "P1",
      entry.path,
      "entrypoint package has no non-test .mbt files. See docs/invariants.md#P1",
    )
    return results
  }
  if mbt_files.length() > max_non_test_mbt() {
    failed = true
    push_fail(
      results,
      "P1",
      entry.path,
      "too many non-test .mbt files (" +
      mbt_files.length().to_string() +
      " > " +
      max_non_test_mbt().to_string() +
      "). Fix: move logic to examples/" +
      entry.example +
      "/app. See docs/invariants.md#P1",
    )
  }
  let mut total_lines = 0
  for file in mbt_files {
    let text = match file_texts.get(file) {
      Some(value) => value
      None => ""
    }
    total_lines += line_count(text)
    for line in text.split("\n") {
      match product_logic_label(line.to_owned()) {
        Some(label) => {
          failed = true
          push_fail(
            results,
            "P1",
            file,
            "product logic pattern " +
            label +
            " in platform entrypoint. Fix: move to examples/" +
            entry.example +
            "/app. See docs/invariants.md#P1",
          )
        }
        None => ()
      }
    }
  }
  let max_lines = max_lines_for(entry.mobile)
  if total_lines > max_lines {
    failed = true
    let kind = if entry.mobile { "mobile" } else { "desktop/web" }
    push_fail(
      results,
      "P1",
      entry.path,
      "entrypoint non-test lines " +
      total_lines.to_string() +
      " exceed " +
      max_lines.to_string() +
      " (" +
      kind +
      " budget). Fix: move logic to examples/" +
      entry.example +
      "/app. See docs/invariants.md#P1",
    )
  }
  if !failed {
    push_ok(results, "P1", entry.path)
  }
  results
}

///|
fn is_view_enum_decl(line : String) -> Bool {
  let trimmed = line.trim().to_owned()
  let body = if trimmed.has_prefix("pub(all) ") {
    drop_prefix(trimmed, "pub(all) ")
  } else if trimmed.has_prefix("pub ") {
    drop_prefix(trimmed, "pub ")
  } else {
    trimmed
  }
  if !body.has_prefix("enum View") {
    return false
  }
  let rest = body["enum View".length():].to_owned()
  rest == "" ||
  rest.has_prefix(" ") ||
  rest.has_prefix("{") ||
  rest.has_prefix("[")
}

///|
fn has_public_enum_view(text : String) -> Bool {
  for line in text.split("\n") {
    if is_view_enum_decl(line.to_owned()) {
      return true
    }
  }
  false
}

///|
fn has_pub_fn_named(text : String, name : String) -> Bool {
  let needle = "fn " + name
  for line in text.split("\n") {
    let trimmed = line.trim().to_owned()
    if !trimmed.has_prefix("pub ") {
      continue
    }
    let body = drop_prefix(trimmed, "pub ")
    if body.has_prefix(needle) {
      let rest = body[needle.length():].to_owned()
      if rest == "" ||
        rest.has_prefix(" ") ||
        rest.has_prefix("(") ||
        rest.has_prefix("[") {
        return true
      }
    }
    // pub fn[T] name
    if body.has_prefix("fn[") {
      match body.find("] ") {
        Some(offset) => {
          let after = body[offset + 2:].to_owned()
          if after.has_prefix(name) {
            let rest = after[name.length():].to_owned()
            if rest == "" ||
              rest.has_prefix(" ") ||
              rest.has_prefix("(") ||
              rest.has_prefix("[") {
              return true
            }
          }
        }
        None => ()
      }
    }
  }
  false
}

///|
fn check_p2_texts(
  mbti_path : String,
  mbti_text : String?,
  core_files : Array[(String, String)],
) -> Array[HarnessFinding] {
  let results : Array[HarnessFinding] = []
  match mbti_text {
    None => {
      push_fail(
        results, "P2", mbti_path, "missing generated interface. Fix: run moon info for moui/core. See docs/invariants.md#P2",
      )
      return results
    }
    Some(mbti) => {
      if has_public_enum_view(mbti) {
        push_fail(
          results, "P2", mbti_path, "public enum View in core is forbidden for app controls. Fix: keep opaque View + View::node; put controls in moui/views. See docs/invariants.md#P2",
        )
      }
      for name in core_control_fns() {
        if has_pub_fn_named(mbti, name) {
          push_fail(
            results,
            "P2",
            mbti_path,
            "core public control constructor pub fn " +
            name +
            ". Fix: move control to moui/views via @core.View::node. See docs/invariants.md#P2",
          )
        }
      }
    }
  }
  for pair in core_files {
    let (file, text) = pair
    if has_public_enum_view(text) {
      push_fail(
        results, "P2", file, "pub enum View in core source. Fix: controls belong in moui/views. See docs/invariants.md#P2",
      )
    }
    for name in core_control_fns() {
      if has_pub_fn_named(text, name) {
        push_fail(
          results,
          "P2",
          file,
          "pub fn " +
          name +
          " in core. Fix: implement in moui/views with @core.View::node. See docs/invariants.md#P2",
        )
      }
    }
  }
  if !results.any(item => !item.ok) {
    push_ok(results, "P2", "moui/core")
  }
  results
}

///|
fn check_r3_provider_text(path : String, text : String?) -> HarnessFinding {
  match text {
    None =>
      {
        rule: "R3",
        ok: false,
        path,
        hint: "missing desktop Skia provider. Fix: restore provider that reads MOUI_SKIA_RENDERER. See docs/invariants.md#R3",
      }
    Some(body) => {
      let has_env = body.contains("MOUI_SKIA_RENDERER")
      let has_parse = body.contains("NativeRendererMode::parse") ||
        body.contains("select_native_renderer")
      if !has_env || !has_parse {
        {
          rule: "R3",
          ok: false,
          path,
          hint: "desktop Skia provider must honor MOUI_SKIA_RENDERER (auto|skia-gpu|skia-raster) via NativeRendererMode/select_native_renderer. Fix: restore env-driven selection. See docs/invariants.md#R3",
        }
      } else {
        { rule: "R3", ok: true, path, hint: "" }
      }
    }
  }
}

///|
fn check_r3_mobile_main(path : String, text : String?) -> HarnessFinding {
  match text {
    None =>
      {
        rule: "R3",
        ok: false,
        path,
        hint: "mobile entry missing main.mbt. See docs/invariants.md#R3",
      }
    Some(body) => {
      let has_selection = body.contains("mobile_renderer_selection") ||
        body.contains("mobile_renderer_configure")
      let has_configure = body.contains("moui_mobile_renderer_configure")
      if !has_selection || !has_configure {
        {
          rule: "R3",
          ok: false,
          path,
          hint: "mobile entry must expose renderer selection/configure (auto|skia-gpu|skia-raster path). Fix: wire @host.mobile_renderer_selection / moui_mobile_renderer_configure. See docs/invariants.md#R3",
        }
      } else {
        { rule: "R3", ok: true, path, hint: "" }
      }
    }
  }
}

///|
fn check_r3_prepare(path : String, text : String?) -> HarnessFinding {
  match text {
    None =>
      {
        rule: "R3",
        ok: false,
        path,
        hint: "missing mobile prepare-native-build helper. See docs/invariants.md#R3",
      }
    Some(body) => {
      let ok = body.contains("--renderer") &&
        body.contains("auto") &&
        body.contains("skia-gpu") &&
        body.contains("skia-raster")
      {
        rule: "R3",
        ok,
        path,
        hint: if ok {
          ""
        } else {
          "prepare-native-build must accept --renderer auto|skia-gpu|skia-raster. See docs/invariants.md#R3"
        },
      }
    }
  }
}

///|
fn count_p_rows(text : String) -> Int {
  let mut count = 0
  for line in text.split("\n") {
    let trimmed = line.trim().to_owned()
    if trimmed.has_prefix("|") {
      let rest = trimmed[1:].to_owned().trim().to_owned()
      if rest.has_prefix("P") &&
        rest.length() >= 2 &&
        rest[1] >= '1' &&
        rest[1] <= '9' {
        let after = rest[2:].to_owned().trim().to_owned()
        if after.has_prefix("|") {
          count += 1
        }
      }
    }
  }
  count
}

///|
fn check_g1_skill_text(path : String, text : String) -> HarnessFinding? {
  if count_p_rows(text) >= 3 {
    Some({
      rule: "G1",
      ok: false,
      path,
      hint: "skill re-lists invariant P-rows. Fix: link docs/invariants.md instead of copying the table. See docs/golden-principles.md",
    })
  } else {
    None
  }
}

///|
fn read_optional_text(repo_root : String, path : String) -> String? {
  match @tools.read_required_text(@tools.resolve_path(repo_root, path), path) {
    Ok(text) => Some(text)
    Err(_) => None
  }
}

///|
fn validate_repo(repo_root : String) -> Array[HarnessFinding] {
  let results : Array[HarnessFinding] = []
  let entries = list_example_entrypoints(repo_root)
  if entries.is_empty() {
    push_fail(
      results, "P1", "examples", "no platform entry packages found. Fix: restore examples/*/app + thin entrypoints. See docs/invariants.md#P1",
    )
  }
  for entry in entries {
    let has_app_package = @tools.directory_exists(
      @tools.resolve_path(repo_root, "examples/" + entry.example + "/app"),
    )
    let has_root_app = @tools.file_exists(
      @tools.resolve_path(repo_root, "examples/" + entry.example + "/app.mbt"),
    )
    let mbt_files : Array[String] = []
    collect_files_with_suffix(repo_root, entry.path, is_non_test_mbt, mbt_files)
    let file_texts : Map[String, String] = Map([])
    for file in mbt_files {
      match read_optional_text(repo_root, file) {
        Some(text) => file_texts[file] = text
        None => ()
      }
    }
    for
      item in check_p1_entry_texts(
        entry, has_app_package, has_root_app, mbt_files, file_texts,
      ) {
      results.push(item)
    }
  }

  let core_mbti = "moui/core/pkg.generated.mbti"
  let core_files_paths : Array[String] = []
  collect_files_with_suffix(
    repo_root, "moui/core", is_non_test_mbt, core_files_paths,
  )
  let core_files : Array[(String, String)] = []
  for file in core_files_paths {
    match read_optional_text(repo_root, file) {
      Some(text) => core_files.push((file, text))
      None => ()
    }
  }
  for
    item in check_p2_texts(
      core_mbti,
      read_optional_text(repo_root, core_mbti),
      core_files,
    ) {
    results.push(item)
  }

  for path in desktop_skia_providers() {
    results.push(
      check_r3_provider_text(path, read_optional_text(repo_root, path)),
    )
  }
  for entry in entries {
    if entry.mobile {
      let main_path = entry.path + "/main.mbt"
      results.push(
        check_r3_mobile_main(
          main_path,
          read_optional_text(repo_root, main_path),
        ),
      )
    }
  }
  let prepare = "moui/scripts/mobile/prepare-native-build.mjs"
  results.push(
    check_r3_prepare(prepare, read_optional_text(repo_root, prepare)),
  )

  let skill_files : Array[String] = []
  for root in ["skills", ".agents/skills"] {
    if @tools.directory_exists(@tools.resolve_path(repo_root, root)) {
      collect_files_with_suffix(
        repo_root,
        root,
        name => name.has_suffix(".md"),
        skill_files,
      )
    }
  }
  let mut g1_bad = 0
  for file in skill_files {
    match read_optional_text(repo_root, file) {
      Some(text) =>
        match check_g1_skill_text(file, text) {
          Some(finding) => {
            g1_bad += 1
            results.push(finding)
          }
          None => ()
        }
      None => ()
    }
  }
  if g1_bad == 0 {
    results.push({
      rule: "G1",
      ok: true,
      path: "skills/",
      hint: "scanned " +
      skill_files.length().to_string() +
      " skill markdown file(s)",
    })
  }
  results
}

///|
fn finding_to_json(finding : HarnessFinding) -> Json {
  let object : Map[String, Json] = Map([])
  object["rule"] = Json::string(finding.rule)
  object["ok"] = Json::boolean(finding.ok)
  object["path"] = Json::string(finding.path)
  object["hint"] = Json::string(finding.hint)
  Json::object(object)
}

///|
fn results_to_json(results : Array[HarnessFinding]) -> Json {
  let failures = results.filter(item => !item.ok)
  let object : Map[String, Json] = Map([])
  object["schemaVersion"] = Json::number(1.0, repr="1")
  object["tool"] = Json::string("validate-harness-invariants")
  object["rules"] = Json::array(
    ["P1", "P2", "R3", "G1"].map(rule => Json::string(rule)),
  )
  object["results"] = Json::array(results.map(finding_to_json))
  object["failures"] = Json::array(failures.map(finding_to_json))
  Json::object(object)
}

///|
struct CliOptions {
  repo_root : String
  json : Bool
  help : Bool
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let mut repo_root = @env.current_dir().unwrap_or("")
  let mut json = false
  let mut help = false
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "-h" | "--help" => {
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
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Err(message) => {
      println(message)
      println(usage())
      2
    }
    Ok(options) => {
      if options.help {
        println(usage())
        return 0
      }
      let results = validate_repo(options.repo_root)
      let failures = results.filter(item => !item.ok)
      if options.json {
        println(results_to_json(results).stringify(indent=2))
      } else if failures.is_empty() {
        let ok_counts = results.filter(item => item.ok).length()
        println(
          "validate-harness-invariants: OK (" +
          ok_counts.to_string() +
          " checks; rules P1/P2/R3/G1; JSON via --json)",
        )
      } else {
        println("validate-harness-invariants: FAIL")
        for item in failures {
          println("")
          println("[" + item.rule + "] " + item.path)
          println("  " + item.hint)
        }
      }
      if failures.is_empty() {
        0
      } else {
        1
      }
    }
  }
}

///|
fn main {
  let code = run(@tools.args_without_program(@env.args()))
  if code != 0 {
    @sys.exit(code)
  }
}
