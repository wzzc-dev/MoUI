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
