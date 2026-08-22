///|
test "profile_draw_frame records runtime-owned phases" {
  let app = AppRuntime::new_view(
    root=runtime_state_probe_view(kind="timing", declaration_token="one"),
    size=@core.Size::new(width=40.0, height=20.0),
  )
  app.set_environment(@core.Environment::neutral().with_text_scale(1.25))
  let ticks = [0.0, 1.0, 3.0, 4.0, 7.0, 8.0, 12.0, 13.0, 18.0, 20.0]
  let index = Ref(0)
  let profiled = app.profile_draw_frame(() => {
    let value = ticks[index.val]
    index.val = index.val + 1
    value
  })
  let timing = profiled.timing()
  inspect(timing.build_ms(), content="2")
  inspect(timing.layout_ms(), content="3")
  inspect(timing.paint_ms(), content="4")
  inspect(timing.draw_ms(), content="5")
  inspect(timing.total_ms(), content="20")
  ignore(profiled.frame())
  assert_true(app.inspector_snapshot().runtime().last_frame_timing() == timing)
}

///|
test "profile_draw_frame leaves clean phases at zero" {
  let app = AppRuntime::new_view(
    root=runtime_state_probe_view(kind="timing", declaration_token="one"),
    size=@core.Size::new(width=40.0, height=20.0),
  )
  let ticks = [0.0, 2.0, 5.0, 6.0]
  let index = Ref(0)
  let timing = app
    .profile_draw_frame(() => {
      let value = ticks[index.val]
      index.val = index.val + 1
      value
    })
    .timing()
  inspect(timing.build_ms(), content="0")
  inspect(timing.layout_ms(), content="0")
  inspect(timing.paint_ms(), content="0")
  inspect(timing.draw_ms(), content="3")
  inspect(timing.total_ms(), content="6")
}
