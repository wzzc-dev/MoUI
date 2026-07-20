// Android build glue. Migrates `moui_shell/scripts/build-android-apk.sh`
// (99 lines) into MoonBit.
//
// `build_android` prepares the native build inputs (M5), stages the managed
// Gradle template or validates the ejected shell lock (M9.1), invokes
// Gradle via `process_exec_with_inherit`, and copies the produced APK.

///|
priv struct BuildAndroidOptions {
  app : ShellApp
  android_project : String?
  app_config : String
  workspace_root : String
  project_root : String
  moui_root : String
  skia_root : String
  abi : String
  compile_sdk : Int
  target_sdk : Int
  renderer : String
  build_dir : String
  output_apk : String
  fallback_skia : Bool
  ejected_shell : Bool
  prepare_only : Bool
}

///|
priv struct BuildResult {
  platform : String
  build_dir : String
  output_artifact : String
  prepare_result : PrepareResult
}

///|
/// Copy the managed Android Gradle template into `target_project` and write
/// the `.moui-managed-shell` marker so future runs can replace it safely.
/// Mirrors the `cp -R` block at lines 76-84 of `build-android-apk.sh`.
fn stage_managed_android_project(
  template_root : String,
  target_project : String,
) -> Result[Unit, String] {
  let stage_marker = join_path(target_project, ".moui-managed-shell")
  if path_is_dir(target_project) && !path_is_file(stage_marker) {
    return Err(
      "refusing to replace an unowned Android project: " + target_project,
    )
  }
  remove_tree(target_project)
  match mkdir_p(target_project) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  // Recursively copy the template_root/* into target_project.
  match copy_tree(template_root, target_project) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  // Touch the stage marker.
  match write_file_bytes_result(stage_marker, b"") {
    Ok(_) => Ok(())
    Err(message) => Err(message)
  }
}

///|
/// Recursively copy a directory tree from `source` into `target` (which must
/// already exist). Files are byte-copied; symlinks are not followed.
fn copy_tree(source : String, target : String) -> Result[Unit, String] {
  let entries = @fs.read_dir(source) catch {
    _ => return Err("could not read directory: " + source)
  }
  for entry in entries {
    let from = join_path(source, entry)
    let to = join_path(target, entry)
    if path_is_dir(from) {
      match mkdir_p(to) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
      match copy_tree(from, to) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    } else if path_is_file(from) {
      match read_file_bytes_optional(from) {
        Some(bytes) =>
          match write_file_bytes_result(to, bytes) {
            Ok(_) => ()
            Err(message) => return Err(message)
          }
        None => return Err("could not read file: " + from)
      }
    }
  }
  Ok(())
}

///|
/// Locate the Gradle wrapper at `<workspace>/gradlew` or fall back to a
/// `gradle` on PATH. Mirrors the dispatch at line 91 of
/// `build-android-apk.sh`.
fn resolve_gradle_command(
  workspace_root : String,
) -> Result[(String, Array[String]), String] {
  let gradlew = join_path(workspace_root, "gradlew")
  if path_is_executable(gradlew) {
    return Ok((gradlew, []))
  }
  match find_in_path("gradle", detect_host_platform()) {
    Some(path) => Ok((path, []))
    None => Err("Gradle was not found; install Gradle or add a gradlew wrapper")
  }
}

