///|
fn old_host_path() -> String {
  "moui/backend/" + "host"
}

///|
fn old_bridge_path() -> String {
  "moui/backend/" + "platform_bridge"
}

///|
fn event_platforms() -> Array[String] {
  [
    "moui/backend/macos", "moui/backend/windows", "moui/backend/linux", "moui/backend/web",
  ]
}

///|
fn embedded_platforms() -> Array[String] {
  ["moui/backend/android", "moui/backend/ios", "moui/backend/harmonyos"]
}

///|
fn desktop_service_platforms() -> Array[String] {
  ["moui/backend/macos", "moui/backend/windows", "moui/backend/linux"]
}

///|
fn has_import(text : String, path : String) -> Bool {
  text.contains("\"" + path + "\"")
}

///|
fn has_default_import(text : String, path : String) -> Bool {
  let package_token = "\"" + path + "\""
  let mut in_import_block = false
  let mut block_contains_package = false
  for line_view in text.split("\n") {
    let line = line_view.to_owned().trim().to_owned()
    if !in_import_block {
      if line == "import {" {
        in_import_block = true
        block_contains_package = false
      }
    } else {
      if line.contains(package_token) {
        block_contains_package = true
      }
      if line.has_prefix("}") {
        if block_contains_package &&
          !line.contains("for \"test\"") &&
          !line.contains("for \"wbtest\"") {
          return true
        }
        in_import_block = false
        block_contains_package = false
      }
    }
  }
  false
}

///|
fn require_default_import(
  package_path : String,
  pkg : String,
  dependency : String,
  failures : Array[String],
) -> Unit {
  if !has_default_import(pkg, dependency) {
    failures.push(package_path + " must depend on " + dependency)
  }
}

///|
fn reject_default_import(
  package_path : String,
  pkg : String,
  dependency : String,
  failures : Array[String],
) -> Unit {
  if has_default_import(pkg, dependency) {
    failures.push(package_path + " must not depend on " + dependency)
  }
}

///|
fn uses_common_event_owner(text : String) -> Bool {
  text.contains("@window_host.transform_cross_platform_event") ||
  text.contains("@window_host.normalize_pointer_position") ||
  text.contains("@window_host.make_surface_metrics")
}

///|
fn has_shared_event_contract(text : String) -> Bool {
  text.contains("pub(all) enum TransformedWindowEvent") &&
  text.contains("pub(all) enum PlatformSurfaceLifecycle") &&
  text.contains("pub fn transform_cross_platform_event") &&
  text.contains("pub fn make_surface_metrics") &&
  text.contains("pub fn normalize_pointer_position")
}

///|
fn redefined_shared_helper(text : String) -> String? {
  for
    helper in [
      "make_surface_metrics", "normalize_pointer_position", "transform_cross_platform_event",
    ] {
    if text.contains("pub fn " + helper) || text.contains("fn " + helper) {
      return Some(helper)
    }
  }
  None
}

///|
fn collect_platform_sources(
  repo_root : String,
  package_path : String,
  failures : Array[String],
) -> Array[String] {
  let files : Array[String] = []
  collect_mbt_files(repo_root, package_path, files, failures)
  files
}

///|
fn validate_deleted_packages(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  for old in [old_host_path(), old_bridge_path()] {
    if @tools.directory_exists(@tools.resolve_path(repo_root, old)) {
      failures.push(old + " must not exist after backend convergence")
    }
  }
  let internal_path = @tools.resolve_path(repo_root, "moui/backend/internal")
  if @tools.directory_exists(internal_path) {
    failures.push(
      "moui/backend/internal must not remain after common migration",
    )
  }
}

///|
fn validate_common_contract(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let common = "moui/backend/common"
  match read_repo_text(repo_root, common + "/moon.pkg") {
    Ok(pkg) => {
      if !has_import(pkg, "wzzc-dev/moui/backend") {
        failures.push(
          common + " must depend on the root backend protocol package",
        )
      }
      if !has_import(pkg, "wzzc-dev/moui/runtime") ||
        !has_import(pkg, "wzzc-dev/moui/render") {
        failures.push(common + " must own shared runtime/frame implementation")
      }
    }
    Err(message) => failures.push(message)
  }
  match read_repo_text(repo_root, common + "/window_event_transformer.mbt") {
    Ok(source) if has_shared_event_contract(source) => ()
    Ok(_) => failures.push(common + " shared event contract is incomplete")
    Err(message) => failures.push(message)
  }
  for child in ["desktop", "embedded", "native"] {
    let path = common + "/" + child
    if !@tools.directory_exists(@tools.resolve_path(repo_root, path)) {
      failures.push(path + " is missing")
    }
  }
  match
    read_repo_text(repo_root, common + "/desktop/service_wire_encoding.mbt") {
    Ok(source) if source.contains("encode_menu_commands") => ()
    Ok(_) => failures.push(common + "/desktop must own desktop wire encoding")
    Err(message) => failures.push(message)
  }
  match
    read_repo_text(
      repo_root,
      common + "/embedded/services/session_transport.mbt",
    ) {
    Ok(source) if source.contains("HostSessionTransport") => ()
    Ok(_) =>
      failures.push(common + "/embedded/services must own session transport")
    Err(message) => failures.push(message)
  }
}

