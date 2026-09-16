// MSVC child-process environment for Windows desktop builds, mirroring
// `moui/scripts/windows/msvc_env.ps1`. `moui_cli_process_exec` REPLACES the
// child environment when a non-empty env array is supplied, so the full
// environment is assembled here: capture the `vcvarsall.bat` environment via
// `cmd /c ... && set`, then layer CC/CXX/CL/LINK and the vcpkg zlib triplet
// on top. Builds on other platforms pass an empty env array and inherit.

///|
priv enum EnvOverride {
  SetEnv(String, String)
  /// Prepend `value;` to the current value of `key` (PATH-style keys).
  PrependPath(String, String)
}

///|
/// Parse `cmd /c set` output into KEY/VALUE pairs. Lines without `=` and
/// `=KEY=VALUE`-style oddities are skipped.
fn parse_env_output(text : String) -> Array[(String, String)] {
  let entries : Array[(String, String)] = []
  for line_view in text.split("\n") {
    let line = line_view.to_owned()
    let trimmed = strip_trailing_cr(line)
    if trimmed == "" || trimmed.has_prefix("=") {
      continue
    }
    match trimmed.split_once("=") {
      Some((key_view, value_view)) =>
        entries.push((key_view.to_owned(), value_view.to_owned()))
      None => ()
    }
  }
  entries
}

///|
fn strip_trailing_cr(line : String) -> String {
  if line.has_suffix("\r") {
    line[:line.length() - 1].to_owned()
  } else {
    line
  }
}

///|
fn apply_env_overrides(
  base : Array[(String, String)],
  overrides : Array[EnvOverride],
) -> Array[(String, String)] {
  let result = base.copy()
  for entry in overrides {
    match entry {
      SetEnv(key, value) => {
        let mut found = false
        for index, entry in result {
          if entry.0 == key {
            result[index] = (key, value)
            found = true
            break
          }
        }
        if !found {
          result.push((key, value))
        }
      }
      PrependPath(key, value) => {
        if value == "" {
          continue
        }
        let mut found = false
        for index, entry in result {
          if entry.0 == key {
            let current = entry.1
            if current == "" {
              result[index] = (key, value)
            } else if current == value || current.has_prefix(value + ";") {
              // Already present at the front; keep the environment stable.
              result[index] = (key, current)
            } else {
              result[index] = (key, value + ";" + current)
            }
            found = true
            break
          }
        }
        if !found {
          result.push((key, value))
        }
      }
    }
  }
  result
}

///|
fn vswhere_path() -> String {
  let program_files = @env.get_env_var("ProgramFiles(x86)").unwrap_or(
    "C:/Program Files (x86)",
  )
  join_path(program_files, "Microsoft Visual Studio/Installer/vswhere.exe")
}

///|
/// Locate `vcvarsall.bat` through vswhere. Fails with an actionable message
/// when Visual Studio Build Tools with the VC.Tools.x86.x64 component are
/// missing.
fn locate_vcvarsall() -> Result[String, String] {
  let vswhere = vswhere_path()
  if !path_is_file(vswhere) {
    return Err(
      "vswhere.exe was not found at " +
      vswhere +
      "; install Visual Studio Build Tools with: winget install --id Microsoft.VisualStudio.2022.BuildTools -e",
    )
  }
  let result = process_exec_argv(
    [
      vswhere, "-latest", "-products", "*", "-requires", "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
      "-property", "installationPath",
    ],
    capture=true,
  )
  let install_path = match result {
    Ok(value) =>
      if value.exit_code != 0 {
        return Err(
          "vswhere exited with code " +
          value.exit_code.to_string() +
          ": " +
          value.stderr,
        )
      } else {
        value.stdout.trim().to_owned()
      }
    Err(message) => return Err("could not run vswhere: " + message)
  }
  if install_path == "" {
    return Err(
      "no Visual Studio installation with the C++ x64/x86 toolset was found; install Visual Studio Build Tools with: winget install --id Microsoft.VisualStudio.2022.BuildTools -e",
    )
  }
  let vcvars = join_path(install_path, "VC/Auxiliary/Build/vcvarsall.bat")
  if !path_is_file(vcvars) {
    return Err("vcvarsall.bat was not found: " + vcvars)
  }
  Ok(vcvars)
}

///|
/// Capture the full environment produced by importing `vcvarsall.bat`.
fn msvc_capture_environment(
  vcvars : String,
  arch? : String = "x64",
) -> Result[Array[(String, String)], String] {
  let command = "\"" + vcvars + "\" " + arch + " >nul && set"
  let result = process_exec_argv(["cmd.exe", "/d", "/c", command], capture=true)
  match result {
    Ok(value) =>
      if value.exit_code != 0 {
        Err(
          "importing the MSVC environment failed (exit " +
          value.exit_code.to_string() +
          "): " +
          value.stderr,
        )
      } else {
        Ok(parse_env_output(value.stdout))
      }
    Err(message) => Err("could not import the MSVC environment: " + message)
  }
}

