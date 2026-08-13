///|
test "accesskit adapter maps flat runtime semantics nodes" {
  let child_id = @core.SemanticsNodeId::new(2UL)
  let child = @core.SemanticsNode::{
    node_id: child_id,
    semantic_id: @core.SemanticId::parse("document.save"),
    role: @core.SemanticsRole::Heading,
    level: Some(2),
    url: "https://example.test/save",
    label: "Save",
    value: "",
    description: "Save current document",
    state: @core.SemanticsState::default(),
    numeric: None,
    text: None,
    collection: None,
    relations: @core.SemanticsRelations::empty(),
    live: @core.SemanticsLive::Off,
    live_atomic: false,
    actions: [
      @core.SemanticsActionKind::Focus,
      @core.SemanticsActionKind::Activate,
    ],
    focus_order: Some(0),
    frame: @core.Rect::new(x=8.0, y=8.0, width=80.0, height=32.0),
    children: [],
  }
  let root = @core.SemanticsNode::{
    node_id: @core.SemanticsNodeId::new(1UL),
    semantic_id: None,
    role: @core.SemanticsRole::Group,
    level: None,
    url: "",
    label: "Root",
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
    frame: @core.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0),
    children: [child_id],
  }
  let root_node = @accesskit.accesskit_node_from_semantics(root)
  let child_node = @accesskit.accesskit_node_from_semantics(child)
  assert_true(
    @accesskit.accesskit_node_id_for_semantics(child_id) ==
    @moon_accesskit.NodeId::from_u64(2UL),
  )
  let root_children = root_node.children()
  assert_eq(root_children.length(), 1)
  assert_true(root_children[0] == @moon_accesskit.NodeId::from_u64(2UL))
  inspect(child_node.role(), content="Heading")
  assert_true(child_node.level() == Some(2))
  assert_true(child_node.url() == Some("https://example.test/save"))
  match child_node.label() {
    Some(label) => inspect(label, content="Save")
    None => fail("expected child accessibility label")
  }
  match child_node.description() {
    Some(description) => inspect(description, content="Save current document")
    None => fail("expected child accessibility description")
  }
  assert_true(child_node.supports_action(@moon_accesskit.Action::Click))
}

///|
test "accesskit bridge forwards generation-checked neutral actions" {
  let invoked = Ref(0)
  let node_id = @core.SemanticsNodeId::new(42UL)
  let generation = @core.SemanticsGeneration::new(7UL)
  let bridge = @accesskit.AccessKitBridge::new(diagnostic_name="test", perform=request => {
    if request.target == @core.SemanticsTarget::ByNodeId(node_id) &&
      request.precondition ==
      @runtime.SemanticsGenerationPrecondition::Exact(generation) &&
      request.action == @core.SemanticsAction::SetText("Luna") {
      invoked.val = invoked.val + 1
      @accesskit.AccessKitActionResult::Handled({
        before: generation,
        after: @core.SemanticsGeneration::new(8UL),
        pending_work: false,
      })
    } else {
      @accesskit.AccessKitActionResult::Rejected(
        @runtime.SemanticsActionDispatchError::TargetNotFound(request.target),
      )
    }
  })
  match
    bridge.perform_action(
      @accesskit.accesskit_semantics_action_request(
        node_id~,
        generation~,
        action=@core.SemanticsAction::SetText("Luna"),
      ),
    ) {
    @accesskit.AccessKitActionResult::Handled(receipt) =>
      assert_true(receipt.after == @core.SemanticsGeneration::new(8UL))
    _ => fail("expected handled action")
  }
  inspect(invoked.val, content="1")
}

///|
test "unavailable accesskit bridge is inert" {
  let bridge = @accesskit.AccessKitBridge::unavailable(reason="not installed")
  let request = @accesskit.accesskit_semantics_action_request(
    node_id=@core.SemanticsNodeId::new(1UL),
    generation=@core.SemanticsGeneration::new(1UL),
    action=@core.SemanticsAction::Activate,
  )
  assert_true(
    bridge.publish_semantics(
      @runtime.SemanticsRead::Unchanged(@core.SemanticsGeneration::new(1UL)),
    )
    is None,
  )
  match bridge.perform_action(request) {
    @accesskit.AccessKitActionResult::BridgeUnavailable(_) => ()
    _ => fail("expected unavailable bridge")
  }
}
