///|
fn[Msg] text_area_control(
  value~ : String,
  placeholder~ : String,
  size~ : @core.Size,
  theme? : @core.Theme,
  variant? : @style.TextFieldVariant = @style.TextFieldVariant::Outline,
  style? : @style.TextFieldStyle,
  on_input? : ((String) -> Msg)? = None,
  on_submit? : Msg? = None,
  lines? : Int = 4,
  line_height? : Double = 28.0,
  key? : String? = None,
) -> @core.View[Msg] {
  let value_snapshot = value
  @core.View::from_node(
    TextArea::{
      value: value_snapshot,
      placeholder,
      size,
      theme,
      variant,
      style,
      lines,
      line_height,
      has_on_submit: on_submit is Some(_),
      key,
    },
    event=(node, ctx) => text_area_event(node, ctx, value, on_input, on_submit),
    text_command=(_node, ctx, intent, paste_text) => {
      handle_text_field_command(ctx, value~, on_input~, intent, paste_text~)
    },
    semantics_actions=_node => {
      let handlers : Array[@core.ViewSemanticsActionHandler[Msg]] = [
        @core.ViewSemanticsActionHandler::set_text((ctx, next) => {
          text_semantics_set_text(ctx, value, on_input, next)
        }),
        @core.ViewSemanticsActionHandler::set_selection((ctx, selection) => {
          let selection = @core.normalize_grapheme_range(
            @core.TextGraphemeBoundaries::new(text=value),
            selection,
          )
          @core.ViewSemanticsActionResult::accepted(
            text_control=Some({
              ..ctx.text_control,
              caret: selection.end,
              selection: if selection.is_collapsed() {
                None
              } else {
                Some(selection)
              },
              text_selection_anchor: if selection.is_collapsed() {
                None
              } else {
                Some(selection.start)
              },
            }),
            dirty=@core.ViewDirtyHint::ViewPaintDirty,
          )
        }),
      ]
      match on_submit {
        Some(message) =>
          handlers.push(
            @core.ViewSemanticsActionHandler::submit(_ctx => {
              @core.ViewSemanticsActionResult::message(message)
            }),
          )
        None => ()
      }
      handlers
    },
  )
}

///|
fn[Msg] text_area_event(
  node : TextArea,
  ctx : @core.ViewEventContext,
  value : String,
  on_input : ((String) -> Msg)?,
  on_submit : Msg?,
) -> @core.ViewEventResult[Msg] {
  let resolved_theme = node.theme.unwrap_or(ctx.environment.theme)
  let resolved_style = match node.style {
    Some(value) => value
    None => node.variant.style(resolved_theme)
  }
  handle_text_area_event(
    ctx,
    value~,
    on_input~,
    on_submit~,
    font=resolved_style.font,
    line_height=node.line_height,
  )
}

///|
fn[Msg] handle_text_area_event(
  ctx : @core.ViewEventContext,
  value~ : String,
  on_input~ : ((String) -> Msg)?,
  on_submit~ : Msg?,
  font~ : @core.FontSpec,
  line_height~ : Double,
) -> @core.ViewEventResult[Msg] {
  let result = match ctx.event {
    @core.AppEvent::Pointer(event) =>
      handle_text_area_pointer(ctx, value~, font~, line_height~, event)
    @core.AppEvent::Keyboard(event) =>
      handle_text_area_keyboard(
        ctx,
        value~,
        on_input~,
        on_submit~,
        font~,
        line_height~,
        event,
      )
    @core.AppEvent::TextInput(event) =>
      view_text_input_result(ctx, value~, on_input~, event, record_history=true)
    _ => @core.ViewEventResult::ignored()
  }
  text_area_reveal_caret(ctx, value~, font~, line_height~, result)
}

