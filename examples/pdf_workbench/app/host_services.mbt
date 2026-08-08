///|
fn PdfWorkbenchModel::request_startup_pdf(
  self : PdfWorkbenchModel,
  startup_pdf_path : String,
  startup_page_number : Int,
  services : @services.AppServices,
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
    }.request_open_path(path, services)
  }
}

///|
fn PdfWorkbenchModel::request_open_path(
  self : PdfWorkbenchModel,
  path : String,
  services : @services.AppServices,
) -> PdfWorkbenchUpdate {
  PdfWorkbenchUpdate::new(
    {
      ..self,
      status: Requesting("Opening PDF"),
      pending_operation: Some(ReadPdf(path)),
      last_event: "Opening " + pdf_workbench_file_name(path),
    },
    effect=services
      .files()
      .read_bytes(path)
      .effect(map=result => PdfBytesRead(path, result)),
  )
}

///|
fn PdfWorkbenchModel::request_open(
  self : PdfWorkbenchModel,
  services : @services.AppServices,
) -> PdfWorkbenchUpdate {
  PdfWorkbenchUpdate::new(
    {
      ..self,
      status: Requesting("Opening PDF"),
      pending_operation: Some(PickOpenFile),
      last_event: "Waiting for file picker",
      startup_page_after_load: None,
    },
    effect=services
      .files()
      .open_file(
        options=@services.FileDialogOptions::new(title="Open PDF", filters=[
          "pdf",
        ]),
      )
      .effect(map=result => OpenFilePicked(result)),
  )
}

///|
fn PdfWorkbenchModel::request_save(
  self : PdfWorkbenchModel,
  services : @services.AppServices,
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
  services : @services.AppServices,
  default_name~ : String,
) -> PdfWorkbenchUpdate {
  PdfWorkbenchUpdate::new(
    {
      ..self,
      status: Requesting("Choosing save location"),
      pending_operation: Some(PickSaveFile),
      last_event: "Waiting for save dialog",
    },
    effect=services
      .files()
      .save_file(
        options=@services.FileDialogOptions::new(
          title="Save PDF",
          default_name=Some(default_name),
          filters=["pdf"],
        ),
      )
      .effect(map=result => SaveFilePicked(result)),
  )
}

///|
fn PdfWorkbenchModel::request_binary_write(
  self : PdfWorkbenchModel,
  path : String,
  document : PdfWorkbenchDocument,
  _services : @services.AppServices,
  document_services : PdfWorkbenchDocumentServices,
) -> PdfWorkbenchUpdate {
  PdfWorkbenchUpdate::new(
    {
      ..self,
      status: Requesting("Preparing PDF bytes"),
      pending_operation: Some(PrepareSave(path)),
      last_event: "Preparing PDF writeback for " + path,
    },
    effect=@moui.Effect::run(
      key="pdf-workbench:prepare-save",
      kind="pdf-document-service",
      label="Prepare PDF bytes",
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
        dispatch(SaveBytesPrepared(path, bytes, diagnostics))
      },
    ),
  )
}

///|
fn PdfWorkbenchModel::apply_open_file_pick(
  self : PdfWorkbenchModel,
  result : @services.ServiceTaskResult[String],
  services : @services.AppServices,
) -> PdfWorkbenchUpdate {
  if self.pending_operation != Some(PickOpenFile) {
    return PdfWorkbenchUpdate::new(self)
  }
  match result {
    Success(path) =>
      { ..self, pending_operation: None }.request_open_path(path, services)
    Failure(error) =>
      PdfWorkbenchUpdate::new({
        ..self,
        pending_operation: None,
        status: Failed("File dialog failed: " + error.message),
        last_event: "Open file dialog failed",
      })
    Cancelled =>
      PdfWorkbenchUpdate::new({
        ..self,
        pending_operation: None,
        status: Ready,
        last_event: "No file selected",
      })
  }
}

