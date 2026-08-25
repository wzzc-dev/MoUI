///|
priv enum DoctorStatus {
  Pass
  Warn
  Fail
  Skip
} derive(Eq)

///|
fn DoctorStatus::name(self : DoctorStatus) -> String {
  match self {
    Pass => "pass"
    Warn => "warn"
    Fail => "fail"
    Skip => "skip"
  }
}

///|
priv struct DoctorCheck {
  id : String
  status : DoctorStatus
  required : Bool
  summary : String
  detail : String
  remediation : String
}

///|
priv struct DoctorReport {
  schema_version : Int
  ok : Bool
  host : String
  project_root : String
  platforms : Array[String]
  checks : Array[DoctorCheck]
  evidence : Map[String, EvidenceStatus]
}

///|
priv struct DoctorOptions {
  project_root : String
  platforms : Array[String]
  all : Bool
}

///|
fn doctor_check(
  id : String,
  status : DoctorStatus,
  required : Bool,
  summary : String,
  detail? : String = "",
  remediation? : String = "",
) -> DoctorCheck {
  { id, status, required, summary, detail, remediation }
}

///|
fn skipped_check(id : String, summary : String) -> DoctorCheck {
  doctor_check(id, Skip, false, summary)
}

///|
fn path_is_file(path : String) -> Bool {
  @fs.is_file(path) catch {
    _ => false
  }
}

///|
fn path_is_dir(path : String) -> Bool {
  @fs.is_dir(path) catch {
    _ => false
  }
}

///|
fn path_is_nonempty_file(path : String) -> Bool {
  if !path_is_file(path) {
    return false
  }
  let bytes = @fs.read_file_to_bytes(path) catch { _ => return false }
  !bytes.is_empty()
}

///|
/// Backward-compatible alias for `find_in_path` defined in `cli_path.mbt`.
/// Existing doctor call sites continue to use the `find_executable` name.
fn find_executable(name : String, host : HostPlatform) -> String? {
  find_in_path(name, host)
}

///|
/// Backward-compatible alias for `first_existing` defined in `cli_path.mbt`.
fn first_existing_file(paths : Array[String]) -> String? {
  first_existing(paths)
}

///|
fn env_directory(names : Array[String]) -> String? {
  for name in names {
    match @env.get_env_var(name) {
      Some(value) if path_is_dir(value) => return Some(value)
      _ => ()
    }
  }
  None
}

///|
fn valid_skia_root(root : String) -> Bool {
  path_is_dir(root) &&
  path_is_nonempty_file(join_path(root, "moon.mod")) &&
  path_is_nonempty_file(join_path(root, "build.js")) &&
  path_is_nonempty_file(join_path(root, "skia-provider-lock.json")) &&
  path_is_nonempty_file(join_path(root, "native/capabilities.json"))
}

///|
fn doctor_platforms(
  options : DoctorOptions,
  host : HostPlatform,
) -> Result[Array[String], String] {
  if options.all {
    return Ok([ for platform in platform_order => platform ])
  }
  if !options.platforms.is_empty() {
    let selected : Map[String, Bool] = Map([])
    for platform in options.platforms {
      let platform = platform.to_lower()
      if !is_platform(platform) {
        return Err("unsupported doctor platform: " + platform)
      }
      selected[platform] = true
    }
    let result : Array[String] = []
    for platform in platform_order {
      if selected.contains(platform) {
        result.push(platform)
      }
    }
    return Ok(result)
  }
  let manifest_path = join_path(options.project_root, "moui.project.json")
  if !@fs.path_exists(manifest_path) {
    return Ok(default_platforms(host))
  }
  match read_project_manifest(options.project_root) {
    Ok(manifest) => Ok(manifest.platforms)
    Err(message) => Err(message)
  }
}

///|
fn moonbit_doctor_check(host : HostPlatform) -> DoctorCheck {
  match find_executable("moon", host) {
    Some(path) =>
      doctor_check(
        "moonbit",
        Pass,
        true,
        "MoonBit CLI is available",
        detail=path,
      )
    None =>
      doctor_check(
        "moonbit",
        Fail,
        true,
        "MoonBit CLI is missing from PATH",
        remediation="Install MoonBit and ensure the moon executable is on PATH.",
      )
  }
}

