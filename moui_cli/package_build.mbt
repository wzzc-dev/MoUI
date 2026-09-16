// `moui package <platform> <app>` — produce distributable artifacts:
// Windows portable folders with `run.cmd`, macOS `.app` bundles, and web
// bundles. Ports the shell helpers (`package_windows_app_msvc.ps1`,
// `package-macos-app.sh`, `package-web-app.mjs`) into the CLI. Invoked
// without positional arguments, `moui package` keeps the legacy release
// planner behavior (`package_report.mbt`).

///|
priv struct ParsedPackageBuild {
  help : Bool
  json : Bool
  platform : String
  app : String
  options : PackageBuildOptions
}

///|
priv struct PackageBuildOptions {
  output_dir : String?
  name : String?
  version : String
  build_number : String
  bundle_id : String?
  renderer : String
  no_build : Bool
  dry_run : Bool
}

///|
fn package_build_usage() -> String {
  (
    #|Usage: moui package <platform> <app> [options]
    #|
    #|Produce a distributable artifact for a desktop or web target:
    #|windows -> portable folder with run.cmd, macos -> .app bundle,
    #|web -> static web bundle. Linux packaging is not implemented; use
    #|`moui build linux` and run the raw executable.
    #|
    #|Arguments:
    #|  platform     Target platform: macos, windows, or web.
    #|  app          Project directory holding the entrypoint packages (or
    #|               the entrypoint package itself).
    #|
    #|Options:
    #|  --output DIR        Distribution root. Defaults to dist/<platform>.
    #|  --name NAME         App display name. Defaults from the project id.
    #|  --version VERSION   Version recorded in the manifest. Defaults to 0.1.0.
    #|  --build-number N    Build number recorded in the manifest. Defaults to 1.
    #|  --bundle-id ID      macOS bundle identifier. Defaults to dev.wzzc.moui.app.
    #|  --renderer NAME     Entrypoint override (auto / skia / wgpu / sun).
    #|  --no-build          Package the existing build output without rebuilding.
    #|  --dry-run           Print the planned layout and manifest without writing.
    #|  --json              Emit machine-readable output.
    #|  -h, --help          Show this help.
  )
}

///|
/// Route to the real packager when the first positional argument names a
/// supported platform; otherwise the legacy release planner runs.
fn package_build_requested(args : Array[String]) -> Bool {
  match args.get(0) {
    Some(first) =>
      !first.has_prefix("-") &&
      (
        desktop_platform_supported(first) ||
        first == "android" ||
        first == "ios" ||
        first == "harmonyos"
      )
    None => false
  }
}

