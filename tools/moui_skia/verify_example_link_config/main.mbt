///|
let required_example_vars : Map[String, String] = {
  "triangle_window_macos/moon.pkg": "MOUI_SKIA_EXAMPLE_MACOS_WINDOW_LINK_FLAGS",
  "macos_hello_triangle/moon.pkg": "MOUI_SKIA_EXAMPLE_MACOS_METAL_WINDOW_LINK_FLAGS",
}

///|
let required_native_pkg_vars : Map[String, String] = {
  "native/moon.pkg": "MOUI_SKIA_CC_LINK_FLAGS",
}

///|
// App-facing Skia entrypoints keep empty cc-link-flags; platform frameworks
// and Skia provider flags live on backend/provider packages instead.
let required_moui_entry_tokens : Map[String, Array[String]] = {
  "moui_tests/skia_renderer_smoke/native/moon.pkg": [],
  "examples/showcase/macos_skia/moon.pkg": [],
  "examples/markdown_editor/macos_skia/moon.pkg": [],
  "examples/mo_workbench/macos_skia/moon.pkg": [],
  "examples/button_freeze_probe/macos_skia/moon.pkg": [],
  "examples/showcase/linux_skia/moon.pkg": [],
  "examples/showcase/windows_skia/moon.pkg": [],
}

///|
let forbidden_example_patterns : Array[String] = [".skia-cache", "package/out"]

///|
struct CliOptions {
  repo_root : String
  build_script : String
  examples_dir : String
  help : Bool
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui_skia/verify_example_link_config [options]
    #|
    #|Checks that checked-in example moon.pkg files use the link variables owned
    #|by this module and that MoUI Skia entrypoints keep platform link flags
    #|without hardcoded Skia provider cache paths.
    #|
    #|Options:
    #|  --repo-root PATH      Repository root used to resolve relative paths. Defaults to cwd.
    #|  --build-script PATH   Build script path. Defaults to build.js.
    #|  --examples-dir PATH   Examples directory. Defaults to examples.
    #|  -h, --help            Show this help.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let build_script = Ref("build.js")
  let examples_dir = Ref("examples")
  let help = Ref(false)
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--repo-root" => {
        if index + 1 >= args.length() {
          return Err("missing value for --repo-root")
        }
        repo_root.val = args[index + 1]
        index += 2
      }
      "--build-script" => {
        if index + 1 >= args.length() {
          return Err("missing value for --build-script")
        }
        build_script.val = args[index + 1]
        index += 2
      }
      "--examples-dir" => {
        if index + 1 >= args.length() {
          return Err("missing value for --examples-dir")
        }
        examples_dir.val = args[index + 1]
        index += 2
      }
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      other => return Err("unknown argument: " + other)
    }
  }
  Ok({
    repo_root: repo_root.val,
    build_script: build_script.val,
    examples_dir: examples_dir.val,
    help: help.val,
  })
}

///|
fn compact_whitespace(text : String) -> String {
  let builder = StringBuilder()
  for char in text {
    if !(char == ' ' || char == '\n' || char == '\r' || char == '\t') {
      builder.write_char(char)
    }
  }
  builder.to_string()
}

///|
fn count_occurrences(text : String, needle : String) -> Int {
  if needle == "" {
    return 0
  }
  let mut count = 0
  let mut index = 0
  while index + needle.length() <= text.length() {
    if text[index:index + needle.length()].to_owned() == needle {
      count += 1
      index += needle.length()
    } else {
      index += 1
    }
  }
  count
}

///|
fn contains_provider_cache_token(text : String) -> Bool {
  if forbidden_example_patterns.any(pattern => text.contains(pattern)) {
    return true
  }
  let chars = text.to_array()
  let mut index = 0
  while index < chars.length() {
    if chars[index] == 'm' && index + 10 <= chars.length() {
      let mut digits = 0
      let mut cursor = index + 1
      while cursor < chars.length() &&
            chars[cursor] >= '0' &&
            chars[cursor] <= '9' {
        digits += 1
        cursor += 1
      }
      if digits > 0 && cursor < chars.length() && chars[cursor] == '-' {
        cursor += 1
        let hex_start = cursor
        while cursor < chars.length() && hex_char(chars[cursor]) {
          cursor += 1
        }
        if cursor - hex_start >= 8 &&
          token_boundary(chars, index - 1) &&
          token_boundary(chars, cursor) {
          return true
        }
      }
    }
    index += 1
  }
  false
}

///|
fn hex_char(char : Char) -> Bool {
  (char >= '0' && char <= '9') ||
  (char >= 'a' && char <= 'f') ||
  (char >= 'A' && char <= 'F')
}

///|
fn word_char(char : Char) -> Bool {
  (char >= '0' && char <= '9') ||
  (char >= 'a' && char <= 'z') ||
  (char >= 'A' && char <= 'Z') ||
  char == '_'
}

///|
fn token_boundary(chars : Array[Char], index : Int) -> Bool {
  index < 0 || index >= chars.length() || !word_char(chars[index])
}

///|
fn require_build_variable(
  text : String,
  variable : String,
  message : String,
) -> Result[Unit, String] {
  if count_occurrences(text, variable) < 2 {
    Err(message + variable + " in both fallback and configured paths")
  } else {
    Ok(())
  }
}

///|
fn expected_link_variable(variable : String) -> String {
  "\"cc-link-flags\":\"${build." + variable + "}\""
}

