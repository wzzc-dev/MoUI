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
  assert_true(unzoomed_page_three.effect is @moui.Effect::NoEffect)
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
  assert_true(cached_page_one.effect is @moui.Effect::NoEffect)
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
  let services = @services.AppServices::unavailable()
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
  assert_true(hit.effect is @moui.Effect::NoEffect)
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
  assert_true(hit_original.effect is @moui.Effect::NoEffect)
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
