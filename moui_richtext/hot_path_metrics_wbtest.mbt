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
  hot_path_scroll_geometry_point_updates.val = 0
  hot_path_block_conversion_builds.val = 0
  hot_path_block_wrap_builds.val = 0
  hot_path_block_wrap_cache_hits.val = 0
  hot_path_block_fingerprints_built.val = 0
  hot_path_height_metrics_recomputed.val = 0
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
  markdown_document_scroll_geometry_from_heights(heights, epoch=0)
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
    let _ = rich_text_record_block_measured_height(
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
test "hot path: fenwick point updates match a rebuild" {
  let heights : Array[Double] = [
    24.0, 48.0, 12.0, 96.0, 30.0, 0.0, 60.0, 45.0, 18.0, 72.0,
  ]
  let geometry = geometry_of_heights(heights)
  let updates : Array[(Int, Double)] = [
    (0, 90.0),
    (9, 3.5),
    (5, 44.0),
    (2, 0.0),
    (4, 12.5),
    (9, 3.5),
  ]
  let expected : Array[Double] = []
  expected.append(heights)
  for pair in updates {
    markdown_document_scroll_geometry_set_height(
      geometry,
      index=pair.0,
      height=pair.1,
    )
    expected[pair.0] = pair.1
    let limit = heights.length() + 1
    for upto in 0..<limit {
      let mut want = 0.0
      for j in 0..<upto {
        want = want + expected[j]
      }
      assert_true(
        markdown_document_scroll_geometry_prefix_at(geometry, count=upto) ==
        want,
      )
    }
  }
  // A no-op update (same height) must leave the tree untouched.
  markdown_document_scroll_geometry_set_height(geometry, index=3, height=96.0)
  let mut total = 0.0
  for height in expected {
    total = total + height
  }
  assert_true(
    markdown_document_scroll_geometry_prefix_at(
      geometry,
      count=heights.length(),
    ) ==
    total,
  )
}

///|
test "hot path: window range matches the legacy scan after point updates" {
  let heights : Array[Double] = [
    24.0, 48.0, 12.0, 96.0, 30.0, 0.0, 60.0, 45.0, 18.0, 72.0,
  ]
  let geometry = geometry_of_heights(heights)
  let expected : Array[Double] = []
  expected.append(heights)
  let updates : Array[(Int, Double)] = [(1, 220.0), (0, 5.0), (8, 64.0)]
  for pair in updates {
    markdown_document_scroll_geometry_set_height(
      geometry,
      index=pair.0,
      height=pair.1,
    )
    expected[pair.0] = pair.1
    for step in 0..<60 {
      let scroll_y = step.to_double() * 13.0
      for viewport in [0.0, 96.0, 300.0, 9000.0] {
        let got = markdown_document_window_range_for_geometry(
          geometry,
          scroll_y~,
          viewport_height=viewport,
          overscan=24.0,
        )
        let want = legacy_window_range(expected, scroll_y, viewport, 24.0)
        assert_true(got.visible_start == want.0)
        assert_true(got.visible_end == want.1)
        assert_true(got.top_padding == want.2)
        assert_true(got.content_height == want.3)
      }
    }
  }
}

///|
test "hot path: measured-height change updates the scroll geometry in place" {
  let base = @core.FontSpec::new()
  let session = MarkdownDocumentSession::new(hot_path_bench_document(20))
  for editor_block in session.editor_blocks {
    let _ = rich_text_record_block_measured_height(
      editor_block,
      base,
      width=720.0,
      height=24.0,
    )
  }
  let before = session.estimated_content_height(base~, content_width=720.0)
  hot_path_metrics_reset()
  let changed = rich_text_record_block_measured_height(
    session.editor_blocks[0],
    base,
    width=720.0,
    height=900.0,
  )
  assert_true(changed)
  markdown_document_apply_measured_height(
    session,
    base,
    block_index=0,
    width=720.0,
    height=900.0,
  )
  let after = session.estimated_content_height(base~, content_width=720.0)
  assert_true(after - before == 876.0)
  // The new height landed through the O(log n) point update: no block
  // was re-walked, and the cached entry was never invalidated.
  assert_true(hot_path_block_height_walk_blocks.val == 0)
  assert_true(hot_path_scroll_geometry_point_updates.val == 1)
}

///|
test "hot path: repeated identical measurements are not re-applied" {
  let base = @core.FontSpec::new()
  let session = MarkdownDocumentSession::new(hot_path_bench_document(6))
  for editor_block in session.editor_blocks {
    let _ = rich_text_record_block_measured_height(
      editor_block,
      base,
      width=720.0,
      height=24.0,
    )
  }
  let _ = session.estimated_content_height(base~, content_width=720.0)
  let changed = rich_text_record_block_measured_height(
    session.editor_blocks[1],
    base,
    width=720.0,
    height=24.0,
  )
  assert_true(!changed)
}

///|
/// The regression A1 targets: while scrolling into never-painted blocks,
/// every paint records fresh measured heights. Under the old global
/// epoch that invalidated the whole geometry each step (one full walk
/// per wheel event); with point updates only the very first real build
/// may walk.
test "hot path: scrolling through freshly measured blocks stays walk-free" {
  let base = @core.FontSpec::new()
  let width = 720.0
  let session = MarkdownDocumentSession::new(hot_path_bench_document(40))
  let count = session.editor_blocks.length()
  assert_true(count > 40)
  // First paint records nothing yet: geometry caches the “no measured
  // geometry yet” verdict.
  let _ = session.estimated_content_height(base~, content_width=width)
  hot_path_metrics_reset()
  let mut start = 0
  let mut steps = 0
  while start < count {
    let end = markdown_editor_min_int(start + 8, count)
    // The paint lays out the new window and records its measured
    // heights (record + in-place apply), then the next wheel queries
    // the geometry through rich_text_window.
    for index in start..<end {
      let _ = rich_text_record_block_measured_height(
        session.editor_blocks[index],
        base,
        width~,
        height=48.0,
      )
      // Unconditional per-slot apply, mirroring the paint path: the
      // height table dedupes by content, the geometry keeps one slot
      // per block position.
      markdown_document_apply_measured_height(
        session,
        base,
        block_index=index,
        width~,
        height=48.0,
      )
    }
    let _ = session.rich_text_window(
      { caret: 0, selection: None },
      scroll_y=steps.to_double() * 200.0,
      viewport_height=800.0,
      overscan=320.0,
      content_width=width,
    )
    start = end
    steps = steps + 1
  }
  assert_true(steps == (count + 7) / 8)
  assert_true(hot_path_scroll_geometry_point_updates.val >= count - 8)
  assert_true(hot_path_scroll_geometry_cache_hits.val >= steps - 1)
  assert_true(hot_path_scroll_geometry_cache_hits.val >= steps - 1)
  // At most one rebuild across the whole scroll (the first real build;
  // earlier tests in this binary may already have measured-height entries
  // that turn the pre-reset query into that build directly). Under the
  // old epoch semantics this counter was count × steps.
  assert_true(hot_path_block_height_walk_blocks.val <= count)
}

///|
fn hot_path_apply_edit(
  session : MarkdownDocumentSession,
  next_source : String,
) -> MarkdownDocumentSession {
  session.apply(
    MarkdownEditTransaction::from_sources(
      session.source,
      next_source,
      reason=TextInput,
    ),
  )
}

///|
/// Test-only char-space `index_of` (the editor document fixtures are ASCII,
/// so char indices equal string slice offsets).
fn hot_path_index_of(source : String, needle : String) -> Int {
  let chars = source.to_array()
  let needle_chars = needle.to_array()
  let limit = chars.length() - needle_chars.length()
  let mut index = 0
  let mut found = -1
  while index <= limit && found < 0 {
    let mut matches = true
    for offset, needle_char in needle_chars {
      if chars[index + offset] != needle_char {
        matches = false
        break
      }
    }
    if matches {
      found = index
    }
    index = index + 1
  }
  found
}

///|
/// Derived state an incremental `apply` must reproduce exactly (ids and
/// revisions legitimately differ from a from-scratch session and are not
/// compared here).
fn hot_path_assert_matches_scratch(
  session : MarkdownDocumentSession,
  next_source : String,
) -> Unit raise {
  let full = MarkdownDocumentSession::new(next_source)
  assert_eq(session.line_count, full.line_count)
  assert_eq(session.word_count, full.word_count)
  assert_eq(session.reading_minutes, full.reading_minutes)
  assert_eq(session.active_heading, full.active_heading)
  assert_eq(session.outline, full.outline)
  assert_eq(
    session.height_index.blocks.length(),
    full.height_index.blocks.length(),
  )
  assert_eq(
    session.height_index.visual_content_units,
    full.height_index.visual_content_units,
  )
  assert_eq(
    session.height_index.source_content_units,
    full.height_index.source_content_units,
  )
  for index, metric in session.height_index.blocks {
    let expected = full.height_index.blocks[index]
    assert_eq(metric.source_range, expected.source_range)
    assert_eq(metric.visual_top_units, expected.visual_top_units)
    assert_eq(metric.visual_height_units, expected.visual_height_units)
    assert_eq(metric.source_top_units, expected.source_top_units)
    assert_eq(metric.source_height_units, expected.source_height_units)
  }
  for index, block in session.blocks {
    let expected = full.blocks[index]
    assert_eq(block.source_range, expected.source_range)
    assert_eq(block.content_range, expected.content_range)
    assert_eq(block.kind, expected.kind)
    assert_eq(block.text, expected.text)
    assert_eq(block.fingerprint, expected.fingerprint)
    assert_eq(block.inline_count, expected.inline_count)
  }
}

///|
/// A2's correctness contract: every incremental bookkeeping fast path
/// (fingerprints, height metrics, outline splice, word/line deltas) must
/// end in exactly the state a from-scratch parse of the same source has.
test "hot path: incremental bookkeeping matches a from-scratch session" {
  let mut session = MarkdownDocumentSession::new(hot_path_bench_document(20))
  // Append at the document end (word-boundary delta: no new word).
  let source1 = session.source + "x"
  session = hot_path_apply_edit(session, source1)
  hot_path_assert_matches_scratch(session, source1)
  // Insert into an early paragraph: everything after the edit shifts by
  // one character — outline positions, height metric ranges and tops.
  let insert_at = hot_path_index_of(source1, "with") + 5
  let source2 = (source1[:insert_at] + "Q" + source1[insert_at:]).to_owned()
  session = hot_path_apply_edit(session, source2)
  hot_path_assert_matches_scratch(session, source2)
  // Delete a letter inside the same word (no word-count change).
  let delete_at = hot_path_index_of(source2, "with") + 1
  let source3 = (source2[:delete_at] + source2[delete_at + 1:]).to_owned()
  session = hot_path_apply_edit(session, source3)
  hot_path_assert_matches_scratch(session, source3)
  // Delete the space between two words (word count drops by one).
  let space_at = hot_path_index_of(source3, " wth")
  let source4 = (source3[:space_at] + source3[space_at + 1:]).to_owned()
  session = hot_path_apply_edit(session, source4)
  hot_path_assert_matches_scratch(session, source4)
  // Append a full word at the end (word count rises by one).
  let source5 = source4 + " omega"
  session = hot_path_apply_edit(session, source5)
  hot_path_assert_matches_scratch(session, source5)
  assert_true(
    session.word_count > MarkdownDocumentSession::new(source4).word_count,
  )
}

///|
/// A2's work contract: a keystroke must only pay derived-bookkeeping work
/// for the re-parse window — not the whole document.
test "hot path: keystroke bookkeeping work stays inside the re-parse window" {
  let mut session = MarkdownDocumentSession::new(hot_path_bench_document(60))
  let block_count = session.editor_blocks.length()
  assert_true(block_count > 600)
  hot_path_metrics_reset()
  for _ in 0..<5 {
    session = hot_path_apply_edit(session, session.source + "x")
  }
  let keystrokes = 5
  assert_eq(hot_path_full_parse_count.val, 0)
  assert_eq(hot_path_incremental_fallback_count.val, 0)
  assert_eq(hot_path_region_reparse_count.val, keystrokes)
  // The trailing cluster is a couple of blocks; whole-document work would
  // show thousands of fingerprint builds and height recomputes here.
  assert_true(hot_path_block_fingerprints_built.val < block_count)
  assert_true(hot_path_height_metrics_recomputed.val < block_count)
}

///|
/// Id stability across appends: the reindex pass reuses prefix/suffix ids
/// and revisions by position, so untouched blocks never re-stamp.
test "hot path: untouched block ids and revisions survive appends" {
  let start = MarkdownDocumentSession::new(hot_path_bench_document(30))
  let mut session = start
  for _ in 0..<3 {
    session = hot_path_apply_edit(session, session.source + "y")
  }
  let mut stable = 0
  for index, block in session.blocks {
    if index < start.blocks.length() &&
      start.blocks[index].fingerprint == block.fingerprint {
      if start.blocks[index].id == block.id &&
        start.blocks[index].revision == block.revision {
        stable = stable + 1
      }
    }
  }
  assert_true(stable >= start.blocks.length() - 2)
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
