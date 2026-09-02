///|
test "RichTextDocument::plain splits text by newline into blocks" {
  let document = RichTextDocument::plain("alpha\nbeta\ngamma")
  inspect(document.blocks.length(), content="3")
  inspect(document.blocks[0].runs[0].text, content="alpha")
  inspect(document.blocks[1].runs[0].text, content="beta")
  inspect(document.blocks[2].runs[0].text, content="gamma")
}

///|
test "RichTextDocument::plain with empty string yields a single empty block" {
  let document = RichTextDocument::plain("")
  inspect(document.blocks.length(), content="1")
  inspect(document.blocks[0].runs[0].text, content="")
}

///|
test "RichTextDocument::plain without newlines yields a single block" {
  let document = RichTextDocument::plain("only line")
  inspect(document.blocks.length(), content="1")
  inspect(document.blocks[0].runs[0].text, content="only line")
}

///|
test "RichTextDocument::plain preserves trailing newline as empty block" {
  let document = RichTextDocument::plain("line\n")
  inspect(document.blocks.length(), content="2")
  inspect(document.blocks[0].runs[0].text, content="line")
  inspect(document.blocks[1].runs[0].text, content="")
}

///|
test "RichTextDocument::new keeps the supplied blocks" {
  let block = RichTextBlock::new(runs=[RichTextRun::new(text="hello")])
  let document = RichTextDocument::new(blocks=[block])
  inspect(document.blocks.length(), content="1")
  inspect(document.blocks[0].runs[0].text, content="hello")
}

///|
test "RichTextBlock::new defaults: empty prefix, no table, no rule" {
  let block = RichTextBlock::new(runs=[RichTextRun::new(text="x")])
  inspect(block.prefix, content="")
  assert_true(block.table is None)
  inspect(block.rule, content="false")
  inspect(block.corner_radius, content="0")
  assert_true(block.source_range is None)
  assert_true(block.content_range is None)
}

///|
test "RichTextRun::new defaults: no visual_text, no image, no decoration" {
  let run = RichTextRun::new(text="text")
  inspect(run.text, content="text")
  assert_true(run.visual_text is None)
  assert_true(run.image_source is None)
  assert_true(run.decoration is None)
  assert_true(run.source_range is None)
}

///|
test "markdown_document parses heading into a single block" {
  let document = markdown_document("# Title")
  inspect(document.blocks.length(), content="1")
  let run_text = document.blocks[0].runs[0].text
  assert_true(run_text.contains("Title"))
}

///|
test "parse_markdown strips optional closing atx heading markers" {
  let blocks = parse_markdown("## Title ##")
  inspect(blocks.length(), content="1")
  guard blocks[0] is { kind: Heading(2), text: "Title", .. } else {
    fail("expected heading text without closing marker")
  }
}

///|
test "parse_markdown keeps literal trailing hashes without atx closing separator" {
  let blocks = parse_markdown("## Title###")
  inspect(blocks.length(), content="1")
  guard blocks[0] is { kind: Heading(2), text: "Title###", .. } else {
    fail("expected literal trailing hashes to stay in heading text")
  }
}

///|
test "markdown_document parses paragraph and preserves text" {
  let document = markdown_document("Just a paragraph.")
  inspect(document.blocks.length(), content="1")
  let run_text = document.blocks[0].runs[0].text
  assert_true(run_text.contains("Just"))
}

///|
test "parse_markdown keeps soft-wrapped paragraph lines in one block" {
  let blocks = parse_markdown("first line\nsecond line")
  inspect(blocks.length(), content="1")
  guard blocks[0] is { kind: Paragraph, text: "first line\nsecond line", .. } else {
    fail("expected one soft-wrapped paragraph")
  }
}

