///|
pub struct PdfWorkbenchApp {
  unit : Unit
}

///|
pub enum PdfWorkbenchStatus {
  Empty
  Requesting(String)
  Pending(@host.HostServiceRequestId, String)
  Ready
  Failed(String)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct PdfWorkbenchPageSummary {
  page_number : Int
  text_preview : String
  content_diagnostic : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct PdfWorkbenchCropBox {
  left : Double
  bottom : Double
  right : Double
  top : Double
} derive(Eq, Debug, ToJson)

///|
pub(all) enum PdfWorkbenchEdit {
  RotatePage(Int, Int)
  CropPage(Int, PdfWorkbenchCropBox)
  StampText(Int, String)
  SetMetadataTitle(String)
  AddBookmark(Int, String)
  AddTextAnnotation(Int, String)
} derive(Eq, Debug, ToJson)

///|
pub(all) struct PdfWorkbenchDocument {
  path : String
  original_bytes : Bytes
  page_count : Int
  selected_page : Int
  extracted_text : String
  dirty : Bool
  writeback_available : Bool
  edits : Array[PdfWorkbenchEdit]
  unsupported_entries : Array[String]
  page_summaries : Array[PdfWorkbenchPageSummary]
  metadata_summary : String
  metadata_title : String
  outline_summary : String
  annotation_summary : String
  clean_unsupported_entries : Array[String]
  clean_page_summaries : Array[PdfWorkbenchPageSummary]
  clean_metadata_title : String
  clean_annotation_summary : String
}

///|
pub(all) enum PdfWorkbenchLoadResult {
  Loaded(PdfWorkbenchDocument)
  Failed(String)
}

///|
pub struct PdfWorkbenchModel {
  document : PdfWorkbenchDocument?
  status : PdfWorkbenchStatus
  raster_status : PdfWorkbenchRasterStatus
  raster_page : PdfWorkbenchRasterPage?
  raster_cache : Array[PdfWorkbenchRasterPage]
  sidebar_scroll : @core.ScrollState
  inspector_scroll : @core.ScrollState
  preview_scroll_offset : @core.Point
  reader_fullscreen : Bool
  query : String
  metadata_title_draft : String
  bookmark_title_draft : String
  annotation_text_draft : String
  page_number_draft : String
  startup_page_after_load : Int?
  zoom : Double
  last_event : String
}

///|
priv struct PdfWorkbenchUpdate {
  model : PdfWorkbenchModel
  effect : @core.Effect[PdfWorkbenchMsg]
}

///|
priv enum PdfWorkbenchMsg {
  OpenRequested
  SaveRequested
  SaveAsRequested
  HostCompleted(@host.HostCompletedServiceResponse)
  SaveCompleted(String, Bytes, Array[String], @host.HostServiceResponse)
  SaveFailed(String)
  RasterCompleted(PdfWorkbenchRasterRequest, PdfWorkbenchRasterResponse)
  PreviousPage
  NextPage
  SelectPage(Int)
  SearchChanged(String)
  SearchPrevious
  SearchNext
  PageNumberChanged(String)
  GoToPage
  MetadataTitleChanged(String)
  ApplyMetadataTitle
  BookmarkTitleChanged(String)
  AddBookmarkForCurrentPage
  AnnotationTextChanged(String)
  AddAnnotationForCurrentPage
  PreviewScrolled(@core.Point)
  ToggleReaderFullscreen
  ZoomIn
  ZoomOut
  ZoomFitWidth
  RotateCurrentPage
  CropCurrentPage
  StampCurrentPage
  UndoLastEdit
  DiscardEdits
  ClearFailure
}

///|
pub fn PdfWorkbenchApp::new() -> PdfWorkbenchApp {
  { unit: () }
}

///|
pub fn PdfWorkbenchModel::new() -> PdfWorkbenchModel {
  {
    document: None,
    status: PdfWorkbenchStatus::Empty,
    raster_status: PdfWorkbenchRasterStatus::RasterIdle,
    raster_page: None,
    raster_cache: [],
    sidebar_scroll: @core.ScrollState::new(),
    inspector_scroll: @core.ScrollState::new(),
    preview_scroll_offset: @core.Point::new(x=0.0, y=0.0),
    reader_fullscreen: false,
    query: "",
    metadata_title_draft: "",
    bookmark_title_draft: "",
    annotation_text_draft: "",
    page_number_draft: "",
    startup_page_after_load: None,
    zoom: 1.0,
    last_event: "Open a PDF to inspect its document model",
  }
}

///|
fn PdfWorkbenchUpdate::new(
  model : PdfWorkbenchModel,
  effect? : @core.Effect[PdfWorkbenchMsg] = @core.Effect::none(),
) -> PdfWorkbenchUpdate {
  { model, effect }
}

///|
fn PdfWorkbenchUpdate::as_tuple(
  self : PdfWorkbenchUpdate,
) -> (PdfWorkbenchModel, @core.Effect[PdfWorkbenchMsg]) {
  (self.model, self.effect)
}

///|
fn PdfWorkbenchModel::update_with_services(
  self : PdfWorkbenchModel,
  message : PdfWorkbenchMsg,
  services : @host.HostAppServices,
  raster_services? : PdfWorkbenchRasterServices = PdfWorkbenchRasterServices::unavailable(),
  document_services? : PdfWorkbenchDocumentServices = PdfWorkbenchDocumentServices::lightweight(),
) -> PdfWorkbenchUpdate {
  match message {
    OpenRequested => self.request_open(services)
    SaveRequested =>
      self.request_save(services, document_services, save_as=false)
    SaveAsRequested =>
      self.request_save(services, document_services, save_as=true)
    HostCompleted(completion) =>
      self.apply_host_completion(
        completion, services, raster_services, document_services,
      )
    SaveCompleted(path, bytes, diagnostics, response) => {
      let reraster_after_save = self.should_reraster_after_save()
      let saved = self.apply_save_completion(
        path, bytes, diagnostics, response, document_services,
      )
      match saved.status {
        Ready if reraster_after_save =>
          saved.request_current_raster(raster_services)
        _ => PdfWorkbenchUpdate::new(saved)
      }
    }
    SaveFailed(reason) =>
      PdfWorkbenchUpdate::new({
        ..self,
        status: Failed(reason),
        last_event: "Writeback adapter failed",
      })
    RasterCompleted(request, response) =>
      PdfWorkbenchUpdate::new(self.apply_raster_completion(request, response))
    PreviousPage =>
      self.select_page_delta(-1).request_current_raster(raster_services)
    NextPage =>
      self.select_page_delta(1).request_current_raster(raster_services)
    SelectPage(page) =>
      self.select_page(page).request_current_raster(raster_services)
    SearchChanged(query) =>
      PdfWorkbenchUpdate::new(self.with_search_query(query))
    SearchPrevious =>
      self
      .select_previous_search_result()
      .request_current_raster(raster_services)
    SearchNext =>
      self.select_next_search_result().request_current_raster(raster_services)
    PageNumberChanged(value) =>
      PdfWorkbenchUpdate::new({ ..self, page_number_draft: value })
    GoToPage =>
      match self.document {
        Some(_) =>
          match pdf_workbench_parse_positive_int(self.page_number_draft) {
            Some(_) =>
              self.go_to_page_number().request_current_raster(raster_services)
            None => PdfWorkbenchUpdate::new(self.go_to_page_number())
          }
        None => PdfWorkbenchUpdate::new(self.go_to_page_number())
      }
    MetadataTitleChanged(value) =>
      PdfWorkbenchUpdate::new({ ..self, metadata_title_draft: value })
    ApplyMetadataTitle => PdfWorkbenchUpdate::new(self.apply_metadata_title())
    BookmarkTitleChanged(value) =>
      PdfWorkbenchUpdate::new({ ..self, bookmark_title_draft: value })
    AddBookmarkForCurrentPage =>
      PdfWorkbenchUpdate::new(self.add_bookmark_for_current_page())
    AnnotationTextChanged(value) =>
      PdfWorkbenchUpdate::new({ ..self, annotation_text_draft: value })
    AddAnnotationForCurrentPage =>
      PdfWorkbenchUpdate::new(self.add_annotation_for_current_page())
    PreviewScrolled(delta) =>
      PdfWorkbenchUpdate::new(self.scroll_preview(delta))
    ToggleReaderFullscreen =>
      PdfWorkbenchUpdate::new(self.toggle_reader_fullscreen())
    ZoomIn =>
      self.with_zoom(self.zoom + 0.1).request_current_raster(raster_services)
    ZoomOut =>
      self.with_zoom(self.zoom - 0.1).request_current_raster(raster_services)
    ZoomFitWidth => self.with_zoom(1.0).request_current_raster(raster_services)
    RotateCurrentPage => PdfWorkbenchUpdate::new(self.rotate_current_page())
    CropCurrentPage => PdfWorkbenchUpdate::new(self.crop_current_page())
    StampCurrentPage => PdfWorkbenchUpdate::new(self.stamp_current_page())
    UndoLastEdit => PdfWorkbenchUpdate::new(self.undo_last_edit())
    DiscardEdits => PdfWorkbenchUpdate::new(self.discard_edits())
    ClearFailure => PdfWorkbenchUpdate::new(self.clear_failure())
  }
}

///|
fn PdfWorkbenchModel::subscriptions(
  self : PdfWorkbenchModel,
  services : @host.HostAppServices,
) -> @core.Subscription[PdfWorkbenchMsg] {
  match self.status {
    Pending(id, label) =>
      services.completion_subscription(
        id,
        map=completion => HostCompleted(completion),
        label~,
      )
    _ => @core.Subscription::none()
  }
}

///|
pub fn PdfWorkbenchApp::runtime(
  self : PdfWorkbenchApp,
  width? : Double = 1120.0,
  height? : Double = 720.0,
) -> @core.AppRuntime {
  ignore(self)
  PdfWorkbenchModel::new().runtime(width~, height~)
}

///|
pub fn PdfWorkbenchApp::runtime_with_services(
  self : PdfWorkbenchApp,
  services : @host.HostAppServices,
  raster_services? : PdfWorkbenchRasterServices = PdfWorkbenchRasterServices::unavailable(),
  document_services? : PdfWorkbenchDocumentServices = PdfWorkbenchDocumentServices::lightweight(),
  startup_pdf_path? : String = "",
  startup_page_number? : Int = 1,
  width? : Double = 1120.0,
  height? : Double = 720.0,
) -> @core.AppRuntime {
  ignore(self)
  PdfWorkbenchModel::new().runtime_with_services(
    services,
    raster_services~,
    document_services~,
    startup_pdf_path~,
    startup_page_number~,
    width~,
    height~,
  )
}

///|
pub fn PdfWorkbenchModel::runtime(
  self : PdfWorkbenchModel,
  width? : Double = 1120.0,
  height? : Double = 720.0,
) -> @core.AppRuntime {
  self.runtime_with_services(
    @host.HostAppServices::unavailable(),
    width~,
    height~,
  )
}

///|
pub fn PdfWorkbenchModel::runtime_with_services(
  self : PdfWorkbenchModel,
  services : @host.HostAppServices,
  raster_services? : PdfWorkbenchRasterServices = PdfWorkbenchRasterServices::unavailable(),
  document_services? : PdfWorkbenchDocumentServices = PdfWorkbenchDocumentServices::lightweight(),
  startup_pdf_path? : String = "",
  startup_page_number? : Int = 1,
  width? : Double = 1120.0,
  height? : Double = 720.0,
) -> @core.AppRuntime {
  @core.AppRuntime::new_program(
    program=@core.Program::new_with_environment(
      init=() => {
        self
        .request_startup_pdf(startup_pdf_path, startup_page_number, services)
        .as_tuple()
      },
      update=(model, message) => {
        model
        .update_with_services(
          message,
          services,
          raster_services~,
          document_services~,
        )
        .as_tuple()
      },
      view=(model, env) => model.view_with_environment(env),
      subscriptions=model => model.subscriptions(services),
    ),
    size=@core.Size::new(width~, height~),
  )
}

///|
pub fn runtime(
  width? : Double = 1120.0,
  height? : Double = 720.0,
) -> @core.AppRuntime {
  PdfWorkbenchModel::new().runtime(width~, height~)
}

///|
fn PdfWorkbenchModel::request_startup_pdf(
  self : PdfWorkbenchModel,
  startup_pdf_path : String,
  startup_page_number : Int,
  services : @host.HostAppServices,
) -> PdfWorkbenchUpdate {
  let path = startup_pdf_path.trim().to_owned()
  if path == "" {
    PdfWorkbenchUpdate::new(self)
  } else {
    {
      ..self,
      startup_page_after_load: Some(
        if startup_page_number < 1 {
          1
        } else {
          startup_page_number
        },
      ),
    }.request_open_path(path, services, source="startup")
  }
}

///|
fn PdfWorkbenchModel::request_open_path(
  self : PdfWorkbenchModel,
  path : String,
  services : @host.HostAppServices,
  source~ : String,
) -> PdfWorkbenchUpdate {
  let request = @host.HostServiceRequest::BinaryFile(
    @host.HostBinaryFileRequest::ReadBytes(path),
  )
  PdfWorkbenchUpdate::new(
    {
      ..self,
      status: Requesting("Opening PDF"),
      last_event: "Opening " + pdf_workbench_file_name(path),
    },
    effect=@core.Effect::host_service(
      key="pdf-workbench:open-path:" +
        pdf_workbench_string_hash(path).to_string(),
      label="Open PDF path",
      run=dispatch => {
        println("pdf workbench: opening " + source + " PDF " + path)
        let response = services.read_binary_file(path)
        println(pdf_workbench_binary_response_log(response))
        dispatch(HostCompleted(pdf_workbench_completion(request, response)))
      },
    ),
  )
}

///|
fn PdfWorkbenchModel::request_open(
  self : PdfWorkbenchModel,
  services : @host.HostAppServices,
) -> PdfWorkbenchUpdate {
  let request = @host.HostServiceRequest::FileDialog(
    @host.HostFileDialogOptions::new(
      kind=@host.HostFileDialogKind::OpenFile,
      title="Open PDF",
      filters=["pdf"],
    ),
  )
  PdfWorkbenchUpdate::new(
    {
      ..self,
      status: Requesting("Opening PDF"),
      last_event: "Waiting for file picker",
      startup_page_after_load: None,
    },
    effect=@core.Effect::host_service(
      key="pdf-workbench:open-file",
      label="Open PDF file",
      run=dispatch => {
        println("pdf workbench: opening PDF file dialog")
        let response = services.open_file(title="Open PDF", filters=["pdf"])
        dispatch(HostCompleted(pdf_workbench_completion(request, response)))
      },
    ),
  )
}

///|
fn PdfWorkbenchModel::request_save(
  self : PdfWorkbenchModel,
  services : @host.HostAppServices,
  document_services : PdfWorkbenchDocumentServices,
  save_as~ : Bool,
) -> PdfWorkbenchUpdate {
  match self.document {
    Some(document) =>
      if save_as || document.path == "" {
        self.request_save_path(
          services,
          default_name=pdf_workbench_default_save_file_name(document.path),
        )
      } else {
        self.request_binary_write(
          document.path,
          document,
          services,
          document_services,
        )
      }
    None =>
      PdfWorkbenchUpdate::new({
        ..self,
        status: Failed("open a PDF before saving"),
        last_event: "Save unavailable",
      })
  }
}

///|
fn PdfWorkbenchModel::request_save_path(
  self : PdfWorkbenchModel,
  services : @host.HostAppServices,
  default_name~ : String,
) -> PdfWorkbenchUpdate {
  let request = @host.HostServiceRequest::FileDialog(
    @host.HostFileDialogOptions::new(
      kind=@host.HostFileDialogKind::SaveFile,
      title="Save PDF",
      default_name=Some(default_name),
      filters=["pdf"],
    ),
  )
  PdfWorkbenchUpdate::new(
    {
      ..self,
      status: Requesting("Choosing save location"),
      last_event: "Waiting for save dialog",
    },
    effect=@core.Effect::host_service(
      key="pdf-workbench:save-path",
      label="Choose PDF save path",
      run=dispatch => {
        let response = services.save_file(
          title="Save PDF",
          default_name=Some(default_name),
          filters=["pdf"],
        )
        dispatch(HostCompleted(pdf_workbench_completion(request, response)))
      },
    ),
  )
}

///|
fn PdfWorkbenchModel::request_binary_write(
  self : PdfWorkbenchModel,
  path : String,
  document : PdfWorkbenchDocument,
  services : @host.HostAppServices,
  document_services : PdfWorkbenchDocumentServices,
) -> PdfWorkbenchUpdate {
  PdfWorkbenchUpdate::new(
    {
      ..self,
      status: Requesting("Writing PDF bytes"),
      last_event: "Writing original bytes to " + path,
    },
    effect=@core.Effect::host_service(
      key="pdf-workbench:write-binary",
      label="Write PDF bytes",
      run=dispatch => {
        let (bytes, diagnostics) = if document.dirty ||
          document.edits.length() > 0 {
          match document_services.writeback_document(document) {
            WritebackReady(bytes, diagnostics) => (bytes, diagnostics)
            WritebackFailed(reason) => {
              dispatch(SaveFailed(reason))
              return
            }
          }
        } else {
          (document.original_bytes, [])
        }
        let request = @host.HostServiceRequest::BinaryFile(
          @host.HostBinaryFileRequest::WriteBytes(path, bytes),
        )
        println("pdf workbench: writing \{bytes.length()} byte(s) to " + path)
        let response = services.write_binary_file(path, bytes)
        ignore(request)
        dispatch(SaveCompleted(path, bytes, diagnostics, response))
      },
    ),
  )
}

///|
fn PdfWorkbenchModel::apply_host_completion(
  self : PdfWorkbenchModel,
  completion : @host.HostCompletedServiceResponse,
  services : @host.HostAppServices,
  raster_services : PdfWorkbenchRasterServices,
  document_services : PdfWorkbenchDocumentServices,
) -> PdfWorkbenchUpdate {
  match completion.response {
    @host.HostServiceResponse::Pending(id) =>
      PdfWorkbenchUpdate::new({
        ..self,
        status: Pending(id, pdf_workbench_pending_label(completion.request)),
        last_event: "Waiting for host service",
      })
    @host.HostServiceResponse::FileDialogSelection(paths) =>
      self.apply_file_dialog(
        paths,
        completion.request,
        services,
        raster_services,
        document_services,
      )
    @host.HostServiceResponse::BinaryFileContent(path, bytes) =>
      self
      .apply_pdf_bytes(path, bytes, document_services)
      .request_current_raster(raster_services)
    @host.HostServiceResponse::BinaryFileWritten(path) =>
      PdfWorkbenchUpdate::new(self.mark_saved(path, None, []))
    @host.HostServiceResponse::Unavailable(reason) =>
      PdfWorkbenchUpdate::new({
        ..self,
        status: Failed(
          pdf_workbench_unavailable_message(completion.request, reason),
        ),
        last_event: "Host service unavailable while " +
        pdf_workbench_request_action(completion.request),
      })
    _ => PdfWorkbenchUpdate::new(self)
  }
}

///|
fn PdfWorkbenchModel::apply_file_dialog(
  self : PdfWorkbenchModel,
  paths : Array[String],
  request : @host.HostServiceRequest,
  services : @host.HostAppServices,
  raster_services : PdfWorkbenchRasterServices,
  document_services : PdfWorkbenchDocumentServices,
) -> PdfWorkbenchUpdate {
  if paths.is_empty() {
    PdfWorkbenchUpdate::new({
      ..self,
      status: Ready,
      last_event: "No file selected",
    })
  } else {
    match request {
      @host.HostServiceRequest::FileDialog(
        { kind: @host.HostFileDialogKind::SaveFile, .. }
      ) =>
        match self.document {
          Some(document) => {
            let path = paths[0]
            self.request_binary_write(
              path, document, services, document_services,
            )
          }
          None =>
            PdfWorkbenchUpdate::new({
              ..self,
              status: Failed("open a PDF before saving"),
              last_event: "Save unavailable",
            })
        }
      _ => {
        let path = paths[0]
        println("pdf workbench: selected " + path)
        let read_request = @host.HostServiceRequest::BinaryFile(
          @host.HostBinaryFileRequest::ReadBytes(path),
        )
        let response = services.read_binary_file(path)
        println(pdf_workbench_binary_response_log(response))
        self.apply_host_completion(
          pdf_workbench_completion(read_request, response),
          services,
          raster_services,
          document_services,
        )
      }
    }
  }
}

///|
fn PdfWorkbenchModel::apply_pdf_bytes(
  self : PdfWorkbenchModel,
  path : String,
  bytes : Bytes,
  document_services : PdfWorkbenchDocumentServices,
) -> PdfWorkbenchModel {
  let load_result = match document_services.load_document(path, bytes) {
    Loaded(document) => Loaded(document)
    Failed(reason) =>
      match PdfWorkbenchDocument::from_bytes(path~, bytes~) {
        Loaded(document) =>
          Loaded({
            ..document,
            unsupported_entries: pdf_workbench_append_unsupported_entry(
              document.unsupported_entries,
              "Document service failed; lightweight fallback used: " + reason,
            ),
          })
        Failed(_) => Failed(reason)
      }
  }
  match load_result {
    Loaded(document) => {
      let selected_page = match self.startup_page_after_load {
        Some(page) => pdf_workbench_clamp_int(page, 1, document.page_count)
        None => document.selected_page
      }
      let loaded_document = { ..document, selected_page, }
      println(
        "pdf workbench: loaded \{bytes.length()} byte(s), pages=\{document.page_count}, path=" +
        path,
      )
      self.reset_panel_scrolls()
      {
        ..self,
        document: Some(loaded_document),
        metadata_title_draft: loaded_document.metadata_title,
        bookmark_title_draft: "",
        annotation_text_draft: "",
        page_number_draft: loaded_document.selected_page.to_string(),
        startup_page_after_load: None,
        raster_page: None,
        raster_cache: [],
        raster_status: RasterIdle,
        preview_scroll_offset: @core.Point::new(x=0.0, y=0.0),
        query: "",
        status: Ready,
        last_event: "Loaded " +
        pdf_workbench_file_name(path) +
        " (\{bytes.length()} byte(s), \{document.page_count} page(s))",
      }
    }
    Failed(reason) => {
      println(
        "pdf workbench: load failed for " +
        path +
        " (\{bytes.length()} byte(s)): " +
        reason,
      )
      {
        ..self,
        document: None,
        startup_page_after_load: None,
        raster_page: None,
        raster_cache: [],
        raster_status: RasterFailed(reason),
        status: Failed(
          reason +
          " while loading " +
          pdf_workbench_file_name(path) +
          " (\{bytes.length()} byte(s))",
        ),
        last_event: "PDF load failed",
      }
    }
  }
}

///|
fn PdfWorkbenchModel::mark_saved(
  self : PdfWorkbenchModel,
  path : String,
  bytes : Bytes?,
  diagnostics : Array[String],
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) => {
      let original_bytes = match bytes {
        Some(output) => output
        None => document.original_bytes
      }
      let unsupported_entries = document.unsupported_entries.copy()
      for entry in diagnostics {
        unsupported_entries.push(entry)
      }
      let updated = {
        ..document,
        path,
        original_bytes,
        dirty: false,
        edits: [],
        unsupported_entries,
        clean_unsupported_entries: unsupported_entries.copy(),
        clean_page_summaries: document.page_summaries.copy(),
        clean_metadata_title: document.metadata_title,
        clean_annotation_summary: document.annotation_summary,
      }
      {
        ..self,
        document: Some(updated),
        status: Ready,
        last_event: "Saved " + path,
      }
    }
    None => self
  }
}

