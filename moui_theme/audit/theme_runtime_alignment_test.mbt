///|
test "runtime token alignment ties resolved source imports to design tokens" {
  for
    preset in [
      @common.DesignPreset::Material,
      @common.DesignPreset::Carbon,
      @common.DesignPreset::Primer,
      @common.DesignPreset::Fluent,
    ] {
    let rows = runtime_token_alignment_report(preset)
    assert_true(rows.length() == official_token_anchor_count(preset))
    assert_true(runtime_token_alignment_count(preset) == rows.length())
    assert_true(runtime_token_alignment_gap_count(preset) > 0)
    assert_false(is_design_system_complete(preset))
    for item in rows {
      assert_true(item.official_token != "")
      let material_spacing_placeholder = preset ==
        @common.DesignPreset::Material &&
        item.official_token == "--md-sys-spacing-*"
      if material_spacing_placeholder {
        assert_false(item.required)
      } else {
        assert_true(item.required)
      }
      if item.runtime_aligned {
        assert_true(item.source_imported)
        assert_true(item.source_value_resolved)
        assert_true(item.runtime_value_available)
        assert_true(item.expected_runtime_value == item.runtime_value)
      }
    }
  }
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "colorNeutralForeground1",
    )
    is Some(fluent_foreground) else {
    fail("expected Fluent foreground runtime alignment")
  }
  assert_true(fluent_foreground.runtime_aligned)
  assert_true(fluent_foreground.source_value_resolved)
  assert_true(fluent_foreground.runtime_value_available)
  assert_true(
    fluent_foreground.expected_runtime_value == fluent_foreground.runtime_value,
  )
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "colorBrandBackground",
    )
    is Some(fluent_brand) else {
    fail("expected Fluent brand runtime alignment")
  }
  assert_true(fluent_brand.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "colorCompoundBrandBackground",
    )
    is Some(fluent_compound_brand) else {
    fail("expected Fluent compound brand runtime alignment")
  }
  assert_true(fluent_compound_brand.source_imported)
  assert_true(fluent_compound_brand.source_value_resolved)
  assert_true(fluent_compound_brand.runtime_value_available)
  assert_true(fluent_compound_brand.runtime_aligned)
  assert_fluent_preview_global_color_runtime_alignment(
    "red.primary", "rgba(0.8196078431372549,0.20392156862745098,0.2196078431372549,1)",
  )
  assert_fluent_preview_global_color_runtime_alignment(
    "green.primary", "rgba(0.06274509803921569,0.48627450980392156,0.06274509803921569,1)",
  )
  assert_fluent_preview_global_color_runtime_alignment(
    "lightGreen.primary", "rgba(0.07450980392156863,0.6313725490196078,0.054901960784313725,1)",
  )
  assert_fluent_preview_global_color_runtime_alignment(
    "cranberry.primary", "rgba(0.7725490196078432,0.058823529411764705,0.12156862745098039,1)",
  )
  assert_fluent_preview_global_color_runtime_alignment(
    "darkOrange.primary", "rgba(0.8549019607843137,0.23137254901960785,0.00392156862745098,1)",
  )
  assert_fluent_preview_global_color_runtime_alignment(
    "orange.primary", "rgba(0.9686274509803922,0.38823529411764707,0.047058823529411764,1)",
  )
  assert_fluent_preview_global_color_runtime_alignment(
    "yellow.primary", "rgba(0.9921568627450981,0.8901960784313725,0,1)",
  )
  assert_fluent_preview_global_color_runtime_alignment(
    "marigold.primary", "rgba(0.9176470588235294,0.6392156862745098,0,1)",
  )
  assert_fluent_preview_global_color_runtime_alignment(
    "blue.primary", "rgba(0,0.47058823529411764,0.8313725490196079,1)",
  )
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "ProgressBar.indicator.backgroundColor",
    )
    is Some(fluent_progress) else {
    fail("expected Fluent progress runtime alignment")
  }
  assert_true(fluent_progress.source_imported)
  assert_true(fluent_progress.source_value_resolved)
  assert_true(fluent_progress.runtime_value_available)
  assert_true(fluent_progress.runtime_aligned)
  assert_true(fluent_progress.status == DesignTokenStatus::ComponentMapped)
  assert_true(
    fluent_progress.moui_token == "DesignComponentTokens.progress.foreground",
  )
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "colorNeutralBackground2",
    )
    is Some(fluent_surface) else {
    fail("expected Fluent surface runtime alignment")
  }
  assert_true(fluent_surface.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "colorNeutralBackground3",
    )
    is Some(fluent_surface_variant) else {
    fail("expected Fluent surface-variant runtime alignment")
  }
  assert_true(fluent_surface_variant.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "colorNeutralStroke1",
    )
    is Some(fluent_outline) else {
    fail("expected Fluent outline runtime alignment")
  }
  assert_true(fluent_outline.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "colorNeutralForeground3",
    )
    is Some(fluent_muted) else {
    fail("expected Fluent muted runtime alignment")
  }
  assert_true(fluent_muted.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "borderRadiusMedium",
    )
    is Some(fluent_radius) else {
    fail("expected Fluent radius runtime alignment")
  }
  assert_true(fluent_radius.runtime_aligned)
  inspect(fluent_radius.runtime_value, content="4")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "fontSizeBase300",
    )
    is Some(fluent_body_font_size) else {
    fail("expected Fluent body font-size runtime alignment")
  }
  assert_true(fluent_body_font_size.runtime_aligned)
  inspect(fluent_body_font_size.runtime_value, content="14")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "fontSizeBase500",
    )
    is Some(fluent_title_font_size) else {
    fail("expected Fluent title font-size runtime alignment")
  }
  assert_true(fluent_title_font_size.source_value_resolved)
  assert_true(fluent_title_font_size.runtime_value_available)
  // Fluent 2 title maps to 20px (subtitle1), aligning with the resolved
  // runtime value from the design token set.
  assert_true(fluent_title_font_size.runtime_aligned)
  assert_true(fluent_title_font_size.status == DesignTokenStatus::PreviewMapped)
  inspect(fluent_title_font_size.expected_runtime_value, content="20")
  inspect(fluent_title_font_size.runtime_value, content="20")
  assert_fluent_preview_typography_runtime_alignment(
    "fontSizeBase100", "10", "12",
  )
  assert_fluent_preview_typography_runtime_alignment(
    "fontSizeBase400", "16", "14",
  )
  assert_fluent_preview_typography_runtime_alignment(
    "fontSizeBase600", "24", "20",
  )
  assert_fluent_preview_typography_runtime_alignment(
    "fontSizeHero700", "28", "20",
  )
  assert_fluent_preview_typography_runtime_alignment(
    "fontSizeHero800", "32", "20",
  )
  assert_fluent_preview_typography_runtime_alignment(
    "fontSizeHero900", "40", "20",
  )
  assert_fluent_preview_typography_runtime_alignment(
    "fontSizeHero1000", "68", "20",
  )
  assert_fluent_typography_destination_gap("lineHeightBase100", "14")
  assert_fluent_typography_destination_gap("lineHeightBase200", "16")
  assert_fluent_typography_destination_gap("lineHeightBase300", "20")
  assert_fluent_typography_destination_gap("lineHeightBase400", "22")
  assert_fluent_typography_destination_gap("lineHeightBase500", "28")
  assert_fluent_typography_destination_gap("lineHeightBase600", "32")
  assert_fluent_typography_destination_gap("lineHeightHero700", "36")
  assert_fluent_typography_destination_gap("lineHeightHero800", "40")
  assert_fluent_typography_destination_gap("lineHeightHero900", "52")
  assert_fluent_typography_destination_gap("lineHeightHero1000", "92")
  assert_fluent_preview_typography_runtime_alignment(
    "fontWeightMedium", "500", "600",
  )
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "fontWeightSemibold",
    )
    is Some(fluent_semibold) else {
    fail("expected Fluent semibold runtime alignment")
  }
  assert_true(fluent_semibold.runtime_aligned)
  inspect(fluent_semibold.runtime_value, content="600")
  assert_fluent_mapped_typography_runtime_alignment("fontWeightBold", "700")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "fontFamilyBase",
    )
    is Some(fluent_family_base) else {
    fail("expected Fluent base font-family runtime alignment")
  }
  assert_true(fluent_family_base.source_value_resolved)
  assert_true(fluent_family_base.runtime_value_available)
  assert_false(fluent_family_base.runtime_aligned)
  assert_true(fluent_family_base.status == PreviewMapped)
  assert_true(fluent_family_base.expected_runtime_value.contains("Segoe UI"))
  inspect(fluent_family_base.runtime_value, content="system-ui")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "fontFamilyMonospace",
    )
    is Some(fluent_family_monospace) else {
    fail("expected Fluent monospace font-family runtime alignment")
  }
  assert_true(
    fluent_family_monospace.expected_runtime_value.contains("Consolas"),
  )
  inspect(fluent_family_monospace.runtime_value, content="system-ui")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "fontFamilyNumeric",
    )
    is Some(fluent_family_numeric) else {
    fail("expected Fluent numeric font-family runtime alignment")
  }
  assert_true(
    fluent_family_numeric.expected_runtime_value.contains("Bahnschrift"),
  )
  inspect(fluent_family_numeric.runtime_value, content="system-ui")
  assert_fluent_mapped_stroke_width_runtime_alignment("strokeWidthThin", "1")
  assert_fluent_mapped_stroke_width_runtime_alignment("strokeWidthThick", "2")
  assert_fluent_preview_stroke_width_runtime_alignment(
    "strokeWidthThicker", "3", "2",
  )
  assert_fluent_preview_stroke_width_runtime_alignment(
    "strokeWidthThickest", "4", "2",
  )
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "spacingHorizontalM",
    )
    is Some(fluent_spacing) else {
    fail("expected Fluent spacing runtime alignment")
  }
  assert_true(fluent_spacing.runtime_aligned)
  inspect(fluent_spacing.runtime_value, content="12")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "spacingHorizontalXL",
    )
    is Some(fluent_spacing_xl) else {
    fail("expected Fluent extra-large spacing runtime alignment")
  }
  assert_true(fluent_spacing_xl.runtime_aligned)
  inspect(fluent_spacing_xl.runtime_value, content="20")
  assert_fluent_preview_spacing_runtime_alignment(
    "spacingHorizontalNone", "0", "4",
  )
  assert_fluent_preview_spacing_runtime_alignment(
    "spacingHorizontalXXS", "2", "4",
  )
  assert_fluent_preview_spacing_runtime_alignment(
    "spacingHorizontalSNudge", "6", "8",
  )
  assert_fluent_preview_spacing_runtime_alignment(
    "spacingHorizontalMNudge", "10", "12",
  )
  assert_fluent_preview_spacing_runtime_alignment(
    "spacingHorizontalL", "16", "20",
  )
  assert_fluent_preview_spacing_runtime_alignment(
    "spacingHorizontalXXL", "24", "32",
  )
  assert_fluent_mapped_spacing_runtime_alignment("spacingHorizontalXXXL", "32")
  assert_fluent_preview_spacing_runtime_alignment(
    "spacingVerticalNone", "0", "4",
  )
  assert_fluent_preview_spacing_runtime_alignment(
    "spacingVerticalXXS", "2", "4",
  )
  assert_fluent_mapped_spacing_runtime_alignment("spacingVerticalXS", "4")
  assert_fluent_preview_spacing_runtime_alignment(
    "spacingVerticalSNudge", "6", "8",
  )
  assert_fluent_mapped_spacing_runtime_alignment("spacingVerticalS", "8")
  assert_fluent_preview_spacing_runtime_alignment(
    "spacingVerticalMNudge", "10", "12",
  )
  assert_fluent_mapped_spacing_runtime_alignment("spacingVerticalM", "12")
  assert_fluent_preview_spacing_runtime_alignment(
    "spacingVerticalL", "16", "20",
  )
  assert_fluent_mapped_spacing_runtime_alignment("spacingVerticalXL", "20")
  assert_fluent_preview_spacing_runtime_alignment(
    "spacingVerticalXXL", "24", "32",
  )
  assert_fluent_mapped_spacing_runtime_alignment("spacingVerticalXXXL", "32")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "borderRadiusCircular",
    )
    is Some(fluent_radius_circular) else {
    fail("expected Fluent circular radius runtime alignment")
  }
  assert_true(fluent_radius_circular.source_value_resolved)
  assert_true(fluent_radius_circular.runtime_value_available)
  assert_false(fluent_radius_circular.runtime_aligned)
  assert_true(fluent_radius_circular.status == DesignTokenStatus::PreviewMapped)
  inspect(fluent_radius_circular.expected_runtime_value, content="10000")
  inspect(fluent_radius_circular.runtime_value, content="999")
  assert_fluent_preview_radius_runtime_alignment("borderRadiusNone", "0", "2")
  assert_fluent_preview_radius_runtime_alignment("borderRadiusLarge", "6", "8")
  assert_fluent_preview_radius_runtime_alignment(
    "borderRadius2XLarge", "12", "8",
  )
  assert_fluent_preview_radius_runtime_alignment(
    "borderRadius3XLarge", "16", "8",
  )
  assert_fluent_preview_radius_runtime_alignment(
    "borderRadius4XLarge", "24", "999",
  )
  assert_fluent_preview_radius_runtime_alignment(
    "borderRadius5XLarge", "32", "999",
  )
  assert_fluent_preview_radius_runtime_alignment(
    "borderRadius6XLarge", "40", "999",
  )
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "durationUltraFast",
    )
    is Some(fluent_duration_ultra_fast) else {
    fail("expected Fluent ultra-fast duration runtime alignment")
  }
  assert_true(fluent_duration_ultra_fast.source_value_resolved)
  assert_true(fluent_duration_ultra_fast.runtime_value_available)
  assert_false(fluent_duration_ultra_fast.runtime_aligned)
  assert_true(
    fluent_duration_ultra_fast.status == DesignTokenStatus::PreviewMapped,
  )
  inspect(fluent_duration_ultra_fast.expected_runtime_value, content="50")
  inspect(fluent_duration_ultra_fast.runtime_value, content="100")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "durationFaster",
    )
    is Some(fluent_duration_fast) else {
    fail("expected Fluent faster duration runtime alignment")
  }
  assert_true(fluent_duration_fast.runtime_aligned)
  assert_true(fluent_duration_fast.status == DesignTokenStatus::ThemeMapped)
  inspect(fluent_duration_fast.runtime_value, content="100")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "durationFast",
    )
    is Some(fluent_duration_fast_preview) else {
    fail("expected Fluent fast duration runtime alignment")
  }
  assert_true(fluent_duration_fast_preview.source_value_resolved)
  assert_true(fluent_duration_fast_preview.runtime_value_available)
  assert_false(fluent_duration_fast_preview.runtime_aligned)
  assert_true(
    fluent_duration_fast_preview.status == DesignTokenStatus::PreviewMapped,
  )
  inspect(fluent_duration_fast_preview.expected_runtime_value, content="150")
  inspect(fluent_duration_fast_preview.runtime_value, content="100")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "durationNormal",
    )
    is Some(fluent_duration) else {
    fail("expected Fluent duration runtime alignment")
  }
  assert_true(fluent_duration.runtime_aligned)
  assert_true(fluent_duration.status == DesignTokenStatus::ThemeMapped)
  inspect(fluent_duration.runtime_value, content="150")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "durationGentle",
    )
    is Some(fluent_duration_gentle) else {
    fail("expected Fluent gentle duration runtime alignment")
  }
  assert_true(fluent_duration_gentle.source_value_resolved)
  assert_true(fluent_duration_gentle.runtime_value_available)
  assert_false(fluent_duration_gentle.runtime_aligned)
  assert_true(fluent_duration_gentle.status == DesignTokenStatus::PreviewMapped)
  inspect(fluent_duration_gentle.expected_runtime_value, content="200")
  inspect(fluent_duration_gentle.runtime_value, content="150")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "durationSlow",
    )
    is Some(fluent_duration_slow) else {
    fail("expected Fluent slow duration runtime alignment")
  }
  assert_true(fluent_duration_slow.runtime_aligned)
  assert_true(fluent_duration_slow.status == DesignTokenStatus::ThemeMapped)
  inspect(fluent_duration_slow.runtime_value, content="250")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "durationSlower",
    )
    is Some(fluent_duration_slower) else {
    fail("expected Fluent slower duration runtime alignment")
  }
  assert_true(fluent_duration_slower.source_value_resolved)
  assert_true(fluent_duration_slower.runtime_value_available)
  assert_false(fluent_duration_slower.runtime_aligned)
  assert_true(fluent_duration_slower.status == DesignTokenStatus::PreviewMapped)
  inspect(fluent_duration_slower.expected_runtime_value, content="400")
  inspect(fluent_duration_slower.runtime_value, content="250")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "durationUltraSlow",
    )
    is Some(fluent_duration_ultra_slow) else {
    fail("expected Fluent ultra-slow duration runtime alignment")
  }
  assert_true(fluent_duration_ultra_slow.source_value_resolved)
  assert_true(fluent_duration_ultra_slow.runtime_value_available)
  assert_false(fluent_duration_ultra_slow.runtime_aligned)
  assert_true(
    fluent_duration_ultra_slow.status == DesignTokenStatus::PreviewMapped,
  )
  inspect(fluent_duration_ultra_slow.expected_runtime_value, content="500")
  inspect(fluent_duration_ultra_slow.runtime_value, content="250")
  assert_fluent_preview_curve_runtime_alignment(
    "curveAccelerateMax", "cubic-bezier(0.9,0.1,1,0.2)",
  )
  assert_fluent_preview_curve_runtime_alignment(
    "curveAccelerateMid", "cubic-bezier(1,0,1,1)",
  )
  assert_fluent_preview_curve_runtime_alignment(
    "curveAccelerateMin", "cubic-bezier(0.8,0,0.78,1)",
  )
  assert_fluent_preview_curve_runtime_alignment(
    "curveDecelerateMax", "cubic-bezier(0.1,0.9,0.2,1)",
  )
  assert_fluent_preview_curve_runtime_alignment(
    "curveDecelerateMid", "cubic-bezier(0,0,0,1)",
  )
  assert_fluent_preview_curve_runtime_alignment(
    "curveDecelerateMin", "cubic-bezier(0.33,0,0.1,1)",
  )
  assert_fluent_preview_curve_runtime_alignment(
    "curveEasyEaseMax", "cubic-bezier(0.8,0,0.2,1)",
  )
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "curveEasyEase",
    )
    is Some(fluent_curve) else {
    fail("expected Fluent curve runtime alignment row")
  }
  assert_true(fluent_curve.source_imported)
  assert_true(fluent_curve.source_value_resolved)
  assert_true(fluent_curve.runtime_value_available)
  assert_false(fluent_curve.runtime_aligned)
  assert_true(fluent_curve.status == DesignTokenStatus::PreviewMapped)
  inspect(
    fluent_curve.expected_runtime_value,
    content="cubic-bezier(0.33,0,0.67,1)",
  )
  inspect(fluent_curve.runtime_value, content="ease-in-out")
  assert_fluent_preview_curve_runtime_alignment(
    "curveLinear", "cubic-bezier(0,0,1,1)",
  )
  guard runtime_token_alignment_for(
      @common.DesignPreset::Fluent,
      "colorNeutralBackground1Hover",
    )
    is Some(fluent_hover) else {
    fail("expected Fluent hover runtime alignment row")
  }
  assert_false(fluent_hover.runtime_aligned)
  assert_true(fluent_hover.source_value_resolved)
  assert_true(fluent_hover.runtime_value_available)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--fgColor-default",
    )
    is Some(primer_foreground) else {
    fail("expected Primer foreground runtime alignment")
  }
  assert_true(primer_foreground.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--fgColor-accent",
    )
    is Some(primer_accent) else {
    fail("expected Primer accent runtime alignment")
  }
  assert_true(primer_accent.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--button-primary-bgColor-rest",
    )
    is Some(primer_button) else {
    fail("expected Primer primary button runtime alignment row")
  }
  assert_true(primer_button.source_imported)
  assert_true(primer_button.source_value_resolved)
  assert_true(primer_button.runtime_value_available)
  assert_false(primer_button.runtime_aligned)
  assert_true(primer_button.status == DesignTokenStatus::PreviewMapped)
  assert_true(
    primer_button.expected_runtime_value != primer_button.runtime_value,
  )
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--progressBar-fgColor-accent",
    )
    is Some(primer_progress) else {
    fail("expected Primer progress runtime alignment")
  }
  assert_true(primer_progress.source_imported)
  assert_true(primer_progress.source_value_resolved)
  assert_true(primer_progress.runtime_value_available)
  assert_true(primer_progress.runtime_aligned)
  assert_true(primer_progress.status == DesignTokenStatus::ComponentMapped)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--base-size-4",
    )
    is Some(primer_base_size_xs) else {
    fail("expected Primer base size 4 runtime alignment")
  }
  assert_true(primer_base_size_xs.source_imported)
  assert_true(primer_base_size_xs.source_value_resolved)
  assert_true(primer_base_size_xs.runtime_value_available)
  assert_true(primer_base_size_xs.runtime_aligned)
  assert_true(primer_base_size_xs.status == DesignTokenStatus::ThemeMapped)
  inspect(primer_base_size_xs.runtime_value, content="4")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--base-size-8",
    )
    is Some(primer_base_size_sm) else {
    fail("expected Primer base size 8 runtime alignment")
  }
  assert_true(primer_base_size_sm.runtime_aligned)
  assert_true(primer_base_size_sm.status == DesignTokenStatus::ThemeMapped)
  inspect(primer_base_size_sm.runtime_value, content="8")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--base-size-12",
    )
    is Some(primer_base_size_md) else {
    fail("expected Primer base size 12 runtime alignment")
  }
  assert_true(primer_base_size_md.runtime_aligned)
  assert_true(primer_base_size_md.status == DesignTokenStatus::ThemeMapped)
  inspect(primer_base_size_md.runtime_value, content="12")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--base-size-16",
    )
    is Some(primer_base_size) else {
    fail("expected Primer base size runtime alignment")
  }
  assert_true(primer_base_size.source_imported)
  assert_true(primer_base_size.source_value_resolved)
  assert_true(primer_base_size.runtime_value_available)
  assert_true(primer_base_size.runtime_aligned)
  assert_true(primer_base_size.status == DesignTokenStatus::ThemeMapped)
  inspect(primer_base_size.runtime_value, content="16")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--base-size-24",
    )
    is Some(primer_base_size_xl) else {
    fail("expected Primer base size 24 runtime alignment")
  }
  assert_true(primer_base_size_xl.runtime_aligned)
  assert_true(primer_base_size_xl.status == DesignTokenStatus::ThemeMapped)
  inspect(primer_base_size_xl.runtime_value, content="24")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--base-text-size-xs",
    )
    is Some(primer_caption_size) else {
    fail("expected Primer caption text size runtime alignment")
  }
  assert_true(primer_caption_size.source_imported)
  assert_true(primer_caption_size.source_value_resolved)
  assert_true(primer_caption_size.runtime_value_available)
  assert_true(primer_caption_size.runtime_aligned)
  assert_true(primer_caption_size.status == DesignTokenStatus::ThemeMapped)
  inspect(primer_caption_size.runtime_value, content="12")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--base-text-size-sm",
    )
    is Some(primer_body_size) else {
    fail("expected Primer body text size runtime alignment")
  }
  assert_true(primer_body_size.runtime_aligned)
  assert_true(primer_body_size.status == DesignTokenStatus::ThemeMapped)
  inspect(primer_body_size.runtime_value, content="14")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--base-text-size-lg",
    )
    is Some(primer_title_size) else {
    fail("expected Primer title text size runtime alignment")
  }
  assert_true(primer_title_size.runtime_aligned)
  assert_true(primer_title_size.status == DesignTokenStatus::ThemeMapped)
  inspect(primer_title_size.runtime_value, content="20")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--base-text-weight-normal",
    )
    is Some(primer_body_weight) else {
    fail("expected Primer body text weight runtime alignment")
  }
  assert_true(primer_body_weight.runtime_aligned)
  assert_true(primer_body_weight.status == DesignTokenStatus::ThemeMapped)
  inspect(primer_body_weight.runtime_value, content="400")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--base-text-weight-semibold",
    )
    is Some(primer_control_weight) else {
    fail("expected Primer control text weight runtime alignment")
  }
  assert_true(primer_control_weight.runtime_aligned)
  assert_true(primer_control_weight.status == DesignTokenStatus::ThemeMapped)
  inspect(primer_control_weight.runtime_value, content="600")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--borderRadius-small",
    )
    is Some(primer_radius_small) else {
    fail("expected Primer small radius runtime alignment")
  }
  assert_true(primer_radius_small.source_imported)
  assert_true(primer_radius_small.source_value_resolved)
  assert_true(primer_radius_small.runtime_value_available)
  assert_false(primer_radius_small.runtime_aligned)
  assert_true(primer_radius_small.status == DesignTokenStatus::PreviewMapped)
  inspect(primer_radius_small.expected_runtime_value, content="3")
  inspect(primer_radius_small.runtime_value, content="4")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--borderRadius-medium",
    )
    is Some(primer_radius_medium) else {
    fail("expected Primer medium radius runtime alignment")
  }
  assert_true(primer_radius_medium.runtime_aligned)
  assert_true(primer_radius_medium.status == DesignTokenStatus::ThemeMapped)
  inspect(primer_radius_medium.runtime_value, content="6")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--borderRadius-large",
    )
    is Some(primer_radius_large) else {
    fail("expected Primer large radius runtime alignment")
  }
  assert_false(primer_radius_large.runtime_aligned)
  assert_true(primer_radius_large.status == DesignTokenStatus::PreviewMapped)
  inspect(primer_radius_large.expected_runtime_value, content="12")
  inspect(primer_radius_large.runtime_value, content="8")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--borderRadius-full",
    )
    is Some(primer_radius_full) else {
    fail("expected Primer full radius runtime alignment")
  }
  assert_false(primer_radius_full.runtime_aligned)
  assert_true(primer_radius_full.status == DesignTokenStatus::PreviewMapped)
  inspect(primer_radius_full.expected_runtime_value, content="9999")
  inspect(primer_radius_full.runtime_value, content="999")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--borderRadius-default",
    )
    is Some(primer_radius_default) else {
    fail("expected Primer default radius runtime alignment")
  }
  assert_true(primer_radius_default.runtime_aligned)
  assert_true(primer_radius_default.status == DesignTokenStatus::ThemeMapped)
  inspect(primer_radius_default.runtime_value, content="6")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--shadow-resting-small",
    )
    is Some(primer_shadow_small) else {
    fail("expected Primer small resting shadow runtime alignment")
  }
  assert_true(primer_shadow_small.source_imported)
  assert_true(primer_shadow_small.source_value_resolved)
  assert_true(primer_shadow_small.runtime_value_available)
  assert_true(primer_shadow_small.runtime_aligned)
  assert_true(primer_shadow_small.status == DesignTokenStatus::PreviewMapped)
  inspect(primer_shadow_small.runtime_value, content="1")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--shadow-resting-medium",
    )
    is Some(primer_shadow_medium) else {
    fail("expected Primer medium resting shadow runtime alignment")
  }
  assert_true(primer_shadow_medium.source_value_resolved)
  assert_true(primer_shadow_medium.runtime_value_available)
  assert_false(primer_shadow_medium.runtime_aligned)
  assert_true(primer_shadow_medium.status == DesignTokenStatus::PreviewMapped)
  inspect(primer_shadow_medium.expected_runtime_value, content="3")
  inspect(primer_shadow_medium.runtime_value, content="4")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--shadow-floating-large",
    )
    is Some(primer_shadow_large) else {
    fail("expected Primer large floating shadow runtime alignment")
  }
  assert_true(primer_shadow_large.source_value_resolved)
  assert_true(primer_shadow_large.runtime_value_available)
  assert_false(primer_shadow_large.runtime_aligned)
  assert_true(primer_shadow_large.status == DesignTokenStatus::PreviewMapped)
  inspect(primer_shadow_large.expected_runtime_value, content="40")
  inspect(primer_shadow_large.runtime_value, content="10")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--base-duration-0",
    )
    is Some(primer_duration_zero) else {
    fail("expected Primer 0ms duration runtime alignment")
  }
  assert_true(primer_duration_zero.source_imported)
  assert_true(primer_duration_zero.source_value_resolved)
  assert_true(primer_duration_zero.runtime_value_available)
  assert_false(primer_duration_zero.runtime_aligned)
  assert_true(primer_duration_zero.status == DesignTokenStatus::PreviewMapped)
  inspect(primer_duration_zero.expected_runtime_value, content="0")
  inspect(primer_duration_zero.runtime_value, content="100")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--base-duration-100",
    )
    is Some(primer_duration_fast) else {
    fail("expected Primer 100ms duration runtime alignment")
  }
  assert_true(primer_duration_fast.source_imported)
  assert_true(primer_duration_fast.source_value_resolved)
  assert_true(primer_duration_fast.runtime_value_available)
  assert_true(primer_duration_fast.runtime_aligned)
  inspect(primer_duration_fast.runtime_value, content="100")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--base-duration-200",
    )
    is Some(primer_duration_normal) else {
    fail("expected Primer 200ms duration runtime alignment")
  }
  assert_true(primer_duration_normal.source_imported)
  assert_true(primer_duration_normal.source_value_resolved)
  assert_true(primer_duration_normal.runtime_value_available)
  assert_false(primer_duration_normal.runtime_aligned)
  assert_true(primer_duration_normal.status == DesignTokenStatus::PreviewMapped)
  inspect(primer_duration_normal.expected_runtime_value, content="200")
  inspect(primer_duration_normal.runtime_value, content="160")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--base-duration-300",
    )
    is Some(primer_duration_slow) else {
    fail("expected Primer 300ms duration runtime alignment")
  }
  assert_true(primer_duration_slow.source_imported)
  assert_true(primer_duration_slow.source_value_resolved)
  assert_true(primer_duration_slow.runtime_value_available)
  assert_false(primer_duration_slow.runtime_aligned)
  assert_true(primer_duration_slow.status == DesignTokenStatus::PreviewMapped)
  inspect(primer_duration_slow.expected_runtime_value, content="300")
  inspect(primer_duration_slow.runtime_value, content="260")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--base-duration-1000",
    )
    is Some(primer_duration_long) else {
    fail("expected Primer 1000ms duration runtime alignment")
  }
  assert_true(primer_duration_long.source_imported)
  assert_true(primer_duration_long.source_value_resolved)
  assert_true(primer_duration_long.runtime_value_available)
  assert_false(primer_duration_long.runtime_aligned)
  assert_true(primer_duration_long.status == DesignTokenStatus::PreviewMapped)
  inspect(primer_duration_long.expected_runtime_value, content="1000")
  inspect(primer_duration_long.runtime_value, content="260")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--base-easing-linear",
    )
    is Some(primer_linear) else {
    fail("expected Primer linear easing runtime alignment")
  }
  assert_true(primer_linear.source_imported)
  assert_true(primer_linear.source_value_resolved)
  assert_true(primer_linear.runtime_value_available)
  assert_false(primer_linear.runtime_aligned)
  assert_true(primer_linear.status == DesignTokenStatus::PreviewMapped)
  inspect(primer_linear.expected_runtime_value, content="cubic-bezier(0,0,1,1)")
  inspect(primer_linear.runtime_value, content="ease-out")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--base-easing-easeOut",
    )
    is Some(primer_easing) else {
    fail("expected Primer easeOut runtime alignment")
  }
  assert_true(primer_easing.source_imported)
  assert_true(primer_easing.source_value_resolved)
  assert_true(primer_easing.runtime_value_available)
  assert_false(primer_easing.runtime_aligned)
  assert_true(primer_easing.status == DesignTokenStatus::PreviewMapped)
  inspect(
    primer_easing.expected_runtime_value,
    content="cubic-bezier(0.3,0.8,0.6,1)",
  )
  inspect(primer_easing.runtime_value, content="ease-out")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--base-easing-easeInOut",
    )
    is Some(primer_ease_in_out) else {
    fail("expected Primer easeInOut runtime alignment")
  }
  assert_true(primer_ease_in_out.source_imported)
  assert_true(primer_ease_in_out.source_value_resolved)
  assert_true(primer_ease_in_out.runtime_value_available)
  assert_false(primer_ease_in_out.runtime_aligned)
  assert_true(primer_ease_in_out.status == DesignTokenStatus::PreviewMapped)
  inspect(
    primer_ease_in_out.expected_runtime_value,
    content="cubic-bezier(0.6,0,0.2,1)",
  )
  inspect(primer_ease_in_out.runtime_value, content="ease-out")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--control-bgColor-rest",
    )
    is Some(primer_control) else {
    fail("expected Primer control rest background runtime alignment")
  }
  assert_true(primer_control.source_imported)
  assert_true(primer_control.source_value_resolved)
  assert_true(primer_control.runtime_value_available)
  assert_true(primer_control.runtime_aligned)
  assert_true(primer_control.status == DesignTokenStatus::ComponentMapped)
  assert_true(
    primer_control.moui_token == "DesignComponentTokens.picker.background",
  )
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--control-transparent-bgColor-hover",
    )
    is Some(primer_control_hover) else {
    fail("expected Primer transparent hover runtime alignment")
  }
  assert_true(primer_control_hover.source_imported)
  assert_true(primer_control_hover.source_value_resolved)
  assert_true(primer_control_hover.runtime_value_available)
  assert_false(primer_control_hover.runtime_aligned)
  assert_true(primer_control_hover.status == DesignTokenStatus::PreviewMapped)
  assert_true(
    primer_control_hover.expected_runtime_value !=
    primer_control_hover.runtime_value,
  )
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--control-borderColor-emphasis",
    )
    is Some(primer_control_border) else {
    fail("expected Primer control emphasized border runtime alignment")
  }
  assert_true(primer_control_border.source_imported)
  assert_true(primer_control_border.source_value_resolved)
  assert_true(primer_control_border.runtime_value_available)
  assert_false(primer_control_border.runtime_aligned)
  assert_true(primer_control_border.status == DesignTokenStatus::PreviewMapped)
  assert_true(
    primer_control_border.expected_runtime_value !=
    primer_control_border.runtime_value,
  )
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--bgColor-muted",
    )
    is Some(primer_surface) else {
    fail("expected Primer surface runtime alignment")
  }
  assert_true(primer_surface.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--bgColor-inset",
    )
    is Some(primer_surface_variant) else {
    fail("expected Primer surface-variant runtime alignment")
  }
  assert_true(primer_surface_variant.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--borderColor-default",
    )
    is Some(primer_outline) else {
    fail("expected Primer outline runtime alignment")
  }
  assert_true(primer_outline.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--fgColor-muted",
    )
    is Some(primer_muted) else {
    fail("expected Primer muted runtime alignment")
  }
  assert_true(primer_muted.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Primer,
      "--fgColor-danger",
    )
    is Some(primer_danger) else {
    fail("expected Primer danger runtime alignment")
  }
  assert_true(primer_danger.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Material,
      "--md-sys-color-primary",
    )
    is Some(material_primary) else {
    fail("expected Material primary runtime alignment row")
  }
  assert_true(material_primary.source_imported)
  assert_true(material_primary.source_value_resolved)
  assert_true(material_primary.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Material,
      "--md-sys-color-on-primary",
    )
    is Some(material_on_primary) else {
    fail("expected Material on-primary runtime alignment row")
  }
  assert_true(material_on_primary.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Material,
      "--md-sys-color-error",
    )
    is Some(material_error) else {
    fail("expected Material error runtime alignment row")
  }
  assert_true(material_error.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Material,
      "--md-sys-color-outline",
    )
    is Some(material_outline) else {
    fail("expected Material outline runtime alignment row")
  }
  assert_true(material_outline.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Material,
      "--md-filled-button-container-color",
    )
    is Some(material_button_container) else {
    fail("expected Material filled-button container runtime alignment row")
  }
  assert_true(material_button_container.source_imported)
  assert_true(material_button_container.source_value_resolved)
  assert_true(material_button_container.runtime_value_available)
  assert_true(material_button_container.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Material,
      "--md-filled-button-label-text-color",
    )
    is Some(material_button_label) else {
    fail("expected Material filled-button label runtime alignment row")
  }
  assert_true(material_button_label.source_imported)
  assert_true(material_button_label.source_value_resolved)
  assert_true(material_button_label.runtime_value_available)
  assert_true(material_button_label.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Material,
      "--md-filled-button-pressed-state-layer-opacity",
    )
    is Some(material_button_pressed) else {
    fail("expected Material filled-button pressed runtime alignment row")
  }
  assert_true(material_button_pressed.source_imported)
  assert_true(material_button_pressed.source_value_resolved)
  assert_true(material_button_pressed.runtime_value_available)
  assert_true(material_button_pressed.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Material,
      "--md-sys-typescale-body-medium-size",
    )
    is Some(material_body_size) else {
    fail("expected Material body type runtime alignment row")
  }
  assert_true(material_body_size.source_imported)
  assert_true(material_body_size.source_value_resolved)
  assert_true(material_body_size.runtime_value_available)
  assert_true(material_body_size.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Material,
      "--md-sys-shape-corner-medium",
    )
    is Some(material_corner) else {
    fail("expected Material medium corner runtime alignment row")
  }
  assert_true(material_corner.source_imported)
  assert_true(material_corner.source_value_resolved)
  assert_true(material_corner.runtime_value_available)
  assert_true(material_corner.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Material,
      "--md-sys-elevation-level1",
    )
    is Some(material_elevation) else {
    fail("expected Material level1 elevation runtime alignment row")
  }
  assert_true(material_elevation.source_imported)
  assert_true(material_elevation.source_value_resolved)
  assert_true(material_elevation.runtime_value_available)
  assert_true(material_elevation.runtime_aligned)
  inspect(material_elevation.runtime_value, content="1")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Material,
      "--md-sys-elevation-level3",
    )
    is Some(material_elevation_level3) else {
    fail("expected Material level3 elevation runtime alignment row")
  }
  assert_true(material_elevation_level3.source_imported)
  assert_true(material_elevation_level3.source_value_resolved)
  assert_true(material_elevation_level3.runtime_value_available)
  assert_true(material_elevation_level3.runtime_aligned)
  inspect(material_elevation_level3.runtime_value, content="6")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Material,
      "--md-sys-elevation-level5",
    )
    is Some(material_elevation_level5) else {
    fail("expected Material level5 elevation runtime alignment row")
  }
  assert_true(material_elevation_level5.source_imported)
  assert_true(material_elevation_level5.source_value_resolved)
  assert_true(material_elevation_level5.runtime_value_available)
  assert_true(material_elevation_level5.runtime_aligned)
  inspect(material_elevation_level5.runtime_value, content="12")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Material,
      "--md-sys-motion-duration-short4",
    )
    is Some(material_motion_short4) else {
    fail("expected Material short4 motion runtime alignment row")
  }
  assert_true(material_motion_short4.source_imported)
  assert_true(material_motion_short4.source_value_resolved)
  assert_true(material_motion_short4.runtime_value_available)
  assert_true(material_motion_short4.runtime_aligned)
  inspect(material_motion_short4.runtime_value, content="200")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Material,
      "--md-sys-motion-duration-medium2",
    )
    is Some(material_motion_medium2) else {
    fail("expected Material medium2 motion runtime alignment row")
  }
  assert_true(material_motion_medium2.source_imported)
  assert_true(material_motion_medium2.source_value_resolved)
  assert_true(material_motion_medium2.runtime_value_available)
  assert_true(material_motion_medium2.runtime_aligned)
  inspect(material_motion_medium2.runtime_value, content="300")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Material,
      "--md-sys-motion-duration-medium4",
    )
    is Some(material_motion_medium4) else {
    fail("expected Material medium4 motion runtime alignment row")
  }
  assert_true(material_motion_medium4.source_imported)
  assert_true(material_motion_medium4.source_value_resolved)
  assert_true(material_motion_medium4.runtime_value_available)
  assert_true(material_motion_medium4.runtime_aligned)
  inspect(material_motion_medium4.runtime_value, content="400")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Material,
      "--md-sys-motion-easing-standard",
    )
    is Some(material_motion_easing) else {
    fail("expected Material standard easing runtime alignment row")
  }
  assert_true(material_motion_easing.source_imported)
  assert_true(material_motion_easing.source_value_resolved)
  assert_true(material_motion_easing.runtime_value_available)
  assert_false(material_motion_easing.runtime_aligned)
  assert_true(material_motion_easing.status == DesignTokenStatus::PreviewMapped)
  inspect(
    material_motion_easing.expected_runtime_value,
    content="cubic-bezier(0.2,0,0,1)",
  )
  inspect(material_motion_easing.runtime_value, content="ease-out")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Material,
      "--md-sys-motion-*",
    )
    is Some(material_motion) else {
    fail("expected Material motion runtime alignment row")
  }
  assert_true(material_motion.source_imported)
  assert_true(material_motion.source_value_resolved)
  assert_true(material_motion.runtime_value_available)
  assert_true(material_motion.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Material,
      "--md-linear-progress-active-indicator-color",
    )
    is Some(material_progress) else {
    fail("expected Material progress runtime alignment row")
  }
  assert_true(material_progress.source_imported)
  assert_true(material_progress.source_value_resolved)
  assert_true(material_progress.runtime_value_available)
  assert_true(material_progress.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Material,
      "--md-menu-container-color",
    )
    is Some(material_menu) else {
    fail("expected Material menu runtime alignment row")
  }
  assert_true(material_menu.source_imported)
  assert_true(material_menu.source_value_resolved)
  assert_true(material_menu.runtime_value_available)
  assert_true(material_menu.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Material,
      "--md-sys-spacing-*",
    )
    is Some(material_spacing) else {
    fail("expected Material spacing runtime alignment gap")
  }
  assert_false(material_spacing.source_imported)
  assert_false(material_spacing.required)
  assert_false(material_spacing.runtime_aligned)
  guard runtime_token_alignment_for(@common.DesignPreset::Carbon, "$background")
    is Some(carbon_background) else {
    fail("expected Carbon background runtime alignment row")
  }
  assert_true(carbon_background.source_imported)
  assert_true(carbon_background.source_value_resolved)
  assert_true(carbon_background.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Carbon,
      "$text-primary",
    )
    is Some(carbon_text) else {
    fail("expected Carbon text runtime alignment row")
  }
  assert_true(carbon_text.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Carbon,
      "$support-error",
    )
    is Some(carbon_error) else {
    fail("expected Carbon support-error runtime alignment row")
  }
  assert_true(carbon_error.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Carbon,
      "$button-primary",
    )
    is Some(carbon_button) else {
    fail("expected Carbon button-primary runtime alignment row")
  }
  assert_true(carbon_button.source_imported)
  assert_true(carbon_button.source_value_resolved)
  assert_true(carbon_button.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Carbon,
      "$background-hover",
    )
    is Some(carbon_hover) else {
    fail("expected Carbon background-hover runtime alignment row")
  }
  assert_true(carbon_hover.source_imported)
  assert_true(carbon_hover.source_value_resolved)
  assert_true(carbon_hover.runtime_value_available)
  assert_true(carbon_hover.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Carbon,
      "$border-interactive",
    )
    is Some(carbon_border) else {
    fail("expected Carbon border-interactive runtime alignment row")
  }
  assert_true(carbon_border.source_imported)
  assert_true(carbon_border.source_value_resolved)
  assert_true(carbon_border.runtime_value_available)
  assert_true(carbon_border.runtime_aligned)
  guard runtime_token_alignment_for(@common.DesignPreset::Carbon, "$field")
    is Some(carbon_field) else {
    fail("expected Carbon field runtime alignment row")
  }
  assert_true(carbon_field.source_imported)
  assert_true(carbon_field.source_value_resolved)
  assert_true(carbon_field.runtime_value_available)
  assert_true(carbon_field.runtime_aligned)
  guard runtime_token_alignment_for(
      @common.DesignPreset::Carbon,
      "$slider-filled-track",
    )
    is Some(carbon_slider) else {
    fail("expected Carbon slider filled-track runtime alignment row")
  }
  assert_true(carbon_slider.source_imported)
  assert_true(carbon_slider.source_value_resolved)
  assert_true(carbon_slider.runtime_value_available)
  assert_true(carbon_slider.runtime_aligned)
  assert_true(carbon_slider.status == DesignTokenStatus::ComponentMapped)
  assert_carbon_mapped_spacing_runtime_alignment("$spacing-01", "2")
  assert_carbon_preview_spacing_runtime_alignment("$spacing-02", "4", "2")
  assert_carbon_mapped_spacing_runtime_alignment("$spacing-03", "8")
  assert_carbon_mapped_spacing_runtime_alignment("$spacing-04", "12")
  assert_carbon_mapped_spacing_runtime_alignment("$spacing-05", "16")
  assert_carbon_mapped_spacing_runtime_alignment("$spacing-06", "24")
  assert_carbon_preview_spacing_runtime_alignment("$spacing-07", "32", "24")
  assert_carbon_preview_spacing_runtime_alignment("$spacing-08", "40", "24")
  assert_carbon_preview_spacing_runtime_alignment("$spacing-09", "48", "24")
  assert_carbon_preview_spacing_runtime_alignment("$spacing-10", "64", "24")
  assert_carbon_preview_spacing_runtime_alignment("$spacing-11", "80", "24")
  assert_carbon_preview_spacing_runtime_alignment("$spacing-12", "96", "24")
  assert_carbon_preview_spacing_runtime_alignment("$spacing-13", "160", "24")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Carbon,
      "$duration-fast-01",
    )
    is Some(carbon_duration_fast01) else {
    fail("expected Carbon fast-01 duration runtime alignment row")
  }
  assert_true(carbon_duration_fast01.source_imported)
  assert_true(carbon_duration_fast01.source_value_resolved)
  assert_true(carbon_duration_fast01.runtime_value_available)
  assert_false(carbon_duration_fast01.runtime_aligned)
  assert_true(carbon_duration_fast01.status == DesignTokenStatus::PreviewMapped)
  inspect(carbon_duration_fast01.expected_runtime_value, content="70")
  inspect(carbon_duration_fast01.runtime_value, content="90")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Carbon,
      "$duration-fast-02",
    )
    is Some(carbon_duration_fast) else {
    fail("expected Carbon fast duration runtime alignment row")
  }
  assert_true(carbon_duration_fast.source_imported)
  assert_true(carbon_duration_fast.source_value_resolved)
  assert_true(carbon_duration_fast.runtime_value_available)
  assert_false(carbon_duration_fast.runtime_aligned)
  assert_true(carbon_duration_fast.status == DesignTokenStatus::PreviewMapped)
  inspect(carbon_duration_fast.expected_runtime_value, content="110")
  inspect(carbon_duration_fast.runtime_value, content="90")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Carbon,
      "$duration-moderate-01",
    )
    is Some(carbon_duration_normal) else {
    fail("expected Carbon moderate-01 duration runtime alignment row")
  }
  assert_true(carbon_duration_normal.source_imported)
  assert_true(carbon_duration_normal.source_value_resolved)
  assert_true(carbon_duration_normal.runtime_value_available)
  assert_true(carbon_duration_normal.runtime_aligned)
  inspect(carbon_duration_normal.runtime_value, content="150")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Carbon,
      "$duration-moderate-02",
    )
    is Some(carbon_duration_slow) else {
    fail("expected Carbon moderate-02 duration runtime alignment row")
  }
  assert_true(carbon_duration_slow.source_imported)
  assert_true(carbon_duration_slow.source_value_resolved)
  assert_true(carbon_duration_slow.runtime_value_available)
  assert_true(carbon_duration_slow.runtime_aligned)
  inspect(carbon_duration_slow.runtime_value, content="240")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Carbon,
      "$duration-slow-02",
    )
    is Some(carbon_duration_slow02) else {
    fail("expected Carbon slow-02 duration runtime alignment row")
  }
  assert_true(carbon_duration_slow02.source_imported)
  assert_true(carbon_duration_slow02.source_value_resolved)
  assert_true(carbon_duration_slow02.runtime_value_available)
  assert_false(carbon_duration_slow02.runtime_aligned)
  assert_true(carbon_duration_slow02.status == DesignTokenStatus::PreviewMapped)
  inspect(carbon_duration_slow02.expected_runtime_value, content="700")
  inspect(carbon_duration_slow02.runtime_value, content="240")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Carbon,
      "easings.standard.productive",
    )
    is Some(carbon_easing) else {
    fail("expected Carbon standard productive easing runtime alignment row")
  }
  assert_true(carbon_easing.source_imported)
  assert_true(carbon_easing.source_value_resolved)
  assert_true(carbon_easing.runtime_value_available)
  assert_false(carbon_easing.runtime_aligned)
  assert_true(carbon_easing.status == DesignTokenStatus::PreviewMapped)
  inspect(
    carbon_easing.expected_runtime_value,
    content="cubic-bezier(0.2,0,0.38,0.9)",
  )
  inspect(carbon_easing.runtime_value, content="ease-in-out")
  guard runtime_token_alignment_for(
      @common.DesignPreset::Carbon,
      "easings.exit.expressive",
    )
    is Some(carbon_easing_exit) else {
    fail("expected Carbon expressive exit easing runtime alignment row")
  }
  assert_true(carbon_easing_exit.source_imported)
  assert_true(carbon_easing_exit.source_value_resolved)
  assert_true(carbon_easing_exit.runtime_value_available)
  assert_false(carbon_easing_exit.runtime_aligned)
  assert_true(carbon_easing_exit.status == DesignTokenStatus::PreviewMapped)
  inspect(
    carbon_easing_exit.expected_runtime_value,
    content="cubic-bezier(0.4,0.14,1,1)",
  )
  inspect(carbon_easing_exit.runtime_value, content="ease-in-out")
}

///|
