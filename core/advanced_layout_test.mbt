///|
test "stack lays children over the same frame in paint order" {
  let stack = ViewSpec::StackSpec({
    key: None,
    children: [
      ViewSpec::TextSpec({
        key: None,
        text: "A",
        size: Size::new(width=40.0, height=20.0),
        font: FontSpec::new(),
        color: Color::black(),
      }),
      ViewSpec::TextSpec({
        key: None,
        text: "B",
        size: Size::new(width=20.0, height=10.0),
        font: FontSpec::new(),
        color: Color::blue(),
      }),
    ],
  })
  let layout = layout_spec(
    stack,
    Rect::new(x=0.0, y=0.0, width=100.0, height=80.0),
  )
  inspect(layout.children.length(), content="2")
  assert_true(layout.children[0].frame == layout.frame)
  assert_true(layout.children[1].frame == layout.frame)
}

///|
test "scroll view emits clip and offsets child frame" {
  let scroll = ViewSpec::ScrollSpec({
    key: None,
    offset: Point::new(x=0.0, y=12.0),
    viewport: Some(Size::new(width=80.0, height=40.0)),
    child: ViewSpec::TextSpec({
      key: None,
      text: "Scrolled",
      size: Size::new(width=120.0, height=80.0),
      font: FontSpec::new(),
      color: Color::black(),
    }),
  })
  let render = mount_view_spec(scroll).render(
    Rect::new(x=5.0, y=6.0, width=80.0, height=40.0),
  )
  guard render.paint_commands is [PushClip(_)] else {
    fail("expected scroll clip commands")
  }
  guard render.post_paint_commands is [PopClip] else {
    fail("expected scroll pop clip after children")
  }
  inspect(render.children[0].frame.origin.y, content="-6")
}

///|
test "scroll clip wraps child draw commands in collected paint order" {
  let scroll = ViewSpec::ScrollSpec({
    key: None,
    offset: Point::new(x=0.0, y=0.0),
    viewport: Some(Size::new(width=80.0, height=40.0)),
    child: ViewSpec::ModifiedSpec({
      key: None,
      modifier: ClipModifier,
      child: ViewSpec::TextSpec({
        key: None,
        text: "Nested",
        size: Size::new(width=120.0, height=80.0),
        font: FontSpec::new(),
        color: Color::black(),
      }),
    }),
  })
  let commands : Array[DrawCommand] = []
  mount_view_spec(scroll)
  .render(Rect::new(x=0.0, y=0.0, width=80.0, height=40.0))
  .collect_draw_commands(commands)
  inspect(commands.length(), content="5")
  assert_true(commands[0] is PushClip(_))
  assert_true(commands[1] is PushClip(_))
  assert_true(commands[2] is DrawText(_))
  assert_true(commands[3] is PopClip)
  assert_true(commands[4] is PopClip)
}

///|
test "modifier order changes background frame around padding" {
  let inner_background = test_label("A").background(Color::blue()).padding(8.0)
  let outer_background = test_label("A").padding(8.0).background(Color::blue())
  let inner_commands : Array[DrawCommand] = []
  mount_view_spec(inner_background)
  .render(Rect::new(x=0.0, y=0.0, width=96.0, height=40.0))
  .collect_draw_commands(inner_commands)
  let outer_commands : Array[DrawCommand] = []
  mount_view_spec(outer_background)
  .render(Rect::new(x=0.0, y=0.0, width=96.0, height=40.0))
  .collect_draw_commands(outer_commands)
  guard inner_commands[0] is FillRoundedRectBrush({ rect: inner_rect, .. }, _) else {
    fail("expected inner background")
  }
  guard outer_commands[0] is FillRoundedRectBrush({ rect: outer_rect, .. }, _) else {
    fail("expected outer background")
  }
  inspect(inner_rect.origin.x, content="8")
  inspect(inner_rect.size.width, content="80")
  inspect(outer_rect.origin.x, content="0")
  inspect(outer_rect.size.width, content="96")
}

///|
test "opacity and clip modifiers preserve nested push pop order" {
  let spec = test_label("A").clip().opacity(0.5)
  let commands : Array[DrawCommand] = []
  mount_view_spec(spec)
  .render(Rect::new(x=0.0, y=0.0, width=80.0, height=20.0))
  .collect_draw_commands(commands)
  inspect(commands.length(), content="5")
  assert_true(commands[0] is PushOpacity(0.5))
  assert_true(commands[1] is PushClip(_))
  assert_true(commands[2] is DrawText(_))
  assert_true(commands[3] is PopClip)
  assert_true(commands[4] is PopOpacity)
}

