///|
fn markdown_editor_wrap_selection_input(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> RichTextInputTransform? {
  if markdown_editor_any_code_block_at_content_offset(source, caret, selection) {
    return None
  }
  let marker = match input {
    "**" => "**"
    "__" => "__"
    "~~" => "~~"
    "`" => "`"
    "*" => "*"
    "_" => "_"
    _ => return None
  }
  match markdown_editor_active_selection(selection) {
    Some(range) => {
      let result = markdown_editor_toggle_inline_range(source, range, marker)
      Some(
        markdown_editor_transform_result(
          text=result.source,
          caret=result.caret,
          selection=result.selection,
        ),
      )
    }
    None => markdown_editor_pair_inline_marker_input(source, marker, caret)
  }
}

///|
fn markdown_editor_pair_inline_marker_input(
  source : String,
  marker : String,
  caret : Int,
) -> RichTextInputTransform? {
  if marker == "" || marker == "*" || marker == "_" {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  Some(
    markdown_editor_transform_result(
      text=String::from_array(chars[:caret]) +
        marker +
        marker +
        String::from_array(chars[caret:]),
      caret=caret + markdown_editor_text_length(marker),
    ),
  )
}

///|
fn markdown_editor_pair_delimiter_input(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> RichTextInputTransform? {
  if markdown_editor_any_code_block_at_content_offset(source, caret, selection) {
    return None
  }
  let close = match input {
    "(" => ")"
    "[" => "]"
    "{" => "}"
    "\"" => "\""
    "'" =>
      if markdown_editor_apostrophe_in_word(source, caret, selection) {
        return None
      } else {
        "'"
      }
    "`" => "`"
    _ => return None
  }
  let chars = source.to_array()
  match markdown_editor_active_selection(selection) {
    Some(range) => {
      let normalized = range.normalized()
      let text = String::from_array(chars[:normalized.start]) +
        input +
        String::from_array(chars[normalized.start:normalized.end]) +
        close +
        String::from_array(chars[normalized.end:])
      Some(
        markdown_editor_transform_result(
          text~,
          caret=normalized.end + markdown_editor_text_length(input),
          selection=Some(
            @core.TextRange::new(
              start=normalized.start + markdown_editor_text_length(input),
              end=normalized.end + markdown_editor_text_length(input),
            ),
          ),
        ),
      )
    }
    None => {
      let caret = markdown_editor_clamp_int(caret, 0, chars.length())
      let insert = input + close
      Some(
        markdown_editor_transform_result(
          text=String::from_array(chars[:caret]) +
            insert +
            String::from_array(chars[caret:]),
          caret=caret + markdown_editor_text_length(input),
        ),
      )
    }
  }
}

///|
fn markdown_editor_skip_closing_delimiter(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let close = match input {
    "**" => "**"
    "__" => "__"
    "~~" => "~~"
    "_" => "_"
    ")" => ")"
    "]" => "]"
    "}" => "}"
    "\"" => "\""
    "'" => "'"
    "`" => "`"
    _ => return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  if close == "_" {
    match markdown_editor_find_inline_opening_marker(chars, caret, close) {
      Some(open_start) =>
        if !markdown_editor_inline_marker_pair_supported(
            chars,
            open_start,
            markdown_editor_text_length(close),
            caret,
            close,
          ) {
          return None
        }
      None => return None
    }
  }
  if markdown_editor_source_has_marker(chars, caret, close) {
    Some(
      markdown_editor_transform_result(
        text=source,
        caret=caret + markdown_editor_text_length(close),
      ),
    )
  } else {
    None
  }
}

///|
fn markdown_editor_apostrophe_in_word(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> Bool {
  if markdown_editor_active_selection(selection) is Some(_) {
    return false
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  caret > 0 &&
  caret < chars.length() &&
  markdown_editor_ascii_word_char(chars[caret - 1]) &&
  markdown_editor_ascii_word_char(chars[caret])
}

///|
pub fn markdown_editor_ascii_word_char(ch : Char) -> Bool {
  (ch >= 'a' && ch <= 'z') ||
  (ch >= 'A' && ch <= 'Z') ||
  (ch >= '0' && ch <= '9') ||
  ch == '_'
}

///|
fn markdown_editor_backspace_empty_delimiter_pair(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  if caret <= 0 || caret >= chars.length() {
    return None
  }
  if !markdown_editor_empty_delimiter_pair_at(chars, caret) {
    return None
  }
  Some(
    markdown_editor_transform_result(
      text=String::from_array(chars[:caret - 1]) +
        String::from_array(chars[caret + 1:]),
      caret=caret - 1,
    ),
  )
}

///|
fn markdown_editor_empty_delimiter_pair_at(
  chars : Array[Char],
  caret : Int,
) -> Bool {
  if caret <= 0 || caret >= chars.length() {
    return false
  }
  let open = chars[caret - 1].to_int()
  let close = chars[caret].to_int()
  match open {
    40 => close == 41 // ()
    91 => close == 93 // []
    123 => close == 125 // {}
    34 => close == 34 // ""
    39 => close == 39 // ''
    96 => close == 96 // ``
    _ => false
  }
}

///|
fn markdown_editor_delete_empty_delimiter_pair(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  if caret + 1 >= chars.length() {
    return None
  }
  if !markdown_editor_empty_delimiter_pair_at(chars, caret + 1) {
    return None
  }
  Some(
    markdown_editor_transform_result(
      text=String::from_array(chars[:caret]) +
        String::from_array(chars[caret + 2:]),
      caret~,
    ),
  )
}

///|
fn markdown_editor_backspace_empty_inline_marker_pair(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  for marker in ["**", "__", "~~", "`"] {
    let marker_length = markdown_editor_text_length(marker)
    if caret >= marker_length &&
      markdown_editor_empty_inline_marker_pair_at(
        chars,
        caret - marker_length,
        marker,
      ) {
      return Some(
        markdown_editor_remove_empty_inline_marker_pair(
          chars,
          caret - marker_length,
          marker_length,
        ),
      )
    }
    if caret >= marker_length * 2 &&
      markdown_editor_empty_inline_marker_pair_at(
        chars,
        caret - marker_length * 2,
        marker,
      ) {
      return Some(
        markdown_editor_remove_empty_inline_marker_pair(
          chars,
          caret - marker_length * 2,
          marker_length,
        ),
      )
    }
  }
  None
}

///|
fn markdown_editor_delete_empty_inline_marker_pair(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
) -> RichTextInputTransform? {
  if markdown_editor_active_selection(selection) is Some(_) {
    return None
  }
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  for marker in ["**", "__", "~~", "`"] {
    let marker_length = markdown_editor_text_length(marker)
    if markdown_editor_empty_inline_marker_pair_at(chars, caret, marker) {
      return Some(
        markdown_editor_remove_empty_inline_marker_pair(
          chars, caret, marker_length,
        ),
      )
    }
    if caret >= marker_length &&
      markdown_editor_empty_inline_marker_pair_at(
        chars,
        caret - marker_length,
        marker,
      ) {
      return Some(
        markdown_editor_remove_empty_inline_marker_pair(
          chars,
          caret - marker_length,
          marker_length,
        ),
      )
    }
  }
  None
}

///|
fn markdown_editor_empty_inline_marker_pair_at(
  chars : Array[Char],
  open_start : Int,
  marker : String,
) -> Bool {
  let marker_length = markdown_editor_text_length(marker)
  open_start >= 0 &&
  markdown_editor_source_has_marker(chars, open_start, marker) &&
  markdown_editor_source_has_marker(chars, open_start + marker_length, marker)
}

///|
fn markdown_editor_remove_empty_inline_marker_pair(
  chars : Array[Char],
  open_start : Int,
  marker_length : Int,
) -> RichTextInputTransform {
  markdown_editor_transform_result(
    text=String::from_array(chars[:open_start]) +
      String::from_array(chars[open_start + marker_length * 2:]),
    caret=open_start,
  )
}

///|
fn markdown_editor_backspace_inline_marker(
  source : String,
  caret : Int,
) -> RichTextInputTransform? {
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  match markdown_editor_backspace_footnote_marker(chars, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match markdown_editor_backspace_autolink_marker(chars, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match markdown_editor_backspace_reference_marker(source, chars, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  for marker in ["**", "__", "~~", "`", "*", "_"] {
    let marker_length = markdown_editor_text_length(marker)
    if caret >= marker_length &&
      markdown_editor_source_has_marker(chars, caret - marker_length, marker) {
      match
        markdown_editor_find_inline_opening_marker(
          chars,
          caret - marker_length,
          marker,
        ) {
        Some(open_start) =>
          if markdown_editor_inline_marker_pair_supported(
              chars,
              open_start,
              marker_length,
              caret - marker_length,
              marker,
            ) {
            return Some(
              markdown_editor_remove_inline_marker_pair(
                chars,
                open_start,
                marker_length,
                caret - marker_length,
              ),
            )
          }
        None => ()
      }
      match markdown_editor_find_inline_closing_marker(chars, caret, marker) {
        Some(close_start) =>
          if markdown_editor_inline_marker_pair_supported(
              chars,
              caret - marker_length,
              marker_length,
              close_start,
              marker,
            ) {
            return Some(
              markdown_editor_remove_inline_marker_pair(
                chars,
                caret - marker_length,
                marker_length,
                close_start,
              ),
            )
          }
        None => ()
      }
    }
  }
  None
}

///|
fn markdown_editor_delete_inline_marker(
  source : String,
  chars : Array[Char],
  caret : Int,
) -> RichTextInputTransform? {
  match markdown_editor_delete_footnote_marker(chars, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match markdown_editor_delete_autolink_marker(chars, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  match markdown_editor_delete_reference_marker(source, chars, caret) {
    Some(transform) => return Some(transform)
    None => ()
  }
  for marker in ["**", "__", "~~", "`", "*", "_"] {
    let marker_length = markdown_editor_text_length(marker)
    if markdown_editor_source_has_marker(chars, caret, marker) {
      match
        markdown_editor_find_inline_closing_marker(
          chars,
          caret + marker_length,
          marker,
        ) {
        Some(close_start) =>
          if markdown_editor_inline_marker_pair_supported(
              chars, caret, marker_length, close_start, marker,
            ) {
            return Some(
              markdown_editor_remove_inline_marker_pair(
                chars, caret, marker_length, close_start,
              ),
            )
          }
        None => ()
      }
      match markdown_editor_find_inline_opening_marker(chars, caret, marker) {
        Some(open_start) =>
          if markdown_editor_inline_marker_pair_supported(
              chars, open_start, marker_length, caret, marker,
            ) {
            return Some(
              markdown_editor_remove_inline_marker_pair(
                chars, open_start, marker_length, caret,
              ),
            )
          }
        None => ()
      }
    }
  }
  None
}

///|
fn markdown_editor_source_has_marker(
  chars : Array[Char],
  start : Int,
  marker : String,
) -> Bool {
  let marker_chars = marker.to_array()
  if start < 0 || start + marker_chars.length() > chars.length() {
    return false
  }
  for index in 0..<marker_chars.length() {
    if chars[start + index] != marker_chars[index] {
      return false
    }
  }
  true
}

///|
fn markdown_editor_find_inline_closing_marker(
  chars : Array[Char],
  start : Int,
  marker : String,
) -> Int? {
  let marker_length = markdown_editor_text_length(marker)
  let mut index = start
  while index + marker_length <= chars.length() && chars[index] != '\n' {
    if markdown_editor_source_has_marker(chars, index, marker) {
      return Some(index)
    }
    index = index + 1
  }
  None
}

///|
fn markdown_editor_find_inline_opening_marker(
  chars : Array[Char],
  close_start : Int,
  marker : String,
) -> Int? {
  let marker_length = markdown_editor_text_length(marker)
  let mut index = close_start - marker_length
  while index >= 0 {
    if chars[index] == '\n' {
      return None
    }
    if markdown_editor_source_has_marker(chars, index, marker) {
      return Some(index)
    }
    index = index - 1
  }
  None
}

///|
fn markdown_editor_remove_inline_marker_pair(
  chars : Array[Char],
  open_start : Int,
  marker_length : Int,
  close_start : Int,
) -> RichTextInputTransform {
  let text = String::from_array(chars[:open_start]) +
    String::from_array(chars[open_start + marker_length:close_start]) +
    String::from_array(chars[close_start + marker_length:])
  markdown_editor_transform_result(text~, caret=open_start)
}

///|
fn markdown_editor_inline_marker_pair_supported(
  chars : Array[Char],
  open_start : Int,
  marker_length : Int,
  close_start : Int,
  marker : String,
) -> Bool {
  if marker != "_" {
    return true
  }
  let before_open_is_word = open_start > 0 &&
    markdown_editor_ascii_word_char(chars[open_start - 1])
  let after_close = close_start + marker_length
  let after_close_is_word = after_close < chars.length() &&
    markdown_editor_ascii_word_char(chars[after_close])
  !before_open_is_word && !after_close_is_word
}

///|
