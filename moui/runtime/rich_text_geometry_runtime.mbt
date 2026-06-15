///|
fn rich_text_block_source_offset_to_visual(
  block : RichTextBlock,
  source_offset : Int,
  content : RichTextSourceRange,
) -> Int {
  if source_offset < content.start {
    0
  } else if source_offset > content.end {
    rich_text_block_visual_length(block)
  } else {
    let prefix_length = text_length(block.prefix)
    match rich_text_block_run_visual_offset_from_source(block, source_offset) {
      Some(offset) => prefix_length + offset
      None =>
        clamp_int(
          prefix_length + source_offset - content.start,
          0,
          rich_text_block_visual_length(block),
        )
    }
  }
}

///|
fn rich_text_block_run_visual_offset_from_source(
  block : RichTextBlock,
  source_offset : Int,
) -> Int? {
  let mut visual = 0
  for run in block.runs {
    let visual_text = rich_text_run_visual_text(run)
    let visual_length = text_length(visual_text)
    match run.source_range {
      Some(range) =>
        if source_offset <= range.end {
          return Some(
            visual +
            rich_text_run_visual_offset_from_source_offset(
              source_offset - range.start,
              run.text,
              visual_text,
            ),
          )
        }
      None => ()
    }
    visual = visual + visual_length
  }
  Some(visual)
}

///|
fn rich_text_table_column_count(table : RichTextTable) -> Int {
  let mut count = 0
  for row in table.rows {
    count = rich_text_max_int(count, row.length())
  }
  count
}

///|
fn rich_text_editor_content_rect(frame : Rect) -> Rect {
  frame.inset(Insets::symmetric(horizontal=14.0, vertical=12.0))
}

///|
fn rich_text_document_caret_rect_at_source(
  document : RichTextDocument,
  source_caret : Int,
  content : Rect,
  base_font : FontSpec,
  text_system? : TextSystem = TextSystem::fallback(),
) -> Rect? {
  rich_text_document_caret_rect(
    document, source_caret, content, base_font, text_system,
  )
}

///|
fn rich_text_editor_caret_at_point(
  data : RichTextEditorViewSpec,
  point : Point,
  frame : Rect,
  text_system : TextSystem,
) -> Int {
  let text = data.value.get()
  let document = (data.format)(text)
  let content = rich_text_editor_content_rect(frame)
  rich_text_document_source_offset_at_point(
    document,
    point,
    content,
    data.font,
    text_system,
  ).unwrap_or(text_length(text))
}

///|
fn rich_text_editor_prefix_source_offset_at_point(
  data : RichTextEditorViewSpec,
  point : Point,
  frame : Rect,
  text_system : TextSystem,
) -> Int? {
  let text = data.value.get()
  let document = (data.format)(text)
  let content = rich_text_editor_content_rect(frame)
  rich_text_document_prefix_source_offset_at_point(
    document,
    point,
    content,
    data.font,
    text_system,
  )
}

///|
fn rich_text_block_table_source_offset_at_point(
  block : RichTextBlock,
  point : Point,
  frame : Rect,
) -> Int? {
  match block.table {
    Some(table) => {
      let row_count = table.rows.length()
      let column_count = rich_text_table_column_count(table)
      if row_count == 0 || column_count == 0 || table.row_height <= 0.0 {
        return None
      }
      let row_index = clamp_int(
        ((point.y - frame.origin.y) / table.row_height).floor().to_int(),
        0,
        row_count - 1,
      )
      let column_width = frame.size.width / column_count.to_double()
      let column_index = clamp_int(
        ((point.x - frame.origin.x) / column_width).floor().to_int(),
        0,
        column_count - 1,
      )
      let row = table.rows[row_index]
      if column_index >= row.length() {
        return None
      }
      match row[column_index].source_range {
        Some(range) => {
          let x = clamp_double(
            point.x,
            frame.origin.x + column_width * column_index.to_double(),
            frame.origin.x + column_width * (column_index + 1).to_double(),
          )
          let relative = if column_width <= 0.0 {
            0.0
          } else {
            (x - (frame.origin.x + column_width * column_index.to_double())) /
            column_width
          }
          Some(
            clamp_int(
              range.start +
              (relative * (range.end - range.start).to_double())
              .round()
              .to_int(),
              range.start,
              range.end,
            ),
          )
        }
        None => None
      }
    }
    None => None
  }
}

