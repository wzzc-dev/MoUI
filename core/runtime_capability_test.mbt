///|
test "component effects clean up on rebuild and unmount" {
  let value = State::new(0)
  let starts = Ref(0)
  let cleanups = Ref(0)
  let runtime = RuntimeState::new_component(
    root=Component::new(ctx => {
      let current = ctx.watch(value)
      ctx.run_effect(key="value:\{current}", () => {
        starts.val = starts.val + 1
        Some(() => cleanups.val = cleanups.val + 1)
      })
      ViewSpec::TextSpec({
        key: None,
        text: "Value \{current}",
        size: Size::new(width=80.0, height=20.0),
        font: FontSpec::new(size=12.0, weight=400),
        color: Color::black(),
      })
    }),
    size=Size::new(width=80.0, height=20.0),
  )
  ignore(runtime.build_draw_commands())
  inspect(starts.val, content="1")
  inspect(cleanups.val, content="0")
  value.set(1)
  ignore(runtime.build_draw_commands())
  inspect(starts.val, content="2")
  inspect(cleanups.val, content="1")
  runtime.mount(ViewSpec::EmptySpec)
  inspect(cleanups.val, content="2")
}

///|
test "saveable strings survive rebuild resize and root remount by stable component id" {
  let value = State::new("first")
  let runtime = RuntimeState::new_component(
    root=Component::new(ctx => {
      let current = ctx.watch(value)
      ctx.save_string(key="draft", current)
      ViewSpec::TextSpec({
        key: None,
        text: ctx.restore_string(key="draft").unwrap_or("missing"),
        size: Size::new(width=120.0, height=20.0),
        font: FontSpec::new(size=12.0, weight=400),
        color: Color::black(),
      })
    }),
    size=Size::new(width=120.0, height=20.0),
  )
  guard runtime.build_draw_commands()[1] is DrawText({ text: "first", .. }) else {
    fail("expected initial saved value")
  }
  value.set("second")
  guard runtime.build_draw_commands()[1] is DrawText({ text: "second", .. }) else {
    fail("expected saved value after rebuild")
  }
  runtime.dispatch_event(AppEvent::Resize(Size::new(width=160.0, height=30.0)))
  guard runtime.build_draw_commands()[1] is DrawText({ text: "second", .. }) else {
    fail("expected saved value after resize")
  }
  runtime.mount(runtime.root_spec)
  guard runtime.build_draw_commands()[1] is DrawText({ text: "second", .. }) else {
    fail("expected saved value after same-root remount")
  }
}
