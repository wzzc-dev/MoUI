/// Segment-based text storage: the single source of truth for a Markdown
/// editor document.
///
/// The document text lives in an array of contiguous segments; an edit
/// rewrites only the one or two segments the edit range spans and shifts
/// the offsets of the segments after it in place. The whole-source string
/// is a lazily materialized view, cached per revision, so a keystroke
/// costs O(edit-local) work instead of paying for a multi-megabyte
/// re-materialization (and every downstream full-document scan of one)
/// unless a reader actually asks for the whole text.
///
/// The store is mutated in place and shared by reference (every session
/// value derived from an edit carries the same `Ref`), mirroring the GPUI
/// adapter's in-place block-array reuse. Callers must not cache segment
/// data across an `edit`; read through `source`/`text_of` instead.

///|
/// Internal detail of `MarkdownDocumentTextStore`; public only because the
/// session (a `pub(all)` struct) transitively exposes the store. Do not
/// construct or mutate segments directly — go through the store API.
pub(all) struct MarkdownTextSegment {
  // Absolute char offsets, mutated in place when edits before shift the tail.
  mut start : Int
  mut end : Int
  mut text : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct MarkdownDocumentTextStore {
  // Contiguous, ascending segments covering the document: the first
  // starts at 0, each next starts where its predecessor ended. A segment
  // may only be empty when it is the sole content of an empty document.
  segments : Ref[Array[MarkdownTextSegment]]
  revision : Ref[Int]
  // (revision at which the joined text was cached, joined text).
  materialized : Ref[(Int, String)]
}

///|
/// Value semantics despite the shared mutable core: two stores are equal
/// when they hold the same text at the same revision (session values
/// derived from edits share one store; structurally equal documents in
/// different stores still compare equal).
pub impl Eq for MarkdownDocumentTextStore with fn equal(self, other) {
  self.revision.val == other.revision.val && self.source() == other.source()
}

///|
pub impl Debug for MarkdownDocumentTextStore with fn to_repr(self) {
  Repr::string(
    "MarkdownDocumentTextStore(revision=" +
    self.revision.val.to_string() +
    ", length=" +
    self.length().to_string() +
    ")",
  )
}

///|
pub impl ToJson for MarkdownDocumentTextStore with fn to_json(self) {
  self.source().to_json()
}

///|
pub fn MarkdownDocumentTextStore::new(
  text : String,
) -> MarkdownDocumentTextStore {
  let length = text.char_length()
  {
    segments: Ref([{ start: 0, end: length, text }]),
    revision: Ref(0),
    materialized: Ref((0, text)),
  }
}

///|
/// Seed the store from per-block texts (one segment per block, in order).
/// The whole document is not joined here — materialization stays lazy
/// until a reader asks for the whole text.
pub fn MarkdownDocumentTextStore::from_texts(
  texts : Array[String],
) -> MarkdownDocumentTextStore {
  let segments : Array[MarkdownTextSegment] = []
  let mut offset = 0
  for text in texts {
    let length = text.char_length()
    segments.push({ start: offset, end: offset + length, text })
    offset = offset + length
  }
  if segments.length() == 0 {
    segments.push({ start: 0, end: 0, text: "" })
  }
  { segments: Ref(segments), revision: Ref(0), materialized: Ref((-1, "")) }
}

///|
/// Segment the document once at (mostly ascending, non-negative) char
/// boundaries — typically the block starts, so every local read
/// (`text_of`, `char_at`) stays bounded by one block instead of the
/// document. One linear char pass over `source`; the materialized cache
/// is seeded with `source` itself, so the whole text stays free to read.
pub fn MarkdownDocumentTextStore::segmented(
  source : String,
  boundaries : Array[Int],
) -> MarkdownDocumentTextStore {
  let segments : Array[MarkdownTextSegment] = []
  let mut next = 0
  while next < boundaries.length() && boundaries[next] <= 0 {
    next = next + 1
  }
  let mut segment_start = 0
  let mut current = StringBuilder()
  let mut char_index = 0
  for ch in source {
    current.write_char(ch)
    char_index = char_index + 1
    if next < boundaries.length() && char_index == boundaries[next] {
      segments.push({
        start: segment_start,
        end: char_index,
        text: current.to_string(),
      })
      segment_start = char_index
      current = StringBuilder()
      next = next + 1
      while next < boundaries.length() && boundaries[next] <= char_index {
        next = next + 1
      }
    }
  }
  segments.push({
    start: segment_start,
    end: char_index,
    text: current.to_string(),
  })
  { segments: Ref(segments), revision: Ref(0), materialized: Ref((0, source)) }
}

///|
/// Rebuild the store in place from a whole new text (open, undo restore,
/// external replace). The previous contents are dropped entirely.
pub fn MarkdownDocumentTextStore::replace_all(
  self : MarkdownDocumentTextStore,
  text : String,
) -> Unit {
  let length = text.char_length()
  self.segments.val = [{ start: 0, end: length, text }]
  self.revision.val = self.revision.val + 1
  self.materialized.val = (self.revision.val, text)
}

///|
pub fn MarkdownDocumentTextStore::revision(
  self : MarkdownDocumentTextStore,
) -> Int {
  self.revision.val
}

///|
/// Char length of the document. O(1) — the tail segment carries the end.
pub fn MarkdownDocumentTextStore::length(
  self : MarkdownDocumentTextStore,
) -> Int {
  let segments = self.segments.val
  if segments.length() == 0 {
    0
  } else {
    segments[segments.length() - 1].end
  }
}

///|
/// The whole document text: cached across reads of the same revision, so
/// the single join per revision is the only materialization cost.
pub fn MarkdownDocumentTextStore::source(
  self : MarkdownDocumentTextStore,
) -> String {
  let revision = self.revision.val
  let cached = self.materialized.val
  if cached.0 == revision {
    cached.1
  } else {
    let mut joined = ""
    for segment in self.segments.val {
      joined = joined + segment.text
    }
    self.materialized.val = (revision, joined)
    joined
  }
}

///|
/// Adopt an already-materialized whole text (a caller — typically the
/// editing control — just produced exactly this revision's full string).
/// Records it as the cache without copying or joining; segment reads
/// still go through the segment array.
pub fn MarkdownDocumentTextStore::seed(
  self : MarkdownDocumentTextStore,
  text : String,
) -> Unit {
  self.materialized.val = (self.revision.val, text)
}

///|
/// Char at a char-space offset, resolved through the segment index: a
/// binary search plus a scan bounded by the containing segment, never by
/// the document.
pub fn MarkdownDocumentTextStore::char_at(
  self : MarkdownDocumentTextStore,
  index : Int,
) -> Char? {
  let segments = self.segments.val
  if index < 0 {
    return None
  }
  let segment_index = markdown_text_store_segment_index(segments, index)
  if segment_index >= segments.length() {
    return None
  }
  let segment = segments[segment_index]
  let mut char_index = segment.start
  for ch in segment.text {
    if char_index == index {
      return Some(ch)
    }
    char_index = char_index + 1
  }
  None
}

///|
/// Index of the first segment whose `end` is past `offset`; returns
/// `segments.length()` when `offset` sits at (or past) the document end.
fn markdown_text_store_segment_index(
  segments : Array[MarkdownTextSegment],
  offset : Int,
) -> Int {
  let mut low = 0
  let mut high = segments.length()
  while low < high {
    let mid = (low + high) / 2
    if segments[mid].end <= offset {
      low = mid + 1
    } else {
      high = mid
    }
  }
  low
}

///|
/// Slice `segment`'s text between the absolute char offsets `from`..`to`.
/// The char→unit mapping scan stays inside one segment, so it is bounded
/// by the segment, not by the document.
fn markdown_text_segment_slice(
  segment : MarkdownTextSegment,
  from : Int,
  to : Int,
) -> String {
  let text = segment.text
  if from <= segment.start && to >= segment.end {
    return text
  }
  if to <= from || segment.end <= segment.start {
    return ""
  }
  let mut unit_start = 0
  let mut unit_end = text.length()
  let mut char_index = segment.start
  let mut units = 0
  for ch in text {
    if char_index == from {
      unit_start = units
    }
    if char_index == to {
      unit_end = units
      break
    }
    units = units + ch.utf16_len()
    char_index = char_index + 1
  }
  text.sub(start=unit_start, end=unit_end).to_owned()
}

///|
/// Text between two char offsets, read through the segment array. Used by
/// block materialization and other local reads that must not materialize
/// the whole document.
pub fn MarkdownDocumentTextStore::text_of(
  self : MarkdownDocumentTextStore,
  start : Int,
  end : Int,
) -> String {
  let segments = self.segments.val
  if end <= start || segments.length() == 0 {
    return ""
  }
  let first = markdown_text_store_segment_index(segments, start)
  if first >= segments.length() {
    return ""
  }
  if segments[first].start <= start && segments[first].end >= end {
    return markdown_text_segment_slice(segments[first], start, end)
  }
  let mut out = ""
  let mut index = first
  while index < segments.length() && segments[index].start < end {
    let segment = segments[index]
    let from = markdown_editor_max_int(start, segment.start)
    let to = markdown_editor_min_int(end, segment.end)
    if to > from {
      out = out + markdown_text_segment_slice(segment, from, to)
    }
    index = index + 1
  }
  out
}

///|
/// Apply an edit in place: splice the segments the range spans into a
/// single rewritten segment, shift the offsets of every segment after the
/// edit by the char delta (in place, texts untouched), bump the revision,
/// and invalidate the materialization cache. `range` and `replacement`
/// mirror a `MarkdownEditTransaction`: char offsets into the pre-edit
/// text.
pub fn MarkdownDocumentTextStore::edit(
  self : MarkdownDocumentTextStore,
  range : MarkdownSourceRange,
  replacement : String,
) -> Unit {
  let segments = self.segments.val
  let document_end = self.length()
  let start = markdown_editor_clamp_int(range.start, 0, document_end)
  let end = markdown_editor_clamp_int(
    markdown_editor_max_int(range.end, start),
    start,
    document_end,
  )
  let replacement_length = replacement.char_length()
  let delta = replacement_length - (end - start)
  if segments.length() == 0 {
    self.segments.val = [
      { start: 0, end: replacement_length, text: replacement },
    ]
  } else if start >= segments[segments.length() - 1].end {
    // Edit at (or past) the document end: extend the tail segment.
    let last = segments[segments.length() - 1]
    last.text = markdown_text_segment_slice(last, last.start, start) +
      replacement
    last.end = start + replacement_length
  } else {
    let first = markdown_text_store_segment_index(segments, start)
    let mut last = first
    while last + 1 < segments.length() && segments[last + 1].start < end {
      last = last + 1
    }
    if last == first {
      // Fast path for the dominant keystroke case: the edit stays inside
      // one segment, so rewrite that segment in place and shift the tail
      // offsets in place — no fresh segment array, no per-segment re-push.
      let segment = segments[first]
      let head = markdown_text_segment_slice(segment, segment.start, start)
      let tail = markdown_text_segment_slice(segment, end, segment.end)
      segment.text = head + replacement + tail
      segment.end = segment.start +
        (start - segment.start) +
        replacement_length +
        (segment.end - end)
      if delta != 0 {
        for index = first + 1; index < segments.length(); index = index + 1 {
          let after = segments[index]
          after.start = after.start + delta
          after.end = after.end + delta
        }
      }
    } else {
      let head = markdown_text_segment_slice(
        segments[first],
        segments[first].start,
        start,
      )
      let tail = markdown_text_segment_slice(
        segments[last],
        end,
        segments[last].end,
      )
      // The spliced segment replaces segments first..last wholesale: it
      // spans head (text kept before the edit) + replacement + tail (text
      // kept after it), starting where the first replaced segment started.
      let spliced_start = segments[first].start
      let spliced : MarkdownTextSegment = {
        start: spliced_start,
        end: spliced_start +
        (start - spliced_start) +
        replacement_length +
        (segments[last].end - end),
        text: head + replacement + tail,
      }
      let next : Array[MarkdownTextSegment] = []
      for index in 0..<first {
        next.push(segments[index])
      }
      next.push(spliced)
      for index = last + 1; index < segments.length(); index = index + 1 {
        let segment = segments[index]
        segment.start = segment.start + delta
        segment.end = segment.end + delta
        next.push(segment)
      }
      self.segments.val = next
    }
  }
  self.revision.val = self.revision.val + 1
}
