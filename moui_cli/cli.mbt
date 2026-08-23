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
  fix : Bool
  options : DoctorOptions
}

///|
priv struct ParsedAddPlatform {
  help : Bool
  json : Bool
  options : AddPlatformOptions?
}

///|
priv struct ParsedPackage {
  help : Bool
  json : Bool
  options : PackageReportOptions
}

///|
fn root_usage() -> String {
  (
    #|MoUI command-line tools
    #|
    #|Usage:
    #|  moui new <target> [options]
    #|  moui add platform <platform> [options]
    #|  moui doctor [options]
    #|  moui package [options]
    #|  moui dev [package] [options]
    #|  moui build <platform> <app> [options]
    #|  moui run <platform> <app> [options]
    #|  moui devices [options]
    #|  moui verify <platform> <app> [options]
    #|  moui config <action> [args]
    #|  moui --version
    #|
    #|Commands:
    #|  new             Create an independent MoUI project.
    #|  add platform    Add platforms to an existing project.
    #|  doctor          Check the selected platform toolchains.
    #|  package         Validate and plan a unified package manifest.
    #|  dev             Build, watch, and restart a MoUI project.
    #|  build           Build a mobile app artifact (APK / .app / .hap) without installing.
    #|  run             Build, install, and launch a mobile app on a device or emulator.
    #|  devices         List connected mobile devices and emulators.
    #|  verify          Verify embedded-runtime evidence.
    #|  config          Get/set MoUI CLI configuration values (XDG-backed).
    #|
    #|Options:
    #|  -h, --help      Show help.
    #|  --version       Show the CLI version and default MoUI dependency version.
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
    #|  --template NAME         App skeleton: counter (default) or hello.
    #|  --moui-version VERSION  MoUI dependency version written into moon.mod.
    #|                          Defaults to 0.1.11. Independent from CLI version.
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
    #|  --fix                Apply safe local remediations (moon.work/README).
    #|  --json               Emit machine-readable output.
    #|  -h, --help           Show this help.
  )
}

///|
fn add_usage() -> String {
  (
    #|Usage: moui add platform <platform> [options]
    #|
    #|Add one or more platforms to an existing MoUI project.
    #|
    #|Options:
    #|  --project-root PATH  Project root. Defaults to the current directory.
    #|  --platform PLATFORM  Additional platform; may be repeated.
    #|  --bundle-id ID       Required when adding the first mobile platform.
    #|  --json               Emit machine-readable output.
    #|  -h, --help           Show this help.
  )
}

