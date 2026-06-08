///|
#borrow(path, pdf_bytes, cache_key)
extern "C" fn pdfium_render_page_raw(
  path : Bytes,
  pdf_bytes : Bytes,
  page_number : Int,
  zoom : Double,
  dpi : Int,
  max_pixel_edge : Int,
  cache_key : Bytes,
) -> Bytes = "moui_pdf_workbench_pdfium_render_page"

///|
extern "C" fn pdfium_available_raw() -> Int = "moui_pdf_workbench_pdfium_available"

///|
pub fn pdfium_available() -> Bool {
  pdfium_available_raw() != 0
}

///|
pub fn raster_services() -> @app.PdfWorkbenchRasterServices {
  @app.PdfWorkbenchRasterServices::new(render=request => render_page(request))
}

///|
pub fn render_page(
  request : @app.PdfWorkbenchRasterRequest,
) -> @app.PdfWorkbenchRasterResponse {
  let raw = pdfium_render_page_raw(
    pdfium_encode_string(request.path),
    request.bytes,
    request.page_number,
    request.zoom,
    request.dpi,
    request.max_pixel_edge,
    pdfium_encode_string(request.cache_key),
  )
  pdfium_decode_response(raw, request)
}

///|
fn pdfium_decode_response(
  raw : Bytes,
  request : @app.PdfWorkbenchRasterRequest,
) -> @app.PdfWorkbenchRasterResponse {
  let text = @utf8.decode_lossy(raw[:], ignore_bom=false)
  let lines : Array[String] = []
  for line in text.split("\n") {
    lines.push(line.trim().to_owned())
  }
  if lines.is_empty() {
    return @app.PdfWorkbenchRasterResponse::RasterPageFailed(
      "PDFium adapter returned an empty response",
    )
  }
  let tag = lines[0]
  match tag {
    "READY" =>
      if lines.length() < 6 {
        @app.PdfWorkbenchRasterResponse::RasterPageFailed(
          "PDFium adapter returned an incomplete ready response",
        )
      } else {
        let image_source = lines[1]
        match
          (
            pdfium_parse_positive_int(lines[2]),
            pdfium_parse_positive_int(lines[3]),
            pdfium_parse_positive_int(lines[4]),
          ) {
          (Some(width_px), Some(height_px), Some(page_count)) =>
            @app.PdfWorkbenchRasterResponse::RasterPageReady({
              cache_key: request.cache_key,
              page_number: request.page_number,
              zoom: request.zoom,
              page_count,
              width_px,
              height_px,
              image_source,
              diagnostic: lines[5],
            })
          _ =>
            @app.PdfWorkbenchRasterResponse::RasterPageFailed(
              "PDFium adapter returned invalid bitmap dimensions or page count",
            )
        }
      }
    "UNAVAILABLE" =>
      @app.PdfWorkbenchRasterResponse::RasterPageUnavailable(
        pdfium_response_reason(
          lines,
          fallback="PDFium raster service unavailable",
        ),
      )
    "FAILED" =>
      @app.PdfWorkbenchRasterResponse::RasterPageFailed(
        pdfium_response_reason(lines, fallback="PDFium rasterization failed"),
      )
    _ =>
      @app.PdfWorkbenchRasterResponse::RasterPageFailed(
        "PDFium adapter returned unknown response tag: " + tag,
      )
  }
}

///|
fn pdfium_response_reason(lines : Array[String], fallback~ : String) -> String {
  if lines.length() < 2 {
    fallback
  } else {
    let reason = lines[1]
    if reason == "" {
      fallback
    } else {
      reason
    }
  }
}

///|
fn pdfium_parse_positive_int(value : String) -> Int? {
  let chars = value.to_array()
  if chars.is_empty() {
    return None
  }
  let mut parsed = 0
  for ch in chars {
    if ch < '0' || ch > '9' {
      return None
    }
    parsed = parsed * 10 + ch.to_int() - '0'.to_int()
  }
  if parsed <= 0 {
    None
  } else {
    Some(parsed)
  }
}

///|
fn pdfium_encode_string(value : String) -> Bytes {
  @utf8.encode(value[:], bom=false)
}
