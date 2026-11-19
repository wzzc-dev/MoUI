// White-box tests for the source-file policy gate: scan skips, relative-path
// safety, line counting, classification thresholds, and entry lookup.

///|
fn entry(path : String, max_lines : Int32) -> PolicyEntry {
  {
    path,
    classification: "logic",
    max_lines,
    reason: "test",
    generator: "",
    check_command: "",
    header: "",
  }
}

///|
test "skipped_directory ignores build and dependency directories only" {
  assert_true(skipped_directory("_build"))
  assert_true(skipped_directory("node_modules"))
  assert_true(skipped_directory(".git"))
  assert_true(skipped_directory("artifacts"))
  assert_true(skipped_directory(".dsh"))
  assert_true(!skipped_directory("moui"))
  assert_true(!skipped_directory("src"))
  assert_true(!skipped_directory("Build"))
}

///|
test "repository_relative_path rejects absolute and escaping paths" {
  assert_true(repository_relative_path("moui/core/view.mbt"))
  assert_true(repository_relative_path("examples/showcase/app/model.mbt"))
  assert_true(!repository_relative_path(""))
  assert_true(!repository_relative_path("/abs/path.mbt"))
  assert_true(!repository_relative_path("\\windows\\path.mbt"))
  assert_true(!repository_relative_path("a\\b.mbt"))
  assert_true(!repository_relative_path("C:relative.mbt"))
  assert_true(!repository_relative_path(".."))
  assert_true(!repository_relative_path("../outside.mbt"))
  assert_true(!repository_relative_path("a/../b.mbt"))
  assert_true(!repository_relative_path("dir/.."))
}

///|
test "source line counts and classification thresholds match policy" {
  assert_eq(source_line_count(""), 0)
  assert_eq(source_line_count("a"), 1)
  assert_eq(source_line_count("a\n"), 1)
  assert_eq(source_line_count("a\nb"), 2)
  assert_eq(source_line_count("a\n\n"), 2)
  assert_true(has_source_extension("a.mbt", [".mbt", ".mjs"]))
  assert_true(has_source_extension("a.mjs", [".mbt", ".mjs"]))
  assert_true(!has_source_extension("a.mbti", [".mbt"]))
  assert_true(!has_source_extension("a.js", [".mbt", ".mjs"]))
  // At review_lines the file needs review; hard limit only trips above it.
  assert_eq(unregistered_logic_classification(79, 80, 150), "ok")
  assert_eq(unregistered_logic_classification(80, 80, 150), "review")
  assert_eq(unregistered_logic_classification(150, 80, 150), "review")
  assert_eq(unregistered_logic_classification(151, 80, 150), "hard-limit")
}

///|
test "entry_for_path matches the exact tracked path" {
  let entries = [entry("moui/core/a.mbt", 200), entry("moui/core/b.mbt", 400)]
  match entry_for_path(entries, "moui/core/b.mbt") {
    Some(found) => {
      assert_eq(found.path, "moui/core/b.mbt")
      assert_eq(found.max_lines, 400)
    }
    None => assert_true(false)
  }
  match entry_for_path(entries, "moui/core/missing.mbt") {
    None => assert_true(true)
    Some(_) => assert_true(false)
  }
}