///|
test "grid lays children into fixed columns" {
  let grid = ViewSpec::GridSpec({
    key: None,
    columns: 2,
    row_spacing: 4.0,
    column_spacing: 8.0,
    children: [
      ViewSpec::TextSpec({
        key: None,
        text: "A",
        size: Size::new(width=40.0, height=20.0),
        font: FontSpec::new(),
        color: Color::black(),
      }),
      ViewSpec::TextSpec({
        key: None,
        text: "B",
        size: Size::new(width=40.0, height=20.0),
        font: FontSpec::new(),
        color: Color::black(),
      }),
      ViewSpec::TextSpec({
        key: None,
        text: "C",
        size: Size::new(width=40.0, height=20.0),
        font: FontSpec::new(),
        color: Color::black(),
      }),
    ],
  })
  let layout = layout_spec(
    grid,
    Rect::new(x=0.0, y=0.0, width=108.0, height=80.0),
  )
  inspect(layout.children.length(), content="3")
  inspect(layout.children[0].frame.size.width, content="50")
  inspect(layout.children[1].frame.origin.x, content="58")
  inspect(layout.children[2].frame.origin.y, content="24")
}

///|
test "custom layout delegate measures places paints and exposes child semantics" {
  let spec = ViewSpec::custom_layout(
    children=[
      test_label("A").key("a"),
      test_label("B").key("b"),
    ],
    measure=ctx => {
      ctx.constraints.constrain(
        Size::new(
          width=ctx.child_sizes[0].width + ctx.child_sizes[1].width + 6.0,
          height=20.0,
        ),
      )
    },
    place=ctx => {
      [
        Rect::new(
          x=ctx.frame.origin.x,
          y=ctx.frame.origin.y,
          width=ctx.child_sizes[0].width,
          height=ctx.frame.size.height,
        ),
        Rect::new(
          x=ctx.frame.origin.x + ctx.child_sizes[0].width + 6.0,
          y=ctx.frame.origin.y,
          width=ctx.child_sizes[1].width,
          height=ctx.frame.size.height,
        ),
      ]
    },
    paint=frame => {
      [
        DrawCommand::FillRoundedRectBrush(
          RoundedRect::new(rect=frame, radius=2.0),
          Brush::solid(Color::gray()),
        ),
      ]
    },
    semantics_role=SemanticsRole::Group,
    semantics_label="Custom row",
  ).key("custom-row")
  let runtime = RuntimeState::new_spec(
    root=spec,
    size=Size::new(width=120.0, height=32.0),
  )
  let layout = runtime.layout()
  inspect(layout.children.length(), content="2")
  inspect(layout.children[1].frame.origin.x, content="86")
  let commands = runtime.build_draw_commands()
  assert_true(
    commands.any(command => {
      command is DrawCommand::FillRoundedRectBrush(_, Brush::Solid(_))
    }),
  )
  let semantics = runtime.semantics()
  inspect(semantics.label, content="Custom row")
  inspect(semantics.children.length(), content="2")
  assert_true(runtime.element_tree.find_keyed("b") is Some(_))
}

///|
test "custom layout delegate receives child baselines and layout priorities" {
  let first_baseline_ref : Ref[Double?] = Ref(None)
  let first_priority_ref = Ref(0.0)
  let second_priority_ref = Ref(0.0)
  let spec = ViewSpec::custom_layout(
    children=[
      test_label("Title").layout_priority(2.0),
      ViewSpec::TextSpec({
        key: None,
        text: "Caption",
        size: Size::new(width=52.0, height=18.0),
        font: FontSpec::new(size=10.0, weight=400),
        color: Color::black(),
      }),
    ],
    measure=ctx => {
      first_baseline_ref.val = ctx.child_baselines[0]
      first_priority_ref.val = ctx.child_priorities[0]
      second_priority_ref.val = ctx.child_priorities[1]
      Size::new(width=132.0, height=32.0)
    },
    place=ctx => {
      let first_baseline = ctx.child_baselines[0].unwrap_or(0.0)
      let second_baseline = ctx.child_baselines[1].unwrap_or(0.0)
      let shared_baseline = if first_baseline > second_baseline {
        first_baseline
      } else {
        second_baseline
      }
      [
        Rect::new(
          x=ctx.frame.origin.x,
          y=ctx.frame.origin.y + shared_baseline - first_baseline,
          width=ctx.child_sizes[0].width,
          height=ctx.child_sizes[0].height,
        ),
        Rect::new(
          x=ctx.frame.origin.x + 80.0,
          y=ctx.frame.origin.y + shared_baseline - second_baseline,
          width=ctx.child_sizes[1].width,
          height=ctx.child_sizes[1].height,
        ),
      ]
    },
  )
  let layout = layout_spec(
    spec,
    Rect::new(x=0.0, y=0.0, width=132.0, height=32.0),
  )
  match first_baseline_ref.val {
    Some(baseline) => inspect(baseline, content="12.8")
    None => fail("expected text baseline")
  }
  inspect(first_priority_ref.val, content="2")
  inspect(second_priority_ref.val, content="0")
  inspect(layout.children[0].frame.origin.y, content="0")
  inspect((layout.children[1].frame.origin.y * 10.0).to_int(), content="48")
}

