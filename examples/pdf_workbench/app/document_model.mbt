///|
pub fn PdfWorkbenchDocument::from_bytes(
  path~ : String,
  bytes~ : Bytes,
) -> PdfWorkbenchLoadResult {
  let sample = pdf_workbench_decode_sample(bytes)
  if !sample.contains("%PDF-") {
    return Failed("PDF header not found")
  }
  let page_count = pdf_workbench_estimated_page_count(sample)
  let version = pdf_workbench_pdf_version(sample)
  let page_summaries = pdf_workbench_page_summaries_from_sample(
    sample, page_count,
  )
  PdfWorkbenchDocument::from_engine_summary(
    path~,
    original_bytes=bytes,
    page_count~,
    selected_page=1,
    extracted_text=sample,
    dirty=false,
    writeback_available=false,
    edits=[],
    unsupported_entries=[
      "Lightweight fallback summary is active; native entrypoints use pdflite for real document metadata and text",
      "pdflite parsing/writeback is isolated in examples/pdf_workbench/pdflite_adapter",
      "PDFium raster service supplies real page bitmaps when the native adapter is linked",
      "Skia PDF backend is reserved for export/generation, not page rasterization",
    ],
    page_summaries~,
    metadata_summary="PDF \{version}; bytes=\{bytes.length()}; parser=lightweight-ui-shell",
    metadata_title="",
    outline_summary="Outline requires pdflite adapter",
    annotation_summary="Annotations require pdflite adapter",
  )
}

///|
fn pdf_workbench_append_unsupported_entry(
  entries : Array[String],
  entry : String,
) -> Array[String] {
  let next = entries.copy()
  next.push(entry)
  next
}

///|
pub fn PdfWorkbenchDocument::from_engine_summary(
  path~ : String,
  original_bytes~ : Bytes,
  page_count~ : Int,
  selected_page~ : Int,
  extracted_text~ : String,
  dirty~ : Bool,
  writeback_available? : Bool = false,
  edits? : Array[PdfWorkbenchEdit] = [],
  unsupported_entries? : Array[String] = [],
  page_summaries? : Array[PdfWorkbenchPageSummary] = [],
  metadata_summary? : String = "",
  metadata_title? : String = "",
  outline_summary? : String = "",
  annotation_summary? : String = "",
) -> PdfWorkbenchLoadResult {
  let safe_page_count = if page_count < 1 { 1 } else { page_count }
  let selected = pdf_workbench_clamp_int(selected_page, 1, safe_page_count)
  let summaries = if page_summaries.is_empty() {
    pdf_workbench_empty_page_summaries(safe_page_count)
  } else {
    page_summaries
  }
  Loaded({
    path,
    original_bytes,
    page_count: safe_page_count,
    selected_page: selected,
    extracted_text,
    dirty,
    writeback_available,
    edits,
    unsupported_entries,
    page_summaries: summaries,
    metadata_summary,
    metadata_title,
    outline_summary,
    annotation_summary,
    clean_unsupported_entries: unsupported_entries.copy(),
    clean_page_summaries: summaries.copy(),
    clean_metadata_title: metadata_title,
    clean_annotation_summary: annotation_summary,
  })
}

///|
pub fn PdfWorkbenchDocument::with_edit(
  self : PdfWorkbenchDocument,
  edit : PdfWorkbenchEdit,
) -> PdfWorkbenchDocument {
  let base = match edit {
    SetMetadataTitle(title) => { ..self, metadata_title: title }
    AddTextAnnotation(page, text) =>
      {
        ..self,
        annotation_summary: pdf_workbench_annotation_summary_with_queued_note(
          self.annotation_summary,
          page,
          text,
        ),
      }
    _ => self
  }
  let edits = base.edits.copy()
  edits.push(edit)
  let diagnostic = pdf_workbench_edit_diagnostic(edit)
  let unsupported_entries = base.unsupported_entries.copy()
  if !base.writeback_available {
    unsupported_entries.push(
      "Queued edit needs pdflite adapter writeback before it can be saved",
    )
  }
  let page_summaries = match edit {
    SetMetadataTitle(_) | AddBookmark(_, _) => base.page_summaries
    _ =>
      base.page_summaries.map(summary => {
        if summary.page_number ==
          pdf_workbench_edit_page(edit, base.selected_page) {
          {
            ..summary,
            content_diagnostic: summary.content_diagnostic + "; " + diagnostic,
          }
        } else {
          summary
        }
      })
  }
  { ..base, dirty: true, edits, unsupported_entries, page_summaries }
}

