///|
priv struct ParsedDev {
  help : Bool
  json : Bool
  project_root : String
  runner : String?
  runner_args : Array[String]
}

///|
fn dev_usage() -> String {
  (
    #|Usage: moui dev [package] [options]
    #|
    #|Build and watch a MoUI project. Native targets restart the app after a
    #|successful rebuild. Web targets serve the project with refresh and a
    #|compiler-error overlay.
    #|
    #|Arguments:
    #|  package                  Package path. Defaults to web_wasm or app.
    #|
    #|Options:
    #|  --package PATH           Package path (same as the positional argument).
    #|  --target TARGET         MoonBit target (native or wasm-gc).
    #|  --project-root PATH     Project root. Defaults to the current directory.
    #|  --interval-ms MS         Watch interval. Defaults to 500.
    #|  --port PORT              Web server port. Defaults to 3000.
    #|  --state PATH             Optional state file passed as MOUI_DEV_STATE_FILE.
    #|  --runner PATH            Node runner path. Defaults to .moui/dev.mjs or scripts/moui-dev.mjs.
    #|  --web                    Serve Web output and inject the dev client.
    #|  --once, --build-only     Build once and exit.
    #|  --json                   Emit machine-readable status lines.
    #|  -h, --help               Show this help.
  )
}

///|
fn dev_int_option(value : String, name : String) -> Result[String, String] {
  match parse_int(value) {
    Ok(number) if number > 0 => Ok(value)
    _ => Err(name + " must be a positive integer")
  }
}

///|
fn parse_dev_args(
  args : Array[String],
  cwd : String,
) -> Result[ParsedDev, String] {
  let help = Ref(false)
  let json = Ref(false)
  let project_root = Ref(cwd)
  let runner : Ref[String?] = Ref(None)
  let package_name : Ref[String?] = Ref(None)
  let runner_args : Array[String] = []
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
      "--web" | "--once" | "--build-only" =>
        match flag_without_value(inline, name) {
          Ok(_) => runner_args.push(name)
          Err(message) => return Err(message)
        }
      "--package"
      | "--target"
      | "--project-root"
      | "--interval-ms"
      | "--port"
      | "--state"
      | "--runner" => {
        let (value, next) = match option_value(args, index, inline, name) {
          Ok(result) => result
          Err(message) => return Err(message)
        }
        match name {
          "--package" => package_name.val = Some(value)
          "--project-root" => project_root.val = make_absolute(value, cwd)
          "--runner" => runner.val = Some(make_absolute(value, cwd))
          "--interval-ms" | "--port" =>
            match dev_int_option(value, name) {
              Ok(validated) => runner_args.push(name + "=" + validated)
              Err(message) => return Err(message)
            }
          "--target" | "--state" => runner_args.push(name + "=" + value)
          _ => ()
        }
        index = next
        continue
      }
      value if !value.has_prefix("-") => positional.push(value)
      _ => return Err("unknown option for moui dev: " + name)
    }
    index += 1
  }
  if positional.length() > 1 ||
    (positional.length() == 1 && package_name.val is Some(_)) {
    return Err("moui dev accepts at most one package path")
  }
  if package_name.val is None && positional.length() == 1 {
    runner_args.push("--package=" + positional[0])
  } else if package_name.val is Some(value) {
    runner_args.push("--package=" + value)
  }
  if json.val {
    runner_args.push("--json")
  }
  Ok({
    help: help.val,
    json: json.val,
    project_root: project_root.val,
    runner: runner.val,
    runner_args,
  })
}

///|
fn dev_runner_candidates(
  project_root : String,
  requested : String?,
) -> Array[String] {
  let candidates : Array[String] = []
  match requested {
    Some(path) => candidates.push(path)
    None => ()
  }
  match @env.get_env_var("MOUI_DEV_RUNNER") {
    Some(path) => candidates.push(path)
    None => ()
  }
  candidates.push(join_path(project_root, ".moui/dev.mjs"))
  candidates.push(join_path(project_root, "scripts/moui-dev.mjs"))
  let current = Ref(normalized_path(project_root))
  for _ in 0..<64 {
    candidates.push(join_path(current.val, "scripts/moui-dev.mjs"))
    let parent = parent_dir(current.val)
    if parent == current.val {
      break
    }
    current.val = parent
  }
  candidates
}

///|
fn run_dev(parsed : ParsedDev) -> CliOutcome {
  if parsed.help {
    return stdout_outcome(dev_usage())
  }
  let runner = match
    first_existing(dev_runner_candidates(parsed.project_root, parsed.runner)) {
    Some(path) => path
    None =>
      return failed_outcome(
        "moui dev runner not found; generate a project with `moui new` or set MOUI_DEV_RUNNER",
        parsed.json,
        dev_usage(),
      )
  }
  let argv = ["node", runner]
  argv.push("--project-root=" + parsed.project_root)
  for argument in parsed.runner_args {
    argv.push(argument)
  }
  match process_exec_argv(argv, cwd=parsed.project_root, capture=false) {
    Ok(result) =>
      if parsed.json {
        let value : Json = {
          "schemaVersion": 1,
          "ok": result.exit_code == 0,
          "command": "dev",
          "runner": runner,
          "exitCode": result.exit_code,
        }
        if result.exit_code == 0 {
          stdout_outcome(value.stringify(indent=2) + "\n")
        } else {
          failed_outcome(
            "moui dev runner exited with code " + result.exit_code.to_string(),
            true,
            "",
          )
        }
      } else if result.exit_code == 0 {
        stdout_outcome("")
      } else {
        failed_outcome(
          "moui dev runner exited with code " + result.exit_code.to_string(),
          false,
          "",
        )
      }
    Err(message) => failed_outcome(message, parsed.json, dev_usage())
  }
}
