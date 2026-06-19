///|
fn ElementNode::dispatch_pointer(
  self : ElementNode,
  event : PointerEvent,
  render : RenderNode,
  environment? : Environment = Environment::neutral(),
  style? : ViewStyle = ViewStyle::empty(),
  text_system? : TextSystem = TextSystem::fallback(),
  capture_lookup? : Bool = true,
  now_ms? : Double = 0.0,
) -> ElementEventResult {
  let child_result = self.dispatch_pointer_to_children(
    event,
    render,
    environment~,
    style~,
    text_system~,
    capture_lookup~,
    now_ms~,
  )
  if child_result.activated {
    child_result
  } else {
    let own = self.dispatch_view_event(
      self.erased_view_node,
      AppEvent::Pointer(event),
      render,
      text_system,
      environment~,
      style~,
      now_ms~,
    )
    {
      changed: child_result.changed || own.changed,
      activated: own.activated,
      focused: match own.focused {
        Some(value) => Some(value)
        None => child_result.focused
      },
    }
  }
}

///|
fn ElementNode::dispatch_view_event(
  self : ElementNode,
  data : ErasedViewNode,
  event : AppEvent,
  render : RenderNode,
  text_system : TextSystem,
  environment? : Environment = Environment::neutral(),
  style? : ViewStyle = ViewStyle::empty(),
  now_ms? : Double = 0.0,
) -> ElementEventResult {
  let result = (data.event)({
    frame: render.frame,
    child_frames: render.children.map(child => child.frame),
    event,
    focused: false,
    state: { ..data.state, focused: false },
    text_control: self.control.text_context(),
    text_system,
    environment,
    style,
    now_ms,
  })
  match result.state {
    Some(next_state) => self.erased_view_node = { ..data, state: next_state }
    None => ()
  }
  match result.text_control {
    Some(next_control) => self.control.apply_text_context(next_control)
    None => ()
  }
  self.apply_view_dirty_hint(result.dirty)
  {
    changed: result.changed || result.captured,
    activated: result.activated,
    focused: if result.focused {
      Some(self.id)
    } else {
      None
    },
  }
}

///|
fn ElementNode::apply_view_dirty_hint(
  self : ElementNode,
  dirty : ViewDirtyHint,
) -> Unit {
  match dirty {
    ViewClean => ()
    ViewPaintDirty => self.mark_pointer_paint_dirty()
    ViewLayoutDirty => {
      self.dirty.mark_layout()
      self.clear_cached_layout_and_paint()
    }
    ViewBuildDirty => {
      self.dirty.mark_build()
      self.clear_cached_layout_and_paint()
    }
  }
}

///|
fn ElementNode::mark_pointer_paint_dirty(self : ElementNode) -> Unit {
  self.dirty.mark_paint()
  self.render_cache.clear()
}

///|
fn ElementNode::dispatch_pointer_to_children(
  self : ElementNode,
  event : PointerEvent,
  render : RenderNode,
  environment~ : Environment,
  style~ : ViewStyle,
  text_system~ : TextSystem,
  capture_lookup~ : Bool,
  now_ms~ : Double,
) -> ElementEventResult {
  let mut changed = false
  let mut activated = false
  let mut focused : ElementId? = None
  let mut layout_changed = false
  let child_environment = (self.erased_view_node.child_environment)(environment)
  let child_style = (self.erased_view_node.child_style)(style)
  let mut index = self.children.length() - 1
  while index >= 0 {
    if index < render.children.length() {
      let child = self.children[index]
      let child_render = render.children[index]
      let has_capture = capture_lookup &&
        child.has_active_pointer_capture(event.phase)
      if has_capture || child_render.hit_bounds().contains(event.position) {
        let result = child.dispatch_pointer(
          event,
          child_render,
          environment=child_environment,
          style=child_style,
          text_system~,
          capture_lookup~,
          now_ms~,
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
fn RenderNode::hit_bounds(self : RenderNode) -> Rect {
  self.paint_bounds
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
fn ElementNode::has_local_active_pointer_capture(_self : ElementNode) -> Bool {
  false
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
  environment? : Environment = Environment::neutral(),
  style? : ViewStyle = ViewStyle::empty(),
  text_system~ : TextSystem,
  now_ms? : Double = 0.0,
) -> ElementEventResult? {
  if self.id == target {
    Some(
      self.dispatch_pointer(
        event,
        render,
        environment~,
        style~,
        text_system~,
        capture_lookup=false,
        now_ms~,
      ),
    )
  } else {
    let child_environment = (self.erased_view_node.child_environment)(
      environment,
    )
    let child_style = (self.erased_view_node.child_style)(style)
    let mut index = 0
    while index < self.children.length() {
      if index < render.children.length() {
        match
          self.children[index].dispatch_pointer_to_target(
            target,
            event,
            render.children[index],
            environment=child_environment,
            style=child_style,
            text_system~,
            now_ms~,
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
