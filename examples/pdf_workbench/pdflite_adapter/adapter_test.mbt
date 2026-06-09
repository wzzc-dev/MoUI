///|
test "pdflite adapter loads minimum document into workbench summary" {
  let bytes = pdflite_minimum_pdf_bytes()
  assert_true(bytes.length() > 0)
  match load_document_from_bytes(path="/tmp/minimum.pdf", bytes~) {
    @app.PdfWorkbenchLoadResult::Loaded(document) => {
      inspect(document.page_count, content="1")
      inspect(document.selected_page, content="1")
      assert_true(document.writeback_available)
      assert_true(document.metadata_summary.contains("pdflite-adapter"))
    }
    @app.PdfWorkbenchLoadResult::Failed(reason) => fail(reason)
  }
}

///|
test "pdflite adapter loads generated three page document" {
  let bytes = pdflite_three_page_pdf_bytes()
  assert_true(bytes.length() > 0)
  match load_document_from_bytes(path="/tmp/three-page.pdf", bytes~) {
    @app.PdfWorkbenchLoadResult::Loaded(document) => {
      inspect(document.page_count, content="3")
      inspect(document.selected_page, content="1")
      inspect(document.page_summaries.length(), content="3")
      assert_true(document.writeback_available)
      assert_true(document.metadata_summary.contains("pdflite-adapter"))
    }
    @app.PdfWorkbenchLoadResult::Failed(reason) => fail(reason)
  }
}

///|
test "pdflite adapter rejects malformed bytes" {
  match load_document_from_bytes(path="/tmp/bad.pdf", bytes=b"not a pdf") {
    @app.PdfWorkbenchLoadResult::Loaded(_) => fail("expected parse failure")
    @app.PdfWorkbenchLoadResult::Failed(reason) =>
      inspect(reason, content="PDF parse failed")
  }
}

///|
test "pdflite adapter service handler exposes real document services" {
  let bytes = pdflite_minimum_pdf_bytes()
  let services = service_handler().document_services()
  let document = match services.load_document("/tmp/minimum.pdf", bytes) {
    @app.PdfWorkbenchLoadResult::Loaded(document) => document
    @app.PdfWorkbenchLoadResult::Failed(reason) => fail(reason)
  }
  assert_true(document.writeback_available)
  assert_true(document.metadata_summary.contains("pdflite-adapter"))
  let edited = document.with_edit(
    @app.PdfWorkbenchEdit::StampText(1, "SERVICE"),
  )
  match services.writeback_document(edited) {
    @app.PdfWorkbenchDocumentWritebackResult::WritebackReady(
      output,
      diagnostics
    ) => {
      assert_true(output.length() > bytes.length())
      assert_true(diagnostics.any(entry => entry.contains("StampText")))
      match services.load_document("/tmp/service-output.pdf", output) {
        @app.PdfWorkbenchLoadResult::Loaded(reparsed) => {
          assert_true(reparsed.extracted_text.contains("SERVICE"))
          assert_true(reparsed.writeback_available)
        }
        @app.PdfWorkbenchLoadResult::Failed(reason) => fail(reason)
      }
    }
    @app.PdfWorkbenchDocumentWritebackResult::WritebackFailed(reason) =>
      fail(reason)
  }
}

///|
test "pdflite adapter rotate crop and writeback roundtrip" {
  let bytes = pdflite_minimum_pdf_bytes()
  assert_true(pdflite_rotate_crop_roundtrip(bytes))
}

///|
test "pdflite adapter writeback applies rotate and crop edits" {
  let bytes = pdflite_minimum_pdf_bytes()
  let document = match
    load_document_from_bytes(path="/tmp/minimum.pdf", bytes~) {
    @app.PdfWorkbenchLoadResult::Loaded(document) => document
    @app.PdfWorkbenchLoadResult::Failed(reason) => fail(reason)
  }
  let edited = document
    .with_edit(@app.PdfWorkbenchEdit::RotatePage(1, 90))
    .with_edit(
      @app.PdfWorkbenchEdit::CropPage(1, {
        left: 36.0,
        bottom: 36.0,
        right: 523.0,
        top: 770.0,
      }),
    )
  match writeback_document(edited) {
    @app.PdfWorkbenchDocumentWritebackResult::WritebackReady(
      output,
      diagnostics
    ) => {
      assert_true(output.length() > 0)
      inspect(diagnostics.length(), content="2")
      match load_document_from_bytes(path="/tmp/output.pdf", bytes=output) {
        @app.PdfWorkbenchLoadResult::Loaded(reparsed) =>
          inspect(reparsed.page_count, content="1")
        @app.PdfWorkbenchLoadResult::Failed(reason) => fail(reason)
      }
    }
    @app.PdfWorkbenchDocumentWritebackResult::WritebackFailed(reason) =>
      fail(reason)
  }
}

