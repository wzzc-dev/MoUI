///|
test "doctor statuses use the stable machine-readable vocabulary" {
  inspect(DoctorStatus::Pass.name(), content="pass")
  inspect(DoctorStatus::Warn.name(), content="warn")
  inspect(DoctorStatus::Fail.name(), content="fail")
  inspect(DoctorStatus::Skip.name(), content="skip")
}

///|
test "Android doctor versions match the managed shell toolchain floor" {
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
test "mobile entrypoint requires nonempty package and main files" {
  let root = test_temp_path("doctor-entrypoint")
  remove_tree(root)
  let package_path = join_path(root, "android_skia/moon.pkg")
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
    join_path(root, "android_skia/main.mbt"),
    (
      #|moui_mobile_take_host_update_envelope_json
      #|moui_mobile_dispatch_host_response_envelope_json
      #|moui_mobile_renderer_configure
      #|moui_mobile_renderer_status_json
      #|moui_mobile_dispatch_text_input
      #|moui_mobile_dispatch_command
      #|moui_mobile_dispatch_accessibility
      #|moui_mobile_complete_clipboard_v1
      #|moui_mobile_attach_surface
      #|moui_mobile_resize
      #|moui_mobile_dispatch_pointer
      #|moui_mobile_dispatch_scroll
      #|moui_mobile_frame_tick
      #|moui_mobile_render_frame
      #|moui_mobile_detach_surface
      #|moui_mobile_destroy_application
    ),
  ) catch {
    _ => {
      remove_tree(root)
      fail("could not write entrypoint main fixture")
    }
  }
  @fs.write_string_to_file(
    package_path,
    @fs.read_file_to_string(join_path(root, "android_skia/main.mbt")),
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

///|
fn doctor_test_plugin_manifest() -> String {
  let value : Json = {
    "schemaVersion": 1,
    "id": "sample.camera",
    "shellApi": 1,
    "platforms": {
      "android": {
        "sources": ["android/src/Camera.kt"],
        "resources": ["android/res/camera.txt"],
        "entry": "dev.example.SampleCameraPlugin",
      },
    },
    "platformViewKinds": ["sample.camera.preview"],
    "hostChannels": ["sample.camera.control"],
    "permissions": ["camera"],
  }
  value.stringify(indent=2) + "\n"
}

///|
fn doctor_test_mobile_with_plugin(permission : Bool) -> String raise {
  let parsed = @json.parse(eject_test_mobile_text())
  guard parsed is Object(root) else { fail("mobile fixture must be an object") }
  guard root.get("mobile") is Some(Object(mobile)) else {
    fail("mobile fixture must contain mobile")
  }
  mobile["plugins"] = ["plugins/camera/moui.plugin.json"].to_json()
  let no_permissions : Array[String] = []
  mobile["permissions"] = if permission {
    ["camera"].to_json()
  } else {
    no_permissions.to_json()
  }
  root["mobile"] = Json::object(mobile)
  Json::object(root).stringify(indent=2) + "\n"
}

///|
test "doctor validates plugin schema, permissions, and content digest" {
  let root = test_temp_path("doctor-plugin")
  remove_tree(root)
  eject_test_write_text(
    join_path(root, "mobile.json"),
    doctor_test_mobile_with_plugin(true),
  )
  eject_test_write_text(
    join_path(root, "plugins/camera/moui.plugin.json"),
    doctor_test_plugin_manifest(),
  )
  eject_test_write_text(
    join_path(root, "plugins/camera/android/src/Camera.kt"),
    "class SampleCameraPlugin\n",
  )
  eject_test_write_text(
    join_path(root, "plugins/camera/android/res/camera.txt"),
    "camera\n",
  )
  let config = match read_mobile_doctor_config(root) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let plugins = match read_doctor_plugins(root, config) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let first_digest = doctor_plugins_digest(plugins)
  eject_test_write_text(
    join_path(root, "plugins/camera/android/src/Camera.kt"),
    "class ChangedCameraPlugin\n",
  )
  let changed = match read_doctor_plugins(root, config) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  inspect(first_digest == doctor_plugins_digest(changed), content="false")
  eject_test_write_text(
    join_path(root, "mobile.json"),
    doctor_test_mobile_with_plugin(false),
  )
  let no_permission = match read_mobile_doctor_config(root) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  inspect(read_doctor_plugins(root, no_permission) is Err(_), content="true")
  eject_test_write_text(
    join_path(root, "mobile.json"),
    doctor_test_mobile_with_plugin(true),
  )
  eject_test_write_text(
    join_path(root, "plugins/camera/build.gradle"),
    "dependencies {}\n",
  )
  inspect(read_doctor_plugins(root, config) is Err(_), content="true")
  remove_tree(root)
}

///|
test "doctor stages managed canonical shell and reports ejected drift" {
  let root = test_temp_path("doctor-shell")
  let moui_root = join_path(root, "moui")
  remove_tree(root)
  eject_test_prepare_project(root, moui_root)
  let managed = mobile_project_doctor_checks(root, ["android"])
  inspect(
    managed.any(check => {
      check.id == "mobile.android.managed-staging" && check.status == Pass
    }),
    content="true",
  )
  let result = match
    eject_mobile_shell({
      project_root: root,
      platform: "android",
      output: "",
      moui_root: Some(moui_root),
    }) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let config = match read_mobile_doctor_config(root) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let plugins = match read_doctor_plugins(root, config) {
    Ok(value) => value
    Err(message) => fail(message)
  }
  let clean = ejected_shell_doctor_check(
    root,
    "android",
    plugins,
    Some(moui_root),
  )
  inspect(clean.status == Pass, content="true")
  eject_test_write_text(join_path(result.output, "README.md"), "changed\n")
  let drift = ejected_shell_doctor_check(
    root,
    "android",
    plugins,
    Some(moui_root),
  )
  inspect(drift.status == Warn, content="true")
  inspect(drift.detail.contains("modified:README.md"), content="true")
  remove_tree(root)
}

///|
test "doctor keeps structural config and protocol compatibility separate" {
  let root = test_temp_path("doctor-protocol")
  remove_tree(root)
  let parsed = @json.parse(eject_test_mobile_text()) catch {
    _ => fail("mobile fixture must parse")
  }
  guard parsed is Object(fields) else { fail("mobile fixture must be object") }
  fields["runtimeAbiVersion"] = (2 : Int).to_json()
  eject_test_write_text(
    join_path(root, "mobile.json"),
    Json::object(fields).stringify(indent=2) + "\n",
  )
  let checks = mobile_project_doctor_checks(root, ["android"])
  inspect(
    checks.any(check => check.id == "mobile.config" && check.status == Pass),
    content="true",
  )
  inspect(
    checks.any(check => check.id == "mobile.protocol" && check.status == Fail),
    content="true",
  )
  remove_tree(root)
}
