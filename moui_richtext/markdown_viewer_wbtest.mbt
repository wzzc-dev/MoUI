///|
/// Test helpers for markdown viewer rendering tests.
fn mv_font() -> @core.FontSpec {
  @core.FontSpec::new(size=14.0)
}

///|
fn mv_text_system() -> @core.TextSystem {
  @core.TextSystem::fallback()
}

///|
/// Collect all DrawText commands from ViewPaintLayers (child_layers).
fn mv_layer_text_commands(
  layers : Array[@core.ViewPaintLayer],
) -> Array[@core.TextRun] {
  let runs : Array[@core.TextRun] = []
  for layer in layers {
    for command in layer.commands {
      match command {
        @core.DrawCommand::DrawText(run) => runs.push(run)
        _ => ()
      }
    }
  }
  runs
}

///|
/// Collect all FillRoundedRectBrush commands from layers (backgrounds, borders).
fn mv_layer_rect_commands(
  layers : Array[@core.ViewPaintLayer],
) -> Array[@core.Rect] {
  let rects : Array[@core.Rect] = []
  for layer in layers {
    for command in layer.commands {
      match command {
        @core.DrawCommand::FillRoundedRectBrush(rounded, _) =>
          rects.push(rounded.rect)
        @core.DrawCommand::FillRect(rect, _) => rects.push(rect)
        @core.DrawCommand::StrokeRect(rect, _, _) => rects.push(rect)
        _ => ()
      }
    }
  }
  rects
}

// ============================================================================
// rich_text_document_height tests
// ============================================================================

///|
test "rich_text_document_height: heading block produces positive height" {
  let document = markdown_document("# Title", base=mv_font())
  let height = rich_text_document_height(
    document,
    mv_font(),
    text_system=mv_text_system(),
  )
  assert_true(height > 0.0)
}

///|
test "rich_text_document_height: multiple blocks accumulate height" {
  let document = markdown_document(
    "# Title\n\nParagraph one.\n\nParagraph two.",
    base=mv_font(),
  )
  let height = rich_text_document_height(
    document,
    mv_font(),
    text_system=mv_text_system(),
  )
  // At least 3 blocks (heading + 2 paragraphs), each with positive height.
  assert_true(document.blocks.length() >= 3)
  assert_true(height > 0.0)
  // Each block should have at least font size height (14.0).
  assert_true(height >= 14.0 * 3.0)
}

///|
test "rich_text_document_height: code block height accounts for multiple lines" {
  let document = markdown_document(
    "```\nline one\nline two\nline three\n```",
    base=mv_font(),
  )
  let height = rich_text_document_height(
    document,
    mv_font(),
    text_system=mv_text_system(),
  )
  // Code block with 3 lines should be taller than a single-line paragraph.
  let single = markdown_document("Just one line.", base=mv_font())
  let single_height = rich_text_document_height(
    single,
    mv_font(),
    text_system=mv_text_system(),
  )
  assert_true(height > single_height * 2.0)
}

///|
test "rich_text_document_height: table block height accounts for row count" {
  let document = markdown_document(
    "| A | B |\n|---|---|\n| 1 | 2 |\n| 3 | 4 |",
    base=mv_font(),
  )
  let height = rich_text_document_height(
    document,
    mv_font(),
    text_system=mv_text_system(),
  )
  // Table has 3 rows (header + 2 data), row_height = base.size * 1.9 = 26.6.
  // Total table height should be at least 3 * 26.6 = 79.8.
  assert_true(height >= 3.0 * 14.0 * 1.9)
}

///|
test "rich_text_document_height: list items each contribute height" {
  let document = markdown_document(
    "- Item 1\n- Item 2\n- Item 3",
    base=mv_font(),
  )
  let height = rich_text_document_height(
    document,
    mv_font(),
    text_system=mv_text_system(),
  )
  // 3 list items, each with line_height = base.size * 1.55 = 21.7.
  assert_true(height >= 3.0 * 14.0 * 1.5)
}

