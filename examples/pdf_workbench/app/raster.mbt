///|
pub(all) struct PdfWorkbenchRasterRequest {
  path : String
  bytes : Bytes
  page_number : Int
  zoom : Double
  dpi : Int
  max_pixel_edge : Int
  cache_key : String
}

///|
pub(all) struct PdfWorkbenchRasterPage {
  cache_key : String
  page_number : Int
  zoom : Double
  page_count : Int
  width_px : Int
  height_px : Int
  image_source : String
  diagnostic : String
} derive(Eq, Debug, ToJson)

///|
pub(all) enum PdfWorkbenchRasterResponse {
  RasterPageReady(PdfWorkbenchRasterPage)
  RasterPageUnavailable(String)
  RasterPageFailed(String)
} derive(Eq, Debug, ToJson)

///|
pub(all) enum PdfWorkbenchRasterStatus {
  RasterIdle
  RasterRendering(String)
  RasterReady
  RasterUnavailable(String)
  RasterFailed(String)
} derive(Eq, Debug, ToJson)

///|
pub struct PdfWorkbenchRasterServices {
  render : (PdfWorkbenchRasterRequest) -> PdfWorkbenchRasterResponse
}

///|
pub fn PdfWorkbenchRasterServices::new(
  render~ : (PdfWorkbenchRasterRequest) -> PdfWorkbenchRasterResponse,
) -> PdfWorkbenchRasterServices {
  { render, }
}

///|
pub fn PdfWorkbenchRasterServices::unavailable() -> PdfWorkbenchRasterServices {
  PdfWorkbenchRasterServices::new(render=_request => {
    RasterPageUnavailable("PDFium raster service unavailable")
  })
}

///|
pub fn PdfWorkbenchRasterServices::render_page(
  self : PdfWorkbenchRasterServices,
  request : PdfWorkbenchRasterRequest,
) -> PdfWorkbenchRasterResponse {
  (self.render)(request)
}

///|
fn PdfWorkbenchModel::request_current_raster(
  self : PdfWorkbenchModel,
  raster_services : PdfWorkbenchRasterServices,
) -> PdfWorkbenchUpdate {
  match self.document {
    Some(document) => {
      let request = self.raster_request(document)
      match self.lookup_raster_page(request.cache_key) {
        Some(page) =>
          PdfWorkbenchUpdate::new({
            ..self,
            raster_page: Some(page),
            raster_cache: pdf_workbench_raster_cache_mark_used(
              self.raster_cache,
              page,
            ),
            raster_status: RasterReady,
            last_event: "Raster cache hit for page " +
            page.page_number.to_string(),
          })
        None =>
          PdfWorkbenchUpdate::new(
            {
              ..self,
              raster_page: None,
              raster_status: RasterRendering(
                "Rendering page " + document.selected_page.to_string(),
              ),
              last_event: "Rendering page " + document.selected_page.to_string(),
            },
            effect=@moui.Effect::host_service(
              key="pdf-workbench:raster:" + request.cache_key,
              label="Render PDF page",
              run=dispatch => {
                let response = raster_services.render_page(request)
                dispatch(RasterCompleted(request, response))
              },
            ),
          )
      }
    }
    None => PdfWorkbenchUpdate::new(self)
  }
}

///|
fn PdfWorkbenchModel::apply_raster_completion(
  self : PdfWorkbenchModel,
  request : PdfWorkbenchRasterRequest,
  response : PdfWorkbenchRasterResponse,
) -> PdfWorkbenchModel {
  if self.current_raster_cache_key() != Some(request.cache_key) {
    return self
  }
  match response {
    RasterPageReady(page) => {
      let cache = self.raster_cache.copy()
      pdf_workbench_raster_cache_store(cache, page)
      let document = match self.document {
        Some(document) =>
          Some(document.with_page_count_from_raster(page.page_count))
        None => None
      }
      {
        ..self,
        document,
        raster_page: Some(page),
        raster_cache: cache,
        raster_status: RasterReady,
        status: Ready,
        last_event: "Rendered page " +
        page.page_number.to_string() +
        " as " +
        page.width_px.to_string() +
        "x" +
        page.height_px.to_string() +
        " bitmap",
      }
    }
    RasterPageUnavailable(reason) =>
      {
        ..self,
        raster_page: None,
        raster_status: RasterUnavailable(reason),
        status: Ready,
        last_event: "Raster unavailable: " + reason,
      }
    RasterPageFailed(reason) =>
      {
        ..self,
        raster_page: None,
        raster_status: RasterFailed(reason),
        status: Ready,
        last_event: "Raster failed: " + reason,
      }
  }
}

