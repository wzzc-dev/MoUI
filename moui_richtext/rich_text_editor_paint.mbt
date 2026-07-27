///|
fn rich_text_editor_paint(
  ctx : @core.ViewPaintContext,
  value~ : String,
  placeholder~ : String,
  format~ : RichTextFormatter,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  placeholder_color~ : @core.Color,
  background~ : @core.Brush,
  border~ : @core.BorderStyle?,
  focused_border~ : @core.BorderStyle?,
  cursor_color~ : @core.Color,
  corner_radius~ : Double,
  visible_scroll_y~ : Double,
  visible_viewport_height~ : Double,
  visible_overscan~ : Double,
) -> @core.ViewPaintPlan {
  let commands : Array[@core.DrawCommand] = []
  let overlay_commands : Array[@core.DrawCommand] = []
  let rounded = @core.RoundedRect::new(rect=ctx.frame, radius=corner_radius)
  commands.push(@core.DrawCommand::FillRoundedRectBrush(rounded, background))
  append_rich_text_border(
    commands,
    rounded,
    if ctx.focused {
      focused_border
    } else {
      border
    },
  )
  let text = value
  let display_text = rich_text_with_composition(
    text,
    ctx.text_control,
    focused=ctx.focused,
  )
  let content = rich_text_editor_content_rect(ctx.frame)
  let scroll_y = visible_scroll_y
  let document_content = rich_text_scrolled_content_rect(
    content,
    scroll_y~,
    visible_viewport_height~,
  )
  commands.push(@core.DrawCommand::PushClip(content))
  let child_layers : Array[@core.ViewPaintLayer] = []
  if display_text == "" {
    commands.push(
      @core.DrawCommand::DrawText(
        @core.TextRun::new(
          text=placeholder,
          frame=content,
          font~,
          color=placeholder_color,
          align=@core.TextAlign::TextStart,
        ),
      ),
    )
  } else {
    let document = format(display_text)
    // `document_content` is already shifted by `-scroll_y`, so blocks are in
    // paint coordinates. Windowed culling must NOT add `scroll_y` again —
    // that double-count made the visible band start near `clip.y + scroll_y`
    // while blocks sat near `clip.y - scroll_y`, which culls the whole
    // viewport (blank editor) and leaves stale/out-of-band layers (overlap).
    append_rich_text_document_layers(
      child_layers,
      document,
      document_content,
      font,
      foreground,
      text_system=ctx.text_system,
      visible_scroll_y=0.0,
      visible_viewport_height~,
      visible_overscan~,
      clip_rect=Some(content),
    )
    if ctx.focused {
      append_rich_text_editor_overlay(
        overlay_commands,
        text~,
        display_text~,
        document~,
        content=document_content,
        font~,
        cursor_color~,
        control=ctx.text_control,
        text_system=ctx.text_system,
      )
    }
  }
  // PopClip must go in post_commands so child_layers stay inside the clip.
  {
    commands,
    child_layers,
    post_commands: [@core.DrawCommand::PopClip],
    overlay_commands,
    repaint_boundary: false,
    animating: false,
  }
}

///|
fn append_rich_text_border(
  commands : Array[@core.DrawCommand],
  rounded : @core.RoundedRect,
  border : @core.BorderStyle?,
) -> Unit {
  match border {
    Some(border) =>
      if border.width > 0.0 {
        commands.push(
          @core.DrawCommand::StrokeRoundedRectBrush(
            rounded,
            border.brush,
            border.width,
          ),
        )
      }
    None => ()
  }
}

///|
fn rich_text_scrolled_content_rect(
  content : @core.Rect,
  scroll_y~ : Double,
  visible_viewport_height~ : Double,
) -> @core.Rect {
  if visible_viewport_height > 0.0 {
    content.offset(dx=0.0, dy=-scroll_y)
  } else {
    content
  }
}

