///|
fn read_text(root : String, relative : String) -> String? {
  let path = @tools.resolve_path(root, relative)
  if !@tools.file_exists(path) {
    return None
  }
  match @tools.read_required_text(path, relative) {
    Ok(text) => Some(text)
    Err(_) => Some("")
  }
}

///|
fn package_imports(
  root : String,
  package_path : String,
  dependency : String,
) -> Bool {
  match read_text(root, package_path + "/moon.pkg") {
    Some(text) => text.contains("\"" + dependency + "\"")
    None => false
  }
}

///|
fn reject_tokens_in_package(
  root : String,
  package_path : String,
  tokens : Array[String],
  failures : Array[String],
) -> Unit {
  let directory = @tools.resolve_path(root, package_path)
  if !@tools.directory_exists(directory) {
    failures.push(package_path + " is missing")
    return
  }
  let entries : Array[String] = @fs.read_dir(directory) catch { _ => [] }
  for entry in entries {
    if entry.has_suffix(".mbt") || entry.has_suffix(".mbti") {
      match read_text(root, package_path + "/" + entry) {
        Some(text) =>
          for token in tokens {
            if text.contains(token) {
              failures.push(
                package_path +
                "/" +
                entry +
                " retains forbidden physical lifecycle state: " +
                token,
              )
            }
          }
        None => ()
      }
    }
  }
}

///|
fn validate_deleted_packages(root : String, failures : Array[String]) -> Unit {
  for old in ["moui/backend/" + "host", "moui/backend/" + "platform_bridge"] {
    if @tools.directory_exists(@tools.resolve_path(root, old)) {
      failures.push(old + " must be removed")
    }
  }
  if @tools.directory_exists(@tools.resolve_path(root, "moui/backend/internal")) {
    failures.push("moui/backend/internal must be removed")
  }
}

///|
fn validate_window_common(root : String, failures : Array[String]) -> Unit {
  let common = "moui/backend/common"
  match read_text(root, common + "/lifecycle/window_lifecycle_core.mbt") {
    Some(text) if text.contains("WindowLifecycleCore") &&
      text.contains("begin_close") &&
      text.contains("finish_close") &&
      text.contains("rollback") => ()
    _ => failures.push(common + " must define the private WindowLifecycleCore")
  }
  match read_text(root, common + "/frame/window_frame_state.mbt") {
    Some(text) if text.contains("WindowFrameState") &&
      text.contains("finish_presented") &&
      text.contains("dispose") => ()
    _ => failures.push(common + "/frame must define WindowFrameState")
  }
  match read_text(root, common + "/lifecycle/embedded_lifecycle.mbt") {
    Some(text) if text.contains("EmbeddedLifecycle") &&
      text.contains("mut generation") &&
      text.contains("mut primary_window") &&
      text.contains("mut exit_intent") => ()
    _ => failures.push(common + "/lifecycle must define EmbeddedLifecycle")
  }
  match read_text(root, common + "/window_host_workflows.mbt") {
    Some(text) if text.contains("pub fn attach_window_surface") &&
      text.contains("pub fn dispose_window") &&
      !text.contains("struct WindowCoordinator") => ()
    _ => failures.push(common + " must expose stateless window-host workflows")
  }
  match read_text(root, common + "/lifecycle/window_slot.mbt") {
    Some(text) if !text.contains("platform_id :") &&
      !text.contains("lookup_platform") => ()
    _ =>
      failures.push(
        "common WindowSlotMap must be keyed only by backend WindowId",
      )
  }
}

