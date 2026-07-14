///|
struct CliOptions {
  repo_root : String
  manifest : String
  help : Bool
}

///|
fn usage() -> String {
  let text =
    #|Usage: node scripts/validate-check-profiles.mjs [options]
    #|       moon run tools/moui/validate_check_profiles --target native -- [options]
    #|
    #|Validates the checked-in MoUI check profile catalog.
    #|
    #|Options:
    #|  --repo-root PATH   Repository root used to resolve paths. Defaults to cwd.
    #|  --manifest PATH    Check profile catalog path. Default: checks/profiles.json
    #|  -h, --help         Show this help.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let manifest = Ref("checks/profiles.json")
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
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      other => return Err("unknown argument: " + other)
    }
  }
  Ok({ repo_root: repo_root.val, manifest: manifest.val, help: help.val })
}

///|
fn json_object(value : Json) -> Map[String, Json]? {
  match value {
    Json::Object(fields) => Some(fields)
    _ => None
  }
}

///|
fn json_object_field(value : Json?) -> Map[String, Json]? {
  match value {
    Some(Json::Object(fields)) => Some(fields)
    _ => None
  }
}

///|
fn json_array_field(value : Json?) -> Array[Json] {
  match value {
    Some(Json::Array(values)) => values
    _ => []
  }
}

///|
fn json_string(value : Json?) -> String? {
  match value {
    Some(Json::String(text)) => Some(text)
    _ => None
  }
}

///|
fn json_non_empty_string(value : Json?) -> String? {
  match value {
    Some(Json::String(text)) if text.trim().to_owned() != "" => Some(text)
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
fn push(failures : Array[String], message : String) -> Unit {
  failures.push(message)
}

///|
fn repo_path_exists(repo_root : String, path : String) -> Bool {
  let resolved = @tools.resolve_path(repo_root, path)
  @tools.file_exists(resolved) || @tools.directory_exists(resolved)
}

///|
fn looks_like_repo_path(value : String) -> Bool {
  value.has_prefix("scripts/") ||
  value.has_prefix("checks/") ||
  value.has_prefix(".github/") ||
  value.has_prefix("docs/") ||
  value.has_prefix("smoke/")
}

///|
fn valid_host(value : String) -> Bool {
  value == "any" ||
  value == "darwin" ||
  value == "linux" ||
  value == "windows" ||
  value == "non-windows"
}

///|
fn old_entrypoint_token(value : String) -> Bool {
  value.contains("dev-check.sh") ||
  value.contains("dev_check.ps1") ||
  value.contains("conformance-check.sh")
}

///|
fn validate_step(
  repo_root : String,
  profile_name : String,
  step_json : Json,
  step_index : Int,
  failures : Array[String],
) -> Unit {
  let label = profile_name + ".steps[\{step_index}]"
  let step = match json_object(step_json) {
    Some(fields) => fields
    None => {
      push(failures, label + " must be an object")
      return
    }
  }
  match json_non_empty_string(step.get("name")) {
    Some(_) => ()
    None => push(failures, label + ".name is required")
  }
  match json_string(step.get("host")) {
    Some(host) if valid_host(host) => ()
    Some(_) =>
      push(
        failures,
        label + ".host must be any, darwin, linux, windows, or non-windows",
      )
    None => ()
  }
  let argv = json_array_field(step.get("argv"))
  if argv.is_empty() {
    push(failures, label + ".argv must be a non-empty string array")
    return
  }
  let args : Array[String] = []
  for arg_json in argv {
    match arg_json {
      Json::String(arg) if arg != "" => args.push(arg)
      _ => {
        push(failures, label + ".argv must be a non-empty string array")
        return
      }
    }
  }
  for arg in args {
    if old_entrypoint_token(arg) {
      push(failures, label + ".argv references deleted entrypoint: " + arg)
    }
    if looks_like_repo_path(arg) &&
      !arg.has_prefix("artifacts/") &&
      !repo_path_exists(repo_root, arg) {
      push(failures, label + ".argv references missing repo path: " + arg)
    }
  }
}

///|
fn validate_profile(
  repo_root : String,
  profiles : Map[String, Json],
  profile_name : String,
  profile_json : Json,
  failures : Array[String],
) -> Unit {
  let profile = match json_object(profile_json) {
    Some(fields) => fields
    None => {
      push(failures, profile_name + " profile must be an object")
      return
    }
  }
  match json_non_empty_string(profile.get("description")) {
    Some(_) => ()
    None => push(failures, profile_name + ".description is required")
  }
  for included in json_array_field(profile.get("includes")) {
    match included {
      Json::String(name) if name != profile_name && profiles.contains(name) =>
        ()
      Json::String(name) if name == profile_name =>
        push(failures, profile_name + ".includes cannot include itself")
      Json::String(name) =>
        push(
          failures,
          profile_name + ".includes references unknown profile: " + name,
        )
      _ => push(failures, profile_name + ".includes must be a string array")
    }
  }
  let steps = json_array_field(profile.get("steps"))
  if steps.is_empty() {
    push(failures, profile_name + ".steps must be non-empty")
  }
  for index, step in steps {
    validate_step(repo_root, profile_name, step, index, failures)
  }
}

///|
fn validate_required_profiles(
  profiles : Map[String, Json],
  failures : Array[String],
) -> Unit {
  for required in ["pr", "daily", "platform", "theme", "full"] {
    if !profiles.contains(required) {
      push(failures, "profiles must include " + required)
    }
  }
}

///|
fn parse_catalog_text(
  text : String,
) -> Result[Map[String, Json], Array[String]] {
  let parsed = @json.parse(text) catch {
    _ => return Err(["failed to read JSON: invalid JSON"])
  }
  match json_object(parsed) {
    Some(fields) => Ok(fields)
    None => Err(["catalog must be a JSON object"])
  }
}

///|
fn validate_catalog_text(
  repo_root : String,
  text : String,
) -> Result[Map[String, Json], Array[String]] {
  match parse_catalog_text(text) {
    Ok(catalog) => {
      let failures : Array[String] = []
      if !json_number_is_one(catalog.get("schemaVersion")) {
        push(failures, "schemaVersion must be 1")
      }
      match json_non_empty_string(catalog.get("description")) {
        Some(_) => ()
        None => push(failures, "description is required")
      }
      let profiles = match json_object_field(catalog.get("profiles")) {
        Some(fields) => fields
        None => {
          push(failures, "profiles must be an object")
          Map([])
        }
      }
      validate_required_profiles(profiles, failures)
      for name, profile in profiles {
        validate_profile(repo_root, profiles, name, profile, failures)
      }
      if failures.is_empty() {
        Ok(catalog)
      } else {
        Err(failures)
      }
    }
    Err(failures) => Err(failures)
  }
}

///|
fn load_catalog(
  options : CliOptions,
) -> Result[Map[String, Json], Array[String]] {
  let manifest_path = @tools.resolve_path(options.repo_root, options.manifest)
  let text = match
    @tools.read_required_text(manifest_path, "check profile catalog") {
    Ok(value) => value
    Err(message) => return Err([message])
  }
  validate_catalog_text(options.repo_root, text)
}

///|
fn run(args : Array[String]) -> Int {
  let options = match parse_cli(args) {
    Ok(value) => value
    Err(message) => {
      println(usage())
      println(message)
      return 2
    }
  }
  if options.help {
    println(usage())
    return 0
  }
  match load_catalog(options) {
    Ok(_) => {
      println("check profile catalog passed")
      0
    }
    Err(failures) => {
      for failure in failures {
        println(failure)
      }
      1
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
