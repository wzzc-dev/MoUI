///|
struct CliOptions {
  repo_root : String
  platform : String
  log_dir : String
  require_commit : Bool
  help : Bool
}

///|
struct ArtifactPaths {
  log_dir : String
  preflight_log : String
  wrapper_log : String
  native_log : String
  acceptance_log : String
  build_log : String
}

///|
struct ArtifactTexts {
  wrapper_text : String
  native_text : String
  acceptance_text : String
  build_text : String?
  status_text : String
  provider_lock_text : String
}

///|
fn usage() -> String {
  let text =
    #|Usage: tools/moui_skia/verify_real_skia_artifact --platform NAME --log-dir PATH [options]
    #|
    #|Checks a real Skia smoke artifact/log directory as a bundle. The directory
    #|must contain the preflight log, wrapper log, native smoke executable log,
    #|and acceptance summary for the selected platform.
    #|
    #|Options:
    #|  --repo-root PATH    Repository root used to resolve relative paths. Defaults to cwd.
    #|  --platform NAME     linux, macos, or windows.
    #|  --log-dir PATH      Directory containing platform real-smoke logs.
    #|  --require-commit    Require skia_commit=<40 hex chars> in wrapper and acceptance logs.
    #|  -h, --help          Show this help.
    #|
  text
}

///|
fn parse_cli(args : Array[String]) -> Result[CliOptions, String] {
  let repo_root = Ref(@env.current_dir().unwrap_or(""))
  let platform = Ref("")
  let log_dir = Ref("")
  let require_commit = Ref(false)
  let help = Ref(false)
  let mut index = 0
  while index < args.length() {
    match args[index] {
      "--repo-root" => {
        if index + 1 >= args.length() {
          return Err("missing value for --repo-root")
        }
        repo_root.val = args[index + 1]
        index += 2
      }
      "--platform" => {
        if index + 1 >= args.length() {
          return Err("missing value for --platform")
        }
        platform.val = args[index + 1]
        index += 2
      }
      "--log-dir" => {
        if index + 1 >= args.length() {
          return Err("missing value for --log-dir")
        }
        log_dir.val = args[index + 1]
        index += 2
      }
      "--require-commit" => {
        require_commit.val = true
        index += 1
      }
      "-h" | "--help" => {
        help.val = true
        index += 1
      }
      other => return Err("unknown argument: " + other)
    }
  }
  if !help.val {
    match platform.val {
      "linux" | "macos" | "windows" => ()
      "" => return Err("--platform is required")
      other => return Err("unsupported platform: " + other)
    }
    if log_dir.val == "" {
      return Err("--log-dir is required")
    }
  }
  Ok({
    repo_root: repo_root.val,
    platform: platform.val,
    log_dir: log_dir.val,
    require_commit: require_commit.val,
    help: help.val,
  })
}

///|
fn artifact_paths(
  repo_root : String,
  platform : String,
  log_dir : String,
) -> ArtifactPaths {
  let resolved_log_dir = @tools.resolve_path(repo_root, log_dir)
  {
    log_dir: resolved_log_dir,
    preflight_log: @tools.join_path(
      resolved_log_dir,
      platform + "-real-skia-smoke-preflight.log",
    ),
    wrapper_log: @tools.join_path(
      resolved_log_dir,
      platform + "-real-skia-smoke.log",
    ),
    native_log: @tools.join_path(
      resolved_log_dir,
      platform + "-native-smoke-output.log",
    ),
    acceptance_log: @tools.join_path(
      resolved_log_dir,
      platform + "-real-skia-acceptance.log",
    ),
    build_log: @tools.join_path(resolved_log_dir, platform + "-skia-build.log"),
  }
}

///|
fn ascii_lower_char(char : Char) -> Char {
  if char >= 'A' && char <= 'Z' {
    (char.to_int() + 32).unsafe_to_char()
  } else {
    char
  }
}

///|
fn ascii_lower(value : String) -> String {
  let builder = StringBuilder()
  for char in value {
    builder.write_char(ascii_lower_char(char))
  }
  builder.to_string()
}

