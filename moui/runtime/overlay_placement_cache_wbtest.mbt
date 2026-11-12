///|
/// C3 (plan hot-path-invalidation-boilerplate-convergence) regression tests:
/// overlay placement updates must re-place only the affected spine —
/// unaffected sibling subtrees keep hitting their per-node place caches —
/// and the placement collect must be skipped entirely on idle passes.

///|
fn c3_find_element(element : ElementNode, kind : String) -> ElementNode? {
  if element.view_node.identity().kind == kind {
    return Some(element)
  }
  for child in element.children {
    match c3_find_element(child, kind) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
fn c3_find_placed(placed : PlacedNode, id : ElementId) -> PlacedNode? {
  if placed.element_id == id {
    return Some(placed)
  }
  for child in placed.children {
    match c3_find_placed(child, id) {
      Some(found) => return Some(found)
      None => ()
    }
  }
  None
}

///|
fn c3_required_element(element : ElementNode?, label : String) -> ElementNode {
  match element {
    Some(found) => found
    None => abort(label)
  }
}

///|
fn c3_required_placed(placed : PlacedNode?, label : String) -> PlacedNode {
  match placed {
    Some(found) => found
    None => abort(label)
  }
}

///|
fn c3_required_rect(rect : Rect?, label : String) -> Rect {
  match rect {
    Some(found) => found
    None => abort(label)
  }
}

///|
fn c3_placed_screen_frame(
  placed : PlacedNode,
  id : ElementId,
  node_to_screen : Transform2D,
) -> Rect? {
  if placed.element_id == id {
    return Some(runtime_screen_frame(node_to_screen, placed.frame))
  }
  for index, child in placed.children {
    let child_to_screen = if placed.overlay_child_indices.contains(index) {
      runtime_overlay_to_screen(child.frame)
    } else {
      runtime_child_to_screen(
        node_to_screen,
        placed.child_transform,
        child.frame,
      )
    }
    match c3_placed_screen_frame(child, id, child_to_screen) {
      Some(frame) => return Some(frame)
      None => ()
    }
  }
  None
}

///|
fn c3_text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Rect? {
  let mut current = @core.Transform2D::identity()
  let stack : Array[@core.Transform2D] = []
  for command in commands {
    match command {
      PushTransform(transform) => {
        stack.push(current)
        current = {
          a: current.a * transform.a + current.c * transform.b,
          b: current.b * transform.a + current.d * transform.b,
          c: current.a * transform.c + current.c * transform.d,
          d: current.b * transform.c + current.d * transform.d,
          tx: current.a * transform.tx + current.c * transform.ty + current.tx,
          ty: current.b * transform.tx + current.d * transform.ty + current.ty,
        }
      }
      PopTransform =>
        match stack.pop() {
          Some(transform) => current = transform
          None => current = @core.Transform2D::identity()
        }
      DrawText({ text: value, frame, .. }) =>
        if value == text {
          let right = frame.origin.x + frame.size.width
          let bottom = frame.origin.y + frame.size.height
          let x0 = current.a * frame.origin.x +
            current.c * frame.origin.y +
            current.tx
          let y0 = current.b * frame.origin.x +
            current.d * frame.origin.y +
            current.ty
          let x1 = current.a * right + current.c * frame.origin.y + current.tx
          let y1 = current.b * right + current.d * frame.origin.y + current.ty
          let x2 = current.a * frame.origin.x + current.c * bottom + current.tx
          let y2 = current.b * frame.origin.x + current.d * bottom + current.ty
          let x3 = current.a * right + current.c * bottom + current.tx
          let y3 = current.b * right + current.d * bottom + current.ty
          let min_x = x0.min(x1).min(x2).min(x3)
          let max_x = x0.max(x1).max(x2).max(x3)
          let min_y = y0.min(y1).min(y2).min(y3)
          let max_y = y0.max(y1).max(y2).max(y3)
          return Some(
            @core.Rect::new(
              x=min_x,
              y=min_y,
              width=max_x - min_x,
              height=max_y - min_y,
            ),
          )
        }
      _ => ()
    }
  }
  None
}

///|
fn c3_pointer(
  runtime : AppRuntime,
  x : Double,
  y : Double,
  phase : @core.PointerPhase,
) -> Unit {
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(position=@core.Point::new(x~, y~), phase~),
    ),
  )
}

