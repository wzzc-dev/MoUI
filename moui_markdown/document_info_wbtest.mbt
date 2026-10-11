///|
test "markdown document info tallies blocks and inline references" {
  let source = "# Draft\n\nParagraph with **bold** and [MoUI](https://example.com).\n\n![Alt](assets/logo.png)\n\n- [x] Done\n- [ ] Todo\n\n| Name | Value |\n| --- | --- |\n| A | 1 |\n\n```mbt\nlet x = 1\n```\n\n> Quoted\n\n[^note]: Footnote\n\nRef[^note]"
  let snapshot = @richtext.MarkdownEditorSnapshot::parse(source)
  let info = markdown_document_info_from_snapshot(snapshot)
  inspect(info.heading_count, content="1")
  inspect(info.paragraph_count, content="3")
  inspect(info.list_item_count, content="2")
  inspect(info.task_count, content="2")
  inspect(info.checked_task_count, content="1")
  inspect(info.quote_count, content="1")
  inspect(info.code_block_count, content="1")
  inspect(info.table_count, content="1")
  inspect(info.link_count, content="1")
  inspect(info.image_count, content="1")
  inspect(info.footnote_reference_count, content="1")
  inspect(info.footnote_definition_count, content="1")
  inspect(
    info.character_count,
    content=@richtext.markdown_editor_text_length(source).to_string(),
  )
}

///|
test "markdown document info from session matches snapshot" {
  let source = "# Title\n\nBody"
  let session = @richtext.MarkdownDocumentSession::new(source)
  let snapshot = @richtext.MarkdownEditorSnapshot::parse(source)
  assert_eq(
    markdown_document_info_from_session(session),
    markdown_document_info_from_snapshot(snapshot),
  )
}