///|
fn compact_whitespace(text : String) -> String {
  let builder = StringBuilder()
  let mut in_space = false
  for char in text {
    if char == ' ' || char == '\t' || char == '\n' || char == '\r' {
      if !in_space {
        builder.write_char(' ')
      }
      in_space = true
    } else {
      builder.write_char(char)
      in_space = false
    }
  }
  builder.to_string().trim().to_owned()
}

///|
fn path_basename(path : String) -> String {
  let start = Ref(0)
  for index in 0..<path.length() {
    if path[index] == '/' || path[index] == '\\' {
      start.val = index + 1
    }
  }
  path[start.val:].to_owned()
}

///|
fn log_lines(text : String) -> Array[String] {
  let lines : Array[String] = []
  for line in text.split("\n") {
    lines.push(line.to_owned())
  }
  lines
}

///|
fn extract_field(text : String, field : String) -> String {
  let prefix = field + "="
  let result = Ref("")
  for line in log_lines(text) {
    let trimmed = line.trim().to_owned()
    if trimmed.has_prefix(prefix) {
      result.val = trimmed[prefix.length():].trim().to_owned()
    }
  }
  result.val
}

///|
fn has_log_field_line(text : String, field : String) -> Bool {
  log_lines(text).any(line => line.trim().to_owned().has_prefix(field))
}

///|
fn has_exact_log_line(text : String, expected : String) -> Bool {
  log_lines(text).any(line => line.trim().to_owned() == expected)
}

///|
fn reject_dry_run_log(
  text : String,
  label : String,
  path : String,
) -> Result[Unit, String] {
  let lowered = ascii_lower(text)
  if lowered.contains("dry run complete") ||
    lowered.contains("smoke was not run") ||
    lowered.contains("no build was run") {
    return Err(label + " log is from a dry-run configuration: " + path)
  }
  for line in log_lines(lowered) {
    let normalized = compact_whitespace(
      line.replace(old="-", new="_").replace(old=" ", new="_"),
    )
    if normalized.contains("dry_run=true") ||
      normalized.contains("dry_run_config=true") {
      return Err(label + " log is from a dry-run configuration: " + path)
    }
  }
  Ok(())
}

///|
fn require_log_field(
  text : String,
  field : String,
  message_prefix : String,
) -> Result[Unit, String] {
  if has_log_field_line(text, field) {
    Ok(())
  } else {
    Err(message_prefix + ": " + field)
  }
}

///|
fn require_exact_log_line(
  text : String,
  expected : String,
  message_prefix : String,
) -> Result[Unit, String] {
  if has_exact_log_line(text, expected) {
    Ok(())
  } else {
    Err(message_prefix + ": " + expected)
  }
}

///|
fn require_acceptance_log_reference(
  acceptance_text : String,
  field : String,
  expected_path : String,
) -> Result[Unit, String] {
  let actual_path = extract_field(acceptance_text, field)
  if actual_path == "" {
    return Err(
      "acceptance log is missing required artifact log field: " + field + "=",
    )
  }
  let expected_name = path_basename(expected_path)
  let actual_name = path_basename(actual_path)
  if actual_name != expected_name {
    return Err(
      "acceptance log field " +
      field +
      "= does not reference expected artifact log: " +
      expected_name,
    )
  }
  Ok(())
}

///|
fn wrapper_records_skia_library(wrapper_text : String) -> Bool {
  for line in log_lines(wrapper_text) {
    if line.contains("library=") &&
      (
        line.contains("libskia.a") ||
        line.contains("libskia.so") ||
        line.contains("libskia.dylib") ||
        line.contains("skia.lib") ||
        line.contains("skia.dll.lib") ||
        line.contains("skia.dll")
      ) {
      return true
    }
  }
  false
}

///|
fn accepted_commit(text : String) -> String {
  let result = Ref("")
  for line in log_lines(text) {
    let value = extract_field(line, "skia_commit")
    if @skia_acceptance.full_hex_hash(value) {
      result.val = @skia_acceptance.lowercase_hex(value)
    }
  }
  result.val
}

