///|
fn[Msg] text_field_control(
  value~ : @core.Binding[String],
  placeholder~ : String,
  size~ : @core.Size,
  theme? : @core.Theme,
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  style? : TextFieldStyle,
  on_input? : ((String) -> Msg)? = None,
  on_submit? : Msg? = None,
  kind? : String = "TextField",
  key? : String? = None,
) -> @core.View[Msg] {
  let theme_revision = match theme {
    Some(t) => t.revision_fingerprint()
    None => "context"
  }
  let variant_label = match variant {
    TextFieldVariant::Filled => "filled"
    TextFieldVariant::Outline => "outline"
    TextFieldVariant::Plain => "plain"
  }
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind~, key~),
    revision=() => {
      "textfield:\{value.get()}:\{placeholder}:\{view_size_revision(size)}:\{variant_label}:\{theme_revision}:\{on_submit is Some(_)}"
    },
    layout=ctx => {
      @core.ViewLayoutResult::new(size=ctx.constraints.constrain(size))
    },
    paint=ctx => {
      let resolved_theme = theme.unwrap_or(ctx.environment.theme)
      let resolved_style = match style {
        Some(value) => value
        None => variant.style(resolved_theme)
      }
      let normal = resolved_style.normal
      let focused = resolved_style.focused
      let commands : Array[@core.DrawCommand] = []
      let overlay_commands : Array[@core.DrawCommand] = []
      append_text_field_commands(
        commands,
        overlay_commands,
        text=value.get(),
        placeholder~,
        size~,
        font=resolved_style.font,
        foreground=normal.foreground,
        placeholder_color=resolved_style.placeholder_color,
        background=normal.background,
        border=normal.border,
        focused_border=focused.border,
        cursor_color=resolved_style.cursor_color,
        corner_radius=normal.radius,
        frame=ctx.frame,
        focused=ctx.focused,
        control=ctx.text_control,
        text_system=ctx.text_system,
        theme=resolved_theme,
        bottom_border_only=normal.bottom_border_only,
        inner_focus_border=if ctx.focused {
          focused.inner_focus_border
        } else {
          None
        },
      )
      {
        commands,
        child_layers: [],
        post_commands: [],
        overlay_commands,
        platform_views: [],
        repaint_boundary: false,
        animating: false,
      }
    },
    event=ctx => {
      handle_text_field_event(
        ctx,
        value~,
        on_input~,
        on_submit~,
        search_bar=false,
        on_clear=None,
      )
    },
    text_input_state=ctx => {
      let resolved_theme = theme.unwrap_or(ctx.environment.theme)
      let resolved_style = match style {
        Some(value) => value
        None => variant.style(resolved_theme)
      }
      Some(
        text_input_state_for_single_line(
          text=value.get(),
          frame=ctx.frame,
          font=resolved_style.font,
          control=ctx.text_control,
          text_system=ctx.text_system,
          search_bar=false,
        ),
      )
    },
    text_command=(ctx, intent, paste_text) => {
      handle_text_field_command(ctx, value~, on_input~, intent, paste_text~)
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
fn[Msg] controlled_text_field_control(
  value~ : String,
  on_input~ : (String) -> Msg,
  placeholder~ : String,
  size~ : @core.Size,
  theme? : @core.Theme,
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  style? : TextFieldStyle,
  on_submit? : Msg? = None,
  kind? : String = "TextField",
  key? : String? = None,
) -> @core.View[Msg] {
  text_field_control(
    value=@core.Binding::new(get=() => value, set=_next => ()),
    placeholder~,
    size~,
    theme?,
    variant~,
    style?,
    on_input=Some(on_input),
    on_submit~,
    kind~,
    key~,
  )
}

///|
fn[Msg] search_bar_control(
  query~ : @core.Binding[String],
  placeholder~ : String,
  theme? : @core.Theme,
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  style? : TextFieldStyle,
  on_input? : ((String) -> Msg)? = None,
  on_submit? : Msg? = None,
  on_clear? : Msg? = None,
  kind? : String = "SearchBar",
  key? : String? = None,
) -> @core.View[Msg] {
  let theme_revision = match theme {
    Some(t) => t.revision_fingerprint()
    None => "context"
  }
  let variant_label = match variant {
    TextFieldVariant::Filled => "filled"
    TextFieldVariant::Outline => "outline"
    TextFieldVariant::Plain => "plain"
  }
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind~, key~),
    revision=() => {
      "searchbar:\{query.get()}:\{placeholder}:\{variant_label}:\{theme_revision}:\{on_submit is Some(_)}:\{on_clear is Some(_)}"
    },
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(
          @core.Size::new(width=240.0, height=40.0),
        ),
      )
    },
    paint=ctx => {
      let resolved_theme = theme.unwrap_or(ctx.environment.theme)
      let resolved_style = match style {
        Some(value) => value
        None => variant.style(resolved_theme)
      }
      let normal = resolved_style.normal
      let focused = resolved_style.focused
      let commands : Array[@core.DrawCommand] = []
      let overlay_commands : Array[@core.DrawCommand] = []
      append_searchbar_commands(
        commands,
        overlay_commands,
        text=query.get(),
        placeholder~,
        font=resolved_style.font,
        foreground=normal.foreground,
        placeholder_color=resolved_style.placeholder_color,
        background=normal.background,
        border=normal.border,
        focused_border=focused.border,
        cursor_color=resolved_style.cursor_color,
        corner_radius=normal.radius,
        frame=ctx.frame,
        focused=ctx.focused,
        control=ctx.text_control,
        text_system=ctx.text_system,
        theme=resolved_theme,
      )
      {
        commands,
        child_layers: [],
        post_commands: [],
        overlay_commands,
        platform_views: [],
        repaint_boundary: false,
        animating: false,
      }
    },
    event=ctx => {
      handle_text_field_event(
        ctx,
        value=query,
        on_input~,
        on_submit~,
        search_bar=true,
        on_clear~,
      )
    },
    text_input_state=ctx => {
      let resolved_theme = theme.unwrap_or(ctx.environment.theme)
      let resolved_style = match style {
        Some(value) => value
        None => variant.style(resolved_theme)
      }
      Some(
        text_input_state_for_single_line(
          text=query.get(),
          frame=ctx.frame,
          font=resolved_style.font,
          control=ctx.text_control,
          text_system=ctx.text_system,
          search_bar=true,
        ),
      )
    },
    text_command=(ctx, intent, paste_text) => {
      handle_text_field_command(
        ctx,
        value=query,
        on_input~,
        intent,
        paste_text~,
      )
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        role=@core.SemanticsRole::TextField,
        label=placeholder,
        value=query.get(),
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
fn[Msg] controlled_search_bar_control(
  query~ : String,
  on_input~ : (String) -> Msg,
  placeholder~ : String,
  theme? : @core.Theme,
  variant? : TextFieldVariant = TextFieldVariant::Filled,
  style? : TextFieldStyle,
  on_submit? : Msg? = None,
  on_clear? : Msg? = None,
  kind? : String = "SearchBar",
  key? : String? = None,
) -> @core.View[Msg] {
  search_bar_control(
    query=@core.Binding::new(get=() => query, set=_next => ()),
    placeholder~,
    theme?,
    variant~,
    style?,
    on_input=Some(on_input),
    on_submit~,
    on_clear~,
    kind~,
    key~,
  )
}

///|
fn[Msg] handle_text_field_event(
  ctx : @core.ViewEventContext,
  value~ : @core.Binding[String],
  on_input~ : ((String) -> Msg)?,
  on_submit~ : Msg?,
  search_bar~ : Bool,
  on_clear~ : Msg?,
) -> @core.ViewEventResult[Msg] {
  match ctx.event {
    @core.AppEvent::Pointer(event) =>
      handle_text_field_pointer(
        ctx,
        value~,
        on_input~,
        search_bar~,
        on_clear~,
        event,
      )
    @core.AppEvent::Keyboard(event) =>
      handle_text_field_keyboard(ctx, value~, on_input~, on_submit~, event)
    @core.AppEvent::TextInput(event) =>
      view_text_input_result(ctx, value~, on_input~, event, record_history=true)
    _ => @core.ViewEventResult::ignored()
  }
}

///|
fn[Msg] handle_text_field_pointer(
  ctx : @core.ViewEventContext,
  value~ : @core.Binding[String],
  on_input~ : ((String) -> Msg)?,
  search_bar~ : Bool,
  on_clear~ : Msg?,
  event : @core.PointerEvent,
) -> @core.ViewEventResult[Msg] {
  let text = value.get()
  if search_bar && text != "" {
    let clear_frame = searchbar_clear_frame(ctx.frame)
    if event.phase == @core.PointerPhase::Up &&
      clear_frame.contains(event.position) {
      let next_control = text_control_for_text(ctx.text_control, "")
      value.set("")
      let messages = text_input_messages(on_input, "") +
        option_message(on_clear)
      return view_event_result(
        changed=true,
        activated=true,
        focused=true,
        captured=true,
        text_control=Some(next_control),
        dirty=@core.ViewDirtyHint::ViewPaintDirty,
        messages~,
      )
    }
  }
  if event.phase == @core.PointerPhase::Down &&
    ctx.frame.contains(event.position) {
    let caret_at_end = @core.TextGraphemeBoundaries::new(text~).length()
    let next_control = {
      ..ctx.text_control,
      caret: caret_at_end,
      selection: None,
      text_selection_anchor: None,
      composition: None,
      composition_cursor: None,
    }
    view_event_result(
      changed=true,
      focused=true,
      captured=true,
      text_control=Some(next_control),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
    )
  } else {
    @core.ViewEventResult::ignored()
  }
}

///|
fn[Msg] handle_text_field_keyboard(
  ctx : @core.ViewEventContext,
  value~ : @core.Binding[String],
  on_input~ : ((String) -> Msg)?,
  on_submit~ : Msg?,
  event : @core.KeyboardEvent,
) -> @core.ViewEventResult[Msg] {
  if !event.pressed {
    return @core.ViewEventResult::ignored()
  }
  if event.key == "Enter" {
    return view_event_result(
      changed=true,
      activated=on_submit is Some(_),
      captured=true,
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
      messages=option_message(on_submit),
    )
  }
  if @core.is_select_all_shortcut(event) {
    let next_control = select_text_control(ctx.text_control, value.get())
    return view_event_result(
      changed=true,
      captured=true,
      text_control=Some(next_control),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
    )
  }
  if @core.is_undo_shortcut(event) {
    let result = restore_text_history(ctx.text_control, value.get(), undo=true)
    value.set(result.text)
    return view_event_result(
      changed=result.changed,
      captured=true,
      text_control=Some(result.control),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
      messages=text_input_messages(on_input, result.text),
    )
  }
  if @core.is_redo_shortcut(event) {
    let result = restore_text_history(ctx.text_control, value.get(), undo=false)
    value.set(result.text)
    return view_event_result(
      changed=result.changed,
      captured=true,
      text_control=Some(result.control),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
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
  if event.key == "ArrowLeft" {
    return view_caret_move_result(
      ctx,
      value.get(),
      MoveLeft,
      event.modifiers.shift,
    )
  }
  if event.key == "ArrowRight" {
    return view_caret_move_result(
      ctx,
      value.get(),
      MoveRight,
      event.modifiers.shift,
    )
  }
  if event.key == "Home" {
    return view_caret_move_result(
      ctx,
      value.get(),
      MoveStart,
      event.modifiers.shift,
    )
  }
  if event.key == "End" {
    return view_caret_move_result(
      ctx,
      value.get(),
      MoveEnd,
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
  let next_source : Array[@core.TextHistoryEntryContext] = []
  for index in 0..<(source.length() - 1) {
    next_source.push(source[index])
  }
  let current_entry : @core.TextHistoryEntryContext = {
    text: current,
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
    text: restored.text,
    control: next_control,
    changed: restored.text != current,
  }
}

///|
fn[Msg] view_caret_move_result(
  ctx : @core.ViewEventContext,
  text : String,
  direction : TextCaretDirection,
  extend_selection : Bool,
) -> @core.ViewEventResult[Msg] {
  let caret_move = move_text_caret(
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
  )
}

///|
fn[Msg] view_text_input_result(
  ctx : @core.ViewEventContext,
  value~ : @core.Binding[String],
  on_input~ : ((String) -> Msg)?,
  event : @core.TextInputEvent,
  record_history~ : Bool,
) -> @core.ViewEventResult[Msg] {
  let text = value.get()
  let result = apply_text_input(ctx.text_control, text, event, record_history~)
  if result.changed {
    value.set(result.text)
  }
  view_event_result(
    changed=result.changed,
    captured=result.changed,
    text_control=Some(result.control),
    dirty=@core.ViewDirtyHint::ViewPaintDirty,
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
fn[Msg] handle_text_field_command(
  ctx : @core.ViewEventContext,
  value~ : @core.Binding[String],
  on_input~ : ((String) -> Msg)?,
  intent : @core.CommandIntent,
  paste_text~ : String?,
) -> @core.ViewTextCommandResult[Msg] {
  let text = value.get()
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
          if result.changed {
            value.set(result.text)
          }
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
          if result.changed {
            value.set(result.text)
          }
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
      if result.changed {
        value.set(result.text)
      }
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
      if result.changed {
        value.set(result.text)
      }
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
