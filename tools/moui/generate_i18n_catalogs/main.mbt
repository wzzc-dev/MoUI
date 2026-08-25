///|
struct CatalogMessage {
  key : String
  one : String?
  other : String?
}

///|
struct SourceCatalog {
  locale : String
  path : String
  messages : Array[CatalogMessage]
}

///|
struct CatalogManifest {
  path : String
  catalogs : Array[String]
}

///|
struct CliOptions {
  input : String
  display_input : String
  out : String
  check : Bool
  help : Bool
}

///|
fn usage() -> String {
  (
    #|Usage: tools/moui/generate_i18n_catalogs --input <manifest.json> [--display-input <path>] --out <generated.mbt> [--check]
    #|
    #|Manifest schema (schemaVersion 1):
    #|{
    #|  "schemaVersion": 1,
    #|  "catalogs": ["en-US.json", "zh-Hans.json"]
    #|}
    #|
    #|Catalog paths are relative to the manifest. Each <locale>.json catalog is:
    #|{
    #|  "locale": "en-US",
    #|  "messages": {
    #|    "message.key": "Text with {name}",
    #|    "item.count": { "one": "{count} item", "other": "{count} items" }
    #|  }
    #|}
    #|
    #|A plural message must contain exactly string `one` and `other` forms.
    #|
  )
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let mut input = ""
  let mut display_input = ""
  let mut out = ""
  let mut check = false
  let mut help = false
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "-h" | "--help" => {
        help = true
        index += 1
      }
      "--input" => {
        if index + 1 >= args.length() {
          return Err("missing value for --input")
        }
        input = args[index + 1]
        index += 2
      }
      "--display-input" => {
        if index + 1 >= args.length() {
          return Err("missing value for --display-input")
        }
        display_input = args[index + 1]
        index += 2
      }
      "--out" => {
        if index + 1 >= args.length() {
          return Err("missing value for --out")
        }
        out = args[index + 1]
        index += 2
      }
      "--check" => {
        check = true
        index += 1
      }
      value => return Err("unknown argument: " + value)
    }
  }
  Ok({ input, display_input, out, check, help })
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
fn json_string(value : Json?, label : String) -> Result[String, String] {
  match value {
    Some(Json::String(text)) if text.trim().to_owned() != "" => Ok(text)
    _ => Err(label + " must be a non-empty string")
  }
}

///|
fn json_array(value : Json?, label : String) -> Result[Array[Json], String] {
  match value {
    Some(Json::Array(items)) => Ok(items)
    _ => Err(label + " must be an array")
  }
}

///|
fn json_schema_version(value : Json?, label : String) -> Result[Unit, String] {
  match value {
    Some(Json::Number(number, repr=_)) if number == 1.0 => Ok(())
    _ => Err(label + " must be 1")
  }
}

///|
fn parent_dir(path : String) -> String {
  let normalized = path.replace_all(old="\\", new="/")
  match normalized.rev_find("/") {
    None => "."
    Some(0) => "/"
    Some(index) => normalized[:index].to_owned()
  }
}

///|
fn source_basename(path : String) -> String {
  let normalized = path.replace_all(old="\\", new="/")
  match normalized.rev_find("/") {
    Some(index) => normalized[index + 1:].to_owned()
    None => normalized
  }
}

///|
fn source_locale(path : String) -> String? {
  let name = source_basename(path)
  if !name.has_suffix(".json") || name.length() == 5 {
    None
  } else {
    Some(name[:name.length() - 5].to_owned())
  }
}

///|
fn valid_locale_tag(locale : String) -> Bool {
  if locale == "" || locale.has_prefix("-") || locale.has_suffix("-") {
    return false
  }
  let parts = locale.split("-").collect()
  if parts.is_empty() {
    return false
  }
  let language = parts[0].to_owned()
  if language.length() < 2 ||
    language.length() > 3 ||
    !language.all(char => char.is_ascii_alphabetic()) {
    return false
  }
  for index in 1..<parts.length() {
    let part = parts[index].to_owned()
    if part.length() == 4 {
      if !part.all(char => char.is_ascii_alphabetic()) {
        return false
      }
    } else if part.length() == 2 {
      if !part.all(char => char.is_ascii_alphabetic()) {
        return false
      }
    } else if part.length() == 3 {
      if !part.all(char => char.is_ascii_digit()) {
        return false
      }
    } else {
      return false
    }
  }
  true
}

