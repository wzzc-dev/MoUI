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
  let services = @backend_common_services.app_services(bridge~)
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
  let services = @backend_common_services.app_services(bridge~)
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
    @core.AppEvent::Resize(@geometry.Size::new(width=1600.0, height=720.0)),
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
/// Runtime that records the latest model value into `latest` on every
/// update/view pass, so tests can observe scroll offsets and other model
/// state that is now carried by messages instead of mutable references.
fn PdfWorkbenchModel::tracked_test_runtime(
  self : PdfWorkbenchModel,
  latest : Ref[PdfWorkbenchModel],
  width~ : Double,
  height~ : Double,
) -> @runtime.AppRuntime {
  let program = @moui.Program::new_with_environment(
    init=() => (self, @moui.Effect::none()),
    update=(model, message) => {
      let next = model.update(message)
      latest.val = next
      (next, @moui.Effect::none())
    },
    view=(model, env) => {
      latest.val = model
      model.view_with_environment(env)
    },
  )
  pdf_workbench_test_runtime(program, width~, height~)
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
  let latest = Ref(model)
  let runtime = model.tracked_test_runtime(latest, width=1280.0, height=620.0)
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
  assert_true(latest.val.sidebar_scroll.y > 0.0)
  pdf_workbench_scroll_at(runtime, inspector_frame, dy=-220.0)
  assert_true(latest.val.inspector_scroll.y > 0.0)
  guard pdf_workbench_image_frame(runtime.draw_commands()) is Some(after_image) else {
    fail("expected reader image after side scroll")
  }
  assert_true(after_image.size.width >= before_image.size.width)
}

///|
test "pdf workbench typed full reader command fills window and restores chrome" {
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
  let runtime = pdf_workbench_test_runtime(
    model
    .program()
    .with_commands(commands=_model => {
      [
        @moui.ProgramCommand::new(
          command=@core.ActionCommand::new(intent=@core.CommandIntent::Activate),
          message=ToggleReaderFullscreen,
        ),
      ]
    }),
    width=1280.0,
    height=620.0,
  )
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

  assert_true(runtime.dispatch_command(@core.CommandIntent::Activate))
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

  assert_true(runtime.dispatch_command(@core.CommandIntent::Activate))
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
