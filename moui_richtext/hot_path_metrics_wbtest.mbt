///|
/// Characterization tests for hot-path counters. These pin the current
/// incremental-parse behavior and the still-remaining full-walk scroll
/// geometry; each assertion documents the exact work a hot-path operation
/// performs so regressions (or improvements) are visible in the diff.

///|
fn hot_path_metrics_reset() -> Unit {
  hot_path_full_parse_count.val = 0
  hot_path_region_reparse_count.val = 0
  hot_path_incremental_fallback_count.val = 0
  hot_path_block_height_walk_blocks.val = 0
  hot_path_scroll_geometry_cache_hits.val = 0
  hot_path_block_conversion_builds.val = 0
  hot_path_block_wrap_builds.val = 0
  hot_path_block_wrap_cache_hits.val = 0
}

///|
fn hot_path_bench_document(block_count : Int) -> String {
  let parts : Array[String] = []
  for index in 0..<block_count {
    parts.push("## Section " + index.to_string())
    parts.push("")
    parts.push(
      "Paragraph " +
      index.to_string() +
      " with **bold** and [link](https://example.com) text for measurement.",
    )
    parts.push("")
    parts.push("- Item " + index.to_string() + " alpha")
    parts.push("  - Nested " + index.to_string() + " beta")
    parts.push("")
    parts.push("> Quoted " + index.to_string() + " line")
    parts.push("")
    parts.push("```moonbit")
    parts.push("fn add(a : Int, b : Int) -> Int { a + b }")
    parts.push("```")
    parts.push("")
    parts.push("| Name | Value |")
    parts.push("| ---- | ----- |")
    parts.push("| row-" + index.to_string() + " | 1 |")
    parts.push("")
  }
  parts.push("Tail paragraph with plain text ending the document")
  parts.join("\n")
}

///|
test "hot path: plain keystrokes at document end parse only the last cluster" {
  hot_path_metrics_reset()
  let session = MarkdownDocumentSession::new(hot_path_bench_document(40))
  inspect(hot_path_full_parse_count.val, content="1")
  hot_path_metrics_reset()
  let mut current = session
  for _ in 0..<20 {
    current = current.apply(
      MarkdownEditTransaction::from_sources(
        current.source,
        current.source + "x",
        reason=TextInput,
      ),
    )
  }
  inspect(hot_path_full_parse_count.val, content="0")
  inspect(hot_path_region_reparse_count.val, content="20")
  assert_true(current.blocks.length() == session.blocks.length())
}

///|
test "hot path: backspace into the previous cluster still avoids full parse" {
  let session = MarkdownDocumentSession::new(hot_path_bench_document(30))
  let last_end = session.source_length
  hot_path_metrics_reset()
  let next = session.apply(
    MarkdownEditTransaction::from_sources(
      session.source,
      markdown_editor_substring(session.source, 0, last_end - 1),
      reason=TextInput,
    ),
  )
  inspect(hot_path_full_parse_count.val, content="0")
  inspect(hot_path_region_reparse_count.val, content="1")
  let full = MarkdownDocumentSession::new(next.source)
  inspect(next.blocks.length(), content=full.blocks.length().to_string())
}

///|
test "hot path: newline edits keep the full-parse fallback" {
  let session = MarkdownDocumentSession::new("# Title\n\nBody")
  hot_path_metrics_reset()
  let next = session.apply(
    MarkdownEditTransaction::from_sources(
      session.source,
      "# Title\n\nBody\nNew line",
      reason=TextInput,
    ),
  )
  inspect(hot_path_full_parse_count.val, content="1")
  inspect(hot_path_region_reparse_count.val, content="0")
  assert_true(next.source == "# Title\n\nBody\nNew line")
}

///|
/// The pre-cache linear window scan, kept here as the reference for the
/// persisted prefix-sum binary search.
fn legacy_window_range(
  heights : Array[Double],
  scroll_y : Double,
  viewport_height : Double,
  overscan : Double,
) -> (Int, Int, Double, Double) {
  if heights.is_empty() {
    return (-1, -1, 0.0, 0.0)
  }
  let mut content_height = 0.0
  for height in heights {
    content_height = content_height + height
  }
  if viewport_height <= 0.0 {
    return (0, heights.length() - 1, 0.0, content_height)
  }
  let visible_min = max_double(0.0, scroll_y - overscan)
  let visible_max = min_double(
    content_height,
    scroll_y + viewport_height + overscan,
  )
  let mut y = 0.0
  let mut visible_start = -1
  let mut visible_end = -1
  let mut top_padding = 0.0
  for index, height in heights {
    let bottom = y + height
    if bottom >= visible_min && y <= visible_max {
      if visible_start < 0 {
        visible_start = index
        top_padding = y
      }
      visible_end = index
    } else if visible_end >= 0 && y > visible_max {
      break
    }
    y = bottom
  }
  if visible_start < 0 {
    let last = heights.length() - 1
    let mut top = 0.0
    for index in 0..<last {
      top = top + heights[index]
    }
    return (last, last, top, content_height)
  }
  (visible_start, visible_end, top_padding, content_height)
}

