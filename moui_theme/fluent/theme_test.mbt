///|
test "fluent package entrypoints align with common preset" {
  let expected = @common.DesignPreset::Fluent
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

///|
test "fluent carries structural component differentiation beyond palette" {
  // Fluent 2 is not just a palette swap: it declares subtle/subtle-brand
  // button variants, an underline text-field appearance, and layered
  // card/flyout/dialog shadows that the shared neutral builder does not.
  let light = tokens(scheme=@core.ColorScheme::Light)
  let dark = tokens(scheme=@core.ColorScheme::Dark)
  let transparent = @core.Color::rgba(r=0.0, g=0.0, b=0.0, a=0.0)

  // Subtle / subtle-brand button variants exist and are transparent-backed.
  assert_true(light.components.button.subtle.background.equal(transparent))
  assert_true(
    light.components.button.subtle_brand.foreground == light.palette.primary,
  )

  // Text field is underline appearance: bottom-border-only, with an inner
  // focus reveal border on the focused state.
  assert_true(
    light.components.text_field.appearance ==
    @common.DesignTextFieldAppearance::Underline,
  )
  assert_true(light.components.text_field.normal.bottom_border_only)
  assert_true(light.components.text_field.focused.bottom_border_only)
  assert_true(light.components.text_field.focused.inner_focus_border is Some(_))

  // Layered elevation tiers are populated for both schemes.
  assert_true(light.elevation.card is Some(_))
  assert_true(light.elevation.flyout is Some(_))
  assert_true(light.elevation.dialog is Some(_))
  assert_true(dark.elevation.card is Some(_))
  assert_true(dark.elevation.flyout is Some(_))
  assert_true(dark.elevation.dialog is Some(_))

  // Per-tier surface shadows bind to the Fluent elevation ramp.
  assert_true(light.components.surface.base_shadow is Some(_))
  assert_true(light.components.surface.raised_shadow is Some(_))
  assert_true(light.components.surface.overlay_shadow is Some(_))

  // Neutral presets (e.g. Primer) keep the neutral defaults: no underline,
  // no layered shadows, subtle/subtle-brand alias to transparent/brand.
  let primer = @common.DesignPreset::Primer.tokens(
    scheme=@core.ColorScheme::Light,
  )
  assert_true(
    primer.components.text_field.appearance ==
    @common.DesignTextFieldAppearance::Outline,
  )
  assert_true(primer.components.text_field.normal.bottom_border_only == false)
  assert_true(primer.elevation.card == None)
  assert_true(primer.components.surface.base_shadow == None)
}

///|
test "fluent shadow tokens align with pinned source values" {
  // shadow4/shadow16/shadow64 are source-locked and runtime-aligned: the
  // resolved key-shadow offset matches the pinned @fluentui/tokens value.
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for("shadow4")
    is Some(shadow4) else {
    fail("expected shadow4 runtime alignment")
  }
  assert_true(shadow4.runtime_aligned)
  inspect(shadow4.runtime_value, content="2")
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for("shadow16")
    is Some(shadow16) else {
    fail("expected shadow16 runtime alignment")
  }
  assert_true(shadow16.runtime_aligned)
  inspect(shadow16.runtime_value, content="8")
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for("shadow64")
    is Some(shadow64) else {
    fail("expected shadow64 runtime alignment")
  }
  assert_true(shadow64.runtime_aligned)
  inspect(shadow64.runtime_value, content="32")
}