///|
/// First existing zlib import library under the vcpkg triplet root.
fn msvc_zlib_lib_file(triplet_root : String) -> String? {
  for candidate in ["lib/zlib.lib", "lib/z.lib", "lib/zlibstatic.lib"] {
    let path = join_path(triplet_root, candidate)
    if path_is_file(path) {
      return Some(path)
    }
  }
  None
}

///|
/// First existing zlib runtime DLL under the vcpkg triplet root.
fn msvc_zlib_runtime_dll(triplet_root : String) -> String? {
  for candidate in ["bin/zlib1.dll", "bin/z.dll", "bin/zlib.dll"] {
    let path = join_path(triplet_root, candidate)
    if path_is_file(path) {
      return Some(path)
    }
  }
  None
}

///|
/// Layer the MoUI MSVC build flags over a captured vcvarsall environment.
/// Flag strings match `moui/scripts/windows/msvc_env.ps1` exactly. Both
/// `zlib_triplet` and `zlib_lib` are resolved by the caller so this function
/// stays pure; `zlib_lib` must live under `zlib_triplet`.
fn msvc_build_overrides(
  zlib_triplet : String?,
  zlib_lib : String?,
  wgpu_native_root? : String? = None,
) -> Result[Array[EnvOverride], String] {
  let overrides : Array[EnvOverride] = []
  overrides.push(SetEnv("CC", "cl.exe"))
  overrides.push(SetEnv("CXX", "cl.exe"))
  overrides.push(
    SetEnv(
      "CL", "/DNOMINMAX /experimental:c11atomics /utf-8 /wd4005 /DMOONBIT_FFI_EXPORT=",
    ),
  )
  match (zlib_triplet, zlib_lib) {
    (Some(triplet), Some(lib)) => {
      overrides.push(
        SetEnv(
          "LINK",
          "comdlg32.lib shell32.lib advapi32.lib ole32.lib user32.lib gdi32.lib dwrite.lib d2d1.lib " +
          lib +
          " /SUBSYSTEM:WINDOWS /ENTRY:mainCRTStartup",
        ),
      )
      overrides.push(PrependPath("INCLUDE", join_path(triplet, "include")))
      overrides.push(PrependPath("LIB", join_path(triplet, "lib")))
      overrides.push(PrependPath("PATH", join_path(triplet, "bin")))
      overrides.push(SetEnv("MOUI_MSVC_ZLIB_TRIPLET_ROOT", triplet))
    }
    _ =>
      return Err(
        "zlib:x64-windows was not detected; run scripts/windows/setup_msvc_deps.ps1 -InstallZlib",
      )
  }
  match wgpu_native_root {
    Some(root) => overrides.push(SetEnv("MBT_WGPU_NATIVE_ROOT", root))
    None => ()
  }
  Ok(overrides)
}

///|
/// Resolve the zlib triplet and import library for a project root.
fn msvc_resolve_zlib(project_root : String) -> Result[(String, String), String] {
  match msvc_zlib_root(project_root) {
    Some(triplet) =>
      match msvc_zlib_lib_file(triplet) {
        Some(lib) => Ok((triplet, lib))
        None =>
          Err(
            "zlib import library was not found under " +
            triplet +
            "; run scripts/windows/setup_msvc_deps.ps1 -InstallZlib",
          )
      }
    None =>
      Err(
        "zlib:x64-windows was not detected; run scripts/windows/setup_msvc_deps.ps1 -InstallZlib",
      )
  }
}

///|
/// Full child environment for `moon build --target native` on Windows.
/// Returns an empty array when the platform is not Windows or the user
/// already configured a C compiler (CC preset), meaning "inherit as-is".
fn windows_moon_env(
  project_root : String,
  host : HostPlatform,
  wgpu_native_root? : String? = None,
) -> Result[Array[(String, String)], String] {
  if host != Windows {
    return Ok([])
  }
  if @env.get_env_var("CC") is Some(_) {
    return Ok([])
  }
  let vcvars = match locate_vcvarsall() {
    Ok(path) => path
    Err(message) => return Err(message)
  }
  let base = match msvc_capture_environment(vcvars) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let (zlib_triplet, zlib_lib) = match msvc_resolve_zlib(project_root) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let overrides = match
    msvc_build_overrides(Some(zlib_triplet), Some(zlib_lib), wgpu_native_root~) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok(apply_env_overrides(base, overrides))
}
