///|
/// Pointer hit testing must share the painted block geometry: percentage-width
/// image runs only reach their real height when the content column width is
/// known (see `rich_text_run_resolved_image_width`). A width-blind walk — the
/// historical behavior — accumulates different block heights than painting, so
/// every click below an image gallery resolved into the wrong block (often the
/// gallery's HTML block, whose selection-reveal then collapsed the rendered
/// images into raw markup and made the visible content jump).
test "pointer hit test matches painted geometry around image galleries" {
  let source = "# Title\n\n<div>\n<img src=\"resource/a.png\" width=\"48%\" alt=\"A\"/>\n<img src=\"resource/b.png\" width=\"48%\" alt=\"B\"/>\n</div>\n\n## Section\n\nTarget paragraph text.\n\nTail paragraph text.\n"
  let session = MarkdownDocumentSession::new(source)
  let font = @core.FontSpec::new(size=17.0)
  let text_system = @core.TextSystem::fallback()
  let selection : MarkdownEditorSelection = { caret: 0, selection: None }
  let content_width = 960.0
  let window = session.rich_text_window(
    selection,
    base=font,
    scroll_y=0.0,
    viewport_height=2000.0,
    overscan=0.0,
    content_width~,
  )
  let content = @core.Rect::new(
    x=0.0,
    y=0.0,
    width=content_width,
    height=2000.0,
  )
  let window_content = window.content_rect(content)
  // Painted geometry: the same width-aware walk `append_rich_text_document_layers`
  // uses, so bands line up with what is actually on screen.
  let mut y = window_content.origin.y
  let mut gallery_frame : @core.Rect? = None
  let mut gallery_start = -1
  let mut gallery_end = -1
  let mut target_frame : @core.Rect? = None
  let mut target_start = -1
  let mut target_end = -1
  for block in window.document.blocks {
    let line_height = rich_text_block_line_height(
      block,
      font,
      text_system,
      block_width=window_content.size.width,
    )
    let block_height = line_height + block.inset.top + block.inset.bottom
    let frame = @core.Rect::new(
      x=window_content.origin.x + block.inset.left,
      y=y + block.inset.top,
      width=max_double(
        0.0,
        window_content.size.width - block.inset.left - block.inset.right,
      ),
      height=line_height,
    )
    if block.source_range is Some(range) {
      let block_source = source[range.start:range.end].to_owned()
      if block_source.contains("img") {
        gallery_frame = Some(frame)
        gallery_start = range.start
        gallery_end = range.end
      }
      if block_source.contains("Target") {
        target_frame = Some(frame)
        target_start = range.start
        target_end = range.end
      }
    }
    y = y + block_height
  }
  let target_frame = match target_frame {
    Some(frame) => frame
    None => fail("target paragraph not found in window")
  }
  assert_true(target_start >= 0 && target_end >= target_start)
  let gallery_frame = match gallery_frame {
    Some(frame) => frame
    None => fail("gallery range not found")
  }
  assert_true(gallery_start >= 0 && gallery_end >= gallery_start)
  // Clicking the middle of the visible target paragraph must land in it.
  let target_click = @core.Point::new(
    x=target_frame.origin.x + target_frame.size.width * 0.5,
    y=target_frame.origin.y + target_frame.size.height * 0.5,
  )
  let caret = rich_text_document_source_offset_at_point(
    window.document,
    target_click,
    window_content,
    font,
    text_system,
  ).unwrap_or(-1)
  assert_true(caret >= target_start && caret <= target_end)
  // Clicking the middle of the rendered gallery must stay inside the gallery's
  // source range instead of skipping into the blocks below.
  let gallery_click = @core.Point::new(
    x=gallery_frame.origin.x + gallery_frame.size.width * 0.5,
    y=gallery_frame.origin.y + gallery_frame.size.height * 0.5,
  )
  let gallery_caret = rich_text_document_source_offset_at_point(
    window.document,
    gallery_click,
    window_content,
    font,
    text_system,
  ).unwrap_or(-1)
  assert_true(gallery_caret >= gallery_start && gallery_caret <= gallery_end)
}