///|
fn package_usage() -> String {
  (
    #|Usage: moui package [options]
    #|
    #|Validate project metadata and plan platform artifacts. The default keeps
    #|the legacy inventory report; --manifest or --output emits schema 1 JSON.
    #|
    #|Options:
    #|  --project-root PATH  Project root. Defaults to the current directory.
    #|  --platform PLATFORM  Package one platform; may be repeated.
    #|  --version VERSION    Release version override.
    #|  --output DIR         Artifact output directory.
    #|  --manifest PATH      Write the unified moui-package.json manifest.
    #|  --build              Mark the plan for a host build (never claims built).
    #|  --dry-run            Validate and print the plan without writing files.
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

// CLI argument helpers (`json_requested`, `option_parts`, `option_value`,
// `flag_without_value`, `parse_string_option`, `parse_string_list`) now live
// in `cli_args.mbt`.

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
  let template : Ref[String?] = Ref(None)
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
      | "--template"
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
          "--template" => template.val = Some(value)
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
  let template_name = template.val.unwrap_or("counter").to_lower()
  if template_name != "counter" && template_name != "hello" {
    return Err(
      "unsupported template: " + template_name + " (expected counter|hello)",
    )
  }
  let options : ProjectOptions = {
    target: resolved_target,
    id: project_id,
    module_name: module_name.val.unwrap_or("local/" + project_id),
    title: title.val.unwrap_or_else(() => default_title(project_id)),
    moui_version: moui_version.val.unwrap_or(default_moui_dependency_version),
    template: template_name,
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
  let fix = Ref(false)
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
      "--all" | "--fix" | "--json" | "-h" | "--help" => {
        match flag_without_value(inline, name) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
        match name {
          "--all" => all.val = true
          "--fix" => fix.val = true
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
    fix: fix.val,
    options: { project_root: project_root.val, platforms, all: all.val },
  })
}

///|
fn parse_add_platform_args(
  args : Array[String],
  cwd : String,
) -> Result[ParsedAddPlatform, String] {
  let project_root = Ref(cwd)
  let platforms : Array[String] = []
  let bundle_id : Ref[String?] = Ref(None)
  let help = Ref(false)
  let json = Ref(false)
  let mut index = 0
  while index < args.length() {
    let argument = args[index]
    let (name, inline) = option_parts(argument)
    match name {
      "--project-root" | "--platform" | "--bundle-id" => {
        let (value, next) = match option_value(args, index, inline, name) {
          Ok(result) => result
          Err(message) => return Err(message)
        }
        match name {
          "--project-root" => project_root.val = resolve_path(cwd, value)
          "--platform" => platforms.push(value)
          "--bundle-id" => bundle_id.val = Some(value)
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
        return Err("unknown option for moui add platform: " + name)
      _ => {
        platforms.push(argument)
        index += 1
      }
    }
  }
  if help.val {
    return Ok({ help: true, json: json.val, options: None })
  }
  if platforms.is_empty() {
    return Err("moui add platform requires at least one platform")
  }
  Ok({
    help: false,
    json: json.val,
    options: Some({
      project_root: project_root.val,
      platforms,
      bundle_id: bundle_id.val,
    }),
  })
}

///|
fn parse_package_args(
  args : Array[String],
  cwd : String,
) -> Result[ParsedPackage, String] {
  let project_root = Ref(cwd)
  let help = Ref(false)
  let json = Ref(false)
  let platforms : Ref[Array[String]] = Ref([])
  let version : Ref[String?] = Ref(None)
  let output_dir : Ref[String?] = Ref(None)
  let manifest_path : Ref[String?] = Ref(None)
  let build = Ref(false)
  let dry_run = Ref(false)
  let mut index = 0
  while index < args.length() {
    let argument = args[index]
    let (name, inline) = option_parts(argument)
    match name {
      "--platform" => {
        let (value, next) = match option_value(args, index, inline, name) {
          Ok(result) => result
          Err(message) => return Err(message)
        }
        platforms.val.push(value)
        index = next
      }
      "--version" | "--output" | "--manifest" => {
        let (value, next) = match option_value(args, index, inline, name) {
          Ok(result) => result
          Err(message) => return Err(message)
        }
        match name {
          "--version" => version.val = Some(value)
          "--output" => output_dir.val = Some(resolve_path(cwd, value))
          "--manifest" => manifest_path.val = Some(resolve_path(cwd, value))
          _ => ()
        }
        index = next
      }
      "--build" | "--dry-run" => {
        match flag_without_value(inline, name) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
        if name == "--build" {
          build.val = true
        } else {
          dry_run.val = true
        }
        index += 1
      }
      "--project-root" => {
        let (value, next) = match option_value(args, index, inline, name) {
          Ok(result) => result
          Err(message) => return Err(message)
        }
        project_root.val = resolve_path(cwd, value)
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
      _ => return Err("unknown option for moui package: " + name)
    }
  }
  Ok({
    help: help.val,
    json: json.val,
    options: {
      project_root: project_root.val,
      platforms: platforms.val,
      version: version.val,
      output_dir: output_dir.val,
      manifest_path: manifest_path.val,
      build: build.val,
      dry_run: dry_run.val,
    },
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
  let fixes : Array[String] = if parsed.fix {
    match apply_doctor_fixes(parsed.options) {
      Ok(value) => value
      Err(message) => return failed_outcome(message, parsed.json, "")
    }
  } else {
    []
  }
  match run_doctor(parsed.options) {
    Ok(report) => doctor_report_outcome(report, parsed.json, fixes~)
    Err(message) => failed_outcome(message, parsed.json, "")
  }
}

///|
fn doctor_report_outcome(
  report : DoctorReport,
  json : Bool,
  fixes? : Array[String] = [],
) -> CliOutcome {
  let text = if json {
    let root = @json.parse(report.to_json_text()) catch {
      _ =>
        return {
          exit_code: if report.ok {
            0
          } else {
            1
          },
          stdout: report.to_json_text(),
          stderr: "",
        }
    }
    guard root is Object(fields) else {
      return {
        exit_code: if report.ok {
          0
        } else {
          1
        },
        stdout: report.to_json_text(),
        stderr: "",
      }
    }
    fields["fixes"] = fixes.to_json()
    Json::object(fields).stringify(indent=2) + "\n"
  } else {
    let builder = StringBuilder::new()
    builder.write_string(report.to_human_text())
    if !fixes.is_empty() {
      builder.write_string("Applied fixes:\n")
      for action in fixes {
        builder.write_string("- " + action + "\n")
      }
    }
    builder.to_string()
  }
  { exit_code: if report.ok { 0 } else { 1 }, stdout: text, stderr: "" }
}

///|
fn run_add_platform(args : Array[String], cwd : String) -> CliOutcome {
  let json = json_requested(args)
  let parsed = match parse_add_platform_args(args, cwd) {
    Ok(value) => value
    Err(message) => return failed_outcome(message, json, add_usage())
  }
  if parsed.help {
    return stdout_outcome(add_usage())
  }
  guard parsed.options is Some(options) else {
    return failed_outcome(
      "add platform options are unavailable",
      parsed.json,
      "",
    )
  }
  match add_platforms_to_project(options) {
    Ok((added, files)) =>
      if parsed.json {
        let value : Json = {
          "schemaVersion": 1,
          "ok": true,
          "command": "add platform",
          "projectRoot": options.project_root,
          "addedPlatforms": added,
          "files": files,
        }
        stdout_outcome(value.stringify(indent=2) + "\n")
      } else {
        stdout_outcome(
          "Added platforms: " +
          added.join(", ") +
          "\nWrote \{files.length()} files under " +
          options.project_root +
          "\n",
        )
      }
    Err(message) => failed_outcome(message, parsed.json, "")
  }
}

///|
fn run_package_command(args : Array[String], cwd : String) -> CliOutcome {
  let json = json_requested(args)
  let parsed = match parse_package_args(args, cwd) {
    Ok(value) => value
    Err(message) => return failed_outcome(message, json, package_usage())
  }
  if parsed.help {
    return stdout_outcome(package_usage())
  }
  if parsed.options.manifest_path is Some(_) ||
    parsed.options.output_dir is Some(_) ||
    parsed.options.build ||
    parsed.options.dry_run ||
    !parsed.options.platforms.is_empty() ||
    parsed.options.version is Some(_) {
    match package_manifest_outcome(parsed.options, parsed.json) {
      Ok(outcome) => return outcome
      Err(message) => return failed_outcome(message, parsed.json, "")
    }
  }
  if parsed.json {
    match package_report_json(parsed.options) {
      Ok(text) => stdout_outcome(text)
      Err(message) => failed_outcome(message, true, "")
    }
  } else {
    match package_report_text(parsed.options) {
      Ok(text) => stdout_outcome(text)
      Err(message) => failed_outcome(message, false, "")
    }
  }
}

///|
fn version_output(json : Bool) -> CliOutcome {
  if json {
    let value : Json = {
      "schemaVersion": 1,
      "ok": true,
      "command": "version",
      "version": cli_version(),
      "defaultMouiDependencyVersion": default_moui_dependency_version,
      "note": "CLI version and default wzzc-dev/moui dependency version are independent.",
    }
    stdout_outcome(value.stringify(indent=2) + "\n")
  } else {
    stdout_outcome(
      "moui " +
      cli_version() +
      "\ndefault moui dependency: wzzc-dev/moui@" +
      default_moui_dependency_version +
      "\n(CLI version and dependency version are independent)\n",
    )
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
    "build" =>
      match parse_build_args(args[1:].to_owned(), cwd, detect_host_platform()) {
        Ok(parsed) => run_build(parsed, detect_host_platform())
        Err(message) =>
          failed_outcome(message, json_requested(args), build_usage())
      }
    "add" =>
      if args.length() == 1 ||
        (args.length() == 2 && (args[1] == "-h" || args[1] == "--help")) {
        stdout_outcome(add_usage())
      } else if args[1] == "platform" {
        run_add_platform(args[2:].to_owned(), cwd)
      } else {
        failed_outcome(
          "unknown moui add command: " + args[1],
          json_requested(args),
          add_usage(),
        )
      }
    "doctor" => run_doctor_command(args[1:].to_owned(), cwd)
    "package" => run_package_command(args[1:].to_owned(), cwd)
    "dev" =>
      match parse_dev_args(args[1:].to_owned(), cwd) {
        Ok(parsed) => run_dev(parsed)
        Err(message) =>
          failed_outcome(message, json_requested(args), dev_usage())
      }
    "run" =>
      match parse_run_args(args[1:].to_owned(), cwd, detect_host_platform()) {
        Ok(parsed) => run_run(parsed, cwd, detect_host_platform())
        Err(message) =>
          failed_outcome(message, json_requested(args), run_usage())
      }
    "devices" =>
      match parse_devices_args(args[1:].to_owned()) {
        Ok(parsed) => run_devices(parsed, detect_host_platform())
        Err(message) =>
          failed_outcome(message, json_requested(args), devices_usage())
      }
    "verify" =>
      match
        parse_verify_args(args[1:].to_owned(), cwd, detect_host_platform()) {
        Ok(parsed) => run_verify(parsed, detect_host_platform())
        Err(message) =>
          failed_outcome(message, json_requested(args), verify_usage())
      }
    "config" =>
      match parse_config_args(args[1:].to_owned()) {
        Ok(parsed) => run_config(parsed, detect_host_platform())
        Err(message) =>
          failed_outcome(message, json_requested(args), config_usage())
      }
    command =>
      failed_outcome(
        "unknown moui command: " + command,
        json_requested(args),
        root_usage(),
      )
  }
}
