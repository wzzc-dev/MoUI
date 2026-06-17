///|
pub fn[Msg] expanded(
  child : @core.View[Msg],
  weight? : Double = 1.0,
) -> @core.View[Msg] {
  child.expanded(weight~)
}

///|
pub fn[Msg] flexible(
  child : @core.View[Msg],
  weight? : Double = 1.0,
) -> @core.View[Msg] {
  child.flexible(weight~)
}

///|
pub fn[Msg] layout_priority(
  child : @core.View[Msg],
  priority : Double,
) -> @core.View[Msg] {
  child.layout_priority(priority)
}

///|
pub fn[Msg] align(
  child : @core.View[Msg],
  alignment? : @core.Alignment = @core.Alignment::center(),
) -> @core.View[Msg] {
  child.align(alignment~)
}

///|
pub fn[Msg] aspect_ratio(
  child : @core.View[Msg],
  ratio : Double,
) -> @core.View[Msg] {
  child.aspect_ratio(ratio)
}

///|
pub fn[Msg] intrinsic_width(child : @core.View[Msg]) -> @core.View[Msg] {
  child.intrinsic_width()
}

///|
pub fn[Msg] intrinsic_height(child : @core.View[Msg]) -> @core.View[Msg] {
  child.intrinsic_height()
}

///|
pub fn[Msg] custom_layout(
  measure~ : (@core.Constraints) -> @core.Size,
  paint~ : (@core.Rect) -> Array[@core.DrawCommand],
  semantics_role? : @core.SemanticsRole = @core.SemanticsRole::Group,
  semantics_label? : String = "",
) -> @core.View[Msg] {
  @widget.custom(
    measure=ctx => @core.WidgetLayoutResult::new(size=measure(ctx.constraints)),
    paint=ctx => @core.WidgetPaintPlan::commands(paint(ctx.frame)),
    semantics=() => {
      @core.WidgetSemanticsInfo::new(
        role=semantics_role,
        label=semantics_label,
        value=semantics_label,
      )
    },
  )
}

///|
pub fn[Msg] custom_children_layout(
  children~ : Array[@core.View[Msg]],
  measure~ : (@core.CustomLayoutContext) -> @core.Size,
  place~ : (@core.CustomPlacementContext) -> Array[@core.Rect],
  paint? : (@core.Rect) -> Array[@core.DrawCommand] = _frame => [],
  semantics_role? : @core.SemanticsRole = @core.SemanticsRole::Group,
  semantics_label? : String = "",
) -> @core.View[Msg] {
  @widget.custom_children_layout(
    children~,
    measure~,
    place~,
    paint~,
    semantics_role~,
    semantics_label~,
  )
}

///|
pub fn[Msg] component(
  build : (@core.ComponentContext) -> @core.View[Msg],
) -> @core.View[Msg] {
  @widget.component(build)
}

///|
fn available_width(width : Double, constraints : @core.Constraints) -> Double {
  constraints.constrain(@core.Size::new(width~, height=0.0)).width
}

///|
fn placement_width(width : Double, frame : @core.Rect) -> Double {
  if frame.size.width > 0.0 {
    layout_max_double(1.0, layout_min_double(width, frame.size.width))
  } else {
    layout_max_double(1.0, width)
  }
}

///|
fn layout_mirror_x(
  frame : @core.Rect,
  local_x : Double,
  width : Double,
  direction : @core.LayoutDirection,
) -> Double {
  match direction {
    @core.LayoutDirection::LeftToRight => frame.origin.x + local_x
    @core.LayoutDirection::RightToLeft =>
      frame.origin.x + frame.size.width - local_x - width
  }
}

///|
fn layout_ceil_div(a : Int, b : Int) -> Int {
  let b = layout_max_int(1, b)
  if a == 0 {
    0
  } else {
    (a + b - 1) / b
  }
}

///|
fn layout_min_int(a : Int, b : Int) -> Int {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn layout_max_int(a : Int, b : Int) -> Int {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn layout_min_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn layout_max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}