///|
fn is_sha256(value : String) -> Bool {
  if value.length() != 64 {
    return false
  }
  for char in value {
    if !((char >= '0' && char <= '9') ||
      (char >= 'a' && char <= 'f') ||
      (char >= 'A' && char <= 'F')) {
      return false
    }
  }
  true
}

///|
fn json_string(fields : Map[String, Json], key : String) -> String {
  match fields.get(key) {
    Some(Json::String(value)) => value
    _ => ""
  }
}

///|
fn object_field(fields : Map[String, Json], key : String) -> Map[String, Json]? {
  match fields.get(key) {
    Some(Json::Object(value)) => Some(value)
    _ => None
  }
}

///|
fn parse_provider_lock(text : String) -> Result[Map[String, Json], String] {
  let parsed = @json.parse(text) catch {
    _ => return Err("provider manifest is invalid")
  }
  match parsed {
    Json::Object(fields) => Ok(fields)
    _ => Err("provider manifest root must be an object")
  }
}

///|
fn provider_object(
  lock : Map[String, Json],
  provider_name : String,
) -> Result[Map[String, Json], String] {
  let providers = match object_field(lock, "providers") {
    Some(value) => value
    None =>
      return Err(
        provider_name +
        " provider manifest is missing providers." +
        provider_name,
      )
  }
  match object_field(providers, provider_name) {
    Some(value) => Ok(value)
    None =>
      Err(
        provider_name +
        " provider manifest is missing providers." +
        provider_name,
      )
  }
}

///|
fn asset_sha_matches(
  value : Json,
  package_name : String,
  sha256 : String,
) -> Bool {
  match value {
    Json::Object(fields) => {
      if json_string(fields, "name") == package_name &&
        ascii_lower(json_string(fields, "sha256")) == ascii_lower(sha256) {
        return true
      }
      for child in fields.values() {
        if asset_sha_matches(child, package_name, sha256) {
          return true
        }
      }
      false
    }
    Json::Array(values) =>
      values.any(child => asset_sha_matches(child, package_name, sha256))
    _ => false
  }
}

///|
fn release_asset_sha_matches(
  value : Json,
  package_name : String,
  sha256 : String,
  link_mode : String,
) -> Bool {
  match value {
    Json::Object(fields) => {
      match fields.get(link_mode) {
        Some(asset) if asset_sha_matches(asset, package_name, sha256) =>
          return true
        _ => ()
      }
      for child in fields.values() {
        if release_asset_sha_matches(child, package_name, sha256, link_mode) {
          return true
        }
      }
      false
    }
    Json::Array(values) =>
      values.any(child => {
        release_asset_sha_matches(child, package_name, sha256, link_mode)
      })
    _ => false
  }
}

///|
fn provider_platform_assets(
  provider : Map[String, Json],
  platform : String,
) -> Json? {
  match object_field(provider, "assets") {
    Some(assets) => assets.get(platform)
    None => None
  }
}

