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

///|
test "pdf workbench rotate and crop mark document dirty" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
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
  let rotated = model.update(RotateCurrentPage)
  guard rotated.document is Some(rotated_document) else {
    fail("expected rotated document")
  }
  assert_true(rotated_document.dirty)
  let cropped = rotated.update(CropCurrentPage)
  guard cropped.document is Some(cropped_document) else {
    fail("expected cropped document")
  }
  assert_true(cropped_document.dirty)
  let stamped = cropped.update(StampCurrentPage)
  guard stamped.document is Some(stamped_document) else {
    fail("expected stamped document")
  }
  assert_true(stamped_document.dirty)
  inspect(stamped_document.edits.length(), content="3")
}

///|
test "pdf workbench metadata title apply marks document dirty" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
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
  let drafted = model.update(MetadataTitleChanged("Quarterly Review"))
  inspect(drafted.metadata_title_draft, content="Quarterly Review")
  let applied = drafted.update(ApplyMetadataTitle)
  guard applied.document is Some(document) else {
    fail("expected edited document")
  }
  assert_true(document.dirty)
  inspect(document.metadata_title, content="Quarterly Review")
  inspect(document.edits.length(), content="1")
  guard document.edits[0] is SetMetadataTitle("Quarterly Review") else {
    fail("expected metadata title edit")
  }
}

///|
test "pdf workbench add bookmark marks document dirty" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
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
  let drafted = model.update(BookmarkTitleChanged("Chapter 1"))
  inspect(drafted.bookmark_title_draft, content="Chapter 1")
  let applied = drafted.update(AddBookmarkForCurrentPage)
  guard applied.document is Some(document) else {
    fail("expected edited document")
  }
  assert_true(document.dirty)
  inspect(document.edits.length(), content="1")
  guard document.edits[0] is AddBookmark(1, "Chapter 1") else {
    fail("expected bookmark edit")
  }
}

///|
test "pdf workbench add note marks document dirty" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
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
  let drafted = model.update(AnnotationTextChanged("Check the source table"))
  inspect(drafted.annotation_text_draft, content="Check the source table")
  let applied = drafted.update(AddAnnotationForCurrentPage)
  guard applied.document is Some(document) else {
    fail("expected edited document")
  }
  assert_true(document.dirty)
  assert_true(document.annotation_summary.contains("Check the source table"))
  inspect(document.edits.length(), content="1")
  guard document.edits[0] is AddTextAnnotation(1, "Check the source table") else {
    fail("expected text annotation edit")
  }
}

///|
test "pdf workbench discard edits restores clean preview state" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let document = match
    PdfWorkbenchDocument::from_engine_summary(
      path="/tmp/minimum.pdf",
      original_bytes=bytes,
      page_count=1,
      selected_page=1,
      extracted_text="clean page text",
      dirty=false,
      writeback_available=false,
      unsupported_entries=["clean diagnostic"],
      page_summaries=[
        {
          page_number: 1,
          text_preview: "clean page text",
          content_diagnostic: "clean page diagnostic",
        },
      ],
      metadata_summary="PDF 1.4; parser=test",
      metadata_title="Original Title",
      outline_summary="clean outline",
      annotation_summary="Clean annotations",
    ) {
    Loaded(document) => document
    Failed(reason) => fail(reason)
  }
  let model = {
    ..PdfWorkbenchModel::new(),
    document: Some(document),
    status: PdfWorkbenchStatus::Ready,
    metadata_title_draft: document.metadata_title,
  }
  let edited = model
    .update(MetadataTitleChanged("Changed Title"))
    .update(ApplyMetadataTitle)
    .update(AnnotationTextChanged("Draft note"))
    .update(AddAnnotationForCurrentPage)
    .update(StampCurrentPage)
  guard edited.document is Some(edited_document) else {
    fail("expected edited document")
  }
  assert_true(edited_document.dirty)
  inspect(edited_document.metadata_title, content="Changed Title")
  assert_true(edited_document.annotation_summary.contains("Draft note"))
  assert_true(
    edited_document.selected_summary().content_diagnostic.contains(
      "queued stamp",
    ),
  )
  assert_true(
    edited_document.unsupported_entries.any(entry => {
      entry.contains("Queued edit needs pdflite adapter writeback")
    }),
  )
  let discarded = edited.update(DiscardEdits)
  guard discarded.document is Some(discarded_document) else {
    fail("expected discarded document")
  }
  assert_false(discarded_document.dirty)
  inspect(discarded_document.edits.length(), content="0")
  inspect(discarded_document.metadata_title, content="Original Title")
  inspect(discarded.metadata_title_draft, content="Original Title")
  inspect(discarded.bookmark_title_draft, content="")
  inspect(discarded.annotation_text_draft, content="")
  inspect(discarded_document.annotation_summary, content="Clean annotations")
  inspect(
    discarded_document.selected_summary().content_diagnostic,
    content="clean page diagnostic",
  )
  inspect(discarded_document.unsupported_entries.length(), content="1")
  assert_false(
    discarded_document.unsupported_entries.any(entry => {
      entry.contains("Queued edit needs pdflite adapter writeback")
    }),
  )
  inspect(discarded.last_event, content="Discarded queued edits")
}

///|
test "pdf workbench undo last edit replays remaining cleanly" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let document = match
    PdfWorkbenchDocument::from_engine_summary(
      path="/tmp/minimum.pdf",
      original_bytes=bytes,
      page_count=1,
      selected_page=1,
      extracted_text="clean page text",
      dirty=false,
      writeback_available=false,
      unsupported_entries=["clean diagnostic"],
      page_summaries=[
        {
          page_number: 1,
          text_preview: "clean page text",
          content_diagnostic: "clean page diagnostic",
        },
      ],
      metadata_summary="PDF 1.4; parser=test",
      metadata_title="Original Title",
      outline_summary="clean outline",
      annotation_summary="Clean annotations",
    ) {
    Loaded(document) => document
    Failed(reason) => fail(reason)
  }
  let model = {
    ..PdfWorkbenchModel::new(),
    document: Some(document),
    status: PdfWorkbenchStatus::Ready,
    metadata_title_draft: document.metadata_title,
  }
  let edited = model
    .update(MetadataTitleChanged("Changed Title"))
    .update(ApplyMetadataTitle)
    .update(AnnotationTextChanged("Draft note"))
    .update(AddAnnotationForCurrentPage)
    .update(StampCurrentPage)
  guard edited.document is Some(edited_document) else {
    fail("expected edited document")
  }
  inspect(edited_document.edits.length(), content="3")
  assert_true(
    edited_document.selected_summary().content_diagnostic.contains(
      "queued stamp",
    ),
  )
  let without_stamp = edited.update(UndoLastEdit)
  guard without_stamp.document is Some(without_stamp_document) else {
    fail("expected document after undoing stamp")
  }
  inspect(without_stamp_document.edits.length(), content="2")
  inspect(without_stamp_document.metadata_title, content="Changed Title")
  assert_true(without_stamp_document.annotation_summary.contains("Draft note"))
  assert_false(
    without_stamp_document.selected_summary().content_diagnostic.contains(
      "queued stamp",
    ),
  )
  inspect(without_stamp.metadata_title_draft, content="Changed Title")
  inspect(without_stamp.last_event, content="Undid last queued edit")
  let without_note = without_stamp.update(UndoLastEdit)
  guard without_note.document is Some(without_note_document) else {
    fail("expected document after undoing note")
  }
  inspect(without_note_document.edits.length(), content="1")
  inspect(without_note_document.metadata_title, content="Changed Title")
  inspect(without_note_document.annotation_summary, content="Clean annotations")
  let clean = without_note.update(UndoLastEdit)
  guard clean.document is Some(clean_document) else {
    fail("expected document after undoing title")
  }
  assert_false(clean_document.dirty)
  inspect(clean_document.edits.length(), content="0")
  inspect(clean_document.metadata_title, content="Original Title")
  inspect(clean.metadata_title_draft, content="Original Title")
  inspect(clean_document.annotation_summary, content="Clean annotations")
  inspect(
    clean_document.selected_summary().content_diagnostic,
    content="clean page diagnostic",
  )
}

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