///|
/// Clicking a visible block must both resolve the caret into that block and
/// draw the caret inside the block's painted band. A caret rect that drifts
/// out of the band shows up as "clicked but no caret visible" even though the
/// selection landed correctly.
test "caret rect stays inside the clicked block's painted band" {
  let source = [
    "# Title", "", "<div>", "<img src=\"resource/a.png\" width=\"48%\" alt=\"A\"/>",
    "<img src=\"resource/b.png\" width=\"48%\" alt=\"B\"/>", "</div>", "", "## 支持平台",
    "", "| 平台 | 形态 |", "| --- | --- |", "| macOS | committed |", "| Android | experimental |",
    "", "> 移动端不是胶水代码。", "", "详见平台就绪声明。", "",
    "### 运行时管线", "", "```sh", "View[Msg] -> ElementTree -> DrawCommand",
    "text -> renderer", "```", "", "- moui/core 拥有契约", "- moui/views 拥有控件",
    "",
  ].join("\n")
  let session = MarkdownDocumentSession::new(source)
  let font = @core.FontSpec::new(size=17.0)
  let text_system = @core.TextSystem::fallback()
  let content_width = 960.0
  let viewport_height = 640.0
  // Selection parked in a paragraph well below the top so the gallery stays
  // rendered and the window covers the table/quote/code region.
  let needle = "详见平台就绪声明"
  let chars = source.to_array()
  let needle_chars = needle.to_array()
  let mut anchor = 0
  for start in 0..<=(chars.length() - needle_chars.length()) {
    let mut matched = true
    for offset in 0..<needle_chars.length() {
      if chars[start + offset] != needle_chars[offset] {
        matched = false
        break
      }
    }
    if matched {
      anchor = start
      break
    }
  }
  let selection : MarkdownEditorSelection = { caret: anchor, selection: None }
  let scroll_y = session.source_offset_y(anchor, base=font, content_width~) -
    240.0
  let window = session.rich_text_window(
    selection,
    base=font,
    scroll_y=max_double(0.0, scroll_y),
    viewport_height~,
    overscan=320.0,
    content_width~,
  )
  let content = @core.Rect::new(
    x=0.0,
    y=0.0,
    width=content_width,
    height=viewport_height,
  )
  let window_content = window.content_rect(content)
  // Painted bands, exactly as append_rich_text_document_layers stacks them.
  let mut y = window_content.origin.y
  let mut checked = 0
  for block in window.document.blocks {
    let line_height = rich_text_block_line_height(
      block,
      font,
      text_system,
      block_width=window_content.size.width,
    )
    let block_height = line_height + block.inset.top + block.inset.bottom
    let frame = @core.Rect::new(
      x=window_content.origin.x + block.inset.left,
      y=y + block.inset.top,
      width=max_double(
        0.0,
        window_content.size.width - block.inset.left - block.inset.right,
      ),
      height=line_height,
    )
    if block.source_range is Some(range) && range.end > range.start {
      let block_source = source[range.start:range.end].to_owned()
      let is_text_block = block_source.contains("支持平台") ||
        block_source.contains("移动端不是") ||
        block_source.contains("详见平台就绪声明") ||
        block_source.contains("运行时管线") ||
        block_source.contains("View[Msg]") ||
        block_source.contains("moui/core 拥有契约")
      // The band invariant holds for every block in the window document, not
      // just fully visible ones.
      if is_text_block {
        let click = @core.Point::new(
          x=frame.origin.x + max_double(20.0, frame.size.width * 0.3),
          y=frame.origin.y + max_double(6.0, frame.size.height * 0.5),
        )
        let caret = rich_text_document_source_offset_at_point(
          window.document,
          click,
          window_content,
          font,
          text_system,
        ).unwrap_or(-1)
        assert_true(caret >= range.start && caret <= range.end)
        let rect = rich_text_document_caret_rect_at_source(
          window.document,
          caret,
          window_content,
          font,
          text_system~,
        )
        let rect = match rect {
          Some(rect) => rect
          None => fail("caret rect missing for " + block_source)
        }
        assert_true(
          rect.origin.y >= y - 1.0 &&
          rect.origin.y + rect.size.height <= y + block_height + 1.0,
        )
        checked = checked + 1
      }
    }
    y = y + block_height
  }
  assert_true(checked >= 6)
}

