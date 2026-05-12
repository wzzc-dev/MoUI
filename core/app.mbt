///|
pub(all) struct RuntimeState {
  mut root : ViewNode
  mut size : Size
  mut needs_redraw : Bool
  mut needs_rebuild : Bool
}

///|
pub fn RuntimeState::new(root~ : ViewNode, size~ : Size) -> RuntimeState {
  { root, size, needs_redraw: true, needs_rebuild: false }
}

///|
pub fn RuntimeState::set_root(self : RuntimeState, root : ViewNode) -> Unit {
  self.root = root
  self.needs_rebuild = false
  self.needs_redraw = true
}

///|
pub fn RuntimeState::dispatch_event(
  self : RuntimeState,
  event : AppEvent,
) -> Unit {
  match event {
    Resize(size) => {
      self.size = size
      self.needs_redraw = true
    }
    Redraw(_) => self.needs_redraw = false
    Pointer(event) => {
      let bounds = Rect::new(
        x=0.0,
        y=0.0,
        width=self.size.width,
        height=self.size.height,
      )
      let result = self.root.handle_pointer(event, bounds)
      self.root = result.node
      self.needs_redraw = self.needs_redraw || result.changed
      self.needs_rebuild = self.needs_rebuild || result.activated
    }
    Keyboard(_) => self.needs_redraw = true
    CloseRequested => ()
  }
}

///|
pub fn RuntimeState::layout(self : RuntimeState) -> LayoutResult {
  layout_node(
    self.root,
    Rect::new(x=0.0, y=0.0, width=self.size.width, height=self.size.height),
  )
}

///|
pub fn RuntimeState::build_draw_commands(
  self : RuntimeState,
) -> Array[DrawCommand] {
  let commands : Array[DrawCommand] = [Clear(Color::white())]
  self.root.paint(
    Rect::new(x=0.0, y=0.0, width=self.size.width, height=self.size.height),
    commands,
  )
  commands
}
