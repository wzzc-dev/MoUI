///|
test "material package entrypoints align with common preset" {
  let expected = @common.DesignPreset::Material
  assert_true(preset() == expected)
  assert_true(tokens().preset == expected)
  assert_true(light_theme().scheme == @core.ColorScheme::Light)
  assert_true(dark_theme().scheme == @core.ColorScheme::Dark)
  assert_true(
    system_theme(system_scheme=@core.ColorScheme::Dark).scheme ==
    @core.ColorScheme::Dark,
  )
  assert_true(report().preset == expected)
  assert_true(manifest().preset == expected)
  assert_true(component_token_matrix().length() > 0)
}
