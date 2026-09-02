///|
/// Internal shared helpers for read-only rich text/markdown viewers.
/// Uses MarkdownDocumentSession for editor-parity layout and rendering.

///|
priv struct RichTextDocumentViewPrepared {
  document : RichTextDocument
  content_height : Double
  block_tops : Array[Double]
  block_heights : Array[Double]
}

///|
fn RichTextDocumentViewPrepared::new(
  document : RichTextDocument,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
  block_width : Double,
) -> RichTextDocumentViewPrepared {
  let block_tops : Array[Double] = []
  let block_heights : Array[Double] = []
  let mut content_height = 0.0
  for block in document.blocks {
    let height = rich_text_block_line_height(
        block,
        base_font,
        text_system,
        block_width~,
      ) +
      block.inset.top +
      block.inset.bottom
    block_tops.push(content_height)
    block_heights.push(height)
    content_height = content_height + height
  }
  { document, content_height, block_tops, block_heights }
}

///|
/// A bounded process-local entry keeps prepared documents alive across view
/// reconciliation. Scroll position is application state in the virtual-list
/// API, so the viewer node itself is rebuilt for every scroll update; without
/// this shared store each rebuilt node would parse and measure its source again.
priv struct RichTextDocumentViewCacheEntry {
  source : String
  width : Double
  base_font : @core.FontSpec
  text_system_id : String
  prepared : RichTextDocumentViewPrepared
}

///|
let rich_text_document_view_cache_store : Ref[
  Array[RichTextDocumentViewCacheEntry],
] = Ref([])

///|
fn rich_text_document_view_cache_capacity() -> Int {
  64
}

///|
priv struct RichTextDocumentViewCache {
  mut source : String?
  mut width : Double
  mut base_font : @core.FontSpec?
  mut text_system_id : String
  mut prepared : RichTextDocumentViewPrepared?
}

///|
fn RichTextDocumentViewCache::new() -> RichTextDocumentViewCache {
  {
    source: None,
    width: 0.0,
    base_font: None,
    text_system_id: "",
    prepared: None,
  }
}

