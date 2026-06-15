///|
test "sibling components rebuild only the watched subtree" {
  let left = State::new(0)
  let right = State::new(10)
  let left_builds = Ref(0)
  let right_builds = Ref(0)
  let root = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Horizontal,
    spacing: 0.0,
    main_axis_alignment: MainAxisAlignment::MainStart,
    cross_axis_alignment: CrossAxisAlignment::CrossStart,
    children: [
      ViewSpec::component(
        Component::new(ctx => {
          left_builds.val = left_builds.val + 1
          ViewSpec::TextSpec({
            key: None,
            text: "L\{ctx.watch(left)}",
            size: Size::new(width=40.0, height=20.0),
            font: FontSpec::new(size=12.0, weight=400),
            color: Color::black(),
          })
        }),
      ).key("left"),
      ViewSpec::component(
        Component::new(ctx => {
          right_builds.val = right_builds.val + 1
          ViewSpec::TextSpec({
            key: None,
            text: "R\{ctx.watch(right)}",
            size: Size::new(width=40.0, height=20.0),
            font: FontSpec::new(size=12.0, weight=400),
            color: Color::black(),
          })
        }),
      ).key("right"),
    ],
  })
  let runtime = RuntimeState::new_spec(
    root~,
    size=Size::new(width=100.0, height=40.0),
  )
  inspect(left_builds.val, content="1")
  inspect(right_builds.val, content="1")
  left.set(1)
  inspect(runtime.needs_rebuild, content="true")
  ignore(runtime.build_draw_commands())
  inspect(left_builds.val, content="2")
  inspect(right_builds.val, content="1")
}

///|
test "keyed component reorder preserves subscriptions" {
  let first = State::new(1)
  let second = State::new(2)
  let flip = State::new(false)
  let first_builds = Ref(0)
  let second_builds = Ref(0)
  let first_component = ViewSpec::component(
    Component::new(ctx => {
      first_builds.val = first_builds.val + 1
      ViewSpec::TextSpec({
        key: None,
        text: "A\{ctx.watch(first)}",
        size: Size::new(width=40.0, height=20.0),
        font: FontSpec::new(size=12.0, weight=400),
        color: Color::black(),
      })
    }),
  ).key("first")
  let second_component = ViewSpec::component(
    Component::new(ctx => {
      second_builds.val = second_builds.val + 1
      ViewSpec::TextSpec({
        key: None,
        text: "B\{ctx.watch(second)}",
        size: Size::new(width=40.0, height=20.0),
        font: FontSpec::new(size=12.0, weight=400),
        color: Color::black(),
      })
    }),
  ).key("second")
  let runtime = RuntimeState::new_component(
    root=Component::new(ctx => {
      let children = if ctx.watch(flip) {
        [second_component, first_component]
      } else {
        [first_component, second_component]
      }
      ViewSpec::FlexSpec({
        key: None,
        axis: Axis::Horizontal,
        spacing: 0.0,
        main_axis_alignment: MainAxisAlignment::MainStart,
        cross_axis_alignment: CrossAxisAlignment::CrossStart,
        children,
      })
    }),
    size=Size::new(width=100.0, height=40.0),
  )
  flip.set(true)
  ignore(runtime.build_draw_commands())
  inspect(first_builds.val, content="1")
  inspect(second_builds.val, content="1")
  first.set(7)
  ignore(runtime.build_draw_commands())
  inspect(first_builds.val, content="2")
  inspect(second_builds.val, content="1")
}

///|
test "removed component cancels subscriptions" {
  let visible = State::new(true)
  let child_state = State::new(0)
  let runtime = RuntimeState::new_component(
    root=Component::new(ctx => {
      if ctx.watch(visible) {
        ViewSpec::component(
          Component::new(child_ctx => {
            ViewSpec::TextSpec({
              key: None,
              text: "Child \{child_ctx.watch(child_state)}",
              size: Size::new(width=80.0, height=20.0),
              font: FontSpec::new(size=12.0, weight=400),
              color: Color::black(),
            })
          }),
        ).key("child")
      } else {
        EmptySpec
      }
    }),
    size=Size::new(width=100.0, height=40.0),
  )
  visible.set(false)
  ignore(runtime.build_draw_commands())
  child_state.set(1)
  inspect(runtime.needs_rebuild, content="false")
}

///|
test "layout and paint caches skip unchanged sibling components" {
  let left = State::new(0)
  let right = State::new(0)
  let left_measure = Ref(0)
  let left_paint = Ref(0)
  let right_measure = Ref(0)
  let right_paint = Ref(0)
  let counted = fn(
    label : String,
    state : State[Int],
    measure_count : Ref[Int],
    paint_count : Ref[Int],
  ) -> ViewSpec {
    ViewSpec::component(
      Component::new(ctx => {
        let value = ctx.watch(state)
        ViewSpec::custom(
          measure=constraints => {
            measure_count.val = measure_count.val + 1
            constraints.constrain(Size::new(width=40.0, height=20.0))
          },
          paint=frame => {
            paint_count.val = paint_count.val + 1
            [
              DrawText(
                TextRun::new(
                  text="\{label}\{value}",
                  frame~,
                  font=FontSpec::new(size=12.0, weight=400),
                  color=Color::black(),
                ),
              ),
            ]
          },
        )
      }),
    )
  }
  let root = ViewSpec::FlexSpec({
    key: None,
    axis: Axis::Horizontal,
    spacing: 0.0,
    main_axis_alignment: MainAxisAlignment::MainStart,
    cross_axis_alignment: CrossAxisAlignment::CrossStart,
    children: [
      counted("L", left, left_measure, left_paint).key("left"),
      counted("R", right, right_measure, right_paint).key("right"),
    ],
  })
  let runtime = RuntimeState::new_spec(
    root~,
    size=Size::new(width=100.0, height=40.0),
  )
  ignore(runtime.build_draw_commands())
  inspect(left_measure.val, content="1")
  inspect(left_paint.val, content="1")
  inspect(right_measure.val, content="1")
  inspect(right_paint.val, content="1")
  ignore(runtime.build_draw_commands())
  inspect(left_measure.val, content="1")
  inspect(left_paint.val, content="1")
  inspect(right_measure.val, content="1")
  inspect(right_paint.val, content="1")
  left.set(1)
  ignore(runtime.build_draw_commands())
  inspect(left_measure.val, content="2")
  inspect(left_paint.val, content="2")
  inspect(right_measure.val, content="1")
  inspect(right_paint.val, content="1")
  runtime.dispatch_event(AppEvent::Resize(Size::new(width=120.0, height=40.0)))
  ignore(runtime.build_draw_commands())
  inspect(left_measure.val, content="3")
  inspect(right_measure.val, content="2")
}
