///|
fn markdown_editor_transform_multiline_paste(
  source : String,
  caret : Int,
  selection : @core.TextRange?,
  input : String,
) -> RichTextInputTransform? {
  match markdown_editor_active_selection(selection) {
    Some(_) => None
    None => {
      let current : MarkdownEditorSelection = { caret, selection }
      let range = markdown_editor_current_line_range(source, current)
      let chars = source.to_array()
      let line = String::from_array(chars[range.start:range.end])
      let insert = match
        markdown_editor_code_block_at_content_offset(source, caret, selection) {
        Some(_) => markdown_editor_code_block_paste_insert(source, caret, input)
        None =>
          match
            markdown_editor_quoted_code_block_at_content_offset(
              source, caret, selection,
            ) {
            Some(block) =>
              markdown_editor_quoted_code_block_paste_insert(
                source, block, caret, input,
              )
            None => markdown_editor_contextual_paste_insert(line, input)
          }
      }
      if insert == input {
        None
      } else {
        let caret = markdown_editor_clamp_int(caret, 0, chars.length())
        Some(
          markdown_editor_transform_result(
            text=String::from_array(chars[:caret]) +
              insert +
              String::from_array(chars[caret:]),
            caret=caret + markdown_editor_text_length(insert),
          ),
        )
      }
    }
  }
}

///|
fn markdown_editor_code_block_paste_insert(
  source : String,
  caret : Int,
  input : String,
) -> String {
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  let line_start = markdown_editor_line_start(chars, caret)
  let indent = markdown_editor_line_indent(chars, line_start, caret)
  markdown_editor_join_paste_lines(
    markdown_editor_prefix_paste_continuation_lines(input, indent),
  )
}

///|
fn markdown_editor_quoted_code_block_paste_insert(
  source : String,
  block : MarkdownEditorQuotedCodeBlock,
  caret : Int,
  input : String,
) -> String {
  let chars = source.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  let current_line = markdown_editor_current_line_range(source, {
    caret,
    selection: None,
  })
  let line = String::from_array(chars[current_line.start:current_line.end])
  let prefix = match markdown_editor_quoted_code_content_prefix(line) {
    Some(prefix) => prefix
    None =>
      markdown_editor_quoted_code_block_opening_content_prefix(source, block)
  }
  markdown_editor_join_paste_lines(
    markdown_editor_prefix_paste_continuation_lines(input, prefix),
  )
}

///|
fn markdown_editor_contextual_paste_insert(
  line : String,
  input : String,
) -> String {
  if markdown_editor_continuation_marker(line) == "" {
    return input
  }
  let continuation = markdown_editor_continuation_marker(line)
  let lines = markdown_editor_paste_lines(input)
  let formatted : Array[String] = []
  let mut ordered_number = markdown_editor_ordered_continuation_number(line)
  for index in 0..<lines.length() {
    if index == 0 {
      formatted.push(lines[index])
      continue
    }
    let stripped = markdown_editor_strip_block_marker(lines[index])
    if stripped.trim().to_owned() == "" {
      formatted.push(markdown_editor_blank_paste_continuation_prefix(line))
      continue
    }
    if markdown_editor_line_indent_prefix_length(lines[index]) > 0 {
      formatted.push(markdown_editor_quote_context_prefix(line) + lines[index])
      continue
    }
    let prefix = if ordered_number > 0 {
      let marker = markdown_editor_ordered_paste_prefix(line, ordered_number)
      ordered_number = ordered_number + 1
      marker
    } else {
      continuation
    }
    formatted.push(prefix + stripped)
  }
  markdown_editor_join_paste_lines(formatted)
}

///|
fn markdown_editor_quote_context_prefix(line : String) -> String {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  if chars.length() >= indent + 2 &&
    chars[indent] == '>' &&
    chars[indent + 1] == ' ' {
    String::from_array(chars[:indent + 2]) +
    markdown_editor_quote_context_prefix(String::from_array(chars[indent + 2:]))
  } else {
    ""
  }
}

///|
fn markdown_editor_blank_paste_continuation_prefix(line : String) -> String {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  if chars.length() >= indent + 2 &&
    chars[indent] == '>' &&
    chars[indent + 1] == ' ' {
    return String::from_array(chars[:indent + 2]) +
      markdown_editor_blank_paste_continuation_prefix(
        String::from_array(chars[indent + 2:]),
      )
  }
  ""
}

///|
fn markdown_editor_ordered_continuation_number(line : String) -> Int {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  if chars.length() >= indent + 2 &&
    chars[indent] == '>' &&
    chars[indent + 1] == ' ' {
    return markdown_editor_ordered_continuation_number(
      String::from_array(chars[indent + 2:]),
    )
  }
  if markdown_editor_ordered_marker_length(chars) > 0 {
    markdown_editor_parse_digits(
      chars,
      indent,
      markdown_editor_ordered_digit_end(chars),
    ) +
    1
  } else {
    0
  }
}

///|
fn markdown_editor_ordered_paste_prefix(line : String, number : Int) -> String {
  let chars = line.to_array()
  let indent = markdown_editor_leading_indent_length(chars)
  if chars.length() >= indent + 2 &&
    chars[indent] == '>' &&
    chars[indent + 1] == ' ' {
    return String::from_array(chars[:indent + 2]) +
      markdown_editor_ordered_paste_prefix(
        String::from_array(chars[indent + 2:]),
        number,
      )
  }
  String::from_array(chars[:indent]) + number.to_string() + ". "
}

///|
fn markdown_editor_ordered_digit_end(chars : Array[Char]) -> Int {
  let mut index = markdown_editor_leading_indent_length(chars)
  while index < chars.length() && chars[index].is_ascii_digit() {
    index = index + 1
  }
  index
}

///|
fn markdown_editor_paste_lines(input : String) -> Array[String] {
  let lines = markdown_editor_lines(
    markdown_editor_trim_trailing_newline(input),
  )
  let result : Array[String] = []
  for line in lines {
    result.push(line.text.to_owned())
  }
  result
}

///|
fn markdown_editor_prefix_paste_continuation_lines(
  input : String,
  prefix : String,
) -> Array[String] {
  let lines = markdown_editor_paste_lines(input)
  let result : Array[String] = []
  for index in 0..<lines.length() {
    if index == 0 {
      result.push(lines[index])
    } else {
      result.push(prefix + lines[index])
    }
  }
  result
}

///|
fn markdown_editor_join_paste_lines(lines : Array[String]) -> String {
  markdown_join_lines(lines)
}

///|
fn markdown_editor_trim_trailing_newline(input : String) -> String {
  let chars = input.to_array()
  if chars.length() > 0 && chars[chars.length() - 1] == '\n' {
    String::from_array(chars[:chars.length() - 1])
  } else {
    input
  }
}
