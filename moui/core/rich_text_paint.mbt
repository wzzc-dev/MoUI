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
    if focused && element.control.composition is None {
      append_rich_text_selection_commands(
        commands,
        document,
        content,
        environment.font.unwrap_or(data.font),
        environment.text_system,
        element.control.selection,
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
                  x=block_frame.origin.x,
                  y=block_frame.origin.y + block.inset.top,
                  width=border.width,
                  height=line_height,
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
  let line_height = rich_text_block_line_step(block, base_font)
  let mut x = frame.origin.x
  let mut line = 0
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
    let segments = rich_text_split_lines(rich_text_run_visual_text(run))
    for index, segment in segments {
      let width = rich_text_run_segment_width(
        run, segment, run_font, text_system,
      )
      let line_y = frame.origin.y + line.to_double() * line_height
      let run_frame = Rect::new(
        x~,
        y=line_y,
        width=max_double(
          0.0,
          min_double(width, frame.origin.x + frame.size.width - x),
        ),
        height=rich_text_run_segment_height(run, line_height),
      )
      if segment != "" || run.image_source is Some(_) {
        append_rich_text_run_segment(
          commands, run, segment, run_frame, width, run_font, run_color,
        )
      }
      if index + 1 < segments.length() {
        line = line + 1
        x = frame.origin.x
      } else {
        x = x + width
      }
    }
  }
}

///|
fn append_rich_text_run_segment(
  commands : Array[DrawCommand],
  run : RichTextRun,
  text : String,
  run_frame : Rect,
  width : Double,
  font : FontSpec,
  color : Color,
) -> Unit {
  match run.background {
    Some(background) =>
      commands.push(
        FillRoundedRectBrush(
          RoundedRect::new(
            rect=Rect::new(
              x=run_frame.origin.x - 3.0,
              y=run_frame.origin.y + 4.0,
              width=width + 6.0,
              height=max_double(12.0, run_frame.size.height - 8.0),
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
        DrawImage({ source, frame: run_frame, opacity: 1.0, fit: run.image_fit }),
      )
    None =>
      commands.push(
        DrawText(
          TextRun::new(
            text~,
            frame=run_frame,
            font~,
            color~,
            align=TextAlign::TextStart,
          ),
        ),
      )
  }
  append_rich_text_run_decoration(commands, run, run_frame, width, font, color)
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
  let text_height = rich_text_block_line_step(block, base_font)
  let mut height = text_height *
    rich_text_block_visual_line_count(block).to_double()
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
fn rich_text_block_line_step(
  block : RichTextBlock,
  base_font : FontSpec,
) -> Double {
  block.line_height.unwrap_or(
    rich_text_block_font(block, base_font).size * 1.55,
  )
}

///|
fn rich_text_block_visual_line_count(block : RichTextBlock) -> Int {
  let mut line_count = 1
  line_count = line_count + rich_text_text_newline_count(block.prefix)
  for run in block.runs {
    line_count = line_count +
      rich_text_text_newline_count(rich_text_run_visual_text(run))
  }
  line_count
}

///|
fn rich_text_split_lines(text : String) -> Array[String] {
  let lines : Array[String] = []
  let current : Array[Char] = []
  for ch in text {
    if ch == '\n' {
      lines.push(String::from_array(current))
      current.clear()
    } else {
      current.push(ch)
    }
  }
  lines.push(String::from_array(current))
  lines
}

///|
fn rich_text_text_newline_count(text : String) -> Int {
  let mut count = 0
  for ch in text {
    if ch == '\n' {
      count = count + 1
    }
  }
  count
}

///|
pub fn rich_text_document_height(
  document : RichTextDocument,
  base_font : FontSpec,
) -> Double {
  let mut height = 0.0
  for block in document.blocks {
    height = height +
      rich_text_block_line_height(block, base_font) +
      block.inset.top +
      block.inset.bottom
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
fn rich_text_run_segment_width(
  run : RichTextRun,
  text : String,
  font : FontSpec,
  text_system : TextSystem,
) -> Double {
  match run.image_size {
    Some(size) => size.width
    None => rich_text_width(text, font, text_system)
  }
}

///|
fn rich_text_run_segment_height(
  run : RichTextRun,
  line_height : Double,
) -> Double {
  match run.image_size {
    Some(size) => max_double(line_height, size.height)
    None => line_height
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