///|
pub fn PdfWorkbenchDocument::undo_last_edit(
  self : PdfWorkbenchDocument,
) -> PdfWorkbenchDocument? {
  if self.edits.is_empty() {
    return None
  }
  let remaining : Array[PdfWorkbenchEdit] = []
  for index in 0..<(self.edits.length() - 1) {
    remaining.push(self.edits[index])
  }
  Some(self.replay_edits(remaining))
}

///|
fn PdfWorkbenchDocument::replay_edits(
  self : PdfWorkbenchDocument,
  edits : Array[PdfWorkbenchEdit],
) -> PdfWorkbenchDocument {
  let mut replayed = self.discard_edits()
  for edit in edits {
    replayed = replayed.with_edit(edit)
  }
  replayed
}

///|
pub fn PdfWorkbenchDocument::discard_edits(
  self : PdfWorkbenchDocument,
) -> PdfWorkbenchDocument {
  {
    ..self,
    dirty: false,
    edits: [],
    unsupported_entries: self.clean_unsupported_entries.copy(),
    page_summaries: self.clean_page_summaries.copy(),
    metadata_title: self.clean_metadata_title,
    annotation_summary: self.clean_annotation_summary,
  }
}

///|
fn pdf_workbench_annotation_summary_with_queued_note(
  summary : String,
  page : Int,
  text : String,
) -> String {
  let prefix = "Queued text annotation page \{page}: " + text
  if summary.trim().to_owned() == "" {
    prefix
  } else {
    summary + "; " + prefix
  }
}

///|
fn pdf_workbench_edit_page(edit : PdfWorkbenchEdit, fallback : Int) -> Int {
  match edit {
    RotatePage(page, _) => page
    CropPage(page, _) => page
    StampText(page, _) => page
    AddBookmark(page, _) => page
    AddTextAnnotation(page, _) => page
    SetMetadataTitle(_) => fallback
  }
}

///|
pub fn PdfWorkbenchDocument::with_page_count_from_raster(
  self : PdfWorkbenchDocument,
  page_count : Int,
) -> PdfWorkbenchDocument {
  let safe_page_count = if page_count < 1 { 1 } else { page_count }
  if safe_page_count <= self.page_count &&
    self.page_summaries.length() >= safe_page_count &&
    self.clean_page_summaries.length() >= safe_page_count {
    self
  } else {
    let summaries = pdf_workbench_extend_raster_page_summaries(
      self.page_summaries,
      safe_page_count,
    )
    let clean_summaries = pdf_workbench_extend_raster_page_summaries(
      self.clean_page_summaries,
      safe_page_count,
    )
    {
      ..self,
      page_count: self.page_count.max(safe_page_count),
      selected_page: pdf_workbench_clamp_int(
        self.selected_page,
        1,
        self.page_count.max(safe_page_count),
      ),
      page_summaries: summaries,
      clean_page_summaries: clean_summaries,
    }
  }
}

///|
fn pdf_workbench_extend_raster_page_summaries(
  summaries : Array[PdfWorkbenchPageSummary],
  page_count : Int,
) -> Array[PdfWorkbenchPageSummary] {
  let next = summaries.copy()
  let mut page = next.length() + 1
  while page <= page_count {
    next.push({
      page_number: page,
      text_preview: "PDF page \{page} loaded. PDFium confirmed this page; pdflite adapter owns extracted text.",
      content_diagnostic: "PDFium raster page confirmed; lightweight summary unavailable",
    })
    page = page + 1
  }
  next
}

///|
pub fn PdfWorkbenchDocument::selected_summary(
  self : PdfWorkbenchDocument,
) -> PdfWorkbenchPageSummary {
  if self.page_summaries.is_empty() {
    {
      page_number: self.selected_page,
      text_preview: "No extracted text",
      content_diagnostic: "No page summary available",
    }
  } else {
    let index = pdf_workbench_clamp_int(
      self.selected_page - 1,
      0,
      self.page_summaries.length() - 1,
    )
    self.page_summaries[index]
  }
}

///|
pub fn PdfWorkbenchDocument::search_count(
  self : PdfWorkbenchDocument,
  query : String,
) -> Int {
  let pages = self.search_match_pages(query)
  pages.length()
}

///|
pub fn PdfWorkbenchDocument::search_match_pages(
  self : PdfWorkbenchDocument,
  query : String,
) -> Array[Int] {
  let needle = pdf_workbench_normalized_query(query)
  let matches : Array[Int] = []
  if needle == "" {
    return matches
  }
  for summary in self.page_summaries {
    if pdf_workbench_page_summary_matches(summary, needle) {
      matches.push(summary.page_number)
    }
  }
  if matches.is_empty() && self.extracted_text.to_lower().contains(needle) {
    matches.push(self.selected_page)
  }
  matches
}

