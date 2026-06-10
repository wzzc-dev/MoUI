///|
struct CliOptions {
  repo_root : String
  patch_file : String
  status_file : String
  revision_file : String
  patched_status_file : String
  skip_input_state : Bool
  help : Bool
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui_skia/verify_acceptance_state_patch [options]
    #|
    #|Validates the pure acceptance-state patch contract for Linux real-Skia
    #|acceptance handoff artifacts. The host script still owns git apply and
    #|platform-status replay.
    #|
    #|Options:
    #|  --repo-root PATH             Repository root used to resolve relative paths. Defaults to cwd.
    #|  --patch-file PATH            Acceptance state patch. Default: logs/linux-acceptance-state.patch.
    #|  --status-file PATH           Original skia-platform-status.json path.
    #|                               Default: skia-platform-status.json.
    #|  --revision-file PATH         Original skia-revision.txt path.
    #|                               Default: skia-revision.txt.
    #|  --patched-status-file PATH   Patched skia-platform-status.json to verify Linux acceptance.
    #|  --skip-input-state           Skip original patch/status/revision existence and patch-shape checks.
    #|  -h, --help                   Show this help.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let patch_file = Ref("logs/linux-acceptance-state.patch")
  let status_file = Ref("skia-platform-status.json")
  let revision_file = Ref("skia-revision.txt")
  let patched_status_file = Ref("")
  let skip_input_state = Ref(false)
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
      "--patch-file" => {
        if index + 1 >= args.length() {
          return Err("missing value for --patch-file")
        }
        patch_file.val = args[index + 1]
        index += 2
      }
      "--status-file" => {
        if index + 1 >= args.length() {
          return Err("missing value for --status-file")
        }
        status_file.val = args[index + 1]
        index += 2
      }
      "--revision-file" => {
        if index + 1 >= args.length() {
          return Err("missing value for --revision-file")
        }
        revision_file.val = args[index + 1]
        index += 2
      }
      "--patched-status-file" => {
        if index + 1 >= args.length() {
          return Err("missing value for --patched-status-file")
        }
        patched_status_file.val = args[index + 1]
        index += 2
      }
      "--skip-input-state" => {
        skip_input_state.val = true
        index += 1
      }
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      value => return Err("unknown argument: " + value)
    }
  }
  Ok({
    repo_root: repo_root.val,
    patch_file: patch_file.val,
    status_file: status_file.val,
    revision_file: revision_file.val,
    patched_status_file: patched_status_file.val,
    skip_input_state: skip_input_state.val,
    help: help.val,
  })
}

///|
fn allowed_patch_file(path : String) -> Bool {
  path == "skia-revision.txt" || path == "skia-platform-status.json"
}

///|
fn normalize_patch_path(path : String) -> String {
  let normalized = path.trim().to_owned().replace(old="\\", new="/")
  if normalized.has_prefix("./") {
    normalize_patch_path(normalized[2:].to_owned())
  } else {
    normalized
  }
}

///|
fn find_substring(text : String, needle : String) -> Int? {
  if needle == "" {
    return Some(0)
  }
  if needle.length() > text.length() {
    return None
  }
  for index in 0..<=(text.length() - needle.length()) {
    if text[index:index + needle.length()].to_owned() == needle {
      return Some(index)
    }
  }
  None
}

///|
fn parse_diff_header(line : String) -> (String, String)? {
  let prefix = "diff --git a/"
  if !line.has_prefix(prefix) {
    return None
  }
  let rest = line[prefix.length():].to_owned()
  let marker = " b/"
  match find_substring(rest, marker) {
    Some(index) => {
      let old_path = normalize_patch_path(rest[:index].to_owned())
      let new_path = normalize_patch_path(
        rest[index + marker.length():].to_owned(),
      )
      Some((old_path, new_path))
    }
    None => None
  }
}

///|
fn validate_acceptance_state_patch_text(text : String) -> Result[Unit, String] {
  if text == "" {
    return Err("acceptance state patch is empty")
  }
  let diff_files : Map[String, Bool] = {}
  for line in text.split("\n") {
    match parse_diff_header(line.to_owned()) {
      Some((old_path, new_path)) => {
        if old_path != new_path {
          return Err(
            "acceptance state patch must not rename files: " +
            old_path +
            " -> " +
            new_path,
          )
        }
        if !allowed_patch_file(old_path) {
          return Err(
            "acceptance state patch touches unexpected file: " + old_path,
          )
        }
        diff_files[old_path] = true
      }
      None => ()
    }
  }
  if diff_files.is_empty() {
    return Err("acceptance state patch does not contain git file diffs")
  }
  if !diff_files.contains("skia-platform-status.json") {
    return Err("acceptance state patch must update skia-platform-status.json")
  }
  Ok(())
}

