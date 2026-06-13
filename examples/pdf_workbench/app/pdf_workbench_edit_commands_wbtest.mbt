///|
test "pdf workbench rotate and crop mark document dirty" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let model = match
    PdfWorkbenchDocument::from_bytes(path="/tmp/minimum.pdf", bytes~) {
    Loaded(document) =>
      {
        ..PdfWorkbenchModel::new(),
        document: Some(document),
        status: PdfWorkbenchStatus::Ready,
      }
    Failed(reason) => fail(reason)
  }
  let rotated = model.update(RotateCurrentPage)
  guard rotated.document is Some(rotated_document) else {
    fail("expected rotated document")
  }
  assert_true(rotated_document.dirty)
  let cropped = rotated.update(CropCurrentPage)
  guard cropped.document is Some(cropped_document) else {
    fail("expected cropped document")
  }
  assert_true(cropped_document.dirty)
  let stamped = cropped.update(StampCurrentPage)
  guard stamped.document is Some(stamped_document) else {
    fail("expected stamped document")
  }
  assert_true(stamped_document.dirty)
  inspect(stamped_document.edits.length(), content="3")
}

///|
test "pdf workbench metadata title apply marks document dirty" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let model = match
    PdfWorkbenchDocument::from_bytes(path="/tmp/minimum.pdf", bytes~) {
    Loaded(document) =>
      {
        ..PdfWorkbenchModel::new(),
        document: Some(document),
        status: PdfWorkbenchStatus::Ready,
      }
    Failed(reason) => fail(reason)
  }
  let drafted = model.update(MetadataTitleChanged("Quarterly Review"))
  inspect(drafted.metadata_title_draft, content="Quarterly Review")
  let applied = drafted.update(ApplyMetadataTitle)
  guard applied.document is Some(document) else {
    fail("expected edited document")
  }
  assert_true(document.dirty)
  inspect(document.metadata_title, content="Quarterly Review")
  inspect(document.edits.length(), content="1")
  guard document.edits[0] is SetMetadataTitle("Quarterly Review") else {
    fail("expected metadata title edit")
  }
}

///|
test "pdf workbench add bookmark marks document dirty" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let model = match
    PdfWorkbenchDocument::from_bytes(path="/tmp/minimum.pdf", bytes~) {
    Loaded(document) =>
      {
        ..PdfWorkbenchModel::new(),
        document: Some(document),
        status: PdfWorkbenchStatus::Ready,
      }
    Failed(reason) => fail(reason)
  }
  let drafted = model.update(BookmarkTitleChanged("Chapter 1"))
  inspect(drafted.bookmark_title_draft, content="Chapter 1")
  let applied = drafted.update(AddBookmarkForCurrentPage)
  guard applied.document is Some(document) else {
    fail("expected edited document")
  }
  assert_true(document.dirty)
  inspect(document.edits.length(), content="1")
  guard document.edits[0] is AddBookmark(1, "Chapter 1") else {
    fail("expected bookmark edit")
  }
}

///|
test "pdf workbench add note marks document dirty" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let model = match
    PdfWorkbenchDocument::from_bytes(path="/tmp/minimum.pdf", bytes~) {
    Loaded(document) =>
      {
        ..PdfWorkbenchModel::new(),
        document: Some(document),
        status: PdfWorkbenchStatus::Ready,
      }
    Failed(reason) => fail(reason)
  }
  let drafted = model.update(AnnotationTextChanged("Check the source table"))
  inspect(drafted.annotation_text_draft, content="Check the source table")
  let applied = drafted.update(AddAnnotationForCurrentPage)
  guard applied.document is Some(document) else {
    fail("expected edited document")
  }
  assert_true(document.dirty)
  assert_true(document.annotation_summary.contains("Check the source table"))
  inspect(document.edits.length(), content="1")
  guard document.edits[0] is AddTextAnnotation(1, "Check the source table") else {
    fail("expected text annotation edit")
  }
}
