///|
fn append_rich_text_editor_commands(
  commands : Array[DrawCommand],
  element : ElementNode,
  data : RichTextEditorViewSpec,
  frame : Rect,
  focused : Bool,
  environment : RenderEnvironment,
) -> Unit {
  let border = if focused { data.focused_border } else { data.border }
  let rounded = RoundedRect::new(rect=frame, radius=data.corner_radius)
  commands.push(FillRoundedRectBrush(rounded, data.background))
  match border {
    Some(border) =>
      if border.width > 0.0 {
        commands.push(
          StrokeRoundedRectBrush(rounded, border.brush, border.width),
        )
      }
    None => ()
  }
  let text = data.value.get()
  let display_text = text_with_composition(text, element, focused)
  let content = rich_text_editor_content_rect(frame)
  commands.push(PushClip(content))
  if display_text == "" {
    commands.push(
      DrawText(
        TextRun::new(
          text=data.placeholder,
          frame=content,
          font=environment.font.unwrap_or(data.font),
          color=data.placeholder_color,
          align=TextAlign::TextStart,
        ),
      ),
    )
  } else {
    let document = (data.format)(display_text)
    if focused && element.composition is None {
      append_rich_text_selection_commands(
        commands,
        document,
        content,
        environment.font.unwrap_or(data.font),
        environment.text_system,
        element.selection,
      )
    }
    append_rich_text_blocks(
      commands,
      document,
      content,
      environment.font.unwrap_or(data.font),
      environment.foreground.unwrap_or(data.foreground),
      environment.text_system,
    )
  }
  if focused {
    append_rich_text_editor_cursor(
      commands,
      element,
      data,
      text,
      display_text,
      content,
      environment.text_system,
    )
  }
  commands.push(PopClip)
}

///|
fn append_rich_text_selection_commands(
  commands : Array[DrawCommand],
  document : RichTextDocument,
  content : Rect,
  base_font : FontSpec,
  text_system : TextSystem,
  selection : TextRange?,
) -> Unit {
  match active_text_selection(selection) {
    Some(selection) => {
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
        match rich_text_block_selection_visual_range(block, selection) {
          Some(range) =>
            append_rich_text_block_selection_rect(
              commands, block, range, frame, base_font, text_system,
            )
          None => ()
        }
        y = y + block_height
      }
    }
    None => ()
  }
}

///|
fn append_rich_text_block_selection_rect(
  commands : Array[DrawCommand],
  block : RichTextBlock,
  range : TextRange,
  frame : Rect,
  base_font : FontSpec,
  text_system : TextSystem,
) -> Unit {
  let start_rect = rich_text_block_caret_rect(
    block,
    range.start,
    frame,
    base_font,
    text_system,
  )
  let end_rect = rich_text_block_caret_rect(
    block,
    range.end,
    frame,
    base_font,
    text_system,
  )
  if end_rect.origin.x > start_rect.origin.x {
    commands.push(
      FillRect(
        Rect::new(
          x=start_rect.origin.x,
          y=frame.origin.y + 4.0,
          width=end_rect.origin.x - start_rect.origin.x,
          height=max_double(10.0, frame.size.height - 8.0),
        ),
        Color::blue().with_alpha(0.18),
      ),
    )
  }
}

///|
fn rich_text_block_selection_visual_range(
  block : RichTextBlock,
  selection : TextRange,
) -> TextRange? {
  match (block.source_range, block.content_range) {
    (Some(source), Some(content)) =>
      if selection.end <= source.start || selection.start >= source.end {
        None
      } else {
        let start = rich_text_block_source_offset_to_visual(
          block,
          clamp_int(selection.start, source.start, source.end),
          content,
        )
        let end = rich_text_block_source_offset_to_visual(
          block,
          clamp_int(selection.end, source.start, source.end),
          content,
        )
        if end > start {
          Some(TextRange::new(start~, end~))
        } else {
          None
        }
      }
    (_, Some(content)) =>
      if selection.end <= content.start || selection.start >= content.end {
        None
      } else {
        let start = rich_text_block_source_offset_to_visual(
          block,
          clamp_int(selection.start, content.start, content.end),
          content,
        )
        let end = rich_text_block_source_offset_to_visual(
          block,
          clamp_int(selection.end, content.start, content.end),
          content,
        )
        if end > start {
          Some(TextRange::new(start~, end~))
        } else {
          None
        }
      }
    _ => None
  }
}

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
    let length = text_length(run.text)
    let visual_length = text_length(rich_text_run_visual_text(run))
    match run.source_range {
      Some(range) =>
        if source_offset <= range.end {
          return Some(
            visual +
            rich_text_run_visual_offset_from_source_offset(
              source_offset - range.start,
              length,
              visual_length,
            ),
          )
        }
      None => return None
    }
    visual = visual + visual_length
  }
  Some(visual)
}

