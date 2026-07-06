///|
test "source imported Fluent tokens expose pinned source values" {
  guard source_imported_token_for(
      @common.DesignPreset::Fluent,
      "colorBrandBackground",
    )
    is Some(fluent_brand) else {
    fail("expected imported Fluent brand token")
  }
  assert_true(fluent_brand.source_value.contains("#0f6cbd"))
  guard source_import_integrity_for(
      @common.DesignPreset::Fluent,
      "colorBrandBackground",
    )
    is Some(fluent_brand_integrity) else {
    fail("expected Fluent brand integrity record")
  }
  assert_true(fluent_brand_integrity.integrity_ok)
  assert_true(fluent_brand_integrity.source_locked)
  assert_true(fluent_brand_integrity.moui_token_matches_golden)
  assert_fluent_preview_global_color_source_import(
    "red.primary", "#d13438", "DesignSemanticPalette.danger",
  )
  assert_fluent_preview_global_color_source_import(
    "green.primary", "#107c10", "DesignSemanticPalette.success",
  )
  assert_fluent_preview_global_color_source_import(
    "lightGreen.primary", "#13a10e", "DesignSemanticPalette.success",
  )
  assert_fluent_preview_global_color_source_import(
    "cranberry.primary", "#c50f1f", "DesignSemanticPalette.danger",
  )
  assert_fluent_preview_global_color_source_import(
    "darkOrange.primary", "#da3b01", "DesignSemanticPalette.warning",
  )
  assert_fluent_preview_global_color_source_import(
    "orange.primary", "#f7630c", "DesignSemanticPalette.warning",
  )
  assert_fluent_preview_global_color_source_import(
    "yellow.primary", "#fde300", "DesignSemanticPalette.warning",
  )
  assert_fluent_preview_global_color_source_import(
    "marigold.primary", "#eaa300", "DesignSemanticPalette.warning",
  )
  assert_fluent_preview_global_color_source_import(
    "blue.primary", "#0078d4", "DesignSemanticPalette.info",
  )
  guard source_imported_token_for(
      @common.DesignPreset::Fluent,
      "colorCompoundBrandBackground",
    )
    is Some(fluent_compound_brand) else {
    fail("expected imported Fluent compound brand token")
  }
  assert_true(fluent_compound_brand.source_file.contains("lightColor.ts"))
  assert_true(fluent_compound_brand.source_value.contains("#0f6cbd"))
  guard source_import_coverage_for(
      @common.DesignPreset::Fluent,
      "colorCompoundBrandBackground",
    )
    is Some(fluent_compound_brand_coverage) else {
    fail("expected Fluent compound brand source-import coverage")
  }
  assert_true(fluent_compound_brand_coverage.source_imported)
  assert_true(fluent_compound_brand_coverage.golden_mapped)
  assert_true(
    fluent_compound_brand_coverage.moui_token ==
    "DesignComponentTokens.button.primary.background",
  )
  assert_true(
    fluent_compound_brand_coverage.status == DesignTokenStatus::ComponentMapped,
  )
  guard source_import_coverage_for(
      @common.DesignPreset::Fluent,
      "ProgressBar.indicator.backgroundColor",
    )
    is Some(fluent_progress) else {
    fail("expected Fluent progress source-import coverage")
  }
  assert_true(fluent_progress.source_imported)
  assert_true(fluent_progress.golden_mapped)
  assert_true(
    fluent_progress.moui_token == "DesignComponentTokens.progress.foreground",
  )
  assert_true(fluent_progress.status == DesignTokenStatus::ComponentMapped)
  assert_true(fluent_progress.source_file.contains("progress-bar.styles.ts"))
  assert_true(
    fluent_progress.source_value.contains("colorCompoundBrandBackground"),
  )
  guard source_import_integrity_for(
      @common.DesignPreset::Fluent,
      "ProgressBar.indicator.backgroundColor",
    )
    is Some(fluent_progress_integrity) else {
    fail("expected Fluent progress source-import integrity record")
  }
  assert_true(fluent_progress_integrity.integrity_ok)
  assert_true(fluent_progress_integrity.moui_token_matches_golden)
  guard source_import_integrity_for(
      @common.DesignPreset::Fluent,
      "colorCompoundBrandBackground",
    )
    is Some(fluent_compound_brand_integrity) else {
    fail("expected Fluent compound brand integrity record")
  }
  assert_true(fluent_compound_brand_integrity.integrity_ok)
  assert_true(fluent_compound_brand_integrity.moui_token_matches_golden)
  guard source_import_coverage_for(
      @common.DesignPreset::Fluent,
      "spacingHorizontalM",
    )
    is Some(fluent_spacing) else {
    fail("expected Fluent spacing source-import coverage")
  }
  assert_true(fluent_spacing.source_imported)
  assert_true(fluent_spacing.golden_mapped)
  assert_true(fluent_spacing.moui_token == "DesignSpacingTokens.md")
  assert_true(fluent_spacing.status == DesignTokenStatus::ThemeMapped)
  guard source_import_integrity_for(
      @common.DesignPreset::Fluent,
      "spacingHorizontalM",
    )
    is Some(fluent_spacing_integrity) else {
    fail("expected Fluent spacing integrity record")
  }
  assert_true(fluent_spacing_integrity.integrity_ok)
  assert_true(fluent_spacing_integrity.moui_token_matches_golden)
  assert_fluent_preview_spacing_source_import(
    "spacingHorizontalNone", "none = '0'", "DesignSpacingTokens.xs",
  )
  assert_fluent_preview_spacing_source_import(
    "spacingHorizontalXXS", "xxs = '2px'", "DesignSpacingTokens.xs",
  )
  assert_fluent_preview_spacing_source_import(
    "spacingHorizontalSNudge", "sNudge = '6px'", "DesignSpacingTokens.sm",
  )
  assert_fluent_preview_spacing_source_import(
    "spacingHorizontalMNudge", "mNudge = '10px'", "DesignSpacingTokens.md",
  )
  assert_fluent_preview_spacing_source_import(
    "spacingHorizontalL", "l = '16px'", "DesignSpacingTokens.lg",
  )
  assert_fluent_preview_spacing_source_import(
    "spacingHorizontalXXL", "xxl = '24px'", "DesignSpacingTokens.xl",
  )
  assert_fluent_mapped_spacing_source_import(
    "spacingHorizontalXXXL", "xxxl = '32px'", "DesignSpacingTokens.xl",
  )
  assert_fluent_preview_spacing_source_import(
    "spacingVerticalNone", "none = '0'", "DesignSpacingTokens.xs",
  )
  assert_fluent_preview_spacing_source_import(
    "spacingVerticalXXS", "xxs = '2px'", "DesignSpacingTokens.xs",
  )
  assert_fluent_mapped_spacing_source_import(
    "spacingVerticalXS", "xs = '4px'", "DesignSpacingTokens.xs",
  )
  assert_fluent_preview_spacing_source_import(
    "spacingVerticalSNudge", "sNudge = '6px'", "DesignSpacingTokens.sm",
  )
  assert_fluent_mapped_spacing_source_import(
    "spacingVerticalS", "s = '8px'", "DesignSpacingTokens.sm",
  )
  assert_fluent_preview_spacing_source_import(
    "spacingVerticalMNudge", "mNudge = '10px'", "DesignSpacingTokens.md",
  )
  assert_fluent_mapped_spacing_source_import(
    "spacingVerticalM", "m = '12px'", "DesignSpacingTokens.md",
  )
  assert_fluent_preview_spacing_source_import(
    "spacingVerticalL", "l = '16px'", "DesignSpacingTokens.lg",
  )
  assert_fluent_mapped_spacing_source_import(
    "spacingVerticalXL", "xl = '20px'", "DesignSpacingTokens.lg",
  )
  assert_fluent_preview_spacing_source_import(
    "spacingVerticalXXL", "xxl = '24px'", "DesignSpacingTokens.xl",
  )
  assert_fluent_mapped_spacing_source_import(
    "spacingVerticalXXXL", "xxxl = '32px'", "DesignSpacingTokens.xl",
  )
  guard source_import_coverage_for(
      @common.DesignPreset::Fluent,
      "durationUltraFast",
    )
    is Some(fluent_duration_ultra_fast) else {
    fail("expected Fluent ultra-fast duration source-import coverage")
  }
  assert_true(fluent_duration_ultra_fast.source_imported)
  assert_true(fluent_duration_ultra_fast.golden_mapped)
  assert_true(
    fluent_duration_ultra_fast.moui_token == "DesignMotionTokens.fast_ms",
  )
  assert_true(
    fluent_duration_ultra_fast.status == DesignTokenStatus::PreviewMapped,
  )
  guard source_import_coverage_for(
      @common.DesignPreset::Fluent,
      "durationFaster",
    )
    is Some(fluent_duration_fast) else {
    fail("expected Fluent faster duration source-import coverage")
  }
  assert_true(fluent_duration_fast.source_imported)
  assert_true(fluent_duration_fast.golden_mapped)
  assert_true(fluent_duration_fast.moui_token == "DesignMotionTokens.fast_ms")
  assert_true(fluent_duration_fast.status == DesignTokenStatus::ThemeMapped)
  guard source_import_integrity_for(
      @common.DesignPreset::Fluent,
      "durationFaster",
    )
    is Some(fluent_duration_fast_integrity) else {
    fail("expected Fluent faster duration integrity record")
  }
  assert_true(fluent_duration_fast_integrity.integrity_ok)
  assert_true(fluent_duration_fast_integrity.moui_token_matches_golden)
  guard source_import_coverage_for(@common.DesignPreset::Fluent, "durationFast")
    is Some(fluent_duration_fast_preview) else {
    fail("expected Fluent fast duration source-import coverage")
  }
  assert_true(fluent_duration_fast_preview.source_imported)
  assert_true(fluent_duration_fast_preview.golden_mapped)
  assert_true(
    fluent_duration_fast_preview.moui_token == "DesignMotionTokens.fast_ms",
  )
  assert_true(
    fluent_duration_fast_preview.status == DesignTokenStatus::PreviewMapped,
  )
  guard source_import_coverage_for(
      @common.DesignPreset::Fluent,
      "durationNormal",
    )
    is Some(fluent_duration) else {
    fail("expected Fluent duration source-import coverage")
  }
  assert_true(fluent_duration.source_imported)
  assert_true(fluent_duration.golden_mapped)
  assert_true(fluent_duration.moui_token == "DesignMotionTokens.normal_ms")
  assert_true(fluent_duration.status == DesignTokenStatus::ThemeMapped)
  guard source_import_integrity_for(
      @common.DesignPreset::Fluent,
      "durationNormal",
    )
    is Some(fluent_duration_integrity) else {
    fail("expected Fluent duration integrity record")
  }
  assert_true(fluent_duration_integrity.integrity_ok)
  assert_true(fluent_duration_integrity.moui_token_matches_golden)
  guard source_import_coverage_for(
      @common.DesignPreset::Fluent,
      "durationGentle",
    )
    is Some(fluent_duration_gentle) else {
    fail("expected Fluent gentle duration source-import coverage")
  }
  assert_true(fluent_duration_gentle.source_imported)
  assert_true(fluent_duration_gentle.golden_mapped)
  assert_true(
    fluent_duration_gentle.moui_token == "DesignMotionTokens.normal_ms",
  )
  assert_true(fluent_duration_gentle.status == DesignTokenStatus::PreviewMapped)
  guard source_import_coverage_for(@common.DesignPreset::Fluent, "durationSlow")
    is Some(fluent_duration_slow) else {
    fail("expected Fluent slow duration source-import coverage")
  }
  assert_true(fluent_duration_slow.source_imported)
  assert_true(fluent_duration_slow.golden_mapped)
  assert_true(fluent_duration_slow.moui_token == "DesignMotionTokens.slow_ms")
  assert_true(fluent_duration_slow.status == DesignTokenStatus::ThemeMapped)
  guard source_import_coverage_for(
      @common.DesignPreset::Fluent,
      "durationSlower",
    )
    is Some(fluent_duration_slower) else {
    fail("expected Fluent slower duration source-import coverage")
  }
  assert_true(fluent_duration_slower.source_imported)
  assert_true(fluent_duration_slower.golden_mapped)
  assert_true(fluent_duration_slower.moui_token == "DesignMotionTokens.slow_ms")
  assert_true(fluent_duration_slower.status == DesignTokenStatus::PreviewMapped)
  guard source_import_coverage_for(
      @common.DesignPreset::Fluent,
      "durationUltraSlow",
    )
    is Some(fluent_duration_ultra_slow) else {
    fail("expected Fluent ultra-slow duration source-import coverage")
  }
  assert_true(fluent_duration_ultra_slow.source_imported)
  assert_true(fluent_duration_ultra_slow.golden_mapped)
  assert_true(
    fluent_duration_ultra_slow.moui_token == "DesignMotionTokens.slow_ms",
  )
  assert_true(
    fluent_duration_ultra_slow.status == DesignTokenStatus::PreviewMapped,
  )
  assert_fluent_preview_curve_source_import(
    "curveAccelerateMax", "cubic-bezier(0.9,0.1,1,0.2)",
  )
  assert_fluent_preview_curve_source_import(
    "curveAccelerateMid", "cubic-bezier(1,0,1,1)",
  )
  assert_fluent_preview_curve_source_import(
    "curveAccelerateMin", "cubic-bezier(0.8,0,0.78,1)",
  )
  assert_fluent_preview_curve_source_import(
    "curveDecelerateMax", "cubic-bezier(0.1,0.9,0.2,1)",
  )
  assert_fluent_preview_curve_source_import(
    "curveDecelerateMid", "cubic-bezier(0,0,0,1)",
  )
  assert_fluent_preview_curve_source_import(
    "curveDecelerateMin", "cubic-bezier(0.33,0,0.1,1)",
  )
  assert_fluent_preview_curve_source_import(
    "curveEasyEaseMax", "cubic-bezier(0.8,0,0.2,1)",
  )
  guard source_import_coverage_for(
      @common.DesignPreset::Fluent,
      "curveEasyEase",
    )
    is Some(fluent_curve) else {
    fail("expected Fluent curve source-import coverage")
  }
  assert_true(fluent_curve.source_imported)
  assert_true(fluent_curve.golden_mapped)
  assert_true(fluent_curve.moui_token == "DesignMotionTokens.easing")
  assert_true(fluent_curve.status == DesignTokenStatus::PreviewMapped)
  guard source_import_integrity_for(
      @common.DesignPreset::Fluent,
      "curveEasyEase",
    )
    is Some(fluent_curve_integrity) else {
    fail("expected Fluent curve integrity record")
  }
  assert_true(fluent_curve_integrity.integrity_ok)
  assert_true(fluent_curve_integrity.moui_token_matches_golden)
  assert_fluent_preview_curve_source_import(
    "curveLinear", "cubic-bezier(0,0,1,1)",
  )
  guard source_imported_token_for(
      @common.DesignPreset::Fluent,
      "fontSizeBase300",
    )
    is Some(fluent_font_size) else {
    fail("expected imported Fluent font-size token")
  }
  assert_true(fluent_font_size.source_file.contains("fonts.ts"))
  assert_true(fluent_font_size.source_value.contains("14px"))
  guard source_import_coverage_for(
      @common.DesignPreset::Fluent,
      "fontSizeBase300",
    )
    is Some(fluent_font_coverage) else {
    fail("expected Fluent font-size source-import coverage")
  }
  assert_true(fluent_font_coverage.source_imported)
  assert_true(fluent_font_coverage.golden_mapped)
  assert_true(fluent_font_coverage.status == DesignTokenStatus::ThemeMapped)
  guard source_import_coverage_for(
      @common.DesignPreset::Fluent,
      "fontWeightSemibold",
    )
    is Some(fluent_semibold) else {
    fail("expected Fluent semibold source-import coverage")
  }
  assert_true(fluent_semibold.source_imported)
  assert_true(fluent_semibold.golden_mapped)
  assert_true(
    fluent_semibold.moui_token == "DesignTypographyTokens.control.weight",
  )
  assert_true(fluent_semibold.status == DesignTokenStatus::ThemeMapped)
  guard source_import_integrity_for(
      @common.DesignPreset::Fluent,
      "fontWeightSemibold",
    )
    is Some(fluent_semibold_integrity) else {
    fail("expected Fluent semibold integrity record")
  }
  assert_true(fluent_semibold_integrity.integrity_ok)
  assert_true(fluent_semibold_integrity.moui_token_matches_golden)
  assert_fluent_preview_typography_source_import(
    "fontSizeBase100", "10px", "DesignTypographyTokens.caption.size",
  )
  assert_fluent_mapped_typography_source_import(
    "fontSizeBase200", "12px", "DesignTypographyTokens.caption.size",
  )
  assert_fluent_preview_typography_source_import(
    "fontSizeBase400", "16px", "DesignTypographyTokens.control.size",
  )
  assert_fluent_preview_typography_source_import(
    "fontSizeBase600", "24px", "DesignTypographyTokens.title.size",
  )
  assert_fluent_preview_typography_source_import(
    "fontSizeHero700", "28px", "DesignTypographyTokens.title.size",
  )
  assert_fluent_preview_typography_source_import(
    "fontSizeHero800", "32px", "DesignTypographyTokens.title.size",
  )
  assert_fluent_preview_typography_source_import(
    "fontSizeHero900", "40px", "DesignTypographyTokens.title.size",
  )
  assert_fluent_preview_typography_source_import(
    "fontSizeHero1000", "68px", "DesignTypographyTokens.title.size",
  )
  assert_fluent_preview_typography_source_import(
    "lineHeightBase100", "14px", "DesignTypographyTokens.caption.line_height",
  )
  assert_fluent_preview_typography_source_import(
    "lineHeightBase200", "16px", "DesignTypographyTokens.caption.line_height",
  )
  assert_fluent_preview_typography_source_import(
    "lineHeightBase300", "20px", "DesignTypographyTokens.body.line_height",
  )
  assert_fluent_preview_typography_source_import(
    "lineHeightBase400", "22px", "DesignTypographyTokens.control.line_height",
  )
  assert_fluent_preview_typography_source_import(
    "lineHeightBase500", "28px", "DesignTypographyTokens.title.line_height",
  )
  assert_fluent_preview_typography_source_import(
    "lineHeightBase600", "32px", "DesignTypographyTokens.title.line_height",
  )
  assert_fluent_preview_typography_source_import(
    "lineHeightHero700", "36px", "DesignTypographyTokens.title.line_height",
  )
  assert_fluent_preview_typography_source_import(
    "lineHeightHero800", "40px", "DesignTypographyTokens.title.line_height",
  )
  assert_fluent_preview_typography_source_import(
    "lineHeightHero900", "52px", "DesignTypographyTokens.title.line_height",
  )
  assert_fluent_preview_typography_source_import(
    "lineHeightHero1000", "92px", "DesignTypographyTokens.title.line_height",
  )
  assert_fluent_preview_typography_source_import(
    "fontWeightMedium", "500", "DesignTypographyTokens.control.weight",
  )
  assert_fluent_mapped_typography_source_import(
    "fontWeightBold", "700", "DesignTypographyTokens.title.weight",
  )
  assert_fluent_preview_typography_source_import(
    "fontFamilyBase", "Segoe UI", "DesignTypographyTokens.body.families",
  )
  assert_fluent_preview_typography_source_import(
    "fontFamilyMonospace", "Consolas", "DesignTypographyTokens.control.families",
  )
  assert_fluent_preview_typography_source_import(
    "fontFamilyNumeric", "Bahnschrift", "DesignTypographyTokens.body.families",
  )
  assert_fluent_mapped_stroke_width_source_import(
    "strokeWidthThin", "1px", "DesignComponentTokens.text_field.normal.border_width",
  )
  assert_fluent_mapped_stroke_width_source_import(
    "strokeWidthThick", "2px", "DesignComponentTokens.text_field.focused.border_width",
  )
  assert_fluent_preview_stroke_width_source_import(
    "strokeWidthThicker", "3px", "DesignComponentTokens.text_field.focused.border_width",
  )
  assert_fluent_preview_stroke_width_source_import(
    "strokeWidthThickest", "4px", "DesignComponentTokens.text_field.focused.border_width",
  )
  guard source_imported_token_for(
      @common.DesignPreset::Fluent,
      "spacingHorizontalXS",
    )
    is Some(fluent_spacing_xs_import) else {
    fail("expected imported Fluent extra-small spacing token")
  }
  assert_true(fluent_spacing_xs_import.source_file.contains("spacings.ts"))
  assert_true(fluent_spacing_xs_import.source_value.contains("'4px'"))
  guard source_import_coverage_for(
      @common.DesignPreset::Fluent,
      "spacingHorizontalXS",
    )
    is Some(fluent_spacing_xs) else {
    fail("expected Fluent extra-small spacing source-import coverage")
  }
  assert_true(fluent_spacing_xs.source_imported)
  assert_true(fluent_spacing_xs.golden_mapped)
  assert_true(fluent_spacing_xs.moui_token == "DesignSpacingTokens.xs")
  assert_true(fluent_spacing_xs.status == DesignTokenStatus::ThemeMapped)
  guard source_imported_token_for(
      @common.DesignPreset::Fluent,
      "borderRadiusCircular",
    )
    is Some(fluent_radius_circular_import) else {
    fail("expected imported Fluent circular radius token")
  }
  assert_true(
    fluent_radius_circular_import.source_file.contains("borderRadius.ts"),
  )
  assert_true(fluent_radius_circular_import.source_value.contains("10000px"))
  guard source_import_coverage_for(
      @common.DesignPreset::Fluent,
      "borderRadiusCircular",
    )
    is Some(fluent_radius_circular) else {
    fail("expected Fluent circular radius source-import coverage")
  }
  assert_true(fluent_radius_circular.source_imported)
  assert_true(fluent_radius_circular.golden_mapped)
  assert_true(fluent_radius_circular.moui_token == "DesignRadiusTokens.pill")
  assert_true(fluent_radius_circular.status == DesignTokenStatus::PreviewMapped)
  assert_fluent_preview_radius_source_import(
    "borderRadiusNone", "borderRadiusNone: '0'", "DesignRadiusTokens.sm",
  )
  assert_fluent_preview_radius_source_import(
    "borderRadiusLarge", "borderRadiusLarge: '6px'", "DesignRadiusTokens.lg",
  )
  assert_fluent_preview_radius_source_import(
    "borderRadius2XLarge", "borderRadius2XLarge: '12px'", "DesignRadiusTokens.lg",
  )
  assert_fluent_preview_radius_source_import(
    "borderRadius3XLarge", "borderRadius3XLarge: '16px'", "DesignRadiusTokens.lg",
  )
  assert_fluent_preview_radius_source_import(
    "borderRadius4XLarge", "borderRadius4XLarge: '24px'", "DesignRadiusTokens.pill",
  )
  assert_fluent_preview_radius_source_import(
    "borderRadius5XLarge", "borderRadius5XLarge: '32px'", "DesignRadiusTokens.pill",
  )
  assert_fluent_preview_radius_source_import(
    "borderRadius6XLarge", "borderRadius6XLarge: '40px'", "DesignRadiusTokens.pill",
  )
}
