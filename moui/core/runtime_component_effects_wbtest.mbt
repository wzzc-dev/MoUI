///|
test "component effects clean up on rebuild and unmount" {
  let value = State::new(0)
  let label = State::new("same")
  let starts = Ref(0)
  let cleanups = Ref(0)
  let runtime = RuntimeState::new_component(
    root=Component::new(ctx => {
      let current = ctx.watch(value)
      let key = ctx.watch(label)
      ctx.run_effect(key~, () => {
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
  inspect(starts.val, content="1")
  inspect(cleanups.val, content="0")
  label.set("changed")
  ignore(runtime.build_draw_commands())
  inspect(starts.val, content="2")
  inspect(cleanups.val, content="1")
  runtime.mount(ViewSpec::EmptySpec)
  inspect(cleanups.val, content="2")
}

///|
test "app runtime destroy cancels component effects and clears lifecycle state" {
  let starts = Ref(0)
  let cleanups = Ref(0)
  let runtime = RuntimeKernel::new_component(
    root=Component::new(ctx => {
      ctx.run_effect(key="root", () => {
        starts.val = starts.val + 1
        Some(() => cleanups.val = cleanups.val + 1)
      })
      ViewSpec::TextSpec({
        key: None,
        text: "Mounted",
        size: Size::new(width=80.0, height=20.0),
        font: FontSpec::new(size=12.0, weight=400),
        color: Color::black(),
      })
    }),
    size=Size::new(width=80.0, height=20.0),
  )
  ignore(runtime.draw_commands())
  inspect(starts.val, content="1")
  runtime.destroy()
  inspect(cleanups.val, content="1")
  inspect(runtime.needs_redraw(), content="false")
  inspect(runtime.draw_commands().length(), content="1")
}

///|
test "component lifecycle helpers run mount once and dispose on unmount" {
  let value = State::new(0)
  let mounts = Ref(0)
  let disposes = Ref(0)
  let runtime = RuntimeState::new_component(
    root=Component::new(ctx => {
      let current = ctx.watch(value)
      ctx.on_mount(key="metrics", () => mounts.val = mounts.val + 1)
      ctx.on_dispose(key="metrics", () => disposes.val = disposes.val + 1)
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
  inspect(mounts.val, content="1")
  inspect(disposes.val, content="0")
  value.set(1)
  ignore(runtime.build_draw_commands())
  inspect(mounts.val, content="1")
  inspect(disposes.val, content="0")
  runtime.mount(ViewSpec::EmptySpec)
  inspect(disposes.val, content="1")
}

///|
test "component update effects rerun only when deps change" {
  let dep = State::new("a")
  let tick = State::new(0)
  let starts = Ref(0)
  let cleanups = Ref(0)
  let last_reason : Ref[ComponentEffectCancelReason?] = Ref(None)
  let runtime = RuntimeState::new_component(
    root=Component::new(ctx => {
      let current_dep = ctx.watch(dep)
      let current_tick = ctx.watch(tick)
      ctx.on_update_with_reason(key="sync", deps=[current_dep], () => {
        starts.val = starts.val + 1
        Some(reason => {
          cleanups.val = cleanups.val + 1
          last_reason.val = Some(reason)
        })
      })
      ViewSpec::TextSpec({
        key: None,
        text: "\{current_dep}:\{current_tick}",
        size: Size::new(width=80.0, height=20.0),
        font: FontSpec::new(size=12.0, weight=400),
        color: Color::black(),
      })
    }),
    size=Size::new(width=80.0, height=20.0),
  )
  ignore(runtime.build_draw_commands())
  inspect(starts.val, content="1")
  tick.set(1)
  ignore(runtime.build_draw_commands())
  inspect(starts.val, content="1")
  inspect(cleanups.val, content="0")
  dep.set("b")
  ignore(runtime.build_draw_commands())
  inspect(starts.val, content="2")
  inspect(cleanups.val, content="1")
  match last_reason.val {
    Some(EffectKeyChanged) => ()
    _ => fail("expected key change cleanup reason")
  }
}

///|
test "runtime destroy reports effect cancellation reason" {
  let reason : Ref[ComponentEffectCancelReason?] = Ref(None)
  let runtime = RuntimeKernel::new_component(
    root=Component::new(ctx => {
      ctx.run_effect(key="tracked", () => None)
      ctx.run_effect_with_reason(key="tracked-reason", () => {
        Some(cancel_reason => reason.val = Some(cancel_reason))
      })
      ViewSpec::TextSpec({
        key: None,
        text: "Tracked",
        size: Size::new(width=80.0, height=20.0),
        font: FontSpec::new(size=12.0, weight=400),
        color: Color::black(),
      })
    }),
    size=Size::new(width=80.0, height=20.0),
  )
  ignore(runtime.draw_commands())
  runtime.destroy()
  match reason.val {
    Some(EffectRuntimeDestroyed) => ()
    _ => fail("expected runtime destroy cleanup reason")
  }
}