///|
/// Table cells wrap instead of clipping, rows grow with their tallest cell,
/// clicks map into the wrapped line, and selection bands follow the cell
/// geometry instead of the block's text-line box.
test "table cells wrap and selection follows cell geometry" {
  let source = "| 平台 | 形态 | 说明 |\n| --- | --- | --- |\n| HarmonyOS | experimental | 同上；已签名真机的完整 signing 流程待补充 |\n"
  let session = MarkdownDocumentSession::new(source)
  let font = @core.FontSpec::new(size=17.0)
  let text_system = @core.TextSystem::fallback()
  let content_width = 960.0
  let window = session.rich_text_window(
    { caret: 0, selection: None },
    base=font,
    scroll_y=0.0,
    viewport_height=900.0,
    overscan=0.0,
    content_width~,
  )
  let content = @core.Rect::new(x=0.0, y=0.0, width=content_width, height=900.0)
  let window_content = window.content_rect(content)
  let mut table_block : RichTextBlock? = None
  let mut table_y = 0.0
  let mut y = window_content.origin.y
  for block in window.document.blocks {
    let line_height = rich_text_block_line_height(
      block,
      font,
      text_system,
      block_width=window_content.size.width,
    )
    if block.table is Some(_) {
      table_block = Some(block)
      table_y = y
    }
    y = y + line_height + block.inset.top + block.inset.bottom
  }
  let block = match table_block {
    Some(block) => block
    None => fail("table block missing")
  }
  let table = match block.table {
    Some(table) => table
    None => fail("table missing")
  }
  let frame = @core.Rect::new(
    x=window_content.origin.x + block.inset.left,
    y=table_y + block.inset.top,
    width=max_double(
      0.0,
      window_content.size.width - block.inset.left - block.inset.right,
    ),
    height=1000.0,
  )
  let layout = rich_text_table_layout(
    table,
    block,
    font,
    frame_width=frame.size.width,
    text_system~,
  )
  // 说明 column (index 2) text is too long for its column: it must wrap and
  // the row must grow past the single-line row height.
  let last_row = layout.rows[layout.rows.length() - 1]
  let long_cell = last_row.cells[2]
  assert_true(long_cell.lines.length() >= 2)
  assert_true(last_row.height > table.row_height)
  let mut wrapped_text = ""
  for line in long_cell.lines {
    wrapped_text = wrapped_text + line.text
  }
  assert_true(wrapped_text.contains("signing"))
  assert_true(wrapped_text.contains("待补充"))
  // A click on the wrapped cell's SECOND line resolves into the cell's source
  // range, past the first line's characters.
  let cell_range = match table.rows[table.rows.length() - 1][2].source_range {
    Some(range) => range
    None => fail("cell source range missing")
  }
  let second_line = long_cell.lines[1]
  let click_y = frame.origin.y +
    layout.row_top(layout.rows.length() - 1) +
    table.cell_padding.top +
    layout.line_step * 1.5
  let click_x = frame.origin.x +
    layout.column_width * 2.0 +
    table.cell_padding.left +
    4.0
  let caret = rich_text_document_source_offset_at_point(
    window.document,
    @core.Point::new(x=click_x, y=click_y),
    window_content,
    font,
    text_system,
  ).unwrap_or(-1)
  assert_true(caret >= cell_range.start && caret <= cell_range.end)
  assert_true(caret >= cell_range.start + second_line.start)
  // Selecting part of the cell draws the highlight over the cell band, not
  // the block's first text line.
  let sel_start = cell_range.start + second_line.start
  let sel_end = cell_range.start + second_line.end
  let commands : Array[@core.DrawCommand] = []
  append_rich_text_selection_commands(
    commands,
    window.document,
    window_content,
    font,
    text_system,
    Some(@core.TextRange::new(start=sel_start, end=sel_end)),
  )
  let mut has_band_in_row = false
  for command in commands {
    match command {
      @core.DrawCommand::FillRect(rect, _) =>
        if rect.origin.y >=
          frame.origin.y + layout.row_top(layout.rows.length() - 1) &&
          rect.origin.y <
          frame.origin.y +
          layout.row_top(layout.rows.length() - 1) +
          last_row.height {
          has_band_in_row = true
        }
      _ => ()
    }
  }
  assert_true(has_band_in_row)
}