///|
fn rich_text_block_source_offset_from_visual(
  block : RichTextBlock,
  visual_offset : Int,
) -> Int {
  match block.content_range {
    Some(content) => {
      let prefix_length = text_length(block.prefix)
      if visual_offset <= prefix_length {
        content.start
      } else {
        match
          rich_text_block_run_source_offset_from_visual(
            block,
            visual_offset - prefix_length,
          ) {
          Some(offset) => offset
          None =>
            clamp_int(
              content.start + visual_offset - prefix_length,
              content.start,
              content.end,
            )
        }
      }
    }
    None => visual_offset
  }
}

///|
fn rich_text_block_run_source_offset_from_visual(
  block : RichTextBlock,
  visual_offset : Int,
) -> Int? {
  let mut remaining = visual_offset
  let mut fallback = match block.content_range {
    Some(content) => Some(content.start)
    None => None
  }
  for run in block.runs {
    let visual_text = rich_text_run_visual_text(run)
    let visual_length = text_length(visual_text)
    if remaining <= visual_length {
      match run.source_range {
        Some(range) =>
          return Some(
            clamp_int(
              range.start +
              rich_text_run_source_offset_from_visual_offset(
                remaining,
                visual_text,
                run.text,
              ),
              range.start,
              range.end,
            ),
          )
        None => return fallback
      }
    }
    remaining = remaining - visual_length
    match run.source_range {
      Some(range) => fallback = Some(range.end)
      None => ()
    }
  }
  match block.runs.last() {
    Some(run) =>
      match run.source_range {
        Some(range) => Some(range.end)
        None => fallback
      }
    None => None
  }
}

///|
fn rich_text_document_has_source_ranges(document : RichTextDocument) -> Bool {
  document.blocks.any(block => block.content_range is Some(_))
}

///|
fn rich_text_caret_before_block(
  source_caret : Int,
  block : RichTextBlock,
) -> Bool {
  match block.source_range {
    Some(range) => source_caret < range.start
    None => false
  }
}

///|
fn rich_text_block_visual_offset(
  block : RichTextBlock,
  source_caret : Int,
) -> Int? {
  match (block.source_range, block.content_range) {
    (Some(source), Some(content)) =>
      if source_caret < source.start || source_caret > source.end {
        None
      } else if source_caret < content.start {
        Some(0)
      } else if source_caret > content.end {
        Some(rich_text_block_visual_length(block))
      } else {
        Some(
          rich_text_block_source_offset_to_visual(block, source_caret, content),
        )
      }
    (_, Some(content)) =>
      if source_caret < content.start || source_caret > content.end {
        None
      } else {
        Some(
          rich_text_block_source_offset_to_visual(block, source_caret, content),
        )
      }
    _ => None
  }
}

///|
fn rich_text_block_visual_length(block : RichTextBlock) -> Int {
  let mut length = text_length(block.prefix)
  for run in block.runs {
    length = length + text_length(rich_text_run_visual_text(run))
  }
  length
}

///|
fn rich_text_run_visual_text(run : RichTextRun) -> String {
  run.visual_text.unwrap_or(run.text)
}

///|
fn rich_text_run_visual_offset_from_source_offset(
  source_offset : Int,
  source_text : String,
  visual_text : String,
) -> Int {
  let source_boundaries = TextGraphemeBoundaries::new(text=source_text)
  let visual_boundaries = TextGraphemeBoundaries::new(text=visual_text)
  let source_length = source_boundaries.length()
  let visual_length = visual_boundaries.length()
  let source_offset = source_boundaries.nearest_boundary(source_offset)
  if source_length <= 0 || visual_length <= 0 {
    0
  } else if source_offset <= 0 {
    0
  } else if source_offset >= source_length {
    visual_length
  } else {
    visual_boundaries.nearest_boundary(
      (source_offset.to_double() *
      visual_length.to_double() /
      source_length.to_double())
      .round()
      .to_int(),
    )
  }
}