///|
fn valid_message_key(key : String) -> Bool {
  if key == "" || key.has_prefix(".") || key.has_suffix(".") {
    return false
  }
  let mut previous_dot = false
  for char in key {
    if char == '.' {
      if previous_dot {
        return false
      }
      previous_dot = true
    } else if char.is_ascii_alphabetic() ||
      char.is_ascii_digit() ||
      char == '_' ||
      char == '-' {
      previous_dot = false
    } else {
      return false
    }
  }
  true
}

///|
struct JsonKeyScanner {
  chars : Array[Char]
  mut cursor : Int
}

///|
fn json_scan_whitespace(scanner : JsonKeyScanner) -> Unit {
  while scanner.cursor < scanner.chars.length() {
    match scanner.chars[scanner.cursor] {
      ' ' | '\n' | '\r' | '\t' => scanner.cursor += 1
      _ => return
    }
  }
}

///|
fn hex_value(char : Char) -> Int {
  match char {
    '0'..='9' => char.to_int() - '0'.to_int()
    'a'..='f' => char.to_int() - 'a'.to_int() + 10
    'A'..='F' => char.to_int() - 'A'.to_int() + 10
    _ => 0
  }
}

///|
fn json_scan_string(scanner : JsonKeyScanner) -> String? {
  if scanner.cursor >= scanner.chars.length() ||
    scanner.chars[scanner.cursor] != '"' {
    return None
  }
  scanner.cursor += 1
  let raw = StringBuilder()
  while scanner.cursor < scanner.chars.length() {
    let char = scanner.chars[scanner.cursor]
    scanner.cursor += 1
    if char == '"' {
      return Some(raw.to_string())
    }
    if char == '"' {
      return Some(raw.to_string())
    }
    if char != '\\' {
      raw.write_char(char)
      continue
    }
    if scanner.cursor >= scanner.chars.length() {
      return None
    }
    let escaped = scanner.chars[scanner.cursor]
    scanner.cursor += 1
    match escaped {
      '"' => raw.write_char('"')
      '\\' => raw.write_char('\\')
      '/' => raw.write_char('/')
      'b' => raw.write_char('\b')
      'f' => raw.write_char('\f')
      'n' => raw.write_char('\n')
      'r' => raw.write_char('\r')
      't' => raw.write_char('\t')
      'u' => {
        let mut value = 0
        let mut count = 0
        while count < 4 && scanner.cursor < scanner.chars.length() {
          value = value * 16 + hex_value(scanner.chars[scanner.cursor])
          scanner.cursor += 1
          count += 1
        }
        if count != 4 {
          return None
        }
        raw.write_char(value.unsafe_to_char())
      }
      _ => return None
    }
  }
  None
}

///|
fn json_scan_literal(scanner : JsonKeyScanner) -> Unit {
  while scanner.cursor < scanner.chars.length() {
    match scanner.chars[scanner.cursor] {
      ' ' | '\n' | '\r' | '\t' | ',' | ']' | '}' => return
      _ => scanner.cursor += 1
    }
  }
}

///|
fn scan_json_value_for_duplicate_keys(
  scanner : JsonKeyScanner,
  label : String,
) -> Result[Unit, String] {
  json_scan_whitespace(scanner)
  if scanner.cursor >= scanner.chars.length() {
    return Ok(())
  }
  match scanner.chars[scanner.cursor] {
    '"' => {
      ignore(json_scan_string(scanner))
      Ok(())
    }
    '{' => scan_json_object_for_duplicate_keys(scanner, label)
    '[' => scan_json_array_for_duplicate_keys(scanner, label)
    _ => {
      json_scan_literal(scanner)
      Ok(())
    }
  }
}

