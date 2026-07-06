///|
fn consumer(path : String, text : String) -> ConsumerText {
  { path, text: Some(text) }
}

///|
test "counts only committed ./window workspace member lines" {
  inspect(
    count_window_workspace_members("members = [\n  \"./window\",\n]\n"),
    content="1",
  )
  inspect(
    count_window_workspace_members("  \"./window\",  \n\"./window\",\n"),
    content="2",
  )
  inspect(
    count_window_workspace_members("# \"./window\",\n\"./window\""),
    content="0",
  )
}

///|
test "extracts all quoted wzzc-dev/window versions" {
  let text =
    #|import {
    #|  "wzzc-dev/window@0.5.1-0.1.6",
    #|  "wzzc-dev/window@0.5.1-0.1.7",
    #|}
    #|
  inspect(
    version_list(extract_window_versions(text)),
    content="0.5.1-0.1.6, 0.5.1-0.1.7",
  )
}

///|
test "valid consumers pin one shared window version" {
  let result = validate_window_dependency_inputs(
    Some("members = [\n  \"./moui\",\n]\n"),
    [
      consumer("moui/moon.mod", "\"wzzc-dev/window@0.5.1-0.1.6\""),
      consumer("moui_skia/moon.mod", "\"wzzc-dev/window@0.5.1-0.1.6\""),
    ],
  )
  inspect(result.errors.is_empty(), content="true")
  inspect(result.pinned, content="0.5.1-0.1.6")
}

///|
test "rejects local window workspace member" {
  let result = validate_window_dependency_inputs(
    Some("members = [\n  \"./window\",\n]\n"),
    [consumer("moui/moon.mod", "\"wzzc-dev/window@0.5.1-0.1.6\"")],
  )
  inspect(result.errors.length(), content="1")
  assert_true(
    result.errors[0].contains(
      "moon.work lists \"./window\" as a workspace member (1 occurrence(s)).",
    ),
  )
  assert_true(result.errors[0].contains("scripts/window-dev-mode.sh off"))
}

///|
test "reports missing expected consumer dependency" {
  let result = validate_window_dependency_inputs(Some("members = []\n"), [
    consumer("moui/moon.mod", "import {}"),
  ])
  inspect(result.errors.length(), content="1")
  inspect(
    result.errors[0],
    content="moui/moon.mod: expected a \"wzzc-dev/window@<version>\" declaration but found none.\n" +
      "  If this module no longer depends on window, remove it from EXPECTED_WINDOW_CONSUMERS.\n" +
      "  Otherwise restore the import.",
  )
}

///|
test "reports multiple versions in one consumer" {
  let result = validate_window_dependency_inputs(Some("members = []\n"), [
    consumer(
      "moui/moon.mod", "\"wzzc-dev/window@0.5.1-0.1.6\"\n\"wzzc-dev/window@0.5.1-0.1.7\"",
    ),
  ])
  inspect(result.errors.length(), content="2")
  assert_true(
    result.errors[0].contains(
      "moui/moon.mod: declares wzzc-dev/window at multiple versions: 0.5.1-0.1.6, 0.5.1-0.1.7.",
    ),
  )
  assert_true(
    result.errors[1].contains(
      "wzzc-dev/window version mismatch across consumers:",
    ),
  )
}

///|
test "reports cross-consumer version mismatch" {
  let result = validate_window_dependency_inputs(Some("members = []\n"), [
    consumer("moui/moon.mod", "\"wzzc-dev/window@0.5.1-0.1.6\""),
    consumer("moui_skia/moon.mod", "\"wzzc-dev/window@0.5.1-0.1.7\""),
  ])
  inspect(result.errors.length(), content="1")
  assert_true(result.errors[0].contains("  - moui/moon.mod: 0.5.1-0.1.6"))
  assert_true(result.errors[0].contains("  - moui_skia/moon.mod: 0.5.1-0.1.7"))
}
