///|
priv struct TextHistoryRestoreResult {
  text : String
  control : @core.TextControlStateContext
  changed : Bool
}

///|
fn restore_text_history(
  control : @core.TextControlStateContext,
  current : String,
  undo~ : Bool,
) -> TextHistoryRestoreResult {
  let source = if undo { control.undo_stack } else { control.redo_stack }
  if source.length() == 0 {
    return { text: current, control, changed: false }
  }
  let restored = source[source.length() - 1]
  let restored_text = if undo {
    restored.undo_text(current)
  } else {
    restored.redo_text(current)
  }
  let next_source : Array[@core.TextHistoryEntryContext] = []
  for index in 0..<(source.length() - 1) {
    next_source.push(source[index])
  }
  // The opposite stack receives the same delta carrying the live
  // editor position: undo/redo are two views of one entry, so redoing
  // re-applies the edit and lands the caret where the undo left it.
  let current_entry : @core.TextHistoryEntryContext = {
    ..restored,
    caret: control.caret,
    selection: control.selection,
  }
  let destination = if undo { control.redo_stack } else { control.undo_stack }
  let next_destination : Array[@core.TextHistoryEntryContext] = []
  next_destination.append(destination)
  next_destination.push(current_entry)
  let next_control = if undo {
    {
      ..control,
      caret: restored.caret,
      selection: restored.selection,
      composition: None,
      composition_cursor: None,
      undo_stack: next_source,
      redo_stack: next_destination,
    }
  } else {
    {
      ..control,
      caret: restored.caret,
      selection: restored.selection,
      composition: None,
      composition_cursor: None,
      undo_stack: next_destination,
      redo_stack: next_source,
    }
  }
  {
    text: restored_text,
    control: next_control,
    changed: restored_text != current,
  }
}

///|
fn[Msg] view_text_input_result(
  ctx : @core.ViewEventContext,
  value~ : String,
  on_input~ : ((String) -> Msg)?,
  event : @core.TextInputEvent,
  record_history~ : Bool,
) -> @core.ViewEventResult[Msg] {
  let text = value
  let result = apply_text_input(ctx.text_control, text, event, record_history~)
  @common.view_event_result(
    changed=result.changed,
    captured=result.changed,
    text_control=Some(result.control),
    dirty=if result.text != text {
      @core.ViewDirtyHint::ViewBuildDirty
    } else {
      @core.ViewDirtyHint::ViewPaintDirty
    },
    messages=if result.changed {
      text_input_messages(on_input, result.text)
    } else {
      []
    },
  )
}

///|
priv struct TextInputApplyResult {
  text : String
  control : @core.TextControlStateContext
  changed : Bool
}

