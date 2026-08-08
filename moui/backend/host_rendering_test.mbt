///|
test "present completion helpers distinguish terminal outcomes" {
  let completion = status => {
    @render.RenderPresentCompletion::new(
      token=@render.FrameToken::new(surface_generation=1, sequence=1),
      submitted_at_ms=1.0,
      completed_at_ms=2.0,
      presented_at_ms=if status is @render.RenderPresentStatus::Presented {
        2.0
      } else {
        0.0
      },
      status~,
      gpu_context_generation=1,
    )
  }
  let recorded = [completion(@render.RenderPresentStatus::Recorded)]
  assert_false(@render.render_present_completions_have_terminal(recorded))
  assert_false(@render.render_present_completions_have_presented(recorded))
  let dropped = [completion(@render.RenderPresentStatus::Dropped)]
  assert_true(@render.render_present_completions_have_terminal(dropped))
  assert_false(@render.render_present_completions_have_presented(dropped))
  let fallback = [completion(@render.RenderPresentStatus::FallbackToRaster)]
  assert_true(@render.render_present_completions_have_terminal(fallback))
  assert_false(@render.render_present_completions_have_presented(fallback))
  let presented = [completion(@render.RenderPresentStatus::Presented)]
  assert_true(@render.render_present_completions_have_terminal(presented))
  assert_true(@render.render_present_completions_have_presented(presented))
}

///|
test "host driver dispatches resize and deduplicates redraw requests" {
  let scheduled = Ref(0)
  let runtime = host_test_runtime(
    root=@views.empty(),
    size=@core.Size::new(width=10.0, height=10.0),
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    scheduled.val = scheduled.val + 1
  })
  let metrics = @core.SurfaceMetrics::from_logical(
    size=@core.Size::new(width=320.0, height=240.0),
  )
  let first = driver.dispatch(Event::Resized(metrics))
  let second = driver.dispatch(Event::Resized(metrics))
  assert_true(runtime.size() == @core.Size::new(width=320.0, height=240.0))
  inspect(first.redraw_requested, content="true")
  inspect(second.redraw_requested, content="true")
  inspect(scheduled.val, content="1")
  driver.begin_redraw()
  ignore(driver.dispatch(Event::Resized(metrics)))
  inspect(scheduled.val, content="1")
  driver.finish_redraw()
  inspect(scheduled.val, content="2")
}

///|
test "host driver coalesces dirty redraw while previous redraw is pending" {
  let scheduled = Ref(0)
  let text = Ref("")
  let runtime = host_test_text_field_runtime(
    value=text,
    width=240.0,
    height=40.0,
    size=@core.Size::new(width=240.0, height=60.0),
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    scheduled.val = scheduled.val + 1
  })
  ignore(
    driver.dispatch(
      Event::Pointer(
        @core.PointerEvent::new(
          position=@core.Point::new(x=10.0, y=10.0),
          phase=@core.PointerPhase::Down,
        ),
      ),
    ),
  )
  inspect(scheduled.val, content="1")
  let pending = driver.dispatch(
    Event::TextInput(@core.TextInputEvent::InsertText("a")),
  )
  inspect(text.val, content="a")
  inspect(pending.redraw_requested, content="true")
  inspect(scheduled.val, content="1")
  driver.begin_redraw()
  ignore(
    driver.dispatch(Event::TextInput(@core.TextInputEvent::InsertText("b"))),
  )
  inspect(text.val, content="ab")
  inspect(scheduled.val, content="1")
  driver.finish_redraw()
  inspect(scheduled.val, content="2")
}

///|
test "host renderer capability records preserve optional callback behavior" {
  let platform_draws = Ref(0)
  let platform_callbacks = Ref(0)
  let context_losses = Ref(0)
  let renderer = @render.RendererSession::new(
    resize=_ => (),
    render_frame=_ => @render.RenderFrameResult::new(presented=true),
    text_system=() => @core.TextSystem::fallback(),
    image_records=() => [@render.ImageResourceRecord::loading("pending.png")],
    platform_view=@render.RendererPlatformViewCapability::new(
      draw_platform_view_pixels=fn(
        _pixels,
        _src_width,
        _src_height,
        _src_stride,
        _dst_x,
        _dst_y,
        _dst_width,
        _dst_height,
      ) {
        platform_draws.val = platform_draws.val + 1
      },
      set_platform_view_draw_fn=draw_fn => {
        match draw_fn {
          Some(draw) => {
            platform_callbacks.val = platform_callbacks.val + 1
            draw()
          }
          None => ()
        }
      },
    ),
    gpu_recovery=@render.RendererGpuRecoveryCapability::new(
      inject_context_loss=() => context_losses.val = context_losses.val + 1,
      gpu_recovery_count=() => 3,
      gpu_fallback_active=() => true,
    ),
  )
  inspect(renderer.image_diagnostics().records().length(), content="1")
  renderer.draw_platform_view_pixels(b"", 0, 0, 0, 0.0, 0.0, 0.0, 0.0)
  renderer.set_platform_view_draw_fn(
    Some(() => platform_draws.val = platform_draws.val + 1),
  )
  renderer.inject_context_loss()
  inspect(platform_draws.val, content="2")
  inspect(platform_callbacks.val, content="1")
  inspect(context_losses.val, content="1")
  inspect(renderer.gpu_recovery_count(), content="3")
  assert_true(renderer.gpu_fallback_active())
}

///|
test "host renderer absent capabilities keep no-op defaults" {
  let platform_draws = Ref(0)
  let renderer = @render.RendererSession::new(
    resize=_ => (),
    render_frame=_ => @render.RenderFrameResult::new(presented=true),
    text_system=() => @core.TextSystem::fallback(),
  )
  inspect(renderer.image_diagnostics().records().length(), content="0")
  renderer.draw_platform_view_pixels(b"", 0, 0, 0, 0.0, 0.0, 0.0, 0.0)
  renderer.set_platform_view_draw_fn(
    Some(() => platform_draws.val = platform_draws.val + 1),
  )
  renderer.inject_context_loss()
  inspect(renderer.gpu_recovery_count(), content="0")
  inspect(platform_draws.val, content="0")
  assert_false(renderer.gpu_fallback_active())
}

///|
test "redraw scheduler schedules follow-up requested during frame" {
  let scheduled = Ref(0)
  let runtime = host_test_runtime(
    root=@views.empty(),
    size=@core.Size::new(width=10.0, height=10.0),
  )
  let driver = @runtime.HostRuntimeDriver::new(runtime~, schedule_redraw=() => {
    scheduled.val = scheduled.val + 1
  })
  driver.request_redraw()
  inspect(scheduled.val, content="1")
  driver.begin_redraw()
  driver.request_redraw()
  inspect(scheduled.val, content="1")
  driver.finish_redraw()
  inspect(scheduled.val, content="2")
  assert_true(driver.event_result().redraw_requested)
}
