///|
pub fn ElementNode::dispatch_pointer(
  self : ElementNode,
  event : PointerEvent,
  render : RenderNode,
  text_system? : TextSystem = TextSystem::fallback(),
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
        self.caret = text_field_text_length(self.spec)
        self.selection = None
        self.composition = None
        self.composition_cursor = None
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
    | ScrollSpec(_)
    | GridSpec(_)
    | ListSpec(_)
    | CustomLayoutSpec(_)
    | ComponentSpec(_)
    | SheetSpec(_) =>
      self.dispatch_pointer_to_children(event, render, text_system~)
    ModifiedSpec(data) =>
      self.dispatch_modified_pointer(data, event, render, text_system~)
    EmptySpec | TextSpec(_) | ImageSpec(_) | SpacerSpec(_) | CustomSpec(_) =>
      { changed: false, activated: false, focused: None }
  }
}

///|
fn ElementNode::dispatch_pointer_to_children(
  self : ElementNode,
  event : PointerEvent,
  render : RenderNode,
  text_system~ : TextSystem,
) -> ElementEventResult {
  let mut changed = false
  let mut activated = false
  let mut focused : ElementId? = None
  let mut index = self.children.length() - 1
  while index >= 0 {
    if index < render.children.length() &&
      render.children[index].frame.contains(event.position) {
      let result = self.children[index].dispatch_pointer(
        event,
        render.children[index],
        text_system~,
      )
      changed = result.changed
      activated = result.activated
      match result.focused {
        Some(_) => focused = result.focused
        None => ()
      }
      if result.changed || result.activated || result.focused is Some(_) {
        break
      }
    }
    index = index - 1
  }
  if changed {
    self.dirty.mark_paint()
  }
  { changed, activated, focused }
}

///|
fn ElementNode::dispatch_modified_pointer(
  self : ElementNode,
  data : ModifiedViewSpec,
  event : PointerEvent,
  render : RenderNode,
  text_system~ : TextSystem,
) -> ElementEventResult {
  match data.modifier {
    DisabledModifier(true) =>
      { changed: false, activated: false, focused: None }
    OnTapModifier(handler) => {
      let child_result = self.dispatch_pointer_to_children(
        event,
        render,
        text_system~,
      )
      if child_result.activated {
        child_result
      } else {
        let inside = render.frame.contains(event.position)
        let tap = recognize_button_tap(self.button_state, inside, event.phase)
        if tap.activated {
          handler()
        }
        let changed = child_result.changed ||
          tap.next_state != self.button_state ||
          tap.activated
        self.button_state = tap.next_state
        if changed {
          self.dirty.mark_paint()
        }
        {
          changed,
          activated: child_result.activated || tap.activated,
          focused: child_result.focused,
        }
      }
    }
    _ => self.dispatch_pointer_to_children(event, render, text_system~)
  }
}

///|
pub fn ElementNode::hit_test_path(
  self : ElementNode,
  point : Point,
  render : RenderNode,
) -> HitTestResult {
  let path : Array[HitTestEntry] = []
  if self.append_hit_test_path(point, render, path) {
    { path, }
  } else {
    { path: [] }
  }
}

