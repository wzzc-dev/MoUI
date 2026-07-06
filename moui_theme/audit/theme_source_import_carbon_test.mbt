///|
test "source imported Carbon tokens expose pinned source values" {
  guard source_imported_token_for(@common.DesignPreset::Carbon, "$background")
    is Some(carbon_background) else {
    fail("expected imported Carbon background token")
  }
  assert_true(carbon_background.source_value.contains("background = white"))
  guard source_imported_token_for(@common.DesignPreset::Carbon, "white")
    is Some(carbon_white) else {
    fail("expected imported Carbon white primitive")
  }
  assert_true(carbon_white.source_value.contains("#ffffff"))
  assert_true(
    carbon_white.source_file.contains("packages/colors/src/colors.ts"),
  )
  guard source_imported_token_for(
      @common.DesignPreset::Carbon,
      "$button-primary",
    )
    is Some(carbon_button) else {
    fail("expected imported Carbon button-primary token")
  }
  assert_true(carbon_button.source_value.contains("#0f62fe"))
  assert_true(carbon_button.source_file.contains("component-tokens/button"))
  guard source_import_coverage_for(
      @common.DesignPreset::Carbon,
      "$button-primary",
    )
    is Some(carbon_button_coverage) else {
    fail("expected Carbon button-primary source-import coverage")
  }
  assert_true(carbon_button_coverage.source_imported)
  assert_true(carbon_button_coverage.golden_mapped)
  assert_true(
    carbon_button_coverage.moui_token ==
    "DesignComponentTokens.button.primary.background",
  )
  guard source_import_integrity_for(
      @common.DesignPreset::Carbon,
      "$button-primary",
    )
    is Some(carbon_button_integrity) else {
    fail("expected Carbon button-primary source-import integrity")
  }
  assert_true(carbon_button_integrity.integrity_ok)
  assert_true(carbon_button_integrity.moui_token_matches_golden)
  guard source_imported_token_for(
      @common.DesignPreset::Carbon,
      "$background-hover",
    )
    is Some(carbon_hover) else {
    fail("expected imported Carbon background-hover token")
  }
  assert_true(carbon_hover.source_value.contains("adjustAlpha(gray50, 0.12)"))
  assert_true(carbon_hover.source_value.contains("hover alpha 0.12"))
  guard source_import_integrity_for(
      @common.DesignPreset::Carbon,
      "$background-hover",
    )
    is Some(carbon_hover_integrity) else {
    fail("expected Carbon background-hover source-import integrity")
  }
  assert_true(carbon_hover_integrity.integrity_ok)
  guard source_imported_token_for(
      @common.DesignPreset::Carbon,
      "$border-interactive",
    )
    is Some(carbon_border) else {
    fail("expected imported Carbon border-interactive token")
  }
  assert_true(carbon_border.source_value.contains("borderInteractive = blue60"))
  assert_true(carbon_border.source_value.contains("#0f62fe"))
  guard source_import_integrity_for(
      @common.DesignPreset::Carbon,
      "$border-interactive",
    )
    is Some(carbon_border_integrity) else {
    fail("expected Carbon border-interactive source-import integrity")
  }
  assert_true(carbon_border_integrity.integrity_ok)
  guard source_imported_token_for(@common.DesignPreset::Carbon, "$field")
    is Some(carbon_field) else {
    fail("expected imported Carbon field token")
  }
  assert_true(carbon_field.source_value.contains("field01 = gray10"))
  assert_true(carbon_field.source_value.contains("#f4f4f4"))
  guard source_import_integrity_for(@common.DesignPreset::Carbon, "$field")
    is Some(carbon_field_integrity) else {
    fail("expected Carbon field source-import integrity")
  }
  assert_true(carbon_field_integrity.integrity_ok)
  guard source_imported_token_for(
      @common.DesignPreset::Carbon,
      "$slider-filled-track",
    )
    is Some(carbon_slider) else {
    fail("expected imported Carbon slider filled-track token")
  }
  assert_true(carbon_slider.source_file.contains("components/slider"))
  assert_true(
    carbon_slider.source_sha == "4069d9960891d06181aed8e00b9d76c333323711",
  )
  assert_true(carbon_slider.source_value.contains("slider__filled-track"))
  assert_true(carbon_slider.source_value.contains("$layer-selected-inverse"))
  assert_true(carbon_slider.source_value.contains("#161616"))
  guard source_import_coverage_for(
      @common.DesignPreset::Carbon,
      "$slider-filled-track",
    )
    is Some(carbon_slider_coverage) else {
    fail("expected Carbon slider filled-track source-import coverage")
  }
  assert_true(carbon_slider_coverage.source_imported)
  assert_true(carbon_slider_coverage.golden_mapped)
  assert_true(
    carbon_slider_coverage.moui_token ==
    "DesignComponentTokens.slider.foreground",
  )
  guard source_import_integrity_for(
      @common.DesignPreset::Carbon,
      "$slider-filled-track",
    )
    is Some(carbon_slider_integrity) else {
    fail("expected Carbon slider filled-track source-import integrity")
  }
  assert_true(carbon_slider_integrity.integrity_ok)
  assert_true(carbon_slider_integrity.moui_token_matches_golden)
  assert_carbon_mapped_layout_source_import(
    "$spacing-01", "spacing01", "miniUnits(0.25)", "2px", "DesignSpacingTokens.xs",
  )
  assert_carbon_preview_layout_source_import(
    "$spacing-02", "spacing02", "miniUnits(0.5)", "4px", "DesignSpacingTokens.xs",
  )
  assert_carbon_mapped_layout_source_import(
    "$spacing-03", "spacing03", "miniUnits(1)", "8px", "DesignSpacingTokens.sm",
  )
  assert_carbon_mapped_layout_source_import(
    "$spacing-04", "spacing04", "miniUnits(1.5)", "12px", "DesignSpacingTokens.md",
  )
  assert_carbon_mapped_layout_source_import(
    "$spacing-05", "spacing05", "miniUnits(2)", "16px", "DesignSpacingTokens.lg",
  )
  assert_carbon_mapped_layout_source_import(
    "$spacing-06", "spacing06", "miniUnits(3)", "24px", "DesignSpacingTokens.xl",
  )
  assert_carbon_preview_layout_source_import(
    "$spacing-07", "spacing07", "miniUnits(4)", "32px", "DesignSpacingTokens.xl",
  )
  assert_carbon_preview_layout_source_import(
    "$spacing-08", "spacing08", "miniUnits(5)", "40px", "DesignSpacingTokens.xl",
  )
  assert_carbon_preview_layout_source_import(
    "$spacing-09", "spacing09", "miniUnits(6)", "48px", "DesignSpacingTokens.xl",
  )
  assert_carbon_preview_layout_source_import(
    "$spacing-10", "spacing10", "miniUnits(8)", "64px", "DesignSpacingTokens.xl",
  )
  assert_carbon_preview_layout_source_import(
    "$spacing-11", "spacing11", "miniUnits(10)", "80px", "DesignSpacingTokens.xl",
  )
  assert_carbon_preview_layout_source_import(
    "$spacing-12", "spacing12", "miniUnits(12)", "96px", "DesignSpacingTokens.xl",
  )
  assert_carbon_preview_layout_source_import(
    "$spacing-13", "spacing13", "miniUnits(20)", "160px", "DesignSpacingTokens.xl",
  )
  assert_carbon_mapped_layout_source_import(
    "$layout-01", "layout01", "miniUnits(2)", "16px", "DesignSpacingTokens.lg",
  )
  assert_carbon_mapped_layout_source_import(
    "$layout-02", "layout02", "miniUnits(3)", "24px", "DesignSpacingTokens.xl",
  )
  assert_carbon_preview_layout_source_import(
    "$layout-07", "layout07", "miniUnits(20)", "160px", "DesignSpacingTokens.xl",
  )
  assert_carbon_mapped_layout_source_import(
    "$container-01", "container01", "miniUnits(3)", "24px", "DesignSpacingTokens.xl",
  )
  assert_carbon_preview_layout_source_import(
    "$container-05", "container05", "miniUnits(8)", "64px", "DesignSpacingTokens.xl",
  )
  guard source_imported_token_for(
      @common.DesignPreset::Carbon,
      "durationFast01",
    )
    is Some(carbon_duration_fast01) else {
    fail("expected imported Carbon fast-01 duration token")
  }
  assert_true(carbon_duration_fast01.source_file.contains("packages/motion"))
  assert_true(
    carbon_duration_fast01.source_sha ==
    "9fccea9022fffa680734ab458aff8e394d6094ca",
  )
  assert_true(carbon_duration_fast01.source_value.contains("durationFast01"))
  assert_true(carbon_duration_fast01.source_value.contains("70ms"))
  guard source_import_coverage_for(
      @common.DesignPreset::Carbon,
      "$duration-fast-01",
    )
    is Some(carbon_duration_fast01_coverage) else {
    fail("expected Carbon fast-01 duration source-import coverage")
  }
  assert_true(carbon_duration_fast01_coverage.source_imported)
  assert_true(carbon_duration_fast01_coverage.golden_mapped)
  assert_true(
    carbon_duration_fast01_coverage.moui_token == "DesignMotionTokens.fast_ms",
  )
  assert_true(
    carbon_duration_fast01_coverage.status == DesignTokenStatus::PreviewMapped,
  )
  guard source_imported_token_for(
      @common.DesignPreset::Carbon,
      "durationFast02",
    )
    is Some(carbon_duration_fast) else {
    fail("expected imported Carbon fast duration token")
  }
  assert_true(carbon_duration_fast.source_file.contains("packages/motion"))
  assert_true(
    carbon_duration_fast.source_sha ==
    "9fccea9022fffa680734ab458aff8e394d6094ca",
  )
  assert_true(carbon_duration_fast.source_value.contains("durationFast02"))
  assert_true(carbon_duration_fast.source_value.contains("110ms"))
  guard source_import_coverage_for(
      @common.DesignPreset::Carbon,
      "$duration-fast-02",
    )
    is Some(carbon_duration_fast_coverage) else {
    fail("expected Carbon fast duration source-import coverage")
  }
  assert_true(carbon_duration_fast_coverage.source_imported)
  assert_true(carbon_duration_fast_coverage.golden_mapped)
  assert_true(
    carbon_duration_fast_coverage.moui_token == "DesignMotionTokens.fast_ms",
  )
  guard source_imported_token_for(
      @common.DesignPreset::Carbon,
      "durationModerate01",
    )
    is Some(carbon_duration_normal) else {
    fail("expected imported Carbon moderate-01 duration token")
  }
  assert_true(carbon_duration_normal.source_value.contains("150ms"))
  guard source_import_coverage_for(
      @common.DesignPreset::Carbon,
      "$duration-moderate-01",
    )
    is Some(carbon_duration_normal_coverage) else {
    fail("expected Carbon moderate-01 duration source-import coverage")
  }
  assert_true(carbon_duration_normal_coverage.source_imported)
  assert_true(carbon_duration_normal_coverage.golden_mapped)
  assert_true(
    carbon_duration_normal_coverage.moui_token == "DesignMotionTokens.normal_ms",
  )
  guard source_import_integrity_for(
      @common.DesignPreset::Carbon,
      "$duration-moderate-01",
    )
    is Some(carbon_duration_normal_integrity) else {
    fail("expected Carbon moderate-01 duration source-import integrity")
  }
  assert_true(carbon_duration_normal_integrity.integrity_ok)
  assert_true(carbon_duration_normal_integrity.moui_token_matches_golden)
  guard source_imported_token_for(
      @common.DesignPreset::Carbon,
      "durationModerate02",
    )
    is Some(carbon_duration_slow) else {
    fail("expected imported Carbon moderate-02 duration token")
  }
  assert_true(carbon_duration_slow.source_value.contains("240ms"))
  guard source_import_coverage_for(
      @common.DesignPreset::Carbon,
      "$duration-moderate-02",
    )
    is Some(carbon_duration_slow_coverage) else {
    fail("expected Carbon moderate-02 duration source-import coverage")
  }
  assert_true(carbon_duration_slow_coverage.source_imported)
  assert_true(carbon_duration_slow_coverage.golden_mapped)
  assert_true(
    carbon_duration_slow_coverage.moui_token == "DesignMotionTokens.slow_ms",
  )
  guard source_imported_token_for(
      @common.DesignPreset::Carbon,
      "durationSlow02",
    )
    is Some(carbon_duration_slow02) else {
    fail("expected imported Carbon slow-02 duration token")
  }
  assert_true(carbon_duration_slow02.source_value.contains("durationSlow02"))
  assert_true(carbon_duration_slow02.source_value.contains("700ms"))
  guard source_import_coverage_for(
      @common.DesignPreset::Carbon,
      "$duration-slow-02",
    )
    is Some(carbon_duration_slow02_coverage) else {
    fail("expected Carbon slow-02 duration source-import coverage")
  }
  assert_true(carbon_duration_slow02_coverage.source_imported)
  assert_true(carbon_duration_slow02_coverage.golden_mapped)
  assert_true(
    carbon_duration_slow02_coverage.moui_token == "DesignMotionTokens.slow_ms",
  )
  assert_true(
    carbon_duration_slow02_coverage.status == DesignTokenStatus::PreviewMapped,
  )
  guard source_imported_token_for(
      @common.DesignPreset::Carbon,
      "easings.standard.productive",
    )
    is Some(carbon_easing) else {
    fail("expected imported Carbon standard productive easing token")
  }
  assert_true(
    carbon_easing.source_value.contains("cubic-bezier(0.2, 0, 0.38, 0.9)"),
  )
  guard source_import_coverage_for(
      @common.DesignPreset::Carbon,
      "easings.standard.productive",
    )
    is Some(carbon_easing_coverage) else {
    fail("expected Carbon standard productive easing source-import coverage")
  }
  assert_true(carbon_easing_coverage.source_imported)
  assert_true(carbon_easing_coverage.golden_mapped)
  assert_true(carbon_easing_coverage.moui_token == "DesignMotionTokens.easing")
  assert_true(carbon_easing_coverage.status == DesignTokenStatus::PreviewMapped)
  guard source_import_integrity_for(
      @common.DesignPreset::Carbon,
      "easings.standard.productive",
    )
    is Some(carbon_easing_integrity) else {
    fail("expected Carbon standard productive easing source-import integrity")
  }
  assert_true(carbon_easing_integrity.integrity_ok)
  assert_true(carbon_easing_integrity.moui_token_matches_golden)
  guard source_imported_token_for(
      @common.DesignPreset::Carbon,
      "easings.exit.expressive",
    )
    is Some(carbon_easing_exit) else {
    fail("expected imported Carbon expressive exit easing token")
  }
  assert_true(
    carbon_easing_exit.source_value.contains("cubic-bezier(0.4, 0.14, 1, 1)"),
  )
  guard source_import_coverage_for(
      @common.DesignPreset::Carbon,
      "easings.exit.expressive",
    )
    is Some(carbon_easing_exit_coverage) else {
    fail("expected Carbon expressive exit easing source-import coverage")
  }
  assert_true(carbon_easing_exit_coverage.source_imported)
  assert_true(carbon_easing_exit_coverage.golden_mapped)
  assert_true(
    carbon_easing_exit_coverage.moui_token == "DesignMotionTokens.easing",
  )
  assert_true(
    carbon_easing_exit_coverage.status == DesignTokenStatus::PreviewMapped,
  )
  guard source_import_integrity_for(
      @common.DesignPreset::Carbon,
      "easings.exit.expressive",
    )
    is Some(carbon_easing_exit_integrity) else {
    fail("expected Carbon expressive exit easing source-import integrity")
  }
  assert_true(carbon_easing_exit_integrity.integrity_ok)
  assert_true(carbon_easing_exit_integrity.moui_token_matches_golden)
  guard source_imported_token_for(
      @common.DesignPreset::Carbon,
      "Carbon motion token family",
    )
    is Some(carbon_motion_family) else {
    fail("expected imported Carbon motion token family")
  }
  assert_true(carbon_motion_family.source_file.contains("packages/motion"))
  assert_true(carbon_motion_family.source_value.contains("durationFast01"))
  assert_true(carbon_motion_family.source_value.contains("standard"))
  guard source_import_coverage_for(
      @common.DesignPreset::Carbon,
      "Carbon motion token family",
    )
    is Some(carbon_motion_family_coverage) else {
    fail("expected Carbon motion family source-import coverage")
  }
  assert_true(carbon_motion_family_coverage.source_imported)
  assert_true(carbon_motion_family_coverage.golden_mapped)
  assert_true(carbon_motion_family_coverage.moui_token == "DesignMotionTokens")
  assert_true(
    carbon_motion_family_coverage.status == DesignTokenStatus::PreviewMapped,
  )
  guard source_import_integrity_for(
      @common.DesignPreset::Carbon,
      "Carbon motion token family",
    )
    is Some(carbon_motion_family_integrity) else {
    fail("expected Carbon motion family source-import integrity")
  }
  assert_true(carbon_motion_family_integrity.integrity_ok)
  assert_true(carbon_motion_family_integrity.moui_token_matches_golden)
}