///|
test "pdf workbench opens via binary host service" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      file_dialogs=true,
      file_access=true,
    ),
    handle=request => {
      match request {
        @host.HostServiceRequest::FileDialog(_) =>
          @host.HostServiceResponse::FileDialogSelection(["/tmp/minimum.pdf"])
        @host.HostServiceRequest::BinaryFile(
          @host.HostBinaryFileRequest::ReadBytes(path)
        ) => @host.HostServiceResponse::BinaryFileContent(path, bytes)
        @host.HostServiceRequest::BinaryFile(
          @host.HostBinaryFileRequest::WriteBytes(path, _)
        ) => @host.HostServiceResponse::BinaryFileWritten(path)
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let services = @host.HostAppServices::new(bridge~)
  let update = PdfWorkbenchModel::new().update_with_services(
    OpenRequested,
    services,
  )
  let after_dialog = run_pdf_workbench_effect(update, services)
  guard after_dialog.model.document is Some(document) else {
    fail("expected loaded PDF")
  }
  inspect(document.page_count, content="1")
  assert_true(
    document.selected_summary().text_preview.contains("PDF page 1 loaded"),
  )
}

///|
test "pdf workbench open uses document service summary" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let services = pdf_workbench_test_binary_services(bytes)
  let render_count = Ref(0)
  let keys : Array[String] = []
  let raster_services = pdf_workbench_ready_raster_services(render_count, keys)
  let document_services = pdf_workbench_engine_document_services()
  let loaded = run_pdf_workbench_effect_chain(
    PdfWorkbenchModel::new().update_with_services(
      OpenRequested,
      services,
      raster_services~,
      document_services~,
    ),
    services,
    raster_services~,
    document_services~,
  )
  guard loaded.model.document is Some(document) else {
    fail("expected service loaded PDF")
  }
  inspect(document.page_count, content="2")
  assert_true(document.writeback_available)
  assert_true(document.metadata_summary.contains("fake-engine"))
  inspect(loaded.model.metadata_title_draft, content="Fake PDF Title")
  inspect(document.search_count("beta"), content="1")
}

