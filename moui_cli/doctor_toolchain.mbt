///|
priv enum DoctorProbeKind {
  DashVersion
  DoubleDashVersion
  SwiftCompilerVersion
  WaylandPackages
  XcodeDeveloperPath
}

///|
fn DoctorProbeKind::code(self : DoctorProbeKind) -> Int {
  match self {
    DashVersion => 1
    DoubleDashVersion => 2
    SwiftCompilerVersion => 3
    WaylandPackages => 4
    XcodeDeveloperPath => 5
  }
}

///|
priv struct DoctorProbeResult {
  status : Int
  output : String
}

///|
/// Run a fixed, read-only doctor probe via `process_exec_argv`. Replaces the
/// previous `moui_cli_run_doctor_probe` C FFI. The argv is built from the
/// `DoctorProbeKind` so the probe semantics stay in MoonBit.
fn run_doctor_probe(
  executable : String,
  kind : DoctorProbeKind,
) -> DoctorProbeResult {
  let argv : Array[String] = match kind {
    DashVersion => [executable, "-version"]
    DoubleDashVersion => [executable, "--version"]
    SwiftCompilerVersion => [executable, "swiftc", "--version"]
    WaylandPackages =>
      [
        executable, "--exists", "wayland-client", "wayland-cursor", "wayland-protocols",
      ]
    XcodeDeveloperPath => [executable, "-p"]
  }
  match process_exec_argv(argv, capture=true, timeout_ms=30000) {
    Ok(result) =>
      {
        status: result.exit_code,
        output: (result.stdout + "\n" + result.stderr).trim().to_owned(),
      }
    Err(_message) => { status: 102, output: "" }
  }
}

///|
fn numeric_version_at(text : String, start : Int) -> Array[Int]? {
  if start < 0 ||
    start >= text.length() ||
    text[start] < '0' ||
    text[start] > '9' {
    return None
  }
  let parts : Array[Int] = []
  let number = Ref(0)
  let digits = Ref(0)
  for index in start..<text.length() {
    let unit = text[index]
    if unit >= '0' && unit <= '9' {
      number.val = number.val * 10 + unit.to_int() - '0'.to_int()
      digits.val += 1
    } else if unit == '.' {
      if digits.val == 0 {
        return None
      }
      parts.push(number.val)
      number.val = 0
      digits.val = 0
    } else {
      if digits.val > 0 {
        parts.push(number.val)
      }
      return if parts.is_empty() { None } else { Some(parts) }
    }
  }
  if digits.val > 0 {
    parts.push(number.val)
  } else {
    return None
  }
  Some(parts)
}

///|
fn first_numeric_version(text : String, start? : Int = 0) -> Array[Int]? {
  let start = if start < 0 { 0 } else { start }
  for index in start..<text.length() {
    let unit = text[index]
    if unit >= '0' &&
      unit <= '9' &&
      (index == start || text[index - 1] < '0' || text[index - 1] > '9') {
      match numeric_version_at(text, index) {
        Some(version) => return Some(version)
        None => ()
      }
    }
  }
  None
}

///|
fn numeric_version_after(text : String, marker : String) -> Array[Int]? {
  match text.find(marker) {
    Some(offset) => first_numeric_version(text, start=offset + marker.length())
    None => None
  }
}

///|
fn numeric_version_at_least(actual : Array[Int], required : Array[Int]) -> Bool {
  let length = actual.length().max(required.length())
  for index in 0..<length {
    let left = if index < actual.length() { actual[index] } else { 0 }
    let right = if index < required.length() { required[index] } else { 0 }
    if left > right {
      return true
    }
    if left < right {
      return false
    }
  }
  true
}

///|
fn numeric_version_has_prefix(
  actual : Array[Int],
  expected : Array[Int],
) -> Bool {
  if actual.length() < expected.length() {
    return false
  }
  for index, part in expected {
    if actual[index] != part {
      return false
    }
  }
  true
}

///|
fn numeric_version_text(version : Array[Int]) -> String {
  version.map(part => part.to_string()).join(".")
}

///|
fn detected_version(output : String, marker : String) -> Array[Int]? {
  match numeric_version_after(output, marker) {
    Some(version) => Some(version)
    None => first_numeric_version(output)
  }
}

///|
fn probe_version_floor(
  executable : String,
  kind : DoctorProbeKind,
  marker : String,
  required : Array[Int],
  label : String,
) -> Result[String, String] {
  let probe = run_doctor_probe(executable, kind)
  if probe.status != 0 {
    return Err(
      label +
      " version probe failed (status=" +
      probe.status.to_string() +
      ")" +
      (if probe.output == "" { "" } else { ": " + probe.output }),
    )
  }
  let version = match detected_version(probe.output, marker) {
    Some(version) => version
    None => return Err(label + " version could not be parsed: " + probe.output)
  }
  let actual = numeric_version_text(version)
  let floor = numeric_version_text(required)
  if !numeric_version_at_least(version, required) {
    return Err(label + " " + actual + " is below required " + floor)
  }
  Ok(actual)
}

