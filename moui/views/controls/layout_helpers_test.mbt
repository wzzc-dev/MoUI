// Unit tests for the `rounded_clip` layout helper (now implemented in
// controls/layout_helpers.mbt) and `@text.text` alignment forwarding.
// The shared helpers drive view layout/paint directly with synthetic
// contexts (no renderer required).

///|
fn center_test_rect(width~ : Double, height~ : Double) -> @core.View[Unit] {
  @core.View::from_node(CenterTestRect::{ width, height })
}

///|
priv struct CenterTestRect {
  width : Double
  height : Double
}

///|
impl @core.ViewNode for CenterTestRect with fn identity(_self) {
  @core.ViewIdentity::new(kind="CenterTestRect")
}

///|
impl @core.ViewNode for CenterTestRect with fn declaration(self) {
  @core.ViewDeclaration::channels(
    layout=@core.DeclarationChannel::Exact(
      @core.DeclarationKey::record(type_tag="CenterTestRect", fields=[
        ("width", @core.DeclarationKey::double(self.width)),
        ("height", @core.DeclarationKey::double(self.height)),
      ]),
    ),
    paint=@core.DeclarationChannel::Constant,
    semantics=@core.DeclarationChannel::Constant,
    platform=@core.DeclarationChannel::Constant,
  )
}

///|
impl @core.ViewNode for CenterTestRect with fn layout(self, ctx) {
  @core.ViewLayoutResult::new(
    size=ctx.constraints.constrain(
      @core.Size::new(width=self.width, height=self.height),
    ),
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
    state: center_test_state(),
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
    slots: @core.ViewStateSlots::empty(),
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
test "text forwards explicit alignment to text run" {
  let view : @core.View[Unit] = @text.text(
    "left aligned",
    width=120.0,
    height=24.0,
    align=@core.TextAlign::TextStart,
  )
  let plan = view.paint(
    center_paint_context(
      frame=@core.Rect::new(x=0.0, y=0.0, width=120.0, height=24.0),
    ),
  )
  guard plan.commands[0] is @core.DrawCommand::DrawText({ text, align, .. }) else {
    fail("expected text draw command")
  }
  inspect(text, content="left aligned")
  inspect(align == @core.TextAlign::TextStart, content="true")
}

///|
test "rounded clip wraps child with rounded clip paint commands" {
  let view = rounded_clip(
    center_test_rect(width=80.0, height=40.0),
    radius=12.0,
  )
  let layout = view.layout(
    center_layout_context(
      constraints=@core.Constraints::loose(
        @core.Size::new(width=200.0, height=120.0),
      ),
      child_size=@core.Size::new(width=80.0, height=40.0),
    ),
  )
  assert_true(layout.size == @core.Size::new(width=80.0, height=40.0))
  assert_true(
    layout.child_frames[0] ==
    @core.Rect::new(x=0.0, y=0.0, width=80.0, height=40.0),
  )
  let plan = view.paint(
    center_paint_context(
      frame=@core.Rect::new(x=10.0, y=20.0, width=80.0, height=40.0),
    ),
  )
  guard plan.commands[0] is @core.DrawCommand::PushRoundedClip({ rect, radius }) else {
    fail("expected rounded clip command")
  }
  assert_true(rect == @core.Rect::new(x=10.0, y=20.0, width=80.0, height=40.0))
  inspect(radius, content="12")
  guard plan.post_commands[0] is @core.DrawCommand::PopRoundedClip else {
    fail("expected rounded clip pop command")
  }
}