///|
test "list lays out keyed rows and reconcile preserves keyed identity" {
  let first = ViewSpec::TextSpec({
    key: None,
    text: "First",
    size: Size::new(width=40.0, height=20.0),
    font: FontSpec::new(),
    color: Color::black(),
  }).key("first")
  let second = ViewSpec::TextSpec({
    key: None,
    text: "Second",
    size: Size::new(width=40.0, height=30.0),
    font: FontSpec::new(),
    color: Color::black(),
  }).key("second")
  let old = mount_view_spec(
    ViewSpec::ListSpec({ key: None, spacing: 6.0, children: [first, second] }),
  )
  let first_id = old.children[0].id
  let second_id = old.children[1].id
  let next = reconcile_element(
    old,
    ViewSpec::ListSpec({ key: None, spacing: 6.0, children: [second, first] }),
  )
  assert_true(next.children[0].id == second_id)
  assert_true(next.children[1].id == first_id)
  let layout = next
    .render(Rect::new(x=0.0, y=0.0, width=120.0, height=80.0))
    .to_layout_result()
  inspect(layout.children[1].frame.origin.y, content="36")
}

///|
test "measure pass deflates padding constraints and inflates size" {
  let root = ViewSpec::PaddingSpec({
    key: None,
    insets: Insets::all(5.0),
    child: ViewSpec::TextSpec({
      key: None,
      text: "A",
      size: Size::new(width=100.0, height=80.0),
      font: FontSpec::new(),
      color: Color::black(),
    }),
  })
  let measured = mount_view_spec(root).measure(
    Constraints::loose(Size::new(width=60.0, height=50.0)),
  )
  inspect(measured.children[0].size.width, content="50")
  inspect(measured.children[0].size.height, content="40")
  inspect(measured.size.width, content="60")
  inspect(measured.size.height, content="50")
}

///|
test "measure pass applies frame constraints before placement" {
  let root = ViewSpec::FrameSpec({
    key: None,
    width: Some(64.0),
    height: Some(24.0),
    min_width: None,
    min_height: None,
    max_width: None,
    max_height: None,
    child: ViewSpec::TextSpec({
      key: None,
      text: "A",
      size: Size::new(width=100.0, height=80.0),
      font: FontSpec::new(),
      color: Color::black(),
    }),
  })
  let measured = mount_view_spec(root).measure(Constraints::unbounded())
  inspect(measured.size.width, content="64")
  inspect(measured.size.height, content="24")
}

///|
test "measure pass keeps flex size from measured children" {
  let root = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Horizontal,
    spacing: 4.0,
    main_axis_alignment: MainStart,
    cross_axis_alignment: CrossStart,
    children: [
      ViewSpec::TextSpec({
        key: None,
        text: "A",
        size: Size::new(width=20.0, height=10.0),
        font: FontSpec::new(),
        color: Color::black(),
      }),
      ViewSpec::TextSpec({
        key: None,
        text: "B",
        size: Size::new(width=30.0, height=16.0),
        font: FontSpec::new(),
        color: Color::black(),
      }),
    ],
  })
  let measured = mount_view_spec(root).measure(Constraints::unbounded())
  inspect(measured.size.width, content="54")
  inspect(measured.size.height, content="16")
}

///|
test "scroll measure allows child to exceed viewport constraints" {
  let root = ViewSpec::ScrollSpec({
    key: None,
    offset: Point::new(x=0.0, y=0.0),
    viewport: Some(Size::new(width=40.0, height=30.0)),
    child: ViewSpec::TextSpec({
      key: None,
      text: "Large",
      size: Size::new(width=100.0, height=90.0),
      font: FontSpec::new(),
      color: Color::black(),
    }),
  })
  let measured = mount_view_spec(root).measure(
    Constraints::loose(Size::new(width=40.0, height=30.0)),
  )
  inspect(measured.size.width, content="40")
  inspect(measured.size.height, content="30")
  inspect(measured.children[0].size.width, content="100")
  inspect(measured.children[0].size.height, content="90")
}
