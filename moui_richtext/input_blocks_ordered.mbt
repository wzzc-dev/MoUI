///|
fn markdown_editor_normalize_ordered_transform(
  edit : RichTextInputTransform,
) -> RichTextInputTransform {
  let normalized = markdown_editor_renumber_ordered_lists(edit.text)
  if normalized.text == edit.text {
    edit
  } else {
    RichTextInputTransform::new(
      text=normalized.text,
      caret=markdown_editor_map_offset_after_replacements(
        edit.caret,
        normalized.replacements,
      ),
      selection=match edit.selection {
        Some(selection) =>
          Some(
            @core.TextRange::new(
              start=markdown_editor_map_offset_after_replacements(
                selection.start,
                normalized.replacements,
              ),
              end=markdown_editor_map_offset_after_replacements(
                selection.end,
                normalized.replacements,
              ),
            ),
          )
        None => None
      },
    )
  }
}

///|
fn markdown_editor_normalize_ordered_edit_result(
  edit : MarkdownEditorEditResult,
) -> MarkdownEditorEditResult {
  let normalized = markdown_editor_renumber_ordered_lists(edit.source)
  if normalized.text == edit.source {
    edit
  } else {
    {
      source: normalized.text,
      caret: markdown_editor_map_offset_after_replacements(
        edit.caret,
        normalized.replacements,
      ),
      selection: match edit.selection {
        Some(selection) =>
          Some(
            @core.TextRange::new(
              start=markdown_editor_map_offset_after_replacements(
                selection.start,
                normalized.replacements,
              ),
              end=markdown_editor_map_offset_after_replacements(
                selection.end,
                normalized.replacements,
              ),
            ),
          )
        None => None
      },
    }
  }
}

///|
priv struct MarkdownEditorOffsetReplacement {
  start : Int
  old_end : Int
  new_end : Int
}

///|
priv struct MarkdownEditorRenumberResult {
  text : String
  replacements : Array[MarkdownEditorOffsetReplacement]
}

///|
fn markdown_editor_renumber_ordered_lists(
  source : String,
) -> MarkdownEditorRenumberResult {
  let lines = markdown_editor_lines(source)
  let rendered : Array[String] = []
  let replacements : Array[MarkdownEditorOffsetReplacement] = []
  let contexts : Array[MarkdownEditorOrderedRenumberContext] = []
  for line in lines {
    match markdown_editor_ordered_line_info(line.text.to_owned()) {
      Some(info) => {
        markdown_editor_trim_ordered_renumber_contexts(contexts, info.indent)
        let next_number = markdown_editor_next_ordered_number(contexts, info)
        let next_digits = next_number.to_string()
        if next_digits == info.digits {
          rendered.push(line.text.to_owned())
        } else {
          let chars = line.text.to_array()
          rendered.push(
            String::from_array(chars[:info.digit_start]) +
            next_digits +
            String::from_array(chars[info.digit_end:]),
          )
          replacements.push({
            start: line.start + info.digit_start,
            old_end: line.start + info.digit_end,
            new_end: line.start +
            info.digit_start +
            markdown_editor_text_length(next_digits),
          })
        }
      }
      None => {
        markdown_editor_reset_ordered_renumber_contexts(
          contexts,
          line.text.to_owned(),
        )
        rendered.push(line.text.to_owned())
      }
    }
  }
  { text: markdown_join_lines(rendered), replacements }
}

///|
priv struct MarkdownEditorOrderedRenumberContext {
  indent : Int
  context_prefix : String
  expected : Int
}

///|
fn markdown_editor_trim_ordered_renumber_contexts(
  contexts : Array[MarkdownEditorOrderedRenumberContext],
  indent : Int,
) -> Unit {
  while contexts.length() > 0 && contexts[contexts.length() - 1].indent > indent {
    ignore(contexts.pop())
  }
}