///|
fn append_rich_text_blocks(
  commands : Array[DrawCommand],
  document : RichTextDocument,
  content : Rect,
  base_font : FontSpec,
  foreground : Color,
  text_system : TextSystem,
) -> Unit {
  let mut y = content.origin.y
  for block in document.blocks {
    let line_height = rich_text_block_line_height(block, base_font)
    let block_height = line_height + block.inset.top + block.inset.bottom
    if y > content.origin.y + content.size.height {
      return
    }
    let block_frame = Rect::new(
      x=content.origin.x,
      y~,
      width=content.size.width,
      height=block_height,
    )
    match block.background {
      Some(background) =>
        commands.push(
          FillRoundedRectBrush(
            RoundedRect::new(rect=block_frame, radius=block.corner_radius),
            background,
          ),
        )
      None => ()
    }
    match block.border_left {
      Some(border) =>
        if border.width > 0.0 {
          commands.push(
            FillRoundedRectBrush(
              RoundedRect::new(
                rect=Rect::new(
                  x=block_frame.origin.x + block.inset.left,
                  y=block_frame.origin.y,
                  width=border.width,
                  height=block_frame.size.height,
                ),
                radius=border.width / 2.0,
              ),
              border.brush,
            ),
          )
        }
      None => ()
    }
    if block.rule {
      commands.push(
        FillRect(
          Rect::new(
            x=block_frame.origin.x + block.inset.left,
            y=block_frame.origin.y + block_height / 2.0,
            width=max_double(
              0.0,
              block_frame.size.width - block.inset.left - block.inset.right,
            ),
            height=1.5,
          ),
          rich_text_block_color(block, foreground).multiply_alpha(0.25),
        ),
      )
    } else if block.table is Some(_) {
      append_rich_text_block_table(
        commands,
        block,
        Rect::new(
          x=block_frame.origin.x + block.inset.left,
          y=block_frame.origin.y + block.inset.top,
          width=max_double(
            0.0,
            block_frame.size.width - block.inset.left - block.inset.right,
          ),
          height=line_height,
        ),
        base_font,
        foreground,
      )
    } else {
      append_rich_text_block_runs(
        commands,
        block,
        Rect::new(
          x=block_frame.origin.x + block.inset.left,
          y=block_frame.origin.y + block.inset.top,
          width=max_double(
            0.0,
            block_frame.size.width - block.inset.left - block.inset.right,
          ),
          height=line_height,
        ),
        base_font,
        foreground,
        text_system,
      )
    }
    y = y + block_height
  }
}

