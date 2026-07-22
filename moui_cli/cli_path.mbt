///|
/// Convert a relative path to absolute using `base` as the anchor. Absolute
/// paths are returned unchanged.
fn make_absolute(path : String, base : String) -> String {
  if path == "" {
    base
  } else if path_is_absolute(path) {
    path
  } else {
    join_path(base, path)
  }
}

///|
/// Return the local upstream `window` package root used by mobile templates
/// and native glue.
fn window_package_root(workspace_root : String) -> String {
  join_path(workspace_root, "window/modules/window")
}

///|
/// Return the local upstream `window` package root for `platform`.
fn window_platform_root(workspace_root : String, platform : String) -> String {
  join_path(window_package_root(workspace_root), platform)
}

///|
/// Return the local upstream `window` build template for `platform`.
fn window_template_root(workspace_root : String, platform : String) -> String {
  join_path(window_platform_root(workspace_root, platform), "template")
}

///|
/// Return the first existing path among `paths`. Empty strings are skipped.
fn first_existing(paths : Array[String]) -> String? {
  for path in paths {
    if path != "" && path_is_file(path) {
      return Some(path)
    }
  }
  None
}

///|
/// Return the first existing non-empty executable file among `paths`.
fn first_executable(paths : Array[String]) -> String? {
  for path in paths {
    if path != "" && path_is_nonempty_file(path) && path_is_executable(path) {
      return Some(path)
    }
  }
  None
}

///|
/// Split the PATH environment variable using the platform-specific separator
/// (`;` on Windows, `:` elsewhere). Returns an empty array when PATH is unset.
fn path_entries(host : HostPlatform) -> Array[String] {
  match @env.get_env_var("PATH") {
    Some(value) => {
      let separator = if host == Windows { ";" } else { ":" }
      value.split(separator).map(part => part.to_owned()).to_array()
    }
    None => []
  }
}

///|
/// Return the candidate executable file names for `name` on `host`. On
/// Windows, also tries `.exe`, `.cmd`, and `.bat` suffixes.
fn executable_names(name : String, host : HostPlatform) -> Array[String] {
  if host == Windows {
    if name.to_lower().has_suffix(".exe") {
      [name]
    } else {
      [name + ".exe", name + ".cmd", name + ".bat", name]
    }
  } else {
    [name]
  }
}

///|
/// Search for an executable named `name` in every PATH directory. Returns the
/// full path to the first match, or `None` if not found.
fn find_in_path(name : String, host : HostPlatform) -> String? {
  for directory in path_entries(host) {
    let root = if directory == "" { "." } else { directory }
    for candidate in executable_names(name, host) {
      let path = join_path(root, candidate)
      if path_is_nonempty_file(path) && path_is_executable(path) {
        return Some(path)
      }
    }
  }
  None
}

///|
/// Look up `name` in `home/bin` first, then fall back to PATH lookup. `home`
/// may be `None`, in which case this is equivalent to `find_in_path`.
fn find_executable_in_home(
  name : String,
  home : String?,
  host : HostPlatform,
) -> String? {
  match home {
    Some(root) => {
      let candidates : Array[String] = []
      for executable in executable_names(name, host) {
        candidates.push(join_path(root, "bin/" + executable))
      }
      match first_executable(candidates) {
        Some(path) => return Some(path)
        None => ()
      }
    }
    None => ()
  }
  find_in_path(name, host)
}

///|
/// Scan `dir` for a non-empty executable file. Used to locate the `moui`
/// binary inside Moon's target output directory after `moon build`, where
/// Moon names the executable `moui` (Linux) or `moui.exe` (macOS / Windows).
fn find_executable_in_dir(dir : String) -> String? {
  if !path_is_dir(dir) {
    return None
  }
  let entries = @fs.read_dir(dir) catch { _ => return None }
  for entry in entries {
    let candidate = join_path(dir, entry)
    if path_is_nonempty_file(candidate) && path_is_executable(candidate) {
      return Some(candidate)
    }
  }
  None
}

