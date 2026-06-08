///|
pub struct PdfWorkbenchDocumentServices {
  load : (String, Bytes) -> PdfWorkbenchLoadResult
  writeback : (PdfWorkbenchDocument) -> PdfWorkbenchDocumentWritebackResult
}

///|
pub(all) enum PdfWorkbenchDocumentWritebackResult {
  WritebackReady(Bytes, Array[String])
  WritebackFailed(String)
}

///|
pub fn PdfWorkbenchDocumentServices::new(
  load~ : (String, Bytes) -> PdfWorkbenchLoadResult,
  writeback? : (PdfWorkbenchDocument) -> PdfWorkbenchDocumentWritebackResult = pdf_workbench_default_writeback,
) -> PdfWorkbenchDocumentServices {
  { load, writeback }
}

///|
pub fn PdfWorkbenchDocumentServices::lightweight() -> PdfWorkbenchDocumentServices {
  PdfWorkbenchDocumentServices::new(load=(path, bytes) => {
    PdfWorkbenchDocument::from_bytes(path~, bytes~)
  })
}

///|
pub fn PdfWorkbenchDocumentServices::load_document(
  self : PdfWorkbenchDocumentServices,
  path : String,
  bytes : Bytes,
) -> PdfWorkbenchLoadResult {
  (self.load)(path, bytes)
}

///|
pub fn PdfWorkbenchDocumentServices::writeback_document(
  self : PdfWorkbenchDocumentServices,
  document : PdfWorkbenchDocument,
) -> PdfWorkbenchDocumentWritebackResult {
  (self.writeback)(document)
}

///|
fn pdf_workbench_default_writeback(
  document : PdfWorkbenchDocument,
) -> PdfWorkbenchDocumentWritebackResult {
  ignore(document)
  WritebackFailed(
    "PDF writeback requires the pdflite adapter service; edits remain as preview state",
  )
}
