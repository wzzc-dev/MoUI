///|
struct CliOptions {
  root : String
  display_root : String
  base_url : String
  manifest_path : String
  http_checks : Array[HandoffCheck]
  help : Bool
}

///|
struct HandoffTarget {
  name : String
  package_path : String
  html_path : String
  wasm_path : String
}

///|
struct TargetManifest {
  target : HandoffTarget
  wasm_bytes : Int
  compiled_wasm_exports : Array[String]
}

///|
struct HandoffCheck {
  kind : String
  label : String
  path : String
  url : String
  bytes : Int
}

///|
let observation_boundary = "Static HTML/runtime/wasm delivery and compiled WebAssembly export audit only; not browser WebGPU device, wasm instantiation, canvas presentation, or pixel observations."

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui/validate_web_runtime_handoff [options]
    #|
    #|Checks static Web wasm-gc runtime handoff files and writes the optional
    #|web-runtime-handoff manifest.
    #|
    #|Options:
    #|  --root PATH        Repository/build root. Defaults to cwd.
    #|  --display-root PATH Stable root label recorded in the manifest.
    #|  --base-url URL     Base URL recorded in the manifest. HTTP fetch checks
    #|                     are supplied by the compatibility wrapper.
    #|  --manifest PATH    Optional manifest output path.
    #|  --http-check LABEL PATH URL BYTES
    #|                     Add an already-verified HTTP check to the manifest.
    #|  -h, --help         Show this help.
    #|
  text
}

///|
fn parse_positive_int(text : String) -> Int? {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    return None
  }
  let mut value = 0
  for char in trimmed {
    if char < '0' || char > '9' {
      return None
    }
    value = value * 10 + char.to_int() - '0'.to_int()
  }
  if value <= 0 {
    None
  } else {
    Some(value)
  }
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let root = Ref(@env.current_dir().unwrap_or(""))
  let display_root = Ref("")
  let base_url = Ref("")
  let manifest_path = Ref("")
  let http_checks : Array[HandoffCheck] = []
  let help = Ref(false)
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--root" | "--repo-root" => {
        if index + 1 >= args.length() {
          return Err("missing value for " + args[index])
        }
        root.val = args[index + 1]
        index += 2
      }
      "--display-root" => {
        if index + 1 >= args.length() {
          return Err("missing value for --display-root")
        }
        display_root.val = args[index + 1]
        index += 2
      }
      "--base-url" => {
        if index + 1 >= args.length() {
          return Err("missing value for --base-url")
        }
        base_url.val = args[index + 1]
        index += 2
      }
      "--manifest" => {
        if index + 1 >= args.length() {
          return Err("missing value for --manifest")
        }
        manifest_path.val = args[index + 1]
        index += 2
      }
      "--http-check" => {
        if index + 4 >= args.length() {
          return Err("missing values for --http-check")
        }
        let bytes = match parse_positive_int(args[index + 4]) {
          Some(value) => value
          None => return Err("invalid byte count for --http-check")
        }
        http_checks.push({
          kind: "http",
          label: args[index + 1],
          path: args[index + 2],
          url: args[index + 3],
          bytes,
        })
        index += 5
      }
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      other => return Err("unknown argument: " + other)
    }
  }
  Ok({
    root: root.val,
    display_root: display_root.val,
    base_url: base_url.val,
    manifest_path: manifest_path.val,
    http_checks,
    help: help.val,
  })
}

///|
fn required_wasm_exports() -> Array[String] {
  [
    "web_dispatch_event", "web_complete_async_clipboard_read", "web_complete_async_file_dialog",
  ]
}

///|
fn handoff_targets() -> Array[HandoffTarget] {
  [
    {
      name: "showcase-web-wasm",
      package_path: "examples/showcase/web_wasm",
      html_path: "examples/showcase/web_wasm/index.html",
      wasm_path: "_build/wasm-gc/debug/build/examples/showcase/web_wasm/web_wasm.wasm",
    },
    {
      name: "markdown-editor-web-wasm",
      package_path: "examples/markdown_editor/web_wasm",
      html_path: "examples/markdown_editor/web_wasm/index.html",
      wasm_path: "_build/wasm-gc/debug/build/examples/markdown_editor/web_wasm/web_wasm.wasm",
    },
  ]
}

///|
fn read_repo_text(root : String, path : String) -> Result[String, String] {
  @tools.read_required_text(@tools.resolve_path(root, path), path)
}

///|
fn read_repo_bytes(root : String, path : String) -> Result[Bytes, String] {
  let resolved = @tools.resolve_path(root, path)
  if !@tools.file_exists(resolved) {
    return Err(path + ": missing file")
  }
  let bytes = @fs.read_file_to_bytes(resolved) catch {
    _ => return Err(path + ": failed to read")
  }
  Ok(bytes)
}

