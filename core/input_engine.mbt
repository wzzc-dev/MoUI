pub fn ElementNode::dispatch_pointer(
  self : ElementNode,
  event : PointerEvent,
  render : RenderNode,
) -> ElementEventResult {
  match self.spec {
    ButtonSpec(data) =>
      handle_button_element_pointer(self, data, event, render.frame)
    CheckboxSpec(data) =>
      handle_checkbox_element_pointer(self, data, event, render.frame)
    TextFieldSpec(_) => {
      let focused = if event.phase == PointerPhase::Down &&
        render.frame.contains(event.position) {
        self.caret = text_field_text_length(self.spec)
        self.selection = None
        self.composition = None
        Some(self.id)
      } else {
        None
      }
      { changed: false, activated: false, focused }
    }
    FlexSpec(_)
    | PaddingSpec(_)
    | ContainerSpec(_)
    | FrameSpec(_)
    | StackSpec(_)
    | ScrollSpec(_)
    | GridSpec(_)
    | ListSpec(_)
    | ModifiedSpec(_) => {
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
          )
          changed = result.changed
          activated = result.activated
          match result.focused {
            Some(_) => focused = result.focused
            None => ()
          }
          break
        }
        index = index - 1
      }
      if changed {
        self.dirty.mark_paint()
      }
      { changed, activated, focused }
    }
    EmptySpec | TextSpec(_) | ImageSpec(_) | SpacerSpec(_) =>
      { changed: false, activated: false, focused: None }
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
pub fn ElementNode::find_text_field_at(
  self : ElementNode,
  point : Point,
  render : RenderNode,
) -> ElementId? {
  match self.spec {
    TextFieldSpec(_) =>
      if render.frame.contains(point) {
        Some(self.id)
      } else {
        None
      }
    FlexSpec(_)
    | PaddingSpec(_)
    | ContainerSpec(_)
    | FrameSpec(_)
    | StackSpec(_)
    | ScrollSpec(_)
    | GridSpec(_)
    | ListSpec(_)
    | ModifiedSpec(_) => {
      let mut index = self.children.length() - 1
      while index >= 0 {
        if index < render.children.length() &&
          render.children[index].frame.contains(point) {
          match
            self.children[index].find_text_field_at(
              point,
              render.children[index],
            ) {
            Some(id) => return Some(id)
            None => ()
          }
        }
        index = index - 1
      }
      None
    }
    _ => None
  }
}

///|
pub fn ElementNode::focusable_ids(
  self : ElementNode,
  ids : Array[ElementId],
) -> Unit {
  match self.spec {
    TextFieldSpec(_) | CheckboxSpec(_) => ids.push(self.id)
    FlexSpec(_)
    | PaddingSpec(_)
    | ContainerSpec(_)
    | FrameSpec(_)
    | StackSpec(_)
    | ScrollSpec(_)
    | GridSpec(_)
    | ListSpec(_)
    | ModifiedSpec(_) =>
      for child in self.children {
        child.focusable_ids(ids)
      }
    _ => ()
  }
}

///|
pub fn ElementNode::next_focus(
  self : ElementNode,
  current~ : ElementId?,
  reverse~ : Bool,
) -> ElementId? {
  let ids : Array[ElementId] = []
  self.focusable_ids(ids)
  if ids.length() == 0 {
    None
  } else {
    let mut index = -1
    match current {
      Some(current) =>
        for i, id in ids {
          if id == current {
            index = i
          }
        }
      None => ()
    }
    if reverse {
      let next = if index <= 0 { ids.length() - 1 } else { index - 1 }
      Some(ids[next])
    } else {
      let next = if index < 0 || index + 1 >= ids.length() {
        0
      } else {
        index + 1
      }
      Some(ids[next])
    }
  }
}

///|
pub fn ElementNode::find_keyed(self : ElementNode, key : String) -> ElementId? {
  if self.key == Some(Key::new(key)) {
    Some(self.id)
  } else {
    for child in self.children {
      match child.find_keyed(key) {
        Some(id) => return Some(id)
        None => ()
      }
    }
    None
  }
}

///|
pub fn ElementNode::dispatch_keyboard(
  self : ElementNode,
  target : ElementId,
  event : KeyboardEvent,
) -> ElementEventResult {
  if self.id == target {
    match self.spec {
      TextFieldSpec(data) => handle_text_field_keyboard(self, data, event)
      CheckboxSpec(data) => handle_checkbox_keyboard(self, data, event)
      _ => { changed: false, activated: false, focused: None }
    }
  } else {
    let mut changed = false
    let mut activated = false
    for child in self.children {
      let result = child.dispatch_keyboard(target, event)
      changed = changed || result.changed
      activated = activated || result.activated
    }
    if changed {
      self.dirty.mark_paint()
    }
    { changed, activated, focused: None }
  }
}

