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
  sidebar_scroll : @state.ScrollState
  inspector_scroll : @state.ScrollState
  preview_scroll_offset : @geometry.Point
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
  effect : @moui.Effect[PdfWorkbenchMsg]
}

///|
pub enum PdfWorkbenchMsg {
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
  PreviewScrolled(@geometry.Point)
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
    sidebar_scroll: @state.ScrollState::new(),
    inspector_scroll: @state.ScrollState::new(),
    preview_scroll_offset: @geometry.Point::new(x=0.0, y=0.0),
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
  effect? : @moui.Effect[PdfWorkbenchMsg] = @moui.Effect::none(),
) -> PdfWorkbenchUpdate {
  { model, effect }
}

///|
fn PdfWorkbenchUpdate::as_tuple(
  self : PdfWorkbenchUpdate,
) -> (PdfWorkbenchModel, @moui.Effect[PdfWorkbenchMsg]) {
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
) -> @moui.Subscription[PdfWorkbenchMsg] {
  match self.status {
    Pending(id, label) =>
      services.completion_subscription(
        id,
        map=completion => HostCompleted(completion),
        label~,
      )
    _ => @moui.Subscription::none()
  }
}

///|
pub fn PdfWorkbenchApp::program(
  self : PdfWorkbenchApp,
) -> @moui.Program[PdfWorkbenchModel, PdfWorkbenchMsg] {
  ignore(self)
  PdfWorkbenchModel::new().program()
}

///|
pub fn PdfWorkbenchApp::program_with_services(
  self : PdfWorkbenchApp,
  services : @host.HostAppServices,
  raster_services? : PdfWorkbenchRasterServices = PdfWorkbenchRasterServices::unavailable(),
  document_services? : PdfWorkbenchDocumentServices = PdfWorkbenchDocumentServices::lightweight(),
  startup_pdf_path? : String = "",
  startup_page_number? : Int = 1,
) -> @moui.Program[PdfWorkbenchModel, PdfWorkbenchMsg] {
  ignore(self)
  PdfWorkbenchModel::new().program_with_services(
    services,
    raster_services~,
    document_services~,
    startup_pdf_path~,
    startup_page_number~,
  )
}

///|
pub fn PdfWorkbenchModel::program(
  self : PdfWorkbenchModel,
) -> @moui.Program[PdfWorkbenchModel, PdfWorkbenchMsg] {
  self.program_with_services(@host.HostAppServices::unavailable())
}

///|
pub fn PdfWorkbenchModel::program_with_services(
  self : PdfWorkbenchModel,
  services : @host.HostAppServices,
  raster_services? : PdfWorkbenchRasterServices = PdfWorkbenchRasterServices::unavailable(),
  document_services? : PdfWorkbenchDocumentServices = PdfWorkbenchDocumentServices::lightweight(),
  startup_pdf_path? : String = "",
  startup_page_number? : Int = 1,
) -> @moui.Program[PdfWorkbenchModel, PdfWorkbenchMsg] {
  @moui.Program::new_with_environment(
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
  )
}

///|
pub fn program() -> @moui.Program[PdfWorkbenchModel, PdfWorkbenchMsg] {
  PdfWorkbenchModel::new().program()
}