///|
fn c3_wheel(runtime : AppRuntime, x : Double, y : Double, dy : Double) -> Unit {
  ignore(
    runtime.dispatch_pointer_input(
      @core.PointerEvent::new(
        position=@core.Point::new(x~, y~),
        phase=Move,
        wheel_delta=@core.Point::new(x=0.0, y=dy),
      ),
    ),
  )
}

///|
fn c3_text_count(commands : Array[@core.DrawCommand], text : String) -> Int32 {
  let mut count = 0
  for command in commands {
    match command {
      DrawText({ text: value, .. }) => if value == text { count = count + 1 }
      _ => ()
    }
  }
  count
}

///|
enum C3PickerMsg {
  C3Toggle
  C3Select(String)
}

///|
struct C3PickerModel {
  open : Bool
  selected : String
}

///|
fn c3_picker_content(
  items : Array[@views.PickerItem],
  model : C3PickerModel,
) -> @core.View[C3PickerMsg] {
  @views.column(
    [
      @views.frame(@views.text("FillerA"), width=200.0, height=24.0),
      @views.frame(@views.text("FillerB"), width=200.0, height=24.0),
      @views.frame(@views.text("FillerC"), width=200.0, height=24.0),
      @views.frame(
        @views.picker(
          items,
          selected=model.selected,
          on_select=id => C3Select(id),
          expanded=model.open,
          on_expanded_change=_ => C3Toggle,
          placeholder="Pick",
          max_height=160.0,
        ),
        width=200.0,
        height=40.0,
      ),
      @views.frame(@views.text("FillerD"), width=200.0, height=24.0),
      @views.frame(@views.text("FillerE"), width=200.0, height=24.0),
    ],
    spacing=0.0,
  )
}

///|

///|
/// Build the C3 fixture: a scroll view whose content carries a picker (the
/// overlay host) plus filler rows, and an unaffected sibling frame below the
/// scroll view. Wheel scrolling moves the picker without touching the sibling.
fn c3_overlay_fixture(boundary~ : Bool = false) -> AppRuntime {
  let items = [
    @views.picker_item("one", "One"),
    @views.picker_item("two", "Two"),
  ]
  AppRuntime::new_program(
    program=@core.Program::simple(
      init={ open: false, selected: "", },
      update=(model, message) => {
        match message {
          C3Toggle => { ..model, open: !model.open, }
          C3Select(id) => { ..model, selected: id, open: false, }
        }
      },
      view=model => {
        @views.column(
          [
            @views.scroll_view(
              if boundary {
                c3_picker_content(items, model).repaint_boundary()
              } else {
                c3_picker_content(items, model)
              },
              width=200.0,
              height=120.0,
            ),
            @views.frame(@views.text("Sibling"), width=200.0, height=24.0),
          ],
          spacing=0.0,
        )
      },
    ),
    size=@core.Size::new(width=200.0, height=200.0),
  )
}

///|
fn c3_open_picker_popup(runtime : AppRuntime) -> Unit {
  ignore(runtime.draw_frame())
  let button = match c3_text_frame(runtime.draw_commands(), "Pick") {
    Some(frame) => frame
    None => abort("picker placeholder not rendered")
  }
  c3_pointer(runtime, button.origin.x + 10.0, button.origin.y + 10.0, Down)
  c3_pointer(runtime, button.origin.x + 10.0, button.origin.y + 10.0, Up)
  ignore(runtime.draw_frame())
  if c3_text_frame(runtime.draw_commands(), "Two") is None {
    abort("picker popup items should render after opening")
  }
}