///|
fn append_rich_text_block_table(
  commands : Array[DrawCommand],
  block : RichTextBlock,
  frame : Rect,
  base_font : FontSpec,
  foreground : Color,
) -> Unit {
  match block.table {
    Some(table) => {
      let row_count = table.rows.length()
      let column_count = rich_text_table_column_count(table)
      if row_count == 0 || column_count == 0 {
        return
      }
      let column_width = frame.size.width / column_count.to_double()
      for row_index in 0..<row_count {
        let row_y = frame.origin.y + table.row_height * row_index.to_double()
        if row_index == 0 {
          match table.header_background {
            Some(background) =>
              commands.push(
                FillRoundedRectBrush(
                  RoundedRect::new(
                    rect=Rect::new(
                      x=frame.origin.x,
                      y=row_y,
                      width=frame.size.width,
                      height=table.row_height,
                    ),
                    radius=block.corner_radius,
                  ),
                  background,
                ),
              )
            None => ()
          }
        }
        let row = table.rows[row_index]
        for column_index in 0..<column_count {
          let cell_x = frame.origin.x + column_width * column_index.to_double()
          let cell_frame = Rect::new(
            x=cell_x,
            y=row_y,
            width=column_width,
            height=table.row_height,
          )
          commands.push(StrokeRect(cell_frame, table.border, 1.0))
          if column_index < row.length() {
            let cell = row[column_index]
            commands.push(
              DrawText(
                TextRun::new(
                  text=cell.text,
                  frame=cell_frame.inset(table.cell_padding),
                  font={
                    ..rich_text_block_font(block, base_font),
                    weight: if cell.header {
                      700
                    } else {
                      400
                    },
                  },
                  color=rich_text_block_color(block, foreground),
                  align=cell.align.unwrap_or(TextAlign::TextStart),
                ),
              ),
            )
          }
        }
      }
    }
    None => ()
  }
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
fn append_rich_text_block_runs(
  commands : Array[DrawCommand],
  block : RichTextBlock,
  frame : Rect,
  base_font : FontSpec,
  foreground : Color,
  text_system : TextSystem,
) -> Unit {
  let font = rich_text_block_font(block, base_font)
  let color = rich_text_block_color(block, foreground)
  let mut x = frame.origin.x
  if block.prefix != "" {
    let width = rich_text_width(block.prefix, font, text_system)
    commands.push(
      DrawText(
        TextRun::new(
          text=block.prefix,
          frame=Rect::new(
            x~,
            y=frame.origin.y,
            width~,
            height=frame.size.height,
          ),
          font~,
          color~,
          align=TextAlign::TextStart,
        ),
      ),
    )
    x = x + width
  }
  for run in block.runs {
    let run_font = run.font.unwrap_or(font)
    let run_color = run.color.unwrap_or(color)
    let text = rich_text_run_visual_text(run)
    let width = rich_text_run_width(run, run_font, text_system)
    let run_frame = Rect::new(
      x~,
      y=frame.origin.y,
      width=max_double(
        0.0,
        min_double(width, frame.origin.x + frame.size.width - x),
      ),
      height=frame.size.height,
    )
    match run.background {
      Some(background) =>
        commands.push(
          FillRoundedRectBrush(
            RoundedRect::new(
              rect=Rect::new(
                x=x - 3.0,
                y=frame.origin.y + 4.0,
                width=width + 6.0,
                height=max_double(12.0, frame.size.height - 8.0),
              ),
              radius=run.background_radius,
            ),
            background,
          ),
        )
      None => ()
    }
    match run.image_source {
      Some(source) =>
        commands.push(
          DrawImage({
            source,
            frame: run_frame,
            opacity: 1.0,
            fit: run.image_fit,
          }),
        )
      None =>
        commands.push(
          DrawText(
            TextRun::new(
              text~,
              frame=run_frame,
              font=run_font,
              color=run_color,
              align=TextAlign::TextStart,
            ),
          ),
        )
    }
    append_rich_text_run_decoration(
      commands, run, run_frame, width, run_font, run_color,
    )
    x = x + width
  }
}

///|
fn append_rich_text_run_decoration(
  commands : Array[DrawCommand],
  run : RichTextRun,
  frame : Rect,
  width : Double,
  font : FontSpec,
  color : Color,
) -> Unit {
  match run.decoration {
    Some(Strikethrough) => {
      let thickness = max_double(1.0, font.size / 14.0)
      commands.push(
        FillRect(
          Rect::new(
            x=frame.origin.x,
            y=frame.origin.y + frame.size.height * 0.52,
            width~,
            height=thickness,
          ),
          color.multiply_alpha(0.72),
        ),
      )
    }
    None => ()
  }
}

///|
fn rich_text_block_line_height(
  block : RichTextBlock,
  base_font : FontSpec,
) -> Double {
  let text_height = block.line_height.unwrap_or(
    rich_text_block_font(block, base_font).size * 1.55,
  )
  let mut height = text_height
  match block.table {
    Some(table) =>
      height = max_double(
        height,
        table.row_height * table.rows.length().to_double(),
      )
    None => ()
  }
  for run in block.runs {
    match run.image_size {
      Some(size) => height = max_double(height, size.height)
      None => ()
    }
  }
  height
}

///|
fn rich_text_block_font(
  block : RichTextBlock,
  base_font : FontSpec,
) -> FontSpec {
  block.font.unwrap_or(base_font)
}

///|
fn rich_text_block_color(block : RichTextBlock, foreground : Color) -> Color {
  block.color.unwrap_or(foreground)
}

///|
fn rich_text_width(
  text : String,
  font : FontSpec,
  text_system : TextSystem,
) -> Double {
  text_system.measure_text(TextLayoutInput::new(text~, font~)).size.width
}

///|
fn rich_text_run_width(
  run : RichTextRun,
  font : FontSpec,
  text_system : TextSystem,
) -> Double {
  match run.image_size {
    Some(size) => size.width
    None => rich_text_width(rich_text_run_visual_text(run), font, text_system)
  }
}

///|
fn rich_text_run_hit_width(run : RichTextRun, width : Double) -> Double? {
  match run.image_source {
    Some(_) => Some(width)
    None => None
  }
}

///|
fn append_rich_text_editor_cursor(
  commands : Array[DrawCommand],
  element : ElementNode,
  data : RichTextEditorViewSpec,
  text : String,
  display_text : String,
  content : Rect,
  text_system : TextSystem,
) -> Unit {
  let document = (data.format)(display_text)
  let caret = clamp_int(
    text_field_visual_caret(text, element, true),
    0,
    text_length(text),
  )
  let rect = rich_text_document_caret_rect(
    document,
    caret,
    content,
    data.font,
    text_system,
  ).unwrap_or(
    rich_text_caret_rect(display_text, caret, content, data.font, text_system),
  )
  commands.push(
    FillRoundedRectBrush(
      RoundedRect::new(rect~, radius=1.0),
      Brush::solid(data.cursor_color),
    ),
  )
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
pub fn rich_text_editor_content_rect(frame : Rect) -> Rect {
  frame.inset(Insets::symmetric(horizontal=14.0, vertical=12.0))
}

///|
pub fn rich_text_document_caret_rect_at_source(
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
    let offset = rich_text_block_source_offset_at_x(
      block,
      point.x,
      frame,
      base_font,
      text_system,
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
fn rich_text_block_source_offset_at_x(
  block : RichTextBlock,
  x : Double,
  frame : Rect,
  base_font : FontSpec,
  text_system : TextSystem,
) -> Int {
  let visual = rich_text_block_visual_offset_at_x(
    block, x, frame, base_font, text_system,
  )
  rich_text_block_source_offset_from_visual(block, visual)
}

///|
fn rich_text_block_visual_offset_at_x(
  block : RichTextBlock,
  x : Double,
  frame : Rect,
  base_font : FontSpec,
  text_system : TextSystem,
) -> Int {
  let font = rich_text_block_font(block, base_font)
  let mut origin = frame.origin.x
  let mut visual_offset = 0
  if block.prefix != "" {
    let prefix_length = text_length(block.prefix)
    let hit = rich_text_run_visual_offset_at_x(
      block.prefix,
      font,
      x,
      origin,
      text_system,
    )
    if hit < prefix_length ||
      x <= origin + rich_text_width(block.prefix, font, text_system) {
      return hit
    }
    visual_offset = visual_offset + prefix_length
    origin = origin + rich_text_width(block.prefix, font, text_system)
  }
  for run in block.runs {
    let run_font = run.font.unwrap_or(font)
    let text = rich_text_run_visual_text(run)
    let run_length = text_length(text)
    let run_width = rich_text_run_width(run, run_font, text_system)
    if x <= origin + run_width {
      return visual_offset +
        rich_text_run_visual_offset_at_x(
          text,
          run_font,
          x,
          origin,
          text_system,
          width=rich_text_run_hit_width(run, run_width),
        )
    }
    visual_offset = visual_offset + run_length
    origin = origin + run_width
  }
  rich_text_block_visual_length(block)
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
        return (relative * chars.length().to_double()).round().to_int()
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
      return index
    }
  }
  chars.length()
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
  for run in block.runs {
    let length = text_length(run.text)
    let visual_length = text_length(rich_text_run_visual_text(run))
    if remaining <= visual_length {
      match run.source_range {
        Some(range) =>
          return Some(
            clamp_int(
              range.start +
              rich_text_run_source_offset_from_visual_offset(
                remaining, visual_length, length,
              ),
              range.start,
              range.end,
            ),
          )
        None => return None
      }
    }
    remaining = remaining - visual_length
  }
  match block.runs.last() {
    Some(run) =>
      match run.source_range {
        Some(range) => Some(range.end)
        None => None
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
fn rich_text_block_caret_rect(
  block : RichTextBlock,
  visual_offset : Int,
  frame : Rect,
  base_font : FontSpec,
  text_system : TextSystem,
) -> Rect {
  let font = rich_text_block_font(block, base_font)
  let mut remaining = clamp_int(
    visual_offset,
    0,
    rich_text_block_visual_length(block),
  )
  let mut x = frame.origin.x
  if block.prefix != "" {
    let prefix_length = text_length(block.prefix)
    if remaining <= prefix_length {
      let prefix = rich_text_prefix(block.prefix, remaining)
      x = x + rich_text_width(prefix, font, text_system)
      return rich_text_cursor_rect_at(x, frame, font)
    }
    remaining = remaining - prefix_length
    x = x + rich_text_width(block.prefix, font, text_system)
  }
  for run in block.runs {
    let run_font = run.font.unwrap_or(font)
    let text = rich_text_run_visual_text(run)
    let run_length = text_length(text)
    if remaining <= run_length {
      x = x + rich_text_run_prefix_width(run, remaining, run_font, text_system)
      return rich_text_cursor_rect_at(x, frame, run_font)
    }
    remaining = remaining - run_length
    x = x + rich_text_run_width(run, run_font, text_system)
  }
  rich_text_cursor_rect_at(x, frame, font)
}

///|
fn rich_text_run_prefix_width(
  run : RichTextRun,
  visual_offset : Int,
  font : FontSpec,
  text_system : TextSystem,
) -> Double {
  let text = rich_text_run_visual_text(run)
  let length = text_length(text)
  if length <= 0 || visual_offset <= 0 {
    0.0
  } else if visual_offset >= length {
    rich_text_run_width(run, font, text_system)
  } else {
    match run.image_source {
      Some(_) =>
        rich_text_run_width(run, font, text_system) *
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
fn rich_text_run_visual_text(run : RichTextRun) -> String {
  run.visual_text.unwrap_or(run.text)
}

///|
fn rich_text_run_visual_offset_from_source_offset(
  source_offset : Int,
  source_length : Int,
  visual_length : Int,
) -> Int {
  if source_length <= 0 || visual_length <= 0 {
    0
  } else if source_offset <= 0 {
    0
  } else if source_offset >= source_length {
    visual_length
  } else {
    (source_offset.to_double() *
    visual_length.to_double() /
    source_length.to_double())
    .round()
    .to_int()
  }
}

///|
fn rich_text_run_source_offset_from_visual_offset(
  visual_offset : Int,
  visual_length : Int,
  source_length : Int,
) -> Int {
  if visual_length <= 0 || source_length <= 0 {
    0
  } else if visual_offset <= 0 {
    0
  } else if visual_offset >= visual_length {
    source_length
  } else {
    (visual_offset.to_double() *
    source_length.to_double() /
    visual_length.to_double())
    .round()
    .to_int()
  }
}

///|
fn rich_text_prefix(text : String, length : Int) -> String {
  let chars = text.to_array()
  let end = clamp_int(length, 0, chars.length())
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
fn rich_text_caret_rect(
  text : String,
  caret : Int,
  content : Rect,
  font : FontSpec,
  text_system : TextSystem,
) -> Rect {
  let chars = text.to_array()
  let caret = clamp_int(caret, 0, chars.length())
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

///|
fn rich_text_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}
