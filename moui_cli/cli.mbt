///|
let version : String = "0.1.0"

///|
pub(all) struct CliOutcome {
  exit_code : Int
  stdout : String
  stderr : String
}

///|
priv struct ParsedNew {
  help : Bool
  json : Bool
  options : ProjectOptions?
}

///|
priv struct ParsedDoctor {
  help : Bool
  json : Bool
  options : DoctorOptions
}

///|
priv struct ParsedEject {
  help : Bool
  json : Bool
  options : EjectOptions?
}

///|
fn root_usage() -> String {
  (
    #|MoUI command-line tools
    #|
    #|Usage:
    #|  moui new <target> [options]
    #|  moui doctor [options]
    #|  moui mobile eject <platform> [options]
    #|  moui --version
    #|
    #|Commands:
    #|  new             Create an independent MoUI project.
    #|  doctor          Check the selected platform toolchains.
    #|  mobile eject    Copy a managed mobile shell into the project.
    #|
    #|Options:
    #|  -h, --help      Show help.
    #|  --version       Show the CLI version.
  )
}

///|
fn new_usage() -> String {
  (
    #|Usage: moui new <target> [options]
    #|
    #|Options:
    #|  --id ID                 Project identifier. Defaults to the target name.
    #|  --module OWNER/NAME     MoonBit module. Defaults to local/<id>.
    #|  --title TITLE           Display title. Defaults from the project id.
    #|  --moui-version VERSION  MoUI dependency version. Defaults to 0.1.7.
    #|  --platform PLATFORM     Add a target platform; may be repeated.
    #|                          Values: web, macos, windows, linux, android,
    #|                          ios, harmonyos, or all.
    #|  --bundle-id ID          Required when a mobile platform is selected.
    #|  --json                  Emit machine-readable output.
    #|  -h, --help              Show this help.
  )
}

///|
fn doctor_usage() -> String {
  (
    #|Usage: moui doctor [options]
    #|
    #|Options:
    #|  --project-root PATH  Project root. Defaults to the current directory.
    #|  --platform PLATFORM  Check one platform; may be repeated.
    #|  --all                Check every supported platform.
    #|  --json               Emit machine-readable output.
    #|  -h, --help           Show this help.
  )
}

///|
fn mobile_usage() -> String {
  (
    #|Usage: moui mobile eject <android|ios|harmonyos> [options]
    #|
    #|Run `moui mobile eject --help` for command options.
  )
}

///|
fn eject_usage() -> String {
  (
    #|Usage: moui mobile eject <android|ios|harmonyos> [options]
    #|
    #|Options:
    #|  --project-root PATH  Project root. Defaults to the current directory.
    #|  --output PATH        Destination. Defaults to the platform shell path.
    #|  --moui-root PATH     Local MoUI package root containing shell templates.
    #|  --json               Emit machine-readable output.
    #|  -h, --help           Show this help.
  )
}

///|
fn stdout_outcome(text : String) -> CliOutcome {
  { exit_code: 0, stdout: text, stderr: "" }
}

///|
fn failed_outcome(
  message : String,
  json : Bool,
  usage : String,
  exit_code? : Int = 2,
) -> CliOutcome {
  let stderr = if json {
    let value : Json = {
      "schemaVersion": 1,
      "ok": false,
      "error": { "kind": "command", "message": message },
    }
    value.stringify(indent=2) + "\n"
  } else if usage == "" {
    "error: " + message + "\n"
  } else {
    "error: " + message + "\n\n" + usage
  }
  { exit_code, stdout: "", stderr }
}

///|
fn json_requested(args : Array[String]) -> Bool {
  args.any(arg => arg == "--json" || arg.has_prefix("--json="))
}

///|
fn option_parts(argument : String) -> (String, String?) {
  if argument.has_prefix("--") {
    match argument.split_once("=") {
      Some((name, value)) => (name.to_owned(), Some(value.to_owned()))
      None => (argument, None)
    }
  } else {
    (argument, None)
  }
}

///|
fn option_value(
  args : Array[String],
  index : Int,
  inline : String?,
  name : String,
) -> Result[(String, Int), String] {
  match inline {
    Some("") => Err("missing value for " + name)
    Some(value) => Ok((value, index + 1))
    None if index + 1 >= args.length() => Err("missing value for " + name)
    None => Ok((args[index + 1], index + 2))
  }
}

///|
fn flag_without_value(inline : String?, name : String) -> Result[Unit, String] {
  match inline {
    Some(_) => Err(name + " does not take a value")
    None => Ok(())
  }
}