///|
fn validate_protocol_dependency_graph(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  match read_repo_text(repo_root, "moui/backend/moon.pkg") {
    Ok(pkg) => {
      require_default_import(
        "moui/backend", pkg, "wzzc-dev/moui/core", failures,
      )
      for
        forbidden in [
          "wzzc-dev/moui/backend/common", "wzzc-dev/moui/runtime", "wzzc-dev/moui/render",
        ] {
        reject_default_import("moui/backend", pkg, forbidden, failures)
      }
    }
    Err(message) => failures.push(message)
  }
  match read_repo_text(repo_root, "moui/render/moon.pkg") {
    Ok(pkg) => {
      require_default_import("moui/render", pkg, "wzzc-dev/moui/core", failures)
      reject_default_import(
        "moui/render", pkg, "wzzc-dev/moui/backend", failures,
      )
      reject_default_import(
        "moui/render", pkg, "wzzc-dev/moui/render/common", failures,
      )
      for concrete in ["skia", "wgpu", "sun", "canvas2d", "webgpu_adapter"] {
        reject_default_import(
          "moui/render",
          pkg,
          "wzzc-dev/moui/render/" + concrete,
          failures,
        )
      }
    }
    Err(message) => failures.push(message)
  }
  match read_repo_text(repo_root, "moui/render/common/moon.pkg") {
    Ok(pkg) => {
      require_default_import(
        "moui/render/common", pkg, "wzzc-dev/moui/core", failures,
      )
      require_default_import(
        "moui/render/common", pkg, "wzzc-dev/moui/render", failures,
      )
      reject_default_import(
        "moui/render/common", pkg, "wzzc-dev/moui/backend", failures,
      )
      for concrete in ["skia", "wgpu", "sun", "canvas2d", "webgpu_adapter"] {
        reject_default_import(
          "moui/render/common",
          pkg,
          "wzzc-dev/moui/render/" + concrete,
          failures,
        )
      }
    }
    Err(message) => failures.push(message)
  }
  match read_repo_text(repo_root, "moui/backend/common/moon.pkg") {
    Ok(pkg) =>
      require_default_import(
        "moui/backend/common", pkg, "wzzc-dev/moui/backend", failures,
      )
    Err(message) => failures.push(message)
  }
}

///|
fn validate_event_platform(
  repo_root : String,
  package_path : String,
  failures : Array[String],
) -> Unit {
  match read_repo_text(repo_root, package_path + "/moon.pkg") {
    Ok(pkg) if !has_import(pkg, "wzzc-dev/moui/backend/common") =>
      failures.push(package_path + " must import backend/common")
    Ok(_) => ()
    Err(message) => failures.push(message)
  }
  let used = Ref(false)
  for path in collect_platform_sources(repo_root, package_path, failures) {
    match read_repo_text(repo_root, path) {
      Ok(source) => {
        if uses_common_event_owner(source) {
          used.val = true
        }
        match redefined_shared_helper(source) {
          Some(helper) =>
            failures.push(path + " redefines common event helper: " + helper)
          None => ()
        }
      }
      Err(message) => failures.push(message)
    }
  }
  if !used.val {
    failures.push(
      package_path + " does not use backend/common event conversion",
    )
  }
}

///|
fn validate_desktop_services(
  repo_root : String,
  package_path : String,
  failures : Array[String],
) -> Unit {
  match read_repo_text(repo_root, package_path + "/moon.pkg") {
    Ok(pkg) => {
      if !has_import(pkg, "wzzc-dev/moui/backend/common/desktop") {
        failures.push(package_path + " must import backend/common/desktop")
      }
      if !has_import(pkg, "wzzc-dev/moui/backend/common/native") {
        failures.push(package_path + " must import backend/common/native")
      }
      if has_import(pkg, "wzzc-dev/moui/backend/common/embedded/services") {
        failures.push(package_path + " must not import embedded service queues")
      }
    }
    Err(message) => failures.push(message)
  }
}

