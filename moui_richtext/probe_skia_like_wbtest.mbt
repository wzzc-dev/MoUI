///|
/// Mimic real SkParagraph: hard-break lines at every '\n', line text_range
/// ends exclude the newline.
fn skia_like_layout(
  input : @core.TextLayoutInput,
) -> @core.TextParagraphLayoutResult {
  let chars = input.text.to_array()
  let line_height = input.font.size * 1.55
  let char_width = 10.0
  let lines : Array[@core.TextParagraphLineMetrics] = []
  let caret_rects : Array[@core.Rect] = []
  let mut line_start = 0
  let mut line_index = 0
  for index, ch in chars {
    let column = index - line_start
    caret_rects.push(
      @core.Rect::new(
        x=column.to_double() * char_width,
        y=line_index.to_double() * line_height,
        width=1.0,
        height=line_height,
      ),
    )
    if ch == '\n' {
      lines.push({
        line_index,
        text_range: @core.TextRange::new(start=line_start, end=index),
        origin: @core.Point::new(x=0.0, y=line_index.to_double() * line_height),
        size: @core.Size::new(
          width=column.to_double() * char_width,
          height=line_height,
        ),
        baseline: line_index.to_double() * line_height + line_height * 0.8,
      })
      line_index = line_index + 1
      line_start = index + 1
    }
  }
  let tail = chars.length() - line_start
  caret_rects.push(
    @core.Rect::new(
      x=tail.to_double() * char_width,
      y=line_index.to_double() * line_height,
      width=1.0,
      height=line_height,
    ),
  )
  lines.push({
    line_index,
    text_range: @core.TextRange::new(start=line_start, end=chars.length()),
    origin: @core.Point::new(x=0.0, y=line_index.to_double() * line_height),
    size: @core.Size::new(
      width=tail.to_double() * char_width,
      height=line_height,
    ),
    baseline: line_index.to_double() * line_height + line_height * 0.8,
  })
  let clusters = @core.TextGraphemeBoundaries::new(text=input.text).cluster_count()
  {
    text: input.text,
    size: @core.Size::new(
      width=640.0,
      height=line_index.to_double() * line_height + line_height,
    ),
    baseline: line_height * 0.8,
    lines,
    caret_rects,
    visual_order: {
      logical_text: input.text,
      visual_text: input.text,
      logical_cluster_count: clusters,
      visual_cluster_count: clusters,
      segment_count: 1,
      glyph_count: chars.length(),
      visual_order_differs: false,
      bidi_visual_order_ready: false,
    },
    metadata: {
      text_system_id: "skia-like-test",
      paragraph_layout_available: true,
      line_metrics_available: true,
      selection_rects_available: true,
      hit_test_available: true,
      native_paragraph_ready: true,
      bidi_visual_order_ready: false,
    },
  }
}

///|
test "soft break wrap does not double the hard newline" {
  let text_system = @core.TextSystem::new(
    id="skia-like-test",
    measure=input => {
      let width = input.text.to_array().length().to_double() * 10.0
      {
        size: @core.Size::new(width~, height=input.font.size * 1.55),
        baseline: input.font.size * 1.2,
        caret_positions: Array::make(input.text.to_array().length() + 1, 0.0),
      }
    },
    paragraph_layout=Some(skia_like_layout),
  )
  let block = markdown_block_to_rich_text(
    parse_markdown("123\n123")[0],
    @core.FontSpec::new(size=16.0),
  )
  // Width 640 would not wrap "123\n123" by width; the only line boundary
  // comes from the hard newline, and the wrap pass must not inject a
  // second one.
  let wrapped = rich_text_block_soft_wrap(
    block,
    640.0,
    @core.FontSpec::new(size=16.0),
    text_system,
  )
  let mut joined = ""
  for run in wrapped.runs {
    joined = joined + rich_text_run_visual_text(run)
  }
  inspect(joined, content="123\n123")
  let heights = rich_text_block_line_heights(
    wrapped,
    @core.FontSpec::new(size=16.0),
    text_system,
    640.0,
  )
  inspect(heights.length(), content="2")
}
