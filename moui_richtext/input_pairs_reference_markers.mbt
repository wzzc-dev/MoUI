///|
fn markdown_editor_delete_reference_marker(
  source : String,
  chars : Array[Char],
  caret : Int,
) -> RichTextInputTransform? {
  if caret >= chars.length() {
    return None
  }
  if chars[caret] == '[' ||
    (
      chars[caret] == '!' &&
      caret + 1 < chars.length() &&
      chars[caret + 1] == '['
    ) {
    let content_start = if chars[caret] == '!' { caret + 2 } else { caret + 1 }
    match markdown_editor_reference_close_after(source, chars, content_start) {
      Some(bounds) =>
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            bounds.open_start,
            content_start,
            bounds.close_start,
            bounds.target_end,
          ),
        )
      None => ()
    }
  }
  if chars[caret] != ']' {
    return None
  }
  match markdown_editor_reference_open_before(source, chars, caret) {
    Some(bounds) => {
      let mut content_start = bounds.open_start + 1
      if chars[bounds.open_start] == '!' {
        content_start = bounds.open_start + 2
      }
      Some(
        markdown_editor_remove_reference_marker(
          chars,
          bounds.open_start,
          content_start,
          caret,
          bounds.target_end,
        ),
      )
    }
    None => None
  }
}

///|
fn markdown_editor_reference_open_before(
  source : String,
  chars : Array[Char],
  close_start : Int,
) -> MarkdownLinkBounds? {
  if close_start >= chars.length() || chars[close_start] != ']' {
    return None
  }
  let mut open_start = close_start
  while open_start > 0 &&
        chars[open_start - 1] != '[' &&
        chars[open_start - 1] != '\n' {
    open_start = open_start - 1
  }
  if open_start == 0 || chars[open_start - 1] != '[' {
    return None
  }
  let bracket_start = open_start - 1
  let open_start = if bracket_start > 0 && chars[bracket_start - 1] == '!' {
    bracket_start - 1
  } else {
    bracket_start
  }
  let content_start = bracket_start + 1
  let target = match
    markdown_editor_reference_marker_target_after(
      source, chars, close_start, content_start,
    ) {
    Some(target) => target
    None => return None
  }
  Some({
    open_start,
    close_start,
    target_start: target.start,
    target_end: target.end,
    definition_target_start: -1,
    definition_target_end: -1,
    reference_label: target.label,
  })
}

///|
fn markdown_editor_backspace_reference_marker(
  source : String,
  chars : Array[Char],
  caret : Int,
) -> RichTextInputTransform? {
  if caret > 0 {
    match
      markdown_editor_reference_bounds_full_end_before(source, chars, caret) {
      Some(bounds) => {
        let mut content_start = bounds.open_start + 1
        if chars[bounds.open_start] == '!' {
          content_start = bounds.open_start + 2
        }
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            bounds.open_start,
            content_start,
            bounds.close_start,
            bounds.target_end,
          ),
        )
      }
      None => ()
    }
  }
  if caret >= 2 && chars[caret - 2] == '!' && chars[caret - 1] == '[' {
    match markdown_editor_reference_close_after(source, chars, caret) {
      Some(bounds) =>
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            caret - 2,
            caret,
            bounds.close_start,
            bounds.target_end,
          ),
        )
      None => ()
    }
  }
  if caret >= 1 && chars[caret - 1] == '[' {
    match markdown_editor_reference_close_after(source, chars, caret) {
      Some(bounds) =>
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            caret - 1,
            caret,
            bounds.close_start,
            bounds.target_end,
          ),
        )
      None => ()
    }
  }
  None
}

