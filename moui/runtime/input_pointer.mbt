///|
fn ElementNode::dispatch_pointer(
  self : ElementNode,
  event : PointerEvent,
  render : RenderNode,
  text_system? : TextSystem = TextSystem::fallback(),
  capture_lookup? : Bool = true,
) -> ElementEventResult {
  match self.spec {
    ButtonSpec(data) =>
      handle_button_element_pointer(self, data, event, render.frame)
    CheckboxSpec(data) =>
      handle_checkbox_element_pointer(self, data, event, render.frame)
    PickerSpec(data) =>
      handle_picker_element_pointer(self, data, event, render.frame)
    DatePickerSpec(data) =>
      handle_datepicker_element_pointer(self, data, event, render.frame)
    SearchBarSpec(data) =>
      handle_searchbar_element_pointer(self, data, event, render.frame)
    TextFieldSpec(_) => {
      let focused = if event.phase == PointerPhase::Down &&
        render.frame.contains(event.position) {
        self.control.caret = text_field_text_length(self.spec)
        self.control.selection = None
        self.control.composition = None
        self.control.composition_cursor = None
        Some(self.id)
      } else {
        None
      }
      { changed: false, activated: false, focused }
    }
    RichTextEditorSpec(data) =>
      handle_rich_text_editor_pointer(self, data, event, render, text_system)
    FlexSpec(_)
    | PaddingSpec(_)
    | ContainerSpec(_)
    | FrameSpec(_)
    | StackSpec(_)
    | GridSpec(_)
    | ListSpec(_)
    | CustomLayoutSpec(_)
    | ComponentSpec(_) =>
      self.dispatch_pointer_to_children(
        event,
        render,
        text_system~,
        capture_lookup~,
      )
    SheetSpec(data) =>
      self.dispatch_sheet_pointer(
        data,
        event,
        render,
        text_system~,
        capture_lookup~,
      )
    ScrollSpec(data) =>
      self.dispatch_scroll_pointer(
        data,
        event,
        render,
        text_system~,
        capture_lookup~,
      )
    ModifiedSpec(data) =>
      self.dispatch_modified_pointer(
        data,
        event,
        render,
        text_system~,
        capture_lookup~,
      )
    EmptySpec
    | TextSpec(_)
    | ImageSpec(_)
    | WebViewHostSpec(_)
    | SpacerSpec(_)
    | CustomSpec(_) => { changed: false, activated: false, focused: None }
  }
}

///|
fn ElementNode::mark_pointer_paint_dirty(self : ElementNode) -> Unit {
  self.dirty.mark_paint()
  self.render_cache.clear()
}

///|
fn ElementNode::dispatch_scroll_pointer(
  self : ElementNode,
  data : ScrollViewSpec,
  event : PointerEvent,
  render : RenderNode,
  text_system~ : TextSystem,
  capture_lookup~ : Bool,
) -> ElementEventResult {
  if render.frame.contains(event.position) &&
    (event.wheel_delta.x != 0.0 || event.wheel_delta.y != 0.0) {
    match data.on_scroll {
      Some(handler) => {
        handler(event.wheel_delta)
        match data.scroll_state {
          Some(state) => {
            clamp_scroll_state_to_render(state, data, render)
            self.spec = ScrollSpec({ ..data, offset: state.offset() })
          }
          None => ()
        }
        if data.scroll_state is Some(_) && !data.scroll_activates {
          self.mark_pointer_paint_dirty()
        } else {
          self.dirty.mark_layout()
          self.clear_cached_layout_and_paint()
        }
        { changed: true, activated: data.scroll_activates, focused: None }
      }
      None =>
        self.dispatch_pointer_to_children(
          event,
          render,
          text_system~,
          capture_lookup~,
        )
    }
  } else {
    self.dispatch_pointer_to_children(
      event,
      render,
      text_system~,
      capture_lookup~,
    )
  }
}

///|
fn clamp_scroll_state_to_render(
  state : ScrollState,
  data : ScrollViewSpec,
  render : RenderNode,
) -> Unit {
  let viewport = data.viewport.unwrap_or(render.frame.size)
  let content = if render.children.length() > 0 {
    Size::new(
      width=max_double(
        render.children[0].frame.size.width,
        render.children[0].paint_bounds.size.width,
      ),
      height=max_double(
        render.children[0].frame.size.height,
        render.children[0].paint_bounds.size.height,
      ),
    )
  } else {
    viewport
  }
  let current = state.offset()
  state.scroll_to(
    x=clamp_double(
      current.x,
      0.0,
      max_double(0.0, content.width - viewport.width),
    ),
    y=clamp_double(
      current.y,
      0.0,
      max_double(0.0, content.height - viewport.height),
    ),
  )
}

