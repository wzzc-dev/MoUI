///|
/// Present-to-present frame diagnostics for the macOS host.
///
/// Winc's frame log proved the value of a cheap, always-available summary when
/// judging "smoothness": a mean hides the missed-refresh tail, so this records
/// the interval between presented frames, how many exceed one refresh period,
/// and the p50/p95/max over a five-second window. Enabled with
/// `MOUI_FRAME_LOG=1`; silent otherwise.

///|
let macos_frame_log_enabled_cache : Ref[Bool?] = Ref(None)

///|
let macos_frame_log_since_ms : Ref[Double] = Ref(0.0)

///|
let macos_frame_log_last_present_ms : Ref[Double] = Ref(0.0)

///|
let macos_frame_log_intervals : Ref[Array[Double]] = Ref([])

///|
let macos_frame_log_slow_frames : Ref[Int32] = Ref(0)

///|
fn macos_frame_log_enabled() -> Bool {
  match macos_frame_log_enabled_cache.val {
    Some(enabled) => enabled
    None => {
      let enabled = @env.get_env_var("MOUI_FRAME_LOG") == Some("1")
      macos_frame_log_enabled_cache.val = Some(enabled)
      enabled
    }
  }
}

///|
/// Convert a nominal refresh rate in millihertz to a frame period in
/// milliseconds. Zero falls back to 60 Hz.
fn macos_frame_log_refresh_ms(refresh_millihz : Int32) -> Double {
  if refresh_millihz > 0 {
    1_000_000.0 / refresh_millihz.to_double()
  } else {
    1000.0 / 60.0
  }
}

///|
fn macos_frame_log_reset(now_ms : Double) -> Unit {
  macos_frame_log_since_ms.val = now_ms
  macos_frame_log_intervals.val = []
  macos_frame_log_slow_frames.val = 0
}

///|
/// Record one presented frame. Prints and resets the window every five
/// seconds. The slow-frame threshold is 1.5 refresh periods: a frame that
/// exactly meets the period is still one refresh, a frame beyond it necessarily
/// missed one.
fn macos_frame_log_record(now_ms : Double) -> Unit {
  if !macos_frame_log_enabled() {
    return ()
  }
  let refresh_ms = macos_frame_log_refresh_ms(
    @window_macos.host_vsync_refresh_millihz(),
  )
  let since = macos_frame_log_since_ms.val
  if since == 0.0 {
    macos_frame_log_reset(now_ms)
    macos_frame_log_last_present_ms.val = now_ms
    return ()
  }
  let last = macos_frame_log_last_present_ms.val
  if last > 0.0 {
    let interval = now_ms - last
    if interval > 0.0 {
      macos_frame_log_intervals.val.push(interval)
      if interval > refresh_ms * 1.5 {
        macos_frame_log_slow_frames.val = macos_frame_log_slow_frames.val + 1
      }
    }
  }
  macos_frame_log_last_present_ms.val = now_ms
  if now_ms - since < 5000.0 {
    return ()
  }
  let intervals = macos_frame_log_intervals.val
  let frames = intervals.length()
  if frames > 0 {
    let p50 = percentile_ms(intervals, 0.5)
    let p95 = percentile_ms(intervals, 0.95)
    let max = percentile_ms(intervals, 1.0)
    println(
      "MoUI macOS frame-log: frames=\{frames} p50_ms=\{p50} p95_ms=\{p95} max_ms=\{max} slow_frames=\{macos_frame_log_slow_frames.val} refresh_ms=\{refresh_ms}",
    )
  }
  macos_frame_log_reset(now_ms)
}
