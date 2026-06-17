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
    }.request_open_path(path, services)
  }
}

///|
fn PdfWorkbenchModel::request_open_path(
  self : PdfWorkbenchModel,
  path : String,
  services : @host.HostAppServices,
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
        let response = services.read_binary_file(path)
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
        let read_request = @host.HostServiceRequest::BinaryFile(
          @host.HostBinaryFileRequest::ReadBytes(path),
        )
        let response = services.read_binary_file(path)
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
