///|
struct CliOptions {
  manifest_path : String
  display_path : String
  expected_platform : String
  help : Bool
}

///|
fn usage() -> String {
  "Usage: tools/moui/validate_package_manifest <moui-package.json> [--platform macos|windows]"
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let manifest_path = Ref("")
  let display_path = Ref("")
  let expected_platform = Ref("")
  let help = Ref(false)
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--platform" => {
        if index + 1 >= args.length() {
          return Err("missing value for --platform")
        }
        expected_platform.val = args[index + 1]
        index += 2
      }
      "--display-path" => {
        if index + 1 >= args.length() {
          return Err("missing value for --display-path")
        }
        display_path.val = args[index + 1]
        index += 2
      }
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      value => {
        if value.has_prefix("-") {
          return Err("Unknown argument: " + value)
        }
        if manifest_path.val != "" {
          return Err("unexpected argument: " + value)
        }
        manifest_path.val = value
        index += 1
      }
    }
  }
  if !help.val && manifest_path.val == "" {
    return Err("missing moui-package.json path")
  }
  let display = if display_path.val == "" {
    manifest_path.val
  } else {
    display_path.val
  }
  Ok({
    manifest_path: manifest_path.val,
    display_path: display,
    expected_platform: expected_platform.val,
    help: help.val,
  })
}

///|
fn json_object(value : Json) -> Map[String, Json]? {
  match value {
    Json::Object(fields) => Some(fields)
    _ => None
  }
}

///|
fn json_number_is_one(value : Json?) -> Bool {
  match value {
    Some(Json::Number(number, repr=_)) => number == 1.0
    _ => false
  }
}

///|
fn json_string_field(fields : Map[String, Json], key : String) -> String? {
  match fields.get(key) {
    Some(Json::String(value)) if value.trim().to_owned() != "" => Some(value)
    _ => None
  }
}

///|
fn require_string(
  fields : Map[String, Json],
  field : String,
  failures : Array[String],
) -> String {
  match json_string_field(fields, field) {
    Some(value) => value
    None => {
      failures.push("missing non-empty string field '" + field + "'")
      ""
    }
  }
}

///|
fn ascii_lower_char(char : Char) -> Char {
  match char {
    'A' => 'a'
    'B' => 'b'
    'C' => 'c'
    'D' => 'd'
    'E' => 'e'
    'F' => 'f'
    'G' => 'g'
    'H' => 'h'
    'I' => 'i'
    'J' => 'j'
    'K' => 'k'
    'L' => 'l'
    'M' => 'm'
    'N' => 'n'
    'O' => 'o'
    'P' => 'p'
    'Q' => 'q'
    'R' => 'r'
    'S' => 's'
    'T' => 't'
    'U' => 'u'
    'V' => 'v'
    'W' => 'w'
    'X' => 'x'
    'Y' => 'y'
    'Z' => 'z'
    _ => char
  }
}

///|
fn ascii_lower(value : String) -> String {
  let builder = StringBuilder()
  for char in value {
    builder.write_char(ascii_lower_char(char))
  }
  builder.to_string()
}

///|
fn validate_manifest_fields(
  manifest : Map[String, Json],
  expected_platform : String,
) -> Array[String] {
  let failures : Array[String] = []
  if !json_number_is_one(manifest.get("schemaVersion")) {
    failures.push("schemaVersion must be 1")
  }
  let platform = require_string(manifest, "platform", failures)
  if expected_platform != "" && platform != expected_platform {
    failures.push("platform must be '" + expected_platform + "'")
  }
  let output_kind = require_string(manifest, "outputKind", failures)
  ignore(require_string(manifest, "appName", failures))
  ignore(require_string(manifest, "moonPackage", failures))
  ignore(require_string(manifest, "version", failures))
  ignore(require_string(manifest, "buildNumber", failures))
  let executable = require_string(manifest, "executable", failures)
  let bundle_name = require_string(manifest, "bundleName", failures)
  match manifest.get("runtimeFiles") {
    Some(Json::Array(_)) => ()
    _ => failures.push("runtimeFiles must be an array")
  }
  match manifest.get("externalRuntimeDependencies") {
    Some(Json::Array(_)) | None => ()
    _ => failures.push("externalRuntimeDependencies must be an array")
  }
  if platform == "macos" {
    if output_kind != "app-bundle" {
      failures.push("macOS outputKind must be 'app-bundle'")
    }
    ignore(require_string(manifest, "bundleIdentifier", failures))
    if !bundle_name.has_suffix(".app") {
      failures.push("macOS bundleName must end with .app")
    }
  } else if platform == "windows" {
    if output_kind != "portable-folder" {
      failures.push("Windows outputKind must be 'portable-folder'")
    }
    if !ascii_lower(executable).has_suffix(".exe") {
      failures.push("Windows executable must end with .exe")
    }
  } else {
    failures.push("platform must be 'macos' or 'windows'")
  }
  failures
}

///|
fn validate_manifest_text(
  text : String,
  expected_platform : String,
) -> Result[(String, String), Array[String]] {
  let parsed = @json.parse(text) catch {
    _ => return Err(["failed to read JSON: invalid JSON"])
  }
  let manifest = match json_object(parsed) {
    Some(fields) => fields
    None => return Err(["manifest root must be an object"])
  }
  let failures = validate_manifest_fields(manifest, expected_platform)
  if !failures.is_empty() {
    return Err(failures)
  }
  let platform = match json_string_field(manifest, "platform") {
    Some(value) => value
    None => ""
  }
  let output_kind = match json_string_field(manifest, "outputKind") {
    Some(value) => value
    None => ""
  }
  Ok((platform, output_kind))
}

///|
fn validate_package_manifest(
  options : CliOptions,
) -> Result[String, Array[String]] {
  let text = match
    @tools.read_required_text(options.manifest_path, "package manifest") {
    Ok(value) => value
    Err(message) => return Err([message])
  }
  match validate_manifest_text(text, options.expected_platform) {
    Ok((platform, output_kind)) =>
      Ok(options.display_path + ": ok (" + platform + " " + output_kind + ")")
    Err(failures) => Err(failures)
  }
}

///|
fn print_prefixed_failures(path : String, failures : Array[String]) -> Unit {
  for failure in failures {
    println(path + ": " + failure)
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
      match validate_package_manifest(options) {
        Ok(message) => {
          println(message)
          0
        }
        Err(failures) => {
          print_prefixed_failures(options.display_path, failures)
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
