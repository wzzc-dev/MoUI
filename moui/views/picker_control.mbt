///|
priv struct PickerOption {
  id : String
  label : String
}

///|
fn PickerOption::new(id~ : String, label~ : String) -> PickerOption {
  { id, label }
}

///|
fn PickerOption::id(self : PickerOption) -> String {
  self.id
}

///|
fn PickerOption::label(self : PickerOption) -> String {
  self.label
}

///|
fn[Msg] picker_control(
  items~ : Array[PickerOption],
  selected~ : @core.Binding[String],
  placeholder~ : String,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  background~ : @core.Brush,
  corner_radius~ : Double,
  max_height~ : Double,
  on_select? : ((String) -> Msg)? = None,
  kind? : String = "Picker",
  key? : String? = None,
) -> @core.View[Msg] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind~, key~),
    revision=() => {
      "picker:\{picker_items_revision(items)}:\{selected.get()}:\{placeholder}:\{view_font_revision(font)}:\{view_color_revision(foreground)}:\{view_brush_revision(background)}:\{corner_radius}:\{max_height}:\{on_select is Some(_)}"
    },
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(
          @core.Size::new(width=200.0, height=40.0),
        ),
      )
    },
    paint=ctx => {
      let commands : Array[@core.DrawCommand] = []
      let overlay_commands : Array[@core.DrawCommand] = []
      append_picker_commands(
        commands,
        overlay_commands,
        frame=ctx.frame,
        items~,
        selected_id=selected.get(),
        placeholder~,
        font~,
        foreground~,
        background~,
        corner_radius~,
        max_height~,
        expanded=ctx.state.expanded,
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
      match ctx.event {
        @core.AppEvent::Pointer(event) =>
          handle_picker_pointer(
            ctx.state,
            event,
            frame=ctx.frame,
            items~,
            selected~,
            max_height~,
            on_select~,
          )
        @core.AppEvent::Keyboard(event) =>
          handle_picker_keyboard(
            ctx.state,
            event,
            items~,
            selected~,
            on_select~,
          )
        _ => @core.ViewEventResult::ignored()
      }
    },
    semantics=() => {
      @core.ViewSemanticsInfo::new(
        role=@core.SemanticsRole::Menu,
        label=placeholder,
        value=picker_selected_label(items, selected.get(), placeholder),
        actions=[@core.SemanticsAction::Focus, @core.SemanticsAction::Activate],
      )
    },
    focusable=() => true,
  )
}

///|
fn append_picker_commands(
  commands : Array[@core.DrawCommand],
  overlay_commands : Array[@core.DrawCommand],
  frame~ : @core.Rect,
  items~ : Array[PickerOption],
  selected_id~ : String,
  placeholder~ : String,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  background~ : @core.Brush,
  corner_radius~ : Double,
  max_height~ : Double,
  expanded~ : Bool,
) -> Unit {
  let theme = @core.Theme::neutral()
  let rounded = @core.RoundedRect::new(rect=frame, radius=corner_radius)
  commands.push(@core.DrawCommand::FillRoundedRectBrush(rounded, background))
  commands.push(
    @core.DrawCommand::StrokeRoundedRectBrush(
      rounded,
      @core.Brush::solid(theme.palette.surface_variant),
      1.0,
    ),
  )
  let selected_label = picker_selected_label(items, selected_id, placeholder)
  commands.push(
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text=selected_label,
        frame=frame.inset(
          @core.Insets::symmetric(horizontal=12.0, vertical=0.0),
        ),
        font~,
        color=foreground,
        align=@core.TextAlign::TextStart,
      ),
    ),
  )
  let arrow_size = 12.0
  let arrow_frame = @core.Rect::new(
    x=frame.origin.x + frame.size.width - arrow_size - 12.0,
    y=frame.origin.y + (frame.size.height - arrow_size) / 2.0,
    width=arrow_size,
    height=arrow_size,
  )
  commands.push(
    @core.DrawCommand::DrawText(
      @core.TextRun::new(
        text=if expanded { "▲" } else { "▼" },
        frame=arrow_frame,
        font=@core.FontSpec::new(size=arrow_size * 0.9, weight=400),
        color=foreground,
        align=@core.TextAlign::TextCenter,
      ),
    ),
  )
  if expanded {
    append_picker_popup_commands(
      overlay_commands,
      frame~,
      items~,
      selected_id~,
      font~,
      foreground~,
      background~,
      corner_radius~,
      max_height~,
    )
  }
}

