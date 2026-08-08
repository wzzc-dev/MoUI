///|
test "doctor statuses use the stable machine-readable vocabulary" {
  inspect(DoctorStatus::Pass.name(), content="pass")
  inspect(DoctorStatus::Warn.name(), content="warn")
  inspect(DoctorStatus::Fail.name(), content="fail")
  inspect(DoctorStatus::Skip.name(), content="skip")
}

///|
test "Android doctor versions match the window-hosted toolchain floor" {
  inspect(android_compile_sdk, content="36")
  inspect(android_target_sdk, content="35")
  inspect(android_build_tools_version, content="35.0.0")
  inspect(android_cmake_version, content="3.22.1")
  inspect(android_ndk_version, content="28.2.13676358")
  inspect(android_gradle_version, content="9.6.1")
  inspect(xcode_minimum_version, content="15.4")
  inspect(swift_minimum_version, content="5.0")
  inspect(harmonyos_compatible_api, content="20")
  inspect(harmonyos_target_api, content="21")
  inspect(harmonyos_model_version, content="6.0.1")
}

///|
test "doctor JSON preserves status, required, and ok fields" {
  let report : DoctorReport = {
    schema_version: 1,
    ok: false,
    host: "linux",
    project_root: "/project",
    platforms: ["web", "linux"],
    checks: [
      {
        id: "moonbit",
        status: Pass,
        required: true,
        summary: "available",
        detail: "/bin/moon",
        remediation: "",
      },
      {
        id: "wayland",
        status: Fail,
        required: true,
        summary: "missing",
        detail: "",
        remediation: "install it",
      },
      {
        id: "android",
        status: Skip,
        required: false,
        summary: "not selected",
        detail: "",
        remediation: "",
      },
    ],
    evidence: Map([]),
  }
  let text = report.to_json_text()
  let parsed = @json.parse(text) catch { _ => fail("doctor JSON must parse") }
  guard parsed is Object(root) else { fail("doctor JSON must be an object") }
  inspect(root.get("ok") is Some(False), content="true")
  inspect(root.get("host") is Some(String("linux")), content="true")
  guard root.get("checks") is Some(Array(checks)) else {
    fail("doctor JSON must contain checks")
  }
  inspect(checks.length(), content="3")
  inspect(text.contains("\"status\": \"pass\""), content="true")
  inspect(text.contains("\"status\": \"fail\""), content="true")
  inspect(text.contains("\"status\": \"skip\""), content="true")
}

///|
test "Web-only doctor has no required environment failure under the test toolchain" {
  let report = match
    run_doctor({ project_root: ".", platforms: ["web"], all: false }) {
    Ok(report) => report
    Err(message) => fail(message)
  }
  inspect(report.platforms.join(","), content="web")
  inspect(
    report.checks.any(check => check.id == "skia" && check.status == Skip),
    content="true",
  )
  inspect(
    report.ok ==
    !report.checks.any(check => check.required && check.status == Fail),
    content="true",
  )
  inspect(report.to_human_text().contains("MoUI doctor host="), content="true")
}

///|
test "doctor rejects unsupported platform names" {
  inspect(
    run_doctor({ project_root: ".", platforms: ["plan9"], all: false })
    is Err(_),
    content="true",
  )
}

///|
test "doctor rejects an invalid existing project manifest" {
  let root = test_temp_path("doctor-invalid-manifest")
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  @fs.write_string_to_file(
    join_path(root, "moui.project.json"),
    "{ invalid json",
  ) catch {
    _ => {
      remove_tree(root)
      fail("could not write invalid doctor fixture")
    }
  }
  let result = run_doctor({ project_root: root, platforms: [], all: false })
  let explicit = run_doctor({
    project_root: root,
    platforms: ["web"],
    all: false,
  })
  remove_tree(root)
  inspect(
    result is Err(message) && message.contains("invalid JSON"),
    content="true",
  )
  inspect(
    explicit is Err(message) && message.contains("invalid JSON"),
    content="true",
  )
}

///|
test "missing required Skia package is a failure" {
  let root = test_temp_path("doctor-missing-skia")
  remove_tree(root)
  match mkdir_p(join_path(root, "moui_skia")) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let check = skia_doctor_check(root, true)
  remove_tree(root)
  inspect(check.status == Fail, content="true")
  inspect(check.required, content="true")
}

///|
fn doctor_write_fixture(path : String, value : String) -> Unit raise {
  match mkdir_p(parent_dir(path)) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  @fs.write_string_to_file(path, value) catch {
    _ => fail("could not write doctor fixture: " + path)
  }
}