///|
test "pdf workbench runtime open click rebuilds loaded preview" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      file_dialogs=true,
      file_access=true,
    ),
    handle=request => {
      match request {
        @host.HostServiceRequest::FileDialog(_) =>
          @host.HostServiceResponse::FileDialogSelection(["/tmp/minimum.pdf"])
        @host.HostServiceRequest::BinaryFile(
          @host.HostBinaryFileRequest::ReadBytes(path)
        ) => @host.HostServiceResponse::BinaryFileContent(path, bytes)
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  let services = @host.HostAppServices::new(bridge~)
  let runtime = PdfWorkbenchModel::new().runtime_with_services(
    services,
    width=1120.0,
    height=720.0,
  )
  assert_true(
    pdf_workbench_draw_has_text_containing(
      runtime.draw_commands(),
      "Open a PDF to show",
    ),
  )
  pdf_workbench_click_text(runtime, "Open")
  let commands = runtime.draw_commands()
  assert_true(
    pdf_workbench_draw_has_text_containing(commands, "PDF page 1 loaded"),
  )
  assert_true(pdf_workbench_draw_has_text_containing(commands, "Ready"))
}

///|
test "pdf workbench raster preview expands with wider runtime resize" {
  let document = match
    PdfWorkbenchDocument::from_engine_summary(
      path="/tmp/tall.pdf",
      original_bytes=pdf_workbench_minimum_pdf_bytes(),
      page_count=1,
      selected_page=1,
      extracted_text="page one",
      dirty=false,
    ) {
    Loaded(document) => document
    Failed(reason) => fail(reason)
  }
  let model = {
    ..PdfWorkbenchModel::new(),
    document: Some(document),
    status: PdfWorkbenchStatus::Ready,
    raster_status: RasterReady,
    raster_page: Some({
      cache_key: "resize-test",
      page_number: 1,
      zoom: 1.0,
      page_count: 1,
      width_px: 1224,
      height_px: 1584,
      image_source: "/tmp/resize-test.bmp",
      diagnostic: "fake raster",
    }),
  }
  let runtime = model.runtime(width=1120.0, height=720.0)
  guard pdf_workbench_image_frame(runtime.draw_commands()) is Some(before) else {
    fail("expected raster image before resize")
  }
  runtime.dispatch_event(
    @core.AppEvent::Resize(@core.Size::new(width=1600.0, height=720.0)),
  )
  guard pdf_workbench_image_frame(runtime.draw_commands()) is Some(after) else {
    fail("expected raster image after resize")
  }
  assert_true(after.size.width > before.size.width + 300.0)
}

///|
test "pdf workbench narrow viewport prioritizes reader canvas" {
  let document = match
    PdfWorkbenchDocument::from_engine_summary(
      path="/tmp/narrow.pdf",
      original_bytes=pdf_workbench_minimum_pdf_bytes(),
      page_count=3,
      selected_page=1,
      extracted_text="page one\npage two\npage three",
      dirty=false,
      page_summaries=[
        {
          page_number: 1,
          text_preview: "page one",
          content_diagnostic: "ready",
        },
        {
          page_number: 2,
          text_preview: "page two",
          content_diagnostic: "ready",
        },
        {
          page_number: 3,
          text_preview: "page three",
          content_diagnostic: "ready",
        },
      ],
      metadata_summary="PDF 1.4; parser=test",
      metadata_title="Responsive PDF",
      outline_summary="test outline",
      annotation_summary="test annotations",
    ) {
    Loaded(document) => document
    Failed(reason) => fail(reason)
  }
  let model = {
    ..PdfWorkbenchModel::new(),
    document: Some(document),
    status: PdfWorkbenchStatus::Ready,
    raster_status: RasterReady,
    raster_page: Some({
      cache_key: "narrow-test",
      page_number: 1,
      zoom: 1.0,
      page_count: 3,
      width_px: 1224,
      height_px: 1584,
      image_source: "/tmp/narrow-test.bmp",
      diagnostic: "fake raster",
    }),
  }
  let wide_commands = model.runtime(width=1120.0, height=720.0).draw_commands()
  assert_true(pdf_workbench_draw_has_text_containing(wide_commands, "Pages"))
  assert_true(pdf_workbench_draw_has_text_containing(wide_commands, "Document"))
  guard pdf_workbench_image_frame(wide_commands) is Some(wide_image) else {
    fail("expected wide raster image")
  }

  let narrow_commands = model.runtime(width=760.0, height=620.0).draw_commands()
  assert_false(pdf_workbench_draw_has_text_containing(narrow_commands, "Pages"))
  assert_false(
    pdf_workbench_draw_has_text_containing(narrow_commands, "Document"),
  )
  assert_true(
    pdf_workbench_draw_has_text_containing(narrow_commands, "Page 1 / 3"),
  )
  guard pdf_workbench_image_frame(narrow_commands) is Some(narrow_image) else {
    fail("expected narrow raster image")
  }
  assert_true(narrow_image.size.width > wide_image.size.width + 80.0)
  assert_true(narrow_image.size.width > 600.0)
}

///|
test "pdf workbench narrow viewport keeps compact edit controls usable" {
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
  let runtime = loaded.model.runtime_with_services(
    services,
    raster_services~,
    width=760.0,
    height=620.0,
  )
  let initial_commands = runtime.draw_commands()
  assert_false(
    pdf_workbench_draw_has_text_containing(initial_commands, "Document"),
  )
  assert_true(pdf_workbench_draw_has_text_containing(initial_commands, "Edit"))
  assert_true(pdf_workbench_draw_has_text_containing(initial_commands, "Stamp"))

  pdf_workbench_click_text(runtime, "Stamp")
  let stamped_commands = runtime.draw_commands()
  assert_true(
    pdf_workbench_draw_has_text_containing(stamped_commands, "REVIEWED"),
  )
  assert_true(
    pdf_workbench_draw_has_text_containing(stamped_commands, "Quick edits"),
  )

  pdf_workbench_click_text(runtime, "Undo Last")
  let undone_commands = runtime.draw_commands()
  assert_false(
    pdf_workbench_draw_has_text_containing(undone_commands, "REVIEWED"),
  )
  assert_true(pdf_workbench_draw_has_text_containing(undone_commands, "Edit"))
}

///|
test "pdf workbench side panels scroll while reader stays expanded" {
  let summaries : Array[PdfWorkbenchPageSummary] = []
  for page in 1..<=12 {
    summaries.push({
      page_number: page,
      text_preview: "page " + page.to_string(),
      content_diagnostic: "ready",
    })
  }
  let document = match
    PdfWorkbenchDocument::from_engine_summary(
      path="/tmp/scrollable.pdf",
      original_bytes=pdf_workbench_minimum_pdf_bytes(),
      page_count=12,
      selected_page=1,
      extracted_text="scroll test",
      dirty=false,
      writeback_available=true,
      page_summaries=summaries,
      metadata_summary="PDF 1.4; parser=test",
      metadata_title="Scrollable PDF",
      outline_summary="outline ready",
      annotation_summary="annotations ready",
    ) {
    Loaded(document) => document
    Failed(reason) => fail(reason)
  }
  let model = {
    ..PdfWorkbenchModel::new(),
    document: Some(document),
    status: PdfWorkbenchStatus::Ready,
    raster_status: RasterReady,
    raster_page: Some({
      cache_key: "scroll-test",
      page_number: 1,
      zoom: 1.0,
      page_count: 12,
      width_px: 1224,
      height_px: 1584,
      image_source: "/tmp/scroll-test.bmp",
      diagnostic: "fake raster",
    }),
  }
  let runtime = model.runtime(width=1280.0, height=620.0)
  guard pdf_workbench_text_frame(runtime.draw_commands(), "Pages")
    is Some(sidebar_frame) else {
    fail("expected sidebar frame")
  }
  guard pdf_workbench_text_frame(runtime.draw_commands(), "Document")
    is Some(inspector_frame) else {
    fail("expected inspector frame")
  }
  guard pdf_workbench_image_frame(runtime.draw_commands()) is Some(before_image) else {
    fail("expected reader image before side scroll")
  }
  pdf_workbench_scroll_at(runtime, sidebar_frame, dy=-220.0)
  assert_true(model.sidebar_scroll.offset().y > 0.0)
  pdf_workbench_scroll_at(runtime, inspector_frame, dy=-220.0)
  assert_true(model.inspector_scroll.offset().y > 0.0)
  guard pdf_workbench_image_frame(runtime.draw_commands()) is Some(after_image) else {
    fail("expected reader image after side scroll")
  }
  assert_true(after_image.size.width >= before_image.size.width)
}

///|
test "pdf workbench full reader button fills window and restores chrome" {
  let summaries : Array[PdfWorkbenchPageSummary] = []
  for page in 1..<=4 {
    summaries.push({
      page_number: page,
      text_preview: "reader page " + page.to_string(),
      content_diagnostic: "ready",
    })
  }
  let document = match
    PdfWorkbenchDocument::from_engine_summary(
      path="/tmp/full-reader.pdf",
      original_bytes=pdf_workbench_minimum_pdf_bytes(),
      page_count=4,
      selected_page=1,
      extracted_text="reader fullscreen test",
      dirty=false,
      writeback_available=true,
      page_summaries=summaries,
      metadata_summary="PDF 1.4; parser=test",
      metadata_title="Full Reader",
      outline_summary="outline ready",
      annotation_summary="annotations ready",
    ) {
    Loaded(document) => document
    Failed(reason) => fail(reason)
  }
  let model = {
    ..PdfWorkbenchModel::new(),
    document: Some(document),
    status: PdfWorkbenchStatus::Ready,
    raster_status: RasterReady,
    raster_page: Some({
      cache_key: "full-reader-test",
      page_number: 1,
      zoom: 1.0,
      page_count: 4,
      width_px: 1224,
      height_px: 1584,
      image_source: "/tmp/full-reader-test.bmp",
      diagnostic: "fake raster",
    }),
  }
  let runtime = model.runtime(width=1280.0, height=620.0)
  let initial_commands = runtime.draw_commands()
  assert_true(
    pdf_workbench_draw_has_text_containing(initial_commands, "PDF Workbench"),
  )
  assert_true(pdf_workbench_draw_has_text_containing(initial_commands, "Pages"))
  assert_true(
    pdf_workbench_draw_has_text_containing(initial_commands, "Document"),
  )
  assert_true(pdf_workbench_draw_has_text_containing(initial_commands, "Full"))
  guard pdf_workbench_image_frame(initial_commands) is Some(before_image) else {
    fail("expected reader image before fullscreen")
  }

  pdf_workbench_click_text(runtime, "Full")
  let full_commands = runtime.draw_commands()
  assert_false(
    pdf_workbench_draw_has_text_containing(full_commands, "PDF Workbench"),
  )
  assert_false(pdf_workbench_draw_has_text_containing(full_commands, "Pages"))
  assert_false(
    pdf_workbench_draw_has_text_containing(full_commands, "Document"),
  )
  assert_true(pdf_workbench_draw_has_text_containing(full_commands, "Exit"))
  assert_true(
    pdf_workbench_draw_has_text_containing(full_commands, "Page 1 / 4"),
  )
  guard pdf_workbench_image_frame(full_commands) is Some(full_image) else {
    fail("expected reader image after fullscreen")
  }
  assert_true(full_image.size.width > before_image.size.width + 60.0)
  assert_true(full_image.size.height > before_image.size.height + 80.0)

  pdf_workbench_click_text(runtime, "Exit")
  let restored_commands = runtime.draw_commands()
  assert_true(
    pdf_workbench_draw_has_text_containing(restored_commands, "PDF Workbench"),
  )
  assert_true(
    pdf_workbench_draw_has_text_containing(restored_commands, "Pages"),
  )
  assert_true(
    pdf_workbench_draw_has_text_containing(restored_commands, "Document"),
  )
  assert_true(pdf_workbench_draw_has_text_containing(restored_commands, "Full"))
}

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
  let services = @host.HostAppServices::new(bridge~)
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
  let services = @host.HostAppServices::new(bridge~)
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
    @host.HostAppServices::unavailable(),
  )
  assert_false(update.effect is @core.Effect::NoEffect)
  let failed = run_pdf_workbench_effect(
    update,
    @host.HostAppServices::unavailable(),
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
  let services = @host.HostAppServices::new(bridge~)
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
  let services = @host.HostAppServices::new(bridge~)
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

///|
test "pdf workbench open triggers raster request and draws bitmap when ready" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let services = pdf_workbench_test_binary_services(bytes)
  let render_count = Ref(0)
  let keys : Array[String] = []
  let raster_services = pdf_workbench_ready_raster_services(render_count, keys)
  let update = PdfWorkbenchModel::new().update_with_services(
    OpenRequested,
    services,
    raster_services~,
  )
  let loaded = run_pdf_workbench_effect_chain(
    update,
    services,
    raster_services~,
  )
  inspect(render_count.val, content="1")
  assert_true(keys.length() == 1)
  guard loaded.model.raster_page is Some(page) else {
    fail("expected raster page")
  }
  assert_true(page.image_source.contains("fake-raster"))
  let commands = loaded.model
    .runtime(width=1120.0, height=720.0)
    .draw_commands()
  assert_true(pdf_workbench_draw_has_image(commands))
}

