///|
fn markdown_session_clamped_scroll_y(
  session : MarkdownDocumentSession,
  font : @core.FontSpec,
  source_mode~ : Bool,
  scroll_y : Double,
  viewport_height : Double,
  content_width? : Double = 0.0,
) -> Double {
  if viewport_height <= 0.0 {
    return max_double(0.0, scroll_y)
  }
  let content_height = session.estimated_content_height(
      base=font,
      source_mode~,
      content_width~,
    ) +
    96.0
  let max_scroll = max_double(0.0, content_height - viewport_height)
  clamp_double(scroll_y, 0.0, max_scroll)
}

///|
fn markdown_session_display_session(
  session : MarkdownDocumentSession,
  display_text : String,
) -> MarkdownDocumentSession {
  if display_text == session.source {
    session
  } else {
    // Composition is live: paints and host IME polls re-derive this
    // session with the same display text until the candidate changes,
    // so memoize the full parse instead of re-parsing every poll.
    markdown_document_session_parse_cached(display_text)
  }
}

///|
fn markdown_session_visible_window(
  session : MarkdownDocumentSession,
  selection : MarkdownEditorSelection,
  font : @core.FontSpec,
  source_mode~ : Bool,
  focus_mode~ : Bool,
  base_dir~ : String?,
  visible_scroll_y~ : Double,
  visible_viewport_height~ : Double,
  visible_overscan~ : Double,
  content_width? : Double = 0.0,
  text_system? : @core.TextSystem = @core.TextSystem::fallback(),
) -> MarkdownDocumentRichTextWindow {
  let scroll_y = markdown_session_clamped_scroll_y(
    session,
    font,
    source_mode~,
    visible_scroll_y,
    visible_viewport_height,
    content_width~,
  )
  let window = session.rich_text_window(
    selection,
    base=font,
    source_mode~,
    focus_mode~,
    base_dir~,
    scroll_y~,
    viewport_height=visible_viewport_height,
    overscan=visible_overscan,
    content_width~,
  )
  // Paint, caret, hit-test, selection, and the measured-height feed all
  // consume this one soft-wrapped document, so a click lands the caret
  // exactly where the text was drawn (ADR 0001).
  if source_mode || content_width <= 0.0 {
    window
  } else {
    {
      ..window,
      document: rich_text_document_soft_wrap(
        window.document,
        content_width,
        font,
        text_system,
      ),
    }
  }
}

///|
fn markdown_session_input_transform(
  source : String,
  caret : Int,
  range : @core.TextRange?,
  inserted : String,
) -> RichTextInputTransform? {
  markdown_editor_transform_input(source, caret, range, inserted)
}

///|
fn[Msg] markdown_session_on_input_edit(
  session : MarkdownDocumentSession,
  on_transaction : (MarkdownEditTransaction) -> Msg,
) -> (String, Int, @core.TextRange?) -> Msg {
  (next_source, caret, next_selection) => {
    on_transaction(
      MarkdownEditTransaction::from_sources(
        session.source,
        next_source,
        caret~,
        selection=next_selection,
        reason=TextInput,
      ),
    )
  }
}