///|
fn parse_new_args(
  args : Array[String],
  cwd : String,
  host : HostPlatform,
) -> Result[ParsedNew, String] {
  let target : Ref[String?] = Ref(None)
  let id : Ref[String?] = Ref(None)
  let module_name : Ref[String?] = Ref(None)
  let title : Ref[String?] = Ref(None)
  let moui_version : Ref[String?] = Ref(None)
  let bundle_id : Ref[String?] = Ref(None)
  let platforms : Array[String] = []
  let help = Ref(false)
  let json = Ref(false)
  let mut index = 0
  while index < args.length() {
    let argument = args[index]
    let (name, inline) = option_parts(argument)
    match name {
      "--id"
      | "--module"
      | "--title"
      | "--moui-version"
      | "--platform"
      | "--bundle-id" => {
        let (value, next) = match option_value(args, index, inline, name) {
          Ok(result) => result
          Err(message) => return Err(message)
        }
        match name {
          "--id" => id.val = Some(value)
          "--module" => module_name.val = Some(value)
          "--title" => title.val = Some(value)
          "--moui-version" => moui_version.val = Some(value)
          "--platform" => platforms.push(value)
          "--bundle-id" => bundle_id.val = Some(value)
          _ => ()
        }
        index = next
      }
      "--json" => {
        match flag_without_value(inline, name) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
        json.val = true
        index += 1
      }
      "-h" | "--help" => {
        match flag_without_value(inline, name) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
        help.val = true
        index += 1
      }
      _ if argument.has_prefix("-") =>
        return Err("unknown option for moui new: " + name)
      _ => {
        match target.val {
          None => target.val = Some(argument)
          Some(_) => return Err("moui new accepts exactly one target path")
        }
        index += 1
      }
    }
  }
  if help.val {
    return Ok({ help: true, json: json.val, options: None })
  }
  guard target.val is Some(raw_target) else {
    return Err("missing target path for moui new")
  }
  let resolved_target = resolve_path(cwd, raw_target)
  let project_id = id.val.unwrap_or_else(() => project_id_from_path(raw_target))
  let selected = match normalize_platforms(host, platforms) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let options : ProjectOptions = {
    target: resolved_target,
    id: project_id,
    module_name: module_name.val.unwrap_or("local/" + project_id),
    title: title.val.unwrap_or_else(() => default_title(project_id)),
    moui_version: moui_version.val.unwrap_or("0.1.7"),
    platforms: selected,
    bundle_id: bundle_id.val,
  }
  match validate_project_options(options) {
    Ok(_) => Ok({ help: false, json: json.val, options: Some(options) })
    Err(message) => Err(message)
  }
}

///|
fn parse_doctor_args(
  args : Array[String],
  cwd : String,
) -> Result[ParsedDoctor, String] {
  let project_root = Ref(cwd)
  let platforms : Array[String] = []
  let all = Ref(false)
  let help = Ref(false)
  let json = Ref(false)
  let mut index = 0
  while index < args.length() {
    let argument = args[index]
    let (name, inline) = option_parts(argument)
    match name {
      "--project-root" | "--platform" => {
        let (value, next) = match option_value(args, index, inline, name) {
          Ok(result) => result
          Err(message) => return Err(message)
        }
        if name == "--project-root" {
          project_root.val = resolve_path(cwd, value)
        } else {
          platforms.push(value)
        }
        index = next
      }
      "--all" | "--json" | "-h" | "--help" => {
        match flag_without_value(inline, name) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
        match name {
          "--all" => all.val = true
          "--json" => json.val = true
          "-h" | "--help" => help.val = true
          _ => ()
        }
        index += 1
      }
      _ => return Err("unknown option for moui doctor: " + name)
    }
  }
  Ok({
    help: help.val,
    json: json.val,
    options: { project_root: project_root.val, platforms, all: all.val },
  })
}

///|
fn parse_eject_args(
  args : Array[String],
  cwd : String,
) -> Result[ParsedEject, String] {
  let platform : Ref[String?] = Ref(None)
  let project_root = Ref(cwd)
  let output = Ref("")
  let moui_root : Ref[String?] = Ref(None)
  let help = Ref(false)
  let json = Ref(false)
  let mut index = 0
  while index < args.length() {
    let argument = args[index]
    let (name, inline) = option_parts(argument)
    match name {
      "--project-root" | "--output" | "--moui-root" => {
        let (value, next) = match option_value(args, index, inline, name) {
          Ok(result) => result
          Err(message) => return Err(message)
        }
        match name {
          "--project-root" => project_root.val = resolve_path(cwd, value)
          "--output" => output.val = value
          "--moui-root" => moui_root.val = Some(resolve_path(cwd, value))
          _ => ()
        }
        index = next
      }
      "--json" | "-h" | "--help" => {
        match flag_without_value(inline, name) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
        if name == "--json" {
          json.val = true
        } else {
          help.val = true
        }
        index += 1
      }
      _ if argument.has_prefix("-") =>
        return Err("unknown option for moui mobile eject: " + name)
      _ => {
        match platform.val {
          None => platform.val = Some(argument)
          Some(_) =>
            return Err("moui mobile eject accepts exactly one platform")
        }
        index += 1
      }
    }
  }
  if help.val {
    return Ok({ help: true, json: json.val, options: None })
  }
  guard platform.val is Some(selected_platform) else {
    return Err("missing platform for moui mobile eject")
  }
  Ok({
    help: false,
    json: json.val,
    options: Some({
      project_root: project_root.val,
      platform: selected_platform,
      output: output.val,
      moui_root: moui_root.val,
    }),
  })
}

