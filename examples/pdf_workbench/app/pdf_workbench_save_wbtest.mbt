///|
test "pdf workbench save writes original bytes when clean" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let written = Ref(0)
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(file_access=true),
    handle=request => {
      match request {
        @host.HostServiceRequest::BinaryFile(
          @host.HostBinaryFileRequest::WriteBytes(path, out)
        ) => {
          written.val = out.length()
          @host.HostServiceResponse::BinaryFileWritten(path)
        }
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let services = @host.app_services(bridge~)
  let model = match
    PdfWorkbenchDocument::from_bytes(path="/tmp/minimum.pdf", bytes~) {
    Loaded(document) =>
      {
        ..PdfWorkbenchModel::new(),
        document: Some(document),
        status: PdfWorkbenchStatus::Ready,
      }
    Failed(reason) => fail(reason)
  }
  let update = model.update_with_services(SaveRequested, services)
  let saved = run_pdf_workbench_effect(update, services)
  inspect(written.val > 0, content="true")
  guard saved.model.document is Some(document) else {
    fail("expected document")
  }
  assert_false(document.dirty)
}

///|
test "pdf workbench save as defaults to current PDF file name" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let seen_default_name = Ref("")
  let written_path = Ref("")
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      file_dialogs=true,
      file_access=true,
    ),
    handle=request => {
      match request {
        @host.HostServiceRequest::FileDialog(options) => {
          match options.default_name {
            Some(name) => seen_default_name.val = name
            None => seen_default_name.val = "<none>"
          }
          @host.HostServiceResponse::FileDialogSelection([
            "/tmp/exported-report.pdf",
          ])
        }
        @host.HostServiceRequest::BinaryFile(
          @host.HostBinaryFileRequest::WriteBytes(path, _)
        ) => {
          written_path.val = path
          @host.HostServiceResponse::BinaryFileWritten(path)
        }
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let services = @host.app_services(bridge~)
  let model = match
    PdfWorkbenchDocument::from_bytes(path="/tmp/quarterly-review", bytes~) {
    Loaded(document) =>
      {
        ..PdfWorkbenchModel::new(),
        document: Some(document),
        status: PdfWorkbenchStatus::Ready,
      }
    Failed(reason) => fail(reason)
  }
  let saved = run_pdf_workbench_effect_chain(
    model.update_with_services(SaveAsRequested, services),
    services,
  )
  inspect(seen_default_name.val, content="quarterly-review.pdf")
  inspect(written_path.val, content="/tmp/exported-report.pdf")
  guard saved.model.document is Some(document) else {
    fail("expected saved document")
  }
  inspect(document.path, content="/tmp/exported-report.pdf")
  assert_false(document.dirty)
}

///|
test "pdf workbench dirty save reports adapter requirement" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let model = match
    PdfWorkbenchDocument::from_bytes(path="/tmp/minimum.pdf", bytes~) {
    Loaded(document) =>
      {
        ..PdfWorkbenchModel::new(),
        document: Some({ ..document, dirty: true }),
        status: PdfWorkbenchStatus::Ready,
      }
    Failed(reason) => fail(reason)
  }
  let update = model.update_with_services(
    SaveRequested,
    @services.AppServices::unavailable(),
  )
  assert_false(update.effect is @moui.Effect::NoEffect)
  let failed = run_pdf_workbench_effect(
    update,
    @services.AppServices::unavailable(),
  )
  match failed.model.status {
    PdfWorkbenchStatus::Failed(reason) =>
      assert_true(reason.contains("pdflite adapter service"))
    _ => fail("expected dirty save failure")
  }
}