///|
fn scan_json_object_for_duplicate_keys(
  scanner : JsonKeyScanner,
  label : String,
) -> Result[Unit, String] {
  scanner.cursor += 1
  json_scan_whitespace(scanner)
  if scanner.cursor < scanner.chars.length() &&
    scanner.chars[scanner.cursor] == '}' {
    scanner.cursor += 1
    return Ok(())
  }
  let keys : Array[String] = []
  while scanner.cursor < scanner.chars.length() {
    json_scan_whitespace(scanner)
    let key = match json_scan_string(scanner) {
      Some(value) => value
      None => return Ok(())
    }
    if keys.any(existing => existing == key) {
      return Err(label + " contains duplicate JSON object key: " + key)
    }
    keys.push(key)
    json_scan_whitespace(scanner)
    if scanner.cursor >= scanner.chars.length() ||
      scanner.chars[scanner.cursor] != ':' {
      return Ok(())
    }
    scanner.cursor += 1
    match scan_json_value_for_duplicate_keys(scanner, label) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    json_scan_whitespace(scanner)
    if scanner.cursor >= scanner.chars.length() {
      return Ok(())
    }
    if scanner.chars[scanner.cursor] == '}' {
      scanner.cursor += 1
      return Ok(())
    }
    if scanner.chars[scanner.cursor] != ',' {
      return Ok(())
    }
    scanner.cursor += 1
  }
  Ok(())
}

///|
fn scan_json_array_for_duplicate_keys(
  scanner : JsonKeyScanner,
  label : String,
) -> Result[Unit, String] {
  scanner.cursor += 1
  json_scan_whitespace(scanner)
  if scanner.cursor < scanner.chars.length() &&
    scanner.chars[scanner.cursor] == ']' {
    scanner.cursor += 1
    return Ok(())
  }
  while scanner.cursor < scanner.chars.length() {
    match scan_json_value_for_duplicate_keys(scanner, label) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    json_scan_whitespace(scanner)
    if scanner.cursor >= scanner.chars.length() {
      return Ok(())
    }
    if scanner.chars[scanner.cursor] == ']' {
      scanner.cursor += 1
      return Ok(())
    }
    if scanner.chars[scanner.cursor] != ',' {
      return Ok(())
    }
    scanner.cursor += 1
  }
  Ok(())
}

///|
fn reject_duplicate_json_keys(
  text : String,
  label : String,
) -> Result[Unit, String] {
  let scanner = { chars: text.to_array(), cursor: 0 }
  scan_json_value_for_duplicate_keys(scanner, label)
}

///|
fn parse_manifest(
  path : String,
  text : String,
) -> Result[CatalogManifest, String] {
  match reject_duplicate_json_keys(text, path) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let parsed = @json.parse(text) catch {
    _ => return Err(path + " contains invalid JSON")
  }
  let root = match json_object(parsed, path) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match
    json_schema_version(root.get("schemaVersion"), path + ".schemaVersion") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let items = match json_array(root.get("catalogs"), path + ".catalogs") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if items.is_empty() {
    return Err(path + ".catalogs must not be empty")
  }
  let catalog_paths : Array[String] = []
  for index, item in items {
    let label = path + ".catalogs[\{index}]"
    let raw = match item {
      Json::String(value) if value.trim().to_owned() != "" => value
      _ => return Err(label + " must be a non-empty string")
    }
    let resolved = @tools.resolve_path(parent_dir(path), raw)
    if catalog_paths.any(existing => existing == resolved) {
      return Err(label + " duplicates catalog path: " + raw)
    }
    catalog_paths.push(resolved)
  }
  catalog_paths.sort_by((left, right) => left.lexical_compare(right))
  Ok({ path, catalogs: catalog_paths })
}

///|
fn validate_plural_forms(
  fields : Map[String, Json],
  label : String,
) -> Result[CatalogMessage, String] {
  if fields.length() != 2 ||
    !fields.contains("one") ||
    !fields.contains("other") {
    return Err(
      label + " plural messages must contain exactly string one and other forms",
    )
  }
  let one = match json_string(fields.get("one"), label + ".one") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let other = match json_string(fields.get("other"), label + ".other") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ key: "", one: Some(one), other: Some(other) })
}