///|
fn PdfWorkbenchModel::raster_request(
  self : PdfWorkbenchModel,
  document : PdfWorkbenchDocument,
) -> PdfWorkbenchRasterRequest {
  let cache_key = pdf_workbench_raster_cache_key(
    document,
    page_number=document.selected_page,
    zoom=self.zoom,
  )
  {
    path: document.path,
    bytes: document.original_bytes,
    page_number: document.selected_page,
    zoom: self.zoom,
    dpi: 144,
    max_pixel_edge: 4096,
    cache_key,
  }
}

///|
fn PdfWorkbenchModel::lookup_raster_page(
  self : PdfWorkbenchModel,
  cache_key : String,
) -> PdfWorkbenchRasterPage? {
  pdf_workbench_raster_cache_lookup(self.raster_cache, cache_key)
}

///|
fn PdfWorkbenchModel::current_raster_cache_key(
  self : PdfWorkbenchModel,
) -> String? {
  match self.document {
    Some(document) =>
      Some(
        pdf_workbench_raster_cache_key(
          document,
          page_number=document.selected_page,
          zoom=self.zoom,
        ),
      )
    None => None
  }
}

///|
fn pdf_workbench_raster_cache_key(
  document : PdfWorkbenchDocument,
  page_number~ : Int,
  zoom~ : Double,
) -> String {
  pdf_workbench_document_key(document) +
  ":page=" +
  page_number.to_string() +
  ":zoom=" +
  pdf_workbench_zoom_bucket(zoom).to_string()
}

///|
fn pdf_workbench_document_key(document : PdfWorkbenchDocument) -> String {
  pdf_workbench_sanitize_cache_segment(pdf_workbench_file_name(document.path)) +
  "-" +
  document.original_bytes.length().to_string() +
  "-" +
  pdf_workbench_string_hash(document.path).to_string()
}

///|
fn pdf_workbench_zoom_bucket(zoom : Double) -> Int {
  let bucket = (zoom * 100.0).to_int()
  if bucket < 1 {
    1
  } else {
    bucket
  }
}

///|
fn pdf_workbench_max_raster_cache_entries() -> Int {
  12
}

///|
fn pdf_workbench_raster_cache_lookup(
  cache : Array[PdfWorkbenchRasterPage],
  cache_key : String,
) -> PdfWorkbenchRasterPage? {
  for page in cache {
    if page.cache_key == cache_key {
      return Some(page)
    }
  }
  None
}

///|
fn pdf_workbench_raster_cache_store(
  cache : Array[PdfWorkbenchRasterPage],
  page : PdfWorkbenchRasterPage,
) -> Unit {
  let filtered = cache.filter(existing => existing.cache_key != page.cache_key)
  cache.clear()
  for existing in filtered {
    cache.push(existing)
  }
  cache.push(page)
  pdf_workbench_raster_cache_trim(cache)
}

///|
fn pdf_workbench_raster_cache_mark_used(
  cache : Array[PdfWorkbenchRasterPage],
  page : PdfWorkbenchRasterPage,
) -> Array[PdfWorkbenchRasterPage] {
  let next = cache.copy()
  pdf_workbench_raster_cache_store(next, page)
  next
}

///|
fn pdf_workbench_raster_cache_trim(
  cache : Array[PdfWorkbenchRasterPage],
) -> Unit {
  let max_entries = pdf_workbench_max_raster_cache_entries()
  while cache.length() > max_entries {
    ignore(cache.remove(0))
  }
}

///|
fn pdf_workbench_sanitize_cache_segment(value : String) -> String {
  let chars = value.to_array()
  let output : Array[Char] = []
  for ch in chars {
    if (ch >= 'a' && ch <= 'z') ||
      (ch >= 'A' && ch <= 'Z') ||
      (ch >= '0' && ch <= '9') ||
      ch == '-' ||
      ch == '_' {
      output.push(ch)
    } else {
      output.push('_')
    }
  }
  let result = String::from_array(output).trim().to_owned()
  if result == "" {
    "document"
  } else {
    result
  }
}

///|
fn pdf_workbench_string_hash(value : String) -> Int {
  let mut hash = 5381
  for ch in value.to_array() {
    hash = hash * 33 + ch.to_int()
  }
  if hash < 0 {
    -hash
  } else {
    hash
  }
}

///|
fn pdf_workbench_raster_status_label(
  status : PdfWorkbenchRasterStatus,
) -> String {
  match status {
    RasterIdle => "Raster: idle"
    RasterRendering(label) => "Raster: " + label
    RasterReady => "Raster: PDFium bitmap ready"
    RasterUnavailable(reason) => "Raster unavailable: " + reason
    RasterFailed(reason) => "Raster failed: " + reason
  }
}
