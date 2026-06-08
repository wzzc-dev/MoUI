///|
test "pdflite service protocol JSONL encodes PDF bytes as base64 diagnostics" {
  let bytes = b"%PDF-\x00\xff"
  let line = PdfWorkbenchPdfliteServiceRequest::LoadDocument(
    "/tmp/sample.pdf", bytes,
  ).to_json_line()
  assert_true(line.contains("\"type\":\"load\""))
  assert_true(line.contains("\"path\":\"/tmp/sample.pdf\""))
  assert_true(line.contains("\"byteLength\":" + bytes.length().to_string()))
  assert_false(line.contains("%PDF-"))
  let encoded = pdf_workbench_pdflite_protocol_encode_bytes(bytes)
  guard pdf_workbench_pdflite_protocol_decode_bytes(encoded) is Some(decoded) else {
    fail("expected decoded bytes")
  }
  inspect(decoded.length(), content="\{bytes.length()}")
  inspect(decoded[0].to_int(), content="\{bytes[0].to_int()}")
  inspect(
    decoded[decoded.length() - 1].to_int(),
    content="\{bytes[bytes.length() - 1].to_int()}",
  )
}

///|
test "pdflite service protocol decodes load and writeback request lines" {
  let bytes = b"%PDF-1.4\n%protocol\n"
  let load_line = PdfWorkbenchPdfliteServiceRequest::LoadDocument(
    "/tmp/load.pdf", bytes,
  ).to_json_line()
  match PdfWorkbenchPdfliteServiceRequest::from_json_line(load_line) {
    Some(LoadDocument(path, decoded)) => {
      inspect(path, content="/tmp/load.pdf")
      inspect(decoded.length(), content="\{bytes.length()}")
    }
    _ => fail("expected decoded load request")
  }
  let edits : Array[@app.PdfWorkbenchEdit] = [
    @app.PdfWorkbenchEdit::RotatePage(1, 90),
    @app.PdfWorkbenchEdit::CropPage(1, {
      left: 1.0,
      bottom: 2.0,
      right: 3.0,
      top: 4.0,
    }),
    @app.PdfWorkbenchEdit::StampText(1, "REVIEWED"),
    @app.PdfWorkbenchEdit::SetMetadataTitle("Title"),
    @app.PdfWorkbenchEdit::AddBookmark(1, "Chapter"),
    @app.PdfWorkbenchEdit::AddTextAnnotation(1, "Note"),
  ]
  let write_line = PdfWorkbenchPdfliteServiceRequest::WritebackDocument(
    "/tmp/write.pdf", bytes, edits,
  ).to_json_line()
  match PdfWorkbenchPdfliteServiceRequest::from_json_line(write_line) {
    Some(WritebackDocument(path, decoded, decoded_edits)) => {
      inspect(path, content="/tmp/write.pdf")
      inspect(decoded.length(), content="\{bytes.length()}")
      inspect(decoded_edits.length(), content="6")
      guard decoded_edits[1] is @app.PdfWorkbenchEdit::CropPage(_, box) else {
        fail("expected crop edit")
      }
      inspect(box.right, content="3")
    }
    _ => fail("expected decoded writeback request")
  }
}

///|
test "pdflite service protocol rejects malformed request lines" {
  inspect(
    PdfWorkbenchPdfliteServiceRequest::from_json_line("not json") is None,
    content="true",
  )
  inspect(
    PdfWorkbenchPdfliteServiceRequest::from_json_line(
      ({ "type": "load", "path": "/tmp/a.pdf", "bytesBase64": "?" } : Json).stringify(),
    )
    is None,
    content="true",
  )
  inspect(
    PdfWorkbenchPdfliteServiceRequest::from_json_line(
      (
        {
          "type": "writeback",
          "path": "/tmp/a.pdf",
          "bytesBase64": pdf_workbench_pdflite_protocol_encode_bytes(b"pdf"),
          "edits": [["Nope"]],
        } : Json).stringify(),
    )
    is None,
    content="true",
  )
}