///|
/// The core C3 assertion: with the popup open, every scroll frame re-places
/// the host spine while the unaffected sibling subtree keeps hitting its
/// per-node place cache in both the fresh place and the localized overlay
/// re-place. The picker stays content-local while its hoisted popup follows
/// the moved picker in screen space and keeps escaping the scroll clip.
test "C3: overlay re-place reuses unaffected sibling place caches" {
  let runtime = c3_overlay_fixture()
  c3_open_picker_popup(runtime)
  let root = runtime.state.element_tree.root
  let picker = c3_required_element(
    c3_find_element(root, "Picker"),
    "picker element",
  )
  let sibling = root.children[1]
  let overlay_host = c3_required_element(
    c3_find_element(root, "OverlayHost"),
    "overlay host element",
  )
  let popup_surface = c3_required_element(
    c3_find_element(root, "PresentationSurface"),
    "popup surface element",
  )
  let placed_root = runtime.state.cached_layout_tree_root()
  let picker_before = c3_required_placed(
    c3_find_placed(placed_root, picker.id),
    "picker placed",
  )
  let host_before = c3_required_placed(
    c3_find_placed(placed_root, overlay_host.id),
    "overlay host placed",
  )
  let popup_before = c3_required_placed(
    c3_find_placed(placed_root, popup_surface.id),
    "popup placed",
  )
  let sibling_before = c3_required_placed(
    c3_find_placed(placed_root, sibling.id),
    "sibling placed",
  )
  assert_true(
    !host_before.overlay_child_indices.is_empty(),
    msg="the overlay host must hoist the popup surface",
  )
  // Wheel-scroll under the open popup. Each wheel event scrolls 12px and
  // leaves layout dirt pending. Between wheels, run the two placement phases
  // manually so the sibling cache counters can be attributed to each phase.
  for index in 0..<3 {
    let hit_before = sibling.layout_cache.hit_count
    let miss_before = sibling.layout_cache.miss_count
    c3_wheel(runtime, 100.0, 60.0, -12.0)
    runtime.state.layout_current_tree()
    assert_true(
      sibling.layout_cache.hit_count > hit_before,
      msg="fresh place should reuse the unaffected sibling (iteration \{index})",
    )
    assert_true(
      sibling.layout_cache.miss_count == miss_before,
      msg="fresh place must not re-place the unaffected sibling (iteration \{index})",
    )
    runtime.state.ensure_layout_tree()
    assert_true(
      sibling.layout_cache.hit_count > hit_before + 1,
      msg="localized overlay re-place should reuse the unaffected sibling (iteration \{index})",
    )
    assert_true(
      sibling.layout_cache.miss_count == miss_before,
      msg="overlay re-place must not re-place the unaffected sibling (iteration \{index})",
    )
  }
  // The host subtree did re-place for the popup, but the picker's own frame
  // stays content-local. Only its accumulated screen position moved.
  let placed_root_after = runtime.state.cached_layout_tree_root()
  let picker_after = c3_required_placed(
    c3_find_placed(placed_root_after, picker.id),
    "picker placed after scroll",
  )
  let popup_after = c3_required_placed(
    c3_find_placed(placed_root_after, popup_surface.id),
    "popup placed after scroll",
  )
  let picker_before_screen = c3_required_rect(
    c3_placed_screen_frame(placed_root, picker.id, Transform2D::identity()),
    "picker screen frame",
  )
  let picker_after_screen = c3_required_rect(
    c3_placed_screen_frame(
      placed_root_after,
      picker.id,
      Transform2D::identity(),
    ),
    "picker screen frame after scroll",
  )
  assert_true(
    picker_after.frame == picker_before.frame,
    msg="scrolling must not rewrite the picker's content-local frame",
  )
  assert_true(
    picker_after_screen.origin.y < picker_before_screen.origin.y,
    msg="scrolling should move the picker in screen space",
  )
  assert_true(
    popup_after.frame != popup_before.frame,
    msg="popup should follow the moved picker",
  )
  assert_true(
    popup_after.frame.origin.y - picker_after_screen.origin.y ==
    popup_before.frame.origin.y - picker_before_screen.origin.y,
    msg="popup must keep its anchored offset to the picker",
  )
  let host_after = c3_required_placed(
    c3_find_placed(placed_root_after, overlay_host.id),
    "overlay host placed after scroll",
  )
  assert_true(
    !host_after.overlay_child_indices.is_empty(),
    msg="popup must stay hoisted after the localized re-place",
  )
  let sibling_after = c3_required_placed(
    c3_find_placed(placed_root_after, sibling.id),
    "sibling placed after scroll",
  )
  assert_true(
    sibling_after.frame == sibling_before.frame,
    msg="unaffected sibling frame must not move",
  )
  // The rendered frame still shows the popup content.
  assert_true(
    c3_text_frame(runtime.draw_commands(), "Two") is Some(_),
    msg="popup must still render after localized re-places",
  )
}

