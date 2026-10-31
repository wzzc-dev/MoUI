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
fn c3_text_frame(
  commands : Array[@core.DrawCommand],
  text : String,
) -> @core.Rect? {
  for command in commands {
    match command {
      DrawText({ text: value, frame, .. }) =>
        if value == text {
          return Some(frame)
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
/// Build the C3 fixture: a scroll view whose content carries a picker (the
/// overlay host) plus filler rows, and an unaffected sibling frame below the
/// scroll view. Wheel scrolling moves the picker without touching the sibling.
fn c3_overlay_fixture() -> AppRuntime {
  let items = [
    @views.picker_item("one", "One"),
    @views.picker_item("two", "Two"),
  ]
  AppRuntime::new_view(
    root=@views.column(
      [
        @views.scroll_view(
          @views.column(
            [
              @views.frame(@views.text("FillerA"), width=200.0, height=24.0),
              @views.frame(@views.text("FillerB"), width=200.0, height=24.0),
              @views.frame(@views.text("FillerC"), width=200.0, height=24.0),
              @views.frame(
                @views.picker(
                  items,
                  selected="",
                  on_select=_id => (),
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
          ),
          width=200.0,
          height=120.0,
        ),
        @views.frame(@views.text("Sibling"), width=200.0, height=24.0),
      ],
      spacing=0.0,
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
/// re-place. The popup must follow the moved picker and keep escaping the
/// scroll clip.
test "C3: overlay re-place reuses unaffected sibling place caches" {
  let runtime = c3_overlay_fixture()
  c3_open_picker_popup(runtime)
  let root = runtime.state.element_tree.root
  let picker = c3_required_element(
    c3_find_element(root, "Picker"),
    "picker element",
  )
  let sibling = root.children[1]
  let placed_root = runtime.state.cached_layout_tree_root()
  let picker_before = c3_required_placed(
    c3_find_placed(placed_root, picker.id),
    "picker placed",
  )
  let popup_before = c3_required_placed(
    picker_before.children.get(0),
    "popup placed",
  )
  let sibling_before = c3_required_placed(
    c3_find_placed(placed_root, sibling.id),
    "sibling placed",
  )
  assert_true(
    popup_before.frame.origin.y > -1000.0,
    msg="popup must not sit at the provisional sentinel",
  )
  assert_true(
    popup_before.hit_rect == popup_before.frame,
    msg="popup must escape ancestor clips",
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
  // The host subtree did re-place: the picker moved and the popup followed.
  let placed_root_after = runtime.state.cached_layout_tree_root()
  let picker_after = c3_required_placed(
    c3_find_placed(placed_root_after, picker.id),
    "picker placed after scroll",
  )
  let popup_after = c3_required_placed(
    picker_after.children.get(0),
    "popup placed after scroll",
  )
  assert_true(
    picker_after.frame.origin.y < picker_before.frame.origin.y,
    msg="scrolling should have moved the picker",
  )
  assert_true(
    popup_after.frame != popup_before.frame,
    msg="popup should follow the moved picker",
  )
  assert_true(
    popup_after.frame.origin.y - picker_after.frame.origin.y ==
    popup_before.frame.origin.y - picker_before.frame.origin.y,
    msg="popup must keep its anchored offset to the picker",
  )
  assert_true(
    popup_after.hit_rect == popup_after.frame,
    msg="popup must keep escaping ancestor clips after the localized re-place",
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
/// The generation gate: idle placement passes skip the overlay collect
/// entirely (no traversal, no layer/surface churn); any input moves the
/// generation and the next pass re-collects exactly once.
test "C3: idle placement passes skip the overlay collect" {
  let runtime = AppRuntime::new_view(
    root=@views.overlay_host(
      @views.frame(@views.text("Base"), width=200.0, height=100.0),
      [
        @views.PresentationSpec::new(
          id="menu",
          kind=Popover,
          content=@views.frame(@views.text("Menu"), width=40.0, height=20.0),
        ),
      ],
    ),
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
