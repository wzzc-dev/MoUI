///|
test "design system tokens generate existing theme presets" {
  let material_tokens = @common.DesignPreset::Material.tokens()
  let material_theme = @common.DesignPreset::Material.theme()
  assert_true(material_tokens.to_theme() == material_theme)
  assert_true(material_tokens.palette.primary == material_theme.palette.primary)
  assert_true(
    material_tokens.components.button.primary.radius ==
    material_tokens.radius.md,
  )
  inspect(material_tokens.typography.body.size, content="14")
  inspect(material_tokens.radius.md, content="12")
  inspect(material_tokens.motion.fast_ms, content="200")
  inspect(material_tokens.motion.normal_ms, content="300")
  inspect(material_tokens.motion.slow_ms, content="400")
  assert_true(
    material_tokens.components.text_field.focused.border ==
    material_tokens.palette.focus,
  )
  assert_true(
    material_tokens.components.text_field.font ==
    material_tokens.typography.body,
  )
  assert_true(
    material_tokens.components.text_field.core_style().font ==
    material_tokens.typography.body,
  )
  assert_true(
    material_tokens.components.choice_control.selected_color ==
    material_tokens.palette.primary,
  )
  assert_true(
    material_tokens.components.progress.foreground ==
    material_tokens.palette.primary,
  )
  assert_true(
    material_tokens.components.slider.thumb_color ==
    material_tokens.palette.primary,
  )
  assert_true(
    material_tokens.components.picker.foreground ==
    material_tokens.palette.foreground,
  )
  assert_true(
    material_tokens.components.picker.background.fallback_color() ==
    @core.Color::rgba(r=243.0 / 255.0, g=237.0 / 255.0, b=247.0 / 255.0),
  )
  assert_true(
    material_tokens.components.date_picker.radius == material_tokens.radius.md,
  )
  assert_true(
    material_tokens.components.feedback.success.foreground ==
    material_tokens.palette.success,
  )
  let carbon_tokens = @common.DesignPreset::Carbon.tokens()
  inspect(carbon_tokens.state_layer.hover_alpha, content="0.12")
  assert_true(
    carbon_tokens.components.button.tonal.state_layer_alpha ==
    carbon_tokens.state_layer.hover_alpha,
  )
  assert_true(
    carbon_tokens.components.slider.foreground ==
    carbon_tokens.palette.foreground,
  )
  assert_true(
    carbon_tokens.components.slider.thumb_color == carbon_tokens.palette.primary,
  )
  assert_true(
    material_tokens.components.badge.danger.background ==
    material_tokens.palette.danger,
  )
  assert_true(
    material_tokens.components.form_validation.foreground ==
    material_tokens.palette.danger,
  )
  assert_true(
    material_tokens.components.progress.core_style().foreground ==
    material_tokens.palette.primary,
  )
  assert_true(
    material_tokens.components.feedback.core_style().success.foreground ==
    material_tokens.palette.success,
  )
  assert_true(
    material_tokens.components.badge.core_style().danger.background ==
    material_tokens.palette.danger,
  )
  assert_true(
    material_tokens.components.form_validation.core_style().border ==
    material_tokens.palette.danger.multiply_alpha(0.72),
  )
  assert_true(
    material_tokens.to_theme().palette.success ==
    material_tokens.palette.success,
  )
  assert_true(
    material_tokens.to_theme().palette.danger == material_tokens.palette.danger,
  )
}

///|
test "design system tokens carry density and variant adapters" {
  let compact = @common.DesignPreset::Carbon.tokens(
    density=@common.DesignDensity::Compact,
  )
  let comfortable = @common.DesignPreset::Carbon.tokens(
    density=@common.DesignDensity::Comfortable,
  )
  assert_true(compact.spacing.sm < comfortable.spacing.sm)
  inspect(compact.density.label(), content="compact")
  let high_contrast = @common.DesignPreset::Fluent.tokens_for_variant(
    variant=@common.DesignSchemeVariant::SchemeHighContrast,
    system_scheme=@core.ColorScheme::Dark,
  )
  assert_true(
    high_contrast.variant == @common.DesignSchemeVariant::SchemeHighContrast,
  )
  assert_true(high_contrast.scheme == @core.ColorScheme::Dark)
  assert_true(high_contrast.palette.outline == @core.Color::white())
  inspect(high_contrast.motion.normal_ms, content="0")
  let system = @common.DesignPreset::Primer.tokens_for_variant(
    variant=@common.DesignSchemeVariant::SchemeSystem,
    system_scheme=@core.ColorScheme::Dark,
  )
  assert_true(system.variant == @common.DesignSchemeVariant::SchemeSystem)
  assert_true(system.scheme == @core.ColorScheme::Dark)
}

///|
test "token group resolver reports tie core token groups to neutral surfaces" {
  for
    preset in [
      @common.DesignPreset::Material,
      @common.DesignPreset::Carbon,
      @common.DesignPreset::Primer,
      @common.DesignPreset::Fluent,
    ] {
    let report = token_group_resolver_report(preset)
    assert_true(report.length() == 7)
    assert_true(token_group_resolver_count(preset) == 7)
    assert_true(token_group_resolver_gap_count(preset) == 0)
    assert_true(token_group_resolver_source_gap_count(preset) == 0)
    assert_true(token_group_resolver_official_parity_gap_count(preset) == 7)
    for item in report {
      assert_true(item.source_declared)
      assert_true(item.source_locked)
      assert_true(item.source_ref != "")
      assert_true(item.token_surface != "")
      assert_true(item.tokens_api.contains("DesignPreset::tokens"))
      assert_true(item.theme_api != "")
      assert_true(item.resolves_tokens)
      assert_true(item.resolves_neutral_surface)
      assert_true(item.status != DesignTokenStatus::NotMapped)
    }
  }
  guard token_group_resolver_for(
      @common.DesignPreset::Material,
      DesignSystemRequirement::SemanticPalette,
    )
    is Some(material_palette) else {
    fail("expected Material semantic palette token-group resolver")
  }
  assert_true(material_palette.source_label == "Material Web color theming")
  assert_true(material_palette.token_surface.contains("DesignSemanticPalette"))
  assert_true(material_palette.remaining_gap.contains("semantic palette"))
  guard token_group_resolver_for(
      @common.DesignPreset::Fluent,
      DesignSystemRequirement::Motion,
    )
    is Some(fluent_motion) else {
    fail("expected Fluent motion token-group resolver")
  }
  assert_true(fluent_motion.source_label == "Fluent 2 design tokens")
  assert_true(fluent_motion.theme_api.contains("DesignMotionTokens"))
  guard token_group_resolver_for(
      @common.DesignPreset::Carbon,
      DesignSystemRequirement::StateLayer,
    )
    is Some(carbon_state_layer) else {
    fail("expected Carbon state-layer token-group resolver")
  }
  assert_true(carbon_state_layer.status == DesignTokenStatus::ComponentMapped)
  assert_true(carbon_state_layer.theme_api.contains("DesignComponentTokens"))
}

