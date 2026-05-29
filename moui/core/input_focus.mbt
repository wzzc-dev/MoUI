///|
fn ElementNode::find_focusable_at(
  self : ElementNode,
  point : Point,
  render : RenderNode,
) -> ElementId? {
  match self.spec {
    TextFieldSpec(_)
    | CheckboxSpec(_)
    | ButtonSpec(_)
    | PickerSpec(_)
    | DatePickerSpec(_)
    | SearchBarSpec(_) =>
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
    | CustomLayoutSpec(_)
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
fn ElementNode::focusable_ids(
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
fn ElementNode::accepts_tab_input(
  self : ElementNode,
  target : ElementId,
) -> Bool {
  if self.id == target {
    match self.spec {
      RichTextEditorSpec(data) => data.accepts_tab_input
      _ => false
    }
  } else {
    for child in self.children {
      if child.accepts_tab_input(target) {
        return true
      }
    }
    false
  }
}

///|
fn ElementNode::next_focus(
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
  if event.key == "Tab" && data.accepts_tab_input {
    let text = if event.modifiers.shift { "\u{000b}" } else { "\t" }
    return handle_rich_text_editor_input(element, data, InsertText(text))
  }
  if is_select_all_shortcut(event) {
    return select_text_range(element, data.value.get())
  }
  if is_undo_shortcut(event) {
    let result = handle_rich_text_editor_command(
      element,
      data,
      Undo,
      paste_text=None,
    )
    return { changed: result.changed, activated: false, focused: None }
  }
  if is_redo_shortcut(event) {
    let result = handle_rich_text_editor_command(
      element,
      data,
      Redo,
      paste_text=None,
    )
    return { changed: result.changed, activated: false, focused: None }
  }
  if event.key == "Backspace" {
    match active_text_selection(element.control.selection) {
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
    match active_text_selection(element.control.selection) {
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
    return apply_rich_text_caret_move(
      element,
      data,
      move_text_caret(
        data.value.get(),
        element.control.caret,
        element.control.selection,
        MoveLeft,
        extend=event.modifiers.shift,
      ),
    )
  }
  if event.key == "ArrowRight" {
    return apply_rich_text_caret_move(
      element,
      data,
      move_text_caret(
        data.value.get(),
        element.control.caret,
        element.control.selection,
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
    element.control.caret = multiline_line_start(
      data.value.get(),
      element.control.caret,
    )
    element.control.selection = None
    notify_rich_text_selection_change(data, element)
    element.dirty.mark_paint()
    return { changed: true, activated: false, focused: None }
  }
  if event.key == "End" {
    element.control.caret = multiline_line_end(
      data.value.get(),
      element.control.caret,
    )
    element.control.selection = None
    notify_rich_text_selection_change(data, element)
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