///|
/// The caret drawn for a click inside a wrapped table cell must sit inside
/// that cell's row band (previously the walk could push it out of view).
test "table caret rect stays inside the clicked cell band" {
  let source = "| 平台 | 形态 | 说明 |\n| --- | --- | --- |\n| HarmonyOS | experimental | 同上；已签名真机的完整 signing 流程待补充 |\n"
  let session = MarkdownDocumentSession::new(source)
  let font = @core.FontSpec::new(size=17.0)
  let text_system = @core.TextSystem::fallback()
  let content_width = 960.0
  let window = session.rich_text_window(
    { caret: 0, selection: None },
    base=font,
    scroll_y=0.0,
    viewport_height=900.0,
    overscan=0.0,
    content_width~,
  )
  let content = @core.Rect::new(x=0.0, y=0.0, width=content_width, height=900.0)
  let window_content = window.content_rect(content)
  let mut table_block : RichTextBlock? = None
  let mut table_y = 0.0
  let mut y = window_content.origin.y
  for block in window.document.blocks {
    let line_height = rich_text_block_line_height(
      block,
      font,
      text_system,
      block_width=window_content.size.width,
    )
    if block.table is Some(_) {
      table_block = Some(block)
      table_y = y
    }
    y = y + line_height + block.inset.top + block.inset.bottom
  }
  let block = match table_block {
    Some(block) => block
    None => fail("table block missing")
  }
  let table = match block.table {
    Some(table) => table
    None => fail("table missing")
  }
  let frame = @core.Rect::new(
    x=window_content.origin.x + block.inset.left,
    y=table_y + block.inset.top,
    width=max_double(
      0.0,
      window_content.size.width - block.inset.left - block.inset.right,
    ),
    height=1000.0,
  )
  let layout = rich_text_table_layout(
    table,
    block,
    font,
    frame_width=frame.size.width,
    text_system~,
  )
  let last_row_index = layout.rows.length() - 1
  let row_top = frame.origin.y + layout.row_top(last_row_index)
  let row_height = layout.rows[last_row_index].height
  let cell_range = match table.rows[last_row_index][2].source_range {
    Some(range) => range
    None => fail("cell source range missing")
  }
  // Click mid first line of the wrapped cell.
  let click = @core.Point::new(
    x=frame.origin.x + layout.column_width * 2.0 + 30.0,
    y=row_top + table.cell_padding.top + layout.line_step * 0.5,
  )
  let caret = rich_text_document_source_offset_at_point(
    window.document,
    click,
    window_content,
    font,
    text_system,
  ).unwrap_or(-1)
  assert_true(caret >= cell_range.start && caret <= cell_range.end)
  let rect = rich_text_document_caret_rect_at_source(
    window.document,
    caret,
    window_content,
    font,
    text_system~,
  )
  let rect = match rect {
    Some(rect) => rect
    None => fail("table caret rect missing")
  }
  assert_true(
    rect.origin.y >= row_top - 1.0 &&
    rect.origin.y + rect.size.height <= row_top + row_height + 1.0,
  )
}