///|
fn parse_catalog(path : String, text : String) -> Result[SourceCatalog, String] {
  match reject_duplicate_json_keys(text, path) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let parsed = @json.parse(text) catch {
    _ => return Err(path + " contains invalid JSON")
  }
  let root = match json_object(parsed, path) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let locale = match json_string(root.get("locale"), path + ".locale") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if !valid_locale_tag(locale) {
    return Err(path + ".locale is not a valid locale tag: " + locale)
  }
  match source_locale(path) {
    Some(file_locale) if file_locale == locale => ()
    Some(file_locale) =>
      return Err(
        path +
        ".locale " +
        locale +
        " does not match filename locale " +
        file_locale,
      )
    None => return Err(path + " must be named <locale>.json")
  }
  let message_value = match root.get("messages") {
    Some(value) => value
    None => return Err(path + ".messages must be an object")
  }
  let fields = match json_object(message_value, path + ".messages") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if fields.is_empty() {
    return Err(path + ".messages must not be empty")
  }
  let messages : Array[CatalogMessage] = []
  for key in @tools.sorted_map_keys(fields) {
    if !valid_message_key(key) {
      return Err(path + ".messages has invalid key: " + key)
    }
    let value = fields[key]
    let message = match value {
      Json::String(text) => {
        if text == "" {
          return Err(path + ".messages." + key + " must not be empty")
        }
        { key, one: Some(text), other: None }
      }
      Json::Object(plural) => {
        let parsed_plural = match
          validate_plural_forms(plural, path + ".messages." + key) {
          Ok(value) => value
          Err(message) => return Err(message)
        }
        { key, one: parsed_plural.one, other: parsed_plural.other }
      }
      _ =>
        return Err(
          path + ".messages." + key + " must be a string or plural object",
        )
    }
    messages.push(message)
  }
  Ok({ locale, path, messages })
}

///|
fn placeholders_in(
  text : String,
  label : String,
) -> Result[Array[String], String] {
  let names : Array[String] = []
  let chars = text.to_array()
  let mut index = 0
  while index < chars.length() {
    if chars[index] == '{' {
      let start = index + 1
      let mut end = start
      while end < chars.length() && chars[end] != '}' {
        if chars[end] == '{' {
          return Err(label + " has a nested { in placeholder")
        }
        end += 1
      }
      if end == chars.length() {
        return Err(label + " has an unclosed placeholder")
      }
      if end == start {
        return Err(label + " has an empty placeholder")
      }
      let name = String::from_array(chars[start:end])
      if !valid_placeholder_name(name) {
        return Err(label + " has an invalid placeholder: {" + name + "}")
      }
      if !names.any(existing => existing == name) {
        names.push(name)
      }
      index = end + 1
    } else if chars[index] == '}' {
      return Err(label + " has an unmatched }")
    } else {
      index += 1
    }
  }
  names.sort_by((left, right) => left.lexical_compare(right))
  Ok(names)
}

///|
fn valid_placeholder_name(name : String) -> Bool {
  if name == "" {
    return false
  }
  for char in name {
    if !(char.is_ascii_alphabetic() || char.is_ascii_digit() || char == '_') {
      return false
    }
  }
  true
}

///|
fn message_placeholders(
  message : CatalogMessage,
  label : String,
) -> Result[Array[String], String] {
  let names = match message.one {
    Some(text) =>
      match placeholders_in(text, label) {
        Ok(value) => value
        Err(message) => return Err(message)
      }
    None => []
  }
  match message.other {
    None => Ok(names)
    Some(text) => {
      let other_names = match placeholders_in(text, label + ".other") {
        Ok(value) => value
        Err(message) => return Err(message)
      }
      if names != other_names {
        return Err(
          label + " plural one and other forms must use the same placeholders",
        )
      }
      Ok(names)
    }
  }
}

///|
fn exact_keys(catalog : SourceCatalog) -> Array[String] {
  catalog.messages.map(message => message.key)
}

///|
fn message_for(catalog : SourceCatalog, key : String) -> CatalogMessage? {
  for message in catalog.messages {
    if message.key == key {
      return Some(message)
    }
  }
  None
}

