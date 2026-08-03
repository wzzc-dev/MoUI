///|
/// Platform mirror file similarity gate.
///
/// Backends are allowed to share structure but must not be verbatim copies:
/// after normalizing platform tokens (`macos`, `Linux`, `WebRenderer`, ...)
/// a mirror file pair scoring above 80% similarity is rejected unless an
/// explicit per-file budget row explains it. New platform pairs therefore
/// force a decision: fold the shared part into `moui/runtime` or a shared
/// internal package, or register a budget row with a reason.
///
/// Similarity is Dice over the normalized token set. Token normalization
/// maps platform identifiers to `__P__` (substring forms cover both `_macos`
/// snake and `IosImeSink` camel identifiers; `web_` prefix covers web files
/// without touching `webgpu`/`webview`/`wechat` tech names).
struct PlatformFileSimilarityBudget {
  label : String
  path_a : String
  path_b : String
  max_similarity : Double
}

///|
fn platform_file_similarity_budgets() -> Array[PlatformFileSimilarityBudget] {
  let mobile = "moui/backend/"
  [
    {
      label: "Wave 2 embedded runtime hosted window shell (android/ios)",
      path_a: mobile + "android/window_hosted.mbt",
      path_b: mobile + "ios/window_hosted.mbt",
      max_similarity: 0.97,
    },
    {
      label: "Wave 2 embedded runtime hosted window shell (android/harmonyos)",
      path_a: mobile + "android/window_hosted.mbt",
      path_b: mobile + "harmonyos/window_hosted.mbt",
      max_similarity: 0.98,
    },
    {
      label: "Wave 2 embedded runtime hosted window shell (ios/harmonyos)",
      path_a: mobile + "ios/window_hosted.mbt",
      path_b: mobile + "harmonyos/window_hosted.mbt",
      max_similarity: 0.96,
    },
    {
      label: "timer host thin shells (linux/win32)",
      path_a: mobile + "linux/linux_timer_host.mbt",
      path_b: mobile + "windows/win32_timer_host.mbt",
      max_similarity: 0.90,
    },
    {
      label: "window request coordination mirror (macos/linux)",
      path_a: mobile + "macos/macos_window_requests.mbt",
      path_b: mobile + "linux/linux_window_requests.mbt",
      max_similarity: 0.86,
    },
    {
      label: "Wave 2 embedded runtime backend entry shells (android/ios)",
      path_a: mobile + "android/android_backend.mbt",
      path_b: mobile + "ios/ios_backend.mbt",
      max_similarity: 0.96,
    },
    {
      label: "Wave 2 embedded runtime backend entry shells (android/harmonyos)",
      path_a: mobile + "android/android_backend.mbt",
      path_b: mobile + "harmonyos/harmonyos_backend.mbt",
      max_similarity: 0.93,
    },
    {
      label: "Wave 2 embedded runtime backend entry shells (ios/harmonyos)",
      path_a: mobile + "ios/ios_backend.mbt",
      path_b: mobile + "harmonyos/harmonyos_backend.mbt",
      max_similarity: 0.90,
    },
    {
      label: "embedded CPU presenter FFI declarations (android/harmonyos)",
      path_a: mobile + "android/android_present.mbt",
      path_b: mobile + "harmonyos/harmonyos_present.mbt",
      max_similarity: 1.0,
    },
  ]
}

///|
fn platform_similarity_tokens() -> Array[String] {
  [
    "macos_", "linux_", "windows_", "win32_", "android_", "ios_", "harmonyos_", "web_",
    "macos", "linux", "windows", "win32", "android", "ios", "harmonyos", "Macos",
    "Linux", "Windows", "Win32", "Android", "Ios", "Harmonyos", "Web",
  ]
}

///|
/// Normalize platform identifiers to `__P__` then split into identifier and
/// number tokens. Pure, so the gate is unit-testable without a repo.
fn normalize_platform_tokens(text : String) -> Array[String] {
  let mut normalized = text
  for token in platform_similarity_tokens() {
    normalized = normalized.replace_all(old=token, new="__P__")
  }
  let marker = "__P__"
  while normalized.contains(marker + marker) {
    normalized = normalized.replace_all(old=marker + marker, new=marker)
  }
  let tokens : Array[String] = []
  let mut current : String = ""
  for char in normalized {
    let identifier_char = (char >= 'a' && char <= 'z') ||
      (char >= 'A' && char <= 'Z') ||
      (char >= '0' && char <= '9') ||
      char == '_'
    if identifier_char {
      current = current + char.to_string()
    } else if current.length() > 0 {
      tokens.push(current)
      current = ""
    }
  }
  if current.length() > 0 {
    tokens.push(current)
  }
  tokens
}