///|
fn RichTextDocumentViewCache::prepare(
  self : RichTextDocumentViewCache,
  source : String,
  width : Double,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> RichTextDocumentViewPrepared {
  if self.source == Some(source) &&
    self.width == width &&
    self.base_font == Some(base_font) &&
    self.text_system_id == text_system.id() {
    match self.prepared {
      Some(prepared) => return prepared
      None => ()
    }
  }
  // View nodes are immutable snapshots and may be recreated by a model
  // update. Reuse a recent prepared document before doing Markdown parsing or
  // native text measurement again.
  for entry in rich_text_document_view_cache_store.val {
    if entry.source == source &&
      entry.width == width &&
      entry.base_font == base_font &&
      entry.text_system_id == text_system.id() {
      self.source = Some(source)
      self.width = width
      self.base_font = Some(base_font)
      self.text_system_id = text_system.id()
      self.prepared = Some(entry.prepared)
      return entry.prepared
    }
  }
  let session = MarkdownDocumentSession::new(source)
  let dummy_selection : MarkdownEditorSelection = { caret: 0, selection: None }
  let document = session.rich_text(
    dummy_selection,
    base=base_font,
    source_mode=false,
    focus_mode=false,
    base_dir=None,
  )
  let wrapped = rich_text_document_view_wrap(
    document, width, base_font, text_system,
  )
  let prepared = RichTextDocumentViewPrepared::new(
    wrapped, base_font, text_system, width,
  )
  self.source = Some(source)
  self.width = width
  self.base_font = Some(base_font)
  self.text_system_id = text_system.id()
  self.prepared = Some(prepared)
  let store = rich_text_document_view_cache_store.val
  if store.length() >= rich_text_document_view_cache_capacity() {
    ignore(store.remove(0))
  }
  store.push({
    source,
    width,
    base_font,
    text_system_id: text_system.id(),
    prepared,
  })
  prepared
}

///|
/// Calculate content height using MarkdownDocumentSession for editor-parity.
/// This matches session.estimated_content_height() behavior.
fn rich_text_document_session_view_measure_height(
  source : String,
  view_size : @core.Size,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
  cache : RichTextDocumentViewCache,
) -> Double {
  let content_rect = rich_text_editor_content_rect(
    @core.Rect::new(
      x=0.0,
      y=0.0,
      width=view_size.width,
      height=view_size.height,
    ),
  )
  let prepared = cache.prepare(
    source,
    content_rect.size.width,
    base_font,
    text_system,
  )
  prepared.content_height + content_rect.origin.y * 2.0
}

///|
/// Internal shared paint logic using MarkdownDocumentSession for editor-parity.
/// Creates a read-only window (no selection) and renders document layers.
fn rich_text_document_session_view_paint(
  ctx : @core.ViewPaintContext,
  source : String,
  base_font : @core.FontSpec,
  foreground : @core.Color,
  background : @core.Brush,
  corner_radius : Double,
  visible_scroll_y : Double,
  visible_viewport_height : Double,
  visible_overscan : Double,
  cache : RichTextDocumentViewCache,
) -> @core.ViewPaintPlan {
  let commands : Array[@core.DrawCommand] = []
  let rounded = @core.RoundedRect::new(rect=ctx.frame, radius=corner_radius)
  commands.push(@core.DrawCommand::FillRoundedRectBrush(rounded, background))
  let content = rich_text_editor_content_rect(ctx.frame)
  commands.push(@core.DrawCommand::PushClip(content))

  let prepared = cache.prepare(
    source,
    content.size.width,
    base_font,
    ctx.text_system,
  )
  let (window_document, top_padding) = rich_text_document_view_window(
    prepared, visible_scroll_y, visible_viewport_height, visible_overscan,
  )
  // The parent scroll view already translates this view's frame by the
  // current offset. Only restore the omitted window prefix here.
  let document_content = rich_text_document_view_window_content_rect(
    content, top_padding,
  )

  let child_layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    child_layers,
    window_document,
    document_content,
    base_font,
    foreground,
    text_system=ctx.text_system,
    clip_rect=Some(content),
  )
  let overlay_commands : Array[@core.DrawCommand] = []
  for layer in child_layers {
    commands.append(layer.commands)
    overlay_commands.append(layer.overlay_commands)
  }

  {
    commands,
    child_layers: [],
    post_commands: [@core.DrawCommand::PopClip],
    overlay_commands,
    repaint_boundary: false,
    animating: false,
  }
}

///|
fn rich_text_document_view_window_content_rect(
  content : @core.Rect,
  top_padding : Double,
) -> @core.Rect {
  content.offset(dx=0.0, dy=top_padding)
}

///|
/// Hit-test a point against the document rendered via session window,
/// returning the source offset for link resolution.
fn rich_text_document_session_view_offset_at_point(
  source : String,
  point : @core.Point,
  frame : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
  visible_scroll_y : Double,
  visible_viewport_height : Double,
  visible_overscan : Double,
) -> Int? {
  ignore(visible_overscan)
  let content = rich_text_editor_content_rect(frame)
  let session = MarkdownDocumentSession::new(source)
  let dummy_selection : MarkdownEditorSelection = { caret: 0, selection: None }
  let document = session.rich_text(
    dummy_selection,
    base=base_font,
    source_mode=false,
    focus_mode=false,
    base_dir=None,
  )
  let wrapped = rich_text_document_view_wrap(
    document,
    content.size.width,
    base_font,
    text_system,
  )
  ignore(visible_scroll_y)
  ignore(visible_viewport_height)
  rich_text_document_source_offset_at_point(
    wrapped, point, content, base_font, text_system,
  )
}

