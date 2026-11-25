///|
test "offscreen env parsing keeps the windowed default" {
  assert_false(offscreen_enabled(None))
  assert_false(offscreen_enabled(Some("")))
  assert_false(offscreen_enabled(Some("0")))
  assert_false(offscreen_enabled(Some("   ")))
  assert_true(offscreen_enabled(Some("1")))
  assert_true(offscreen_enabled(Some(" true ")))
}

///|
test "offscreen entry is distinct from the windowed backends" {
  let entry = offscreen_entry(width=520.0, height=360.0, frame_interval_ms=16)
  assert_eq(entry.id(), "moui-devhost-offscreen")
}

///|
test "offscreen surface is a CPU-only logical surface" {
  let presented = Ref(0)
  let presented_size = Ref((0, 0))
  let target = @render.PresentTarget::new(description="offscreen-test", present=frame => {
    presented.val = presented.val + 1
    presented_size.val = (frame.width(), frame.height())
    true
  })
  let surface = offscreen_surface(520.0, 360.0, target)
  let metrics = surface.metrics()
  assert_eq(metrics.logical_size().width, 520.0)
  assert_eq(metrics.logical_size().height, 360.0)
  assert_eq(metrics.physical_size().width, 520.0)
  assert_eq(metrics.physical_size().height, 360.0)
  assert_true(surface.cpu_present() is Some(_))
  assert_true(surface.native_surface() is None)
  assert_true(surface.image_source() is Some(_))
  let host_present = match surface.cpu_present() {
    Some(present) => present
    None => fail("offscreen surface must expose a CPU presenter")
  }
  assert_true(
    host_present.present(
      @render.PixelFrame::new(
        width=520,
        height=360,
        row_bytes=2080,
        scale_factor=1.0,
        pixels=b"\x00\x00\x00\x00",
      ),
    ),
  )
  assert_eq(presented.val, 1)
  assert_eq(presented_size.val.0, 520)
  assert_eq(presented_size.val.1, 360)
}

///|
test "offscreen timer pump fires with host monotonic time" {
  offscreen_timers.val = []
  let frames : Array[@core.Frame] = []
  let subscription = @services.TimerSource::subscription(
    offscreen_timer_source(),
    interval_ms=100.0,
    map=frame => frame,
    key="test/offscreen-frame",
    label="Offscreen test frame",
  )
  let sources = subscription.runtime_sources()
  assert_eq(sources.length(), 1)
  let base = offscreen_now_ms()
  let cancel = sources[0].start(frame => frames.push(frame))
  // Registration schedules one interval past the host clock, so this pump is
  // early even though the wall clock may have moved since `base`.
  pump_offscreen_timers(base + 50.0)
  assert_eq(frames.length(), 0)
  pump_offscreen_timers(base + 250.0)
  assert_eq(frames.length(), 1)
  assert_true(frames[0].time_ms >= base + 100.0)
  assert_true(frames[0].delta_ms > 0.0)
  // Not due again until a full interval has elapsed.
  pump_offscreen_timers(base + 260.0)
  assert_eq(frames.length(), 1)
  pump_offscreen_timers(base + 370.0)
  assert_eq(frames.length(), 2)
  match cancel {
    Some(cancel) => cancel()
    None => fail("offscreen timer source must return a cancel handle")
  }
  pump_offscreen_timers(base + 1000.0)
  assert_eq(frames.length(), 2)
  offscreen_timers.val = []
}

///|
test "offscreen injection hook dispatches complete lines without a window" {
  let path = "/tmp/moui-devhost-offscreen-inject-test.jsonl"
  @fs.remove_file(path) catch {
    _ => ()
  }
  let first : Array[String] = [
    "{\"kind\":\"pointer\",\"phase\":\"Down\"}", "{\"kind\":\"pointer\",\"phase\":\"Up\"}",
  ]
  @fs.write_bytes_to_file(
    path,
    @utf8.encode(first[0] + "\n" + first[1] + "\n{\"partial", bom=false),
  )
  let previous = @env.get_env_var("MOUI_HOT_INJECT_FILE")
  @env.set_env_var("MOUI_HOT_INJECT_FILE", path)
  host_injected_lines.val = 0
  let seen : Array[String] = []
  poll_injected_events_with(payload => {
    seen.push(payload)
    true
  })
  assert_eq(seen.length(), 2)
  assert_eq(seen[0], first[0])
  assert_eq(seen[1], first[1])
  // A second poll without a new complete line must not replay the first two.
  poll_injected_events_with(payload => {
    seen.push(payload)
    true
  })
  assert_eq(seen.length(), 2)
  // Completing the partial line makes exactly that line dispatchable.
  @fs.write_bytes_to_file(
    path,
    @utf8.encode(
      first[0] + "\n" + first[1] + "\n{\"partial\":true}\n",
      bom=false,
    ),
  )
  poll_injected_events_with(payload => {
    seen.push(payload)
    true
  })
  assert_eq(seen.length(), 3)
  assert_eq(seen[2], "{\"partial\":true}")
  match previous {
    Some(value) => @env.set_env_var("MOUI_HOT_INJECT_FILE", value)
    None => @env.unset_env_var("MOUI_HOT_INJECT_FILE")
  }
  @fs.remove_file(path) catch {
    _ => ()
  }
}

///|
test "injection line split keeps a trailing partial line for the next poll" {
  let (lines, consumed) = injected_complete_lines(
    "{\"kind\":\"pointer\"}\n{\"kind\":\"key\"}\n{\"partial",
  )
  assert_eq(consumed, 2)
  assert_eq(lines.length(), 2)
  assert_eq(lines[0], "{\"kind\":\"pointer\"}")
  assert_eq(lines[1], "{\"kind\":\"key\"}")
  let (empty_tail, empty_consumed) = injected_complete_lines("\n")
  assert_eq(empty_consumed, 1)
  assert_eq(empty_tail.length(), 1)
  assert_eq(empty_tail[0], "")
  let (none, none_consumed) = injected_complete_lines("{\"partial\"")
  assert_eq(none_consumed, 0)
  assert_eq(none.length(), 0)
}