///|
fn PdfWorkbenchModel::mark_saved_from_written_bytes(
  self : PdfWorkbenchModel,
  path : String,
  bytes : Bytes,
  diagnostics : Array[String],
  document_services : PdfWorkbenchDocumentServices,
) -> PdfWorkbenchModel {
  let was_dirty = match self.document {
    Some(document) => document.dirty || document.edits.length() > 0
    None => false
  }
  if !was_dirty && diagnostics.is_empty() {
    return self.mark_saved(path, Some(bytes), diagnostics)
  }
  match document_services.load_document(path, bytes) {
    Loaded(document) => {
      let selected_page = match self.document {
        Some(previous) =>
          pdf_workbench_clamp_int(
            previous.selected_page,
            1,
            document.page_count,
          )
        None => document.selected_page
      }
      let unsupported_entries = document.unsupported_entries.copy()
      for entry in diagnostics {
        unsupported_entries.push(entry)
      }
      let saved = {
        ..document,
        path,
        original_bytes: bytes,
        selected_page,
        dirty: false,
        edits: [],
        unsupported_entries,
        clean_unsupported_entries: unsupported_entries.copy(),
        clean_page_summaries: document.page_summaries.copy(),
        clean_metadata_title: document.metadata_title,
        clean_annotation_summary: document.annotation_summary,
      }
      {
        ..self,
        document: Some(saved),
        metadata_title_draft: saved.metadata_title,
        bookmark_title_draft: "",
        annotation_text_draft: "",
        page_number_draft: selected_page.to_string(),
        raster_page: None,
        raster_cache: [],
        raster_status: RasterIdle,
        status: Ready,
        last_event: "Saved and reloaded " + path,
      }
    }
    Failed(reason) => {
      let reload_diagnostics = diagnostics.copy()
      reload_diagnostics.push("Reload after save failed: " + reason)
      self.mark_saved(path, Some(bytes), reload_diagnostics)
    }
  }
}

