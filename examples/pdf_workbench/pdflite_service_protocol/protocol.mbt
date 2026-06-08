///|
pub(all) enum PdfWorkbenchPdfliteServiceRequest {
  LoadDocument(String, Bytes)
  WritebackDocument(String, Bytes, Array[@app.PdfWorkbenchEdit])
} derive(Eq, Debug)

///|
pub(all) enum PdfWorkbenchPdfliteServiceResponse {
  DocumentLoaded(@app.PdfWorkbenchDocument)
  WritebackReady(Bytes, Array[String])
  ServiceFailed(String)
}

///|
pub struct PdfWorkbenchPdfliteServiceHandler {
  handle : (PdfWorkbenchPdfliteServiceRequest) -> PdfWorkbenchPdfliteServiceResponse
}

///|
pub fn PdfWorkbenchPdfliteServiceHandler::new(
  handle~ : (PdfWorkbenchPdfliteServiceRequest) -> PdfWorkbenchPdfliteServiceResponse,
) -> PdfWorkbenchPdfliteServiceHandler {
  { handle, }
}

///|
pub fn PdfWorkbenchPdfliteServiceHandler::handle_request(
  self : PdfWorkbenchPdfliteServiceHandler,
  request : PdfWorkbenchPdfliteServiceRequest,
) -> PdfWorkbenchPdfliteServiceResponse {
  (self.handle)(request)
}

///|
pub fn PdfWorkbenchPdfliteServiceHandler::document_services(
  self : PdfWorkbenchPdfliteServiceHandler,
) -> @app.PdfWorkbenchDocumentServices {
  @app.PdfWorkbenchDocumentServices::new(
    load=(path, bytes) => {
      match self.handle_request(LoadDocument(path, bytes)) {
        DocumentLoaded(document) =>
          @app.PdfWorkbenchLoadResult::Loaded(document)
        ServiceFailed(reason) => @app.PdfWorkbenchLoadResult::Failed(reason)
        WritebackReady(_, _) =>
          @app.PdfWorkbenchLoadResult::Failed(
            "pdflite service returned writeback response while loading",
          )
      }
    },
    writeback=document => {
      match
        self.handle_request(
          WritebackDocument(
            document.path,
            document.original_bytes,
            document.edits,
          ),
        ) {
        WritebackReady(bytes, diagnostics) =>
          @app.PdfWorkbenchDocumentWritebackResult::WritebackReady(
            bytes, diagnostics,
          )
        ServiceFailed(reason) =>
          @app.PdfWorkbenchDocumentWritebackResult::WritebackFailed(reason)
        DocumentLoaded(_) =>
          @app.PdfWorkbenchDocumentWritebackResult::WritebackFailed(
            "pdflite service returned load response while writing",
          )
      }
    },
  )
}

///|
pub fn PdfWorkbenchPdfliteServiceRequest::to_json_line(
  self : PdfWorkbenchPdfliteServiceRequest,
) -> String {
  match self {
    LoadDocument(path, bytes) =>
      (
        {
          "type": "load",
          "path": path,
          "bytesBase64": pdf_workbench_pdflite_protocol_encode_bytes(bytes),
          "byteLength": bytes.length(),
        } : Json).stringify()
    WritebackDocument(path, bytes, edits) =>
      (
        {
          "type": "writeback",
          "path": path,
          "bytesBase64": pdf_workbench_pdflite_protocol_encode_bytes(bytes),
          "byteLength": bytes.length(),
          "edits": edits.map(edit => edit.to_json()),
        } : Json).stringify()
  }
}

///|
pub fn PdfWorkbenchPdfliteServiceRequest::from_json_line(
  line : String,
) -> PdfWorkbenchPdfliteServiceRequest? {
  let parsed = @json.parse(line) catch { _ => return None }
  guard parsed is Json::Object(fields) else { return None }
  guard pdf_workbench_pdflite_json_string(fields, "type") is Some(kind) else {
    return None
  }
  guard pdf_workbench_pdflite_json_string(fields, "path") is Some(path) else {
    return None
  }
  guard pdf_workbench_pdflite_json_string(fields, "bytesBase64")
    is Some(encoded) else {
    return None
  }
  guard pdf_workbench_pdflite_protocol_decode_bytes(encoded) is Some(bytes) else {
    return None
  }
  match kind {
    "load" => Some(LoadDocument(path, bytes))
    "writeback" => {
      guard pdf_workbench_pdflite_json_edits(fields) is Some(edits) else {
        return None
      }
      Some(WritebackDocument(path, bytes, edits))
    }
    _ => None
  }
}