///|
fn validate_window_dispatch(root : String, failures : Array[String]) -> Unit {
  let dispatch_path = @tools.resolve_path(
    root, "window/modules/window/internal/embedded_dispatch",
  )
  if !@tools.directory_exists(dispatch_path) {
    failures.push("window/internal/embedded_dispatch is missing")
  }
  let window_forbidden = [
    "EmbeddedHostKernel", "surface_generation", "physical_surface_generation", "primary_window",
    "exit_intent", "mut generation : Int",
  ]
  for
    package_path in [
      "window/modules/window/android", "window/modules/window/ios", "window/modules/window/harmonyos",
    ] {
    reject_tokens_in_package(root, package_path, window_forbidden, failures)
  }
  reject_tokens_in_package(
    root,
    "window/modules/window/internal/embedded_dispatch",
    [
      "EmbeddedHostKernel", "surface_generation", "physical_surface_generation",
      "primary_window", "exit_intent", "mut generation : Int", "register_window(",
      "set_primary_window(", "unregister_window(",
    ],
    failures,
  )
}

///|
fn validate_platform_entries(root : String, failures : Array[String]) -> Unit {
  for
    platform in [
      "moui/backend/macos", "moui/backend/windows", "moui/backend/linux", "moui/backend/web",
    ] {
    if !package_imports(root, platform, "wzzc-dev/moui/backend/common") {
      failures.push(platform + " must enter backend/common")
    }
  }
  for
    platform in [
      "moui/backend/android", "moui/backend/ios", "moui/backend/harmonyos",
    ] {
    if !package_imports(root, platform, "wzzc-dev/moui/backend/common/embedded") {
      failures.push(platform + " must enter backend/common/embedded")
    }
  }
  if @tools.directory_exists(@tools.resolve_path(root, "moui/runtime")) {
    let entries : Array[String] = @fs.read_dir(
      @tools.resolve_path(root, "moui/runtime"),
    ) catch {
      _ => []
    }
    for entry in entries {
      if entry.has_suffix(".mbt") {
        match read_text(root, "moui/runtime/" + entry) {
          Some(text) if text.contains("WindowLifecycle") ||
            text.contains("EmbeddedLifecycle") ||
            text.contains("WindowSurfaceActions") =>
            failures.push(
              "moui/runtime/" + entry + " retains backend/common ownership",
            )
          _ => ()
        }
      }
    }
  }
}

///|
fn validate_embedded_session(root : String, failures : Array[String]) -> Unit {
  let package_path = "moui/backend/common/embedded"
  match read_text(root, package_path + "/embedded_runtime_backend.mbt") {
    Some(text) if text.contains("@window_frame.WindowFrameState::new") &&
      text.contains("@window_image.WindowImageState::new") => ()
    _ =>
      failures.push("embedded sessions must compose the frame and image owners")
  }
  match read_text(root, package_path + "/embedded_runtime_backend.mbt") {
    Some(text) if text.contains(
        "transport.attach(surface_epoch=surface_generation)",
      ) => ()
    _ =>
      failures.push(
        "embedded transport must consume the common lifecycle generation",
      )
  }
  match
    read_text(
      root, "moui/backend/common/services/embedded/session_transport.mbt",
    ) {
    Some(text) if text.contains("HostSession::attach(") &&
      text.contains("surface_epoch~ : Int") &&
      !text.contains("self.surface_epoch = self.surface_epoch + 1") => ()
    _ =>
      failures.push(
        "embedded transport must project, not mint, the surface epoch",
      )
  }
  let embedded_dir = @tools.resolve_path(root, package_path)
  if @tools.directory_exists(embedded_dir) {
    let entries : Array[String] = @fs.read_dir(embedded_dir) catch { _ => [] }
    for entry in entries {
      if entry.has_suffix(".mbt") {
        match read_text(root, package_path + "/" + entry) {
          Some(text) if text.contains("struct EmbeddedImageCoordinator") ||
            text.contains("struct EmbeddedFrameCoordinator") =>
            failures.push(package_path + " retains duplicate frame/image state")
          _ => ()
        }
      }
    }
  }
}

///|
fn validate_window_lifecycle_boundary(root : String) -> Array[String] {
  let failures : Array[String] = []
  validate_deleted_packages(root, failures)
  validate_window_common(root, failures)
  validate_window_dispatch(root, failures)
  validate_platform_entries(root, failures)
  validate_embedded_session(root, failures)
  failures
}