///|
fn push_includes_check(
  text : String,
  needle : String,
  label : String,
  failures : Array[String],
) -> Unit {
  if !text.contains(needle) {
    failures.push(label + " must include '" + needle + "'")
  }
}

///|
fn read_u8(bytes : Bytes, offset : Ref[Int]) -> Result[Int, String] {
  if offset.val >= bytes.length() {
    Err("unexpected end of wasm module")
  } else {
    let value = bytes[offset.val].to_int()
    offset.val += 1
    Ok(value)
  }
}

///|
fn read_uleb_u32(bytes : Bytes, offset : Ref[Int]) -> Result[Int, String] {
  let mut result = 0
  let mut shift = 0
  while true {
    if shift >= 35 {
      return Err("invalid wasm varuint32")
    }
    let byte = match read_u8(bytes, offset) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    result = result + ((byte & 0x7f) << shift)
    if (byte & 0x80) == 0 {
      return Ok(result)
    }
    shift += 7
  }
  Err("invalid wasm varuint32")
}

///|
fn parse_export_section_names(
  bytes : Bytes,
  section_start : Int,
  section_end : Int,
) -> Result[Array[String], String] {
  let offset = Ref(section_start)
  let count = match read_uleb_u32(bytes, offset) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let exports : Array[String] = []
  for _ in 0..<count {
    let name_len = match read_uleb_u32(bytes, offset) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    if name_len < 0 || offset.val + name_len > section_end {
      return Err("invalid wasm export name")
    }
    let name = @utf8.decode_lossy(
      bytes[offset.val:offset.val + name_len],
      ignore_bom=false,
    )
    offset.val += name_len
    ignore(
      match read_u8(bytes, offset) {
        Ok(value) => value
        Err(message) => return Err(message)
      },
    )
    match read_uleb_u32(bytes, offset) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    exports.push(name)
  }
  Ok(exports)
}

///|
fn wasm_export_names(bytes : Bytes) -> Result[Array[String], String] {
  if bytes.length() < 8 ||
    bytes[0].to_int() != 0x00 ||
    bytes[1].to_int() != 0x61 ||
    bytes[2].to_int() != 0x73 ||
    bytes[3].to_int() != 0x6d {
    return Err("invalid wasm magic")
  }
  let offset = Ref(8)
  while offset.val < bytes.length() {
    let section_id = match read_u8(bytes, offset) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let section_size = match read_uleb_u32(bytes, offset) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    if section_size < 0 || offset.val + section_size > bytes.length() {
      return Err("invalid wasm section size")
    }
    let section_start = offset.val
    let section_end = offset.val + section_size
    if section_id == 7 {
      return parse_export_section_names(bytes, section_start, section_end)
    }
    offset.val = section_end
  }
  Ok([])
}

///|
fn array_contains(values : Array[String], expected : String) -> Bool {
  values.any(value => value == expected)
}

///|
fn validate_runtime_assets(
  root : String,
  checks : Array[HandoffCheck],
) -> Array[String] {
  let failures : Array[String] = []
  for
    path in [
      "moui_web_renderer/runtime.js", "moui/backend/web/browser_runtime.js",
    ] {
    match read_repo_bytes(root, path) {
      Ok(bytes) =>
        checks.push({
          kind: "file",
          label: "",
          path,
          url: "",
          bytes: bytes.length(),
        })
      Err(message) => failures.push(message)
    }
  }
  match read_repo_text(root, "moui_web_renderer/runtime.js") {
    Ok(text) => {
      push_includes_check(
        text, "Browser WebGPU renderer runtime", "moui_web_renderer/runtime.js",
        failures,
      )
      push_includes_check(
        text, "bootMouiWasmGcApp", "moui_web_renderer/runtime.js", failures,
      )
    }
    Err(message) => failures.push(message)
  }
  match read_repo_text(root, "moui/backend/web/browser_runtime.js") {
    Ok(text) => {
      push_includes_check(
        text, "install_canvas_events", "moui/backend/web/browser_runtime.js", failures,
      )
      push_includes_check(
        text, "create_canvas", "moui/backend/web/browser_runtime.js", failures,
      )
    }
    Err(message) => failures.push(message)
  }
  failures
}