///|
fn apply_text_input(
  control : @core.TextControlStateContext,
  text : String,
  event : @core.TextInputEvent,
  record_history~ : Bool,
) -> TextInputApplyResult {
  match event {
    @core.TextInputEvent::InsertText(inserted) => {
      if inserted == "" {
        return { text, control, changed: false }
      }
      let edit = replace_current_selection(
        text,
        control.caret,
        control.selection,
        inserted,
      )
      apply_text_edit(control, text, edit, record_history~)
    }
    @core.TextInputEvent::ReplaceText(range, replacement) => {
      let edit = replace_text_range(text, range, replacement)
      apply_text_edit(control, text, edit, record_history~)
    }
    @core.TextInputEvent::SetSelection(range) => {
      let normalized = normalize_text_range_to_grapheme(text, range)
      let next_selection = if normalized.is_collapsed() {
        None
      } else {
        Some(normalized)
      }
      let next_control = {
        ..control,
        caret: normalized.end,
        selection: next_selection,
        composition: None,
        composition_cursor: None,
      }
      {
        text,
        control: next_control,
        changed: next_control.caret != control.caret ||
        next_control.selection != control.selection ||
        control.composition is Some(_) ||
        control.composition_cursor is Some(_),
      }
    }
    @core.TextInputEvent::CompositionStart => {
      let next_control = {
        ..control,
        composition: Some(""),
        composition_cursor: None,
      }
      { text, control: next_control, changed: true }
    }
    @core.TextInputEvent::CompositionUpdate(update) => {
      let next_control = {
        ..control,
        composition: if update.text() == "" {
          None
        } else {
          Some(update.text())
        },
        composition_cursor: match update.cursor() {
          Some(cursor) => {
            let normalized = normalize_text_range_to_grapheme(
              update.text(),
              cursor,
            )
            let length = text_length(update.text())
            let start = clamp_int(normalized.start, 0, length)
            let end = clamp_int(normalized.end, 0, length)
            Some(@core.TextRange::new(start~, end~))
          }
          None => None
        },
      }
      { text, control: next_control, changed: true }
    }
    @core.TextInputEvent::CompositionEnd(inserted) => {
      let next_control = {
        ..control,
        composition: None,
        composition_cursor: None,
      }
      if inserted == "" {
        { text, control: { ..next_control, selection: None }, changed: true }
      } else {
        let edit = replace_current_selection(
          text,
          next_control.caret,
          next_control.selection,
          inserted,
        )
        apply_text_edit(next_control, text, edit, record_history~)
      }
    }
    @core.TextInputEvent::DeleteRange(range) => {
      let edit = replace_text_range(text, range, "")
      apply_text_edit(control, text, edit, record_history~)
    }
    @core.TextInputEvent::DeleteSurrounding(before, after) => {
      let range = surrounding_delete_range(text, control.caret, before, after)
      let edit = replace_text_range(text, range, "")
      apply_text_edit(control, text, edit, record_history~)
    }
  }
}

///|
fn apply_text_edit(
  control : @core.TextControlStateContext,
  previous : String,
  edit : TextEditResult,
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
        start: edit.start,
        before: edit.before,
        after: edit.after,
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
fn[Msg] handle_text_field_command(
  ctx : @core.ViewEventContext,
  value~ : String,
  on_input~ : ((String) -> Msg)?,
  intent : @core.CommandIntent,
  paste_text~ : String?,
) -> @core.ViewTextCommandResult[Msg] {
  let text = value
  match intent {
    @core.CommandIntent::Copy =>
      @core.ViewTextCommandResult::new(
        result=@core.TextCommandResult::handled(
          clipboard_text=Some(selected_text(text, ctx.text_control.selection)),
        ),
      )
    @core.CommandIntent::Cut => {
      let copied = selected_text(text, ctx.text_control.selection)
      match active_text_selection(ctx.text_control.selection) {
        Some(selection) => {
          let result = apply_text_input(
            ctx.text_control,
            text,
            @core.TextInputEvent::DeleteRange(selection),
            record_history=true,
          )
          @core.ViewTextCommandResult::new(
            result=@core.TextCommandResult::handled(
              changed=result.changed,
              clipboard_text=Some(copied),
            ),
            text_control=Some(result.control),
            messages=if result.changed {
              text_input_messages(on_input, result.text)
            } else {
              []
            },
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
          let result = apply_text_input(
            ctx.text_control,
            text,
            @core.TextInputEvent::InsertText(value_to_paste),
            record_history=true,
          )
          @core.ViewTextCommandResult::new(
            result=@core.TextCommandResult::handled(changed=result.changed),
            text_control=Some(result.control),
            messages=if result.changed {
              text_input_messages(on_input, result.text)
            } else {
              []
            },
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
          text_input_messages(on_input, result.text)
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
          text_input_messages(on_input, result.text)
        } else {
          []
        },
      )
    }
    @core.CommandIntent::SelectAll => {
      let next_control = select_text_control(ctx.text_control, text)
      @core.ViewTextCommandResult::new(
        result=@core.TextCommandResult::handled(changed=true),
        text_control=Some(next_control),
      )
    }
    _ => @core.ViewTextCommandResult::ignored()
  }
}
