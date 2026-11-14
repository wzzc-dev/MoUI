///|
test "block line metrics cache shares heights and widths" {
  hot_path_metrics_reset()
  let block = RichTextBlock::new(runs=[
    RichTextRun::new(text="alpha\nbeta gamma"),
  ])
  let font = @core.FontSpec::new(size=16.0)
  let text_system = @core.TextSystem::fallback()
  let heights = rich_text_block_line_heights(block, font, text_system, 240.0)
  let widths = rich_text_block_line_widths(block, font, text_system, 240.0)
  let heights_again = rich_text_block_line_heights(
    block, font, text_system, 240.0,
  )
  assert_eq(heights.length(), 2)
  assert_eq(widths.length(), 2)
  assert_eq(heights_again.length(), 2)
  inspect(hot_path_line_metrics_builds.val, content="1")
  inspect(hot_path_line_metrics_cache_hits.val, content="2")
  // A changed width is a different key and must rebuild.
  let _ = rich_text_block_line_heights(block, font, text_system, 300.0)
  inspect(hot_path_line_metrics_builds.val, content="2")
}
