///|
test "pdf workbench failure banner can be dismissed" {
  let model = {
    ..PdfWorkbenchModel::new(),
    status: PdfWorkbenchStatus::Failed("PDF parse failed for test"),
    last_event: "PDF load failed",
  }
  let runtime = model.runtime(width=1120.0, height=720.0)
  assert_true(
    pdf_workbench_draw_has_text_containing(
      runtime.draw_commands(),
      "PDF Workbench needs attention",
    ),
  )
  assert_true(
    pdf_workbench_draw_has_text_containing(
      runtime.draw_commands(),
      "PDF parse failed for test",
    ),
  )
  pdf_workbench_click_text(runtime, "Dismiss")
  let commands = runtime.draw_commands()
  assert_false(
    pdf_workbench_draw_has_text_containing(
      commands, "PDF Workbench needs attention",
    ),
  )
  assert_false(
    pdf_workbench_draw_has_text_containing(
      commands, "PDF parse failed for test",
    ),
  )
  assert_true(pdf_workbench_draw_has_text_containing(commands, "Ready"))
}