///|
fn ElementNode::dispatch_pointer_to_children(
  self : ElementNode,
  event : PointerEvent,
  render : RenderNode,
  text_system~ : TextSystem,
  capture_lookup~ : Bool,
) -> ElementEventResult {
  let popup_result = self.dispatch_pointer_to_popup_children(
    event,
    render,
    text_system~,
    capture_lookup~,
  )
  if popup_result.changed ||
    popup_result.activated ||
    popup_result.focused is Some(_) {
    return popup_result
  }
  self.dispatch_pointer_to_child_frames(
    event,
    render,
    text_system~,
    capture_lookup~,
  )
}

///|
fn ElementNode::dispatch_pointer_to_popup_children(
  self : ElementNode,
  event : PointerEvent,
  render : RenderNode,
  text_system~ : TextSystem,
  capture_lookup~ : Bool,
) -> ElementEventResult {
  let mut changed = false
  let mut activated = false
  let mut focused : ElementId? = None
  let mut layout_changed = false
  let mut index = self.children.length() - 1
  while index >= 0 {
    if index < render.children.length() {
      let child = self.children[index]
      let child_render = render.children[index]
      let has_capture = capture_lookup &&
        child.has_active_pointer_capture(event.phase)
      if child.expanded_popup_contains(event.position, child_render.frame) ||
        has_capture {
        let result = child.dispatch_pointer(
          event,
          child_render,
          text_system~,
          capture_lookup~,
        )
        changed = result.changed
        activated = result.activated
        layout_changed = result.changed && child.has_dirty_layout()
        match result.focused {
          Some(_) => focused = result.focused
          None => ()
        }
        if has_capture ||
          result.changed ||
          result.activated ||
          result.focused is Some(_) {
          break
        }
      }
    }
    index = index - 1
  }
  if changed {
    if layout_changed {
      self.dirty.mark_layout()
      self.clear_cached_layout_and_paint()
    } else {
      self.mark_pointer_paint_dirty()
    }
  }
  { changed, activated, focused }
}

///|
fn ElementNode::dispatch_pointer_to_child_frames(
  self : ElementNode,
  event : PointerEvent,
  render : RenderNode,
  text_system~ : TextSystem,
  capture_lookup~ : Bool,
) -> ElementEventResult {
  let mut changed = false
  let mut activated = false
  let mut focused : ElementId? = None
  let mut layout_changed = false
  let mut index = self.children.length() - 1
  while index >= 0 {
    if index < render.children.length() {
      let child = self.children[index]
      let child_render = render.children[index]
      if child_render.frame.contains(event.position) {
        let result = child.dispatch_pointer(
          event,
          child_render,
          text_system~,
          capture_lookup~,
        )
        changed = result.changed
        activated = result.activated
        layout_changed = result.changed && child.has_dirty_layout()
        match result.focused {
          Some(_) => focused = result.focused
          None => ()
        }
        if result.changed || result.activated || result.focused is Some(_) {
          break
        }
      }
    }
    index = index - 1
  }
  if changed {
    if layout_changed {
      self.dirty.mark_layout()
      self.clear_cached_layout_and_paint()
    } else {
      self.mark_pointer_paint_dirty()
    }
  }
  { changed, activated, focused }
}

///|
fn ElementNode::has_active_pointer_capture(
  self : ElementNode,
  phase : PointerPhase,
) -> Bool {
  if phase == PointerPhase::Down {
    false
  } else if self.has_local_active_pointer_capture() {
    true
  } else {
    self.children.any(child => child.has_active_pointer_capture(phase))
  }
}

///|
fn ElementNode::has_local_active_pointer_capture(self : ElementNode) -> Bool {
  self.control.button_state == ButtonState::Pressed ||
  self.control.long_press_gesture.phase == LongPressGesturePhase::Pressing ||
  self.control.drag_gesture.phase == DragGesturePhase::Pending ||
  self.control.drag_gesture.phase == DragGesturePhase::Started ||
  self.control.drag_gesture.phase == DragGesturePhase::Changed
}