///|
test "density resolver reports tie spacing scales to source mapped adapters" {
  for
    preset in [
      @common.DesignPreset::Material,
      @common.DesignPreset::Carbon,
      @common.DesignPreset::Primer,
      @common.DesignPreset::Fluent,
    ] {
    let report = density_resolver_report(
      preset,
      scheme=@core.ColorScheme::Light,
    )
    assert_true(report.length() == 3)
    assert_true(density_resolver_count(preset) == 3)
    assert_true(density_resolver_gap_count(preset) == 0)
    assert_true(density_resolver_source_gap_count(preset) == 0)
    if preset == @common.DesignPreset::Material {
      assert_true(density_resolver_official_parity_gap_count(preset) == 3)
    } else {
      assert_true(density_resolver_official_parity_gap_count(preset) == 0)
    }
    for item in report {
      assert_true(item.source_declared)
      assert_true(item.source_locked)
      assert_true(item.source_ref != "")
      assert_true(item.tokens_api.contains("density"))
      assert_true(item.theme_api.contains("density"))
      assert_true(item.resolves_tokens)
      assert_true(item.resolves_theme)
      assert_true(item.resolves_components)
      assert_true(item.spacing_sm == item.theme_spacing_sm)
      assert_true(item.spacing_md == item.theme_spacing_md)
      assert_true(item.surface_padding == item.spacing_md)
      assert_true(item.feedback_padding == item.spacing_sm)
    }
  }
  guard density_resolver_for(
      @common.DesignPreset::Carbon,
      @common.DesignDensity::Compact,
    )
    is Some(carbon_compact) else {
    fail("expected Carbon compact density resolver")
  }
  assert_true(carbon_compact.status == DesignTokenStatus::ThemeMapped)
  assert_true(carbon_compact.source_label == "Carbon themes")
  inspect(carbon_compact.density_multiplier, content="0.82")
  guard density_resolver_for(
      @common.DesignPreset::Material,
      @common.DesignDensity::Comfortable,
    )
    is Some(material_comfortable) else {
    fail("expected Material comfortable density resolver")
  }
  assert_true(material_comfortable.spacing_md > material_comfortable.spacing_sm)
  assert_true(material_comfortable.remaining_gap.contains("Material Web"))
  guard density_resolver_for(
      @common.DesignPreset::Fluent,
      @common.DesignDensity::Standard,
      scheme=@core.ColorScheme::Dark,
    )
    is Some(fluent_standard_dark) else {
    fail("expected Fluent standard dark density resolver")
  }
  assert_true(fluent_standard_dark.scheme == @core.ColorScheme::Dark)
  assert_true(fluent_standard_dark.source_label == "Fluent 2 design tokens")
}

///|
test "variant theme helpers expose high contrast and system themes" {
  let high_contrast_tokens = @common.DesignPreset::Material.tokens_for_variant(
    variant=@common.DesignSchemeVariant::SchemeHighContrast,
    system_scheme=@core.ColorScheme::Dark,
    density=@common.DesignDensity::Compact,
  )
  let high_contrast_theme = @common.preset_for_variant(
    @common.DesignPreset::Material,
    variant=@common.DesignSchemeVariant::SchemeHighContrast,
    system_scheme=@core.ColorScheme::Dark,
    density=@common.DesignDensity::Compact,
  )
  assert_true(high_contrast_theme == high_contrast_tokens.to_theme())
  assert_true(high_contrast_theme.scheme == @core.ColorScheme::Dark)
  assert_true(high_contrast_theme.palette.outline == @core.Color::white())
  inspect(high_contrast_theme.motion.normal_ms, content="0")
  inspect(high_contrast_theme.spacing_scale.sm, content="6.56")
  let system_theme = @common.DesignPreset::Primer.theme_for_variant(
    variant=@common.DesignSchemeVariant::SchemeSystem,
    system_scheme=@core.ColorScheme::Dark,
  )
  assert_true(
    system_theme ==
    @common.DesignPreset::Primer.theme(scheme=@core.ColorScheme::Dark),
  )
  assert_true(system_theme.scheme == @core.ColorScheme::Dark)
}

