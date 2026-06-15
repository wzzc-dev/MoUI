///|
fn ElementNode::dispatch_drag_drop(
  self : ElementNode,
  event : DragDropEvent,
  render : RenderNode,
) -> ElementEventResult {
  match self.spec {
    ModifiedSpec(data) => self.dispatch_modified_drag_drop(data, event, render)
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
    | SheetSpec(_) => self.dispatch_drag_drop_to_children(event, render)
    _ => { changed: false, activated: false, focused: None }
  }
}

///|
fn ElementNode::dispatch_drag_drop_to_children(
  self : ElementNode,
  event : DragDropEvent,
  render : RenderNode,
) -> ElementEventResult {
  match event.position {
    Some(position) => {
      let mut changed = false
      let mut activated = false
      let mut index = self.children.length() - 1
      while index >= 0 {
        if index < render.children.length() &&
          render.children[index].frame.contains(position) {
          let result = self.children[index].dispatch_drag_drop(
            event,
            render.children[index],
          )
          changed = changed || result.changed
          activated = activated || result.activated
          if result.changed || result.activated {
            break
          }
        }
        index = index - 1
      }
      if changed {
        self.dirty.mark_paint()
      }
      { changed, activated, focused: None }
    }
    None => { changed: false, activated: false, focused: None }
  }
}

///|
fn ElementNode::dispatch_modified_drag_drop(
  self : ElementNode,
  data : ModifiedViewSpec,
  event : DragDropEvent,
  render : RenderNode,
) -> ElementEventResult {
  match data.modifier {
    DisabledModifier(true) =>
      { changed: false, activated: false, focused: None }
    OnFileDropModifier(handler) => {
      let child_result = self.dispatch_drag_drop_to_children(event, render)
      if child_result.activated {
        child_result
      } else {
        match (event.phase, event.position) {
          (Dropped, Some(position)) =>
            if render.frame.contains(position) && event.paths.length() > 0 {
              handler(event.paths, position)
              self.dirty.mark_paint()
              { changed: true, activated: true, focused: None }
            } else {
              { changed: false, activated: false, focused: None }
            }
          _ => child_result
        }
      }
    }
    _ => self.dispatch_drag_drop_to_children(event, render)
  }
}
