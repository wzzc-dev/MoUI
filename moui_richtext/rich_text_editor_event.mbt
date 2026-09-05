///|
fn[Msg] rich_text_editor_event(
  ctx : @core.ViewEventContext,
  value~ : String,
  format~ : RichTextFormatter,
  font~ : @core.FontSpec,
  on_input~ : ((String) -> Msg)?,
  on_input_edit~ : ((String, Int, @core.TextRange?, RichTextInputEdit?) -> Msg)?,
  on_selection_change~ : ((Int, @core.TextRange?) -> Msg)?,
  on_prefix_click~ : ((Int) -> Msg)?,
  on_command_click~ : ((Int) -> Msg)?,
  input_transform~ : ((String, Int, @core.TextRange?, String) -> RichTextInputTransform?)?,
  accepts_tab_input~ : Bool,
  visible_scroll_y~ : Double,
  on_scroll~ : ((Double) -> Msg)?,
  visible_viewport_height~ : Double,
  visible_overscan~ : Double,
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
        on_command_click~,
        event~,
        visible_scroll_y~,
        on_scroll~,
        visible_viewport_height~,
        visible_overscan~,
      )
    @core.AppEvent::Keyboard(event) =>
      rich_text_keyboard_event(
        ctx,
        value~,
        format~,
        font~,
        on_input~,
        on_input_edit~,
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
        on_input_edit~,
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
  value~ : String,
  format~ : RichTextFormatter,
  font~ : @core.FontSpec,
  on_selection_change~ : ((Int, @core.TextRange?) -> Msg)?,
  on_prefix_click~ : ((Int) -> Msg)?,
  on_command_click~ : ((Int) -> Msg)?,
  event~ : @core.PointerEvent,
  visible_scroll_y~ : Double,
  on_scroll~ : ((Double) -> Msg)?,
  visible_viewport_height~ : Double,
  visible_overscan~ : Double,
) -> @core.ViewEventResult[Msg] {
  ignore(visible_overscan)
  let inside = ctx.frame.contains(event.position)
  if inside && (event.wheel_delta.x != 0.0 || event.wheel_delta.y != 0.0) {
    return rich_text_scroll_event(
      value,
      format,
      font,
      ctx.text_system,
      event~,
      visible_scroll_y~,
      on_scroll~,
      visible_viewport_height~,
    )
  }
  match event.phase {
    @core.PointerPhase::Down =>
      if inside {
        let text = value
        let document = format(text)
        let base_content = rich_text_editor_content_rect(ctx.frame)
        let content = rich_text_scrolled_content_rect(
          base_content,
          scroll_y=visible_scroll_y,
          visible_viewport_height~,
        )
        // A Cmd/Ctrl-held click opens links/images instead of moving the caret:
        // dispatch the command-click hook with the source offset and swallow the
        // caret placement so the selection is not disturbed.
        let command_modifiers = event.modifiers.meta || event.modifiers.control
        match (command_modifiers, on_command_click) {
          (true, Some(handler)) => {
            let offset = rich_text_document_source_offset_at_point(
              document,
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
          }
        }
      } else {
        @core.ViewEventResult::ignored()
      }
    @core.PointerPhase::Move =>
      match ctx.text_control.text_selection_anchor {
        Some(anchor) => {
          let text = value
          let document = format(text)
          let base_content = rich_text_editor_content_rect(ctx.frame)
          let content = rich_text_scrolled_content_rect(
            base_content,
            scroll_y=visible_scroll_y,
            visible_viewport_height~,
          )
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
fn[Msg] rich_text_scroll_event(
  value : String,
  format : RichTextFormatter,
  font : @core.FontSpec,
  text_system : @core.TextSystem,
  event~ : @core.PointerEvent,
  visible_scroll_y~ : Double,
  on_scroll~ : ((Double) -> Msg)?,
  visible_viewport_height~ : Double,
) -> @core.ViewEventResult[Msg] {
  match on_scroll {
    Some(handler) => {
      let viewport_height = if visible_viewport_height > 0.0 {
        visible_viewport_height
      } else {
        0.0
      }
      let content_height = rich_text_document_height(
          format(value),
          font,
          text_system~,
        ) +
        48.0
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
fn[Msg] rich_text_keyboard_event(
  ctx : @core.ViewEventContext,
  value~ : String,
  format~ : RichTextFormatter,
  font~ : @core.FontSpec,
  on_input~ : ((String) -> Msg)?,
  on_input_edit~ : ((String, Int, @core.TextRange?, RichTextInputEdit?) -> Msg)?,
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
      on_input_edit~,
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
      on_input_edit~,
      on_selection_change~,
      input_transform~,
      event=@core.TextInputEvent::InsertText("\n"),
      record_history=true,
    )
  }
  if @core.is_select_all_shortcut(event) {
    let next_control = select_rich_text_control(ctx.text_control, value)
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
  if @core.is_undo_shortcut(event) {
    let result = restore_text_history(ctx.text_control, value, undo=true)
    return view_event_result(
      changed=result.changed,
      captured=true,
      text_control=Some(result.control),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
      messages=text_input_messages(on_input, result.text) +
        text_input_edit_messages(on_input_edit, result.text, result.control) +
        selection_messages(
          on_selection_change,
          result.control.caret,
          result.control.selection,
        ),
    )
  }
  if @core.is_redo_shortcut(event) {
    let result = restore_text_history(ctx.text_control, value, undo=false)
    return view_event_result(
      changed=result.changed,
      captured=true,
      text_control=Some(result.control),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
      messages=text_input_messages(on_input, result.text) +
        text_input_edit_messages(on_input_edit, result.text, result.control) +
        selection_messages(
          on_selection_change,
          result.control.caret,
          result.control.selection,
        ),
    )
  }
  if event.key == "Backspace" {
    match @core.active_text_selection(ctx.text_control.selection) {
      Some(selection) =>
        return rich_text_input_event(
          ctx,
          value~,
          on_input~,
          on_input_edit~,
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
          on_input_edit~,
          on_selection_change~,
          input_transform~,
          event=@core.TextInputEvent::DeleteSurrounding(1, 0),
          record_history=true,
        )
    }
  }
  if event.key == "Delete" {
    match @core.active_text_selection(ctx.text_control.selection) {
      Some(selection) =>
        return rich_text_input_event(
          ctx,
          value~,
          on_input~,
          on_input_edit~,
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
          on_input_edit~,
          on_selection_change~,
          input_transform~,
          event=@core.TextInputEvent::DeleteSurrounding(0, 1),
          record_history=true,
        )
    }
  }
  if event.key == "ArrowUp" {
    let text = value
    let document = format(text)
    let content = rich_text_editor_content_rect(ctx.frame)
    return rich_text_vertical_caret_move_result(
      ctx,
      text,
      document,
      content,
      font,
      up=true,
      extend_selection=event.modifiers.shift,
      on_selection_change,
    )
  }
  if event.key == "ArrowDown" {
    let text = value
    let document = format(text)
    let content = rich_text_editor_content_rect(ctx.frame)
    return rich_text_vertical_caret_move_result(
      ctx,
      text,
      document,
      content,
      font,
      up=false,
      extend_selection=event.modifiers.shift,
      on_selection_change,
    )
  }
  if event.key == "ArrowLeft" {
    return rich_text_caret_move_result(
      ctx,
      value,
      @core.TextCaretDirection::MoveLeft,
      event.modifiers.shift,
      on_selection_change,
    )
  }
  if event.key == "ArrowRight" {
    return rich_text_caret_move_result(
      ctx,
      value,
      @core.TextCaretDirection::MoveRight,
      event.modifiers.shift,
      on_selection_change,
    )
  }
  if event.key == "Home" {
    return rich_text_line_edge_move_result(
      ctx,
      value,
      home=true,
      on_selection_change,
    )
  }
  if event.key == "End" {
    return rich_text_line_edge_move_result(
      ctx,
      value,
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
          on_input_edit~,
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
  value~ : String,
  on_input~ : ((String) -> Msg)?,
  on_input_edit~ : ((String, Int, @core.TextRange?, RichTextInputEdit?) -> Msg)?,
  on_selection_change~ : ((Int, @core.TextRange?) -> Msg)?,
  input_transform~ : ((String, Int, @core.TextRange?, String) -> RichTextInputTransform?)?,
  event~ : @core.TextInputEvent,
  record_history~ : Bool,
) -> @core.ViewEventResult[Msg] {
  let text = value
  let result = match event {
    @core.TextInputEvent::InsertText(inserted) =>
      if inserted == "" {
        (
          { text, control: ctx.text_control, changed: false, edit: None } :
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
          None => apply_text_input(ctx.text_control, text, event, record_history~)
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
  view_event_result(
    changed=result.changed,
    captured=result.changed,
    text_control=Some(result.control),
    dirty=@core.ViewDirtyHint::ViewPaintDirty,
    messages=if result.changed {
      text_input_messages(on_input, result.text) +
      text_input_edit_messages(
        on_input_edit, result.text, result.control, record=result.edit,
      ) +
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
  value~ : String,
  format~ : RichTextFormatter,
  on_input~ : ((String) -> Msg)?,
  on_input_edit~ : ((String, Int, @core.TextRange?, RichTextInputEdit?) -> Msg)?,
  on_selection_change~ : ((Int, @core.TextRange?) -> Msg)?,
  input_transform~ : ((String, Int, @core.TextRange?, String) -> RichTextInputTransform?)?,
  intent : @core.CommandIntent,
  paste_text~ : String?,
) -> @core.ViewTextCommandResult[Msg] {
  let text = value
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
      match @core.active_text_selection(ctx.text_control.selection) {
        Some(selection) => {
          let event_result = rich_text_input_event(
            ctx,
            value~,
            on_input~,
            on_input_edit~,
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
            on_input_edit~,
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
      @core.ViewTextCommandResult::new(
        result=@core.TextCommandResult::handled(changed=result.changed),
        text_control=Some(result.control),
        messages=if result.changed {
          text_input_messages(on_input, result.text) +
          text_input_edit_messages(on_input_edit, result.text, result.control) +
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
      @core.ViewTextCommandResult::new(
        result=@core.TextCommandResult::handled(changed=result.changed),
        text_control=Some(result.control),
        messages=if result.changed {
          text_input_messages(on_input, result.text) +
          text_input_edit_messages(on_input_edit, result.text, result.control) +
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
  selection_caret~ : Int,
  selection_range~ : @core.TextRange?,
  visible_scroll_y~ : Double,
  visible_viewport_height~ : Double,
  visible_overscan~ : Double,
  text_system~ : @core.TextSystem,
) -> @core.TextInputState {
  ignore(visible_overscan)
  let boundaries = @core.TextGraphemeBoundaries::new(text~)
  let control = if selection_caret >= 0 {
    { ..control, caret: selection_caret, selection: selection_range }
  } else {
    control
  }
  let display_text = rich_text_with_composition(text, control, focused=true)
  let base_content = rich_text_editor_content_rect(frame)
  let content = rich_text_scrolled_content_rect(
    base_content,
    scroll_y=visible_scroll_y,
    visible_viewport_height~,
  )
  let caret = boundaries.nearest_boundary(control.caret)
  let visual_caret = @core.clamp_int(
    rich_text_visual_caret(text, control, focused=true),
    0,
    text_length(display_text),
  )
  let document = format(display_text)
  let caret_rect = rich_text_document_caret_rect_or_plain(
    document, visual_caret, content, font, text_system, display_text,
  )
  {
    focused: true,
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
  direction : @core.TextCaretDirection,
  extend_selection : Bool,
  on_selection_change : ((Int, @core.TextRange?) -> Msg)?,
) -> @core.ViewEventResult[Msg] {
  let caret_move = @core.move_text_caret(
    text,
    ctx.text_control.caret,
    ctx.text_control.selection,
    direction,
    extend_selection~,
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
