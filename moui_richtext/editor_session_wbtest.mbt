///|
test "markdown document session keeps source and cached metadata" {
  let session = MarkdownDocumentSession::new("# Title\n\nBody")
  inspect(session.source(), content="# Title\n\nBody")
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
      session.source(),
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
      session.source(),
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
      session.source(),
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
  let visible_block_count = layout.visible_end - layout.visible_start + 1
  assert_true(visible_block_count > 0)
  assert_true(visible_block_count < layout.blocks.length())
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
      "Paragraph " +
      index.to_string() +
      " with a [link](https://wzzc-dev.github.io/MoUI).",
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

///|
test "markdown document session new parses blocks and metadata correctly" {
  let session = MarkdownDocumentSession::new(
    "# Title\n\nFirst paragraph.\n\n- Item 1\n- Item 2",
  )
  // The editor blocks include headings, paragraphs, list items, and blank lines.
  assert_true(session.blocks.length() >= 4)
  inspect(session.outline.length(), content="1")
  inspect(session.outline[0].title, content="Title")
  inspect(session.outline[0].level, content="1")
  // word_count counts whitespace-separated tokens in the source.
  assert_true(session.word_count >= 5)
  assert_true(session.line_count >= 5)
  inspect(session.parse_count, content="1")
  inspect(session.revision, content="0")
}

///|
test "markdown document session apply is immutable" {
  let session = MarkdownDocumentSession::new("# Title\n\nBody")
  let original_source = session.source()
  let original_block_count = session.blocks.length()
  let original_revision = session.revision
  let next = session.apply(
    MarkdownEditTransaction::from_sources(
      session.source(),
      "# Title\n\nBody changed",
      reason=TextInput,
    ),
  )
  // The original session is unchanged.
  inspect(session.source(), content=original_source)
  inspect(session.blocks.length(), content=original_block_count.to_string())
  inspect(session.revision, content=original_revision.to_string())
  // The new session reflects the edit.
  assert_true(next.source() != session.source())
  inspect(next.revision, content=(original_revision + 1).to_string())
  inspect(next.parse_count, content="2")
}

///|
test "markdown document session apply with same source returns same session" {
  let session = MarkdownDocumentSession::new("# Title\n\nBody")
  let next = session.apply(
    MarkdownEditTransaction::from_sources(
      session.source(),
      session.source(),
      reason=TextInput,
    ),
  )
  // When the source is unchanged, apply returns the same session.
  inspect(next.source(), content=session.source())
  inspect(next.revision, content=session.revision.to_string())
  inspect(next.parse_count, content=session.parse_count.to_string())
}

///|
test "MarkdownEditTransaction::from_sources computes prefix/suffix diff" {
  // Insert at end: "hello" → "hello world"
  let insert_txn = MarkdownEditTransaction::from_sources("hello", "hello world")
  inspect(insert_txn.edit_range.start, content="5")
  inspect(insert_txn.edit_range.end, content="5")
  inspect(insert_txn.replacement, content=" world")
  // Replace middle: "abc" → "axc"
  let replace_txn = MarkdownEditTransaction::from_sources("abc", "axc")
  inspect(replace_txn.edit_range.start, content="1")
  inspect(replace_txn.edit_range.end, content="2")
  inspect(replace_txn.replacement, content="x")
  // Delete middle: "abc" → "ac"
  let delete_txn = MarkdownEditTransaction::from_sources("abc", "ac")
  inspect(delete_txn.edit_range.start, content="1")
  inspect(delete_txn.edit_range.end, content="2")
  inspect(delete_txn.replacement, content="")
}

///|
test "MarkdownEditTransaction::from_sources preserves unicode scalar diff ranges" {
  let insert_txn = MarkdownEditTransaction::from_sources("a🤣b", "a🤣XYb")
  inspect(insert_txn.edit_range.start, content="2")
  inspect(insert_txn.edit_range.end, content="2")
  inspect(insert_txn.replacement, content="XY")

  let replace_txn = MarkdownEditTransaction::from_sources("a🤣b", "a尾b")
  inspect(replace_txn.edit_range.start, content="1")
  inspect(replace_txn.edit_range.end, content="2")
  inspect(replace_txn.replacement, content="尾")

  let delete_txn = MarkdownEditTransaction::from_sources("a🤣b", "ab")
  inspect(delete_txn.edit_range.start, content="1")
  inspect(delete_txn.edit_range.end, content="2")
  inspect(delete_txn.replacement, content="")

  let leading_txn = MarkdownEditTransaction::from_sources(
    "old 🤣 tail", "new 🤣 tail",
  )
  inspect(leading_txn.edit_range.start, content="0")
  inspect(leading_txn.edit_range.end, content="3")
  inspect(leading_txn.replacement, content="new")
}

///|
test "MarkdownEditTransaction::from_sources default caret is at end of new source" {
  let txn = MarkdownEditTransaction::from_sources("abc", "abcdef")
  inspect(txn.caret, content="6")
  assert_true(txn.selection is None)
}

///|
test "MarkdownEditTransaction::from_sources preserves explicit caret and selection" {
  let selection = @core.TextRange::new(start=1, end=3)
  let txn = MarkdownEditTransaction::from_sources(
    "abc",
    "abcdef",
    caret=2,
    selection=Some(selection),
    reason=CommandEdit,
  )
  inspect(txn.caret, content="2")
  guard txn.selection is Some(range) else { fail("expected selection") }
  inspect(range.start, content="1")
  inspect(range.end, content="3")
  // MarkdownEditReason derives Eq but not Show, so compare via equality.
  assert_true(txn.reason == CommandEdit)
}

///|
test "markdown document session estimated_content_height returns positive value" {
  let session = MarkdownDocumentSession::new("# Title\n\nParagraph\n\n- Item")
  let font = @core.FontSpec::new(size=16.0)
  let height = session.estimated_content_height(base=font)
  assert_true(height > 0.0)
  // Source mode height should also be positive.
  let source_height = session.estimated_content_height(
    base=font,
    source_mode=true,
  )
  assert_true(source_height > 0.0)
}

///|
test "markdown document session measures responsive html galleries by width" {
  let source =
    #|<div align="center">
    #|
    #|  <img src="a.png" width="48%" alt="A"/>
    #|  <img src="b.png" width="48%" alt="B"/>
    #|
    #|  <br/><br/>
    #|
    #|  <img src="c.png" width="48%" alt="C"/>
    #|  <img src="d.png" width="48%" alt="D"/>
    #|
    #|</div>
    #|
    #|Tail
  let session = MarkdownDocumentSession::new(source)
  let font = @core.FontSpec::new(size=16.0)
  let narrow_height = session.estimated_content_height(
    base=font,
    content_width=320.0,
  )
  let wide_height = session.estimated_content_height(
    base=font,
    content_width=800.0,
  )
  assert_true(wide_height > narrow_height)
  let window = session.rich_text_window(
    { caret: 0, selection: None },
    base=font,
    scroll_y=0.0,
    viewport_height=300.0,
    overscan=32.0,
    content_width=800.0,
  )
  assert_true(window.content_height >= wide_height - 0.01)
  assert_true(window.rendered_block_count > 0)
}

///|
test "markdown document session source_offset_y increases for later blocks" {
  let session = MarkdownDocumentSession::new(
    "# Heading\n\nFirst paragraph.\n\nSecond paragraph.",
  )
  let font = @core.FontSpec::new(size=16.0)
  let first_block_offset = session.source_offset_y(
    session.editor_blocks[0].source_range.start,
    base=font,
  )
  let last_block_offset = session.source_offset_y(
    session.editor_blocks[session.editor_blocks.length() - 1].source_range.start,
    base=font,
  )
  assert_true(first_block_offset >= 0.0)
  assert_true(last_block_offset >= first_block_offset)
}

///|
test "markdown document session replace_source returns new session" {
  let session = MarkdownDocumentSession::new("# Old\n\nBody")
  let next = session.replace_source("# New\n\nBody")
  // Original session is unchanged.
  inspect(session.source(), content="# Old\n\nBody")
  // New session has the new source.
  assert_true(next.source().contains("New"))
  inspect(next.revision, content="1")
}

///|
test "markdown document session fingerprint stability for unchanged re-parse" {
  let source = "# A\n\nBody\n\nTail"
  let session_a = MarkdownDocumentSession::new(source)
  let session_b = MarkdownDocumentSession::new(source)
  // Two independent parses of the same source should produce the same block fingerprints.
  inspect(
    session_a.blocks.length(),
    content=session_b.blocks.length().to_string(),
  )
  for index, block in session_a.blocks {
    inspect(block.fingerprint, content=session_b.blocks[index].fingerprint)
  }
}

///|
test "markdown document session snapshot produces consistent metadata" {
  let session = MarkdownDocumentSession::new("# Title\n\nParagraph text")
  let font = @core.FontSpec::new(size=16.0)
  let snapshot = session.snapshot(base=font)
  inspect(snapshot.source, content=session.source())
  inspect(snapshot.line_count, content=session.line_count.to_string())
  inspect(snapshot.word_count, content=session.word_count.to_string())
  inspect(
    snapshot.outline.length(),
    content=session.outline.length().to_string(),
  )
  assert_true(snapshot.rich_text.blocks.length() >= 1)
}

///|
test "markdown document session rich_text produces a document with blocks" {
  let session = MarkdownDocumentSession::new("# Title\n\n**bold** text")
  let font = @core.FontSpec::new(size=16.0)
  let document = session.rich_text({ caret: 0, selection: None }, base=font)
  assert_true(document.blocks.length() >= 1)
}

///|
test "markdown document session rich_text source_mode produces monospace runs" {
  let session = MarkdownDocumentSession::new("# Title\n\nBody")
  let font = @core.FontSpec::new(size=16.0)
  let document = session.rich_text(
    { caret: 0, selection: None },
    base=font,
    source_mode=true,
  )
  // Source mode produces a single block with the full source text.
  inspect(document.blocks.length(), content="1")
  guard document.blocks[0].runs[0].font is Some(_src_font) else {
    fail("expected a font on source-mode run")
  }
}

///|
test "markdown editor substring preserves unicode scalar ranges" {
  let source = "a🤣b\n尾"
  inspect(markdown_editor_text_length(source), content="5")
  inspect(markdown_editor_substring(source, 1, 2), content="🤣")
  inspect(markdown_editor_substring(source, 2, 5), content="b\n尾")
  inspect(markdown_editor_substring(source, -10, 1), content="a")
  inspect(markdown_editor_substring(source, 4, 99), content="尾")
}

///|
test "markdown document session source_mode window slices visible source" {
  let parts : Array[String] = []
  for index in 0..<120 {
    parts.push("## Section " + index.to_string())
    parts.push("")
    parts.push("Emoji 🤣 paragraph " + index.to_string())
    parts.push("")
  }
  let source = parts.join("\n")
  let session = MarkdownDocumentSession::new(source)
  let font = @core.FontSpec::new(size=16.0)
  let source_height = session.estimated_content_height(
    base=font,
    source_mode=true,
  )
  let window = session.rich_text_window(
    { caret: 0, selection: None },
    base=font,
    source_mode=true,
    scroll_y=source_height * 0.65,
    viewport_height=96.0,
    overscan=0.0,
  )
  assert_true(window.visible_start > 0)
  assert_true(window.rendered_block_count > 0)
  assert_true(window.rendered_block_count < window.block_count)
  let first_range = session.editor_blocks[window.visible_start].source_range
  let expected = markdown_editor_substring(
    source,
    first_range.start,
    first_range.end,
  )
  inspect(window.document.blocks[0].runs[0].text, content=expected)
}