///|
fn validate_catalogs(catalogs : Array[SourceCatalog]) -> Result[Unit, String] {
  if catalogs.is_empty() {
    return Err("manifest must list at least one catalog")
  }
  let mut index = 0
  while index < catalogs.length() {
    let catalog = catalogs[index]
    if index > 0 && catalogs[index - 1].locale == catalog.locale {
      return Err(catalog.path + " duplicates locale: " + catalog.locale)
    }
    for message in catalog.messages {
      let label = catalog.path + ".messages." + message.key
      match message_placeholders(message, label) {
        Ok(_) => ()
        Err(error) => return Err(error)
      }
    }
    index += 1
  }
  let reference = catalogs[0]
  let reference_keys = exact_keys(reference)
  for catalog in catalogs[1:] {
    let keys = exact_keys(catalog)
    if keys != reference_keys {
      let mut missing = ""
      let mut extra = ""
      for key in reference_keys {
        if !keys.any(candidate => candidate == key) {
          missing = key
          break
        }
      }
      for key in keys {
        if !reference_keys.any(candidate => candidate == key) {
          extra = key
          break
        }
      }
      if missing != "" {
        return Err(catalog.path + " is missing message key: " + missing)
      }
      return Err(catalog.path + " has unexpected message key: " + extra)
    }
    for key in reference_keys {
      let reference_message = match message_for(reference, key) {
        Some(value) => value
        None => return Err("internal error: reference key is missing")
      }
      let candidate_message = match message_for(catalog, key) {
        Some(value) => value
        None => return Err("internal error: candidate key is missing")
      }
      let expected = match
        message_placeholders(
          reference_message,
          reference.path + ".messages." + key,
        ) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      let actual = match
        message_placeholders(
          candidate_message,
          catalog.path + ".messages." + key,
        ) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      if expected != actual {
        return Err(
          catalog.path +
          ".messages." +
          key +
          " placeholder set differs from " +
          reference.path,
        )
      }
    }
  }
  Ok(())
}

///|
fn moon_string(text : String) -> String {
  let builder = StringBuilder()
  for char in text {
    match char {
      '"' => builder.write_string("\\\"")
      '\\' => builder.write_string("\\\\")
      '\n' => builder.write_string("\\n")
      '\r' => builder.write_string("\\r")
      '\t' => builder.write_string("\\t")
      value if value.is_control() => {
        builder.write_string("\\u{")
        builder.write_string(to_hex_upper(value.to_int()))
        builder.write_char('}')
      }
      value => builder.write_char(value)
    }
  }
  builder.to_string()
}

///|
fn to_hex_upper(value : Int) -> String {
  if value == 0 {
    return "0"
  }
  let digits : Array[Char] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F',
  ]
  let reversed : Array[Char] = []
  let mut number = value
  while number > 0 {
    reversed.push(digits[number % 16])
    number = number / 16
  }
  let ordered : Array[Char] = []
  for index = reversed.length() - 1; index >= 0; index = index - 1 {
    ordered.push(reversed[index])
  }
  String::from_array(ordered)
}

///|
fn source_provenance(manifest : CatalogManifest) -> String {
  manifest.catalogs.join(", ")
}

///|
fn generated_text_entry(key : String, text : String) -> Array[String] {
  let key_source = moon_string(key)
  let text_source = moon_string(text)
  let single = "      (\"" +
    key_source +
    "\", GeneratedI18nMessage::Text(\"" +
    text_source +
    "\")),"
  if single.length() <= 81 {
    [single]
  } else if text_source.length() <= 46 {
    [
      "      (",
      "        \"" + key_source + "\",",
      "        GeneratedI18nMessage::Text(\"" + text_source + "\"),",
      "      ),",
    ]
  } else {
    [
      "      (",
      "        \"" + key_source + "\",",
      "        GeneratedI18nMessage::Text(",
      "          \"" + text_source + "\",",
      "        ),",
      "      ),",
    ]
  }
}