///|
fn run_new(args : Array[String], cwd : String) -> CliOutcome {
  let json = json_requested(args)
  let parsed = match parse_new_args(args, cwd, detect_host_platform()) {
    Ok(value) => value
    Err(message) => return failed_outcome(message, json, new_usage())
  }
  if parsed.help {
    return stdout_outcome(new_usage())
  }
  guard parsed.options is Some(options) else {
    return failed_outcome(
      "new command options are unavailable",
      parsed.json,
      "",
    )
  }
  match generate_project(options) {
    Ok(files) =>
      if parsed.json {
        let value : Json = {
          "schemaVersion": 1,
          "ok": true,
          "command": "new",
          "target": options.target,
          "files": files,
        }
        stdout_outcome(value.stringify(indent=2) + "\n")
      } else {
        stdout_outcome(
          "Created MoUI project at " +
          options.target +
          "\nGenerated \{files.length()} files.\n",
        )
      }
    Err(message) => failed_outcome(message, parsed.json, "")
  }
}

///|
fn run_doctor_command(args : Array[String], cwd : String) -> CliOutcome {
  let json = json_requested(args)
  let parsed = match parse_doctor_args(args, cwd) {
    Ok(value) => value
    Err(message) => return failed_outcome(message, json, doctor_usage())
  }
  if parsed.help {
    return stdout_outcome(doctor_usage())
  }
  match run_doctor(parsed.options) {
    Ok(report) => doctor_report_outcome(report, parsed.json)
    Err(message) => failed_outcome(message, parsed.json, "")
  }
}

///|
fn doctor_report_outcome(report : DoctorReport, json : Bool) -> CliOutcome {
  let text = if json { report.to_json_text() } else { report.to_human_text() }
  { exit_code: if report.ok { 0 } else { 1 }, stdout: text, stderr: "" }
}

///|
fn run_eject(args : Array[String], cwd : String) -> CliOutcome {
  let json = json_requested(args)
  let parsed = match parse_eject_args(args, cwd) {
    Ok(value) => value
    Err(message) => return failed_outcome(message, json, eject_usage())
  }
  if parsed.help {
    return stdout_outcome(eject_usage())
  }
  guard parsed.options is Some(options) else {
    return failed_outcome(
      "eject command options are unavailable",
      parsed.json,
      "",
    )
  }
  match eject_mobile_shell(options) {
    Ok(result) =>
      if parsed.json {
        stdout_outcome(result.to_json_text())
      } else {
        stdout_outcome(
          "Ejected " +
          result.platform +
          " shell to " +
          result.output +
          "\nWrote \{result.file_count} template files.\n",
        )
      }
    Err(message) => failed_outcome(message, parsed.json, "")
  }
}

///|
fn version_output(json : Bool) -> CliOutcome {
  if json {
    let value : Json = {
      "schemaVersion": 1,
      "ok": true,
      "command": "version",
      "version": version,
    }
    stdout_outcome(value.stringify(indent=2) + "\n")
  } else {
    stdout_outcome("moui " + version + "\n")
  }
}

///|
pub fn run_cli(args : Array[String], cwd : String) -> CliOutcome {
  if args.is_empty() {
    return stdout_outcome(root_usage())
  }
  match args[0] {
    "-h" | "--help" => stdout_outcome(root_usage())
    "--version" =>
      if args.length() == 1 {
        version_output(false)
      } else if args.length() == 2 && args[1] == "--json" {
        version_output(true)
      } else {
        failed_outcome(
          "--version only accepts the optional --json flag",
          json_requested(args),
          root_usage(),
        )
      }
    "new" => run_new(args[1:].to_owned(), cwd)
    "doctor" => run_doctor_command(args[1:].to_owned(), cwd)
    "mobile" =>
      if args.length() == 1 ||
        (args.length() == 2 && (args[1] == "-h" || args[1] == "--help")) {
        stdout_outcome(mobile_usage())
      } else if args[1] == "eject" {
        run_eject(args[2:].to_owned(), cwd)
      } else {
        failed_outcome(
          "unknown moui mobile command: " + args[1],
          json_requested(args),
          mobile_usage(),
        )
      }
    command =>
      failed_outcome(
        "unknown moui command: " + command,
        json_requested(args),
        root_usage(),
      )
  }
}
