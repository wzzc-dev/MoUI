///|
/// Outline helpers for Markdown documents: foldable outline filtering,
/// labels, indent geometry, active-heading tracking, and reading labels.
/// Extracted from MoMark's app layer.

///|
/// Filter outline items to honor folded headings: a folded heading hides all
/// subsequent items until the next heading at the same or higher level.
pub fn markdown_folded_outline(
  items : Array[@richtext.MarkdownEditorOutlineItem],
  folded_starts : Array[Int],
) -> Array[@richtext.MarkdownEditorOutlineItem] {
  if folded_starts.length() == 0 {
    return items
  }
  let visible : Array[@richtext.MarkdownEditorOutlineItem] = []
  let mut hide_until_level : Int? = None
  for item in items {
    match hide_until_level {
      Some(limit) =>
        if item.level <= limit {
          // Reached a same-or-higher heading: stop hiding.
          hide_until_level = None
          visible.push(item)
          if folded_starts.contains(item.source_start) {
            hide_until_level = Some(item.level)
          }
        } else {
          // Still inside a folded region: skip this nested item.
          ()
        }
      None => {
        visible.push(item)
        if folded_starts.contains(item.source_start) {
          hide_until_level = Some(item.level)
        }
      }
    }
  }
  visible
}

///|
/// The indent width in points for a heading at `level` (12pt per level
/// below the first).
pub fn markdown_outline_indent_width(level : Int) -> Double {
  @richtext.markdown_editor_max_int(0, level - 1).to_double() * 12.0
}

///|
/// The bounded outline label for an item, e.g. "H2 Install". Titles longer
/// than 24 characters are truncated to 21 + "..."; empty titles become
/// "Untitled".
pub fn markdown_outline_label(
  item : @richtext.MarkdownEditorOutlineItem,
) -> String {
  let title = if item.title == "" { "Untitled" } else { item.title }
  "H" + item.level.to_string() + " " + markdown_outline_truncate_title(title)
}

///|
/// Truncate a heading title to the outline label budget.
pub fn markdown_outline_truncate_title(title : String) -> String {
  if @richtext.markdown_editor_text_length(title) <= 24 {
    title
  } else {
    @richtext.markdown_editor_substring(title, 0, 21) + "..."
  }
}

///|
/// The index of the outline item containing `caret` (the last heading whose
/// source start is at or before the caret), or -1 when no heading precedes it.
pub fn markdown_active_outline_index(
  outline : Array[@richtext.MarkdownEditorOutlineItem],
  caret : Int,
) -> Int {
  let mut active = -1
  for index in 0..<outline.length() {
    if outline[index].source_start <= caret {
      active = index
    }
  }
  active
}

///|
/// True when `item` is the outline entry at `active_index` in `full_outline`
/// (identity by source start, so folding keeps the highlight attached).
pub fn markdown_outline_item_is_active(
  full_outline : Array[@richtext.MarkdownEditorOutlineItem],
  item : @richtext.MarkdownEditorOutlineItem,
  active_index : Int,
) -> Bool {
  if active_index < 0 || active_index >= full_outline.length() {
    false
  } else {
    full_outline[active_index].source_start == item.source_start
  }
}

///|
/// "N words / M lines / T min" reading label from a session.
pub fn markdown_session_reading_label(
  session : @richtext.MarkdownDocumentSession,
) -> String {
  markdown_reading_label_parts(
    session.word_count,
    session.line_count,
    session.reading_minutes,
  )
}

///|
/// "N words / M lines / T min" reading label from a snapshot.
pub fn markdown_snapshot_reading_label(
  snapshot : @richtext.MarkdownEditorSnapshot,
) -> String {
  markdown_reading_label_parts(
    snapshot.word_count,
    snapshot.line_count,
    snapshot.reading_minutes,
  )
}

///|
fn markdown_reading_label_parts(
  word_count : Int,
  line_count : Int,
  reading_minutes : Int,
) -> String {
  let minutes = if reading_minutes == 0 {
    "less than 1 min"
  } else if reading_minutes == 1 {
    "1 min"
  } else {
    reading_minutes.to_string() + " min"
  }
  "\{word_count} words / \{line_count} lines / " + minutes
}

///|
/// The compact reading reference ("<1 min"/"1 min"/"N min") from a session.
pub fn markdown_session_reading_time_short_label(
  session : @richtext.MarkdownDocumentSession,
) -> String {
  markdown_reading_time_short_label(session.reading_minutes)
}

///|
/// The compact reading reference from a snapshot.
pub fn markdown_snapshot_reading_time_short_label(
  snapshot : @richtext.MarkdownEditorSnapshot,
) -> String {
  markdown_reading_time_short_label(snapshot.reading_minutes)
}

///|
fn markdown_reading_time_short_label(reading_minutes : Int) -> String {
  if reading_minutes == 0 {
    "<1 min"
  } else if reading_minutes == 1 {
    "1 min"
  } else {
    reading_minutes.to_string() + " min"
  }
}