///|
test "variant resolver reports tie scheme variants to source mapped adapters" {
  for
    preset in [
      @common.DesignPreset::Material,
      @common.DesignPreset::Carbon,
      @common.DesignPreset::Primer,
      @common.DesignPreset::Fluent,
    ] {
    let report = variant_resolver_report(
      preset,
      system_scheme=@core.ColorScheme::Dark,
      density=@common.DesignDensity::Compact,
    )
    assert_true(report.length() == variant_coverage(preset).length())
    assert_true(variant_resolver_count(preset) == report.length())
    assert_true(variant_resolver_source_gap_count(preset) == 0)
    assert_true(variant_resolver_gap_count(preset) == 2)
    assert_true(variant_resolver_official_parity_gap_count(preset) == 4)
    for item in report {
      assert_true(item.source_declared)
      assert_true(item.source_locked)
      assert_true(item.source_ref != "")
      assert_true(item.tokens_api.contains("tokens_for_variant"))
      assert_true(item.theme_api.contains("theme_for_variant"))
      assert_true(item.resolves_tokens)
      assert_true(item.resolves_theme)
      assert_true(item.density == @common.DesignDensity::Compact)
    }
  }
  guard variant_resolver_for(
      @common.DesignPreset::Material,
      @common.DesignSchemeVariant::SchemeHighContrast,
      system_scheme=@core.ColorScheme::Dark,
      density=@common.DesignDensity::Compact,
    )
    is Some(material_high_contrast) else {
    fail("expected Material high-contrast variant resolver")
  }
  assert_true(
    material_high_contrast.variant ==
    @common.DesignSchemeVariant::SchemeHighContrast,
  )
  assert_true(material_high_contrast.resolved_scheme == @core.ColorScheme::Dark)
  assert_true(material_high_contrast.status == DesignTokenStatus::ThemeMapped)
  assert_true(material_high_contrast.official_source.contains("material-web"))
  guard variant_resolver_for(
      @common.DesignPreset::Carbon,
      @common.DesignSchemeVariant::SchemeLight,
    )
    is Some(carbon_light) else {
    fail("expected Carbon light variant resolver")
  }
  assert_true(carbon_light.resolved_scheme == @core.ColorScheme::Light)
  assert_true(carbon_light.status == DesignTokenStatus::PreviewMapped)
  assert_true(carbon_light.remaining_gap.contains("Official scheme variant"))
  guard variant_resolver_for(
      @common.DesignPreset::Fluent,
      @common.DesignSchemeVariant::SchemeSystem,
      system_scheme=@core.ColorScheme::Dark,
    )
    is Some(fluent_system) else {
    fail("expected Fluent system variant resolver")
  }
  assert_true(fluent_system.resolved_scheme == @core.ColorScheme::Dark)
  assert_true(fluent_system.source_label == "Fluent theming")
}

///|
test "custom design system tokens inherit and recompute dependent groups" {
  let base = @common.DesignPreset::Primer.tokens()
  let palette = {
    ..base.palette,
    primary: @core.Color::rgba(r=0.86, g=0.18, b=0.42),
    focus: @core.Color::rgba(r=0.86, g=0.18, b=0.42),
  }
  let spacing = { ..base.spacing, sm: 11.0, md: 17.0 }
  let customized = @common.custom_tokens(base, palette~, spacing~)
  assert_true(customized.palette.primary == palette.primary)
  inspect(customized.spacing.sm, content="11")
  assert_true(
    customized.components.button.primary.background == palette.primary,
  )
  assert_true(customized.components.progress.foreground == palette.primary)
  assert_true(customized.components.slider.thumb_color == palette.primary)
  assert_true(customized.components.picker.foreground == palette.foreground)
  assert_true(
    customized.components.text_field.font == customized.typography.body,
  )
  assert_true(
    customized.components.text_field.core_style().cursor_color == palette.focus,
  )
  assert_true(
    customized.components.text_field.core_style().normal.background ==
    @core.Brush::solid(palette.surface),
  )
  assert_true(
    customized.components.feedback.success.foreground == palette.success,
  )
  assert_true(
    customized.components.form_validation.foreground == palette.danger,
  )
  assert_true(customized.components.surface.base_padding == 17.0)
  assert_true(customized.to_theme().palette.primary == palette.primary)
  assert_true(customized.to_theme().palette.success == palette.success)
}

///|
test "official design presets expose source mapped golden token mappings" {
  for
    preset in [
      @common.DesignPreset::Material,
      @common.DesignPreset::Carbon,
      @common.DesignPreset::Primer,
      @common.DesignPreset::Fluent,
    ] {
    let mappings = golden_mappings(preset)
    assert_true(mappings.length() >= 8)
    assert_true(golden_mapped_count(preset) >= 6)
    assert_true(golden_gap_count(preset) >= 1)
    assert_false(mappings.any(item => item.moui_token.contains("moui/views.")))
    assert_true(
      mappings.any(item => item.category == DesignTokenCategory::Color),
    )
    assert_true(
      mappings.any(item => {
        item.category == DesignTokenCategory::ComponentStyle &&
        item.status == DesignTokenStatus::ComponentMapped
      }),
    )
    assert_true(
      mappings.any(item => {
        item.status == DesignTokenStatus::SourceMapped ||
        item.status == DesignTokenStatus::PreviewMapped ||
        item.status == DesignTokenStatus::NotMapped
      }),
    )
  }
}

///|
test "golden mappings trace back to declared manifest sources" {
  for
    preset in [
      @common.DesignPreset::Material,
      @common.DesignPreset::Carbon,
      @common.DesignPreset::Primer,
      @common.DesignPreset::Fluent,
    ] {
    let usages = source_usage(preset)
    assert_true(usages.length() == sources(preset).length())
    assert_true(undeclared_golden_source_count(preset) == 0)
    assert_true(usages.any(item => item.golden_mapping_count > 0))
    assert_true(unused_official_source_count(preset) > 0)
    assert_true(
      usages.any(item => {
        item.source_kind == "official-source" &&
        item.source_ref != "" &&
        item.token_path != "" &&
        item.source_status == DesignTokenStatus::SourceMapped &&
        item.golden_mapping_count == 0
      }),
    )
  }
}

///|
test "progress and slider golden mappings use component tokens" {
  guard golden_mapping_for(
      @common.DesignPreset::Material,
      "--md-linear-progress-active-indicator-color",
    )
    is Some(material_progress) else {
    fail("expected Material progress token mapping")
  }
  inspect(
    material_progress.moui_token,
    content="DesignComponentTokens.progress.foreground",
  )
  assert_true(material_progress.status == DesignTokenStatus::ComponentMapped)
  guard golden_mapping_for(@common.DesignPreset::Carbon, "$slider-filled-track")
    is Some(carbon_slider) else {
    fail("expected Carbon slider token mapping")
  }
  inspect(
    carbon_slider.moui_token,
    content="DesignComponentTokens.slider.foreground",
  )
  assert_true(carbon_slider.status == DesignTokenStatus::ComponentMapped)
}

