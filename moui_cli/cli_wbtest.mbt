///|
test "new parser applies host defaults and project defaults" {
  let parsed = parse_new_args(["demo_app"], "/workspace", Linux)
  guard parsed is Ok({ options: Some(options), .. }) else {
    fail("expected new arguments to parse")
  }
  inspect(options.target, content="/workspace/demo_app")
  inspect(options.id, content="demo_app")
  inspect(options.module_name, content="local/demo_app")
  inspect(options.title, content="DemoApp")
  inspect(options.moui_version, content="0.1.9")
  inspect(options.platforms.join(","), content="web,linux")
}

///|
test "new parser treats explicit platforms as additive" {
  let parsed = parse_new_args(
    [
      "demo_app", "--platform=android", "--platform", "ios", "--bundle-id=dev.example.demo",
    ],
    "/workspace",
    Linux,
  )
  guard parsed is Ok({ options: Some(options), .. }) else {
    fail("expected mobile new arguments to parse")
  }
  inspect(options.platforms.join(","), content="web,linux,android,ios")
  inspect(options.bundle_id.unwrap_or(""), content="dev.example.demo")
}

///|
test "new parser requires a mobile bundle id" {
  match
    parse_new_args(["demo_app", "--platform", "android"], "/workspace", Linux) {
    Err(message) =>
      inspect(
        message,
        content="--bundle-id is required when generating a mobile platform",
      )
    Ok(_) => fail("expected mobile generation without a bundle id to fail")
  }
}

///|
test "doctor parser accepts equals options and all" {
  let parsed = parse_doctor_args(
    ["--project-root=demo", "--platform=android", "--all", "--fix", "--json"],
    "/workspace",
  )
  guard parsed is Ok(parsed) else { fail("expected doctor arguments to parse") }
  inspect(parsed.options.project_root, content="/workspace/demo")
  inspect(parsed.options.platforms.join(","), content="android")
  inspect(parsed.options.all, content="true")
  inspect(parsed.fix, content="true")
  inspect(parsed.json, content="true")
}

///|
test "JSON usage failures remain valid JSON" {
  let outcome = run_cli(["unknown", "--json"], "/workspace")
  inspect(outcome.exit_code, content="2")
  inspect(outcome.stdout, content="")
  let parsed = @json.parse(outcome.stderr)
  guard parsed is Object(root) else { fail("expected a JSON object") }
  inspect(root.get("ok") == Some(false.to_json()), content="true")
}

///|
test "doctor required failures use exit code one" {
  let report : DoctorReport = {
    schema_version: 1,
    ok: false,
    host: "test",
    project_root: "/workspace",
    platforms: ["android"],
    checks: [],
    evidence: Map([]),
  }
  let outcome = doctor_report_outcome(report, true)
  inspect(outcome.exit_code, content="1")
  let parsed = @json.parse(outcome.stdout)
  guard parsed is Object(root) else { fail("expected doctor JSON") }
  inspect(root.get("ok") == Some(false.to_json()), content="true")
}

///|
test "help and version routes succeed" {
  let help = run_cli(["--help"], "/workspace")
  inspect(help.exit_code, content="0")
  inspect(help.stdout.has_prefix("MoUI command-line tools"), content="true")
  inspect(help.stdout.contains("add platform"), content="true")
  inspect(help.stdout.contains("plugin new"), content="false")
  inspect(help.stdout.contains("package"), content="true")
  let version_result = run_cli(["--version", "--json"], "/workspace")
  inspect(version_result.exit_code, content="0")
  let parsed = @json.parse(version_result.stdout)
  guard parsed is Object(root) else { fail("expected version JSON") }
  inspect(root.get("version") == Some("0.1.3".to_json()), content="true")
  inspect(
    root.get("defaultMouiDependencyVersion") ==
    Some(default_moui_dependency_version.to_json()),
    content="true",
  )
}

///|
test "dev parser forwards watch options to the runner" {
  let parsed = parse_dev_args(
    [
      "web_wasm", "--target=wasm-gc", "--interval-ms", "250", "--port=4173", "--state",
      ".moui/state.json", "--web", "--once", "--json",
    ],
    "/workspace/demo",
  )
  guard parsed is Ok(parsed) else { fail("expected dev arguments to parse") }
  inspect(parsed.project_root, content="/workspace/demo")
  inspect(
    parsed.runner_args.join("|"),
    content="--target=wasm-gc|--interval-ms=250|--port=4173|--state=.moui/state.json|--web|--once|--json|--package=web_wasm",
  )
}

///|
test "dev parser rejects duplicate package paths and invalid intervals" {
  match parse_dev_args(["app", "--package", "other"], "/workspace") {
    Err(message) =>
      inspect(message, content="moui dev accepts at most one package path")
    Ok(_) => fail("expected duplicate package paths to fail")
  }
  match parse_dev_args(["--interval-ms", "0"], "/workspace") {
    Err(message) =>
      inspect(message, content="--interval-ms must be a positive integer")
    Ok(_) => fail("expected invalid interval to fail")
  }
}

///|
test "add platform parser accepts positional platforms" {
  let parsed = parse_add_platform_args(
    ["android", "--platform=ios", "--bundle-id=dev.example.demo"],
    "/workspace",
  )
  guard parsed is Ok({ options: Some(options), .. }) else {
    fail("expected add platform arguments to parse")
  }
  inspect(options.platforms.join(","), content="android,ios")
  inspect(options.bundle_id.unwrap_or(""), content="dev.example.demo")
}

///|
test "window-hosted paths use the nested upstream module layout" {
  let workspace = "/workspace"
  inspect(
    window_package_root(workspace),
    content="/workspace/window/modules/window",
  )
  inspect(
    window_platform_root(workspace, "android"),
    content="/workspace/window/modules/window/android",
  )
  inspect(
    window_template_root(workspace, "android"),
    content="/workspace/window/modules/window/android/template",
  )
  inspect(
    window_template_root(workspace, "ios"),
    content="/workspace/window/modules/window/ios/template",
  )
  inspect(
    window_template_root(workspace, "harmonyos"),
    content="/workspace/window/modules/window/harmonyos/template",
  )
}

///|
