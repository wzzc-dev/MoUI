///|
fn svg_icon_test_paint_context(frame : @core.Rect) -> @core.ViewPaintContext {
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
      caret: 0,
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
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
    text_system: @core.TextSystem::fallback(),
    now_ms: 0.0,
  }
}

///|
fn svg_icon_test_layout_context() -> @core.ViewLayoutContext {
  {
    constraints: @core.Constraints::loose(
      @core.Size::new(width=200.0, height=200.0),
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
    environment: @core.Environment::neutral(),
    style: @core.ViewStyle::empty(),
  }
}

///|
test "svg icon parses absolute and relative path commands" {
  let (verbs, view_box) = svg_icon_parse(
    "<svg viewBox=\"0 0 24 24\"><path d=\"M 4 4 L 20 4 l 0 16 Z\"/></svg>",
  )
  assert_eq(verbs.length(), 4)
  assert_true(view_box is Some(_))
  match verbs[1] {
    @core.LineTo(point) => {
      assert_eq(point.x, 20.0)
      assert_eq(point.y, 4.0)
    }
    _ => abort("expected LineTo")
  }
  match verbs[2] {
    @core.LineTo(point) => {
      assert_eq(point.x, 20.0)
      assert_eq(point.y, 20.0)
    }
    _ => abort("expected relative LineTo")
  }
  match verbs[3] {
    @core.Close => ()
    _ => abort("expected Close")
  }
}

///|
test "svg icon reflects smooth cubic control points" {
  let (verbs, _) = svg_icon_parse(
    "<svg viewBox=\"0 0 24 24\"><path d=\"M 0 0 C 4 0 8 4 8 8 S 16 16 16 8\"/></svg>",
  )
  assert_eq(verbs.length(), 3)
  match verbs[2] {
    @core.CubicTo(control1, _control2, point) => {
      // Reflection of (8, 4) about (8, 8).
      assert_eq(control1.x, 8.0)
      assert_eq(control1.y, 12.0)
      assert_eq(point.x, 16.0)
      assert_eq(point.y, 8.0)
    }
    _ => abort("expected reflected CubicTo")
  }
}

///|
test "svg icon converts arcs to cubic segments" {
  let (verbs, _) = svg_icon_parse(
    "<svg viewBox=\"0 0 24 24\"><path d=\"M 0 0 A 8 8 0 0 1 16 0\"/></svg>",
  )
  assert_true(verbs.length() >= 3)
  let mut last = @core.Point::new(x=0.0, y=0.0)
  for verb in verbs {
    match verb {
      @core.CubicTo(_, _, point) => last = point
      @core.LineTo(point) => last = point
      _ => ()
    }
  }
  assert_true((last.x - 16.0).abs() < 0.001)
  assert_true(last.y.abs() < 0.001)
}

///|
test "svg icon draws a path in the requested size" {
  let view : @core.View[Unit] = icon_svg(
    "<svg viewBox=\"0 0 24 24\"><path d=\"M 4 4 L 20 20\"/></svg>",
    size=16.0,
    color=@core.Color::black(),
  )
  let layout = view.layout(svg_icon_test_layout_context())
  assert_eq(layout.size.width, 16.0)
  assert_eq(layout.size.height, 16.0)
  let plan = view.paint(
    svg_icon_test_paint_context(
      @core.Rect::new(x=0.0, y=0.0, width=16.0, height=16.0),
    ),
  )
  assert_eq(plan.commands.length(), 1)
  match plan.commands[0] {
    @core.DrawPath(spec) => {
      assert_eq(spec.verbs.length(), 2)
      assert_true(spec.stroke is Some(_))
    }
    _ => abort("expected DrawPath")
  }
}
