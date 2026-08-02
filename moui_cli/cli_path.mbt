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
/// Return the local upstream `window` package root used by embedded-runtime templates
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
