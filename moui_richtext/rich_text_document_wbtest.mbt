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
test "markdown_block_to_rich_text keeps soft breaks as visual newlines" {
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
  if !has_newline_in_visual {
    fail("debug: \{run_details} all_visual=\{all_visual_text}")
  }
  assert_true(has_newline_in_visual)
  assert_true(all_visual_text.contains("word1\nword2"))
}

///|
test "real markdown paragraph soft-break renders one visual line per source line" {
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
  assert_true(all_visual.contains("cores\nown"))
  assert_true(all_visual.contains("renderers\nthrough"))
  // Paint segments and block heights both split on the same newlines, so
  // the paragraph renders four visual lines.
  let heights = rich_text_block_line_heights(
    block,
    @core.FontSpec::new(),
    @core.TextSystem::fallback(),
    640.0,
  )
  inspect(heights.length(), content="4")
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
/// Task list items project a vector checkbox marker, not a `☑`/`☐` glyph: the
/// block keeps a one-char placeholder lane so prefix-indexed caret and
/// hit-test arithmetic keep working, and the painter draws the box.
test "markdown_document projects task list items as checkbox markers" {
  let document = markdown_document("- [ ] todo\n- [x] done")
  let markers = document.blocks.map(block => block.marker)
  assert_true(markers.contains(Some(RichTextMarker::TaskCheckbox(false))))
  assert_true(markers.contains(Some(RichTextMarker::TaskCheckbox(true))))
  let prefixes = document.blocks.map(block => block.prefix)
  assert_true(prefixes.contains(" "))
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
/// them instead of joining with newlines. The quote's text keeps its
/// source form (markers included, `>` stripped) — the same contract a
/// paragraph's text has — so styling round-trips; only the rendered runs
/// lose the markers.
test "parse_markdown concatenates inline nodes without inserting breaks" {
  let blocks = parse_markdown(
    "> **注意：** 运行 .\\scripts\\run.ps1 完成。",
  )
  match blocks[0] {
    { kind: Blockquote, text, inlines, .. } => {
      assert_false(text.contains("\n"))
      inspect(
        text,
        content="**注意：** 运行 .\\scripts\\run.ps1 完成。",
      )
      // The styled projection carries no markers, only the visible text.
      let joined = inlines.map(inline => inline.text).join("")
      inspect(joined, content="注意： 运行 .\\scripts\\run.ps1 完成。")
    }
    _ => fail("expected quote block")
  }
}

///|
test "vertical caret movement steps onto the visible blank line" {
  // "123" + three blank lines + "123": Typora spends one blank line on the
  // paragraph break and one more on each empty line it shows, so the run
  // renders as separator + writing line + separator and only the middle one is
  // a caret stop.
  let base = @core.FontSpec::new(size=16.0)
  let text_system = @core.TextSystem::fallback()
  let content = @core.Rect::new(x=0.0, y=0.0, width=640.0, height=400.0)
  let document = markdown_editor_format_for_selection(
    "123\n\n\n\n123",
    { caret: 0, selection: None },
    base~,
  )
  inspect(document.blocks.length(), content="5")
  assert_true(rich_text_block_is_blank_gap(document.blocks[1]))
  assert_true(rich_text_block_is_blank_gap(document.blocks[2]))
  assert_true(rich_text_block_is_blank_gap(document.blocks[3]))
  // The first and last blank lines are separators with no line box at all;
  // only the middle one is an empty writing line.
  debug_inspect(document.blocks[1].line_height, content="Some(0)")
  debug_inspect(document.blocks[2].line_height, content="Some(24.8)")
  debug_inspect(document.blocks[3].line_height, content="Some(0)")
  // Down from the end of the first paragraph: over the separator, onto the
  // writing line (offset 5), then into the second paragraph.
  let mut down = 3
  let down_steps : Array[Int] = []
  for index = 1; index <= 2; index = index + 1 {
    down = rich_text_vertical_target_offset(
      document,
      down,
      @core.Rect::new(x=10.0, y=20.0, width=2.0, height=24.0),
      content,
      base,
      text_system,
      up=false,
    )
    down_steps.push(down)
  }
  inspect(down_steps[0], content="5")
  inspect(down_steps[1], content="7")
  // Up from the start of the second paragraph walks back the same way.
  let mut up = 7
  let up_steps : Array[Int] = []
  for index = 1; index <= 2; index = index + 1 {
    up = rich_text_vertical_target_offset(
      document,
      up,
      @core.Rect::new(x=10.0, y=90.0, width=2.0, height=24.0),
      content,
      base,
      text_system,
      up=true,
    )
    up_steps.push(up)
  }
  inspect(up_steps[0], content="5")
  inspect(up_steps[1], content="3")
  inspect(document.blocks[1].inset.top, content="6.4")
  inspect(document.blocks[2].inset.bottom, content="6.4")
  // The run is separator + writing line + separator: 0.4em + 1.55em + 0.4em
  // plus the spacing the writing line carries, i.e. 2.75em, which with the
  // paragraph's own 0.4em inset is Typora's 3.15em gap for three blank lines.
  assert_true(
    blank_gap_height_matches(
      markdown_editor_blank_gap_run_height(document, base, text_system, 640.0),
      2.75,
      16.0,
    ),
  )
}

///|
/// Gap metrics are `scale * base.size`; the products are not exactly
/// representable in binary floating point, so compare with a tolerance
/// instead of an exact literal.
fn blank_gap_height_matches(
  actual : Double,
  em : Double,
  size : Double,
) -> Bool {
  let diff = actual - size * em
  (if diff < 0.0 { -diff } else { diff }) < 0.0001
}

///|
/// Total rendered height of every blank gap block in `document`.
fn markdown_editor_blank_gap_run_height(
  document : RichTextDocument,
  base : @core.FontSpec,
  text_system : @core.TextSystem,
  block_width : Double,
) -> Double {
  let mut height = 0.0
  for block in document.blocks {
    if rich_text_block_is_blank_gap(block) {
      height = height +
        rich_text_block_line_height(block, base, text_system, block_width~) +
        block.inset.top +
        block.inset.bottom
    }
  }
  height
}

///|
test "blank line runs alternate separator and visible empty line" {
  // Typora's paragraph model spends one blank line on the paragraph break and
  // one more on each empty line it shows, so the space between two blocks grows
  // in steps and only every second blank line is a visible, addressable line.
  // Measured in its stock Github theme, paragraph-to-paragraph is 2.34em for
  // one blank line and 4.72em for three; MoMark measures 2.35em and 4.7em.
  let base = @core.FontSpec::new(size=16.0)
  let text_system = @core.TextSystem::fallback()
  // One, three, and five blank lines: separator, separator + line, twice that.
  let run_em : Array[Double] = [0.4, 2.75, 5.1]
  let visible_lines : Array[Int] = [0, 1, 2]
  // Paragraph-to-paragraph distance: the line box plus the paragraph's own
  // 0.4em inset plus the run. Typora measures 2.34em for one blank line and
  // 4.72em for three in the same reference document.
  let rhythm_em : Array[Double] = [2.35, 4.7, 7.05]
  let sources = ["123\n\n456", "123\n\n\n\n456", "123\n\n\n\n\n\n456"]
  for index, source in sources {
    let document = markdown_editor_format_for_selection(
      source,
      { caret: 0, selection: None },
      base~,
    )
    let run_height = markdown_editor_blank_gap_run_height(
      document, base, text_system, 640.0,
    )
    assert_true(blank_gap_height_matches(run_height, run_em[index], 16.0))
    let mut lines = 0
    for block in document.blocks {
      if rich_text_block_is_blank_gap(block) &&
        rich_text_block_line_height(block, base, text_system) > 0.0 {
        lines = lines + 1
      }
    }
    inspect(lines, content=visible_lines[index].to_string())
    let paragraph_rhythm = rich_text_block_line_height(
        document.blocks[0],
        base,
        text_system,
        block_width=640.0,
      ) +
      document.blocks[0].inset.bottom +
      run_height
    assert_true(
      blank_gap_height_matches(paragraph_rhythm, rhythm_em[index], 16.0),
    )
  }
}

///|
test "blank lines are pointer targets and the caret line stays a writing line" {
  // A pointer anywhere in the blank run parks the caret on a blank line, and
  // that line then expands to a full writing line (Typora's empty paragraph)
  // instead of the collapsed separator margin.
  let base = @core.FontSpec::new(size=16.0)
  let text_system = @core.TextSystem::fallback()
  let content = @core.Rect::new(x=0.0, y=0.0, width=640.0, height=400.0)
  let document = markdown_editor_format_for_selection(
    "123\n\n\n456",
    { caret: 0, selection: None },
    base~,
  )
  // Paragraph "123" is a 1.55em line box (24.8) plus its 0.4em inset (6.4),
  // the two blank lines are the gap blocks at 4..4 and 5..5, and paragraph
  // "456" starts at 56.8. Every point inside the run resolves to one of the
  // blank lines.
  let paragraph_height = rich_text_block_line_height(
      document.blocks[0],
      base,
      text_system,
      block_width=640.0,
    ) +
    document.blocks[0].inset.bottom
  let run_height = markdown_editor_blank_gap_run_height(
    document, base, text_system, 640.0,
  )
  for share in [0.25, 0.5, 0.75] {
    match
      rich_text_document_source_offset_at_point(
        document,
        @core.Point::new(x=10.0, y=paragraph_height + run_height * share),
        content,
        base,
        text_system,
      ) {
      Some(value) => assert_true(value >= 4 && value <= 5)
      None => fail("expected the pointer to resolve to a blank line")
    }
  }
  // The caret's own blank line still renders as a full writing line.
  let active = markdown_editor_format_for_selection(
    "123\n\n\n456",
    { caret: 5, selection: None },
    base~,
  )
  debug_inspect(active.blocks[1].line_height, content="Some(0)")
  debug_inspect(active.blocks[1].inset.top, content="6.4")
  debug_inspect(active.blocks[2].line_height, content="Some(24.8)")
  // The caret's line stands in for the blank line it occupies, so it takes
  // the writing line instead of that blank line's 1.2em increment. Carrying
  // both would leave the caret one increment too low, and the line would jump
  // up on the first keystroke.
  inspect(active.blocks[1].inset.top, content="6.4")
  inspect(active.blocks[2].inset.top, content="0")
  match rich_text_document_caret_rect_at_source(active, 5, content, base) {
    Some(rect) => inspect(rect.size.height > 0.0, content="true")
    None => fail("expected a caret rect on the blank writing line")
  }
}

///|
/// One ArrowUp/ArrowDown press exactly as `markdown_session_editor_event`
/// runs it: rebuild the visible window for the current selection (which
/// re-applies the blank-gap collapse and the soft wrap), then ask for the
/// vertical caret target in that window's geometry.
fn vertical_caret_step(
  session : MarkdownDocumentSession,
  caret : Int,
  base : @core.FontSpec,
  content : @core.Rect,
  text_system : @core.TextSystem,
  up~ : Bool,
) -> Int {
  let window = markdown_session_visible_window(
    session,
    { caret, selection: None },
    base,
    source_mode=false,
    focus_mode=false,
    base_dir=None,
    visible_scroll_y=0.0,
    visible_viewport_height=640.0,
    visible_overscan=0.0,
    content_width=content.size.width,
    text_system~,
  )
  let content = window.content_rect(content)
  let caret_rect = rich_text_document_caret_rect_or_plain(
    window.document,
    caret,
    content,
    base,
    text_system,
    session.source(),
  )
  rich_text_vertical_target_offset(
    window.document,
    caret,
    caret_rect,
    content,
    base,
    text_system,
    up~,
  )
}

///|
test "arrow walk keeps distinct offsets for identical paragraphs" {
  // Three paragraphs that all render "123": identical content, distinct
  // source offsets. The window's soft-wrap cache is content-identity keyed,
  // so without a re-base every paragraph after the first mapped back onto the
  // first one's offsets and the arrow walk collapsed onto those. The walk
  // visits the blank line above each paragraph as well.
  let base = @core.FontSpec::new(size=17.0)
  let text_system = @core.TextSystem::fallback()
  let session = MarkdownDocumentSession::new("123\n\n123\n\n123")
  let content = rich_text_editor_content_rect(
    @core.Rect::new(x=100.0, y=0.0, width=668.0, height=640.0),
  )
  let mut caret = 13
  // Each single blank line is a bare paragraph separator, so the walk steps
  // straight from one paragraph to the one above: 8, 3, then the top.
  caret = vertical_caret_step(
    session,
    caret,
    base,
    content,
    text_system,
    up=true,
  )
  inspect(caret, content="8")
  caret = vertical_caret_step(
    session,
    caret,
    base,
    content,
    text_system,
    up=true,
  )
  inspect(caret, content="3")
  caret = vertical_caret_step(
    session,
    caret,
    base,
    content,
    text_system,
    up=true,
  )
  inspect(caret, content="0")
  caret = vertical_caret_step(
    session,
    caret,
    base,
    content,
    text_system,
    up=true,
  )
  inspect(caret, content="0")
  // And back down: the middle paragraph, then the last one.
  caret = vertical_caret_step(
    session,
    caret,
    base,
    content,
    text_system,
    up=false,
  )
  inspect(caret, content="5")
  caret = vertical_caret_step(
    session,
    caret,
    base,
    content,
    text_system,
    up=false,
  )
  inspect(caret, content="10")
  caret = vertical_caret_step(
    session,
    caret,
    base,
    content,
    text_system,
    up=false,
  )
  inspect(caret, content="10")
}

///|
test "every line box covers the font it renders" {
  // The painter clips every run to its line box, so a box shorter than the
  // font's own ascent plus descent slices the glyph bottoms: with the old
  // base-relative factors a level-2 heading box was 1.1x its font and the
  // descender of "Today" was cut off. Every run therefore has to get at least
  // the framework's natural line height (1.25em) from its line step.
  let base = @core.FontSpec::new(size=17.0)
  let text_system = @core.TextSystem::fallback()
  let document = markdown_editor_format_for_selection(
    "# Editor notes\n\nThis **WYSIWYG** surface keeps `Markdown` as the saved value.\n\n## Today\n- Type into the formatted page\n\n> Unsupported syntax stays editable as plain text.\n\n```\nlet saved = markdown\n```\n\n| a | b |\n| --- | --- |\n| 1 | 2 |\n\n---\n\n[^note]: definition",
    { caret: 0, selection: None },
    base~,
  )
  let mut checked = 0
  for block in document.blocks {
    let step = rich_text_block_line_step(block, base, text_system)
    for run in block.runs {
      let font = run.font.unwrap_or(rich_text_block_font(block, base))
      assert_true(step >= font.size * 1.25)
      checked = checked + 1
    }
  }
  // The document above renders headings, paragraphs, a list, a quote, a code
  // block, a table, a rule, and a footnote definition.
  inspect(checked > 8, content="true")
}
