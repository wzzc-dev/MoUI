///|
test "markdown document session keeps source and cached metadata" {
  let session = MarkdownDocumentSession::new("# Title\n\nBody")
  inspect(session.source, content="# Title\n\nBody")
  inspect(session.line_count, content="3")
  inspect(session.word_count, content="3")
  inspect(session.outline.length(), content="1")
  inspect(session.outline[0].title, content="Title")
  inspect(session.parse_count, content="1")
}

///|
test "markdown document session edit keeps stable ids around dirty block" {
  let session = MarkdownDocumentSession::new("# A\n\nBody\n\nTail")
  let first_id = session.blocks[0].id
  let body_id = session.blocks[2].id
  let tail_id = session.blocks[4].id
  let next = session.apply(
    MarkdownEditTransaction::from_sources(
      session.source,
      "# A\n\nBody!\n\nTail",
      reason=TextInput,
    ),
  )
  inspect(next.blocks[0].id, content=first_id.to_string())
  inspect(next.blocks[2].id, content=body_id.to_string())
  inspect(next.blocks[4].id, content=tail_id.to_string())
  inspect(next.blocks[2].revision, content="1")
  inspect(next.blocks[4].revision, content="0")
  inspect(next.parse_count, content="2")
}

///|
test "markdown document session records dirty block window" {
  let session = MarkdownDocumentSession::new("# A\n\nBody\n\nTail")
  let next = session.apply(
    MarkdownEditTransaction::from_sources(
      session.source,
      "# A\n\nBody!\n\nTail",
      reason=TextInput,
    ),
  )
  guard next.dirty_range is Some(range) else { fail("expected dirty range") }
  inspect(range.start_block, content="1")
  inspect(range.end_block, content="3")
}

///|
test "markdown document session expands global context for fences" {
  let session = MarkdownDocumentSession::new("# A\n\nBody\n\nTail")
  let next = session.apply(
    MarkdownEditTransaction::from_sources(
      session.source,
      "# A\n\n```\nBody\n```\n\nTail",
      reason=TextInput,
    ),
  )
  guard next.dirty_range is Some(range) else { fail("expected dirty range") }
  inspect(range.start_block, content="0")
  inspect(range.end_block, content=(next.blocks.length() - 1).to_string())
}

///|
test "markdown document layout cache reports visible variable height blocks" {
  let session = MarkdownDocumentSession::new(
    "# A\n\nParagraph\n\n```\nline one\nline two\n```\n\nTail",
  )
  let font = @core.FontSpec::new(size=16.0)
  let document = session.rich_text({ caret: 0, selection: None }, base=font)
  let layout = MarkdownDocumentLayoutCache::new(
    session,
    document,
    font,
    width=640.0,
    scroll_y=0.0,
    viewport_height=80.0,
    overscan=0.0,
  )
  assert_true(layout.content_height > 80.0)
  assert_true(layout.visible_block_count() > 0)
  assert_true(layout.visible_block_count() < layout.blocks.length())
}

///|
test "markdown document rich text window renders only visible blocks" {
  let parts : Array[String] = []
  for index in 0..<120 {
    parts.push("## Section " + index.to_string())
    parts.push("")
    parts.push("Paragraph " + index.to_string() + " with **bold** text.")
    parts.push("")
  }
  let session = MarkdownDocumentSession::new(parts.join("\n"))
  let font = @core.FontSpec::new(size=16.0)
  let window = session.rich_text_window(
    { caret: 0, selection: None },
    base=font,
    scroll_y=0.0,
    viewport_height=180.0,
    overscan=0.0,
  )
  assert_true(window.content_height > 180.0)
  inspect(window.visible_start, content="0")
  assert_true(window.rendered_block_count > 0)
  assert_true(window.rendered_block_count < session.editor_blocks.length())
}

///|
test "markdown document rich text window starts near scrolled block" {
  let parts : Array[String] = []
  for index in 0..<160 {
    parts.push("## Section " + index.to_string())
    parts.push("")
    parts.push(
      "Paragraph " + index.to_string() + " with a [link](https://moui.dev).",
    )
    parts.push("")
  }
  let session = MarkdownDocumentSession::new(parts.join("\n"))
  let font = @core.FontSpec::new(size=16.0)
  let target_block = session.editor_blocks[120]
  let scroll_y = session.source_offset_y(
    target_block.source_range.start,
    base=font,
  )
  let window = session.rich_text_window(
    { caret: target_block.source_range.start, selection: None },
    base=font,
    scroll_y~,
    viewport_height=220.0,
    overscan=0.0,
  )
  assert_true(window.visible_start > 0)
  assert_true(window.visible_start <= 120)
  assert_true(window.rendered_block_count < session.editor_blocks.length())
  guard window.document.blocks[0].source_range is Some(range) else {
    fail("expected source range on first window block")
  }
  assert_true(
    range.start >=
    session.editor_blocks[window.visible_start].source_range.start,
  )
}
