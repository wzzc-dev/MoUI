///|
test "pdf workbench discard edits restores clean preview state" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let document = match
    PdfWorkbenchDocument::from_engine_summary(
      path="/tmp/minimum.pdf",
      original_bytes=bytes,
      page_count=1,
      selected_page=1,
      extracted_text="clean page text",
      dirty=false,
      writeback_available=false,
      unsupported_entries=["clean diagnostic"],
      page_summaries=[
        {
          page_number: 1,
          text_preview: "clean page text",
          content_diagnostic: "clean page diagnostic",
        },
      ],
      metadata_summary="PDF 1.4; parser=test",
      metadata_title="Original Title",
      outline_summary="clean outline",
      annotation_summary="Clean annotations",
    ) {
    Loaded(document) => document
    Failed(reason) => fail(reason)
  }
  let model = {
    ..PdfWorkbenchModel::new(),
    document: Some(document),
    status: PdfWorkbenchStatus::Ready,
    metadata_title_draft: document.metadata_title,
  }
  let edited = model
    .update(MetadataTitleChanged("Changed Title"))
    .update(ApplyMetadataTitle)
    .update(AnnotationTextChanged("Draft note"))
    .update(AddAnnotationForCurrentPage)
    .update(StampCurrentPage)
  guard edited.document is Some(edited_document) else {
    fail("expected edited document")
  }
  assert_true(edited_document.dirty)
  inspect(edited_document.metadata_title, content="Changed Title")
  assert_true(edited_document.annotation_summary.contains("Draft note"))
  assert_true(
    edited_document.selected_summary().content_diagnostic.contains(
      "queued stamp",
    ),
  )
  assert_true(
    edited_document.unsupported_entries.any(entry => {
      entry.contains("Queued edit needs pdflite adapter writeback")
    }),
  )
  let discarded = edited.update(DiscardEdits)
  guard discarded.document is Some(discarded_document) else {
    fail("expected discarded document")
  }
  assert_false(discarded_document.dirty)
  inspect(discarded_document.edits.length(), content="0")
  inspect(discarded_document.metadata_title, content="Original Title")
  inspect(discarded.metadata_title_draft, content="Original Title")
  inspect(discarded.bookmark_title_draft, content="")
  inspect(discarded.annotation_text_draft, content="")
  inspect(discarded_document.annotation_summary, content="Clean annotations")
  inspect(
    discarded_document.selected_summary().content_diagnostic,
    content="clean page diagnostic",
  )
  inspect(discarded_document.unsupported_entries.length(), content="1")
  assert_false(
    discarded_document.unsupported_entries.any(entry => {
      entry.contains("Queued edit needs pdflite adapter writeback")
    }),
  )
  inspect(discarded.last_event, content="Discarded queued edits")
}

///|
test "pdf workbench undo last edit replays remaining cleanly" {
  let bytes = pdf_workbench_minimum_pdf_bytes()
  let document = match
    PdfWorkbenchDocument::from_engine_summary(
      path="/tmp/minimum.pdf",
      original_bytes=bytes,
      page_count=1,
      selected_page=1,
      extracted_text="clean page text",
      dirty=false,
      writeback_available=false,
      unsupported_entries=["clean diagnostic"],
      page_summaries=[
        {
          page_number: 1,
          text_preview: "clean page text",
          content_diagnostic: "clean page diagnostic",
        },
      ],
      metadata_summary="PDF 1.4; parser=test",
      metadata_title="Original Title",
      outline_summary="clean outline",
      annotation_summary="Clean annotations",
    ) {
    Loaded(document) => document
    Failed(reason) => fail(reason)
  }
  let model = {
    ..PdfWorkbenchModel::new(),
    document: Some(document),
    status: PdfWorkbenchStatus::Ready,
    metadata_title_draft: document.metadata_title,
  }
  let edited = model
    .update(MetadataTitleChanged("Changed Title"))
    .update(ApplyMetadataTitle)
    .update(AnnotationTextChanged("Draft note"))
    .update(AddAnnotationForCurrentPage)
    .update(StampCurrentPage)
  guard edited.document is Some(edited_document) else {
    fail("expected edited document")
  }
  inspect(edited_document.edits.length(), content="3")
  assert_true(
    edited_document.selected_summary().content_diagnostic.contains(
      "queued stamp",
    ),
  )
  let without_stamp = edited.update(UndoLastEdit)
  guard without_stamp.document is Some(without_stamp_document) else {
    fail("expected document after undoing stamp")
  }
  inspect(without_stamp_document.edits.length(), content="2")
  inspect(without_stamp_document.metadata_title, content="Changed Title")
  assert_true(without_stamp_document.annotation_summary.contains("Draft note"))
  assert_false(
    without_stamp_document.selected_summary().content_diagnostic.contains(
      "queued stamp",
    ),
  )
  inspect(without_stamp.metadata_title_draft, content="Changed Title")
  inspect(without_stamp.last_event, content="Undid last queued edit")
  let without_note = without_stamp.update(UndoLastEdit)
  guard without_note.document is Some(without_note_document) else {
    fail("expected document after undoing note")
  }
  inspect(without_note_document.edits.length(), content="1")
  inspect(without_note_document.metadata_title, content="Changed Title")
  inspect(without_note_document.annotation_summary, content="Clean annotations")
  let clean = without_note.update(UndoLastEdit)
  guard clean.document is Some(clean_document) else {
    fail("expected document after undoing title")
  }
  assert_false(clean_document.dirty)
  inspect(clean_document.edits.length(), content="0")
  inspect(clean_document.metadata_title, content="Original Title")
  inspect(clean.metadata_title_draft, content="Original Title")
  inspect(clean_document.annotation_summary, content="Clean annotations")
  inspect(
    clean_document.selected_summary().content_diagnostic,
    content="clean page diagnostic",
  )
}
