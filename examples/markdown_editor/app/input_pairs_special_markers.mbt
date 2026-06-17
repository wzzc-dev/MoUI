///|
fn markdown_editor_backspace_footnote_marker(
  chars : Array[Char],
  caret : Int,
) -> @views.RichTextInputTransform? {
  if caret <= 0 {
    return None
  }
  if caret >= 2 && chars[caret - 2] == '[' && chars[caret - 1] == '^' {
    match markdown_editor_footnote_close_after(chars, caret) {
      Some(close_start) =>
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            caret - 2,
            caret,
            close_start,
            close_start,
          ),
        )
      None => ()
    }
  }
  if chars[caret - 1] == ']' {
    match markdown_editor_footnote_open_before(chars, caret - 1) {
      Some(open_start) =>
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            open_start,
            open_start + 2,
            caret - 1,
            caret - 1,
          ),
        )
      None => ()
    }
  }
  None
}

///|
fn markdown_editor_delete_footnote_marker(
  chars : Array[Char],
  caret : Int,
) -> @views.RichTextInputTransform? {
  if caret >= chars.length() {
    return None
  }
  if chars[caret] == '[' &&
    caret + 1 < chars.length() &&
    chars[caret + 1] == '^' {
    match markdown_editor_footnote_close_after(chars, caret + 2) {
      Some(close_start) =>
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            caret,
            caret + 2,
            close_start,
            close_start,
          ),
        )
      None => ()
    }
  }
  if chars[caret] == ']' {
    match markdown_editor_footnote_open_before(chars, caret) {
      Some(open_start) =>
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            open_start,
            open_start + 2,
            caret,
            caret,
          ),
        )
      None => ()
    }
  }
  None
}

///|
fn markdown_editor_footnote_close_after(
  chars : Array[Char],
  content_start : Int,
) -> Int? {
  let mut close_start = content_start
  while close_start < chars.length() &&
        chars[close_start] != ']' &&
        chars[close_start] != '\n' {
    close_start = close_start + 1
  }
  if close_start <= content_start ||
    close_start >= chars.length() ||
    chars[close_start] != ']' {
    None
  } else {
    Some(close_start)
  }
}

///|
fn markdown_editor_footnote_open_before(
  chars : Array[Char],
  close_start : Int,
) -> Int? {
  if close_start >= chars.length() || chars[close_start] != ']' {
    return None
  }
  let mut content_start = close_start
  while content_start > 0 &&
        chars[content_start - 1] != '[' &&
        chars[content_start - 1] != '\n' {
    content_start = content_start - 1
  }
  if content_start <= 0 || chars[content_start - 1] != '[' {
    return None
  }
  let open_start = content_start - 1
  if content_start >= close_start ||
    content_start >= chars.length() ||
    chars[content_start] != '^' ||
    content_start + 1 >= close_start {
    None
  } else {
    Some(open_start)
  }
}

///|
fn markdown_editor_backspace_autolink_marker(
  chars : Array[Char],
  caret : Int,
) -> @views.RichTextInputTransform? {
  if caret <= 0 {
    return None
  }
  if chars[caret - 1] == '>' {
    match markdown_editor_autolink_open_before(chars, caret - 1) {
      Some(open_start) =>
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            open_start,
            open_start + 1,
            caret - 1,
            caret - 1,
          ),
        )
      None => ()
    }
  }
  if chars[caret - 1] == '<' {
    match markdown_editor_autolink_close_after(chars, caret) {
      Some(close_start) =>
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            caret - 1,
            caret,
            close_start,
            close_start,
          ),
        )
      None => ()
    }
  }
  None
}

///|
fn markdown_editor_delete_autolink_marker(
  chars : Array[Char],
  caret : Int,
) -> @views.RichTextInputTransform? {
  if caret >= chars.length() {
    return None
  }
  if chars[caret] == '<' {
    match markdown_editor_autolink_close_after(chars, caret + 1) {
      Some(close_start) =>
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            caret,
            caret + 1,
            close_start,
            close_start,
          ),
        )
      None => ()
    }
  }
  if chars[caret] == '>' {
    match markdown_editor_autolink_open_before(chars, caret) {
      Some(open_start) =>
        return Some(
          markdown_editor_remove_reference_marker(
            chars,
            open_start,
            open_start + 1,
            caret,
            caret,
          ),
        )
      None => ()
    }
  }
  None
}

///|
fn markdown_editor_autolink_close_after(
  chars : Array[Char],
  content_start : Int,
) -> Int? {
  let mut close = content_start
  while close < chars.length() && chars[close] != '>' && chars[close] != '\n' {
    close = close + 1
  }
  if close >= chars.length() || chars[close] != '>' {
    return None
  }
  let target = String::from_array(chars[content_start:close])
  if markdown_editor_is_autolink_target(target) {
    Some(close)
  } else {
    None
  }
}

///|
fn markdown_editor_autolink_open_before(
  chars : Array[Char],
  close_start : Int,
) -> Int? {
  let mut open = close_start
  while open > 0 && chars[open - 1] != '<' && chars[open - 1] != '\n' {
    open = open - 1
  }
  if open <= 0 || chars[open - 1] != '<' {
    return None
  }
  let target = String::from_array(chars[open:close_start])
  if markdown_editor_is_autolink_target(target) {
    Some(open - 1)
  } else {
    None
  }
}