///|
fn skia_doctor_check(project_root : String, required : Bool) -> DoctorCheck {
  if !required {
    return skipped_check(
      "skia", "Skia is not required by the selected Web-only project",
    )
  }
  let env_root = @env.get_env_var("MOUI_SKIA_ROOT").unwrap_or("")
  let candidates = [env_root]
  for root in project_search_roots(project_root) {
    candidates.push(join_path(root, "moui_skia"))
    candidates.push(join_path(root, ".mooncakes/wzzc-dev/moui_skia"))
  }
  let invalid_root = Ref("")
  for path in candidates {
    if valid_skia_root(path) {
      return doctor_check(
        "skia",
        Pass,
        true,
        "MoUI Skia package is available",
        detail=path,
      )
    }
    if invalid_root.val == "" && path_is_dir(path) {
      invalid_root.val = path
    }
  }
  doctor_check(
    "skia",
    Fail,
    true,
    if invalid_root.val == "" {
      "No local MoUI Skia package or override was found"
    } else {
      "The resolved MoUI Skia package is incomplete"
    },
    detail=invalid_root.val,
    remediation="Run moon update/build to resolve wzzc-dev/moui_skia, or set MOUI_SKIA_ROOT to a complete package root.",
  )
}

///|
fn valid_msvc_zlib_root(root : String) -> Bool {
  path_is_nonempty_file(join_path(root, "include/zlib.h")) &&
  (
    path_is_nonempty_file(join_path(root, "lib/zlib.lib")) ||
    path_is_nonempty_file(join_path(root, "lib/zlibstatic.lib"))
  )
}

///|
fn msvc_zlib_root(project_root : String) -> String? {
  let vcpkg_root = @env.get_env_var("VCPKG_ROOT").unwrap_or("")
  let vcpkg_installation = @env.get_env_var("VCPKG_INSTALLATION_ROOT").unwrap_or(
    "",
  )
  let candidates = [
    @env.get_env_var("MOUI_MSVC_ZLIB_TRIPLET_ROOT").unwrap_or(""),
    join_path(vcpkg_root, "installed/x64-windows"),
    join_path(vcpkg_installation, "installed/x64-windows"),
    join_path(project_root, ".tools/vcpkg-msvc/vcpkg_installed/x64-windows"),
    join_path(project_root, "vcpkg_installed/x64-windows"),
  ]
  for root in candidates {
    if root != "" && valid_msvc_zlib_root(root) {
      return Some(root)
    }
  }
  None
}

///|
fn msvc_doctor_check(
  project_root : String,
  host : HostPlatform,
  required : Bool,
) -> DoctorCheck {
  if !required {
    return skipped_check(
      "msvc", "MSVC is not required by the selected platforms",
    )
  }
  let configured = @env.get_env_var("VCToolsInstallDir") is Some(_) ||
    @env.get_env_var("VCINSTALLDIR") is Some(_) ||
    @env.get_env_var("VSINSTALLDIR") is Some(_)
  match find_executable("cl", host) {
    Some(path) => {
      if find_executable("node", host) is None {
        return doctor_check(
          "msvc",
          Fail,
          true,
          "MSVC is available, but Node.js is missing from PATH",
          detail=path,
          remediation="Install Node.js for MoonBit native build hooks.",
        )
      }
      match msvc_zlib_root(project_root) {
        Some(zlib) =>
          doctor_check(
            "msvc",
            Pass,
            true,
            "MSVC and the x64-windows zlib dependency are available",
            detail=path + " | " + zlib,
          )
        None =>
          doctor_check(
            "msvc",
            Fail,
            true,
            "MSVC is available, but zlib:x64-windows was not detected",
            detail=path,
            remediation="Run scripts/windows/setup_msvc_deps.ps1 -InstallZlib, then initialize scripts/windows/msvc_env.ps1.",
          )
      }
    }
    None if configured =>
      doctor_check(
        "msvc",
        Fail,
        true,
        "Visual Studio is configured but cl.exe is not on PATH",
        remediation="Run moui from a Visual Studio Developer PowerShell or initialize the MSVC environment.",
      )
    None =>
      doctor_check(
        "msvc",
        Fail,
        true,
        "MSVC Build Tools were not detected",
        remediation="Install Visual Studio Build Tools with the Desktop development with C++ workload.",
      )
  }
}