///|
fn ElementNode::active_pointer_capture_id(
  self : ElementNode,
  phase : PointerPhase,
) -> ElementId? {
  if phase == PointerPhase::Down {
    None
  } else if self.has_local_active_pointer_capture() {
    Some(self.id)
  } else {
    let mut index = self.children.length() - 1
    while index >= 0 {
      match self.children[index].active_pointer_capture_id(phase) {
        Some(id) => return Some(id)
        None => ()
      }
      index = index - 1
    }
    None
  }
}

///|
fn ElementNode::dispatch_pointer_to_target(
  self : ElementNode,
  target : ElementId,
  event : PointerEvent,
  render : RenderNode,
  text_system~ : TextSystem,
) -> ElementEventResult? {
  if self.id == target {
    Some(
      self.dispatch_pointer(event, render, text_system~, capture_lookup=false),
    )
  } else {
    let mut index = 0
    while index < self.children.length() {
      if index < render.children.length() {
        match
          self.children[index].dispatch_pointer_to_target(
            target,
            event,
            render.children[index],
            text_system~,
          ) {
          Some(result) => {
            if result.changed {
              self.mark_pointer_paint_dirty()
            }
            return Some(result)
          }
          None => ()
        }
      }
      index = index + 1
    }
    None
  }
}

///|
fn ElementNode::expanded_popup_contains(
  self : ElementNode,
  position : Point,
  frame : Rect,
) -> Bool {
  match self.spec {
    PickerSpec(data) =>
      self.control.picker_expanded &&
      picker_popup_frame(data, frame).contains(position)
    DatePickerSpec(_) =>
      self.control.datepicker_expanded &&
      datepicker_popup_frame(frame).contains(position)
    _ => false
  }
}

///|
fn picker_popup_frame(data : PickerViewSpec, frame : Rect) -> Rect {
  let item_height = 36.0
  let count = data.items.length().to_double()
  Rect::new(
    x=frame.origin.x,
    y=frame.origin.y + frame.size.height + 4.0,
    width=frame.size.width,
    height=min_double(data.maxHeight, count * item_height),
  )
}

///|
fn datepicker_popup_frame(frame : Rect) -> Rect {
  Rect::new(
    x=frame.origin.x,
    y=frame.origin.y + frame.size.height + 4.0,
    width=max_double(frame.size.width, 280.0),
    height=350.0,
  )
}

///|
fn ElementNode::dispatch_sheet_pointer(
  self : ElementNode,
  data : SheetViewSpec,
  event : PointerEvent,
  render : RenderNode,
  text_system~ : TextSystem,
  capture_lookup~ : Bool,
) -> ElementEventResult {
  let child_result = self.dispatch_pointer_to_children(
    event,
    render,
    text_system~,
    capture_lookup~,
  )
  if child_result.activated {
    child_result
  } else {
    let outside_content = event.phase == PointerPhase::Up &&
      render.frame.contains(event.position) &&
      render.children.length() > 0 &&
      !render.children[0].frame.contains(event.position)
    if outside_content {
      match data.on_dismiss {
        Some(handler) => {
          handler()
          { changed: true, activated: true, focused: child_result.focused }
        }
        None =>
          if render.frame.contains(event.position) {
            { changed: true, activated: false, focused: child_result.focused }
          } else {
            child_result
          }
      }
    } else if render.frame.contains(event.position) {
      { changed: true, activated: false, focused: child_result.focused }
    } else {
      child_result
    }
  }
}