///|
pub fn PdfWorkbenchDocument::next_search_page(
  self : PdfWorkbenchDocument,
  query : String,
) -> Int? {
  let matches = self.search_match_pages(query)
  if matches.is_empty() {
    return None
  }
  for page in matches {
    if page > self.selected_page {
      return Some(page)
    }
  }
  Some(matches[0])
}

///|
pub fn PdfWorkbenchDocument::previous_search_page(
  self : PdfWorkbenchDocument,
  query : String,
) -> Int? {
  let matches = self.search_match_pages(query)
  if matches.is_empty() {
    return None
  }
  let mut previous = matches[matches.length() - 1]
  for page in matches {
    if page < self.selected_page {
      previous = page
    }
  }
  Some(previous)
}

///|
pub fn PdfWorkbenchDocument::search_match_position(
  self : PdfWorkbenchDocument,
  query : String,
  page_number : Int,
) -> Int? {
  let matches = self.search_match_pages(query)
  for index in 0..<matches.length() {
    if matches[index] == page_number {
      return Some(index + 1)
    }
  }
  None
}

///|
fn pdf_workbench_search_position_suffix(
  document : PdfWorkbenchDocument,
  query : String,
  page_number : Int,
) -> String {
  let matches = document.search_match_pages(query)
  match document.search_match_position(query, page_number) {
    Some(position) =>
      " (" + position.to_string() + "/" + matches.length().to_string() + ")"
    None => ""
  }
}

///|
fn pdf_workbench_normalized_query(query : String) -> String {
  query.trim().to_owned().to_lower()
}

///|
fn pdf_workbench_page_summary_matches(
  summary : PdfWorkbenchPageSummary,
  needle : String,
) -> Bool {
  summary.text_preview.to_lower().contains(needle) ||
  summary.content_diagnostic.to_lower().contains(needle)
}

///|
pub fn pdf_workbench_minimum_pdf_bytes() -> Bytes {
  b"%PDF-1.4\n1 0 obj << /Type /Catalog /Pages 2 0 R >> endobj\n2 0 obj << /Type /Pages /Kids [3 0 R] /Count 1 >> endobj\n3 0 obj << /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >> endobj\ntrailer << /Root 1 0 R >>\n%%EOF\n"
}

///|
fn pdf_workbench_decode_sample(bytes : Bytes) -> String {
  let length = if bytes.length() > 8192 { 8192 } else { bytes.length() }
  @utf8.decode_lossy(bytes[:length], ignore_bom=true)
}

///|
fn pdf_workbench_pdf_version(sample : String) -> String {
  if sample.contains("%PDF-2.0") {
    "2.0"
  } else if sample.contains("%PDF-1.7") {
    "1.7"
  } else if sample.contains("%PDF-1.6") {
    "1.6"
  } else if sample.contains("%PDF-1.5") {
    "1.5"
  } else if sample.contains("%PDF-1.4") {
    "1.4"
  } else if sample.contains("%PDF-1.3") {
    "1.3"
  } else if sample.contains("%PDF-1.2") {
    "1.2"
  } else if sample.contains("%PDF-1.1") {
    "1.1"
  } else if sample.contains("%PDF-1.0") {
    "1.0"
  } else {
    "unknown"
  }
}

///|
fn pdf_workbench_estimated_page_count(sample : String) -> Int {
  let page_markers = pdf_workbench_count_occurrences(sample, "/Type /Page")
  let pages_markers = pdf_workbench_count_occurrences(sample, "/Type /Pages")
  let count = page_markers - pages_markers
  if count < 1 {
    1
  } else {
    count
  }
}

///|
fn pdf_workbench_page_summaries_from_sample(
  sample : String,
  page_count : Int,
) -> Array[PdfWorkbenchPageSummary] {
  let summaries : Array[PdfWorkbenchPageSummary] = []
  let version = pdf_workbench_pdf_version(sample)
  for page in 1..<=page_count {
    summaries.push({
      page_number: page,
      text_preview: "PDF page \{page} loaded. Lightweight shell detected PDF \{version}; use the pdflite adapter for extracted text.",
      content_diagnostic: "lightweight summary only; pdflite adapter owns precise text/content extraction",
    })
  }
  summaries
}

///|
fn pdf_workbench_empty_page_summaries(
  page_count : Int,
) -> Array[PdfWorkbenchPageSummary] {
  let summaries : Array[PdfWorkbenchPageSummary] = []
  for page in 1..<=page_count {
    summaries.push({
      page_number: page,
      text_preview: "No extracted text on this page",
      content_diagnostic: "no page summary available",
    })
  }
  summaries
}

