///|
/// A neutral leaf for attaching declarative drag modifiers.
fn drag_test_leaf() -> @core.View[String] {
  @core.View::from_node(DragTestLeafNode::{ })
}

///|
struct DragTestLeafNode {}

///|
impl @core.ViewNode for DragTestLeafNode with fn identity(_self) {
  @core.ViewIdentity::new(kind="DragTestLeaf")
}

///|
impl @core.ViewNode for DragTestLeafNode with fn layout(_self, context) {
  @core.ViewLayoutResult::new(
    size=context.constraints.constrain(@core.Size::new(width=10.0, height=10.0)),
  )
}

///|
fn drag_test_context(
  phase : @core.DragPhase,
  target_key~ : String? = None,
) -> @core.ViewDragContext {
  @core.ViewDragContext::new(
    phase~,
    payload=@core.DragPayload::new(key="item"),
    position=@core.Point::new(x=5.0, y=6.0),
    frame=@core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
    target_key~,
  )
}

///|
test "drag payload and source defaults" {
  let payload = @core.DragPayload::new(key="tab/42")
  assert_eq(payload.key, "tab/42")
  assert_eq(payload.text, "")
  assert_eq(@core.DragPayload::new(key="k", text="label").text, "label")
  let default_source = @core.DragSource::new(payload~)
  assert_eq(default_source.min_distance, 4.0)
  // Negative distances clamp to zero so the recognizer cannot start before
  // the press sample.
  assert_eq(
    @core.DragSource::new(payload~, min_distance=-3.0).min_distance,
    0.0,
  )
  assert_eq(@core.DragSource::new(payload~, min_distance=0.0).min_distance, 0.0)
}

///|
test "drop target accepts defaults to every payload" {
  let target = @core.DropTarget::new(key="zone")
  assert_true(target.accepts(@core.DragPayload::new(key="anything")))
  let strict = @core.DropTarget::new(key="strict", accepts=fn(payload) {
    payload.key == "ok"
  })
  assert_true(strict.accepts(@core.DragPayload::new(key="ok")))
  assert_false(strict.accepts(@core.DragPayload::new(key="no")))
}

///|
test "drag declaration none and source/target independence" {
  assert_true(@core.DragDeclaration::none().is_empty())
  let payload = @core.DragPayload::new(key="item")
  let declaration = @core.DragDeclaration::new(
    source=Some(@core.DragSource::new(payload~)),
  )
  assert_false(declaration.is_empty())
  match declaration.source {
    Some(source) => assert_eq(source.payload, payload)
    None => fail("expected a source")
  }
  let both = @core.DragDeclaration::new(
    source=Some(@core.DragSource::new(payload~)),
    target=Some(@core.DropTarget::new(key="zone")),
  )
  assert_true(both.source is Some(_) && both.target is Some(_))
}

///|
test "draggable modifier identity and declaration snapshot" {
  let payload = @core.DragPayload::new(key="item")
  let view = drag_test_leaf().draggable(payload~, min_distance=2.5)
  assert_true(view.identity().kind.contains("Draggable"))
  let declaration = view.drag_declaration()
  assert_true(declaration.target is None)
  match declaration.source {
    Some(source) => {
      assert_eq(source.payload, payload)
      assert_eq(source.min_distance, 2.5)
    }
    None => fail("expected a drag source declaration")
  }
}

///|
test "drop_target modifier identity and declaration snapshot" {
  let view = drag_test_leaf().drop_target(key="zone")
  assert_true(view.identity().kind.contains("DropTarget"))
  let declaration = view.drag_declaration()
  assert_true(declaration.source is None)
  match declaration.target {
    Some(target) => assert_eq(target.key, "zone")
    None => fail("expected a drop target declaration")
  }
}

