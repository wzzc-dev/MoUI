///|
pub fn pdflite_minimum_pdf_bytes() -> Bytes {
  let document = @pdf.pdf_minimum_valid_pdf() catch { _ => return b"" }
  @pdf.pdf_write_document(document) catch {
    _ => b""
  }
}

///|
pub fn pdflite_three_page_pdf_bytes() -> Bytes {
  let document = @pdf.pdf_document_empty()
  let page_root = document.add_pagetree([
    @page.pdf_page_blank(@geometry.paper_a4),
    @page.pdf_page_blank(@geometry.paper_a4),
    @page.pdf_page_blank(@geometry.paper_a4),
  ]) catch {
    _ => return b""
  }
  ignore(document.add_root(page_root, []) catch { _ => return b"" })
  @pdf.pdf_write_document(document) catch {
    _ => b""
  }
}

///|
pub fn load_document_from_bytes(
  path~ : String,
  bytes~ : Bytes,
) -> @app.PdfWorkbenchLoadResult {
  let document = @pdf.pdf_read_document_from_bytes(bytes) catch {
    _ => return @app.PdfWorkbenchLoadResult::Failed("PDF parse failed")
  }
  let page_count = document.endpage() catch {
    _ => return @app.PdfWorkbenchLoadResult::Failed("PDF page tree read failed")
  }
  let pages = pdflite_page_numbers(page_count)
  let extracted_text = pdflite_extract_text(document, pages)
  let page_summaries = pdflite_page_summaries(document, page_count)
  let (major, minor) = document.version()
  let metadata_title = pdflite_metadata_title(document)
  @app.PdfWorkbenchDocument::from_engine_summary(
    path~,
    original_bytes=bytes,
    page_count~,
    selected_page=1,
    extracted_text~,
    dirty=false,
    writeback_available=true,
    edits=[],
    unsupported_entries=[
      "PDFium raster service owns existing-page bitmap rendering", "Skia PDF backend is reserved for export/generation, not page rasterization",
    ],
    page_summaries~,
    metadata_summary=pdflite_metadata_summary(
      major,
      minor,
      bytes.length(),
      metadata_title,
    ),
    metadata_title~,
    outline_summary=pdflite_bookmark_summary(document),
    annotation_summary=pdflite_annotation_summary(document, pages),
  )
}

///|
pub fn document_services() -> @app.PdfWorkbenchDocumentServices {
  @app.PdfWorkbenchDocumentServices::new(
    load=(path, bytes) => load_document_from_bytes(path~, bytes~),
    writeback=document => writeback_document(document),
  )
}

///|
pub fn service_handler() -> @protocol.PdfWorkbenchPdfliteServiceHandler {
  @protocol.PdfWorkbenchPdfliteServiceHandler::new(handle=request => {
    match request {
      @protocol.PdfWorkbenchPdfliteServiceRequest::LoadDocument(path, bytes) =>
        match load_document_from_bytes(path~, bytes~) {
          @app.PdfWorkbenchLoadResult::Loaded(document) =>
            @protocol.PdfWorkbenchPdfliteServiceResponse::DocumentLoaded(
              document,
            )
          @app.PdfWorkbenchLoadResult::Failed(reason) =>
            @protocol.PdfWorkbenchPdfliteServiceResponse::ServiceFailed(reason)
        }
      @protocol.PdfWorkbenchPdfliteServiceRequest::WritebackDocument(
        path,
        bytes,
        edits
      ) =>
        match
          @app.PdfWorkbenchDocument::from_engine_summary(
            path~,
            original_bytes=bytes,
            page_count=1,
            selected_page=1,
            extracted_text="pdflite service writeback input",
            dirty=true,
            writeback_available=true,
            edits~,
          ) {
          @app.PdfWorkbenchLoadResult::Loaded(document) =>
            match writeback_document(document) {
              @app.PdfWorkbenchDocumentWritebackResult::WritebackReady(
                output,
                diagnostics
              ) =>
                @protocol.PdfWorkbenchPdfliteServiceResponse::WritebackReady(
                  output, diagnostics,
                )
              @app.PdfWorkbenchDocumentWritebackResult::WritebackFailed(reason) =>
                @protocol.PdfWorkbenchPdfliteServiceResponse::ServiceFailed(
                  reason,
                )
            }
          @app.PdfWorkbenchLoadResult::Failed(reason) =>
            @protocol.PdfWorkbenchPdfliteServiceResponse::ServiceFailed(reason)
        }
    }
  })
}

