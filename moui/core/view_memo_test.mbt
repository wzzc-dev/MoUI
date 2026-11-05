///|
struct ViewMemoTestNode {
  label : String
  message : Int32
}

///|
impl @core.ViewNode for ViewMemoTestNode with fn identity(self) {
  @core.ViewIdentity::new(kind="view-memo-test", key=Some(self.label))
}

///|
impl @core.ViewNode for ViewMemoTestNode with fn layout(self, context) {
  @core.ViewLayoutResult::new(
    size=context.constraints.constrain(
      @core.Size::new(width=self.label.length().to_double(), height=10.0),
    ),
  )
}

///|
impl @core.ViewNode for ViewMemoTestNode with fn semantics(self) {
  @core.ViewSemanticsInfo::leaf(role=Button, label=self.label)
}

///|
fn view_memo_test_view(label : String, message : Int32) -> @core.View[Int32] {
  @core.View::from_node(ViewMemoTestNode::{ label, message, }, event=(
    node,
    _context,
  ) => @core.ViewEventResult::message(node.message))
}

///|
fn view_memo_test_event_context() -> @core.ViewEventContext {
  {
    frame: @core.Rect::new(x=0.0, y=0.0, width=20.0, height=10.0),
    child_frames: [],
    event: CloseRequested,
    focused: false,
    state: {
      focused: false,
      hovered: false,
      pressed: false,
      selected: false,
      checked: false,
      expanded: false,
      disabled: false,
      slots: @core.ViewStateSlots::empty(),
    },
    text_control: {
      caret: 0,
      selection: None,
      text_selection_anchor: None,
      goal_column: None,
      reveal: None,
      text_selection_origin: None,
      composition: None,
      composition_cursor: None,
      undo_stack: [],
      redo_stack: [],
    },
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
    now_ms: 0.0,
  }
}

///|
test "ViewMemo skips build for an equal explicit key" {
  let build_count = Ref(0)
  let memo : @core.ViewMemo[Int32] = @core.ViewMemo::new()
  let first = memo.view(key=@core.DeclarationKey::string("first"), build=() => {
    build_count.val = build_count.val + 1
    view_memo_test_view("first", 1)
  })
  let second = memo.view(key=@core.DeclarationKey::string("first"), build=() => {
    build_count.val = build_count.val + 1
    view_memo_test_view("stale", 99)
  })
  assert_eq(build_count.val, 1)
  assert_eq(
    second.identity().key.map(key => key.value()),
    first.identity().key.map(key => key.value()),
  )
  assert_eq(second.event(view_memo_test_event_context()).messages, [1])
}

///|
test "ViewMemo rebuilds when its explicit key changes" {
  let build_count = Ref(0)
  let memo : @core.ViewMemo[Int32] = @core.ViewMemo::new()
  let key = Ref(0)
  let render = () => {
    let current = key.val
    memo.view(key=@core.DeclarationKey::int(current), build=() => {
      build_count.val = build_count.val + 1
      view_memo_test_view("value-\{current}", current)
    })
  }
  let first = render()
  assert_eq(first.event(view_memo_test_event_context()).messages, [0])
  key.val = 1
  let second = render()
  assert_eq(build_count.val, 2)
  assert_eq(second.identity().key.map(key => key.value()), Some("value-1"))
  assert_eq(second.event(view_memo_test_event_context()).messages, [1])
}

///|
test "ViewMemo keys are content-canonical, not object identity" {
  let build_count = Ref(0)
  let memo : @core.ViewMemo[Int32] = @core.ViewMemo::new()
  let make_key = value => {
    @core.DeclarationKey::record(type_tag="view-memo-test", fields=[
      ("value", @core.DeclarationKey::int(value)),
    ])
  }
  ignore(
    memo.view(key=make_key(7), build=() => {
      build_count.val = build_count.val + 1
      view_memo_test_view("seven", 7)
    }),
  )
  ignore(
    memo.view(key=make_key(7), build=() => {
      build_count.val = build_count.val + 1
      view_memo_test_view("wrong", 0)
    }),
  )
  assert_eq(build_count.val, 1)
}

///|
test "ViewMemo preserves mapped event and semantics behavior" {
  let memo : @core.ViewMemo[Int32] = @core.ViewMemo::new()
  let mapped = memo
    .view(key=@core.DeclarationKey::string("mapped"), build=() => {
      view_memo_test_view("Mapped", 41)
    })
    .map(message => "mapped-\{message}")
  assert_eq(mapped.semantics().label, Some("Mapped"))
  assert_eq(mapped.event(view_memo_test_event_context()).messages, ["mapped-41"])
}

///|
test "ViewMemo stats are shared by handles and count hits and builds" {
  let memo : @core.ViewMemo[Int32] = @core.ViewMemo::new()
  let shared_handle = memo
  ignore(
    memo.view(key=@core.DeclarationKey::string("first"), build=() => {
      view_memo_test_view("first", 1)
    }),
  )
  ignore(
    shared_handle.view(key=@core.DeclarationKey::string("first"), build=() => {
      view_memo_test_view("stale", 99)
    }),
  )
  ignore(
    shared_handle.view(key=@core.DeclarationKey::string("second"), build=() => {
      view_memo_test_view("second", 2)
    }),
  )
  let stats = memo.stats()
  assert_eq(stats.build_count(), 2)
  assert_eq(stats.hit_count(), 1)
  assert_eq(stats.miss_count(), 2)
}
