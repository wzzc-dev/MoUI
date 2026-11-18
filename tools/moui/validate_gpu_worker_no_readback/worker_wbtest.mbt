// White-box tests for the GPU no-readback gate: forbidden-pattern scanning,
// worker diagnostics, Android build-flag checks, and CLI parsing.

///|
fn matched_offset(text : String, needle : String) -> Int32 {
  match first_match_offset(text, needle) {
    Some(offset) => offset
    None => -1
  }
}

///|
test "forbidden patterns and offset helpers locate violations" {
  let patterns = forbidden_patterns()
  assert_eq(patterns.length(), 4)
  assert_eq(patterns[0].label, "Skia readback")
  assert_eq(patterns[3].label, "platform CPU presenter")
  assert_eq(line_of_offset("a\nbc\n", 2), 2)
  assert_eq(line_of_offset("a\nbc\n", 4), 2)
  assert_eq(line_of_offset("a\nbc\n", 5), 3)
  assert_eq(matched_offset("abcabc", "c"), 2)
  assert_eq(matched_offset("abc", "z"), -1)
}

///|
test "validate_worker_source reports each forbidden category once with a line" {
  assert_eq(validate_worker_source("worker.cpp", "int x = 1;\n").length(), 0)
  let readback = validate_worker_source(
    "worker.cpp", "// ok\nint px = readPixels(0);\n",
  )
  assert_eq(readback.length(), 1)
  assert_eq(
    readback[0],
    "worker.cpp:2: GPU worker contains forbidden Skia readback",
  )
  // One failure per category; a second needle in the same category
  // (`readPixels` after `read_pixels`) is suppressed by the per-pattern break.
  let both = validate_worker_source(
    "worker.cpp", "read_pixels(); readPixels(); present_skia_pixels(); CGImage frame;\n",
  )
  assert_eq(both.length(), 3)
  assert_true(both[0].contains("forbidden Skia readback"))
  assert_true(both[1].contains("forbidden CPU pixel presenter"))
  assert_true(both[2].contains("forbidden platform CPU presenter"))
}

///|
test "validate_worker_api requires a zero readback diagnostic" {
  assert_eq(validate_worker_api("api.mbt", "readback_count: 0L").length(), 0)
  assert_eq(validate_worker_api("api.mbt", "readback_count:0L").length(), 0)
  let missing = validate_worker_api("api.mbt", "readback_count: 1L")
  assert_eq(missing.length(), 1)
  assert_eq(
    missing[0],
    "api.mbt: native worker diagnostics must report readback_count: 0L",
  )
}

///|
test "validate_build_flags slices the Android block and bans -lvulkan" {
  let good = "} else if platform == \"android\" {\n  link = \"\";\n} else if platform == \"harmonyos\" {\n  link = \"\";\n}\n"
  assert_eq(validate_build_flags("moui_skia/build.mbtx", good).length(), 0)
  let bad = "} else if platform == \"android\" {\n  link = \"-lvulkan\";\n} else if platform == \"harmonyos\" {\n  link = \"\";\n}\n"
  let failures = validate_build_flags("moui_skia/build.mbtx", bad)
  assert_eq(failures.length(), 1)
  assert_eq(
    failures[0],
    "moui_skia/build.mbtx: Android minSdk 23 GPU builds must dynamically load Vulkan, not link -lvulkan",
  )
  let missing = validate_build_flags(
    "moui_skia/build.mbtx", "no platform flags here",
  )
  assert_eq(
    missing[0],
    "moui_skia/build.mbtx: Android Skia platform flags block was not found",
  )
  // The slice stops at the HarmonyOS block, so flags after it are not judged.
  let sliced = match android_flags_block(bad) {
    Some(block) => block
    None => ""
  }
  assert_true(sliced.contains("-lvulkan"))
  assert_true(!sliced.contains("harmonyos"))
  // An earlier android branch (the target-triple branch) must not win over the
  // platform-flags branch that precedes the harmonyos branch.
  let two_branches = "if platform == \"android\" {\n  target = \"aarch64-unknown-linux-android\";\n} else if platform == \"android\" {\n  link = \"-lvulkan\";\n} else if platform == \"harmonyos\" {\n}\n"
  let flags_only = match android_flags_block(two_branches) {
    Some(block) => block
    None => ""
  }
  assert_true(flags_only.contains("-lvulkan"))
  assert_true(!flags_only.contains("target ="))
  // The JS prebuild used `===`; keep reading it so an older checkout still
  // gets the same verdict.
  let legacy = "if (platform === \"android\") {\n  extraFlags = [\"-lvulkan\"];\n}\nif (platform === \"harmonyos\") {\n}\n"
  assert_eq(validate_build_flags("build.js", legacy).length(), 1)
}

///|
test "parse_repo_root handles help, missing values, and unknown flags" {
  match parse_repo_root(["--repo-root", "/repo"]) {
    Ok(root) => assert_eq(root, "/repo")
    Err(_) => assert_true(false)
  }
  match parse_repo_root(["--help"]) {
    Err(message) => assert_eq(message, "help")
    Ok(_) => assert_true(false)
  }
  match parse_repo_root(["--repo-root"]) {
    Err(message) => assert_eq(message, "missing value for --repo-root")
    Ok(_) => assert_true(false)
  }
  match parse_repo_root(["--wat"]) {
    Err(message) => assert_eq(message, "Unknown argument: --wat")
    Ok(_) => assert_true(false)
  }
}
