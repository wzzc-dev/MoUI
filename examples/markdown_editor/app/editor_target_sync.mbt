///|
fn markdown_editor_session_active_block(
  session : @moui_richtext.MarkdownDocumentSession,
  selection : MarkdownEditorSelection,
) -> @moui_richtext.MarkdownEditorBlock? {
  let anchor = match markdown_editor_active_selection(selection.selection) {
    Some(range) => range.start
    None => selection.caret
  }
  let anchor = markdown_editor_clamp_int(anchor, 0, session.source_length)
  let blocks = session.editor_blocks
  if blocks.length() == 0 {
    return None
  }
  let mut low = 0
  let mut high = blocks.length() - 1
  while low <= high {
    let mid = (low + high) / 2
    let block = blocks[mid]
    if anchor < block.source_range.start {
      high = mid - 1
    } else if anchor > block.source_range.end {
      low = mid + 1
    } else {
      return Some(block)
    }
  }
  None
}

///|
fn markdown_editor_session_active_block_label(
  block : @moui_richtext.MarkdownEditorBlock?,
) -> String {
  match block {
    Some(block) => markdown_editor_session_block_kind_label(block.block.kind)
    None => "Paragraph"
  }
}

///|
fn markdown_editor_session_block_kind_label(
  kind : @moui_richtext.MarkdownBlockKind,
) -> String {
  match kind {
    @moui_richtext.MarkdownBlockKind::Heading(level) =>
      "Heading " + level.to_string()
    @moui_richtext.MarkdownBlockKind::UnorderedListItem => "Bullet list"
    @moui_richtext.MarkdownBlockKind::TaskListItem(_) => "Task list"
    @moui_richtext.MarkdownBlockKind::OrderedListItem(_) => "Ordered list"
    @moui_richtext.MarkdownBlockKind::Blockquote => "Quote"
    @moui_richtext.MarkdownBlockKind::CodeBlock => "Code block"
    @moui_richtext.MarkdownBlockKind::HorizontalRule => "Rule"
    @moui_richtext.MarkdownBlockKind::Table => "Table"
    @moui_richtext.MarkdownBlockKind::FootnoteDefinition(label) =>
      "Footnote " + label
    @moui_richtext.MarkdownBlockKind::HtmlBlock => "HTML"
    @moui_richtext.MarkdownBlockKind::FrontMatter => "Front matter"
    @moui_richtext.MarkdownBlockKind::Paragraph => "Paragraph"
  }
}

///|
fn markdown_editor_session_selected_link_target(
  source : String,
  selection : MarkdownEditorSelection,
  block : @moui_richtext.MarkdownEditorBlock?,
) -> String? {
  if markdown_editor_session_should_probe_reference(
      selection,
      block,
      image=false,
    ) {
    markdown_editor_selected_link_target(source, selection)
  } else {
    None
  }
}

///|
fn markdown_editor_session_selected_image_target(
  source : String,
  selection : MarkdownEditorSelection,
  block : @moui_richtext.MarkdownEditorBlock?,
) -> String? {
  if markdown_editor_session_should_probe_reference(
      selection,
      block,
      image=true,
    ) {
    markdown_editor_selected_image_target(source, selection)
  } else {
    None
  }
}

///|
fn markdown_editor_session_should_probe_reference(
  selection : MarkdownEditorSelection,
  block : @moui_richtext.MarkdownEditorBlock?,
  image~ : Bool,
) -> Bool {
  match markdown_editor_active_selection(selection.selection) {
    Some(_) => true
    None =>
      match block {
        Some(block) =>
          match block.block.kind {
            @moui_richtext.MarkdownBlockKind::Paragraph =>
              markdown_editor_paragraph_reference_probe(
                block.block.text,
                selection.caret - block.source_range.start,
                image~,
              )
            _ =>
              if image {
                block.block.text.contains("![")
              } else {
                block.block.text.contains("[") || block.block.text.contains("<")
              }
          }
        None => false
      }
  }
}

///|
fn markdown_editor_paragraph_reference_probe(
  text : String,
  caret : Int,
  image~ : Bool,
) -> Bool {
  let text_length = markdown_editor_text_length(text)
  let caret = markdown_editor_clamp_int(caret, 0, text_length)
  let utf16_length = text.length()
  let caret_offset = if caret == text_length {
    utf16_length
  } else {
    text.offset_of_nth_char(caret).unwrap_or(utf16_length)
  }
  let mut offset = 0
  let mut index = 0
  let mut previous : Char? = None
  let mut angle_open_seen = false
  let mut bracket_open_seen = false
  let mut bracket_previous : Char? = None
  while index < caret && offset < utf16_length {
    match text.get_char(offset) {
      Some(ch) => {
        if ch == '\n' {
          angle_open_seen = false
          bracket_open_seen = false
          bracket_previous = None
        } else {
          if ch == '<' {
            angle_open_seen = true
          }
          if ch == '[' {
            bracket_open_seen = true
            bracket_previous = previous
          }
        }
        previous = Some(ch)
        offset = offset + ch.utf16_len()
        index = index + 1
      }
      None => break
    }
  }
  if !image &&
    angle_open_seen &&
    markdown_editor_paragraph_has_closing_reference(
      text, caret_offset, utf16_length, '>',
    ) {
    return true
  }
  if !bracket_open_seen {
    return false
  }
  match (image, bracket_previous) {
    (true, Some('!')) => ()
    (true, _) => return false
    (false, Some('!')) => return false
    (false, _) => ()
  }
  markdown_editor_paragraph_has_closing_reference(
    text, caret_offset, utf16_length, ']',
  )
}

///|
fn markdown_editor_paragraph_has_closing_reference(
  text : String,
  start_offset : Int,
  utf16_length : Int,
  close : Char,
) -> Bool {
  let mut offset = start_offset
  while offset < utf16_length {
    match text.get_char(offset) {
      Some(ch) =>
        if ch == close {
          return true
        } else if ch == '\n' {
          return false
        } else {
          offset = offset + ch.utf16_len()
        }
      None => return false
    }
  }
  false
}

///|
fn markdown_editor_session_selected_footnote_text(
  source : String,
  selection : MarkdownEditorSelection,
  block : @moui_richtext.MarkdownEditorBlock?,
) -> String? {
  match markdown_editor_active_selection(selection.selection) {
    Some(_) => markdown_editor_selected_footnote_text(source, selection)
    None =>
      match block {
        Some(
          {
            block: {
              kind: @moui_richtext.MarkdownBlockKind::FootnoteDefinition(_),
              text,
              ..,
            },
            ..,
          }
        ) => Some(text)
        Some({ block: { text, .. }, .. }) =>
          if text.contains("[^") {
            markdown_editor_selected_footnote_text(source, selection)
          } else {
            None
          }
        None => None
      }
  }
}

///|
fn markdown_editor_session_selected_html_block_text(
  block : @moui_richtext.MarkdownEditorBlock?,
) -> String? {
  match block {
    Some(
      {
        block: { kind: @moui_richtext.MarkdownBlockKind::HtmlBlock, text, .. },
        ..,
      }
    ) => Some(text)
    _ => None
  }
}
