///|
/// Shared helpers for views smoke and behavior tests.
/// These are public so sibling test files can reuse them.

///|
/// A minimal environment useful for smoke-testing views without a full runtime.
pub fn smoke_environment() -> @core.Environment {
  @core.Environment::neutral()
}

///|
/// A minimal theme (ColorPalette + TypographyScale) for smoke-testing views.
pub fn smoke_theme() -> @core.Theme {
  @core.Theme::neutral()
}

///|
/// Build a loose layout context for a single-child view.
pub fn single_child_layout_context(
  constraints~ : @core.Constraints,
  child_size~ : @core.Size,
) -> @core.ViewLayoutContext {
  {
    constraints,
    child_sizes: [child_size],
    child_flex_weights: [0.0],
    state: smoke_view_state(),
    text_system: @core.TextSystem::fallback(),
    environment: smoke_environment(),
    style: @core.ViewStyle::empty(),
  }
}

///|
/// Build a layout context with no children.
pub fn empty_layout_context(
  constraints~ : @core.Constraints,
) -> @core.ViewLayoutContext {
  {
    constraints,
    child_sizes: [],
    child_flex_weights: [],
    state: smoke_view_state(),
    text_system: @core.TextSystem::fallback(),
    environment: smoke_environment(),
    style: @core.ViewStyle::empty(),
  }
}

///|
/// Build a layout context with multiple children.
pub fn multi_child_layout_context(
  constraints~ : @core.Constraints,
  child_sizes~ : Array[@core.Size],
) -> @core.ViewLayoutContext {
  let flex_weights : Array[Double] = child_sizes.map(_ => 0.0)
  {
    constraints,
    child_sizes: child_sizes.copy(),
    child_flex_weights: flex_weights,
    state: smoke_view_state(),
    text_system: @core.TextSystem::fallback(),
    environment: smoke_environment(),
    style: @core.ViewStyle::empty(),
  }
}

///|
/// Neutral view state for paint contexts.
pub fn smoke_view_state() -> @core.ViewStateContext {
  {
    focused: false,
    hovered: false,
    pressed: false,
    selected: false,
    checked: false,
    expanded: false,
    disabled: false,
    slots: @core.ViewStateSlots::empty(),
  }
}

///|
/// Empty text control state for paint contexts.
pub fn smoke_text_control() -> @core.TextControlStateContext {
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
/// Build a minimal paint context for a view.
pub fn smoke_paint_context(frame~ : @core.Rect) -> @core.ViewPaintContext {
  {
    frame,
    child_frames: [],
    focused: false,
    state: smoke_view_state(),
    text_control: smoke_text_control(),
    text_system: @core.TextSystem::fallback(),
    environment: smoke_environment(),
    style: @core.ViewStyle::empty(),
    now_ms: 0.0,
  }
}

///|
/// Layout a view in a loose 400x300 space and return the layout result.
pub fn layout_view(
  view : @core.View[Unit],
  width~ : Double,
  height~ : Double,
) -> @core.ViewLayoutResult {
  view.layout(
    empty_layout_context(
      constraints=@core.Constraints::loose(@core.Size::new(width~, height~)),
    ),
  )
}

///|
/// Layout a single-child view in a loose 400x300 space with a given child size.
pub fn layout_single_child(
  view : @core.View[Unit],
  child_size~ : @core.Size,
  width~ : Double,
  height~ : Double,
) -> @core.ViewLayoutResult {
  view.layout(
    single_child_layout_context(
      constraints=@core.Constraints::loose(@core.Size::new(width~, height~)),
      child_size~,
    ),
  )
}

///|
/// Paint a view in a 400x300 frame and return the paint plan.
pub fn paint_view(view : @core.View[Unit]) -> @core.ViewPaintPlan {
  view.paint(
    smoke_paint_context(
      frame=@core.Rect::new(x=0.0, y=0.0, width=400.0, height=300.0),
    ),
  )
}

///|
/// Layout + paint a view and return (layout_result, paint_plan).
pub fn render_view(
  view : @core.View[Unit],
) -> (@core.ViewLayoutResult, @core.ViewPaintPlan) {
  let layout = layout_view(view, width=400.0, height=300.0)
  let paint = paint_view(view)
  (layout, paint)
}

///|
/// Assert a view produces a valid layout result (non-zero or zero size is ok,
/// just not a crash).
pub fn assert_layouts(view : @core.View[Unit]) -> Unit {
  let result = layout_view(view, width=400.0, height=300.0)
  let _ = result.size
  ()
}

///|
/// Assert a view paints without crashing.
pub fn assert_paints(view : @core.View[Unit]) -> Unit {
  let _plan = paint_view(view)
  ()
}