///|
pub fn ElementNode::dispatch_text_input(
  self : ElementNode,
  target : ElementId,
  event : TextInputEvent,
) -> ElementEventResult {
  if self.id == target {
    match self.spec {
      TextFieldSpec(data) => handle_text_field_input(self, data, event)
      _ => { changed: false, activated: false, focused: None }
    }
  } else {
    let mut changed = false
    let mut activated = false
    for child in self.children {
      let result = child.dispatch_text_input(target, event)
      changed = changed || result.changed
      activated = activated || result.activated
    }
    if changed {
      self.dirty.mark_paint()
    }
    { changed, activated, focused: None }
  }
}

///|
fn handle_text_field_keyboard(
  element : ElementNode,
  data : TextFieldViewSpec,
  event : KeyboardEvent,
) -> ElementEventResult {
  if !event.pressed {
    return { changed: false, activated: false, focused: None }
  }
  if event.key == "Enter" {
    match data.on_submit {
      Some(handler) => handler()
      None => ()
    }
    element.dirty.mark_paint()
    return { changed: true, activated: true, focused: None }
  }
  if event.key == "Backspace" {
    return handle_text_field_input(
      element,
      data,
      DeleteSurrounding(1, 0),
    )
  }
  if event.key == "Delete" {
    return handle_text_field_input(
      element,
      data,
      DeleteSurrounding(0, 1),
    )
  }
  if event.key == "ArrowLeft" {
    element.caret = clamp_int(element.caret - 1, 0, text_length(data.value.get()))
    element.selection = None
    element.dirty.mark_paint()
    return { changed: true, activated: false, focused: None }
  }
  if event.key == "ArrowRight" {
    element.caret = clamp_int(element.caret + 1, 0, text_length(data.value.get()))
    element.selection = None
    element.dirty.mark_paint()
    return { changed: true, activated: false, focused: None }
  }
  match event.text {
    Some(text) =>
      if text != "" {
        handle_text_field_input(element, data, InsertText(text))
      } else {
        { changed: false, activated: false, focused: None }
      }
    None => { changed: false, activated: false, focused: None }
  }
}

///|
fn handle_checkbox_keyboard(
  element : ElementNode,
  data : CheckboxViewSpec,
  event : KeyboardEvent,
) -> ElementEventResult {
  if event.pressed &&
    (event.key == "Enter" || event.key == "Space" || event.key == " ") {
    data.checked.set(!data.checked.get())
    element.dirty.mark_paint()
    { changed: true, activated: true, focused: None }
  } else {
    { changed: false, activated: false, focused: None }
  }
}

///|
fn handle_text_field_input(
  element : ElementNode,
  data : TextFieldViewSpec,
  event : TextInputEvent,
) -> ElementEventResult {
  match event {
    InsertText(text) => {
      if text == "" {
        return { changed: false, activated: false, focused: None }
      }
      let edit = replace_current_selection(
        data.value.get(),
        element.caret,
        element.selection,
        text,
      )
      apply_text_edit(element, data, edit)
    }
    CompositionStart => {
      element.composition = Some("")
      element.selection = None
      element.dirty.mark_paint()
      { changed: true, activated: false, focused: None }
    }
    CompositionUpdate(update) => {
      element.composition = if update.text == "" {
        None
      } else {
        Some(update.text)
      }
      match update.cursor {
        Some(cursor) => {
          let normalized = cursor.normalized()
          let start = clamp_int(normalized.start, 0, text_length(update.text))
          let end = clamp_int(normalized.end, 0, text_length(update.text))
          element.selection = Some(TextRange::new(start~, end~))
        }
        None => ()
      }
      element.dirty.mark_paint()
      { changed: true, activated: false, focused: None }
    }
    CompositionEnd(text) => {
      element.composition = None
      element.selection = None
      if text == "" {
        element.dirty.mark_paint()
        { changed: true, activated: false, focused: None }
      } else {
        let edit = replace_current_selection(
          data.value.get(),
          element.caret,
          None,
          text,
        )
        apply_text_edit(element, data, edit)
      }
    }
    DeleteRange(range) => {
      let edit = replace_text_range(data.value.get(), range, "")
      apply_text_edit(element, data, edit)
    }
    DeleteSurrounding(before, after) => {
      let text = data.value.get()
      let range = surrounding_delete_range(text, element.caret, before, after)
      let edit = replace_text_range(text, range, "")
      apply_text_edit(element, data, edit)
    }
  }
}
