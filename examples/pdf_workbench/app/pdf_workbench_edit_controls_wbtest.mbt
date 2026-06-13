///|
test "pdf workbench undo last button clears latest overlay only" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let services = pdf_workbench_test_binary_services(bytes)
  let render_count = Ref(0)
  let keys : Array[String] = []
  let raster_services = pdf_workbench_ready_raster_services(render_count, keys)
  let loaded = run_pdf_workbench_effect_chain(
    PdfWorkbenchModel::new().update_with_services(
      OpenRequested,
      services,
      raster_services~,
    ),
    services,
    raster_services~,
  )
  let edited = loaded.model
    .update(AnnotationTextChanged("Keep this note"))
    .update(AddAnnotationForCurrentPage)
    .update(StampCurrentPage)
  let runtime = edited.runtime_with_services(
    services,
    raster_services~,
    width=1120.0,
    height=720.0,
  )
  assert_true(
    pdf_workbench_draw_has_text_containing(runtime.draw_commands(), "REVIEWED"),
  )
  assert_true(
    pdf_workbench_draw_has_text_containing(
      runtime.draw_commands(),
      "Keep this note",
    ),
  )
  pdf_workbench_click_text(runtime, "Undo Last")
  let commands = runtime.draw_commands()
  assert_false(pdf_workbench_draw_has_text_containing(commands, "REVIEWED"))
  assert_true(
    pdf_workbench_draw_has_text_containing(commands, "Keep this note"),
  )
}

///|
test "pdf workbench discard edits button clears visible stamp overlay" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let services = pdf_workbench_test_binary_services(bytes)
  let render_count = Ref(0)
  let keys : Array[String] = []
  let raster_services = pdf_workbench_ready_raster_services(render_count, keys)
  let loaded = run_pdf_workbench_effect_chain(
    PdfWorkbenchModel::new().update_with_services(
      OpenRequested,
      services,
      raster_services~,
    ),
    services,
    raster_services~,
  )
  let edited = loaded.model.update(StampCurrentPage)
  let runtime = edited.runtime_with_services(
    services,
    raster_services~,
    width=1120.0,
    height=720.0,
  )
  assert_true(
    pdf_workbench_draw_has_text_containing(runtime.draw_commands(), "REVIEWED"),
  )
  pdf_workbench_click_text(runtime, "Discard Edits")
  assert_false(
    pdf_workbench_draw_has_text_containing(runtime.draw_commands(), "REVIEWED"),
  )
  assert_true(
    pdf_workbench_draw_has_text_containing(
      runtime.draw_commands(),
      "Saved state",
    ),
  )
}
