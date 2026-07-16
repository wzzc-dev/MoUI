///|
fn validate_mobile_app_json(
  repo_root : String,
  app_id : String,
  text : String,
) -> Array[String] {
  let failures : Array[String] = []
  let root = match parse_json_object(text) {
    Ok(fields) => fields
    Err(_) => {
      failures.push(app_id + " mobile.json contains invalid JSON")
      return failures
    }
  }
  let schema = match json_int(root.get("schemaVersion")) {
    Some(value) => value
    None => {
      failures.push(app_id + " schemaVersion must be a number")
      return failures
    }
  }
  if schema != 2 {
    failures.push(
      app_id +
      ": schemaVersion 1 is deprecated and requires the explicit legacy config flag; set MOUI_MOBILE_ALLOW_LEGACY_CONFIG=1 for the Release N compatibility path",
    )
    return failures
  }
  match json_string(root.get("id")) {
    Some(id) =>
      if id != app_id {
        failures.push(app_id + " mobile.json id must match directory app id")
      }
    None => failures.push(app_id + " id must be a string")
  }
  let app_package = match json_string(root.get("appPackage")) {
    Some(value) => value
    None => {
      failures.push(app_id + " appPackage must be a non-empty string")
      ""
    }
  }
  if app_package != "" {
    require_path(repo_root, failures, app_id + ".appPackage", app_package)
  }
  let android = json_object(root.get("android"))
  let ios = json_object(root.get("ios"))
  let harmonyos = json_object(root.get("harmonyos"))
  if android is None && ios is None && harmonyos is None {
    failures.push(
      app_id + ": at least one of android, ios, or harmonyos must be configured",
    )
  }
  match android {
    Some(fields) => {
      require_path(
        repo_root,
        failures,
        app_id + ".android.moonPackage",
        managed_moon_package(repo_root, app_id, "android"),
      )
      require_path(
        repo_root,
        failures,
        app_id + ".androidShell",
        "moui/mobile/android/template",
      )
      match json_string(fields.get("applicationId")) {
        Some(application_id) =>
          if !valid_android_application_id(application_id) {
            failures.push(
              app_id +
              ".android.applicationId is not a valid Android application id",
            )
          }
        None =>
          failures.push(app_id + ".android.applicationId must be a string")
      }
      let shell_mode = match json_string(fields.get("shellMode")) {
        Some(value) => value
        None => "legacy"
      }
      let min_sdk = match json_int(fields.get("minSdk")) {
        Some(value) => value
        None => 0
      }
      let native_library = "moui_" + safe_app_id(app_id) + "_android"
      if !valid_native_library(native_library) {
        failures.push(
          app_id +
          ".android.nativeLibrary must contain only letters, numbers, and underscores",
        )
      }
      if shell_mode == "managed" && min_sdk < 23 {
        failures.push(app_id + ".android.minSdk must be at least 23")
      }
    }
    None => ()
  }
  match ios {
    Some(fields) => {
      require_path(
        repo_root,
        failures,
        app_id + ".ios.moonPackage",
        managed_moon_package(repo_root, app_id, "ios"),
      )
      require_path(
        repo_root,
        failures,
        app_id + ".ios.infoPlist",
        "moui/mobile/ios/template/Info.plist",
      )
      require_path(
        repo_root,
        failures,
        app_id + ".iosShell",
        "moui/mobile/ios/template",
      )
      match json_string(fields.get("bundleId")) {
        Some(bundle_id) =>
          if !valid_bundle_id(bundle_id) {
            failures.push(app_id + ".ios.bundleId is not a valid bundle id")
          }
        None => failures.push(app_id + ".ios.bundleId must be a string")
      }
      let shell_mode = match json_string(fields.get("shellMode")) {
        Some(value) => value
        None => "legacy"
      }
      let deployment = match json_string(fields.get("deploymentTarget")) {
        Some(value) => value
        None => "0"
      }
      if shell_mode == "managed" && parse_float_prefix(deployment) < 15.0 {
        failures.push(app_id + ".ios.deploymentTarget must be at least 15.0")
      }
    }
    None => ()
  }
  match harmonyos {
    Some(fields) => {
      require_path(
        repo_root,
        failures,
        app_id + ".harmonyos.moonPackage",
        managed_moon_package(repo_root, app_id, "harmonyos"),
      )
      require_path(
        repo_root,
        failures,
        app_id + ".harmonyosShell",
        "moui/mobile/harmonyos/template",
      )
      match json_string(fields.get("bundleName")) {
        Some(bundle_name) =>
          if !valid_bundle_id(bundle_name) {
            failures.push(
              app_id + ".harmonyos.bundleName is not a valid bundle name",
            )
          }
        None => failures.push(app_id + ".harmonyos.bundleName must be a string")
      }
      let native_library = "moui_mobile_harmonyos"
      if !valid_native_library(native_library) {
        failures.push(
          app_id +
          ".harmonyos.nativeLibrary must contain only letters, numbers, and underscores",
        )
      }
      let shell_mode = match json_string(fields.get("shellMode")) {
        Some(value) => value
        None => "legacy"
      }
      let sdk = match json_int(fields.get("compatibleSdkVersion")) {
        Some(value) => value
        None => 0
      }
      if shell_mode == "managed" && sdk < 20 {
        failures.push(
          app_id + ".harmonyos.compatibleSdkVersion must be at least 20",
        )
      }
    }
    None => ()
  }
  failures
}

///|
fn validate_discovered_apps(
  repo_root : String,
) -> (Array[String], Array[String]) {
  let failures : Array[String] = []
  let ids = discover_example_mobile_ids(repo_root)
  for app_id in ids {
    let path = "examples/" + app_id + "/mobile.json"
    match read_repo_text(repo_root, path) {
      Ok(text) =>
        for failure in validate_mobile_app_json(repo_root, app_id, text) {
          failures.push(failure)
        }
      Err(message) => failures.push(message)
    }
  } nobreak {
    ()
  }
  (ids, failures)
}
