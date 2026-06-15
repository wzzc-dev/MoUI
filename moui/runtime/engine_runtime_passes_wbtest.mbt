///|
test "runtime exposes mount rebuild layout and paint passes" {
  let runtime = RuntimeState::new_spec(
    root=test_label("A"),
    size=Size::new(width=100.0, height=40.0),
  )
  runtime.mount(test_label("B"))
  guard runtime.paint_pass() is [_, DrawText({ text: "B", .. })] else {
    fail("expected mounted label")
  }
  runtime.root_spec = test_label("C")
  runtime.needs_rebuild = true
  runtime.rebuild()
  guard runtime.paint_pass() is [_, DrawText({ text: "C", .. })] else {
    fail("expected rebuilt label")
  }
  runtime.dispatch_event(Resize(Size::new(width=120.0, height=60.0)))
  inspect(runtime.needs_layout, content="true")
  runtime.layout_pass()
  inspect(runtime.needs_layout, content="false")
}

///|
test "dirty queue records and clears runtime work" {
  let runtime = RuntimeState::new_spec(
    root=test_label("A"),
    size=Size::new(width=100.0, height=40.0),
  )
  inspect(runtime.dirty_count(), content="0")
  runtime.mark_dirty(runtime.element_tree.id())
  runtime.mark_dirty(runtime.element_tree.id())
  inspect(runtime.dirty_count(), content="1")
  ignore(runtime.build_draw_commands())
  inspect(runtime.dirty_count(), content="0")
}

///|
test "layout pass refreshes layout tree without repainting" {
  let runtime = RuntimeState::new_spec(
    root=test_label("A"),
    size=Size::new(width=100.0, height=40.0),
  )
  runtime.dispatch_event(Resize(Size::new(width=160.0, height=50.0)))
  inspect(runtime.needs_layout, content="true")
  inspect(runtime.needs_paint, content="true")
  runtime.layout_pass()
  inspect(runtime.needs_layout, content="false")
  inspect(runtime.needs_paint, content="true")
  inspect(runtime.layout_tree.root.frame.size.width, content="160")
  inspect(runtime.layout().frame.size.width, content="160")
}

///|
test "paint only dirty reuses custom layout placement" {
  let place_count = Ref(0)
  let spec = ViewSpec::custom_layout(
    children=[
      ViewSpec::custom(measure=_ => Size::new(width=30.0, height=20.0), paint=frame => {
        [
          FillRoundedRectBrush(
            RoundedRect::new(rect=frame),
            Brush::solid(Color::blue()),
          ),
        ]
      }),
    ],
    measure=ctx => ctx.child_sizes[0],
    place=ctx => {
      place_count.val = place_count.val + 1
      [
        Rect::new(
          x=ctx.frame.origin.x + 7.0,
          y=ctx.frame.origin.y + 5.0,
          width=ctx.child_sizes[0].width,
          height=ctx.child_sizes[0].height,
        ),
      ]
    },
  )
  let runtime = RuntimeState::new_spec(
    root=spec,
    size=Size::new(width=100.0, height=60.0),
  )
  inspect(place_count.val, content="1")
  let layout = runtime.layout()
  inspect(layout.children[0].frame.origin.x, content="7")
  runtime.mark_dirty(runtime.element_tree.id())
  let commands = runtime.build_draw_commands()
  inspect(place_count.val, content="1")
  guard commands is [_, FillRoundedRectBrush({ rect: frame, .. }, _)] else {
    fail("expected child paint command")
  }
  assert_true(frame == layout.children[0].frame)
}
