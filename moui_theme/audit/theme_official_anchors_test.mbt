///|
test "official token anchors expose mapped coverage and required gaps" {
  for
    preset in [
      @common.DesignPreset::Material,
      @common.DesignPreset::Carbon,
      @common.DesignPreset::Primer,
      @common.DesignPreset::Fluent,
    ] {
    assert_true(official_token_anchor_count(preset) >= 8)
    assert_true(mapped_official_token_anchor_count(preset) > 0)
    assert_true(unmapped_official_token_anchor_count(preset) > 0)
    assert_true(unanchored_golden_mapping_count(preset) == 0)
    assert_true(golden_mappings_without_official_anchor(preset).length() == 0)
    if preset == @common.DesignPreset::Material {
      assert_true(
        official_token_anchor_source_lock_count(preset) ==
        official_token_anchor_count(preset) - 1,
      )
    } else {
      assert_true(
        official_token_anchor_source_lock_count(preset) ==
        official_token_anchor_count(preset),
      )
    }
    assert_true(official_token_anchor_source_gap_count(preset) == 0)
    assert_true(undeclared_official_token_anchor_source_count(preset) == 0)
    assert_true(has_official_token_source_locks(preset))
    assert_true(
      official_token_source_usage(preset).length() == sources(preset).length(),
    )
    assert_true(
      official_token_source_usage(preset).any(item => {
        item.anchor_count > 0 && item.source_locked && item.source_ref != ""
      }),
    )
    assert_false(is_design_system_complete(preset))
    assert_true(
      has_official_token_anchor(
        preset,
        official_token_anchors(preset)[0].official_token,
      ),
    )
    for mapping in golden_mappings(preset) {
      assert_true(has_official_token_anchor(preset, mapping.official_token))
    }
  }
  guard official_token_coverage_for(
      @common.DesignPreset::Material,
      "--md-sys-color-primary",
    )
    is Some(material_primary) else {
    fail("expected Material official token coverage")
  }
  assert_true(material_primary.mapped)
  assert_true(material_primary.source_declared)
  assert_true(material_primary.source_locked)
  inspect(material_primary.source_kind, content="official-docs")
  inspect(material_primary.source_ref, content="live")
  inspect(material_primary.moui_token, content="DesignSemanticPalette.primary")
  guard official_token_coverage_for(
      @common.DesignPreset::Material,
      "--md-sys-elevation-level1",
    )
    is Some(material_elevation) else {
    fail("expected Material level1 elevation official token coverage")
  }
  assert_true(material_elevation.mapped)
  assert_true(material_elevation.source_declared)
  assert_true(material_elevation.source_locked)
  assert_true(
    material_elevation.moui_token == "DesignElevationTokens.sm.offset.y",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Material,
      "--md-sys-elevation-level3",
    )
    is Some(material_elevation_level3) else {
    fail("expected Material level3 elevation official token coverage")
  }
  assert_true(material_elevation_level3.mapped)
  assert_true(material_elevation_level3.source_declared)
  assert_true(material_elevation_level3.source_locked)
  assert_true(
    material_elevation_level3.moui_token == "DesignElevationTokens.md.offset.y",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Material,
      "--md-sys-elevation-level5",
    )
    is Some(material_elevation_level5) else {
    fail("expected Material level5 elevation official token coverage")
  }
  assert_true(material_elevation_level5.mapped)
  assert_true(material_elevation_level5.source_declared)
  assert_true(material_elevation_level5.source_locked)
  assert_true(
    material_elevation_level5.moui_token == "DesignElevationTokens.lg.offset.y",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Material,
      "--md-sys-motion-duration-short4",
    )
    is Some(material_motion_short4) else {
    fail("expected Material short4 motion official token coverage")
  }
  assert_true(material_motion_short4.mapped)
  assert_true(material_motion_short4.source_declared)
  assert_true(material_motion_short4.source_locked)
  assert_true(material_motion_short4.moui_token == "DesignMotionTokens.fast_ms")
  guard official_token_coverage_for(
      @common.DesignPreset::Material,
      "--md-sys-motion-duration-medium2",
    )
    is Some(material_motion_medium2) else {
    fail("expected Material medium2 motion official token coverage")
  }
  assert_true(material_motion_medium2.mapped)
  assert_true(material_motion_medium2.source_declared)
  assert_true(material_motion_medium2.source_locked)
  assert_true(
    material_motion_medium2.moui_token == "DesignMotionTokens.normal_ms",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Material,
      "--md-sys-motion-duration-medium4",
    )
    is Some(material_motion_medium4) else {
    fail("expected Material medium4 motion official token coverage")
  }
  assert_true(material_motion_medium4.mapped)
  assert_true(material_motion_medium4.source_declared)
  assert_true(material_motion_medium4.source_locked)
  assert_true(
    material_motion_medium4.moui_token == "DesignMotionTokens.slow_ms",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Material,
      "--md-sys-motion-easing-standard",
    )
    is Some(material_motion_easing) else {
    fail("expected Material standard easing official token coverage")
  }
  assert_true(material_motion_easing.mapped)
  assert_true(material_motion_easing.source_declared)
  assert_true(material_motion_easing.source_locked)
  assert_true(material_motion_easing.status == DesignTokenStatus::PreviewMapped)
  assert_true(material_motion_easing.moui_token == "DesignMotionTokens.easing")
  guard official_token_coverage_for(
      @common.DesignPreset::Material,
      "--md-sys-spacing-*",
    )
    is Some(material_spacing) else {
    fail("expected Material spacing official token gap")
  }
  assert_false(material_spacing.required)
  assert_false(material_spacing.mapped)
  assert_true(material_spacing.status == DesignTokenStatus::NotMapped)
  assert_carbon_mapped_spacing_official_coverage(
    "$spacing-01", "DesignSpacingTokens.xs",
  )
  assert_carbon_preview_spacing_official_coverage(
    "$spacing-02", "DesignSpacingTokens.xs",
  )
  assert_carbon_mapped_spacing_official_coverage(
    "$spacing-03", "DesignSpacingTokens.sm",
  )
  assert_carbon_mapped_spacing_official_coverage(
    "$spacing-04", "DesignSpacingTokens.md",
  )
  assert_carbon_mapped_spacing_official_coverage(
    "$spacing-05", "DesignSpacingTokens.lg",
  )
  assert_carbon_mapped_spacing_official_coverage(
    "$spacing-06", "DesignSpacingTokens.xl",
  )
  assert_carbon_preview_spacing_official_coverage(
    "$spacing-07", "DesignSpacingTokens.xl",
  )
  assert_carbon_preview_spacing_official_coverage(
    "$spacing-08", "DesignSpacingTokens.xl",
  )
  assert_carbon_preview_spacing_official_coverage(
    "$spacing-09", "DesignSpacingTokens.xl",
  )
  assert_carbon_preview_spacing_official_coverage(
    "$spacing-10", "DesignSpacingTokens.xl",
  )
  assert_carbon_preview_spacing_official_coverage(
    "$spacing-11", "DesignSpacingTokens.xl",
  )
  assert_carbon_preview_spacing_official_coverage(
    "$spacing-12", "DesignSpacingTokens.xl",
  )
  assert_carbon_preview_spacing_official_coverage(
    "$spacing-13", "DesignSpacingTokens.xl",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Carbon,
      "$duration-moderate-01",
    )
    is Some(carbon_duration) else {
    fail("expected Carbon moderate duration official token coverage")
  }
  assert_true(carbon_duration.mapped)
  assert_true(carbon_duration.source_declared)
  assert_true(carbon_duration.source_locked)
  assert_true(carbon_duration.source_kind == "official-source")
  assert_true(carbon_duration.token_path == "packages/motion")
  assert_true(carbon_duration.moui_token == "DesignMotionTokens.normal_ms")
  guard official_token_coverage_for(
      @common.DesignPreset::Carbon,
      "easings.standard.productive",
    )
    is Some(carbon_easing) else {
    fail("expected Carbon easing official token coverage")
  }
  assert_true(carbon_easing.mapped)
  assert_true(carbon_easing.source_declared)
  assert_true(carbon_easing.source_locked)
  assert_true(carbon_easing.status == DesignTokenStatus::PreviewMapped)
  assert_true(carbon_easing.moui_token == "DesignMotionTokens.easing")
  guard official_token_coverage_for(
      @common.DesignPreset::Carbon,
      "$duration-slow-02",
    )
    is Some(carbon_duration_slow02) else {
    fail("expected Carbon slow-02 duration official token coverage")
  }
  assert_true(carbon_duration_slow02.mapped)
  assert_true(carbon_duration_slow02.source_declared)
  assert_true(carbon_duration_slow02.source_locked)
  assert_true(carbon_duration_slow02.status == DesignTokenStatus::PreviewMapped)
  assert_true(carbon_duration_slow02.moui_token == "DesignMotionTokens.slow_ms")
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--button-primary-bgColor-rest",
    )
    is Some(primer_button) else {
    fail("expected Primer primary button official token coverage")
  }
  assert_true(primer_button.mapped)
  assert_true(primer_button.source_declared)
  assert_true(primer_button.source_locked)
  assert_true(primer_button.status == DesignTokenStatus::ComponentMapped)
  assert_true(
    primer_button.moui_token ==
    "DesignComponentTokens.button.primary.background",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--control-bgColor-rest",
    )
    is Some(primer_control) else {
    fail("expected Primer control rest background official token coverage")
  }
  assert_true(primer_control.mapped)
  assert_true(primer_control.source_declared)
  assert_true(primer_control.source_locked)
  assert_true(primer_control.status == DesignTokenStatus::ComponentMapped)
  assert_true(
    primer_control.moui_token == "DesignComponentTokens.picker.background",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--control-transparent-bgColor-hover",
    )
    is Some(primer_control_hover) else {
    fail("expected Primer transparent hover official token coverage")
  }
  assert_true(primer_control_hover.mapped)
  assert_true(primer_control_hover.source_declared)
  assert_true(primer_control_hover.source_locked)
  assert_true(primer_control_hover.status == DesignTokenStatus::ComponentMapped)
  assert_true(
    primer_control_hover.moui_token == "DesignStateLayerTokens.hover_alpha",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--control-borderColor-emphasis",
    )
    is Some(primer_control_border) else {
    fail("expected Primer control emphasized border official token coverage")
  }
  assert_true(primer_control_border.mapped)
  assert_true(primer_control_border.source_declared)
  assert_true(primer_control_border.source_locked)
  assert_true(
    primer_control_border.status == DesignTokenStatus::ComponentMapped,
  )
  assert_true(
    primer_control_border.moui_token == "DesignTextFieldTokens.focused.border",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--base-size-4",
    )
    is Some(primer_base_size_xs) else {
    fail("expected Primer base size 4 official token coverage")
  }
  assert_true(primer_base_size_xs.mapped)
  assert_true(primer_base_size_xs.source_declared)
  assert_true(primer_base_size_xs.source_locked)
  assert_true(primer_base_size_xs.status == DesignTokenStatus::ThemeMapped)
  assert_true(primer_base_size_xs.moui_token == "DesignSpacingTokens.xs")
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--base-size-8",
    )
    is Some(primer_base_size_sm) else {
    fail("expected Primer base size 8 official token coverage")
  }
  assert_true(primer_base_size_sm.mapped)
  assert_true(primer_base_size_sm.source_declared)
  assert_true(primer_base_size_sm.source_locked)
  assert_true(primer_base_size_sm.status == DesignTokenStatus::ThemeMapped)
  assert_true(primer_base_size_sm.moui_token == "DesignSpacingTokens.sm")
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--base-size-12",
    )
    is Some(primer_base_size_md) else {
    fail("expected Primer base size 12 official token coverage")
  }
  assert_true(primer_base_size_md.mapped)
  assert_true(primer_base_size_md.source_declared)
  assert_true(primer_base_size_md.source_locked)
  assert_true(primer_base_size_md.status == DesignTokenStatus::ThemeMapped)
  assert_true(primer_base_size_md.moui_token == "DesignSpacingTokens.md")
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--base-size-16",
    )
    is Some(primer_base_size) else {
    fail("expected Primer base size official token coverage")
  }
  assert_true(primer_base_size.mapped)
  assert_true(primer_base_size.source_declared)
  assert_true(primer_base_size.source_locked)
  assert_true(primer_base_size.status == DesignTokenStatus::ThemeMapped)
  assert_true(primer_base_size.moui_token == "DesignSpacingTokens.lg")
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--base-size-24",
    )
    is Some(primer_base_size_xl) else {
    fail("expected Primer base size 24 official token coverage")
  }
  assert_true(primer_base_size_xl.mapped)
  assert_true(primer_base_size_xl.source_declared)
  assert_true(primer_base_size_xl.source_locked)
  assert_true(primer_base_size_xl.status == DesignTokenStatus::ThemeMapped)
  assert_true(primer_base_size_xl.moui_token == "DesignSpacingTokens.xl")
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--base-text-size-xs",
    )
    is Some(primer_caption_size) else {
    fail("expected Primer caption text size official token coverage")
  }
  assert_true(primer_caption_size.mapped)
  assert_true(primer_caption_size.source_declared)
  assert_true(primer_caption_size.source_locked)
  assert_true(primer_caption_size.status == DesignTokenStatus::ThemeMapped)
  assert_true(
    primer_caption_size.moui_token == "DesignTypographyTokens.caption.size",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--base-text-size-sm",
    )
    is Some(primer_body_size) else {
    fail("expected Primer body text size official token coverage")
  }
  assert_true(primer_body_size.mapped)
  assert_true(primer_body_size.source_declared)
  assert_true(primer_body_size.source_locked)
  assert_true(primer_body_size.status == DesignTokenStatus::ThemeMapped)
  assert_true(primer_body_size.moui_token == "DesignTypographyTokens.body.size")
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--base-text-size-lg",
    )
    is Some(primer_title_size) else {
    fail("expected Primer title text size official token coverage")
  }
  assert_true(primer_title_size.mapped)
  assert_true(primer_title_size.source_declared)
  assert_true(primer_title_size.source_locked)
  assert_true(primer_title_size.status == DesignTokenStatus::ThemeMapped)
  assert_true(
    primer_title_size.moui_token == "DesignTypographyTokens.title.size",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--base-text-weight-normal",
    )
    is Some(primer_body_weight) else {
    fail("expected Primer body text weight official token coverage")
  }
  assert_true(primer_body_weight.mapped)
  assert_true(primer_body_weight.source_declared)
  assert_true(primer_body_weight.source_locked)
  assert_true(primer_body_weight.status == DesignTokenStatus::ThemeMapped)
  assert_true(
    primer_body_weight.moui_token == "DesignTypographyTokens.body.weight",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--base-text-weight-semibold",
    )
    is Some(primer_control_weight) else {
    fail("expected Primer control text weight official token coverage")
  }
  assert_true(primer_control_weight.mapped)
  assert_true(primer_control_weight.source_declared)
  assert_true(primer_control_weight.source_locked)
  assert_true(primer_control_weight.status == DesignTokenStatus::ThemeMapped)
  assert_true(
    primer_control_weight.moui_token == "DesignTypographyTokens.control.weight",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--borderRadius-small",
    )
    is Some(primer_radius_small) else {
    fail("expected Primer small radius official token coverage")
  }
  assert_true(primer_radius_small.mapped)
  assert_true(primer_radius_small.source_declared)
  assert_true(primer_radius_small.source_locked)
  assert_true(primer_radius_small.status == DesignTokenStatus::PreviewMapped)
  assert_true(primer_radius_small.moui_token == "DesignRadiusTokens.sm")
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--borderRadius-medium",
    )
    is Some(primer_radius_medium) else {
    fail("expected Primer medium radius official token coverage")
  }
  assert_true(primer_radius_medium.mapped)
  assert_true(primer_radius_medium.source_declared)
  assert_true(primer_radius_medium.source_locked)
  assert_true(primer_radius_medium.status == DesignTokenStatus::ThemeMapped)
  assert_true(primer_radius_medium.moui_token == "DesignRadiusTokens.md")
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--borderRadius-large",
    )
    is Some(primer_radius_large) else {
    fail("expected Primer large radius official token coverage")
  }
  assert_true(primer_radius_large.mapped)
  assert_true(primer_radius_large.source_declared)
  assert_true(primer_radius_large.source_locked)
  assert_true(primer_radius_large.status == DesignTokenStatus::PreviewMapped)
  assert_true(primer_radius_large.moui_token == "DesignRadiusTokens.lg")
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--borderRadius-full",
    )
    is Some(primer_radius_full) else {
    fail("expected Primer full radius official token coverage")
  }
  assert_true(primer_radius_full.mapped)
  assert_true(primer_radius_full.source_declared)
  assert_true(primer_radius_full.source_locked)
  assert_true(primer_radius_full.status == DesignTokenStatus::PreviewMapped)
  assert_true(primer_radius_full.moui_token == "DesignRadiusTokens.pill")
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--borderRadius-default",
    )
    is Some(primer_radius_default) else {
    fail("expected Primer default radius official token coverage")
  }
  assert_true(primer_radius_default.mapped)
  assert_true(primer_radius_default.source_declared)
  assert_true(primer_radius_default.source_locked)
  assert_true(primer_radius_default.status == DesignTokenStatus::ThemeMapped)
  assert_true(primer_radius_default.moui_token == "DesignRadiusTokens.md")
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--shadow-resting-small",
    )
    is Some(primer_shadow_small) else {
    fail("expected Primer small resting shadow official token coverage")
  }
  assert_true(primer_shadow_small.mapped)
  assert_true(primer_shadow_small.source_declared)
  assert_true(primer_shadow_small.source_locked)
  assert_true(primer_shadow_small.status == DesignTokenStatus::PreviewMapped)
  assert_true(
    primer_shadow_small.moui_token == "DesignElevationTokens.sm.offset.y",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--shadow-resting-medium",
    )
    is Some(primer_shadow_medium) else {
    fail("expected Primer medium resting shadow official token coverage")
  }
  assert_true(primer_shadow_medium.mapped)
  assert_true(primer_shadow_medium.source_declared)
  assert_true(primer_shadow_medium.source_locked)
  assert_true(primer_shadow_medium.status == DesignTokenStatus::PreviewMapped)
  assert_true(
    primer_shadow_medium.moui_token == "DesignElevationTokens.md.offset.y",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--shadow-floating-large",
    )
    is Some(primer_shadow_large) else {
    fail("expected Primer large floating shadow official token coverage")
  }
  assert_true(primer_shadow_large.mapped)
  assert_true(primer_shadow_large.source_declared)
  assert_true(primer_shadow_large.source_locked)
  assert_true(primer_shadow_large.status == DesignTokenStatus::PreviewMapped)
  assert_true(
    primer_shadow_large.moui_token == "DesignElevationTokens.lg.offset.y",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--base-duration-0",
    )
    is Some(primer_duration_zero) else {
    fail("expected Primer 0ms duration official token coverage")
  }
  assert_true(primer_duration_zero.mapped)
  assert_true(primer_duration_zero.source_declared)
  assert_true(primer_duration_zero.source_locked)
  assert_true(primer_duration_zero.status == DesignTokenStatus::PreviewMapped)
  assert_true(primer_duration_zero.moui_token == "DesignMotionTokens.fast_ms")
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--base-duration-100",
    )
    is Some(primer_duration_fast) else {
    fail("expected Primer 100ms duration official token coverage")
  }
  assert_true(primer_duration_fast.mapped)
  assert_true(primer_duration_fast.source_declared)
  assert_true(primer_duration_fast.source_locked)
  assert_true(primer_duration_fast.status == DesignTokenStatus::ThemeMapped)
  assert_true(primer_duration_fast.moui_token == "DesignMotionTokens.fast_ms")
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--base-duration-200",
    )
    is Some(primer_duration_normal) else {
    fail("expected Primer 200ms duration official token coverage")
  }
  assert_true(primer_duration_normal.mapped)
  assert_true(primer_duration_normal.source_declared)
  assert_true(primer_duration_normal.source_locked)
  assert_true(primer_duration_normal.status == DesignTokenStatus::PreviewMapped)
  assert_true(
    primer_duration_normal.moui_token == "DesignMotionTokens.normal_ms",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--base-duration-300",
    )
    is Some(primer_duration_slow) else {
    fail("expected Primer 300ms duration official token coverage")
  }
  assert_true(primer_duration_slow.mapped)
  assert_true(primer_duration_slow.source_declared)
  assert_true(primer_duration_slow.source_locked)
  assert_true(primer_duration_slow.status == DesignTokenStatus::PreviewMapped)
  assert_true(primer_duration_slow.moui_token == "DesignMotionTokens.slow_ms")
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--base-duration-1000",
    )
    is Some(primer_duration_long) else {
    fail("expected Primer 1000ms duration official token coverage")
  }
  assert_true(primer_duration_long.mapped)
  assert_true(primer_duration_long.source_declared)
  assert_true(primer_duration_long.source_locked)
  assert_true(primer_duration_long.status == DesignTokenStatus::PreviewMapped)
  assert_true(primer_duration_long.moui_token == "DesignMotionTokens.slow_ms")
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--base-easing-linear",
    )
    is Some(primer_linear) else {
    fail("expected Primer linear easing official token coverage")
  }
  assert_true(primer_linear.mapped)
  assert_true(primer_linear.source_declared)
  assert_true(primer_linear.source_locked)
  assert_true(primer_linear.status == DesignTokenStatus::PreviewMapped)
  assert_true(primer_linear.moui_token == "DesignMotionTokens.easing")
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--base-easing-easeOut",
    )
    is Some(primer_easing) else {
    fail("expected Primer easeOut official token coverage")
  }
  assert_true(primer_easing.mapped)
  assert_true(primer_easing.source_declared)
  assert_true(primer_easing.source_locked)
  assert_true(primer_easing.status == DesignTokenStatus::PreviewMapped)
  assert_true(primer_easing.moui_token == "DesignMotionTokens.easing")
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--base-easing-easeInOut",
    )
    is Some(primer_ease_in_out) else {
    fail("expected Primer easeInOut official token coverage")
  }
  assert_true(primer_ease_in_out.mapped)
  assert_true(primer_ease_in_out.source_declared)
  assert_true(primer_ease_in_out.source_locked)
  assert_true(primer_ease_in_out.status == DesignTokenStatus::PreviewMapped)
  assert_true(primer_ease_in_out.moui_token == "DesignMotionTokens.easing")
  guard official_token_coverage_for(
      @common.DesignPreset::Primer,
      "--progressBar-fgColor-accent",
    )
    is Some(primer_progress) else {
    fail("expected Primer progress official token coverage")
  }
  assert_true(primer_progress.mapped)
  assert_true(primer_progress.source_declared)
  assert_true(primer_progress.source_locked)
  assert_true(primer_progress.status == DesignTokenStatus::ComponentMapped)
  assert_true(
    primer_progress.moui_token == "DesignComponentTokens.progress.foreground",
  )
  assert_fluent_preview_global_color_official_coverage(
    "red.primary", "DesignSemanticPalette.danger",
  )
  assert_fluent_preview_global_color_official_coverage(
    "green.primary", "DesignSemanticPalette.success",
  )
  assert_fluent_preview_global_color_official_coverage(
    "lightGreen.primary", "DesignSemanticPalette.success",
  )
  assert_fluent_preview_global_color_official_coverage(
    "cranberry.primary", "DesignSemanticPalette.danger",
  )
  assert_fluent_preview_global_color_official_coverage(
    "darkOrange.primary", "DesignSemanticPalette.warning",
  )
  assert_fluent_preview_global_color_official_coverage(
    "orange.primary", "DesignSemanticPalette.warning",
  )
  assert_fluent_preview_global_color_official_coverage(
    "yellow.primary", "DesignSemanticPalette.warning",
  )
  assert_fluent_preview_global_color_official_coverage(
    "marigold.primary", "DesignSemanticPalette.warning",
  )
  assert_fluent_preview_global_color_official_coverage(
    "blue.primary", "DesignSemanticPalette.info",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Fluent,
      "spacingHorizontalM",
    )
    is Some(fluent_spacing) else {
    fail("expected Fluent spacing official token coverage")
  }
  assert_true(fluent_spacing.mapped)
  assert_true(fluent_spacing.source_declared)
  assert_true(fluent_spacing.source_locked)
  assert_true(fluent_spacing.moui_token == "DesignSpacingTokens.md")
  guard official_token_coverage_for(
      @common.DesignPreset::Fluent,
      "spacingHorizontalXL",
    )
    is Some(fluent_spacing_xl) else {
    fail("expected Fluent extra-large spacing official token coverage")
  }
  assert_true(fluent_spacing_xl.mapped)
  assert_true(fluent_spacing_xl.source_declared)
  assert_true(fluent_spacing_xl.source_locked)
  assert_true(fluent_spacing_xl.moui_token == "DesignSpacingTokens.lg")
  assert_fluent_preview_spacing_official_coverage(
    "spacingHorizontalNone", "DesignSpacingTokens.xs",
  )
  assert_fluent_preview_spacing_official_coverage(
    "spacingHorizontalXXS", "DesignSpacingTokens.xs",
  )
  assert_fluent_preview_spacing_official_coverage(
    "spacingHorizontalSNudge", "DesignSpacingTokens.sm",
  )
  assert_fluent_preview_spacing_official_coverage(
    "spacingHorizontalMNudge", "DesignSpacingTokens.md",
  )
  assert_fluent_preview_spacing_official_coverage(
    "spacingHorizontalL", "DesignSpacingTokens.lg",
  )
  assert_fluent_preview_spacing_official_coverage(
    "spacingHorizontalXXL", "DesignSpacingTokens.xl",
  )
  assert_fluent_mapped_spacing_official_coverage(
    "spacingHorizontalXXXL", "DesignSpacingTokens.xl",
  )
  assert_fluent_preview_spacing_official_coverage(
    "spacingVerticalNone", "DesignSpacingTokens.xs",
  )
  assert_fluent_preview_spacing_official_coverage(
    "spacingVerticalXXS", "DesignSpacingTokens.xs",
  )
  assert_fluent_mapped_spacing_official_coverage(
    "spacingVerticalXS", "DesignSpacingTokens.xs",
  )
  assert_fluent_preview_spacing_official_coverage(
    "spacingVerticalSNudge", "DesignSpacingTokens.sm",
  )
  assert_fluent_mapped_spacing_official_coverage(
    "spacingVerticalS", "DesignSpacingTokens.sm",
  )
  assert_fluent_preview_spacing_official_coverage(
    "spacingVerticalMNudge", "DesignSpacingTokens.md",
  )
  assert_fluent_mapped_spacing_official_coverage(
    "spacingVerticalM", "DesignSpacingTokens.md",
  )
  assert_fluent_preview_spacing_official_coverage(
    "spacingVerticalL", "DesignSpacingTokens.lg",
  )
  assert_fluent_mapped_spacing_official_coverage(
    "spacingVerticalXL", "DesignSpacingTokens.lg",
  )
  assert_fluent_preview_spacing_official_coverage(
    "spacingVerticalXXL", "DesignSpacingTokens.xl",
  )
  assert_fluent_mapped_spacing_official_coverage(
    "spacingVerticalXXXL", "DesignSpacingTokens.xl",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Fluent,
      "fontWeightSemibold",
    )
    is Some(fluent_semibold) else {
    fail("expected Fluent semibold official token coverage")
  }
  assert_true(fluent_semibold.mapped)
  assert_true(fluent_semibold.source_declared)
  assert_true(fluent_semibold.source_locked)
  assert_true(
    fluent_semibold.moui_token == "DesignTypographyTokens.control.weight",
  )
  assert_fluent_preview_typography_official_coverage(
    "fontSizeBase100", "DesignTypographyTokens.caption.size",
  )
  assert_fluent_mapped_typography_official_coverage(
    "fontSizeBase200", "DesignTypographyTokens.caption.size",
  )
  assert_fluent_preview_typography_official_coverage(
    "fontSizeBase400", "DesignTypographyTokens.control.size",
  )
  assert_fluent_preview_typography_official_coverage(
    "fontSizeBase600", "DesignTypographyTokens.title.size",
  )
  assert_fluent_preview_typography_official_coverage(
    "fontSizeHero700", "DesignTypographyTokens.title.size",
  )
  assert_fluent_preview_typography_official_coverage(
    "fontSizeHero800", "DesignTypographyTokens.title.size",
  )
  assert_fluent_preview_typography_official_coverage(
    "fontSizeHero900", "DesignTypographyTokens.title.size",
  )
  assert_fluent_preview_typography_official_coverage(
    "fontSizeHero1000", "DesignTypographyTokens.title.size",
  )
  assert_fluent_preview_typography_official_coverage(
    "lineHeightBase100", "DesignTypographyTokens.caption.line_height",
  )
  assert_fluent_preview_typography_official_coverage(
    "lineHeightBase200", "DesignTypographyTokens.caption.line_height",
  )
  assert_fluent_preview_typography_official_coverage(
    "lineHeightBase300", "DesignTypographyTokens.body.line_height",
  )
  assert_fluent_preview_typography_official_coverage(
    "lineHeightBase400", "DesignTypographyTokens.control.line_height",
  )
  assert_fluent_preview_typography_official_coverage(
    "lineHeightBase500", "DesignTypographyTokens.title.line_height",
  )
  assert_fluent_preview_typography_official_coverage(
    "lineHeightBase600", "DesignTypographyTokens.title.line_height",
  )
  assert_fluent_preview_typography_official_coverage(
    "lineHeightHero700", "DesignTypographyTokens.title.line_height",
  )
  assert_fluent_preview_typography_official_coverage(
    "lineHeightHero800", "DesignTypographyTokens.title.line_height",
  )
  assert_fluent_preview_typography_official_coverage(
    "lineHeightHero900", "DesignTypographyTokens.title.line_height",
  )
  assert_fluent_preview_typography_official_coverage(
    "lineHeightHero1000", "DesignTypographyTokens.title.line_height",
  )
  assert_fluent_preview_typography_official_coverage(
    "fontWeightMedium", "DesignTypographyTokens.control.weight",
  )
  assert_fluent_mapped_typography_official_coverage(
    "fontWeightBold", "DesignTypographyTokens.title.weight",
  )
  assert_fluent_preview_typography_official_coverage(
    "fontFamilyBase", "DesignTypographyTokens.body.families",
  )
  assert_fluent_preview_typography_official_coverage(
    "fontFamilyMonospace", "DesignTypographyTokens.control.families",
  )
  assert_fluent_preview_typography_official_coverage(
    "fontFamilyNumeric", "DesignTypographyTokens.body.families",
  )
  assert_fluent_mapped_stroke_width_official_coverage(
    "strokeWidthThin", "DesignComponentTokens.text_field.normal.border_width",
  )
  assert_fluent_mapped_stroke_width_official_coverage(
    "strokeWidthThick", "DesignComponentTokens.text_field.focused.border_width",
  )
  assert_fluent_preview_stroke_width_official_coverage(
    "strokeWidthThicker", "DesignComponentTokens.text_field.focused.border_width",
  )
  assert_fluent_preview_stroke_width_official_coverage(
    "strokeWidthThickest", "DesignComponentTokens.text_field.focused.border_width",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Fluent,
      "borderRadiusCircular",
    )
    is Some(fluent_radius_circular) else {
    fail("expected Fluent circular radius official token coverage")
  }
  assert_true(fluent_radius_circular.mapped)
  assert_true(fluent_radius_circular.source_declared)
  assert_true(fluent_radius_circular.source_locked)
  assert_true(fluent_radius_circular.moui_token == "DesignRadiusTokens.pill")
  assert_true(fluent_radius_circular.status == DesignTokenStatus::PreviewMapped)
  assert_fluent_preview_radius_official_coverage(
    "borderRadiusNone", "DesignRadiusTokens.sm",
  )
  assert_fluent_preview_radius_official_coverage(
    "borderRadiusLarge", "DesignRadiusTokens.lg",
  )
  assert_fluent_preview_radius_official_coverage(
    "borderRadius2XLarge", "DesignRadiusTokens.lg",
  )
  assert_fluent_preview_radius_official_coverage(
    "borderRadius3XLarge", "DesignRadiusTokens.lg",
  )
  assert_fluent_preview_radius_official_coverage(
    "borderRadius4XLarge", "DesignRadiusTokens.pill",
  )
  assert_fluent_preview_radius_official_coverage(
    "borderRadius5XLarge", "DesignRadiusTokens.pill",
  )
  assert_fluent_preview_radius_official_coverage(
    "borderRadius6XLarge", "DesignRadiusTokens.pill",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Fluent,
      "durationUltraFast",
    )
    is Some(fluent_duration_ultra_fast) else {
    fail("expected Fluent ultra-fast duration official token coverage")
  }
  assert_true(fluent_duration_ultra_fast.mapped)
  assert_true(fluent_duration_ultra_fast.source_declared)
  assert_true(fluent_duration_ultra_fast.source_locked)
  assert_true(
    fluent_duration_ultra_fast.status == DesignTokenStatus::PreviewMapped,
  )
  assert_true(
    fluent_duration_ultra_fast.moui_token == "DesignMotionTokens.fast_ms",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Fluent,
      "durationFaster",
    )
    is Some(fluent_duration_fast) else {
    fail("expected Fluent faster duration official token coverage")
  }
  assert_true(fluent_duration_fast.mapped)
  assert_true(fluent_duration_fast.source_declared)
  assert_true(fluent_duration_fast.source_locked)
  assert_true(fluent_duration_fast.status == DesignTokenStatus::ThemeMapped)
  assert_true(fluent_duration_fast.moui_token == "DesignMotionTokens.fast_ms")
  guard official_token_coverage_for(
      @common.DesignPreset::Fluent,
      "durationFast",
    )
    is Some(fluent_duration_fast_preview) else {
    fail("expected Fluent fast duration official token coverage")
  }
  assert_true(fluent_duration_fast_preview.mapped)
  assert_true(fluent_duration_fast_preview.source_declared)
  assert_true(fluent_duration_fast_preview.source_locked)
  assert_true(
    fluent_duration_fast_preview.status == DesignTokenStatus::PreviewMapped,
  )
  assert_true(
    fluent_duration_fast_preview.moui_token == "DesignMotionTokens.fast_ms",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Fluent,
      "durationNormal",
    )
    is Some(fluent_duration) else {
    fail("expected Fluent duration official token coverage")
  }
  assert_true(fluent_duration.mapped)
  assert_true(fluent_duration.source_declared)
  assert_true(fluent_duration.source_locked)
  assert_true(fluent_duration.status == DesignTokenStatus::ThemeMapped)
  assert_true(fluent_duration.moui_token == "DesignMotionTokens.normal_ms")
  guard official_token_coverage_for(
      @common.DesignPreset::Fluent,
      "durationGentle",
    )
    is Some(fluent_duration_gentle) else {
    fail("expected Fluent gentle duration official token coverage")
  }
  assert_true(fluent_duration_gentle.mapped)
  assert_true(fluent_duration_gentle.source_declared)
  assert_true(fluent_duration_gentle.source_locked)
  assert_true(fluent_duration_gentle.status == DesignTokenStatus::PreviewMapped)
  assert_true(
    fluent_duration_gentle.moui_token == "DesignMotionTokens.normal_ms",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Fluent,
      "durationSlow",
    )
    is Some(fluent_duration_slow) else {
    fail("expected Fluent slow duration official token coverage")
  }
  assert_true(fluent_duration_slow.mapped)
  assert_true(fluent_duration_slow.source_declared)
  assert_true(fluent_duration_slow.source_locked)
  assert_true(fluent_duration_slow.status == DesignTokenStatus::ThemeMapped)
  assert_true(fluent_duration_slow.moui_token == "DesignMotionTokens.slow_ms")
  guard official_token_coverage_for(
      @common.DesignPreset::Fluent,
      "durationSlower",
    )
    is Some(fluent_duration_slower) else {
    fail("expected Fluent slower duration official token coverage")
  }
  assert_true(fluent_duration_slower.mapped)
  assert_true(fluent_duration_slower.source_declared)
  assert_true(fluent_duration_slower.source_locked)
  assert_true(fluent_duration_slower.status == DesignTokenStatus::PreviewMapped)
  assert_true(fluent_duration_slower.moui_token == "DesignMotionTokens.slow_ms")
  guard official_token_coverage_for(
      @common.DesignPreset::Fluent,
      "durationUltraSlow",
    )
    is Some(fluent_duration_ultra_slow) else {
    fail("expected Fluent ultra-slow duration official token coverage")
  }
  assert_true(fluent_duration_ultra_slow.mapped)
  assert_true(fluent_duration_ultra_slow.source_declared)
  assert_true(fluent_duration_ultra_slow.source_locked)
  assert_true(
    fluent_duration_ultra_slow.status == DesignTokenStatus::PreviewMapped,
  )
  assert_true(
    fluent_duration_ultra_slow.moui_token == "DesignMotionTokens.slow_ms",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Fluent,
      "colorCompoundBrandBackground",
    )
    is Some(fluent_compound_brand) else {
    fail("expected Fluent compound brand official token coverage")
  }
  assert_true(fluent_compound_brand.mapped)
  assert_true(fluent_compound_brand.source_declared)
  assert_true(fluent_compound_brand.source_locked)
  assert_true(
    fluent_compound_brand.status == DesignTokenStatus::ComponentMapped,
  )
  assert_true(
    fluent_compound_brand.moui_token ==
    "DesignComponentTokens.button.primary.background",
  )
  guard official_token_coverage_for(
      @common.DesignPreset::Fluent,
      "ProgressBar.indicator.backgroundColor",
    )
    is Some(fluent_progress) else {
    fail("expected Fluent progress official token coverage")
  }
  assert_true(fluent_progress.mapped)
  assert_true(fluent_progress.source_declared)
  assert_true(fluent_progress.source_locked)
  assert_true(fluent_progress.status == DesignTokenStatus::ComponentMapped)
  assert_true(
    fluent_progress.moui_token == "DesignComponentTokens.progress.foreground",
  )
  assert_fluent_preview_curve_official_coverage("curveAccelerateMax")
  assert_fluent_preview_curve_official_coverage("curveAccelerateMid")
  assert_fluent_preview_curve_official_coverage("curveAccelerateMin")
  assert_fluent_preview_curve_official_coverage("curveDecelerateMax")
  assert_fluent_preview_curve_official_coverage("curveDecelerateMid")
  assert_fluent_preview_curve_official_coverage("curveDecelerateMin")
  assert_fluent_preview_curve_official_coverage("curveEasyEaseMax")
  guard official_token_coverage_for(
      @common.DesignPreset::Fluent,
      "curveEasyEase",
    )
    is Some(fluent_curve) else {
    fail("expected Fluent curve official token coverage")
  }
  assert_true(fluent_curve.mapped)
  assert_true(fluent_curve.source_declared)
  assert_true(fluent_curve.source_locked)
  assert_true(fluent_curve.status == DesignTokenStatus::PreviewMapped)
  assert_true(fluent_curve.moui_token == "DesignMotionTokens.easing")
  assert_fluent_preview_curve_official_coverage("curveLinear")
}

///|
