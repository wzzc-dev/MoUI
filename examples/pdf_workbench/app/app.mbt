///|
using @views {
  badge,
  banner,
  button,
  column,
  custom_layout,
  expanded,
  row,
  scroll_view,
  spacer,
  stat_card,
  status_badge,
  status_bar,
  surface,
  text,
  text_field,
}

///|
pub struct PdfWorkbenchApp {
  unit : Unit
}

///|
pub(all) enum PdfWorkbenchStatus {
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
pub(all) struct PdfWorkbenchModel {
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
pub(all) struct PdfWorkbenchUpdate {
  model : PdfWorkbenchModel
  effect : @core.Effect[PdfWorkbenchMsg]
}

///|
pub(all) enum PdfWorkbenchMsg {
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
pub fn PdfWorkbenchUpdate::new(
  model : PdfWorkbenchModel,
  effect? : @core.Effect[PdfWorkbenchMsg] = @core.Effect::none(),
) -> PdfWorkbenchUpdate {
  { model, effect }
}

///|
pub fn PdfWorkbenchUpdate::as_tuple(
  self : PdfWorkbenchUpdate,
) -> (PdfWorkbenchModel, @core.Effect[PdfWorkbenchMsg]) {
  (self.model, self.effect)
}

///|
pub fn PdfWorkbenchModel::update(
  self : PdfWorkbenchModel,
  message : PdfWorkbenchMsg,
) -> PdfWorkbenchModel {
  self.update_with_services(message, @host.HostAppServices::unavailable()).model
}

///|
pub fn PdfWorkbenchModel::update_with_services(
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
pub fn PdfWorkbenchModel::subscriptions(
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

///|
pub fn PdfWorkbenchDocument::from_bytes(
  path~ : String,
  bytes~ : Bytes,
) -> PdfWorkbenchLoadResult {
  let sample = pdf_workbench_decode_sample(bytes)
  if !sample.contains("%PDF-") {
    return Failed("PDF header not found")
  }
  let page_count = pdf_workbench_estimated_page_count(sample)
  let version = pdf_workbench_pdf_version(sample)
  let page_summaries = pdf_workbench_page_summaries_from_sample(
    sample, page_count,
  )
  PdfWorkbenchDocument::from_engine_summary(
    path~,
    original_bytes=bytes,
    page_count~,
    selected_page=1,
    extracted_text=sample,
    dirty=false,
    writeback_available=false,
    edits=[],
    unsupported_entries=[
      "Lightweight fallback summary is active; native entrypoints use pdflite for real document metadata and text",
      "pdflite parsing/writeback is isolated in examples/pdf_workbench/pdflite_adapter",
      "PDFium raster service supplies real page bitmaps when the native adapter is linked",
      "Skia PDF backend is reserved for export/generation, not page rasterization",
    ],
    page_summaries~,
    metadata_summary="PDF \{version}; bytes=\{bytes.length()}; parser=lightweight-ui-shell",
    metadata_title="",
    outline_summary="Outline requires pdflite adapter",
    annotation_summary="Annotations require pdflite adapter",
  )
}

///|
fn pdf_workbench_append_unsupported_entry(
  entries : Array[String],
  entry : String,
) -> Array[String] {
  let next = entries.copy()
  next.push(entry)
  next
}

///|
pub fn PdfWorkbenchDocument::from_engine_summary(
  path~ : String,
  original_bytes~ : Bytes,
  page_count~ : Int,
  selected_page~ : Int,
  extracted_text~ : String,
  dirty~ : Bool,
  writeback_available? : Bool = false,
  edits? : Array[PdfWorkbenchEdit] = [],
  unsupported_entries? : Array[String] = [],
  page_summaries? : Array[PdfWorkbenchPageSummary] = [],
  metadata_summary? : String = "",
  metadata_title? : String = "",
  outline_summary? : String = "",
  annotation_summary? : String = "",
) -> PdfWorkbenchLoadResult {
  let safe_page_count = if page_count < 1 { 1 } else { page_count }
  let selected = pdf_workbench_clamp_int(selected_page, 1, safe_page_count)
  let summaries = if page_summaries.is_empty() {
    pdf_workbench_empty_page_summaries(safe_page_count)
  } else {
    page_summaries
  }
  Loaded({
    path,
    original_bytes,
    page_count: safe_page_count,
    selected_page: selected,
    extracted_text,
    dirty,
    writeback_available,
    edits,
    unsupported_entries,
    page_summaries: summaries,
    metadata_summary,
    metadata_title,
    outline_summary,
    annotation_summary,
    clean_unsupported_entries: unsupported_entries.copy(),
    clean_page_summaries: summaries.copy(),
    clean_metadata_title: metadata_title,
    clean_annotation_summary: annotation_summary,
  })
}

///|
pub fn PdfWorkbenchDocument::with_edit(
  self : PdfWorkbenchDocument,
  edit : PdfWorkbenchEdit,
) -> PdfWorkbenchDocument {
  let base = match edit {
    SetMetadataTitle(title) => { ..self, metadata_title: title }
    AddTextAnnotation(page, text) =>
      {
        ..self,
        annotation_summary: pdf_workbench_annotation_summary_with_queued_note(
          self.annotation_summary,
          page,
          text,
        ),
      }
    _ => self
  }
  let edits = base.edits.copy()
  edits.push(edit)
  let diagnostic = pdf_workbench_edit_diagnostic(edit)
  let unsupported_entries = base.unsupported_entries.copy()
  if !base.writeback_available {
    unsupported_entries.push(
      "Queued edit needs pdflite adapter writeback before it can be saved",
    )
  }
  let page_summaries = match edit {
    SetMetadataTitle(_) | AddBookmark(_, _) => base.page_summaries
    _ =>
      base.page_summaries.map(summary => {
        if summary.page_number ==
          pdf_workbench_edit_page(edit, base.selected_page) {
          {
            ..summary,
            content_diagnostic: summary.content_diagnostic + "; " + diagnostic,
          }
        } else {
          summary
        }
      })
  }
  { ..base, dirty: true, edits, unsupported_entries, page_summaries }
}

///|
pub fn PdfWorkbenchDocument::undo_last_edit(
  self : PdfWorkbenchDocument,
) -> PdfWorkbenchDocument? {
  if self.edits.is_empty() {
    return None
  }
  let remaining : Array[PdfWorkbenchEdit] = []
  for index in 0..<(self.edits.length() - 1) {
    remaining.push(self.edits[index])
  }
  Some(self.replay_edits(remaining))
}

///|
fn PdfWorkbenchDocument::replay_edits(
  self : PdfWorkbenchDocument,
  edits : Array[PdfWorkbenchEdit],
) -> PdfWorkbenchDocument {
  let mut replayed = self.discard_edits()
  for edit in edits {
    replayed = replayed.with_edit(edit)
  }
  replayed
}

///|
pub fn PdfWorkbenchDocument::discard_edits(
  self : PdfWorkbenchDocument,
) -> PdfWorkbenchDocument {
  {
    ..self,
    dirty: false,
    edits: [],
    unsupported_entries: self.clean_unsupported_entries.copy(),
    page_summaries: self.clean_page_summaries.copy(),
    metadata_title: self.clean_metadata_title,
    annotation_summary: self.clean_annotation_summary,
  }
}

///|
fn pdf_workbench_annotation_summary_with_queued_note(
  summary : String,
  page : Int,
  text : String,
) -> String {
  let prefix = "Queued text annotation page \{page}: " + text
  if summary.trim().to_owned() == "" {
    prefix
  } else {
    summary + "; " + prefix
  }
}

///|
fn pdf_workbench_edit_page(edit : PdfWorkbenchEdit, fallback : Int) -> Int {
  match edit {
    RotatePage(page, _) => page
    CropPage(page, _) => page
    StampText(page, _) => page
    AddBookmark(page, _) => page
    AddTextAnnotation(page, _) => page
    SetMetadataTitle(_) => fallback
  }
}

///|
pub fn PdfWorkbenchDocument::with_page_count_from_raster(
  self : PdfWorkbenchDocument,
  page_count : Int,
) -> PdfWorkbenchDocument {
  let safe_page_count = if page_count < 1 { 1 } else { page_count }
  if safe_page_count <= self.page_count &&
    self.page_summaries.length() >= safe_page_count &&
    self.clean_page_summaries.length() >= safe_page_count {
    self
  } else {
    let summaries = pdf_workbench_extend_raster_page_summaries(
      self.page_summaries,
      safe_page_count,
    )
    let clean_summaries = pdf_workbench_extend_raster_page_summaries(
      self.clean_page_summaries,
      safe_page_count,
    )
    {
      ..self,
      page_count: self.page_count.max(safe_page_count),
      selected_page: pdf_workbench_clamp_int(
        self.selected_page,
        1,
        self.page_count.max(safe_page_count),
      ),
      page_summaries: summaries,
      clean_page_summaries: clean_summaries,
    }
  }
}

///|
fn pdf_workbench_extend_raster_page_summaries(
  summaries : Array[PdfWorkbenchPageSummary],
  page_count : Int,
) -> Array[PdfWorkbenchPageSummary] {
  let next = summaries.copy()
  let mut page = next.length() + 1
  while page <= page_count {
    next.push({
      page_number: page,
      text_preview: "PDF page \{page} loaded. PDFium confirmed this page; pdflite adapter owns extracted text.",
      content_diagnostic: "PDFium raster page confirmed; lightweight summary unavailable",
    })
    page = page + 1
  }
  next
}

///|
pub fn PdfWorkbenchDocument::selected_summary(
  self : PdfWorkbenchDocument,
) -> PdfWorkbenchPageSummary {
  if self.page_summaries.is_empty() {
    {
      page_number: self.selected_page,
      text_preview: "No extracted text",
      content_diagnostic: "No page summary available",
    }
  } else {
    let index = pdf_workbench_clamp_int(
      self.selected_page - 1,
      0,
      self.page_summaries.length() - 1,
    )
    self.page_summaries[index]
  }
}

///|
pub fn PdfWorkbenchDocument::search_count(
  self : PdfWorkbenchDocument,
  query : String,
) -> Int {
  let pages = self.search_match_pages(query)
  pages.length()
}

///|
pub fn PdfWorkbenchDocument::search_match_pages(
  self : PdfWorkbenchDocument,
  query : String,
) -> Array[Int] {
  let needle = pdf_workbench_normalized_query(query)
  let matches : Array[Int] = []
  if needle == "" {
    return matches
  }
  for summary in self.page_summaries {
    if pdf_workbench_page_summary_matches(summary, needle) {
      matches.push(summary.page_number)
    }
  }
  if matches.is_empty() && self.extracted_text.to_lower().contains(needle) {
    matches.push(self.selected_page)
  }
  matches
}

///|
pub fn PdfWorkbenchDocument::next_search_page(
  self : PdfWorkbenchDocument,
  query : String,
) -> Int? {
  let matches = self.search_match_pages(query)
  if matches.is_empty() {
    return None
  }
  for page in matches {
    if page > self.selected_page {
      return Some(page)
    }
  }
  Some(matches[0])
}

///|
pub fn PdfWorkbenchDocument::previous_search_page(
  self : PdfWorkbenchDocument,
  query : String,
) -> Int? {
  let matches = self.search_match_pages(query)
  if matches.is_empty() {
    return None
  }
  let mut previous = matches[matches.length() - 1]
  for page in matches {
    if page < self.selected_page {
      previous = page
    }
  }
  Some(previous)
}

///|
pub fn PdfWorkbenchDocument::search_match_position(
  self : PdfWorkbenchDocument,
  query : String,
  page_number : Int,
) -> Int? {
  let matches = self.search_match_pages(query)
  for index in 0..<matches.length() {
    if matches[index] == page_number {
      return Some(index + 1)
    }
  }
  None
}

///|
fn pdf_workbench_search_position_suffix(
  document : PdfWorkbenchDocument,
  query : String,
  page_number : Int,
) -> String {
  let matches = document.search_match_pages(query)
  match document.search_match_position(query, page_number) {
    Some(position) =>
      " (" + position.to_string() + "/" + matches.length().to_string() + ")"
    None => ""
  }
}

///|
fn pdf_workbench_normalized_query(query : String) -> String {
  query.trim().to_owned().to_lower()
}

///|
fn pdf_workbench_page_summary_matches(
  summary : PdfWorkbenchPageSummary,
  needle : String,
) -> Bool {
  summary.text_preview.to_lower().contains(needle) ||
  summary.content_diagnostic.to_lower().contains(needle)
}

///|
pub fn pdf_workbench_minimum_pdf_bytes() -> Bytes {
  b"%PDF-1.4\n1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n"
}

///|
fn pdf_workbench_decode_sample(bytes : Bytes) -> String {
  let length = if bytes.length() > 8192 { 8192 } else { bytes.length() }
  @utf8.decode_lossy(bytes[:length], ignore_bom=true)
}

///|
fn pdf_workbench_pdf_version(sample : String) -> String {
  if sample.contains("%PDF-2.0") {
    "2.0"
  } else if sample.contains("%PDF-1.7") {
    "1.7"
  } else if sample.contains("%PDF-1.6") {
    "1.6"
  } else if sample.contains("%PDF-1.5") {
    "1.5"
  } else if sample.contains("%PDF-1.4") {
    "1.4"
  } else if sample.contains("%PDF-1.3") {
    "1.3"
  } else if sample.contains("%PDF-1.2") {
    "1.2"
  } else if sample.contains("%PDF-1.1") {
    "1.1"
  } else if sample.contains("%PDF-1.0") {
    "1.0"
  } else {
    "unknown"
  }
}

///|
fn pdf_workbench_estimated_page_count(sample : String) -> Int {
  let page_markers = pdf_workbench_count_occurrences(sample, "/Type /Page")
  let pages_markers = pdf_workbench_count_occurrences(sample, "/Type /Pages")
  let count = page_markers - pages_markers
  if count < 1 {
    1
  } else {
    count
  }
}

///|
fn pdf_workbench_page_summaries_from_sample(
  sample : String,
  page_count : Int,
) -> Array[PdfWorkbenchPageSummary] {
  let summaries : Array[PdfWorkbenchPageSummary] = []
  let version = pdf_workbench_pdf_version(sample)
  for page in 1..<=page_count {
    summaries.push({
      page_number: page,
      text_preview: "PDF page \{page} loaded. Lightweight shell detected PDF \{version}; use the pdflite adapter for extracted text.",
      content_diagnostic: "lightweight summary only; pdflite adapter owns precise text/content extraction",
    })
  }
  summaries
}

///|
fn pdf_workbench_empty_page_summaries(
  page_count : Int,
) -> Array[PdfWorkbenchPageSummary] {
  let summaries : Array[PdfWorkbenchPageSummary] = []
  for page in 1..<=page_count {
    summaries.push({
      page_number: page,
      text_preview: "No extracted text on this page",
      content_diagnostic: "no page summary available",
    })
  }
  summaries
}

///|
fn pdf_workbench_count_occurrences(haystack : String, needle : String) -> Int {
  let source = haystack.to_array()
  let pattern = needle.to_array()
  if pattern.is_empty() || source.length() < pattern.length() {
    return 0
  }
  let mut count = 0
  for index in 0..<=(source.length() - pattern.length()) {
    let mut matched = true
    for offset in 0..<pattern.length() {
      if source[index + offset] != pattern[offset] {
        matched = false
      }
    }
    if matched {
      count = count + 1
    }
  }
  count
}

///|
fn pdf_workbench_edit_diagnostic(edit : PdfWorkbenchEdit) -> String {
  match edit {
    RotatePage(page, degrees) =>
      "queued rotate page \{page} by \{degrees} degrees"
    CropPage(page, box) =>
      "queued crop page \{page} to [\{box.left}, \{box.bottom}, \{box.right}, \{box.top}]"
    StampText(page, value) => "queued stamp page \{page}: " + value
    SetMetadataTitle(value) => "queued metadata title: " + value
    AddBookmark(page, title) => "queued bookmark page \{page}: " + title
    AddTextAnnotation(page, text) =>
      "queued text annotation page \{page}: " + text
  }
}

///|
fn pdf_workbench_default_stamp_text() -> String {
  "REVIEWED"
}

///|
fn pdf_workbench_clamp_int(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
fn pdf_workbench_parse_positive_int(value : String) -> Int? {
  let chars = value.trim().to_owned().to_array()
  if chars.length() == 0 {
    return None
  }
  let mut parsed = 0
  for char in chars {
    if !char.is_ascii_digit() {
      return None
    }
    parsed = parsed * 10 + char.to_int() - '0'.to_int()
  }
  if parsed < 1 {
    None
  } else {
    Some(parsed)
  }
}

///|
fn pdf_workbench_file_name(path : String) -> String {
  let chars = path.to_array()
  let mut start = 0
  for index in 0..<chars.length() {
    if chars[index] == '/' || chars[index] == '\\' {
      start = index + 1
    }
  }
  String::from_array(chars[start:]).trim().to_owned()
}

///|
fn pdf_workbench_default_save_file_name(path : String) -> String {
  let name = pdf_workbench_file_name(path)
  if name == "" {
    "document.pdf"
  } else if pdf_workbench_ends_with_ignore_case(name, ".pdf") {
    name
  } else {
    name + ".pdf"
  }
}

///|
fn pdf_workbench_ends_with_ignore_case(value : String, suffix : String) -> Bool {
  let source = value.to_lower().to_array()
  let pattern = suffix.to_lower().to_array()
  if pattern.length() > source.length() {
    return false
  }
  let start = source.length() - pattern.length()
  for offset in 0..<pattern.length() {
    if source[start + offset] != pattern[offset] {
      return false
    }
  }
  true
}

///|
fn pdf_workbench_request_action(request : @host.HostServiceRequest) -> String {
  match request {
    @host.HostServiceRequest::FileDialog(_) => "choosing a PDF"
    @host.HostServiceRequest::BinaryFile(
      @host.HostBinaryFileRequest::ReadBytes(path)
    ) => "reading " + pdf_workbench_file_name(path)
    @host.HostServiceRequest::BinaryFile(
      @host.HostBinaryFileRequest::WriteBytes(path, _)
    ) => "writing " + pdf_workbench_file_name(path)
    _ => "handling host service"
  }
}

///|
fn pdf_workbench_unavailable_message(
  request : @host.HostServiceRequest,
  reason : String,
) -> String {
  match request {
    @host.HostServiceRequest::BinaryFile(
      @host.HostBinaryFileRequest::ReadBytes(path)
    ) => "Read failed for " + pdf_workbench_file_name(path) + ": " + reason
    @host.HostServiceRequest::BinaryFile(
      @host.HostBinaryFileRequest::WriteBytes(path, _)
    ) => "Write failed for " + pdf_workbench_file_name(path) + ": " + reason
    @host.HostServiceRequest::FileDialog(_) => "File dialog failed: " + reason
    _ => reason
  }
}

///|
fn pdf_workbench_binary_response_log(
  response : @host.HostServiceResponse,
) -> String {
  match response {
    @host.HostServiceResponse::BinaryFileContent(path, bytes) =>
      "pdf workbench: read \{bytes.length()} byte(s) from " + path
    @host.HostServiceResponse::BinaryFileWritten(path) =>
      "pdf workbench: wrote PDF bytes to " + path
    @host.HostServiceResponse::Unavailable(reason) =>
      "pdf workbench: binary file service unavailable: " + reason
    @host.HostServiceResponse::Pending(id) =>
      "pdf workbench: binary file service pending id=\{id.value}"
    _ => "pdf workbench: binary file service returned non-binary response"
  }
}

///|
fn pdf_workbench_pending_label(request : @host.HostServiceRequest) -> String {
  match request {
    @host.HostServiceRequest::FileDialog(_) => "PDF file dialog completion"
    @host.HostServiceRequest::BinaryFile(_) => "PDF binary file completion"
    _ => "PDF host service completion"
  }
}

///|
fn pdf_workbench_completion(
  request : @host.HostServiceRequest,
  response : @host.HostServiceResponse,
) -> @host.HostCompletedServiceResponse {
  let id = match response {
    @host.HostServiceResponse::Pending(id) => id
    _ => @host.HostServiceRequestId::new(0)
  }
  { id, request, response }
}

///|
pub fn view(model : PdfWorkbenchModel) -> @core.View[PdfWorkbenchMsg] {
  model.view_for_viewport(@core.Size::new(width=1120.0, height=720.0))
}

///|
fn PdfWorkbenchModel::view_with_environment(
  self : PdfWorkbenchModel,
  env : @core.ViewEnvironment,
) -> @core.View[PdfWorkbenchMsg] {
  self.view_for_viewport(env.viewport_size())
}

///|
fn PdfWorkbenchModel::view_for_viewport(
  self : PdfWorkbenchModel,
  viewport : @core.Size,
) -> @core.View[PdfWorkbenchMsg] {
  let theme = @views.light_theme()
  let metrics = pdf_workbench_layout_metrics(
    viewport,
    theme,
    reader_fullscreen=self.reader_fullscreen,
  )
  if self.reader_fullscreen {
    return surface(
      pdf_workbench_page_surface(self, metrics, theme),
      width=metrics.viewport.width,
      height=metrics.viewport.height,
      variant=@views.SurfaceVariant::Base,
      theme~,
      padding=theme.spacing_scale.sm,
    )
  }
  let header = pdf_workbench_toolbar(self, theme)
  let body_columns : Array[@core.View[PdfWorkbenchMsg]] = []
  if metrics.sidebar_visible {
    body_columns.push(pdf_workbench_sidebar(self, metrics, theme))
  }
  body_columns.push(expanded(pdf_workbench_page_surface(self, metrics, theme)))
  if metrics.inspector_visible {
    body_columns.push(pdf_workbench_inspector(self, metrics, theme))
  }
  let body = row(
    body_columns,
    spacing=theme.spacing_scale.md,
    align=@views.CrossAlign::Start,
  )
  let rows : Array[@core.View[PdfWorkbenchMsg]] = [header]
  match self.status {
    Failed(_) => rows.push(pdf_workbench_failure_banner(self, metrics, theme))
    _ => ()
  }
  rows.push(body)
  rows.push(pdf_workbench_status(self, metrics, theme))
  surface(
    column(
      rows,
      spacing=theme.spacing_scale.md,
      align=@views.CrossAlign::Stretch,
    ),
    width=metrics.viewport.width,
    height=metrics.viewport.height,
    variant=@views.SurfaceVariant::Base,
    theme~,
    padding=theme.spacing_scale.lg,
  )
}

///|
priv struct PdfWorkbenchLayoutMetrics {
  viewport : @core.Size
  inner_width : Double
  body_height : Double
  sidebar_visible : Bool
  sidebar_width : Double
  sidebar_scroll_width : Double
  page_width : Double
  preview_width : Double
  preview_height : Double
  inspector_visible : Bool
  inspector_width : Double
  inspector_scroll_width : Double
  reader_fullscreen : Bool
}

///|
fn pdf_workbench_layout_metrics(
  viewport : @core.Size,
  theme : @core.Theme,
  reader_fullscreen? : Bool = false,
) -> PdfWorkbenchLayoutMetrics {
  let safe_width = viewport.width.max(640.0)
  let safe_height = viewport.height.max(520.0)
  let root_padding = if reader_fullscreen {
    theme.spacing_scale.sm
  } else {
    theme.spacing_scale.lg
  }
  let spacing = theme.spacing_scale.md
  let inner_width = (safe_width - root_padding * 2.0).max(560.0)
  let inner_height = (safe_height - root_padding * 2.0).max(460.0)
  let toolbar_height = 58.0
  let status_height = 40.0
  let body_height = if reader_fullscreen {
    inner_height.max(320.0)
  } else {
    (inner_height - toolbar_height - status_height - spacing * 2.0).max(320.0)
  }
  let sidebar_visible = !reader_fullscreen && inner_width >= 860.0
  let inspector_visible = !reader_fullscreen && inner_width >= 1040.0
  let sidebar_width = if !sidebar_visible {
    0.0
  } else if inner_width >= 1500.0 {
    260.0
  } else if inner_width >= 1180.0 {
    236.0
  } else {
    212.0
  }
  let inspector_width = if !inspector_visible {
    0.0
  } else if inner_width >= 1500.0 {
    286.0
  } else if inner_width >= 1180.0 {
    260.0
  } else {
    232.0
  }
  let visible_side_columns = (if sidebar_visible { 1 } else { 0 }) +
    (if inspector_visible { 1 } else { 0 })
  let page_width = (inner_width -
  sidebar_width -
  inspector_width -
  spacing * visible_side_columns.to_double()).max(360.0)
  let panel_padding = theme.spacing_scale.md
  let compact_panel_padding = theme.spacing_scale.sm
  {
    viewport: @core.Size::new(width=safe_width, height=safe_height),
    inner_width,
    body_height,
    sidebar_visible,
    sidebar_width,
    sidebar_scroll_width: (sidebar_width - compact_panel_padding * 2.0).max(
      160.0,
    ),
    page_width,
    preview_width: (page_width - panel_padding * 2.0).max(300.0),
    preview_height: (body_height - panel_padding * 2.0 - 42.0).max(260.0),
    inspector_visible,
    inspector_width,
    inspector_scroll_width: (inspector_width - compact_panel_padding * 2.0).max(
      180.0,
    ),
    reader_fullscreen,
  }
}

///|
fn pdf_workbench_panel_item_width(
  scroll_width : Double,
  theme : @core.Theme,
) -> Double {
  (scroll_width - theme.spacing_scale.md).max(140.0)
}

///|
fn pdf_workbench_panel_scroll_height(
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @core.Theme,
) -> Double {
  (metrics.body_height - theme.spacing_scale.sm * 2.0).max(260.0)
}

///|
fn pdf_workbench_toolbar(
  model : PdfWorkbenchModel,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  row(
    [
      column(
        [
          text(
            "PDF Workbench",
            role=@views.TextRole::Title,
            theme~,
            width=220.0,
            height=32.0,
          ),
          text(
            "Native PDF reader with light editing",
            role=@views.TextRole::Caption,
            theme~,
            width=300.0,
            height=22.0,
          ).foreground(theme.palette.muted),
        ],
        spacing=0.0,
        align=@views.CrossAlign::Start,
      ),
      spacer(min_length=16.0, weight=1.0),
      button("Open", on_click=OpenRequested, theme~, width=82.0, height=36.0),
      button(
        "Save",
        on_click=SaveRequested,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=78.0,
        height=36.0,
      ),
      button(
        "Save As",
        on_click=SaveAsRequested,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=92.0,
        height=36.0,
      ),
      text_field(
        model.query,
        on_input=query => SearchChanged(query),
        placeholder="Search extracted text",
        variant=@views.TextFieldVariant::Outline,
        theme~,
        width=156.0,
        height=36.0,
      ),
      text(
        model.search_status_label(),
        role=@views.TextRole::Caption,
        theme~,
        width=92.0,
        height=24.0,
      ).foreground(theme.palette.muted),
      button(
        "Prev Hit",
        on_click=SearchPrevious,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=78.0,
        height=36.0,
      ),
      button(
        "Next Hit",
        on_click=SearchNext,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=78.0,
        height=36.0,
      ),
    ],
    spacing=theme.spacing_scale.sm,
    align=@views.CrossAlign::Center,
  )
}

///|
fn pdf_workbench_sidebar(
  model : PdfWorkbenchModel,
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let rows : Array[@core.View[PdfWorkbenchMsg]] = []
  let item_width = pdf_workbench_panel_item_width(
    metrics.sidebar_scroll_width,
    theme,
  )
  match model.document {
    Some(document) => {
      let search_matches = document.search_match_pages(model.query)
      rows.push(
        stat_card(
          "Pages",
          document.page_count.to_string(),
          caption=if document.dirty { "Unsaved edits" } else { "Saved state" },
          tone=if document.dirty {
            @views.FeedbackTone::Warning
          } else {
            @views.FeedbackTone::Success
          },
          theme~,
          width=item_width,
          height=104.0,
        ),
      )
      for summary in document.page_summaries {
        rows.push(
          pdf_workbench_page_nav_item(
            summary,
            selected=summary.page_number == document.selected_page,
            matched=search_matches.any(page => page == summary.page_number),
            thumbnail_raster=model.thumbnail_raster_for_page(
              summary.page_number,
            ),
            width=item_width,
            theme,
          ),
        )
      }
    }
    None =>
      rows.push(
        banner(
          "No PDF loaded",
          "Use Open to load PDF bytes through the host binary file service.",
          tone=@views.FeedbackTone::Info,
          theme~,
          width=item_width,
        ),
      )
  }
  surface(
    scroll_view(
      column(
        rows,
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Stretch,
      ),
      width=metrics.sidebar_scroll_width,
      height=pdf_workbench_panel_scroll_height(metrics, theme),
      offset=model.sidebar_scroll.offset(),
      state=Some(model.sidebar_scroll),
    ),
    width=metrics.sidebar_width,
    height=metrics.body_height,
    variant=@views.SurfaceVariant::Raised,
    theme~,
    padding=theme.spacing_scale.sm,
  )
}

///|
fn pdf_workbench_page_nav_item(
  summary : PdfWorkbenchPageSummary,
  selected~ : Bool,
  matched~ : Bool,
  thumbnail_raster~ : PdfWorkbenchRasterPage?,
  width~ : Double,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let control_width = (width - 68.0).max(110.0)
  row(
    [
      pdf_workbench_page_thumbnail(summary, selected~, thumbnail_raster~, theme),
      column(
        [
          button(
            "Page " + summary.page_number.to_string(),
            on_click=SelectPage(summary.page_number),
            variant=if selected {
              @views.ButtonVariant::Primary
            } else {
              @views.ButtonVariant::Ghost
            },
            theme~,
            width=control_width,
            height=32.0,
          ),
          text(
            if selected {
              "Current"
            } else if matched {
              "Match"
            } else {
              ""
            },
            role=@views.TextRole::Caption,
            theme~,
            width=control_width,
            height=18.0,
          ).foreground(theme.palette.muted),
        ],
        spacing=2.0,
        align=@views.CrossAlign::Stretch,
      ),
    ],
    spacing=theme.spacing_scale.sm,
    align=@views.CrossAlign::Center,
  )
}

///|
fn pdf_workbench_page_thumbnail(
  summary : PdfWorkbenchPageSummary,
  selected~ : Bool,
  thumbnail_raster~ : PdfWorkbenchRasterPage?,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  custom_layout(
    measure=_ => @core.Size::new(width=54.0, height=68.0),
    paint=frame => {
      let page_width = 40.0
      let page_height = 56.0
      let x = frame.origin.x + (frame.size.width - page_width) / 2.0
      let y = frame.origin.y + (frame.size.height - page_height) / 2.0
      let page_rect = @core.Rect::new(
        x~,
        y~,
        width=page_width,
        height=page_height,
      )
      let commands : Array[@core.DrawCommand] = []
      if selected {
        commands.push(
          @core.DrawCommand::FillRect(
            frame,
            theme.palette.primary.multiply_alpha(0.10),
          ),
        )
      }
      commands.push(
        @core.DrawCommand::FillRect(page_rect, @core.Color::white()),
      )
      match thumbnail_raster {
        Some(raster) =>
          commands.push(
            @core.DrawCommand::DrawImage(@core.ImageRun::{
              source: raster.image_source,
              frame: page_rect,
              opacity: 1.0,
              fit: @core.ImageFit::Contain,
            }),
          )
        None => ()
      }
      commands.push(
        @core.DrawCommand::StrokeRect(
          page_rect,
          if selected {
            theme.palette.primary
          } else {
            theme.palette.outline
          },
          if selected {
            2.0
          } else {
            1.0
          },
        ),
      )
      let line_color = if selected {
        theme.palette.primary.multiply_alpha(0.42)
      } else {
        theme.palette.muted.multiply_alpha(0.48)
      }
      match thumbnail_raster {
        Some(_) => {
          let label_rect = @core.Rect::new(
            x=x + 5.0,
            y=y + page_height - 17.0,
            width=page_width - 10.0,
            height=13.0,
          )
          commands.push(
            @core.DrawCommand::FillRect(
              label_rect,
              theme.palette.surface.multiply_alpha(0.82),
            ),
          )
        }
        None =>
          for index in 0..<4 {
            let line_y = y + 14.0 + index.to_double() * 7.0
            let line_width = if index == 3 { 18.0 } else { 26.0 }
            commands.push(
              @core.DrawCommand::FillRect(
                @core.Rect::new(
                  x=x + 7.0,
                  y=line_y,
                  width=line_width,
                  height=2.0,
                ),
                line_color,
              ),
            )
          }
      }
      commands.push(
        @core.DrawCommand::DrawText(
          @core.TextRun::new(
            text=summary.page_number.to_string(),
            frame=@core.Rect::new(
              x=x + 7.0,
              y=y + page_height - 16.0,
              width=page_width - 14.0,
              height=12.0,
            ),
            font=@core.FontSpec::new(size=10.0),
            color=if selected {
              theme.palette.primary
            } else {
              theme.palette.muted
            },
            align=@core.TextAlign::TextCenter,
          ),
        ),
      )
      commands
    },
    semantics_label="Page thumbnail " + summary.page_number.to_string(),
  )
}

///|
fn PdfWorkbenchModel::thumbnail_raster_for_page(
  self : PdfWorkbenchModel,
  page_number : Int,
) -> PdfWorkbenchRasterPage? {
  match self.raster_page {
    Some(page) => if page.page_number == page_number { return Some(page) }
    None => ()
  }
  let length = self.raster_cache.length()
  for offset in 0..<length {
    let index = length - 1 - offset
    let page = self.raster_cache[index]
    if page.page_number == page_number {
      return Some(page)
    }
  }
  None
}

///|
fn pdf_workbench_page_surface(
  model : PdfWorkbenchModel,
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let page = match model.document {
    Some(document) => document.selected_summary()
    None =>
      match model.status {
        Failed(reason) =>
          {
            page_number: 0,
            text_preview: "PDF load failed: " + reason,
            content_diagnostic: model.last_event,
          }
        _ =>
          {
            page_number: 0,
            text_preview: "Open a PDF to show a structured page preview.",
            content_diagnostic: "No document",
          }
      }
  }
  let page_label = match model.document {
    Some(document) =>
      "Page " +
      document.selected_page.to_string() +
      " / " +
      document.page_count.to_string()
    None => "Preview"
  }
  let rows : Array[@core.View[PdfWorkbenchMsg]] = [
    pdf_workbench_page_toolbar(model, page_label, metrics, theme),
  ]
  if !metrics.reader_fullscreen && !metrics.inspector_visible {
    rows.push(pdf_workbench_compact_edit_strip(model, metrics, theme))
  }
  rows.push(
    scroll_view(
      pdf_workbench_preview_canvas(
        page,
        model.document,
        model.raster_page,
        model.raster_status,
        model.zoom,
        metrics,
        theme,
      ),
      offset=model.preview_scroll_offset,
      width=metrics.preview_width,
      height=pdf_workbench_page_scroll_height(metrics),
      on_scroll=Some(delta => PreviewScrolled(delta)),
    ),
  )
  surface(
    column(
      rows,
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Stretch,
    ),
    width=metrics.page_width,
    height=metrics.body_height,
    variant=@views.SurfaceVariant::Raised,
    theme~,
    padding=theme.spacing_scale.md,
  )
}

///|
fn pdf_workbench_page_toolbar(
  model : PdfWorkbenchModel,
  page_label : String,
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let fullscreen_label = if model.reader_fullscreen { "Exit" } else { "Full" }
  row(
    [
      button(
        "Prev",
        on_click=PreviousPage,
        variant=@views.ButtonVariant::Ghost,
        theme~,
        width=56.0,
        height=32.0,
      ),
      text(
        page_label,
        role=@views.TextRole::Title,
        theme~,
        width=(metrics.page_width - 514.0).max(36.0),
        height=32.0,
      ),
      button(
        "Next",
        on_click=NextPage,
        variant=@views.ButtonVariant::Ghost,
        theme~,
        width=56.0,
        height=32.0,
      ),
      spacer(min_length=8.0, weight=1.0),
      text_field(
        model.page_number_draft,
        on_input=value => PageNumberChanged(value),
        placeholder="Page",
        variant=@views.TextFieldVariant::Outline,
        theme~,
        width=52.0,
        height=32.0,
      ),
      button(
        "Go",
        on_click=GoToPage,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=40.0,
        height=32.0,
      ),
      text(
        pdf_workbench_zoom_label(model.zoom),
        role=@views.TextRole::Caption,
        theme~,
        width=48.0,
        height=24.0,
      ).foreground(theme.palette.muted),
      button("+", on_click=ZoomIn, theme~, width=34.0, height=32.0),
      button("-", on_click=ZoomOut, theme~, width=34.0, height=32.0),
      button(
        "Fit",
        on_click=ZoomFitWidth,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=44.0,
        height=32.0,
      ),
      button(
        fullscreen_label,
        on_click=ToggleReaderFullscreen,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=54.0,
        height=32.0,
      ),
    ],
    spacing=theme.spacing_scale.sm,
    align=@views.CrossAlign::Center,
  )
}

///|
fn pdf_workbench_compact_edit_strip(
  model : PdfWorkbenchModel,
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  ignore(metrics)
  let dirty = match model.document {
    Some(document) => document.dirty || document.edits.length() > 0
    None => false
  }
  row(
    [
      text(
        if dirty {
          "Quick edits"
        } else {
          "Edit"
        },
        role=@views.TextRole::Control,
        theme~,
        width=72.0,
        height=28.0,
      ),
      button(
        "Rotate 90",
        on_click=RotateCurrentPage,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=82.0,
        height=30.0,
      ),
      button(
        "Crop",
        on_click=CropCurrentPage,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=58.0,
        height=30.0,
      ),
      button(
        "Stamp",
        on_click=StampCurrentPage,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width=66.0,
        height=30.0,
      ),
      spacer(min_length=4.0, weight=1.0),
      button(
        "Undo Last",
        on_click=UndoLastEdit,
        variant=@views.ButtonVariant::Ghost,
        theme~,
        width=78.0,
        height=30.0,
      ),
      button(
        "Discard Edits",
        on_click=DiscardEdits,
        variant=@views.ButtonVariant::Ghost,
        theme~,
        width=104.0,
        height=30.0,
      ),
    ],
    spacing=theme.spacing_scale.xs,
    align=@views.CrossAlign::Center,
  )
}

///|
fn pdf_workbench_page_scroll_height(
  metrics : PdfWorkbenchLayoutMetrics,
) -> Double {
  if metrics.reader_fullscreen || metrics.inspector_visible {
    metrics.preview_height
  } else {
    (metrics.preview_height - 38.0).max(220.0)
  }
}

///|
fn pdf_workbench_preview_canvas(
  page : PdfWorkbenchPageSummary,
  document : PdfWorkbenchDocument?,
  raster_page : PdfWorkbenchRasterPage?,
  raster_status : PdfWorkbenchRasterStatus,
  zoom : Double,
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  custom_layout(
    measure=_ => pdf_workbench_preview_content_size(raster_page, zoom, metrics),
    paint=frame => {
      let page_size = pdf_workbench_preview_page_size(
        raster_page, zoom, metrics,
      )
      let page_width = page_size.width
      let page_height = page_size.height
      let x = frame.origin.x + (frame.size.width - page_width) / 2.0
      let y = frame.origin.y + 36.0
      let page_rect = @core.Rect::new(
        x~,
        y~,
        width=page_width,
        height=page_height,
      )
      let loaded_title = match document {
        Some(_) => "Loaded PDF"
        None => if page.page_number == 0 { "No PDF loaded" } else { "Preview" }
      }
      let file_line = match document {
        Some(document) =>
          pdf_workbench_file_name(document.path) +
          " | \{document.original_bytes.length()} byte(s) | page \{document.selected_page}/\{document.page_count}"
        None => "Use Open to choose a .pdf file"
      }
      let commands : Array[@core.DrawCommand] = []
      commands.push(
        @core.DrawCommand::FillRect(frame, theme.palette.surface_variant),
      )
      commands.push(
        @core.DrawCommand::FillRect(page_rect, @core.Color::white()),
      )
      match raster_page {
        Some(raster) =>
          commands.push(
            @core.DrawCommand::DrawImage(@core.ImageRun::{
              source: raster.image_source,
              frame: page_rect,
              opacity: 1.0,
              fit: @core.ImageFit::Contain,
            }),
          )
        None => {
          commands.push(
            @core.DrawCommand::DrawText(
              @core.TextRun::new(
                text=loaded_title,
                frame=@core.Rect::new(
                  x=x + 24.0,
                  y=y + 28.0,
                  width=page_width - 48.0,
                  height=28.0,
                ),
                font=@core.FontSpec::new(size=18.0),
                color=theme.palette.foreground,
                align=@core.TextAlign::TextStart,
              ),
            ),
          )
          commands.push(
            @core.DrawCommand::DrawText(
              @core.TextRun::new(
                text=file_line,
                frame=@core.Rect::new(
                  x=x + 24.0,
                  y=y + 62.0,
                  width=page_width - 48.0,
                  height=24.0,
                ),
                font=@core.FontSpec::new(size=12.0),
                color=theme.palette.muted,
                align=@core.TextAlign::TextStart,
              ),
            ),
          )
          commands.push(
            @core.DrawCommand::DrawText(
              @core.TextRun::new(
                text=page.text_preview,
                frame=@core.Rect::new(
                  x=x + 24.0,
                  y=y + 104.0,
                  width=page_width - 48.0,
                  height=160.0,
                ),
                font=@core.FontSpec::new(size=14.0),
                color=theme.palette.foreground,
                align=@core.TextAlign::TextStart,
              ),
            ),
          )
          commands.push(
            @core.DrawCommand::DrawText(
              @core.TextRun::new(
                text=page.content_diagnostic,
                frame=@core.Rect::new(
                  x=x + 24.0,
                  y=y + page_height - 92.0,
                  width=page_width - 48.0,
                  height=32.0,
                ),
                font=@core.FontSpec::new(size=12.0),
                color=theme.palette.muted,
                align=@core.TextAlign::TextStart,
              ),
            ),
          )
        }
      }
      commands.push(
        @core.DrawCommand::StrokeRect(page_rect, theme.palette.outline, 1.0),
      )
      match document {
        Some(document) =>
          pdf_workbench_push_page_edit_overlays(
            commands, document, page_rect, theme,
          )
        None => ()
      }
      commands.push(
        @core.DrawCommand::DrawText(
          @core.TextRun::new(
            text=pdf_workbench_raster_status_label(raster_status),
            frame=@core.Rect::new(
              x=frame.origin.x + 16.0,
              y=frame.origin.y + 4.0,
              width=frame.size.width - 32.0,
              height=20.0,
            ),
            font=@core.FontSpec::new(size=12.0),
            color=theme.palette.muted,
            align=@core.TextAlign::TextStart,
          ),
        ),
      )
      commands
    },
    semantics_label=page.text_preview,
  )
}

///|
fn pdf_workbench_preview_aspect(
  raster_page : PdfWorkbenchRasterPage?,
) -> Double {
  match raster_page {
    Some(raster) =>
      if raster.height_px > 0 {
        raster.width_px.to_double() / raster.height_px.to_double()
      } else {
        0.75
      }
    None => 0.75
  }
}

///|
fn pdf_workbench_preview_display_zoom(zoom : Double) -> Double {
  if zoom < 0.5 {
    0.5
  } else if zoom > 2.0 {
    2.0
  } else {
    zoom
  }
}

///|
fn pdf_workbench_preview_page_size(
  raster_page : PdfWorkbenchRasterPage?,
  zoom : Double,
  metrics : PdfWorkbenchLayoutMetrics,
) -> @core.Size {
  let aspect = pdf_workbench_preview_aspect(raster_page)
  let available_width = (metrics.preview_width - 32.0).max(120.0)
  let page_width = (available_width * pdf_workbench_preview_display_zoom(zoom)).max(
    120.0,
  )
  @core.Size::new(width=page_width, height=(page_width / aspect).max(120.0))
}

///|
fn pdf_workbench_preview_content_size(
  raster_page : PdfWorkbenchRasterPage?,
  zoom : Double,
  metrics : PdfWorkbenchLayoutMetrics,
) -> @core.Size {
  let page_size = pdf_workbench_preview_page_size(raster_page, zoom, metrics)
  @core.Size::new(
    width=(page_size.width + 32.0).max(metrics.preview_width),
    height=(page_size.height + 72.0).max(metrics.preview_height),
  )
}

///|
fn pdf_workbench_push_page_edit_overlays(
  commands : Array[@core.DrawCommand],
  document : PdfWorkbenchDocument,
  page_rect : @core.Rect,
  theme : @core.Theme,
) -> Unit {
  let mut stamp_index = 0
  let mut note_index = 0
  for edit in document.edits {
    match edit {
      StampText(page, value) =>
        if page == document.selected_page {
          let stamp_width = 104.0
          let stamp_height = 28.0
          let stamp_rect = @core.Rect::new(
            x=page_rect.origin.x + page_rect.size.width - stamp_width - 18.0,
            y=page_rect.origin.y + 18.0 + stamp_index.to_double() * 34.0,
            width=stamp_width,
            height=stamp_height,
          )
          commands.push(
            @core.DrawCommand::FillRect(
              stamp_rect,
              theme.palette.primary.multiply_alpha(0.12),
            ),
          )
          commands.push(
            @core.DrawCommand::StrokeRect(
              stamp_rect,
              theme.palette.primary.multiply_alpha(0.72),
              1.0,
            ),
          )
          commands.push(
            @core.DrawCommand::DrawText(
              @core.TextRun::new(
                text=value,
                frame=stamp_rect,
                font=@core.FontSpec::new(size=12.0),
                color=theme.palette.primary,
                align=@core.TextAlign::TextCenter,
              ),
            ),
          )
          stamp_index = stamp_index + 1
        }
      AddTextAnnotation(page, value) =>
        if page == document.selected_page {
          let note_width = 168.0
          let note_height = 46.0
          let note_rect = @core.Rect::new(
            x=page_rect.origin.x + 18.0,
            y=page_rect.origin.y + 18.0 + note_index.to_double() * 52.0,
            width=note_width,
            height=note_height,
          )
          commands.push(
            @core.DrawCommand::FillRect(
              note_rect,
              theme.palette.primary.multiply_alpha(0.10),
            ),
          )
          commands.push(
            @core.DrawCommand::StrokeRect(
              note_rect,
              theme.palette.primary.multiply_alpha(0.58),
              1.0,
            ),
          )
          commands.push(
            @core.DrawCommand::DrawText(
              @core.TextRun::new(
                text=value,
                frame=@core.Rect::new(
                  x=note_rect.origin.x + 8.0,
                  y=note_rect.origin.y + 7.0,
                  width=note_rect.size.width - 16.0,
                  height=note_rect.size.height - 14.0,
                ),
                font=@core.FontSpec::new(size=11.0),
                color=theme.palette.primary,
                align=@core.TextAlign::TextStart,
              ),
            ),
          )
          note_index = note_index + 1
        }
      _ => ()
    }
  }
}

///|
fn pdf_workbench_inspector(
  model : PdfWorkbenchModel,
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let rows : Array[@core.View[PdfWorkbenchMsg]] = []
  let item_width = pdf_workbench_panel_item_width(
    metrics.inspector_scroll_width,
    theme,
  )
  match model.document {
    Some(document) => {
      let matches = document.search_count(model.query)
      rows.push(
        pdf_workbench_inspector_summary(
          model, document, matches, item_width, theme,
        ),
      )
      rows.push(pdf_workbench_inspector_page_group(item_width, theme))
      rows.push(
        pdf_workbench_inspector_queue_group(document, item_width, theme),
      )
      rows.push(
        pdf_workbench_inspector_document_group(
          model, document, item_width, theme,
        ),
      )
      rows.push(
        pdf_workbench_inspector_diagnostics_group(document, item_width, theme),
      )
    }
    None =>
      rows.push(
        banner(
          "Skia PDF note",
          "Skia's PDF sample is for PDF output generation, not existing-page rasterization.",
          tone=@views.FeedbackTone::Info,
          theme~,
          width=item_width,
        ),
      )
  }
  surface(
    scroll_view(
      column(
        rows,
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Stretch,
      ),
      width=metrics.inspector_scroll_width,
      height=pdf_workbench_panel_scroll_height(metrics, theme),
      offset=model.inspector_scroll.offset(),
      state=Some(model.inspector_scroll),
    ),
    width=metrics.inspector_width,
    height=metrics.body_height,
    variant=@views.SurfaceVariant::Raised,
    theme~,
    padding=theme.spacing_scale.sm,
  )
}

///|
fn pdf_workbench_inspector_summary(
  model : PdfWorkbenchModel,
  document : PdfWorkbenchDocument,
  matches : Int,
  width : Double,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let zoom_label = pdf_workbench_zoom_label(model.zoom)
  let edit_tone = if document.dirty {
    @views.BadgeTone::Warning
  } else {
    @views.BadgeTone::Success
  }
  surface(
    column(
      [
        row(
          [
            status_badge(
              if document.dirty {
                "Unsaved"
              } else {
                "Saved"
              },
              tone=edit_tone,
              detail=if document.dirty {
                "Queued edits need save or discard"
              } else {
                "No queued edits"
              },
              theme~,
              width=78.0,
              height=24.0,
            ),
            badge(
              zoom_label,
              tone=@views.BadgeTone::Neutral,
              theme~,
              width=58.0,
              height=24.0,
            ),
            badge(
              pdf_workbench_search_badge_label(document, model.query),
              tone=if matches > 0 {
                @views.BadgeTone::Accent
              } else {
                @views.BadgeTone::Neutral
              },
              theme~,
              width=64.0,
              height=24.0,
            ),
          ],
          spacing=theme.spacing_scale.xs,
          align=@views.CrossAlign::Center,
        ),
        pdf_workbench_inspector_caption(
          "Page " +
          document.selected_page.to_string() +
          " of " +
          document.page_count.to_string() +
          " | " +
          pdf_workbench_raster_status_label(model.raster_status),
          width - 20.0,
          32.0,
          theme,
        ),
      ],
      spacing=theme.spacing_scale.xs,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    height=72.0,
    background=theme.palette.surface_variant.multiply_alpha(0.72),
    corner_radius=theme.radius_scale.sm,
    theme~,
    padding=theme.spacing_scale.sm,
  )
}

///|
fn pdf_workbench_inspector_page_group(
  width : Double,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let button_width = (width - theme.spacing_scale.sm) / 2.0
  pdf_workbench_inspector_group(
    "Page",
    [
      row(
        [
          button(
            "Rotate 90",
            on_click=RotateCurrentPage,
            variant=@views.ButtonVariant::Outline,
            theme~,
            width=button_width,
            height=34.0,
          ),
          button(
            "Crop",
            on_click=CropCurrentPage,
            variant=@views.ButtonVariant::Outline,
            theme~,
            width=button_width,
            height=34.0,
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Center,
      ),
      button(
        "Stamp",
        on_click=StampCurrentPage,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width~,
        height=34.0,
      ),
    ],
    width,
    theme,
  )
}

///|
fn pdf_workbench_inspector_document_group(
  model : PdfWorkbenchModel,
  document : PdfWorkbenchDocument,
  width : Double,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  pdf_workbench_inspector_group(
    "Document",
    [
      text_field(
        model.metadata_title_draft,
        on_input=value => MetadataTitleChanged(value),
        placeholder="Document title",
        variant=@views.TextFieldVariant::Outline,
        theme~,
        width~,
        height=34.0,
      ),
      button(
        "Apply Title",
        on_click=ApplyMetadataTitle,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width~,
        height=34.0,
      ),
      text_field(
        model.bookmark_title_draft,
        on_input=value => BookmarkTitleChanged(value),
        placeholder="Current page bookmark",
        variant=@views.TextFieldVariant::Outline,
        theme~,
        width~,
        height=34.0,
      ),
      button(
        "Add Bookmark",
        on_click=AddBookmarkForCurrentPage,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width~,
        height=34.0,
      ),
      text_field(
        model.annotation_text_draft,
        on_input=value => AnnotationTextChanged(value),
        placeholder="Current page note",
        variant=@views.TextFieldVariant::Outline,
        theme~,
        width~,
        height=34.0,
      ),
      button(
        "Add Note",
        on_click=AddAnnotationForCurrentPage,
        variant=@views.ButtonVariant::Outline,
        theme~,
        width~,
        height=34.0,
      ),
      pdf_workbench_inspector_caption(
        if document.writeback_available {
          "pdflite writeback ready"
        } else {
          "Save needs pdflite document service"
        },
        width,
        22.0,
        theme,
      ),
    ],
    width,
    theme,
  )
}

///|
fn pdf_workbench_inspector_queue_group(
  document : PdfWorkbenchDocument,
  width : Double,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let rows : Array[@core.View[PdfWorkbenchMsg]] = [
    row(
      [
        button(
          "Undo Last",
          on_click=UndoLastEdit,
          variant=@views.ButtonVariant::Ghost,
          theme~,
          width=(width - theme.spacing_scale.sm) / 2.0,
          height=34.0,
        ),
        button(
          "Discard Edits",
          on_click=DiscardEdits,
          variant=@views.ButtonVariant::Ghost,
          theme~,
          width=(width - theme.spacing_scale.sm) / 2.0,
          height=34.0,
        ),
      ],
      spacing=theme.spacing_scale.sm,
      align=@views.CrossAlign::Center,
    ),
  ]
  if document.edits.is_empty() {
    rows.push(
      pdf_workbench_inspector_caption("No queued edits", width, 24.0, theme),
    )
  } else {
    let mut index = 0
    for edit in document.edits {
      if index < 4 {
        rows.push(pdf_workbench_edit_queue_row(edit, index + 1, width, theme))
      }
      index = index + 1
    }
    if document.edits.length() > 4 {
      rows.push(
        pdf_workbench_inspector_caption(
          "+" + (document.edits.length() - 4).to_string() + " more queued",
          width,
          22.0,
          theme,
        ),
      )
    }
  }
  pdf_workbench_inspector_group("Queue", rows, width, theme)
}

///|
fn pdf_workbench_inspector_diagnostics_group(
  document : PdfWorkbenchDocument,
  width : Double,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let rows : Array[@core.View[PdfWorkbenchMsg]] = [
    pdf_workbench_inspector_caption(
      document.metadata_summary,
      width,
      36.0,
      theme,
    ),
    pdf_workbench_inspector_caption(
      document.outline_summary,
      width,
      36.0,
      theme,
    ),
    pdf_workbench_inspector_caption(
      document.annotation_summary,
      width,
      36.0,
      theme,
    ),
  ]
  let mut count = 0
  for entry in document.unsupported_entries {
    if count < 4 {
      rows.push(pdf_workbench_inspector_caption(entry, width, 44.0, theme))
    }
    count = count + 1
  }
  if document.unsupported_entries.length() > 4 {
    rows.push(
      pdf_workbench_inspector_caption(
        "+" +
        (document.unsupported_entries.length() - 4).to_string() +
        " more diagnostics",
        width,
        22.0,
        theme,
      ),
    )
  }
  pdf_workbench_inspector_group("Diagnostics", rows, width, theme)
}

///|
fn pdf_workbench_inspector_group(
  title : String,
  children : Array[@core.View[PdfWorkbenchMsg]],
  width : Double,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let rows : Array[@core.View[PdfWorkbenchMsg]] = [
    text(title, role=@views.TextRole::Control, theme~, width~, height=24.0),
  ]
  for child in children {
    rows.push(child)
  }
  surface(
    column(
      rows,
      spacing=theme.spacing_scale.xs,
      align=@views.CrossAlign::Stretch,
    ),
    width~,
    background=theme.palette.surface.multiply_alpha(0.96),
    corner_radius=theme.radius_scale.sm,
    theme~,
    padding=theme.spacing_scale.sm,
  )
}

///|
fn pdf_workbench_inspector_caption(
  value : String,
  width : Double,
  height : Double,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  text(value, role=@views.TextRole::Caption, theme~, width~, height~).foreground(
    theme.palette.muted,
  )
}

///|
fn pdf_workbench_edit_queue_row(
  edit : PdfWorkbenchEdit,
  index : Int,
  width : Double,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let label = index.to_string() + ". " + pdf_workbench_edit_queue_label(edit)
  surface(
    pdf_workbench_inspector_caption(label, width - 16.0, 30.0, theme),
    width~,
    height=38.0,
    background=theme.palette.surface_variant.multiply_alpha(0.58),
    corner_radius=theme.radius_scale.sm,
    theme~,
    padding=theme.spacing_scale.xs,
  )
}

///|
fn pdf_workbench_zoom_label(zoom : Double) -> String {
  pdf_workbench_zoom_bucket(zoom).to_string() + "%"
}

///|
fn pdf_workbench_edit_queue_label(edit : PdfWorkbenchEdit) -> String {
  match edit {
    RotatePage(page, degrees) => "Rotate page \{page} \{degrees} deg"
    CropPage(page, _) => "Crop page \{page}"
    StampText(page, value) => "Stamp page \{page}: " + value
    SetMetadataTitle(value) => "Set title: " + value
    AddBookmark(page, title) => "Bookmark page \{page}: " + title
    AddTextAnnotation(page, text) => "Note page \{page}: " + text
  }
}

///|
fn pdf_workbench_failure_banner(
  model : PdfWorkbenchModel,
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  match model.status {
    Failed(reason) =>
      row(
        [
          banner(
            "PDF Workbench needs attention",
            reason,
            tone=@views.FeedbackTone::Danger,
            theme~,
            width=(metrics.inner_width - 112.0 - theme.spacing_scale.sm).max(
              360.0,
            ),
          ),
          button(
            "Dismiss",
            on_click=ClearFailure,
            variant=@views.ButtonVariant::Outline,
            theme~,
            width=88.0,
            height=36.0,
          ),
        ],
        spacing=theme.spacing_scale.sm,
        align=@views.CrossAlign::Center,
      )
    _ => spacer(min_length=0.0)
  }
}

///|
fn pdf_workbench_status(
  model : PdfWorkbenchModel,
  metrics : PdfWorkbenchLayoutMetrics,
  theme : @core.Theme,
) -> @core.View[PdfWorkbenchMsg] {
  let status = match model.status {
    Empty => "Empty"
    Requesting(label) => "Requesting: " + label
    Pending(_, label) => "Pending: " + label
    Ready => "Ready"
    Failed(reason) => "Failed: " + reason
  }
  let document_status = match model.document {
    Some(document) =>
      pdf_workbench_file_name(document.path) +
      " | \{document.original_bytes.length()} byte(s) | page \{document.selected_page}/\{document.page_count}"
    None => "No document"
  }
  status_bar(
    [
      status,
      document_status,
      model.search_status_label(),
      pdf_workbench_raster_status_label(model.raster_status),
      model.last_event,
    ],
    theme~,
    width=metrics.inner_width,
  )
}

///|
fn PdfWorkbenchModel::search_status_label(self : PdfWorkbenchModel) -> String {
  match self.document {
    Some(document) => {
      let query = self.query.trim().to_owned()
      if query == "" {
        "Find: empty"
      } else {
        "Find: " + pdf_workbench_search_badge_label(document, self.query)
      }
    }
    None =>
      if self.query.trim().to_owned() == "" {
        "Find: empty"
      } else {
        "Find: no document"
      }
  }
}

///|
fn pdf_workbench_search_badge_label(
  document : PdfWorkbenchDocument,
  query : String,
) -> String {
  let matches = document.search_match_pages(query)
  if query.trim().to_owned() == "" {
    "No query"
  } else if matches.is_empty() {
    "0 hits"
  } else {
    match document.search_match_position(query, document.selected_page) {
      Some(position) =>
        position.to_string() + "/" + matches.length().to_string()
      None => {
        let suffix = if matches.length() == 1 { " hit" } else { " hits" }
        matches.length().to_string() + suffix
      }
    }
  }
}