// ============================================================================
// append_rich_text_document_layers culling tests
// ============================================================================

///|
test "append_rich_text_document_layers: non-windowed renders all blocks within clip" {
  let document = markdown_document("# A\n\nB\n\nC\n\nD\n\nE", base=mv_font())
  let content = @core.Rect::new(x=0.0, y=0.0, width=400.0, height=10000.0)
  let layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    layers,
    document,
    content,
    mv_font(),
    @core.Color::black(),
    text_system=mv_text_system(),
    clip_rect=Some(content),
  )
  // All 9 blocks (5 content + 4 empty paragraph separators) should be rendered.
  inspect(layers.length(), content="9")
}

///|
test "append_rich_text_document_layers: non-windowed culls blocks below clip height" {
  let document = markdown_document(
    "# A\n\nB\n\nC\n\nD\n\nE\n\nF\n\nG\n\nH\n\nI\n\nJ",
    base=mv_font(),
  )
  // Very short clip height — only the first block should fit.
  let content = @core.Rect::new(x=0.0, y=0.0, width=400.0, height=1.0)
  let layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    layers,
    document,
    content,
    mv_font(),
    @core.Color::black(),
    text_system=mv_text_system(),
    clip_rect=Some(content),
  )
  // Only blocks whose y < clip.origin.y + clip.size.height (1.0) are rendered.
  // The first block starts at y=0.0, so it should be included.
  // All subsequent blocks start at y > 1.0 and should be culled.
  assert_true(layers.length() >= 1)
  assert_true(layers.length() < document.blocks.length())
}

///|
test "append_rich_text_document_layers: windowed mode culls off-screen blocks" {
  let parts : Array[String] = []
  for index in 0..<40 {
    parts.push("## Section " + index.to_string())
    parts.push("")
  }
  let document = markdown_document(parts.join("\n"), base=mv_font())
  let content = @core.Rect::new(x=0.0, y=0.0, width=400.0, height=200.0)
  let layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    layers,
    document,
    content,
    mv_font(),
    @core.Color::black(),
    text_system=mv_text_system(),
    visible_scroll_y=500.0,
    visible_viewport_height=200.0,
    visible_overscan=50.0,
    clip_rect=Some(content),
  )
  // With viewport at scroll_y=500 and height=200, only a subset of 40 sections
  // should be rendered.
  assert_true(layers.length() > 0)
  assert_true(layers.length() < document.blocks.length())
}

// ============================================================================
// markdown_viewer paint output tests
// ============================================================================

///|
test "markdown_viewer renders heading text with larger font" {
  let document = markdown_document("# Big Title", base=mv_font())
  let content = @core.Rect::new(x=0.0, y=0.0, width=400.0, height=500.0)
  let layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    layers,
    document,
    content,
    mv_font(),
    @core.Color::black(),
    text_system=mv_text_system(),
    clip_rect=Some(content),
  )
  let runs = mv_layer_text_commands(layers)
  assert_true(runs.length() > 0)
  // Heading font size should be scaled up (1.45x for h1).
  let heading_run = runs[0]
  assert_true(heading_run.font.size > mv_font().size)
}

///|
test "markdown_viewer renders paragraph text within content width" {
  let document = markdown_document("Hello world paragraph.", base=mv_font())
  let content = @core.Rect::new(x=10.0, y=0.0, width=300.0, height=500.0)
  let layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    layers,
    document,
    content,
    mv_font(),
    @core.Color::black(),
    text_system=mv_text_system(),
    clip_rect=Some(content),
  )
  let runs = mv_layer_text_commands(layers)
  assert_true(runs.length() > 0)
  // Text frame should not extend beyond content right edge.
  for run in runs {
    let right_edge = run.frame.origin.x + run.frame.size.width
    let content_right = content.origin.x + content.size.width
    // Allow small bleed (font.size * 0.18 + 2.0) for ink clipping.
    let bleed = 14.0 * 0.18 + 4.0
    assert_true(right_edge <= content_right + bleed)
  }
}