///|
test "pdf workbench startup path loads and rasters before first draw" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let services = pdf_workbench_test_binary_services(bytes)
  let render_count = Ref(0)
  let keys : Array[String] = []
  let raster_services = pdf_workbench_ready_raster_services(render_count, keys)
  let document_services = pdf_workbench_engine_document_services()
  let runtime = PdfWorkbenchModel::new().runtime_with_services(
    services,
    raster_services~,
    document_services~,
    startup_pdf_path="/tmp/minimum.pdf",
    width=1120.0,
    height=720.0,
  )
  inspect(render_count.val, content="1")
  inspect(keys.length(), content="1")
  let commands = runtime.draw_commands()
  assert_true(pdf_workbench_draw_has_image(commands))
  assert_true(
    pdf_workbench_draw_has_text_containing(commands, "Fake PDF Title"),
  )
}

///|
test "pdf workbench startup page loads and rasters requested page" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let services = pdf_workbench_test_binary_services(bytes)
  let render_count = Ref(0)
  let keys : Array[String] = []
  let raster_services = pdf_workbench_ready_raster_services(
    render_count,
    keys,
    page_count=2,
  )
  let document_services = pdf_workbench_engine_document_services()
  let runtime = PdfWorkbenchModel::new().runtime_with_services(
    services,
    raster_services~,
    document_services~,
    startup_pdf_path="/tmp/minimum.pdf",
    startup_page_number=2,
    width=1120.0,
    height=720.0,
  )
  inspect(render_count.val, content="1")
  assert_true(keys[0].contains("page=2"))
  let commands = runtime.draw_commands()
  assert_true(pdf_workbench_draw_has_image(commands))
  assert_true(pdf_workbench_draw_has_text_containing(commands, "Page 2 / 2"))
}

///|
test "pdf workbench lightweight smoke covers startup raster navigation search and cache" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let services = pdf_workbench_test_binary_services(bytes)
  let render_count = Ref(0)
  let keys : Array[String] = []
  let raster_services = pdf_workbench_ready_raster_services(
    render_count,
    keys,
    page_count=3,
  )
  let document_services = pdf_workbench_engine_document_services()
  let startup_runtime = PdfWorkbenchModel::new().runtime_with_services(
    services,
    raster_services~,
    document_services~,
    startup_pdf_path="/tmp/minimum.pdf",
    width=1120.0,
    height=720.0,
  )
  let startup_commands = startup_runtime.draw_commands()
  inspect(render_count.val, content="1")
  assert_true(pdf_workbench_draw_has_image(startup_commands))
  assert_true(
    pdf_workbench_draw_has_text_containing(startup_commands, "Fake PDF Title"),
  )
  assert_true(
    pdf_workbench_draw_has_text_containing(startup_commands, "Page 3"),
  )

  let loaded = run_pdf_workbench_effect_chain(
    PdfWorkbenchModel::new().update_with_services(
      OpenRequested,
      services,
      raster_services~,
      document_services~,
    ),
    services,
    raster_services~,
    document_services~,
  )
  guard loaded.model.document is Some(opened_document) else {
    fail("expected loaded document in smoke")
  }
  inspect(opened_document.page_count, content="3")
  let page_one_key = keys[1]

  let page_two = run_pdf_workbench_effect_chain(
    loaded.model.update_with_services(NextPage, services, raster_services~),
    services,
    raster_services~,
    document_services~,
  )
  guard page_two.model.document is Some(page_two_document) else {
    fail("expected page two document in smoke")
  }
  inspect(page_two_document.selected_page, content="2")
  inspect(render_count.val, content="3")
  guard page_two.model.raster_page is Some(page_two_raster) else {
    fail("expected page two raster in smoke")
  }
  inspect(page_two_raster.page_number, content="2")

  let searched = page_two.model.update_with_services(
    SearchChanged("page 3"),
    services,
    raster_services~,
    document_services~,
  )
  let page_three = run_pdf_workbench_effect_chain(
    searched.model.update_with_services(SearchNext, services, raster_services~),
    services,
    raster_services~,
    document_services~,
  )
  guard page_three.model.document is Some(page_three_document) else {
    fail("expected page three document in smoke")
  }
  inspect(page_three_document.selected_page, content="3")
  inspect(page_three_document.search_count("page 3"), content="1")
  inspect(render_count.val, content="4")
  assert_true(page_three.model.last_event.contains("Rendered page 3"))

  let zoomed = run_pdf_workbench_effect_chain(
    page_three.model.update_with_services(ZoomIn, services, raster_services~),
    services,
    raster_services~,
    document_services~,
  )
  inspect(render_count.val, content="5")
  guard zoomed.model.raster_page is Some(zoomed_raster) else {
    fail("expected zoomed raster in smoke")
  }
  assert_true(zoomed_raster.cache_key != keys[3])

  let unzoomed_page_three = zoomed.model.update_with_services(
    ZoomOut,
    services,
    raster_services~,
    document_services~,
  )
  assert_true(unzoomed_page_three.effect is @core.Effect::NoEffect)
  inspect(render_count.val, content="5")
  guard unzoomed_page_three.model.raster_page is Some(page_three_cached) else {
    fail("expected cached page three raster in smoke")
  }
  inspect(page_three_cached.cache_key, content=keys[3])

  let cached_page_one = unzoomed_page_three.model.update_with_services(
    SelectPage(1),
    services,
    raster_services~,
    document_services~,
  )
  assert_true(cached_page_one.effect is @core.Effect::NoEffect)
  inspect(render_count.val, content="5")
  guard cached_page_one.model.raster_page is Some(cached_raster) else {
    fail("expected cached page one raster in smoke")
  }
  inspect(cached_raster.cache_key, content=page_one_key)
  assert_true(cached_page_one.model.last_event.contains("Raster cache hit"))
}