///|
fn parse_package_build_args(
  args : Array[String],
  cwd : String,
) -> Result[ParsedPackageBuild, String] {
  let _ = cwd
  let help = Ref(false)
  let json = Ref(false)
  let output_dir : Ref[String?] = Ref(None)
  let name : Ref[String?] = Ref(None)
  let version : Ref[String?] = Ref(None)
  let build_number : Ref[String?] = Ref(None)
  let bundle_id : Ref[String?] = Ref(None)
  let renderer : Ref[String?] = Ref(None)
  let no_build = Ref(false)
  let dry_run = Ref(false)
  let positional : Array[String] = []
  let mut index = 0
  while index < args.length() {
    let argument = args[index]
    let (flag, inline) = option_parts(argument)
    match flag {
      "--json" =>
        match flag_without_value(inline, flag) {
          Ok(_) => json.val = true
          Err(message) => return Err(message)
        }
      "-h" | "--help" =>
        match flag_without_value(inline, flag) {
          Ok(_) => help.val = true
          Err(message) => return Err(message)
        }
      "--no-build" | "--dry-run" =>
        match flag_without_value(inline, flag) {
          Ok(_) =>
            match flag {
              "--no-build" => no_build.val = true
              "--dry-run" => dry_run.val = true
              _ => ()
            }
          Err(message) => return Err(message)
        }
      "--output"
      | "--name"
      | "--version"
      | "--build-number"
      | "--bundle-id"
      | "--renderer" =>
        match option_value(args, index, inline, flag) {
          Ok((value, next)) => {
            match flag {
              "--output" => output_dir.val = Some(value)
              "--name" => name.val = Some(value)
              "--version" => version.val = Some(value)
              "--build-number" => build_number.val = Some(value)
              "--bundle-id" => bundle_id.val = Some(value)
              "--renderer" => renderer.val = Some(value)
              _ => ()
            }
            index = next
            continue
          }
          Err(message) => return Err(message)
        }
      _ if argument.has_prefix("-") =>
        return Err("unknown option for moui package: " + flag)
      _ => positional.push(argument)
    }
    index += 1
  }
  if help.val {
    return Ok({
      help: true,
      json: json.val,
      platform: "",
      app: "",
      options: {
        output_dir: None,
        name: None,
        version: "0.1.0",
        build_number: "1",
        bundle_id: None,
        renderer: "auto",
        no_build: false,
        dry_run: false,
      },
    })
  }
  if positional.length() < 2 {
    return Err("usage: moui package <platform> <app> [options]")
  }
  if positional.length() > 2 {
    return Err("moui package accepts exactly two positional arguments")
  }
  let platform = positional[0]
  let app = positional[1]
  if platform == "linux" {
    return Err(
      "Linux packaging is not implemented; use `moui build linux <app>` and run the raw executable, or `moui package linux --help` after support lands",
    )
  }
  if platform == "android" || platform == "ios" || platform == "harmonyos" {
    return Err(
      "mobile artifacts are produced by `moui build " +
      platform +
      "` and verified with `moui verify`; moui package supports macos, windows, and web",
    )
  }
  if !desktop_platform_supported(platform) {
    return Err(
      "unsupported platform for moui package: " +
      platform +
      " (expected macos, windows, or web)",
    )
  }
  Ok({
    help: false,
    json: json.val,
    platform,
    app,
    options: {
      output_dir: output_dir.val,
      name: name.val,
      version: version.val.unwrap_or("0.1.0"),
      build_number: build_number.val.unwrap_or("1"),
      bundle_id: bundle_id.val,
      renderer: renderer.val.unwrap_or("auto"),
      no_build: no_build.val,
      dry_run: dry_run.val,
    },
  })
}

///|
fn copy_file(source : String, destination : String) -> Result[Unit, String] {
  let bytes = @fs.read_file_to_bytes(source) catch {
    _ => return Err("could not read file for packaging: " + source)
  }
  @fs.write_bytes_to_file(destination, bytes) catch {
    _ => return Err("could not write packaged file: " + destination)
  }
  Ok(())
}

///|
fn find_existing_file(candidates : Array[String]) -> String? {
  for candidate in candidates {
    if candidate != "" && path_is_file(candidate) {
      return Some(candidate)
    }
  }
  None
}

///|
fn locate_manifest_validator(build_base : String) -> String? {
  find_existing_file([
    join_path(build_base, "scripts/validate-package-manifest.mjs"),
    "scripts/validate-package-manifest.mjs",
    join_path(
      moon_workspace_root(build_base).unwrap_or(""),
      "scripts/validate-package-manifest.mjs",
    ),
  ])
}

///|
fn validate_package_manifest(
  manifest_path : String,
  platform : String,
  build_base : String,
) -> String {
  match locate_manifest_validator(build_base) {
    Some(script) =>
      match
        process_exec_argv(
          ["node", script, manifest_path, "--platform", platform],
          capture=true,
        ) {
        Ok(result) =>
          if result.exit_code == 0 {
            "manifest validated"
          } else {
            "manifest validation failed: " + result.stderr
          }
        Err(message) => "manifest validation skipped: " + message
      }
    None => "manifest validation skipped (validator script not found)"
  }
}