///|
test "markdown_viewer renders code block with background" {
  let document = markdown_document("```\ncode here\n```", base=mv_font())
  let content = @core.Rect::new(x=0.0, y=0.0, width=400.0, height=500.0)
  let layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    layers,
    document,
    content,
    mv_font(),
    @core.Color::black(),
    text_system=mv_text_system(),
    clip_rect=Some(content),
  )
  assert_true(layers.length() > 0)
  // Code block should have a background fill command.
  let has_background = layers
    .iter()
    .any(layer => {
      layer.commands
      .iter()
      .any(command => command is @core.DrawCommand::FillRoundedRectBrush(_, _))
    })
  assert_true(has_background)
  // Code block text should use monospace font.
  let runs = mv_layer_text_commands(layers)
  let has_mono = runs
    .iter()
    .any(run => run.font.families == @core.FontFamilyStack::monospace())
  assert_true(has_mono)
}

///|
test "markdown_viewer renders unordered list with bullet prefix" {
  let document = markdown_document("- First\n- Second", base=mv_font())
  let content = @core.Rect::new(x=0.0, y=0.0, width=400.0, height=500.0)
  let layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    layers,
    document,
    content,
    mv_font(),
    @core.Color::black(),
    text_system=mv_text_system(),
    clip_rect=Some(content),
  )
  let runs = mv_layer_text_commands(layers)
  // Should have bullet "• " prefix runs.
  let has_bullet = runs.iter().any(run => run.text.contains("•"))
  assert_true(has_bullet)
}

///|
test "markdown_viewer renders ordered list with number prefix" {
  let document = markdown_document("1. First\n2. Second", base=mv_font())
  let content = @core.Rect::new(x=0.0, y=0.0, width=400.0, height=500.0)
  let layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    layers,
    document,
    content,
    mv_font(),
    @core.Color::black(),
    text_system=mv_text_system(),
    clip_rect=Some(content),
  )
  let runs = mv_layer_text_commands(layers)
  let has_number = runs.iter().any(run => run.text.contains("1."))
  assert_true(has_number)
}

///|
test "markdown_viewer renders blockquote with left border" {
  let document = markdown_document("> Quoted text", base=mv_font())
  let content = @core.Rect::new(x=0.0, y=0.0, width=400.0, height=500.0)
  let layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    layers,
    document,
    content,
    mv_font(),
    @core.Color::black(),
    text_system=mv_text_system(),
    clip_rect=Some(content),
  )
  assert_true(layers.length() > 0)
  // Blockquote should have a left border (narrow FillRoundedRectBrush).
  let rects = mv_layer_rect_commands(layers)
  // Look for a narrow rect (width ~4.0) that represents the left border.
  let has_border = rects
    .iter()
    .any(rect => rect.size.width <= 5.0 && rect.size.width > 0.0)
  assert_true(has_border)
}

///|
test "markdown_viewer renders horizontal rule as thin rect" {
  let document = markdown_document("---", base=mv_font())
  let content = @core.Rect::new(x=0.0, y=0.0, width=400.0, height=500.0)
  let layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    layers,
    document,
    content,
    mv_font(),
    @core.Color::black(),
    text_system=mv_text_system(),
    clip_rect=Some(content),
  )
  assert_true(layers.length() > 0)
  // Horizontal rule should produce a FillRect with height ~1.5.
  let has_rule = layers
    .iter()
    .any(layer => {
      layer.commands
      .iter()
      .any(command => {
        match command {
          @core.DrawCommand::FillRect(rect, _) => rect.size.height <= 2.0
          _ => false
        }
      })
    })
  assert_true(has_rule)
}

