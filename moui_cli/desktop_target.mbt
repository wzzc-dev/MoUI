// Desktop and web target resolution shared by `moui build`, `moui run`,
// and `moui package`. Entrypoint naming follows the repository convention:
// `<platform>_skia`, `<platform>_wgpu`, `<platform>_sun`, `web_wasm`.
// The positional `<app>` argument is the project directory that holds the
// entrypoint packages (or the entrypoint package directory itself).

///|
priv struct DesktopTarget {
  platform : String
  package_path : String
  target : String
}

///|
fn desktop_platform_supported(platform : String) -> Bool {
  platform == "macos" ||
  platform == "windows" ||
  platform == "linux" ||
  platform == "web"
}

///|
/// Entrypoint package candidates for a desktop/web platform, ordered by
/// preference. `renderer` selects a specific backend ("skia" / "wgpu" /
/// "sun"); "auto" prefers the Skia mainline and falls back to the
/// diagnostic routes when the Skia entrypoint does not exist.
fn desktop_entrypoint_candidates(
  platform : String,
  renderer? : String = "auto",
) -> Result[Array[String], String] {
  if platform == "web" {
    return Ok(["web_wasm"])
  }
  let suffix : String = match renderer {
    "skia" | "auto" => "_skia"
    "wgpu" => "_wgpu"
    "sun" => "_sun"
    other =>
      return Err(
        "unknown renderer for desktop targets: " +
        other +
        " (expected auto / skia / wgpu / sun)",
      )
  }
  let primary = platform + suffix
  let candidates = [primary]
  if renderer == "auto" {
    for fallback in ["_wgpu", "_sun", ""] {
      let name = platform + fallback
      if name != primary {
        candidates.push(name)
      }
    }
  }
  Ok(candidates)
}

///|
fn desktop_entrypoint_exists(root : String, candidate : String) -> Bool {
  let path = join_path(root, candidate)
  @fs.is_dir(path) catch {
    _ => false
  }
}

///|
/// Resolve the entrypoint package for a desktop/web target under the
/// project root that holds the entrypoint packages.
fn resolve_desktop_target(
  app_root : String,
  platform : String,
  renderer? : String = "auto",
) -> Result[DesktopTarget, String] {
  let candidates = match desktop_entrypoint_candidates(platform, renderer~) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  for candidate in candidates {
    if desktop_entrypoint_exists(app_root, candidate) {
      let target = if platform == "web" { "wasm-gc" } else { "native" }
      return Ok({ platform, package_path: candidate, target })
    }
  }
  let expected = candidates.join(", ")
  Err(
    "no " +
    platform +
    " entrypoint package found under " +
    app_root +
    " (expected one of: " +
    expected +
    ")",
  )
}

///|
/// Resolve the project root that holds the entrypoint packages. Accepts
/// either the project directory or an entrypoint package directory such as
/// `windows_skia` / `web_wasm`.
fn resolve_desktop_root(
  base : String,
  app : String,
  platform : String,
  renderer? : String = "auto",
) -> Result[String, String] {
  let root = resolve_path(base, app)
  let candidates = match desktop_entrypoint_candidates(platform, renderer~) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  for candidate in candidates {
    if desktop_entrypoint_exists(root, candidate) {
      return Ok(root)
    }
  }
  // The argument may point at the entrypoint package itself.
  let leaf = base_name(root)
  let is_entrypoint_package = leaf == "web_wasm" ||
    leaf.has_suffix("_skia") ||
    leaf.has_suffix("_wgpu") ||
    leaf.has_suffix("_sun")
  if is_entrypoint_package {
    let has_manifest = @fs.is_file(join_path(root, "moon.pkg")) catch {
      _ => false
    }
    if has_manifest {
      return Ok(parent_dir(root))
    }
  }
  Ok(root)
}

///|
/// Relative path of `target` below `root`, or `target` unchanged when it is
/// not below `root`. Both inputs are normalized before comparison.
fn relative_path_under(root : String, target : String) -> String {
  let root = normalized_path(root)
  let target = normalized_path(target)
  if root == "" || root == "." {
    return target
  }
  let prefix = root + "/"
  if target == root {
    return "."
  }
  if target.has_prefix(prefix) {
    target[prefix.length():].to_owned()
  } else {
    target
  }
}

///|
/// Predicted `moon build` output path for a desktop/web target. `moon` names
/// executables `<package-leaf>.exe` on every host platform.
fn desktop_artifact_path(
  build_base : String,
  package_path : String,
  target : String,
  release? : Bool = false,
) -> String {
  let stage = if release { "release" } else { "debug" }
  let extension = if target == "wasm-gc" { ".wasm" } else { ".exe" }
  join_path(
    build_base,
    "_build/" +
    target +
    "/" +
    stage +
    "/build/" +
    normalized_path(package_path) +
    "/" +
    base_name(package_path) +
    extension,
  )
}

///|
/// The directory `moon build` writes `_build` under: the enclosing workspace
/// root when one exists, otherwise the app root (standalone projects).
fn desktop_build_base(app_root : String) -> String {
  moon_workspace_root(app_root).unwrap_or(app_root)
}

///|
/// Spawn-cwd and package-path pair for `moon build`: moon is invoked from
/// the build base (workspace root) with the package path relative to it.
fn desktop_moon_invocation_for_root(
  app_root : String,
  target : DesktopTarget,
) -> (String, String) {
  let build_base = desktop_build_base(app_root)
  let package_path = relative_path_under(
    build_base,
    join_path(app_root, target.package_path),
  )
  (build_base, package_path)
}

///|
priv struct DesktopFlow {
  app_root : String
  build_base : String
  package_path : String
  target : DesktopTarget
}

///|
/// One-shot resolution for command flows that start from a base directory
/// and a positional `<app>` argument.
fn resolve_desktop_flow(
  base : String,
  app : String,
  platform : String,
  renderer? : String = "auto",
) -> Result[DesktopFlow, String] {
  let app_root = match resolve_desktop_root(base, app, platform, renderer~) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let target = match resolve_desktop_target(app_root, platform, renderer~) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let (build_base, package_path) = desktop_moon_invocation_for_root(
    app_root, target,
  )
  Ok({ app_root, build_base, package_path, target })
}