///|
fn ElementNode::dispatch_modified_pointer(
  self : ElementNode,
  data : ModifiedViewSpec,
  event : PointerEvent,
  render : RenderNode,
  text_system~ : TextSystem,
  capture_lookup~ : Bool,
) -> ElementEventResult {
  match data.modifier {
    DisabledModifier(true) =>
      { changed: false, activated: false, focused: None }
    OnTapModifier(handler) => {
      let child_result = self.dispatch_pointer_to_children(
        event,
        render,
        text_system~,
        capture_lookup~,
      )
      if child_result.activated {
        child_result
      } else {
        let inside = render.frame.contains(event.position)
        let tap = recognize_button_tap(
          self.control.button_state,
          inside,
          event.phase,
        )
        if tap.activated {
          handler()
        }
        let changed = child_result.changed ||
          tap.next_state != self.control.button_state ||
          tap.activated
        self.control.button_state = tap.next_state
        if changed {
          self.mark_pointer_paint_dirty()
        }
        {
          changed,
          activated: child_result.activated || tap.activated,
          focused: child_result.focused,
        }
      }
    }
    OnLongPressModifier(handler) => {
      let child_result = self.dispatch_pointer_to_children(
        event,
        render,
        text_system~,
        capture_lookup~,
      )
      if child_result.activated {
        child_result
      } else {
        let result = self.control.long_press_gesture.update(
          event,
          inside=render.frame.contains(event.position),
        )
        self.control.long_press_gesture = result.state
        if result.recognized {
          handler()
          self.mark_pointer_paint_dirty()
        }
        {
          changed: child_result.changed || result.recognized || result.cancelled,
          activated: result.recognized,
          focused: child_result.focused,
        }
      }
    }
    OnDoubleTapModifier(handler) => {
      let child_result = self.dispatch_pointer_to_children(
        event,
        render,
        text_system~,
        capture_lookup~,
      )
      if child_result.activated {
        child_result
      } else {
        let result = self.control.double_tap_gesture.update(
          event,
          inside=render.frame.contains(event.position),
        )
        self.control.double_tap_gesture = result.state
        if result.recognized {
          handler()
          self.mark_pointer_paint_dirty()
        }
        {
          changed: child_result.changed ||
          event.phase == PointerPhase::Up ||
          result.recognized,
          activated: result.recognized,
          focused: child_result.focused,
        }
      }
    }
    OnDragModifier(handler) =>
      self.dispatch_drag_modifier_pointer(
        event,
        render,
        text_system~,
        capture_lookup~,
        handler=(drag_event, _frame) => handler(drag_event),
      )
    OnDragWithFrameModifier(handler) =>
      self.dispatch_drag_modifier_pointer(
        event,
        render,
        text_system~,
        capture_lookup~,
        handler~,
      )
    _ =>
      self.dispatch_pointer_to_children(
        event,
        render,
        text_system~,
        capture_lookup~,
      )
  }
}

///|
fn ElementNode::dispatch_drag_modifier_pointer(
  self : ElementNode,
  event : PointerEvent,
  render : RenderNode,
  text_system~ : TextSystem,
  capture_lookup~ : Bool,
  handler~ : (DragGestureEvent, Rect) -> Unit,
) -> ElementEventResult {
  let child_result = self.dispatch_pointer_to_children(
    event,
    render,
    text_system~,
    capture_lookup~,
  )
  if child_result.activated {
    child_result
  } else {
    let content_frame = if render.children.length() > 0 {
      render.children[0].frame
    } else {
      render.frame
    }
    let result = self.control.drag_gesture.update(
      event,
      inside=render.frame.contains(event.position),
    )
    self.control.drag_gesture = result.state
    match result.event {
      Some(drag_event) => handler(drag_event, content_frame)
      None => ()
    }
    let activated = result.event is Some(_)
    if activated {
      self.mark_pointer_paint_dirty()
    }
    {
      changed: child_result.changed ||
      event.phase != PointerPhase::Move ||
      activated,
      activated,
      focused: child_result.focused,
    }
  }
}

///|
fn text_field_text_length(spec : ViewSpec) -> Int {
  match spec {
    TextFieldSpec(data) => text_length(data.value.get())
    _ => 0
  }
}

///|
fn handle_rich_text_editor_pointer(
  element : ElementNode,
  data : RichTextEditorViewSpec,
  event : PointerEvent,
  render : RenderNode,
  text_system : TextSystem,
) -> ElementEventResult {
  let inside = render.frame.contains(event.position)
  match event.phase {
    Down =>
      if inside {
        match data.on_prefix_click {
          Some(handler) =>
            match
              rich_text_editor_prefix_source_offset_at_point(
                data,
                event.position,
                render.frame,
                text_system,
              ) {
              Some(offset) => handler(offset)
              None => ()
            }
          None => ()
        }
        let caret = rich_text_editor_caret_at_point(
          data,
          event.position,
          render.frame,
          text_system,
        )
        element.control.caret = caret
        element.control.selection = None
        element.control.text_selection_anchor = Some(caret)
        element.control.composition = None
        element.control.composition_cursor = None
        notify_rich_text_selection_change(data, element)
        { changed: true, activated: false, focused: Some(element.id) }
      } else {
        { changed: false, activated: false, focused: None }
      }
    Move =>
      match element.control.text_selection_anchor {
        Some(anchor) => {
          let caret = rich_text_editor_caret_at_point(
            data,
            event.position,
            render.frame,
            text_system,
          )
          let next_selection : TextRange? = if caret == anchor {
            None
          } else {
            Some(TextRange::new(start=anchor, end=caret))
          }
          let changed = element.control.caret != caret ||
            element.control.selection != next_selection
          element.control.caret = caret
          element.control.selection = next_selection
          if changed {
            notify_rich_text_selection_change(data, element)
            element.mark_pointer_paint_dirty()
          }
          { changed, activated: false, focused: None }
        }
        None => { changed: false, activated: false, focused: None }
      }
    Up | Cancel => {
      element.control.text_selection_anchor = None
      { changed: false, activated: false, focused: None }
    }
  }
}