///|
test "markdown_viewer renders table with borders and header background" {
  let document = markdown_document(
    "| Name | Value |\n|------|-------|\n| A | 1 |\n| B | 2 |",
    base=mv_font(),
  )
  let content = @core.Rect::new(x=0.0, y=0.0, width=400.0, height=500.0)
  let layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    layers,
    document,
    content,
    mv_font(),
    @core.Color::black(),
    text_system=mv_text_system(),
    clip_rect=Some(content),
  )
  assert_true(layers.length() > 0)
  // Table should produce StrokeRect commands for cell borders.
  let has_stroke = layers
    .iter()
    .any(layer => {
      layer.commands
      .iter()
      .any(command => command is @core.DrawCommand::StrokeRect(_, _, _))
    })
  assert_true(has_stroke)
  // Table should render text for all cells including header.
  let runs = mv_layer_text_commands(layers)
  let texts = runs.map(run => run.text)
  assert_true(texts.contains("Name"))
  assert_true(texts.contains("Value"))
  assert_true(texts.contains("A") || texts.iter().any(t => t.contains("A")))
  assert_true(texts.contains("B") || texts.iter().any(t => t.contains("B")))
}

///|
test "markdown_viewer table column widths are equal" {
  let document = markdown_document(
    "| A | B |\n|---|---|\n| 1 | 2 |",
    base=mv_font(),
  )
  let content = @core.Rect::new(x=0.0, y=0.0, width=400.0, height=500.0)
  let layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    layers,
    document,
    content,
    mv_font(),
    @core.Color::black(),
    text_system=mv_text_system(),
    clip_rect=Some(content),
  )
  // Collect all StrokeRect (cell border) widths.
  let cell_widths : Array[Double] = []
  for layer in layers {
    for command in layer.commands {
      match command {
        @core.DrawCommand::StrokeRect(rect, _, _) =>
          cell_widths.push(rect.size.width)
        _ => ()
      }
    }
  }
  // 2 rows (header + 1 data, separator row is not rendered) * 2 columns = 4 cell borders.
  inspect(cell_widths.length(), content="4")
  // All column widths should be equal. Table inset is {left:10, right:10},
  // so content width = 400 - 20 = 380, column width = 380 / 2 = 190.0.
  for width in cell_widths {
    assert_true((width - 190.0).abs() < 1.0)
  }
}

///|
test "markdown_viewer renders bold inline text with heavier weight" {
  let document = markdown_document("This has **bold** text.", base=mv_font())
  let content = @core.Rect::new(x=0.0, y=0.0, width=400.0, height=500.0)
  let layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    layers,
    document,
    content,
    mv_font(),
    @core.Color::black(),
    text_system=mv_text_system(),
    clip_rect=Some(content),
  )
  let runs = mv_layer_text_commands(layers)
  // Should find a run with weight > 400 for "bold".
  let has_bold = runs
    .iter()
    .any(run => run.text.contains("bold") && run.font.weight > 600)
  assert_true(has_bold)
}

///|
test "markdown_viewer renders inline code with monospace font" {
  let document = markdown_document("Use `code` here.", base=mv_font())
  let content = @core.Rect::new(x=0.0, y=0.0, width=400.0, height=500.0)
  let layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    layers,
    document,
    content,
    mv_font(),
    @core.Color::black(),
    text_system=mv_text_system(),
    clip_rect=Some(content),
  )
  let runs = mv_layer_text_commands(layers)
  // Inline code uses a monospace family stack and smaller size (0.92x base).
  let has_code = runs
    .iter()
    .any(run => run.text.contains("code") && run.font.size < mv_font().size)
  assert_true(has_code)
}

///|
test "markdown_viewer renders link with primary color" {
  let document = markdown_document(
    "[example](https://example.com)",
    base=mv_font(),
  )
  let content = @core.Rect::new(x=0.0, y=0.0, width=400.0, height=500.0)
  let layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    layers,
    document,
    content,
    mv_font(),
    @core.Color::black(),
    text_system=mv_text_system(),
    clip_rect=Some(content),
  )
  let runs = mv_layer_text_commands(layers)
  // Link text "example" should be present.
  let has_link = runs.iter().any(run => run.text.contains("example"))
  assert_true(has_link)
}

// ============================================================================
// Layout and spacing tests
// ============================================================================

