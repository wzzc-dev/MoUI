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
  let chars = text.to_array()
  let caret = markdown_editor_clamp_int(caret, 0, chars.length())
  if !image {
    let mut open = caret
    while open > 0 && chars[open - 1] != '<' && chars[open - 1] != '\n' {
      open = open - 1
    }
    if open > 0 && chars[open - 1] == '<' {
      let mut close = caret
      while close < chars.length() &&
            chars[close] != '>' &&
            chars[close] != '\n' {
        close = close + 1
      }
      if close < chars.length() && chars[close] == '>' {
        return true
      }
    }
  }
  let mut open = caret
  while open > 0 && chars[open - 1] != '[' && chars[open - 1] != '\n' {
    open = open - 1
  }
  if open <= 0 || chars[open - 1] != '[' {
    return false
  }
  let open_start = open - 1
  if image {
    if open_start <= 0 || chars[open_start - 1] != '!' {
      return false
    }
  } else if open_start > 0 && chars[open_start - 1] == '!' {
    return false
  }
  let mut close = open
  while close < chars.length() && chars[close] != ']' && chars[close] != '\n' {
    close = close + 1
  }
  close < chars.length() && chars[close] == ']' && caret <= close
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
