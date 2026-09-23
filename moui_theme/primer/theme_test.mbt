///|
test "primer package entrypoints align with common preset" {
  let expected = @common.DesignPreset::Primer
  assert_true(@primer.preset() == expected)
  assert_true(@primer.tokens().preset == expected)
  assert_true(@primer.light_theme().scheme == Light)
  assert_true(@primer.dark_theme().scheme == Dark)
  assert_true(@primer.system_theme(system_scheme=Dark).scheme == Dark)
  assert_true(@audit.design_system_report(@primer.preset()).preset == expected)
  assert_true(@audit.manifest(@primer.preset()).preset == expected)
  assert_true(@audit.component_token_matrix(@primer.preset()).length() > 0)
}