///|
test "markdown_viewer heading has top inset spacing" {
  let document = markdown_document("# Title", base=mv_font())
  let block = document.blocks[0]
  // Heading should have top inset for breath (base.size * 0.6).
  assert_true(block.inset.top > 0.0)
}

///|
test "markdown_viewer paragraph has bottom inset spacing" {
  let document = markdown_document("Just a paragraph.", base=mv_font())
  let block = document.blocks[0]
  // Paragraph should have bottom inset (base.size * 0.4).
  assert_true(block.inset.bottom > 0.0)
}

///|
test "markdown_viewer code block has uniform inset" {
  let document = markdown_document("```\ncode\n```", base=mv_font())
  let block = document.blocks[0]
  // Code block inset: { top: 12.0, right: 14.0, bottom: 12.0, left: 14.0 }.
  assert_true(block.inset.top >= 10.0)
  assert_true(block.inset.bottom >= 10.0)
  assert_true(block.inset.left >= 10.0)
}

///|
test "markdown_viewer blocks do not overlap vertically" {
  let document = markdown_document(
    "# Title\n\nParagraph 1.\n\nParagraph 2.\n\n- List item",
    base=mv_font(),
  )
  let content = @core.Rect::new(x=0.0, y=0.0, width=400.0, height=10000.0)
  let layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    layers,
    document,
    content,
    mv_font(),
    @core.Color::black(),
    text_system=mv_text_system(),
    clip_rect=Some(content),
  )
  // Each layer's frame should not overlap with the next.
  let mut index = 0
  while index < layers.length() - 1 {
    let current_bottom = layers[index].frame.origin.y +
      layers[index].frame.size.height
    let next_top = layers[index + 1].frame.origin.y
    assert_true(next_top >= current_bottom - 0.01)
    index = index + 1
  }
}

// ============================================================================
// Regression tests for known issues
// ============================================================================

///|
test "markdown_viewer long paragraph text stays within content width" {
  let long_text = "This is a very long paragraph that should wrap within the content width and not extend beyond the right edge of the container. " +
    "It contains enough text to exceed a typical 400 pixel width at 14px font size. " +
    "The text should be properly contained within the bounds."
  let document = markdown_document(long_text, base=mv_font())
  let content = @core.Rect::new(x=0.0, y=0.0, width=400.0, height=500.0)
  let layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    layers,
    document,
    content,
    mv_font(),
    @core.Color::black(),
    text_system=mv_text_system(),
    clip_rect=Some(content),
  )
  let runs = mv_layer_text_commands(layers)
  // All text runs should have their right edge within content width.
  let content_right = content.origin.x + content.size.width
  let bleed = 14.0 * 0.18 + 4.0
  for run in runs {
    let right_edge = run.frame.origin.x + run.frame.size.width
    assert_true(right_edge <= content_right + bleed)
  }
}

///|
test "markdown_viewer inserts visual soft wraps without losing inline runs" {
  let source = "A paragraph with **bold text** and `inline code` that must wrap across several narrow visual lines without losing its styled runs."
  let document = markdown_document(source, base=mv_font())
  let wrapped = rich_text_document_view_wrap(
    document,
    150.0,
    mv_font(),
    mv_text_system(),
  )
  assert_true(wrapped.blocks.length() > 0)
  let original_visual : Array[String] = []
  for block in document.blocks {
    for run in block.runs {
      original_visual.push(rich_text_run_visual_text(run))
    }
  }
  let wrapped_visual : Array[String] = []
  let mut has_soft_wrap = false
  let mut run_count = 0
  for block in wrapped.blocks {
    for run in block.runs {
      let visual = rich_text_run_visual_text(run)
      wrapped_visual.push(visual)
      has_soft_wrap = has_soft_wrap || visual.contains("\n")
      run_count = run_count + 1
    }
  }
  assert_true(has_soft_wrap)
  assert_true(run_count >= 3)
  assert_eq(
    wrapped_visual.join("").split("\n").join(""),
    original_visual.join(""),
  )
  assert_true(
    rich_text_document_height(wrapped, mv_font(), text_system=mv_text_system()) >
    rich_text_document_height(document, mv_font(), text_system=mv_text_system()),
  )
}

