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
      SearchBarSpec(data) => handle_searchbar_keyboard(self, data, event)
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
  if is_select_all_shortcut(event) {
    return select_text_range(element, data.value.get())
  }
  if is_undo_shortcut(event) {
    let result = handle_text_field_command(element, data, Undo, paste_text=None)
    return { changed: result.changed, activated: false, focused: None }
  }
  if is_redo_shortcut(event) {
    let result = handle_text_field_command(element, data, Redo, paste_text=None)
    return { changed: result.changed, activated: false, focused: None }
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
fn is_select_all_shortcut(event : KeyboardEvent) -> Bool {
  event.pressed &&
  (event.key == "a" || event.key == "A") &&
  (event.modifiers.meta || event.modifiers.control)
}

///|
fn is_undo_shortcut(event : KeyboardEvent) -> Bool {
  event.pressed &&
  (event.key == "z" || event.key == "Z") &&
  !event.modifiers.shift &&
  (event.modifiers.meta || event.modifiers.control)
}

///|
fn is_redo_shortcut(event : KeyboardEvent) -> Bool {
  event.pressed &&
  (event.key == "z" || event.key == "Z") &&
  event.modifiers.shift &&
  (event.modifiers.meta || event.modifiers.control)
}

///|
fn select_text_range(
  element : ElementNode,
  text : String,
) -> ElementEventResult {
  let length = text_length(text)
  element.caret = length
  element.selection = Some(TextRange::new(start=0, end=length))
  element.composition = None
  element.composition_cursor = None
  element.dirty.mark_paint()
  { changed: true, activated: false, focused: None }
}

///|
fn handle_searchbar_keyboard(
  element : ElementNode,
  data : SearchBarViewSpec,
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
  if is_select_all_shortcut(event) {
    return select_text_range(element, data.query.get())
  }
  if is_undo_shortcut(event) {
    let result = handle_searchbar_command(element, data, Undo, paste_text=None)
    return { changed: result.changed, activated: false, focused: None }
  }
  if is_redo_shortcut(event) {
    let result = handle_searchbar_command(element, data, Redo, paste_text=None)
    return { changed: result.changed, activated: false, focused: None }
  }
  if event.key == "Backspace" {
    match active_text_selection(element.selection) {
      Some(selection) =>
        return handle_searchbar_input(element, data, DeleteRange(selection))
      None =>
        return handle_searchbar_input(element, data, DeleteSurrounding(1, 0))
    }
  }
  if event.key == "Delete" {
    match active_text_selection(element.selection) {
      Some(selection) =>
        return handle_searchbar_input(element, data, DeleteRange(selection))
      None =>
        return handle_searchbar_input(element, data, DeleteSurrounding(0, 1))
    }
  }
  if event.key == "ArrowLeft" {
    return apply_text_caret_move(
      element,
      move_text_caret(
        data.query.get(),
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
        data.query.get(),
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
        data.query.get(),
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
        data.query.get(),
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
        handle_searchbar_input(element, data, InsertText(text))
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