///|
test "draggable translates source phases and ignores target phases" {
  let payload = @core.DragPayload::new(key="item")
  let view = drag_test_leaf().draggable(
    payload~,
    on_start=Some(fn(p, _position) { "start:\{p.key}" }),
    on_move=Some(fn(_p, _position) { "move" }),
    on_end=Some(fn(end) {
      match end.target_key {
        Some(target) => "end:\{target}"
        None => "end:none"
      }
    }),
  )
  let started = view.dispatch_drag(drag_test_context(@core.DragPhase::Started))
  assert_true(started.changed)
  assert_eq(started.messages, ["start:item"])
  let moved = view.dispatch_drag(drag_test_context(@core.DragPhase::Moved))
  assert_eq(moved.messages, ["move"])
  let ended_none = view.dispatch_drag(drag_test_context(@core.DragPhase::Ended))
  assert_eq(ended_none.messages, ["end:none"])
  let ended_target = view.dispatch_drag(
    drag_test_context(@core.DragPhase::Ended, target_key=Some("zone")),
  )
  assert_eq(ended_target.messages, ["end:zone"])
  // Target-side phases are not the source's to handle.
  for
    phase in [
      @core.DragPhase::Entered,
      @core.DragPhase::Left,
      @core.DragPhase::Dropped,
    ] {
    let result = view.dispatch_drag(drag_test_context(phase))
    assert_false(result.changed)
    assert_true(result.messages.is_empty())
  }
}

///|
test "draggable exposes DragEnd with and without a target key" {
  let payload = @core.DragPayload::new(key="item")
  let ends : Array[@core.DragEnd] = []
  let view = drag_test_leaf().draggable(
    payload~,
    on_end=Some(fn(end) {
      ends.push(end)
      "ended"
    }),
  )
  ignore(view.dispatch_drag(drag_test_context(@core.DragPhase::Ended)))
  ignore(
    view.dispatch_drag(
      drag_test_context(@core.DragPhase::Ended, target_key=Some("zone")),
    ),
  )
  assert_eq(ends.length(), 2)
  assert_eq(ends[0].payload, payload)
  assert_true(ends[0].target_key is None)
  assert_eq(ends[1].target_key, Some("zone"))
}

///|
test "drop_target translates target phases and ignores source phases" {
  let payload = @core.DragPayload::new(key="item")
  let view = drag_test_leaf().drop_target(
    key="zone",
    on_enter=Some(fn(_payload, _position) { "enter" }),
    on_move=Some(fn(_payload, _position) { "move" }),
    on_drop=Some(fn(_payload, _position) { "drop" }),
    on_leave=Some(fn() { "leave" }),
  )
  let entered = view.dispatch_drag(
    drag_test_context(@core.DragPhase::Entered, target_key=Some("zone")),
  )
  assert_true(entered.changed)
  assert_eq(entered.messages, ["enter"])
  assert_eq(
    view.dispatch_drag(drag_test_context(@core.DragPhase::Moved)).messages,
    ["move"],
  )
  assert_eq(
    view.dispatch_drag(drag_test_context(@core.DragPhase::Dropped)).messages,
    ["drop"],
  )
  assert_eq(
    view.dispatch_drag(drag_test_context(@core.DragPhase::Left)).messages,
    ["leave"],
  )
  for phase in [@core.DragPhase::Started, @core.DragPhase::Ended] {
    let result = view.dispatch_drag(drag_test_context(phase))
    assert_false(result.changed)
    assert_true(result.messages.is_empty())
  }
  // The predicate rides along with the declaration the runtime reads.
  match view.drag_declaration().target {
    Some(target) => assert_true(target.accepts(payload))
    None => fail("expected a drop target declaration")
  }
}

///|
test "stacked draggable and drop_target declare independent roles" {
  let payload = @core.DragPayload::new(key="item")
  let stacked = drag_test_leaf()
    .draggable(payload~, on_start=Some(fn(_p, _pos) { "start" }))
    .drop_target(key="zone", on_drop=Some(fn(_p, _pos) { "drop" }))
  // The outer wrapper element is the target; it must not answer for the
  // inner source.
  let outer = stacked.drag_declaration()
  assert_true(outer.source is None)
  assert_eq(outer.target.unwrap().key, "zone")
  let children = stacked.children()
  assert_eq(children.length(), 1)
  let inner = children[0].drag_declaration()
  assert_true(inner.target is None)
  assert_eq(inner.source.unwrap().payload, payload)
  // Each element translates only its own phases.
  assert_eq(
    stacked.dispatch_drag(drag_test_context(@core.DragPhase::Dropped)).messages,
    ["drop"],
  )
  assert_eq(
    children[0].dispatch_drag(drag_test_context(@core.DragPhase::Started)).messages,
    ["start"],
  )
  // A plain view declares nothing and translates nothing.
  assert_true(drag_test_leaf().drag_declaration().is_empty())
  assert_true(
    drag_test_leaf().dispatch_drag(drag_test_context(@core.DragPhase::Started)).messages.is_empty(),
  )
}
