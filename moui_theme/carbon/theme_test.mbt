///|
test "carbon package entrypoints align with common preset" {
  let expected = @common.DesignPreset::Carbon
  assert_true(@carbon.preset() == expected)
  assert_true(@carbon.tokens().preset == expected)
  assert_true(@carbon.light_theme().scheme == Light)
  assert_true(@carbon.dark_theme().scheme == Dark)
  assert_true(@carbon.system_theme(system_scheme=Dark).scheme == Dark)
  assert_true(@audit.design_system_report(@carbon.preset()).preset == expected)
  assert_true(@audit.manifest(@carbon.preset()).preset == expected)
  assert_true(@audit.component_token_matrix(@carbon.preset()).length() > 0)
}