///|
fn PdfWorkbenchModel::apply_save_completion(
  self : PdfWorkbenchModel,
  path : String,
  bytes : Bytes,
  diagnostics : Array[String],
  response : @host.HostServiceResponse,
  document_services : PdfWorkbenchDocumentServices,
) -> PdfWorkbenchModel {
  match response {
    @host.HostServiceResponse::BinaryFileWritten(written_path) =>
      self.mark_saved_from_written_bytes(
        written_path, bytes, diagnostics, document_services,
      )
    @host.HostServiceResponse::Unavailable(reason) =>
      {
        ..self,
        status: Failed(
          "Binary PDF write unavailable while saving " +
          pdf_workbench_file_name(path) +
          ": " +
          reason,
        ),
        last_event: "Save unavailable",
      }
    _ =>
      {
        ..self,
        status: Failed("Unexpected host response while saving " + path),
        last_event: "Save failed",
      }
  }
}

///|
fn PdfWorkbenchModel::should_reraster_after_save(
  self : PdfWorkbenchModel,
) -> Bool {
  match self.raster_page {
    Some(_) => true
    None =>
      match self.raster_status {
        RasterReady | RasterRendering(_) => true
        _ => false
      }
  }
}

///|
fn PdfWorkbenchModel::select_page_delta(
  self : PdfWorkbenchModel,
  delta : Int,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) => {
      let next = pdf_workbench_clamp_int(
        document.selected_page + delta,
        1,
        document.page_count,
      )
      {
        ..self,
        document: Some({ ..document, selected_page: next }),
        page_number_draft: next.to_string(),
        preview_scroll_offset: if next == document.selected_page {
          self.preview_scroll_offset
        } else {
          @core.Point::new(x=0.0, y=0.0)
        },
      }
    }
    None => self
  }
}