///|
/// With the table partially scrolled, a click on a visible row must draw the
/// caret in THAT row (walk y-accumulation must match the painted layout).
test "table caret lands in clicked row while scrolled" {
  let source = "# Title\n\nIntro paragraph before the table.\n\n| 平台 | 说明 |\n| --- | --- |\n| macOS | 产品主线（证据完备） |\n| Web | 产品主线（wasm-gc） |\n| Windows | 产品主线（证据完备） |\n| HarmonyOS | 同上；已签名真机的完整 smoke 仍待补齐 |\n"
  let session = MarkdownDocumentSession::new(source)
  let font = @core.FontSpec::new(size=17.0)
  let text_system = @core.TextSystem::fallback()
  let content_width = 960.0
  let viewport_height = 640.0
  let needle = "Windows"
  let chars = source.to_array()
  let needle_chars = needle.to_array()
  let mut caret_anchor = 0
  for start in 0..<=(chars.length() - needle_chars.length()) {
    let mut matched = true
    for offset in 0..<needle_chars.length() {
      if chars[start + offset] != needle_chars[offset] {
        matched = false
        break
      }
    }
    if matched {
      caret_anchor = start
      break
    }
  }
  let window = session.rich_text_window(
    { caret: caret_anchor, selection: None },
    base=font,
    scroll_y=120.0,
    viewport_height~,
    overscan=0.0,
    content_width~,
  )
  let content = @core.Rect::new(
    x=0.0,
    y=0.0,
    width=content_width,
    height=viewport_height,
  )
  let window_content = window.content_rect(content)
  // Painted bands.
  let mut y = window_content.origin.y
  let bands : Array[@core.Rect] = []
  for block in window.document.blocks {
    let line_height = rich_text_block_line_height(
      block,
      font,
      text_system,
      block_width=window_content.size.width,
    )
    if block.table is Some(_) {
      let frame = @core.Rect::new(
        x=window_content.origin.x + block.inset.left,
        y=y + block.inset.top,
        width=max_double(
          0.0,
          window_content.size.width - block.inset.left - block.inset.right,
        ),
        height=line_height,
      )
      let table = match block.table {
        Some(t) => t
        None => fail("table")
      }
      let layout = rich_text_table_layout(
        table,
        block,
        font,
        frame_width=frame.size.width,
        text_system~,
      )
      for row_index, _row in table.rows {
        if row_index == 0 {
          continue
        }
        let row_top = frame.origin.y + layout.row_top(row_index)
        let row_bottom = row_top + layout.rows[row_index].height
        bands.push(
          @core.Rect::new(
            x=frame.origin.x,
            y=row_top,
            width=frame.size.width,
            height=row_bottom - row_top,
          ),
        )
      }
    }
    y = y + line_height + block.inset.top + block.inset.bottom
  }
  // Click the macOS row (first data row) at its visible band center.
  let mac_band = bands[0]
  let click = @core.Point::new(
    x=mac_band.origin.x + 40.0,
    y=mac_band.origin.y + mac_band.size.height * 0.5,
  )
  assert_true(
    click.y >= window_content.origin.y &&
    click.y <= window_content.origin.y + viewport_height,
  )
  let caret = rich_text_document_source_offset_at_point(
    window.document,
    click,
    window_content,
    font,
    text_system,
  ).unwrap_or(-1)
  let rect = rich_text_document_caret_rect_at_source(
    window.document,
    caret,
    window_content,
    font,
    text_system~,
  )
  let rect = match rect {
    Some(r) => r
    None => fail("caret rect missing")
  }
  // The caret must sit in the same band that was clicked.
  assert_true(
    rect.origin.y >= mac_band.origin.y - 1.0 &&
    rect.origin.y <= mac_band.origin.y + mac_band.size.height + 1.0,
  )
}