///|
test "markdown_block_to_rich_text replaces newlines with spaces in paragraph visual_text" {
  let blocks = parse_markdown("word1\nword2")
  let block = markdown_block_to_rich_text(blocks[0], @core.FontSpec::new())
  let mut has_newline_in_visual = false
  let mut all_visual_text = ""
  let mut run_details = ""
  let mut run_index = 0
  for run in block.runs {
    let visual = match run.visual_text {
      Some(t) => t
      None => run.text
    }
    all_visual_text = all_visual_text + visual
    run_details = run_details +
      "run\{run_index}: text=\{run.text}, visual=\{visual}\n"
    run_index = run_index + 1
    if visual.contains("\n") {
      has_newline_in_visual = true
    }
  }
  if has_newline_in_visual || all_visual_text.contains("  ") {
    fail("debug: \{run_details} all_visual=\{all_visual_text}")
  }
  assert_false(has_newline_in_visual)
  assert_true(all_visual_text.contains("word1 word2"))
  assert_false(all_visual_text.contains("  "))
}

///|
test "real markdown paragraph soft-break joins with single space" {
  let src = "MoUI is a multi-platform MoonBit GUI framework for building\ndeclarative UI apps with shared platform-neutral app logic. Native host cores\nown windows, events, services, and lifecycle, then receive concrete renderers\nthrough platform renderer provider packages."
  let blocks = parse_markdown(src)
  let block = markdown_block_to_rich_text(blocks[0], @core.FontSpec::new())
  let mut all_visual = ""
  let mut run_details = ""
  let mut idx = 0
  for run in block.runs {
    let visual = match run.visual_text {
      Some(t) => t
      None => run.text
    }
    all_visual = all_visual + visual
    run_details = run_details +
      "run\{idx}: text='\{run.text}' visual='\{visual}'\n"
    idx = idx + 1
  }
  assert_false(all_visual.contains("  "))
  assert_true(all_visual.contains("cores own"))
  assert_true(all_visual.contains("renderers through"))
}

///|
test "parse_markdown keeps multiline setext heading in one block" {
  let blocks = parse_markdown("Alpha\nBeta\n---\nTail")
  inspect(blocks.length(), content="2")
  guard blocks[0] is { kind: Heading(2), text: "Alpha\nBeta", .. } else {
    fail("expected multiline setext heading")
  }
  guard blocks[1] is { kind: Paragraph, text: "Tail", .. } else {
    fail("expected paragraph after setext heading")
  }
}

///|
test "markdown_document parses unordered list items" {
  let document = markdown_document("- one\n- two\n- three")
  // Each list line becomes its own block; allow at least three list-ish blocks.
  assert_true(document.blocks.length() >= 3)
  let prefixes = document.blocks.map(block => block.prefix)
  assert_true(prefixes.contains("• "))
}

///|
test "parse_markdown recognizes plus unordered list markers" {
  let blocks = parse_markdown("+ plus")
  inspect(blocks.length(), content="1")
  guard blocks[0] is { kind: UnorderedListItem, text: "plus", .. } else {
    fail("expected plus marker to parse as unordered list item")
  }
}

///|
test "markdown_document parses task list items with checkbox prefix" {
  let document = markdown_document("- [ ] todo\n- [x] done")
  let prefixes = document.blocks.map(block => block.prefix)
  assert_true(prefixes.contains("☐ "))
  assert_true(prefixes.contains("☑ "))
}

///|
test "markdown_document parses ordered list items with numeric prefix" {
  let document = markdown_document("1. first\n2. second")
  let prefixes = document.blocks.map(block => block.prefix)
  assert_true(prefixes.contains("1. "))
  assert_true(prefixes.contains("2. "))
}

///|
test "parse_markdown recognizes paren ordered list markers" {
  let blocks = parse_markdown("3) third")
  inspect(blocks.length(), content="1")
  guard blocks[0] is { kind: OrderedListItem(3), text: "third", .. } else {
    fail("expected paren ordered marker to parse as ordered list item")
  }
}

///|
test "markdown_document parses blockquote with left border" {
  let document = markdown_document("> quoted text")
  inspect(document.blocks.length(), content="1")
  assert_true(document.blocks[0].border_left is Some(_))
  assert_true(document.blocks[0].background is Some(_))
}