///|
/// Caret-following postprocessor: whenever an event moved the caret or
/// selection, adjust the self-owned scroll offset just enough to bring
/// the caret's line slot into the viewport, merging the new offset into
/// the event's state channel. Paint reads the slot directly, so a
/// layout-dirty hint is enough to repaint the shifted window.
fn[Msg] text_area_reveal_caret(
  ctx : @core.ViewEventContext,
  value~ : String,
  font~ : @core.FontSpec,
  line_height~ : Double,
  result : @core.ViewEventResult[Msg],
) -> @core.ViewEventResult[Msg] {
  let control = match result.text_control {
    None => return result
    Some(control) => control
  }
  if control.caret == ctx.text_control.caret &&
    control.selection == ctx.text_control.selection {
    return result
  }
  let text_frame = text_area_text_frame(ctx.frame)
  let display_text = text_with_composition(value, control, focused=true)
  let paragraph = text_area_paragraph(
    ctx.text_system,
    display_text,
    font,
    text_frame,
  )
  let line_count = paragraph.lines.length()
  let offset = text_area_clamped_scroll_offset(
    text_area_scroll_offset(ctx.state),
    line_count~,
    line_height~,
    viewport_height=text_frame.size.height,
  )
  let caret_line = text_area_line_index_for_paragraph_offset(
    paragraph,
    control.caret,
  )
  let next_offset = text_area_offset_for_caret_reveal(
    current=offset,
    caret_line~,
    line_count~,
    line_height~,
    viewport_height=text_frame.size.height,
  )
  if next_offset == offset {
    result
  } else {
    let base_state = match result.state {
      None => ctx.state
      Some(state) => state
    }
    {
      ..result,
      state: Some(
        base_state.with_slot(
          text_area_scroll_slot(),
          { offset_y : next_offset },
        ),
      ),
      dirty: @core.ViewDirtyHint::ViewLayoutDirty,
    }
  }
}

///|
fn[Msg] handle_text_area_keyboard(
  ctx : @core.ViewEventContext,
  value~ : String,
  on_input~ : ((String) -> Msg)?,
  on_submit~ : Msg?,
  font~ : @core.FontSpec,
  line_height~ : Double,
  event : @core.KeyboardEvent,
) -> @core.ViewEventResult[Msg] {
  if !event.pressed {
    return @core.ViewEventResult::ignored()
  }
  if event.key == "Enter" {
    if on_submit is Some(_) && !event.modifiers.shift {
      return @common.view_event_result(
        changed=true,
        activated=on_submit is Some(_),
        captured=true,
        dirty=@core.ViewDirtyHint::ViewPaintDirty,
        messages=option_message(on_submit),
      )
    }
    return view_text_input_result(
      ctx,
      value~,
      on_input~,
      @core.TextInputEvent::InsertText("\n"),
      record_history=true,
    )
  }
  if @core.is_select_all_shortcut(event) {
    let next_control = select_text_control(ctx.text_control, value)
    return @common.view_event_result(
      changed=true,
      captured=true,
      text_control=Some(next_control),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
    )
  }
  if @core.is_undo_shortcut(event) {
    let result = restore_text_history(ctx.text_control, value, undo=true)
    return @common.view_event_result(
      changed=result.changed,
      captured=true,
      text_control=Some(result.control),
      dirty=@core.ViewDirtyHint::ViewBuildDirty,
      messages=text_input_messages(on_input, result.text),
    )
  }
  if @core.is_redo_shortcut(event) {
    let result = restore_text_history(ctx.text_control, value, undo=false)
    return @common.view_event_result(
      changed=result.changed,
      captured=true,
      text_control=Some(result.control),
      dirty=@core.ViewDirtyHint::ViewBuildDirty,
      messages=text_input_messages(on_input, result.text),
    )
  }
  if event.key == "Backspace" {
    match active_text_selection(ctx.text_control.selection) {
      Some(selection) =>
        return view_text_input_result(
          ctx,
          value~,
          on_input~,
          @core.TextInputEvent::DeleteRange(selection),
          record_history=true,
        )
      None =>
        return view_text_input_result(
          ctx,
          value~,
          on_input~,
          @core.TextInputEvent::DeleteSurrounding(1, 0),
          record_history=true,
        )
    }
  }
  if event.key == "Delete" {
    match active_text_selection(ctx.text_control.selection) {
      Some(selection) =>
        return view_text_input_result(
          ctx,
          value~,
          on_input~,
          @core.TextInputEvent::DeleteRange(selection),
          record_history=true,
        )
      None =>
        return view_text_input_result(
          ctx,
          value~,
          on_input~,
          @core.TextInputEvent::DeleteSurrounding(0, 1),
          record_history=true,
        )
    }
  }
  if event.key == "ArrowUp" {
    return text_area_vertical_caret_move(
      ctx,
      value,
      font~,
      line_height~,
      up=true,
      extend_selection=event.modifiers.shift,
    )
  }
  if event.key == "ArrowDown" {
    return text_area_vertical_caret_move(
      ctx,
      value,
      font~,
      line_height~,
      up=false,
      extend_selection=event.modifiers.shift,
    )
  }
  if event.key == "ArrowLeft" {
    return view_caret_move_result(
      ctx,
      value,
      TextCaretDirection::MoveLeft,
      event.modifiers.shift,
    )
  }
  if event.key == "ArrowRight" {
    return view_caret_move_result(
      ctx,
      value,
      TextCaretDirection::MoveRight,
      event.modifiers.shift,
    )
  }
  if event.key == "Home" {
    return view_caret_move_result(
      ctx,
      value,
      TextCaretDirection::MoveStart,
      event.modifiers.shift,
    )
  }
  if event.key == "End" {
    return view_caret_move_result(
      ctx,
      value,
      TextCaretDirection::MoveEnd,
      event.modifiers.shift,
    )
  }
  match event.text {
    Some(text) =>
      if text != "" {
        view_text_input_result(
          ctx,
          value~,
          on_input~,
          @core.TextInputEvent::InsertText(text),
          record_history=true,
        )
      } else {
        @core.ViewEventResult::ignored()
      }
    None => @core.ViewEventResult::ignored()
  }
}