///|
fn validate_target(
  root : String,
  target : HandoffTarget,
  checks : Array[HandoffCheck],
) -> Result[TargetManifest, Array[String]] {
  let failures : Array[String] = []
  match read_repo_text(root, target.html_path) {
    Ok(html) => {
      push_includes_check(html, "bootMouiWasmGcApp", target.html_path, failures)
      push_includes_check(
        html,
        "../../../moui_web_renderer/runtime.js",
        target.html_path,
        failures,
      )
      push_includes_check(html, "#canvas-host", target.html_path, failures)
      push_includes_check(html, "Loading wasm-gc", target.html_path, failures)
      push_includes_check(html, "Running", target.html_path, failures)
      push_includes_check(
        html,
        target.wasm_path.replace(old="_build", new="../../../_build"),
        target.html_path,
        failures,
      )
    }
    Err(message) => failures.push(message)
  }
  let wasm_bytes = match read_repo_bytes(root, target.wasm_path) {
    Ok(bytes) => bytes
    Err(message) => {
      failures.push(message)
      Bytes::make(0, 0)
    }
  }
  let wasm_size = wasm_bytes.length()
  if wasm_size > 0 {
    checks.push({
      kind: "file",
      label: "",
      path: target.wasm_path,
      url: "",
      bytes: wasm_size,
    })
    if wasm_size < 1024 {
      failures.push(
        target.wasm_path +
        ": wasm artifact is unexpectedly small (" +
        wasm_size.to_string() +
        " bytes)",
      )
    }
  }
  let exports = if wasm_size > 0 {
    match wasm_export_names(wasm_bytes) {
      Ok(values) => values
      Err(message) => {
        failures.push(
          target.wasm_path +
          ": failed to compile wasm module for export audit: " +
          message,
        )
        []
      }
    }
  } else {
    []
  }
  for export_name in required_wasm_exports() {
    if !array_contains(exports, export_name) {
      failures.push(
        target.wasm_path +
        ": missing required wasm export '" +
        export_name +
        "'",
      )
    }
  }
  if failures.is_empty() {
    Ok({ target, wasm_bytes: wasm_size, compiled_wasm_exports: exports })
  } else {
    Err(failures)
  }
}

///|
fn json_escape(value : String) -> String {
  let builder = StringBuilder()
  for char in value {
    match char {
      '"' => builder.write_string("\\\"")
      '\\' => builder.write_string("\\\\")
      '\n' => builder.write_string("\\n")
      '\r' => builder.write_string("\\r")
      '\t' => builder.write_string("\\t")
      _ => builder.write_char(char)
    }
  }
  builder.to_string()
}

///|
fn write_json_string(builder : StringBuilder, value : String) -> Unit {
  builder.write_char('"')
  builder.write_string(json_escape(value))
  builder.write_char('"')
}

///|
fn write_string_array(builder : StringBuilder, values : Array[String]) -> Unit {
  builder.write_string("[")
  for index in 0..<values.length() {
    if index > 0 {
      builder.write_string(", ")
    }
    write_json_string(builder, values[index])
  }
  builder.write_string("]")
}

///|
fn write_check(
  builder : StringBuilder,
  check : HandoffCheck,
  indent : String,
) -> Unit {
  builder.write_string(indent)
  builder.write_string("{ \"kind\": ")
  write_json_string(builder, check.kind)
  if check.kind == "http" {
    builder.write_string(", \"label\": ")
    write_json_string(builder, check.label)
  }
  builder.write_string(", \"path\": ")
  write_json_string(builder, check.path)
  if check.kind == "http" {
    builder.write_string(", \"url\": ")
    write_json_string(builder, check.url)
  }
  builder.write_string(", \"bytes\": ")
  builder.write_string(check.bytes.to_string())
  builder.write_string(" }")
}