///|
fn verify_jetbrains_provider(
  platform : String,
  wrapper_text : String,
  acceptance_text : String,
  provider_lock_text : String,
) -> Result[Unit, String] {
  for
    field in [
      "skia_provider=", "jetbrains_tag=", "skia_commit=", "skia_package=", "skia_package_sha256=",
    ] {
    match
      require_log_field(
        wrapper_text, field, "JetBrains wrapper log is missing required field",
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  let commit = extract_field(wrapper_text, "skia_commit")
  let package_name = extract_field(wrapper_text, "skia_package")
  let sha256 = extract_field(wrapper_text, "skia_package_sha256")
  if !@skia_acceptance.full_hex_hash(commit) {
    return Err(
      "JetBrains wrapper log is missing a full 40-character skia_commit hash",
    )
  }
  if !is_sha256(sha256) {
    return Err(
      "JetBrains wrapper log is missing a full 64-character skia_package_sha256 hash",
    )
  }
  let lock = match parse_provider_lock(provider_lock_text) {
    Ok(value) => value
    Err(message) => return Err("JetBrains " + message)
  }
  let provider = match provider_object(lock, "jetbrains") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let tag = extract_field(wrapper_text, "jetbrains_tag")
  if tag != json_string(provider, "tag") {
    return Err(
      "JetBrains tag mismatch: log=" +
      tag +
      " manifest=" +
      json_string(provider, "tag"),
    )
  }
  if ascii_lower(commit) != ascii_lower(json_string(provider, "commit")) {
    return Err(
      "JetBrains commit mismatch: log=" +
      ascii_lower(commit) +
      " manifest=" +
      json_string(provider, "commit"),
    )
  }
  let assets = match provider_platform_assets(provider, platform) {
    Some(value) => value
    None =>
      return Err(
        "JetBrains package is not locked for platform=" +
        platform +
        ": " +
        package_name,
      )
  }
  if !asset_sha_matches(assets, package_name, sha256) {
    return Err(
      "JetBrains package SHA256 mismatch for " +
      package_name +
      ": " +
      ascii_lower(sha256),
    )
  }
  for
    field in [
      "jetbrains_tag", "skia_commit", "skia_package", "skia_package_sha256",
    ] {
    let wrapper_value = ascii_lower(extract_field(wrapper_text, field))
    let acceptance_value = ascii_lower(extract_field(acceptance_text, field))
    if wrapper_value != acceptance_value {
      return Err("wrapper and acceptance logs disagree on JetBrains " + field)
    }
  }
  Ok(())
}

///|
fn verify_release_provider(
  platform : String,
  wrapper_text : String,
  acceptance_text : String,
  provider_lock_text : String,
) -> Result[Unit, String] {
  for
    field in [
      "skia_provider=", "skia_link_mode=", "release_owner=", "release_repo=", "release_tag=",
      "release_url=", "skia_commit=", "skia_package=", "skia_package_sha256=",
    ] {
    match
      require_log_field(
        wrapper_text, field, "release wrapper log is missing required field",
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  let link_mode = extract_field(wrapper_text, "skia_link_mode")
  if !(link_mode == "static" || link_mode == "dynamic") {
    return Err(
      "release wrapper log is missing resolved skia_link_mode=static|dynamic",
    )
  }
  let commit = extract_field(wrapper_text, "skia_commit")
  let package_name = extract_field(wrapper_text, "skia_package")
  let sha256 = extract_field(wrapper_text, "skia_package_sha256")
  if !@skia_acceptance.full_hex_hash(commit) {
    return Err(
      "release wrapper log is missing a full 40-character skia_commit hash",
    )
  }
  if !is_sha256(sha256) {
    return Err(
      "release wrapper log is missing a full 64-character skia_package_sha256 hash",
    )
  }
  let lock = match parse_provider_lock(provider_lock_text) {
    Ok(value) => value
    Err(message) => return Err("release " + message)
  }
  let provider = match provider_object(lock, "release") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  for
    mapping in [
      ("owner", "release_owner"),
      ("repo", "release_repo"),
      ("tag", "release_tag"),
      ("release_url", "release_url"),
    ] {
    let field = mapping.0
    let log_field = mapping.1
    let actual = extract_field(wrapper_text, log_field)
    let expected = json_string(provider, field)
    if actual != expected {
      return Err(
        "release " +
        field +
        " mismatch: log=" +
        actual +
        " manifest=" +
        expected,
      )
    }
  }
  if ascii_lower(commit) != ascii_lower(json_string(provider, "commit")) {
    return Err(
      "release commit mismatch: log=" +
      ascii_lower(commit) +
      " manifest=" +
      json_string(provider, "commit"),
    )
  }
  let assets = match provider_platform_assets(provider, platform) {
    Some(value) => value
    None =>
      return Err(
        "release package is not locked for platform=" +
        platform +
        " link_mode=" +
        link_mode +
        ": " +
        package_name,
      )
  }
  if !release_asset_sha_matches(assets, package_name, sha256, link_mode) {
    return Err(
      "release package SHA256 mismatch for " +
      package_name +
      ": " +
      ascii_lower(sha256),
    )
  }
  for
    field in [
      "release_owner", "release_repo", "release_tag", "release_url", "skia_commit",
      "skia_package", "skia_package_sha256", "skia_link_mode",
    ] {
    let wrapper_value = if field == "skia_commit" ||
      field == "skia_package_sha256" {
      ascii_lower(extract_field(wrapper_text, field))
    } else {
      extract_field(wrapper_text, field)
    }
    let acceptance_value = if field == "skia_commit" ||
      field == "skia_package_sha256" {
      ascii_lower(extract_field(acceptance_text, field))
    } else {
      extract_field(acceptance_text, field)
    }
    if wrapper_value != acceptance_value {
      return Err("wrapper and acceptance logs disagree on release " + field)
    }
  }
  Ok(())
}

///|
fn verify_artifact_texts(
  platform : String,
  require_commit : Bool,
  paths : ArtifactPaths,
  texts : ArtifactTexts,
) -> Result[Unit, String] {
  match
    reject_dry_run_log(
      texts.wrapper_text,
      "artifact wrapper",
      paths.wrapper_log,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    reject_dry_run_log(
      texts.native_text,
      "artifact native smoke",
      paths.native_log,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    reject_dry_run_log(
      texts.acceptance_text,
      "artifact acceptance",
      paths.acceptance_log,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }

  let wrapper_provider = match
    extract_field(texts.wrapper_text, "skia_provider") {
    "" | "unknown" => "source"
    value => value
  }
  let acceptance_provider = match
    extract_field(texts.acceptance_text, "skia_provider") {
    "" | "unknown" => wrapper_provider
    value => value
  }
  if wrapper_provider != acceptance_provider {
    return Err("wrapper and acceptance logs disagree on skia_provider")
  }

  if platform == "linux" && require_commit && wrapper_provider == "source" {
    if texts.build_text is None {
      return Err(
        "source-built Linux artifact is missing expected build log: " +
        paths.build_log,
      )
    }
    match
      require_log_field(
        texts.wrapper_text,
        "build_log=",
        "wrapper log is missing required field",
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }

  match
    @smoke_contract.verify_smoke_log_contract(
      texts.native_text,
      texts.status_text,
      "moui_skia native smoke test passed",
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match
    @skia_acceptance.verify_acceptance_log_text(
      texts.acceptance_text,
      require_commit,
    ) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }

  for
    field in [
      "skia_include=", "skia_lib_dir=", "skia_lib=", "stub_cc_flags=", "cc_link_flags=",
    ] {
    match
      require_log_field(
        texts.wrapper_text,
        field,
        "wrapper log is missing required field",
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  if !wrapper_records_skia_library(texts.wrapper_text) {
    return Err("wrapper log does not record a Skia library file")
  }

  for
    reference in [
      ("preflight_log", paths.preflight_log),
      ("wrapper_log", paths.wrapper_log),
      ("native_log", paths.native_log),
      ("acceptance_log", paths.acceptance_log),
    ] {
    let field = reference.0
    let expected_path = reference.1
    match
      require_acceptance_log_reference(
        texts.acceptance_text,
        field,
        expected_path,
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }
  if platform == "linux" && require_commit && wrapper_provider == "source" {
    match
      require_acceptance_log_reference(
        texts.acceptance_text,
        "build_log",
        paths.build_log,
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
  }

  if require_commit &&
    !@skia_acceptance.full_hex_hash(
      extract_field(texts.wrapper_text, "skia_commit"),
    ) {
    return Err("wrapper log is missing a full 40-character skia_commit hash")
  }
  match wrapper_provider {
    "jetbrains" =>
      match
        verify_jetbrains_provider(
          platform,
          texts.wrapper_text,
          texts.acceptance_text,
          texts.provider_lock_text,
        ) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    "release" =>
      match
        verify_release_provider(
          platform,
          texts.wrapper_text,
          texts.acceptance_text,
          texts.provider_lock_text,
        ) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    _ => ()
  }

  if require_commit {
    let wrapper_commit = accepted_commit(texts.wrapper_text)
    let acceptance_commit = accepted_commit(texts.acceptance_text)
    if wrapper_commit != acceptance_commit {
      return Err("wrapper and acceptance logs disagree on skia_commit")
    }
  }
  if platform == "linux" && require_commit && wrapper_provider == "source" {
    let build_text = match texts.build_text {
      Some(value) => value
      None =>
        return Err(
          "source-built Linux artifact is missing expected build log: " +
          paths.build_log,
        )
    }
    match
      require_exact_log_line(
        build_text, "Linux Skia source build environment:", "Linux source build log is missing required field",
      ) {
      Ok(_) => ()
      Err(message) => return Err(message)
    }
    for field in ["skia_checkout=", "skia_commit=", "gn_args="] {
      match
        require_log_field(
          build_text, field, "Linux source build log is missing required field",
        ) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    }
    let wrapper_commit = accepted_commit(texts.wrapper_text)
    let build_commit = accepted_commit(build_text)
    if wrapper_commit != build_commit {
      return Err("Linux build and wrapper logs disagree on skia_commit")
    }
  }
  Ok(())
}

///|
fn read_required(path : String, label : String) -> Result[String, String] {
  @tools.read_required_text(path, label)
}

///|
fn verify_real_skia_artifact(options : CliOptions) -> Result[String, String] {
  let paths = artifact_paths(
    options.repo_root,
    options.platform,
    options.log_dir,
  )
  if !@tools.directory_exists(paths.log_dir) {
    return Err("real Skia artifact log directory is missing: " + paths.log_dir)
  }
  for
    path in [
      paths.preflight_log,
      paths.wrapper_log,
      paths.native_log,
      paths.acceptance_log,
    ] {
    if !@tools.file_exists(path) {
      return Err("real Skia artifact is missing expected log: " + path)
    }
  }
  let wrapper_text = match read_required(paths.wrapper_log, "wrapper log") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let native_text = match
    read_required(paths.native_log, "native smoke executable log") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let acceptance_text = match
    read_required(paths.acceptance_log, "acceptance log") {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let provider = match extract_field(wrapper_text, "skia_provider") {
    "" | "unknown" => "source"
    value => value
  }
  let build_text = if options.platform == "linux" &&
    options.require_commit &&
    provider == "source" {
    if !@tools.file_exists(paths.build_log) {
      return Err(
        "source-built Linux artifact is missing expected build log: " +
        paths.build_log,
      )
    }
    match read_required(paths.build_log, "Linux source build log") {
      Ok(value) => Some(value)
      Err(message) => return Err(message)
    }
  } else {
    None
  }
  let status_text = match
    read_required(
      @tools.join_path(options.repo_root, "skia-platform-status.json"),
      "Skia platform status JSON",
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let provider_lock_text = match
    read_required(
      @tools.join_path(options.repo_root, "skia-provider-lock.json"),
      "Skia provider lock manifest",
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  match
    verify_artifact_texts(options.platform, options.require_commit, paths, {
      wrapper_text,
      native_text,
      acceptance_text,
      build_text,
      status_text,
      provider_lock_text,
    }) {
    Ok(_) =>
      Ok(
        "Verified " +
        options.platform +
        " real Skia artifact logs in " +
        paths.log_dir +
        ".",
      )
    Err(message) => Err(message)
  }
}

///|
fn run(args : Array[String]) -> Int {
  match parse_cli(args) {
    Ok(options) if options.help => {
      println(usage())
      0
    }
    Ok(options) =>
      match verify_real_skia_artifact(options) {
        Ok(message) => {
          println(message)
          0
        }
        Err(message) => {
          println(message)
          1
        }
      }
    Err(message) => {
      println(message)
      println(usage())
      2
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
