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
  let cached = markdown_editor_block_to_rich_text(next.source(), shifted, base)
  let fresh = markdown_editor_block_to_rich_text_uncached(
    next.source(),
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
test "measured block height lookups key on identity, font, and width" {
  let base = @core.FontSpec::new(size=16.0)
  let recorded = rich_text_record_block_measured_height(
    base,
    width=420.0,
    block_id=1,
    block_revision=0,
    height=47.5,
  )
  assert_true(recorded)
  let seed = rich_text_block_height_digest_seed(base, width=420.0)
  let hit = rich_text_block_measured_height(
    base,
    width=420.0,
    seed~,
    block_id=1,
    block_revision=0,
  )
  let other_width = rich_text_block_measured_height(
    base,
    width=421.0,
    seed=rich_text_block_height_digest_seed(base, width=421.0),
    block_id=1,
    block_revision=0,
  )
  let other_font = rich_text_block_measured_height(
    @core.FontSpec::new(size=18.0),
    width=420.0,
    seed=rich_text_block_height_digest_seed(
      @core.FontSpec::new(size=18.0),
      width=420.0,
    ),
    block_id=1,
    block_revision=0,
  )
  // A revision bump is a content change: the old height must not leak.
  let other_revision = rich_text_block_measured_height(
    base,
    width=420.0,
    seed~,
    block_id=1,
    block_revision=1,
  )
  assert_true(hit == Some(47.5))
  assert_true(other_width == None)
  assert_true(other_font == None)
  assert_true(other_revision == None)
}

///|
test "measured block heights do not leak across document sessions" {
  let base = @core.FontSpec::new(size=16.0)
  let first_digest = 0x1111222233334444UL
  let second_digest = 0x5555666677778888UL
  let first = rich_text_record_block_measured_height(
    base,
    width=420.0,
    block_id=1,
    block_revision=0,
    height=72.0,
    source_digest=Some(first_digest),
  )
  assert_true(first)
  let second_seed = rich_text_block_height_digest_seed(
    base,
    width=420.0,
    source_digest=Some(second_digest),
  )
  // A new document reuses block id 1/revision 0, but it must start with a
  // cache miss until that document paints the block itself.
  let second_before = rich_text_block_measured_height(
    base,
    width=420.0,
    seed=second_seed,
    block_id=1,
    block_revision=0,
    source_digest=Some(second_digest),
  )
  assert_true(second_before == None)
  let second = rich_text_record_block_measured_height(
    base,
    width=420.0,
    block_id=1,
    block_revision=0,
    height=31.0,
    source_digest=Some(second_digest),
  )
  assert_true(second)
  let second_after = rich_text_block_measured_height(
    base,
    width=420.0,
    seed=second_seed,
    block_id=1,
    block_revision=0,
    source_digest=Some(second_digest),
  )
  assert_true(second_after == Some(31.0))
  let first_seed = rich_text_block_height_digest_seed(
    base,
    width=420.0,
    source_digest=Some(first_digest),
  )
  let first_after = rich_text_block_measured_height(
    base,
    width=420.0,
    seed=first_seed,
    block_id=1,
    block_revision=0,
    source_digest=Some(first_digest),
  )
  assert_true(first_after == Some(72.0))
}
