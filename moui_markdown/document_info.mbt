///|
/// Markdown document statistics (word/character/line counts, block and
/// inline tallies) extracted from MoMark's document-info inspector.

///|
/// Block and inline statistics for a Markdown document.
pub(all) struct MarkdownDocumentInfo {
  character_count : Int
  heading_count : Int
  paragraph_count : Int
  list_item_count : Int
  task_count : Int
  checked_task_count : Int
  quote_count : Int
  code_block_count : Int
  table_count : Int
  link_count : Int
  image_count : Int
  footnote_reference_count : Int
  footnote_definition_count : Int
} derive(Eq, Debug, ToJson)

///|
pub extend MarkdownDocumentInfo with Eq::{equal, not_equal}

///|
pub extend MarkdownDocumentInfo with Debug::{to_repr}

///|
pub extend MarkdownDocumentInfo with ToJson::{to_json}

///|
/// Compute document info from raw source + parsed editor blocks.
pub fn markdown_document_info_from_parts(
  source : String,
  blocks : Array[@richtext.MarkdownEditorBlock],
) -> MarkdownDocumentInfo {
  let mut heading_count = 0
  let mut paragraph_count = 0
  let mut list_item_count = 0
  let mut task_count = 0
  let mut checked_task_count = 0
  let mut quote_count = 0
  let mut code_block_count = 0
  let mut table_count = 0
  let mut link_count = 0
  let mut image_count = 0
  let mut footnote_reference_count = 0
  let mut footnote_definition_count = 0
  for editor_block in blocks {
    match editor_block.block.kind {
      Heading(_) => heading_count = heading_count + 1
      Paragraph =>
        if editor_block.block.text.trim().to_owned() != "" {
          paragraph_count = paragraph_count + 1
        }
      UnorderedListItem | OrderedListItem(_) =>
        list_item_count = list_item_count + 1
      TaskListItem(checked) => {
        task_count = task_count + 1
        list_item_count = list_item_count + 1
        if checked {
          checked_task_count = checked_task_count + 1
        }
      }
      Blockquote => quote_count = quote_count + 1
      CodeBlock => code_block_count = code_block_count + 1
      Table => table_count = table_count + 1
      FootnoteDefinition(_) =>
        footnote_definition_count = footnote_definition_count + 1
      HorizontalRule | HtmlBlock | FrontMatter => ()
    }
    for inline in editor_block.block.inlines {
      match inline.kind {
        Link | Autolink => link_count = link_count + 1
        Image => image_count = image_count + 1
        FootnoteReference =>
          footnote_reference_count = footnote_reference_count + 1
        Plain | Bold | Italic | Code | Strikethrough | Highlight | HtmlInline =>
          ()
      }
    }
  }
  {
    character_count: @richtext.markdown_editor_text_length(source),
    heading_count,
    paragraph_count,
    list_item_count,
    task_count,
    checked_task_count,
    quote_count,
    code_block_count,
    table_count,
    link_count,
    image_count,
    footnote_reference_count,
    footnote_definition_count,
  }
}

///|
/// Compute document info from a snapshot.
pub fn markdown_document_info_from_snapshot(
  snapshot : @richtext.MarkdownEditorSnapshot,
) -> MarkdownDocumentInfo {
  markdown_document_info_from_parts(snapshot.source, snapshot.blocks)
}

///|
/// Compute document info from a live session.
pub fn markdown_document_info_from_session(
  session : @richtext.MarkdownDocumentSession,
) -> MarkdownDocumentInfo {
  markdown_document_info_from_parts(session.source(), session.editor_blocks)
}
