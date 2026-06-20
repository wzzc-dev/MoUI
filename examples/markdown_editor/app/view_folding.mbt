///|
/// Toggle the folded state of a heading identified by its source start offset.
/// In the outline panel, a folded heading hides its nested sub-headings (those
/// at a deeper level), matching Typora's foldable outline. The editor body
/// itself is unaffected; folding is an outline-navigation aid.
fn MarkdownEditorApp::toggle_heading_fold(
  self : MarkdownEditorApp,
  source_start : Int,
) -> Unit {
  let folded = self.folded_headings.get()
  let next : Array[Int] = []
  let mut found = false
  for offset in folded {
    if offset == source_start {
      found = true
    } else {
      next.push(offset)
    }
  }
  if !found {
    next.push(source_start)
  }
  self.folded_headings.set(next)
}

///|
/// True when a heading at `source_start` is currently folded in the outline.
fn MarkdownEditorApp::heading_is_folded(
  self : MarkdownEditorApp,
  source_start : Int,
) -> Bool {
  self.folded_headings.get().contains(source_start)
}

///|
/// Filter the outline items to honor folded headings. A folded heading hides
/// all subsequent outline items until the next heading at the same or higher
/// level (i.e. its nested children).
fn markdown_editor_folded_outline(
  items : Array[MarkdownEditorOutlineItem],
  folded_starts : Array[Int],
) -> Array[MarkdownEditorOutlineItem] {
  if folded_starts.length() == 0 {
    return items
  }
  let visible : Array[MarkdownEditorOutlineItem] = []
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
