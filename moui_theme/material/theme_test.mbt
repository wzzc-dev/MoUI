///|
test "material package entrypoints align with common preset" {
  let expected = @common.DesignPreset::Material
  assert_true(@material.preset() == expected)
  assert_true(@material.tokens().preset == expected)
  assert_true(@material.light_theme().scheme == Light)
  assert_true(@material.dark_theme().scheme == Dark)
  assert_true(@material.system_theme(system_scheme=Dark).scheme == Dark)
  assert_true(
    @audit.design_system_report(@material.preset()).preset == expected,
  )
  assert_true(@audit.manifest(@material.preset()).preset == expected)
  assert_true(@audit.component_token_matrix(@material.preset()).length() > 0)
}
