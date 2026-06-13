///|
test "pdf workbench loads minimum document with lightweight summary" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  assert_true(bytes.length() > 0)
  match PdfWorkbenchDocument::from_bytes(path="/tmp/minimum.pdf", bytes~) {
    Loaded(document) => {
      inspect(document.page_count, content="1")
      inspect(document.selected_page, content="1")
      assert_true(document.metadata_summary.contains("lightweight-ui-shell"))
      assert_false(document.writeback_available)
    }
    Failed(reason) => fail(reason)
  }
}

///|
test "pdf workbench rejects malformed bytes" {
  match
    PdfWorkbenchDocument::from_bytes(path="/tmp/bad.pdf", bytes=b"not a pdf") {
    Loaded(_) => fail("expected parse failure")
    Failed(reason) => inspect(reason, content="PDF header not found")
  }
}