///|
fn append_picker_popup_commands(
  overlay_commands : Array[@core.DrawCommand],
  frame~ : @core.Rect,
  items~ : Array[PickerOption],
  selected_id~ : String,
  font~ : @core.FontSpec,
  foreground~ : @core.Color,
  background~ : @core.Brush,
  corner_radius~ : Double,
  max_height~ : Double,
) -> Unit {
  let theme = @core.Theme::neutral()
  let list_frame = picker_popup_frame(items, frame, max_height)
  let list_rounded = @core.RoundedRect::new(
    rect=list_frame,
    radius=corner_radius,
  )
  overlay_commands.push(
    @core.DrawCommand::DrawShadow(
      @core.ShadowSpec::new(
        rect=list_rounded,
        color=@core.Color::black().with_alpha(0.15),
        offset=@core.Point::new(x=0.0, y=4.0),
        blur_radius=12.0,
        spread=0.0,
      ),
    ),
  )
  overlay_commands.push(
    @core.DrawCommand::FillRoundedRectBrush(list_rounded, background),
  )
  for index, item in items {
    let item_frame = picker_item_frame(list_frame, index)
    let is_selected = item.id() == selected_id
    if is_selected {
      overlay_commands.push(
        @core.DrawCommand::FillRoundedRectBrush(
          @core.RoundedRect::new(
            rect=item_frame.inset(
              @core.Insets::symmetric(horizontal=4.0, vertical=2.0),
            ),
            radius=4.0,
          ),
          @core.Brush::solid(theme.palette.primary.with_alpha(0.1)),
        ),
      )
    }
    overlay_commands.push(
      @core.DrawCommand::DrawText(
        @core.TextRun::new(
          text=item.label(),
          frame=item_frame.inset(
            @core.Insets::symmetric(horizontal=12.0, vertical=0.0),
          ),
          font~,
          color=if is_selected { theme.palette.primary } else { foreground },
          align=@core.TextAlign::TextStart,
        ),
      ),
    )
  }
}

///|
fn[Msg] handle_picker_pointer(
  state : @core.ViewStateContext,
  event : @core.PointerEvent,
  frame~ : @core.Rect,
  items~ : Array[PickerOption],
  selected~ : @core.Binding[String],
  max_height~ : Double,
  on_select~ : ((String) -> Msg)?,
) -> @core.ViewEventResult[Msg] {
  let inside_button = frame.contains(event.position)
  let popup_frame = picker_popup_frame(items, frame, max_height)
  let inside_popup = popup_frame.contains(event.position)
  if state.expanded {
    if event.phase == @core.PointerPhase::Up && inside_popup {
      match picker_item_id_at_position(items, popup_frame, event.position) {
        Some(id) => {
          selected.set(id)
          view_event_result(
            changed=true,
            activated=true,
            captured=true,
            state=Some({ ..state, expanded: false }),
            dirty=@core.ViewDirtyHint::ViewPaintDirty,
            messages=picker_messages(on_select, id),
          )
        }
        None =>
          view_event_result(
            changed=true,
            captured=true,
            state=Some({ ..state, expanded: false }),
            dirty=@core.ViewDirtyHint::ViewPaintDirty,
          )
      }
    } else if event.phase == @core.PointerPhase::Up && inside_button {
      view_event_result(
        changed=true,
        captured=true,
        state=Some({ ..state, expanded: false }),
        dirty=@core.ViewDirtyHint::ViewPaintDirty,
      )
    } else if event.phase == @core.PointerPhase::Up {
      view_event_result(
        changed=true,
        captured=true,
        state=Some({ ..state, expanded: false }),
        dirty=@core.ViewDirtyHint::ViewPaintDirty,
      )
    } else if inside_button || inside_popup {
      view_event_result(changed=true, captured=true)
    } else {
      @core.ViewEventResult::ignored()
    }
  } else if event.phase == @core.PointerPhase::Up && inside_button {
    view_event_result(
      changed=true,
      captured=true,
      state=Some({ ..state, expanded: true }),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
    )
  } else {
    @core.ViewEventResult::ignored()
  }
}