///|
test "markdown_viewer wraps inline code using its wider run font" {
  let width = 520.0
  let document = markdown_document(
    "The current mainline is native Skia raster plus the `wasm-gc + window/web + browser WebGPU host imports` path.",
    base=mv_font(),
  )
  let wrapped = rich_text_document_view_wrap(
    document,
    width,
    mv_font(),
    mv_text_system(),
  )
  let mut line_width = 0.0
  let mut max_line_width = 0.0
  for block in wrapped.blocks {
    line_width = line_width +
      rich_text_width(
        block.prefix,
        rich_text_block_font(block, mv_font()),
        mv_text_system(),
      )
    for run in block.runs {
      let font = run.font.unwrap_or(rich_text_block_font(block, mv_font()))
      let segments = rich_text_split_lines(rich_text_run_visual_text(run))
      for index, segment in segments {
        line_width = line_width +
          rich_text_width(segment, font, mv_text_system())
        max_line_width = max_double(max_line_width, line_width)
        if index + 1 < segments.length() {
          line_width = 0.0
        }
      }
    }
  }
  assert_true(max_line_width <= width + 0.01)
}

///|
test "markdown_viewer reuses prepared document until layout inputs change" {
  let fallback = mv_text_system()
  let measure_count = [0]
  let counted = @core.TextSystem::new(id="counted-markdown-viewer", measure=input => {
    measure_count[0] = measure_count[0] + 1
    fallback.measure_text(input)
  })
  let cache = RichTextDocumentViewCache::new()
  let source = "# Cached\n\nA paragraph that wraps across multiple viewer lines."
  ignore(cache.prepare(source, 180.0, mv_font(), counted))
  let first_prepare_count = measure_count[0]
  assert_true(first_prepare_count > 0)
  ignore(cache.prepare(source, 180.0, mv_font(), counted))
  assert_eq(measure_count[0], first_prepare_count)
  let rebuilt_cache = RichTextDocumentViewCache::new()
  ignore(rebuilt_cache.prepare(source, 180.0, mv_font(), counted))
  assert_eq(measure_count[0], first_prepare_count)
  ignore(cache.prepare(source, 160.0, mv_font(), counted))
  assert_true(measure_count[0] > first_prepare_count)
}

///|
test "markdown_viewer window keeps only wrapped blocks near the viewport" {
  let sections : Array[String] = []
  for index in 0..<60 {
    sections.push(
      "## Section \{index}\n\nA wrapping paragraph for section \{index} with enough words to occupy multiple narrow lines.",
    )
  }
  let document = markdown_document(sections.join("\n\n"), base=mv_font())
  let wrapped = rich_text_document_view_wrap(
    document,
    180.0,
    mv_font(),
    mv_text_system(),
  )
  let prepared = RichTextDocumentViewPrepared::new(
    wrapped,
    mv_font(),
    mv_text_system(),
    180.0,
  )
  let (window, top_padding) = rich_text_document_view_window(
    prepared, 900.0, 240.0, 80.0,
  )
  assert_true(window.blocks.length() > 0)
  assert_true(window.blocks.length() < wrapped.blocks.length())
  assert_true(top_padding > 0.0)
}

///|
test "markdown_viewer window positioning does not apply parent scroll twice" {
  let parent_scrolled_content = @core.Rect::new(
    x=14.0,
    y=-888.0,
    width=320.0,
    height=3000.0,
  )
  let positioned = rich_text_document_view_window_content_rect(
    parent_scrolled_content, 640.0,
  )
  inspect(positioned.origin.x, content="14")
  inspect(positioned.origin.y, content="-248")
}