///|
fn handle_button_element_pointer(
  element : ElementNode,
  data : ButtonViewSpec,
  event : PointerEvent,
  frame : Rect,
) -> ElementEventResult {
  let inside = frame.contains(event.position)
  let tap = recognize_button_tap(
    element.control.button_state,
    inside,
    event.phase,
  )
  if tap.activated {
    match data.on_click {
      Some(handler) => handler()
      None => ()
    }
  }
  let changed = tap.next_state != element.control.button_state || tap.activated
  element.control.button_state = tap.next_state
  if changed {
    element.mark_pointer_paint_dirty()
  }
  { changed, activated: tap.activated, focused: None }
}

///|
fn handle_checkbox_element_pointer(
  element : ElementNode,
  data : CheckboxViewSpec,
  event : PointerEvent,
  frame : Rect,
) -> ElementEventResult {
  if event.phase == PointerPhase::Up && frame.contains(event.position) {
    data.checked.set(!data.checked.get())
    element.mark_pointer_paint_dirty()
    { changed: true, activated: true, focused: None }
  } else {
    { changed: false, activated: false, focused: None }
  }
}

///|
fn handle_picker_element_pointer(
  element : ElementNode,
  data : PickerViewSpec,
  event : PointerEvent,
  frame : Rect,
) -> ElementEventResult {
  let main_button_clicked = event.phase == PointerPhase::Up &&
    frame.contains(event.position)
  if element.control.picker_expanded {
    let item_height = 36.0
    let count = data.items.length().to_double()
    let list_height = min_double(data.maxHeight, count * item_height)
    let list_frame = Rect::new(
      x=frame.origin.x,
      y=frame.origin.y + frame.size.height + 4.0,
      width=frame.size.width,
      height=list_height,
    )
    if main_button_clicked && !list_frame.contains(event.position) {
      element.control.picker_expanded = false
      element.mark_pointer_paint_dirty()
      { changed: true, activated: false, focused: None }
    } else if event.phase == PointerPhase::Up &&
      list_frame.contains(event.position) {
      let clicked_y = event.position.y - list_frame.origin.y
      let clicked_index = (clicked_y / item_height).to_int()
      if clicked_index >= 0 && clicked_index < data.items.length() {
        let clicked_item = data.items[clicked_index]
        data.selected.set(clicked_item.id())
        element.control.picker_expanded = false
        element.mark_pointer_paint_dirty()
        { changed: true, activated: true, focused: None }
      } else {
        { changed: false, activated: false, focused: None }
      }
    } else {
      { changed: false, activated: false, focused: None }
    }
  } else if main_button_clicked {
    element.control.picker_expanded = true
    element.mark_pointer_paint_dirty()
    { changed: true, activated: false, focused: None }
  } else {
    { changed: false, activated: false, focused: None }
  }
}