///|
test "markdown_document parses fenced code block with backticks" {
  let document = markdown_document("```\ncode here\n```")
  let code_blocks = document.blocks.filter(b => b.background is Some(_))
  assert_true(code_blocks.length() >= 1)
}

///|
test "markdown_document parses fenced code block with tildes" {
  let document = markdown_document("~~~\ncode here\n~~~")
  assert_true(document.blocks.length() >= 1)
}

///|
test "parse_markdown parses tilde fenced code block with language" {
  let blocks = parse_markdown("~~~mermaid\ngraph TD\n~~~")
  inspect(blocks.length(), content="1")
  guard blocks[0]
    is { kind: CodeBlock, text: "graph TD", code_language: Some("mermaid"), .. } else {
    fail("expected tilde fenced code block")
  }
}

///|
test "parse_markdown groups adjacent indented code lines" {
  let blocks = parse_markdown("    one\n    two")
  inspect(blocks.length(), content="1")
  guard blocks[0]
    is { kind: CodeBlock, text: "one\ntwo", code_language: None, .. } else {
    fail("expected one indented code block")
  }
}

///|
test "parse_markdown keeps blank lines inside indented code blocks" {
  let blocks = parse_markdown("    one\n\n    two")
  inspect(blocks.length(), content="1")
  guard blocks[0]
    is { kind: CodeBlock, text: "one\n\ntwo", code_language: None, .. } else {
    fail("expected blank-separated indented code chunks to stay together")
  }
}

///|
test "parse_markdown treats four-space indented fences as code text" {
  let blocks = parse_markdown("    ```\n    code\n    ```")
  inspect(blocks.length(), content="1")
  guard blocks[0]
    is { kind: CodeBlock, text: "```\ncode\n```", code_language: None, .. } else {
    fail("expected indented fence markers to stay in code text")
  }
}

///|
test "parse_markdown treats tab-indented fences as code text" {
  let blocks = parse_markdown("\t```\n\tcode\n\t```")
  inspect(blocks.length(), content="1")
  guard blocks[0]
    is { kind: CodeBlock, text: "```\ncode\n```", code_language: None, .. } else {
    fail("expected tab-indented fence markers to stay in code text")
  }
}

///|
test "markdown_document parses horizontal rule as a rule block" {
  let document = markdown_document("---\n")
  let rule_blocks = document.blocks.filter(b => b.rule)
  assert_true(rule_blocks.length() >= 1)
}

///|
test "markdown_document parses table with separator row" {
  let document = markdown_document(
    "| Header 1 | Header 2 |\n| --- | --- |\n| Cell 1 | Cell 2 |",
  )
  let table_blocks = document.blocks.filter(b => b.table is Some(_))
  assert_true(table_blocks.length() >= 1)
}

///|
test "parse_markdown keeps multiline html blocks together" {
  let blocks = parse_markdown("<section>\nLine **raw**\n</section>\n\nTail")
  inspect(blocks.length(), content="2")
  guard blocks[0]
    is { kind: HtmlBlock, text: "<section>\nLine **raw**\n</section>", .. } else {
    fail("expected multiline html block")
  }
  guard blocks[1] is { kind: Paragraph, text: "Tail", .. } else {
    fail("expected paragraph after html block")
  }
}

///|
test "parse_markdown keeps processing instruction html blocks together" {
  let blocks = parse_markdown("<?moui\nraw\n?>\n\nTail")
  inspect(blocks.length(), content="2")
  guard blocks[0] is { kind: HtmlBlock, text: "<?moui\nraw\n?>", .. } else {
    fail("expected processing instruction html block")
  }
  guard blocks[1] is { kind: Paragraph, text: "Tail", .. } else {
    fail("expected paragraph after processing instruction")
  }
}

///|
test "parse_markdown keeps cdata html blocks together" {
  let blocks = parse_markdown("<![CDATA[\nraw <tag>\n]]>\n\nTail")
  inspect(blocks.length(), content="2")
  guard blocks[0] is { kind: HtmlBlock, text: "<![CDATA[\nraw <tag>\n]]>", .. } else {
    fail("expected cdata html block")
  }
  guard blocks[1] is { kind: Paragraph, text: "Tail", .. } else {
    fail("expected paragraph after cdata")
  }
}