///|
fn PdfWorkbenchModel::apply_pdf_bytes_read(
  self : PdfWorkbenchModel,
  path : String,
  result : @services.ServiceTaskResult[Bytes],
  raster_services : PdfWorkbenchRasterServices,
  document_services : PdfWorkbenchDocumentServices,
) -> PdfWorkbenchUpdate {
  if self.pending_operation != Some(ReadPdf(path)) {
    return PdfWorkbenchUpdate::new(self)
  }
  let model = { ..self, pending_operation: None }
  match result {
    Success(bytes) =>
      model
      .apply_pdf_bytes(path, bytes, document_services)
      .request_current_raster(raster_services)
    Failure(error) =>
      PdfWorkbenchUpdate::new({
        ..model,
        status: Failed(
          "Read failed for " +
          pdf_workbench_file_name(path) +
          ": " +
          error.message,
        ),
        last_event: "PDF read failed",
      })
    Cancelled =>
      PdfWorkbenchUpdate::new({
        ..model,
        status: Failed("Read cancelled for " + pdf_workbench_file_name(path)),
        last_event: "PDF read cancelled",
      })
  }
}

///|
fn PdfWorkbenchModel::apply_save_file_pick(
  self : PdfWorkbenchModel,
  result : @services.ServiceTaskResult[String],
  services : @services.AppServices,
  document_services : PdfWorkbenchDocumentServices,
) -> PdfWorkbenchUpdate {
  if self.pending_operation != Some(PickSaveFile) {
    return PdfWorkbenchUpdate::new(self)
  }
  match result {
    Success(path) =>
      match self.document {
        Some(document) =>
          { ..self, pending_operation: None }.request_binary_write(
            path, document, services, document_services,
          )
        None =>
          PdfWorkbenchUpdate::new({
            ..self,
            pending_operation: None,
            status: Failed("open a PDF before saving"),
            last_event: "Save unavailable",
          })
      }
    Failure(error) =>
      PdfWorkbenchUpdate::new({
        ..self,
        pending_operation: None,
        status: Failed("File dialog failed: " + error.message),
        last_event: "Save dialog failed",
      })
    Cancelled =>
      PdfWorkbenchUpdate::new({
        ..self,
        pending_operation: None,
        status: Ready,
        last_event: "No file selected",
      })
  }
}

///|
fn PdfWorkbenchModel::request_binary_write_task(
  self : PdfWorkbenchModel,
  path : String,
  bytes : Bytes,
  diagnostics : Array[String],
  services : @services.AppServices,
) -> PdfWorkbenchUpdate {
  if self.pending_operation != Some(PrepareSave(path)) {
    return PdfWorkbenchUpdate::new(self)
  }
  PdfWorkbenchUpdate::new(
    {
      ..self,
      pending_operation: Some(WritePdf(path)),
      status: Requesting("Writing PDF bytes"),
      last_event: "Writing PDF bytes to " + path,
    },
    effect=services
      .files()
      .write_bytes(path, bytes)
      .effect(map=result => PdfBytesWritten(path, bytes, diagnostics, result)),
  )
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
        preview_scroll_offset: @geometry.Point::new(x=0.0, y=0.0),
        sidebar_scroll: @geometry.Point::new(x=0.0, y=0.0),
        inspector_scroll: @geometry.Point::new(x=0.0, y=0.0),
        query: "",
        status: Ready,
        last_event: "Loaded " +
        pdf_workbench_file_name(path) +
        " (\{bytes.length()} byte(s), \{document.page_count} page(s))",
      }
    }
    Failed(reason) =>
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
  result : @services.ServiceTaskResult[Unit],
  document_services : PdfWorkbenchDocumentServices,
) -> PdfWorkbenchModel {
  if self.pending_operation != Some(WritePdf(path)) {
    return self
  }
  let model = { ..self, pending_operation: None }
  match result {
    Success(_) =>
      model.mark_saved_from_written_bytes(
        path, bytes, diagnostics, document_services,
      )
    Failure(error) =>
      {
        ..model,
        status: Failed(
          "Binary PDF write unavailable while saving " +
          pdf_workbench_file_name(path) +
          ": " +
          error.message,
        ),
        last_event: "Save unavailable",
      }
    Cancelled =>
      {
        ..model,
        status: Failed("PDF write cancelled while saving " + path),
        last_event: "Save cancelled",
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