///|
pub fn PdfWorkbenchPdfliteServiceResponse::to_json_line(
  self : PdfWorkbenchPdfliteServiceResponse,
) -> String {
  match self {
    DocumentLoaded(document) =>
      (
        {
          "type": "loaded",
          "path": document.path,
          "byteLength": document.original_bytes.length(),
          "pageCount": document.page_count,
          "selectedPage": document.selected_page,
          "extractedText": document.extracted_text,
          "metadataSummary": document.metadata_summary,
          "metadataTitle": document.metadata_title,
          "outlineSummary": document.outline_summary,
          "annotationSummary": document.annotation_summary,
          "writebackAvailable": document.writeback_available,
          "unsupportedEntries": document.unsupported_entries,
          "pageSummaries": document.page_summaries.map(
            pdf_workbench_pdflite_page_summary_json,
          ),
          "diagnostic": "pdflite document loaded",
        } : Json).stringify()
    WritebackReady(bytes, diagnostics) =>
      (
        {
          "type": "writeback_ready",
          "bytesBase64": pdf_workbench_pdflite_protocol_encode_bytes(bytes),
          "byteLength": bytes.length(),
          "diagnostics": diagnostics,
        } : Json).stringify()
    ServiceFailed(reason) =>
      ({ "type": "failed", "reason": reason } : Json).stringify()
  }
}

///|
pub fn PdfWorkbenchPdfliteServiceResponse::from_json_line(
  line : String,
  original_bytes~ : Bytes,
) -> PdfWorkbenchPdfliteServiceResponse? {
  let parsed = @json.parse(line) catch { _ => return None }
  guard parsed is Json::Object(fields) else { return None }
  guard pdf_workbench_pdflite_json_string(fields, "type") is Some(kind) else {
    return None
  }
  match kind {
    "loaded" => pdf_workbench_pdflite_loaded_response(fields, original_bytes~)
    "writeback_ready" => {
      guard pdf_workbench_pdflite_json_string(fields, "bytesBase64")
        is Some(encoded) else {
        return None
      }
      guard pdf_workbench_pdflite_protocol_decode_bytes(encoded) is Some(bytes) else {
        return None
      }
      guard pdf_workbench_pdflite_json_string_array(fields, "diagnostics")
        is Some(diagnostics) else {
        return None
      }
      Some(WritebackReady(bytes, diagnostics))
    }
    "failed" =>
      match pdf_workbench_pdflite_json_string(fields, "reason") {
        Some(reason) => Some(ServiceFailed(reason))
        None => None
      }
    _ => None
  }
}

///|
fn pdf_workbench_pdflite_loaded_response(
  fields : Map[String, Json],
  original_bytes~ : Bytes,
) -> PdfWorkbenchPdfliteServiceResponse? {
  guard pdf_workbench_pdflite_json_string(fields, "path") is Some(path) else {
    return None
  }
  guard pdf_workbench_pdflite_json_int(fields, "pageCount") is Some(page_count) else {
    return None
  }
  guard pdf_workbench_pdflite_json_int(fields, "selectedPage")
    is Some(selected_page) else {
    return None
  }
  guard pdf_workbench_pdflite_json_bool(fields, "writebackAvailable")
    is Some(writeback_available) else {
    return None
  }
  guard pdf_workbench_pdflite_json_string_array(fields, "unsupportedEntries")
    is Some(unsupported_entries) else {
    return None
  }
  guard pdf_workbench_pdflite_json_page_summaries(fields)
    is Some(page_summaries) else {
    return None
  }
  let extracted_text = pdf_workbench_pdflite_json_string_or(
    fields,
    "extractedText",
    default="",
  )
  let metadata_summary = pdf_workbench_pdflite_json_string_or(
    fields,
    "metadataSummary",
    default="",
  )
  let metadata_title = pdf_workbench_pdflite_json_string_or(
    fields,
    "metadataTitle",
    default="",
  )
  let outline_summary = pdf_workbench_pdflite_json_string_or(
    fields,
    "outlineSummary",
    default="",
  )
  let annotation_summary = pdf_workbench_pdflite_json_string_or(
    fields,
    "annotationSummary",
    default="",
  )
  match
    @app.PdfWorkbenchDocument::from_engine_summary(
      path~,
      original_bytes~,
      page_count~,
      selected_page~,
      extracted_text~,
      dirty=false,
      writeback_available~,
      edits=[],
      unsupported_entries~,
      page_summaries~,
      metadata_summary~,
      metadata_title~,
      outline_summary~,
      annotation_summary~,
    ) {
    @app.PdfWorkbenchLoadResult::Loaded(document) =>
      Some(DocumentLoaded(document))
    @app.PdfWorkbenchLoadResult::Failed(reason) => Some(ServiceFailed(reason))
  }
}