///|
test "retained repaint boundaries never inline a hoisted overlay" {
  let runtime = c3_overlay_fixture(boundary=true)
  c3_open_picker_popup(runtime)
  c3_wheel(runtime, 100.0, 60.0, -12.0)
  ignore(runtime.draw_frame())
  ignore(runtime.draw_frame())
  assert_eq(
    c3_text_count(runtime.draw_commands(), "Two"),
    1,
    msg="a cached repaint boundary must not replay its overlay twice",
  )
  assert_true(
    c3_text_frame(runtime.draw_commands(), "Two") is Some(_),
    msg="the hoisted overlay must survive retained-cache fallback",
  )
}

///|
/// The generation gate: idle placement passes skip the overlay collect
/// entirely (no traversal, no layer/surface churn); any input moves the
/// generation and the next pass re-collects exactly once.
test "C3: idle placement passes skip the overlay collect" {
  let root : @core.View[Unit] = @views.overlay_host(
    @views.frame(@views.text("Base"), width=200.0, height=100.0),
    [
      @views.PresentationSpec::new(
        id="menu",
        kind=Popover,
        content=@views.frame(@views.text("Menu"), width=40.0, height=20.0),
      ),
    ],
  )
  let runtime = AppRuntime::new_view(
    root~,
    size=@core.Size::new(width=200.0, height=100.0),
  )
  ignore(runtime.draw_frame())
  let state = runtime.state
  let collected = state.stats.overlay_collect_count
  assert_true(
    state.overlay_collected_at_generation == state.overlay_input_generation,
    msg="the settling frame should have collected at the current generation",
  )
  let layer_count = state.layer_stack.length()
  assert_true(
    layer_count >= 1,
    msg="the presented popover host should register a dismissal layer",
  )
  state.ensure_layout_tree()
  state.ensure_layout_tree()
  assert_true(
    state.stats.overlay_collect_count == collected,
    msg="idle placement passes must skip the overlay collect",
  )
  assert_true(
    state.overlay_collected_at_generation == state.overlay_input_generation,
    msg="the collected generation must track the input generation",
  )
  assert_true(
    state.layer_stack.length() == layer_count,
    msg="skipping must preserve the dismissal layer stack",
  )
  c3_pointer(runtime, 5.0, 5.0, Move)
  state.ensure_layout_tree()
  assert_true(
    state.stats.overlay_collect_count == collected + 1,
    msg="an input event must trigger exactly one re-collect",
  )
}

///|
/// A view node whose `layout` output depends on view state (with only a
/// paint-dirty hint) must re-place when a place pass reaches it: the per-node
/// place cache keys on the element's view-state revision.
priv struct C3RevisionProbeNode {}

///|
impl @core.ViewNode for C3RevisionProbeNode with fn identity(_self) {
  @core.ViewIdentity::new(kind="C3RevisionProbe")
}

///|
impl @core.ViewNode for C3RevisionProbeNode with fn declaration(_self) {
  @core.ViewDeclaration::constant()
}

///|
impl @core.ViewNode for C3RevisionProbeNode with fn child_constraints(
  _self,
  _constraints,
) {
  @core.Constraints::unbounded()
}