///|
test "markdown_document parses front matter as a block" {
  let document = markdown_document("---\ntitle: Doc\ntags: []\n---\n\nBody")
  assert_true(document.blocks.length() >= 1)
}

///|
test "RichTextBlock content_range is subset of source_range when both present" {
  let document = markdown_document("# Heading\n\nParagraph text")
  for block in document.blocks {
    match (block.source_range, block.content_range) {
      (Some(src), Some(content)) => {
        assert_true(content.start >= src.start)
        assert_true(content.end <= src.end)
      }
      _ => ()
    }
  }
}

///|
test "RichTextBlock source_range and content_range are populated for parsed blocks" {
  let document = markdown_document("# Heading\n\nParagraph")
  let has_source_range = document.blocks.any(b => b.source_range is Some(_))
  let has_content_range = document.blocks.any(b => b.content_range is Some(_))
  assert_true(has_source_range)
  assert_true(has_content_range)
}

///|
test "markdown_document maps decoded entity runs to full source range" {
  let document = markdown_document("AT&amp;T &lt; 5")
  guard document.blocks[0].runs[0]
    is { text: "AT&T < 5", source_range: Some({ start: 0, end: 15 }), .. } else {
    fail("expected decoded entity run to cover raw source")
  }
}

///|
test "markdown_document maps numeric entity runs to full source range" {
  let document = markdown_document("A&#38;B &#x3c; C")
  guard document.blocks[0].runs[0]
    is { text: "A&B < C", source_range: Some({ start: 0, end: 16 }), .. } else {
    fail("expected numeric entity run to cover raw source")
  }
}

///|
test "RichTextRun visual_text overrides display text when present" {
  let run_with_visual = RichTextRun::new(text="[^1]: ", visual_text=Some("1"))
  assert_true(run_with_visual.visual_text is Some(_))
  inspect(run_with_visual.text, content="[^1]: ")
  let plain_run = RichTextRun::new(text="plain")
  assert_true(plain_run.visual_text is None)
}

///|
test "RichTextDocument struct fields are accessible" {
  let document = markdown_document("# Title\n\nBody")
  let _blocks : Array[RichTextBlock] = document.blocks
  assert_true(_blocks.length() >= 1)
  for block in _blocks {
    let _runs : Array[RichTextRun] = block.runs
    let _prefix : String = block.prefix
    let _rule : Bool = block.rule
    let _corner_radius : Double = block.corner_radius
    let _ = _runs
    let _ = _prefix
    let _ = _rule
    let _ = _corner_radius
  }
}

///|
/// Quote lines parse per source line, so quoted fence markers would
/// flatten to empty blocks and paint blank rows around the quoted code.
test "parse_markdown keeps quoted fence marker lines visible" {
  let blocks = parse_markdown("> ```powershell\n> .\\run.ps1\n> ```")
  inspect(blocks.length(), content="3")
  match blocks[0] {
    { kind: Blockquote, text, .. } => inspect(text, content="```powershell")
    _ => fail("expected quoted fence opener block")
  }
  match blocks[2] {
    { kind: Blockquote, text, .. } => inspect(text, content="```")
    _ => fail("expected quoted fence closer block")
  }
}

///|
/// Inline nodes are siblings on one visual line (backslash escapes split
/// Text nodes without any source break), so flattening must concatenate
/// them instead of joining with newlines.
test "parse_markdown concatenates inline nodes without inserting breaks" {
  let blocks = parse_markdown("> **注意：** 运行 .\\scripts\\run.ps1 完成。")
  match blocks[0] {
    { kind: Blockquote, text, .. } => {
      assert_false(text.contains("\n"))
      inspect(text, content="注意： 运行 .\\scripts\\run.ps1 完成。")
    }
    _ => fail("expected quote block")
  }
}
