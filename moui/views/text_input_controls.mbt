///|
priv struct TextEditResult {
  text : String
  caret : Int
  selection : @core.TextRange?
}

///|
priv enum TextCaretDirection {
  MoveLeft
  MoveRight
  MoveStart
  MoveEnd
}

///|
priv struct TextCaretMoveResult {
  caret : Int
  selection : @core.TextRange?
}

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
fn append_text_field_commands(
  commands : Array[@core.DrawCommand],
  overlay_commands : Array[@core.DrawCommand],
  text~ : String,
  placeholder~ : String,
  size~ : @core.Size,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  placeholder_color~ : @core.Color,
  background~ : @core.Brush,
  border~ : @core.BorderStyle?,
  focused_border~ : @core.BorderStyle?,
  cursor_color~ : @core.Color,
  corner_radius~ : Double,
  frame~ : @core.Rect,
  focused~ : Bool,
  control~ : @core.TextControlStateContext,
  text_system~ : @core.TextSystem,
  theme~ : @core.Theme,
  bottom_border_only? : Bool = false,
  inner_focus_border? : @core.Color? = None,
) -> Unit {
  ignore(size)
  let border = if focused { focused_border } else { border }
  let rounded = @core.RoundedRect::new(rect=frame, radius=corner_radius)
  commands.push(@core.DrawCommand::FillRoundedRectBrush(rounded, background))
  if bottom_border_only {
    append_bottom_border(commands, frame, border)
  } else {
    append_border(commands, rounded, border)
  }
  // Fluent 2 focus reveal: paint an inner stroke inside the frame when focused.
  match inner_focus_border {
    Some(color) =>
      append_inner_focus_border(commands, frame, color, corner_radius)
    None => ()
  }
  let display_text = text_with_composition(text, control, focused~)
  let display = if display_text == "" { placeholder } else { display_text }
  let color = if text == "" { placeholder_color } else { foreground }
  let text_frame = frame.inset(
    @core.Insets::symmetric(horizontal=10.0, vertical=4.0),
  )
  commands.push(
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text=display,
        frame=text_frame,
        font~,
        color~,
        align=@core.TextAlign::TextStart,
      ),
    ),
  )
  if focused {
    let layout = text_system.measure_text(
      @core.TextLayoutInput::new(
        text=display_text,
        font~,
        max_width=text_frame.size.width,
      ),
    )
    append_text_field_editing_overlay(
      overlay_commands,
      text~,
      display_text~,
      text_frame~,
      layout~,
      control~,
      cursor_color~,
      theme~,
    )
  }
}

///|
fn append_searchbar_commands(
  commands : Array[@core.DrawCommand],
  overlay_commands : Array[@core.DrawCommand],
  text~ : String,
  placeholder~ : String,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  placeholder_color~ : @core.Color,
  background~ : @core.Brush,
  border~ : @core.BorderStyle?,
  focused_border~ : @core.BorderStyle?,
  cursor_color~ : @core.Color,
  corner_radius~ : Double,
  frame~ : @core.Rect,
  focused~ : Bool,
  control~ : @core.TextControlStateContext,
  text_system~ : @core.TextSystem,
  theme~ : @core.Theme,
) -> Unit {
  let rounded = @core.RoundedRect::new(rect=frame, radius=corner_radius)
  let border = if focused { focused_border } else { border }
  commands.push(@core.DrawCommand::FillRoundedRectBrush(rounded, background))
  append_border(commands, rounded, border)
  let icon_frame = @core.Rect::new(
    x=frame.origin.x + 10.0,
    y=frame.origin.y + (frame.size.height - 16.0) / 2.0,
    width=16.0,
    height=16.0,
  )
  append_searchbar_search_icon(commands, icon_frame, foreground.with_alpha(0.6))
  let display_text = text_with_composition(text, control, focused~)
  let display = if display_text == "" { placeholder } else { display_text }
  let color = if text == "" { placeholder_color } else { foreground }
  let text_frame = searchbar_text_frame(frame, has_text=text != "")
  commands.push(
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text=display,
        frame=text_frame,
        font~,
        color~,
        align=@core.TextAlign::TextStart,
      ),
    ),
  )
  if focused {
    let layout = text_system.measure_text(
      @core.TextLayoutInput::new(
        text=display_text,
        font~,
        max_width=text_frame.size.width,
      ),
    )
    append_text_field_editing_overlay(
      overlay_commands,
      text~,
      display_text~,
      text_frame~,
      layout~,
      control~,
      cursor_color~,
      theme~,
    )
  }
  if text != "" {
    let clear_frame = searchbar_clear_frame(frame)
    append_searchbar_clear_icon(
      commands,
      clear_frame,
      foreground.with_alpha(0.6),
    )
  }
}

