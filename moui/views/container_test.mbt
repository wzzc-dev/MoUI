// Unit tests for `center` in moui/views/container.mbt (lines 65-129).
//
// `center` builds a custom-children-layout view whose `measure` and `place`
// callbacks position a single child at the center of the available frame.
// These tests drive the view layout directly with synthetic layout contexts
// (no renderer required) so the centering math is verified deterministically.
//
// Note: `Size`/`Rect` derive `Eq` but not `Show`, so they are compared with
// `assert_true(actual == expected)` rather than `assert_eq`.

///|
/// A leaf view that reports a fixed intrinsic size and paints nothing.
fn center_test_rect(width~ : Double, height~ : Double) -> @core.View[Unit] {
  @core.View::node(
    identity=() => @core.ViewIdentity::new(kind="CenterTestRect"),
    revision=() => "center-test-rect:\{width}:\{height}",
    layout=ctx => {
      @core.ViewLayoutResult::new(
        size=ctx.constraints.constrain(@core.Size::new(width~, height~)),
      )
    },
  )
}

///|
/// Build a layout context for the single-child `center` view. `child_size`
/// is the size `center` should read for its only child.
fn center_layout_context(
  constraints~ : @core.Constraints,
  child_size~ : @core.Size,
) -> @core.ViewLayoutContext {
  {
    constraints,
    child_sizes: [child_size],
    child_flex_weights: [0.0],
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
  }
}

///|
/// Neutral view state for paint contexts.
fn center_test_state() -> @core.ViewStateContext {
  {
    focused: false,
    hovered: false,
    pressed: false,
    selected: false,
    checked: false,
    expanded: false,
    disabled: false,
    scratch: "",
  }
}

///|
/// Empty text control state for paint contexts.
fn center_test_text_control() -> @core.TextControlStateContext {
  {
    caret: 0,
    selection: None,
    text_selection_anchor: None,
    composition: None,
    composition_cursor: None,
    undo_stack: [],
    redo_stack: [],
  }
}

///|
/// Build a paint context centered on `frame`.
fn center_paint_context(frame~ : @core.Rect) -> @core.ViewPaintContext {
  {
    frame,
    child_frames: [],
    focused: false,
    state: center_test_state(),
    text_control: center_test_text_control(),
    text_system: @core.TextSystem::fallback(),
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
    now_ms: 0.0,
  }
}

///|
test "center measures to bounded constraints when no explicit size is given" {
  let child = center_test_rect(width=100.0, height=50.0)
  let view = center(child)
  let ctx = center_layout_context(
    constraints=@core.Constraints::loose(
      @core.Size::new(width=300.0, height=200.0),
    ),
    child_size=@core.Size::new(width=100.0, height=50.0),
  )
  let result = view.layout(ctx)
  // No explicit width/height and the constraint maximum is finite, so the
  // measured size fills the available bounds.
  assert_true(result.size == @core.Size::new(width=300.0, height=200.0))
  assert_eq(result.child_frames.length(), 1)
  // The 100x50 child is centered inside the 300x200 frame.
  assert_true(
    result.child_frames[0] ==
    @core.Rect::new(x=100.0, y=75.0, width=100.0, height=50.0),
  )
}

///|
test "center honors explicit width and height" {
  let child = center_test_rect(width=100.0, height=50.0)
  let view = center(child, width=400.0, height=300.0)
  let ctx = center_layout_context(
    constraints=@core.Constraints::loose(
      @core.Size::new(width=500.0, height=400.0),
    ),
    child_size=@core.Size::new(width=100.0, height=50.0),
  )
  let result = view.layout(ctx)
  // Explicit size wins over the constraint maximum.
  assert_true(result.size == @core.Size::new(width=400.0, height=300.0))
  // The 100x50 child is centered inside the 400x300 frame.
  assert_true(
    result.child_frames[0] ==
    @core.Rect::new(x=150.0, y=125.0, width=100.0, height=50.0),
  )
}