///|
fn append_rich_text_document_layers(
  layers : Array[@core.ViewPaintLayer],
  document : RichTextDocument,
  content : @core.Rect,
  base_font : @core.FontSpec,
  foreground : @core.Color,
  text_system~ : @core.TextSystem,
  visible_scroll_y? : Double = 0.0,
  visible_viewport_height? : Double = 0.0,
  visible_overscan? : Double = 320.0,
  clip_rect? : @core.Rect? = None,
) -> Unit {
  // `content` sets the block positioning origin (may already include -scroll_y
  // or a window top_padding). `clip` is the untranslated viewport used for
  // culling. When blocks are pre-positioned into paint space, pass
  // `visible_scroll_y=0` so this band is just the clip plus overscan.
  let clip = match clip_rect {
    Some(r) => r
    None => content
  }
  let mut y = content.origin.y
  let windowed = visible_viewport_height > 0.0
  let visible_top = clip.origin.y + visible_scroll_y - 12.0 - visible_overscan
  let visible_bottom = visible_top +
    visible_viewport_height +
    visible_overscan * 2.0
  for index, block in document.blocks {
    let line_height = rich_text_block_line_height(
      block,
      base_font,
      text_system,
      block_width=content.size.width,
    )
    let block_height = line_height + block.inset.top + block.inset.bottom
    let block_bottom = y + block_height
    if windowed && block_bottom < visible_top {
      y = block_bottom
      continue
    }
    if windowed && y > visible_bottom {
      return
    }
    if !windowed && y > clip.origin.y + clip.size.height {
      return
    }
    let frame = @core.Rect::new(
      x=content.origin.x,
      y~,
      width=content.size.width,
      height=block_height,
    )
    let commands : Array[@core.DrawCommand] = []
    append_rich_text_block_commands(
      commands,
      block,
      frame,
      line_height,
      base_font,
      foreground,
      text_system~,
    )
    layers.push(
      @core.ViewPaintLayer::new(
        frame~,
        cache_key=rich_text_block_cache_key(index, block, frame),
        content_revision=rich_text_block_content_revision(
          block, index, frame, base_font, foreground,
        ),
        commands~,
      ),
    )
    y = block_bottom
  }
}

