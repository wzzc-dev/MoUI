///|
fn scroll_window_assert_stable_blank_geometry(source : String) -> Unit raise {
  ignore(markdown_scroll_take_geometry_compensation())
  let base = @core.FontSpec::new(size=17.0)
  let text_system = @core.TextSystem::fallback()
  let width = 600.0
  let session = MarkdownDocumentSession::new(source)
  let selection : MarkdownEditorSelection = { caret: 0, selection: None, }
  let full = markdown_session_visible_window(
    session,
    selection,
    base,
    source_mode=false,
    focus_mode=false,
    base_dir=None,
    visible_scroll_y=0.0,
    visible_viewport_height=0.0,
    visible_overscan=0.0,
    content_width=width,
    text_system~,
  )
  ignore(
    markdown_session_record_measured_block_heights(
      session,
      full,
      content_width=width,
      base~,
      base_dir=None,
      text_system~,
      visible_scroll_y=0.0,
    ),
  )
  ignore(markdown_scroll_take_geometry_compensation())
  let tops : Array[Double] = []
  let mut top = 0.0
  for block in full.document.blocks {
    tops.push(top)
    top = top +
      rich_text_block_total_height(block, base, text_system, block_width=width)
  }
  for step in 0..<200 {
    let window = markdown_session_visible_window(
      session,
      selection,
      base,
      source_mode=false,
      focus_mode=false,
      base_dir=None,
      visible_scroll_y=step.to_double() * 10.0,
      visible_viewport_height=300.0,
      visible_overscan=320.0,
      content_width=width,
      text_system~,
    )
    let mut y = window.top_padding
    for offset, block in window.document.blocks {
      let index = window.visible_start + offset
      assert_true(
        (y - tops[index]).abs() < 0.001,
        msg="block \{index} at scroll \{window.scroll_y} moved from \{tops[index]} to \{y}",
      )
      let expected = rich_text_block_total_height(
        full.document.blocks[index],
        base,
        text_system,
        block_width=width,
      )
      let actual = rich_text_block_total_height(
        block,
        base,
        text_system,
        block_width=width,
      )
      assert_true(
        (actual - expected).abs() < 0.001,
        msg="block \{index} at scroll \{window.scroll_y} changed height from \{expected} to \{actual}",
      )
      y = y + actual
    }
  }
}

///|
test "window boundaries preserve heading positions across blank runs" {
  let parts : Array[String] = []
  for index in 0..<20 {
    parts.push("## Heading \{index}\n\n\n\nBody \{index}.")
  }
  scroll_window_assert_stable_blank_geometry(parts.join("\n\n\n\n"))
}

///|
test "a blank-only viewport retains the surrounding document spacing" {
  scroll_window_assert_stable_blank_geometry(
    "## Before" + "\n".repeat(100) + "## After\n\nBody.",
  )
}

///|
test "a wholly blank document retains every writing line while scrolling" {
  scroll_window_assert_stable_blank_geometry("\n".repeat(100))
}

///|
test "blank-run context stays cached while scrolling and refreshes after an edit" {
  let session = MarkdownDocumentSession::new("Before\n\n\n\nAfter")
  assert_eq(markdown_document_window_blank_gap_context(session, 2), (1, true))
  let cached = markdown_window_blank_gap_run.val.unwrap()
  assert_eq(markdown_document_window_blank_gap_context(session, 3), (2, true))
  assert_true(
    physical_equal(cached, markdown_window_blank_gap_run.val.unwrap()),
  )
  let next = session.apply(
    MarkdownEditTransaction::from_sources(
      session.source(),
      "Before\n\n\n\n\nAfter",
      reason=TextInput,
    ),
  )
  assert_eq(next.document_identity, session.document_identity)
  assert_eq(markdown_document_window_blank_gap_context(next, 4), (3, true))
  let refreshed = markdown_window_blank_gap_run.val.unwrap()
  assert_false(physical_equal(cached, refreshed))
  assert_eq(refreshed.revision, next.revision)
}