///|
pub fn writeback_document(
  document : @app.PdfWorkbenchDocument,
) -> @app.PdfWorkbenchDocumentWritebackResult {
  let parsed = @pdf.pdf_read_document_from_bytes(document.original_bytes) catch {
    _ =>
      return @app.PdfWorkbenchDocumentWritebackResult::WritebackFailed(
        "PDF parse failed before writeback",
      )
  }
  let mut rewritten = parsed
  let diagnostics : Array[String] = []
  for edit in document.edits {
    match edit {
      @app.PdfWorkbenchEdit::RotatePage(page, rotation) => {
        rewritten = rewritten.copy().rotate_pages(rotation, [page]) catch {
            _ =>
              return @app.PdfWorkbenchDocumentWritebackResult::WritebackFailed(
                "pdflite rotate writeback failed for page \{page}",
              )
          }
        diagnostics.push(
          "pdflite writeback applied RotatePage(page=\{page}, rotation=\{rotation})",
        )
      }
      @app.PdfWorkbenchEdit::CropPage(page, box) => {
        rewritten = rewritten
          .copy()
          .crop_pages([page], [(box.left, box.bottom, box.right, box.top)]) catch {
            _ =>
              return @app.PdfWorkbenchDocumentWritebackResult::WritebackFailed(
                "pdflite crop writeback failed for page \{page}",
              )
          }
        diagnostics.push("pdflite writeback applied CropPage(page=\{page})")
      }
      @app.PdfWorkbenchEdit::StampText(page, text) => {
        rewritten = pdflite_add_stamp_text(rewritten.copy(), page, text) catch {
          _ =>
            return @app.PdfWorkbenchDocumentWritebackResult::WritebackFailed(
              "pdflite text stamp writeback failed for page \{page}",
            )
        }
        diagnostics.push("pdflite writeback applied StampText(page=\{page})")
      }
      @app.PdfWorkbenchEdit::SetMetadataTitle(title) => {
        rewritten = pdflite_set_metadata_title(rewritten.copy(), title) catch {
          _ =>
            return @app.PdfWorkbenchDocumentWritebackResult::WritebackFailed(
              "pdflite metadata title writeback failed",
            )
        }
        diagnostics.push("pdflite writeback applied SetMetadataTitle")
      }
      @app.PdfWorkbenchEdit::AddBookmark(page, title) => {
        rewritten = pdflite_add_bookmark(rewritten.copy(), page, title) catch {
          _ =>
            return @app.PdfWorkbenchDocumentWritebackResult::WritebackFailed(
              "pdflite bookmark writeback failed for page \{page}",
            )
        }
        diagnostics.push("pdflite writeback applied AddBookmark(page=\{page})")
      }
      @app.PdfWorkbenchEdit::AddTextAnnotation(page, text) => {
        rewritten = pdflite_add_text_annotation(rewritten.copy(), page, text) catch {
          _ =>
            return @app.PdfWorkbenchDocumentWritebackResult::WritebackFailed(
              "pdflite text annotation writeback failed for page \{page}",
            )
        }
        diagnostics.push(
          "pdflite writeback applied AddTextAnnotation(page=\{page})",
        )
      }
    }
  }
  let output = @pdf.pdf_write_document(rewritten) catch {
    _ =>
      return @app.PdfWorkbenchDocumentWritebackResult::WritebackFailed(
        "pdflite document serialization failed",
      )
  }
  @app.PdfWorkbenchDocumentWritebackResult::WritebackReady(output, diagnostics)
}

///|
fn pdflite_add_text_annotation(
  document : @pdf.PdfDocument,
  page : Int,
  text : String,
) -> @pdf.PdfDocument raise @pdfcore.PdfError {
  let note_text = text.trim().to_owned()
  if note_text == "" {
    document
  } else {
    let pages = document.pages_of_pagetree()
    if page < 1 || page > pages.length() {
      raise @pdfcore.PdfError::BadPageSpecification(
        "add text annotation page \{page}",
      )
    }
    let index = page - 1
    let page_bounds = document.parse_rectangle(pages[index].mediabox)
    let note_rect = pdflite_annotation_rect_near_top(page_bounds)
    let annotation = @annotation.pdf_annotation_make(
      AnnotationText,
      contents=Some(@pdf.pdf_pdfdocstring_of_utf8(@utf8.encode(note_text))),
      rectangle=note_rect,
      colour=Some({ red: 255, green: 222, blue: 72 }),
      subject=Some(@ascii.encode("MoUI PDF Workbench note")),
    )
    pages[index] = document.add_annotation(pages[index], annotation)
    document.change_pages(pages)
  }
}

///|
fn pdflite_annotation_rect_near_top(
  bounds : @geometry.PdfRectangle,
) -> @geometry.PdfRectangle {
  let width = 28.0
  let height = 28.0
  let left = bounds.min_x + 36.0
  let top = bounds.max_y - 36.0
  { min_x: left, min_y: top - height, max_x: left + width, max_y: top }
}

///|
fn pdflite_add_bookmark(
  document : @pdf.PdfDocument,
  page : Int,
  title : String,
) -> @pdf.PdfDocument raise @pdfcore.PdfError {
  let bookmark_title = title.trim().to_owned()
  if bookmark_title == "" {
    document
  } else {
    let bookmarks = document.read_bookmarks(preserve_actions=true)
    bookmarks.push({
      level: 0,
      text: @pdf.pdf_pdfdocstring_of_utf8(@utf8.encode(bookmark_title)),
      target: document.target_of_page_number(page),
      is_open: true,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    })
    document.add_bookmarks(bookmarks)
  }
}