///|
fn package_build_outcome(
  platform : String,
  app : String,
  output_path : String,
  validator_note : String,
  json : Bool,
) -> CliOutcome {
  if json {
    let fields : Map[String, Json] = Map([])
    fields["schemaVersion"] = Json::number(1.0)
    fields["ok"] = Json::boolean(true)
    fields["command"] = Json::string("package")
    fields["platform"] = Json::string(platform)
    fields["app"] = Json::string(app)
    fields["output"] = Json::string(output_path)
    fields["validation"] = Json::string(validator_note)
    stdout_outcome(Json::object(fields).stringify(indent=2) + "\n")
  } else {
    let mut text = "[package] " + platform + " app=" + app + "\n"
    text += "  output: " + output_path + "\n"
    text += "  " + validator_note + "\n"
    stdout_outcome(text)
  }
}

///|
fn run_package_build(args : Array[String], cwd : String) -> CliOutcome {
  let json = json_requested(args)
  let parsed = match parse_package_build_args(args, cwd) {
    Ok(value) => value
    Err(message) => return failed_outcome(message, json, package_build_usage())
  }
  if parsed.help {
    return stdout_outcome(package_build_usage())
  }
  let json = parsed.json
  let options = parsed.options
  let flow = match
    resolve_desktop_flow(
      cwd,
      parsed.app,
      parsed.platform,
      renderer=options.renderer,
    ) {
    Ok(value) => value
    Err(message) => return failed_outcome(message, json, package_build_usage())
  }
  let name = match options.name {
    Some(value) => value
    None => product_name(base_name(flow.app_root))
  }
  let dist_root = resolve_path(
    cwd,
    options.output_dir.unwrap_or("dist/" + parsed.platform),
  )
  let artifact = if options.no_build || options.dry_run {
    desktop_artifact_path(
      flow.build_base,
      flow.package_path,
      flow.target.target,
      release=parsed.platform == "web",
    )
  } else {
    match desktop_build_once(flow, detect_host_platform()) {
      Ok(value) => value
      Err(message) =>
        return failed_outcome(message, json, package_build_usage())
    }
  }
  match parsed.platform {
    "windows" =>
      package_windows_portable(flow, options, name, dist_root, artifact, json)
    "macos" =>
      package_macos_bundle(flow, options, name, dist_root, artifact, json)
    "web" => package_web_bundle(flow, options, dist_root, json, cwd)
    _ =>
      failed_outcome(
        "packaging for " + parsed.platform + " is not implemented",
        json,
        package_build_usage(),
      )
  }
}