///|
fn PdfWorkbenchModel::select_page(
  self : PdfWorkbenchModel,
  page : Int,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) => {
      let selected = pdf_workbench_clamp_int(page, 1, document.page_count)
      {
        ..self,
        document: Some({ ..document, selected_page: selected }),
        page_number_draft: selected.to_string(),
        preview_scroll_offset: if selected == document.selected_page {
          self.preview_scroll_offset
        } else {
          @core.Point::new(x=0.0, y=0.0)
        },
      }
    }
    None => self
  }
}

///|
fn PdfWorkbenchModel::with_zoom(
  self : PdfWorkbenchModel,
  zoom : Double,
) -> PdfWorkbenchModel {
  let clamped = if zoom < 0.5 { 0.5 } else if zoom > 2.0 { 2.0 } else { zoom }
  {
    ..self,
    zoom: clamped,
    preview_scroll_offset: if clamped == self.zoom {
      self.preview_scroll_offset
    } else {
      @core.Point::new(x=0.0, y=0.0)
    },
  }
}

///|
fn PdfWorkbenchModel::scroll_preview(
  self : PdfWorkbenchModel,
  delta : @core.Point,
) -> PdfWorkbenchModel {
  {
    ..self,
    preview_scroll_offset: @core.Point::new(
      x=(self.preview_scroll_offset.x - delta.x).max(0.0),
      y=(self.preview_scroll_offset.y - delta.y).max(0.0),
    ),
  }
}