///|
/// Resolve a usable `moui_cli` binary path for tools that need to invoke
/// `moui_cli` as a subprocess (e.g. iOS Xcode Run Script Phase via
/// the window-hosted iOS build template, which invokes `moui_cli`. Fast path:
/// `moui_cli` is on PATH
/// (user installed it). Slow path: build `moui_cli/cmd/moui` to a stable cache
/// dir under `<build_dir>/moui-cli-bin` and return the resulting binary path.
/// Moon's incremental cache makes the slow path near-instant on subsequent
/// runs, but we rebuild when any `moui_cli/*.mbt` source is newer than the
/// cached binary so source changes always flow through.
fn ensure_moui_cli_binary(
  workspace_root : String,
  build_dir : String,
) -> Result[String, String] {
  let host = detect_host_platform()
  // Fast path: `moui_cli` is on PATH (user installed it).
  match find_in_path("moui_cli", host) {
    Some(path) => return Ok(path)
    None => ()
  }
  // Slow path: build to a stable cache dir under <build_dir>/moui-cli-bin.
  let bin_cache_dir = join_path(build_dir, "moui-cli-bin")
  let target_dir = join_path(bin_cache_dir, "target")
  // Moon writes the executable to:
  //   <target_dir>/native/debug/build/wzzc-dev/moui_cli/cmd/moui/<moui|moui.exe>
  let candidate_dir = join_path(
    join_path(join_path(join_path(target_dir, "native"), "debug"), "build"),
    "wzzc-dev/moui_cli/cmd/moui",
  )
  match find_executable_in_dir(candidate_dir) {
    Some(path) =>
      // Invalidate the cache when any source file under `moui_cli/` is
      // newer than the cached binary. Without this, edits to `moui_cli`
      // would not be picked up until the user manually clears the cache.
      if !moui_cli_sources_newer_than(workspace_root, path) {
        return Ok(path)
      } else {
        log_info(
          "[moui-cli] Cached binary is stale; rebuilding from " +
          join_path(workspace_root, "moui_cli"),
        )
      }
    None => ()
  }
  match mkdir_p(bin_cache_dir) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let argv = [
    "moon", "build", "moui_cli/cmd/moui", "--target", "native", "--target-dir", target_dir,
  ]
  log_command("ensure_moui_cli_binary", argv)
  let env = moon_build_env()
  let result = match
    process_exec_argv(argv, cwd=workspace_root, env~, capture=false) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  if result.exit_code != 0 {
    return Err(
      "moon build moui_cli/cmd/moui failed with exit code " +
      result.exit_code.to_string(),
    )
  }
  match find_executable_in_dir(candidate_dir) {
    Some(path) => Ok(path)
    None =>
      Err(
        "moon build did not produce a moui_cli executable in " + candidate_dir,
      )
  }
}

///|
/// Return `true` when any `.mbt` file under `<workspace_root>/moui_cli/` is
/// newer than the file at `binary_path`. Used to detect stale cached CLI
/// binaries.
fn moui_cli_sources_newer_than(
  workspace_root : String,
  binary_path : String,
) -> Bool {
  let cli_root = join_path(workspace_root, "moui_cli")
  let binary_mtime = match file_mtime(binary_path) {
    Some(value) => value
    None => return true
  }
  moui_cli_source_tree_has_newer(cli_root, binary_mtime)
}

///|
/// Recursive scan: returns `true` when any `.mbt` file under `dir` has an
/// mtime strictly greater than `threshold_mtime`.
fn moui_cli_source_tree_has_newer(dir : String, threshold_mtime : Int) -> Bool {
  let entries = @fs.read_dir(dir) catch { _ => return false }
  for entry in entries {
    let path = join_path(dir, entry)
    if path_is_dir(path) {
      if moui_cli_source_tree_has_newer(path, threshold_mtime) {
        return true
      }
    } else if path_has_suffix(path, ".mbt") {
      match file_mtime(path) {
        Some(m) if m > threshold_mtime => return true
        _ => ()
      }
    }
  }
  false
}

///|
/// Return the mtime of `path` as a Unix timestamp (seconds), or `None` when
/// the stat call fails. Uses BSD `stat -f %m` on macOS and GNU `stat -c %Y`
/// on Linux.
fn file_mtime(path : String) -> Int? {
  let host = detect_host_platform()
  let argv = if host is Macos {
    ["stat", "-f", "%m", path]
  } else {
    ["stat", "-c", "%Y", path]
  }
  match process_exec_argv(argv, capture=true) {
    Ok(result) if result.exit_code == 0 => {
      let text = result.stdout.trim().to_string()
      match parse_int(text) {
        Ok(num) => Some(num)
        Err(_) => None
      }
    }
    _ => None
  }
}

///|
/// Return `true` when `path` ends with `suffix`.
fn path_has_suffix(path : String, suffix : String) -> Bool {
  path.has_suffix(suffix)
}