///|
fn[Msg] handle_picker_keyboard(
  state : @core.ViewStateContext,
  event : @core.KeyboardEvent,
  items~ : Array[PickerOption],
  selected~ : @core.Binding[String],
  on_select~ : ((String) -> Msg)?,
) -> @core.ViewEventResult[Msg] {
  if !event.pressed {
    @core.ViewEventResult::ignored()
  } else if event.key == "Escape" && state.expanded {
    view_event_result(
      changed=true,
      captured=true,
      state=Some({ ..state, expanded: false }),
      dirty=@core.ViewDirtyHint::ViewPaintDirty,
    )
  } else if event.key == "Enter" || event.key == "Space" || event.key == " " {
    if state.expanded {
      match picker_selected_id_or_first(items, selected.get()) {
        Some(id) => {
          selected.set(id)
          view_event_result(
            changed=true,
            activated=true,
            captured=true,
            state=Some({ ..state, expanded: false }),
            dirty=@core.ViewDirtyHint::ViewPaintDirty,
            messages=picker_messages(on_select, id),
          )
        }
        None =>
          view_event_result(
            changed=true,
            captured=true,
            state=Some({ ..state, expanded: false }),
            dirty=@core.ViewDirtyHint::ViewPaintDirty,
          )
      }
    } else {
      view_event_result(
        changed=true,
        captured=true,
        state=Some({ ..state, expanded: true }),
        dirty=@core.ViewDirtyHint::ViewPaintDirty,
      )
    }
  } else {
    @core.ViewEventResult::ignored()
  }
}

///|
fn[Msg] picker_messages(
  on_select : ((String) -> Msg)?,
  id : String,
) -> Array[Msg] {
  match on_select {
    Some(handler) => [handler(id)]
    None => []
  }
}

///|
fn picker_selected_label(
  items : Array[PickerOption],
  selected_id : String,
  placeholder : String,
) -> String {
  let mut label = placeholder
  for item in items {
    if item.id() == selected_id {
      label = item.label()
      break
    }
  }
  label
}

///|
fn picker_selected_id_or_first(
  items : Array[PickerOption],
  selected_id : String,
) -> String? {
  let mut selected : String? = None
  for item in items {
    if item.id() == selected_id {
      selected = Some(item.id())
      break
    }
  }
  match selected {
    Some(id) => Some(id)
    None =>
      match items.get(0) {
        Some(item) => Some(item.id())
        None => None
      }
  }
}

///|
fn picker_item_id_at_position(
  items : Array[PickerOption],
  list_frame : @core.Rect,
  position : @core.Point,
) -> String? {
  let index = ((position.y - list_frame.origin.y) / picker_item_height()).to_int()
  if index >= 0 && index < items.length() {
    Some(items[index].id())
  } else {
    None
  }
}

///|
fn picker_popup_frame(
  items : Array[PickerOption],
  frame : @core.Rect,
  max_height : Double,
) -> @core.Rect {
  @core.Rect::new(
    x=frame.origin.x,
    y=frame.origin.y + frame.size.height + 4.0,
    width=frame.size.width,
    height=view_min_double(
      max_height,
      items.length().to_double() * picker_item_height(),
    ),
  )
}

///|
fn picker_item_frame(list_frame : @core.Rect, index : Int) -> @core.Rect {
  @core.Rect::new(
    x=list_frame.origin.x,
    y=list_frame.origin.y + index.to_double() * picker_item_height(),
    width=list_frame.size.width,
    height=picker_item_height(),
  )
}

///|
fn picker_item_height() -> Double {
  36.0
}

///|
fn picker_items_revision(items : Array[PickerOption]) -> String {
  let mut result = ""
  for item in items {
    result = "\{result}|\{item.id()}:\{item.label()}"
  }
  result
}