///|
fn PdfWorkbenchModel::toggle_reader_fullscreen(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  let next_fullscreen = !self.reader_fullscreen
  {
    ..self,
    reader_fullscreen: next_fullscreen,
    last_event: if next_fullscreen {
      "Reader filled window"
    } else {
      "Reader restored panels"
    },
  }
}

///|
fn PdfWorkbenchModel::reset_panel_scrolls(self : PdfWorkbenchModel) -> Unit {
  self.sidebar_scroll.scroll_to(x=0.0, y=0.0)
  self.inspector_scroll.scroll_to(x=0.0, y=0.0)
}

///|
fn PdfWorkbenchModel::select_next_search_result(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  self.select_search_result(true)
}

///|
fn PdfWorkbenchModel::select_previous_search_result(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  self.select_search_result(false)
}

///|
fn PdfWorkbenchModel::select_search_result(
  self : PdfWorkbenchModel,
  forward : Bool,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) => {
      let target = if forward {
        document.next_search_page(self.query)
      } else {
        document.previous_search_page(self.query)
      }
      match target {
        Some(page) =>
          {
            ..self,
            document: Some({ ..document, selected_page: page }),
            page_number_draft: page.to_string(),
            preview_scroll_offset: if page == document.selected_page {
              self.preview_scroll_offset
            } else {
              @core.Point::new(x=0.0, y=0.0)
            },
            last_event: "Search matched page " +
            page.to_string() +
            pdf_workbench_search_position_suffix(document, self.query, page),
          }
        None =>
          {
            ..self,
            last_event: if self.query.trim().to_owned() == "" {
              "Enter search text before finding"
            } else {
              "No page matches for search"
            },
          }
      }
    }
    None => { ..self, last_event: "Open a PDF before searching" }
  }
}

