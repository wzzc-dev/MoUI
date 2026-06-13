///|
fn PdfWorkbenchModel::rotate_current_page(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) =>
      self.replace_document_summary(
        document.with_edit(RotatePage(document.selected_page, 90)),
        event="Queued 90 degree page rotation",
      )
    None =>
      {
        ..self,
        status: Failed("open a PDF before editing"),
        last_event: "Edit unavailable",
      }
  }
}

///|
fn PdfWorkbenchModel::crop_current_page(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) => {
      let box = { left: 36.0, bottom: 36.0, right: 523.0, top: 770.0 }
      self.replace_document_summary(
        document.with_edit(CropPage(document.selected_page, box)),
        event="Queued sample crop box",
      )
    }
    None =>
      {
        ..self,
        status: Failed("open a PDF before editing"),
        last_event: "Edit unavailable",
      }
  }
}

///|
fn PdfWorkbenchModel::stamp_current_page(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) =>
      self.replace_document_summary(
        document.with_edit(
          StampText(document.selected_page, pdf_workbench_default_stamp_text()),
        ),
        event="Queued page stamp",
      )
    None =>
      {
        ..self,
        status: Failed("open a PDF before editing"),
        last_event: "Edit unavailable",
      }
  }
}

///|
fn PdfWorkbenchModel::discard_edits(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) =>
      if document.dirty || document.edits.length() > 0 {
        let reverted = document.discard_edits()
        {
          ..self,
          document: Some(reverted),
          metadata_title_draft: reverted.metadata_title,
          bookmark_title_draft: "",
          annotation_text_draft: "",
          status: Ready,
          last_event: "Discarded queued edits",
        }
      } else {
        { ..self, status: Ready, last_event: "No queued edits to discard" }
      }
    None =>
      {
        ..self,
        status: Failed("open a PDF before editing"),
        last_event: "Edit unavailable",
      }
  }
}

///|
fn PdfWorkbenchModel::clear_failure(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  match self.status {
    Failed(_) => { ..self, status: Ready, last_event: "Cleared failure" }
    _ => self
  }
}

///|
fn PdfWorkbenchModel::undo_last_edit(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) =>
      match document.undo_last_edit() {
        Some(reverted) =>
          {
            ..self,
            document: Some(reverted),
            metadata_title_draft: reverted.metadata_title,
            bookmark_title_draft: "",
            annotation_text_draft: "",
            status: Ready,
            last_event: "Undid last queued edit",
          }
        None => { ..self, status: Ready, last_event: "No queued edits to undo" }
      }
    None =>
      {
        ..self,
        status: Failed("open a PDF before editing"),
        last_event: "Edit unavailable",
      }
  }
}

///|
fn PdfWorkbenchModel::apply_metadata_title(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) => {
      let next_title = self.metadata_title_draft.trim().to_owned()
      if next_title == document.metadata_title {
        { ..self, status: Ready, last_event: "Metadata title unchanged" }
      } else {
        self.replace_document_summary(
          document.with_edit(SetMetadataTitle(next_title)),
          event="Queued metadata title update",
        )
      }
    }
    None =>
      {
        ..self,
        status: Failed("open a PDF before editing metadata"),
        last_event: "Metadata edit unavailable",
      }
  }
}

///|
fn PdfWorkbenchModel::add_bookmark_for_current_page(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) => {
      let title = self.bookmark_title_draft.trim().to_owned()
      if title == "" {
        { ..self, status: Ready, last_event: "Bookmark title required" }
      } else {
        self.replace_document_summary(
          document.with_edit(AddBookmark(document.selected_page, title)),
          event="Queued bookmark for page " + document.selected_page.to_string(),
        )
      }
    }
    None =>
      {
        ..self,
        status: Failed("open a PDF before editing bookmarks"),
        last_event: "Bookmark edit unavailable",
      }
  }
}

///|
fn PdfWorkbenchModel::add_annotation_for_current_page(
  self : PdfWorkbenchModel,
) -> PdfWorkbenchModel {
  match self.document {
    Some(document) => {
      let text = self.annotation_text_draft.trim().to_owned()
      if text == "" {
        { ..self, status: Ready, last_event: "Annotation text required" }
      } else {
        self.replace_document_summary(
          document.with_edit(AddTextAnnotation(document.selected_page, text)),
          event="Queued note for page " + document.selected_page.to_string(),
        )
      }
    }
    None =>
      {
        ..self,
        status: Failed("open a PDF before editing annotations"),
        last_event: "Annotation edit unavailable",
      }
  }
}

///|
fn PdfWorkbenchModel::replace_document_summary(
  self : PdfWorkbenchModel,
  document : PdfWorkbenchDocument,
  event~ : String,
) -> PdfWorkbenchModel {
  { ..self, document: Some(document), status: Ready, last_event: event }
}