///|
fn append_border(
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
/// Fluent 2 underline text field: paint only the bottom edge as a straight
/// line, ignoring side/top borders and corner radius.
fn append_bottom_border(
  commands : Array[@core.DrawCommand],
  frame : @core.Rect,
  border : @core.BorderStyle?,
) -> Unit {
  match border {
    Some(border) =>
      if border.width > 0.0 {
        let y = frame.origin.y + frame.size.height - border.width / 2.0
        let path = @core.PathSpec::new(
          verbs=[
            @core.PathVerb::MoveTo(@core.Point::new(x=frame.origin.x, y~)),
            @core.PathVerb::LineTo(
              @core.Point::new(x=frame.origin.x + frame.size.width, y~),
            ),
          ],
          stroke=Some(border.brush),
          stroke_width=border.width,
        )
        commands.push(@core.DrawCommand::DrawPath(path))
      }
    None => ()
  }
}

///|
/// Fluent 2 focus reveal: paint an inner stroke inset 2px inside the control
/// frame so focus reads as a distinct inner ring rather than a thicker outer
/// border.
fn append_inner_focus_border(
  commands : Array[@core.DrawCommand],
  frame : @core.Rect,
  color : @core.Color,
  corner_radius : Double,
) -> Unit {
  let inset = 2.0
  let inner = @core.RoundedRect::new(
    rect=@core.Rect::new(
      x=frame.origin.x + inset,
      y=frame.origin.y + inset,
      width=frame.size.width - inset * 2.0,
      height=frame.size.height - inset * 2.0,
    ),
    radius=(corner_radius - inset).clamp(min=0.0, max=corner_radius),
  )
  commands.push(
    @core.DrawCommand::StrokeRoundedRectBrush(
      inner,
      @core.Brush::solid(color),
      1.0,
    ),
  )
}

///|
fn append_text_field_editing_overlay(
  commands : Array[@core.DrawCommand],
  text~ : String,
  display_text~ : String,
  text_frame~ : @core.Rect,
  layout~ : @core.TextLayoutResult,
  control~ : @core.TextControlStateContext,
  cursor_color~ : @core.Color,
  theme~ : @core.Theme,
) -> Unit {
  commands.push(@core.DrawCommand::PushClip(text_frame))
  if control.composition is None {
    append_text_field_selection_commands(
      commands,
      display_text,
      text_frame,
      layout,
      control.selection,
      theme,
    )
  } else {
    append_text_field_composition_underline(
      commands,
      text~,
      text_frame~,
      layout~,
      control~,
      cursor_color~,
    )
  }
  let caret = clamp_int(
    text_field_visual_caret(text, control, focused=true),
    0,
    max_int(0, layout.caret_positions.length() - 1),
  )
  let cursor_x = text_frame.origin.x + layout.caret_positions[caret]
  let cursor = @core.Rect::new(
    x=cursor_x,
    y=text_frame.origin.y + 6.0,
    width=1.5,
    height=max_double(8.0, text_frame.size.height - 12.0),
  )
  commands.push(@core.DrawCommand::FillRect(cursor, cursor_color))
  commands.push(@core.DrawCommand::PopClip)
}

///|
fn append_text_field_selection_commands(
  commands : Array[@core.DrawCommand],
  text : String,
  text_frame : @core.Rect,
  layout : @core.TextLayoutResult,
  selection : @core.TextRange?,
  theme : @core.Theme,
) -> Unit {
  match active_text_selection(selection) {
    Some(selection) => {
      let selection = @core.normalize_grapheme_range(
        @core.TextGraphemeBoundaries::new(text~),
        selection,
      )
      let start = clamp_int(
        selection.start,
        0,
        max_int(0, layout.caret_positions.length() - 1),
      )
      let end = clamp_int(
        selection.end,
        start,
        max_int(start, layout.caret_positions.length() - 1),
      )
      let x0 = text_frame.origin.x + layout.caret_positions[start]
      let x1 = text_frame.origin.x + layout.caret_positions[end]
      if x1 > x0 {
        // Selection highlight tracks the ambient theme's primary palette token
        // so it follows the active color scheme (light/dark) and custom palette
        // overrides, rather than a hard-coded light theme. The alpha matches the
        // rich text editor selection highlight convention (0.18) so plain text
        // fields and rich editors render selection highlights consistently.
        let selection_color = theme.palette.primary.with_alpha(0.18)
        commands.push(
          @core.DrawCommand::FillRect(
            @core.Rect::new(
              x=x0,
              y=text_frame.origin.y + 6.0,
              width=x1 - x0,
              height=max_double(8.0, text_frame.size.height - 12.0),
            ),
            selection_color,
          ),
        )
      }
    }
    None => ()
  }
}

///|
fn append_text_field_composition_underline(
  commands : Array[@core.DrawCommand],
  text~ : String,
  text_frame~ : @core.Rect,
  layout~ : @core.TextLayoutResult,
  control~ : @core.TextControlStateContext,
  cursor_color~ : @core.Color,
) -> Unit {
  match control.composition {
    Some(composition) =>
      if composition != "" {
        let start = clamp_int(
          composition_start_index(text, control.caret, control.selection),
          0,
          max_int(0, layout.caret_positions.length() - 1),
        )
        let end = clamp_int(
          start + text_length(composition),
          start,
          max_int(start, layout.caret_positions.length() - 1),
        )
        let x0 = text_frame.origin.x + layout.caret_positions[start]
        let x1 = text_frame.origin.x + layout.caret_positions[end]
        if x1 > x0 {
          commands.push(
            @core.DrawCommand::FillRect(
              @core.Rect::new(
                x=x0,
                y=text_frame.origin.y + text_frame.size.height - 7.0,
                width=x1 - x0,
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
fn append_searchbar_search_icon(
  commands : Array[@core.DrawCommand],
  frame : @core.Rect,
  color : @core.Color,
) -> Unit {
  let center = @core.Point::new(
    x=frame.origin.x + frame.size.width * 0.42,
    y=frame.origin.y + frame.size.height * 0.42,
  )
  let radius = frame.size.width * 0.26
  commands.push(
    @core.DrawCommand::StrokeRoundedRect(
      @core.RoundedRect::new(
        rect=@core.Rect::new(
          x=center.x - radius,
          y=center.y - radius,
          width=radius * 2.0,
          height=radius * 2.0,
        ),
        radius~,
      ),
      color,
      1.6,
    ),
  )
  commands.push(
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(
            @core.Point::new(
              x=center.x + radius * 0.7,
              y=center.y + radius * 0.7,
            ),
          ),
          @core.PathVerb::LineTo(
            @core.Point::new(
              x=frame.origin.x + frame.size.width * 0.86,
              y=frame.origin.y + frame.size.height * 0.86,
            ),
          ),
        ],
        stroke=Some(@core.Brush::solid(color)),
        stroke_width=1.6,
      ),
    ),
  )
}

///|
fn append_searchbar_clear_icon(
  commands : Array[@core.DrawCommand],
  frame : @core.Rect,
  color : @core.Color,
) -> Unit {
  let inset = frame.size.width * 0.28
  commands.push(
    @core.DrawCommand::DrawPath(
      @core.PathSpec::new(
        verbs=[
          @core.PathVerb::MoveTo(
            @core.Point::new(x=frame.origin.x + inset, y=frame.origin.y + inset),
          ),
          @core.PathVerb::LineTo(
            @core.Point::new(
              x=frame.origin.x + frame.size.width - inset,
              y=frame.origin.y + frame.size.height - inset,
            ),
          ),
          @core.PathVerb::MoveTo(
            @core.Point::new(
              x=frame.origin.x + frame.size.width - inset,
              y=frame.origin.y + inset,
            ),
          ),
          @core.PathVerb::LineTo(
            @core.Point::new(
              x=frame.origin.x + inset,
              y=frame.origin.y + frame.size.height - inset,
            ),
          ),
        ],
        stroke=Some(@core.Brush::solid(color)),
        stroke_width=1.6,
      ),
    ),
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
  extend : Bool,
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

///|
fn text_input_state_for_single_line(
  text~ : String,
  frame~ : @core.Rect,
  font~ : @core.FontSpec,
  control~ : @core.TextControlStateContext,
  text_system~ : @core.TextSystem,
  search_bar~ : Bool,
) -> @core.TextInputState {
  let boundaries = @core.TextGraphemeBoundaries::new(text~)
  let display_text = text_with_composition(text, control, focused=true)
  let text_frame = if search_bar {
    searchbar_text_frame(frame, has_text=text != "")
  } else {
    frame.inset(@core.Insets::symmetric(horizontal=10.0, vertical=4.0))
  }
  let layout = text_system.measure_text(
    @core.TextLayoutInput::new(
      text=display_text,
      font~,
      max_width=text_frame.size.width,
    ),
  )
  let caret = boundaries.nearest_boundary(control.caret)
  let visual_caret = clamp_int(
    text_field_visual_caret(text, control, focused=true),
    0,
    max_int(0, layout.caret_positions.length() - 1),
  )
  let cursor_x = text_frame.origin.x + layout.caret_positions[visual_caret]
  let caret_rect = @core.Rect::new(
    x=cursor_x,
    y=text_frame.origin.y + 6.0,
    width=1.5,
    height=max_double(8.0, text_frame.size.height - 12.0),
  )
  {
    focused: true,
    element_id: None,
    text,
    caret,
    selection: text_input_grapheme_selection(boundaries, control.selection),
    composition: control.composition,
    composition_cursor: control.composition_cursor,
    frame,
    caret_rect,
  }
}

///|
fn text_input_grapheme_selection(
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
    None => None
  }
}

///|
fn text_with_composition(
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
fn text_field_visual_caret(
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
fn composition_start_index(
  text : String,
  caret : Int,
  selection : @core.TextRange?,
) -> Int {
  match active_text_selection(selection) {
    Some(selection) =>
      @core.normalize_grapheme_range(
        @core.TextGraphemeBoundaries::new(text~),
        selection,
      ).start
    None => @core.TextGraphemeBoundaries::new(text~).nearest_boundary(caret)
  }
}

///|
fn composition_cursor_offset(
  control : @core.TextControlStateContext,
  composition : String,
) -> Int {
  let length = text_length(composition)
  match control.composition_cursor {
    Some(cursor) => {
      let normalized = cursor.normalized()
      @core.TextGraphemeBoundaries::new(text=composition).nearest_boundary(
        clamp_int(normalized.end, 0, length),
      )
    }
    None => length
  }
}

///|
fn selected_text(text : String, selection : @core.TextRange?) -> String {
  match active_text_selection(selection) {
    Some(selection) => {
      let chars = text.to_array()
      let range = @core.normalize_grapheme_range(
        @core.TextGraphemeBoundaries::new(text~),
        selection,
      )
      let start = clamp_int(range.start, 0, chars.length())
      let end = clamp_int(range.end, start, chars.length())
      String::from_array(chars[start:end])
    }
    None => ""
  }
}

///|
fn active_text_selection(selection : @core.TextRange?) -> @core.TextRange? {
  match selection {
    Some(selection) => {
      let normalized = selection.normalized()
      if normalized.is_collapsed() {
        None
      } else {
        Some(normalized)
      }
    }
    None => None
  }
}

///|
fn normalize_text_range_to_grapheme(
  text : String,
  range : @core.TextRange,
) -> @core.TextRange {
  @core.normalize_grapheme_range(
    @core.TextGraphemeBoundaries::new(text~),
    range,
  )
}

///|
fn replace_current_selection(
  text : String,
  caret : Int,
  selection : @core.TextRange?,
  replacement : String,
) -> TextEditResult {
  let range = match selection {
    Some(selection) => selection
    None => @core.TextRange::collapsed(caret)
  }
  replace_text_range(text, range, replacement)
}

///|
fn replace_text_range(
  text : String,
  range : @core.TextRange,
  replacement : String,
) -> TextEditResult {
  let normalized = range.normalized()
  let range = normalize_text_range_to_grapheme(text, normalized)
  let next_text = @core.replace_text_range(text, range, replacement)
  let caret = range.start +
    @core.TextGraphemeBoundaries::new(text=replacement).length()
  let boundaries = @core.TextGraphemeBoundaries::new(text=next_text)
  { text: next_text, caret: boundaries.clamp_index(caret), selection: None }
}

///|
fn surrounding_delete_range(
  text : String,
  caret : Int,
  before : Int,
  after : Int,
) -> @core.TextRange {
  let length = text_length(text)
  let before = max_int(0, before)
  let after = max_int(0, after)
  let range = @core.delete_grapheme_range(
    @core.TextGraphemeBoundaries::new(text~),
    caret,
    before,
    after,
  )
  @core.TextRange::new(
    start=clamp_int(range.start, 0, length),
    end=clamp_int(range.end, 0, length),
  )
}

///|
fn move_text_caret(
  text : String,
  caret : Int,
  selection : @core.TextRange?,
  direction : TextCaretDirection,
  extend~ : Bool,
) -> TextCaretMoveResult {
  let boundaries = @core.TextGraphemeBoundaries::new(text~)
  let length = boundaries.length()
  let caret = boundaries.clamp_index(caret)
  if extend {
    let anchor = boundaries.nearest_boundary(
      text_selection_anchor(caret, selection),
    )
    let next = move_text_caret_index(text, caret, direction)
    {
      caret: next,
      selection: if next == anchor {
        None
      } else {
        Some(@core.TextRange::new(start=anchor, end=next))
      },
    }
  } else {
    match active_text_selection(selection) {
      Some(selection) => {
        let selection = @core.normalize_grapheme_range(boundaries, selection)
        match direction {
          MoveLeft => { caret: selection.start, selection: None }
          MoveRight => { caret: selection.end, selection: None }
          MoveStart => { caret: 0, selection: None }
          MoveEnd => { caret: length, selection: None }
        }
      }
      None =>
        {
          caret: move_text_caret_index(text, caret, direction),
          selection: None,
        }
    }
  }
}

///|
fn text_selection_anchor(caret : Int, selection : @core.TextRange?) -> Int {
  match selection {
    Some(selection) =>
      if caret == selection.start {
        selection.end
      } else {
        selection.start
      }
    None => caret
  }
}

///|
fn move_text_caret_index(
  text : String,
  caret : Int,
  direction : TextCaretDirection,
) -> Int {
  let boundaries = @core.TextGraphemeBoundaries::new(text~)
  let length = boundaries.length()
  let caret = boundaries.clamp_index(caret)
  match direction {
    MoveLeft => boundaries.previous_boundary(caret)
    MoveRight => boundaries.next_boundary(caret)
    MoveStart => 0
    MoveEnd => length
  }
}

///|
fn select_text_control(
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
fn text_control_for_text(
  control : @core.TextControlStateContext,
  text : String,
) -> @core.TextControlStateContext {
  {
    ..control,
    caret: text_length(text),
    selection: None,
    text_selection_anchor: None,
    composition: None,
    composition_cursor: None,
  }
}

///|
fn[Msg] text_input_messages(
  on_input : ((String) -> Msg)?,
  text : String,
) -> Array[Msg] {
  match on_input {
    Some(handler) => [handler(text)]
    None => []
  }
}

///|
fn[Msg] option_message(message : Msg?) -> Array[Msg] {
  match message {
    Some(message) => [message]
    None => []
  }
}

///|
fn searchbar_text_frame(frame : @core.Rect, has_text~ : Bool) -> @core.Rect {
  @core.Rect::new(
    x=frame.origin.x + 32.0,
    y=frame.origin.y,
    width=if has_text {
      frame.size.width - 64.0
    } else {
      frame.size.width - 32.0
    },
    height=frame.size.height,
  ).inset(@core.Insets::symmetric(vertical=0.0))
}

///|
fn searchbar_clear_frame(frame : @core.Rect) -> @core.Rect {
  @core.Rect::new(
    x=frame.origin.x + frame.size.width - 26.0,
    y=frame.origin.y + (frame.size.height - 16.0) / 2.0,
    width=16.0,
    height=16.0,
  )
}

///|
fn text_length(text : String) -> Int {
  text.to_array().length()
}

///|
fn max_double(a : Double, b : Double) -> Double {
  if a >= b {
    a
  } else {
    b
  }
}

///|
fn max_int(a : Int, b : Int) -> Int {
  if a >= b {
    a
  } else {
    b
  }
}

///|
fn clamp_int(value : Int, min : Int, max : Int) -> Int {
  if value < min {
    min
  } else if value > max {
    max
  } else {
    value
  }
}
