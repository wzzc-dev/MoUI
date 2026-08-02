///|
/// Specification tests for the reference extraction and normalization of
/// `validate_doc_references`. These assert the validator's parsing behavior
/// (kept as the exception to the self-test cleanup: they test behavior of
/// the tooling, not the tool running itself).

///|
test "link_targets extracts inline link targets" {
  let targets = link_targets("see [docs](docs/testing.md) and [x](https://a.b)")
  assert_eq(targets.length(), 2)
  assert_eq(targets[0], "docs/testing.md")
  assert_eq(targets[1], "https://a.b")
}

///|
test "link_targets extracts reference-style definitions" {
  let targets = link_targets("[label]: docs/architecture-map.md")
  assert_eq(targets.length(), 1)
  assert_eq(targets[0], "docs/architecture-map.md")
}

///|
test "link_targets ignores anchor-only references" {
  let targets = link_targets("[label]: #section")
  assert_eq(targets.length(), 0)
}

///|
test "command_paths extracts repository paths" {
  let paths = command_paths(
    "node scripts/validate-api-surface.mjs --repo-root .",
  )
  assert_eq(paths.length(), 1)
  assert_eq(paths[0], "scripts/validate-api-surface.mjs")
}

///|
test "command_paths handles ./ prefix and skips flags and window/" {
  let paths = command_paths(
    "sh ./scripts/check.sh --profile daily window/scripts/x.sh",
  )
  assert_eq(paths.length(), 1)
  assert_eq(paths[0], "scripts/check.sh")
}

///|
test "command_paths skips glob tokens and non-commands" {
  assert_eq(command_paths("node scripts/*.mjs").length(), 0)
  assert_eq(command_paths("echo hello").length(), 0)
}

///|
test "strip_anchor removes anchors" {
  assert_eq(strip_anchor("docs/testing.md#section"), "docs/testing.md")
  assert_eq(strip_anchor("docs/testing.md"), "docs/testing.md")
}

///|
test "find_from finds needles after an offset" {
  assert_eq(find_from("a-b-c", "-", 0), Some(1))
  assert_eq(find_from("a-b-c", "-", 2), Some(3))
  assert_eq(find_from("abc", "z", 0), None)
}

///|
test "normalize_inline_path cuts line-number suffixes" {
  assert_eq(
    normalize_inline_path("moui/backend/macos/macos_services.mbt:84"),
    Some("moui/backend/macos/macos_services.mbt"),
  )
  assert_eq(
    normalize_inline_path(
      "tools/moui/validate_harness_invariants/main.mbt:440-451",
    ),
    Some("tools/moui/validate_harness_invariants/main.mbt"),
  )
}

///|
test "normalize_inline_path skips urls, globs, window and smoke evidence" {
  assert_eq(normalize_inline_path("https://example.com"), None)
  assert_eq(normalize_inline_path("scripts/*.mjs"), None)
  assert_eq(normalize_inline_path("window/scripts/foo.sh"), None)
  assert_eq(normalize_inline_path("smoke/evidence"), None)
  assert_eq(normalize_inline_path("tools/call"), None)
}

///|
test "normalize_inline_path cuts parenthesized annotations" {
  assert_eq(
    normalize_inline_path("scripts/refresh-evidence-table.mjs（带参数）"),
    Some("scripts/refresh-evidence-table.mjs"),
  )
}

///|
test "normalize_inline_path keeps dotted moui symbol references" {
  assert_eq(
    normalize_inline_path("moui/views.web_view"),
    Some("moui/views.web_view"),
  )
}

///|
test "normalize_inline_path skips bare moui package names" {
  assert_eq(normalize_inline_path("moui/style"), None)
}