///|
fn geometry_of_heights(
  heights : Array[Double],
) -> MarkdownDocumentScrollGeometry {
  let prefix : Array[Double] = [0.0]
  let mut total = 0.0
  for height in heights {
    total = total + height
    prefix.push(total)
  }
  { heights, prefix, epoch: 0 }
}

///|
test "hot path: prefix-sum window matches the legacy linear scan" {
  let heights : Array[Double] = [
    24.0, 48.0, 12.0, 96.0, 30.0, 0.0, 60.0, 45.0, 18.0, 72.0,
  ]
  let geometry = geometry_of_heights(heights)
  for step in 0..<80 {
    let scroll_y = step.to_double() * 17.0
    for viewport in [0.0, 64.0, 320.0, 4000.0] {
      let got = markdown_document_window_range_for_geometry(
        geometry,
        scroll_y~,
        viewport_height=viewport,
        overscan=32.0,
      )
      let want = legacy_window_range(heights, scroll_y, viewport, 32.0)
      assert_true(got.visible_start == want.0)
      assert_true(got.visible_end == want.1)
      assert_true(got.top_padding == want.2)
      assert_true(got.content_height == want.3)
    }
  }
}

///|
test "hot path: wheel and rebuild walk zero blocks once geometry exists" {
  let base = @core.FontSpec::new()
  let session = MarkdownDocumentSession::new(hot_path_bench_document(30))
  for editor_block in session.editor_blocks {
    rich_text_record_block_measured_height(
      editor_block,
      base,
      width=720.0,
      height=24.0,
    )
  }
  // First geometry build pays for the walk (it replaces the old per-wheel
  // scan); everything after must be served from the persisted index.
  let _ = session.estimated_content_height(base~, content_width=720.0)
  hot_path_metrics_reset()
  for step in 0..<10 {
    let _ = session.estimated_content_height(base~, content_width=720.0)
    let _ = session.rich_text_window(
      { caret: 0, selection: None },
      scroll_y=step.to_double() * 100.0,
      viewport_height=900.0,
      overscan=320.0,
      content_width=720.0,
    )
  }
  assert_true(hot_path_block_height_walk_blocks.val == 0)
  assert_true(hot_path_scroll_geometry_cache_hits.val >= 20)
}

///|
test "hot path: measured-height change invalidates the scroll geometry" {
  let base = @core.FontSpec::new()
  let session = MarkdownDocumentSession::new(hot_path_bench_document(20))
  for editor_block in session.editor_blocks {
    rich_text_record_block_measured_height(
      editor_block,
      base,
      width=720.0,
      height=24.0,
    )
  }
  let before = session.estimated_content_height(base~, content_width=720.0)
  rich_text_record_block_measured_height(
    session.editor_blocks[0],
    base,
    width=720.0,
    height=900.0,
  )
  let after = session.estimated_content_height(base~, content_width=720.0)
  assert_true(after - before == 876.0)
}

///|
test "hot path: zero content width skips the height walk" {
  let base = @core.FontSpec::new()
  let session = MarkdownDocumentSession::new(hot_path_bench_document(30))
  hot_path_metrics_reset()
  let _ = session.estimated_content_height(base~)
  assert_true(hot_path_block_height_walk_blocks.val == 0)
}

///|
test "hot path: incremental apply matches the full parse block by block" {
  let base = hot_path_bench_document(12)
  let session = MarkdownDocumentSession::new(base)
  let mut current = session
  let mut edits = 0
  for index in 0..<60 {
    let caret = index * 53 % markdown_editor_max_int(1, session.source_length)
    let next_source = markdown_editor_substring(current.source, 0, caret) +
      "q" +
      markdown_editor_substring(current.source, caret, current.source_length)
    let next = current.apply(
      MarkdownEditTransaction::from_sources(
        current.source,
        next_source,
        reason=TextInput,
      ),
    )
    let full = MarkdownDocumentSession::new(next_source)
    assert_true(next.editor_blocks == full.editor_blocks)
    current = next
    edits = edits + 1
  }
  inspect(edits, content="60")
}