///|
fn json_object(value : Json?) -> Map[String, Json]? {
  match value {
    Some(Json::Object(fields)) => Some(fields)
    _ => None
  }
}

///|
fn require_object(
  object : Map[String, Json],
  field : String,
  label : String,
) -> Result[Map[String, Json], String] {
  match object.get(field) {
    Some(Json::Object(fields)) => Ok(fields)
    _ => Err(label + "." + field + " must be an object")
  }
}

///|
fn require_string(
  object : Map[String, Json],
  field : String,
  label : String,
) -> Result[String, String] {
  match object.get(field) {
    Some(Json::String(value)) if value.trim().to_owned() != "" => Ok(value)
    _ => Err(label + "." + field + " must be a non-empty string")
  }
}

///|
fn validate_linux_accepted_status_text(text : String) -> Result[Unit, String] {
  let parsed = @json.parse(text) catch {
    _ => return Err("Skia platform status JSON is invalid")
  }
  let status = match json_object(Some(parsed)) {
    Some(fields) => fields
    None => return Err("Skia platform status root must be an object")
  }
  let platforms = match require_object(status, "platforms", "status") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let linux = match require_object(platforms, "linux", "status.platforms") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match linux.get("accepted") {
    Some(Json::True) => ()
    _ => return Err("acceptance state patch does not mark Linux accepted")
  }
  let accepted_commit = match
    require_string(linux, "accepted_commit", "status.platforms.linux") {
    Ok(value) => value
    Err(_) =>
      return Err(
        "acceptance state patch does not record a Linux accepted_commit",
      )
  }
  if !@skia_acceptance.full_hex_hash(accepted_commit) {
    return Err("acceptance state patch does not record a Linux accepted_commit")
  }
  Ok(())
}

///|
fn read_existing_file(path : String, label : String) -> Result[String, String] {
  if !@tools.file_exists(path) {
    return Err(label + " is missing: " + path)
  }
  match @tools.read_required_text(path, label) {
    Ok(value) => Ok(value)
    Err(message) => Err(message)
  }
}

///|
fn verify_input_state(options : CliOptions) -> Result[Unit, String] {
  let resolved_patch_file = @tools.resolve_path(
    options.repo_root,
    options.patch_file,
  )
  let resolved_status_file = @tools.resolve_path(
    options.repo_root,
    options.status_file,
  )
  let resolved_revision_file = @tools.resolve_path(
    options.repo_root,
    options.revision_file,
  )
  let patch_text = match
    read_existing_file(resolved_patch_file, "acceptance state patch") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if patch_text.length() == 0 {
    return Err("acceptance state patch is empty: " + resolved_patch_file)
  }
  match read_existing_file(resolved_status_file, "Skia platform status file") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match read_existing_file(resolved_revision_file, "Skia revision file") {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match validate_acceptance_state_patch_text(patch_text) {
    Ok(_) => Ok(())
    Err("acceptance state patch is empty") =>
      Err("acceptance state patch is empty: " + resolved_patch_file)
    Err("acceptance state patch does not contain git file diffs") =>
      Err(
        "acceptance state patch does not contain git file diffs: " +
        resolved_patch_file,
      )
    Err(message) => Err(message)
  }
}

///|
fn verify_patched_status(options : CliOptions) -> Result[Unit, String] {
  if options.patched_status_file == "" {
    return Ok(())
  }
  let resolved_status_file = @tools.resolve_path(
    options.repo_root,
    options.patched_status_file,
  )
  let status_text = match
    read_existing_file(resolved_status_file, "Skia platform status file") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  validate_linux_accepted_status_text(status_text)
}

///|
fn verify_acceptance_state_patch(
  options : CliOptions,
) -> Result[String, String] {
  if !options.skip_input_state {
    match verify_input_state(options) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  match verify_patched_status(options) {
    Ok(_) => {
      let subject = if options.skip_input_state &&
        options.patched_status_file != "" {
        @tools.resolve_path(options.repo_root, options.patched_status_file)
      } else {
        @tools.resolve_path(options.repo_root, options.patch_file)
      }
      Ok("Verified Linux acceptance state patch contract for " + subject + ".")
    }
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
      match verify_acceptance_state_patch(options) {
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