///|
fn rich_text_run_source_offset_from_visual_offset(
  visual_offset : Int,
  visual_text : String,
  source_text : String,
) -> Int {
  let visual_boundaries = TextGraphemeBoundaries::new(text=visual_text)
  let source_boundaries = TextGraphemeBoundaries::new(text=source_text)
  let visual_length = visual_boundaries.length()
  let source_length = source_boundaries.length()
  let visual_offset = visual_boundaries.nearest_boundary(visual_offset)
  if visual_length <= 0 || source_length <= 0 {
    0
  } else if visual_offset <= 0 {
    0
  } else if visual_offset >= visual_length {
    source_length
  } else {
    source_boundaries.nearest_boundary(
      (visual_offset.to_double() *
      source_length.to_double() /
      visual_length.to_double())
      .round()
      .to_int(),
    )
  }
}

///|
fn rich_text_prefix(text : String, length : Int) -> String {
  let chars = text.to_array()
  let end = TextGraphemeBoundaries::new(text~).nearest_boundary(length)
  String::from_array(chars[0:end])
}

///|
fn rich_text_cursor_rect_at(x : Double, frame : Rect, font : FontSpec) -> Rect {
  Rect::new(
    x~,
    y=frame.origin.y + 4.0,
    width=1.5,
    height=max_double(10.0, font.size * 1.55 - 8.0),
  )
}

///|
fn rich_text_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn rich_text_document_caret_rect(
  document : RichTextDocument,
  source_caret : Int,
  content : Rect,
  base_font : FontSpec,
  text_system : TextSystem,
) -> Rect? {
  if !rich_text_document_has_source_ranges(document) {
    return None
  }
  let mut y = content.origin.y
  let mut last_rect = Rect::new(
    x=content.origin.x,
    y=content.origin.y + 4.0,
    width=1.5,
    height=max_double(10.0, base_font.size * 1.55 - 8.0),
  )
  for block in document.blocks {
    let line_height = rich_text_block_line_height(block, base_font)
    let block_height = line_height + block.inset.top + block.inset.bottom
    let frame = Rect::new(
      x=content.origin.x + block.inset.left,
      y=y + block.inset.top,
      width=max_double(
        0.0,
        content.size.width - block.inset.left - block.inset.right,
      ),
      height=line_height,
    )
    if rich_text_caret_before_block(source_caret, block) {
      return Some(
        rich_text_block_caret_rect(block, 0, frame, base_font, text_system),
      )
    }
    match rich_text_block_visual_offset(block, source_caret) {
      Some(visual_offset) =>
        return Some(
          rich_text_block_caret_rect(
            block, visual_offset, frame, base_font, text_system,
          ),
        )
      None => ()
    }
    last_rect = rich_text_block_caret_rect(
      block,
      rich_text_block_visual_length(block),
      frame,
      base_font,
      text_system,
    )
    y = y + block_height
  }
  Some(last_rect)
}

///|
fn rich_text_document_prefix_source_offset_at_point(
  document : RichTextDocument,
  point : Point,
  content : Rect,
  base_font : FontSpec,
  text_system : TextSystem,
) -> Int? {
  if !rich_text_document_has_source_ranges(document) {
    return None
  }
  let mut y = content.origin.y
  for block in document.blocks {
    let line_height = rich_text_block_line_height(block, base_font)
    let block_height = line_height + block.inset.top + block.inset.bottom
    let frame = Rect::new(
      x=content.origin.x + block.inset.left,
      y=y + block.inset.top,
      width=max_double(
        0.0,
        content.size.width - block.inset.left - block.inset.right,
      ),
      height=line_height,
    )
    if point.y < y + block_height {
      return rich_text_block_prefix_source_offset_at_point(
        block, point, frame, base_font, text_system,
      )
    }
    y = y + block_height
  }
  None
}

///|
fn rich_text_block_prefix_source_offset_at_point(
  block : RichTextBlock,
  point : Point,
  frame : Rect,
  base_font : FontSpec,
  text_system : TextSystem,
) -> Int? {
  if block.prefix == "" {
    return None
  }
  let font = rich_text_block_font(block, base_font)
  let width = rich_text_width(block.prefix, font, text_system)
  if point.x >= frame.origin.x && point.x <= frame.origin.x + width {
    match block.content_range {
      Some(content) => Some(content.start)
      None => None
    }
  } else {
    None
  }
}