///|
fn verify_pkg_uses_build_variable(
  pkg_path : String,
  variable : String,
  label : String,
) -> Result[String, String] {
  let text = match @tools.read_required_text(pkg_path, label + " moon.pkg") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let compact = compact_whitespace(text)
  if !compact.contains(expected_link_variable(variable)) {
    return Err(
      label +
      " moon.pkg does not use build variable " +
      variable +
      ": " +
      pkg_path,
    )
  }
  Ok(text)
}

///|
fn collect_moon_pkg_files(directory : String) -> Result[Array[String], String] {
  if !@tools.directory_exists(directory) {
    return Err("examples directory is missing: " + directory)
  }
  let result : Array[String] = []
  collect_moon_pkg_files_into(directory, result)
  result.sort()
  Ok(result)
}

///|
fn collect_moon_pkg_files_into(
  directory : String,
  result : Array[String],
) -> Unit {
  let entries = @fs.read_dir(directory) catch { _ => [] }
  for entry in entries {
    let path = @tools.join_path(directory, entry)
    if @tools.file_exists(path) && entry == "moon.pkg" {
      result.push(path)
    } else if @tools.directory_exists(path) {
      collect_moon_pkg_files_into(path, result)
    }
  }
}

///|
fn parent_path(path : String) -> String {
  let chars = path.to_array()
  let mut index = chars.length() - 1
  while index >= 0 {
    if chars[index] == '/' || chars[index] == '\\' {
      let builder = StringBuilder()
      for offset in 0..<index {
        builder.write_char(chars[offset])
      }
      return builder.to_string()
    }
    index -= 1
  }
  ""
}

///|
fn verify_no_provider_path(
  text : String,
  path : String,
  label : String,
) -> Result[Unit, String] {
  if contains_provider_cache_token(text) {
    Err(label + " contains hardcoded Skia provider path text: " + path)
  } else {
    Ok(())
  }
}

///|
fn verify_example_link_config(options : CliOptions) -> Result[String, String] {
  let resolved_build_script = @tools.resolve_path(
    options.repo_root,
    options.build_script,
  )
  let resolved_examples_dir = @tools.resolve_path(
    options.repo_root,
    options.examples_dir,
  )
  let build_text = match
    @tools.read_required_text(resolved_build_script, "build script") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if !@tools.directory_exists(resolved_examples_dir) {
    return Err("examples directory is missing: " + resolved_examples_dir)
  }

  for variable in required_example_vars.values() {
    match
      require_build_variable(
        build_text, variable, "build script does not emit ",
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  for variable in required_native_pkg_vars.values() {
    match
      require_build_variable(
        build_text, variable, "build script does not emit ",
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  if !build_text.contains("macosExampleLinkFlags") {
    return Err("build script is missing macOS example link flag helper")
  }
  for framework in ["QuartzCore", "AppKit", "Metal", "CoreVideo", "IOSurface"] {
    if !build_text.contains(framework) {
      return Err(
        "build script is missing macOS example framework: " + framework,
      )
    }
  }

  for relative_pkg in required_example_vars.keys() {
    let variable = required_example_vars[relative_pkg]
    let pkg_path = @tools.join_path(resolved_examples_dir, relative_pkg)
    match verify_pkg_uses_build_variable(pkg_path, variable, "example") {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }

  let binding_root = parent_path(resolved_build_script)
  for relative_pkg in required_native_pkg_vars.keys() {
    let variable = required_native_pkg_vars[relative_pkg]
    let pkg_path = @tools.join_path(binding_root, relative_pkg)
    let pkg_text = match
      verify_pkg_uses_build_variable(pkg_path, variable, "native") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    match verify_no_provider_path(pkg_text, pkg_path, "native moon.pkg") {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }

  let example_pkg_files = match collect_moon_pkg_files(resolved_examples_dir) {
    Ok(values) => values
    Err(message) => return Err(message)
  }
  for pkg_path in example_pkg_files {
    let pkg_text = match
      @tools.read_required_text(pkg_path, "example moon.pkg") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    match verify_no_provider_path(pkg_text, pkg_path, "example moon.pkg") {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }

  let maybe_moui_root = parent_path(binding_root)
  if @tools.directory_exists(@tools.join_path(maybe_moui_root, "moui")) &&
    @tools.directory_exists(@tools.join_path(maybe_moui_root, "examples")) {
    for relative_pkg in required_moui_entry_tokens.keys() {
      let pkg_path = @tools.join_path(maybe_moui_root, relative_pkg)
      let pkg_text = match
        @tools.read_required_text(pkg_path, "MoUI Skia entry moon.pkg") {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      if pkg_text.contains("MOUI_SKIA_CC_LINK_FLAGS") {
        return Err(
          "MoUI Skia entry moon.pkg uses out-of-scope MOUI_SKIA_CC_LINK_FLAGS: " +
          pkg_path,
        )
      }
      for token in required_moui_entry_tokens[relative_pkg] {
        if !pkg_text.contains(token) {
          return Err(
            "MoUI Skia entry moon.pkg is missing platform link token " +
            token +
            ": " +
            pkg_path,
          )
        }
      }
      match
        verify_no_provider_path(pkg_text, pkg_path, "MoUI Skia entry moon.pkg") {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
  }

  Ok("Verified example link configuration in " + resolved_examples_dir)
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) =>
      match verify_example_link_config(options) {
        Ok(message) => {
          println(message)
          0
        }
        Err(message) => {
          println(message)
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
