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
  line_budget : Int
}

///|
struct MatrixEntrypointRoute {
  suffix : String
  mobile : Bool
  line_budget : Int
}

///|
fn usage() -> String {
  (
    #|Usage: tools/moui/validate_harness_invariants [--repo-root PATH] [--json] [--skip-examples]
    #|
    #|Harness batch-1 structural invariants: P1/P2/R3/G1.
    #|
    #|--skip-examples  skip example entrypoint scans (P1 catalog, entry texts,
    #|                 mobile R3 entry checks); core/renderer/pipeline/skills
    #|                 checks still run. Composition-root wrappers pass this
    #|                 so app iteration does not trip repo-level budgets.
    #|
  )
}

///|
fn max_non_test_mbt() -> Int {
  2
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
  ["moui_skia_renderer/binding_factory.mbt"]
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
fn token_count(text : String, token : String) -> Int {
  let mut parts = 0
  for _ in text.split(token) {
    parts += 1
  }
  if parts == 0 {
    0
  } else {
    parts - 1
  }
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
fn path_basename(path : String) -> String {
  let mut result = ""
  for part in path.split("/") {
    if part != "" {
      result = part.to_owned()
    }
  }
  result
}

///|
fn parse_matrix_entrypoint_routes(
  repo_root : String,
) -> Result[Array[MatrixEntrypointRoute], String] {
  let path = "checks/platform-matrix.json"
  let text = match read_optional_text(repo_root, path) {
    Some(text) => text
    None => return Err("missing " + path)
  }
  let parsed = @json.parse(text) catch {
    _ => return Err(path + ": invalid JSON")
  }
  let fields = match parsed {
    Object(fields) => fields
    _ => return Err(path + " must be an object")
  }
  let routes = match fields.get("routes") {
    Some(Array(routes)) => routes
    _ => return Err(path + ".routes must be an array")
  }
  let result : Array[MatrixEntrypointRoute] = []
  for route in routes {
    let route_fields = match route {
      Object(route_fields) => route_fields
      _ => return Err(path + ".routes entries must be objects")
    }
    let showcase_package = match route_fields.get("showcasePackage") {
      Some(String(value)) => value
      _ => return Err(path + ": route showcasePackage must be a string")
    }
    let _ = match route_fields.get("tier") {
      Some(Number(value, repr=_)) => value.to_int()
      _ => return Err(path + ": route tier must be an integer")
    }
    let kind = match route_fields.get("entrypointKind") {
      Some(String(value)) => value
      _ => return Err(path + ": route entrypointKind must be a string")
    }
    let line_budget = match route_fields.get("lineBudget") {
      Some(Number(value, repr=_)) => value.to_int()
      _ => return Err(path + ": route lineBudget must be an integer")
    }
    let suffix = path_basename(showcase_package)
    if result.any(item => item.suffix == suffix) {
      return Err(path + ": duplicate entrypoint suffix " + suffix)
    }
    result.push({ suffix, mobile: kind == "mobile", line_budget })
  }
  if result.is_empty() {
    Err(path + ": routes must not be empty")
  } else {
    Ok(result)
  }
}

///|
fn platform_prefix(suffix : String) -> String {
  match suffix.find("_") {
    Some(offset) => suffix[:offset].to_owned()
    None => suffix
  }
}

///|
fn looks_like_platform_root(
  name : String,
  routes : Array[MatrixEntrypointRoute],
) -> Bool {
  routes.any(route => {
    let prefix = platform_prefix(route.suffix)
    name == route.suffix || name.has_prefix(prefix + "_")
  })
}

///|
fn find_matrix_route(
  routes : Array[MatrixEntrypointRoute],
  suffix : String,
) -> MatrixEntrypointRoute? {
  routes.iter().find_first(route => route.suffix == suffix)
}

///|
fn validate_entrypoint_catalog(
  repo_root : String,
  routes : Array[MatrixEntrypointRoute],
) -> Array[HarnessFinding] {
  let results : Array[HarnessFinding] = []
  let ui_roots : Array[String] = []
  let examples_root = @tools.resolve_path(repo_root, "examples")
  let examples : Array[String] = @fs.read_dir(examples_root) catch {
    _ => return results
  }
  examples.sort_by((left, right) => left.lexical_compare(right))
  for example in examples {
    let example_path = @tools.resolve_path(repo_root, "examples/" + example)
    if !@tools.directory_exists(example_path) {
      continue
    }
    let children : Array[String] = @fs.read_dir(example_path) catch {
      _ => continue
    }
    children.sort_by((left, right) => left.lexical_compare(right))
    for child in children {
      let relative = "examples/" + example + "/" + child
      let absolute = @tools.resolve_path(repo_root, relative)
      if !@tools.directory_exists(absolute) ||
        !@tools.file_exists(
          @tools.resolve_path(repo_root, relative + "/main.mbt"),
        ) ||
        !looks_like_platform_root(child, routes) {
        continue
      }
      ui_roots.push(relative)
      match find_matrix_route(routes, child) {
        None =>
          push_fail(
            results, "P1", relative, "matrix-external platform/renderer composition root. Fix: remove it or add the RFC, platform matrix route, evidence contract, and matching Showcase route required by docs/invariants.md#P1",
          )
        Some(_) => ()
      }
    }
  }
  if ui_roots.length() > 38 {
    push_fail(
      results,
      "P1",
      "examples",
      "UI composition root count " +
      ui_roots.length().to_string() +
      " exceeds 38. Fix: keep composition roots within the repository budget. See docs/invariants.md#P1",
    )
  }
  for route in routes {
    let expected = "examples/showcase/" + route.suffix
    if !ui_roots.contains(expected) {
      push_fail(
        results, "P1", expected, "Showcase must contain every canonical platform-matrix route. See docs/invariants.md#P1",
      )
    }
  }
  if !results.any(item => !item.ok) {
    results.push({
      rule: "P1",
      ok: true,
      path: "examples",
      hint: "scanned " + ui_roots.length().to_string() + " UI composition roots",
    })
  }
  results
}

///|
fn list_example_entrypoints(
  repo_root : String,
  routes : Array[MatrixEntrypointRoute],
) -> Array[Entrypoint] {
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
    for route in routes {
      let path = "examples/" + name + "/" + route.suffix
      if @tools.file_exists(@tools.resolve_path(repo_root, path + "/main.mbt")) {
        found.push({
          example: name,
          path,
          mobile: route.mobile,
          line_budget: route.line_budget,
        })
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
  for file in mbt_files {
    let text = match file_texts.get(file) {
      Some(value) => value
      None => ""
    }
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
  let main_path = entry.path + "/main.mbt"
  let main_lines = match file_texts.get(main_path) {
    Some(text) => line_count(text)
    None => 0
  }
  if main_lines == 0 {
    failed = true
    push_fail(results, "P1", main_path, "entrypoint is missing main.mbt")
  } else if main_lines > entry.line_budget {
    failed = true
    push_fail(
      results,
      "P1",
      main_path,
      "entrypoint main.mbt lines " +
      main_lines.to_string() +
      " exceed " +
      entry.line_budget.to_string() +
      ". Fix: move integration logic to a sibling composition package and business logic to examples/" +
      entry.example +
      "/app. See docs/invariants.md#P1",
    )
  }
  let abi_functions = if entry.path.has_suffix("/web_wasm") {
    [
      "web_dispatch_event", "web_dispatch_pointer_input", "web_dispatch_route", "web_dispatch_semantics_action",
      "web_complete_async_clipboard_read", "web_complete_async_file_dialog",
    ]
  } else if entry.path.has_suffix("/wechat_canvas") {
    [
      "wechat_dispatch_event", "wechat_dispatch_pointer_input", "wechat_render_frame",
      "wechat_surface_created", "wechat_surface_destroyed", "wechat_app_show", "wechat_app_hide",
    ]
  } else {
    []
  }
  let optional_abi_functions = if entry.path.has_suffix("/web_wasm") {
    // Platform-view routes need this additional browser-to-wasm callback;
    // ordinary Web roots keep the smaller fixed ABI shim.
    ["web_dispatch_platform_view_event"]
  } else {
    []
  }
  if !abi_functions.is_empty() {
    let abi_path = entry.path + "/abi.mbt"
    let abi_text = match file_texts.get(abi_path) {
      Some(text) => text
      None => ""
    }
    let backend_alias = if entry.path.has_suffix("/web_wasm") {
      "web"
    } else {
      "wechat"
    }
    if abi_text == "" {
      failed = true
      push_fail(
        results, "P1", abi_path, "wasm entrypoint is missing its mechanical ABI shim. See docs/invariants.md#P1",
      )
    } else if abi_text.contains("pub using") {
      failed = true
      push_fail(
        results, "P1", abi_path, "pub using does not create executable-package wasm exports; define only the fixed mechanical ABI shims. See docs/invariants.md#P1",
      )
    } else {
      for name in abi_functions {
        if !abi_text.contains("pub fn " + name + "(") ||
          !abi_text.contains("@" + backend_alias + "." + name + "(") {
          failed = true
          push_fail(
            results,
            "P1",
            abi_path,
            "missing fixed " +
            name +
            " backend ABI delegation. See docs/invariants.md#P1",
          )
        }
      }
      let mut optional_count = 0
      for name in optional_abi_functions {
        let has_declaration = abi_text.contains("pub fn " + name + "(")
        let has_backend_call = abi_text.contains(
          "@" + backend_alias + "." + name + "(",
        )
        if has_declaration || has_backend_call {
          optional_count += 1
        }
        if has_declaration != has_backend_call {
          failed = true
          push_fail(
            results,
            "P1",
            abi_path,
            "optional " +
            name +
            " ABI delegation is incomplete. See docs/invariants.md#P1",
          )
        }
      }
      let expected_abi_functions = abi_functions.length() + optional_count
      if token_count(abi_text, "pub fn ") != expected_abi_functions ||
        token_count(abi_text, "@" + backend_alias + ".") !=
        expected_abi_functions {
        failed = true
        push_fail(
          results, "P1", abi_path, "ABI shim contains declarations or backend calls outside the fixed route contract. See docs/invariants.md#P1",
        )
      }
    }
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
          results, "P2", mbti_path, "public enum View in core is forbidden for app controls. Fix: keep opaque View plus the ViewNode trait; put controls in moui/views. See docs/invariants.md#P2",
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
            ". Fix: move control to moui/views as a concrete @core.ViewNode constructed with @core.View::from_node. See docs/invariants.md#P2",
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
          " in core. Fix: implement a concrete @core.ViewNode in moui/views and construct it with @core.View::from_node. See docs/invariants.md#P2",
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
        hint: "missing moui_skia_renderer binding factory. See docs/invariants.md#R3",
      }
    Some(body) => {
      let has_env = body.contains("MOUI_SKIA_RENDERER")
      let has_parse = body.contains("NativeRendererMode::parse") &&
        body.contains("pub fn from_env(") &&
        body.contains("pub fn raster(") &&
        body.contains("pub fn gpu(")
      if !has_env || !has_parse {
        {
          rule: "R3",
          ok: false,
          path,
          hint: "moui_skia_renderer must own MOUI_SKIA_RENDERER selection and expose raster/gpu/from_env providers with an explicit platform policy. See docs/invariants.md#R3",
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
      // The composition root delegates lifecycle ownership to the platform
      // backend entry. The concrete ApplicationHandler/EventLoop remains in
      // the backend package and must not be duplicated in every app.
      let has_composition = body.contains("@runtime.run_app(") &&
        (body.contains(".render(") || body.contains(".render_all("))
      let has_backend_entry = body.contains(".backend(") &&
        body.contains(".entry(") &&
        body.contains(".run()")
      if !has_composition || !has_backend_entry {
        {
          rule: "R3",
          ok: false,
          path,
          hint: "embedded-runtime main.mbt must explicitly compose renderer and backend entry; backend entry owns the window HostCmd ApplicationHandler/EventLoop. See docs/invariants.md#R3",
        }
      } else {
        { rule: "R3", ok: true, path, hint: "" }
      }
    }
  }
}

///|
fn check_r3_mobile_pkg(path : String, text : String?) -> HarnessFinding {
  match text {
    None =>
      {
        rule: "R3",
        ok: false,
        path,
        hint: "mobile entry missing moon.pkg. See docs/invariants.md#R3",
      }
    Some(body) => {
      let has_backend = body.contains("wzzc-dev/moui/backend/")
      let has_renderer = body.contains("wzzc-dev/moui_skia_renderer") ||
        body.contains("wzzc-dev/moui_sun_renderer") ||
        body.contains("wzzc-dev/moui_web_renderer") ||
        body.contains("wzzc-dev/moui_wgpu_renderer")
      let ok = has_backend && has_renderer
      {
        rule: "R3",
        ok,
        path,
        hint: if ok {
          ""
        } else {
          "window-hosted embedded-runtime moon.pkg must import a platform backend and renderer; window lifecycle imports belong to the backend package. See docs/invariants.md#R3"
        },
      }
    }
  }
}

///|
fn check_r3_mobile_build_pipeline(
  path : String,
  texts : Array[String?],
) -> HarnessFinding {
  let body = StringBuilder()
  for text in texts {
    match text {
      Some(value) => {
        body.write_string(value)
        body.write_char('\n')
      }
      None =>
        return {
          rule: "R3",
          ok: false,
          path,
          hint: "missing mobile build pipeline source. See docs/invariants.md#R3",
        }
    }
  }
  let combined = body.to_string()
  let ok = combined.contains("--renderer") &&
    combined.contains("auto") &&
    combined.contains("skia-gpu") &&
    combined.contains("skia-raster")
  {
    rule: "R3",
    ok,
    path,
    hint: if ok {
      ""
    } else {
      "moui_cli mobile build pipeline must accept --renderer auto|skia-gpu|skia-raster. See docs/invariants.md#R3"
    },
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
fn validate_repo(
  repo_root : String,
  skip_examples : Bool,
) -> Array[HarnessFinding] {
  let results : Array[HarnessFinding] = []
  if skip_examples {
    // Composition-root wrapper mode: example entrypoint scans are opt-in so
    // app iteration does not trip repo-level composition budgets. Core,
    // renderer, pipeline, and skills invariants still run.
    results.push({
      rule: "P1",
      ok: true,
      path: "examples",
      hint: "example entrypoint scans skipped (--skip-examples)",
    })
  } else {
    let routes = match parse_matrix_entrypoint_routes(repo_root) {
      Ok(routes) => routes
      Err(message) => {
        push_fail(results, "P1", "checks/platform-matrix.json", message)
        []
      }
    }
    let entries = list_example_entrypoints(repo_root, routes)
    for item in validate_entrypoint_catalog(repo_root, routes) {
      results.push(item)
    }
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
      collect_files_with_suffix(
        repo_root,
        entry.path,
        is_non_test_mbt,
        mbt_files,
      )
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
    for entry in entries {
      if entry.mobile {
        let main_path = entry.path + "/main.mbt"
        let pkg_path = entry.path + "/moon.pkg"
        results.push(
          check_r3_mobile_main(
            main_path,
            read_optional_text(repo_root, main_path),
          ),
        )
        results.push(
          check_r3_mobile_pkg(pkg_path, read_optional_text(repo_root, pkg_path)),
        )
      }
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
  // MoonBit files do not define package boundaries. The mobile build contract
  // is intentionally split between shared preparation, CLI parsing, and the
  // three platform builders, so validate the owning package as one surface.
  let build_pipeline_path = "moui_cli mobile build pipeline"
  let build_pipeline_files = [
    "moui_cli/prepare_native_build.mbt", "moui_cli/build_command.mbt", "moui_cli/build_android.mbt",
    "moui_cli/build_ios.mbt", "moui_cli/build_harmonyos.mbt",
  ]
  results.push(
    check_r3_mobile_build_pipeline(
      build_pipeline_path,
      build_pipeline_files.map(path => read_optional_text(repo_root, path)),
    ),
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
  skip_examples : Bool
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let mut repo_root = @env.current_dir().unwrap_or("")
  let mut json = false
  let mut help = false
  let mut skip_examples = false
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
      "--skip-examples" => {
        skip_examples = true
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
  Ok({ repo_root, json, help, skip_examples })
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
      let results = validate_repo(options.repo_root, options.skip_examples)
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
