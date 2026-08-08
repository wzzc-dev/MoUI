///|
fn PdfWorkbenchModel::update(
  self : PdfWorkbenchModel,
  message : PdfWorkbenchMsg,
) -> PdfWorkbenchModel {
  self.update_with_services(message, @services.AppServices::unavailable()).model
}

///|
fn PdfWorkbenchModel::runtime(
  self : PdfWorkbenchModel,
  width? : Double = 1120.0,
  height? : Double = 720.0,
) -> @runtime.AppRuntime {
  pdf_workbench_test_runtime(self.program(), width~, height~)
}

///|
fn PdfWorkbenchModel::runtime_with_services(
  self : PdfWorkbenchModel,
  services : @services.AppServices,
  raster_services? : PdfWorkbenchRasterServices = PdfWorkbenchRasterServices::unavailable(),
  document_services? : PdfWorkbenchDocumentServices = PdfWorkbenchDocumentServices::lightweight(),
  startup_pdf_path? : String = "",
  startup_page_number? : Int = 1,
  width? : Double = 1120.0,
  height? : Double = 720.0,
) -> @runtime.AppRuntime {
  pdf_workbench_test_runtime(
    self.program(
      environment=@services.AppEnvironment::new(services~),
      raster_services~,
      document_services~,
      startup_pdf_path~,
      startup_page_number~,
    ),
    width~,
    height~,
  )
}

///|
fn pdf_workbench_test_runtime(
  program : @moui.Program[PdfWorkbenchModel, PdfWorkbenchMsg],
  width~ : Double,
  height~ : Double,
) -> @runtime.AppRuntime {
  @runtime.new_program_with_dimensions(program~, width~, height~)
}

///|
fn run_pdf_workbench_effect(
  update : PdfWorkbenchUpdate,
  services : @services.AppServices,
) -> PdfWorkbenchUpdate {
  run_pdf_workbench_effect_chain(update, services)
}

///|
fn run_pdf_workbench_effect_chain(
  update : PdfWorkbenchUpdate,
  services : @services.AppServices,
  raster_services? : PdfWorkbenchRasterServices = PdfWorkbenchRasterServices::unavailable(),
  document_services? : PdfWorkbenchDocumentServices = PdfWorkbenchDocumentServices::lightweight(),
) -> PdfWorkbenchUpdate {
  let model = Ref(update.model)
  let effect = Ref(update.effect)
  let mut turns = 0
  while turns < 8 && !(effect.val is @moui.Effect::NoEffect) {
    let current = effect.val
    effect.val = @moui.Effect::none()
    run_pdf_workbench_effect_value(
      current, model, effect, services, raster_services, document_services,
    )
    turns = turns + 1
  }
  PdfWorkbenchUpdate::new(model.val, effect=effect.val)
}

///|
fn run_pdf_workbench_effect_value(
  current : @moui.Effect[PdfWorkbenchMsg],
  model : Ref[PdfWorkbenchModel],
  effect : Ref[@moui.Effect[PdfWorkbenchMsg]],
  services : @services.AppServices,
  raster_services : PdfWorkbenchRasterServices,
  document_services : PdfWorkbenchDocumentServices,
) -> Unit {
  match current {
    @moui.Effect::Run(_descriptor, run) =>
      run(message => {
        let next = model.val.update_with_services(
          message,
          services,
          raster_services~,
          document_services~,
        )
        model.val = next.model
        effect.val = next.effect
      })
    @moui.Effect::Task(_descriptor, start) =>
      ignore(
        start(message => {
          let next = model.val.update_with_services(
            message,
            services,
            raster_services~,
            document_services~,
          )
          model.val = next.model
          effect.val = next.effect
        }),
      )
    @moui.Effect::Dispatch(run) =>
      run(message => {
        let next = model.val.update_with_services(
          message,
          services,
          raster_services~,
          document_services~,
        )
        model.val = next.model
        effect.val = next.effect
      })
    @moui.Effect::Send(message) => {
      let next = model.val.update_with_services(
        message,
        services,
        raster_services~,
        document_services~,
      )
      model.val = next.model
      effect.val = next.effect
    }
    @moui.Effect::Batch(effects) =>
      for nested in effects {
        run_pdf_workbench_effect_value(
          nested, model, effect, services, raster_services, document_services,
        )
      }
    _ => ()
  }
}

///|
fn pdf_workbench_test_binary_services(bytes : Bytes) -> @services.AppServices {
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
  @backend_common_services.app_services(bridge~)
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
  runtime : @runtime.AppRuntime,
  label : String,
) -> Unit raise {
  guard pdf_workbench_text_frame(runtime.draw_commands(), label) is Some(frame) else {
    fail("expected text frame for " + label)
  }
  let point = @geometry.Point::new(
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
  runtime : @runtime.AppRuntime,
  frame : @core.Rect,
  dy~ : Double,
) -> Unit {
  let point = @geometry.Point::new(
    x=frame.origin.x + frame.size.width / 2.0,
    y=frame.origin.y + frame.size.height / 2.0,
  )
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=point,
        phase=@core.PointerPhase::Move,
        wheel_delta=@geometry.Point::new(x=0.0, y=dy),
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