///|
fn package_windows_portable(
  flow : DesktopFlow,
  options : PackageBuildOptions,
  name : String,
  dist_root : String,
  artifact : String,
  json : Bool,
) -> CliOutcome {
  let app_dir = join_path(dist_root, name)
  let executable = name + ".exe"
  let manifest_path = join_path(app_dir, "moui-package.json")
  if options.dry_run {
    let mut text = "[package] windows app=" + name + " (dry-run)\n"
    text += "  output: " + app_dir + "\n"
    text += "  files: " +
      executable +
      ", run.cmd, moui-package.json (+ zlib DLL)\n"
    return stdout_outcome(text)
  }
  if !path_is_file(artifact) {
    return failed_outcome(
      "build artifact not found: " + artifact,
      json,
      package_build_usage(),
    )
  }
  remove_tree(app_dir)
  match mkdir_p(app_dir) {
    Ok(_) => ()
    Err(message) => return failed_outcome(message, json, package_build_usage())
  }
  match copy_file(artifact, join_path(app_dir, executable)) {
    Ok(_) => ()
    Err(message) => return failed_outcome(message, json, package_build_usage())
  }
  let runtime_files = ["run.cmd"]
  match msvc_zlib_root(flow.app_root) {
    Some(triplet) =>
      match msvc_zlib_runtime_dll(triplet) {
        Some(dll) => {
          let dll_name = base_name(dll)
          match copy_file(dll, join_path(app_dir, dll_name)) {
            Ok(_) => runtime_files.push(dll_name)
            Err(message) =>
              return failed_outcome(message, json, package_build_usage())
          }
        }
        None => ()
      }
    None => ()
  }
  let run_cmd = [
      "@echo off",
      "setlocal",
      "set \"PATH=%~dp0;%PATH%\"",
      "\"%~dp0" + executable + "\" %*",
      "exit /b %ERRORLEVEL%",
    ].join("\r\n") +
    "\r\n"
  @fs.write_bytes_to_file(
    join_path(app_dir, "run.cmd"),
    @utf8.encode(run_cmd[:], bom=false),
  ) catch {
    _ =>
      return failed_outcome(
        "could not write run.cmd",
        json,
        package_build_usage(),
      )
  }
  let fields : Map[String, Json] = Map([])
  fields["schemaVersion"] = Json::number(1.0)
  fields["platform"] = Json::string("windows")
  fields["outputKind"] = Json::string("portable-folder")
  fields["appName"] = Json::string(name)
  fields["moonPackage"] = Json::string(flow.package_path)
  fields["version"] = Json::string(options.version)
  fields["buildNumber"] = Json::string(options.build_number)
  fields["executable"] = Json::string(executable)
  fields["bundleName"] = Json::string(name)
  fields["runtimeFiles"] = runtime_files.to_json()
  let manifest = Json::object(fields).stringify(indent=2) + "\n"
  @fs.write_bytes_to_file(manifest_path, @utf8.encode(manifest[:], bom=false)) catch {
    _ =>
      return failed_outcome(
        "could not write moui-package.json",
        json,
        package_build_usage(),
      )
  }
  let note = validate_package_manifest(
    manifest_path,
    "windows",
    flow.build_base,
  )
  package_build_outcome("windows", name, app_dir, note, json)
}

///|
fn package_macos_bundle(
  flow : DesktopFlow,
  options : PackageBuildOptions,
  name : String,
  dist_root : String,
  artifact : String,
  json : Bool,
) -> CliOutcome {
  let bundle_id = options.bundle_id.unwrap_or("dev.wzzc.moui.app")
  let bundle_dir = join_path(dist_root, name + ".app")
  let macos_dir = join_path(bundle_dir, "Contents/MacOS")
  let resources_dir = join_path(bundle_dir, "Contents/Resources")
  let executable = base_name(artifact)
  let executable = if executable.has_suffix(".exe") {
    executable[:executable.length() - 4].to_owned()
  } else {
    executable
  }
  let manifest_path = join_path(resources_dir, "moui-package.json")
  if options.dry_run {
    let mut text = "[package] macos app=" + name + " (dry-run)\n"
    text += "  output: " + bundle_dir + "\n"
    text += "  files: Contents/MacOS/" +
      executable +
      ", Contents/Resources/moui-package.json\n"
    return stdout_outcome(text)
  }
  if !path_is_file(artifact) {
    return failed_outcome(
      "build artifact not found: " + artifact,
      json,
      package_build_usage(),
    )
  }
  remove_tree(bundle_dir)
  match mkdir_p(macos_dir) {
    Ok(_) => ()
    Err(message) => return failed_outcome(message, json, package_build_usage())
  }
  match mkdir_p(resources_dir) {
    Ok(_) => ()
    Err(message) => return failed_outcome(message, json, package_build_usage())
  }
  let binary_path = join_path(macos_dir, executable)
  match copy_file(artifact, binary_path) {
    Ok(_) => ()
    Err(message) => return failed_outcome(message, json, package_build_usage())
  }
  match make_executable(binary_path) {
    Ok(_) => ()
    Err(message) => return failed_outcome(message, json, package_build_usage())
  }
  let plist = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
    "<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">\n" +
    "<plist version=\"1.0\">\n<dict>\n" +
    "  <key>CFBundleExecutable</key>\n  <string>" +
    executable +
    "</string>\n" +
    "  <key>CFBundleIdentifier</key>\n  <string>" +
    bundle_id +
    "</string>\n" +
    "  <key>CFBundleName</key>\n  <string>" +
    name +
    "</string>\n" +
    "  <key>CFBundlePackageType</key>\n  <string>APPL</string>\n" +
    "  <key>CFBundleShortVersionString</key>\n  <string>" +
    options.version +
    "</string>\n" +
    "  <key>CFBundleVersion</key>\n  <string>" +
    options.build_number +
    "</string>\n" +
    "  <key>LSMinimumSystemVersion</key>\n  <string>12.0</string>\n" +
    "  <key>NSHighResolutionCapable</key>\n  <true/>\n" +
    "</dict>\n</plist>\n"
  @fs.write_bytes_to_file(
    join_path(bundle_dir, "Contents/Info.plist"),
    @utf8.encode(plist[:], bom=false),
  ) catch {
    _ =>
      return failed_outcome(
        "could not write Info.plist",
        json,
        package_build_usage(),
      )
  }
  let fields : Map[String, Json] = Map([])
  fields["schemaVersion"] = Json::number(1.0)
  fields["platform"] = Json::string("macos")
  fields["outputKind"] = Json::string("app-bundle")
  fields["appName"] = Json::string(name)
  fields["moonPackage"] = Json::string(flow.package_path)
  fields["bundleIdentifier"] = Json::string(bundle_id)
  fields["version"] = Json::string(options.version)
  fields["buildNumber"] = Json::string(options.build_number)
  fields["executable"] = Json::string(executable)
  fields["bundleName"] = Json::string(name + ".app")
  fields["runtimeFiles"] = ([] : Array[String]).to_json()
  let manifest = Json::object(fields).stringify(indent=2) + "\n"
  @fs.write_bytes_to_file(manifest_path, @utf8.encode(manifest[:], bom=false)) catch {
    _ =>
      return failed_outcome(
        "could not write moui-package.json",
        json,
        package_build_usage(),
      )
  }
  let note = validate_package_manifest(manifest_path, "macos", flow.build_base)
  package_build_outcome("macos", name, bundle_dir, note, json)
}

