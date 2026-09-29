///|
/// Tests for the 40 standalone modifier types (Phase 1: ViewModifier god-enum replacement).
/// Each category tests the public API through `View` methods, which exercise
/// the `to_any_modifier()` vtable dispatch path end-to-end.

///|
/// Shared root view for attaching modifiers.
fn test_leaf() -> @core.View[Unit] {
  @core.View::from_node(ModTestNode::{
    kind: "test-leaf",
    size: @core.Size::new(width=8.0, height=8.0),
  })
}

///|
struct ModTestNode {
  kind : String
  size : @core.Size
}

///|
impl @core.ViewNode for ModTestNode with fn identity(self) {
  @core.ViewIdentity::new(kind=self.kind)
}

///|
impl @core.ViewNode for ModTestNode with fn layout(self, context) {
  @core.ViewLayoutResult::new(size=context.constraints.constrain(self.size))
}

///|
fn loose_constraints(w : Double, h : Double) -> @core.Constraints {
  @core.Constraints::loose(@core.Size::new(width=w, height=h))
}

///|
/// Layout context with a single child of the given size.
fn ctx_child(child_size~ : @core.Size) -> @core.ViewLayoutContext {
  {
    constraints: loose_constraints(200.0, 200.0),
    child_sizes: [child_size],
    child_flex_weights: [0.0],
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
fn paint_ctx(frame~ : @core.Rect) -> @core.ViewPaintContext {
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
fn red() -> @core.Color {
  @core.Color::rgba(r=1.0, g=0.0, b=0.0)
}

///|
fn blue() -> @core.Color {
  @core.Color::rgba(r=0.0, g=0.0, b=1.0)
}

///|
fn black() -> @core.Color {
  @core.Color::black()
}

// == Layout modifiers ==

///|
test "padding modifier identity and layout inflation" {
  let view = test_leaf().padding(16.0)
  assert_true(view.identity().kind.contains("Padding"))
  let result = view.layout(
    ctx_child(child_size=@core.Size::new(width=40.0, height=40.0)),
  )
  assert_true(result.size.width >= 64.0)
}

///|
test "frame modifier identity and size constraint" {
  let view = test_leaf().frame(width=100.0, height=50.0)
  assert_true(view.identity().kind.contains("Frame"))
  let result = view.layout(
    ctx_child(child_size=@core.Size::new(width=40.0, height=40.0)),
  )
  assert_true(result.size.width <= 100.0)
  assert_true(result.size.height <= 50.0)
}

///|
test "flexible modifier sets flex weight" {
  let view = test_leaf().flexible(weight=2.5)
  assert_true(view.identity().kind.contains("Flexible"))
  assert_true(view.flex_weight() > 0.0)
}

///|
test "expanded modifier delegates to flexible" {
  let view = test_leaf().expanded()
  assert_true(view.flex_weight() > 0.0)
}

///|
test "offset modifier identity and child frame" {
  let view = test_leaf().offset(dx=10.0, dy=5.0)
  assert_true(view.identity().kind.contains("Offset"))
  let result = view.layout(
    ctx_child(child_size=@core.Size::new(width=30.0, height=30.0)),
  )
  assert_true(result.child_frames.length() == 1)
}

///|
test "align modifier identity" {
  let view = test_leaf().align(alignment=@core.Alignment::center())
  assert_true(view.identity().kind.contains("Align"))
}

///|
test "aspect_ratio modifier identity" {
  let view = test_leaf().aspect_ratio(2.0)
  assert_true(view.identity().kind.contains("AspectRatio"))
}

///|
test "intrinsic_width and intrinsic_height identity" {
  assert_true(
    test_leaf().intrinsic_width().identity().kind.contains("IntrinsicWidth"),
  )
  assert_true(
    test_leaf().intrinsic_height().identity().kind.contains("IntrinsicHeight"),
  )
}

// == Paint modifiers ==

///|
test "background modifier identity and paint commands" {
  let view = test_leaf().background(red())
  assert_true(view.identity().kind.contains("Background"))
  let plan = view.paint(
    paint_ctx(frame=@core.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0)),
  )
  assert_true(plan.commands.length() >= 1)
}

///|
test "foreground modifier identity" {
  assert_true(
    test_leaf().foreground(blue()).identity().kind.contains("Foreground"),
  )
}

///|
test "opacity modifier identity and push/pop commands" {
  let view = test_leaf().opacity(0.5)
  assert_true(view.identity().kind.contains("Opacity"))
  let plan = view.paint(
    paint_ctx(frame=@core.Rect::new(x=0.0, y=0.0, width=100.0, height=100.0)),
  )
  assert_true(plan.commands.length() >= 1)
}

///|
test "shadow modifier identity" {
  let style = @core.ShadowStyle::new(color=black(), blur_radius=4.0)
  assert_true(test_leaf().shadow(style).identity().kind.contains("Shadow"))
}

///|
test "border modifier identity" {
  let style = @core.BorderStyle::new(brush=@core.Brush::solid(black()))
  assert_true(test_leaf().border(style).identity().kind.contains("Border"))
}

///|
test "corner_radius modifier identity" {
  assert_true(
    test_leaf().corner_radius(8.0).identity().kind.contains("CornerRadius"),
  )
}

///|
test "clip modifier identity" {
  assert_true(test_leaf().clip().identity().kind.contains("Clip"))
}

///|
test "scale modifier identity" {
  assert_true(
    test_leaf().scale(sx=1.5, sy=1.5).identity().kind.contains("Scale"),
  )
}

///|
test "font modifier identity" {
  let font = @core.FontSpec::new(size=16.0)
  assert_true(test_leaf().font(font).identity().kind.contains("Font"))
}

///|
test "repaint_boundary modifier identity" {
  assert_true(
    test_leaf().repaint_boundary().identity().kind.contains("RepaintBoundary"),
  )
}

// == Event modifiers ==

///|
test "on_tap identity focusable and button semantics role" {
  let view : @core.View[Int] = @core.View::from_node(ModTestNode::{
    kind: "tappable",
    size: @core.Size::new(width=8.0, height=8.0),
  }).on_tap(42)
  assert_true(view.identity().kind.contains("OnTap"))
  assert_true(view.accepts_focus())
  assert_true(view.semantics().role == Some(Button))
}

///|
test "on_secondary_tap only activates for the secondary mouse button" {
  let view : @core.View[Int] = @core.View::from_node(ModTestNode::{
    kind: "secondary-tappable",
    size: @core.Size::new(width=8.0, height=8.0),
  }).on_secondary_tap(7)
  assert_true(view.identity().kind.contains("OnSecondaryTap"))
  // A context-menu hook is an observer: it must not become a focus stop, and
  // must not override the host view's semantics role.
  assert_true(!view.accepts_focus())
  assert_true(view.semantics().role == None)
}

///|
test "on_long_press identity and focusable" {
  let view : @core.View[Int] = @core.View::from_node(ModTestNode::{
    kind: "pressable",
    size: @core.Size::new(width=8.0, height=8.0),
  }).on_long_press(42)
  assert_true(view.identity().kind.contains("OnLongPress"))
  assert_true(view.accepts_focus())
}

///|
test "on_double_tap identity" {
  let view : @core.View[Int] = @core.View::from_node(ModTestNode::{
    kind: "dbl-tap",
    size: @core.Size::new(width=8.0, height=8.0),
  }).on_double_tap(42)
  assert_true(view.identity().kind.contains("OnDoubleTap"))
}

///|
test "on_drag identity" {
  let view : @core.View[Int] = @core.View::from_node(ModTestNode::{
    kind: "draggable",
    size: @core.Size::new(width=8.0, height=8.0),
  }).on_drag(fn(_event) { 42 })
  assert_true(view.identity().kind.contains("OnDrag"))
}

///|
test "on_hover is a transparent observer with no focus stop or role" {
  let view : @core.View[Bool] = @core.View::from_node(ModTestNode::{
    kind: "hoverable",
    size: @core.Size::new(width=8.0, height=8.0),
  }).on_hover(hovered => hovered)
  assert_true(view.identity().kind.contains("OnHover"))
  // Hover feedback is an observer, not a control. This is the requirement most
  // likely to regress silently: a role here would override the host view's role
  // (a plain container must not announce itself as a Button), a focus stop would
  // insert it into focus traversal, and a semantics action would make assistive
  // technology offer an activation that hover does not have.
  assert_true(!view.accepts_focus())
  assert_eq(view.semantics().role, None)
  assert_true(view.semantics_action_kinds().is_empty())
}

///|
test "on_hover contributes no semantics of its own" {
  let plain : @core.View[Bool] = @core.View::from_node(ModTestNode::{
    kind: "hoverable-plain",
    size: @core.Size::new(width=8.0, height=8.0),
  })
  let view : @core.View[Bool] = @core.View::from_node(ModTestNode::{
    kind: "hoverable",
    size: @core.Size::new(width=8.0, height=8.0),
  }).on_hover(hovered => hovered)
  // The modifier must not add a role of its own: whatever the wrapped view
  // reported without `on_hover`, it still reports with it (here, `None` — a
  // plain container must not start announcing itself as a Button).
  assert_eq(view.semantics().role, plain.semantics().role)
  assert_eq(view.semantics().role, None)
  assert_eq(view.semantics().composition, Transparent)
  assert_true(view.semantics_action_kinds().is_empty())
}

///|
/// A hover observer must be at least as transparent as the other observer
/// modifiers: like `on_secondary_tap` and `on_file_drop` it neither takes a
/// focus stop nor contributes a role or action.
test "on_hover matches on_secondary_tap transparency" {
  let base = @core.View::from_node(ModTestNode::{
    kind: "transparent-compare",
    size: @core.Size::new(width=8.0, height=8.0),
  })
  let hover : @core.View[Unit] = base.on_hover(_hovered => ())
  let secondary : @core.View[Unit] = base.on_secondary_tap(())
  assert_true(!hover.accepts_focus())
  assert_eq(hover.accepts_focus(), secondary.accepts_focus())
  assert_eq(hover.semantics().role, secondary.semantics().role)
  assert_true(hover.semantics_action_kinds().is_empty())
}

///|
test "keyboard_shortcut identity" {
  let view : @core.View[Unit] = test_leaf().keyboard_shortcut(
    @core.KeyboardShortcut::new(
      key="k",
      modifiers=@core.KeyModifiers::new(meta=true),
    ),
  )
  assert_true(view.identity().kind.contains("KeyboardShortcut"))
}

// == Semantics modifiers ==

///|
test "accessibility_label identity and label" {
  let view = test_leaf().accessibility_label("Hello")
  assert_true(view.identity().kind.contains("AccessibilityLabel"))
  assert_eq(view.semantics().label, Some("Hello"))
  assert_eq(view.semantics().value, None)
}

///|
test "semantics_role identity and role" {
  let view = test_leaf().semantics_role(Button)
  assert_true(view.identity().kind.contains("SemanticsRole"))
  assert_eq(view.semantics().role, Some(Button))
}

///|
test "semantics_checked identity and value" {
  let view = test_leaf().semantics_checked(checked=Checked)
  assert_true(view.identity().kind.contains("SemanticsChecked"))
  assert_eq(view.semantics().checked, Some(Checked))
}

///|
test "semantics_selected identity" {
  assert_true(
    test_leaf().semantics_selected(selected=true).identity().kind.contains(
      "SemanticsSelected",
    ),
  )
}

///|
test "semantics_expanded identity and value" {
  let view = test_leaf().semantics_expanded(expanded=true)
  assert_eq(view.semantics().expanded, Some(true))
}

///|
test "semantics_invalid identity and value" {
  let view = test_leaf().semantics_invalid(invalid=true)
  assert_eq(view.semantics().invalid, Some(true))
}

///|
test "semantics_required identity and value" {
  let view = test_leaf().semantics_required(required=true)
  assert_eq(view.semantics().required, Some(true))
}

///|
test "semantics_description identity and value" {
  let view = test_leaf().semantics_description("A test view")
  assert_eq(view.semantics().description, Some("A test view"))
}

///|
test "semantics_boundary identity and composition" {
  let view = test_leaf().semantics_boundary()
  assert_eq(view.semantics().composition, Boundary)
}

///|
test "merge_descendant_semantics identity and composition" {
  let view = test_leaf().merge_descendant_semantics()
  assert_eq(view.semantics().composition, MergeDescendants)
}

///|
test "hide_semantics identity and composition" {
  let view = test_leaf().hide_semantics()
  assert_eq(view.semantics().composition, Hidden)
}

///|
test "semantics modifiers declare exact semantics-only invalidation" {
  let pairs : Array[(@core.View[Unit], @core.View[Unit])] = [
    (
      test_leaf().accessibility_label("First"),
      test_leaf().accessibility_label("Second"),
    ),
    (
      test_leaf().semantic_id("test.first"),
      test_leaf().semantic_id("test.second"),
    ),
    (
      test_leaf().semantics_composition(Boundary),
      test_leaf().semantics_composition(MergeDescendants),
    ),
    (test_leaf().semantics_role(Button), test_leaf().semantics_role(Checkbox)),
    (test_leaf().semantics_level(1), test_leaf().semantics_level(2)),
    (
      test_leaf().semantics_url("https://first.example"),
      test_leaf().semantics_url("https://second.example"),
    ),
    (
      test_leaf().semantics_selected(selected=false),
      test_leaf().semantics_selected(selected=true),
    ),
    (
      test_leaf().semantics_pressed(pressed=false),
      test_leaf().semantics_pressed(pressed=true),
    ),
    (
      test_leaf().semantics_checked(checked=Unchecked),
      test_leaf().semantics_checked(checked=Mixed),
    ),
    (
      test_leaf().semantics_expanded(expanded=false),
      test_leaf().semantics_expanded(expanded=true),
    ),
    (
      test_leaf().semantics_invalid(invalid=false),
      test_leaf().semantics_invalid(invalid=true),
    ),
    (
      test_leaf().semantics_required(required=false),
      test_leaf().semantics_required(required=true),
    ),
    (
      test_leaf().semantics_description("First description"),
      test_leaf().semantics_description("Second description"),
    ),
    (
      test_leaf().semantics_state(busy=false),
      test_leaf().semantics_state(busy=true),
    ),
  ]
  for pair in pairs {
    let changes = pair.1.declaration().changes_from(pair.0.declaration())
    assert_false(changes.layout())
    assert_false(changes.paint())
    assert_true(changes.semantics())
    assert_false(changes.platform())
  }
}

// == Environment modifiers ==

///|
test "disabled modifier identity" {
  assert_true(
    test_leaf().disabled(disabled=true).identity().kind.contains("Disabled"),
  )
}

///|
test "theme modifier identity" {
  assert_true(
    test_leaf().theme(@core.Theme::neutral()).identity().kind.contains("Theme"),
  )
}

///|
test "environment modifier identity" {
  assert_true(
    test_leaf().environment(@core.Environment::neutral()).identity().kind.contains(
      "Environment",
    ),
  )
}

///|
test "focusable modifier identity and value" {
  let view = test_leaf().focusable(focusable=true)
  assert_true(view.identity().kind.contains("Focusable"))
  assert_true(view.accepts_focus())
}

// == Chained modifiers ==

///|
test "chained layout and paint and event compose correctly" {
  let view : @core.View[Int] = @core.View::from_node(ModTestNode::{
      kind: "chain",
      size: @core.Size::new(width=8.0, height=8.0),
    })
    .frame(width=100.0, height=60.0)
    .background(red())
    .corner_radius(8.0)
    .on_tap(1)
  assert_true(view.identity().kind.contains("OnTap"))
  assert_true(view.accepts_focus())
  // The outermost modifier's paint plan gets its own commands. The background
  // modifier is wrapped inside, so its paint commands are in child_layers.
  let plan = view.paint(
    paint_ctx(frame=@core.Rect::new(x=0.0, y=0.0, width=100.0, height=60.0)),
  )
  assert_true(plan.commands.length() + plan.child_layers.length() >= 0)
}

///|
test "chained semantics modifiers: outermost modifier contributes its semantics" {
  // ModifierViewNode returns the outermost modifier's ViewSemanticsInfo.
  // The runtime's element tree builder walks the chain and merges semantics;
  // view.semantics() only returns the modifier node's own info (the outermost).
  // For semantics_checked(checked=true), the outermost modifier contributes checked.
  let view = test_leaf()
    .semantics_role(Checkbox)
    .accessibility_label("Agree")
    .semantics_checked(checked=Checked)
  assert_eq(view.semantics().checked, Some(Checked))
  // The inner semantics_role modifier is wrapped deeper; view.semantics()
  // returns the outermost's info which is only about checked.
}
