///|
test "overlay fade duration resolves reduced motion and theme tiers" {
  let neutral = RenderEnvironment::from_environment(@core.Environment::neutral())
  assert_eq(overlay_fade_duration_ms(neutral), 180.0)
  let reduced = RenderEnvironment::from_environment(
    @core.Environment::neutral().with_reduced_motion(true),
  )
  assert_eq(overlay_fade_duration_ms(reduced), 0.0)
  let base = @core.Environment::neutral()
  let custom = {
    ..base,
    theme: {
      ..base.theme,
      motion: {
        fast_ms: 10.0,
        normal_ms: 50.0,
        slow_ms: 100.0,
        easing: @core.Easing::EaseInOut,
      },
    },
  }
  assert_eq(
    overlay_fade_duration_ms(RenderEnvironment::from_environment(custom)),
    50.0,
  )
}

///|
test "overlay enter opacity completes immediately at zero duration" {
  let enter = [(ElementId::new(7), 100.0)]
  // Zero duration (reduced motion): terminal at any elapsed time.
  assert_eq(overlay_enter_opacity(enter, ElementId::new(7), 100.0, 0.0), None)
  assert_eq(overlay_enter_opacity(enter, ElementId::new(7), 500.0, 0.0), None)
  // Mid-fade progress is elapsed/duration.
  let mid = overlay_enter_opacity(enter, ElementId::new(7), 190.0, 180.0)
  assert_eq(mid.unwrap(), 0.5)
  // A completed fade reports None so the render cache re-engages.
  assert_eq(
    overlay_enter_opacity(enter, ElementId::new(7), 500.0, 180.0),
    None,
  )
  // Untracked surfaces render normally.
  assert_eq(overlay_enter_opacity(enter, ElementId::new(9), 190.0, 180.0), None)
}
