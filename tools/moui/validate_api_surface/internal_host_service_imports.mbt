///|
fn embedded_runtime_internal_package_token() -> String {
  "wzzc-dev/moui/backend/common/embedded"
}

///|
fn allowed_embedded_runtime_internal_imports() -> Array[String] {
  [
    "moui/backend/android/moon.pkg", "moui/backend/ios/moon.pkg", "moui/backend/harmonyos/moon.pkg",
  ]
}

///|
fn desktop_host_services_internal_package_token() -> String {
  "wzzc-dev/moui/backend/common/services/desktop"
}

///|
fn allowed_desktop_host_services_internal_imports() -> Array[String] {
  [
    "moui/backend/macos/moon.pkg", "moui/backend/windows/moon.pkg", "moui/backend/linux/moon.pkg",
  ]
}

///|
fn embedded_host_services_internal_package_token() -> String {
  "wzzc-dev/moui/backend/common/services/embedded"
}

///|
fn allowed_embedded_host_services_internal_imports() -> Array[String] {
  ["moui/backend/common/embedded/moon.pkg"]
}

///|
fn native_host_services_internal_package_token() -> String {
  "wzzc-dev/moui/backend/common/services/native"
}

///|
fn allowed_native_host_services_internal_imports() -> Array[String] {
  [
    "moui/backend/common/services/desktop/moon.pkg", "moui/backend/macos/moon.pkg",
    "moui/backend/windows/moon.pkg", "moui/backend/linux/moon.pkg",
  ]
}

///|
fn native_image_source_internal_package_token() -> String {
  "wzzc-dev/moui/backend/common/image/native"
}

///|
fn allowed_native_image_source_internal_imports() -> Array[String] {
  [
    "moui/backend/common/embedded/moon.pkg", "moui/backend/macos/moon.pkg", "moui/backend/windows/moon.pkg",
    "moui/backend/linux/moon.pkg",
  ]
}

///|
fn validate_embedded_runtime_internal_import_text(
  path : String,
  text : String,
  failures : Array[String],
) -> Unit {
  if text.contains("\"" + embedded_runtime_internal_package_token() + "\"") &&
    !allowed_embedded_runtime_internal_imports().contains(path) {
    failures.push(
      path +
      ": internal embedded runtime session may only be imported by Android, iOS, and HarmonyOS backends",
    )
  }
}

///|
fn validate_embedded_runtime_internal_imports(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let paths : Array[String] = []
  collect_moon_pkg_files(repo_root, "moui", paths, failures)
  let mut import_count = 0
  for path in paths {
    let text = match read_repo_text(repo_root, path) {
      Ok(value) => value
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    if text.contains("\"" + embedded_runtime_internal_package_token() + "\"") {
      import_count += 1
    }
    validate_embedded_runtime_internal_import_text(path, text, failures)
  }
  println("api surface: embedded runtime imports=\{import_count}/3")
}

///|
fn validate_internal_package_imports(
  repo_root : String,
  token : String,
  owner : String,
  allowed : Array[String],
  failures : Array[String],
) -> Unit {
  let paths : Array[String] = []
  collect_moon_pkg_files(repo_root, "moui", paths, failures)
  let mut import_count = 0
  for path in paths {
    let text = match read_repo_text(repo_root, path) {
      Ok(value) => value
      Err(message) => {
        failures.push(message)
        continue
      }
    }
    if text.contains("\"" + token + "\"") {
      import_count += 1
      if !allowed.contains(path) {
        failures.push(path + ": internal " + owner + " import is forbidden")
      }
    }
  }
  println(
    "api surface: " + owner + " imports=\{import_count}/\{allowed.length()}",
  )
}

///|
fn validate_host_service_internal_imports(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  validate_internal_package_imports(
    repo_root,
    desktop_host_services_internal_package_token(),
    "desktop host services",
    allowed_desktop_host_services_internal_imports(),
    failures,
  )
  validate_internal_package_imports(
    repo_root,
    embedded_host_services_internal_package_token(),
    "embedded host services",
    allowed_embedded_host_services_internal_imports(),
    failures,
  )
  validate_internal_package_imports(
    repo_root,
    native_host_services_internal_package_token(),
    "native host services",
    allowed_native_host_services_internal_imports(),
    failures,
  )
  validate_internal_package_imports(
    repo_root,
    native_image_source_internal_package_token(),
    "native image source",
    allowed_native_image_source_internal_imports(),
    failures,
  )
}