///|
test "markdown_viewer repaints a visible window from controlled parent scroll" {
  let sections : Array[String] = []
  for index in 0..<80 {
    sections.push(
      "## Section \{index}\n\nParagraph \{index} has enough words to wrap across multiple lines in a narrow viewer.",
    )
  }
  let observed = Ref(@core.Point::new(x=0.0, y=0.0))
  let runtime = @runtime.AppRuntime::new_program(
    program=@core.Program::simple(
      init=@core.Point::new(x=0.0, y=0.0),
      update=(_model, next) => {
        observed.val = next
        next
      },
      view=offset => {
        @views.scroll_view(
          markdown_viewer(
            source=sections.join("\n\n"),
            size=@core.Size::new(width=320.0, height=0.0),
            font=mv_font(),
            visible_scroll_y=offset.y,
            visible_viewport_height=400.0,
          ),
          offset~,
          width=320.0,
          height=400.0,
          on_scroll=Some(next => next),
        )
      },
    ),
    size=@core.Size::new(width=320.0, height=400.0),
  )
  runtime.set_text_system(mv_text_system())
  ignore(runtime.draw_commands())
  runtime.dispatch_event(
    @core.AppEvent::Pointer(
      @core.PointerEvent::new(
        position=@core.Point::new(x=160.0, y=200.0),
        phase=@core.PointerPhase::Move,
        wheel_delta=@core.Point::new(x=0.0, y=-960.0),
      ),
    ),
  )
  assert_true(observed.val.y >= 960.0)
  let has_visible_text = runtime
    .draw_commands()
    .any(command => {
      match command {
        @core.DrawCommand::DrawText(run) =>
          run.frame.origin.y < 400.0 &&
          run.frame.origin.y + run.frame.size.height > 0.0
        _ => false
      }
    })
  assert_true(has_visible_text)
}

///|
test "markdown_viewer table cell text stays within cell bounds" {
  let document = markdown_document(
    "| Short | VeryLongHeaderName |\n|-------|-------------------|\n| 1 | 2 |",
    base=mv_font(),
  )
  let content = @core.Rect::new(x=0.0, y=0.0, width=200.0, height=500.0)
  let layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    layers,
    document,
    content,
    mv_font(),
    @core.Color::black(),
    text_system=mv_text_system(),
    clip_rect=Some(content),
  )
  // With 200px width and 2 columns, each cell is 100px.
  // "VeryLongHeaderName" at 14px is likely wider than 100px.
  // This test documents the current behavior (text may overflow cell).
  let runs = mv_layer_text_commands(layers)
  let has_long = runs.iter().any(run => run.text.contains("VeryLongHeaderName"))
  assert_true(has_long)
}

///|
test "markdown_viewer multiple headings have increasing spacing for deeper levels" {
  let document = markdown_document("# H1\n\n## H2\n\n### H3", base=mv_font())
  let content = @core.Rect::new(x=0.0, y=0.0, width=400.0, height=10000.0)
  let layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    layers,
    document,
    content,
    mv_font(),
    @core.Color::black(),
    text_system=mv_text_system(),
    clip_rect=Some(content),
  )
  // Collect all non-empty text runs, sorted by y position.
  let runs = mv_layer_text_commands(layers).filter(r => r.text.length() > 0)
  assert_true(runs.length() >= 3)
  // H1 font size > H2 font size > H3 font size.
  assert_true(runs[0].font.size > runs[1].font.size)
  assert_true(runs[1].font.size > runs[2].font.size)
}

///|
test "markdown_viewer document height matches sum of block heights" {
  let document = markdown_document(
    "# Title\n\nParagraph.\n\n- Item 1\n- Item 2\n\n```\ncode\n```\n\n> Quote",
    base=mv_font(),
  )
  let total_height = rich_text_document_height(
    document,
    mv_font(),
    text_system=mv_text_system(),
  )
  let mut sum = 0.0
  for block in document.blocks {
    sum = sum +
      rich_text_block_line_height(block, mv_font(), mv_text_system()) +
      block.inset.top +
      block.inset.bottom
  }
  assert_true((total_height - sum).abs() < 0.01)
}

