///|
test "macos semantics node json serializes semantic id as string" {
  let node : @core.SemanticsNode = {
    node_id: @core.SemanticsNodeId::new(7),
    semantic_id: Some(@core.SemanticId::parse("a11y.button").unwrap()),
    role: Button,
    level: None,
    url: "",
    label: "Probe button",
    value: "",
    description: "",
    state: @core.SemanticsState::default(),
    numeric: None,
    text: None,
    collection: None,
    relations: @core.SemanticsRelations::empty(),
    live: Off,
    live_atomic: false,
    actions: [Activate],
    focus_order: None,
    frame: @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
    children: [],
  }
  let json = macos_semantics_node_json(node).stringify()
  inspect(json.contains("\"semantic_id\":\"a11y.button\""), content="true")
  assert_false(json.contains("\"semantic_id\":["))
  assert_true(json.contains("\"level\":null"))
  let numeric : @core.SemanticsNode = {
    ..node,
    node_id: @core.SemanticsNodeId::new(8),
    role: Slider,
    semantic_id: Some(@core.SemanticId::parse("a11y.slider").unwrap()),
    numeric: Some(
      @core.SemanticsNumericValue::new(current=0.7, min=0.0, max=1.0, step=0.1),
    ),
  }
  let numeric_json = macos_semantics_node_json(numeric).stringify()
  inspect(numeric_json.contains("\"current\":0.7"), content="true")
  assert_false(numeric_json.contains("\"current\":["))
  assert_true(numeric_json.contains("\"min\":0"))
}
