///|
struct ViewBuilderCacheTestNode {
  label : String
  message : Int32
}

///|
impl @core.ViewNode for ViewBuilderCacheTestNode with fn identity(self) {
  @core.ViewIdentity::new(kind="view-builder-cache-test", key=Some(self.label))
}

///|
impl @core.ViewNode for ViewBuilderCacheTestNode with fn layout(self, context) {
  @core.ViewLayoutResult::new(
    size=context.constraints.constrain(
      @core.Size::new(width=self.label.length().to_double(), height=10.0),
    ),
  )
}

///|
impl @core.ViewNode for ViewBuilderCacheTestNode with fn semantics(self) {
  @core.ViewSemanticsInfo::leaf(role=Button, label=self.label)
}

///|
fn view_builder_cache_test_view(
  label : String,
  message : Int32,
  action_message : Int32,
) -> @core.View[Int32] {
  @core.View::from_node(
    ViewBuilderCacheTestNode::{ label, message, },
    event=(node, _context) => @core.ViewEventResult::message(node.message),
    semantics_actions=_node => {
      [
        @core.ViewSemanticsActionHandler::activate(_context => {
          @core.ViewSemanticsActionResult::message(action_message)
        }),
      ]
    },
  )
}

///|
fn view_builder_cache_test_builder_key(
  kind : String,
  id : String,
) -> @core.DeclarationKey {
  @core.DeclarationKey::record(type_tag="view-builder-cache-test.builder", fields=[
    ("kind", @core.DeclarationKey::string(kind)),
    ("id", @core.DeclarationKey::string(id)),
  ])
}

///|
fn view_builder_cache_test_content_key(
  label : String,
  message : Int32,
  action_message : Int32,
  theme : String,
) -> @core.DeclarationKey {
  @core.DeclarationKey::record(type_tag="view-builder-cache-test.content", fields=[
    ("label", @core.DeclarationKey::string(label)),
    ("message", @core.DeclarationKey::int(message)),
    ("action_message", @core.DeclarationKey::int(action_message)),
    ("theme", @core.DeclarationKey::string(theme)),
  ])
}

