///|
fn bridge_test_text_input() -> @core.TextInputState {
  {
    focused: true,
    text: "世界",
    caret: 2,
    selection: Some(@core.TextRange::new(start=0, end=2)),
    composition: Some("世"),
    composition_cursor: Some(@core.TextRange::new(start=0, end=1)),
    frame: @core.Rect::new(x=4.0, y=8.0, width=200.0, height=24.0),
    caret_rect: @core.Rect::new(x=40.0, y=10.0, width=2.0, height=18.0),
  }
}

///|
fn bridge_test_semantics(
  generation : UInt64,
  node_id : UInt64,
  label : String,
) -> @core.SemanticsFramePayload {
  let node : @core.SemanticsNode = {
    node_id: @core.SemanticsNodeId::new(node_id),
    semantic_id: None,
    role: @core.SemanticsRole::TextField,
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
    actions: [@core.SemanticsActionKind::Focus],
    focus_order: Some(0),
    frame: @core.Rect::new(x=0.0, y=0.0, width=100.0, height=20.0),
    children: [],
  }
  @core.SemanticsFramePayload::new(
    generation=@core.SemanticsGeneration::new(generation),
    nodes=[node],
    root=Some(@core.SemanticsNodeId::new(node_id)),
    focused=Some(@core.SemanticsNodeId::new(node_id)),
  )
}

///|
fn bridge_test_frame(
  generation : UInt64,
  node_id : UInt64,
  label : String,
) -> @core.DrawFrame {
  @core.DrawFrame::new(
    commands=[],
    platform_views=[
      @core.PlatformViewPlacement::new(
        id="preview",
        kind="web_view",
        frame=@core.Rect::new(x=10.0, y=20.0, width=320.0, height=200.0),
        properties=[
          @core.PlatformViewProperty::new(
            key="url",
            value="https://example.test",
          ),
        ],
      ),
    ],
    overlay_bounds=Some(
      @core.Rect::new(x=10.0, y=20.0, width=320.0, height=200.0),
    ),
    damage=@core.DamageRegion::Empty,
    clear_color=@core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0),
    semantics=Some(bridge_test_semantics(generation, node_id, label)),
  )
}

///|
fn publish_test_frame(text : String) -> Unit raise {
  match @protocol.decode_frame_payload(text) {
    Some(payload) => ignore(publish_frame(payload))
    None => fail("test frame did not decode")
  }
}

///|
test "bridge frame publishes text input, platform views and full damage" {
  clear_after_reload()
  let frame = bridge_test_frame(1UL, 1UL, "Body")
  publish_test_frame(
    @protocol.encode_frame(frame, text_input=Some(bridge_test_text_input())),
  )
  let augmented = augment_frame(
    @core.DrawFrame::new(commands=[], damage=@core.DamageRegion::Empty),
  )
  assert_eq(augmented.platform_views.length(), 1)
  assert_eq(augmented.platform_views[0].kind, "web_view")
  assert_eq(
    augmented.overlay_bounds,
    Some(@core.Rect::new(x=10.0, y=20.0, width=320.0, height=200.0)),
  )
  assert_eq(augmented.clear_color.a, 0.0)
  assert_true(augmented.damage is FullSurface(_))
  let input = focused_text_input()
  assert_eq(input.focused, true)
  assert_eq(input.text, "世界")
  assert_eq(input.composition, Some("世"))
}

