///|
/// The golden gate: every scene's rendered pixels must hash to the checked-in
/// baseline. A failing diff prints the actual hash — that is the update
/// procedure's input, not a reason to relax the gate. Scenes whose baseline is
/// still pending are collected into one report so a first run fills every
/// constant in a single pass.
test "golden scenes match the checked-in pixel baselines" {
  let mut pending = ""
  for scene in @golden.golden_scenes() {
    let frame = @golden.golden_render_frame(scene.1)
    let hash = @golden.golden_frame_hash(
      width=frame.width(),
      height=frame.height(),
      row_bytes=frame.row_bytes(),
      pixels=frame.pixels(),
    )
    let mut expected : UInt64 = 0UL
    let mut found = false
    for baseline in @golden.golden_baselines() {
      if baseline.0 == scene.0 {
        expected = baseline.1
        found = true
      }
    }
    assert_true(found)
    if expected == 0UL {
      pending = if pending == "" {
        "\{scene.0}=\{hash}"
      } else {
        "\{pending} \{scene.0}=\{hash}"
      }
    } else {
      inspect(hash, content=expected.to_string())
    }
  }
  if pending != "" {
    inspect(pending, content="PENDING-BASELINES")
  }
}

///|
/// The perceptual gate: two presentations through independent renderer
/// instances must diff at zero, so a golden-hash change always means the
/// pixels moved deliberately, never that the renderer became nondeterministic.
test "golden scenes render identically across fresh renderer instances" {
  for scene in @golden.golden_scenes() {
    let first = @golden.golden_render_frame(scene.1)
    let second = @golden.golden_render_frame(scene.1)
    let diff = @pixelmatch.pixelmatch(
      @golden.golden_frame_image(first),
      @golden.golden_frame_image(second),
      None,
      @pixelmatch.Options::default(),
    )
    inspect(diff, content="0")
  }
}

///|
/// The cache gate: a second render through the *same* renderer exercises the
/// cached-layer paths and must stay pixel-identical, so a caching regression
/// surfaces here before a Showcase does.
test "golden scenes stay pixel-stable across cached passes" {
  for scene in @golden.golden_scenes() {
    let frames = @golden.golden_render_frames(scene.1, passes=2)
    assert_true(frames.length() == 2)
    let diff = @pixelmatch.pixelmatch(
      @golden.golden_frame_image(frames[0]),
      @golden.golden_frame_image(frames[1]),
      None,
      @pixelmatch.Options::default(),
    )
    inspect(diff, content="0")
  }
}

///|
/// Content probe: the hash gates above are opaque, so the harness also
/// verifies known scene pixels directly — a baseline that drifted because the
/// renderer silently stopped drawing a command would fail here, not pass.
test "golden scene pixels carry the expected colors at probe points" {
  let mut scene_commands : Array[@core.DrawCommand] = []
  let mut have_scene = false
  for scene in @golden.golden_scenes() {
    if scene.0 == "solid_and_rounded_rects" {
      scene_commands = scene.1
      have_scene = true
    }
  }
  assert_true(have_scene)
  let image = @golden.golden_frame_image(
    @golden.golden_render_frame(scene_commands),
  )
  // The background corner stays white.
  let corner = image.get_pixel(0, 0)
  assert_true(corner.r > 240 && corner.g > 240 && corner.b > 240)
  // The center of the first rect lands inside the blue fill (0.12, 0.36,
  // 0.95 after sRGB conversion); loose bands keep the probe about "did the
  // rect draw", not about exact color math.
  let rect_center = image.get_pixel(17, 17)
  assert_true(rect_center.r < 70 && rect_center.b > 190)
}
