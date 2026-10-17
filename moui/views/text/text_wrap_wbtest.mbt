///|
/// White-box tests for the `text` view's opt-in `wrap` mode: layout bounds
/// against real constraints, plus the per-line paint contract pinned here so
/// a regression back to a single clipped run (or to surface-global
/// coordinates) fails immediately.

///|
fn wrap_layout_context(
  constraints~ : @core.Constraints,
) -> @core.ViewLayoutContext {
  {
    constraints,
    child_sizes: [],
    child_flex_weights: [],
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
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
  }
}

///|
fn wrap_paint_context(frame : @core.Rect) -> @core.ViewPaintContext {
  {
    frame,
    child_frames: [frame],
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
fn wrapped_text_size(
  label~ : String,
  width~ : Double,
  height? : Double = 32.0,
  max_width? : Double = 1000.0,
) -> @core.Size {
  let view : @core.View[Unit] = text(label, width~, height~, wrap=true)
  view.layout(
    wrap_layout_context(
      constraints=@core.Constraints::loose(
        @core.Size::new(width=max_width, height=10000.0),
      ),
    ),
  ).size
}

///|
test "wrap mode keeps the requested line width instead of outgrowing it" {
  let long_label = "WWWWWWWWWW WWWWWWWWWW WWWWWWWWWW WWWWWWWWWW"
  // Single-line behavior is unchanged: the box grows to the measured width.
  assert_true(text_sizing_width(long_label) > 160.0)
  // wrap=true bounds that box to the line width instead.
  let size = wrapped_text_size(label=long_label, width=120.0)
  assert_eq(size.width, 120.0)
}

///|
test "wrapped text grows downward with the line count" {
  let short = wrapped_text_size(label="Hi", width=120.0)
  let long = wrapped_text_size(
    label="WWWWWWWWWW WWWWWWWWWW WWWWWWWWWW WWWWWWWWWW",
    width=120.0,
  )
  assert_eq(short.height, 32.0)
  assert_true(long.height > 32.0)
}

///|
test "the incoming constraint can only narrow the wrap width" {
  let wide = wrapped_text_size(
    label="WWWWWWWWWW WWWWWWWWWW WWWWWWWWWW WWWWWWWWWW",
    width=120.0,
  )
  let narrow = wrapped_text_size(
    label="WWWWWWWWWW WWWWWWWWWW WWWWWWWWWW WWWWWWWWWW",
    width=120.0,
    max_width=80.0,
  )
  assert_eq(narrow.width, 80.0)
  // Fewer pixels per line means at least as many lines.
  assert_true(narrow.height >= wide.height)
}

///|
test "CJK text wraps without needing spaces" {
  let size = wrapped_text_size(
    label="雨夜江南小镇的当铺里灯光昏黄旧账簿摊开在柜台一角墨迹未干",
    width=120.0,
  )
  assert_eq(size.width, 120.0)
  assert_true(size.height > 32.0)
}

///|
test "hard breaks still stack lines in wrap mode" {
  let broken = wrapped_text_size(
    label="一二三四五\n一二三四五\n一二三四五",
    width=400.0,
    height=8.0,
  )
  let joined = wrapped_text_size(
    label="一二三四五一二三四五一二三四五",
    width=400.0,
    height=8.0,
  )
  assert_true(broken.height > joined.height)
}

///|
test "wrapped text paints one run per line at global coordinates" {
  let frame = @core.Rect::new(x=33.0, y=44.0, width=120.0, height=60.0)
  let view : @core.View[Unit] = text(
    "一二三四五六七八九十 二三四五六七八九十",
    width=120.0,
    wrap=true,
  )
  let plan = view.paint(wrap_paint_context(frame))
  assert_true(plan.commands.length() >= 2)
  let mut previous_y = frame.origin.y - 1.0
  for command in plan.commands {
    match command {
      PushClip(rect) => assert_eq(rect.size.width, frame.size.width)
      PopClip => ()
      DrawText(run) => {
        // Lines live in canvas-global coordinates: x is the view's own frame
        // origin and y advances past it, never restarts from (0, 0).
        assert_eq(run.frame.origin.x, frame.origin.x)
        assert_true(run.frame.origin.y >= frame.origin.y)
        assert_true(run.frame.origin.y > previous_y)
        previous_y = run.frame.origin.y
      }
      _ => fail("wrapped labels must only push clip and draw runs")
    }
  }
}

///|
test "single-line text stays exactly one run" {
  let frame = @core.Rect::new(x=0.0, y=0.0, width=160.0, height=32.0)
  let view : @core.View[Unit] = text("Hi")
  let plan = view.paint(wrap_paint_context(frame))
  assert_eq(plan.commands.length(), 1)
}
