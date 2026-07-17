///|
test "extracts unique window versions" {
  let text =
    #|deps = {
    #|  "wzzc-dev/window@0.1.2",
    #|  "other@1",
    #|  "wzzc-dev/window@0.1.2",
    #|}
    #|
  let versions = unique_strings(extract_window_versions(text))
  debug_inspect(
    versions,
    content=(
      #|["0.1.2"]
    ),
  )
}

///|
test "rejects multiple distinct versions" {
  // Direct function path uses file; unit-test extraction uniqueness only.
  let versions = unique_strings(
    extract_window_versions(
      "\"wzzc-dev/window@1.0.0\" \"wzzc-dev/window@2.0.0\"",
    ),
  )
  debug_inspect(versions.length(), content="2")
}
