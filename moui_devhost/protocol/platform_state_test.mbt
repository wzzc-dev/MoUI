///|
fn platform_state_node_one(
  second : @core.SemanticsNodeId,
) -> @core.SemanticsNode {
  let semantic_id = @core.SemanticId::parse("editor.body").unwrap()
  let relations : @core.SemanticsRelations = {
    labelled_by: [second],
    described_by: [],
    controls: [],
    error_message: [],
    active_descendant: [],
  }
  let state : @core.SemanticsState = {
    ..@core.SemanticsState::default(),
    focused: true,
    required: true,
    multiline: true,
    checked: Some(@core.SemanticsCheckedState::Mixed),
  }
  {
    node_id: @core.SemanticsNodeId::new(1UL),
    semantic_id: Some(semantic_id),
    role: @core.SemanticsRole::TextField,
    level: Some(2),
    url: "",
    label: "Body",
    value: "hello",
    description: "editor",
    state,
    numeric: Some(
      @core.SemanticsNumericValue::new(
        current=3.0,
        min=0.0,
        max=10.0,
        step=1.0,
        value_text="3",
      ),
    ),
    text: Some(
      @core.SemanticsTextValue::new(
        selection=@core.TextRange::new(start=0, end=5),
        caret=5,
        editable=true,
      ),
    ),
    collection: Some(
      @core.SemanticsCollectionInfo::new(
        row_index=1,
        row_count=4,
        column_index=2,
        set_size=8,
      ),
    ),
    relations,
    live: @core.SemanticsLive::Polite,
    live_atomic: true,
    actions: [
      @core.SemanticsActionKind::Focus,
      @core.SemanticsActionKind::SetText,
    ],
    focus_order: Some(0),
    frame: @core.Rect::new(x=8.0, y=12.0, width=200.0, height=24.0),
    children: [second],
  }
}

///|
fn platform_state_node_two() -> @core.SemanticsNode {
  let id = @core.SemanticId::parse("editor.hint").unwrap()
  {
    node_id: @core.SemanticsNodeId::new(2UL),
    semantic_id: Some(id),
    role: @core.SemanticsRole::Text,
    level: None,
    url: "https://example.invalid/hint",
    label: "Hint",
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
    frame: @core.Rect::new(x=0.0, y=0.0, width=10.0, height=10.0),
    children: [],
  }
}

///|
fn platform_state_payload() -> @core.SemanticsFramePayload {
  let second = @core.SemanticsNodeId::new(2UL)
  @core.SemanticsFramePayload::new(
    generation=@core.SemanticsGeneration::new(9UL),
    nodes=[platform_state_node_one(second), platform_state_node_two()],
    root=Some(@core.SemanticsNodeId::new(1UL)),
    focused=Some(@core.SemanticsNodeId::new(1UL)),
  )
}

///|
fn platform_state_text_input() -> @core.TextInputState {
  {
    focused: true,
    text: "hello 世界",
    caret: 8,
    selection: Some(@core.TextRange::new(start=0, end=5)),
    composition: Some("世"),
    composition_cursor: Some(@core.TextRange::new(start=6, end=8)),
    frame: @core.Rect::new(x=4.0, y=6.0, width=300.0, height=28.0),
    caret_rect: @core.Rect::new(x=180.0, y=8.0, width=2.0, height=20.0),
  }
}

///|
fn platform_state_frame() -> @core.DrawFrame {
  let placement : @core.PlatformViewPlacement = {
    id: "preview",
    kind: "web_view",
    frame: @core.Rect::new(x=10.0, y=20.0, width=320.0, height=200.0),
    clip: Some(@core.Rect::new(x=10.0, y=20.0, width=300.0, height=180.0)),
    properties: [
      @core.PlatformViewProperty::new(key="url", value="https://example.test"),
      @core.PlatformViewProperty::new(key="transparent", value="true"),
    ],
  }
  {
    commands: [
      @core.DrawCommand::Clear(@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)),
    ],
    platform_views: [placement],
    overlay_bounds: Some(
      @core.Rect::new(x=10.0, y=20.0, width=320.0, height=200.0),
    ),
    damage: @core.DamageRegion::Empty,
    clear_color: @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0),
    semantics: Some(platform_state_payload()),
  }
}