///|
fn wayland_doctor_check(host : HostPlatform, required : Bool) -> DoctorCheck {
  if !required {
    return skipped_check(
      "wayland", "Wayland is not required by the selected platforms",
    )
  }
  let scanner = find_executable("wayland-scanner", host)
  let pkg_config = find_executable("pkg-config", host)
  if scanner is None || pkg_config is None {
    return doctor_check(
      "wayland",
      Fail,
      true,
      "Wayland build tools are incomplete",
      detail="wayland-scanner=" +
        scanner.unwrap_or("missing") +
        " pkg-config=" +
        pkg_config.unwrap_or("missing"),
      remediation="Install wayland-scanner, pkg-config, libwayland-dev, and wayland-protocols.",
    )
  }
  let package_probe = run_doctor_probe(pkg_config.unwrap(), WaylandPackages)
  if package_probe.status != 0 {
    return doctor_check(
      "wayland",
      Fail,
      true,
      "Required Wayland pkg-config packages do not resolve",
      detail="packages=wayland-client,wayland-cursor,wayland-protocols" +
        (if package_probe.output == "" {
          ""
        } else {
          " | " + package_probe.output
        }),
      remediation="Install libwayland-dev and wayland-protocols, then ensure PKG_CONFIG_PATH exposes their .pc files.",
    )
  }
  let detail = scanner.unwrap() +
    " | " +
    pkg_config.unwrap() +
    " | packages=wayland-client,wayland-cursor,wayland-protocols"
  if @env.get_env_var("WAYLAND_DISPLAY") is None {
    doctor_check(
      "wayland",
      Warn,
      true,
      "Wayland build tools are available, but no active Wayland display is set",
      detail~,
      remediation="Set WAYLAND_DISPLAY when running native window smoke tests.",
    )
  } else {
    doctor_check(
      "wayland",
      Pass,
      true,
      "Wayland build and display environment is available",
      detail~,
    )
  }
}

///|
fn project_entrypoint_checks(
  project_root : String,
  platforms : Array[String],
) -> Array[DoctorCheck] {
  let checks : Array[DoctorCheck] = []
  for platform in ["android", "ios", "harmonyos"] {
    if platforms.contains(platform) {
      let generated_root = join_path(project_root, platform + "_window_hosted")
      let repository_root = join_path(project_root, platform)
      let entrypoint_root = if @fs.path_exists(
          join_path(generated_root, "moon.pkg"),
        ) ||
        @fs.path_exists(join_path(generated_root, "main.mbt")) {
        generated_root
      } else if @fs.path_exists(join_path(repository_root, "moon.pkg")) ||
        @fs.path_exists(join_path(repository_root, "main.mbt")) {
        repository_root
      } else {
        generated_root
      }
      let package_path = join_path(entrypoint_root, "moon.pkg")
      let main_path = join_path(entrypoint_root, "main.mbt")
      let package_text = @fs.read_file_to_string(package_path) catch { _ => "" }
      let main_text = @fs.read_file_to_string(main_path) catch { _ => "" }
      let package_markers = [
        "wzzc-dev/moui/runtime",
        "wzzc-dev/moui/backend/" + platform,
        "wzzc-dev/moui_skia_renderer",
      ]
      let main_markers = [
        "@runtime.run_app", ".render_all(", ".backend(@platform_host.entry())",
      ]
      let missing : Array[String] = []
      for marker in package_markers {
        if !package_text.contains(marker) {
          missing.push(marker)
        }
      }
      for marker in main_markers {
        if !main_text.contains(marker) {
          missing.push(marker)
        }
      }
      if path_is_nonempty_file(package_path) &&
        path_is_nonempty_file(main_path) &&
        missing.is_empty() {
        checks.push(
          doctor_check(
            "project." + platform + ".entrypoint",
            Pass,
            true,
            platform + " MoonBit entrypoint is present",
            detail=package_path + " | " + main_path,
          ),
        )
      } else {
        checks.push(
          doctor_check(
            "project." + platform + ".entrypoint",
            Warn,
            true,
            platform +
            " mobile metadata is present but its MoonBit entrypoint contract is incomplete",
            detail=if missing.is_empty() {
              "expected nonempty " + package_path + " and " + main_path
            } else {
              "missing markers: " + missing.join(", ")
            },
            remediation="Generate or add the platform entrypoint before building the native app.",
          ),
        )
      }
    }
  }
  checks
}

