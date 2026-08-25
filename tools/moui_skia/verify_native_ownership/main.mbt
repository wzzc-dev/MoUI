///|
struct CliOptions {
  repo_root : String
  manifest : String
  header : String
  source : String
  handles : String
  types : String
  help : Bool
}

///|
struct OwnershipInputs {
  manifest_path : String
  handle_paths : Array[String]
  header_text : String
  source_text : String
  types_text : String
}

///|
struct ExternalWrapper {
  name : String
  moonbit_handle : String
  moonbit_type : String
  wrapper_struct : String
  field : String
  owner_field : String?
  owner_type : String?
  moonbit_owner_field : String?
  factory : String
  finalizer : String
  ownership : String
}

///|
struct RegularObject {
  name : String
  moonbit_handle : String?
  moonbit_type : String?
  wrapper_struct : String
  factory : String
  allocation : String
  pointer_field_count : Int
  pointer_fields : Array[String]
  value_fields : Array[String]
}

///|
struct OwnershipManifest {
  external_wrappers : Array[ExternalWrapper]
  regular_objects : Array[RegularObject]
  regular_runtime_objects : Array[RegularObject]
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui_skia/verify_native_ownership [options]
    #|
    #|Checks native/ownership.json against MoonBit handle declarations and the
    #|C++ stub wrapper/finalizer implementation.
    #|
    #|Options:
    #|  --repo-root PATH      Repository root used to resolve relative paths. Defaults to cwd.
    #|  --manifest PATH       Ownership manifest. Defaults to native/ownership.json.
    #|  --header PATH         Native common header. Defaults to the manifest value.
    #|  --source PATH         Native common C++ source. Defaults to the manifest value.
    #|  --handles PATH        MoonBit handle declarations. Defaults to the manifest value.
    #|  --types PATH          MoonBit public wrapper types. Defaults to the manifest value.
    #|  -h, --help            Show this help.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let manifest = Ref("native/ownership.json")
  let header = Ref("")
  let source = Ref("")
  let handles = Ref("")
  let types = Ref("")
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
      "--header" => {
        if index + 1 >= args.length() {
          return Err("missing value for --header")
        }
        header.val = args[index + 1]
        index += 2
      }
      "--source" => {
        if index + 1 >= args.length() {
          return Err("missing value for --source")
        }
        source.val = args[index + 1]
        index += 2
      }
      "--handles" => {
        if index + 1 >= args.length() {
          return Err("missing value for --handles")
        }
        handles.val = args[index + 1]
        index += 2
      }
      "--types" => {
        if index + 1 >= args.length() {
          return Err("missing value for --types")
        }
        types.val = args[index + 1]
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
    header: header.val,
    source: source.val,
    handles: handles.val,
    types: types.val,
    help: help.val,
  })
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
fn json_optional_string_field(
  fields : Map[String, Json],
  key : String,
) -> String? {
  match fields.get(key) {
    Some(Json::String(value)) if value.trim().to_owned() != "" =>
      Some(value.trim().to_owned())
    _ => None
  }
}