///|
fn[Msg] text_area_vertical_caret_move(
  ctx : @core.ViewEventContext,
  text : String,
  font~ : @core.FontSpec,
  line_height~ : Double,
  up~ : Bool,
  extend_selection~ : Bool,
) -> @core.ViewEventResult[Msg] {
  let text_frame = text_area_text_frame(ctx.frame)
  let display_text = text_with_composition(text, ctx.text_control, focused=true)
  let paragraph = text_area_paragraph(
    ctx.text_system,
    display_text,
    font,
    text_frame,
  )
  let visual_caret = text_field_visual_caret(
    text,
    ctx.text_control,
    focused=true,
  )
  let caret_rect = paragraph.caret_rect_at(visual_caret)
  let target_point = if up {
    @core.Point::new(
      x=caret_rect.origin.x,
      y=caret_rect.origin.y - line_height * 0.5,
    )
  } else {
    @core.Point::new(
      x=caret_rect.origin.x,
      y=caret_rect.origin.y + line_height * 1.5,
    )
  }
  let hit = paragraph.hit_test(target_point)
  if hit.offset == ctx.text_control.caret && !extend_selection {
    return @core.ViewEventResult::ignored()
  }
  let next_control = if extend_selection {
    let anchor = match ctx.text_control.text_selection_anchor {
      Some(a) => a
      None => ctx.text_control.caret
    }
    let start = @core.min_int(anchor, hit.offset)
    let end = @core.max_int(anchor, hit.offset)
    {
      ..ctx.text_control,
      caret: hit.offset,
      selection: Some(@core.TextRange::new(start~, end~)),
      text_selection_anchor: Some(anchor),
      composition: None,
      composition_cursor: None,
    }
  } else {
    {
      ..ctx.text_control,
      caret: hit.offset,
      selection: None,
      text_selection_anchor: None,
      composition: None,
      composition_cursor: None,
    }
  }
  let changed = next_control.caret != ctx.text_control.caret ||
    next_control.selection != ctx.text_control.selection ||
    ctx.text_control.composition is Some(_) ||
    ctx.text_control.composition_cursor is Some(_)
  @common.view_event_result(
    changed~,
    captured=true,
    text_control=Some(next_control),
    dirty=@core.ViewDirtyHint::ViewPaintDirty,
  )
}