///|
fn token_set_dice(first : Array[String], second : Array[String]) -> Double {
  let first_set : Set[String] = Set::from_array(first)
  let second_set : Set[String] = Set::from_array(second)
  if first_set.is_empty() || second_set.is_empty() {
    return 0.0
  }
  let mut intersection = 0
  for token in first_set {
    if second_set.contains(token) {
      intersection = intersection + 1
    }
  }
  2.0 *
  intersection.to_double() /
  (first_set.length().to_double() + second_set.length().to_double())
}

///|
/// Map a backend file to its cross-platform mirror group (basename without
/// the platform prefix), or `None` for files with no platform mirror.
fn mirror_group_name(file : String) -> String {
  let parts = file.split("/").to_array()
  let name = parts[parts.length() - 1].to_owned()
  for
    prefix in [
      "macos_", "linux_", "windows_", "win32_", "android_", "ios_", "harmonyos_",
      "web_",
    ] {
    if name.has_prefix(prefix) {
      return name[prefix.length():].to_owned()
    }
  }
  name
}

///|
fn platform_backend_dirs() -> Array[String] {
  ["macos", "linux", "windows", "android", "ios", "harmonyos", "web"]
}

///|
fn is_platform_backend_file(path : String) -> Bool {
  if !path.has_suffix(".mbt") ||
    path.contains("_test.mbt") ||
    path.contains("_wbtest.mbt") {
    return false
  }
  for dir in platform_backend_dirs() {
    if path.has_prefix("moui/backend/" + dir + "/") ||
      path.has_prefix(dir + "/") {
      return true
    }
  }
  false
}

///|
fn find_similarity_budget(
  first : String,
  second : String,
) -> PlatformFileSimilarityBudget? {
  for budget in platform_file_similarity_budgets() {
    if (budget.path_a == first && budget.path_b == second) ||
      (budget.path_a == second && budget.path_b == first) {
      return Some(budget)
    }
  }
  None
}

///|
fn validate_platform_file_similarity(
  repo_root : String,
  failures : Array[String],
) -> Unit {
  let files : Array[String] = []
  for dir in platform_backend_dirs() {
    collect_mbt_files(repo_root, "moui/backend/" + dir, files, failures)
  }
  let grouped : Map[String, Array[String]] = Map([])
  for file in files {
    if !is_platform_backend_file(file) {
      continue
    }
    let group = mirror_group_name(file)
    match grouped.get(group) {
      Some(existing) => existing.push(file)
      None => grouped.set(group, [file])
    }
  }
  let threshold = 0.80
  for group in grouped.values() {
    for i in 0..<group.length() {
      for j in (i + 1)..<group.length() {
        let first = group[i]
        let second = group[j]
        let first_text = match read_repo_text(repo_root, first) {
          Ok(text) => text
          Err(message) => {
            failures.push(message)
            continue
          }
        }
        let second_text = match read_repo_text(repo_root, second) {
          Ok(text) => text
          Err(message) => {
            failures.push(message)
            continue
          }
        }
        let similarity = token_set_dice(
          normalize_platform_tokens(first_text),
          normalize_platform_tokens(second_text),
        )
        match find_similarity_budget(first, second) {
          Some(budget) =>
            if similarity > budget.max_similarity {
              failures.push(
                "platform file similarity: " +
                budget.label +
                " (" +
                first +
                " <-> " +
                second +
                ") " +
                (similarity * 100.0).round().to_int().to_string() +
                "% exceeds budget " +
                (budget.max_similarity * 100.0).round().to_int().to_string() +
                "%",
              )
            }
          None =>
            if similarity > threshold {
              failures.push(
                "platform file similarity: " +
                first +
                " <-> " +
                second +
                " is " +
                (similarity * 100.0).round().to_int().to_string() +
                "% similar (limit " +
                (threshold * 100.0).round().to_int().to_string() +
                "%). Fold shared logic into moui/runtime or register a " +
                "platform_file_similarity_budgets row with a reason.",
              )
            }
        }
      }
    }
  }
}