///|
fn rich_text_document_view_wrap(
  document : RichTextDocument,
  width : Double,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> RichTextDocument {
  let blocks : Array[RichTextBlock] = []
  for block in document.blocks {
    blocks.push(rich_text_block_soft_wrap(block, width, base_font, text_system))
  }
  { blocks, }
}

///|
fn rich_text_document_view_window(
  prepared : RichTextDocumentViewPrepared,
  scroll_y : Double,
  viewport_height : Double,
  overscan : Double,
) -> (RichTextDocument, Double) {
  if viewport_height <= 0.0 {
    return (prepared.document, 0.0)
  }
  let visible_top = max_double(0.0, scroll_y - overscan)
  let visible_bottom = scroll_y + viewport_height + overscan
  let blocks : Array[RichTextBlock] = []
  let mut y = 0.0
  let mut top_padding = 0.0
  for index, block in prepared.document.blocks {
    y = prepared.block_tops[index]
    let block_height = prepared.block_heights[index]
    let block_bottom = y + block_height
    if block_bottom >= visible_top && y <= visible_bottom {
      if blocks.is_empty() {
        top_padding = y
      }
      blocks.push(block)
    } else if y > visible_bottom {
      break
    }
  }
  ({ blocks, }, top_padding)
}

///|
fn rich_text_document_view_wrap_block(
  block : RichTextBlock,
  width : Double,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> RichTextBlock {
  if block.rule || block.table is Some(_) || block.runs.is_empty() {
    return block
  }
  if block.runs.any(run => run.image_source is Some(_)) {
    return block
  }
  let available_width = max_double(
    1.0,
    width - block.inset.left - block.inset.right,
  )
  let visual = rich_text_document_view_block_visual_text(block)
  let wrap_font = rich_text_document_view_wrap_font(
    block, visual, base_font, text_system,
  )
  let layout = text_system.layout_paragraph(
    @core.TextLayoutInput::new(
      text=visual,
      font=wrap_font,
      max_width=available_width,
    ),
  )
  if layout.lines.length() <= 1 {
    return block
  }
  let soft_breaks : Array[Int] = []
  let visual_length = visual.to_array().length()
  for index, line in layout.lines {
    if index + 1 < layout.lines.length() &&
      line.text_range.end > 0 &&
      line.text_range.end < visual_length {
      soft_breaks.push(line.text_range.end)
    }
  }
  if soft_breaks.is_empty() {
    return block
  }
  let runs : Array[RichTextRun] = []
  let mut offset = block.prefix.to_array().length()
  for run in block.runs {
    let run_visual = rich_text_run_visual_text(run)
    let run_length = run_visual.to_array().length()
    let local_breaks : Array[Int] = []
    for soft_break in soft_breaks {
      if soft_break > offset && soft_break <= offset + run_length {
        local_breaks.push(soft_break - offset)
      }
    }
    if local_breaks.is_empty() {
      runs.push(run)
    } else {
      runs.push({
        ..run,
        visual_text: Some(
          rich_text_document_view_insert_breaks(run_visual, local_breaks),
        ),
      })
    }
    offset = offset + run_length
  }
  { ..block, runs, }
}

///|
fn rich_text_document_view_wrap_font(
  block : RichTextBlock,
  visual : String,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> @core.FontSpec {
  let mut widest_font = rich_text_block_font(block, base_font)
  let mut widest_width = rich_text_width(visual, widest_font, text_system)
  for run in block.runs {
    match run.font {
      Some(font) => {
        let width = rich_text_width(visual, font, text_system)
        if width > widest_width {
          widest_font = font
          widest_width = width
        }
      }
      None => ()
    }
  }
  widest_font
}

///|
fn rich_text_document_view_block_visual_text(block : RichTextBlock) -> String {
  let parts : Array[String] = [block.prefix]
  for run in block.runs {
    parts.push(rich_text_run_visual_text(run))
  }
  parts.join("")
}

///|
fn rich_text_document_view_insert_breaks(
  value : String,
  breaks : Array[Int],
) -> String {
  let chars = value.to_array()
  let output : Array[Char] = []
  for index, ch in chars {
    output.push(ch)
    let boundary = index + 1
    if breaks.any(value => value == boundary) &&
      ch != '\n' &&
      (boundary >= chars.length() || chars[boundary] != '\n') {
      output.push('\n')
    }
  }
  String::from_array(output)
}
