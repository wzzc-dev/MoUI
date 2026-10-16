///|
test "draw frame defaults to no overlay bounds" {
  let frame = @core.DrawFrame::new(
    commands=[],
    damage=@core.DamageRegion::empty(),
  )
  assert_true(frame.overlay_bounds is None)
}

///|
fn payload_test_node(label : String) -> @core.SemanticsNode {
  {
    node_id: @core.SemanticsNodeId::new(7UL),
    semantic_id: None,
    role: @core.SemanticsRole::Text,
    level: None,
    url: "",
    label,
    value: "",
    description: "",
    state: @core.SemanticsState::default(),
    numeric: None,
    text: None,
    collection: None,
    relations: @core.SemanticsRelations::empty(),
    live: @core.SemanticsLive::Off,
    live_atomic: false,
    actions: [],
    focus_order: None,
    frame: @core.Rect::new(x=0.0, y=0.0, width=40.0, height=8.0),
    children: [],
  }
}

///|
test "draw frame semantics payload is opt-in and copy-protected" {
  let plain = @core.DrawFrame::new(
    commands=[],
    damage=@core.DamageRegion::empty(),
  )
  assert_true(plain.semantics is None)
  let nodes = [payload_test_node("Hello")]
  let payload = @core.SemanticsFramePayload::new(
    generation=@core.SemanticsGeneration::new(7UL),
    nodes~,
    root=Some(nodes[0].node_id),
  )
  let frame = @core.DrawFrame::new(
    commands=[],
    damage=@core.DamageRegion::empty(),
    semantics=Some(payload),
  )
  match frame.semantics {
    Some(carried) => {
      assert_true(carried.generation() == @core.SemanticsGeneration::new(7UL))
      assert_true(carried.root() == Some(nodes[0].node_id))
      assert_true(carried.focused() is None)
      assert_eq(carried.node_count(), 1)
      assert_eq(carried.nodes()[0].label, "Hello")
      // accessors project copies, so a consumer cannot grow the carried tree
      carried.nodes().push(nodes[0])
      assert_eq(carried.node_count(), 1)
    }
    None => fail("expected a semantics payload")
  }
  assert_true(
    frame ==
    @core.DrawFrame::new(
      commands=[],
      damage=@core.DamageRegion::empty(),
      semantics=Some(payload),
    ),
  )
  assert_true(frame != plain)
}