///|
fn pdf_workbench_pdflite_page_summary_json(
  summary : @app.PdfWorkbenchPageSummary,
) -> Json {
  (
    {
      "pageNumber": summary.page_number,
      "textPreview": summary.text_preview,
      "contentDiagnostic": summary.content_diagnostic,
    } : Json)
}

///|
pub fn pdf_workbench_pdflite_protocol_encode_bytes(bytes : Bytes) -> String {
  @base64.encode(bytes[:])
}

///|
pub fn pdf_workbench_pdflite_protocol_decode_bytes(value : String) -> Bytes? {
  Some(@base64.decode(value)) catch {
    _ => None
  }
}

///|
fn pdf_workbench_pdflite_json_string(
  fields : Map[String, Json],
  key : String,
) -> String? {
  match fields.get(key) {
    Some(Json::String(value)) => Some(value)
    _ => None
  }
}

///|
fn pdf_workbench_pdflite_json_string_or(
  fields : Map[String, Json],
  key : String,
  default~ : String,
) -> String {
  match pdf_workbench_pdflite_json_string(fields, key) {
    Some(value) => value
    None => default
  }
}

///|
fn pdf_workbench_pdflite_json_int(
  fields : Map[String, Json],
  key : String,
) -> Int? {
  match fields.get(key) {
    Some(value) => pdf_workbench_pdflite_json_value_int(value)
    None => None
  }
}

///|
fn pdf_workbench_pdflite_json_bool(
  fields : Map[String, Json],
  key : String,
) -> Bool? {
  match fields.get(key) {
    Some(Json::True) => Some(true)
    Some(Json::False) => Some(false)
    _ => None
  }
}

///|
fn pdf_workbench_pdflite_json_string_array(
  fields : Map[String, Json],
  key : String,
) -> Array[String]? {
  match fields.get(key) {
    None => Some([])
    Some(Json::Array(values)) => {
      let strings : Array[String] = []
      for value in values {
        guard pdf_workbench_pdflite_json_value_string(value) is Some(text) else {
          return None
        }
        strings.push(text)
      }
      Some(strings)
    }
    _ => None
  }
}

///|
fn pdf_workbench_pdflite_json_page_summaries(
  fields : Map[String, Json],
) -> Array[@app.PdfWorkbenchPageSummary]? {
  match fields.get("pageSummaries") {
    None => Some([])
    Some(Json::Array(values)) => {
      let summaries : Array[@app.PdfWorkbenchPageSummary] = []
      for value in values {
        guard pdf_workbench_pdflite_json_page_summary(value) is Some(summary) else {
          return None
        }
        summaries.push(summary)
      }
      Some(summaries)
    }
    _ => None
  }
}

///|
fn pdf_workbench_pdflite_json_page_summary(
  value : Json,
) -> @app.PdfWorkbenchPageSummary? {
  guard value is Json::Object(fields) else { return None }
  guard pdf_workbench_pdflite_json_int(fields, "pageNumber")
    is Some(page_number) else {
    return None
  }
  guard pdf_workbench_pdflite_json_string(fields, "textPreview")
    is Some(text_preview) else {
    return None
  }
  guard pdf_workbench_pdflite_json_string(fields, "contentDiagnostic")
    is Some(content_diagnostic) else {
    return None
  }
  Some({ page_number, text_preview, content_diagnostic })
}