///|
/// Build the Android APK by orchestrating M5 native preparation + Gradle.
/// Mirrors `build-android-apk.sh`.
fn build_android(
  options : BuildAndroidOptions,
  host : HostPlatform,
) -> Result[BuildResult, String] {
  let _ = host // Host is unused on Android; tools are cross-platform.
  // 1. Determine runner_mode and validate ejected lock (if applicable).
  let runner_mode = if options.ejected_shell { "ejected" } else { "managed" }
  let android_project = match options.android_project {
    Some(value) =>
      if path_is_absolute(value) {
        value
      } else {
        join_path(options.workspace_root, value)
      }
    None =>
      if options.ejected_shell {
        return Err("--ejected-shell requires --android-project")
      } else {
        join_path(options.build_dir, "android-project")
      }
  }
  if options.ejected_shell {
    let lock_path = join_path(android_project, ".moui-shell.json")
    match
      validate_ejected_lock(
        lock_path,
        "android",
        options.moui_root,
        join_path(options.moui_root, "../moui_shell"),
        options.project_root,
        options.app_config,
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  } else {
    let template_root = join_path(
      join_path(options.moui_root, "../moui_shell"),
      "android/runner/template",
    )
    match stage_managed_android_project(template_root, android_project) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  // 2. Build the PrepareOptions and call prepare_native_build.
  let contract = match
    managed_platform_contract(
      options.app,
      "android",
      options.workspace_root,
      join_path(options.moui_root, "../moui_shell"),
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let prepare_options : PrepareOptions = {
    app: options.app,
    app_config_path: options.app_config,
    workspace_root: options.workspace_root,
    moui_root: options.moui_root,
    skia_root: options.skia_root,
    build_dir: options.build_dir,
    abi: options.abi,
    android_shell: runner_mode,
    sdk: "",
    arch: "",
    renderer: options.renderer,
    fallback_skia: options.fallback_skia,
    shell_root: join_path(options.moui_root, "../moui_shell"),
    contract,
  }
  let prepare_result = match prepare_native_build(prepare_options) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if options.prepare_only {
    log_info("[moui-shell-android] prepared " + options.build_dir)
    return Ok({
      platform: "android",
      build_dir: options.build_dir,
      output_artifact: "",
      prepare_result,
    })
  }
  // 3. Invoke Gradle with the MoUI project properties.
  let (gradle_cmd, _) = match resolve_gradle_command(options.workspace_root) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let gradle_args = [
    "-p",
    android_project,
    ":app:assembleDebug",
    "-PmouiApp=" + options.app.id,
    "-PmouiAbi=" + options.abi,
    "-PmouiCompileSdk=" + options.compile_sdk.to_string(),
    "-PmouiTargetSdk=" + options.target_sdk.to_string(),
    "-PmouiRenderer=" + options.renderer,
    "-PmouiBuildDir=" + options.build_dir,
    "-PmouiWorkspaceRoot=" + options.workspace_root,
    "-PmouiRoot=" + options.moui_root,
    "-PmouiShellRoot=" + join_path(options.moui_root, "../moui_shell"),
    "-PmouiAppConfig=" + options.app_config,
    "-PmouiAndroidShell=" + runner_mode,
  ]
  let gradle_env = moon_build_env()
  log_command("gradle", [gradle_cmd, ..gradle_args])
  match
    process_exec_argv(
      [gradle_cmd, ..gradle_args],
      cwd=android_project,
      env=gradle_env,
      capture=false,
    ) {
    Ok(result) if result.exit_code == 0 => ()
    Ok(result) =>
      return Err("Gradle failed with exit code " + result.exit_code.to_string())
    Err(message) => return Err(message)
  }
  // 4. Copy APK to output_apk.
  let apk_path = join_path(
    join_path(android_project, "app/build/outputs/apk/debug"),
    "app-debug.apk",
  )
  if !path_is_file(apk_path) {
    return Err("Gradle APK was not found: " + apk_path)
  }
  match mkdir_p(parent_dir(options.output_apk)) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match copy_file_atomic(apk_path, options.output_apk) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  log_info("[moui-shell-android] wrote " + options.output_apk)
  Ok({
    platform: "android",
    build_dir: options.build_dir,
    output_artifact: options.output_apk,
    prepare_result,
  })
}

///|
/// Copy `source` to `target` byte-for-byte. Used to stage the final APK.
fn copy_file_atomic(source : String, target : String) -> Result[Unit, String] {
  match read_file_bytes_optional(source) {
    Some(bytes) => write_file_bytes_result(target, bytes)
    None => Err("could not read source file: " + source)
  }
}
