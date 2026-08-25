///|
let primitive_types : Map[String, Bool] = {
  "Bool": true,
  "Byte": true,
  "Char": true,
  "Double": true,
  "Float": true,
  "Int": true,
  "Int16": true,
  "Int64": true,
  "Int8": true,
  "UInt": true,
  "UInt16": true,
  "UInt64": true,
  "UInt8": true,
  "Unit": true,
}

///|
struct CliOptions {
  repo_root : String
  native_dir : String
  help : Bool
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui_skia/verify_native_ffi_borrows [options]
    #|
    #|Checks native MoonBit extern "C" declarations so every non-primitive
    #|parameter is explicitly listed in #borrow(...) or #owned(...).
    #|
    #|Options:
    #|  --repo-root PATH      Repository root used to resolve relative paths. Defaults to cwd.
    #|  --native-dir PATH     Native package directory. Defaults to native.
    #|  -h, --help            Show this help.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let native_dir = Ref("native")
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
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      other => return Err("unknown argument: " + other)
    }
  }
  Ok({ repo_root: repo_root.val, native_dir: native_dir.val, help: help.val })
}

///|
fn find_substring(
  text : Array[Char],
  needle : Array[Char],
  start : Int,
) -> Int? {
  if needle.is_empty() {
    return Some(start)
  }
  if text.length() < needle.length() || start > text.length() - needle.length() {
    return None
  }
  let mut index = start
  while index <= text.length() - needle.length() {
    let mut matched = true
    let mut offset = 0
    while matched && offset < needle.length() {
      if text[index + offset] != needle[offset] {
        matched = false
      }
      offset += 1
    }
    if matched {
      return Some(index)
    }
    index += 1
  }
  None
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
fn ascii_whitespace(char : Char) -> Bool {
  char == ' ' || char == '\n' || char == '\r' || char == '\t'
}

///|
fn skip_whitespace(chars : Array[Char], start : Int) -> Int {
  let mut index = start
  while index < chars.length() && ascii_whitespace(chars[index]) {
    index += 1
  }
  index
}

///|
fn identifier_char(char : Char) -> Bool {
  (char >= 'A' && char <= 'Z') ||
  (char >= 'a' && char <= 'z') ||
  (char >= '0' && char <= '9') ||
  char == '_'
}

///|
fn read_identifier(chars : Array[Char], start : Int) -> (String, Int)? {
  let index = skip_whitespace(chars, start)
  if index >= chars.length() {
    return None
  }
  let first = chars[index]
  if !((first >= 'A' && first <= 'Z') ||
    (first >= 'a' && first <= 'z') ||
    first == '_') {
    return None
  }
  let mut end = index + 1
  while end < chars.length() && identifier_char(chars[end]) {
    end += 1
  }
  Some((chars_to_string(chars, index, end), end))
}

///|
fn split_blocks(text : String) -> Array[String] {
  let chars = text.to_array()
  let marker = "///|".to_array()
  let blocks : Array[String] = []
  let mut start = 0
  let mut index = 0
  while index < chars.length() {
    let at_line_start = index == 0 || chars[index - 1] == '\n'
    match find_substring(chars, marker, index) {
      Some(found) if found == index && at_line_start => {
        blocks.push(chars_to_string(chars, start, index))
        index += marker.length()
        start = index
      }
      Some(found) => index = found
      None => index = chars.length()
    }
    if index < chars.length() && !(index == 0 || chars[index - 1] == '\n') {
      index += 1
    }
  }
  blocks.push(chars_to_string(chars, start, chars.length()))
  blocks
}

///|
fn split_top_level(text : String) -> Array[String] {
  let chars = text.to_array()
  let parts : Array[String] = []
  let mut start = 0
  let mut bracket_depth = 0
  let mut paren_depth = 0
  for index in 0..<chars.length() {
    match chars[index] {
      '[' => bracket_depth += 1
      ']' if bracket_depth > 0 => bracket_depth -= 1
      '(' => paren_depth += 1
      ')' if paren_depth > 0 => paren_depth -= 1
      ',' if bracket_depth == 0 && paren_depth == 0 => {
        parts.push(chars_to_string(chars, start, index).trim().to_owned())
        start = index + 1
      }
      _ => ()
    }
  }
  let tail = chars_to_string(chars, start, chars.length()).trim().to_owned()
  if tail != "" {
    parts.push(tail)
  }
  parts
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
fn parse_params(
  params_text : String,
  path : String,
  fn_name : String,
) -> Result[Map[String, String], String] {
  let params : Map[String, String] = Map([])
  for part in split_top_level(params_text) {
    if part == "" {
      continue
    }
    let chars = part.to_array()
    let mut colon = -1
    for index in 0..<chars.length() {
      if chars[index] == ':' && colon < 0 {
        colon = index
      }
    }
    if colon <= 0 {
      return Err(
        path + ": could not parse parameter in " + fn_name + ": " + part,
      )
    }
    let name = chars_to_string(chars, 0, colon).trim().to_owned()
    let typ = chars_to_string(chars, colon + 1, chars.length())
      .trim()
      .to_owned()
    if name == "" || typ == "" {
      return Err(
        path + ": could not parse parameter in " + fn_name + ": " + part,
      )
    }
    if params.contains(name) {
      return Err(path + ": duplicate parameter " + name + " in " + fn_name)
    }
    params[name] = typ
  }
  Ok(params)
}

///|
fn normalized_type(typ : String) -> String {
  let builder = StringBuilder()
  for char in typ {
    if !ascii_whitespace(char) {
      builder.write_char(char)
    }
  }
  let normalized = builder.to_string()
  if normalized.has_suffix("?") {
    normalized[:normalized.length() - 1].to_owned()
  } else {
    normalized
  }
}

///|
fn non_primitive_type(typ : String) -> Bool {
  !primitive_types.contains(normalized_type(typ))
}

///|
fn parse_annotations(
  prefix : String,
  path : String,
  fn_name : String,
) -> Result[Map[String, String], String] {
  let chars = prefix.to_array()
  let borrow = "#borrow(".to_array()
  let owned = "#owned(".to_array()
  let annotated : Map[String, String] = Map([])
  let duplicates : Map[String, Bool] = Map([])
  let mut index = 0
  while index < chars.length() {
    let found = match find_substring(chars, borrow, index) {
      Some(position) => Some((position, "borrow", borrow.length()))
      None =>
        match find_substring(chars, owned, index) {
          Some(position) => Some((position, "owned", owned.length()))
          None => None
        }
    }
    match found {
      Some((position, kind, marker_length)) => {
        let start = position + marker_length
        let mut end = start
        while end < chars.length() && chars[end] != ')' {
          end += 1
        }
        if end >= chars.length() {
          return Err(
            path + ": unterminated FFI ownership annotation in " + fn_name,
          )
        }
        let names = chars_to_string(chars, start, end)
        for raw_name in names.split(",").to_array() {
          let name = raw_name.trim().to_owned()
          if name == "" {
            continue
          }
          if annotated.contains(name) {
            duplicates[name] = true
          }
          annotated[name] = kind
        }
        index = end + 1
      }
      None => index = chars.length()
    }
  }
  if !duplicates.is_empty() {
    return Err(
      path +
      ": duplicate FFI ownership annotation(s) in " +
      fn_name +
      ": " +
      @tools.comma_join(@tools.sorted_map_keys(duplicates)),
    )
  }
  Ok(annotated)
}

///|
fn extern_match(chars : Array[Char]) -> (Int, Int, String)? {
  let upper = "extern \"C\" fn".to_array()
  let lower = "extern \"c\" fn".to_array()
  let found = match find_substring(chars, upper, 0) {
    Some(position) => Some((position, upper.length()))
    None =>
      match find_substring(chars, lower, 0) {
        Some(position) => Some((position, lower.length()))
        None => None
      }
  }
  match found {
    Some((position, length)) =>
      match read_identifier(chars, position + length) {
        Some((fn_name, after_name)) => Some((position, after_name, fn_name))
        None => None
      }
    None => None
  }
}

///|
fn check_block(block : String, path : String) -> Result[Unit, String] {
  let chars = block.to_array()
  match extern_match(chars) {
    None => Ok(())
    Some((extern_start, after_name, fn_name)) => {
      let mut open_index = after_name
      while open_index < chars.length() && chars[open_index] != '(' {
        open_index += 1
      }
      if open_index >= chars.length() {
        return Err(path + ": missing parameter list for " + fn_name)
      }
      let close_index = match find_matching_paren(chars, open_index) {
        Some(index) => index
        None => return Err("unterminated extern parameter list")
      }
      let params_text = chars_to_string(chars, open_index + 1, close_index)
      let params = match parse_params(params_text, path, fn_name) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      let annotations = match
        parse_annotations(
          chars_to_string(chars, 0, extern_start),
          path,
          fn_name,
        ) {
        Ok(value) => value
        Err(message) => return Err(message)
      }

      let unknown : Array[String] = []
      for name in annotations.keys() {
        if !params.contains(name) {
          unknown.push(name)
        }
      }
      unknown.sort()
      if !unknown.is_empty() {
        return Err(
          path +
          ": " +
          fn_name +
          " annotates unknown parameter(s): " +
          @tools.comma_join(unknown),
        )
      }

      let missing : Array[String] = []
      let unnecessary : Array[String] = []
      for name in params.keys() {
        let typ = params[name]
        if non_primitive_type(typ) {
          if !annotations.contains(name) {
            missing.push(name)
          }
        } else if annotations.contains(name) {
          unnecessary.push(name)
        }
      }
      missing.sort()
      unnecessary.sort()
      if !missing.is_empty() {
        return Err(
          path +
          ": " +
          fn_name +
          " is missing #borrow/#owned for non-primitive parameter(s): " +
          @tools.comma_join(missing),
        )
      }
      if !unnecessary.is_empty() {
        return Err(
          path +
          ": " +
          fn_name +
          " annotates primitive parameter(s): " +
          @tools.comma_join(unnecessary),
        )
      }
      Ok(())
    }
  }
}

///|
fn verify_native_ffi_borrows(options : CliOptions) -> Result[String, String] {
  let resolved_native_dir = @tools.resolve_path(
    options.repo_root,
    options.native_dir,
  )
  if !@tools.directory_exists(resolved_native_dir) {
    return Err("native package directory is missing: " + resolved_native_dir)
  }
  let files = match
    @tools.file_names_with_suffix(resolved_native_dir, "_native.mbt") {
    Ok(values) => values
    Err(message) => return Err(message)
  }
  if files.is_empty() {
    return Err(
      "native package directory has no *_native.mbt files: " +
      resolved_native_dir,
    )
  }
  for file_name in files {
    let path = @tools.join_path(resolved_native_dir, file_name)
    let text = match @tools.read_required_text(path, "native MoonBit file") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    for block in split_blocks(text) {
      match check_block(block, path) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
  }
  Ok("Verified native FFI borrow annotations in " + resolved_native_dir)
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) =>
      match verify_native_ffi_borrows(options) {
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
