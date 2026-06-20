///|
pub fn[Msg] rich_text_editor(
  value~ : @core.Binding[String],
  placeholder~ : String,
  size~ : @core.Size,
  format~ : RichTextFormatter,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  placeholder_color~ : @core.Color,
  background~ : @core.Brush,
  border? : @core.BorderStyle? = None,
  focused_border? : @core.BorderStyle? = None,
  cursor_color~ : @core.Color,
  corner_radius? : Double = 0.0,
  on_input? : ((String) -> Msg)? = None,
  on_selection_change? : ((Int, @core.TextRange?) -> Msg)? = None,
  on_prefix_click? : ((Int) -> Msg)? = None,
  input_transform? : ((String, Int, @core.TextRange?, String) -> RichTextInputTransform?)? = None,
  accepts_tab_input? : Bool = false,
  kind? : String = "RichTextEditor",
  key? : String? = None,
) -> @core.View[Msg] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind~, key~),
    revision=() => {
      "rich-text-editor:\{value.get()}:\{placeholder}:\{view_size_revision(size)}:\{view_font_revision(font)}:\{view_color_revision(foreground)}:\{view_color_revision(placeholder_color)}:\{view_brush_revision(background)}:\{view_border_option_revision(border)}:\{view_border_option_revision(focused_border)}:\{view_color_revision(cursor_color)}:\{corner_radius}:\{accepts_tab_input}"
    },
    layout=ctx => {
      @core.ViewLayoutResult::new(size=ctx.constraints.constrain(size))
    },
    paint=ctx => {
      rich_text_editor_paint(
        ctx,
        value~,
        placeholder~,
        format~,
        font~,
        foreground~,
        placeholder_color~,
        background~,
        border~,
        focused_border~,
        cursor_color~,
        corner_radius~,
      )
    },
    event=ctx => {
      rich_text_editor_event(
        ctx,
        value~,
        format~,
        font~,
        on_input~,
        on_selection_change~,
        on_prefix_click~,
        input_transform~,
        accepts_tab_input~,
      )
    },
    text_input_state=ctx => {
      Some(
        rich_text_input_state(
          text=value.get(),
          frame=ctx.frame,
          format~,
          font~,
          control=ctx.text_control,
          text_system=ctx.text_system,
        ),
      )
    },
    text_command=(ctx, intent, paste_text) => {
      rich_text_editor_command(
        ctx,
        value~,
        format~,
        on_input~,
        on_selection_change~,
        input_transform~,
        intent,
        paste_text~,
      )
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        role=@core.SemanticsRole::TextField,
        label=placeholder,
        value=value.get(),
        actions=[
          @core.SemanticsAction::Focus,
          @core.SemanticsAction::SetText,
          @core.SemanticsAction::Submit,
        ],
      )
    },
    focusable=() => true,
  )
}

///|
pub fn[Msg] controlled_rich_text_editor(
  value~ : String,
  on_input~ : (String) -> Msg,
  placeholder~ : String,
  size~ : @core.Size,
  format~ : RichTextFormatter,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  placeholder_color~ : @core.Color,
  background~ : @core.Brush,
  border? : @core.BorderStyle? = None,
  focused_border? : @core.BorderStyle? = None,
  cursor_color~ : @core.Color,
  corner_radius? : Double = 0.0,
  on_selection_change? : ((Int, @core.TextRange?) -> Msg)? = None,
  on_prefix_click? : ((Int) -> Msg)? = None,
  input_transform? : ((String, Int, @core.TextRange?, String) -> RichTextInputTransform?)? = None,
  accepts_tab_input? : Bool = false,
  kind? : String = "RichTextEditor",
  key? : String? = None,
) -> @core.View[Msg] {
  rich_text_editor(
    value=@core.Binding::new(get=() => value, set=_next => ()),
    placeholder~,
    size~,
    format~,
    font~,
    foreground~,
    placeholder_color~,
    background~,
    border~,
    focused_border~,
    cursor_color~,
    corner_radius~,
    on_input=Some(on_input),
    on_selection_change~,
    on_prefix_click~,
    input_transform~,
    accepts_tab_input~,
    kind~,
    key~,
  )
}

