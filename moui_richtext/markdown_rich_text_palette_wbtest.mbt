///|
/// The default palette must keep the historical light colors: existing golden
/// tests and callers that never mention a palette depend on it.
test "markdown rich text palette defaults to the historical light colors" {
  let light = MarkdownRichTextPalette::light()
  let session = MarkdownDocumentSession::new("> quoted\n")
  let document = session.rich_text(
    { caret: 0, selection: None, },
    base=@core.FontSpec::new(size=16.0),
  )
  let quote_index = markdown_test_block_index(session, Blockquote)
  assert_true(quote_index >= 0)
  assert_true(document.blocks[quote_index].color == Some(light.quote_text))
  assert_true(
    document.blocks[quote_index].background ==
    Some(@core.Brush::solid(light.quote_background)),
  )
}

///|
/// A dark palette must reach every baked role, including blockquotes and code
/// blocks, whose colors used to be hard-coded black.
test "markdown rich text palette recolors dark blockquotes and code" {
  let light = MarkdownRichTextPalette::light()
  let dark = MarkdownRichTextPalette::dark()
  let source = "> quoted\n\n```moonbit\nlet x = 1\n```\n"
  let light_session = MarkdownDocumentSession::new(source)
  let dark_session = light_session.with_rich_text_palette(Some(dark))
  let selection : MarkdownEditorSelection = { caret: 0, selection: None, }
  let light_document = light_session.rich_text(
    selection,
    base=@core.FontSpec::new(size=16.0),
  )
  let dark_document = dark_session.rich_text(
    selection,
    base=@core.FontSpec::new(size=16.0),
  )
  let quote_index = markdown_test_block_index(light_session, Blockquote)
  let code_index = markdown_test_block_index(light_session, CodeBlock)
  assert_true(quote_index >= 0 && code_index >= 0)
  assert_true(
    light_document.blocks[quote_index].color == Some(light.quote_text),
  )
  assert_true(dark_document.blocks[quote_index].color == Some(dark.quote_text))
  assert_true(
    dark_document.blocks[quote_index].background ==
    Some(@core.Brush::solid(dark.quote_background)),
  )
  // The code block's background and language label are baked too.
  assert_true(
    dark_document.blocks[code_index].background ==
    Some(@core.Brush::solid(dark.code_background)),
  )
}

///|
/// Switching the palette must invalidate the block conversion cache: the same
/// block converted for light first cannot be served back for dark.
test "markdown rich text palette digest invalidates block conversions" {
  let light = MarkdownRichTextPalette::light()
  let dark = MarkdownRichTextPalette::dark()
  let font = @core.FontSpec::new(size=16.0)
  let block = parse_markdown_editor_blocks("> quoted\n")[0].block
  let light_block = markdown_block_to_rich_text(
    block,
    font,
    palette=Some(light),
  )
  let dark_block = markdown_block_to_rich_text(block, font, palette=Some(dark))
  assert_true(light_block.color == Some(light.quote_text))
  assert_true(dark_block.color == Some(dark.quote_text))
  assert_true(light.cache_key() != dark.cache_key())
}

///|
/// The palette is presentation state carried by the session: edits and a
/// whole-source replacement keep it, so the next projection does not silently
/// fall back to light colors mid-session.
test "markdown session keeps its palette across edits and replaces" {
  let dark = MarkdownRichTextPalette::dark()
  let session = MarkdownDocumentSession::new("> quoted\n").with_rich_text_palette(
    Some(dark),
  )
  let edited = session.apply(
    MarkdownEditTransaction::replace_all(session.source(), "> changed\n"),
  )
  assert_true(edited.rich_text_palette == Some(dark))
  let replaced = edited.replace_source("> replaced\n")
  assert_true(replaced.rich_text_palette == Some(dark))
}

///|
fn markdown_test_block_index(
  session : MarkdownDocumentSession,
  kind : MarkdownBlockKind,
) -> Int32 {
  for index, block in session.editor_blocks {
    if block.block.kind == kind {
      return index
    }
  }
  -1
}
