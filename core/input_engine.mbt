///|
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
        self.composition_cursor = None
        Some(self.id)
      } else {
        None
      }
      { changed: false, activated: false, focused }
    }
    RichTextEditorSpec(_) => {
      let focused = if event.phase == PointerPhase::Down &&
        render.frame.contains(event.position) {
        self.caret = rich_text_editor_text_length(self.spec)
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
    | ComponentSpec(_) => self.dispatch_pointer_to_children(event, render)
    ModifiedSpec(data) => self.dispatch_modified_pointer(data, event, render)
    EmptySpec | TextSpec(_) | ImageSpec(_) | SpacerSpec(_) | CustomSpec(_) =>
      { changed: false, activated: false, focused: None }
  }
}

///|
fn ElementNode::dispatch_pointer_to_children(
  self : ElementNode,
  event : PointerEvent,
  render : RenderNode,
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

///|
fn ElementNode::dispatch_modified_pointer(
  self : ElementNode,
  data : ModifiedViewSpec,
  event : PointerEvent,
  render : RenderNode,
) -> ElementEventResult {
  match data.modifier {
    DisabledModifier(true) =>
      { changed: false, activated: false, focused: None }
    OnTapModifier(handler) => {
      let child_result = self.dispatch_pointer_to_children(event, render)
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
    _ => self.dispatch_pointer_to_children(event, render)
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
fn rich_text_editor_text_length(spec : ViewSpec) -> Int {
  match spec {
    RichTextEditorSpec(data) => text_length(data.value.get())
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
pub fn ElementNode::find_focusable_at(
  self : ElementNode,
  point : Point,
  render : RenderNode,
) -> ElementId? {
  match self.spec {
    TextFieldSpec(_) | CheckboxSpec(_) | ButtonSpec(_) =>
      if render.frame.contains(point) {
        Some(self.id)
      } else {
        None
      }
    RichTextEditorSpec(_) =>
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
    | ComponentSpec(_) => {
      let mut index = self.children.length() - 1
      while index >= 0 {
        if index < render.children.length() &&
          render.children[index].frame.contains(point) {
          match
            self.children[index].find_focusable_at(
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
    ModifiedSpec(data) =>
      match data.modifier {
        DisabledModifier(true) => None
        FocusableModifier(true) =>
          if render.frame.contains(point) {
            Some(self.id)
          } else {
            None
          }
        _ => {
          let mut index = self.children.length() - 1
          while index >= 0 {
            if index < render.children.length() &&
              render.children[index].frame.contains(point) {
              match
                self.children[index].find_focusable_at(
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
    TextFieldSpec(_)
    | RichTextEditorSpec(_)
    | ButtonSpec(_)
    | CheckboxSpec(_) => ids.push(self.id)
    ModifiedSpec(data) =>
      match data.modifier {
        DisabledModifier(true) => ()
        FocusableModifier(true) => ids.push(self.id)
        _ =>
          for child in self.children {
            child.focusable_ids(ids)
          }
      }
    FlexSpec(_)
    | PaddingSpec(_)
    | ContainerSpec(_)
    | FrameSpec(_)
    | StackSpec(_)
    | ScrollSpec(_)
    | GridSpec(_)
    | ListSpec(_)
    | ComponentSpec(_) =>
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
  if self.spec is ModifiedSpec({ modifier: DisabledModifier(true), .. }) {
    return { changed: false, activated: false, focused: None }
  }
  if self.id == target {
    match self.spec {
      TextFieldSpec(data) => handle_text_field_keyboard(self, data, event)
      RichTextEditorSpec(data) =>
        handle_rich_text_editor_keyboard(self, data, event)
      ButtonSpec(data) => handle_button_keyboard(self, data, event)
      CheckboxSpec(data) => handle_checkbox_keyboard(self, data, event)
      ModifiedSpec(data) => handle_focused_modified_keyboard(self, data, event)
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
  if self.spec is ModifiedSpec({ modifier: DisabledModifier(true), .. }) {
    return { changed: false, activated: false, focused: None }
  }
  if self.id == target {
    match self.spec {
      TextFieldSpec(data) => handle_text_field_input(self, data, event)
      RichTextEditorSpec(data) =>
        handle_rich_text_editor_input(self, data, event)
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
pub fn ElementNode::dispatch_keyboard_shortcut(
  self : ElementNode,
  event : KeyboardEvent,
) -> ElementEventResult {
  match self.spec {
    ModifiedSpec(data) =>
      match data.modifier {
        DisabledModifier(true) =>
          { changed: false, activated: false, focused: None }
        KeyboardShortcutModifier(shortcut) =>
          if shortcut.matches(event) {
            self.activate_primary()
          } else {
            self.dispatch_keyboard_shortcut_to_children(event)
          }
        _ => self.dispatch_keyboard_shortcut_to_children(event)
      }
    _ => self.dispatch_keyboard_shortcut_to_children(event)
  }
}

///|
fn ElementNode::dispatch_keyboard_shortcut_to_children(
  self : ElementNode,
  event : KeyboardEvent,
) -> ElementEventResult {
  let mut changed = false
  let mut activated = false
  for child in self.children {
    let result = child.dispatch_keyboard_shortcut(event)
    changed = changed || result.changed
    activated = activated || result.activated
    if result.activated {
      break
    }
  }
  if changed {
    self.dirty.mark_paint()
  }
  { changed, activated, focused: None }
}

///|
fn ElementNode::activate_primary(self : ElementNode) -> ElementEventResult {
  match self.spec {
    ButtonSpec(data) => {
      match data.on_click {
        Some(handler) => handler()
        None => ()
      }
      self.dirty.mark_paint()
      { changed: true, activated: true, focused: None }
    }
    CheckboxSpec(data) => {
      data.checked.set(!data.checked.get())
      self.dirty.mark_paint()
      { changed: true, activated: true, focused: None }
    }
    ModifiedSpec(data) =>
      match data.modifier {
        DisabledModifier(true) =>
          { changed: false, activated: false, focused: None }
        OnTapModifier(handler) => {
          handler()
          self.dirty.mark_paint()
          { changed: true, activated: true, focused: None }
        }
        _ => self.activate_first_child()
      }
    _ => self.activate_first_child()
  }
}

///|
fn ElementNode::activate_first_child(self : ElementNode) -> ElementEventResult {
  for child in self.children {
    let result = child.activate_primary()
    if result.activated || result.changed {
      return result
    }
  }
  { changed: false, activated: false, focused: None }
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
    match active_text_selection(element.selection) {
      Some(selection) =>
        return handle_text_field_input(element, data, DeleteRange(selection))
      None =>
        return handle_text_field_input(element, data, DeleteSurrounding(1, 0))
    }
  }
  if event.key == "Delete" {
    match active_text_selection(element.selection) {
      Some(selection) =>
        return handle_text_field_input(element, data, DeleteRange(selection))
      None =>
        return handle_text_field_input(element, data, DeleteSurrounding(0, 1))
    }
  }
  if event.key == "ArrowLeft" {
    return apply_text_caret_move(
      element,
      move_text_caret(
        data.value.get(),
        element.caret,
        element.selection,
        MoveLeft,
        extend=event.modifiers.shift,
      ),
    )
  }
  if event.key == "ArrowRight" {
    return apply_text_caret_move(
      element,
      move_text_caret(
        data.value.get(),
        element.caret,
        element.selection,
        MoveRight,
        extend=event.modifiers.shift,
      ),
    )
  }
  if event.key == "Home" {
    return apply_text_caret_move(
      element,
      move_text_caret(
        data.value.get(),
        element.caret,
        element.selection,
        MoveStart,
        extend=event.modifiers.shift,
      ),
    )
  }
  if event.key == "End" {
    return apply_text_caret_move(
      element,
      move_text_caret(
        data.value.get(),
        element.caret,
        element.selection,
        MoveEnd,
        extend=event.modifiers.shift,
      ),
    )
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
fn handle_rich_text_editor_keyboard(
  element : ElementNode,
  data : RichTextEditorViewSpec,
  event : KeyboardEvent,
) -> ElementEventResult {
  if !event.pressed {
    return { changed: false, activated: false, focused: None }
  }
  if event.key == "Enter" {
    return handle_rich_text_editor_input(element, data, InsertText("\n"))
  }
  if event.key == "Backspace" {
    match active_text_selection(element.selection) {
      Some(selection) =>
        return handle_rich_text_editor_input(
          element,
          data,
          DeleteRange(selection),
        )
      None =>
        return handle_rich_text_editor_input(
          element,
          data,
          DeleteSurrounding(1, 0),
        )
    }
  }
  if event.key == "Delete" {
    match active_text_selection(element.selection) {
      Some(selection) =>
        return handle_rich_text_editor_input(
          element,
          data,
          DeleteRange(selection),
        )
      None =>
        return handle_rich_text_editor_input(
          element,
          data,
          DeleteSurrounding(0, 1),
        )
    }
  }
  if event.key == "ArrowLeft" {
    return apply_text_caret_move(
      element,
      move_text_caret(
        data.value.get(),
        element.caret,
        element.selection,
        MoveLeft,
        extend=event.modifiers.shift,
      ),
    )
  }
  if event.key == "ArrowRight" {
    return apply_text_caret_move(
      element,
      move_text_caret(
        data.value.get(),
        element.caret,
        element.selection,
        MoveRight,
        extend=event.modifiers.shift,
      ),
    )
  }
  if event.key == "ArrowUp" {
    return move_multiline_caret_vertical(element, data, -1)
  }
  if event.key == "ArrowDown" {
    return move_multiline_caret_vertical(element, data, 1)
  }
  if event.key == "Home" {
    element.caret = multiline_line_start(data.value.get(), element.caret)
    element.selection = None
    element.dirty.mark_paint()
    return { changed: true, activated: false, focused: None }
  }
  if event.key == "End" {
    element.caret = multiline_line_end(data.value.get(), element.caret)
    element.selection = None
    element.dirty.mark_paint()
    return { changed: true, activated: false, focused: None }
  }
  match event.text {
    Some(text) =>
      if text != "" {
        handle_rich_text_editor_input(element, data, InsertText(text))
      } else {
        { changed: false, activated: false, focused: None }
      }
    None => { changed: false, activated: false, focused: None }
  }
}

///|
fn handle_button_keyboard(
  element : ElementNode,
  data : ButtonViewSpec,
  event : KeyboardEvent,
) -> ElementEventResult {
  if event.pressed &&
    (event.key == "Enter" || event.key == "Space" || event.key == " ") {
    match data.on_click {
      Some(handler) => handler()
      None => ()
    }
    element.dirty.mark_paint()
    { changed: true, activated: true, focused: None }
  } else {
    { changed: false, activated: false, focused: None }
  }
}

///|
fn handle_focused_modified_keyboard(
  element : ElementNode,
  data : ModifiedViewSpec,
  event : KeyboardEvent,
) -> ElementEventResult {
  match data.modifier {
    DisabledModifier(true) =>
      { changed: false, activated: false, focused: None }
    FocusableModifier(true) =>
      if event.pressed &&
        (event.key == "Enter" || event.key == "Space" || event.key == " ") {
        element.activate_first_child()
      } else {
        { changed: false, activated: false, focused: None }
      }
    _ => { changed: false, activated: false, focused: None }
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
      element.composition_cursor = None
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
          element.composition_cursor = Some(TextRange::new(start~, end~))
        }
        None => element.composition_cursor = None
      }
      element.dirty.mark_paint()
      { changed: true, activated: false, focused: None }
    }
    CompositionEnd(text) => {
      element.composition = None
      element.composition_cursor = None
      if text == "" {
        element.selection = None
        element.dirty.mark_paint()
        { changed: true, activated: false, focused: None }
      } else {
        let edit = replace_current_selection(
          data.value.get(),
          element.caret,
          element.selection,
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
