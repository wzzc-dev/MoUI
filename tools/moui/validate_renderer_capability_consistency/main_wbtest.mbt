///|
/// Specification tests for the report-table parsing and status mapping of
/// `validate_renderer_capability_consistency`. These test the validator's
/// own parsing behavior (a product of the tooling), so they are kept as the
/// exception to the self-test cleanup: they assert behavior, not the tool
/// running itself.

///|
test "split_cells strips leading/trailing pipes and whitespace" {
  let cells = split_cells("| Rect | supported | partial | gap | sun | note |")
  assert_eq(cells[0], "Rect")
  assert_eq(cells[1], "supported")
  assert_eq(cells[3], "gap")
  assert_eq(cells.length(), 6)
}

///|
test "split_cells handles rows without leading pipe" {
  let cells = split_cells("Rect | supported | partial | gap | sun")
  assert_eq(cells[0], "Rect")
  assert_eq(cells.length(), 5)
}

///|
test "feature_by_report_name covers all report rows" {
  let names = [
    "Rect", "Rounded rect", "Gradient", "Shadow", "Text", "Image", "Clip", "Transform",
    "Opacity", "Layer compositing", "Blend mode", "Filter effect", "Path/vector",
    "Shader effect", "Text shaping", "Emoji text", "Async image",
  ]
  for name in names {
    match feature_by_report_name(name) {
      Some(_) => ()
      None => fail("missing mapping for \{name}")
    }
  }
  match feature_by_report_name("Not a feature") {
    None => ()
    Some(_) => fail("unknown name should map to None")
  }
}

///|
test "status_from_report maps the five report statuses" {
  assert_eq(
    status_from_report("supported"),
    Some(@render.RendererFeatureStatus::Supported),
  )
  assert_eq(
    status_from_report("partial"),
    Some(@render.RendererFeatureStatus::Partial),
  )
  assert_eq(status_from_report("gap"), Some(@render.RendererFeatureStatus::Gap))
  assert_eq(
    status_from_report("host-forwarded"),
    Some(@render.RendererFeatureStatus::HostForwarded),
  )
  assert_eq(
    status_from_report("unavailable"),
    Some(@render.RendererFeatureStatus::Unavailable),
  )
  assert_eq(status_from_report("SUPPORTED"), None)
  assert_eq(status_from_report(""), None)
}

///|
test "parse_table finds the header and all data rows" {
  let text =
    #|# Title
    #|
    #|| Feature | Skia raster native | Web wasm-gc | Native wgpu diagnostic | Sun CPU raster | Follow-up |
    #|| --- | --- | --- | --- | --- | --- |
    #|| Rect | supported | supported | supported | supported | note |
    #|| Gradient | supported | partial | partial | supported | note |
    #|| Text shaping | supported | supported | supported | partial | note |
  let (header_line, rows) = parse_table(text)
  assert_eq(header_line, 3)
  assert_eq(rows.length(), 3)
  assert_eq(rows[0].feature_name, "Rect")
  assert_eq(rows[0].skia, "supported")
  assert_eq(rows[1].wgpu, "partial")
  assert_eq(rows[2].sun, "partial")
}

///|
test "parse_table ignores tables without the capability header" {
  let (header_line, rows) = parse_table("| A | B |\n| --- | --- |\n| x | y |")
  assert_eq(header_line, 0)
  assert_eq(rows.length(), 0)
}

///|
test "status_label round-trips report strings" {
  assert_eq(status_label(@render.RendererFeatureStatus::Supported), "supported")
  assert_eq(status_label(@render.RendererFeatureStatus::Partial), "partial")
  assert_eq(status_label(@render.RendererFeatureStatus::Gap), "gap")
  assert_eq(
    status_label(@render.RendererFeatureStatus::HostForwarded),
    "host-forwarded",
  )
  assert_eq(
    status_label(@render.RendererFeatureStatus::Unavailable),
    "unavailable",
  )
}