///|
fn append_rich_text_block_commands(
  commands : Array[@core.DrawCommand],
  block : RichTextBlock,
  block_frame : @core.Rect,
  line_height : Double,
  base_font : @core.FontSpec,
  foreground : @core.Color,
  text_system~ : @core.TextSystem,
) -> Unit {
  match block.background {
    Some(background) =>
      commands.push(
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(rect=block_frame, radius=block.corner_radius),
          background,
        ),
      )
    None => ()
  }
  match block.border_left {
    Some(border) =>
      if border.width > 0.0 {
        commands.push(
          @core.DrawCommand::FillRoundedRectBrush(
            @core.RoundedRect::new(
              rect=@core.Rect::new(
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
      @core.DrawCommand::FillRect(
        @core.Rect::new(
          x=block_frame.origin.x + block.inset.left,
          y=block_frame.origin.y + block_frame.size.height / 2.0,
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
      @core.Rect::new(
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
      @core.Rect::new(
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
      text_system~,
    )
  }
}

///|
fn append_rich_text_block_runs(
  commands : Array[@core.DrawCommand],
  block : RichTextBlock,
  frame : @core.Rect,
  base_font : @core.FontSpec,
  foreground : @core.Color,
  text_system~ : @core.TextSystem,
) -> Unit {
  let block_font = rich_text_block_font(block, base_font)
  let block_color = rich_text_block_color(block, foreground)
  let line_step = rich_text_block_line_step(block, base_font, text_system)
  let line_heights = rich_text_block_line_heights(
    block,
    base_font,
    text_system,
    frame.size.width,
  )
  let line_widths = rich_text_block_line_widths(
    block,
    base_font,
    text_system,
    frame.size.width,
  )
  let mut line = 0
  let mut x = rich_text_block_line_start_x(block, frame, line_widths, line)
  if block.prefix != "" {
    let width = rich_text_width(block.prefix, block_font, text_system)
    let prefix_frame = rich_text_text_paint_frame(
      x~,
      y=frame.origin.y,
      width~,
      height=line_heights.get(0).unwrap_or(line_step),
      line_right=frame.origin.x + frame.size.width,
      font=block_font,
    )
    commands.push(
      @core.DrawCommand::DrawText(
        @core.TextRun::new(
          text=block.prefix,
          frame=prefix_frame,
          font=block_font,
          color=block_color,
          align=@core.TextAlign::TextStart,
        ),
      ),
    )
    x = x + width
  }
  for run in block.runs {
    let font = run.font.unwrap_or(block_font)
    let color = run.color.unwrap_or(block_color)
    let segments = rich_text_split_lines(rich_text_run_visual_text(run))
    for index, segment in segments {
      let width = rich_text_run_segment_width(
        run,
        segment,
        font,
        text_system,
        available_width=frame.size.width,
      )
      let line_y = frame.origin.y + rich_text_line_offset(line_heights, line)
      let run_frame = rich_text_run_segment_paint_frame(
        run,
        x~,
        y=line_y,
        width~,
        height=rich_text_run_segment_height(
          run,
          line_step,
          available_width=frame.size.width,
        ),
        line_right=frame.origin.x + frame.size.width,
        font~,
      )
      if segment != "" || run.image_source is Some(_) {
        append_rich_text_run_segment(
          commands, run, segment, run_frame, width, font, color,
        )
      }
      if index + 1 < segments.length() {
        line = line + 1
        x = rich_text_block_line_start_x(block, frame, line_widths, line)
      } else {
        x = x + width
      }
    }
  }
}

///|
fn rich_text_block_line_start_x(
  block : RichTextBlock,
  frame : @core.Rect,
  line_widths : Array[Double],
  line : Int,
) -> Double {
  let width = min_double(
    frame.size.width,
    max_double(0.0, line_widths.get(line).unwrap_or(0.0)),
  )
  let remaining = max_double(0.0, frame.size.width - width)
  match block.line_align.unwrap_or(TextStart) {
    TextCenter => frame.origin.x + remaining / 2.0
    TextEnd => frame.origin.x + remaining
    TextStart => frame.origin.x
  }
}

///|
fn rich_text_run_segment_paint_frame(
  run : RichTextRun,
  x~ : Double,
  y~ : Double,
  width~ : Double,
  height~ : Double,
  line_right~ : Double,
  font~ : @core.FontSpec,
) -> @core.Rect {
  match run.image_source {
    Some(_) =>
      @core.Rect::new(
        x~,
        y~,
        width=max_double(0.0, min_double(width, line_right - x)),
        height~,
      )
    None =>
      rich_text_text_paint_frame(x~, y~, width~, height~, line_right~, font~)
  }
}

///|
fn rich_text_text_paint_frame(
  x~ : Double,
  y~ : Double,
  width~ : Double,
  height~ : Double,
  line_right~ : Double,
  font~ : @core.FontSpec,
) -> @core.Rect {
  @core.Rect::new(
    x~,
    y~,
    width=max_double(
      0.0,
      min_double(width + rich_text_text_clip_bleed(font), line_right - x),
    ),
    height~,
  )
}

///|
fn rich_text_text_clip_bleed(font : @core.FontSpec) -> Double {
  max_double(2.0, font.size * 0.18)
}

///|
fn append_rich_text_run_segment(
  commands : Array[@core.DrawCommand],
  run : RichTextRun,
  text : String,
  run_frame : @core.Rect,
  width : Double,
  font : @core.FontSpec,
  color : @core.Color,
) -> Unit {
  match run.background {
    Some(background) =>
      commands.push(
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(
            rect=@core.Rect::new(
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
        @core.DrawCommand::DrawImage({
          source,
          frame: run_frame,
          opacity: 1.0,
          fit: run.image_fit,
        }),
      )
    None =>
      commands.push(
        @core.DrawCommand::DrawText(
          @core.TextRun::new(
            text~,
            frame=run_frame,
            font~,
            color~,
            align=@core.TextAlign::TextStart,
          ),
        ),
      )
  }
  append_rich_text_run_decoration(commands, run, run_frame, width, font, color)
}

///|
fn append_rich_text_run_decoration(
  commands : Array[@core.DrawCommand],
  run : RichTextRun,
  frame : @core.Rect,
  width : Double,
  font : @core.FontSpec,
  color : @core.Color,
) -> Unit {
  match run.decoration {
    Some(RichTextDecoration::Strikethrough) => {
      let thickness = max_double(1.0, font.size / 14.0)
      commands.push(
        @core.DrawCommand::FillRect(
          @core.Rect::new(
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
fn append_rich_text_block_table(
  commands : Array[@core.DrawCommand],
  block : RichTextBlock,
  frame : @core.Rect,
  base_font : @core.FontSpec,
  foreground : @core.Color,
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
                @core.DrawCommand::FillRoundedRectBrush(
                  @core.RoundedRect::new(
                    rect=@core.Rect::new(
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
          let cell_frame = @core.Rect::new(
            x=cell_x,
            y=row_y,
            width=column_width,
            height=table.row_height,
          )
          commands.push(
            @core.DrawCommand::StrokeRect(cell_frame, table.border, 1.0),
          )
          if column_index < row.length() {
            let cell = row[column_index]
            commands.push(
              @core.DrawCommand::DrawText(
                @core.TextRun::new(
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
                  align=cell.align.unwrap_or(@core.TextAlign::TextStart),
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
fn append_rich_text_editor_overlay(
  commands : Array[@core.DrawCommand],
  text~ : String,
  display_text~ : String,
  document~ : RichTextDocument,
  content~ : @core.Rect,
  font~ : @core.FontSpec,
  cursor_color~ : @core.Color,
  control~ : @core.TextControlStateContext,
  text_system~ : @core.TextSystem,
  clip_rect? : @core.Rect? = None,
) -> Unit {
  let clip = match clip_rect {
    Some(r) => r
    None => content
  }
  commands.push(@core.DrawCommand::PushClip(clip))
  if control.composition is None {
    append_rich_text_selection_commands(
      commands,
      document,
      content,
      font,
      text_system,
      control.selection,
    )
  } else {
    append_rich_text_composition_underline(
      commands,
      document,
      text~,
      display_text~,
      content~,
      font~,
      text_system~,
      cursor_color~,
      control~,
    )
  }
  let caret = @core.clamp_int(
    rich_text_visual_caret(text, control, focused=true),
    0,
    text_length(display_text),
  )
  let caret_rect = rich_text_document_caret_rect_or_plain(
    document, caret, content, font, text_system, display_text,
  )
  commands.push(@core.DrawCommand::FillRect(caret_rect, cursor_color))
  commands.push(@core.DrawCommand::PopClip)
}

///|
fn append_rich_text_composition_underline(
  commands : Array[@core.DrawCommand],
  document : RichTextDocument,
  text~ : String,
  display_text~ : String,
  content~ : @core.Rect,
  font~ : @core.FontSpec,
  text_system~ : @core.TextSystem,
  cursor_color~ : @core.Color,
  control~ : @core.TextControlStateContext,
) -> Unit {
  match control.composition {
    Some(composition) =>
      if composition != "" {
        let start = @core.composition_start_index(
          text,
          control.caret,
          control.selection,
        )
        let end = start + text_length(composition)
        let start_rect = rich_text_document_caret_rect_or_plain(
          document, start, content, font, text_system, display_text,
        )
        let end_rect = rich_text_document_caret_rect_or_plain(
          document, end, content, font, text_system, display_text,
        )
        if end_rect.origin.x > start_rect.origin.x {
          commands.push(
            @core.DrawCommand::FillRect(
              @core.Rect::new(
                x=start_rect.origin.x,
                y=start_rect.origin.y + start_rect.size.height - 5.0,
                width=end_rect.origin.x - start_rect.origin.x,
                height=1.5,
              ),
              cursor_color.with_alpha(0.72),
            ),
          )
        }
      }
    None => ()
  }
}
