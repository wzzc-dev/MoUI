///|
test "source imported Primer tokens expose pinned source values" {
  guard source_imported_token_for(
      @common.DesignPreset::Primer,
      "fgColor.default.$value",
    )
    is Some(primer_foreground_import) else {
    fail("expected imported Primer foreground token")
  }
  assert_true(primer_foreground_import.source_value.contains("#1f2328"))
  assert_true(primer_foreground_import.source_file.contains("fgColor.json5"))
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--fgColor-default",
    )
    is Some(primer_foreground) else {
    fail("expected Primer source-import coverage")
  }
  assert_true(primer_foreground.source_imported)
  assert_true(primer_foreground.source_token == "fgColor.default.$value")
  guard source_imported_token_for(
      @common.DesignPreset::Primer,
      "base.size.'4'.$value",
    )
    is Some(primer_base_size_xs_import) else {
    fail("expected imported Primer base size 4 token")
  }
  assert_true(primer_base_size_xs_import.source_file.contains("size.json5"))
  assert_true(
    primer_base_size_xs_import.source_sha ==
    "f84e6a0f0553677724f1973d4b7270c61fa40c28",
  )
  assert_true(primer_base_size_xs_import.source_value.contains("value: 4"))
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--base-size-4",
    )
    is Some(primer_base_size_xs) else {
    fail("expected Primer base size 4 source-import coverage")
  }
  assert_true(primer_base_size_xs.source_imported)
  assert_true(primer_base_size_xs.golden_mapped)
  assert_true(primer_base_size_xs.source_token == "base.size.'4'.$value")
  assert_true(primer_base_size_xs.moui_token == "DesignSpacingTokens.xs")
  assert_true(primer_base_size_xs.status == DesignTokenStatus::ThemeMapped)
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--base-size-8",
    )
    is Some(primer_base_size_sm) else {
    fail("expected Primer base size 8 source-import coverage")
  }
  assert_true(primer_base_size_sm.source_imported)
  assert_true(primer_base_size_sm.golden_mapped)
  assert_true(primer_base_size_sm.source_token == "base.size.'8'.$value")
  assert_true(primer_base_size_sm.moui_token == "DesignSpacingTokens.sm")
  assert_true(primer_base_size_sm.status == DesignTokenStatus::ThemeMapped)
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--base-size-12",
    )
    is Some(primer_base_size_md) else {
    fail("expected Primer base size 12 source-import coverage")
  }
  assert_true(primer_base_size_md.source_imported)
  assert_true(primer_base_size_md.golden_mapped)
  assert_true(primer_base_size_md.source_token == "base.size.'12'.$value")
  assert_true(primer_base_size_md.moui_token == "DesignSpacingTokens.md")
  assert_true(primer_base_size_md.status == DesignTokenStatus::ThemeMapped)
  guard source_imported_token_for(
      @common.DesignPreset::Primer,
      "base.size.'16'.$value",
    )
    is Some(primer_base_size_import) else {
    fail("expected imported Primer base size 16 token")
  }
  assert_true(primer_base_size_import.source_file.contains("size.json5"))
  assert_true(
    primer_base_size_import.source_sha ==
    "f84e6a0f0553677724f1973d4b7270c61fa40c28",
  )
  assert_true(primer_base_size_import.source_value.contains("value: 16"))
  assert_true(primer_base_size_import.source_value.contains("unit: 'px'"))
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--base-size-16",
    )
    is Some(primer_base_size) else {
    fail("expected Primer base size source-import coverage")
  }
  assert_true(primer_base_size.source_imported)
  assert_true(primer_base_size.golden_mapped)
  assert_true(primer_base_size.source_token == "base.size.'16'.$value")
  assert_true(primer_base_size.moui_token == "DesignSpacingTokens.lg")
  assert_true(primer_base_size.status == DesignTokenStatus::ThemeMapped)
  guard source_import_integrity_for(
      @common.DesignPreset::Primer,
      "--base-size-16",
    )
    is Some(primer_base_size_integrity) else {
    fail("expected Primer base size source-import integrity")
  }
  assert_true(primer_base_size_integrity.integrity_ok)
  assert_true(primer_base_size_integrity.moui_token_matches_golden)
  guard source_imported_token_for(
      @common.DesignPreset::Primer,
      "base.size.'24'.$value",
    )
    is Some(primer_base_size_xl_import) else {
    fail("expected imported Primer base size 24 token")
  }
  assert_true(primer_base_size_xl_import.source_file.contains("size.json5"))
  assert_true(
    primer_base_size_xl_import.source_sha ==
    "f84e6a0f0553677724f1973d4b7270c61fa40c28",
  )
  assert_true(primer_base_size_xl_import.source_value.contains("value: 24"))
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--base-size-24",
    )
    is Some(primer_base_size_xl) else {
    fail("expected Primer base size 24 source-import coverage")
  }
  assert_true(primer_base_size_xl.source_imported)
  assert_true(primer_base_size_xl.golden_mapped)
  assert_true(primer_base_size_xl.source_token == "base.size.'24'.$value")
  assert_true(primer_base_size_xl.moui_token == "DesignSpacingTokens.xl")
  assert_true(primer_base_size_xl.status == DesignTokenStatus::ThemeMapped)
  guard source_imported_token_for(
      @common.DesignPreset::Primer,
      "base.text.size.xs.$value",
    )
    is Some(primer_caption_size_import) else {
    fail("expected imported Primer caption text size token")
  }
  assert_true(
    primer_caption_size_import.source_file.contains("typography.json5"),
  )
  assert_true(
    primer_caption_size_import.source_sha ==
    "642b424c0e0ebcc46e9ce8da12f96534fd24568d",
  )
  assert_true(primer_caption_size_import.source_value.contains("value: 0.75"))
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--base-text-size-xs",
    )
    is Some(primer_caption_size) else {
    fail("expected Primer caption text size source-import coverage")
  }
  assert_true(primer_caption_size.source_imported)
  assert_true(primer_caption_size.golden_mapped)
  assert_true(primer_caption_size.source_token == "base.text.size.xs.$value")
  assert_true(
    primer_caption_size.moui_token == "DesignTypographyTokens.caption.size",
  )
  assert_true(primer_caption_size.status == DesignTokenStatus::ThemeMapped)
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--base-text-size-sm",
    )
    is Some(primer_body_size) else {
    fail("expected Primer body text size source-import coverage")
  }
  assert_true(primer_body_size.source_imported)
  assert_true(primer_body_size.golden_mapped)
  assert_true(primer_body_size.source_token == "base.text.size.sm.$value")
  assert_true(primer_body_size.moui_token == "DesignTypographyTokens.body.size")
  assert_true(primer_body_size.status == DesignTokenStatus::ThemeMapped)
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--base-text-size-lg",
    )
    is Some(primer_title_size) else {
    fail("expected Primer title text size source-import coverage")
  }
  assert_true(primer_title_size.source_imported)
  assert_true(primer_title_size.golden_mapped)
  assert_true(primer_title_size.source_token == "base.text.size.lg.$value")
  assert_true(
    primer_title_size.moui_token == "DesignTypographyTokens.title.size",
  )
  assert_true(primer_title_size.status == DesignTokenStatus::ThemeMapped)
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--base-text-weight-normal",
    )
    is Some(primer_body_weight) else {
    fail("expected Primer body text weight source-import coverage")
  }
  assert_true(primer_body_weight.source_imported)
  assert_true(primer_body_weight.golden_mapped)
  assert_true(
    primer_body_weight.source_token == "base.text.weight.normal.$value",
  )
  assert_true(
    primer_body_weight.moui_token == "DesignTypographyTokens.body.weight",
  )
  assert_true(primer_body_weight.status == DesignTokenStatus::ThemeMapped)
  guard source_imported_token_for(
      @common.DesignPreset::Primer,
      "base.text.weight.semibold.$value",
    )
    is Some(primer_control_weight_import) else {
    fail("expected imported Primer control text weight token")
  }
  assert_true(
    primer_control_weight_import.source_file.contains("typography.json5"),
  )
  assert_true(
    primer_control_weight_import.source_sha ==
    "642b424c0e0ebcc46e9ce8da12f96534fd24568d",
  )
  assert_true(primer_control_weight_import.source_value.contains("600"))
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--base-text-weight-semibold",
    )
    is Some(primer_control_weight) else {
    fail("expected Primer control text weight source-import coverage")
  }
  assert_true(primer_control_weight.source_imported)
  assert_true(primer_control_weight.golden_mapped)
  assert_true(
    primer_control_weight.source_token == "base.text.weight.semibold.$value",
  )
  assert_true(
    primer_control_weight.moui_token == "DesignTypographyTokens.control.weight",
  )
  assert_true(primer_control_weight.status == DesignTokenStatus::ThemeMapped)
  guard source_import_integrity_for(
      @common.DesignPreset::Primer,
      "--base-text-size-sm",
    )
    is Some(primer_body_size_integrity) else {
    fail("expected Primer body text size source-import integrity")
  }
  assert_true(primer_body_size_integrity.integrity_ok)
  assert_true(primer_body_size_integrity.moui_token_matches_golden)
  guard source_imported_token_for(
      @common.DesignPreset::Primer,
      "borderRadius.small.$value",
    )
    is Some(primer_radius_small_import) else {
    fail("expected imported Primer small radius token")
  }
  assert_true(primer_radius_small_import.source_file.contains("radius.json5"))
  assert_true(
    primer_radius_small_import.source_sha ==
    "e68682b0f98485e8a6a6f05c36cc8c5053f338b5",
  )
  assert_true(primer_radius_small_import.source_value.contains("value: 3"))
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--borderRadius-small",
    )
    is Some(primer_radius_small) else {
    fail("expected Primer small radius source-import coverage")
  }
  assert_true(primer_radius_small.source_imported)
  assert_true(primer_radius_small.golden_mapped)
  assert_true(primer_radius_small.source_token == "borderRadius.small.$value")
  assert_true(primer_radius_small.moui_token == "DesignRadiusTokens.sm")
  assert_true(primer_radius_small.status == DesignTokenStatus::PreviewMapped)
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--borderRadius-medium",
    )
    is Some(primer_radius_medium) else {
    fail("expected Primer medium radius source-import coverage")
  }
  assert_true(primer_radius_medium.source_imported)
  assert_true(primer_radius_medium.golden_mapped)
  assert_true(primer_radius_medium.source_token == "borderRadius.medium.$value")
  assert_true(primer_radius_medium.moui_token == "DesignRadiusTokens.md")
  assert_true(primer_radius_medium.status == DesignTokenStatus::ThemeMapped)
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--borderRadius-large",
    )
    is Some(primer_radius_large) else {
    fail("expected Primer large radius source-import coverage")
  }
  assert_true(primer_radius_large.source_imported)
  assert_true(primer_radius_large.golden_mapped)
  assert_true(primer_radius_large.source_token == "borderRadius.large.$value")
  assert_true(primer_radius_large.moui_token == "DesignRadiusTokens.lg")
  assert_true(primer_radius_large.status == DesignTokenStatus::PreviewMapped)
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--borderRadius-full",
    )
    is Some(primer_radius_full) else {
    fail("expected Primer full radius source-import coverage")
  }
  assert_true(primer_radius_full.source_imported)
  assert_true(primer_radius_full.golden_mapped)
  assert_true(primer_radius_full.source_token == "borderRadius.full.$value")
  assert_true(primer_radius_full.moui_token == "DesignRadiusTokens.pill")
  assert_true(primer_radius_full.status == DesignTokenStatus::PreviewMapped)
  guard source_imported_token_for(
      @common.DesignPreset::Primer,
      "borderRadius.default.$value",
    )
    is Some(primer_radius_default_import) else {
    fail("expected imported Primer default radius token")
  }
  assert_true(primer_radius_default_import.source_file.contains("radius.json5"))
  assert_true(
    primer_radius_default_import.source_sha ==
    "e68682b0f98485e8a6a6f05c36cc8c5053f338b5",
  )
  assert_true(
    primer_radius_default_import.source_value.contains("borderRadius.medium"),
  )
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--borderRadius-default",
    )
    is Some(primer_radius_default) else {
    fail("expected Primer default radius source-import coverage")
  }
  assert_true(primer_radius_default.source_imported)
  assert_true(primer_radius_default.golden_mapped)
  assert_true(
    primer_radius_default.source_token == "borderRadius.default.$value",
  )
  assert_true(primer_radius_default.moui_token == "DesignRadiusTokens.md")
  assert_true(primer_radius_default.status == DesignTokenStatus::ThemeMapped)
  guard source_import_integrity_for(
      @common.DesignPreset::Primer,
      "--borderRadius-medium",
    )
    is Some(primer_radius_integrity) else {
    fail("expected Primer medium radius source-import integrity")
  }
  assert_true(primer_radius_integrity.integrity_ok)
  assert_true(primer_radius_integrity.moui_token_matches_golden)
  guard source_imported_token_for(
      @common.DesignPreset::Primer,
      "shadow.resting.small.$value",
    )
    is Some(primer_shadow_small_import) else {
    fail("expected imported Primer small resting shadow token")
  }
  assert_true(primer_shadow_small_import.source_file.contains("shadow.json5"))
  assert_true(
    primer_shadow_small_import.source_sha ==
    "a20e0c19833d9664ee65f55ab6e034c939af63de",
  )
  assert_true(primer_shadow_small_import.source_value.contains("offsetY: 1"))
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--shadow-resting-small",
    )
    is Some(primer_shadow_small) else {
    fail("expected Primer small resting shadow source-import coverage")
  }
  assert_true(primer_shadow_small.source_imported)
  assert_true(primer_shadow_small.golden_mapped)
  assert_true(primer_shadow_small.source_token == "shadow.resting.small.$value")
  assert_true(
    primer_shadow_small.moui_token == "DesignElevationTokens.sm.offset.y",
  )
  assert_true(primer_shadow_small.status == DesignTokenStatus::PreviewMapped)
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--shadow-resting-medium",
    )
    is Some(primer_shadow_medium) else {
    fail("expected Primer medium resting shadow source-import coverage")
  }
  assert_true(primer_shadow_medium.source_imported)
  assert_true(primer_shadow_medium.golden_mapped)
  assert_true(
    primer_shadow_medium.source_token == "shadow.resting.medium.$value",
  )
  assert_true(
    primer_shadow_medium.moui_token == "DesignElevationTokens.md.offset.y",
  )
  assert_true(primer_shadow_medium.status == DesignTokenStatus::PreviewMapped)
  guard source_imported_token_for(
      @common.DesignPreset::Primer,
      "shadow.floating.large.$value",
    )
    is Some(primer_shadow_large_import) else {
    fail("expected imported Primer large floating shadow token")
  }
  assert_true(primer_shadow_large_import.source_file.contains("shadow.json5"))
  assert_true(
    primer_shadow_large_import.source_sha ==
    "a20e0c19833d9664ee65f55ab6e034c939af63de",
  )
  assert_true(primer_shadow_large_import.source_value.contains("offsetY: 40"))
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--shadow-floating-large",
    )
    is Some(primer_shadow_large) else {
    fail("expected Primer large floating shadow source-import coverage")
  }
  assert_true(primer_shadow_large.source_imported)
  assert_true(primer_shadow_large.golden_mapped)
  assert_true(
    primer_shadow_large.source_token == "shadow.floating.large.$value",
  )
  assert_true(
    primer_shadow_large.moui_token == "DesignElevationTokens.lg.offset.y",
  )
  assert_true(primer_shadow_large.status == DesignTokenStatus::PreviewMapped)
  guard source_import_integrity_for(
      @common.DesignPreset::Primer,
      "--shadow-resting-small",
    )
    is Some(primer_shadow_integrity) else {
    fail("expected Primer small shadow source-import integrity")
  }
  assert_true(primer_shadow_integrity.integrity_ok)
  assert_true(primer_shadow_integrity.moui_token_matches_golden)
  guard source_imported_token_for(
      @common.DesignPreset::Primer,
      "base.duration.'0'.$value",
    )
    is Some(primer_duration_zero_import) else {
    fail("expected imported Primer 0ms duration token")
  }
  assert_true(primer_duration_zero_import.source_file.contains("timing.json5"))
  assert_true(
    primer_duration_zero_import.source_sha ==
    "7d1763e6c4ca45bdf70ae26e9c55cfb9fd09ef1f",
  )
  assert_true(primer_duration_zero_import.source_value.contains("value: 0"))
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--base-duration-0",
    )
    is Some(primer_duration_zero) else {
    fail("expected Primer 0ms duration source-import coverage")
  }
  assert_true(primer_duration_zero.source_imported)
  assert_true(primer_duration_zero.golden_mapped)
  assert_true(primer_duration_zero.source_token == "base.duration.'0'.$value")
  assert_true(primer_duration_zero.moui_token == "DesignMotionTokens.fast_ms")
  assert_true(primer_duration_zero.status == DesignTokenStatus::PreviewMapped)
  guard source_imported_token_for(
      @common.DesignPreset::Primer,
      "base.duration.'100'.$value",
    )
    is Some(primer_duration_fast_import) else {
    fail("expected imported Primer 100ms duration token")
  }
  assert_true(primer_duration_fast_import.source_file.contains("timing.json5"))
  assert_true(
    primer_duration_fast_import.source_sha ==
    "7d1763e6c4ca45bdf70ae26e9c55cfb9fd09ef1f",
  )
  assert_true(primer_duration_fast_import.source_value.contains("value: 100"))
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--base-duration-100",
    )
    is Some(primer_duration_fast) else {
    fail("expected Primer 100ms duration source-import coverage")
  }
  assert_true(primer_duration_fast.source_imported)
  assert_true(primer_duration_fast.golden_mapped)
  assert_true(primer_duration_fast.source_token == "base.duration.'100'.$value")
  assert_true(primer_duration_fast.moui_token == "DesignMotionTokens.fast_ms")
  assert_true(primer_duration_fast.status == DesignTokenStatus::ThemeMapped)
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--base-duration-200",
    )
    is Some(primer_duration_normal) else {
    fail("expected Primer 200ms duration source-import coverage")
  }
  assert_true(primer_duration_normal.source_imported)
  assert_true(
    primer_duration_normal.source_token == "base.duration.'200'.$value",
  )
  assert_true(
    primer_duration_normal.moui_token == "DesignMotionTokens.normal_ms",
  )
  assert_true(primer_duration_normal.status == DesignTokenStatus::PreviewMapped)
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--base-duration-300",
    )
    is Some(primer_duration_slow) else {
    fail("expected Primer 300ms duration source-import coverage")
  }
  assert_true(primer_duration_slow.source_imported)
  assert_true(primer_duration_slow.source_token == "base.duration.'300'.$value")
  assert_true(primer_duration_slow.moui_token == "DesignMotionTokens.slow_ms")
  assert_true(primer_duration_slow.status == DesignTokenStatus::PreviewMapped)
  guard source_imported_token_for(
      @common.DesignPreset::Primer,
      "base.duration.'1000'.$value",
    )
    is Some(primer_duration_long_import) else {
    fail("expected imported Primer 1000ms duration token")
  }
  assert_true(primer_duration_long_import.source_file.contains("timing.json5"))
  assert_true(primer_duration_long_import.source_value.contains("value: 1000"))
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--base-duration-1000",
    )
    is Some(primer_duration_long) else {
    fail("expected Primer 1000ms duration source-import coverage")
  }
  assert_true(primer_duration_long.source_imported)
  assert_true(primer_duration_long.golden_mapped)
  assert_true(
    primer_duration_long.source_token == "base.duration.'1000'.$value",
  )
  assert_true(primer_duration_long.moui_token == "DesignMotionTokens.slow_ms")
  assert_true(primer_duration_long.status == DesignTokenStatus::PreviewMapped)
  guard source_imported_token_for(
      @common.DesignPreset::Primer,
      "base.easing.linear.$value",
    )
    is Some(primer_linear_import) else {
    fail("expected imported Primer linear easing token")
  }
  assert_true(primer_linear_import.source_file.contains("easing.json5"))
  assert_true(
    primer_linear_import.source_sha ==
    "e0e9196b89eada51c0ef9cd53fee9a9083374645",
  )
  assert_true(primer_linear_import.source_value.contains("0,0,1,1"))
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--base-easing-linear",
    )
    is Some(primer_linear) else {
    fail("expected Primer linear easing source-import coverage")
  }
  assert_true(primer_linear.source_imported)
  assert_true(primer_linear.source_token == "base.easing.linear.$value")
  assert_true(primer_linear.moui_token == "DesignMotionTokens.easing")
  assert_true(primer_linear.status == DesignTokenStatus::PreviewMapped)
  guard source_imported_token_for(
      @common.DesignPreset::Primer,
      "base.easing.easeOut.$value",
    )
    is Some(primer_easing_import) else {
    fail("expected imported Primer easeOut token")
  }
  assert_true(primer_easing_import.source_file.contains("easing.json5"))
  assert_true(
    primer_easing_import.source_sha ==
    "e0e9196b89eada51c0ef9cd53fee9a9083374645",
  )
  assert_true(primer_easing_import.source_value.contains("0.3,0.8,0.6,1"))
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--base-easing-easeOut",
    )
    is Some(primer_easing) else {
    fail("expected Primer easeOut source-import coverage")
  }
  assert_true(primer_easing.source_imported)
  assert_true(primer_easing.source_token == "base.easing.easeOut.$value")
  assert_true(primer_easing.moui_token == "DesignMotionTokens.easing")
  assert_true(primer_easing.status == DesignTokenStatus::PreviewMapped)
  guard source_import_integrity_for(
      @common.DesignPreset::Primer,
      "--base-easing-easeOut",
    )
    is Some(primer_easing_integrity) else {
    fail("expected Primer easeOut source-import integrity")
  }
  assert_true(primer_easing_integrity.integrity_ok)
  assert_true(primer_easing_integrity.moui_token_matches_golden)
  guard source_imported_token_for(
      @common.DesignPreset::Primer,
      "base.easing.easeInOut.$value",
    )
    is Some(primer_ease_in_out_import) else {
    fail("expected imported Primer easeInOut token")
  }
  assert_true(primer_ease_in_out_import.source_file.contains("easing.json5"))
  assert_true(primer_ease_in_out_import.source_value.contains("0.6,0,0.2,1"))
  guard source_import_integrity_for(
      @common.DesignPreset::Primer,
      "--base-easing-easeInOut",
    )
    is Some(primer_ease_in_out_integrity) else {
    fail("expected Primer easeInOut source-import integrity")
  }
  assert_true(primer_ease_in_out_integrity.integrity_ok)
  assert_true(primer_ease_in_out_integrity.moui_token_matches_golden)
  guard source_imported_token_for(
      @common.DesignPreset::Primer,
      "Primer animation token family",
    )
    is Some(primer_animation_family) else {
    fail("expected imported Primer animation token family")
  }
  assert_true(primer_animation_family.source_file.contains("timing.json5"))
  assert_true(primer_animation_family.source_value.contains("base.duration"))
  assert_true(primer_animation_family.source_value.contains("base.easing"))
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "Primer animation token family",
    )
    is Some(primer_animation_family_coverage) else {
    fail("expected Primer animation family source-import coverage")
  }
  assert_true(primer_animation_family_coverage.source_imported)
  assert_true(primer_animation_family_coverage.golden_mapped)
  assert_true(
    primer_animation_family_coverage.moui_token == "DesignMotionTokens",
  )
  assert_true(
    primer_animation_family_coverage.status == DesignTokenStatus::PreviewMapped,
  )
  guard source_import_integrity_for(
      @common.DesignPreset::Primer,
      "Primer animation token family",
    )
    is Some(primer_animation_family_integrity) else {
    fail("expected Primer animation family source-import integrity")
  }
  assert_true(primer_animation_family_integrity.integrity_ok)
  assert_true(primer_animation_family_integrity.moui_token_matches_golden)
  guard source_imported_token_for(
      @common.DesignPreset::Primer,
      "button.primary.bgColor.rest.$value",
    )
    is Some(primer_button_import) else {
    fail("expected imported Primer primary button background token")
  }
  assert_true(primer_button_import.source_file.contains("button.json5"))
  assert_true(
    primer_button_import.source_sha ==
    "a1fe0c55d866663ee03883c7652248040a652c8e",
  )
  assert_true(primer_button_import.source_value.contains("#1f883d"))
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--button-primary-bgColor-rest",
    )
    is Some(primer_button) else {
    fail("expected Primer primary button source-import coverage")
  }
  assert_true(primer_button.source_imported)
  assert_true(primer_button.golden_mapped)
  assert_true(
    primer_button.source_token == "button.primary.bgColor.rest.$value",
  )
  assert_true(
    primer_button.moui_token ==
    "DesignComponentTokens.button.primary.background",
  )
  assert_true(primer_button.status == DesignTokenStatus::ComponentMapped)
  guard source_import_integrity_for(
      @common.DesignPreset::Primer,
      "--button-primary-bgColor-rest",
    )
    is Some(primer_button_integrity) else {
    fail("expected Primer primary button source-import integrity")
  }
  assert_true(primer_button_integrity.integrity_ok)
  assert_true(primer_button_integrity.moui_token_matches_golden)
  guard source_imported_token_for(
      @common.DesignPreset::Primer,
      "control.bgColor.rest.$value",
    )
    is Some(primer_control_import) else {
    fail("expected imported Primer control rest background token")
  }
  assert_true(primer_control_import.source_file.contains("control.json5"))
  assert_true(
    primer_control_import.source_sha ==
    "e59325362304202a432f44cd78b712b84a4cfcc0",
  )
  assert_true(primer_control_import.source_value.contains("#F6F8FA"))
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--control-bgColor-rest",
    )
    is Some(primer_control) else {
    fail("expected Primer control rest background source-import coverage")
  }
  assert_true(primer_control.source_imported)
  assert_true(primer_control.golden_mapped)
  assert_true(primer_control.source_token == "control.bgColor.rest.$value")
  assert_true(
    primer_control.moui_token == "DesignComponentTokens.picker.background",
  )
  assert_true(primer_control.status == DesignTokenStatus::ComponentMapped)
  guard source_import_integrity_for(
      @common.DesignPreset::Primer,
      "--control-bgColor-rest",
    )
    is Some(primer_control_integrity) else {
    fail("expected Primer control rest background source-import integrity")
  }
  assert_true(primer_control_integrity.integrity_ok)
  assert_true(primer_control_integrity.moui_token_matches_golden)
  guard source_imported_token_for(
      @common.DesignPreset::Primer,
      "control.transparent.bgColor.hover.alpha",
    )
    is Some(primer_control_hover_import) else {
    fail("expected imported Primer transparent hover control token")
  }
  assert_true(primer_control_hover_import.source_file.contains("control.json5"))
  assert_true(
    primer_control_hover_import.source_sha ==
    "e59325362304202a432f44cd78b712b84a4cfcc0",
  )
  assert_true(primer_control_hover_import.source_value.contains("alpha: 0.1"))
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--control-transparent-bgColor-hover",
    )
    is Some(primer_control_hover) else {
    fail("expected Primer transparent hover source-import coverage")
  }
  assert_true(primer_control_hover.source_imported)
  assert_true(primer_control_hover.golden_mapped)
  assert_true(
    primer_control_hover.source_token ==
    "control.transparent.bgColor.hover.alpha",
  )
  assert_true(
    primer_control_hover.moui_token == "DesignStateLayerTokens.hover_alpha",
  )
  assert_true(primer_control_hover.status == DesignTokenStatus::ComponentMapped)
  guard source_import_integrity_for(
      @common.DesignPreset::Primer,
      "--control-transparent-bgColor-hover",
    )
    is Some(primer_control_hover_integrity) else {
    fail("expected Primer transparent hover source-import integrity")
  }
  assert_true(primer_control_hover_integrity.integrity_ok)
  assert_true(primer_control_hover_integrity.moui_token_matches_golden)
  guard source_imported_token_for(
      @common.DesignPreset::Primer,
      "control.borderColor.emphasis.$value",
    )
    is Some(primer_control_border_import) else {
    fail("expected imported Primer control emphasized border token")
  }
  assert_true(
    primer_control_border_import.source_file.contains("control.json5"),
  )
  assert_true(
    primer_control_border_import.source_sha ==
    "e59325362304202a432f44cd78b712b84a4cfcc0",
  )
  assert_true(primer_control_border_import.source_value.contains("#818B98"))
  assert_true(
    primer_control_border_import.source_value.contains("borderColor.json5"),
  )
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--control-borderColor-emphasis",
    )
    is Some(primer_control_border) else {
    fail("expected Primer control emphasized border source-import coverage")
  }
  assert_true(primer_control_border.source_imported)
  assert_true(primer_control_border.golden_mapped)
  assert_true(
    primer_control_border.source_token == "control.borderColor.emphasis.$value",
  )
  assert_true(
    primer_control_border.moui_token == "DesignTextFieldTokens.focused.border",
  )
  assert_true(
    primer_control_border.status == DesignTokenStatus::ComponentMapped,
  )
  guard source_import_integrity_for(
      @common.DesignPreset::Primer,
      "--control-borderColor-emphasis",
    )
    is Some(primer_control_border_integrity) else {
    fail("expected Primer control emphasized border source-import integrity")
  }
  assert_true(primer_control_border_integrity.integrity_ok)
  assert_true(primer_control_border_integrity.moui_token_matches_golden)
  guard source_imported_token_for(
      @common.DesignPreset::Primer,
      "progressBar.bgColor.accent.$value",
    )
    is Some(primer_progress_import) else {
    fail("expected imported Primer progress accent token")
  }
  assert_true(primer_progress_import.source_file.contains("progressBar.json5"))
  assert_true(
    primer_progress_import.source_sha ==
    "40816af4a1a546db95f856c616befe994e68ad75",
  )
  assert_true(primer_progress_import.source_value.contains("#0969da"))
  guard source_import_coverage_for(
      @common.DesignPreset::Primer,
      "--progressBar-fgColor-accent",
    )
    is Some(primer_progress) else {
    fail("expected Primer progress source-import coverage")
  }
  assert_true(primer_progress.source_imported)
  assert_true(primer_progress.golden_mapped)
  assert_true(
    primer_progress.source_token == "progressBar.bgColor.accent.$value",
  )
  assert_true(
    primer_progress.moui_token == "DesignComponentTokens.progress.foreground",
  )
  assert_true(primer_progress.status == DesignTokenStatus::ComponentMapped)
  guard source_import_integrity_for(
      @common.DesignPreset::Primer,
      "--progressBar-fgColor-accent",
    )
    is Some(primer_progress_integrity) else {
    fail("expected Primer progress source-import integrity")
  }
  assert_true(primer_progress_integrity.integrity_ok)
  assert_true(primer_progress_integrity.moui_token_matches_golden)
}