///|
fn markdown_editor_next_ordered_number(
  contexts : Array[MarkdownEditorOrderedRenumberContext],
  info : MarkdownEditorOrderedLineInfo,
) -> Int {
  if contexts.length() > 0 &&
    contexts[contexts.length() - 1].indent == info.indent &&
    contexts[contexts.length() - 1].context_prefix == info.context_prefix {
    let context = contexts[contexts.length() - 1]
    ignore(contexts.pop())
    contexts.push({
      indent: info.indent,
      context_prefix: info.context_prefix,
      expected: context.expected + 1,
    })
    context.expected
  } else {
    while contexts.length() > 0 &&
          contexts[contexts.length() - 1].indent >= info.indent {
      ignore(contexts.pop())
    }
    contexts.push({
      indent: info.indent,
      context_prefix: info.context_prefix,
      expected: info.number + 1,
    })
    info.number
  }
}

///|
fn markdown_editor_reset_ordered_renumber_contexts(
  contexts : Array[MarkdownEditorOrderedRenumberContext],
  line : String,
) -> Unit {
  if contexts.length() == 0 || markdown_editor_ordered_renumber_blank_line(line) {
    return
  }
  let indent = markdown_editor_ordered_line_context_indent(line)
  if indent > contexts[contexts.length() - 1].indent {
    return
  }
  contexts.clear()
}

///|
fn markdown_editor_ordered_renumber_blank_line(line : String) -> Bool {
  let chars = line.to_array()
  let indent = markdown_editor_ordered_line_context_indent(line)
  String::from_array(chars[indent:]).trim().to_owned() == ""
}

///|
priv struct MarkdownEditorOrderedLineInfo {
  indent : Int
  context_prefix : String
  digit_start : Int
  digit_end : Int
  digits : String
  number : Int
}

///|
fn markdown_editor_ordered_line_info(
  line : String,
) -> MarkdownEditorOrderedLineInfo? {
  let chars = line.to_array()
  let indent = markdown_editor_ordered_line_context_indent(line)
  let digit_end = markdown_editor_ordered_digit_end_at(chars, indent)
  if digit_end <= indent ||
    digit_end + 1 >= chars.length() ||
    chars[digit_end] != '.' ||
    chars[digit_end + 1] != ' ' {
    None
  } else {
    Some({
      indent,
      context_prefix: String::from_array(chars[:indent]),
      digit_start: indent,
      digit_end,
      digits: String::from_array(chars[indent:digit_end]),
      number: markdown_editor_parse_digits(chars, indent, digit_end),
    })
  }
}

///|
fn markdown_editor_ordered_line_context_indent(line : String) -> Int {
  let chars = line.to_array()
  let mut index = 0
  let mut scanning = true
  while scanning {
    while index < chars.length() &&
          (chars[index] == ' ' || chars[index] == '\t') {
      index = index + 1
    }
    if index + 1 < chars.length() &&
      chars[index] == '>' &&
      chars[index + 1] == ' ' {
      index = index + 2
    } else {
      scanning = false
    }
  }
  index
}

///|
fn markdown_editor_ordered_digit_end_at(
  chars : Array[Char],
  start : Int,
) -> Int {
  let mut index = markdown_editor_clamp_int(start, 0, chars.length())
  while index < chars.length() && chars[index].is_ascii_digit() {
    index = index + 1
  }
  index
}

///|
fn markdown_editor_map_offset_after_replacements(
  offset : Int,
  replacements : Array[MarkdownEditorOffsetReplacement],
) -> Int {
  let mut mapped = offset
  for replacement in replacements {
    let delta = replacement.new_end - replacement.old_end
    if offset > replacement.old_end {
      mapped = mapped + delta
    } else if offset >= replacement.start {
      mapped = replacement.new_end
    }
  }
  mapped
}

///|
fn markdown_editor_parse_digits(
  chars : Array[Char],
  start : Int,
  end : Int,
) -> Int {
  let mut value = 0
  for index in start..<end {
    value = value * 10 + chars[index].to_int() - '0'.to_int()
  }
  value
}
