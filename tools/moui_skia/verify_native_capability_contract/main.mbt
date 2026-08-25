///|
let native_targets : Array[String] = ["native", "llvm"]

///|
let fallback_targets : Array[String] = ["wasm", "wasm-gc", "js"]

///|
struct CliOptions {
  repo_root : String
  manifest : String
  native_dir : String
  pkg_path : String
  ownership : String
  status_file : String
  smoke_source : String
  help : Bool
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui_skia/verify_native_capability_contract [options]
    #|
    #|Checks native/capabilities.json against native MoonBit implementation files,
    #|fallback twins, ownership metadata, and smoke capability markers.
    #|
    #|Options:
    #|  --repo-root PATH      Repository root used to resolve relative paths. Defaults to cwd.
    #|  --manifest PATH       Native capability manifest. Defaults to native/capabilities.json.
    #|  --native-dir PATH     Native package directory. Defaults to native.
    #|  --pkg PATH            Native moon.pkg path. Defaults to native/moon.pkg.
    #|  --ownership PATH      Native ownership manifest. Defaults to native/ownership.json.
    #|  --status-file PATH    Platform status JSON. Defaults to skia-platform-status.json.
    #|  --smoke-source PATH   Native smoke source file or directory. Defaults to scripts/native_smoke.
    #|  -h, --help            Show this help.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let manifest = Ref("native/capabilities.json")
  let native_dir = Ref("native")
  let pkg_path = Ref("native/moon.pkg")
  let ownership = Ref("native/ownership.json")
  let status_file = Ref("skia-platform-status.json")
  let smoke_source = Ref("scripts/native_smoke")
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
      "--manifest" => {
        if index + 1 >= args.length() {
          return Err("missing value for --manifest")
        }
        manifest.val = args[index + 1]
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
      "--ownership" => {
        if index + 1 >= args.length() {
          return Err("missing value for --ownership")
        }
        ownership.val = args[index + 1]
        index += 2
      }
      "--status-file" => {
        if index + 1 >= args.length() {
          return Err("missing value for --status-file")
        }
        status_file.val = args[index + 1]
        index += 2
      }
      "--smoke-source" => {
        if index + 1 >= args.length() {
          return Err("missing value for --smoke-source")
        }
        smoke_source.val = args[index + 1]
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
    manifest: manifest.val,
    native_dir: native_dir.val,
    pkg_path: pkg_path.val,
    ownership: ownership.val,
    status_file: status_file.val,
    smoke_source: smoke_source.val,
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
fn identifier_start(char : Char) -> Bool {
  (char >= 'A' && char <= 'Z') || (char >= 'a' && char <= 'z') || char == '_'
}

///|
fn identifier_char(char : Char) -> Bool {
  identifier_start(char) || (char >= '0' && char <= '9')
}

///|
fn chars_to_string(chars : Array[Char], start : Int, end : Int) -> String {
  let builder = StringBuilder()
  for index in start..<end {
    builder.write_char(chars[index])
  }
  builder.to_string()
}

///|
fn read_identifier(chars : Array[Char], start : Int) -> (String, Int)? {
  let start = skip_whitespace(chars, start)
  if start >= chars.length() || !identifier_start(chars[start]) {
    return None
  }
  let mut end = start + 1
  while end < chars.length() && identifier_char(chars[end]) {
    end += 1
  }
  Some((chars_to_string(chars, start, end), end))
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
fn word_at(chars : Array[Char], start : Int, word : String) -> Bool {
  let word_chars = word.to_array()
  if start + word_chars.length() > chars.length() {
    return false
  }
  for offset in 0..<word_chars.length() {
    if chars[start + offset] != word_chars[offset] {
      return false
    }
  }
  let before_ok = start == 0 || !identifier_char(chars[start - 1])
  let after = start + word_chars.length()
  let after_ok = after >= chars.length() || !identifier_char(chars[after])
  before_ok && after_ok
}

///|
fn find_matching_paren(chars : Array[Char], open_index : Int) -> Int? {
  let mut depth = 0
  for index in open_index..<chars.length() {
    match chars[index] {
      '(' => depth += 1
      ')' => {
        depth -= 1
        if depth == 0 {
          return Some(index)
        }
      }
      _ => ()
    }
  }
  None
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
            match parse_target_list(chars, array_start + 1) {
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
fn parse_public_function_at(chars : Array[Char], start : Int) -> (String, Int)? {
  if !word_at(chars, start, "pub") {
    return None
  }
  let mut index = skip_whitespace(chars, start + 3)
  if index < chars.length() && chars[index] == '(' {
    match find_matching_paren(chars, index) {
      Some(close_index) => index = skip_whitespace(chars, close_index + 1)
      None => return None
    }
  }
  if word_at(chars, index, "extern") {
    index = skip_whitespace(chars, index + "extern".length())
    match read_quoted(chars, index) {
      Some((_abi, after_abi)) => index = skip_whitespace(chars, after_abi)
      None => ()
    }
  }
  if !word_at(chars, index, "fn") {
    return None
  }
  index = skip_whitespace(chars, index + 2)
  match read_identifier(chars, index) {
    Some((first, after_first)) => {
      let after_first = skip_whitespace(chars, after_first)
      if after_first + 1 < chars.length() &&
        chars[after_first] == ':' &&
        chars[after_first + 1] == ':' {
        match read_identifier(chars, after_first + 2) {
          Some((second, after_second)) =>
            Some((first + "::" + second, after_second))
          None => Some((first, after_first))
        }
      } else {
        Some((first, after_first))
      }
    }
    None => None
  }
}

///|
fn public_functions(text : String) -> Map[String, Bool] {
  let chars = text.to_array()
  let names : Map[String, Bool] = Map([])
  let mut index = 0
  while index < chars.length() {
    match parse_public_function_at(chars, index) {
      Some((name, after_name)) => {
        names[name] = true
        index = after_name
      }
      None => index += 1
    }
  }
  names
}

///|
fn json_object(
  value : Json,
  label : String,
) -> Result[Map[String, Json], String] {
  match value {
    Json::Object(fields) => Ok(fields)
    _ => Err(label + " must be an object")
  }
}

///|
fn json_string_field(fields : Map[String, Json], key : String) -> String {
  match fields.get(key) {
    Some(Json::String(value)) => value.trim().to_owned()
    _ => ""
  }
}

///|
fn json_array_field_or_empty(
  fields : Map[String, Json],
  key : String,
  label : String,
) -> Result[Array[Json], String] {
  match fields.get(key) {
    None | Some(Json::Null) => Ok([])
    Some(Json::Array(values)) => Ok(values)
    _ => Err(label + " must be a list")
  }
}

///|
fn required_array_field(
  fields : Map[String, Json],
  key : String,
  message : String,
) -> Result[Array[Json], String] {
  match fields.get(key) {
    Some(Json::Array(values)) if !values.is_empty() => Ok(values)
    _ => Err(message)
  }
}

///|
fn owned_names(
  ownership : Map[String, Json],
) -> Result[Map[String, Bool], String] {
  let names : Map[String, Bool] = Map([])
  for section in ["external_wrappers", "regular_objects"] {
    let entries = match
      json_array_field_or_empty(
        ownership,
        section,
        "native ownership manifest " + section,
      ) {
      Ok(values) => values
      Err(message) => return Err(message)
    }
    for entry in entries {
      let fields = match
        json_object(entry, "native ownership " + section + " entries") {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let name = json_string_field(fields, "name")
      if name != "" {
        names[name] = true
      }
    }
  }
  Ok(names)
}

///|
fn status_markers(
  status : Map[String, Json],
) -> Result[Map[String, Bool], String] {
  let markers : Map[String, Bool] = Map([])
  for
    section in [
      "native_smoke_capabilities", "native_smoke_conditional_capabilities",
    ] {
    let entries = match
      json_array_field_or_empty(status, section, "platform status " + section) {
      Ok(values) => values
      Err(message) => return Err(message)
    }
    for entry in entries {
      let fields = match
        json_object(entry, "platform status " + section + " entries") {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let marker = json_string_field(fields, "marker")
      if marker != "" {
        markers[marker] = true
      }
    }
  }
  Ok(markers)
}

///|
fn json_string_list(
  fields : Map[String, Json],
  key : String,
  label : String,
) -> Result[Array[String], String] {
  let values = match json_array_field_or_empty(fields, key, label) {
    Ok(values) => values
    Err(message) => return Err(message)
  }
  let strings : Array[String] = []
  for value in values {
    match value {
      Json::String(text) => strings.push(text.trim().to_owned())
      _ => strings.push("")
    }
  }
  Ok(strings)
}

///|
fn map_contains_all_public_apis(
  capability_id : String,
  native_exports : Map[String, Bool],
  fallback_exports : Map[String, Bool],
) -> Result[Unit, String] {
  let missing_fallback_exports : Array[String] = []
  for name in native_exports.keys() {
    if !fallback_exports.contains(name) {
      missing_fallback_exports.push(name)
    }
  }
  missing_fallback_exports.sort()
  if !missing_fallback_exports.is_empty() {
    return Err(
      "native capability fallback is missing public APIs: " +
      capability_id +
      ": " +
      @tools.comma_join(missing_fallback_exports),
    )
  }
  let extra_fallback_exports : Array[String] = []
  for name in fallback_exports.keys() {
    if !native_exports.contains(name) {
      extra_fallback_exports.push(name)
    }
  }
  extra_fallback_exports.sort()
  if !extra_fallback_exports.is_empty() {
    return Err(
      "native capability fallback has public APIs absent from native side: " +
      capability_id +
      ": " +
      @tools.comma_join(extra_fallback_exports),
    )
  }
  Ok(())
}

///|
fn missing_keys(
  left : Map[String, String],
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
fn verify_capability_entry(
  capability : Json,
  target_entries : Map[String, Array[String]],
  native_files : Map[String, String],
  fallback_files : Map[String, String],
  owned : Map[String, Bool],
  markers_by_status : Map[String, Bool],
  smoke_source : String,
  covered_native_files : Map[String, Bool],
  covered_fallback_files : Map[String, Bool],
  seen_ids : Map[String, Bool],
  seen_markers : Map[String, Bool],
) -> Result[Unit, String] {
  let fields = match json_object(capability, "native capability entries") {
    Ok(value) => value
    Err(_) => return Err("native capability entries must be objects")
  }
  let capability_id = json_string_field(fields, "id")
  let area = json_string_field(fields, "area")
  let native_file = json_string_field(fields, "native_file")
  let unavailable_file = json_string_field(fields, "unavailable_file")
  let rationale = json_string_field(fields, "non_smoke_rationale")
  let handles = match
    json_string_list(fields, "handles", "native capability handles") {
    Ok(values) => values
    Err(_) =>
      return Err("native capability handles must be a list: " + capability_id)
  }
  let smoke_markers = match
    json_string_list(fields, "smoke_markers", "native capability smoke_markers") {
    Ok(values) => values
    Err(_) =>
      return Err(
        "native capability smoke_markers must be a list: " + capability_id,
      )
  }

  if capability_id == "" {
    return Err("native capability is missing id")
  }
  if seen_ids.contains(capability_id) {
    return Err("duplicate native capability id: " + capability_id)
  }
  seen_ids[capability_id] = true
  if area == "" {
    return Err("native capability is missing area: " + capability_id)
  }
  if !native_file.has_suffix("_native.mbt") {
    return Err(
      "native capability native_file must end with _native.mbt: " +
      capability_id,
    )
  }
  if !unavailable_file.has_suffix("_unavailable.mbt") {
    return Err(
      "native capability unavailable_file must end with _unavailable.mbt: " +
      capability_id,
    )
  }
  let native_text = match native_files.get(native_file) {
    Some(text) => text
    None =>
      return Err(
        "native capability references missing native file: " +
        capability_id +
        ": " +
        native_file,
      )
  }
  let fallback_text = match fallback_files.get(unavailable_file) {
    Some(text) => text
    None =>
      return Err(
        "native capability references missing fallback file: " +
        capability_id +
        ": " +
        unavailable_file,
      )
  }
  covered_native_files[native_file] = true
  covered_fallback_files[unavailable_file] = true
  match target_entries.get(native_file) {
    Some(targets) if array_equal(targets, native_targets) => ()
    _ =>
      return Err(
        "native capability has wrong native targets in moon.pkg: " +
        capability_id +
        ": " +
        native_file,
      )
  }
  match target_entries.get(unavailable_file) {
    Some(targets) if array_equal(targets, fallback_targets) => ()
    _ =>
      return Err(
        "native capability has wrong fallback targets in moon.pkg: " +
        capability_id +
        ": " +
        unavailable_file,
      )
  }
  match
    map_contains_all_public_apis(
      capability_id,
      public_functions(native_text),
      public_functions(fallback_text),
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  for handle in handles {
    if handle == "" {
      return Err(
        "native capability has an empty handle entry: " + capability_id,
      )
    }
    if !owned.contains(handle) {
      return Err(
        "native capability handle is missing from ownership manifest: " +
        capability_id +
        ": " +
        handle,
      )
    }
  }
  if smoke_markers.is_empty() && rationale == "" {
    return Err(
      "native capability must list smoke_markers or non_smoke_rationale: " +
      capability_id,
    )
  }
  for marker in smoke_markers {
    if marker == "" {
      return Err(
        "native capability has an empty smoke marker: " + capability_id,
      )
    }
    if !markers_by_status.contains(marker) {
      return Err(
        "native capability smoke marker is missing from platform status: " +
        capability_id +
        ": " +
        marker,
      )
    }
    if !smoke_source.contains(marker) {
      return Err(
        "native capability smoke marker is not emitted by native smoke source: " +
        capability_id +
        ": " +
        marker,
      )
    }
    seen_markers[marker] = true
  }
  Ok(())
}

///|
fn verify_capability_contract_data(
  manifest : Map[String, Json],
  ownership : Map[String, Json],
  status : Map[String, Json],
  target_entries : Map[String, Array[String]],
  native_files : Map[String, String],
  fallback_files : Map[String, String],
  smoke_source : String,
) -> Result[Unit, String] {
  match manifest.get("schema_version") {
    Some(Json::Number(number, repr=_)) if number == 1.0 => ()
    Some(Json::Number(number, repr=_)) =>
      return Err("unsupported native capability schema_version: \{number}")
    _ => return Err("unsupported native capability schema_version: ")
  }
  let capabilities = match
    required_array_field(
      manifest, "capabilities", "native capability manifest is missing capabilities",
    ) {
    Ok(values) => values
    Err(message) => return Err(message)
  }
  let owned = match owned_names(ownership) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let markers_by_status = match status_markers(status) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let covered_native_files : Map[String, Bool] = Map([])
  let covered_fallback_files : Map[String, Bool] = Map([])
  let seen_ids : Map[String, Bool] = Map([])
  let seen_markers : Map[String, Bool] = Map([])
  for capability in capabilities {
    match
      verify_capability_entry(
        capability, target_entries, native_files, fallback_files, owned, markers_by_status,
        smoke_source, covered_native_files, covered_fallback_files, seen_ids, seen_markers,
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  let missing_manifest_native = missing_keys(native_files, covered_native_files)
  if !missing_manifest_native.is_empty() {
    return Err(
      "native capability manifest does not cover native files: " +
      @tools.comma_join(missing_manifest_native),
    )
  }
  let missing_manifest_fallback = missing_keys(
    fallback_files, covered_fallback_files,
  )
  if !missing_manifest_fallback.is_empty() {
    return Err(
      "native capability manifest does not cover fallback files: " +
      @tools.comma_join(missing_manifest_fallback),
    )
  }
  if seen_markers.is_empty() {
    return Err(
      "native capability manifest does not bind any runtime smoke marker",
    )
  }
  Ok(())
}

///|
fn read_json_object(
  path : String,
  label : String,
) -> Result[Map[String, Json], String] {
  let text = match @tools.read_required_text(path, label) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let parsed = @json.parse(text) catch {
    _ => return Err(label + " JSON is invalid: " + path)
  }
  json_object(parsed, label)
}

///|
fn read_file_map(
  directory : String,
  suffix : String,
  label : String,
) -> Result[Map[String, String], String] {
  if !@tools.directory_exists(directory) {
    return Err(label + " directory is missing: " + directory)
  }
  let names = match @tools.file_names_with_suffix(directory, suffix) {
    Ok(value) => value
    Err(message) => return Err(label + " " + message)
  }
  let files : Map[String, String] = Map([])
  for name in names {
    let path = @tools.join_path(directory, name)
    match @tools.read_required_text(path, label + " file") {
      Ok(text) => files[name] = text
      Err(message) => return Err(message)
    }
  }
  Ok(files)
}

///|
fn read_smoke_source(path : String) -> Result[String, String] {
  if @tools.file_exists(path) {
    return @tools.read_required_text(path, "native smoke source")
  }
  if !@tools.directory_exists(path) {
    return Err("native smoke source is missing: " + path)
  }
  let names = match @tools.file_names_with_suffix(path, ".mbt") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if names.is_empty() {
    return Err("native smoke source directory has no .mbt files: " + path)
  }
  let builder = StringBuilder()
  for index in 0..<names.length() {
    if index > 0 {
      builder.write_char('\n')
    }
    match
      @tools.read_required_text(
        @tools.join_path(path, names[index]),
        "native smoke source",
      ) {
      Ok(text) => builder.write_string(text)
      Err(message) => return Err(message)
    }
  }
  Ok(builder.to_string())
}

///|
fn verify_native_capability_contract(
  options : CliOptions,
) -> Result[String, String] {
  let manifest_path = @tools.resolve_path(options.repo_root, options.manifest)
  let native_dir = @tools.resolve_path(options.repo_root, options.native_dir)
  let pkg_path = @tools.resolve_path(options.repo_root, options.pkg_path)
  let ownership_path = @tools.resolve_path(options.repo_root, options.ownership)
  let status_path = @tools.resolve_path(options.repo_root, options.status_file)
  let smoke_source_path = @tools.resolve_path(
    options.repo_root,
    options.smoke_source,
  )
  let manifest = match
    read_json_object(manifest_path, "native capability manifest") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let ownership = match
    read_json_object(ownership_path, "native ownership manifest") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let status = match read_json_object(status_path, "Skia platform status") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let pkg_text = match @tools.read_required_text(pkg_path, "native moon.pkg") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let target_entries = match parse_target_entries(pkg_text) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let native_files = match
    read_file_map(native_dir, "_native.mbt", "native package") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let fallback_files = match
    read_file_map(native_dir, "_unavailable.mbt", "native package") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let smoke_source = match read_smoke_source(smoke_source_path) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match
    verify_capability_contract_data(
      manifest, ownership, status, target_entries, native_files, fallback_files,
      smoke_source,
    ) {
    Ok(_) => Ok("Verified native capability contract in " + manifest_path)
    Err(message) => Err(message)
  }
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) =>
      match verify_native_capability_contract(options) {
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
