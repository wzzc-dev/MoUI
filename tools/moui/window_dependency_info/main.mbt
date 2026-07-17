///|
fn usage() -> String {
  (
    #|Usage: tools/moui/window_dependency_info --print-version|--print-package|--print-cache-zip [--repo-root PATH] [--home PATH]
    #|
  )
}

///|
fn extract_window_versions(text : String) -> Array[String] {
  let marker = "\"wzzc-dev/window@"
  let versions : Array[String] = []
  let mut cursor = 0
  while cursor < text.length() {
    let rest = text[cursor:]
    match rest.find(marker) {
      Some(relative_start) => {
        let version_start = cursor + relative_start + marker.length()
        let version_rest = text[version_start:]
        match version_rest.find("\"") {
          Some(relative_end) => {
            versions.push(
              text[version_start:version_start + relative_end].to_owned(),
            )
            cursor = version_start + relative_end + 1
          }
          None => cursor = text.length()
        }
      }
      None => cursor = text.length()
    }
  }
  versions
}

///|
fn unique_strings(values : Array[String]) -> Array[String] {
  let unique : Array[String] = []
  for value in values {
    let mut seen = false
    for item in unique {
      if item == value {
        seen = true
      }
    }
    if !seen {
      unique.push(value)
    }
  }
  unique
}

///|
fn window_dependency_version(repo_root : String) -> Result[String, String] {
  let path = "moui/moon.mod"
  let text = match
    @tools.read_required_text(@tools.resolve_path(repo_root, path), path) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let versions = unique_strings(extract_window_versions(text))
  if versions.length() != 1 {
    Err(
      "Expected exactly one wzzc-dev/window version in moui/moon.mod, got " +
      versions.length().to_string(),
    )
  } else {
    Ok(versions[0])
  }
}

///|
fn window_dependency_package(repo_root : String) -> Result[String, String] {
  match window_dependency_version(repo_root) {
    Ok(version) => Ok("wzzc-dev/window@" + version)
    Err(message) => Err(message)
  }
}

///|
fn window_dependency_cache_zip(
  repo_root : String,
  home : String,
) -> Result[String, String] {
  match window_dependency_version(repo_root) {
    Ok(version) =>
      Ok(
        @tools.join_path(
          home,
          ".moon/registry/cache/wzzc-dev/window/" + version + ".zip",
        ),
      )
    Err(message) => Err(message)
  }
}

///|
fn parse_cli(args : Array[String]) -> Result[(String, String, String), String] {
  let mut mode = ""
  let mut repo_root = @env.current_dir().unwrap_or("")
  let mut home = @env.get_env_var("HOME").unwrap_or("")
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "-h" | "--help" => return Err("help")
      "--print-version" => {
        mode = "version"
        index += 1
      }
      "--print-package" => {
        mode = "package"
        index += 1
      }
      "--print-cache-zip" => {
        mode = "cache-zip"
        index += 1
      }
      "--repo-root" => {
        if index + 1 >= args.length() {
          return Err("missing value for --repo-root")
        }
        repo_root = args[index + 1]
        index += 2
      }
      "--home" => {
        if index + 1 >= args.length() {
          return Err("missing value for --home")
        }
        home = args[index + 1]
        index += 2
      }
      value => return Err("Unknown argument: " + value)
    }
  }
  if mode == "" {
    return Err("missing print mode")
  }
  Ok((mode, repo_root, home))
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Err("help") | Err("missing print mode") => {
      println(usage())
      2
    }
    Err(message) => {
      println(message)
      println(usage())
      2
    }
    Ok((mode, repo_root, home)) => {
      let result = match mode {
        "version" => window_dependency_version(repo_root)
        "package" => window_dependency_package(repo_root)
        "cache-zip" => window_dependency_cache_zip(repo_root, home)
        _ => Err("unknown mode")
      }
      match result {
        Ok(value) => {
          println(value)
          0
        }
        Err(message) => {
          println(message)
          1
        }
      }
    }
  }
}

///|
fn main {
  let code = run(@tools.args_without_program(@env.args()))
  if code != 0 {
    @sys.exit(code)
  }
}