///|
test "frame carries platform views, overlay bounds, semantics and text input" {
  let encoded = @protocol.encode_frame(
    platform_state_frame(),
    text_input=Some(platform_state_text_input()),
  )
  let payload = match @protocol.decode_frame_payload(encoded) {
    Some(payload) => payload
    None => abort("platform frame failed to decode")
  }
  assert_eq(payload.clear_color().a, 0.0)
  let views = match payload.platform_views() {
    Some(views) => views
    None => abort("platform views missing")
  }
  assert_eq(views.length(), 1)
  let view = views[0]
  assert_eq(view.id, "preview")
  assert_eq(view.kind, "web_view")
  assert_eq(view.frame.size.width, 320.0)
  assert_eq(
    view.clip,
    Some(@core.Rect::new(x=10.0, y=20.0, width=300.0, height=180.0)),
  )
  assert_eq(view.properties.length(), 2)
  assert_eq(view.properties[0].key, "url")
  assert_eq(view.properties[0].value, "https://example.test")
  assert_eq(
    payload.overlay_bounds(),
    Some(@core.Rect::new(x=10.0, y=20.0, width=320.0, height=200.0)),
  )
  let semantics = match payload.semantics() {
    Some(semantics) => semantics
    None => abort("semantics missing")
  }
  assert_eq(semantics.generation(), @core.SemanticsGeneration::new(9UL))
  assert_eq(semantics.root(), Some(@core.SemanticsNodeId::new(1UL)))
  assert_eq(semantics.focused(), Some(@core.SemanticsNodeId::new(1UL)))
  let nodes = semantics.nodes()
  assert_eq(nodes.length(), 2)
  let node = nodes[0]
  assert_eq(node.role, @core.SemanticsRole::TextField)
  assert_eq(node.semantic_id.unwrap().value(), "editor.body")
  assert_eq(node.level, Some(2))
  assert_eq(node.state.focused, true)
  assert_eq(node.state.checked, Some(@core.SemanticsCheckedState::Mixed))
  assert_eq(node.numeric.unwrap().current, Some(3.0))
  assert_eq(node.text.unwrap().caret, Some(5))
  assert_eq(
    node.text.unwrap().selection,
    Some(@core.TextRange::new(start=0, end=5)),
  )
  assert_eq(node.collection.unwrap().row_index, Some(1))
  assert_eq(node.relations.labelled_by, [@core.SemanticsNodeId::new(2UL)])
  assert_eq(node.live, @core.SemanticsLive::Polite)
  assert_eq(node.live_atomic, true)
  assert_eq(node.actions, [
    @core.SemanticsActionKind::Focus,
    @core.SemanticsActionKind::SetText,
  ])
  assert_eq(node.focus_order, Some(0))
  assert_eq(node.children, [@core.SemanticsNodeId::new(2UL)])
  let input = match payload.text_input() {
    Some(input) => input
    None => abort("text input missing")
  }
  assert_eq(input.focused, true)
  assert_eq(input.text, "hello 世界")
  assert_eq(input.caret, 8)
  assert_eq(input.selection, Some(@core.TextRange::new(start=0, end=5)))
  assert_eq(input.composition, Some("世"))
  assert_eq(
    input.composition_cursor,
    Some(@core.TextRange::new(start=6, end=8)),
  )
  assert_eq(
    input.caret_rect,
    @core.Rect::new(x=180.0, y=8.0, width=2.0, height=20.0),
  )
}

///|
test "legacy frames decode without platform state" {
  let legacy = "{\"version\":1,\"commands\":[]}"
  let payload = match @protocol.decode_frame_payload(legacy) {
    Some(payload) => payload
    None => abort("legacy frame failed to decode")
  }
  assert_eq(payload.platform_views(), None)
  assert_eq(payload.overlay_bounds(), None)
  assert_eq(payload.semantics(), None)
  assert_eq(payload.text_input(), None)
}

///|
test "present malformed platform state rejects the frame" {
  let malformed = [
    "{\"version\":1,\"commands\":[],\"platform_views\":\"nope\"}", "{\"version\":1,\"commands\":[],\"platform_views\":[{\"id\":\"x\"}]}",
    "{\"version\":1,\"commands\":[],\"overlay_bounds\":{\"x\":1}}", "{\"version\":1,\"commands\":[],\"semantics\":{\"generation\":\"nope\"}}",
    "{\"version\":1,\"commands\":[],\"text_input\":{\"focused\":true}}",
  ]
  for text in malformed {
    assert_true(@protocol.decode_frame_payload(text) is None)
  }
}

