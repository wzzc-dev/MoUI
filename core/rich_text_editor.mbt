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
  let content = frame.inset(Insets::symmetric(horizontal=14.0, vertical=12.0))
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
    append_rich_text_blocks(
      commands,
      (data.format)(display_text),
      content,
      environment.font.unwrap_or(data.font),
      environment.foreground.unwrap_or(data.foreground),
      environment.text_measurer,
    )
  }
  if focused {
    append_rich_text_editor_cursor(
      commands,
      element,
      data,
      text,
      content,
      environment.text_measurer,
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
  text_measurer : TextMeasurer,
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
        text_measurer,
      )
    }
    y = y + block_height
  }
}

///|
fn append_rich_text_block_runs(
  commands : Array[DrawCommand],
  block : RichTextBlock,
  frame : Rect,
  base_font : FontSpec,
  foreground : Color,
  text_measurer : TextMeasurer,
) -> Unit {
  let font = rich_text_block_font(block, base_font)
  let color = rich_text_block_color(block, foreground)
  let mut x = frame.origin.x
  if block.prefix != "" {
    let width = rich_text_width(block.prefix, font, text_measurer)
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
    let width = rich_text_width(run.text, run_font, text_measurer)
    let run_frame = Rect::new(
      x~,
      y=frame.origin.y,
      width=max_double(0.0, frame.origin.x + frame.size.width - x),
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
    commands.push(
      DrawText(
        TextRun::new(
          text=run.text,
          frame=run_frame,
          font=run_font,
          color=run_color,
          align=TextAlign::TextStart,
        ),
      ),
    )
    x = x + width
  }
}

///|
fn rich_text_block_line_height(
  block : RichTextBlock,
  base_font : FontSpec,
) -> Double {
  block.line_height.unwrap_or(
    rich_text_block_font(block, base_font).size * 1.55,
  )
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
  text_measurer : TextMeasurer,
) -> Double {
  text_measurer.measure_text(TextLayoutInput::new(text~, font~)).size.width
}

///|
fn append_rich_text_editor_cursor(
  commands : Array[DrawCommand],
  element : ElementNode,
  data : RichTextEditorViewSpec,
  text : String,
  content : Rect,
  text_measurer : TextMeasurer,
) -> Unit {
  let caret = clamp_int(
    text_field_visual_caret(text, element, true),
    0,
    text_length(text),
  )
  let rect = rich_text_caret_rect(
    text_with_composition(text, element, true),
    caret,
    content,
    data.font,
    text_measurer,
  )
  commands.push(
    FillRoundedRectBrush(
      RoundedRect::new(rect~, radius=1.0),
      Brush::solid(data.cursor_color),
    ),
  )
}

///|
fn rich_text_caret_rect(
  text : String,
  caret : Int,
  content : Rect,
  font : FontSpec,
  text_measurer : TextMeasurer,
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
  let x = content.origin.x + rich_text_width(prefix, font, text_measurer)
  let line_height = font.size * 1.55
  Rect::new(
    x~,
    y=content.origin.y + line.to_double() * line_height + 4.0,
    width=1.5,
    height=max_double(10.0, line_height - 8.0),
  )
}