///|
fn rich_text_document_source_offset_at_point(
  document : RichTextDocument,
  point : Point,
  content : Rect,
  base_font : FontSpec,
  text_system : TextSystem,
) -> Int? {
  if !rich_text_document_has_source_ranges(document) {
    return None
  }
  let mut y = content.origin.y
  let mut last_offset : Int? = None
  for block in document.blocks {
    let line_height = rich_text_block_line_height(block, base_font)
    let block_height = line_height + block.inset.top + block.inset.bottom
    let frame = Rect::new(
      x=content.origin.x + block.inset.left,
      y=y + block.inset.top,
      width=max_double(
        0.0,
        content.size.width - block.inset.left - block.inset.right,
      ),
      height=line_height,
    )
    let offset = rich_text_block_source_offset_at_point(
      block, point, frame, base_font, text_system,
    )
    last_offset = Some(offset)
    if point.y < y + block_height {
      match rich_text_block_table_source_offset_at_point(block, point, frame) {
        Some(offset) => return Some(offset)
        None => ()
      }
      return Some(offset)
    }
    y = y + block_height
  }
  last_offset
}

///|
fn rich_text_block_visual_offset_at_point(
  block : RichTextBlock,
  point : Point,
  frame : Rect,
  base_font : FontSpec,
  text_system : TextSystem,
) -> Int {
  let font = rich_text_block_font(block, base_font)
  let line_step = rich_text_block_line_step(block, base_font)
  let target_line = clamp_int(
    ((point.y - frame.origin.y) / line_step).floor().to_int(),
    0,
    rich_text_block_visual_line_count(block) - 1,
  )
  let mut origin = frame.origin.x
  let mut visual_offset = 0
  let mut line = 0
  let mut line_end = 0
  if block.prefix != "" {
    let prefix_length = text_length(block.prefix)
    let hit = rich_text_run_visual_offset_at_x(
      block.prefix,
      font,
      point.x,
      origin,
      text_system,
    )
    let width = rich_text_width(block.prefix, font, text_system)
    if target_line == 0 && (hit < prefix_length || point.x <= origin + width) {
      return hit
    }
    visual_offset = visual_offset + prefix_length
    line_end = visual_offset
    origin = origin + width
  }
  for run in block.runs {
    let run_font = run.font.unwrap_or(font)
    let segments = rich_text_split_lines(rich_text_run_visual_text(run))
    for index, segment in segments {
      let segment_length = text_length(segment)
      let segment_width = rich_text_run_segment_width(
        run, segment, run_font, text_system,
      )
      if line == target_line {
        line_end = visual_offset + segment_length
        if point.x <= origin + segment_width || segment_length == 0 {
          return visual_offset +
            rich_text_run_visual_offset_at_x(
              segment,
              run_font,
              point.x,
              origin,
              text_system,
              width=rich_text_run_hit_width(run, segment_width),
            )
        }
      }
      visual_offset = visual_offset + segment_length
      origin = origin + segment_width
      if index + 1 < segments.length() {
        if line == target_line {
          return line_end
        }
        visual_offset = visual_offset + 1
        line = line + 1
        origin = frame.origin.x
      }
    }
  }
  line_end
}

///|
fn rich_text_block_source_offset_at_point(
  block : RichTextBlock,
  point : Point,
  frame : Rect,
  base_font : FontSpec,
  text_system : TextSystem,
) -> Int {
  let visual = rich_text_block_visual_offset_at_point(
    block, point, frame, base_font, text_system,
  )
  rich_text_block_source_offset_from_visual(block, visual)
}

///|
fn rich_text_run_visual_offset_at_x(
  text : String,
  font : FontSpec,
  x : Double,
  origin_x : Double,
  text_system : TextSystem,
  width? : Double? = None,
) -> Int {
  let chars = text.to_array()
  let boundaries = TextGraphemeBoundaries::new(text~)
  if x <= origin_x {
    return 0
  }
  match width {
    Some(width) =>
      if chars.length() <= 1 {
        if x < origin_x + width / 2.0 {
          return 0
        } else {
          return chars.length()
        }
      } else {
        let relative = clamp_double((x - origin_x) / width, 0.0, 1.0)
        return boundaries.nearest_boundary(
          (relative * chars.length().to_double()).round().to_int(),
        )
      }
    None => ()
  }
  for index in 0..<chars.length() {
    let before = rich_text_width(
      String::from_array(chars[0:index]),
      font,
      text_system,
    )
    let after = rich_text_width(
      String::from_array(chars[0:index + 1]),
      font,
      text_system,
    )
    if x < origin_x + (before + after) / 2.0 {
      return boundaries.nearest_boundary(index)
    }
  }
  chars.length()
}

