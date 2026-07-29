// Window-hosted Android packaging.
// Android APK packaging now uses the window-hosted template at
// `window/modules/window/android/template/` +
// `examples/<app>/android_window_hosted` entrypoint.
//
// `build_android` generates MoonBit C, stages the window-hosted Gradle
// template, applies app identity (applicationId, namespace, label), and
// invokes `gradle :app:assembleDebug` with the `MBW_*` project properties
// consumed by the template's `app/src/main/cpp/CMakeLists.txt`.

///|
priv struct BuildAndroidOptions {
  app : MobileApp
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
  prepare_only : Bool
}

///|
priv struct BuildResult {
  platform : String
  build_dir : String
  output_artifact : String
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
/// `gradle` on PATH. Mirrors the dispatch at lines 48-59 of
/// `window/modules/window/android/scripts/build-hosted-apk.sh`.
fn resolve_gradle_command(
  workspace_root : String,
) -> Result[(String, Array[String]), String] {
  // Prefer a previously staged Gradle wrapper inside an existing Android
  // project (e.g. artifacts/android/<app>/android-project/gradlew). This
  // mirrors the upstream script's first lookup.
  let staged_gradlew = join_path(
    join_path(workspace_root, "artifacts/android"),
    "android-project/gradlew",
  )
  if path_is_executable(staged_gradlew) {
    return Ok((staged_gradlew, []))
  }
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
/// Stage the window-hosted Android Gradle template into `target_project` and
/// write the `.moui-window-hosted-stage` marker so future runs can replace
/// it safely.
fn stage_android_window_hosted_project(
  template_root : String,
  target_project : String,
) -> Result[Unit, String] {
  let stage_marker = join_path(target_project, ".moui-window-hosted-stage")
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
  match copy_tree(template_root, target_project) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match write_file_bytes_result(stage_marker, b"") {
    Ok(_) => Ok(())
    Err(message) => Err(message)
  }
}

///|
/// Apply mobile app identity onto a staged window-hosted Android template.
/// Patches `app/build.gradle` (applicationId, namespace) and
/// `app/src/main/AndroidManifest.xml` (android:label).
fn apply_android_window_hosted_identity(
  project_root : String,
  app : MobileApp,
  compile_sdk : Int,
  target_sdk : Int,
  _renderer : String,
) -> Result[Unit, String] {
  let android = match app.android {
    Some(value) => value
    None => return Err("moui.mobile.json missing android section")
  }
  let application_id = android.application_id
  // Patch app/build.gradle: namespace, applicationId, compileSdk, targetSdk, minSdk.
  let app_gradle_path = join_path(project_root, "app/build.gradle")
  let app_gradle_text = match read_file_string_optional(app_gradle_path) {
    Some(value) => value
    None => return Err("could not read: " + app_gradle_path)
  }
  let patched_gradle = patch_android_build_gradle(
    app_gradle_text,
    application_id,
    application_id,
    compile_sdk,
    target_sdk,
    android.min_sdk,
    app.display_name,
  )
  match
    write_file_bytes_result(
      app_gradle_path,
      @utf8.encode(patched_gradle[:], bom=false),
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  // Patch AndroidManifest.xml android:label.
  let manifest_path = join_path(
    project_root, "app/src/main/AndroidManifest.xml",
  )
  match read_file_string_optional(manifest_path) {
    Some(manifest_text) => {
      let patched = patch_android_manifest_label(
        manifest_text,
        app.display_name,
      )
      match
        write_file_bytes_result(
          manifest_path,
          @utf8.encode(patched[:], bom=false),
        ) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
    None => () // Tolerate missing manifest (template guarantees it).
  }
  log_info(
    "[moui-window-hosted-android] Applied identity applicationId=" +
    application_id,
  )
  Ok(())
}

///|
/// Patch `namespace = "..."` and `applicationId = "..."` and SDK versions
/// inside a window-hosted `app/build.gradle` template. Rewrites the lines
/// in place; preserves all other Gradle content.
fn patch_android_build_gradle(
  text : String,
  application_id : String,
  mo_namespace : String,
  compile_sdk : Int,
  target_sdk : Int,
  min_sdk : Int,
  app_label : String,
) -> String {
  let out : Array[String] = []
  for line_view in text.split("\n") {
    let line = line_view.to_owned()
    let trimmed = line.trim().to_owned()
    if trimmed.has_prefix("namespace =") {
      out.push("    namespace = \"" + mo_namespace + "\"")
    } else if trimmed.has_prefix("applicationId =") {
      out.push("        applicationId = \"" + application_id + "\"")
    } else if trimmed.has_prefix("compileSdk =") {
      out.push("    compileSdk = " + compile_sdk.to_string())
    } else if trimmed.has_prefix("minSdk =") {
      out.push("        minSdk = " + min_sdk.to_string())
    } else if trimmed.has_prefix("targetSdk =") {
      out.push("        targetSdk = " + target_sdk.to_string())
    } else if line.contains("android:label=") {
      // Replace any `android:label="..."` literal on this line.
      out.push(patch_android_label_inline(line, app_label))
    } else {
      out.push(line)
    }
  }
  out.join("\n")
}

///|
/// Replace `android:label="..."` substring within a single line, returning
/// the patched line. Used as a non-regex fallback for
/// `patch_android_build_gradle`.
fn patch_android_label_inline(line : String, label : String) -> String {
  let marker = "android:label=\""
  let pos = line.find(marker)
  match pos {
    None => line
    Some(start) => {
      let after_start = start + marker.length()
      let after = line[after_start:]
      let end_rel = after.find("\"")
      match end_rel {
        None => line
        Some(end) => {
          // Reconstruct: <prefix up to and including opening quote> + label +
          // <closing quote> + <remainder after original closing quote>.
          let prefix = line[:after_start].to_owned()
          let suffix = after[end + 1:].to_owned()
          prefix + label + "\"" + suffix
        }
      }
    }
  }
}

///|
/// Patch `android:label="..."` in an AndroidManifest.xml document. Falls
/// back to inline line-by-line replacement when no label attribute is
/// present.
fn patch_android_manifest_label(text : String, label : String) -> String {
  let lines : Array[String] = []
  for line_view in text.split("\n") {
    lines.push(line_view.to_owned())
  }
  let out : Array[String] = []
  let mut patched = false
  for line in lines {
    if line.contains("android:label=") {
      out.push(patch_android_label_inline(line, label))
      patched = true
    } else {
      out.push(line)
    }
  }
  if !patched {
    // Inject `android:label` on the first `<application` line we find.
    let injected : Array[String] = []
    let mut did_inject = false
    for line in lines {
      if !did_inject && line.contains("<application") {
        // Insert attribute before the closing `>` of this line.
        let idx = line.find(">")
        match idx {
          Some(pos) => {
            injected.push(
              line[:pos].to_owned() +
              " android:label=\"" +
              label +
              "\"" +
              line[pos:].to_owned(),
            )
            did_inject = true
          }
          None => injected.push(line)
        }
      } else {
        injected.push(line)
      }
    }
    return injected.join("\n")
  }
  out.join("\n")
}

///|
/// Build the Android APK by orchestrating MoonBit C generation + Gradle.
/// Mirrors `window/modules/window/android/scripts/build-hosted-apk.sh`.
fn build_android(
  options : BuildAndroidOptions,
  host : HostPlatform,
) -> Result[BuildResult, String] {
  let _ = host
  // Make build_dir + workspace_root absolute so MBW_* project properties
  // passed to Gradle (which runs with cwd=android-project) resolve
  // correctly regardless of the user's original cwd.
  let workspace_root_abs = make_absolute(
    options.workspace_root,
    @env.get_env_var("PWD").unwrap_or("."),
  )
  let build_dir_abs = make_absolute(options.build_dir, workspace_root_abs)
  // 2. Resolve the upstream window package root and template.
  let window_root = window_package_root(workspace_root_abs)
  let template_root = window_template_root(workspace_root_abs, "android")
  if !path_is_file(join_path(template_root, "app/src/main/cpp/CMakeLists.txt")) ||
    !path_is_file(join_path(template_root, "app/build.gradle")) ||
    !path_is_file(join_path(template_root, "settings.gradle")) {
    return Err(
      "MoUI window-hosted Android template is incomplete: " + template_root,
    )
  }
  // 3. Generate MoonBit C from the entrypoint package.
  let entrypoint_package = match
    mobile_entrypoint_package(
      options.app.metadata_path,
      "android",
      workspace_root_abs,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let moonbit_c = match
    generate_moonbit_c(
      workspace_root_abs,
      entrypoint_package,
      base_name(entrypoint_package) + ".c",
      build_dir_abs,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if !path_is_file(moonbit_c) {
    return Err("MoonBit generated C was not found: " + moonbit_c)
  }
  // Resolve real Skia link flags via `node moui_skia/build.js`. Mirrors the
  // iOS path in `build_ios.mbt`: when fallback_skia is false, build.js returns
  // `-DMOUI_SKIA_HAS_SKIA ...` (stub_flags) + `libskia.a` or `-lskia` plus
  // Android runtime libs (link_flags). When fallback_skia is true, returns an
  // empty SkiaLink and the stubs link without `MOUI_SKIA_HAS_SKIA`, so
  // `skia_available()` returns false at runtime — the stub-only build-evidence
  // path that presents a black surface.
  let skia_arch = match
    lookup_static_map(android_abi_to_skia_arch, options.abi) {
    Some(value) => value
    None => return Err("unsupported Android ABI: " + options.abi)
  }
  let renderer_selected = if options.fallback_skia {
    "skia-raster"
  } else if options.renderer == "skia-raster" {
    "skia-raster"
  } else {
    "skia-gpu"
  }
  let link_mode = @env.get_env_var("MOUI_SKIA_LINK_MODE").unwrap_or_else(() => {
    if renderer_selected == "skia-gpu" {
      "static"
    } else {
      "dynamic"
    }
  })
  let gpu_env : Array[(String, String)] = if renderer_selected == "skia-gpu" {
    [("MOUI_SKIA_ENABLE_GPU_VULKAN", "1"), ("MOUI_SKIA_ENABLE_GPU_EGL", "1")]
  } else {
    []
  }
  let skia_root_abs = make_absolute(options.skia_root, workspace_root_abs)
  let skia_link = match
    resolve_skia(
      skia_root_abs,
      "android",
      skia_arch,
      link_mode,
      options.fallback_skia,
      gpu_env,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  // Write Skia flags into response files so the CMake template can read them
  // via `file(READ ...)` + `separate_arguments`. Direct `-D` passing through
  // Gradle `externalNativeBuild.cmake.arguments` would split on spaces and
  // break `-I/path with spaces` and multi-flag stub strings.
  let native_dir = join_path(build_dir_abs, "native")
  let skia_cxx_rsp = join_path(native_dir, "skia-cxx-flags.rsp")
  let skia_link_rsp = join_path(native_dir, "skia-link-flags.rsp")
  match write_rsp(skia_cxx_rsp, skia_link.stub_flags) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match write_rsp(skia_link_rsp, skia_link.link_flags) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  // When the dynamic Skia link mode is selected, `libskia.so` must be packaged
  // into the APK's jniLibs/<abi>/ directory. The static link mode embeds Skia
  // into libwindow_android_app.so and needs no extra packaging.
  let jni_libs_dir : String? = if contains_flag(skia_link.link_flags, "-lskia") {
    let dir = join_path(build_dir_abs, "jniLibs")
    let sdk_root = android_sdk_home()
    if sdk_root != "" {
      let ndk_home = resolve_android_ndk_home(sdk_root)
      if ndk_home != "" {
        match
          copy_android_shared_libs(
            options.abi,
            ndk_home,
            skia_link.link_flags,
            dir,
          ) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      }
    }
    Some(dir)
  } else {
    None
  }
  // 4. Stage the window-hosted template into <build_dir>/android-project.
  let android_project = join_path(build_dir_abs, "android-project")
  match stage_android_window_hosted_project(template_root, android_project) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    apply_android_window_hosted_identity(
      android_project,
      options.app,
      options.compile_sdk,
      options.target_sdk,
      options.renderer,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  if options.prepare_only {
    log_info(
      "[moui-window-hosted-android] Prepared " +
      build_dir_abs +
      " (moonbit_c=" +
      moonbit_c +
      ")",
    )
    return Ok({
      platform: "android",
      build_dir: build_dir_abs,
      output_artifact: "",
    })
  }
  // 5. Resolve Gradle command.
  let (gradle_cmd, _) = match resolve_gradle_command(workspace_root_abs) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  // 6. Resolve MOON_HOME.
  let moon_home = make_absolute(
    @env.get_env_var("MOON_HOME").unwrap_or_else(() => {
      let home = @env.get_env_var("HOME").unwrap_or("")
      join_path(home, ".moon")
    }),
    workspace_root_abs,
  )
  // 7. Invoke `gradle :app:assembleDebug` with MBW_* project properties.
  let gradle_args = [
    "-p",
    android_project,
    ":app:assembleDebug",
    "-PmbwWorkspaceRoot=" + workspace_root_abs,
    "-PmbwWindowRoot=" + window_root,
    "-PmbwMoonHome=" + moon_home,
    "-PmbwMoonbitC=" + moonbit_c,
    "-PmbwAbi=" + options.abi,
    "-PmbwSkiaCxxRsp=" + skia_cxx_rsp,
    "-PmbwSkiaLinkRsp=" + skia_link_rsp,
    "-PmbwJniLibsDir=" +
    (match jni_libs_dir {
      Some(dir) => dir
      None => ""
    }),
    "--no-daemon",
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
  // 8. Copy APK to output_apk.
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
  log_info("[moui-window-hosted-android] Wrote " + options.output_apk)
  Ok({
    platform: "android",
    build_dir: build_dir_abs,
    output_artifact: options.output_apk,
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