///|
fn generated_plural_entry(
  key : String,
  one : String,
  other : String,
) -> Array[String] {
  let key_source = moon_string(key)
  let one_source = moon_string(one)
  let other_source = moon_string(other)
  let single = "      (\"" +
    key_source +
    "\", GeneratedI18nMessage::Plural(one=\"" +
    one_source +
    "\", other=\"" +
    other_source +
    "\")),"
  if single.length() <= 81 {
    [single]
  } else {
    [
      "      (",
      "        \"" + key_source + "\",",
      "        GeneratedI18nMessage::Plural(",
      "          one=\"" + one_source + "\",",
      "          other=\"" + other_source + "\",",
      "        ),",
      "      ),",
    ]
  }
}

///|
fn generate_catalog_source(
  manifest : CatalogManifest,
  catalogs : Array[SourceCatalog],
) -> String {
  let lines : Array[String] = []
  lines.push(
    "///| Generated by scripts/generate-i18n-catalogs.mjs; DO NOT EDIT.",
  )
  lines.push("")
  lines.push(
    "///| Provenance: manifest=" +
    manifest.path +
    "; catalogs=" +
    source_provenance(manifest) +
    ".",
  )
  lines.push("")
  lines.push("///|")
  lines.push("pub(all) enum GeneratedI18nMessage {")
  lines.push("  Text(String)")
  lines.push("  Plural(one~ : String, other~ : String)")
  lines.push("}")
  lines.push("")
  lines.push("///|")
  lines.push("pub(all) struct GeneratedI18nCatalog {")
  lines.push("  locale : String")
  lines.push("  messages : Array[(String, GeneratedI18nMessage)]")
  lines.push("}")
  lines.push("")
  lines.push("///|")
  lines.push(
    "pub let generated_i18n_catalogs : Array[GeneratedI18nCatalog] = [",
  )
  for catalog in catalogs {
    lines.push("  {")
    lines.push("    locale: \"" + moon_string(catalog.locale) + "\",")
    lines.push("    messages: [")
    for message in catalog.messages {
      match message.other {
        None =>
          match message.one {
            Some(text) =>
              for line in generated_text_entry(message.key, text) {
                lines.push(line)
              }
            None => ()
          }
        Some(other) =>
          match message.one {
            Some(one) =>
              for line in generated_plural_entry(message.key, one, other) {
                lines.push(line)
              }
            None => ()
          }
      }
    }
    lines.push("    ],")
    lines.push("  },")
  }
  lines.push("]")
  lines.join("\n") + "\n"
}

///|
fn generate_from_files(
  input : String,
  display_input : String,
) -> Result[String, String] {
  let manifest_text = match @tools.read_required_text(input, input) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let manifest = match parse_manifest(input, manifest_text) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let display_manifest = match parse_manifest(display_input, manifest_text) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let catalogs : Array[SourceCatalog] = []
  for index, path in manifest.catalogs {
    let text = match @tools.read_required_text(path, path) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    let catalog = match parse_catalog(display_manifest.catalogs[index], text) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
    catalogs.push(catalog)
  }
  catalogs.sort_by((left, right) => left.locale.lexical_compare(right.locale))
  match validate_catalogs(catalogs) {
    Ok(_) => Ok(generate_catalog_source(display_manifest, catalogs))
    Err(message) => Err(message)
  }
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
  if options.input == "" || options.out == "" {
    println(usage())
    return 2
  }
  let display_input = if options.display_input == "" {
    options.input
  } else {
    options.display_input
  }
  let generated = match generate_from_files(options.input, display_input) {
    Ok(value) => value
    Err(message) => {
      println(message)
      return 1
    }
  }
  if options.check {
    match @tools.read_required_text(options.out, options.out) {
      Ok(current) =>
        if current == generated {
          println(options.out + ": ok")
          0
        } else {
          println(
            options.out + ": generated i18n catalog source is out of date",
          )
          1
        }
      Err(message) => {
        println(message)
        1
      }
    }
  } else {
    match @tools.write_text_file(options.out, generated, options.out) {
      Ok(_) => {
        println("wrote " + options.out)
        0
      }
      Err(message) => {
        println(message)
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
