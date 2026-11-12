///|
priv struct ParsedTest {
  help : Bool
  json : Bool
  package_path : String?
  target : String
  project_root : String
}

///|
fn test_usage() -> String {
  (
    #|Usage: moui test [package] [options]
    #|
    #|Run a project's MoonBit tests. Defaults to the `app` package when it
    #|exists, otherwise runs every package in the project.
    #|
    #|Options:
    #|  --package PATH        Package path (same as the positional argument).
    #|  --target TARGET       MoonBit target (native or wasm-gc). Defaults to native.
    #|  --project-root PATH   Project root. Defaults to the current directory.
    #|  --json                Emit a machine-readable result envelope.
    #|  -h, --help            Show this help.
  )
}

///|
fn parse_test_args(
  args : Array[String],
  cwd : String,
) -> Result[ParsedTest, String] {
  let help = Ref(false)
  let json = Ref(false)
  let package_name : Ref[String?] = Ref(None)
  let target = Ref("native")
  let project_root = Ref(cwd)
  let positional : Array[String] = []
  let mut index = 0
  while index < args.length() {
    let argument = args[index]
    let (name, inline) = option_parts(argument)
    match name {
      "-h" | "--help" =>
        match flag_without_value(inline, name) {
          Ok(_) => help.val = true
          Err(message) => return Err(message)
        }
      "--json" =>
        match flag_without_value(inline, name) {
          Ok(_) => json.val = true
          Err(message) => return Err(message)
        }
      "--package" | "--target" | "--project-root" =>
        match option_value(args, index, inline, name) {
          Ok((value, next)) => {
            match name {
              "--package" => package_name.val = Some(value)
              "--target" => target.val = value
              "--project-root" => project_root.val = make_absolute(value, cwd)
              _ => ()
            }
            index = next
            continue
          }
          Err(message) => return Err(message)
        }
      _ if argument.has_prefix("-") =>
        return Err("unknown option for moui test: " + name)
      _ => positional.push(argument)
    }
    index += 1
  }
  if positional.length() > 1 ||
    (positional.length() == 1 && package_name.val is Some(_)) {
    return Err("moui test accepts at most one package path")
  }
  if package_name.val is None && positional.length() == 1 {
    package_name.val = Some(positional[0])
  }
  Ok({
    help: help.val,
    json: json.val,
    package_path: package_name.val,
    target: target.val,
    project_root: project_root.val,
  })
}

///|
fn test_default_package(project_root : String) -> String? {
  if path_is_file(join_path(project_root, "app/moon.pkg")) {
    Some("app")
  } else {
    None
  }
}

///|
fn run_test(args : Array[String], cwd : String) -> CliOutcome {
  let parsed = match parse_test_args(args, cwd) {
    Ok(value) => value
    Err(message) => return failed_outcome(message, false, test_usage())
  }
  if parsed.help {
    return stdout_outcome(test_usage())
  }
  let package_name = match parsed.package_path {
    Some(value) => Some(value)
    None => test_default_package(parsed.project_root)
  }
  let argv = ["moon", "test"]
  match package_name {
    Some(value) => argv.push(value)
    None => ()
  }
  argv.push("--target")
  argv.push(parsed.target)
  let result = match
    process_exec_argv(argv, cwd=parsed.project_root, capture=parsed.json) {
    Ok(value) => value
    Err(message) => return failed_outcome(message, parsed.json, test_usage())
  }
  if parsed.json {
    let fields : Map[String, Json] = Map([])
    fields["schemaVersion"] = Json::number(1.0)
    fields["command"] = Json::string("test")
    fields["ok"] = Json::boolean(result.exit_code == 0)
    fields["exitCode"] = Json::number(result.exit_code.to_double())
    fields["package"] = match package_name {
      Some(value) => Json::string(value)
      None => Json::null()
    }
    fields["target"] = Json::string(parsed.target)
    fields["stdout"] = Json::string(result.stdout)
    fields["stderr"] = Json::string(result.stderr)
    let output = Json::object(fields).stringify(indent=2) + "\n"
    { exit_code: result.exit_code, stdout: output, stderr: "", }
  } else {
    { exit_code: result.exit_code, stdout: "", stderr: "", }
  }
}
