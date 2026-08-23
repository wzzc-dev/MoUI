///|
test "fallback diagnostics input carries devtools report fields" {
  let input = ShowcaseDiagnosticsInput::fallback()
  assert_true(input.devtools.summary_text.length() > 0)
  assert_true(input.devtools.report_text.contains("[view]"))
  assert_true(input.devtools.json_text.length() > 0)
}

///|
test "devtools inspector card builds from model input" {
  let model = ShowcaseModel::new()
  let view = model.devtools_inspector_card(@views.default_theme(), 640.0)
  ignore(view)
}