///|
fn pdf_workbench_count_occurrences(haystack : String, needle : String) -> Int {
  let source = haystack.to_array()
  let pattern = needle.to_array()
  if pattern.is_empty() || source.length() < pattern.length() {
    return 0
  }
  let mut count = 0
  for index in 0..<=(source.length() - pattern.length()) {
    let mut matched = true
    for offset in 0..<pattern.length() {
      if source[index + offset] != pattern[offset] {
        matched = false
      }
    }
    if matched {
      count = count + 1
    }
  }
  count
}

///|
fn pdf_workbench_edit_diagnostic(edit : PdfWorkbenchEdit) -> String {
  match edit {
    RotatePage(page, degrees) =>
      "queued rotate page \{page} by \{degrees} degrees"
    CropPage(page, box) =>
      "queued crop page \{page} to [\{box.left}, \{box.bottom}, \{box.right}, \{box.top}]"
    StampText(page, value) => "queued stamp page \{page}: " + value
    SetMetadataTitle(value) => "queued metadata title: " + value
    AddBookmark(page, title) => "queued bookmark page \{page}: " + title
    AddTextAnnotation(page, text) =>
      "queued text annotation page \{page}: " + text
  }
}

///|
fn pdf_workbench_default_stamp_text() -> String {
  "REVIEWED"
}

///|
fn pdf_workbench_clamp_int(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}

///|
fn pdf_workbench_parse_positive_int(value : String) -> Int? {
  let chars = value.trim().to_owned().to_array()
  if chars.length() == 0 {
    return None
  }
  let mut parsed = 0
  for char in chars {
    if !char.is_ascii_digit() {
      return None
    }
    parsed = parsed * 10 + char.to_int() - '0'.to_int()
  }
  if parsed < 1 {
    None
  } else {
    Some(parsed)
  }
}

///|
fn pdf_workbench_file_name(path : String) -> String {
  let chars = path.to_array()
  let mut start = 0
  for index in 0..<chars.length() {
    if chars[index] == '/' || chars[index] == '\\' {
      start = index + 1
    }
  }
  String::from_array(chars[start:]).trim().to_owned()
}

///|
fn pdf_workbench_default_save_file_name(path : String) -> String {
  let name = pdf_workbench_file_name(path)
  if name == "" {
    "document.pdf"
  } else if pdf_workbench_ends_with_ignore_case(name, ".pdf") {
    name
  } else {
    name + ".pdf"
  }
}

///|
fn pdf_workbench_ends_with_ignore_case(value : String, suffix : String) -> Bool {
  let source = value.to_lower().to_array()
  let pattern = suffix.to_lower().to_array()
  if pattern.length() > source.length() {
    return false
  }
  let start = source.length() - pattern.length()
  for offset in 0..<pattern.length() {
    if source[start + offset] != pattern[offset] {
      return false
    }
  }
  true
}

///|
fn pdf_workbench_request_action(request : @host.HostServiceRequest) -> String {
  match request {
    @host.HostServiceRequest::FileDialog(_) => "choosing a PDF"
    @host.HostServiceRequest::BinaryFile(
      @host.HostBinaryFileRequest::ReadBytes(path)
    ) => "reading " + pdf_workbench_file_name(path)
    @host.HostServiceRequest::BinaryFile(
      @host.HostBinaryFileRequest::WriteBytes(path, _)
    ) => "writing " + pdf_workbench_file_name(path)
    _ => "handling host service"
  }
}

///|
fn pdf_workbench_unavailable_message(
  request : @host.HostServiceRequest,
  reason : String,
) -> String {
  match request {
    @host.HostServiceRequest::BinaryFile(
      @host.HostBinaryFileRequest::ReadBytes(path)
    ) => "Read failed for " + pdf_workbench_file_name(path) + ": " + reason
    @host.HostServiceRequest::BinaryFile(
      @host.HostBinaryFileRequest::WriteBytes(path, _)
    ) => "Write failed for " + pdf_workbench_file_name(path) + ": " + reason
    @host.HostServiceRequest::FileDialog(_) => "File dialog failed: " + reason
    _ => reason
  }
}

///|
fn pdf_workbench_pending_label(request : @host.HostServiceRequest) -> String {
  match request {
    @host.HostServiceRequest::FileDialog(_) => "PDF file dialog completion"
    @host.HostServiceRequest::BinaryFile(_) => "PDF binary file completion"
    _ => "PDF host service completion"
  }
}

///|
fn pdf_workbench_completion(
  request : @host.HostServiceRequest,
  response : @host.HostServiceResponse,
) -> @host.HostCompletedServiceResponse {
  let id = match response {
    @host.HostServiceResponse::Pending(id) => id
    _ => @host.HostServiceRequestId::new(0)
  }
  { id, request, response }
}