///|
fn PdfWorkbenchModel::with_search_query(
  self : PdfWorkbenchModel,
  query : String,
) -> PdfWorkbenchModel {
  let needle = query.trim().to_owned()
  let last_event = if needle == "" {
    "Search cleared"
  } else {
    match self.document {
      Some(document) => {
        let matches = document.search_count(query)
        if matches == 0 {
          "Search found no matching pages"
        } else if matches == 1 {
          "Search found 1 matching page"
        } else {
          "Search found " + matches.to_string() + " matching pages"
        }
      }
      None => "Open a PDF before searching"
    }
  }
  { ..self, query, last_event }
}

///|
fn PdfWorkbenchModel::go_to_page_number(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) =>
      match pdf_workbench_parse_positive_int(self.page_number_draft) {
        Some(page) => {
          let selected = pdf_workbench_clamp_int(page, 1, document.page_count)
          {
            ..self,
            document: Some({ ..document, selected_page: selected }),
            page_number_draft: selected.to_string(),
            preview_scroll_offset: if selected == document.selected_page {
              self.preview_scroll_offset
            } else {
              @core.Point::new(x=0.0, y=0.0)
            },
            last_event: if selected == page {
              "Jumped to page " + selected.to_string()
            } else {
              "Jumped to nearest page " + selected.to_string()
            },
          }
        }
        None =>
          {
            ..self,
            page_number_draft: document.selected_page.to_string(),
            last_event: "Enter a valid page number",
          }
      }
    None =>
      {
        ..self,
        page_number_draft: "",
        last_event: "Open a PDF before jumping to a page",
      }
  }
}