///|
fn validate_embedded_runtime(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let package_path = "moui/backend/common/embedded"
  match read_repo_text(repo_root, package_path + "/moon.pkg") {
    Ok(pkg) => {
      if !has_import(pkg, "wzzc-dev/moui/backend/common") {
        failures.push(package_path + " must import backend/common")
      }
      if !has_import(pkg, "wzzc-dev/moui/backend/common/embedded/services") {
        failures.push(package_path + " must import embedded services")
      }
    }
    Err(message) => failures.push(message)
  }
  let used = Ref(false)
  for path in collect_platform_sources(repo_root, package_path, failures) {
    match read_repo_text(repo_root, path) {
      Ok(source) => {
        if uses_common_event_owner(source) {
          used.val = true
        }
        match redefined_shared_helper(source) {
          Some(helper) =>
            failures.push(path + " redefines common event helper: " + helper)
          None => ()
        }
      }
      Err(message) => failures.push(message)
    }
  }
  if !used.val {
    failures.push(
      package_path + " does not use backend/common event conversion",
    )
  }
}

///|
fn validate_embedded_platform(
  repo_root : String,
  package_path : String,
  failures : Array[String],
) -> Unit {
  match read_repo_text(repo_root, package_path + "/moon.pkg") {
    Ok(pkg) => {
      if !has_import(pkg, "wzzc-dev/moui/backend/common/embedded") {
        failures.push(package_path + " must import backend/common/embedded")
      }
      if has_import(pkg, "wzzc-dev/moui/backend/common/embedded/services") {
        failures.push(
          package_path + " must not import embedded service queues directly",
        )
      }
    }
    Err(message) => failures.push(message)
  }
  for path in collect_platform_sources(repo_root, package_path, failures) {
    match read_repo_text(repo_root, path) {
      Ok(source) =>
        match redefined_shared_helper(source) {
          Some(helper) =>
            failures.push(path + " redefines common event helper: " + helper)
          None => ()
        }
      Err(message) => failures.push(message)
    }
  }
}

///|
fn validate_wechat(repo_root : String, failures : Array[String]) -> Unit {
  for
    path in collect_platform_sources(repo_root, "moui/backend/wechat", failures) {
    match read_repo_text(repo_root, path) {
      Ok(source) => {
        if source.contains("WindowEvent") {
          failures.push(
            path + " violates the WeChat direct-canvas callback boundary",
          )
        }
        match redefined_shared_helper(source) {
          Some(helper) =>
            failures.push(path + " redefines common event helper: " + helper)
          None => ()
        }
      }
      Err(message) => failures.push(message)
    }
  }
}

///|
fn validate_repository(repo_root : String) -> Array[String] {
  let failures : Array[String] = []
  validate_deleted_packages(repo_root, failures)
  validate_protocol_dependency_graph(repo_root, failures)
  validate_common_contract(repo_root, failures)
  for platform in event_platforms() {
    validate_event_platform(repo_root, platform, failures)
  }
  for platform in desktop_service_platforms() {
    validate_desktop_services(repo_root, platform, failures)
  }
  validate_embedded_runtime(repo_root, failures)
  for platform in embedded_platforms() {
    validate_embedded_platform(repo_root, platform, failures)
  }
  validate_wechat(repo_root, failures)
  failures
}

///|
test "common boundary predicates recognize the converged package layout" {
  inspect(
    has_import(
      "import { \"wzzc-dev/moui/backend/common\" }", "wzzc-dev/moui/backend/common",
    ),
    content="true",
  )
  inspect(
    uses_common_event_owner("@window_host.transform_cross_platform_event"),
    content="true",
  )
  inspect(
    has_shared_event_contract(
      "pub(all) enum TransformedWindowEvent\n" +
      "pub(all) enum PlatformSurfaceLifecycle\n" +
      "pub fn transform_cross_platform_event\n" +
      "pub fn make_surface_metrics\n" +
      "pub fn normalize_pointer_position",
    ),
    content="true",
  )
}

///|
test "common boundary rejects duplicated shared helper definitions" {
  inspect(
    redefined_shared_helper("fn normalize_pointer_position() -> Unit { () }").unwrap(),
    content="normalize_pointer_position",
  )
}

///|
test "dependency checks distinguish production and test imports" {
  let pkg =
    #|import {
    #|  "wzzc-dev/moui/core",
    #|}
    #|
    #|import {
    #|  "wzzc-dev/moui/runtime",
    #|  "wzzc-dev/moui/render/common",
    #|} for "test"
  inspect(has_default_import(pkg, "wzzc-dev/moui/core"), content="true")
  inspect(has_default_import(pkg, "wzzc-dev/moui/runtime"), content="false")
  inspect(
    has_default_import(pkg, "wzzc-dev/moui/render/common"),
    content="false",
  )
}