///|
fn manifest_text(
  root : String,
  base_url : String,
  targets : Array[TargetManifest],
  checks : Array[HandoffCheck],
) -> String {
  let builder = StringBuilder()
  builder.write_string("{\n")
  builder.write_string("  \"schemaVersion\": 1,\n")
  builder.write_string("  \"mode\": \"web-runtime-handoff\",\n")
  builder.write_string(
    "  \"generatedBy\": \"scripts/validate-web-runtime-handoff.mjs\",\n",
  )
  builder.write_string("  \"root\": ")
  write_json_string(builder, root)
  builder.write_string(",\n")
  builder.write_string("  \"baseUrl\": ")
  write_json_string(builder, base_url)
  builder.write_string(",\n")
  builder.write_string("  \"observationBoundary\": ")
  write_json_string(builder, observation_boundary)
  builder.write_string(",\n")
  builder.write_string("  \"runtimeAssets\": [\n")
  builder.write_string("    \"moui_web_renderer/runtime.js\",\n")
  builder.write_string("    \"moui/backend/web/browser_runtime.js\"\n")
  builder.write_string("  ],\n")
  builder.write_string("  \"targets\": [\n")
  for index in 0..<targets.length() {
    if index > 0 {
      builder.write_string(",\n")
    }
    let item = targets[index]
    builder.write_string("    {\n")
    builder.write_string("      \"name\": ")
    write_json_string(builder, item.target.name)
    builder.write_string(",\n")
    builder.write_string("      \"packagePath\": ")
    write_json_string(builder, item.target.package_path)
    builder.write_string(",\n")
    builder.write_string("      \"htmlPath\": ")
    write_json_string(builder, item.target.html_path)
    builder.write_string(",\n")
    builder.write_string("      \"wasmPath\": ")
    write_json_string(builder, item.target.wasm_path)
    builder.write_string(",\n")
    builder.write_string("      \"requiredWasmExports\": ")
    write_string_array(builder, required_wasm_exports())
    builder.write_string(",\n")
    builder.write_string("      \"compiledWasmExports\": ")
    write_string_array(builder, item.compiled_wasm_exports)
    builder.write_string(",\n")
    builder.write_string(
      "      \"htmlRuntimeImport\": \"../../../moui_web_renderer/runtime.js\",\n",
    )
    builder.write_string("      \"canvasHostSelector\": \"#canvas-host\",\n")
    builder.write_string("      \"wasmBytes\": ")
    builder.write_string(item.wasm_bytes.to_string())
    builder.write_string("\n")
    builder.write_string("    }")
  }
  builder.write_string("\n  ],\n")
  builder.write_string("  \"checks\": [\n")
  for index in 0..<checks.length() {
    if index > 0 {
      builder.write_string(",\n")
    }
    write_check(builder, checks[index], "    ")
  }
  builder.write_string("\n  ]\n")
  builder.write_string("}\n")
  builder.to_string()
}

///|
fn parent_dir(path : String) -> String {
  let normalized = path.replace(old="\\", new="/")
  let slash = Ref(-1)
  for index in 0..<normalized.length() {
    if normalized[index] == '/' {
      slash.val = index
    }
  }
  if slash.val < 0 {
    ""
  } else if slash.val == 0 {
    "/"
  } else {
    normalized[:slash.val].to_owned()
  }
}

///|
fn create_dir_if_missing(path : String) -> Result[Unit, String] {
  if path == "" || @tools.directory_exists(path) {
    return Ok(())
  }
  @fs.create_dir(path) catch {
    _ => return Err("could not create directory: " + path)
  }
  Ok(())
}

///|
fn mkdir_p(path : String) -> Result[Unit, String] {
  if path == "" || @tools.directory_exists(path) {
    return Ok(())
  }
  let normalized = path.replace(old="\\", new="/")
  let current = Ref(if normalized.has_prefix("/") { "/" } else { "" })
  for part in normalized.split("/") {
    if part == "" {
      continue
    }
    let part = part.to_owned()
    if current.val == "" || current.val == "/" {
      current.val = current.val + part
    } else {
      current.val = current.val + "/" + part
    }
    match create_dir_if_missing(current.val) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///|
fn validate_web_runtime_handoff(
  options : CliOptions,
) -> Result[String, Array[String]] {
  let failures : Array[String] = []
  let checks : Array[HandoffCheck] = []
  for failure in validate_runtime_assets(options.root, checks) {
    failures.push(failure)
  }
  let target_manifests : Array[TargetManifest] = []
  for target in handoff_targets() {
    match validate_target(options.root, target, checks) {
      Ok(manifest) => target_manifests.push(manifest)
      Err(messages) =>
        for message in messages {
          failures.push(message)
        }
    }
  }
  for check in options.http_checks {
    checks.push(check)
  }
  if !failures.is_empty() {
    return Err(failures)
  }
  if options.manifest_path != "" {
    let dir = parent_dir(options.manifest_path)
    match mkdir_p(dir) {
      Ok(_) => ()
      Err(message) => return Err([message])
    }
    match
      @tools.write_text_file(
        options.manifest_path,
        manifest_text(
          if options.display_root == "" {
            options.root
          } else {
            options.display_root
          },
          options.base_url,
          target_manifests,
          checks,
        ),
        "web runtime handoff manifest",
      ) {
      Ok(_) => ()
      Err(message) => return Err([message])
    }
  }
  Ok("web runtime handoff: ok")
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) =>
      match validate_web_runtime_handoff(options) {
        Ok(message) => {
          if options.manifest_path != "" {
            println("web runtime handoff manifest: " + options.manifest_path)
          }
          println(message)
          0
        }
        Err(failures) => {
          for failure in failures {
            println("web runtime handoff: " + failure)
          }
          1
        }
      }
    Err(message) => {
      println(message)
      println(usage())
      2
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