///|
fn java_major_version(output : String) -> Int? {
  let version = match detected_version(output, "version") {
    Some(version) => version
    None => return None
  }
  if version[0] == 1 && version.length() > 1 {
    Some(version[1])
  } else {
    Some(version[0])
  }
}

///|
fn probe_java_floor(executable : String) -> Result[String, String] {
  let probe = run_doctor_probe(executable, DashVersion)
  if probe.status != 0 {
    return Err(
      "Java version probe failed (status=" + probe.status.to_string() + ")",
    )
  }
  let major = match java_major_version(probe.output) {
    Some(value) => value
    None => return Err("Java version could not be parsed: " + probe.output)
  }
  if major < 17 {
    return Err("Java " + major.to_string() + " is below required Java 17")
  }
  Ok(major.to_string())
}

///|
fn property_version(text : String, key : String) -> Array[Int]? {
  for line in text.split("\n") {
    let line = line.to_owned()
    if line.trim().has_prefix(key) {
      match line.find("=") {
        Some(offset) =>
          match first_numeric_version(line, start=offset + 1) {
            Some(version) => return Some(version)
            None => ()
          }
        None => ()
      }
    }
  }
  None
}

///|
fn ndk_revision(root : String) -> Array[Int]? {
  let properties = @fs.read_file_to_string(join_path(root, "source.properties")) catch {
    _ => return None
  }
  property_version(properties, "Pkg.Revision")
}

///|
fn gradle_wrapper_version(properties : String) -> Array[Int]? {
  numeric_version_after(properties, "gradle-")
}

///|
fn gradle_declared_version_floor(
  version : Array[Int],
  source : String,
) -> Result[String, String] {
  let actual = numeric_version_text(version)
  if !numeric_version_at_least(version, [9, 6, 1]) {
    return Err("Gradle " + actual + " is below required 9.6.1 (" + source + ")")
  }
  Ok(actual + " (" + source + ")")
}

///|
fn gradle_version_floor(
  project_root : String,
  executable : String,
  host : HostPlatform,
) -> Result[String, String]? {
  let wrapper = normalized_path(executable) ==
    normalized_path(join_path(project_root, "gradlew")) ||
    normalized_path(executable) ==
    normalized_path(join_path(project_root, "gradlew.bat"))
  if wrapper {
    let properties_path = join_path(
      project_root, "gradle/wrapper/gradle-wrapper.properties",
    )
    let configured = @env.get_env_var("MOUI_GRADLE_VERSION")
    match configured {
      Some(value) =>
        match first_numeric_version(value) {
          Some(version) =>
            return Some(
              gradle_declared_version_floor(version, "MOUI_GRADLE_VERSION"),
            )
          None =>
            return Some(Err("MOUI_GRADLE_VERSION is not a numeric version"))
        }
      None => ()
    }
    let properties = @fs.read_file_to_string(properties_path) catch { _ => "" }
    match gradle_wrapper_version(properties) {
      Some(version) =>
        return Some(gradle_declared_version_floor(version, "wrapper metadata"))
      None => ()
    }
    let wrapper_text = @fs.read_file_to_string(executable) catch { _ => "" }
    match numeric_version_after(wrapper_text, "MOUI_GRADLE_VERSION:-") {
      Some(version) =>
        return Some(
          gradle_declared_version_floor(version, "wrapper declaration"),
        )
      None => ()
    }
    return None
  }
  if host == Windows &&
    (
      executable.to_lower().has_suffix(".bat") ||
      executable.to_lower().has_suffix(".cmd")
    ) {
    return None
  }
  Some(
    probe_version_floor(
      executable,
      DoubleDashVersion,
      "Gradle",
      [9, 6, 1],
      "Gradle",
    ),
  )
}

///|
fn versioned_android_executable(
  root : String,
  relative_executable : String,
  required : Array[Int],
) -> (String, String)? {
  if !path_is_dir(root) {
    return None
  }
  let entries : Array[String] = @fs.read_dir(root) catch { _ => [] }
  let best_version : Ref[Array[Int]?] = Ref(None)
  let best_path = Ref("")
  for entry in entries {
    let version = match first_numeric_version(entry) {
      Some(value) if numeric_version_at_least(value, required) => value
      _ => continue
    }
    let executable = first_executable([
      join_path(root, entry + "/" + relative_executable),
      join_path(root, entry + "/" + relative_executable + ".exe"),
    ])
    guard executable is Some(executable) else { continue }
    let newer = match best_version.val {
      Some(current) => numeric_version_at_least(version, current)
      None => true
    }
    if newer {
      best_version.val = Some(version)
      best_path.val = executable
    }
  }
  match best_version.val {
    Some(version) => Some((best_path.val, numeric_version_text(version)))
    None => None
  }
}

///|
fn json_int(value : Json?) -> Int? {
  match value {
    Some(Number(number, repr=_)) if number.to_int().to_double() == number =>
      Some(number.to_int())
    Some(String(text)) =>
      match first_numeric_version(text) {
        Some([number]) => Some(number)
        _ => None
      }
    _ => None
  }
}