///|
fn rich_text_block_caret_rect(
  block : RichTextBlock,
  visual_offset : Int,
  frame : Rect,
  base_font : FontSpec,
  text_system : TextSystem,
) -> Rect {
  let font = rich_text_block_font(block, base_font)
  let line_step = rich_text_block_line_step(block, base_font)
  let mut remaining = clamp_int(
    visual_offset,
    0,
    rich_text_block_visual_length(block),
  )
  let mut x = frame.origin.x
  let mut y = frame.origin.y
  if block.prefix != "" {
    let prefix_length = text_length(block.prefix)
    if remaining <= prefix_length {
      let prefix = rich_text_prefix(block.prefix, remaining)
      x = x + rich_text_width(prefix, font, text_system)
      return rich_text_cursor_rect_at(
        x,
        Rect::new(
          x=frame.origin.x,
          y~,
          width=frame.size.width,
          height=frame.size.height,
        ),
        font,
      )
    }
    remaining = remaining - prefix_length
    x = x + rich_text_width(block.prefix, font, text_system)
  }
  for run in block.runs {
    let run_font = run.font.unwrap_or(font)
    let segments = rich_text_split_lines(rich_text_run_visual_text(run))
    for index, segment in segments {
      let segment_length = text_length(segment)
      if remaining <= segment_length {
        x = x +
          rich_text_run_segment_prefix_width(
            run, segment, remaining, run_font, text_system,
          )
        return rich_text_cursor_rect_at(
          x,
          Rect::new(
            x=frame.origin.x,
            y~,
            width=frame.size.width,
            height=line_step,
          ),
          run_font,
        )
      }
      remaining = remaining - segment_length
      x = x + rich_text_run_segment_width(run, segment, run_font, text_system)
      if index + 1 < segments.length() {
        if remaining == 0 {
          return rich_text_cursor_rect_at(
            x,
            Rect::new(
              x=frame.origin.x,
              y~,
              width=frame.size.width,
              height=line_step,
            ),
            run_font,
          )
        }
        remaining = remaining - 1
        y = y + line_step
        x = frame.origin.x
      }
    }
  }
  rich_text_cursor_rect_at(
    x,
    Rect::new(x=frame.origin.x, y~, width=frame.size.width, height=line_step),
    font,
  )
}

///|
fn rich_text_run_segment_prefix_width(
  run : RichTextRun,
  text : String,
  visual_offset : Int,
  font : FontSpec,
  text_system : TextSystem,
) -> Double {
  let length = text_length(text)
  if length <= 0 || visual_offset <= 0 {
    0.0
  } else if visual_offset >= length {
    rich_text_run_segment_width(run, text, font, text_system)
  } else {
    match run.image_source {
      Some(_) =>
        rich_text_run_segment_width(run, text, font, text_system) *
        visual_offset.to_double() /
        length.to_double()
      None =>
        rich_text_width(
          rich_text_prefix(text, visual_offset),
          font,
          text_system,
        )
    }
  }
}

///|
fn rich_text_caret_rect(
  text : String,
  caret : Int,
  content : Rect,
  font : FontSpec,
  text_system : TextSystem,
) -> Rect {
  let chars = text.to_array()
  let caret = TextGraphemeBoundaries::new(text~).nearest_boundary(caret)
  let mut line = 0
  let mut column_start = 0
  for index in 0..<caret {
    if chars[index] == '\n' {
      line = line + 1
      column_start = index + 1
    }
  }
  let prefix = String::from_array(chars[column_start:caret])
  let x = content.origin.x + rich_text_width(prefix, font, text_system)
  let line_height = font.size * 1.55
  Rect::new(
    x~,
    y=content.origin.y + line.to_double() * line_height + 4.0,
    width=1.5,
    height=max_double(10.0, line_height - 8.0),
  )
}
