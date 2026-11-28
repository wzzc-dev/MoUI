///|
/// Cursor resolution over the live element/render trees.
///
/// The pointer cursor is a *presentation fact of the hit chain*, so it is
/// resolved the same way focus pickup and pointer dispatch find a target: walk
/// the render tree front-to-back, descend into the child that covers the
/// point, and stop at the deepest declaration. `Inherit` keeps walking back up
/// the chain, which is why this returns `None` ("no declaration in this
/// subtree") instead of substituting a default: the caller merges the result
/// with the ancestor's own declaration.
///
/// Deliberately read-only. Nothing here mutates element state, marks damage, or
/// dispatches an event, so a pointer move that crosses a `.cursor(...)` region
/// costs one tree walk and no repaint.
fn ElementNode::resolve_cursor_at(
  self : ElementNode,
  point : Point,
  render : RenderNode,
  node_to_screen~ : Transform2D = Transform2D::identity(),
  clip~ : Rect? = None,
) -> @core.CursorStyle? {
  let own_screen_frame = render.screen_frame(node_to_screen)
  let child_clip : Rect? = if render.clips_children {
    Some(runtime_clip_intersection(clip, own_screen_frame))
  } else {
    clip
  }
  // Hoisted overlay surfaces win over in-flow content painted underneath them,
  // top-most first — the same precedence pointer dispatch applies. Without it a
  // popup opened over a splitter would inherit the splitter's resize cursor.
  let mut overlay_index = self.children.length() - 1
  while overlay_index >= 0 {
    if overlay_index < render.children.length() {
      let child_render = render.children[overlay_index]
      if child_render.is_overlay_child || child_render.has_overlay_descendant {
        let child_to_screen = render.child_to_screen(
          node_to_screen, child_render,
        )
        let overlay_hit = (
            child_render.is_overlay_child &&
            runtime_point_hits_frame(
              point,
              child_render.screen_frame(child_to_screen),
              None,
            )
          ) ||
          child_render.subtree_overlay_contains_in_screen(
            point, child_to_screen,
          )
        if overlay_hit {
          match
            self.children[overlay_index].resolve_cursor_at(
              point,
              child_render,
              node_to_screen=child_to_screen,
              clip=None,
            ) {
            Some(style) => return Some(style)
            None => ()
          }
        }
      }
    }
    overlay_index = overlay_index - 1
  }
  // In-flow children, front-to-back (reverse paint order). An overlay child has
  // already been offered the point above; visiting it here as well would let a
  // popup owner fall back to its own in-flow frame after the popup itself said
  // "no declaration".
  let mut index = self.children.length() - 1
  while index >= 0 {
    if index < render.children.length() {
      let child_render = render.children[index]
      if !child_render.is_overlay_child {
        let child_to_screen = render.child_to_screen(
          node_to_screen, child_render,
        )
        if runtime_point_hits_frame(
            point,
            child_render.screen_frame(child_to_screen),
            child_clip,
          ) {
          match
            self.children[index].resolve_cursor_at(
              point,
              child_render,
              node_to_screen=child_to_screen,
              clip=child_clip,
            ) {
            Some(style) => return Some(style)
            None => ()
          }
        }
      }
    }
    index = index - 1
  }
  let own = self.view_node.pointer_cursor()
  if own.is_inherit() {
    None
  } else {
    Some(own)
  }
}

///|
/// Resolve the cursor at an explicit point, including the out-of-window reset.
fn RuntimeState::resolve_cursor_at(
  self : RuntimeState,
  point : @core.Point,
) -> @core.CursorStyle {
  // A pointer outside the window surface shows the arrow even though the last
  // sample still hits the root declaration: this is the "pointer left the
  // window" reset, and hosts report it as an out-of-bounds `Exit` rather than as
  // a separate leave event.
  let inside = point.x >= 0.0 &&
    point.y >= 0.0 &&
    point.x < self.size.width &&
    point.y < self.size.height
  if !inside {
    return @core.CursorStyle::Default
  }
  match self.element_tree.root.resolve_cursor_at(point, self.render_tree.root) {
    Some(style) => style
    None => @core.CursorStyle::Default
  }
}

///|
/// Resolve the cursor the host should show right now.
///
/// While the primary pointer is pressed, the style frozen at the press wins:
/// dragging out of a splitter gutter must keep the resize cursor instead of
/// snapping back to the arrow the moment the pointer leaves the declaring
/// region. Otherwise the latest pointer sample decides, and a pointer that has
/// never entered the window resolves to `Default`.
///
/// `Default` is also what the three reset paths converge on — pointer leaving
/// the window, the declaring view unmounting, focus loss — without the view tree
/// having to clear anything.
pub fn AppRuntime::pointer_cursor(self : AppRuntime) -> @core.CursorStyle {
  self.state.pointer_cursor()
}

///|
fn RuntimeState::pointer_cursor(self : RuntimeState) -> @core.CursorStyle {
  match self.animfocus.press_cursor.get(primary_pointer_id) {
    Some(style) => style
    None =>
      match self.last_pointer_position {
        Some(point) => self.resolve_cursor_at(point)
        None => @core.CursorStyle::Default
      }
  }
}
