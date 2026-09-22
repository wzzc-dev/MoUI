///|
/// Collect the drawn text of one paint layer in draw order. Two frames that
/// should rasterize a block identically must produce equal arrays here.
fn layer_drawn_texts(
  layer : @core.ViewPaintLayer,
  texts : Array[String],
) -> Unit {
  for command in layer.commands {
    match command {
      @core.DrawCommand::DrawText(run) => texts.push(run.text)
      _ => ()
    }
  }
}

///|
/// Find the paint layer whose drawn text contains `marker`.
fn find_layer_with_text(
  layers : Array[@core.ViewPaintLayer],
  marker : String,
) -> @core.ViewPaintLayer? {
  for layer in layers {
    let texts : Array[String] = []
    layer_drawn_texts(layer, texts)
    for text in texts {
      if text.contains(marker) {
        return Some(layer)
      }
    }
  }
  None
}

///|
/// Build the visible window at `scroll_y` and paint it into block layers,
/// mirroring `markdown_session_editor_paint`.
fn paint_window_layers(
  session : MarkdownDocumentSession,
  selection : MarkdownEditorSelection,
  base : @core.FontSpec,
  content : @core.Rect,
  scroll_y : Double,
  viewport_height : Double,
  overscan : Double,
) -> Array[@core.ViewPaintLayer] {
  let window = markdown_session_visible_window(
    session,
    selection,
    base,
    source_mode=false,
    focus_mode=false,
    base_dir=None,
    visible_scroll_y=scroll_y,
    visible_viewport_height=viewport_height,
    visible_overscan=overscan,
    content_width=content.size.width,
    text_system=@core.TextSystem::fallback(),
  )
  let window_content = window.content_rect(content)
  let layers : Array[@core.ViewPaintLayer] = []
  append_rich_text_document_layers(
    layers,
    window.document,
    window_content,
    base,
    @core.Color::black(),
    text_system=@core.TextSystem::fallback(),
    visible_scroll_y=0.0,
    visible_viewport_height=viewport_height,
    clip_rect=Some(content),
  )
  layers
}

///|
/// Regression: a fenced code block scrolled into the viewport for the first
/// time stayed blank (only the language label painted) until a click or a
/// later relayout. Line-level viewport culling drew no text when the block
/// first entered the visible band at its bottom edge, and the retained-layer
/// cache then re-pasted that textless raster on every scrolled frame — its
/// cache key and content revision do not encode the visible band. Band-fitting
/// blocks must therefore paint ALL their lines in every frame, so the first
/// admitted raster is already final.
test "band-fitting blocks paint every line at band-edge admission" {
  ignore(markdown_scroll_take_geometry_compensation())
  let base = @core.FontSpec::new(size=19.0)
  let width = 717.0
  let text_system = @core.TextSystem::fallback()
  let marker = "MARKER_SH_UNIQUE_9247"
  let parts : Array[String] = []
  for index in 0..<30 {
    parts.push("Paragraph \{index} with some flowing text to grow the page.")
  }
  parts.push("```sh")
  parts.push("echo \{marker}")
  parts.push("echo second line of the block")
  parts.push("```")
  parts.push("Trailing paragraph after the fenced code block.")
  let source = parts.join("\n\n")
  let session = MarkdownDocumentSession::new(source)
  let selection : MarkdownEditorSelection = { caret: 0, selection: None }
  let viewport_height = 520.0
  let overscan = 320.0
  let content = @core.Rect::new(x=0.0, y=0.0, width~, height=viewport_height)
  // Warm the measured-height feed so block offsets match what the window and
  // the layer builder both use.
  let warm = markdown_session_visible_window(
    session,
    selection,
    base,
    source_mode=false,
    focus_mode=false,
    base_dir=None,
    visible_scroll_y=0.0,
    visible_viewport_height=viewport_height,
    visible_overscan=overscan,
    content_width=width,
    text_system~,
  )
  ignore(
    markdown_session_record_measured_block_heights(
      session,
      warm,
      content_width=width,
      base~,
      base_dir=None,
      text_system~,
      visible_scroll_y=0.0,
    ),
  )
  ignore(markdown_scroll_take_geometry_compensation())
  // Document-space top of the code block. Estimates carry wrap drift, so the
  // admission scroll is scanned around it instead of computed exactly.
  let heights = match
    markdown_document_block_heights(session, base, content_width=width) {
    Some(heights) => heights
    None => fail("expected block heights after measuring the document")
  }
  let mut code_index = -1
  for index, block in session.editor_blocks {
    if block.block.kind is MarkdownBlockKind::CodeBlock {
      code_index = index
      break
    }
  }
  if code_index < 0 {
    fail("document should contain a fenced code block")
  }
  let mut code_top = 0.0
  for index in 0..<code_index {
    code_top = code_top + heights[index]
  }
  // The settled frame: block fully inside the viewport.
  let settled_layers = paint_window_layers(
    session, selection, base, content, code_top, viewport_height, overscan,
  )
  let settled_layer = match find_layer_with_text(settled_layers, marker) {
    Some(layer) => layer
    None => fail("code block should be painted once scrolled into view")
  }
  let settled_texts : Array[String] = []
  layer_drawn_texts(settled_layer, settled_texts)
  if settled_layer.cache_key == "" {
    fail("band-fitting code block should stay in the retained-layer cache")
  }
  // Scan upward from the estimated admission offset for the first frame whose
  // layer list contains the block — that is the raster the cache admits.
  let admission_texts : Array[String] = []
  let mut admitted = false
  let mut scroll_y = code_top - viewport_height - overscan - 120.0
  let scan_end = scroll_y + 240.0
  while scroll_y <= scan_end {
    let layers = paint_window_layers(
      session, selection, base, content, scroll_y, viewport_height, overscan,
    )
    match find_layer_with_text(layers, marker) {
      Some(layer) => {
        layer_drawn_texts(layer, admission_texts)
        if layer.cache_key == "" {
          fail("band-fitting code block must keep its retained-layer key")
        }
        admitted = true
        break
      }
      None => scroll_y = scroll_y + 4.0
    }
  }
  if !admitted {
    fail("code block was never admitted near its estimated offset")
  }
  if admission_texts.length() != settled_texts.length() {
    fail(
      "admitted raster differs from settled raster: \{admission_texts.length().to_string()} drawn segments vs \{settled_texts.length().to_string()}",
    )
  }
  for index, text in admission_texts {
    if text != settled_texts[index] {
      fail(
        "admitted raster differs from settled raster at segment \{index.to_string()}: \{text} vs \{settled_texts[index]}",
      )
    }
  }
}

