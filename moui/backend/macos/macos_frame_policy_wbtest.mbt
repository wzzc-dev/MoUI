///|
test "frame pacing waits for vsync only when a frame is owed and the clock is live" {
  assert_true(
    macos_frame_wait_action(
      frame_owed=false,
      vsync_available=true,
      pacing_enabled=true,
    )
    is SleepIdle,
  )
  assert_true(
    macos_frame_wait_action(
      frame_owed=true,
      vsync_available=true,
      pacing_enabled=true,
    )
    is WaitForVsync,
  )
  assert_true(
    macos_frame_wait_action(
      frame_owed=true,
      vsync_available=true,
      pacing_enabled=false,
    )
    is SleepActive,
  )
  assert_true(
    macos_frame_wait_action(
      frame_owed=true,
      vsync_available=false,
      pacing_enabled=true,
    )
    is SleepActive,
  )
  assert_true(
    macos_frame_wait_action(
      frame_owed=false,
      vsync_available=false,
      pacing_enabled=false,
    )
    is SleepIdle,
  )
}
