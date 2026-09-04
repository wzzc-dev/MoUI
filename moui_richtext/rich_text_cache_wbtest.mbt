///|
test "cached rich block conversions rebase source ranges after upstream edits" {
  let source =
    #|First paragraph.
    #|
    #|Some **bold** text lives here.
    #|
    #|Tail paragraph.
    #|
  let base = @core.FontSpec::new(size=16.0)
  let session = MarkdownDocumentSession::new(source)
  // Blank source lines are editable blocks too, so locate the prose
  // block by unique text instead of a fixed index.
  let mut middle : MarkdownEditorBlock? = None
  for block in session.editor_blocks {
    if middle is None && block.block.text == "Some **bold** text lives here." {
      middle = Some(block)
    }
  }
  let middle = middle.unwrap()
  let before = markdown_editor_block_to_rich_text(source, middle, base)
  let next = session.replace_source("Typed intro.\n\n" + source)
  let mut shifted : MarkdownEditorBlock? = None
  for block in next.editor_blocks {
    if shifted is None &&
      block.block.text == middle.block.text &&
      block.block.kind == middle.block.kind {
      shifted = Some(block)
    }
  }
  let shifted = shifted.unwrap()
  let delta = shifted.source_range.start - middle.source_range.start
  assert_true(delta > 0)
  // This call hits the content-keyed conversion cache even though the
  // block's absolute offsets moved; the rebase must reproduce exactly
  // what a fresh uncached conversion produces at the new offsets.
  let cached = markdown_editor_block_to_rich_text(next.source, shifted, base)
  let fresh = markdown_editor_block_to_rich_text_uncached(
    next.source,
    shifted,
    base,
    base_dir=None,
  )
  assert_true(cached == fresh)
  match (before.source_range, cached.source_range) {
    (Some(before_range), Some(cached_range)) => {
      assert_true(cached_range.start == before_range.start + delta)
      assert_true(cached_range.end == before_range.end + delta)
    }
    _ => assert_true(false)
  }
}

///|
test "measured block height lookups key on content, font, and width" {
  let base = @core.FontSpec::new(size=16.0)
  let block = MarkdownEditorBlock::{
    block: MarkdownBlock::{
      kind: Paragraph,
      text: "Height probe",
      inlines: [],
      table_alignments: [],
      code_language: None,
    },
    source_range: { start: 0, end: 12 },
    content_range: { start: 0, end: 12 },
  }
  let recorded = rich_text_record_block_measured_height(
    block,
    base,
    width=420.0,
    height=47.5,
  )
  assert_true(recorded)
  let hit = rich_text_block_measured_height(block, base, width=420.0)
  let other_width = rich_text_block_measured_height(block, base, width=421.0)
  let other_font = rich_text_block_measured_height(
    block,
    @core.FontSpec::new(size=18.0),
    width=420.0,
  )
  assert_true(hit == Some(47.5))
  assert_true(other_width == None)
  assert_true(other_font == None)
}