///|
fn pdflite_metadata_title(document : @pdf.PdfDocument) -> String {
  document.info_utf8(pdflite_pdf_name("/Title"))
}

///|
fn pdflite_metadata_summary(
  major : Int,
  minor : Int,
  byte_length : Int,
  title : String,
) -> String {
  let prefix = "PDF \{major}.\{minor}; bytes=\{byte_length}; parser=pdflite-adapter"
  if title == "" {
    prefix
  } else {
    prefix + "; title=" + title
  }
}

///|
fn pdflite_pdf_name(value : String) -> @pdfcore.PdfName {
  @pdfcore.pdf_name_of_bytes(@ascii.encode(value))
}

///|
fn pdflite_set_metadata_title(
  document : @pdf.PdfDocument,
  title : String,
) -> @pdf.PdfDocument raise @pdfcore.PdfError {
  let value = @pdf.pdf_pdfdocstring_of_utf8(@utf8.encode(title))
  document.set_info_entry(
    pdflite_pdf_name("/Title"),
    @syntax.PdfObject::PdfString(value),
    4,
    xmp_also=true,
  )
}

///|
fn pdflite_add_stamp_text(
  document : @pdf.PdfDocument,
  page : Int,
  text : String,
) -> @pdf.PdfDocument raise @pdfcore.PdfError {
  let stamp_text = text.trim().to_owned()
  if stamp_text == "" {
    document
  } else {
    let stamp_font : @pdf.PdfFont = @pdf.PdfFont::PdfFontStandard({
      font: @pdf.PdfStandardFont::PdfHelveticaBold,
      encoding: @pdf.PdfEncoding::PdfWinAnsiEncoding,
    })
    document.addtexts_with_font(
      [page],
      stamp_text,
      @date.pdf_strftime_dummy_time(),
      [],
      Some(stamp_font),
      None,
      pdflite_pdf_name("/Helvetica-Bold"),
      18.0,
      1.0,
      @colour.PdfContentColour::PdfContentRGB(0.76, 0.12, 0.16),
      @geometry.PdfPosition::PdfPositionTopRight(18.0, 18.0),
      opacity=0.42,
      justification=@addtext.PdfAddTextJustification::PdfAddTextRightJustify,
      rotation=@addtext.PdfAddTextRotation::PdfAddTextRot0,
    )
  }
}

///|
pub fn pdflite_rotate_crop_roundtrip(bytes : Bytes) -> Bool {
  let document = @pdf.pdf_read_document_from_bytes(bytes) catch {
    _ => return false
  }
  let rotated = document.copy().rotate_pages(90, [1]) catch {
      _ => return false
    }
  let cropped = rotated.copy().crop_pages([1], [(36.0, 36.0, 523.0, 770.0)]) catch {
      _ => return false
    }
  let output = @pdf.pdf_write_document(cropped) catch { _ => return false }
  let reparsed = @pdf.pdf_read_document_from_bytes(output) catch {
    _ => return false
  }
  let page_count = reparsed.endpage() catch { _ => return false }
  page_count > 0
}

///|
fn pdflite_extract_text(
  document : @pdf.PdfDocument,
  pages : Array[Int],
) -> String {
  let bytes = document.test_extract_text(pages) catch { _ => return "" }
  @utf8.decode_lossy(bytes[:], ignore_bom=true)
}

///|
fn pdflite_page_summaries(
  document : @pdf.PdfDocument,
  page_count : Int,
) -> Array[@app.PdfWorkbenchPageSummary] {
  let summaries : Array[@app.PdfWorkbenchPageSummary] = []
  for page in 1..<=page_count {
    let text = pdflite_extract_text(document, [page])
    summaries.push({
      page_number: page,
      text_preview: pdflite_preview_text(text),
      content_diagnostic: "pdflite text extraction ready; content JSON adapter pending for this v1 preview",
    })
  }
  summaries
}

///|
fn pdflite_page_numbers(page_count : Int) -> Array[Int] {
  let pages : Array[Int] = []
  for page in 1..<=page_count {
    pages.push(page)
  }
  pages
}

///|
fn pdflite_bookmark_summary(document : @pdf.PdfDocument) -> String {
  let bytes = document.bookmarks_json_blob(json_preserve_actions=false) catch {
    _ => return "Bookmarks unavailable"
  }
  "Bookmark JSON bytes: " + bytes.length().to_string()
}

///|
fn pdflite_annotation_summary(
  document : @pdf.PdfDocument,
  pages : Array[Int],
) -> String {
  let bytes = document.annotations_json_blob(pages) catch {
    _ => return "Annotations unavailable"
  }
  "Annotation JSON bytes: " + bytes.length().to_string()
}

///|
fn pdflite_preview_text(text : String) -> String {
  let trimmed = text.trim().to_owned()
  if trimmed == "" {
    "No extractable text on this page"
  } else if trimmed.to_array().length() > 96 {
    String::from_array(trimmed.to_array()[:96]) + "..."
  } else {
    trimmed
  }
}