///|
test "text input state round trips standalone" {
  let encoded = @protocol.encode_text_input_state(platform_state_text_input())
  assert_true(
    @protocol.decode_text_input_state(encoded) ==
    Some(platform_state_text_input()),
  )
  assert_eq(@protocol.decode_text_input_state("{}"), None)
}

///|
test "semantics action request round trips every target and action form" {
  let id = @core.SemanticId::parse("editor.body").unwrap()
  let request : @runtime.PerformSemanticsActionRequest = {
    target: @core.SemanticsTarget::BySemanticId(id),
    action: @core.SemanticsAction::SetSelection(
      @core.TextRange::new(start=1, end=3),
    ),
    precondition: @runtime.SemanticsGenerationPrecondition::Exact(
      @core.SemanticsGeneration::new(9UL),
    ),
  }
  assert_eq(
    @protocol.decode_semantics_action_request(
      @protocol.encode_semantics_action_request(request),
    ),
    Some(request),
  )
  let path_request : @runtime.PerformSemanticsActionRequest = {
    target: @core.SemanticsTarget::ByPath([
      @core.SemanticsPathSegment::{
        index: 0,
        role: Some(@core.SemanticsRole::TextField),
        label: Some("Body"),
        value: None,
        semantic_id: Some(id),
      },
    ]),
    action: @core.SemanticsAction::Scroll(@core.SemanticsScrollDirection::Down),
    precondition: @runtime.SemanticsGenerationPrecondition::Latest,
  }
  assert_eq(
    @protocol.decode_semantics_action_request(
      @protocol.encode_semantics_action_request(path_request),
    ),
    Some(path_request),
  )
  assert_eq(@protocol.decode_semantics_action_request("{}"), None)
}

///|
test "semantics action results carry receipts and errors across the ABI" {
  let receipt : @runtime.SemanticsActionReceipt = {
    before: @core.SemanticsGeneration::new(3UL),
    after: @core.SemanticsGeneration::new(4UL),
    pending_work: true,
  }
  let ok : Result[
    @runtime.SemanticsActionReceipt,
    @runtime.SemanticsActionDispatchError,
  ] = Ok(receipt)
  assert_eq(
    @protocol.decode_semantics_action_result(
      @protocol.encode_semantics_action_result(ok),
    ),
    Some(ok),
  )
  let id = @core.SemanticId::parse("editor.body").unwrap()
  let failures : Array[@runtime.SemanticsActionDispatchError] = [
    @runtime.SemanticsActionDispatchError::RuntimeClosed,
    @runtime.SemanticsActionDispatchError::StaleGeneration(
      @core.SemanticsGeneration::new(1UL),
      @core.SemanticsGeneration::new(2UL),
    ),
    @runtime.SemanticsActionDispatchError::TargetNotFound(
      @core.SemanticsTarget::BySemanticId(id),
    ),
    @runtime.SemanticsActionDispatchError::TargetAmbiguous(id),
    @runtime.SemanticsActionDispatchError::TargetDisabled(
      @core.SemanticsTarget::ByNodeId(@core.SemanticsNodeId::new(1UL)),
    ),
    @runtime.SemanticsActionDispatchError::ActionUnavailable(
      @core.SemanticsTarget::ByNodeId(@core.SemanticsNodeId::new(1UL)),
      @core.SemanticsActionKind::Activate,
    ),
    @runtime.SemanticsActionDispatchError::HandlerRejected(
      @core.SemanticsTarget::BySemanticId(id),
      @core.SemanticsActionKind::SetText,
    ),
    @runtime.SemanticsActionDispatchError::ReentrantDispatch,
  ]
  for error in failures {
    let result : Result[
      @runtime.SemanticsActionReceipt,
      @runtime.SemanticsActionDispatchError,
    ] = Err(error)
    assert_eq(
      @protocol.decode_semantics_action_result(
        @protocol.encode_semantics_action_result(result),
      ),
      Some(result),
    )
  }
  assert_eq(@protocol.decode_semantics_action_result("{\"ok\":true}"), None)
}