///|
test "pdf workbench raster page count unlocks page navigation" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let services = pdf_workbench_test_binary_services(bytes)
  let render_count = Ref(0)
  let keys : Array[String] = []
  let raster_services = pdf_workbench_ready_raster_services(
    render_count,
    keys,
    page_count=3,
  )
  let loaded = run_pdf_workbench_effect_chain(
    PdfWorkbenchModel::new().update_with_services(
      OpenRequested,
      services,
      raster_services~,
    ),
    services,
    raster_services~,
  )
  guard loaded.model.document is Some(document) else {
    fail("expected loaded PDF")
  }
  inspect(document.page_count, content="3")
  inspect(document.page_summaries.length(), content="3")
  let next = run_pdf_workbench_effect_chain(
    loaded.model.update_with_services(NextPage, services, raster_services~),
    services,
    raster_services~,
  )
  guard next.model.document is Some(next_document) else {
    fail("expected loaded PDF after next page")
  }
  inspect(next_document.selected_page, content="2")
  inspect(render_count.val, content="2")
  guard next.model.raster_page is Some(page) else {
    fail("expected page 2 raster")
  }
  inspect(page.page_number, content="2")
}

///|
test "pdf workbench raster page count survives discarded edits" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let services = pdf_workbench_test_binary_services(bytes)
  let render_count = Ref(0)
  let keys : Array[String] = []
  let raster_services = pdf_workbench_ready_raster_services(
    render_count,
    keys,
    page_count=3,
  )
  let loaded = run_pdf_workbench_effect_chain(
    PdfWorkbenchModel::new().update_with_services(
      OpenRequested,
      services,
      raster_services~,
    ),
    services,
    raster_services~,
  )
  let page_three = run_pdf_workbench_effect_chain(
    loaded.model.update_with_services(SelectPage(3), services, raster_services~),
    services,
    raster_services~,
  )
  let edited = page_three.model.update(StampCurrentPage)
  guard edited.document is Some(edited_document) else {
    fail("expected edited PDF")
  }
  inspect(edited_document.page_count, content="3")
  inspect(edited_document.page_summaries.length(), content="3")
  inspect(edited_document.clean_page_summaries.length(), content="3")
  assert_true(
    edited_document.selected_summary().content_diagnostic.contains(
      "queued stamp",
    ),
  )

  let discarded = edited.update(DiscardEdits)
  guard discarded.document is Some(discarded_document) else {
    fail("expected discarded PDF")
  }
  inspect(discarded_document.page_count, content="3")
  inspect(discarded_document.selected_page, content="3")
  inspect(discarded_document.page_summaries.length(), content="3")
  inspect(discarded_document.clean_page_summaries.length(), content="3")
  inspect(discarded_document.selected_summary().page_number, content="3")
  assert_false(
    discarded_document.selected_summary().content_diagnostic.contains(
      "queued stamp",
    ),
  )
}

///|
test "pdf workbench page number jump renders requested page" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let services = pdf_workbench_test_binary_services(bytes)
  let render_count = Ref(0)
  let keys : Array[String] = []
  let raster_services = pdf_workbench_ready_raster_services(
    render_count,
    keys,
    page_count=3,
  )
  let loaded = run_pdf_workbench_effect_chain(
    PdfWorkbenchModel::new().update_with_services(
      OpenRequested,
      services,
      raster_services~,
    ),
    services,
    raster_services~,
  )
  let drafted = loaded.model.update_with_services(
    PageNumberChanged("3"),
    services,
    raster_services~,
  )
  inspect(drafted.model.page_number_draft, content="3")
  let jumped = run_pdf_workbench_effect_chain(
    drafted.model.update_with_services(GoToPage, services, raster_services~),
    services,
    raster_services~,
  )
  guard jumped.model.document is Some(document) else {
    fail("expected loaded PDF")
  }
  inspect(document.selected_page, content="3")
  inspect(jumped.model.page_number_draft, content="3")
  inspect(render_count.val, content="2")
  guard jumped.model.raster_page is Some(page) else {
    fail("expected page 3 raster")
  }
  inspect(page.page_number, content="3")
}

///|
test "pdf workbench invalid page number jump restores current page" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let services = pdf_workbench_test_binary_services(bytes)
  let render_count = Ref(0)
  let keys : Array[String] = []
  let raster_services = pdf_workbench_ready_raster_services(
    render_count,
    keys,
    page_count=3,
  )
  let loaded = run_pdf_workbench_effect_chain(
    PdfWorkbenchModel::new().update_with_services(
      OpenRequested,
      services,
      raster_services~,
    ),
    services,
    raster_services~,
  )
  let page_two = run_pdf_workbench_effect_chain(
    loaded.model.update_with_services(NextPage, services, raster_services~),
    services,
    raster_services~,
  )
  let drafted = page_two.model.update_with_services(
    PageNumberChanged("abc"),
    services,
    raster_services~,
  )
  let jumped = run_pdf_workbench_effect_chain(
    drafted.model.update_with_services(GoToPage, services, raster_services~),
    services,
    raster_services~,
  )
  guard jumped.model.document is Some(document) else {
    fail("expected loaded PDF")
  }
  inspect(document.selected_page, content="2")
  inspect(jumped.model.page_number_draft, content="2")
  assert_true(jumped.model.last_event.contains("valid page"))
  inspect(render_count.val, content="2")
}