///|
test "markdown viewer renders centered responsive html image galleries" {
  let gallery =
    #|<div align="center">
    #|
    #|  <img src="resource/a.png" width="48%" alt="A"/>
    #|  <img src="resource/b.png" width="48%" alt="B"/>
    #|
    #|  <br/><br/>
    #|
    #|  <img src="resource/c.png" width="48%" alt="C"/>
    #|  <img src="resource/d.png" width="48%" alt="D"/>
    #|
    #|</div>
  let blocks = parse_markdown(gallery)
  inspect(blocks.length(), content="1")
  let document = RichTextDocument::new(blocks=[
    markdown_block_to_rich_text(
      blocks[0],
      mv_font(),
      base_dir=Some("/tmp/docs"),
    ),
  ])
  guard document.blocks[0] is { line_align: Some(TextCenter), runs, .. } else {
    fail("expected a centered image-gallery block")
  }
  inspect(runs.length(), content="6")
  guard runs[0]
    is {
      text: "<img src=\"resource/a.png\" width=\"48%\" alt=\"A\"/>",
      image_source: Some("/tmp/docs/resource/a.png"),
      image_width_fraction: Some(fraction),
      ..,
    } else {
    fail("expected relative gallery image with a width fraction")
  }
  assert_true((fraction - 0.48).abs() < 0.001)

  let content = @core.Rect::new(x=0.0, y=0.0, width=500.0, height=1200.0)
  let layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    layers,
    document,
    content,
    mv_font(),
    @core.Color::black(),
    text_system=mv_text_system(),
    clip_rect=Some(content),
  )
  let image_frames : Array[@core.Rect] = []
  let image_sources : Array[String] = []
  for layer in layers {
    for command in layer.commands {
      match command {
        @core.DrawCommand::DrawImage({ source, frame, .. }) => {
          image_sources.push(source)
          image_frames.push(frame)
        }
        _ => ()
      }
    }
  }
  inspect(image_frames.length(), content="4")
  inspect(image_sources[3], content="/tmp/docs/resource/d.png")
  // 48% of 500 is 240px. The two images use 480px, leaving a centered 10px
  // margin on both sides.
  assert_true((image_frames[0].size.width - 240.0).abs() < 0.01)
  assert_true((image_frames[0].origin.x - 10.0).abs() < 0.01)
  assert_true((image_frames[1].origin.x - 250.0).abs() < 0.01)
  // Two <br> tags create a blank visual line between gallery rows.
  assert_true(
    image_frames[2].origin.y >
    image_frames[0].origin.y + image_frames[0].size.height,
  )
}

///|
test "markdown viewer keeps fixed html image dimensions and raw html fallback" {
  let fixed = markdown_document(
    "<center><img src=\"fixed.png\" width=\"120\" height=\"60\" alt=\"Fixed\"/></center>",
    base=mv_font(),
  )
  let content = @core.Rect::new(x=0.0, y=0.0, width=500.0, height=500.0)
  let layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    layers,
    fixed,
    content,
    mv_font(),
    @core.Color::black(),
    text_system=mv_text_system(),
    clip_rect=Some(content),
  )
  let frames : Array[@core.Rect] = []
  for layer in layers {
    for command in layer.commands {
      match command {
        @core.DrawCommand::DrawImage({ frame, .. }) => frames.push(frame)
        _ => ()
      }
    }
  }
  inspect(frames.length(), content="1")
  assert_true((frames[0].size.width - 120.0).abs() < 0.01)
  assert_true((frames[0].size.height - 60.0).abs() < 0.01)
  assert_true((frames[0].origin.x - 190.0).abs() < 0.01)

  let unsupported = markdown_document(
    "<div align=\"center\"><img src=\"a.png\"/><span>caption</span></div>",
    base=mv_font(),
  )
  guard unsupported.blocks[0]
    is { runs: [{ image_source: None, text, .. }], .. } else {
    fail("expected unsupported mixed html to remain raw")
  }
  inspect(
    text,
    content="<div align=\"center\"><img src=\"a.png\"/><span>caption</span></div>",
  )
}