///|
fn handle_datepicker_element_pointer(
  element : ElementNode,
  data : DatePickerViewSpec,
  event : PointerEvent,
  frame : Rect,
) -> ElementEventResult {
  let main_button_clicked = event.phase == PointerPhase::Up &&
    frame.contains(event.position)
  if element.control.datepicker_expanded {
    let panel_width = max_double(frame.size.width, 280.0)
    let panel_height = 350.0
    let panel_frame = Rect::new(
      x=frame.origin.x,
      y=frame.origin.y + frame.size.height + 4.0,
      width=panel_width,
      height=panel_height,
    )
    if main_button_clicked && !panel_frame.contains(event.position) {
      // 点击了外部区域，收起面板
      element.control.datepicker_expanded = false
      element.mark_pointer_paint_dirty()
      { changed: true, activated: false, focused: None }
    } else if event.phase == PointerPhase::Up &&
      panel_frame.contains(event.position) {
      // 点击了面板内容，处理各种情况
      let header_height = 50.0
      let day_header_height = 36.0
      let cell_height = 36.0
      let start_y = panel_frame.origin.y + header_height + day_header_height

      let button_size = 32.0
      let left_button_frame = Rect::new(
        x=panel_frame.origin.x + 8.0,
        y=panel_frame.origin.y + (header_height - button_size) / 2.0,
        width=button_size,
        height=button_size,
      )
      let right_button_frame = Rect::new(
        x=panel_frame.origin.x + panel_frame.size.width - button_size - 8.0,
        y=panel_frame.origin.y + (header_height - button_size) / 2.0,
        width=button_size,
        height=button_size,
      )

      if left_button_frame.contains(event.position) {
        // 左导航按钮：上一个月
        let view_date = element.control.datepicker_view
        let new_view_date = if view_date.month == 1 {
          { ..view_date, year: view_date.year - 1, month: 12 }
        } else {
          { ..view_date, month: view_date.month - 1 }
        }
        element.control.datepicker_view = new_view_date
        element.mark_pointer_paint_dirty()
        { changed: true, activated: false, focused: None }
      } else if right_button_frame.contains(event.position) {
        // 右导航按钮：下一个月
        let view_date = element.control.datepicker_view
        let new_view_date = if view_date.month == 12 {
          { ..view_date, year: view_date.year + 1, month: 1 }
        } else {
          { ..view_date, month: view_date.month + 1 }
        }
        element.control.datepicker_view = new_view_date
        element.mark_pointer_paint_dirty()
        { changed: true, activated: false, focused: None }
      } else if event.position.y >= start_y {
        // 点击了日期单元格
        let year = element.control.datepicker_view.year
        let month = element.control.datepicker_view.month
        let first_day_weekday = first_weekday_of_month_sunday0(year, month)

        let day_cell_width = panel_frame.size.width / 7.0
        let clicked_x = event.position.x - panel_frame.origin.x
        let clicked_y = event.position.y - start_y
        let col = (clicked_x / day_cell_width).to_int()
        let row = (clicked_y / cell_height).to_int()
        let total_index = row * 7 + col
        let day = total_index - first_day_weekday + 1

        let days_in_month_count = days_in_month(year, month)
        if day >= 1 && day <= days_in_month_count {
          let selected = data.selected.get()
          let new_selected = { ..selected, year, month, day }
          if date_value_in_range(new_selected, data.min_date, data.max_date) {
            data.selected.set(new_selected)
            element.control.datepicker_expanded = false
            element.mark_pointer_paint_dirty()
            { changed: true, activated: true, focused: None }
          } else {
            { changed: false, activated: false, focused: None }
          }
        } else {
          { changed: false, activated: false, focused: None }
        }
      } else {
        { changed: false, activated: false, focused: None }
      }
    } else {
      { changed: false, activated: false, focused: None }
    }
  } else if main_button_clicked {
    // 打开日期选择器
    element.control.datepicker_expanded = true
    element.control.datepicker_view = data.selected.get()
    element.mark_pointer_paint_dirty()
    { changed: true, activated: false, focused: None }
  } else {
    { changed: false, activated: false, focused: None }
  }
}

///|
fn handle_searchbar_element_pointer(
  element : ElementNode,
  data : SearchBarViewSpec,
  event : PointerEvent,
  frame : Rect,
) -> ElementEventResult {
  // 检查是否点击了清除按钮
  let text = data.query.get()
  if text != "" {
    let clear_frame = Rect::new(
      x=frame.origin.x + frame.size.width - 26.0,
      y=frame.origin.y + (frame.size.height - 16.0) / 2.0,
      width=16.0,
      height=16.0,
    )
    if event.phase == PointerPhase::Up && clear_frame.contains(event.position) {
      data.query.set("")
      match data.on_clear {
        Some(on_clear) => on_clear()
        None => ()
      }
      element.mark_pointer_paint_dirty()
      return { changed: true, activated: true, focused: Some(element.id) }
    }
  }

  // 否则，像 TextField 一样处理
  let focused = if event.phase == PointerPhase::Down &&
    frame.contains(event.position) {
    element.control.caret = text_length(text)
    element.control.selection = None
    element.control.composition = None
    element.control.composition_cursor = None
    Some(element.id)
  } else {
    None
  }
  { changed: false, activated: false, focused }
}
