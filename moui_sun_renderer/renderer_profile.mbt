///|
/// Opt-in frame profiler for the Sun raster path (`MOUI_SUN_PROFILE=1`).
///
/// Prints per-frame phase totals (canvas setup, command replay, readback,
/// present) plus per-command-type bucket totals, so "the CPU rasterizer is
/// slow" can be attributed to a phase and a command family. Disabled, every
/// call site is one cached-boolean check; keep it dependency-free apart from
/// the core monotonic clock. Evidence from its first round of use is recorded
/// in `docs/plans/done/sun-cpu-raster-hot-paths.md`.

///|
let sun_profile_enabled_cache : Ref[Bool?] = Ref(None)

///|
let sun_profile_frames_printed : Ref[Int32] = Ref(0)

///|
let sun_profile_frames_limit : Ref[Int32?] = Ref(None)

///|
let sun_profile_bucket_count : Int32 = 34

///|
let sun_profile_bucket_us : Ref[Array[Double]] = Ref(
  Array::make(sun_profile_bucket_count, 0.0),
)

///|
let sun_profile_bucket_hits : Ref[Array[Int32]] = Ref(
  Array::make(sun_profile_bucket_count, 0),
)

///|
let sun_profile_bucket_names : Array[String] = [
  "Clear", "FillRect", "StrokeRect", "FillRoundedRect", "StrokeRoundedRect", "FillRoundedRectBrush",
  "StrokeRoundedRectBrush", "DrawShadow", "DrawText", "DrawImage", "PushClip", "PopClip",
  "PushRoundedClip", "PopRoundedClip", "PushPathClip", "PopPathClip", "PushTransform",
  "PopTransform", "PushOpacity", "PopOpacity", "PushLayer", "PopLayer", "BeginRetainedLayer",
  "EndRetainedLayer", "PushFilter", "PopFilter", "DrawPath", "DrawShaderEffect",
  "CachedLayerComposite", "CachedLayerRender", "PlatformViewDraw", "Other", "BrushFillSolid",
  "BrushFillShader",
]

///|
fn sun_profile_enabled() -> Bool {
  match sun_profile_enabled_cache.val {
    Some(enabled) => enabled
    None => {
      let enabled = @env.get_env_var("MOUI_SUN_PROFILE") == Some("1")
      sun_profile_enabled_cache.val = Some(enabled)
      enabled
    }
  }
}

///|
fn sun_profile_frames_limit_value() -> Int32 {
  match sun_profile_frames_limit.val {
    Some(limit) => limit
    None => {
      let limit = 60
      sun_profile_frames_limit.val = Some(limit)
      limit
    }
  }
}

///|
fn sun_profile_begin_frame() -> Unit {
  if !sun_profile_enabled() {
    return ()
  }
  let us = sun_profile_bucket_us.val
  let hits = sun_profile_bucket_hits.val
  for index in 0..<sun_profile_bucket_count {
    us[index] = 0.0
    hits[index] = 0
  }
}

///|
fn sun_profile_add(bucket : Int32, micros : Double) -> Unit {
  if !sun_profile_enabled() {
    return ()
  }
  if bucket >= 0 && bucket.to_int() < sun_profile_bucket_count {
    sun_profile_bucket_us.val[bucket.to_int()] = sun_profile_bucket_us.val[bucket.to_int()] +
      micros
    sun_profile_bucket_hits.val[bucket.to_int()] = sun_profile_bucket_hits.val[bucket.to_int()] +
      1
  }
}

///|
fn sun_profile_tag(command : @core.DrawCommand) -> Int32 {
  match command {
    Clear(_) => 0
    FillRect(_) => 1
    StrokeRect(_) => 2
    FillRoundedRect(_) => 3
    StrokeRoundedRect(_) => 4
    FillRoundedRectBrush(_) => 5
    StrokeRoundedRectBrush(_) => 6
    DrawShadow(_) => 7
    DrawText(_) => 8
    DrawImage(_) => 9
    PushClip(_) => 10
    PopClip => 11
    PushRoundedClip(_) => 12
    PopRoundedClip => 13
    PushPathClip(_) => 14
    PopPathClip => 15
    PushTransform(_) => 16
    PopTransform => 17
    PushOpacity(_) => 18
    PopOpacity => 19
    PushLayer(_) => 20
    PopLayer => 21
    BeginRetainedLayer(_) => 22
    EndRetainedLayer(_) => 23
    PushFilter(_) => 24
    PopFilter => 25
    DrawPath(_) => 26
    DrawShaderEffect(_) => 27
  }
}

///|
fn sun_profile_report_frame(
  commands : Int32,
  setup_us : Double,
  replay_us : Double,
  read_us : Double,
  present_us : Double,
) -> Unit {
  if !sun_profile_enabled() {
    return ()
  }
  let printed = sun_profile_frames_printed.val
  if printed >= sun_profile_frames_limit_value() {
    return ()
  }
  sun_profile_frames_printed.val = printed + 1
  let bucket_us = sun_profile_bucket_us.val.copy()
  let bucket_hits = sun_profile_bucket_hits.val.copy()
  // Keep the per-frame report dependency-free: pick the top buckets with a
  // simple selection pass instead of a comparator closure.
  let order : Array[Int32] = Array::make(sun_profile_bucket_count, 0)
  let mut filled = 0
  for index in 0..<sun_profile_bucket_count {
    if bucket_hits[index] > 0 {
      order[filled] = index
      filled = filled + 1
    }
  }
  let mut slot = 0
  while slot < filled {
    let mut best = slot
    let mut scan = slot + 1
    while scan < filled {
      if bucket_us[order[scan]] > bucket_us[order[best]] {
        best = scan
      }
      scan = scan + 1
    }
    if best != slot {
      let tmp = order[slot]
      order[slot] = order[best]
      order[best] = tmp
    }
    slot = slot + 1
  }
  let total_us = setup_us + replay_us + read_us + present_us
  eprintln(
    "MoUI sun profile frame=\{printed} commands=\{commands} total_ms=\{sun_profile_ms(total_us)} setup_ms=\{sun_profile_ms(setup_us)} replay_ms=\{sun_profile_ms(replay_us)} read_ms=\{sun_profile_ms(read_us)} present_ms=\{sun_profile_ms(present_us)}",
  )
  let mut shown = 0
  while shown < filled && shown < 12 {
    let bucket = order[shown]
    eprintln(
      "  sun bucket \{sun_profile_bucket_names[bucket]}: ms=\{sun_profile_ms(bucket_us[bucket])} hits=\{bucket_hits[bucket]}",
    )
    shown = shown + 1
  }
}

///|
fn sun_profile_ms(micros : Double) -> Double {
  let value = micros / 1000.0
  (value * 1000.0).round() / 1000.0
}