///|
test "Skia doctor resolves the nearest repository workspace" {
  let root = test_temp_path("doctor-workspace-skia")
  let project = join_path(root, "examples/sample")
  let skia = join_path(root, "moui_skia")
  remove_tree(root)
  doctor_write_fixture(join_path(root, "moon.work"), "members = []\n")
  doctor_write_fixture(join_path(skia, "moon.mod"), "name = \"fixture/skia\"\n")
  doctor_write_fixture(join_path(skia, "build.js"), "export default {}\n")
  doctor_write_fixture(join_path(skia, "skia-provider-lock.json"), "{}\n")
  doctor_write_fixture(join_path(skia, "native/capabilities.json"), "{}\n")
  match mkdir_p(project) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let check = skia_doctor_check(project, true)
  remove_tree(root)
  inspect(check.status == Pass, content="true")
  inspect(check.detail, content=skia)
}

///|
fn doctor_mobile_entrypoint_contract_text() -> String {
  let text =
    #|@runtime.run_app("app", runtime)
    #|  .render_all(@render_skia.from_env(platform=@render_skia.NativeGpuPlatform::Android))
    #|  .backend(@platform_host.entry())
    #|  .run()
  text
}

///|
test "mobile entrypoint requires nonempty package and main files" {
  let root = test_temp_path("doctor-entrypoint")
  remove_tree(root)
  let package_path = join_path(root, "android_window_hosted/moon.pkg")
  match mkdir_p(parent_dir(package_path)) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  @fs.write_string_to_file(package_path, "supported_targets = \"native\"\n") catch {
    _ => {
      remove_tree(root)
      fail("could not write entrypoint package fixture")
    }
  }
  let incomplete = project_entrypoint_checks(root, ["android"])
  @fs.write_string_to_file(
    join_path(root, "android_window_hosted/main.mbt"),
    doctor_mobile_entrypoint_contract_text(),
  ) catch {
    _ => {
      remove_tree(root)
      fail("could not write entrypoint main fixture")
    }
  }
  @fs.write_string_to_file(
    package_path, "wzzc-dev/moui/runtime\nwzzc-dev/moui/backend/android\nwzzc-dev/moui_skia_renderer\n",
  ) catch {
    _ => {
      remove_tree(root)
      fail("could not write entrypoint export fixture")
    }
  }
  let complete = project_entrypoint_checks(root, ["android"])
  remove_tree(root)
  inspect(incomplete.length(), content="1")
  inspect(incomplete[0].status == Warn, content="true")
  inspect(complete.length(), content="1")
  inspect(complete[0].status == Pass, content="true")
}

///|
test "mobile entrypoint accepts the repository app layout" {
  let root = test_temp_path("doctor-repository-entrypoint")
  let package_path = join_path(root, "android/moon.pkg")
  let main_path = join_path(root, "android/main.mbt")
  remove_tree(root)
  match mkdir_p(parent_dir(package_path)) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  let contract = doctor_mobile_entrypoint_contract_text()
  @fs.write_string_to_file(
    package_path, "wzzc-dev/moui/runtime\nwzzc-dev/moui/backend/android\nwzzc-dev/moui_skia_renderer\n",
  ) catch {
    _ => {
      remove_tree(root)
      fail("could not write repository entrypoint package fixture")
    }
  }
  @fs.write_string_to_file(main_path, contract) catch {
    _ => {
      remove_tree(root)
      fail("could not write repository entrypoint main fixture")
    }
  }
  let checks = project_entrypoint_checks(root, ["android"])
  remove_tree(root)
  inspect(checks.length(), content="1")
  inspect(checks[0].status == Pass, content="true")
  inspect(checks[0].detail.contains("android/moon.pkg"), content="true")
}

///|
test "platform prerequisite structures reject empty placeholders" {
  let root = test_temp_path("doctor-prerequisites")
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  inspect(valid_android_ndk(join_path(root, "ndk")), content="false")
  inspect(valid_msvc_zlib_root(join_path(root, "zlib")), content="false")
  inspect(xcode_root_supports_ios(join_path(root, "xcode")), content="false")
  inspect(valid_skia_root(join_path(root, "skia")), content="false")
  let fake_command = join_path(root, "fake-command")
  @fs.write_bytes_to_file(fake_command, b"") catch {
    _ => {
      remove_tree(root)
      fail("could not write empty command fixture")
    }
  }
  inspect(first_executable([fake_command]) is None, content="true")
  remove_tree(root)
}

///|
test "invalid manifest is a CLI contract error with valid JSON" {
  let root = test_temp_path("doctor-cli-invalid")
  remove_tree(root)
  match mkdir_p(root) {
    Ok(_) => ()
    Err(message) => fail(message)
  }
  @fs.write_string_to_file(
    join_path(root, "moui.project.json"),
    "{ invalid json",
  ) catch {
    _ => {
      remove_tree(root)
      fail("could not write invalid CLI manifest fixture")
    }
  }
  let outcome = run_cli(["doctor", "--project-root", root, "--json"], ".")
  remove_tree(root)
  inspect(outcome.exit_code, content="2")
  inspect(outcome.stdout, content="")
  inspect(@json.parse(outcome.stderr) is Object(_), content="true")
}