///|
fn[Msg] handle_text_area_pointer(
  ctx : @core.ViewEventContext,
  value~ : String,
  font~ : @core.FontSpec,
  line_height~ : Double,
  event : @core.PointerEvent,
) -> @core.ViewEventResult[Msg] {
  let text = value
  let text_frame = text_area_text_frame(ctx.frame)
  let display_text = text_with_composition(
    text,
    ctx.text_control,
    focused=ctx.focused,
  )
  if event.wheel_delta.y != 0.0 && ctx.frame.contains(event.position) {
    let paragraph = text_area_paragraph(
      ctx.text_system,
      display_text,
      font,
      text_frame,
    )
    let line_count = paragraph.lines.length()
    let offset = text_area_clamped_scroll_offset(
      text_area_scroll_offset(ctx.state),
      line_count~,
      line_height~,
      viewport_height=text_frame.size.height,
    )
    let next_offset = text_area_scroll_offset_after_wheel(
      current=offset,
      delta_y=event.wheel_delta.y,
      line_count~,
      line_height~,
      viewport_height=text_frame.size.height,
    )
    if next_offset == offset {
      @core.ViewEventResult::ignored()
    } else {
      @common.view_event_result(
        changed=true,
        captured=true,
        state=Some(
          ctx.state.with_slot(
            text_area_scroll_slot(),
            { offset_y : next_offset },
          ),
        ),
        dirty=@core.ViewDirtyHint::ViewLayoutDirty,
      )
    }
  } else if event.phase == @core.PointerPhase::Down &&
    ctx.frame.contains(event.position) {
    let paragraph = text_area_paragraph(
      ctx.text_system,
      display_text,
      font,
      text_frame,
    )
    let offset = text_area_clamped_scroll_offset(
      text_area_scroll_offset(ctx.state),
      line_count=paragraph.lines.length(),
      line_height~,
      viewport_height=text_frame.size.height,
    )
    let local_point = @core.Point::new(
      x=event.position.x - text_frame.origin.x,
      y=event.position.y - text_frame.origin.y + offset,
    )
    let hit_offset = text_area_hit_offset_at_slot(
      paragraph,
      local_point,
      line_height,
    )
    let next_control = {
      ..ctx.text_control,
      caret: hit_offset,
      selection: None,
      text_selection_anchor: Some(hit_offset),
      composition: None,
      composition_cursor: None,
    }
    @common.view_event_result(
      changed=true,
      focused=true,
      captured=true,
      text_control=Some(next_control),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
    )
  } else if event.phase == @core.PointerPhase::Move &&
    ctx.text_control.text_selection_anchor is Some(anchor) {
    let paragraph = text_area_paragraph(
      ctx.text_system,
      display_text,
      font,
      text_frame,
    )
    let offset = text_area_clamped_scroll_offset(
      text_area_scroll_offset(ctx.state),
      line_count=paragraph.lines.length(),
      line_height~,
      viewport_height=text_frame.size.height,
    )
    let local_point = @core.Point::new(
      x=event.position.x - text_frame.origin.x,
      y=event.position.y - text_frame.origin.y + offset,
    )
    let hit_offset = text_area_hit_offset_at_slot(
      paragraph,
      local_point,
      line_height,
    )
    if hit_offset != anchor || hit_offset != ctx.text_control.caret {
      let start = @core.min_int(anchor, hit_offset)
      let end = @core.max_int(anchor, hit_offset)
      let next_control = {
        ..ctx.text_control,
        caret: hit_offset,
        selection: Some(@core.TextRange::new(start~, end~)),
      }
      @common.view_event_result(
        changed=true,
        captured=true,
        text_control=Some(next_control),
        dirty=@core.ViewDirtyHint::ViewPaintDirty,
      )
    } else {
      @core.ViewEventResult::ignored()
    }
  } else if event.phase == @core.PointerPhase::Up &&
    ctx.text_control.text_selection_anchor is Some(_) {
    @common.view_event_result(
      changed=true,
      captured=true,
      text_control=Some({ ..ctx.text_control, text_selection_anchor: None }),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
    )
  } else {
    @core.ViewEventResult::ignored()
  }
}

///|
fn text_input_state_for_multi_line(
  text~ : String,
  frame~ : @core.Rect,
  font~ : @core.FontSpec,
  control~ : @core.TextControlStateContext,
  text_system~ : @core.TextSystem,
  line_height~ : Double,
  scroll_offset~ : Double,
) -> @core.TextInputState {
  let boundaries = @core.TextGraphemeBoundaries::new(text~)
  let display_text = text_with_composition(text, control, focused=true)
  let text_frame = text_area_text_frame(frame)
  let caret = boundaries.nearest_boundary(control.caret)
  let visual_caret = text_field_visual_caret(text, control, focused=true)
  let paragraph = if display_text == "" {
    None
  } else {
    Some(text_area_paragraph(text_system, display_text, font, text_frame))
  }
  let offset = text_area_clamped_scroll_offset(
    scroll_offset,
    line_count=match paragraph {
      None => 1
      Some(paragraph) => paragraph.lines.length()
    },
    line_height~,
    viewport_height=text_frame.size.height,
  )
  let content_frame = @core.Rect::new(
    x=text_frame.origin.x,
    y=text_frame.origin.y - offset,
    width=text_frame.size.width,
    height=text_frame.size.height,
  )
  let adjusted_rect = match paragraph {
    None => {
      let glyph_h = text_area_glyph_row_height(text_system, " ", font)
      @core.Rect::new(
        x=text_frame.origin.x,
        y=text_area_line_slot_y(content_frame, 0, line_height, glyph_h),
        width=text_editing_cursor_width(),
        height=glyph_h,
      )
    }
    Some(paragraph) => text_area_display_caret_rect(
      paragraph, text_system, content_frame, font, visual_caret, line_height,
    )
  }
  {
    focused: true,
    text,
    caret,
    selection: text_input_grapheme_selection(boundaries, control.selection),
    composition: control.composition,
    composition_cursor: control.composition_cursor,
    frame,
    caret_rect: adjusted_rect,
  }
}