///|
test "pdf workbench sidebar uses clean thumbnail navigation" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let services = pdf_workbench_test_binary_services(bytes)
  let render_count = Ref(0)
  let keys : Array[String] = []
  let raster_services = pdf_workbench_ready_raster_services(
    render_count,
    keys,
    page_count=3,
  )
  let loaded = run_pdf_workbench_effect_chain(
    PdfWorkbenchModel::new().update_with_services(
      OpenRequested,
      services,
      raster_services~,
    ),
    services,
    raster_services~,
  )
  let runtime = loaded.model.runtime_with_services(
    services,
    raster_services~,
    width=1120.0,
    height=720.0,
  )
  let commands = runtime.draw_commands()
  inspect(pdf_workbench_draw_text_count(commands, "Current"), content="1")
  assert_true(pdf_workbench_draw_has_text_containing(commands, "Page 2"))
  let search_runtime = { ..loaded.model, query: "page 2" }.runtime_with_services(
    services,
    raster_services~,
    width=1120.0,
    height=720.0,
  )
  inspect(
    pdf_workbench_draw_text_count(search_runtime.draw_commands(), "Match"),
    content="1",
  )
  pdf_workbench_click_text(runtime, "Page 2")
  guard pdf_workbench_text_frame(runtime.draw_commands(), "Page 2") is Some(_) else {
    fail("expected page 2 navigation item after click")
  }
  inspect(render_count.val, content="2")
}

///|
test "pdf workbench sidebar reuses cached rasters as thumbnails" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let services = pdf_workbench_test_binary_services(bytes)
  let render_count = Ref(0)
  let keys : Array[String] = []
  let raster_services = pdf_workbench_ready_raster_services(
    render_count,
    keys,
    page_count=3,
  )
  let loaded = run_pdf_workbench_effect_chain(
    PdfWorkbenchModel::new().update_with_services(
      OpenRequested,
      services,
      raster_services~,
    ),
    services,
    raster_services~,
  )
  let runtime = loaded.model.runtime_with_services(
    services,
    raster_services~,
    width=1120.0,
    height=720.0,
  )
  inspect(pdf_workbench_draw_image_count(runtime.draw_commands()), content="2")
  pdf_workbench_click_text(runtime, "Page 2")
  inspect(render_count.val, content="2")
  inspect(pdf_workbench_draw_image_count(runtime.draw_commands()), content="3")
}

///|
test "pdf workbench find next selects matching page and renders it" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let services = pdf_workbench_test_binary_services(bytes)
  let render_count = Ref(0)
  let keys : Array[String] = []
  let raster_services = pdf_workbench_ready_raster_services(
    render_count,
    keys,
    page_count=3,
  )
  let loaded = run_pdf_workbench_effect_chain(
    PdfWorkbenchModel::new().update_with_services(
      OpenRequested,
      services,
      raster_services~,
    ),
    services,
    raster_services~,
  )
  let searched = loaded.model.update_with_services(
    SearchChanged("page 3"),
    services,
    raster_services~,
  )
  let found = run_pdf_workbench_effect_chain(
    searched.model.update_with_services(SearchNext, services, raster_services~),
    services,
    raster_services~,
  )
  guard found.model.document is Some(document) else {
    fail("expected loaded PDF")
  }
  inspect(document.selected_page, content="3")
  inspect(document.search_count("page 3"), content="1")
  inspect(render_count.val, content="2")
}

///|
test "pdf workbench find previous wraps and reports active match position" {
  let document = match
    PdfWorkbenchDocument::from_engine_summary(
      path="/tmp/search.pdf",
      original_bytes=pdf_workbench_minimum_pdf_bytes(),
      page_count=3,
      selected_page=2,
      extracted_text="alpha page\nbeta page\ngamma page",
      dirty=false,
      page_summaries=[
        {
          page_number: 1,
          text_preview: "alpha page",
          content_diagnostic: "ready",
        },
        {
          page_number: 2,
          text_preview: "beta page",
          content_diagnostic: "ready",
        },
        {
          page_number: 3,
          text_preview: "gamma page",
          content_diagnostic: "ready",
        },
      ],
    ) {
    Loaded(document) => document
    Failed(reason) => fail(reason)
  }
  match document.search_match_position("page", 2) {
    Some(position) => inspect(position, content="2")
    None => fail("expected selected page search position")
  }
  match document.previous_search_page("page") {
    Some(page) => inspect(page, content="1")
    None => fail("expected previous search page")
  }
  let render_count = Ref(0)
  let keys : Array[String] = []
  let raster_services = pdf_workbench_ready_raster_services(
    render_count,
    keys,
    page_count=3,
  )
  let services = @host.HostAppServices::unavailable()
  let model = {
    ..PdfWorkbenchModel::new(),
    document: Some(document),
    status: PdfWorkbenchStatus::Ready,
    query: "page",
    page_number_draft: "2",
  }
  let previous = run_pdf_workbench_effect_chain(
    model.update_with_services(SearchPrevious, services, raster_services~),
    services,
    raster_services~,
  )
  guard previous.model.document is Some(previous_document) else {
    fail("expected previous search document")
  }
  inspect(previous_document.selected_page, content="1")
  match previous_document.search_match_position("page", 1) {
    Some(position) => inspect(position, content="1")
    None => fail("expected first search position")
  }
  assert_true(
    pdf_workbench_draw_has_text_containing(
      previous.model.runtime(width=1120.0, height=720.0).draw_commands(),
      "Find: 1/3",
    ),
  )

  let wrapped = run_pdf_workbench_effect_chain(
    previous.model.update_with_services(
      SearchPrevious,
      services,
      raster_services~,
    ),
    services,
    raster_services~,
  )
  guard wrapped.model.document is Some(wrapped_document) else {
    fail("expected wrapped search document")
  }
  inspect(wrapped_document.selected_page, content="3")
  match wrapped_document.search_match_position("page", 3) {
    Some(position) => inspect(position, content="3")
    None => fail("expected wrapped search position")
  }
  assert_true(
    pdf_workbench_draw_has_text_containing(
      wrapped.model.runtime(width=1120.0, height=720.0).draw_commands(),
      "Find: 3/3",
    ),
  )
  inspect(render_count.val, content="2")
}

///|
test "pdf workbench opening a new document clears stale search state" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let services = pdf_workbench_test_binary_services(bytes)
  let render_count = Ref(0)
  let keys : Array[String] = []
  let raster_services = pdf_workbench_ready_raster_services(render_count, keys)
  let model = { ..PdfWorkbenchModel::new(), query: "stale query" }
  let loaded = run_pdf_workbench_effect_chain(
    model.update_with_services(OpenRequested, services, raster_services~),
    services,
    raster_services~,
  )
  inspect(loaded.model.query, content="")
  assert_true(
    pdf_workbench_draw_has_text_containing(
      loaded.model.runtime(width=1120.0, height=720.0).draw_commands(),
      "Find: empty",
    ),
  )
}

///|
test "pdf workbench stamp action marks page and draws overlay" {
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
  let runtime = loaded.model.runtime_with_services(
    services,
    raster_services~,
    width=1120.0,
    height=720.0,
  )
  pdf_workbench_click_text(runtime, "Stamp")
  let commands = runtime.draw_commands()
  assert_true(pdf_workbench_draw_has_text_containing(commands, "REVIEWED"))
}