///|
test "pdf workbench dirty save uses document writeback service" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let output = b"%PDF-1.4\n%fake-writeback\n"
  let written = Ref(0)
  let writeback_count = Ref(0)
  let reload_count = Ref(0)
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(file_access=true),
    handle=request => {
      match request {
        @host.HostServiceRequest::BinaryFile(
          @host.HostBinaryFileRequest::WriteBytes(path, out)
        ) => {
          written.val = out.length()
          @host.HostServiceResponse::BinaryFileWritten(path)
        }
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let services = @host.app_services(bridge~)
  let document_services = PdfWorkbenchDocumentServices::new(
    load=(path, input) => {
      reload_count.val = reload_count.val + 1
      PdfWorkbenchDocument::from_engine_summary(
        path~,
        original_bytes=input,
        page_count=2,
        selected_page=1,
        extracted_text="reloaded page one\nreloaded page two",
        dirty=false,
        writeback_available=true,
        page_summaries=[
          {
            page_number: 1,
            text_preview: "reloaded page one",
            content_diagnostic: "reloaded after writeback",
          },
          {
            page_number: 2,
            text_preview: "reloaded page two",
            content_diagnostic: "reloaded after writeback",
          },
        ],
        metadata_summary="PDF 1.4; parser=fake-reload",
        metadata_title="Reloaded Title",
      )
    },
    writeback=document => {
      ignore(document)
      writeback_count.val = writeback_count.val + 1
      WritebackReady(output, ["fake writeback applied"])
    },
  )
  let model = match
    PdfWorkbenchDocument::from_engine_summary(
      path="/tmp/minimum.pdf",
      original_bytes=bytes,
      page_count=1,
      selected_page=1,
      extracted_text="editable page",
      dirty=false,
      writeback_available=true,
    ) {
    Loaded(document) =>
      {
        ..PdfWorkbenchModel::new(),
        document: Some(document),
        status: PdfWorkbenchStatus::Ready,
      }
    Failed(reason) => fail(reason)
  }
  let dirty = model.update(RotateCurrentPage)
  let update = dirty.update_with_services(
    SaveRequested,
    services,
    document_services~,
  )
  let saved = run_pdf_workbench_effect_chain(
    update,
    services,
    document_services~,
  )
  inspect(writeback_count.val, content="1")
  inspect(reload_count.val, content="1")
  inspect(written.val, content="\{output.length()}")
  guard saved.model.document is Some(document) else {
    fail("expected saved document")
  }
  assert_false(document.dirty)
  inspect(document.edits.length(), content="0")
  inspect(document.original_bytes.length(), content="\{output.length()}")
  inspect(document.page_count, content="2")
  inspect(document.metadata_title, content="Reloaded Title")
  inspect(saved.model.metadata_title_draft, content="Reloaded Title")
  inspect(document.selected_summary().text_preview, content="reloaded page one")
  assert_true(saved.model.last_event.contains("Saved and reloaded"))
  assert_true(
    document.unsupported_entries.any(entry => entry.contains("fake writeback")),
  )
}

///|
test "pdf workbench save keeps clean state when reload after writeback fails" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let output = b"%PDF-1.4\n%fake-writeback\n"
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(file_access=true),
    handle=request => {
      match request {
        @host.HostServiceRequest::BinaryFile(
          @host.HostBinaryFileRequest::WriteBytes(path, _)
        ) => @host.HostServiceResponse::BinaryFileWritten(path)
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let services = @host.app_services(bridge~)
  let document_services = PdfWorkbenchDocumentServices::new(
    load=(_path, _input) => Failed("reload parse failed for test"),
    writeback=_document => WritebackReady(output, ["fake writeback applied"]),
  )
  let model = match
    PdfWorkbenchDocument::from_engine_summary(
      path="/tmp/minimum.pdf",
      original_bytes=bytes,
      page_count=1,
      selected_page=1,
      extracted_text="editable page",
      dirty=false,
      writeback_available=true,
    ) {
    Loaded(document) =>
      {
        ..PdfWorkbenchModel::new(),
        document: Some(document),
        status: PdfWorkbenchStatus::Ready,
      }
    Failed(reason) => fail(reason)
  }
  let dirty = model.update(StampCurrentPage)
  let saved = run_pdf_workbench_effect_chain(
    dirty.update_with_services(SaveRequested, services, document_services~),
    services,
    document_services~,
  )
  guard saved.model.document is Some(document) else {
    fail("expected saved document")
  }
  assert_false(document.dirty)
  inspect(document.edits.length(), content="0")
  assert_true(
    document.unsupported_entries.any(entry => {
      entry.contains("Reload after save failed")
    }),
  )
}
