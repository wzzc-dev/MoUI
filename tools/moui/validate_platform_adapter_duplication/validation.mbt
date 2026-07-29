///|
struct DuplicateBudget {
  token : String
  maximum : Int
}

///|
fn bridge_import_platforms() -> Array[String] {
  [
    "moui/backend/macos", "moui/backend/windows", "moui/backend/linux", "moui/backend/web",
    "moui/backend/android", "moui/backend/ios", "moui/backend/harmonyos",
  ]
}

///|
fn normalization_budget_tokens() -> Array[String] {
  ["@host.physical_position_to_core", "@host.surface_metrics_from_physical"]
}

///|
fn duplicate_budgets_from_baseline(
  baseline : String,
) -> Result[Array[DuplicateBudget], String] {
  let budgets : Array[DuplicateBudget] = []
  for token in normalization_budget_tokens() {
    let marker = "\"" + token + "\":"
    match baseline.find(marker) {
      None => return Err("normalization budget missing for " + token)
      Some(start) => {
        let tail = baseline[start + marker.length():].trim()
        let end = normalization_budget_end(tail)
        let raw = tail[:end].trim()
        let maximum : Int = @strconv.from_str(raw) catch {
          _ => return Err("normalization budget is not an integer for " + token)
        }
        if maximum < 0 {
          return Err("normalization budget must be non-negative for " + token)
        }
        budgets.push({ token, maximum })
      }
    }
  }
  Ok(budgets)
}

///|
fn normalization_budget_end(tail : StringView) -> Int {
  let end = Ref(tail.length())
  for delimiter in [",", "\n", "}"] {
    match tail.find(delimiter) {
      Some(index) if index < end.val => end.val = index
      _ => ()
    }
  }
  end.val
}

///|
fn bridge_symbols_present(text : String) -> Bool {
  text.contains("pub(all) enum TransformedWindowEvent") &&
  text.contains("pub(all) enum PlatformSurfaceLifecycle") &&
  text.contains("pub fn transform_cross_platform_event") &&
  text.contains("pub fn make_surface_metrics") &&
  text.contains("pub fn normalize_pointer_position")
}

///|
fn import_is_platform_bridge(text : String) -> Bool {
  text.contains("\"wzzc-dev/moui/backend/platform_bridge\"")
}

///|
fn uses_platform_bridge(text : String) -> Bool {
  text.contains("@platform_bridge.")
}

///|
fn helper_is_redefined(text : String) -> String? {
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
fn expired_allowlist_dates(baseline : String, today : String) -> Array[String] {
  let expired : Array[String] = []
  for line_view in baseline.split("\n") {
    let line = line_view.to_owned()
    let marker = "\"allowUntil\": \""
    if line.contains(marker) {
      let start = line.find(marker).unwrap_or(0) + marker.length()
      let tail = line[start:].to_owned()
      match tail.find("\"") {
        Some(end) => {
          let date = tail[:end].to_owned()
          if date < today {
            expired.push(date)
          }
        }
        None => expired.push("malformed allowUntil")
      }
    }
  }
  expired
}

///|
fn validate_repository(repo_root : String, today : String) -> Array[String] {
  let failures : Array[String] = []
  let duplicate_budgets = Ref([])
  let bridge_source = "moui/backend/platform_bridge/window_event_transformer.mbt"
  match read_repo_text(repo_root, bridge_source) {
    Ok(text) =>
      if !bridge_symbols_present(text) {
        failures.push("Platform Bridge public contract is incomplete")
      }
    Err(message) => failures.push(message)
  }
  match read_repo_text(repo_root, "moui/backend/platform_bridge/moon.pkg") {
    Ok(_) => ()
    Err(message) => failures.push(message)
  }
  match
    read_repo_text(
      repo_root, "checks/platform-adapter-duplication-baseline.json",
    ) {
    Ok(baseline) => {
      if !baseline.contains("\"schemaVersion\": 2") {
        failures.push("platform adapter baseline must use schemaVersion 2")
      }
      if baseline.contains("shared_adapter") ||
        !baseline.contains("platform_bridge_modules") {
        failures.push(
          "platform adapter baseline must use platform_bridge keys only",
        )
      }
      if !baseline.contains("direct-canvas-callback") {
        failures.push("WeChat direct-canvas-callback exemption is missing")
      }
      for date in expired_allowlist_dates(baseline, today) {
        failures.push("platform adapter allowlist expired: " + date)
      }
      match duplicate_budgets_from_baseline(baseline) {
        Ok(budgets) => duplicate_budgets.val = budgets
        Err(message) => failures.push(message)
      }
    }
    Err(message) => failures.push(message)
  }
  let all_platform_files : Array[String] = []
  for platform in bridge_import_platforms() {
    match read_repo_text(repo_root, platform + "/moon.pkg") {
      Ok(pkg) if !import_is_platform_bridge(pkg) =>
        failures.push(platform + " must import backend/platform_bridge")
      Ok(_) => ()
      Err(message) => failures.push(message)
    }
    let files : Array[String] = []
    collect_mbt_files(repo_root, platform, files, failures)
    let platform_uses_bridge = Ref(false)
    for path in files {
      match read_repo_text(repo_root, path) {
        Ok(text) => {
          if uses_platform_bridge(text) {
            platform_uses_bridge.val = true
          }
          match helper_is_redefined(text) {
            Some(helper) =>
              failures.push(path + " redefines bridge helper: " + helper)
            None => ()
          }
        }
        Err(message) => failures.push(message)
      }
    }
    if !platform_uses_bridge.val {
      failures.push(platform + " imports Platform Bridge but does not use it")
    }
    all_platform_files.append(files)
  }
  let wechat_files : Array[String] = []
  collect_mbt_files(repo_root, "moui/backend/wechat", wechat_files, failures)
  for path in wechat_files {
    match read_repo_text(repo_root, path) {
      Ok(text) => {
        if text.contains("WindowEvent") {
          failures.push(path + " violates the direct-canvas-callback exception")
        }
        match helper_is_redefined(text) {
          Some(helper) =>
            failures.push(path + " redefines bridge helper: " + helper)
          None => ()
        }
      }
      Err(message) => failures.push(message)
    }
  }
  all_platform_files.append(wechat_files)
  for budget in duplicate_budgets.val {
    let mut count = 0
    for path in all_platform_files {
      match read_repo_text(repo_root, path) {
        Ok(text) => count += count_token(text, budget.token)
        Err(_) => ()
      }
    }
    if count > budget.maximum {
      failures.push(
        "platform normalization duplicate budget exceeded: " +
        budget.token +
        " count=\{count} max=\{budget.maximum}",
      )
    }
  }
  failures
}