///|
test "pdflite adapter writeback applies stamp edits" {
  let bytes = pdflite_minimum_pdf_bytes()
  let document = match
    load_document_from_bytes(path="/tmp/minimum.pdf", bytes~) {
    @app.PdfWorkbenchLoadResult::Loaded(document) => document
    @app.PdfWorkbenchLoadResult::Failed(reason) => fail(reason)
  }
  let edited = document.with_edit(
    @app.PdfWorkbenchEdit::StampText(1, "REVIEWED"),
  )
  match writeback_document(edited) {
    @app.PdfWorkbenchDocumentWritebackResult::WritebackReady(
      output,
      diagnostics
    ) => {
      assert_true(output.length() > bytes.length())
      inspect(diagnostics.length(), content="1")
      assert_true(diagnostics[0].contains("StampText"))
      match load_document_from_bytes(path="/tmp/stamped.pdf", bytes=output) {
        @app.PdfWorkbenchLoadResult::Loaded(reparsed) => {
          inspect(reparsed.page_count, content="1")
          assert_true(reparsed.extracted_text.contains("REVIEWED"))
        }
        @app.PdfWorkbenchLoadResult::Failed(reason) => fail(reason)
      }
    }
    @app.PdfWorkbenchDocumentWritebackResult::WritebackFailed(reason) =>
      fail(reason)
  }
}

///|
test "pdflite adapter writeback applies metadata title edits" {
  let bytes = pdflite_minimum_pdf_bytes()
  let document = match
    load_document_from_bytes(path="/tmp/minimum.pdf", bytes~) {
    @app.PdfWorkbenchLoadResult::Loaded(document) => document
    @app.PdfWorkbenchLoadResult::Failed(reason) => fail(reason)
  }
  let edited = document.with_edit(
    @app.PdfWorkbenchEdit::SetMetadataTitle("Quarterly Review"),
  )
  match writeback_document(edited) {
    @app.PdfWorkbenchDocumentWritebackResult::WritebackReady(
      output,
      diagnostics
    ) => {
      assert_true(output.length() > bytes.length())
      inspect(diagnostics.length(), content="1")
      assert_true(diagnostics[0].contains("SetMetadataTitle"))
      match load_document_from_bytes(path="/tmp/titled.pdf", bytes=output) {
        @app.PdfWorkbenchLoadResult::Loaded(reparsed) => {
          inspect(reparsed.page_count, content="1")
          inspect(reparsed.metadata_title, content="Quarterly Review")
          assert_true(reparsed.metadata_summary.contains("Quarterly Review"))
        }
        @app.PdfWorkbenchLoadResult::Failed(reason) => fail(reason)
      }
    }
    @app.PdfWorkbenchDocumentWritebackResult::WritebackFailed(reason) =>
      fail(reason)
  }
}

///|
test "pdflite adapter writeback applies bookmark edits" {
  let bytes = pdflite_minimum_pdf_bytes()
  let document = match
    load_document_from_bytes(path="/tmp/minimum.pdf", bytes~) {
    @app.PdfWorkbenchLoadResult::Loaded(document) => document
    @app.PdfWorkbenchLoadResult::Failed(reason) => fail(reason)
  }
  let edited = document.with_edit(
    @app.PdfWorkbenchEdit::AddBookmark(1, "Chapter 1"),
  )
  match writeback_document(edited) {
    @app.PdfWorkbenchDocumentWritebackResult::WritebackReady(
      output,
      diagnostics
    ) => {
      assert_true(output.length() > bytes.length())
      inspect(diagnostics.length(), content="1")
      assert_true(diagnostics[0].contains("AddBookmark"))
      let reparsed = @pdf.pdf_read_document_from_bytes(output) catch {
        _ => fail("failed to reparse bookmark output")
      }
      let bookmarks = reparsed.read_bookmarks(preserve_actions=true) catch {
        _ => fail("failed to read written bookmarks")
      }
      inspect(bookmarks.length(), content="1")
      inspect(
        @utf8.decode_lossy(@pdf.pdf_utf8_of_pdfdocstring(bookmarks[0].text)),
        content="Chapter 1",
      )
      inspect(
        reparsed.page_number_of_target(bookmarks[0].target) catch {
          _ => fail("failed to resolve bookmark target")
        },
        content="1",
      )
    }
    @app.PdfWorkbenchDocumentWritebackResult::WritebackFailed(reason) =>
      fail(reason)
  }
}

///|
test "pdflite adapter writeback applies text annotation edits" {
  let bytes = pdflite_minimum_pdf_bytes()
  let document = match
    load_document_from_bytes(path="/tmp/minimum.pdf", bytes~) {
    @app.PdfWorkbenchLoadResult::Loaded(document) => document
    @app.PdfWorkbenchLoadResult::Failed(reason) => fail(reason)
  }
  let edited = document.with_edit(
    @app.PdfWorkbenchEdit::AddTextAnnotation(1, "Check the source table"),
  )
  match writeback_document(edited) {
    @app.PdfWorkbenchDocumentWritebackResult::WritebackReady(
      output,
      diagnostics
    ) => {
      assert_true(output.length() > bytes.length())
      inspect(diagnostics.length(), content="1")
      assert_true(diagnostics[0].contains("AddTextAnnotation"))
      let reparsed = @pdf.pdf_read_document_from_bytes(output) catch {
        _ => fail("failed to reparse annotation output")
      }
      let pages = reparsed.pages_of_pagetree() catch {
        _ => fail("failed to read annotation output pages")
      }
      let annotations = reparsed.annotations_of_page(pages[0]) catch {
        _ => fail("failed to read written annotations")
      }
      inspect(annotations.length(), content="1")
      guard annotations[0].subtype is AnnotationText else {
        fail("expected text annotation subtype")
      }
      guard annotations[0].contents is Some(contents) else {
        fail("expected annotation contents")
      }
      inspect(
        @utf8.decode_lossy(@pdf.pdf_utf8_of_pdfdocstring(contents)),
        content="Check the source table",
      )
    }
    @app.PdfWorkbenchDocumentWritebackResult::WritebackFailed(reason) =>
      fail(reason)
  }
}