///|
fn PdfWorkbenchModel::rotate_current_page(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) =>
      self.replace_document_summary(
        document.with_edit(RotatePage(document.selected_page, 90)),
        event="Queued 90 degree page rotation",
      )
    None =>
      {
        ..self,
        status: Failed("open a PDF before editing"),
        last_event: "Edit unavailable",
      }
  }
}

///|
fn PdfWorkbenchModel::crop_current_page(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) => {
      let box = { left: 36.0, bottom: 36.0, right: 523.0, top: 770.0 }
      self.replace_document_summary(
        document.with_edit(CropPage(document.selected_page, box)),
        event="Queued sample crop box",
      )
    }
    None =>
      {
        ..self,
        status: Failed("open a PDF before editing"),
        last_event: "Edit unavailable",
      }
  }
}

///|
fn PdfWorkbenchModel::stamp_current_page(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) =>
      self.replace_document_summary(
        document.with_edit(
          StampText(document.selected_page, pdf_workbench_default_stamp_text()),
        ),
        event="Queued page stamp",
      )
    None =>
      {
        ..self,
        status: Failed("open a PDF before editing"),
        last_event: "Edit unavailable",
      }
  }
}

///|
fn PdfWorkbenchModel::discard_edits(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) =>
      if document.dirty || document.edits.length() > 0 {
        let reverted = document.discard_edits()
        {
          ..self,
          document: Some(reverted),
          metadata_title_draft: reverted.metadata_title,
          bookmark_title_draft: "",
          annotation_text_draft: "",
          status: Ready,
          last_event: "Discarded queued edits",
        }
      } else {
        { ..self, status: Ready, last_event: "No queued edits to discard" }
      }
    None =>
      {
        ..self,
        status: Failed("open a PDF before editing"),
        last_event: "Edit unavailable",
      }
  }
}

