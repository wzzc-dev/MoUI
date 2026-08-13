///|
fn expect_semantic_id(value : String) -> @core.SemanticId {
  @core.SemanticId::parse(value).unwrap()
}

///|
test "SemanticId: parse preserves exact case-sensitive values" {
  let upper = expect_semantic_id("Counter.Increment")
  let lower = expect_semantic_id("counter.increment")
  inspect(upper.value(), content="Counter.Increment")
  inspect(upper == lower, content="false")
  inspect(
    expect_semantic_id("\u{00E9}") == expect_semantic_id("e\u{0301}"),
    content="false",
  )
  inspect(upper.to_json() == "Counter.Increment".to_json(), content="true")
}

///|
test "SemanticId: length is measured in exact UTF-8 bytes" {
  let three_byte_codepoint = "\u{754C}"
  inspect(
    @core.SemanticId::parse(three_byte_codepoint.repeat(85)) is Some(_),
    content="true",
  )
  inspect(
    @core.SemanticId::parse(three_byte_codepoint.repeat(86)) is None,
    content="true",
  )
  inspect(@core.SemanticId::parse("a".repeat(255)) is Some(_), content="true")
  inspect(@core.SemanticId::parse("a".repeat(256)) is None, content="true")
}

///|
test "SemanticId: empty whitespace and control values are rejected" {
  let invalid = [
    "", "counter increment", "counter\nincrement", "counter\u{001B}increment", "counter\u{007F}increment",
    "counter\u{00A0}increment", "counter\u{1680}increment", "counter\u{2007}increment",
    "counter\u{2028}increment", "counter\u{3000}increment",
  ]
  for value in invalid {
    inspect(@core.SemanticId::parse(value) is None, content="true")
  }
}

///|
test "semantics node and generation IDs use lossless decimal wire strings" {
  let node_id = @core.SemanticsNodeId::new(0xFFFFFFFFFFFFFFFFUL)
  let generation = @core.SemanticsGeneration::new(9007199254740993UL)
  inspect(node_id.value() == 0xFFFFFFFFFFFFFFFFUL, content="true")
  inspect(node_id.to_wire(), content="18446744073709551615")
  inspect(node_id.to_json() == "18446744073709551615".to_json(), content="true")
  inspect(generation.value() == 9007199254740993UL, content="true")
  inspect(generation.to_wire(), content="9007199254740993")
  inspect(generation.to_json() == "9007199254740993".to_json(), content="true")
}

///|
test "SemanticsAction: typed payloads map to payload-free capabilities" {
  let set_text = @core.SemanticsAction::SetText("Luna")
  let scroll = @core.SemanticsAction::Scroll(
    @core.SemanticsScrollDirection::Left,
  )
  inspect(set_text.kind() == @core.SemanticsActionKind::SetText, content="true")
  inspect(scroll.kind() == @core.SemanticsActionKind::Scroll, content="true")
  match set_text {
    SetText(value) => inspect(value, content="Luna")
    _ => fail("expected SetText payload")
  }
  match scroll {
    Scroll(Left) => ()
    _ => fail("expected typed left scroll direction")
  }
}

///|
test "SemanticsAction: every capability has a typed invocation" {
  let actions : Array[@core.SemanticsAction] = [
    Activate,
    Focus,
    SetText("value"),
    Submit,
    Scroll(Forward),
    Select,
    Expand,
    Collapse,
    Dismiss,
  ]
  let expected : Array[@core.SemanticsActionKind] = [
    Activate,
    Focus,
    SetText,
    Submit,
    Scroll,
    Select,
    Expand,
    Collapse,
    Dismiss,
  ]
  inspect(actions.map(action => action.kind()) == expected, content="true")
}

///|
test "semantic composition and targets are explicit" {
  let id = expect_semantic_id("counter.increment")
  let node_id = @core.SemanticsNodeId::new(42UL)
  let compositions : Array[@core.SemanticsComposition] = [
    Transparent,
    Boundary,
    MergeDescendants,
    Hidden,
  ]
  inspect(compositions.length(), content="4")
  let targets : Array[@core.SemanticsTarget] = [
    BySemanticId(id),
    ByNodeId(node_id),
  ]
  match targets {
    [BySemanticId(stable), ByNodeId(node)] => {
      inspect(stable == id, content="true")
      inspect(node == node_id, content="true")
    }
    _ => fail("expected both semantic target forms")
  }
}

///|
test "SemanticsNode advertises capability kinds and stable identity" {
  let semantic_id = expect_semantic_id("counter.increment")
  let node : @core.SemanticsNode = {
    node_id: @core.SemanticsNodeId::new(7UL),
    semantic_id: Some(semantic_id),
    role: @core.SemanticsRole::Button,
    level: None,
    url: "",
    label: "Increment",
    value: "",
    description: "",
    state: @core.SemanticsState::default(),
    numeric: None,
    text: None,
    collection: None,
    relations: @core.SemanticsRelations::empty(),
    live: @core.SemanticsLive::Off,
    live_atomic: false,
    actions: [@core.SemanticsActionKind::Focus, Activate],
    focus_order: Some(0),
    frame: @core.Rect::new(x=0.0, y=0.0, width=80.0, height=32.0),
    children: [],
  }
  inspect(node.node_id == @core.SemanticsNodeId::new(7UL), content="true")
  inspect(node.semantic_id == Some(semantic_id), content="true")
  inspect(
    node.actions ==
    [@core.SemanticsActionKind::Focus, @core.SemanticsActionKind::Activate],
    content="true",
  )
}