///|
impl @core.ViewNode for C3RevisionProbeNode with fn layout(_self, context) {
  let size = context.constraints.constrain(
    @core.Size::new(width=40.0, height=20.0),
  )
  let dx = if context.state.selected { 10.0 } else { 0.0 }
  @core.ViewLayoutResult::new(size~, child_frames=[
    @core.Rect::new(x=dx, y=0.0, width=20.0, height=10.0),
  ])
}

///|
fn c3_revision_probe() -> @core.View[Unit] {
  @core.View::from_node(C3RevisionProbeNode::{ }, children=_node => {
    [@views.text("Leaf")]
  })
}

///|
test "C3: place cache keys on the view-state revision" {
  let runtime = AppRuntime::new_view(
    root=@views.column(
      [
        c3_revision_probe(),
        @views.frame(@views.text("Static"), width=40.0, height=20.0),
      ],
      spacing=0.0,
    ),
    size=@core.Size::new(width=100.0, height=60.0),
  )
  ignore(runtime.draw_frame())
  let root = runtime.state.element_tree.root
  let probe = c3_required_element(
    c3_find_element(root, "C3RevisionProbe"),
    "revision probe element",
  )
  let static_frame = root.children[1]
  // Control: a forced re-place with unchanged state hits both caches.
  let probe_hit0 = probe.layout_cache.hit_count
  let static_hit0 = static_frame.layout_cache.hit_count
  root.layout_cache.clear()
  runtime.state.layout_current_tree()
  assert_true(
    probe.layout_cache.hit_count > probe_hit0,
    msg="unchanged state must hit the probe place cache",
  )
  assert_true(
    static_frame.layout_cache.hit_count > static_hit0,
    msg="unchanged state must hit the sibling place cache",
  )
  let child_x_before = c3_required_placed(
      c3_find_placed(runtime.state.cached_layout_tree_root(), probe.id),
      "probe placed",
    ).children[0].frame.origin.x
  assert_true(child_x_before == 0.0, msg="deselected probe child starts at x=0")
  // Flip the view state with no dirty hint beyond paint: the next place pass
  // that reaches the probe must re-place it (state revision moved).
  probe.control.apply_view_context({
    ..probe.control.view_state,
    selected: true,
  })
  assert_true(
    probe.control.state_revision == 1,
    msg="state flip must bump the revision",
  )
  let static_hit1 = static_frame.layout_cache.hit_count
  root.layout_cache.clear()
  runtime.state.layout_current_tree()
  let probe_placed = c3_required_placed(
    c3_find_placed(runtime.state.cached_layout_tree_root(), probe.id),
    "probe placed after flip",
  )
  assert_true(
    probe_placed.children[0].frame.origin.x == 10.0,
    msg="the probe must re-place after a view-state flip instead of serving the stale cache",
  )
  assert_true(
    static_frame.layout_cache.hit_count > static_hit1,
    msg="the state flip must stay local to the flipped element",
  )
}

///|
test "picker reopens after close repeatedly" {
  let runtime = c3_overlay_fixture()
  let mut clock_ms = 0.0
  for _ in 0..<6 {
    c3_open_picker_popup(runtime)
    let button = c3_required_rect(
      c3_text_frame(runtime.draw_commands(), "Pick"),
      "picker button",
    )
    c3_pointer(runtime, button.origin.x + 10.0, button.origin.y + 10.0, Down)
    c3_pointer(runtime, button.origin.x + 10.0, button.origin.y + 10.0, Up)
    ignore(runtime.draw_frame())
    // The exit ghost fades over the theme motion duration; let it finish
    // before asserting the popup is gone. The clock is absolute, so move it
    // forward on every iteration.
    clock_ms = clock_ms + 1000.0
    runtime.advance_time(clock_ms)
    ignore(runtime.draw_frame())
    clock_ms = clock_ms + 1000.0
    runtime.advance_time(clock_ms)
    ignore(runtime.draw_frame())
    if c3_text_frame(runtime.draw_commands(), "Two") is Some(_) {
      fail("picker popup did not close")
    }
  }
}