///|
test "pdf workbench inspector groups queue diagnostics and zoom state" {
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
  let loaded_commands = loaded.model
    .runtime_with_services(
      services,
      raster_services~,
      width=1120.0,
      height=720.0,
    )
    .draw_commands()
  assert_true(pdf_workbench_draw_has_text_containing(loaded_commands, "100%"))
  assert_true(pdf_workbench_draw_has_text_containing(loaded_commands, "Page"))
  assert_true(
    pdf_workbench_draw_has_text_containing(loaded_commands, "Document"),
  )
  assert_true(pdf_workbench_draw_has_text_containing(loaded_commands, "Queue"))
  assert_true(
    pdf_workbench_draw_has_text_containing(loaded_commands, "Diagnostics"),
  )
  assert_true(
    pdf_workbench_draw_has_text_containing(loaded_commands, "No queued edits"),
  )
  let zoomed = run_pdf_workbench_effect_chain(
    loaded.model.update_with_services(ZoomIn, services, raster_services~),
    services,
    raster_services~,
  )
  let edited = zoomed.model.update(StampCurrentPage)
  let edited_commands = edited
    .runtime_with_services(
      services,
      raster_services~,
      width=1120.0,
      height=720.0,
    )
    .draw_commands()
  assert_true(pdf_workbench_draw_has_text_containing(edited_commands, "110%"))
  assert_true(
    pdf_workbench_draw_has_text_containing(
      edited_commands, "Stamp page 1: REVIEWED",
    ),
  )
  assert_true(
    pdf_workbench_draw_has_text_containing(edited_commands, "Unsaved"),
  )
  assert_true(
    pdf_workbench_draw_has_text_containing(
      edited_commands, "Save needs pdflite document service",
    ),
  )
}

///|
test "pdf workbench raster unavailable keeps structured preview" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let services = pdf_workbench_test_binary_services(bytes)
  let update = PdfWorkbenchModel::new().update_with_services(
    OpenRequested,
    services,
    raster_services=PdfWorkbenchRasterServices::unavailable(),
  )
  let loaded = run_pdf_workbench_effect_chain(
    update,
    services,
    raster_services=PdfWorkbenchRasterServices::unavailable(),
  )
  match loaded.model.raster_status {
    RasterUnavailable(reason) => assert_true(reason.contains("PDFium"))
    _ => fail("expected raster unavailable")
  }
  let commands = loaded.model
    .runtime(width=1120.0, height=720.0)
    .draw_commands()
  assert_false(pdf_workbench_draw_has_image(commands))
  assert_true(
    pdf_workbench_draw_has_text_containing(commands, "PDF page 1 loaded"),
  )
}

///|
test "pdf workbench raster failure keeps loaded document" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let services = pdf_workbench_test_binary_services(bytes)
  let raster_services = PdfWorkbenchRasterServices::new(render=_request => {
    RasterPageFailed("render failure for test")
  })
  let update = PdfWorkbenchModel::new().update_with_services(
    OpenRequested,
    services,
    raster_services~,
  )
  let loaded = run_pdf_workbench_effect_chain(
    update,
    services,
    raster_services~,
  )
  guard loaded.model.document is Some(_) else {
    fail("expected loaded PDF after raster failure")
  }
  match loaded.model.raster_status {
    RasterFailed(reason) => assert_true(reason.contains("render failure"))
    _ => fail("expected raster failure")
  }
}

///|
test "pdf workbench zoom changes raster key and cache hit skips render" {
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
  let zoomed = run_pdf_workbench_effect_chain(
    loaded.model.update_with_services(ZoomIn, services, raster_services~),
    services,
    raster_services~,
  )
  inspect(render_count.val, content="2")
  assert_true(keys.length() == 2)
  assert_true(keys[0] != keys[1])
  let hit = zoomed.model.update_with_services(
    SelectPage(1),
    services,
    raster_services~,
  )
  assert_true(hit.effect is @core.Effect::NoEffect)
  inspect(render_count.val, content="2")
  guard hit.model.raster_page is Some(_) else {
    fail("expected cached raster page")
  }
}

///|
test "pdf workbench fit button returns to cached fit-width zoom" {
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
  let zoomed = run_pdf_workbench_effect_chain(
    loaded.model.update_with_services(ZoomIn, services, raster_services~),
    services,
    raster_services~,
  )
  inspect(render_count.val, content="2")
  let runtime = zoomed.model.runtime_with_services(
    services,
    raster_services~,
    width=1120.0,
    height=720.0,
  )
  assert_true(
    pdf_workbench_draw_has_text_containing(runtime.draw_commands(), "110%"),
  )
  pdf_workbench_click_text(runtime, "Fit")
  inspect(render_count.val, content="2")
  let commands = runtime.draw_commands()
  assert_true(pdf_workbench_draw_has_text_containing(commands, "100%"))
  assert_false(pdf_workbench_draw_has_text_containing(commands, "110%"))
}

///|
test "pdf workbench raster cache is bounded and preserves recent hits" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let services = pdf_workbench_test_binary_services(bytes)
  let render_count = Ref(0)
  let keys : Array[String] = []
  let raster_services = pdf_workbench_ready_raster_services(
    render_count,
    keys,
    page_count=13,
  )
  let loaded = run_pdf_workbench_effect_chain(
    PdfWorkbenchModel::new().update_with_services(
      OpenRequested,
      services,
      raster_services~,
    ),
    services,
    raster_services~,
  )
  let mut model = loaded.model
  let original_key = keys[0]
  let mut page_number = 2
  while page_number <= 12 {
    let update = model.update_with_services(
      SelectPage(page_number),
      services,
      raster_services~,
    )
    model = run_pdf_workbench_effect_chain(update, services, raster_services~).model
    page_number = page_number + 1
  }
  inspect(render_count.val, content="12")
  inspect(model.raster_cache.length(), content="12")
  let hit_original = model.update_with_services(
    SelectPage(1),
    services,
    raster_services~,
  )
  assert_true(hit_original.effect is @core.Effect::NoEffect)
  model = hit_original.model
  inspect(render_count.val, content="12")
  guard model.raster_cache.last() is Some(recent) else {
    fail("expected raster cache entry")
  }
  inspect(recent.cache_key, content=original_key)
  let evicted_key = keys[1]
  let page_thirteen = run_pdf_workbench_effect_chain(
    model.update_with_services(SelectPage(13), services, raster_services~),
    services,
    raster_services~,
  )
  model = page_thirteen.model
  inspect(render_count.val, content="13")
  inspect(model.raster_cache.length(), content="12")
  assert_true(model.raster_cache.any(page => page.cache_key == original_key))
  assert_false(model.raster_cache.any(page => page.cache_key == evicted_key))
}

///|
fn run_pdf_workbench_effect(
  update : PdfWorkbenchUpdate,
  services : @host.HostAppServices,
) -> PdfWorkbenchUpdate {
  let model = @core.State::new(update.model)
  let effect = @core.State::new(@core.Effect::none())
  match update.effect {
    @core.Effect::Run(_descriptor, run) =>
      run(message => {
        let next = model.get().update_with_services(message, services)
        model.set(next.model)
        effect.set(next.effect)
      })
    _ => ()
  }
  PdfWorkbenchUpdate::new(model.get(), effect=effect.get())
}