///|
test "center falls back to child size under unbounded constraints" {
  let child = center_test_rect(width=100.0, height=50.0)
  let view = center(child)
  let ctx = center_layout_context(
    constraints=@core.Constraints::unbounded(),
    child_size=@core.Size::new(width=100.0, height=50.0),
  )
  let result = view.layout(ctx)
  // Unbounded (max >= 1e9) means the measured size tracks the child size.
  assert_true(result.size == @core.Size::new(width=100.0, height=50.0))
  // Centered in a frame exactly its own size => origin (0, 0).
  assert_true(
    result.child_frames[0] ==
    @core.Rect::new(x=0.0, y=0.0, width=100.0, height=50.0),
  )
}

///|
test "center clamps child origin to zero when child exceeds the frame" {
  let child = center_test_rect(width=100.0, height=50.0)
  let view = center(child)
  let ctx = center_layout_context(
    constraints=@core.Constraints::loose(
      @core.Size::new(width=60.0, height=30.0),
    ),
    child_size=@core.Size::new(width=100.0, height=50.0),
  )
  let result = view.layout(ctx)
  // Measured size is clamped to the (60x30) constraint maximum.
  assert_true(result.size == @core.Size::new(width=60.0, height=30.0))
  // The child overflows the frame, so its origin is clamped to (0, 0).
  assert_true(
    result.child_frames[0] ==
    @core.Rect::new(x=0.0, y=0.0, width=100.0, height=50.0),
  )
}

///|
test "center with background wraps the content in a container" {
  let child = center_test_rect(width=100.0, height=50.0)
  let view = center(child, background=@core.Color::blue())
  assert_eq(view.identity().kind, "Container")
  // The centered child is preserved inside the container wrapper.
  let children = view.children()
  assert_eq(children.length(), 1)
  // The inner (grand)child keeps the centered-content semantics label added by
  // `center` (the container wraps it through `padding_layout`).
  let inner = children[0].children()
  assert_eq(inner.length(), 1)
  assert_eq(inner[0].semantics().label, "Centered content")
  // Driving the wrapper layout with a pretend child size confirms the
  // container reports the child's measured size.
  let ctx = center_layout_context(
    constraints=@core.Constraints::loose(
      @core.Size::new(width=500.0, height=400.0),
    ),
    child_size=@core.Size::new(width=300.0, height=200.0),
  )
  let result = view.layout(ctx)
  assert_true(result.size == @core.Size::new(width=300.0, height=200.0))
}

///|
test "center applies explicit width and height together with a background" {
  let child = center_test_rect(width=100.0, height=50.0)
  let view = center(
    child,
    width=400.0,
    height=300.0,
    background=@core.Color::blue(),
  )
  // With a fixed width/height the wrapper is a frame around the container.
  assert_true(view.identity().kind.contains("Frame"))
  let ctx = center_layout_context(
    constraints=@core.Constraints::loose(
      @core.Size::new(width=500.0, height=400.0),
    ),
    child_size=@core.Size::new(width=400.0, height=300.0),
  )
  let result = view.layout(ctx)
  // The fixed width/height is reported regardless of the constraint maximum.
  assert_true(result.size == @core.Size::new(width=400.0, height=300.0))
}

///|
test "center reports a centered-content semantics label" {
  let child = center_test_rect(width=100.0, height=50.0)
  let view = center(child)
  assert_eq(view.semantics().label, "Centered content")
}

///|
test "center paints no commands for its custom layout" {
  let child = center_test_rect(width=100.0, height=50.0)
  let view = center(child)
  let plan = view.paint(
    center_paint_context(
      frame=@core.Rect::new(x=0.0, y=0.0, width=300.0, height=200.0),
    ),
  )
  assert_eq(plan.commands.length(), 0)
}

///|
test "center accepts an explicit theme override without changing layout" {
  let child = center_test_rect(width=100.0, height=50.0)
  let view = center(child, theme=@core.Theme::neutral())
  let ctx = center_layout_context(
    constraints=@core.Constraints::loose(
      @core.Size::new(width=300.0, height=200.0),
    ),
    child_size=@core.Size::new(width=100.0, height=50.0),
  )
  let result = view.layout(ctx)
  assert_true(result.size == @core.Size::new(width=300.0, height=200.0))
  assert_true(
    result.child_frames[0] ==
    @core.Rect::new(x=100.0, y=75.0, width=100.0, height=50.0),
  )
}