///|
/// The web bundle is produced by the shared Node packager; the CLI locates
/// it in the workspace (or the installed MoUI package) and streams its
/// output. The script performs its own release+strip build.
fn package_web_bundle(
  flow : DesktopFlow,
  options : PackageBuildOptions,
  dist_root : String,
  json : Bool,
  cwd : String,
) -> CliOutcome {
  if options.dry_run {
    let mut text = "[package] web (dry-run)\n"
    text += "  output: " + dist_root + "\n"
    text += "  files: index.html, *.wasm, runtime.js, .gz/.br siblings, bundle-size.json\n"
    return stdout_outcome(text)
  }
  let script = match
    find_existing_file([
      join_path(flow.build_base, "scripts/package-web-app.mjs"),
      "scripts/package-web-app.mjs",
      join_path(cwd, "scripts/package-web-app.mjs"),
      join_path(
        moon_workspace_root(cwd).unwrap_or(""),
        ".mooncakes/wzzc-dev/moui/scripts/package-web-app.mjs",
      ),
    ]) {
    Some(path) => path
    None =>
      return failed_outcome(
        "package-web-app.mjs was not found; serve the built wasm statically instead (`moui build web` + a static file server)",
        json,
        package_build_usage(),
      )
  }
  let out_dir = join_path(dist_root, base_name(flow.app_root))
  let argv = ["node", script, flow.package_path, "--out", out_dir]
  if options.no_build {
    argv.push("--no-build")
  }
  let result = match
    process_exec_argv(argv, cwd=flow.build_base, capture=false) {
    Ok(value) => value
    Err(message) => return failed_outcome(message, json, package_build_usage())
  }
  if result.exit_code != 0 {
    return failed_outcome(
      "web packaging failed with exit code " + result.exit_code.to_string(),
      json,
      package_build_usage(),
    )
  }
  package_build_outcome(
    "web",
    flow.package_path,
    out_dir,
    "web bundle written",
    json,
  )
}
