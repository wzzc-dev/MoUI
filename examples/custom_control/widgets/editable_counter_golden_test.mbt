///|
fn golden_layout_context(
  direction : @core.LayoutDirection,
) -> @core.ViewLayoutContext {
  {
    constraints: @core.Constraints::loose(
      @core.Size::new(width=300.0, height=120.0),
    ),
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
    environment: @core.Environment::neutral().with_layout_direction(direction),
    style: @core.ViewStyle::empty(),
  }
}

///|
fn golden_paint_context(
  frame : @core.Rect,
  direction : @core.LayoutDirection,
) -> @core.ViewPaintContext {
  {
    frame,
    child_frames: [],
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
      caret: 1,
      selection: None,
      text_selection_anchor: None,
      text_selection_origin: None,
      composition: None,
      composition_cursor: None,
      undo_stack: [],
      redo_stack: [],
      goal_column: None,
      reveal: None,
    },
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral().with_layout_direction(direction),
    style: @core.ViewStyle::empty(),
    now_ms: 0.0,
  }
}

///|
fn golden_counter() -> @core.View[Unit] {
  @widgets.editable_counter(
    label="Quantity",
    value="5",
    numeric_value=5.0,
    on_input=_value => (),
    on_increment=(),
    on_decrement=(),
  )
}

///|
test "editable counter identity and declaration channels stay explicit" {
  let base : @core.View[Unit] = golden_counter()
  let same : @core.View[Unit] = golden_counter()
  let keyed : @core.View[Unit] = golden_counter().key("quantity")
  let other_value : @core.View[Unit] = @widgets.editable_counter(
    label="Quantity",
    value="6",
    numeric_value=6.0,
    on_input=_value => (),
    on_increment=(),
    on_decrement=(),
  )
  assert_true(base.identity() == same.identity())
  assert_true(base.identity() != keyed.identity())
  let before = base.declaration()
  let layout_unchanged = before.layout() == other_value.declaration().layout()
  let paint_changed = before.paint() != other_value.declaration().paint()
  let semantics_changed = before.semantics() !=
    other_value.declaration().semantics()
  assert_true(layout_unchanged)
  assert_true(paint_changed)
  assert_true(semantics_changed)
}

///|
test "editable counter golden layout" {
  let result = golden_counter().layout(golden_layout_context(LeftToRight))
  assert_eq(result.size, @core.Size::new(width=220.0, height=40.0))
  assert_eq(result.child_frames, [])
  assert_eq(result.child_transform, @core.Transform2D::identity())
  assert_eq(result.clips_children, false)
  assert_eq(result.child_frames_tight, false)
}

///|
test "editable counter golden paint commands" {
  let theme = @core.Environment::neutral().theme
  let frame = @core.Rect::new(x=0.0, y=0.0, width=220.0, height=40.0)
  let plan = golden_counter().paint(golden_paint_context(frame, LeftToRight))
  assert_eq(plan.commands, [
    FillRoundedRect(
      @core.RoundedRect::new(rect=frame, radius=8.0),
      theme.palette.surface,
    ),
    StrokeRoundedRect(
      @core.RoundedRect::new(rect=frame, radius=8.0),
      theme.palette.outline,
      1.0,
    ),
    FillRect(
      @core.Rect::new(x=39.0, y=8.0, width=1.0, height=24.0),
      theme.palette.outline_variant,
    ),
    FillRect(
      @core.Rect::new(x=180.0, y=8.0, width=1.0, height=24.0),
      theme.palette.outline_variant,
    ),
    DrawText(
      @core.TextRun::new(
        text="−",
        frame=@core.Rect::new(x=0.0, y=0.0, width=40.0, height=40.0),
        font=theme.typography.control,
        color=theme.palette.on_surface,
      ),
    ),
    DrawText(
      @core.TextRun::new(
        text="5",
        frame=@core.Rect::new(x=40.0, y=0.0, width=140.0, height=40.0),
        font=theme.typography.control,
        color=theme.palette.on_surface,
      ),
    ),
    DrawText(
      @core.TextRun::new(
        text="+",
        frame=@core.Rect::new(x=180.0, y=0.0, width=40.0, height=40.0),
        font=theme.typography.control,
        color=theme.palette.on_surface,
      ),
    ),
  ])
}

///|
test "editable counter mirrors step zones in rtl" {
  let frame = @core.Rect::new(x=10.0, y=4.0, width=220.0, height=40.0)
  let plan = golden_counter().paint(golden_paint_context(frame, RightToLeft))
  let minus = plan.commands[4]
  let plus = plan.commands[6]
  guard minus is DrawText({ frame: minus_frame, .. }) else {
    fail("expected decrement glyph")
  }
  guard plus is DrawText({ frame: plus_frame, .. }) else {
    fail("expected increment glyph")
  }
  assert_eq(minus_frame.origin.x, 190.0)
  assert_eq(plus_frame.origin.x, 10.0)
}

///|
test "editable counter exposes ime frame and composition" {
  let context = {
    ..golden_paint_context(
      @core.Rect::new(x=0.0, y=0.0, width=220.0, height=40.0),
      LeftToRight,
    ),
    text_control: {
      caret: 1,
      selection: None,
      text_selection_anchor: None,
      text_selection_origin: None,
      composition: Some("十"),
      composition_cursor: Some(@core.TextRange::new(start=1, end=1)),
      undo_stack: [],
      redo_stack: [],
      goal_column: None,
      reveal: None,
    },
  }
  match golden_counter().text_input_state(context) {
    Some(input) => {
      assert_eq(input.text, "5")
      assert_eq(input.composition, Some("十"))
      assert_eq(
        input.frame,
        @core.Rect::new(x=40.0, y=0.0, width=140.0, height=40.0),
      )
      assert_true(input.caret_rect.size.height > 0.0)
    }
    None => fail("expected text input state")
  }
}