///|
fn pdf_workbench_pdflite_json_edits(
  fields : Map[String, Json],
) -> Array[@app.PdfWorkbenchEdit]? {
  match fields.get("edits") {
    Some(Json::Array(values)) => {
      let edits : Array[@app.PdfWorkbenchEdit] = []
      for value in values {
        guard pdf_workbench_pdflite_json_edit(value) is Some(edit) else {
          return None
        }
        edits.push(edit)
      }
      Some(edits)
    }
    _ => Some([])
  }
}

///|
fn pdf_workbench_pdflite_json_edit(value : Json) -> @app.PdfWorkbenchEdit? {
  guard value is Json::Array(items) else { return None }
  guard items.length() > 0 else { return None }
  guard pdf_workbench_pdflite_json_value_string(items[0]) is Some(kind) else {
    return None
  }
  match kind {
    "RotatePage" =>
      if items.length() == 3 {
        match
          (
            pdf_workbench_pdflite_json_value_int(items[1]),
            pdf_workbench_pdflite_json_value_int(items[2]),
          ) {
          (Some(page), Some(rotation)) =>
            Some(@app.PdfWorkbenchEdit::RotatePage(page, rotation))
          _ => None
        }
      } else {
        None
      }
    "CropPage" =>
      if items.length() == 3 {
        match
          (
            pdf_workbench_pdflite_json_value_int(items[1]),
            pdf_workbench_pdflite_json_crop_box(items[2]),
          ) {
          (Some(page), Some(box)) =>
            Some(@app.PdfWorkbenchEdit::CropPage(page, box))
          _ => None
        }
      } else {
        None
      }
    "StampText" =>
      if items.length() == 3 {
        match
          (
            pdf_workbench_pdflite_json_value_int(items[1]),
            pdf_workbench_pdflite_json_value_string(items[2]),
          ) {
          (Some(page), Some(text)) =>
            Some(@app.PdfWorkbenchEdit::StampText(page, text))
          _ => None
        }
      } else {
        None
      }
    "SetMetadataTitle" =>
      if items.length() == 2 {
        match pdf_workbench_pdflite_json_value_string(items[1]) {
          Some(title) => Some(@app.PdfWorkbenchEdit::SetMetadataTitle(title))
          None => None
        }
      } else {
        None
      }
    "AddBookmark" =>
      if items.length() == 3 {
        match
          (
            pdf_workbench_pdflite_json_value_int(items[1]),
            pdf_workbench_pdflite_json_value_string(items[2]),
          ) {
          (Some(page), Some(title)) =>
            Some(@app.PdfWorkbenchEdit::AddBookmark(page, title))
          _ => None
        }
      } else {
        None
      }
    "AddTextAnnotation" =>
      if items.length() == 3 {
        match
          (
            pdf_workbench_pdflite_json_value_int(items[1]),
            pdf_workbench_pdflite_json_value_string(items[2]),
          ) {
          (Some(page), Some(text)) =>
            Some(@app.PdfWorkbenchEdit::AddTextAnnotation(page, text))
          _ => None
        }
      } else {
        None
      }
    _ => None
  }
}

///|
fn pdf_workbench_pdflite_json_crop_box(
  value : Json,
) -> @app.PdfWorkbenchCropBox? {
  guard value is Json::Object(fields) else { return None }
  match
    (
      pdf_workbench_pdflite_json_double(fields, "left"),
      pdf_workbench_pdflite_json_double(fields, "bottom"),
      pdf_workbench_pdflite_json_double(fields, "right"),
      pdf_workbench_pdflite_json_double(fields, "top"),
    ) {
    (Some(left), Some(bottom), Some(right), Some(top)) =>
      Some({ left, bottom, right, top })
    _ => None
  }
}

///|
fn pdf_workbench_pdflite_json_double(
  fields : Map[String, Json],
  key : String,
) -> Double? {
  match fields.get(key) {
    Some(value) => pdf_workbench_pdflite_json_value_double(value)
    None => None
  }
}

///|
fn pdf_workbench_pdflite_json_value_string(value : Json) -> String? {
  match value {
    Json::String(text) => Some(text)
    _ => None
  }
}

///|
fn pdf_workbench_pdflite_json_value_int(value : Json) -> Int? {
  match pdf_workbench_pdflite_json_value_double(value) {
    Some(number) => Some(number.to_int())
    None => None
  }
}

///|
fn pdf_workbench_pdflite_json_value_double(value : Json) -> Double? {
  match value {
    Json::Number(number, repr=_) => Some(number)
    _ => None
  }
}
