// Desktop and web build/launch flows shared by `moui build` and `moui run`.
// On Windows the MSVC environment is captured in-process (see
// `windows_env.mbt`) so building no longer requires sourcing
// `msvc_env.ps1` first.

///|
/// Run `moon build` for a resolved desktop/web target. Returns the predicted
/// artifact path. The child streams build output directly to the terminal
/// (`capture=false`), matching the mobile build flow.
fn desktop_build_once(
  flow : DesktopFlow,
  host : HostPlatform,
  release? : Bool = false,
) -> Result[String, String] {
  let argv = [
    "moon",
    "build",
    flow.package_path,
    "--target",
    flow.target.target,
  ]
  if release {
    argv.push("--release")
    argv.push("--strip")
  }
  let env = if flow.target.platform == "windows" {
    match windows_moon_env(flow.app_root, host) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
  } else {
    []
  }
  let result = match
    process_exec_argv(argv, cwd=flow.build_base, env~, capture=false) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if result.exit_code != 0 {
    return Err(
      "moon build failed with exit code " + result.exit_code.to_string(),
    )
  }
  Ok(
    desktop_artifact_path(
      flow.build_base,
      flow.package_path,
      flow.target.target,
      release~,
    ),
  )
}

///|
fn desktop_build_result_text(
  platform : String,
  app : String,
  artifact : String,
) -> String {
  let mut text = "[build] " + platform + " app=" + app + "\n"
  text += "  artifact: " + artifact + "\n"
  text + "  status: built\n"
}

///|
fn desktop_build_result_json(
  platform : String,
  app : String,
  artifact : String,
) -> Json {
  let fields : Map[String, Json] = Map([])
  fields["schemaVersion"] = Json::number(1.0)
  fields["ok"] = Json::boolean(true)
  fields["command"] = Json::string("build")
  fields["platform"] = Json::string(platform)
  fields["app"] = Json::string(app)
  fields["artifact"] = Json::string(artifact)
  Json::object(fields)
}

///|
fn run_build_desktop(parsed : ParsedBuild, host : HostPlatform) -> CliOutcome {
  guard parsed.options is Some(options) else {
    return failed_outcome(
      "build command options are unavailable",
      parsed.json,
      build_usage(),
    )
  }
  let flow = match
    resolve_desktop_flow(
      options.workspace_root,
      parsed.app,
      parsed.platform,
      renderer=options.renderer.unwrap_or("auto"),
    ) {
    Ok(value) => value
    Err(message) => return failed_outcome(message, parsed.json, build_usage())
  }
  let artifact = match desktop_build_once(flow, host, release=options.release) {
    Ok(value) => value
    Err(message) => return failed_outcome(message, parsed.json, build_usage())
  }
  if parsed.json {
    stdout_outcome(
      desktop_build_result_json(parsed.platform, parsed.app, artifact).stringify(
        indent=2,
      ) +
      "\n",
    )
  } else {
    stdout_outcome(
      desktop_build_result_text(parsed.platform, parsed.app, artifact),
    )
  }
}
