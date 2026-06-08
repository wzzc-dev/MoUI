///|
#borrow(path)
extern "C" fn rendered_bmp_header_ok_raw(path : Bytes) -> Int = "moui_pdf_workbench_bmp_header_ok"

///|
#borrow(path)
extern "C" fn rendered_bmp_metadata_ok_raw(
  path : Bytes,
  expected_width : Int,
  expected_height : Int,
) -> Int = "moui_pdf_workbench_bmp_metadata_ok"

///|
test "pdfium adapter reports explicit availability state" {
  let request = pdfium_test_request()
  let response = render_page(request)
  if pdfium_available() {
    match response {
      @app.PdfWorkbenchRasterResponse::RasterPageReady(page) => {
        inspect(page.width_px, content="612")
        inspect(page.height_px, content="792")
        inspect(page.page_count, content="1")
        assert_true(rendered_bmp_header_ok(page.image_source))
        assert_true(
          rendered_bmp_metadata_ok(
            page.image_source,
            page.width_px,
            page.height_px,
          ),
        )
      }
      @app.PdfWorkbenchRasterResponse::RasterPageFailed(reason) =>
        fail("expected minimum PDF render, got failure: " + reason)
      @app.PdfWorkbenchRasterResponse::RasterPageUnavailable(reason) =>
        fail("expected PDFium availability, got unavailable: " + reason)
    }
  } else {
    match response {
      @app.PdfWorkbenchRasterResponse::RasterPageUnavailable(reason) =>
        assert_true(reason.contains("PDFium"))
      _ => fail("expected unavailable response when PDFium is not linked")
    }
  }
}

///|
test "pdfium adapter classifies bad pdf and invalid pages" {
  if !pdfium_available() {
    assert_true(true)
    return
  }
  let bad = render_page({ ..pdfium_test_request(), bytes: b"not a pdf" })
  match bad {
    @app.PdfWorkbenchRasterResponse::RasterPageFailed(reason) =>
      assert_true(reason.contains("load") || reason.contains("parse"))
    _ => fail("expected bad PDF to fail")
  }
  let invalid = render_page({ ..pdfium_test_request(), page_number: 99 })
  match invalid {
    @app.PdfWorkbenchRasterResponse::RasterPageFailed(reason) =>
      assert_true(reason.contains("range") || reason.contains("bounds"))
    _ => fail("expected invalid page to fail")
  }
}

///|
test "pdfium adapter renders second page from generated multipage pdf" {
  if !pdfium_available() {
    assert_true(true)
    return
  }
  let bytes = @pdflite_adapter.pdflite_three_page_pdf_bytes()
  assert_true(bytes.length() > 0)
  let response = render_page({
    ..pdfium_test_request(),
    path: "/tmp/moui-pdf-workbench-test/three-page.pdf",
    bytes,
    page_number: 2,
    cache_key: "three-page-test-page=2-zoom=100",
  })
  match response {
    @app.PdfWorkbenchRasterResponse::RasterPageReady(page) => {
      inspect(page.page_number, content="2")
      inspect(page.page_count, content="3")
      assert_true(rendered_bmp_header_ok(page.image_source))
      assert_true(
        rendered_bmp_metadata_ok(
          page.image_source,
          page.width_px,
          page.height_px,
        ),
      )
    }
    @app.PdfWorkbenchRasterResponse::RasterPageFailed(reason) =>
      fail("expected page 2 render, got failure: " + reason)
    @app.PdfWorkbenchRasterResponse::RasterPageUnavailable(reason) =>
      fail("expected PDFium availability, got unavailable: " + reason)
  }
}

///|
fn pdfium_test_request() -> @app.PdfWorkbenchRasterRequest {
  {
    path: "/tmp/moui-pdf-workbench-test/minimum.pdf",
    bytes: @app.pdf_workbench_minimum_pdf_bytes(),
    page_number: 1,
    zoom: 1.0,
    dpi: 72,
    max_pixel_edge: 1024,
    cache_key: "minimum-test-page=1-zoom=100",
  }
}

///|
fn rendered_bmp_header_ok(path : String) -> Bool {
  rendered_bmp_header_ok_raw(@utf8.encode(path[:], bom=false)) != 0
}

///|
fn rendered_bmp_metadata_ok(
  path : String,
  expected_width : Int,
  expected_height : Int,
) -> Bool {
  rendered_bmp_metadata_ok_raw(
    @utf8.encode(path[:], bom=false),
    expected_width,
    expected_height,
  ) !=
  0
}