///|
fn markdown_session_editor_paint(
  ctx : @core.ViewPaintContext,
  session~ : MarkdownDocumentSession,
  selection~ : MarkdownEditorSelection,
  placeholder~ : String,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  placeholder_color~ : @core.Color,
  background~ : @core.Brush,
  border~ : @core.BorderStyle?,
  focused_border~ : @core.BorderStyle?,
  cursor_color~ : @core.Color,
  corner_radius~ : Double,
  source_mode~ : Bool,
  focus_mode~ : Bool,
  base_dir~ : String?,
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
  let text = session.source
  let display_text = rich_text_with_composition(
    text,
    ctx.text_control,
    focused=ctx.focused,
  )
  let display_session = markdown_session_display_session(session, display_text)
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
    let window = markdown_session_visible_window(
      display_session,
      selection,
      font,
      source_mode~,
      focus_mode~,
      base_dir~,
      visible_scroll_y~,
      visible_viewport_height~,
      visible_overscan~,
      content_width=content.size.width,
      text_system=ctx.text_system,
    )
    let window_content = window.content_rect(content)
    if display_text == session.source &&
      !source_mode &&
      content.size.width > 0.0 {
      markdown_session_record_measured_block_heights(
        session,
        window,
        content_width=content.size.width,
        base=font,
        base_dir~,
        text_system=ctx.text_system,
      )
    }
    // Position blocks inside the offset `window_content`, but cull against
    // the original `content` viewport. Without this, the non-windowed cull
    // uses `window_content.origin.y + height` which is shifted up by
    // `top_padding - scroll_y`, cutting off the bottom of the viewport.
    append_rich_text_document_layers(
      child_layers,
      window.document,
      window_content,
      font,
      foreground,
      text_system=ctx.text_system,
      clip_rect=Some(content),
    )
    if ctx.focused {
      append_rich_text_editor_overlay(
        overlay_commands,
        text~,
        display_text~,
        document=window.document,
        content=window_content,
        font~,
        cursor_color~,
        control=ctx.text_control,
        text_system=ctx.text_system,
        clip_rect=Some(content),
      )
    }
  }
  // PopClip must go in post_commands (not commands) so that child_layers —
  // which are rendered between commands and post_commands — stay inside the
  // content clip. Without this, overscan blocks bleed past the editor frame
  // and overlap the chrome/status bar during scrolling.
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
fn[Msg] markdown_session_editor_event(
  ctx : @core.ViewEventContext,
  session~ : MarkdownDocumentSession,
  selection~ : MarkdownEditorSelection,
  on_transaction~ : (MarkdownEditTransaction) -> Msg,
  font~ : @core.FontSpec,
  source_mode~ : Bool,
  focus_mode~ : Bool,
  base_dir~ : String?,
  on_selection_change~ : ((Int, @core.TextRange?) -> Msg)?,
  on_prefix_click~ : ((Int) -> Msg)?,
  on_command_click~ : ((Int) -> Msg)?,
  accepts_tab_input~ : Bool,
  visible_scroll_y~ : Double,
  on_scroll~ : ((Double) -> Msg)?,
  visible_viewport_height~ : Double,
  visible_overscan~ : Double,
) -> @core.ViewEventResult[Msg] {
  let value = session.source
  let on_input_edit = markdown_session_on_input_edit(session, on_transaction)
  match ctx.event {
    @core.AppEvent::Pointer(event) =>
      markdown_session_pointer_event(
        ctx,
        session~,
        selection~,
        font~,
        source_mode~,
        focus_mode~,
        base_dir~,
        on_selection_change~,
        on_prefix_click~,
        on_command_click~,
        event~,
        visible_scroll_y~,
        on_scroll~,
        visible_viewport_height~,
        visible_overscan~,
      )
    @core.AppEvent::Keyboard(event) => {
      // ArrowUp/ArrowDown 需要用 visible_window 的 document 来正确计算
      // 视觉位置（考虑 scroll offset），所以在这里预处理，而不是走
      // rich_text_keyboard_event 的通用 format(text) 路径。
      if event.pressed && (event.key == "ArrowUp" || event.key == "ArrowDown") {
        let text = session.source
        let window = markdown_session_visible_window(
          session,
          selection,
          font,
          source_mode~,
          focus_mode~,
          base_dir~,
          visible_scroll_y~,
          visible_viewport_height~,
          visible_overscan~,
          content_width=rich_text_editor_content_rect(ctx.frame).size.width,
          text_system=ctx.text_system,
        )
        let content = window.content_rect(
          rich_text_editor_content_rect(ctx.frame),
        )
        return rich_text_vertical_caret_move_result(
          ctx,
          text,
          window.document,
          content,
          font,
          up=event.key == "ArrowUp",
          extend_selection=event.modifiers.shift,
          on_selection_change,
        )
      }
      rich_text_keyboard_event(
        ctx,
        value~,
        format=_source => {
          session.rich_text(
            selection,
            base=font,
            source_mode~,
            focus_mode~,
            base_dir~,
          )
        },
        font~,
        on_input=None,
        on_input_edit=Some(on_input_edit),
        on_selection_change~,
        input_transform=Some(markdown_session_input_transform),
        accepts_tab_input~,
        event~,
      )
    }
    @core.AppEvent::TextInput(event) =>
      rich_text_input_event(
        ctx,
        value~,
        on_input=None,
        on_input_edit=Some(on_input_edit),
        on_selection_change~,
        input_transform=Some(markdown_session_input_transform),
        event~,
        record_history=true,
      )
    _ => @core.ViewEventResult::ignored()
  }
}