///|
fn PdfWorkbenchModel::clear_failure(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  match self.status {
    Failed(_) => { ..self, status: Ready, last_event: "Cleared failure" }
    _ => self
  }
}

///|
fn PdfWorkbenchModel::undo_last_edit(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) =>
      match document.undo_last_edit() {
        Some(reverted) =>
          {
            ..self,
            document: Some(reverted),
            metadata_title_draft: reverted.metadata_title,
            bookmark_title_draft: "",
            annotation_text_draft: "",
            status: Ready,
            last_event: "Undid last queued edit",
          }
        None => { ..self, status: Ready, last_event: "No queued edits to undo" }
      }
    None =>
      {
        ..self,
        status: Failed("open a PDF before editing"),
        last_event: "Edit unavailable",
      }
  }
}

///|
fn PdfWorkbenchModel::apply_metadata_title(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) => {
      let next_title = self.metadata_title_draft.trim().to_owned()
      if next_title == document.metadata_title {
        { ..self, status: Ready, last_event: "Metadata title unchanged" }
      } else {
        self.replace_document_summary(
          document.with_edit(SetMetadataTitle(next_title)),
          event="Queued metadata title update",
        )
      }
    }
    None =>
      {
        ..self,
        status: Failed("open a PDF before editing metadata"),
        last_event: "Metadata edit unavailable",
      }
  }
}

///|
fn PdfWorkbenchModel::add_bookmark_for_current_page(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) => {
      let title = self.bookmark_title_draft.trim().to_owned()
      if title == "" {
        { ..self, status: Ready, last_event: "Bookmark title required" }
      } else {
        self.replace_document_summary(
          document.with_edit(AddBookmark(document.selected_page, title)),
          event="Queued bookmark for page " + document.selected_page.to_string(),
        )
      }
    }
    None =>
      {
        ..self,
        status: Failed("open a PDF before editing bookmarks"),
        last_event: "Bookmark edit unavailable",
      }
  }
}

///|
fn PdfWorkbenchModel::add_annotation_for_current_page(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) => {
      let text = self.annotation_text_draft.trim().to_owned()
      if text == "" {
        { ..self, status: Ready, last_event: "Annotation text required" }
      } else {
        self.replace_document_summary(
          document.with_edit(AddTextAnnotation(document.selected_page, text)),
          event="Queued note for page " + document.selected_page.to_string(),
        )
      }
    }
    None =>
      {
        ..self,
        status: Failed("open a PDF before editing annotations"),
        last_event: "Annotation edit unavailable",
      }
  }
}

///|
fn PdfWorkbenchModel::replace_document_summary(
  self : PdfWorkbenchModel,
  document : PdfWorkbenchDocument,
  event~ : String,
) -> PdfWorkbenchModel {
  { ..self, document: Some(document), status: Ready, last_event: event }
}