///|
fn harmony_sdk_metadata_text(text : String) -> Result[(Int, String), String] {
  let parsed = @json.parse(text) catch {
    _ => return Err("HarmonyOS SDK metadata is not valid JSON")
  }
  guard parsed is Object(root) else {
    return Err("HarmonyOS SDK metadata must be an object")
  }
  let data = match root.get("data") {
    Some(Object(fields)) => Some(fields)
    _ => None
  }
  let api = match json_int(root.get("apiVersion")) {
    Some(value) => Some(value)
    None =>
      match data {
        Some(fields) => json_int(fields.get("apiVersion"))
        None => None
      }
  }
  let model = match root.get("platformVersion") {
    Some(String(value)) => Some(value)
    _ =>
      match data {
        Some(fields) =>
          match fields.get("platformVersion") {
            Some(String(value)) => Some(value)
            _ => None
          }
        None => None
      }
  }
  guard api is Some(api) else {
    return Err("HarmonyOS SDK metadata is missing apiVersion/platformVersion")
  }
  guard model is Some(model) else {
    return Err("HarmonyOS SDK metadata is missing apiVersion/platformVersion")
  }
  Ok((api, model))
}

///|
fn harmony_sdk_metadata(root : String) -> Result[(Int, String, String), String] {
  let candidates = [
    join_path(root, "sdk-pkg.json"),
    join_path(root, "default/sdk-pkg.json"),
    join_path(parent_dir(root), "sdk-pkg.json"),
  ]
  let invalid = Ref("")
  for path in candidates {
    if !path_is_nonempty_file(path) {
      continue
    }
    let text = @fs.read_file_to_string(path) catch { _ => "" }
    if text == "" {
      invalid.val = path
      continue
    }
    match harmony_sdk_metadata_text(text) {
      Ok((api, model)) => return Ok((api, model, path))
      Err(_) => invalid.val = path
    }
  }
  Err(
    if invalid.val == "" {
      "HarmonyOS SDK apiVersion/platformVersion metadata was not found"
    } else {
      "HarmonyOS SDK metadata is incomplete: " + invalid.val
    },
  )
}

///|
fn harmony_project_contract_text(
  mobile_text : String,
  profile_text : String,
  package_text : String,
) -> Result[String, String] {
  let mobile = @json.parse(mobile_text) catch {
    _ => return Err("moui.mobile.json is not valid JSON")
  }
  guard mobile is Object(mobile_root) else {
    return Err("moui.mobile.json must be an object")
  }
  guard mobile_root.get("harmonyos") is Some(Object(harmony)) else {
    return Err("moui.mobile.json must declare HarmonyOS platform metadata")
  }
  guard json_int(harmony.get("compatibleSdkVersion")) is Some(20) else {
    return Err(
      "moui.mobile.json must declare HarmonyOS compatibleSdkVersion 20",
    )
  }
  let profile = @json.parse(profile_text) catch {
    _ => return Err("HarmonyOS build-profile.json5 is not parseable JSON")
  }
  guard profile is Object(profile_root) else {
    return Err("HarmonyOS build profile must be an object")
  }
  guard profile_root.get("app") is Some(Object(app)) else {
    return Err("HarmonyOS build profile must contain app metadata")
  }
  guard app.get("products") is Some(Array([Object(product), ..])) else {
    return Err("HarmonyOS build profile must contain a product")
  }
  guard product.get("targetSdkVersion") is Some(String("6.0.1(21)")) &&
    product.get("compatibleSdkVersion") is Some(String("6.0.0(20)")) else {
    return Err(
      "HarmonyOS build profile must target 6.0.1(21) with compatibility 6.0.0(20)",
    )
  }
  let package_json = @json.parse(package_text) catch {
    _ => return Err("HarmonyOS oh-package.json5 is not parseable JSON")
  }
  guard package_json is Object(package_root) else {
    return Err("HarmonyOS package metadata must be an object")
  }
  guard package_root.get("modelVersion") is Some(String("6.0.1")) else {
    return Err("HarmonyOS project modelVersion must be 6.0.1")
  }
  Ok("compatibleApi=20 targetApi=21 model=6.0.1")
}

///|
fn harmony_project_contract(project_root : String) -> Result[String, String] {
  let mobile_path = join_path(project_root, "moui.mobile.json")
  let mobile_text = @fs.read_file_to_string(mobile_path) catch {
    _ => return Err("HarmonyOS project metadata is missing: " + mobile_path)
  }
  let template_root = window_template_root(project_root, "harmonyos")
  let profile_path = join_path(template_root, "build-profile.json5")
  let package_path = join_path(template_root, "oh-package.json5")
  let profile_text = @fs.read_file_to_string(profile_path) catch {
    _ => return Err("HarmonyOS build profile is missing: " + profile_path)
  }
  let package_text = @fs.read_file_to_string(package_path) catch {
    _ => return Err("HarmonyOS package metadata is missing: " + package_path)
  }
  harmony_project_contract_text(mobile_text, profile_text, package_text)
}