///|
fn rich_text_editor_paint(
  ctx : @core.ViewPaintContext,
  value~ : @core.Binding[String],
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
  let text = value.get()
  let display_text = rich_text_with_composition(
    text,
    ctx.text_control,
    focused=ctx.focused,
  )
  let content = rich_text_editor_content_rect(ctx.frame)
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
    append_rich_text_document_layers(
      child_layers,
      document,
      content,
      font,
      foreground,
      text_system=ctx.text_system,
    )
    if ctx.focused {
      append_rich_text_editor_overlay(
        overlay_commands,
        text~,
        display_text~,
        document~,
        content~,
        font~,
        cursor_color~,
        control=ctx.text_control,
        text_system=ctx.text_system,
      )
    }
  }
  commands.push(@core.DrawCommand::PopClip)
  {
    commands,
    child_layers,
    post_commands: [],
    overlay_commands,
    platform_views: [],
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
fn append_rich_text_document_layers(
  layers : Array[@core.ViewPaintLayer],
  document : RichTextDocument,
  content : @core.Rect,
  base_font : @core.FontSpec,
  foreground : @core.Color,
  text_system~ : @core.TextSystem,
) -> Unit {
  let mut y = content.origin.y
  for index, block in document.blocks {
    let line_height = rich_text_block_line_height(block, base_font)
    let block_height = line_height + block.inset.top + block.inset.bottom
    if y > content.origin.y + content.size.height {
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
    y = y + block_height
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
  let line_step = rich_text_block_line_step(block, base_font)
  let mut x = frame.origin.x
  let mut line = 0
  if block.prefix != "" {
    let width = rich_text_width(block.prefix, block_font, text_system)
    commands.push(
      @core.DrawCommand::DrawText(
        @core.TextRun::new(
          text=block.prefix,
          frame=@core.Rect::new(
            x~,
            y=frame.origin.y,
            width~,
            height=frame.size.height,
          ),
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
      let width = rich_text_run_segment_width(run, segment, font, text_system)
      let line_y = frame.origin.y + line.to_double() * line_step
      let run_frame = @core.Rect::new(
        x~,
        y=line_y,
        width=max_double(
          0.0,
          min_double(width, frame.origin.x + frame.size.width - x),
        ),
        height=rich_text_run_segment_height(run, line_step),
      )
      if segment != "" || run.image_source is Some(_) {
        append_rich_text_run_segment(
          commands, run, segment, run_frame, width, font, color,
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
) -> Unit {
  commands.push(@core.DrawCommand::PushClip(content))
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
  let caret = clamp_int(
    rich_text_visual_caret(text, control, focused=true),
    0,
    text_length(display_text),
  )
  let caret_rect = rich_text_document_caret_rect_at_source(
    document,
    caret,
    content,
    font,
    text_system~,
  ).unwrap_or(
    plain_rich_text_caret_rect(display_text, caret, content, font, text_system),
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
        let start = composition_start_index(
          text,
          control.caret,
          control.selection,
        )
        let end = start + text_length(composition)
        let start_rect = rich_text_document_caret_rect_at_source(
          document,
          start,
          content,
          font,
          text_system~,
        ).unwrap_or(
          plain_rich_text_caret_rect(
            display_text, start, content, font, text_system,
          ),
        )
        let end_rect = rich_text_document_caret_rect_at_source(
          document,
          end,
          content,
          font,
          text_system~,
        ).unwrap_or(
          plain_rich_text_caret_rect(
            display_text, end, content, font, text_system,
          ),
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

///|
fn[Msg] rich_text_editor_event(
  ctx : @core.ViewEventContext,
  value~ : @core.Binding[String],
  format~ : RichTextFormatter,
  font~ : @core.FontSpec,
  on_input~ : ((String) -> Msg)?,
  on_selection_change~ : ((Int, @core.TextRange?) -> Msg)?,
  on_prefix_click~ : ((Int) -> Msg)?,
  input_transform~ : ((String, Int, @core.TextRange?, String) -> RichTextInputTransform?)?,
  accepts_tab_input~ : Bool,
) -> @core.ViewEventResult[Msg] {
  match ctx.event {
    @core.AppEvent::Pointer(event) =>
      rich_text_pointer_event(
        ctx,
        value~,
        format~,
        font~,
        on_selection_change~,
        on_prefix_click~,
        event~,
      )
    @core.AppEvent::Keyboard(event) =>
      rich_text_keyboard_event(
        ctx,
        value~,
        on_input~,
        on_selection_change~,
        input_transform~,
        accepts_tab_input~,
        event~,
      )
    @core.AppEvent::TextInput(event) =>
      rich_text_input_event(
        ctx,
        value~,
        on_input~,
        on_selection_change~,
        input_transform~,
        event~,
        record_history=true,
      )
    _ => @core.ViewEventResult::ignored()
  }
}

///|
fn[Msg] rich_text_pointer_event(
  ctx : @core.ViewEventContext,
  value~ : @core.Binding[String],
  format~ : RichTextFormatter,
  font~ : @core.FontSpec,
  on_selection_change~ : ((Int, @core.TextRange?) -> Msg)?,
  on_prefix_click~ : ((Int) -> Msg)?,
  event~ : @core.PointerEvent,
) -> @core.ViewEventResult[Msg] {
  let inside = ctx.frame.contains(event.position)
  match event.phase {
    @core.PointerPhase::Down =>
      if inside {
        let text = value.get()
        let document = format(text)
        let content = rich_text_editor_content_rect(ctx.frame)
        let prefix_messages = match on_prefix_click {
          Some(handler) =>
            match
              rich_text_document_prefix_source_offset_at_point(
                document,
                event.position,
                content,
                font,
                ctx.text_system,
              ) {
              Some(offset) => [handler(offset)]
              None => []
            }
          None => []
        }
        let caret = rich_text_document_source_offset_at_point(
          document,
          event.position,
          content,
          font,
          ctx.text_system,
        ).unwrap_or(text_length(text))
        let next_control = {
          ..ctx.text_control,
          caret,
          selection: None,
          text_selection_anchor: Some(caret),
          composition: None,
          composition_cursor: None,
        }
        view_event_result(
          changed=true,
          focused=true,
          captured=true,
          text_control=Some(next_control),
          dirty=@core.ViewDirtyHint::ViewPaintDirty,
          messages=prefix_messages +
            selection_messages(on_selection_change, caret, None),
        )
      } else {
        @core.ViewEventResult::ignored()
      }
    @core.PointerPhase::Move =>
      match ctx.text_control.text_selection_anchor {
        Some(anchor) => {
          let text = value.get()
          let document = format(text)
          let content = rich_text_editor_content_rect(ctx.frame)
          let caret = rich_text_document_source_offset_at_point(
            document,
            event.position,
            content,
            font,
            ctx.text_system,
          ).unwrap_or(text_length(text))
          let next_selection = if caret == anchor {
            None
          } else {
            Some(@core.TextRange::new(start=anchor, end=caret))
          }
          let changed = ctx.text_control.caret != caret ||
            ctx.text_control.selection != next_selection
          let next_control = {
            ..ctx.text_control,
            caret,
            selection: next_selection,
            composition: None,
            composition_cursor: None,
          }
          view_event_result(
            changed~,
            captured=true,
            text_control=Some(next_control),
            dirty=@core.ViewDirtyHint::ViewPaintDirty,
            messages=if changed {
              selection_messages(on_selection_change, caret, next_selection)
            } else {
              []
            },
          )
        }
        None => @core.ViewEventResult::ignored()
      }
    @core.PointerPhase::Up
    | @core.PointerPhase::Cancel
    | @core.PointerPhase::Exit => {
      let changed = ctx.text_control.text_selection_anchor is Some(_)
      view_event_result(
        changed~,
        captured=changed,
        text_control=Some({ ..ctx.text_control, text_selection_anchor: None }),
        dirty=@core.ViewDirtyHint::ViewPaintDirty,
      )
    }
  }
}

///|
fn[Msg] rich_text_keyboard_event(
  ctx : @core.ViewEventContext,
  value~ : @core.Binding[String],
  on_input~ : ((String) -> Msg)?,
  on_selection_change~ : ((Int, @core.TextRange?) -> Msg)?,
  input_transform~ : ((String, Int, @core.TextRange?, String) -> RichTextInputTransform?)?,
  accepts_tab_input~ : Bool,
  event~ : @core.KeyboardEvent,
) -> @core.ViewEventResult[Msg] {
  if !event.pressed {
    return @core.ViewEventResult::ignored()
  }
  if event.key == "Tab" && accepts_tab_input {
    let text = if event.modifiers.shift { "\u{000b}" } else { "\t" }
    return rich_text_input_event(
      ctx,
      value~,
      on_input~,
      on_selection_change~,
      input_transform~,
      event=@core.TextInputEvent::InsertText(text),
      record_history=true,
    )
  }
  if event.key == "Enter" {
    return rich_text_input_event(
      ctx,
      value~,
      on_input~,
      on_selection_change~,
      input_transform~,
      event=@core.TextInputEvent::InsertText("\n"),
      record_history=true,
    )
  }
  if is_select_all_shortcut(event) {
    let next_control = select_rich_text_control(ctx.text_control, value.get())
    return view_event_result(
      changed=true,
      captured=true,
      text_control=Some(next_control),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
      messages=selection_messages(
        on_selection_change,
        next_control.caret,
        next_control.selection,
      ),
    )
  }
  if is_undo_shortcut(event) {
    let result = restore_text_history(ctx.text_control, value.get(), undo=true)
    value.set(result.text)
    return view_event_result(
      changed=result.changed,
      captured=true,
      text_control=Some(result.control),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
      messages=text_input_messages(on_input, result.text) +
        selection_messages(
          on_selection_change,
          result.control.caret,
          result.control.selection,
        ),
    )
  }
  if is_redo_shortcut(event) {
    let result = restore_text_history(ctx.text_control, value.get(), undo=false)
    value.set(result.text)
    return view_event_result(
      changed=result.changed,
      captured=true,
      text_control=Some(result.control),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
      messages=text_input_messages(on_input, result.text) +
        selection_messages(
          on_selection_change,
          result.control.caret,
          result.control.selection,
        ),
    )
  }
  if event.key == "Backspace" {
    match active_text_selection(ctx.text_control.selection) {
      Some(selection) =>
        return rich_text_input_event(
          ctx,
          value~,
          on_input~,
          on_selection_change~,
          input_transform~,
          event=@core.TextInputEvent::DeleteRange(selection),
          record_history=true,
        )
      None =>
        return rich_text_input_event(
          ctx,
          value~,
          on_input~,
          on_selection_change~,
          input_transform~,
          event=@core.TextInputEvent::DeleteSurrounding(1, 0),
          record_history=true,
        )
    }
  }
  if event.key == "Delete" {
    match active_text_selection(ctx.text_control.selection) {
      Some(selection) =>
        return rich_text_input_event(
          ctx,
          value~,
          on_input~,
          on_selection_change~,
          input_transform~,
          event=@core.TextInputEvent::DeleteRange(selection),
          record_history=true,
        )
      None =>
        return rich_text_input_event(
          ctx,
          value~,
          on_input~,
          on_selection_change~,
          input_transform~,
          event=@core.TextInputEvent::DeleteSurrounding(0, 1),
          record_history=true,
        )
    }
  }
  if event.key == "ArrowLeft" {
    return rich_text_caret_move_result(
      ctx,
      value.get(),
      MoveLeft,
      event.modifiers.shift,
      on_selection_change,
    )
  }
  if event.key == "ArrowRight" {
    return rich_text_caret_move_result(
      ctx,
      value.get(),
      MoveRight,
      event.modifiers.shift,
      on_selection_change,
    )
  }
  if event.key == "Home" {
    return rich_text_line_edge_move_result(
      ctx,
      value.get(),
      home=true,
      on_selection_change,
    )
  }
  if event.key == "End" {
    return rich_text_line_edge_move_result(
      ctx,
      value.get(),
      home=false,
      on_selection_change,
    )
  }
  match event.text {
    Some(text) =>
      if text != "" {
        rich_text_input_event(
          ctx,
          value~,
          on_input~,
          on_selection_change~,
          input_transform~,
          event=@core.TextInputEvent::InsertText(text),
          record_history=true,
        )
      } else {
        @core.ViewEventResult::ignored()
      }
    None => @core.ViewEventResult::ignored()
  }
}

///|
fn[Msg] rich_text_input_event(
  ctx : @core.ViewEventContext,
  value~ : @core.Binding[String],
  on_input~ : ((String) -> Msg)?,
  on_selection_change~ : ((Int, @core.TextRange?) -> Msg)?,
  input_transform~ : ((String, Int, @core.TextRange?, String) -> RichTextInputTransform?)?,
  event~ : @core.TextInputEvent,
  record_history~ : Bool,
) -> @core.ViewEventResult[Msg] {
  let text = value.get()
  let result = match event {
    @core.TextInputEvent::InsertText(inserted) =>
      if inserted == "" {
        (
          { text, control: ctx.text_control, changed: false } :
          TextInputApplyResult)
      } else {
        match
          rich_text_transform_insert(
            input_transform,
            text,
            ctx.text_control,
            inserted,
          ) {
          Some(transformed) =>
            apply_rich_text_input_transform(
              ctx.text_control,
              text,
              transformed,
              record_history~,
            )
          None =>
            apply_text_input(ctx.text_control, text, event, record_history~)
        }
      }
    @core.TextInputEvent::DeleteRange(_) =>
      match
        rich_text_transform_insert(
          input_transform,
          text,
          ctx.text_control,
          "\u{000e}",
        ) {
        Some(transformed) =>
          apply_rich_text_input_transform(
            ctx.text_control,
            text,
            transformed,
            record_history~,
          )
        None => apply_text_input(ctx.text_control, text, event, record_history~)
      }
    @core.TextInputEvent::DeleteSurrounding(before, after) => {
      let signal = if before > 0 && after == 0 {
        "\u{0008}"
      } else if before == 0 && after > 0 {
        "\u{007f}"
      } else {
        ""
      }
      if signal != "" {
        match
          rich_text_transform_insert(
            input_transform,
            text,
            ctx.text_control,
            signal,
          ) {
          Some(transformed) =>
            apply_rich_text_input_transform(
              ctx.text_control,
              text,
              transformed,
              record_history~,
            )
          None =>
            apply_text_input(ctx.text_control, text, event, record_history~)
        }
      } else {
        apply_text_input(ctx.text_control, text, event, record_history~)
      }
    }
    _ => apply_text_input(ctx.text_control, text, event, record_history~)
  }
  if result.changed {
    value.set(result.text)
  }
  view_event_result(
    changed=result.changed,
    captured=result.changed,
    text_control=Some(result.control),
    dirty=@core.ViewDirtyHint::ViewPaintDirty,
    messages=if result.changed {
      text_input_messages(on_input, result.text) +
      selection_messages(
        on_selection_change,
        result.control.caret,
        result.control.selection,
      )
    } else {
      []
    },
  )
}

///|
fn[Msg] rich_text_editor_command(
  ctx : @core.ViewEventContext,
  value~ : @core.Binding[String],
  format~ : RichTextFormatter,
  on_input~ : ((String) -> Msg)?,
  on_selection_change~ : ((Int, @core.TextRange?) -> Msg)?,
  input_transform~ : ((String, Int, @core.TextRange?, String) -> RichTextInputTransform?)?,
  intent : @core.CommandIntent,
  paste_text~ : String?,
) -> @core.ViewTextCommandResult[Msg] {
  let text = value.get()
  let document = format(text)
  match intent {
    @core.CommandIntent::Copy =>
      @core.ViewTextCommandResult::new(
        result=@core.TextCommandResult::handled(
          clipboard_text=Some(
            selected_rich_text(text, document, ctx.text_control.selection),
          ),
        ),
      )
    @core.CommandIntent::Cut => {
      let copied = selected_rich_text(
        text,
        document,
        ctx.text_control.selection,
      )
      match active_text_selection(ctx.text_control.selection) {
        Some(selection) => {
          let event_result = rich_text_input_event(
            ctx,
            value~,
            on_input~,
            on_selection_change~,
            input_transform~,
            event=@core.TextInputEvent::DeleteRange(selection),
            record_history=true,
          )
          @core.ViewTextCommandResult::new(
            result=@core.TextCommandResult::handled(
              changed=event_result.changed,
              clipboard_text=Some(copied),
            ),
            text_control=event_result.text_control,
            messages=event_result.messages,
          )
        }
        None =>
          @core.ViewTextCommandResult::new(
            result=@core.TextCommandResult::handled(clipboard_text=Some("")),
          )
      }
    }
    @core.CommandIntent::Paste =>
      match paste_text {
        Some(value_to_paste) => {
          let event_result = rich_text_input_event(
            ctx,
            value~,
            on_input~,
            on_selection_change~,
            input_transform~,
            event=@core.TextInputEvent::InsertText(value_to_paste),
            record_history=true,
          )
          @core.ViewTextCommandResult::new(
            result=@core.TextCommandResult::handled(
              changed=event_result.changed,
            ),
            text_control=event_result.text_control,
            messages=event_result.messages,
          )
        }
        None =>
          @core.ViewTextCommandResult::new(
            result=@core.TextCommandResult::handled(),
          )
      }
    @core.CommandIntent::Undo => {
      let result = restore_text_history(ctx.text_control, text, undo=true)
      if result.changed {
        value.set(result.text)
      }
      @core.ViewTextCommandResult::new(
        result=@core.TextCommandResult::handled(changed=result.changed),
        text_control=Some(result.control),
        messages=if result.changed {
          text_input_messages(on_input, result.text) +
          selection_messages(
            on_selection_change,
            result.control.caret,
            result.control.selection,
          )
        } else {
          []
        },
      )
    }
    @core.CommandIntent::Redo => {
      let result = restore_text_history(ctx.text_control, text, undo=false)
      if result.changed {
        value.set(result.text)
      }
      @core.ViewTextCommandResult::new(
        result=@core.TextCommandResult::handled(changed=result.changed),
        text_control=Some(result.control),
        messages=if result.changed {
          text_input_messages(on_input, result.text) +
          selection_messages(
            on_selection_change,
            result.control.caret,
            result.control.selection,
          )
        } else {
          []
        },
      )
    }
    @core.CommandIntent::SelectAll => {
      let next_control = select_rich_text_control(ctx.text_control, text)
      @core.ViewTextCommandResult::new(
        result=@core.TextCommandResult::handled(changed=true),
        text_control=Some(next_control),
        messages=selection_messages(
          on_selection_change,
          next_control.caret,
          next_control.selection,
        ),
      )
    }
    _ => @core.ViewTextCommandResult::ignored()
  }
}

///|
fn rich_text_input_state(
  text~ : String,
  frame~ : @core.Rect,
  format~ : RichTextFormatter,
  font~ : @core.FontSpec,
  control~ : @core.TextControlStateContext,
  text_system~ : @core.TextSystem,
) -> @core.TextInputState {
  let boundaries = @core.TextGraphemeBoundaries::new(text~)
  let display_text = rich_text_with_composition(text, control, focused=true)
  let content = rich_text_editor_content_rect(frame)
  let caret = boundaries.nearest_boundary(control.caret)
  let visual_caret = clamp_int(
    rich_text_visual_caret(text, control, focused=true),
    0,
    text_length(display_text),
  )
  let document = format(display_text)
  let caret_rect = rich_text_document_caret_rect_at_source(
    document,
    visual_caret,
    content,
    font,
    text_system~,
  ).unwrap_or(
    plain_rich_text_caret_rect(
      display_text, visual_caret, content, font, text_system,
    ),
  )
  {
    focused: true,
    element_id: None,
    text,
    caret,
    selection: rich_text_input_grapheme_selection(boundaries, control.selection),
    composition: control.composition,
    composition_cursor: control.composition_cursor,
    frame,
    caret_rect,
  }
}

///|
fn[Msg] rich_text_caret_move_result(
  ctx : @core.ViewEventContext,
  text : String,
  direction : TextCaretDirection,
  extend : Bool,
  on_selection_change : ((Int, @core.TextRange?) -> Msg)?,
) -> @core.ViewEventResult[Msg] {
  let caret_move = move_text_caret(
    text,
    ctx.text_control.caret,
    ctx.text_control.selection,
    direction,
    extend~,
  )
  let next_control = {
    ..ctx.text_control,
    caret: caret_move.caret,
    selection: caret_move.selection,
    composition: None,
    composition_cursor: None,
  }
  let changed = next_control.caret != ctx.text_control.caret ||
    next_control.selection != ctx.text_control.selection ||
    ctx.text_control.composition is Some(_) ||
    ctx.text_control.composition_cursor is Some(_)
  view_event_result(
    changed~,
    captured=true,
    text_control=Some(next_control),
    dirty=@core.ViewDirtyHint::ViewPaintDirty,
    messages=if changed {
      selection_messages(
        on_selection_change,
        next_control.caret,
        next_control.selection,
      )
    } else {
      []
    },
  )
}

///|
fn rich_text_with_composition(
  text : String,
  control : @core.TextControlStateContext,
  focused~ : Bool,
) -> String {
  if !focused {
    text
  } else {
    match control.composition {
      Some(composition) =>
        replace_current_selection(
          text,
          control.caret,
          control.selection,
          composition,
        ).text
      None => text
    }
  }
}

///|
fn rich_text_visual_caret(
  text : String,
  control : @core.TextControlStateContext,
  focused~ : Bool,
) -> Int {
  let caret = clamp_int(control.caret, 0, text_length(text))
  if !focused {
    caret
  } else {
    match control.composition {
      Some(composition) =>
        composition_start_index(text, control.caret, control.selection) +
        composition_cursor_offset(control, composition)
      None => caret
    }
  }
}

///|
fn plain_rich_text_caret_rect(
  text : String,
  caret : Int,
  content : @core.Rect,
  font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> @core.Rect {
  let prefix = string_prefix(text, caret)
  let width = text_system.measure_text(
      @core.TextLayoutInput::new(
        text=prefix,
        font~,
        max_width=content.size.width,
      ),
    ).size.width
  @core.Rect::new(
    x=content.origin.x + width,
    y=content.origin.y + 4.0,
    width=1.5,
    height=max_double(10.0, font.size * 1.55 - 8.0),
  )
}

///|
pub fn rich_text_editor_content_rect(frame : @core.Rect) -> @core.Rect {
  frame.inset(@core.Insets::symmetric(horizontal=14.0, vertical=12.0))
}

///|
fn string_prefix(text : String, end : Int) -> String {
  let chars = text.to_array()
  String::from_array(chars[:clamp_int(end, 0, chars.length())])
}

///|
pub fn rich_text_document_height(
  document : RichTextDocument,
  base_font : @core.FontSpec,
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
fn rich_text_block_line_height(
  block : RichTextBlock,
  base_font : @core.FontSpec,
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
  base_font : @core.FontSpec,
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
fn rich_text_run_visual_text(run : RichTextRun) -> String {
  run.visual_text.unwrap_or(run.text)
}

///|
fn rich_text_block_font(
  block : RichTextBlock,
  base_font : @core.FontSpec,
) -> @core.FontSpec {
  block.font.unwrap_or(base_font)
}

///|
fn rich_text_block_color(
  block : RichTextBlock,
  foreground : @core.Color,
) -> @core.Color {
  block.color.unwrap_or(foreground)
}

///|
fn rich_text_width(
  text : String,
  font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> Double {
  text_system.measure_text(@core.TextLayoutInput::new(text~, font~)).size.width
}

///|
fn rich_text_run_segment_width(
  run : RichTextRun,
  text : String,
  font : @core.FontSpec,
  text_system : @core.TextSystem,
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
    _ => None
  }
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
fn rich_text_input_grapheme_selection(
  boundaries : @core.TextGraphemeBoundaries,
  selection : @core.TextRange?,
) -> @core.TextRange? {
  match selection {
    Some(selection) => {
      let start = boundaries.nearest_boundary(selection.start)
      let end = boundaries.nearest_boundary(selection.end)
      if start == end {
        None
      } else {
        Some(@core.TextRange::new(start~, end~))
      }
    }
    _ => None
  }
}

///|
fn select_rich_text_control(
  control : @core.TextControlStateContext,
  text : String,
) -> @core.TextControlStateContext {
  let length = text_length(text)
  {
    ..control,
    caret: length,
    selection: Some(@core.TextRange::new(start=0, end=length)),
    text_selection_anchor: None,
    composition: None,
    composition_cursor: None,
  }
}

///|
fn[Msg] rich_text_line_edge_move_result(
  ctx : @core.ViewEventContext,
  text : String,
  home~ : Bool,
  on_selection_change : ((Int, @core.TextRange?) -> Msg)?,
) -> @core.ViewEventResult[Msg] {
  let caret = if home {
    multiline_line_start(text, ctx.text_control.caret)
  } else {
    multiline_line_end(text, ctx.text_control.caret)
  }
  let next_control = {
    ..ctx.text_control,
    caret,
    selection: None,
    composition: None,
    composition_cursor: None,
  }
  let changed = next_control.caret != ctx.text_control.caret ||
    ctx.text_control.selection is Some(_) ||
    ctx.text_control.composition is Some(_) ||
    ctx.text_control.composition_cursor is Some(_)
  view_event_result(
    changed~,
    captured=true,
    text_control=Some(next_control),
    dirty=@core.ViewDirtyHint::ViewPaintDirty,
    messages=if changed {
      selection_messages(
        on_selection_change,
        next_control.caret,
        next_control.selection,
      )
    } else {
      []
    },
  )
}

///|
fn multiline_line_start(text : String, caret : Int) -> Int {
  let chars = text.to_array()
  let mut index = clamp_int(caret, 0, chars.length())
  while index > 0 && chars[index - 1] != '\n' {
    index = index - 1
  }
  index
}

///|
fn multiline_line_end(text : String, caret : Int) -> Int {
  let chars = text.to_array()
  let mut index = clamp_int(caret, 0, chars.length())
  while index < chars.length() && chars[index] != '\n' {
    index = index + 1
  }
  index
}

///|
fn rich_text_transform_insert(
  input_transform : ((String, Int, @core.TextRange?, String) -> RichTextInputTransform?)?,
  text : String,
  control : @core.TextControlStateContext,
  inserted : String,
) -> RichTextInputTransform? {
  match input_transform {
    Some(transform) =>
      transform(text, control.caret, control.selection, inserted)
    None => None
  }
}

///|
fn apply_rich_text_input_transform(
  control : @core.TextControlStateContext,
  previous : String,
  edit : RichTextInputTransform,
  record_history~ : Bool,
) -> TextInputApplyResult {
  let changed = edit.text != previous ||
    edit.caret != control.caret ||
    edit.selection != control.selection ||
    control.composition is Some(_) ||
    control.composition_cursor is Some(_)
  if changed {
    let undo_stack : Array[@core.TextHistoryEntryContext] = []
    undo_stack.append(control.undo_stack)
    if record_history && previous != edit.text {
      undo_stack.push({
        text: previous,
        caret: control.caret,
        selection: control.selection,
      })
    }
    {
      text: edit.text,
      control: {
        ..control,
        caret: edit.caret,
        selection: edit.selection,
        composition: None,
        composition_cursor: None,
        undo_stack,
        redo_stack: [],
      },
      changed: true,
    }
  } else {
    { text: previous, control, changed: false }
  }
}

///|
fn selected_rich_text(
  text : String,
  document : RichTextDocument,
  selection : @core.TextRange?,
) -> String {
  match active_text_selection(selection) {
    Some(selection) =>
      if rich_text_document_has_source_ranges(document) {
        selected_rich_text_document_text(document, selection)
      } else {
        selected_text(text, Some(selection))
      }
    None => ""
  }
}

///|
fn selected_rich_text_document_text(
  document : RichTextDocument,
  selection : @core.TextRange,
) -> String {
  let lines : Array[String] = []
  for block in document.blocks {
    match selected_rich_text_block_text(block, selection) {
      Some(text) => lines.push(text)
      None => ()
    }
  }
  join_text_lines(lines)
}

///|
fn selected_rich_text_block_text(
  block : RichTextBlock,
  selection : @core.TextRange,
) -> String? {
  match (block.source_range, block.content_range) {
    (Some(source), Some(content)) =>
      if selection.end <= source.start || selection.start >= source.end {
        None
      } else {
        let start = clamp_int(selection.start, content.start, content.end)
        let end = clamp_int(selection.end, content.start, content.end)
        let text = selected_rich_text_runs_text(block, start, end)
        if text == "" && start != end {
          None
        } else {
          Some(text)
        }
      }
    (_, Some(content)) =>
      if selection.end <= content.start || selection.start >= content.end {
        None
      } else {
        let start = clamp_int(selection.start, content.start, content.end)
        let end = clamp_int(selection.end, content.start, content.end)
        let text = selected_rich_text_runs_text(block, start, end)
        if text == "" && start != end {
          None
        } else {
          Some(text)
        }
      }
    _ => None
  }
}

///|
fn selected_rich_text_runs_text(
  block : RichTextBlock,
  start : Int,
  end : Int,
) -> String {
  let parts : Array[String] = []
  for run in block.runs {
    match run.source_range {
      Some(range) =>
        if end > range.start && start < range.end {
          let copy_text = rich_text_run_copy_text(run)
          parts.push(
            rich_text_run_slice(
              copy_text,
              rich_text_run_copy_offset(
                start - range.start,
                source_text=run.text,
                copy_text~,
              ),
              rich_text_run_copy_offset(
                end - range.start,
                source_text=run.text,
                copy_text~,
              ),
            ),
          )
        }
      None => ()
    }
  }
  join_text_lines(parts)
}

///|
fn rich_text_run_copy_text(run : RichTextRun) -> String {
  match run.visual_text {
    Some(text) => text
    None =>
      match run.image_source {
        Some(_) => rich_text_image_alt_text(run.text).unwrap_or(run.text)
        None => run.text
      }
  }
}

///|
fn rich_text_run_copy_offset(
  source_offset : Int,
  source_text~ : String,
  copy_text~ : String,
) -> Int {
  let source_length = text_length(source_text)
  let copy_length = text_length(copy_text)
  if source_length <= 0 || copy_length <= 0 {
    0
  } else {
    clamp_int(
      (source_offset.to_double() *
      copy_length.to_double() /
      source_length.to_double())
      .round()
      .to_int(),
      0,
      copy_length,
    )
  }
}

///|
fn rich_text_image_alt_text(text : String) -> String? {
  let chars = text.to_array()
  if chars.length() < 5 || chars[0] != '!' || chars[1] != '[' {
    return None
  }
  let mut index = 2
  while index < chars.length() {
    if chars[index] == ']' &&
      index + 1 < chars.length() &&
      chars[index + 1] == '(' {
      return Some(String::from_array(chars[2:index]))
    }
    index = index + 1
  }
  None
}

///|
fn rich_text_run_slice(text : String, start : Int, end : Int) -> String {
  let chars = text.to_array()
  let range = @core.normalize_grapheme_range(
    @core.TextGraphemeBoundaries::new(text~),
    @core.TextRange::new(start~, end~),
  )
  let start = clamp_int(range.start, 0, chars.length())
  let end = clamp_int(range.end, start, chars.length())
  String::from_array(chars[start:end])
}

///|
fn join_text_lines(lines : Array[String]) -> String {
  let chars : Array[Char] = []
  for index in 0..<lines.length() {
    if index > 0 {
      chars.push('\n')
    }
    chars.append(lines[index].to_array())
  }
  String::from_array(chars)
}

///|
fn append_rich_text_selection_commands(
  commands : Array[@core.DrawCommand],
  document : RichTextDocument,
  content : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
  selection : @core.TextRange?,
) -> Unit {
  match active_text_selection(selection) {
    Some(selection) => {
      let mut y = content.origin.y
      for block in document.blocks {
        let line_height = rich_text_block_line_height(block, base_font)
        let block_height = line_height + block.inset.top + block.inset.bottom
        let frame = @core.Rect::new(
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
fn rich_text_block_selection_visual_range(
  block : RichTextBlock,
  selection : @core.TextRange,
) -> @core.TextRange? {
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
          Some(@core.TextRange::new(start~, end~))
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
          Some(@core.TextRange::new(start~, end~))
        } else {
          None
        }
      }
    _ => None
  }
}

///|
fn append_rich_text_block_selection_rect(
  commands : Array[@core.DrawCommand],
  block : RichTextBlock,
  range : @core.TextRange,
  frame : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
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
      @core.DrawCommand::FillRect(
        @core.Rect::new(
          x=start_rect.origin.x,
          y=frame.origin.y + 4.0,
          width=end_rect.origin.x - start_rect.origin.x,
          height=max_double(10.0, frame.size.height - 8.0),
        ),
        @core.Color::blue().with_alpha(0.18),
      ),
    )
  }
}

///|
pub fn rich_text_document_caret_rect_at_source(
  document : RichTextDocument,
  source_caret : Int,
  content : @core.Rect,
  base_font : @core.FontSpec,
  text_system? : @core.TextSystem = @core.TextSystem::fallback(),
) -> @core.Rect? {
  rich_text_document_caret_rect(
    document, source_caret, content, base_font, text_system,
  )
}

///|
fn rich_text_document_caret_rect(
  document : RichTextDocument,
  source_caret : Int,
  content : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> @core.Rect? {
  if !rich_text_document_has_source_ranges(document) {
    return None
  }
  let mut y = content.origin.y
  let mut last_rect = @core.Rect::new(
    x=content.origin.x,
    y=content.origin.y + 4.0,
    width=1.5,
    height=max_double(10.0, base_font.size * 1.55 - 8.0),
  )
  for block in document.blocks {
    let line_height = rich_text_block_line_height(block, base_font)
    let block_height = line_height + block.inset.top + block.inset.bottom
    let frame = @core.Rect::new(
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
fn rich_text_document_source_offset_at_point(
  document : RichTextDocument,
  point : @core.Point,
  content : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> Int? {
  if !rich_text_document_has_source_ranges(document) {
    return None
  }
  let mut y = content.origin.y
  let mut last_offset : Int? = None
  for block in document.blocks {
    let line_height = rich_text_block_line_height(block, base_font)
    let block_height = line_height + block.inset.top + block.inset.bottom
    let frame = @core.Rect::new(
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
fn rich_text_document_prefix_source_offset_at_point(
  document : RichTextDocument,
  point : @core.Point,
  content : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> Int? {
  if !rich_text_document_has_source_ranges(document) {
    return None
  }
  let mut y = content.origin.y
  for block in document.blocks {
    let line_height = rich_text_block_line_height(block, base_font)
    let block_height = line_height + block.inset.top + block.inset.bottom
    let frame = @core.Rect::new(
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
  point : @core.Point,
  frame : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
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
fn rich_text_block_source_offset_at_point(
  block : RichTextBlock,
  point : @core.Point,
  frame : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> Int {
  let visual = rich_text_block_visual_offset_at_point(
    block, point, frame, base_font, text_system,
  )
  rich_text_block_source_offset_from_visual(block, visual)
}

///|
fn rich_text_block_visual_offset_at_point(
  block : RichTextBlock,
  point : @core.Point,
  frame : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
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
fn rich_text_run_visual_offset_at_x(
  text : String,
  font : @core.FontSpec,
  x : Double,
  origin_x : Double,
  text_system : @core.TextSystem,
  width? : Double? = None,
) -> Int {
  let chars = text.to_array()
  let boundaries = @core.TextGraphemeBoundaries::new(text~)
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
fn rich_text_block_caret_rect(
  block : RichTextBlock,
  visual_offset : Int,
  frame : @core.Rect,
  base_font : @core.FontSpec,
  text_system : @core.TextSystem,
) -> @core.Rect {
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
        @core.Rect::new(
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
          @core.Rect::new(
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
            @core.Rect::new(
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
    @core.Rect::new(
      x=frame.origin.x,
      y~,
      width=frame.size.width,
      height=line_step,
    ),
    font,
  )
}

///|
fn rich_text_run_segment_prefix_width(
  run : RichTextRun,
  text : String,
  visual_offset : Int,
  font : @core.FontSpec,
  text_system : @core.TextSystem,
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
fn rich_text_prefix(text : String, length : Int) -> String {
  let chars = text.to_array()
  let end = @core.TextGraphemeBoundaries::new(text~).nearest_boundary(length)
  String::from_array(chars[0:end])
}

///|
fn rich_text_cursor_rect_at(
  x : Double,
  frame : @core.Rect,
  font : @core.FontSpec,
) -> @core.Rect {
  @core.Rect::new(
    x~,
    y=frame.origin.y + 4.0,
    width=1.5,
    height=max_double(10.0, font.size * 1.55 - 8.0),
  )
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
fn rich_text_document_has_source_ranges(document : RichTextDocument) -> Bool {
  document.blocks.any(block => {
    block.source_range is Some(_) ||
    block.content_range is Some(_) ||
    block.runs.any(run => run.source_range is Some(_)) ||
    rich_text_block_table_has_source_ranges(block)
  })
}

///|
fn rich_text_block_table_has_source_ranges(block : RichTextBlock) -> Bool {
  match block.table {
    Some(table) =>
      table.rows.any(row => row.any(cell => cell.source_range is Some(_)))
    None => false
  }
}

///|
fn rich_text_table_column_count(table : RichTextTable) -> Int {
  let mut count = 0
  for row in table.rows {
    count = max_int(count, row.length())
  }
  count
}

///|
fn rich_text_block_cache_key(
  index : Int,
  block : RichTextBlock,
  frame : @core.Rect,
) -> String {
  "rich-text-block;range=\{rich_text_source_range_key(block.source_range)};index=\{index};w=\{frame.size.width};h=\{frame.size.height}"
}

///|
fn rich_text_block_content_revision(
  block : RichTextBlock,
  index : Int,
  frame : @core.Rect,
  base_font : @core.FontSpec,
  foreground : @core.Color,
) -> Int {
  let mut hash = rich_text_hash_mix_int(5381, index)
  hash = rich_text_hash_mix_string(
    hash,
    rich_text_source_range_key(block.source_range),
  )
  hash = rich_text_hash_mix_string(
    hash,
    rich_text_source_range_key(block.content_range),
  )
  hash = rich_text_hash_mix_string(hash, block.prefix)
  hash = rich_text_hash_mix_string(
    hash,
    rich_text_font_key(block.font.unwrap_or(base_font)),
  )
  hash = rich_text_hash_mix_string(
    hash,
    rich_text_color_key(block.color.unwrap_or(foreground)),
  )
  hash = rich_text_hash_mix_string(
    hash,
    rich_text_brush_optional_key(block.background),
  )
  hash = rich_text_hash_mix_string(
    hash,
    rich_text_border_optional_key(block.border_left),
  )
  hash = rich_text_hash_mix_string(hash, rich_text_insets_key(block.inset))
  hash = rich_text_hash_mix_string(
    hash,
    rich_text_double_optional_key(block.line_height),
  )
  hash = rich_text_hash_mix_string(hash, "\{block.corner_radius}")
  hash = rich_text_hash_mix_int(hash, if block.rule { 1 } else { 0 })
  hash = rich_text_hash_mix_string(
    hash,
    "\{frame.size.width}x\{frame.size.height}",
  )
  for run in block.runs {
    hash = rich_text_hash_mix_string(hash, run.text)
    hash = rich_text_hash_mix_string(
      hash,
      rich_text_optional_string_key(run.visual_text),
    )
    hash = rich_text_hash_mix_string(
      hash,
      rich_text_optional_string_key(run.image_source),
    )
    hash = rich_text_hash_mix_string(
      hash,
      rich_text_size_optional_key(run.image_size),
    )
    hash = rich_text_hash_mix_string(
      hash,
      rich_text_image_fit_key(run.image_fit),
    )
    hash = rich_text_hash_mix_string(
      hash,
      rich_text_font_optional_key(run.font),
    )
    hash = rich_text_hash_mix_string(
      hash,
      rich_text_color_optional_key(run.color),
    )
    hash = rich_text_hash_mix_string(
      hash,
      rich_text_brush_optional_key(run.background),
    )
    hash = rich_text_hash_mix_string(hash, "\{run.background_radius}")
    hash = rich_text_hash_mix_string(
      hash,
      rich_text_decoration_key(run.decoration),
    )
    hash = rich_text_hash_mix_string(
      hash,
      rich_text_source_range_key(run.source_range),
    )
  }
  match block.table {
    Some(table) => {
      hash = rich_text_hash_mix_string(hash, "\{table.row_height}")
      hash = rich_text_hash_mix_string(
        hash,
        rich_text_insets_key(table.cell_padding),
      )
      hash = rich_text_hash_mix_string(hash, rich_text_color_key(table.border))
      hash = rich_text_hash_mix_string(
        hash,
        rich_text_brush_optional_key(table.header_background),
      )
      for row in table.rows {
        for cell in row {
          hash = rich_text_hash_mix_string(hash, cell.text)
          hash = rich_text_hash_mix_int(hash, if cell.header { 1 } else { 0 })
          hash = rich_text_hash_mix_string(
            hash,
            rich_text_align_optional_key(cell.align),
          )
          hash = rich_text_hash_mix_string(
            hash,
            rich_text_source_range_key(cell.source_range),
          )
        }
      }
    }
    None => ()
  }
  if hash < 0 {
    -hash
  } else {
    hash
  }
}

///|
fn rich_text_source_range_key(range : RichTextSourceRange?) -> String {
  match range {
    Some(range) => "len=\{max_int(0, range.end - range.start)}"
    None => "none"
  }
}

///|
fn rich_text_optional_string_key(value : String?) -> String {
  value.unwrap_or("none")
}

///|
fn rich_text_size_optional_key(value : @core.Size?) -> String {
  match value {
    Some(size) => "\{size.width}x\{size.height}"
    None => "none"
  }
}

///|
fn rich_text_double_optional_key(value : Double?) -> String {
  match value {
    Some(value) => "\{value}"
    None => "none"
  }
}

///|
fn rich_text_font_optional_key(value : @core.FontSpec?) -> String {
  match value {
    Some(font) => rich_text_font_key(font)
    None => "none"
  }
}

///|
fn rich_text_font_key(font : @core.FontSpec) -> String {
  "\{font.css_family()}|\{font.size}|\{font.weight}|\{font.css_style()}"
}

///|
fn rich_text_color_optional_key(value : @core.Color?) -> String {
  match value {
    Some(color) => rich_text_color_key(color)
    None => "none"
  }
}

///|
fn rich_text_color_key(color : @core.Color) -> String {
  "\{color.r},\{color.g},\{color.b},\{color.a}"
}

///|
fn rich_text_brush_optional_key(value : @core.Brush?) -> String {
  match value {
    Some(brush) => rich_text_brush_key(brush)
    None => "none"
  }
}

///|
fn rich_text_brush_key(brush : @core.Brush) -> String {
  match brush {
    @core.Brush::Solid(color) => "solid:\{rich_text_color_key(color)}"
    @core.Brush::LinearGradient(spec) =>
      "linear:\{spec.start.x},\{spec.start.y},\{spec.end.x},\{spec.end.y},\{rich_text_color_key(spec.start_color)},\{rich_text_color_key(spec.end_color)}"
    @core.Brush::RadialGradient(spec) =>
      "radial:\{spec.center.x},\{spec.center.y},\{spec.radius},\{rich_text_color_key(spec.center_color)},\{rich_text_color_key(spec.edge_color)}"
  }
}

///|
fn rich_text_border_optional_key(value : @core.BorderStyle?) -> String {
  match value {
    Some(border) => "\{rich_text_brush_key(border.brush)}|\{border.width}"
    None => "none"
  }
}

///|
fn rich_text_insets_key(insets : @core.Insets) -> String {
  "\{insets.top},\{insets.right},\{insets.bottom},\{insets.left}"
}

///|
fn rich_text_image_fit_key(fit : @core.ImageFit) -> String {
  match fit {
    @core.ImageFit::Contain => "contain"
    @core.ImageFit::Cover => "cover"
    @core.ImageFit::Stretch => "stretch"
    @core.ImageFit::ScaleDown => "scale-down"
    @core.ImageFit::FitWidth => "fit-width"
    @core.ImageFit::FitHeight => "fit-height"
  }
}

///|
fn rich_text_decoration_key(value : RichTextDecoration?) -> String {
  match value {
    Some(RichTextDecoration::Strikethrough) => "strikethrough"
    None => "none"
  }
}

///|
fn rich_text_align_optional_key(value : @core.TextAlign?) -> String {
  match value {
    Some(@core.TextAlign::TextStart) => "start"
    Some(@core.TextAlign::TextCenter) => "center"
    Some(@core.TextAlign::TextEnd) => "end"
    None => "none"
  }
}

///|
fn rich_text_string_hash(value : String) -> Int {
  let mut hash = 5381
  for ch in value.to_array() {
    hash = hash * 33 + ch.to_int()
  }
  hash
}

///|
fn rich_text_hash_mix_int(hash : Int, value : Int) -> Int {
  hash * 33 + value
}

///|
fn rich_text_hash_mix_string(hash : Int, value : String) -> Int {
  hash * 33 + rich_text_string_hash(value)
}

///|
fn rich_text_block_table_source_offset_at_point(
  block : RichTextBlock,
  point : @core.Point,
  frame : @core.Rect,
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
fn rich_text_run_visual_offset_from_source_offset(
  source_offset : Int,
  source_text : String,
  visual_text : String,
) -> Int {
  let source_boundaries = @core.TextGraphemeBoundaries::new(text=source_text)
  let visual_boundaries = @core.TextGraphemeBoundaries::new(text=visual_text)
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
  let visual_boundaries = @core.TextGraphemeBoundaries::new(text=visual_text)
  let source_boundaries = @core.TextGraphemeBoundaries::new(text=source_text)
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
fn[Msg] selection_messages(
  on_selection_change : ((Int, @core.TextRange?) -> Msg)?,
  caret : Int,
  selection : @core.TextRange?,
) -> Array[Msg] {
  match on_selection_change {
    Some(handler) => [handler(caret, selection)]
    None => []
  }
}