///|
fn[Msg] markdown_session_pointer_event(
  ctx : @core.ViewEventContext,
  session~ : MarkdownDocumentSession,
  selection~ : MarkdownEditorSelection,
  font~ : @core.FontSpec,
  source_mode~ : Bool,
  focus_mode~ : Bool,
  base_dir~ : String?,
  on_selection_change~ : ((Int, @core.TextRange?) -> Msg)?,
  on_prefix_click~ : ((Int) -> Msg)?,
  on_command_click~ : ((Int) -> Msg)?,
  event~ : @core.PointerEvent,
  visible_scroll_y~ : Double,
  on_scroll~ : ((Double) -> Msg)?,
  visible_viewport_height~ : Double,
  visible_overscan~ : Double,
) -> @core.ViewEventResult[Msg] {
  let inside = ctx.frame.contains(event.position)
  let content_width = rich_text_editor_content_rect(ctx.frame).size.width
  if inside && (event.wheel_delta.x != 0.0 || event.wheel_delta.y != 0.0) {
    return markdown_session_scroll_event(
      session,
      font,
      source_mode~,
      event~,
      visible_scroll_y~,
      on_scroll~,
      visible_viewport_height~,
      content_width~,
    )
  }
  match event.phase {
    @core.PointerPhase::Down =>
      if inside {
        let text = session.source
        let window = markdown_session_visible_window(
          session,
          selection,
          font,
          source_mode~,
          focus_mode~,
          base_dir~,
          visible_scroll_y~,
          visible_viewport_height~,
          visible_overscan~,
          content_width~,
          text_system=ctx.text_system,
        )
        let content = window.content_rect(
          rich_text_editor_content_rect(ctx.frame),
        )
        let command_modifiers = event.modifiers.meta || event.modifiers.control
        match (command_modifiers, on_command_click) {
          (true, Some(handler)) => {
            let offset = rich_text_document_source_offset_at_point(
              window.document,
              event.position,
              content,
              font,
              ctx.text_system,
            ).unwrap_or(text_length(text))
            view_event_result(
              changed=true,
              focused=true,
              captured=true,
              text_control=Some(ctx.text_control),
              dirty=@core.ViewDirtyHint::ViewPaintDirty,
              messages=[handler(offset)],
            )
          }
          _ => {
            let prefix_messages = match on_prefix_click {
              Some(handler) =>
                match
                  rich_text_document_prefix_source_offset_at_point(
                    window.document,
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
              window.document,
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
          }
        }
      } else {
        @core.ViewEventResult::ignored()
      }
    @core.PointerPhase::Move =>
      match ctx.text_control.text_selection_anchor {
        Some(anchor) => {
          let text = session.source
          let window = markdown_session_visible_window(
            session,
            selection,
            font,
            source_mode~,
            focus_mode~,
            base_dir~,
            visible_scroll_y~,
            visible_viewport_height~,
            visible_overscan~,
            content_width~,
          )
          let content = window.content_rect(
            rich_text_editor_content_rect(ctx.frame),
          )
          let caret = rich_text_document_source_offset_at_point(
            window.document,
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
          if changed {
            view_event_result(
              changed=true,
              focused=true,
              captured=true,
              text_control=Some({
                ..ctx.text_control,
                caret,
                selection: next_selection,
                composition: None,
                composition_cursor: None,
              }),
              dirty=@core.ViewDirtyHint::ViewPaintDirty,
              messages=selection_messages(
                on_selection_change, caret, next_selection,
              ),
            )
          } else {
            view_event_result(
              focused=true,
              captured=true,
              text_control=Some(ctx.text_control),
            )
          }
        }
        None => @core.ViewEventResult::ignored()
      }
    @core.PointerPhase::Up =>
      if ctx.text_control.text_selection_anchor is Some(_) {
        view_event_result(
          changed=true,
          focused=true,
          captured=true,
          text_control=Some({ ..ctx.text_control, text_selection_anchor: None }),
          dirty=@core.ViewDirtyHint::ViewPaintDirty,
        )
      } else {
        @core.ViewEventResult::ignored()
      }
    _ => @core.ViewEventResult::ignored()
  }
}

///|
fn[Msg] markdown_session_scroll_event(
  session : MarkdownDocumentSession,
  font : @core.FontSpec,
  source_mode~ : Bool,
  event~ : @core.PointerEvent,
  visible_scroll_y~ : Double,
  on_scroll~ : ((Double) -> Msg)?,
  visible_viewport_height~ : Double,
  content_width? : Double = 0.0,
) -> @core.ViewEventResult[Msg] {
  match on_scroll {
    Some(handler) => {
      let viewport_height = if visible_viewport_height > 0.0 {
        visible_viewport_height
      } else {
        0.0
      }
      let content_height = session.estimated_content_height(
          base=font,
          source_mode~,
          content_width~,
        ) +
        96.0
      let max_scroll = max_double(0.0, content_height - viewport_height)
      let next_y = min_double(
        max_double(0.0, visible_scroll_y - event.wheel_delta.y),
        max_scroll,
      )
      view_event_result(
        changed=next_y != visible_scroll_y,
        activated=next_y != visible_scroll_y,
        captured=true,
        dirty=@core.ViewDirtyHint::ViewPaintDirty,
        messages=if next_y != visible_scroll_y { [handler(next_y)] } else { [] },
      )
    }
    None => @core.ViewEventResult::ignored()
  }
}

///|
/// Feed the scroll geometry with the pixel heights actually laid out for
/// the visible block window. Heights are computed from the pre-reveal
/// rich blocks (cache-hot at this point) so temporary marker reveals do
/// not leak into the content-keyed measurements.
fn markdown_session_record_measured_block_heights(
  session : MarkdownDocumentSession,
  window : MarkdownDocumentRichTextWindow,
  content_width~ : Double,
  base~ : @core.FontSpec,
  base_dir~ : String?,
  text_system~ : @core.TextSystem,
) -> Unit {
  if window.visible_start < 0 {
    return
  }
  for offset, _window_block in window.document.blocks {
    match session.editor_blocks.get(window.visible_start + offset) {
      Some(editor_block) => {
        let height = rich_text_block_total_height(
          rich_text_block_soft_wrap(
            markdown_editor_block_to_rich_text(
              session.source,
              editor_block,
              base,
              base_dir~,
            ),
            content_width,
            base,
            text_system,
          ),
          base,
          text_system,
          block_width=content_width,
        )
        let identity = session.blocks.get(window.visible_start + offset)
        let _ = rich_text_record_block_measured_height(
          base,
          width=content_width,
          block_id=match identity {
            Some(session_block) => session_block.id
            None => window.visible_start + offset
          },
          block_revision=match identity {
            Some(session_block) => session_block.revision
            None => 0
          },
          height~,
        )
        // Push the height into this block's geometry slot unconditionally:
        // the measured-height table deduplicates by content, but the
        // scroll geometry keeps one height slot per block position.
        markdown_document_apply_measured_height(
          session,
          base,
          block_index=window.visible_start + offset,
          width=content_width,
          height~,
        )
      }
      None => ()
    }
  }
}

///|
fn markdown_session_estimated_caret_inset_x(
  session : MarkdownDocumentSession,
  source_caret : Int,
  font~ : @core.FontSpec,
  base_dir~ : String?,
  content_width~ : Double,
  text_system~ : @core.TextSystem,
) -> Double {
  for editor_block in session.editor_blocks {
    if source_caret < editor_block.source_range.start ||
      source_caret > editor_block.source_range.end {
      continue
    }
    let rich_block = markdown_editor_block_to_rich_text(
      session.source,
      editor_block,
      font,
      base_dir~,
    )
    let block_font = rich_block.font.unwrap_or(font)
    let scan_end = markdown_editor_min_int(
      source_caret,
      editor_block.source_range.end,
    )
    let before_caret = markdown_editor_substring(
      session.source,
      editor_block.source_range.start,
      scan_end,
    )
    let mut line_start = 0
    for index, ch in before_caret {
      if ch == '\n' {
        line_start = index + 1
      }
    }
    let line_text = markdown_editor_substring(
      before_caret,
      line_start,
      markdown_editor_text_length(before_caret),
    )
    // The caret rect fallback maps canonical source text; hidden inline
    // markers make this an over-estimate, so clamp to the content width.
    let line_width = min_double(
      rich_text_width(line_text, block_font, text_system),
      max_double(0.0, content_width - rich_block.inset.left),
    )
    return rich_block.inset.left +
      rich_text_width(rich_block.prefix, block_font, text_system) +
      line_width
  }
  0.0
}

///|
fn markdown_session_input_state(
  text~ : String,
  frame~ : @core.Rect,
  session~ : MarkdownDocumentSession,
  selection~ : MarkdownEditorSelection,
  font~ : @core.FontSpec,
  control~ : @core.TextControlStateContext,
  source_mode~ : Bool,
  focus_mode~ : Bool,
  base_dir~ : String?,
  visible_scroll_y~ : Double,
  visible_viewport_height~ : Double,
  visible_overscan~ : Double,
  text_system~ : @core.TextSystem,
) -> @core.TextInputState {
  let control = {
    ..control,
    caret: selection.caret,
    selection: selection.selection,
  }
  let caret = @core.clamp_int(control.caret, 0, session.source_length)
  if frame.size.width <= 0.0 || frame.size.height <= 0.0 {
    return {
      focused: true,
      text,
      caret,
      selection: control.selection,
      composition: control.composition,
      composition_cursor: control.composition_cursor,
      frame,
      caret_rect: @core.Rect::new(
        x=frame.origin.x,
        y=frame.origin.y,
        width=1.0,
        height=font.size,
      ),
    }
  }
  let display_text = rich_text_with_composition(text, control, focused=true)
  let display_session = markdown_session_display_session(session, display_text)
  let visual_caret = match control.composition {
    Some(_) =>
      @core.clamp_int(
        rich_text_visual_caret(text, control, focused=true),
        0,
        text_length(display_text),
      )
    None => caret
  }
  let window = markdown_session_visible_window(
    display_session,
    { caret: visual_caret, selection: control.selection },
    font,
    source_mode~,
    focus_mode~,
    base_dir~,
    visible_scroll_y~,
    visible_viewport_height~,
    visible_overscan~,
    content_width=rich_text_editor_content_rect(frame).size.width,
    text_system~,
  )
  let base_content = rich_text_editor_content_rect(frame)
  let content = window.content_rect(base_content)
  let caret_rect = match
    rich_text_document_caret_rect_at_source(
      window.document,
      visual_caret,
      content,
      font,
      text_system~,
    ) {
    Some(rect) => rect
    None =>
      markdown_session_estimated_caret_rect(
        display_session,
        visual_caret,
        base_content,
        font,
        source_mode~,
        scroll_y=window.scroll_y,
        base_dir~,
        text_system~,
      )
  }
  {
    focused: true,
    text,
    caret,
    selection: control.selection,
    composition: control.composition,
    composition_cursor: control.composition_cursor,
    frame,
    caret_rect,
  }
}

///|
fn markdown_session_estimated_caret_rect(
  session : MarkdownDocumentSession,
  source_caret : Int,
  content : @core.Rect,
  font : @core.FontSpec,
  source_mode~ : Bool,
  scroll_y~ : Double,
  base_dir~ : String?,
  text_system~ : @core.TextSystem,
) -> @core.Rect {
  let source_y = session.source_offset_y(source_caret, base=font, source_mode~)
  let inset_x = markdown_session_estimated_caret_inset_x(
    session,
    source_caret,
    font~,
    base_dir~,
    content_width=content.size.width,
    text_system~,
  )
  @core.Rect::new(
    x=content.origin.x + inset_x,
    y=content.origin.y + source_y - scroll_y + 4.0,
    width=1.5,
    height=max_double(10.0, font.size * 1.55 - 8.0),
  )
}

///|
fn[Msg] markdown_session_editor_command(
  ctx : @core.ViewEventContext,
  session~ : MarkdownDocumentSession,
  selection~ : MarkdownEditorSelection,
  on_transaction~ : (MarkdownEditTransaction) -> Msg,
  on_selection_change~ : ((Int, @core.TextRange?) -> Msg)?,
  font~ : @core.FontSpec,
  source_mode~ : Bool,
  focus_mode~ : Bool,
  base_dir~ : String?,
  intent : @core.CommandIntent,
  paste_text~ : String?,
) -> @core.ViewTextCommandResult[Msg] {
  let value = session.source
  let on_input_edit = markdown_session_on_input_edit(session, on_transaction)
  let format_selection = match intent {
    @core.CommandIntent::Copy | @core.CommandIntent::Cut =>
      ({ caret: -1, selection: None } : MarkdownEditorSelection)
    _ => selection
  }
  let format = display_source => {
    if display_source == session.source {
      session.rich_text(
        format_selection,
        base=font,
        source_mode~,
        focus_mode~,
        base_dir~,
      )
    } else if source_mode {
      markdown_editor_format_source_mode(display_source, font)
    } else {
      markdown_editor_format_for_writing_mode(
        display_source,
        format_selection,
        base=font,
        focus_mode~,
        base_dir~,
      )
    }
  }
  rich_text_editor_command(
    ctx,
    value~,
    format~,
    on_input=None,
    on_input_edit=Some(on_input_edit),
    on_selection_change~,
    input_transform=Some(markdown_session_input_transform),
    intent,
    paste_text~,
  )
}