///|
test "picker golden mappings use component tokens" {
  guard golden_mapping_for(
      @common.DesignPreset::Material,
      "--md-menu-container-color",
    )
    is Some(material_picker) else {
    fail("expected Material picker token mapping")
  }
  inspect(
    material_picker.moui_token,
    content="DesignComponentTokens.picker.background",
  )
  assert_true(material_picker.status == DesignTokenStatus::ComponentMapped)
  assert_true(has_golden_mapping(@common.DesignPreset::Carbon, "$field"))
  assert_true(
    has_golden_mapping(@common.DesignPreset::Primer, "--control-bgColor-rest"),
  )
}

///|
test "status color golden mappings use semantic palette roles" {
  guard golden_mapping_for(
      @common.DesignPreset::Material,
      "--md-sys-color-error",
    )
    is Some(material_error) else {
    fail("expected Material error token mapping")
  }
  inspect(material_error.moui_token, content="DesignSemanticPalette.danger")
  assert_true(material_error.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(@common.DesignPreset::Carbon, "$support-success")
    is Some(carbon_success) else {
    fail("expected Carbon support-success token mapping")
  }
  inspect(carbon_success.moui_token, content="DesignSemanticPalette.success")
  assert_true(carbon_success.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(@common.DesignPreset::Carbon, "$support-error")
    is Some(carbon_error) else {
    fail("expected Carbon support-error token mapping")
  }
  inspect(carbon_error.moui_token, content="DesignSemanticPalette.danger")
  assert_true(carbon_error.status == DesignTokenStatus::ThemeMapped)
  assert_true(
    has_golden_mapping(@common.DesignPreset::Primer, "--fgColor-danger"),
  )
  guard golden_mapping_for(@common.DesignPreset::Primer, "--fgColor-success")
    is Some(primer_success) else {
    fail("expected Primer success token mapping")
  }
  inspect(primer_success.moui_token, content="DesignSemanticPalette.success")
  assert_true(primer_success.status == DesignTokenStatus::ThemeMapped)
}

///|
test "golden mappings resolve known official token names" {
  guard golden_mapping_for(
      @common.DesignPreset::Material,
      "--md-sys-color-primary",
    )
    is Some(material_primary) else {
    fail("expected Material primary token mapping")
  }
  inspect(material_primary.moui_token, content="DesignSemanticPalette.primary")
  assert_true(material_primary.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(
      @common.DesignPreset::Material,
      "--md-sys-motion-duration-short4",
    )
    is Some(material_motion_short4) else {
    fail("expected Material short4 motion token mapping")
  }
  inspect(
    material_motion_short4.moui_token,
    content="DesignMotionTokens.fast_ms",
  )
  assert_true(material_motion_short4.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(
      @common.DesignPreset::Material,
      "--md-sys-motion-duration-medium2",
    )
    is Some(material_motion_medium2) else {
    fail("expected Material medium2 motion token mapping")
  }
  inspect(
    material_motion_medium2.moui_token,
    content="DesignMotionTokens.normal_ms",
  )
  assert_true(material_motion_medium2.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(
      @common.DesignPreset::Material,
      "--md-sys-motion-duration-medium4",
    )
    is Some(material_motion_medium4) else {
    fail("expected Material medium4 motion token mapping")
  }
  inspect(
    material_motion_medium4.moui_token,
    content="DesignMotionTokens.slow_ms",
  )
  assert_true(material_motion_medium4.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(
      @common.DesignPreset::Material,
      "--md-sys-motion-easing-standard",
    )
    is Some(material_motion_easing) else {
    fail("expected Material standard easing token mapping")
  }
  inspect(
    material_motion_easing.moui_token,
    content="DesignMotionTokens.easing",
  )
  assert_true(material_motion_easing.status == DesignTokenStatus::PreviewMapped)
  assert_true(
    has_golden_mapping(@common.DesignPreset::Carbon, "$button-primary"),
  )
  assert_carbon_mapped_spacing_golden_mapping(
    "$spacing-01", "DesignSpacingTokens.xs",
  )
  assert_carbon_preview_spacing_golden_mapping(
    "$spacing-02", "DesignSpacingTokens.xs",
  )
  assert_carbon_mapped_spacing_golden_mapping(
    "$spacing-03", "DesignSpacingTokens.sm",
  )
  assert_carbon_mapped_spacing_golden_mapping(
    "$spacing-04", "DesignSpacingTokens.md",
  )
  assert_carbon_mapped_spacing_golden_mapping(
    "$spacing-05", "DesignSpacingTokens.lg",
  )
  assert_carbon_mapped_spacing_golden_mapping(
    "$spacing-06", "DesignSpacingTokens.xl",
  )
  assert_carbon_preview_spacing_golden_mapping(
    "$spacing-07", "DesignSpacingTokens.xl",
  )
  assert_carbon_preview_spacing_golden_mapping(
    "$spacing-08", "DesignSpacingTokens.xl",
  )
  assert_carbon_preview_spacing_golden_mapping(
    "$spacing-09", "DesignSpacingTokens.xl",
  )
  assert_carbon_preview_spacing_golden_mapping(
    "$spacing-10", "DesignSpacingTokens.xl",
  )
  assert_carbon_preview_spacing_golden_mapping(
    "$spacing-11", "DesignSpacingTokens.xl",
  )
  assert_carbon_preview_spacing_golden_mapping(
    "$spacing-12", "DesignSpacingTokens.xl",
  )
  assert_carbon_preview_spacing_golden_mapping(
    "$spacing-13", "DesignSpacingTokens.xl",
  )
  guard golden_mapping_for(
      @common.DesignPreset::Carbon,
      "$duration-moderate-01",
    )
    is Some(carbon_duration) else {
    fail("expected Carbon moderate duration token mapping")
  }
  assert_true(carbon_duration.moui_token == "DesignMotionTokens.normal_ms")
  assert_true(carbon_duration.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(
      @common.DesignPreset::Carbon,
      "easings.standard.productive",
    )
    is Some(carbon_easing) else {
    fail("expected Carbon standard productive easing token mapping")
  }
  assert_true(carbon_easing.moui_token == "DesignMotionTokens.easing")
  assert_true(carbon_easing.status == DesignTokenStatus::PreviewMapped)
  guard golden_mapping_for(@common.DesignPreset::Carbon, "$duration-fast-01")
    is Some(carbon_duration_fast01) else {
    fail("expected Carbon fast-01 duration token mapping")
  }
  assert_true(carbon_duration_fast01.moui_token == "DesignMotionTokens.fast_ms")
  assert_true(carbon_duration_fast01.status == DesignTokenStatus::PreviewMapped)
  guard golden_mapping_for(
      @common.DesignPreset::Carbon,
      "easings.exit.expressive",
    )
    is Some(carbon_easing_exit) else {
    fail("expected Carbon expressive exit easing token mapping")
  }
  assert_true(carbon_easing_exit.moui_token == "DesignMotionTokens.easing")
  assert_true(carbon_easing_exit.status == DesignTokenStatus::PreviewMapped)
  assert_true(
    has_golden_mapping(@common.DesignPreset::Primer, "--fgColor-default"),
  )
  guard golden_mapping_for(@common.DesignPreset::Primer, "--base-size-4")
    is Some(primer_base_size_xs) else {
    fail("expected Primer base size 4 token mapping")
  }
  assert_true(primer_base_size_xs.moui_token == "DesignSpacingTokens.xs")
  assert_true(primer_base_size_xs.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(@common.DesignPreset::Primer, "--base-size-8")
    is Some(primer_base_size_sm) else {
    fail("expected Primer base size 8 token mapping")
  }
  assert_true(primer_base_size_sm.moui_token == "DesignSpacingTokens.sm")
  assert_true(primer_base_size_sm.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(@common.DesignPreset::Primer, "--base-size-12")
    is Some(primer_base_size_md) else {
    fail("expected Primer base size 12 token mapping")
  }
  assert_true(primer_base_size_md.moui_token == "DesignSpacingTokens.md")
  assert_true(primer_base_size_md.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(@common.DesignPreset::Primer, "--base-size-16")
    is Some(primer_base_size) else {
    fail("expected Primer base size token mapping")
  }
  assert_true(primer_base_size.moui_token == "DesignSpacingTokens.lg")
  assert_true(primer_base_size.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(@common.DesignPreset::Primer, "--base-size-24")
    is Some(primer_base_size_xl) else {
    fail("expected Primer base size 24 token mapping")
  }
  assert_true(primer_base_size_xl.moui_token == "DesignSpacingTokens.xl")
  assert_true(primer_base_size_xl.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(@common.DesignPreset::Primer, "--base-text-size-xs")
    is Some(primer_caption_size) else {
    fail("expected Primer caption text size token mapping")
  }
  assert_true(
    primer_caption_size.moui_token == "DesignTypographyTokens.caption.size",
  )
  assert_true(primer_caption_size.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(@common.DesignPreset::Primer, "--base-text-size-sm")
    is Some(primer_body_size) else {
    fail("expected Primer body text size token mapping")
  }
  assert_true(primer_body_size.moui_token == "DesignTypographyTokens.body.size")
  assert_true(primer_body_size.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(@common.DesignPreset::Primer, "--base-text-size-lg")
    is Some(primer_title_size) else {
    fail("expected Primer title text size token mapping")
  }
  assert_true(
    primer_title_size.moui_token == "DesignTypographyTokens.title.size",
  )
  assert_true(primer_title_size.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(
      @common.DesignPreset::Primer,
      "--base-text-weight-normal",
    )
    is Some(primer_body_weight) else {
    fail("expected Primer body text weight token mapping")
  }
  assert_true(
    primer_body_weight.moui_token == "DesignTypographyTokens.body.weight",
  )
  assert_true(primer_body_weight.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(
      @common.DesignPreset::Primer,
      "--base-text-weight-semibold",
    )
    is Some(primer_control_weight) else {
    fail("expected Primer control text weight token mapping")
  }
  assert_true(
    primer_control_weight.moui_token == "DesignTypographyTokens.control.weight",
  )
  assert_true(primer_control_weight.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(@common.DesignPreset::Primer, "--borderRadius-small")
    is Some(primer_radius_small) else {
    fail("expected Primer small radius token mapping")
  }
  assert_true(primer_radius_small.moui_token == "DesignRadiusTokens.sm")
  assert_true(primer_radius_small.status == DesignTokenStatus::PreviewMapped)
  guard golden_mapping_for(
      @common.DesignPreset::Primer,
      "--borderRadius-medium",
    )
    is Some(primer_radius_medium) else {
    fail("expected Primer medium radius token mapping")
  }
  assert_true(primer_radius_medium.moui_token == "DesignRadiusTokens.md")
  assert_true(primer_radius_medium.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(@common.DesignPreset::Primer, "--borderRadius-large")
    is Some(primer_radius_large) else {
    fail("expected Primer large radius token mapping")
  }
  assert_true(primer_radius_large.moui_token == "DesignRadiusTokens.lg")
  assert_true(primer_radius_large.status == DesignTokenStatus::PreviewMapped)
  guard golden_mapping_for(@common.DesignPreset::Primer, "--borderRadius-full")
    is Some(primer_radius_full) else {
    fail("expected Primer full radius token mapping")
  }
  assert_true(primer_radius_full.moui_token == "DesignRadiusTokens.pill")
  assert_true(primer_radius_full.status == DesignTokenStatus::PreviewMapped)
  guard golden_mapping_for(
      @common.DesignPreset::Primer,
      "--borderRadius-default",
    )
    is Some(primer_radius_default) else {
    fail("expected Primer default radius token mapping")
  }
  assert_true(primer_radius_default.moui_token == "DesignRadiusTokens.md")
  assert_true(primer_radius_default.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(
      @common.DesignPreset::Primer,
      "--shadow-resting-small",
    )
    is Some(primer_shadow_small) else {
    fail("expected Primer small resting shadow token mapping")
  }
  assert_true(
    primer_shadow_small.moui_token == "DesignElevationTokens.sm.offset.y",
  )
  assert_true(primer_shadow_small.status == DesignTokenStatus::PreviewMapped)
  guard golden_mapping_for(
      @common.DesignPreset::Primer,
      "--shadow-resting-medium",
    )
    is Some(primer_shadow_medium) else {
    fail("expected Primer medium resting shadow token mapping")
  }
  assert_true(
    primer_shadow_medium.moui_token == "DesignElevationTokens.md.offset.y",
  )
  assert_true(primer_shadow_medium.status == DesignTokenStatus::PreviewMapped)
  guard golden_mapping_for(
      @common.DesignPreset::Primer,
      "--shadow-floating-large",
    )
    is Some(primer_shadow_large) else {
    fail("expected Primer large floating shadow token mapping")
  }
  assert_true(
    primer_shadow_large.moui_token == "DesignElevationTokens.lg.offset.y",
  )
  assert_true(primer_shadow_large.status == DesignTokenStatus::PreviewMapped)
  guard golden_mapping_for(@common.DesignPreset::Primer, "--base-duration-0")
    is Some(primer_duration_zero) else {
    fail("expected Primer 0ms duration token mapping")
  }
  assert_true(primer_duration_zero.moui_token == "DesignMotionTokens.fast_ms")
  assert_true(primer_duration_zero.status == DesignTokenStatus::PreviewMapped)
  guard golden_mapping_for(@common.DesignPreset::Primer, "--base-duration-100")
    is Some(primer_duration_fast) else {
    fail("expected Primer 100ms duration token mapping")
  }
  assert_true(primer_duration_fast.moui_token == "DesignMotionTokens.fast_ms")
  assert_true(primer_duration_fast.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(@common.DesignPreset::Primer, "--base-duration-200")
    is Some(primer_duration_normal) else {
    fail("expected Primer 200ms duration token mapping")
  }
  assert_true(
    primer_duration_normal.moui_token == "DesignMotionTokens.normal_ms",
  )
  assert_true(primer_duration_normal.status == DesignTokenStatus::PreviewMapped)
  guard golden_mapping_for(@common.DesignPreset::Primer, "--base-duration-300")
    is Some(primer_duration_slow) else {
    fail("expected Primer 300ms duration token mapping")
  }
  assert_true(primer_duration_slow.moui_token == "DesignMotionTokens.slow_ms")
  assert_true(primer_duration_slow.status == DesignTokenStatus::PreviewMapped)
  guard golden_mapping_for(@common.DesignPreset::Primer, "--base-duration-1000")
    is Some(primer_duration_long) else {
    fail("expected Primer 1000ms duration token mapping")
  }
  assert_true(primer_duration_long.moui_token == "DesignMotionTokens.slow_ms")
  assert_true(primer_duration_long.status == DesignTokenStatus::PreviewMapped)
  guard golden_mapping_for(@common.DesignPreset::Primer, "--base-easing-linear")
    is Some(primer_linear) else {
    fail("expected Primer linear easing token mapping")
  }
  assert_true(primer_linear.moui_token == "DesignMotionTokens.easing")
  assert_true(primer_linear.status == DesignTokenStatus::PreviewMapped)
  guard golden_mapping_for(
      @common.DesignPreset::Primer,
      "--base-easing-easeOut",
    )
    is Some(primer_easing) else {
    fail("expected Primer easeOut token mapping")
  }
  assert_true(primer_easing.moui_token == "DesignMotionTokens.easing")
  assert_true(primer_easing.status == DesignTokenStatus::PreviewMapped)
  guard golden_mapping_for(
      @common.DesignPreset::Primer,
      "--base-easing-easeInOut",
    )
    is Some(primer_ease_in_out) else {
    fail("expected Primer easeInOut token mapping")
  }
  assert_true(primer_ease_in_out.moui_token == "DesignMotionTokens.easing")
  assert_true(primer_ease_in_out.status == DesignTokenStatus::PreviewMapped)
  assert_true(
    has_golden_mapping(@common.DesignPreset::Fluent, "colorBrandBackground"),
  )
  assert_fluent_preview_global_color_golden_mapping(
    "red.primary", "DesignSemanticPalette.danger",
  )
  assert_fluent_preview_global_color_golden_mapping(
    "green.primary", "DesignSemanticPalette.success",
  )
  assert_fluent_preview_global_color_golden_mapping(
    "lightGreen.primary", "DesignSemanticPalette.success",
  )
  assert_fluent_preview_global_color_golden_mapping(
    "cranberry.primary", "DesignSemanticPalette.danger",
  )
  assert_fluent_preview_global_color_golden_mapping(
    "darkOrange.primary", "DesignSemanticPalette.warning",
  )
  assert_fluent_preview_global_color_golden_mapping(
    "orange.primary", "DesignSemanticPalette.warning",
  )
  assert_fluent_preview_global_color_golden_mapping(
    "yellow.primary", "DesignSemanticPalette.warning",
  )
  assert_fluent_preview_global_color_golden_mapping(
    "marigold.primary", "DesignSemanticPalette.warning",
  )
  assert_fluent_preview_global_color_golden_mapping(
    "blue.primary", "DesignSemanticPalette.info",
  )
  guard golden_mapping_for(@common.DesignPreset::Fluent, "durationUltraFast")
    is Some(fluent_duration_ultra_fast) else {
    fail("expected Fluent ultra-fast duration token mapping")
  }
  assert_true(
    fluent_duration_ultra_fast.moui_token == "DesignMotionTokens.fast_ms",
  )
  assert_true(
    fluent_duration_ultra_fast.status == DesignTokenStatus::PreviewMapped,
  )
  guard golden_mapping_for(@common.DesignPreset::Fluent, "durationFaster")
    is Some(fluent_duration_fast) else {
    fail("expected Fluent faster duration token mapping")
  }
  assert_true(fluent_duration_fast.moui_token == "DesignMotionTokens.fast_ms")
  assert_true(fluent_duration_fast.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(@common.DesignPreset::Fluent, "durationFast")
    is Some(fluent_duration_fast_preview) else {
    fail("expected Fluent fast duration token mapping")
  }
  assert_true(
    fluent_duration_fast_preview.moui_token == "DesignMotionTokens.fast_ms",
  )
  assert_true(
    fluent_duration_fast_preview.status == DesignTokenStatus::PreviewMapped,
  )
  guard golden_mapping_for(@common.DesignPreset::Fluent, "durationNormal")
    is Some(fluent_duration) else {
    fail("expected Fluent duration token mapping")
  }
  assert_true(fluent_duration.moui_token == "DesignMotionTokens.normal_ms")
  assert_true(fluent_duration.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(@common.DesignPreset::Fluent, "durationGentle")
    is Some(fluent_duration_gentle) else {
    fail("expected Fluent gentle duration token mapping")
  }
  assert_true(
    fluent_duration_gentle.moui_token == "DesignMotionTokens.normal_ms",
  )
  assert_true(fluent_duration_gentle.status == DesignTokenStatus::PreviewMapped)
  guard golden_mapping_for(@common.DesignPreset::Fluent, "durationSlow")
    is Some(fluent_duration_slow) else {
    fail("expected Fluent slow duration token mapping")
  }
  assert_true(fluent_duration_slow.moui_token == "DesignMotionTokens.slow_ms")
  assert_true(fluent_duration_slow.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(@common.DesignPreset::Fluent, "durationSlower")
    is Some(fluent_duration_slower) else {
    fail("expected Fluent slower duration token mapping")
  }
  assert_true(fluent_duration_slower.moui_token == "DesignMotionTokens.slow_ms")
  assert_true(fluent_duration_slower.status == DesignTokenStatus::PreviewMapped)
  guard golden_mapping_for(@common.DesignPreset::Fluent, "durationUltraSlow")
    is Some(fluent_duration_ultra_slow) else {
    fail("expected Fluent ultra-slow duration token mapping")
  }
  assert_true(
    fluent_duration_ultra_slow.moui_token == "DesignMotionTokens.slow_ms",
  )
  assert_true(
    fluent_duration_ultra_slow.status == DesignTokenStatus::PreviewMapped,
  )
  guard golden_mapping_for(@common.DesignPreset::Fluent, "spacingHorizontalM")
    is Some(fluent_spacing) else {
    fail("expected Fluent spacing token mapping")
  }
  assert_true(fluent_spacing.moui_token == "DesignSpacingTokens.md")
  assert_true(fluent_spacing.status == DesignTokenStatus::ThemeMapped)
  guard golden_mapping_for(@common.DesignPreset::Fluent, "spacingHorizontalXL")
    is Some(fluent_spacing_xl) else {
    fail("expected Fluent extra-large spacing token mapping")
  }
  assert_true(fluent_spacing_xl.moui_token == "DesignSpacingTokens.lg")
  assert_true(fluent_spacing_xl.status == DesignTokenStatus::ThemeMapped)
  assert_fluent_preview_spacing_golden_mapping(
    "spacingHorizontalNone", "DesignSpacingTokens.xs",
  )
  assert_fluent_preview_spacing_golden_mapping(
    "spacingHorizontalXXS", "DesignSpacingTokens.xs",
  )
  assert_fluent_preview_spacing_golden_mapping(
    "spacingHorizontalSNudge", "DesignSpacingTokens.sm",
  )
  assert_fluent_preview_spacing_golden_mapping(
    "spacingHorizontalMNudge", "DesignSpacingTokens.md",
  )
  assert_fluent_preview_spacing_golden_mapping(
    "spacingHorizontalL", "DesignSpacingTokens.lg",
  )
  assert_fluent_preview_spacing_golden_mapping(
    "spacingHorizontalXXL", "DesignSpacingTokens.xl",
  )
  assert_fluent_mapped_spacing_golden_mapping(
    "spacingHorizontalXXXL", "DesignSpacingTokens.xl",
  )
  assert_fluent_preview_spacing_golden_mapping(
    "spacingVerticalNone", "DesignSpacingTokens.xs",
  )
  assert_fluent_preview_spacing_golden_mapping(
    "spacingVerticalXXS", "DesignSpacingTokens.xs",
  )
  assert_fluent_mapped_spacing_golden_mapping(
    "spacingVerticalXS", "DesignSpacingTokens.xs",
  )
  assert_fluent_preview_spacing_golden_mapping(
    "spacingVerticalSNudge", "DesignSpacingTokens.sm",
  )
  assert_fluent_mapped_spacing_golden_mapping(
    "spacingVerticalS", "DesignSpacingTokens.sm",
  )
  assert_fluent_preview_spacing_golden_mapping(
    "spacingVerticalMNudge", "DesignSpacingTokens.md",
  )
  assert_fluent_mapped_spacing_golden_mapping(
    "spacingVerticalM", "DesignSpacingTokens.md",
  )
  assert_fluent_preview_spacing_golden_mapping(
    "spacingVerticalL", "DesignSpacingTokens.lg",
  )
  assert_fluent_mapped_spacing_golden_mapping(
    "spacingVerticalXL", "DesignSpacingTokens.lg",
  )
  assert_fluent_preview_spacing_golden_mapping(
    "spacingVerticalXXL", "DesignSpacingTokens.xl",
  )
  assert_fluent_mapped_spacing_golden_mapping(
    "spacingVerticalXXXL", "DesignSpacingTokens.xl",
  )
  guard golden_mapping_for(@common.DesignPreset::Fluent, "fontWeightSemibold")
    is Some(fluent_semibold) else {
    fail("expected Fluent semibold token mapping")
  }
  assert_true(
    fluent_semibold.moui_token == "DesignTypographyTokens.control.weight",
  )
  assert_true(fluent_semibold.status == DesignTokenStatus::ThemeMapped)
  assert_fluent_preview_typography_golden_mapping(
    "fontSizeBase100", "DesignTypographyTokens.caption.size",
  )
  assert_fluent_mapped_typography_golden_mapping(
    "fontSizeBase200", "DesignTypographyTokens.caption.size",
  )
  assert_fluent_preview_typography_golden_mapping(
    "fontSizeBase400", "DesignTypographyTokens.control.size",
  )
  assert_fluent_preview_typography_golden_mapping(
    "fontSizeBase600", "DesignTypographyTokens.title.size",
  )
  assert_fluent_preview_typography_golden_mapping(
    "fontSizeHero700", "DesignTypographyTokens.title.size",
  )
  assert_fluent_preview_typography_golden_mapping(
    "fontSizeHero800", "DesignTypographyTokens.title.size",
  )
  assert_fluent_preview_typography_golden_mapping(
    "fontSizeHero900", "DesignTypographyTokens.title.size",
  )
  assert_fluent_preview_typography_golden_mapping(
    "fontSizeHero1000", "DesignTypographyTokens.title.size",
  )
  assert_fluent_preview_typography_golden_mapping(
    "lineHeightBase100", "DesignTypographyTokens.caption.line_height",
  )
  assert_fluent_preview_typography_golden_mapping(
    "lineHeightBase200", "DesignTypographyTokens.caption.line_height",
  )
  assert_fluent_preview_typography_golden_mapping(
    "lineHeightBase300", "DesignTypographyTokens.body.line_height",
  )
  assert_fluent_preview_typography_golden_mapping(
    "lineHeightBase400", "DesignTypographyTokens.control.line_height",
  )
  assert_fluent_preview_typography_golden_mapping(
    "lineHeightBase500", "DesignTypographyTokens.title.line_height",
  )
  assert_fluent_preview_typography_golden_mapping(
    "lineHeightBase600", "DesignTypographyTokens.title.line_height",
  )
  assert_fluent_preview_typography_golden_mapping(
    "lineHeightHero700", "DesignTypographyTokens.title.line_height",
  )
  assert_fluent_preview_typography_golden_mapping(
    "lineHeightHero800", "DesignTypographyTokens.title.line_height",
  )
  assert_fluent_preview_typography_golden_mapping(
    "lineHeightHero900", "DesignTypographyTokens.title.line_height",
  )
  assert_fluent_preview_typography_golden_mapping(
    "lineHeightHero1000", "DesignTypographyTokens.title.line_height",
  )
  assert_fluent_preview_typography_golden_mapping(
    "fontWeightMedium", "DesignTypographyTokens.control.weight",
  )
  assert_fluent_mapped_typography_golden_mapping(
    "fontWeightBold", "DesignTypographyTokens.title.weight",
  )
  assert_fluent_preview_typography_golden_mapping(
    "fontFamilyBase", "DesignTypographyTokens.body.families",
  )
  assert_fluent_preview_typography_golden_mapping(
    "fontFamilyMonospace", "DesignTypographyTokens.control.families",
  )
  assert_fluent_preview_typography_golden_mapping(
    "fontFamilyNumeric", "DesignTypographyTokens.body.families",
  )
  assert_fluent_mapped_stroke_width_golden_mapping(
    "strokeWidthThin", "DesignComponentTokens.text_field.normal.border_width",
  )
  assert_fluent_mapped_stroke_width_golden_mapping(
    "strokeWidthThick", "DesignComponentTokens.text_field.focused.border_width",
  )
  assert_fluent_preview_stroke_width_golden_mapping(
    "strokeWidthThicker", "DesignComponentTokens.text_field.focused.border_width",
  )
  assert_fluent_preview_stroke_width_golden_mapping(
    "strokeWidthThickest", "DesignComponentTokens.text_field.focused.border_width",
  )
  guard golden_mapping_for(@common.DesignPreset::Fluent, "borderRadiusCircular")
    is Some(fluent_radius_circular) else {
    fail("expected Fluent circular radius token mapping")
  }
  assert_true(fluent_radius_circular.moui_token == "DesignRadiusTokens.pill")
  assert_true(fluent_radius_circular.status == DesignTokenStatus::PreviewMapped)
  assert_fluent_preview_radius_golden_mapping(
    "borderRadiusNone", "DesignRadiusTokens.sm",
  )
  assert_fluent_preview_radius_golden_mapping(
    "borderRadiusLarge", "DesignRadiusTokens.lg",
  )
  assert_fluent_preview_radius_golden_mapping(
    "borderRadius2XLarge", "DesignRadiusTokens.lg",
  )
  assert_fluent_preview_radius_golden_mapping(
    "borderRadius3XLarge", "DesignRadiusTokens.lg",
  )
  assert_fluent_preview_radius_golden_mapping(
    "borderRadius4XLarge", "DesignRadiusTokens.pill",
  )
  assert_fluent_preview_radius_golden_mapping(
    "borderRadius5XLarge", "DesignRadiusTokens.pill",
  )
  assert_fluent_preview_radius_golden_mapping(
    "borderRadius6XLarge", "DesignRadiusTokens.pill",
  )
  assert_fluent_preview_curve_golden_mapping("curveAccelerateMax")
  assert_fluent_preview_curve_golden_mapping("curveAccelerateMid")
  assert_fluent_preview_curve_golden_mapping("curveAccelerateMin")
  assert_fluent_preview_curve_golden_mapping("curveDecelerateMax")
  assert_fluent_preview_curve_golden_mapping("curveDecelerateMid")
  assert_fluent_preview_curve_golden_mapping("curveDecelerateMin")
  assert_fluent_preview_curve_golden_mapping("curveEasyEaseMax")
  guard golden_mapping_for(@common.DesignPreset::Fluent, "curveEasyEase")
    is Some(fluent_curve) else {
    fail("expected Fluent curve token mapping")
  }
  assert_true(fluent_curve.moui_token == "DesignMotionTokens.easing")
  assert_true(fluent_curve.status == DesignTokenStatus::PreviewMapped)
  assert_fluent_preview_curve_golden_mapping("curveLinear")
}

///|