///|
fn ElementNode::append_hit_test_path(
  self : ElementNode,
  point : Point,
  render : RenderNode,
  path : Array[HitTestEntry],
) -> Bool {
  if !render.frame.contains(point) {
    false
  } else {
    path.push({
      element_id: self.id,
      local_position: Point::new(
        x=point.x - render.frame.origin.x,
        y=point.y - render.frame.origin.y,
      ),
      frame: render.frame,
    })
    let mut index = self.children.length() - 1
    while index >= 0 {
      if index < render.children.length() &&
        self.children[index].append_hit_test_path(
          point,
          render.children[index],
          path,
        ) {
        return true
      }
      index = index - 1
    }
    true
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
        element.caret = caret
        element.selection = None
        element.text_selection_anchor = Some(caret)
        element.composition = None
        element.composition_cursor = None
        notify_rich_text_selection_change(data, element)
        { changed: true, activated: false, focused: Some(element.id) }
      } else {
        { changed: false, activated: false, focused: None }
      }
    Move =>
      match element.text_selection_anchor {
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
          let changed = element.caret != caret ||
            element.selection != next_selection
          element.caret = caret
          element.selection = next_selection
          if changed {
            notify_rich_text_selection_change(data, element)
            element.dirty.mark_paint()
          }
          { changed, activated: false, focused: None }
        }
        None => { changed: false, activated: false, focused: None }
      }
    Up | Cancel => {
      element.text_selection_anchor = None
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
  let tap = recognize_button_tap(element.button_state, inside, event.phase)
  if tap.activated {
    match data.on_click {
      Some(handler) => handler()
      None => ()
    }
  }
  let changed = tap.next_state != element.button_state || tap.activated
  element.button_state = tap.next_state
  if changed {
    element.dirty.mark_paint()
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
    element.dirty.mark_paint()
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
  if element.picker_expanded {
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
      element.picker_expanded = false
      element.dirty.mark_paint()
      { changed: true, activated: false, focused: None }
    } else if main_button_clicked && list_frame.contains(event.position) {
      let clicked_y = event.position.y - list_frame.origin.y
      let clicked_index = (clicked_y / item_height).to_int()
      if clicked_index >= 0 && clicked_index < data.items.length() {
        let clicked_item = data.items[clicked_index]
        data.selected.set(clicked_item.id)
        element.picker_expanded = false
        element.dirty.mark_paint()
        { changed: true, activated: true, focused: None }
      } else {
        { changed: false, activated: false, focused: None }
      }
    } else {
      { changed: false, activated: false, focused: None }
    }
  } else if main_button_clicked {
    element.picker_expanded = true
    element.dirty.mark_paint()
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
  if element.datepicker_expanded {
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
      element.datepicker_expanded = false
      element.dirty.mark_paint()
      { changed: true, activated: false, focused: None }
    } else if main_button_clicked && panel_frame.contains(event.position) {
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
        let view_date = element.datepicker_view
        let new_view_date = if view_date.month == 1 {
          { ..view_date, year: view_date.year - 1, month: 12 }
        } else {
          { ..view_date, month: view_date.month - 1 }
        }
        element.datepicker_view = new_view_date
        element.dirty.mark_paint()
        { changed: true, activated: false, focused: None }
      } else if right_button_frame.contains(event.position) {
        // 右导航按钮：下一个月
        let view_date = element.datepicker_view
        let new_view_date = if view_date.month == 12 {
          { ..view_date, year: view_date.year + 1, month: 1 }
        } else {
          { ..view_date, month: view_date.month + 1 }
        }
        element.datepicker_view = new_view_date
        element.dirty.mark_paint()
        { changed: true, activated: false, focused: None }
      } else if event.position.y >= start_y {
        // 点击了日期单元格
        let year = element.datepicker_view.year
        let month = element.datepicker_view.month
        let q = 1
        let m = if month < 3 { month + 12 } else { month }
        let y = if month < 3 { year - 1 } else { year }
        let k = y % 100
        let j = y / 100
        let h = (q + 13 * (m + 1) / 5 + k + k / 4 + j / 4 + 5 * j) % 7
        let first_day_weekday = h

        let day_cell_width = panel_frame.size.width / 7.0
        let clicked_x = event.position.x - panel_frame.origin.x
        let clicked_y = event.position.y - start_y
        let col = (clicked_x / day_cell_width).to_int()
        let row = (clicked_y / cell_height).to_int()
        let total_index = row * 7 + col
        let day = total_index - first_day_weekday + 1

        let days_in_month_count = days_in_month(year, month)
        if day >= 1 && day <= days_in_month_count {
          // 有效日期，选中它
          let selected = data.selected.get()
          let new_selected = { ..selected, year, month, day }
          data.selected.set(new_selected)
          element.datepicker_expanded = false
          element.dirty.mark_paint()
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
  } else if main_button_clicked {
    // 打开日期选择器
    element.datepicker_expanded = true
    element.datepicker_view = data.selected.get()
    element.dirty.mark_paint()
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
      element.dirty.mark_paint()
      return { changed: true, activated: true, focused: Some(element.id) }
    }
  }

  // 否则，像 TextField 一样处理
  let focused = if event.phase == PointerPhase::Down &&
    frame.contains(event.position) {
    element.caret = text_length(text)
    element.selection = None
    element.composition = None
    element.composition_cursor = None
    Some(element.id)
  } else {
    None
  }
  { changed: false, activated: false, focused }
}
