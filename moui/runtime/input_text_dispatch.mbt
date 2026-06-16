///|
fn ElementNode::dispatch_text_input(
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
      SearchBarSpec(data) => handle_searchbar_input(self, data, event)
      RichTextEditorSpec(data) =>
        handle_rich_text_editor_input(self, data, event)
      WidgetSpec(data) =>
        self.dispatch_widget_event(
          data,
          AppEvent::TextInput(event),
          RenderNode::empty(),
          TextSystem::fallback(),
        )
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