///|
fn json_required_string(
  fields : Map[String, Json],
  key : String,
  label : String,
) -> Result[String, String] {
  let value = json_string_field(fields, key)
  if value == "" {
    Err(label + " entry is missing " + key)
  } else {
    Ok(value)
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
fn json_required_array(
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
fn json_string_array(
  fields : Map[String, Json],
  key : String,
  label : String,
) -> Result[Array[String], String] {
  match fields.get(key) {
    Some(Json::Array(values)) => {
      let strings : Array[String] = []
      for value in values {
        match value {
          Json::String(text) if text.trim().to_owned() != "" =>
            strings.push(text.trim().to_owned())
          _ => return Err(label + " regular object is missing " + key + " list")
        }
      }
      Ok(strings)
    }
    _ => Err(label + " regular object is missing " + key + " list")
  }
}

///|
fn json_int_field(
  fields : Map[String, Json],
  key : String,
  label : String,
) -> Result[Int, String] {
  match fields.get(key) {
    Some(Json::Number(number, repr=_)) => {
      let value = number.to_int()
      if number == value.to_double() && value >= 0 {
        Ok(value)
      } else {
        Err(label + " regular object is missing non-negative " + key)
      }
    }
    _ => Err(label + " regular object is missing non-negative " + key)
  }
}

///|
fn parse_external_wrapper(value : Json) -> Result[ExternalWrapper, String] {
  let fields = match
    json_object(value, "native ownership external wrapper entry") {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let name = match json_required_string(fields, "name", "native ownership") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let moonbit_handle = match
    json_required_string(fields, "moonbit_handle", "native ownership") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let moonbit_type = match
    json_required_string(fields, "moonbit_type", "native ownership") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let wrapper_struct = match
    json_required_string(fields, "wrapper_struct", "native ownership") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let field = match json_required_string(fields, "field", "native ownership") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let factory = match
    json_required_string(fields, "factory", "native ownership") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let finalizer = match
    json_required_string(fields, "finalizer", "external wrapper") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let ownership = match
    json_required_string(fields, "ownership", "native ownership") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({
    name,
    moonbit_handle,
    moonbit_type,
    wrapper_struct,
    field,
    owner_field: json_optional_string_field(fields, "owner_field"),
    owner_type: json_optional_string_field(fields, "owner_type"),
    moonbit_owner_field: json_optional_string_field(
      fields, "moonbit_owner_field",
    ),
    factory,
    finalizer,
    ownership,
  })
}

///|
fn parse_regular_object(
  value : Json,
  require_moonbit_wrapper : Bool,
) -> Result[RegularObject, String] {
  let fields = match
    json_object(value, "native ownership regular object entry") {
    Ok(result) => result
    Err(message) => return Err(message)
  }
  let name = match json_required_string(fields, "name", "native ownership") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let moonbit_handle = json_optional_string_field(fields, "moonbit_handle")
  let moonbit_type = json_optional_string_field(fields, "moonbit_type")
  if require_moonbit_wrapper && (moonbit_handle is None || moonbit_type is None) {
    return Err(name + " regular object is missing MoonBit handle/type")
  }
  let wrapper_struct = match
    json_required_string(fields, "wrapper_struct", "native ownership") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let factory = match
    json_required_string(fields, "factory", "native ownership") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let allocation = match
    json_required_string(fields, "allocation", "native ownership") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let pointer_field_count = match
    json_int_field(fields, "pointer_field_count", name) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let pointer_fields = match json_string_array(fields, "pointer_fields", name) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let value_fields = match json_string_array(fields, "value_fields", name) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({
    name,
    moonbit_handle,
    moonbit_type,
    wrapper_struct,
    factory,
    allocation,
    pointer_field_count,
    pointer_fields,
    value_fields,
  })
}

///|
fn parse_manifest(text : String) -> Result[OwnershipManifest, String] {
  let parsed = @json.parse(text) catch {
    _ => return Err("native ownership manifest JSON is invalid")
  }
  let root = match json_object(parsed, "native ownership manifest") {
    Ok(fields) => fields
    Err(message) => return Err(message)
  }
  match root.get("schema_version") {
    Some(Json::Number(number, repr=_)) if number == 1.0 => ()
    Some(Json::Number(number, repr=_)) =>
      return Err(
        "unsupported native ownership schema_version: " + number.to_string(),
      )
    _ => return Err("unsupported native ownership schema_version: ")
  }
  let external_values = match
    json_required_array(
      root, "external_wrappers", "native ownership manifest is missing external_wrappers",
    ) {
    Ok(values) => values
    Err(message) => return Err(message)
  }
  let regular_values = match
    json_array_field_or_empty(
      root, "regular_objects", "native ownership manifest regular_objects",
    ) {
    Ok(values) => values
    Err(message) => return Err(message)
  }
  let runtime_values = match
    json_array_field_or_empty(
      root, "regular_runtime_objects", "native ownership manifest regular_runtime_objects",
    ) {
    Ok(values) => values
    Err(message) => return Err(message)
  }
  let external_wrappers : Array[ExternalWrapper] = []
  let regular_objects : Array[RegularObject] = []
  let regular_runtime_objects : Array[RegularObject] = []
  for value in external_values {
    match parse_external_wrapper(value) {
      Ok(entry) => external_wrappers.push(entry)
      Err(message) => return Err(message)
    }
  }
  for value in regular_values {
    match parse_regular_object(value, true) {
      Ok(entry) => regular_objects.push(entry)
      Err(message) => return Err(message)
    }
  }
  for value in runtime_values {
    match parse_regular_object(value, false) {
      Ok(entry) => regular_runtime_objects.push(entry)
      Err(message) => return Err(message)
    }
  }
  Ok({ external_wrappers, regular_objects, regular_runtime_objects })
}

///|
fn is_ascii_whitespace(char : Char) -> Bool {
  char == ' ' || char == '\n' || char == '\r' || char == '\t'
}

///|
fn identifier_char(char : Char) -> Bool {
  (char >= 'A' && char <= 'Z') ||
  (char >= 'a' && char <= 'z') ||
  (char >= '0' && char <= '9') ||
  char == '_'
}

///|
fn identifier_start(char : Char) -> Bool {
  (char >= 'A' && char <= 'Z') || (char >= 'a' && char <= 'z') || char == '_'
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
fn skip_whitespace(chars : Array[Char], start : Int) -> Int {
  let mut index = start
  while index < chars.length() && is_ascii_whitespace(chars[index]) {
    index += 1
  }
  index
}

///|
fn read_identifier(chars : Array[Char], start : Int) -> (String, Int)? {
  let index = skip_whitespace(chars, start)
  if index >= chars.length() || !identifier_start(chars[index]) {
    return None
  }
  let mut end = index + 1
  while end < chars.length() && identifier_char(chars[end]) {
    end += 1
  }
  Some((chars_to_string(chars, index, end), end))
}

///|
fn has_identifier_boundary(chars : Array[Char], start : Int, end : Int) -> Bool {
  let before_ok = start == 0 || !identifier_char(chars[start - 1])
  let after_ok = end >= chars.length() || !identifier_char(chars[end])
  before_ok && after_ok
}

///|
fn find_identifier_occurrence(
  text : String,
  name : String,
  start : Int,
) -> Int? {
  let chars = text.to_array()
  let needle = name.to_array()
  let search = Ref(start)
  while search.val < chars.length() {
    match find_substring(chars, needle, search.val) {
      Some(found) => {
        let end = found + needle.length()
        if has_identifier_boundary(chars, found, end) {
          return Some(found)
        }
        search.val = found + 1
      }
      None => return None
    }
  }
  None
}

///|
fn find_next_char(chars : Array[Char], start : Int, target : Char) -> Int? {
  for index in start..<chars.length() {
    if chars[index] == target {
      return Some(index)
    }
  }
  None
}

///|
fn matching_brace(chars : Array[Char], open_index : Int) -> Int? {
  let mut depth = 0
  for index in open_index..<chars.length() {
    match chars[index] {
      '{' => depth += 1
      '}' => {
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
fn braced_body_after(
  text : String,
  start : Int,
  label : String,
) -> Result[String, String] {
  let chars = text.to_array()
  let open_index = match find_next_char(chars, start, '{') {
    Some(value) => value
    None => return Err("missing " + label)
  }
  let close_index = match matching_brace(chars, open_index) {
    Some(value) => value
    None => return Err("unterminated " + label)
  }
  Ok(chars_to_string(chars, open_index + 1, close_index))
}

///|
fn function_body(
  text : String,
  name : String,
  label : String,
) -> Result[String, String] {
  let start = match find_identifier_occurrence(text, name, 0) {
    Some(value) => value
    None => return Err("missing " + label)
  }
  braced_body_after(text, start, label)
}

///|
fn struct_body(
  text : String,
  name : String,
  label : String,
) -> Result[String, String] {
  let prefix = "struct " + name
  let start = match find_substring(text.to_array(), prefix.to_array(), 0) {
    Some(value) => value
    None => return Err("missing " + label)
  }
  braced_body_after(text, start + prefix.length(), label)
}

///|
fn moonbit_type_body(
  text : String,
  type_name : String,
) -> Result[String, String] {
  let prefix = "struct " + type_name
  let chars = text.to_array()
  let search = Ref(0)
  while search.val < chars.length() {
    match find_substring(chars, prefix.to_array(), search.val) {
      Some(found) => {
        let end = found + prefix.length()
        if end >= chars.length() ||
          is_ascii_whitespace(chars[end]) ||
          chars[end] == '{' {
          return braced_body_after(
            text,
            end,
            "MoonBit wrapper type " + type_name,
          )
        }
        search.val = found + 1
      }
      None => return Err("missing MoonBit wrapper type " + type_name)
    }
  }
  Err("missing MoonBit wrapper type " + type_name)
}

///|
fn compact_whitespace(text : String) -> String {
  let builder = StringBuilder()
  let mut in_space = false
  for char in text {
    if is_ascii_whitespace(char) {
      if !in_space {
        builder.write_char(' ')
      }
      in_space = true
    } else {
      builder.write_char(char)
      in_space = false
    }
  }
  builder.to_string().trim().to_owned()
}

///|
fn contains_priv_field(
  type_body : String,
  field : String,
  typ : String,
) -> Bool {
  compact_whitespace(type_body).contains("priv " + field + " : " + typ)
}

///|
fn contains_field_declaration(body : String, field : String) -> Bool {
  for line_view in body.split("\n") {
    let line = line_view.trim().to_owned()
    if line.has_suffix(";") {
      let chars = line.to_array()
      let mut end = chars.length() - 1
      while end > 0 && !identifier_char(chars[end - 1]) {
        end -= 1
      }
      let mut start = end
      while start > 0 && identifier_char(chars[start - 1]) {
        start -= 1
      }
      if start < end && chars_to_string(chars, start, end) == field {
        return true
      }
    }
  }
  false
}

///|
fn pointer_field_names(body : String) -> Array[String] {
  let names : Array[String] = []
  for line_view in body.split("\n") {
    let line = line_view.trim().to_owned()
    if line.has_suffix(";") && line.contains("*") {
      let chars = line.to_array()
      let mut end = chars.length() - 1
      while end > 0 && !identifier_char(chars[end - 1]) {
        end -= 1
      }
      let mut start = end
      while start > 0 && identifier_char(chars[start - 1]) {
        start -= 1
      }
      if start < end {
        names.push(chars_to_string(chars, start, end))
      }
    }
  }
  names
}

///|
fn contains_assignment(body : String, field : String) -> Bool {
  for line_view in body.split("\n") {
    let line = line_view.trim().to_owned()
    if line.contains("->" + field) && line.contains("=") {
      return true
    }
  }
  false
}

///|
fn scan_identifiers_with_prefix(
  text : String,
  prefix : String,
) -> Map[String, Bool] {
  let chars = text.to_array()
  let prefix_chars = prefix.to_array()
  let names : Map[String, Bool] = Map([])
  let mut index = 0
  while index < chars.length() {
    match find_substring(chars, prefix_chars, index) {
      Some(found) => {
        let mut end = found + prefix_chars.length()
        while end < chars.length() && identifier_char(chars[end]) {
          end += 1
        }
        if end > found + prefix_chars.length() {
          names[chars_to_string(chars, found, end)] = true
        }
        index = end + 1
      }
      None => index = chars.length()
    }
  }
  names
}

///|
fn scan_static_void_finalizers(text : String) -> Map[String, Bool] {
  let chars = text.to_array()
  let prefix = "static void ".to_array()
  let names : Map[String, Bool] = Map([])
  let mut index = 0
  while index < chars.length() {
    match find_substring(chars, prefix, index) {
      Some(found) =>
        match read_identifier(chars, found + prefix.length()) {
          Some((name, after_name)) => {
            if name.has_prefix("moonbit_skia_") && name.has_suffix("_finalize") {
              names[name] = true
            }
            index = after_name + 1
          }
          None => index = found + prefix.length()
        }
      None => index = chars.length()
    }
  }
  names
}

///|
fn declared_handles(text : String) -> Map[String, Bool] {
  let handles : Map[String, Bool] = Map([])
  for line_view in text.split("\n") {
    let line = line_view.trim().to_owned()
    if line.has_prefix("priv type ") {
      let rest = line["priv type ".length():].trim().to_owned()
      let chars = rest.to_array()
      let mut end = 0
      while end < chars.length() && identifier_char(chars[end]) {
        end += 1
      }
      if end > 0 {
        handles[chars_to_string(chars, 0, end)] = true
      }
    }
  }
  handles
}

///|
fn sorted_missing(
  left : Map[String, Bool],
  right : Map[String, Bool],
) -> Array[String] {
  let missing : Map[String, Bool] = Map([])
  for key in left.keys() {
    if !right.contains(key) {
      missing[key] = true
    }
  }
  @tools.sorted_map_keys(missing)
}

///|
fn ensure_unique(
  values : Array[String],
  key : String,
  label : String,
) -> Result[Unit, String] {
  let seen : Map[String, Bool] = Map([])
  for value in values {
    if value == "" {
      return Err(label + " entry is missing " + key)
    }
    if seen.contains(value) {
      return Err("duplicate " + label + " " + key + ": " + value)
    }
    seen[value] = true
  }
  Ok(())
}

///|
fn require_contains(
  text : String,
  needle : String,
  message : String,
) -> Result[Unit, String] {
  if text.contains(needle) {
    Ok(())
  } else {
    Err(message)
  }
}

///|
fn require_assignment(
  text : String,
  field : String,
  message : String,
) -> Result[Unit, String] {
  if contains_assignment(text, field) {
    Ok(())
  } else {
    Err(message)
  }
}

///|
fn join_names(values : Array[String]) -> String {
  @tools.comma_join(values)
}

///|
fn collect_manifest_sets(
  manifest : OwnershipManifest,
) -> (
  Map[String, Bool],
  Map[String, Bool],
  Map[String, Bool],
  Map[String, Bool],
  Map[String, Bool],
) {
  let handles : Map[String, Bool] = Map([])
  let external_factories : Map[String, Bool] = Map([])
  let regular_factories : Map[String, Bool] = Map([])
  let finalizers : Map[String, Bool] = Map([])
  let all_factories : Map[String, Bool] = Map([])
  for entry in manifest.external_wrappers {
    handles[entry.moonbit_handle] = true
    external_factories[entry.factory] = true
    all_factories[entry.factory] = true
    finalizers[entry.finalizer] = true
  }
  for entry in manifest.regular_objects {
    match entry.moonbit_handle {
      Some(handle) => handles[handle] = true
      None => ()
    }
    regular_factories[entry.factory] = true
    all_factories[entry.factory] = true
  }
  for entry in manifest.regular_runtime_objects {
    regular_factories[entry.factory] = true
    all_factories[entry.factory] = true
  }
  (handles, external_factories, regular_factories, finalizers, all_factories)
}

///|
fn verify_unique_manifest_entries(
  manifest : OwnershipManifest,
) -> Result[Unit, String] {
  let names : Array[String] = []
  let wrapper_structs : Array[String] = []
  let moonbit_handles : Array[String] = []
  let moonbit_types : Array[String] = []
  let factories : Array[String] = []
  let finalizers : Array[String] = []
  for entry in manifest.external_wrappers {
    names.push(entry.name)
    wrapper_structs.push(entry.wrapper_struct)
    moonbit_handles.push(entry.moonbit_handle)
    moonbit_types.push(entry.moonbit_type)
    factories.push(entry.factory)
    finalizers.push(entry.finalizer)
  }
  for entry in manifest.regular_objects {
    names.push(entry.name)
    wrapper_structs.push(entry.wrapper_struct)
    match entry.moonbit_handle {
      Some(handle) => moonbit_handles.push(handle)
      None => ()
    }
    match entry.moonbit_type {
      Some(type_name) => moonbit_types.push(type_name)
      None => ()
    }
    factories.push(entry.factory)
  }
  for entry in manifest.regular_runtime_objects {
    names.push(entry.name)
    wrapper_structs.push(entry.wrapper_struct)
    factories.push(entry.factory)
  }
  match ensure_unique(names, "name", "native ownership") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match ensure_unique(wrapper_structs, "wrapper_struct", "native ownership") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match ensure_unique(moonbit_handles, "moonbit_handle", "native ownership") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match ensure_unique(moonbit_types, "moonbit_type", "native ownership") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match ensure_unique(factories, "factory", "native ownership") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match ensure_unique(finalizers, "finalizer", "external wrapper") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  Ok(())
}

///|
fn discovered_external_factories(source : String) -> Map[String, Bool] {
  let names = scan_identifiers_with_prefix(source, "moonbit_skia_make_")
  let result : Map[String, Bool] = Map([])
  for name in names.keys() {
    if name.has_suffix("_wrapper") {
      result[name] = true
    }
  }
  result
}

///|
fn discovered_regular_factories(source : String) -> Map[String, Bool] {
  let names = scan_identifiers_with_prefix(source, "moonbit_skia_make_")
  let result : Map[String, Bool] = Map([])
  for name in names.keys() {
    if !name.has_suffix("_wrapper") {
      match function_body(source, name, "regular object factory " + name) {
        Ok(body) if body.contains("moonbit_malloc") => result[name] = true
        _ => ()
      }
    }
  }
  result
}

///|
fn verify_set_matches(
  expected : Map[String, Bool],
  actual : Map[String, Bool],
  missing_message : String,
  extra_message : String,
) -> Result[Unit, String] {
  let missing = sorted_missing(expected, actual)
  if !missing.is_empty() {
    return Err(missing_message + join_names(missing))
  }
  let extra = sorted_missing(actual, expected)
  if !extra.is_empty() {
    return Err(extra_message + join_names(extra))
  }
  Ok(())
}

///|
fn verify_handles(
  manifest_handles : Map[String, Bool],
  handle_paths : Array[String],
) -> Result[Unit, String] {
  for path in handle_paths {
    let text = match
      @tools.read_required_text(path, "MoonBit native handle file") {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let declared = declared_handles(text)
    let missing = sorted_missing(manifest_handles, declared)
    if !missing.is_empty() {
      return Err(
        "ownership manifest references missing MoonBit handles in " +
        path +
        ": " +
        join_names(missing),
      )
    }
    let extra = sorted_missing(declared, manifest_handles)
    if !extra.is_empty() {
      return Err(
        "MoonBit handles in " +
        path +
        " are missing from ownership manifest: " +
        join_names(extra),
      )
    }
  }
  Ok(())
}

///|
fn verify_external_wrapper(
  entry : ExternalWrapper,
  inputs : OwnershipInputs,
) -> Result[Unit, String] {
  if !["owned_delete", "sk_refcnt", "borrowed_with_refcnt_owner"].contains(
      entry.ownership,
    ) {
    return Err(
      entry.name + " has unsupported ownership kind: " + entry.ownership,
    )
  }

  let type_body = match
    moonbit_type_body(inputs.types_text, entry.moonbit_type) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if !contains_priv_field(type_body, "handle", entry.moonbit_handle) {
    return Err(entry.moonbit_type + " does not store " + entry.moonbit_handle)
  }
  if entry.ownership == "borrowed_with_refcnt_owner" {
    let owner_field = match entry.moonbit_owner_field {
      Some(value) => value
      None =>
        return Err(
          entry.name +
          " borrowed owner contract is missing moonbit_owner_field/owner_type",
        )
    }
    let owner_type = match entry.owner_type {
      Some(value) => value
      None =>
        return Err(
          entry.name +
          " borrowed owner contract is missing moonbit_owner_field/owner_type",
        )
    }
    if !contains_priv_field(type_body, owner_field, owner_type + "?") {
      return Err(
        entry.moonbit_type +
        " does not retain optional owner " +
        owner_field +
        ": " +
        owner_type +
        "?",
      )
    }
  }

  let c_body = match
    struct_body(
      inputs.header_text,
      entry.wrapper_struct,
      "C++ wrapper struct " + entry.wrapper_struct,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if !contains_field_declaration(c_body, entry.field) {
    return Err(entry.wrapper_struct + " is missing field " + entry.field)
  }
  if entry.ownership == "borrowed_with_refcnt_owner" {
    let owner_field = match entry.owner_field {
      Some(value) => value
      None =>
        return Err(
          entry.name + " borrowed owner contract is missing owner_field",
        )
    }
    if !contains_field_declaration(c_body, owner_field) {
      return Err(
        entry.wrapper_struct + " is missing owner field " + owner_field,
      )
    }
  }

  let factory_body = match
    function_body(inputs.source_text, entry.factory, "factory " + entry.factory) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match
    require_contains(
      factory_body,
      "moonbit_make_external_object",
      entry.factory + " must allocate a MoonBit external object",
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    require_contains(
      factory_body,
      entry.finalizer,
      entry.factory + " does not register finalizer " + entry.finalizer,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    require_contains(
      factory_body,
      "sizeof(" + entry.wrapper_struct + ")",
      entry.factory + " does not allocate sizeof(" + entry.wrapper_struct + ")",
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    require_assignment(
      factory_body,
      entry.field,
      entry.factory + " does not initialize " + entry.field,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }

  let finalizer_body = match
    function_body(
      inputs.source_text,
      entry.finalizer,
      "finalizer " + entry.finalizer,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match
    require_contains(
      finalizer_body,
      "static_cast<" + entry.wrapper_struct + "*>",
      entry.finalizer + " does not cast to " + entry.wrapper_struct,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    require_contains(
      compact_whitespace(finalizer_body),
      "wrapper->" + entry.field + " = nullptr;",
      entry.finalizer + " does not clear " + entry.field,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }

  match entry.ownership {
    "owned_delete" =>
      require_contains(
        finalizer_body,
        "delete wrapper->" + entry.field + ";",
        entry.finalizer + " must delete owned " + entry.field,
      )
    "sk_refcnt" =>
      require_contains(
        finalizer_body,
        "wrapper->" + entry.field + "->unref();",
        entry.finalizer + " must unref " + entry.field,
      )
    "borrowed_with_refcnt_owner" => {
      let owner_field = match entry.owner_field {
        Some(value) => value
        None =>
          return Err(
            entry.name + " borrowed owner contract is missing owner_field",
          )
      }
      match
        require_contains(
          factory_body,
          "wrapper->" + owner_field + "->ref();",
          entry.factory + " must ref owner field " + owner_field,
        ) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
      match
        require_contains(
          finalizer_body,
          "wrapper->" + owner_field + "->unref();",
          entry.finalizer + " must unref owner field " + owner_field,
        ) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
      match
        require_contains(
          compact_whitespace(finalizer_body),
          "wrapper->" + owner_field + " = nullptr;",
          entry.finalizer + " does not clear owner field " + owner_field,
        ) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
      if finalizer_body.contains("delete wrapper->" + entry.field + ";") {
        return Err(
          entry.finalizer + " must not delete borrowed field " + entry.field,
        )
      }
      Ok(())
    }
    _ => Ok(())
  }
}

///|
fn arrays_equal(left : Array[String], right : Array[String]) -> Bool {
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
fn verify_regular_object(
  entry : RegularObject,
  inputs : OwnershipInputs,
  require_moonbit_wrapper : Bool,
) -> Result[Unit, String] {
  if entry.allocation != "moonbit_malloc" {
    return Err(
      entry.name +
      " regular object uses unsupported allocation: " +
      entry.allocation,
    )
  }
  if entry.pointer_fields.length() != entry.pointer_field_count {
    return Err(
      entry.name +
      " regular object pointer_fields length does not match pointer_field_count=" +
      entry.pointer_field_count.to_string(),
    )
  }
  if require_moonbit_wrapper {
    let handle = match entry.moonbit_handle {
      Some(value) => value
      None =>
        return Err(
          entry.name + " regular object is missing MoonBit handle/type",
        )
    }
    let type_name = match entry.moonbit_type {
      Some(value) => value
      None =>
        return Err(
          entry.name + " regular object is missing MoonBit handle/type",
        )
    }
    let type_body = match moonbit_type_body(inputs.types_text, type_name) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    if !contains_priv_field(type_body, "handle", handle) {
      return Err(type_name + " does not store " + handle)
    }
  }

  let c_body = match
    struct_body(
      inputs.header_text,
      entry.wrapper_struct,
      "C++ wrapper struct " + entry.wrapper_struct,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let actual_pointer_fields = pointer_field_names(c_body)
  if actual_pointer_fields.length() != entry.pointer_field_count {
    return Err(
      entry.name +
      " regular object pointer_field_count mismatch: manifest=" +
      entry.pointer_field_count.to_string() +
      " struct=" +
      actual_pointer_fields.length().to_string(),
    )
  }
  if !arrays_equal(actual_pointer_fields, entry.pointer_fields) {
    return Err(
      entry.name +
      " regular object pointer_fields mismatch: manifest=" +
      join_names(entry.pointer_fields) +
      " struct=" +
      join_names(actual_pointer_fields),
    )
  }
  for field in entry.value_fields {
    if !contains_field_declaration(c_body, field) {
      return Err(entry.wrapper_struct + " is missing value field " + field)
    }
  }

  let factory_body = match
    function_body(
      inputs.source_text,
      entry.factory,
      "regular object factory " + entry.factory,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match
    require_contains(
      factory_body,
      "moonbit_malloc",
      entry.factory + " must use moonbit_malloc",
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    require_contains(
      factory_body,
      "moonbit_skia_regular_object_header",
      entry.factory + " must initialize a regular object header",
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  if !compact_whitespace(factory_body).contains(
      ", " + entry.pointer_field_count.to_string() + ", 0",
    ) {
    return Err(
      entry.factory +
      " must encode pointer_field_count=" +
      entry.pointer_field_count.to_string() +
      " in its object header",
    )
  }
  if entry.pointer_field_count > 0 {
    let first_pointer_field = entry.pointer_fields[0]
    match
      require_contains(
        factory_body,
        "offsetof(" + entry.wrapper_struct + ", " + first_pointer_field + ")",
        entry.factory +
        " must encode pointer-field offset with offsetof(" +
        entry.wrapper_struct +
        ", " +
        first_pointer_field +
        ")",
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  } else {
    match
      require_contains(
        factory_body,
        "sizeof(" + entry.wrapper_struct + ") >> 2",
        entry.factory +
        " must encode scalar-only header size with sizeof(" +
        entry.wrapper_struct +
        ") >> 2",
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  for field in entry.pointer_fields {
    match
      require_assignment(
        factory_body,
        field,
        entry.factory + " must initialize field " + field,
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  for field in entry.value_fields {
    match
      require_assignment(
        factory_body,
        field,
        entry.factory + " must initialize field " + field,
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  if factory_body.contains("moonbit_make_external_object") {
    return Err(entry.factory + " must not allocate a MoonBit external object")
  }
  let finalizer_name = entry.factory
    .replace(old="make_", new="")
    .replace(old="_run", new="_run_finalize")
  if inputs.source_text.contains(finalizer_name) {
    return Err(
      entry.name +
      " regular object unexpectedly has a finalizer: " +
      finalizer_name,
    )
  }
  Ok(())
}

///|
fn verify_manifest(
  manifest : OwnershipManifest,
  inputs : OwnershipInputs,
) -> Result[Unit, String] {
  match verify_unique_manifest_entries(manifest) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let (
    manifest_handles,
    expected_external_factories,
    expected_regular_factories,
    expected_finalizers,
    _,
  ) = collect_manifest_sets(manifest)

  match verify_handles(manifest_handles, inputs.handle_paths) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    verify_set_matches(
      expected_external_factories,
      discovered_external_factories(inputs.source_text),
      "ownership manifest references missing external wrapper factories: ",
      "external wrapper factories are missing from ownership manifest: ",
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    verify_set_matches(
      expected_regular_factories,
      discovered_regular_factories(inputs.source_text),
      "ownership manifest references missing regular object factories: ",
      "moonbit_malloc regular object factories are missing from ownership manifest: ",
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    verify_set_matches(
      expected_finalizers,
      scan_static_void_finalizers(inputs.source_text),
      "ownership manifest references missing finalizers: ",
      "native finalizers are missing from ownership manifest: ",
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }

  for entry in manifest.external_wrappers {
    match verify_external_wrapper(entry, inputs) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  for entry in manifest.regular_objects {
    match verify_regular_object(entry, inputs, true) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  for entry in manifest.regular_runtime_objects {
    match verify_regular_object(entry, inputs, false) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  Ok(())
}

///|
fn manifest_string_array_field(
  manifest_root : Map[String, Json],
  key : String,
) -> Result[Array[String], String] {
  match manifest_root.get(key) {
    Some(Json::Array(values)) if !values.is_empty() => {
      let paths : Array[String] = []
      for value in values {
        match value {
          Json::String(path) if path.trim().to_owned() != "" =>
            paths.push(path.trim().to_owned())
          _ => return Err("native ownership manifest is missing " + key)
        }
      }
      Ok(paths)
    }
    _ => Err("native ownership manifest is missing " + key)
  }
}

///|
fn load_inputs(
  options : CliOptions,
) -> Result[(OwnershipManifest, OwnershipInputs), String] {
  let manifest_path = @tools.resolve_path(options.repo_root, options.manifest)
  let manifest_text = match
    @tools.read_required_text(manifest_path, "native ownership manifest") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let parsed = @json.parse(manifest_text) catch {
    _ => return Err("native ownership manifest JSON is invalid")
  }
  let root = match json_object(parsed, "native ownership manifest") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let manifest = match parse_manifest(manifest_text) {
    Ok(value) => value
    Err(message) => return Err(message)
  }

  let header_path = if options.header != "" {
    @tools.resolve_path(options.repo_root, options.header)
  } else {
    @tools.resolve_path(
      options.repo_root,
      json_string_field(root, "native_header"),
    )
  }
  let source_path = if options.source != "" {
    @tools.resolve_path(options.repo_root, options.source)
  } else {
    @tools.resolve_path(
      options.repo_root,
      json_string_field(root, "native_source"),
    )
  }
  let handle_paths = if options.handles != "" {
    [@tools.resolve_path(options.repo_root, options.handles)]
  } else {
    let handle_files = match
      manifest_string_array_field(root, "moonbit_handle_files") {
      Ok(value) => value
      Err(_) =>
        match json_string_field(root, "moonbit_handle_file") {
          "" =>
            return Err(
              "native ownership manifest is missing moonbit_handle_files",
            )
          path => [path]
        }
    }
    handle_files.map(path => @tools.resolve_path(options.repo_root, path))
  }
  let types_path = if options.types != "" {
    @tools.resolve_path(options.repo_root, options.types)
  } else {
    @tools.resolve_path(
      options.repo_root,
      json_string_field(root, "moonbit_type_file"),
    )
  }

  let header_text = match
    @tools.read_required_text(header_path, "native ownership header") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let source_text = match
    @tools.read_required_text(source_path, "native ownership source") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let types_text = match
    @tools.read_required_text(types_path, "MoonBit native type file") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(
    (
      manifest,
      { manifest_path, handle_paths, header_text, source_text, types_text },
    ),
  )
}

///|
fn verify_native_ownership(options : CliOptions) -> Result[String, String] {
  let (manifest, inputs) = match load_inputs(options) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match verify_manifest(manifest, inputs) {
    Ok(_) => Ok("Verified native ownership manifest: " + inputs.manifest_path)
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
      match verify_native_ownership(options) {
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