///|
fn run_pdf_workbench_effect_chain(
  update : PdfWorkbenchUpdate,
  services : @host.HostAppServices,
  raster_services? : PdfWorkbenchRasterServices = PdfWorkbenchRasterServices::unavailable(),
  document_services? : PdfWorkbenchDocumentServices = PdfWorkbenchDocumentServices::lightweight(),
) -> PdfWorkbenchUpdate {
  let model = @core.State::new(update.model)
  let effect = @core.State::new(update.effect)
  let mut turns = 0
  while turns < 8 && !(effect.get() is @core.Effect::NoEffect) {
    let current = effect.get()
    effect.set(@core.Effect::none())
    run_pdf_workbench_effect_value(
      current, model, effect, services, raster_services, document_services,
    )
    turns = turns + 1
  }
  PdfWorkbenchUpdate::new(model.get(), effect=effect.get())
}

///|
fn run_pdf_workbench_effect_value(
  current : @core.Effect[PdfWorkbenchMsg],
  model : @core.State[PdfWorkbenchModel],
  effect : @core.State[@core.Effect[PdfWorkbenchMsg]],
  services : @host.HostAppServices,
  raster_services : PdfWorkbenchRasterServices,
  document_services : PdfWorkbenchDocumentServices,
) -> Unit {
  match current {
    @core.Effect::Run(_descriptor, run) =>
      run(message => {
        let next = model
          .get()
          .update_with_services(
            message,
            services,
            raster_services~,
            document_services~,
          )
        model.set(next.model)
        effect.set(next.effect)
      })
    @core.Effect::Dispatch(run) =>
      run(message => {
        let next = model
          .get()
          .update_with_services(
            message,
            services,
            raster_services~,
            document_services~,
          )
        model.set(next.model)
        effect.set(next.effect)
      })
    @core.Effect::Send(message) => {
      let next = model
        .get()
        .update_with_services(
          message,
          services,
          raster_services~,
          document_services~,
        )
      model.set(next.model)
      effect.set(next.effect)
    }
    @core.Effect::Batch(effects) =>
      for nested in effects {
        run_pdf_workbench_effect_value(
          nested, model, effect, services, raster_services, document_services,
        )
      }
    _ => ()
  }
}

///|
fn pdf_workbench_test_binary_services(bytes : Bytes) -> @host.HostAppServices {
  let bridge = @host.HostServiceBridge::new(
    capabilities=@host.HostServiceCapabilities::new(
      file_dialogs=true,
      file_access=true,
    ),
    handle=request => {
      match request {
        @host.HostServiceRequest::FileDialog(_) =>
          @host.HostServiceResponse::FileDialogSelection(["/tmp/minimum.pdf"])
        @host.HostServiceRequest::BinaryFile(
          @host.HostBinaryFileRequest::ReadBytes(path)
        ) => @host.HostServiceResponse::BinaryFileContent(path, bytes)
        @host.HostServiceRequest::BinaryFile(
          @host.HostBinaryFileRequest::WriteBytes(path, _)
        ) => @host.HostServiceResponse::BinaryFileWritten(path)
        _ => @host.HostServiceResponse::Unavailable("unexpected request")
      }
    },
  )
  @host.HostAppServices::new(bridge~)
}

///|
fn pdf_workbench_engine_document_services() -> PdfWorkbenchDocumentServices {
  PdfWorkbenchDocumentServices::new(load=(path, bytes) => {
    PdfWorkbenchDocument::from_engine_summary(
      path~,
      original_bytes=bytes,
      page_count=2,
      selected_page=1,
      extracted_text="alpha page\nbeta page",
      dirty=false,
      writeback_available=true,
      edits=[],
      unsupported_entries=[],
      page_summaries=[
        {
          page_number: 1,
          text_preview: "alpha page",
          content_diagnostic: "fake engine page one",
        },
        {
          page_number: 2,
          text_preview: "beta page",
          content_diagnostic: "fake engine page two",
        },
      ],
      metadata_summary="PDF 1.4; parser=fake-engine",
      metadata_title="Fake PDF Title",
      outline_summary="fake outline ready",
      annotation_summary="fake annotations ready",
    )
  })
}

///|
fn pdf_workbench_ready_raster_services(
  render_count : Ref[Int],
  keys : Array[String],
  page_count? : Int = 1,
) -> PdfWorkbenchRasterServices {
  PdfWorkbenchRasterServices::new(render=request => {
    render_count.val = render_count.val + 1
    keys.push(request.cache_key)
    RasterPageReady({
      cache_key: request.cache_key,
      page_number: request.page_number,
      zoom: request.zoom,
      page_count,
      width_px: 144,
      height_px: 192,
      image_source: "/tmp/fake-raster-" + render_count.val.to_string() + ".bmp",
      diagnostic: "fake raster service",
    })
  })
}

///|
fn pdf_workbench_click_text(
  runtime : @core.AppRuntime,
  label : String,
) -> Unit raise {
  guard pdf_workbench_text_frame(runtime.draw_commands(), label) is Some(frame) else {
    fail("expected text frame for " + label)
  }
  let point = @core.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Down),
    ),
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(position=point, phase=@core.PointerPhase::Up),
    ),
  )
}

///|
fn pdf_workbench_scroll_at(
  runtime : @core.AppRuntime,
  frame : @core.Rect,
  dy~ : Double,
) -> Unit {
  let point = @core.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=point,
        phase=@core.PointerPhase::Move,
        wheel_delta=@core.Point::new(x=0.0, y=dy),
      ),
    ),
  )
}

///|
fn pdf_workbench_draw_has_text_containing(
  commands : Array[@core.DrawCommand],
  needle : String,
) -> Bool {
  commands.any(command => {
    command is @core.DrawCommand::DrawText({ text: value, .. }) &&
    value.contains(needle)
  })
}

///|
fn pdf_workbench_draw_text_count(
  commands : Array[@core.DrawCommand],
  text : String,
) -> Int {
  let mut count = 0
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, .. }) =>
        if value == text {
          count = count + 1
        }
      _ => ()
    }
  }
  count
}

///|
fn pdf_workbench_draw_has_image(commands : Array[@core.DrawCommand]) -> Bool {
  commands.any(command => command is @core.DrawCommand::DrawImage(_))
}

///|
fn pdf_workbench_draw_image_count(commands : Array[@core.DrawCommand]) -> Int {
  let mut count = 0
  for command in commands {
    match command {
      @core.DrawCommand::DrawImage(_) => count = count + 1
      _ => ()
    }
  }
  count
}

///|
fn pdf_workbench_image_frame(
  commands : Array[@core.DrawCommand],
) -> @core.Rect? {
  let mut best : @core.Rect? = None
  let mut best_area = 0.0
  for command in commands {
    match command {
      @core.DrawCommand::DrawImage({ frame, .. }) => {
        let area = frame.size.width * frame.size.height
        if area > best_area {
          best = Some(frame)
          best_area = area
        }
      }
      _ => ()
    }
  }
  best
}

///|
fn pdf_workbench_text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Rect? {
  for command in commands {
    match command {
      @core.DrawCommand::DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame)
        }
      _ => ()
    }
  }
  None
}