///|
fn markdown_editor_reference_bounds_full_end_before(
  source : String,
  chars : Array[Char],
  caret : Int,
) -> MarkdownLinkBounds? {
  if caret <= 0 {
    return None
  }
  let end = caret - 1
  if chars[end] == ')' {
    let mut open = end
    while open > 0 && chars[open - 1] != '(' && chars[open - 1] != '\n' {
      open = open - 1
    }
    if open <= 0 || chars[open - 1] != '(' {
      return None
    }
    let close_start = open - 2
    if close_start < 0 || chars[close_start] != ']' {
      return None
    }
    match markdown_editor_reference_open_before(source, chars, close_start) {
      Some(bounds) => if bounds.target_end == end { Some(bounds) } else { None }
      None => None
    }
  } else if chars[end] == ']' {
    let mut label_open = end
    while label_open > 0 &&
          chars[label_open - 1] != '[' &&
          chars[label_open - 1] != '\n' {
      label_open = label_open - 1
    }
    if label_open <= 0 || chars[label_open - 1] != '[' {
      return None
    }
    let close_start = if label_open >= 2 && chars[label_open - 2] == ']' {
      label_open - 2
    } else {
      end
    }
    match markdown_editor_reference_open_before(source, chars, close_start) {
      Some(bounds) => if bounds.target_end == end { Some(bounds) } else { None }
      None => None
    }
  } else {
    None
  }
}

///|
fn markdown_editor_reference_close_after(
  source : String,
  chars : Array[Char],
  content_start : Int,
) -> MarkdownLinkBounds? {
  let mut close_start = content_start
  while close_start < chars.length() &&
        chars[close_start] != ']' &&
        chars[close_start] != '\n' {
    close_start = close_start + 1
  }
  if close_start >= chars.length() || chars[close_start] != ']' {
    return None
  }
  let open_start = if content_start >= 2 &&
    chars[content_start - 2] == '!' &&
    chars[content_start - 1] == '[' {
    content_start - 2
  } else {
    content_start - 1
  }
  let target = match
    markdown_editor_reference_marker_target_after(
      source, chars, close_start, content_start,
    ) {
    Some(target) => target
    None => return None
  }
  Some({
    open_start,
    close_start,
    target_start: target.start,
    target_end: target.end,
    definition_target_start: -1,
    definition_target_end: -1,
    reference_label: target.label,
  })
}

///|
priv struct MarkdownEditorReferenceMarkerTarget {
  start : Int
  end : Int
  label : String
}

///|
fn markdown_editor_reference_marker_target_after(
  source : String,
  chars : Array[Char],
  close_start : Int,
  content_start : Int,
) -> MarkdownEditorReferenceMarkerTarget? {
  if close_start + 1 < chars.length() && chars[close_start + 1] == '(' {
    let mut target_end = close_start + 2
    while target_end < chars.length() &&
          chars[target_end] != ')' &&
          chars[target_end] != '\n' {
      target_end = target_end + 1
    }
    if target_end < chars.length() && chars[target_end] == ')' {
      Some({ start: close_start + 2, end: target_end, label: "" })
    } else {
      None
    }
  } else if close_start + 1 < chars.length() && chars[close_start + 1] == '[' {
    let mut target_end = close_start + 2
    while target_end < chars.length() &&
          chars[target_end] != ']' &&
          chars[target_end] != '\n' {
      target_end = target_end + 1
    }
    if target_end < chars.length() && chars[target_end] == ']' {
      Some({
        start: close_start + 2,
        end: target_end,
        label: String::from_array(chars[close_start + 2:target_end]),
      })
    } else {
      None
    }
  } else {
    let label = String::from_array(chars[content_start:close_start])
    if label == "" ||
      markdown_editor_reference_definition_target_range(source, label) is None {
      None
    } else {
      Some({ start: close_start, end: close_start, label })
    }
  }
}

///|
fn markdown_editor_remove_reference_marker(
  chars : Array[Char],
  open_start : Int,
  content_start : Int,
  close_start : Int,
  target_end : Int,
) -> RichTextInputTransform {
  let text = String::from_array(chars[:open_start]) +
    String::from_array(chars[content_start:close_start]) +
    String::from_array(chars[target_end + 1:])
  markdown_editor_transform_result(text~, caret=open_start)
}