///|
test "bridge semantics clear stale nodes on a plugin generation swap" {
  clear_after_reload()
  publish_test_frame(@protocol.encode_frame(bridge_test_frame(7UL, 1UL, "old")))
  let first = match read_semantics(None) {
    Ok(Full(snapshot)) => snapshot
    _ => fail("expected a full snapshot")
  }
  assert_eq(first.nodes().length(), 1)
  assert_eq(first.nodes()[0].label, "old")
  let first_generation = first.generation()
  clear_after_reload()
  let empty = match read_semantics(Some(first_generation)) {
    Ok(Full(snapshot)) => snapshot
    _ => fail("expected a full empty snapshot after a swap")
  }
  assert_eq(empty.nodes().length(), 0)
  assert_true(empty.generation() != first_generation)
  let empty_generation = empty.generation()
  publish_test_frame(@protocol.encode_frame(bridge_test_frame(1UL, 2UL, "new")))
  let second = match read_semantics(Some(empty_generation)) {
    Ok(Full(snapshot)) => snapshot
    _ => fail("expected a full snapshot for the new generation")
  }
  assert_eq(second.nodes().length(), 1)
  assert_eq(second.nodes()[0].node_id, @core.SemanticsNodeId::new(2UL))
  assert_eq(second.nodes()[0].label, "new")
  match read_semantics(Some(second.generation())) {
    Ok(Unchanged(generation)) => assert_eq(generation, second.generation())
    _ => fail("expected Unchanged for an unchanged cursor")
  }
}

///|
test "renderer cache reset runs with swap cleanup" {
  let runs = Ref(0)
  install_renderer_cache_reset(Some(() => runs.val = runs.val + 1))
  clear_after_reload()
  assert_eq(runs.val, 1)
  install_renderer_cache_reset(None)
  clear_after_reload()
  assert_eq(runs.val, 1)
}

///|
fn bridge_test_fake_plugin(
  installed : Ref[@backend_host.PlatformViewEventCallback?],
  disposed : Ref[Int32],
  synced : Ref[Int32],
) -> @backend_host.PlatformViewPlugin {
  @backend_host.PlatformViewPlugin::new(
    kind="fake",
    capabilities_summary="test",
    install_event_dispatcher=dispatch => installed.val = Some(dispatch),
    sync_platform_views=(_handle, _frame, _offset) => {
      synced.val = synced.val + 1
    },
    drain_commands=_handle => (),
    dispose_platform_views=_handle => disposed.val = disposed.val + 1,
  )
}

///|
test "platform views are disposed on swap and native events are forwarded" {
  let installed : Ref[@backend_host.PlatformViewEventCallback?] = Ref(None)
  let disposed : Ref[Int32] = Ref(0)
  let synced : Ref[Int32] = Ref(0)
  let host_dispatched : Ref[Int32] = Ref(0)
  let forwarded : Ref[Int32] = Ref(0)
  let plugin = bridge_test_fake_plugin(installed, disposed, synced)
  let wrapped = wrap_platform_view_plugin(plugin, forward=(_id, _event) => {
    forwarded.val = forwarded.val + 1
  })
  let frame = @core.DrawFrame::new(
    commands=[],
    damage=@core.DamageRegion::Empty,
  )
  (wrapped.install_event_dispatcher)((_handle, _id, _event) => {
    host_dispatched.val = host_dispatched.val + 1
  })
  (wrapped.sync_platform_views)(0UL, frame, 0.0)
  assert_eq(disposed.val, 1)
  assert_eq(synced.val, 1)
  (wrapped.sync_platform_views)(0UL, frame, 0.0)
  assert_eq(disposed.val, 1)
  assert_eq(synced.val, 2)
  host_reloads.val = host_reloads.val + 1
  (wrapped.sync_platform_views)(0UL, frame, 0.0)
  assert_eq(disposed.val, 2)
  assert_eq(synced.val, 3)
  match installed.val {
    Some(dispatch) =>
      dispatch(
        0UL,
        "preview",
        @core.PlatformViewEvent::Named(
          name="navigate",
          value="https://example.test",
          detail="",
          flag=true,
        ),
      )
    None => fail("dispatcher was not installed")
  }
  assert_eq(host_dispatched.val, 1)
  assert_eq(forwarded.val, 1)
  (wrapped.dispose_platform_views)(0UL)
  assert_eq(disposed.val, 3)
  (wrapped.sync_platform_views)(0UL, frame, 0.0)
  assert_eq(disposed.val, 3)
}