///|
/// Blocks taller than the visible band keep line culling (the novel-sized
/// paragraph case), and their raster then depends on where they sat in the
/// band — so they must opt out of the retained-layer cache (empty cache key)
/// instead of freezing a partial raster.
test "blocks taller than the visible band opt out of the layer cache" {
  ignore(markdown_scroll_take_geometry_compensation())
  let base = @core.FontSpec::new(size=19.0)
  let width = 717.0
  let text_system = @core.TextSystem::fallback()
  let marker = "TALLBLOCKMARKER5183"
  let parts : Array[String] = []
  for index in 0..<6 {
    parts.push("Paragraph \{index} before the tall block.")
  }
  let tall_lines : Array[String] = []
  for index in 0..<60 {
    tall_lines.push("line \{index} \{marker}")
  }
  parts.push(tall_lines.join("\n"))
  parts.push("Paragraph after the tall block.")
  let source = parts.join("\n\n")
  let session = MarkdownDocumentSession::new(source)
  let selection : MarkdownEditorSelection = { caret: 0, selection: None }
  let viewport_height = 520.0
  let overscan = 320.0
  let content = @core.Rect::new(x=0.0, y=0.0, width~, height=viewport_height)
  let warm = markdown_session_visible_window(
    session,
    selection,
    base,
    source_mode=false,
    focus_mode=false,
    base_dir=None,
    visible_scroll_y=0.0,
    visible_viewport_height=viewport_height,
    visible_overscan=overscan,
    content_width=width,
    text_system~,
  )
  ignore(
    markdown_session_record_measured_block_heights(
      session,
      warm,
      content_width=width,
      base~,
      base_dir=None,
      text_system~,
      visible_scroll_y=0.0,
    ),
  )
  ignore(markdown_scroll_take_geometry_compensation())
  let heights = match
    markdown_document_block_heights(session, base, content_width=width) {
    Some(heights) => heights
    None => fail("expected block heights after measuring the document")
  }
  let mut tall_index = -1
  for index, block in session.editor_blocks {
    if block.block.text.contains(marker) {
      tall_index = index
      break
    }
  }
  if tall_index < 0 {
    fail("document should contain the tall paragraph block")
  }
  let mut tall_top = 0.0
  for index in 0..<tall_index {
    tall_top = tall_top + heights[index]
  }
  // Scan for the first frame where the tall block's layer exists while it
  // straddles the band bottom (line culling engaged).
  let mut straddling_key : String? = None
  let mut scroll_y = tall_top - 400.0 - 150.0
  let scan_end = scroll_y + 300.0
  while scroll_y <= scan_end {
    let layers = paint_window_layers(
      session, selection, base, content, scroll_y, viewport_height, overscan,
    )
    match find_layer_with_text(layers, marker) {
      Some(layer) => {
        straddling_key = Some(layer.cache_key)
        break
      }
      None => scroll_y = scroll_y + 4.0
    }
  }
  match straddling_key {
    Some(key) =>
      if key != "" {
        fail(
          "culled tall block must opt out of the retained-layer cache, got key \{key}",
        )
      }
    None => fail("tall block should be painted while straddling the band")
  }
}
