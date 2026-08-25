///|
let native_targets : Array[String] = ["native", "llvm"]

///|
let fallback_targets : Array[String] = ["wasm", "wasm-gc", "js"]

///|
struct CliOptions {
  repo_root : String
  native_dir : String
  pkg_path : String
  help : Bool
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui_skia/verify_native_fallback_parity [options]
    #|
    #|Checks that every native-only MoonBit implementation file in the native
    #|package has an unavailable fallback twin and that native/moon.pkg maps each
    #|side to the expected target family.
    #|
    #|Options:
    #|  --repo-root PATH      Repository root used to resolve relative paths. Defaults to cwd.
    #|  --native-dir PATH     Native package directory. Defaults to native.
    #|  --pkg PATH            Native moon.pkg path. Defaults to <native-dir>/moon.pkg.
    #|  -h, --help            Show this help.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let native_dir = Ref("native")
  let pkg_path = Ref("")
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
      "--native-dir" => {
        if index + 1 >= args.length() {
          return Err("missing value for --native-dir")
        }
        native_dir.val = args[index + 1]
        index += 2
      }
      "--pkg" => {
        if index + 1 >= args.length() {
          return Err("missing value for --pkg")
        }
        pkg_path.val = args[index + 1]
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
    native_dir: native_dir.val,
    pkg_path: pkg_path.val,
    help: help.val,
  })
}

///|
fn ascii_whitespace(code : Int) -> Bool {
  code == ' ' || code == '\n' || code == '\r' || code == '\t'
}

///|
fn skip_whitespace(chars : Array[Char], start : Int) -> Int {
  let mut index = start
  while index < chars.length() && ascii_whitespace(chars[index].to_int()) {
    index += 1
  }
  index
}

///|
fn read_quoted(chars : Array[Char], start : Int) -> (String, Int)? {
  if start >= chars.length() || chars[start] != '"' {
    return None
  }
  let builder = StringBuilder()
  let mut index = start + 1
  let mut escaped = false
  while index < chars.length() {
    let char = chars[index]
    if escaped {
      builder.write_char(char)
      escaped = false
    } else if char == '\\' {
      escaped = true
    } else if char == '"' {
      return Some((builder.to_string(), index + 1))
    } else {
      builder.write_char(char)
    }
    index += 1
  }
  None
}

///|
fn parse_target_entries(
  text : String,
) -> Result[Map[String, Array[String]], String] {
  let chars = text.to_array()
  let entries : Map[String, Array[String]] = Map([])
  let mut index = 0
  while index < chars.length() {
    match read_quoted(chars, index) {
      Some((file_name, after_file)) if file_name.has_suffix(".mbt") => {
        let colon = skip_whitespace(chars, after_file)
        if colon < chars.length() && chars[colon] == ':' {
          let array_start = skip_whitespace(chars, colon + 1)
          if array_start < chars.length() && chars[array_start] == '[' {
            let result = parse_target_list(chars, array_start + 1)
            match result {
              Ok((targets, after_array)) => {
                if entries.contains(file_name) {
                  return Err(
                    "duplicate target entry in native moon.pkg: " + file_name,
                  )
                }
                entries[file_name] = targets
                index = after_array
              }
              Err(message) => return Err(message)
            }
          } else {
            index = after_file
          }
        } else {
          index = after_file
        }
      }
      Some((_text, after_quote)) => index = after_quote
      None => index += 1
    }
  }
  Ok(entries)
}

///|
fn parse_target_list(
  chars : Array[Char],
  start : Int,
) -> Result[(Array[String], Int), String] {
  let targets : Array[String] = []
  let mut index = start
  while index < chars.length() {
    index = skip_whitespace(chars, index)
    if index >= chars.length() {
      return Err("unterminated target list in native moon.pkg")
    }
    if chars[index] == ']' {
      return Ok((targets, index + 1))
    }
    match read_quoted(chars, index) {
      Some((target, after_target)) => {
        targets.push(target)
        index = skip_whitespace(chars, after_target)
        if index < chars.length() && chars[index] == ',' {
          index += 1
        }
      }
      None => index += 1
    }
  }
  Err("unterminated target list in native moon.pkg")
}

///|
fn array_equal(left : Array[String], right : Array[String]) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    if left[index] != right[index] {
      return false
    }
  }
  true
}

///|
fn require_targets(
  target_entries : Map[String, Array[String]],
  file_name : String,
  expected : Array[String],
) -> Result[Unit, String] {
  match target_entries.get(file_name) {
    Some(actual) if array_equal(actual, expected) => Ok(())
    Some(actual) =>
      Err(
        "native moon.pkg has wrong targets for " +
        file_name +
        ": expected=[" +
        @tools.comma_join(expected) +
        "] actual=[" +
        @tools.comma_join(actual) +
        "]",
      )
    None => Err("native moon.pkg is missing target mapping for " + file_name)
  }
}