///|
fn run_doctor(options : DoctorOptions) -> Result[DoctorReport, String] {
  let host_platform = detect_host_platform()
  let project_manifest_path = join_path(
    options.project_root,
    "moui.project.json",
  )
  if @fs.path_exists(project_manifest_path) {
    match read_project_manifest(options.project_root) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  let platforms = match doctor_platforms(options, host_platform) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let native_selected = platforms.any(platform => platform != "web")
  let checks = [
    moonbit_doctor_check(host_platform),
    skia_doctor_check(options.project_root, native_selected),
    msvc_doctor_check(
      options.project_root,
      host_platform,
      platforms.contains("windows"),
    ),
    wayland_doctor_check(host_platform, platforms.contains("linux")),
    android_doctor_check(
      options.project_root,
      host_platform,
      platforms.contains("android"),
    ),
    xcode_doctor_check(
      host_platform,
      platforms.contains("macos"),
      platforms.contains("ios"),
    ),
    harmonyos_doctor_check(
      options.project_root,
      host_platform,
      platforms.contains("harmonyos"),
    ),
  ]
  for check in project_entrypoint_checks(options.project_root, platforms) {
    checks.push(check)
  }
  let ok = !checks.any(check => check.required && check.status == Fail)
  // Scan `artifacts/<platform>/*/verify-manifest.json` so the doctor can flag
  // missing runtime evidence alongside the toolchain checks.
  let evidence = check_evidence_ready(
    options.project_root,
    platforms,
    host_platform,
  )
  Ok({
    schema_version: 1,
    ok,
    host: host_platform.name(),
    project_root: options.project_root,
    platforms,
    checks,
    evidence,
  })
}

///|
fn doctor_check_json(check : DoctorCheck) -> Json {
  (
    {
      "id": check.id,
      "status": check.status.name(),
      "required": check.required,
      "summary": check.summary,
      "detail": check.detail,
      "remediation": check.remediation,
    } : Json)
}

///|
fn DoctorReport::to_json_text(self : DoctorReport) -> String {
  let checks = self.checks.map(doctor_check_json)
  let evidence_entries : Array[Json] = []
  for key, status in self.evidence {
    let entry : Json = {
      "key": Json::string(key),
      "platform": Json::string(status.platform),
      "appId": Json::string(status.app_id),
      "manifestPath": Json::string(status.manifest_path),
      "passed": Json::boolean(status.passed),
      "observationsSummary": Json::string(status.observations_summary),
    }
    evidence_entries.push(entry)
  }
  let value : Json = {
    "schemaVersion": self.schema_version,
    "ok": self.ok,
    "host": self.host,
    "projectRoot": self.project_root,
    "platforms": self.platforms,
    "checks": checks,
    "evidence": Json::array(evidence_entries),
  }
  value.stringify(indent=2) + "\n"
}

///|
fn DoctorReport::to_human_text(self : DoctorReport) -> String {
  let builder = StringBuilder()
  builder.write_string("MoUI doctor host=" + self.host + "\n")
  for check in self.checks {
    builder.write_string(
      "[" + check.status.name() + "] " + check.id + ": " + check.summary + "\n",
    )
    if check.detail != "" {
      builder.write_string("  " + check.detail + "\n")
    }
    if check.remediation != "" {
      builder.write_string("  Fix: " + check.remediation + "\n")
    }
  }
  if !self.evidence.is_empty() {
    builder.write_string("Runtime evidence:\n")
    builder.write_string(evidence_status_to_text(self.evidence))
  }
  builder.write_string(
    if self.ok {
      "Doctor completed without required failures.\n"
    } else {
      "Doctor found required environment failures.\n"
    },
  )
  builder.to_string()
}
