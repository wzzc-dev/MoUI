// Desktop and web launch flows for `moui run`. Native desktop targets are
// built (unless --no-build) and launched as child processes with the parent
// environment; the web target delegates to the dev runner, which serves the
// built wasm with refresh and error overlays. Mobile run pipelines are
// untouched.

///|
fn run_run_desktop(
  parsed : ParsedRun,
  cwd : String,
  host : HostPlatform,
) -> CliOutcome {
  guard parsed.options is Some(options) else {
    return failed_outcome(
      "run command options are unavailable",
      parsed.json,
      run_usage(),
    )
  }
  let flow = match
    resolve_desktop_flow(
      cwd,
      parsed.app,
      parsed.platform,
      renderer=options.renderer.unwrap_or("auto"),
    ) {
    Ok(value) => value
    Err(message) => return failed_outcome(message, parsed.json, run_usage())
  }
  if parsed.platform == "web" {
    return run_run_desktop_web(parsed, flow)
  }
  if options.prepare_only || options.build_only {
    let artifact = match desktop_build_once(flow, host) {
      Ok(value) => value
      Err(message) => return failed_outcome(message, parsed.json, run_usage())
    }
    return stdout_outcome(
      "[run] " +
      parsed.platform +
      " app=" +
      parsed.app +
      "\n  artifact: " +
      artifact +
      "\n  status: build-only\n",
    )
  }
  let artifact = if options.no_build {
    desktop_artifact_path(
      flow.build_base,
      flow.package_path,
      flow.target.target,
    )
  } else {
    match desktop_build_once(flow, host) {
      Ok(value) => value
      Err(message) => return failed_outcome(message, parsed.json, run_usage())
    }
  }
  if !path_is_file(artifact) {
    return failed_outcome(
      "build artifact not found: " +
      artifact +
      " (remove --no-build or build first with `moui build " +
      parsed.platform +
      " " +
      parsed.app +
      "`)",
      parsed.json,
      run_usage(),
    )
  }
  if options.verify {
    return failed_outcome(
      "--verify is only available for mobile platforms (android / ios / harmonyos)",
      parsed.json,
      run_usage(),
    )
  }
  let argv = [artifact]
  for argument in options.custom_args {
    argv.push(argument)
  }
  // The child inherits the parent environment: desktop runtime does not
  // need the MSVC toolchain, and user shell settings (renderer overrides,
  // font dirs) flow through.
  let result = match process_exec_argv(argv, cwd=flow.app_root, capture=false) {
    Ok(value) => value
    Err(message) => return failed_outcome(message, parsed.json, run_usage())
  }
  if parsed.json {
    let value : Json = {
      "schemaVersion": 1,
      "ok": result.exit_code == 0,
      "command": "run",
      "platform": parsed.platform,
      "app": parsed.app,
      "artifact": artifact,
      "exitCode": result.exit_code,
    }
    if result.exit_code == 0 {
      stdout_outcome(value.stringify(indent=2) + "\n")
    } else {
      {
        exit_code: result.exit_code,
        stdout: value.stringify(indent=2) + "\n",
        stderr: "",
      }
    }
  } else {
    let mut text = "[run] " + parsed.platform + " app=" + parsed.app + "\n"
    text += "  artifact: " + artifact + "\n"
    text += "  exit_code: " + result.exit_code.to_string() + "\n"
    if result.exit_code == 0 {
      stdout_outcome(text)
    } else {
      { exit_code: result.exit_code, stdout: text, stderr: "" }
    }
  }
}

///|
/// `moui run web <app>` delegates to the dev runner: the web target is a
/// serve-and-refresh loop rather than a single process launch.
fn run_run_desktop_web(parsed : ParsedRun, flow : DesktopFlow) -> CliOutcome {
  guard parsed.options is Some(options) else {
    return failed_outcome(
      "run command options are unavailable",
      parsed.json,
      run_usage(),
    )
  }
  let parsed_dev : ParsedDev = {
    help: false,
    json: parsed.json,
    project_root: flow.app_root,
    runner: None,
    runner_args: ["--package=" + flow.package_path, "--web", "--target=wasm-gc"],
  }
  if options.no_build {
    parsed_dev.runner_args.push("--once")
  }
  run_dev(parsed_dev)
}