///|
fn map_from_names(names : Array[String]) -> Map[String, Bool] {
  let result : Map[String, Bool] = Map([])
  for name in names {
    result[name] = true
  }
  result
}

///|
fn base_names(names : Array[String], suffix : String) -> Map[String, Bool] {
  let result : Map[String, Bool] = Map([])
  for name in names {
    match @tools.strip_suffix(name, suffix) {
      Some(base) => result[base] = true
      None => ()
    }
  }
  result
}

///|
fn missing_keys(
  left : Map[String, Bool],
  right : Map[String, Bool],
) -> Array[String] {
  let missing : Array[String] = []
  for key in left.keys() {
    if !right.contains(key) {
      missing.push(key)
    }
  }
  missing.sort()
  missing
}

///|
fn verify_native_fallback_parity(
  options : CliOptions,
) -> Result[String, String] {
  let resolved_native_dir = @tools.resolve_path(
    options.repo_root,
    options.native_dir,
  )
  let resolved_pkg_path = if options.pkg_path == "" {
    @tools.join_path(resolved_native_dir, "moon.pkg")
  } else {
    @tools.resolve_path(options.repo_root, options.pkg_path)
  }

  let pkg_text = match
    @tools.read_required_text(resolved_pkg_path, "native package moon.pkg") {
    Ok(text) => text
    Err(message) => return Err(message)
  }
  let target_entries = match parse_target_entries(pkg_text) {
    Ok(entries) => entries
    Err(message) => return Err(message)
  }
  if target_entries.is_empty() {
    return Err(
      "native package moon.pkg has no target entries: " + resolved_pkg_path,
    )
  }

  let native_files = match
    @tools.file_names_with_suffix(resolved_native_dir, "_native.mbt") {
    Ok(files) => files
    Err(message) => return Err("native package " + message)
  }
  let fallback_files = match
    @tools.file_names_with_suffix(resolved_native_dir, "_unavailable.mbt") {
    Ok(files) => files
    Err(message) => return Err("native package " + message)
  }
  if native_files.is_empty() {
    return Err(
      "native package has no *_native.mbt files: " + resolved_native_dir,
    )
  }
  if fallback_files.is_empty() {
    return Err(
      "native package has no *_unavailable.mbt files: " + resolved_native_dir,
    )
  }

  let native_bases = base_names(native_files, "_native.mbt")
  let fallback_bases = base_names(fallback_files, "_unavailable.mbt")
  let missing_fallbacks = missing_keys(native_bases, fallback_bases)
  if !missing_fallbacks.is_empty() {
    return Err(
      "native implementation files are missing unavailable fallbacks: " +
      @tools.comma_join(missing_fallbacks),
    )
  }
  let missing_native = missing_keys(fallback_bases, native_bases)
  if !missing_native.is_empty() {
    return Err(
      "unavailable fallback files are missing native implementations: " +
      @tools.comma_join(missing_native),
    )
  }

  for base in @tools.sorted_map_keys(native_bases) {
    match
      require_targets(target_entries, base + "_native.mbt", native_targets) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    match
      require_targets(
        target_entries,
        base + "_unavailable.mbt",
        fallback_targets,
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }

  let native_file_map = map_from_names(native_files)
  let fallback_file_map = map_from_names(fallback_files)
  let missing_files : Array[String] = []
  let unpaired_entries : Array[String] = []
  for name in target_entries.keys() {
    if name.has_suffix("_native.mbt") || name.has_suffix("_unavailable.mbt") {
      let entry_path = @tools.join_path(resolved_native_dir, name)
      if !native_file_map.contains(name) && !fallback_file_map.contains(name) {
        unpaired_entries.push(name)
      }
      if !entry_path_is_known(entry_path) {
        missing_files.push(name)
      }
    }
  }
  missing_files.sort()
  unpaired_entries.sort()
  if !missing_files.is_empty() {
    return Err(
      "native moon.pkg target entries reference missing files: " +
      @tools.comma_join(missing_files),
    )
  }
  if !unpaired_entries.is_empty() {
    return Err(
      "native moon.pkg target entries are not native/fallback implementation files: " +
      @tools.comma_join(unpaired_entries),
    )
  }

  Ok("Verified native fallback parity in " + resolved_native_dir)
}

///|
fn entry_path_is_known(path : String) -> Bool {
  @tools.file_exists(path)
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) =>
      match verify_native_fallback_parity(options) {
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