///|
fn view_builder_cache_test_event_context() -> @core.ViewEventContext {
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
fn view_builder_cache_test_semantics_context(
  context : @core.ViewEventContext,
) -> @core.ViewSemanticsActionContext {
  {
    frame: context.frame,
    child_frames: context.child_frames,
    focused: context.focused,
    state: context.state,
    text_control: context.text_control,
    text_system: context.text_system,
    environment: context.environment,
    style: context.style,
  }
}

///|
test "ViewBuilderCache hits only equal builder and content keys" {
  let build_count = Ref(0)
  let cache : @core.ViewBuilderCache[Int32] = @core.ViewBuilderCache::new()
  let builder_key = view_builder_cache_test_builder_key("item", "a")
  let content_key = view_builder_cache_test_content_key("A", 1, 11, "light")
  let first = cache.view(builder_key~, content_key~, build=() => {
    build_count.val = build_count.val + 1
    view_builder_cache_test_view("A", 1, 11)
  })
  let second = cache.view(
    builder_key=view_builder_cache_test_builder_key("item", "a"),
    content_key=view_builder_cache_test_content_key("A", 1, 11, "light"),
    build=() => {
      build_count.val = build_count.val + 1
      view_builder_cache_test_view("stale", 99, 99)
    },
  )
  assert_eq(build_count.val, 1)
  assert_eq(
    second.identity().key.map(key => key.value()),
    first.identity().key.map(key => key.value()),
  )
  assert_eq(second.event(view_builder_cache_test_event_context()).messages, [1])
  let stats = cache.stats()
  assert_eq(stats.build_count(), 1)
  assert_eq(stats.hit_count(), 1)
  assert_eq(stats.miss_count(), 1)
  assert_eq(stats.entry_count(), 1)
}

///|
test "ViewBuilderCache replaces one builder when content changes" {
  let build_count = Ref(0)
  let cache : @core.ViewBuilderCache[Int32] = @core.ViewBuilderCache::new()
  let builder_key = view_builder_cache_test_builder_key("item", "a")
  let render = theme => {
    cache.view(
      builder_key~,
      content_key=view_builder_cache_test_content_key(
        "\{theme}-item",
        7,
        70,
        theme,
      ),
      build=() => {
        build_count.val = build_count.val + 1
        view_builder_cache_test_view("\{theme}-item", 7, 70)
      },
    )
  }
  let light = render("light")
  let dark = render("dark")
  assert_eq(build_count.val, 2)
  assert_eq(light.identity().key.map(key => key.value()), Some("light-item"))
  assert_eq(dark.identity().key.map(key => key.value()), Some("dark-item"))
  let stats = cache.stats()
  assert_eq(stats.build_count(), 2)
  assert_eq(stats.hit_count(), 0)
  assert_eq(stats.miss_count(), 2)
  assert_eq(stats.entry_count(), 1)
}

///|
test "ViewBuilderCache isolates different builders with equal content" {
  let cache : @core.ViewBuilderCache[Int32] = @core.ViewBuilderCache::new()
  let content_key = view_builder_cache_test_content_key("same", 3, 30, "light")
  let first = cache.view(
    builder_key=view_builder_cache_test_builder_key("item", "a"),
    content_key~,
    build=() => view_builder_cache_test_view("first", 3, 30),
  )
  let second = cache.view(
    builder_key=view_builder_cache_test_builder_key("item", "b"),
    content_key~,
    build=() => view_builder_cache_test_view("second", 3, 30),
  )
  assert_eq(first.identity().key.map(key => key.value()), Some("first"))
  assert_eq(second.identity().key.map(key => key.value()), Some("second"))
  assert_eq(cache.stats().build_count(), 2)
  assert_eq(cache.stats().entry_count(), 2)
}

///|
test "ViewBuilderCache keeps stable identities across keyed reorder" {
  let build_count = Ref(0)
  let cache : @core.ViewBuilderCache[Int32] = @core.ViewBuilderCache::new()
  let item = (id, value) => {
    cache.view(
      builder_key=view_builder_cache_test_builder_key("list-item", id),
      content_key=view_builder_cache_test_content_key(
        "item-\{id}",
        value,
        value,
        "light",
      ),
      build=() => {
        build_count.val = build_count.val + 1
        view_builder_cache_test_view("item-\{id}", value, value)
      },
    )
  }
  let first = [item("a", 1), item("b", 2)]
  let reordered = [item("b", 2), item("a", 1)]
  assert_eq(build_count.val, 2)
  assert_eq(first[0].identity().key.map(key => key.value()), Some("item-a"))
  assert_eq(first[1].identity().key.map(key => key.value()), Some("item-b"))
  assert_eq(reordered[0].identity().key.map(key => key.value()), Some("item-b"))
  assert_eq(reordered[1].identity().key.map(key => key.value()), Some("item-a"))
  let stats = cache.stats()
  assert_eq(stats.hit_count(), 2)
  assert_eq(stats.miss_count(), 2)
  assert_eq(stats.entry_count(), 2)
}

///|
test "ViewBuilderCache conditional replacement removes only the old branch" {
  let cache : @core.ViewBuilderCache[Int32] = @core.ViewBuilderCache::new()
  let branch_a = view_builder_cache_test_builder_key("conditional", "a")
  let branch_b = view_builder_cache_test_builder_key("conditional", "b")
  let render = (builder_key, label, message) => {
    cache.view(
      builder_key~,
      content_key=view_builder_cache_test_content_key(
        label, message, message, "light",
      ),
      build=() => view_builder_cache_test_view(label, message, message),
    )
  }
  let first = render(branch_a, "A", 1)
  let second = render(branch_b, "B", 2)
  assert_eq(first.event(view_builder_cache_test_event_context()).messages, [1])
  assert_eq(second.event(view_builder_cache_test_event_context()).messages, [2])
  cache.remove(branch_a)
  assert_eq(cache.stats().entry_count(), 1)
  let cached_b = render(branch_b, "B", 2)
  assert_eq(cached_b.identity().key.map(key => key.value()), Some("B"))
  assert_eq(cache.stats().hit_count(), 1)
  let rebuilt_a = render(branch_a, "A", 1)
  assert_eq(rebuilt_a.identity().key.map(key => key.value()), Some("A"))
  assert_eq(cache.stats().build_count(), 3)
  assert_eq(cache.stats().entry_count(), 2)
}

///|
test "ViewBuilderCache rebuilds when theme or environment content changes" {
  let build_count = Ref(0)
  let cache : @core.ViewBuilderCache[Int32] = @core.ViewBuilderCache::new()
  let builder_key = view_builder_cache_test_builder_key("themed", "card")
  let render = (theme, scale) => {
    cache.view(
      builder_key~,
      content_key=@core.DeclarationKey::record(
        type_tag="view-builder-cache-test.environment",
        fields=[
          ("theme", @core.DeclarationKey::string(theme)),
          ("scale", @core.DeclarationKey::double(scale)),
        ],
      ),
      build=() => {
        build_count.val = build_count.val + 1
        view_builder_cache_test_view("\{theme}-\{scale}", 5, 50)
      },
    )
  }
  let first = render("light", 1.0)
  let second = render("dark", 1.0)
  let third = render("dark", 1.25)
  assert_eq(build_count.val, 3)
  assert_eq(first.identity().key.map(key => key.value()), Some("light-1"))
  assert_eq(second.identity().key.map(key => key.value()), Some("dark-1"))
  assert_eq(third.identity().key.map(key => key.value()), Some("dark-1.25"))
}

///|
test "ViewBuilderCache content key covers captured event payloads" {
  let build_count = Ref(0)
  let cache : @core.ViewBuilderCache[Int32] = @core.ViewBuilderCache::new()
  let builder_key = view_builder_cache_test_builder_key("button", "submit")
  let render = message => {
    cache.view(
      builder_key~,
      content_key=view_builder_cache_test_content_key(
        "Submit",
        message,
        message + 100,
        "light",
      ),
      build=() => {
        build_count.val = build_count.val + 1
        view_builder_cache_test_view("Submit", message, message + 100)
      },
    )
  }
  ignore(render(1))
  let second = render(2)
  assert_eq(build_count.val, 2)
  assert_eq(second.event(view_builder_cache_test_event_context()).messages, [2])
  assert_eq(
    second.dispatch_semantics_action(
      view_builder_cache_test_semantics_context(
        view_builder_cache_test_event_context(),
      ),
      Activate,
    ).messages,
    [102],
  )
}

///|
test "ViewBuilderCache preserves mapped event and semantics behavior" {
  let cache : @core.ViewBuilderCache[Int32] = @core.ViewBuilderCache::new()
  let mapped = cache
    .view(
      builder_key=view_builder_cache_test_builder_key("mapped", "a"),
      content_key=view_builder_cache_test_content_key("Mapped", 41, 42, "light"),
      build=() => view_builder_cache_test_view("Mapped", 41, 42),
    )
    .map(message => "mapped-\{message}")
  let context = view_builder_cache_test_event_context()
  assert_eq(mapped.semantics().label, Some("Mapped"))
  assert_eq(mapped.event(context).messages, ["mapped-41"])
  assert_true(mapped.semantics_action_kinds() == [Activate])
  let action_result = mapped.dispatch_semantics_action(
    view_builder_cache_test_semantics_context(context),
    Activate,
  )
  assert_true(action_result.accepted)
  assert_eq(action_result.messages, ["mapped-42"])
}

///|
test "ViewBuilderCache aliases entries across handles and clear keeps counters" {
  let cache : @core.ViewBuilderCache[Int32] = @core.ViewBuilderCache::new()
  let shared_handle = cache
  ignore(
    cache.view(
      builder_key=view_builder_cache_test_builder_key("item", "a"),
      content_key=view_builder_cache_test_content_key("A", 1, 1, "light"),
      build=() => view_builder_cache_test_view("A", 1, 1),
    ),
  )
  ignore(
    shared_handle.view(
      builder_key=view_builder_cache_test_builder_key("item", "b"),
      content_key=view_builder_cache_test_content_key("B", 2, 2, "light"),
      build=() => view_builder_cache_test_view("B", 2, 2),
    ),
  )
  assert_eq(cache.stats().entry_count(), 2)
  shared_handle.clear()
  let stats = cache.stats()
  assert_eq(stats.entry_count(), 0)
  assert_eq(stats.build_count(), 2)
  assert_eq(stats.hit_count(), 0)
  assert_eq(stats.miss_count(), 2)
}

///|
test "ViewBuilderCache rebuilds only the changed item in a keyed collection" {
  let build_count = Ref(0)
  let item_count = 64
  let cache : @core.ViewBuilderCache[Int32] = @core.ViewBuilderCache::new()
  let builder_keys : Array[@core.DeclarationKey] = []
  for index in 0..<item_count {
    builder_keys.push(
      view_builder_cache_test_builder_key("collection-item", index.to_string()),
    )
  }
  let values = Array::make(item_count, 0)
  let render = () => {
    let views : Array[@core.View[Int32]] = []
    for index in 0..<item_count {
      let item_index = index
      let value = values[item_index]
      let label = "item-\{item_index}"
      views.push(
        cache.view(
          builder_key=builder_keys[item_index],
          content_key=view_builder_cache_test_content_key(
            label, value, value, "light",
          ),
          build=() => {
            build_count.val = build_count.val + 1
            view_builder_cache_test_view(label, value, value)
          },
        ),
      )
    }
    views
  }
  ignore(render())
  assert_eq(build_count.val, item_count)
  ignore(render())
  assert_eq(build_count.val, item_count)
  values[17] = 7
  let changed = render()
  assert_eq(build_count.val, item_count + 1)
  assert_eq(
    changed[17].event(view_builder_cache_test_event_context()).messages,
    [7],
  )
  let stats = cache.stats()
  assert_eq(stats.build_count(), item_count + 1)
  assert_eq(stats.hit_count(), item_count + item_count - 1)
  assert_eq(stats.miss_count(), item_count + 1)
  assert_eq(stats.entry_count(), item_count)
}
