///|
test "sun blend mapping covers the advanced modes" {
  let checks : Array[(@core.BlendMode, @sun_graphics.BlendMode)] = [
    (@core.BlendMode::Add, Add),
    (@core.BlendMode::Difference, Difference),
    (@core.BlendMode::Exclusion, Exclusion),
    (@core.BlendMode::HardLight, HardLight),
    (@core.BlendMode::SoftLight, SoftLight),
    (@core.BlendMode::ColorDodge, ColorDodge),
    (@core.BlendMode::ColorBurn, ColorBurn),
    (@core.BlendMode::Source, Source),
  ]
  for pair in checks {
    let (core_mode, sun_mode) = pair
    let mapped = sun_blend_mode(core_mode)
    assert_true(
      mapped == sun_mode,
      msg="sun blend mapping mismatch for a core mode",
    )
  }
}
