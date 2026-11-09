///|
fn retained_payload_leaf(id : Int32, x : Double, width : Double) -> RenderNode {
  {
    ..RenderNode::empty(),
    element_id: ElementId::new(id),
    frame: Rect::new(x~, y=0.0, width~, height=20.0),
    paint_commands: [
      FillRect(
        Rect::new(x=0.0, y=0.0, width~, height=20.0),
        Color::rgba(r=0.2, g=0.4, b=0.6),
      ),
    ],
  }
}

///|
/// A retained boundary holding a nested boundary, a scrolled child transform,
/// and view-level overlay commands. Overlay commands sit on the boundary itself
/// so both traversals wrap them under the same live transform.
fn retained_payload_tree(memoized : Bool) -> RenderNode {
  let inner = retained_payload_leaf(3, 0.0, 40.0)
  let inner = if memoized {
    inner.with_repaint_boundary_cache()
  } else {
    {
      ..inner,
      is_repaint_boundary: true,
      layer_cache_key: Some(inner.repaint_boundary_cache_key()),
    }
  }
  let scrolled = {
    ..retained_payload_leaf(4, 10.0, 60.0),
    child_transform: Transform2D::translation(dx=0.0, dy=-15.0),
    children: [inner],
  }
  let boundary = {
    ..retained_payload_leaf(2, 30.0, 200.0),
    children: [scrolled],
    post_paint_commands: [
      StrokeRect(
        Rect::new(x=0.0, y=0.0, width=200.0, height=20.0),
        Color::black(),
        1.0,
      ),
    ],
    overlay_paint_commands: [
      FillRect(
        Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
        Color::rgba(r=1.0, g=0.0, b=0.0),
      ),
    ],
  }
  let boundary = if memoized {
    boundary.with_repaint_boundary_cache()
  } else {
    {
      ..boundary,
      is_repaint_boundary: true,
      layer_cache_key: Some(boundary.repaint_boundary_cache_key()),
    }
  }
  { ..retained_payload_leaf(1, 0.0, 800.0), children: [boundary], }
}

///|
fn retained_payload_frame_commands(root : RenderNode) -> Array[DrawCommand] {
  let commands : Array[DrawCommand] = []
  root.collect_frame_commands(commands)
  commands
}

///|
test "retained payload replay emits the same stream as the subtree walk" {
  let memoized = retained_payload_tree(true)
  let walked = retained_payload_tree(false)
  let from_cache = retained_payload_frame_commands(memoized)
  let from_walk = retained_payload_frame_commands(walked)
  assert_eq(from_cache.length(), from_walk.length())
  for index in 0..<from_cache.length() {
    assert_eq(from_cache[index], from_walk[index])
  }
}

///|
test "retained payload replay keeps the complete layer on the wire" {
  let commands = retained_payload_frame_commands(retained_payload_tree(true))
  // P16: both the outer and the nested layer carry their full payload every
  // frame; the memo changes how the runtime builds the stream, not its content.
  assert_eq(
    commands.filter(command => command is BeginRetainedLayer(_)).length(),
    2,
  )
  assert_eq(
    commands.filter(command => command is EndRetainedLayer(_)).length(),
    2,
  )
  // Four painted leaves plus the boundary's own overlay fill.
  assert_eq(commands.filter(command => command is FillRect(_, _)).length(), 5)
}

///|
test "retained layer frames are served from the flattened payload" {
  let boundary = {
    ..retained_payload_leaf(7, 0.0, 50.0),
    is_repaint_boundary: true,
    layer_cache_key: Some("retained-payload-sentinel"),
    // A payload that disagrees with `paint_commands` can only reach the frame
    // if the replay path is the one actually wired into the frame builder.
    cached_draw_commands: Some([
      FillRect(
        Rect::new(x=0.0, y=0.0, width=50.0, height=20.0),
        Color::rgba(r=0.0, g=1.0, b=0.0),
      ),
    ]),
    cached_overlay_draw_commands: Some([]),
  }
  let commands = retained_payload_frame_commands(boundary)
  let fills = commands.filter(command => command is FillRect(_, _))
  assert_eq(fills.length(), 1)
  assert_eq(
    fills[0],
    FillRect(
      Rect::new(x=0.0, y=0.0, width=50.0, height=20.0),
      Color::rgba(r=0.0, g=1.0, b=0.0),
    ),
  )
}