///|
test "pdflite service handler adapts to document services" {
  let bytes = @app.pdf_workbench_minimum_pdf_bytes()
  let output = b"%PDF-1.4\n%written\n"
  let load_count = Ref(0)
  let write_count = Ref(0)
  let write_input_length = Ref(0)
  let write_edit_count = Ref(0)
  let handler = PdfWorkbenchPdfliteServiceHandler::new(handle=request => {
    match request {
      LoadDocument(path, input) => {
        load_count.val = load_count.val + 1
        match
          @app.PdfWorkbenchDocument::from_engine_summary(
            path~,
            original_bytes=input,
            page_count=2,
            selected_page=1,
            extracted_text="alpha\nbeta",
            dirty=false,
            writeback_available=true,
            metadata_title="Protocol Title",
          ) {
          @app.PdfWorkbenchLoadResult::Loaded(document) =>
            DocumentLoaded(document)
          @app.PdfWorkbenchLoadResult::Failed(reason) => ServiceFailed(reason)
        }
      }
      WritebackDocument(path, input, edits) => {
        ignore(path)
        write_input_length.val = input.length()
        write_edit_count.val = edits.length()
        write_count.val = write_count.val + 1
        WritebackReady(output, ["protocol writeback applied"])
      }
    }
  })
  let services = handler.document_services()
  match services.load_document("/tmp/protocol.pdf", bytes) {
    @app.PdfWorkbenchLoadResult::Loaded(document) => {
      inspect(document.page_count, content="2")
      inspect(document.metadata_title, content="Protocol Title")
      assert_true(document.writeback_available)
    }
    @app.PdfWorkbenchLoadResult::Failed(reason) => fail(reason)
  }
  let document = match
    @app.PdfWorkbenchDocument::from_engine_summary(
      path="/tmp/protocol.pdf",
      original_bytes=bytes,
      page_count=1,
      selected_page=1,
      extracted_text="editable",
      dirty=false,
      writeback_available=true,
    ) {
    @app.PdfWorkbenchLoadResult::Loaded(document) =>
      document.with_edit(@app.PdfWorkbenchEdit::StampText(1, "REVIEWED"))
    @app.PdfWorkbenchLoadResult::Failed(reason) => fail(reason)
  }
  match services.writeback_document(document) {
    @app.PdfWorkbenchDocumentWritebackResult::WritebackReady(
      written,
      diagnostics
    ) => {
      inspect(written.length(), content="\{output.length()}")
      inspect(diagnostics.length(), content="1")
      inspect(diagnostics[0], content="protocol writeback applied")
    }
    @app.PdfWorkbenchDocumentWritebackResult::WritebackFailed(reason) =>
      fail(reason)
  }
  inspect(load_count.val, content="1")
  inspect(write_count.val, content="1")
  assert_true(write_input_length.val > 0)
  inspect(write_edit_count.val, content="1")
}

///|
test "pdflite service response JSONL summarizes without dumping documents" {
  let bytes = @app.pdf_workbench_minimum_pdf_bytes()
  let document = match
    @app.PdfWorkbenchDocument::from_engine_summary(
      path="/tmp/loaded.pdf",
      original_bytes=bytes,
      page_count=3,
      selected_page=2,
      extracted_text="page text",
      dirty=false,
      writeback_available=true,
      unsupported_entries=["protocol diagnostic"],
      page_summaries=[
        {
          page_number: 1,
          text_preview: "page one",
          content_diagnostic: "diagnostic one",
        },
        {
          page_number: 2,
          text_preview: "page two",
          content_diagnostic: "diagnostic two",
        },
        {
          page_number: 3,
          text_preview: "page three",
          content_diagnostic: "diagnostic three",
        },
      ],
      metadata_summary="PDF 1.4; parser=pdflite protocol fixture",
      metadata_title="Loaded Title",
      outline_summary="Outline fixture",
      annotation_summary="Annotation fixture",
    ) {
    @app.PdfWorkbenchLoadResult::Loaded(document) => document
    @app.PdfWorkbenchLoadResult::Failed(reason) => fail(reason)
  }
  let line = PdfWorkbenchPdfliteServiceResponse::DocumentLoaded(document).to_json_line()
  assert_true(line.contains("\"type\":\"loaded\""))
  assert_true(line.contains("\"pageCount\":3"))
  assert_true(line.contains("Loaded Title"))
  assert_false(line.contains("%PDF-"))
  match
    PdfWorkbenchPdfliteServiceResponse::from_json_line(
      line,
      original_bytes=bytes,
    ) {
    Some(DocumentLoaded(decoded)) => {
      inspect(decoded.path, content="/tmp/loaded.pdf")
      inspect(decoded.original_bytes.length(), content="\{bytes.length()}")
      inspect(decoded.page_count, content="3")
      inspect(decoded.selected_page, content="2")
      inspect(decoded.metadata_title, content="Loaded Title")
      inspect(
        decoded.metadata_summary,
        content="PDF 1.4; parser=pdflite protocol fixture",
      )
      inspect(decoded.outline_summary, content="Outline fixture")
      inspect(decoded.annotation_summary, content="Annotation fixture")
      inspect(decoded.unsupported_entries.length(), content="1")
      inspect(decoded.page_summaries.length(), content="3")
      inspect(decoded.page_summaries[1].text_preview, content="page two")
      assert_true(decoded.writeback_available)
    }
    _ => fail("expected decoded loaded response")
  }
}

///|
test "pdflite service response JSONL decodes writeback and failure" {
  let output = b"%PDF-1.4\n%written\n"
  let line = PdfWorkbenchPdfliteServiceResponse::WritebackReady(output, [
    "writeback applied",
  ]).to_json_line()
  assert_false(line.contains("%PDF-"))
  match
    PdfWorkbenchPdfliteServiceResponse::from_json_line(line, original_bytes=b"") {
    Some(WritebackReady(bytes, diagnostics)) => {
      inspect(bytes.length(), content="\{output.length()}")
      inspect(diagnostics.length(), content="1")
      inspect(diagnostics[0], content="writeback applied")
    }
    _ => fail("expected decoded writeback response")
  }
  let failed = PdfWorkbenchPdfliteServiceResponse::ServiceFailed(
    "fixture failed",
  ).to_json_line()
  match
    PdfWorkbenchPdfliteServiceResponse::from_json_line(
      failed,
      original_bytes=b"",
    ) {
    Some(ServiceFailed(reason)) => inspect(reason, content="fixture failed")
    _ => fail("expected decoded failed response")
  }
}
