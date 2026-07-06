///|
fn assert_fluent_preview_curve_source_import(
  token : String,
  expected_source_value : String,
) -> Unit raise {
  guard source_import_coverage_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected Fluent curve source-import coverage for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.golden_mapped)
  assert_true(row.source_file.contains("curves.ts"))
  assert_true(row.source_sha == "51486dbdaaecc0cf2c152502ed48717bf537b1eb")
  assert_true(row.source_value.contains(expected_source_value))
  assert_true(row.moui_token == "DesignMotionTokens.easing")
  assert_true(row.status == PreviewMapped)
  guard source_import_integrity_for(@common.DesignPreset::Fluent, token)
    is Some(integrity) else {
    fail("expected Fluent curve integrity record for " + token)
  }
  assert_true(integrity.integrity_ok)
  assert_true(integrity.moui_token_matches_golden)
}

///|
fn assert_fluent_preview_global_color_source_import(
  token : String,
  expected_source_value : String,
  moui_token : String,
) -> Unit raise {
  guard source_import_coverage_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected Fluent global color source-import coverage for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.golden_mapped)
  assert_true(row.source_file.contains("colors.ts"))
  assert_true(row.source_sha == "e8744d569ba821d013ab3f4cec0c319c16c6da50")
  assert_true(row.source_value.contains(expected_source_value))
  assert_true(row.moui_token == moui_token)
  // Source-import status: red/green/darkOrange/blue are ThemeMapped (MoUI
  // matches the source value); the secondary status colors are PreviewMapped
  // (MoUI maps to a nearby neutral). This is independent of runtime alignment.
  assert_true(row.status == fluent_global_color_source_import_status(token))
  guard source_import_integrity_for(@common.DesignPreset::Fluent, token)
    is Some(integrity) else {
    fail("expected Fluent global color integrity record for " + token)
  }
  assert_true(integrity.integrity_ok)
  assert_true(integrity.moui_token_matches_golden)
}

///|
fn assert_fluent_preview_global_color_runtime_alignment(
  token : String,
  expected_runtime_value : String,
) -> Unit raise {
  guard runtime_token_alignment_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected Fluent global color runtime alignment for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.source_value_resolved)
  assert_true(row.runtime_value_available)
  if fluent_global_color_runtime_aligned(token) {
    assert_true(row.runtime_aligned)
    assert_true(row.status == DesignTokenStatus::ThemeMapped)
  } else {
    assert_false(row.runtime_aligned)
    assert_true(row.status == DesignTokenStatus::PreviewMapped)
  }
  inspect(row.expected_runtime_value, content=expected_runtime_value)
}

///|
fn assert_fluent_preview_global_color_official_coverage(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard official_token_coverage_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected Fluent global color official coverage for " + token)
  }
  assert_true(row.mapped)
  assert_true(row.source_declared)
  assert_true(row.source_locked)
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == fluent_global_color_source_import_status(token))
}

///|
fn assert_fluent_preview_global_color_golden_mapping(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard golden_mapping_for(@common.DesignPreset::Fluent, token) is Some(row) else {
    fail("expected Fluent global color golden mapping for " + token)
  }
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == fluent_global_color_source_import_status(token))
}

///|
fn fluent_global_color_runtime_aligned(token : String) -> Bool {
  // Fluent 2 maps semantic slots to status-background tokens that differ from
  // the pinned Fluent global color primaries. `green.primary` still matches
  // success (#107c10); the others now use Fluent 2 status backgrounds
  // (#0f6cbd/#b10f0e/#8a5400) that intentionally differ from the global
  // primaries (blue/red/darkOrange), so they stay as preview-mapped.
  token == "green.primary"
}

///|
/// Source-import status mirrors the pinned imported-token record: the four
/// primary status colors (red/green/darkOrange/blue) are ThemeMapped; the
/// secondary shades (lightGreen/cranberry/orange/yellow/marigold) are
/// PreviewMapped because MoUI maps the semantic slot to a nearby neutral.
fn fluent_global_color_source_import_status(
  token : String,
) -> DesignTokenStatus {
  match token {
    "red.primary" | "green.primary" | "darkOrange.primary" | "blue.primary" =>
      DesignTokenStatus::ThemeMapped
    _ => DesignTokenStatus::PreviewMapped
  }
}

///|
fn assert_fluent_preview_typography_source_import(
  token : String,
  expected_source_value : String,
  moui_token : String,
) -> Unit raise {
  guard source_import_coverage_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected Fluent typography source-import coverage for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.golden_mapped)
  assert_true(row.source_file.contains("fonts.ts"))
  assert_true(row.source_sha == "9b8dca7bf3dc8b7faf4e2628b4eeda574bae91b3")
  assert_true(row.source_value.contains(expected_source_value))
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == PreviewMapped)
  guard source_import_integrity_for(@common.DesignPreset::Fluent, token)
    is Some(integrity) else {
    fail("expected Fluent typography integrity record for " + token)
  }
  assert_true(integrity.integrity_ok)
  assert_true(integrity.moui_token_matches_golden)
}

///|
fn assert_fluent_mapped_typography_source_import(
  token : String,
  expected_source_value : String,
  moui_token : String,
) -> Unit raise {
  guard source_import_coverage_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail(
      "expected mapped Fluent typography source-import coverage for " + token,
    )
  }
  assert_true(row.source_imported)
  assert_true(row.golden_mapped)
  assert_true(row.source_file.contains("fonts.ts"))
  assert_true(row.source_sha == "9b8dca7bf3dc8b7faf4e2628b4eeda574bae91b3")
  assert_true(row.source_value.contains(expected_source_value))
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == ThemeMapped)
  guard source_import_integrity_for(@common.DesignPreset::Fluent, token)
    is Some(integrity) else {
    fail("expected mapped Fluent typography integrity record for " + token)
  }
  assert_true(integrity.integrity_ok)
  assert_true(integrity.moui_token_matches_golden)
}

///|
fn assert_fluent_preview_typography_runtime_alignment(
  token : String,
  expected_runtime_value : String,
  runtime_value : String,
) -> Unit raise {
  guard runtime_token_alignment_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected Fluent typography runtime alignment for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.source_value_resolved)
  assert_true(row.runtime_value_available)
  assert_false(row.runtime_aligned)
  assert_true(row.status == PreviewMapped)
  inspect(row.expected_runtime_value, content=expected_runtime_value)
  inspect(row.runtime_value, content=runtime_value)
}

///|
fn assert_fluent_typography_destination_gap(
  token : String,
  expected_runtime_value : String,
) -> Unit raise {
  guard runtime_token_alignment_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected Fluent typography destination gap for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.source_value_resolved)
  assert_false(row.runtime_value_available)
  assert_false(row.runtime_aligned)
  assert_true(row.status == NotMapped)
  inspect(row.expected_runtime_value, content=expected_runtime_value)
}

///|
fn assert_fluent_mapped_typography_runtime_alignment(
  token : String,
  runtime_value : String,
) -> Unit raise {
  guard runtime_token_alignment_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected mapped Fluent typography runtime alignment for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.source_value_resolved)
  assert_true(row.runtime_value_available)
  assert_true(row.runtime_aligned)
  assert_true(row.status == ThemeMapped)
  inspect(row.runtime_value, content=runtime_value)
}

///|
fn assert_fluent_preview_typography_official_coverage(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard official_token_coverage_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected Fluent typography official token coverage for " + token)
  }
  assert_true(row.mapped)
  assert_true(row.source_declared)
  assert_true(row.source_locked)
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == PreviewMapped)
}

///|
fn assert_fluent_mapped_typography_official_coverage(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard official_token_coverage_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail(
      "expected mapped Fluent typography official token coverage for " + token,
    )
  }
  assert_true(row.mapped)
  assert_true(row.source_declared)
  assert_true(row.source_locked)
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == ThemeMapped)
}

///|
fn assert_fluent_preview_typography_golden_mapping(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard golden_mapping_for(@common.DesignPreset::Fluent, token) is Some(row) else {
    fail("expected Fluent typography golden mapping for " + token)
  }
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == PreviewMapped)
}

///|
fn assert_fluent_mapped_typography_golden_mapping(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard golden_mapping_for(@common.DesignPreset::Fluent, token) is Some(row) else {
    fail("expected mapped Fluent typography golden mapping for " + token)
  }
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == ThemeMapped)
}

///|
fn assert_fluent_mapped_stroke_width_source_import(
  token : String,
  expected_source_value : String,
  moui_token : String,
) -> Unit raise {
  guard source_import_coverage_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail(
      "expected mapped Fluent stroke-width source-import coverage for " + token,
    )
  }
  assert_true(row.source_imported)
  assert_true(row.golden_mapped)
  assert_true(row.source_file.contains("strokeWidths.ts"))
  assert_true(row.source_sha == "6cc868a3551b1b3b87f64b3df4fe9e56edf98ad4")
  assert_true(row.source_value.contains(expected_source_value))
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == ComponentMapped)
  guard source_import_integrity_for(@common.DesignPreset::Fluent, token)
    is Some(integrity) else {
    fail("expected mapped Fluent stroke-width integrity record for " + token)
  }
  assert_true(integrity.integrity_ok)
  assert_true(integrity.moui_token_matches_golden)
}

///|
fn assert_fluent_preview_stroke_width_source_import(
  token : String,
  expected_source_value : String,
  moui_token : String,
) -> Unit raise {
  guard source_import_coverage_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected Fluent stroke-width source-import coverage for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.golden_mapped)
  assert_true(row.source_file.contains("strokeWidths.ts"))
  assert_true(row.source_sha == "6cc868a3551b1b3b87f64b3df4fe9e56edf98ad4")
  assert_true(row.source_value.contains(expected_source_value))
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == PreviewMapped)
  guard source_import_integrity_for(@common.DesignPreset::Fluent, token)
    is Some(integrity) else {
    fail("expected Fluent stroke-width integrity record for " + token)
  }
  assert_true(integrity.integrity_ok)
  assert_true(integrity.moui_token_matches_golden)
}

///|
fn assert_fluent_mapped_stroke_width_runtime_alignment(
  token : String,
  runtime_value : String,
) -> Unit raise {
  guard runtime_token_alignment_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected mapped Fluent stroke-width runtime alignment for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.source_value_resolved)
  assert_true(row.runtime_value_available)
  assert_true(row.runtime_aligned)
  assert_true(row.status == ComponentMapped)
  inspect(row.runtime_value, content=runtime_value)
}

///|
fn assert_fluent_preview_stroke_width_runtime_alignment(
  token : String,
  expected_runtime_value : String,
  runtime_value : String,
) -> Unit raise {
  guard runtime_token_alignment_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected Fluent stroke-width runtime alignment for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.source_value_resolved)
  assert_true(row.runtime_value_available)
  assert_false(row.runtime_aligned)
  assert_true(row.status == PreviewMapped)
  inspect(row.expected_runtime_value, content=expected_runtime_value)
  inspect(row.runtime_value, content=runtime_value)
}

///|
fn assert_fluent_mapped_stroke_width_official_coverage(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard official_token_coverage_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected mapped Fluent stroke-width official coverage for " + token)
  }
  assert_true(row.mapped)
  assert_true(row.source_declared)
  assert_true(row.source_locked)
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == ComponentMapped)
}

///|
fn assert_fluent_preview_stroke_width_official_coverage(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard official_token_coverage_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected Fluent stroke-width official coverage for " + token)
  }
  assert_true(row.mapped)
  assert_true(row.source_declared)
  assert_true(row.source_locked)
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == PreviewMapped)
}

///|
fn assert_fluent_mapped_stroke_width_golden_mapping(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard golden_mapping_for(@common.DesignPreset::Fluent, token) is Some(row) else {
    fail("expected mapped Fluent stroke-width golden mapping for " + token)
  }
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == ComponentMapped)
}

///|
fn assert_fluent_preview_stroke_width_golden_mapping(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard golden_mapping_for(@common.DesignPreset::Fluent, token) is Some(row) else {
    fail("expected Fluent stroke-width golden mapping for " + token)
  }
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == PreviewMapped)
}

///|
fn assert_fluent_preview_curve_runtime_alignment(
  token : String,
  expected_runtime_value : String,
) -> Unit raise {
  guard runtime_token_alignment_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected Fluent curve runtime alignment for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.source_value_resolved)
  assert_true(row.runtime_value_available)
  assert_false(row.runtime_aligned)
  assert_true(row.status == DesignTokenStatus::PreviewMapped)
  inspect(row.expected_runtime_value, content=expected_runtime_value)
  inspect(row.runtime_value, content="ease-in-out")
}

///|
fn assert_fluent_preview_curve_official_coverage(token : String) -> Unit raise {
  guard official_token_coverage_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected Fluent curve official token coverage for " + token)
  }
  assert_true(row.mapped)
  assert_true(row.source_declared)
  assert_true(row.source_locked)
  assert_true(row.moui_token == "DesignMotionTokens.easing")
  assert_true(row.status == DesignTokenStatus::PreviewMapped)
}

///|
fn assert_fluent_preview_curve_golden_mapping(token : String) -> Unit raise {
  guard golden_mapping_for(@common.DesignPreset::Fluent, token) is Some(row) else {
    fail("expected Fluent curve golden mapping for " + token)
  }
  assert_true(row.moui_token == "DesignMotionTokens.easing")
  assert_true(row.status == DesignTokenStatus::PreviewMapped)
}

///|
fn assert_carbon_mapped_layout_source_import(
  token : String,
  expected_source_token : String,
  expected_mini_units : String,
  expected_px : String,
  moui_token : String,
) -> Unit raise {
  guard source_import_coverage_for(@common.DesignPreset::Carbon, token)
    is Some(row) else {
    fail("expected Carbon layout source-import coverage for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.golden_mapped)
  assert_true(row.source_file.contains("packages/layout/src/index.ts"))
  assert_true(row.source_sha == "4aebba452911641c1e8dbe5a9e27f1c160c5bf15")
  assert_true(row.source_value.contains(expected_source_token))
  assert_true(row.source_value.contains(expected_mini_units))
  assert_true(row.source_value.contains(expected_px))
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == DesignTokenStatus::ThemeMapped)
  guard source_import_integrity_for(@common.DesignPreset::Carbon, token)
    is Some(integrity) else {
    fail("expected Carbon layout integrity record for " + token)
  }
  assert_true(integrity.integrity_ok)
  assert_true(integrity.moui_token_matches_golden)
}

///|
fn assert_carbon_preview_layout_source_import(
  token : String,
  expected_source_token : String,
  expected_mini_units : String,
  expected_px : String,
  moui_token : String,
) -> Unit raise {
  guard source_import_coverage_for(@common.DesignPreset::Carbon, token)
    is Some(row) else {
    fail("expected Carbon preview layout source-import coverage for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.golden_mapped)
  assert_true(row.source_file.contains("packages/layout/src/index.ts"))
  assert_true(row.source_sha == "4aebba452911641c1e8dbe5a9e27f1c160c5bf15")
  assert_true(row.source_value.contains(expected_source_token))
  assert_true(row.source_value.contains(expected_mini_units))
  assert_true(row.source_value.contains(expected_px))
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == DesignTokenStatus::PreviewMapped)
  guard source_import_integrity_for(@common.DesignPreset::Carbon, token)
    is Some(integrity) else {
    fail("expected Carbon preview layout integrity record for " + token)
  }
  assert_true(integrity.integrity_ok)
  assert_true(integrity.moui_token_matches_golden)
}

///|
fn assert_carbon_mapped_spacing_runtime_alignment(
  token : String,
  runtime_value : String,
) -> Unit raise {
  guard runtime_token_alignment_for(@common.DesignPreset::Carbon, token)
    is Some(row) else {
    fail("expected Carbon spacing runtime alignment for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.source_value_resolved)
  assert_true(row.runtime_value_available)
  assert_true(row.runtime_aligned)
  assert_true(row.status == DesignTokenStatus::ThemeMapped)
  inspect(row.runtime_value, content=runtime_value)
}

///|
fn assert_carbon_preview_spacing_runtime_alignment(
  token : String,
  expected_runtime_value : String,
  runtime_value : String,
) -> Unit raise {
  guard runtime_token_alignment_for(@common.DesignPreset::Carbon, token)
    is Some(row) else {
    fail("expected Carbon preview spacing runtime alignment for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.source_value_resolved)
  assert_true(row.runtime_value_available)
  assert_false(row.runtime_aligned)
  assert_true(row.status == DesignTokenStatus::PreviewMapped)
  inspect(row.expected_runtime_value, content=expected_runtime_value)
  inspect(row.runtime_value, content=runtime_value)
}

///|
fn assert_carbon_mapped_spacing_official_coverage(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard official_token_coverage_for(@common.DesignPreset::Carbon, token)
    is Some(row) else {
    fail("expected Carbon spacing official token coverage for " + token)
  }
  assert_true(row.mapped)
  assert_true(row.source_declared)
  assert_true(row.source_locked)
  assert_true(row.source_kind == "official-source")
  assert_true(row.token_path == "packages/layout")
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == DesignTokenStatus::ThemeMapped)
}

///|
fn assert_carbon_preview_spacing_official_coverage(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard official_token_coverage_for(@common.DesignPreset::Carbon, token)
    is Some(row) else {
    fail("expected Carbon preview spacing official token coverage for " + token)
  }
  assert_true(row.mapped)
  assert_true(row.source_declared)
  assert_true(row.source_locked)
  assert_true(row.source_kind == "official-source")
  assert_true(row.token_path == "packages/layout")
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == DesignTokenStatus::PreviewMapped)
}

///|
fn assert_carbon_mapped_spacing_golden_mapping(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard golden_mapping_for(@common.DesignPreset::Carbon, token) is Some(row) else {
    fail("expected Carbon spacing golden mapping for " + token)
  }
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == DesignTokenStatus::ThemeMapped)
}

///|
fn assert_carbon_preview_spacing_golden_mapping(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard golden_mapping_for(@common.DesignPreset::Carbon, token) is Some(row) else {
    fail("expected Carbon preview spacing golden mapping for " + token)
  }
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == DesignTokenStatus::PreviewMapped)
}

///|
fn assert_fluent_preview_spacing_source_import(
  token : String,
  expected_source_value : String,
  moui_token : String,
) -> Unit raise {
  guard source_import_coverage_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected Fluent spacing source-import coverage for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.golden_mapped)
  assert_true(row.source_file.contains("spacings.ts"))
  assert_true(row.source_sha == "fa5df4c81834b5abfb508d2317e4c50eff101d1c")
  assert_true(row.source_value.contains(expected_source_value))
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == DesignTokenStatus::PreviewMapped)
  guard source_import_integrity_for(@common.DesignPreset::Fluent, token)
    is Some(integrity) else {
    fail("expected Fluent spacing integrity record for " + token)
  }
  assert_true(integrity.integrity_ok)
  assert_true(integrity.moui_token_matches_golden)
}

///|
fn assert_fluent_preview_spacing_runtime_alignment(
  token : String,
  expected_runtime_value : String,
  runtime_value : String,
) -> Unit raise {
  guard runtime_token_alignment_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected Fluent spacing runtime alignment for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.source_value_resolved)
  assert_true(row.runtime_value_available)
  assert_false(row.runtime_aligned)
  assert_true(row.status == DesignTokenStatus::PreviewMapped)
  inspect(row.expected_runtime_value, content=expected_runtime_value)
  inspect(row.runtime_value, content=runtime_value)
}

///|
fn assert_fluent_preview_spacing_official_coverage(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard official_token_coverage_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected Fluent spacing official token coverage for " + token)
  }
  assert_true(row.mapped)
  assert_true(row.source_declared)
  assert_true(row.source_locked)
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == DesignTokenStatus::PreviewMapped)
}

///|
fn assert_fluent_preview_spacing_golden_mapping(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard golden_mapping_for(@common.DesignPreset::Fluent, token) is Some(row) else {
    fail("expected Fluent spacing golden mapping for " + token)
  }
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == DesignTokenStatus::PreviewMapped)
}

///|
fn assert_fluent_mapped_spacing_source_import(
  token : String,
  expected_source_value : String,
  moui_token : String,
) -> Unit raise {
  guard source_import_coverage_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected mapped Fluent spacing source-import coverage for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.golden_mapped)
  assert_true(row.source_file.contains("spacings.ts"))
  assert_true(row.source_sha == "fa5df4c81834b5abfb508d2317e4c50eff101d1c")
  assert_true(row.source_value.contains(expected_source_value))
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == DesignTokenStatus::ThemeMapped)
  guard source_import_integrity_for(@common.DesignPreset::Fluent, token)
    is Some(integrity) else {
    fail("expected mapped Fluent spacing integrity record for " + token)
  }
  assert_true(integrity.integrity_ok)
  assert_true(integrity.moui_token_matches_golden)
}

///|
fn assert_fluent_mapped_spacing_runtime_alignment(
  token : String,
  runtime_value : String,
) -> Unit raise {
  guard runtime_token_alignment_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected mapped Fluent spacing runtime alignment for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.source_value_resolved)
  assert_true(row.runtime_value_available)
  assert_true(row.runtime_aligned)
  assert_true(row.status == DesignTokenStatus::ThemeMapped)
  inspect(row.runtime_value, content=runtime_value)
}

///|
fn assert_fluent_mapped_spacing_official_coverage(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard official_token_coverage_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected mapped Fluent spacing official token coverage for " + token)
  }
  assert_true(row.mapped)
  assert_true(row.source_declared)
  assert_true(row.source_locked)
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == DesignTokenStatus::ThemeMapped)
}

///|
fn assert_fluent_mapped_spacing_golden_mapping(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard golden_mapping_for(@common.DesignPreset::Fluent, token) is Some(row) else {
    fail("expected mapped Fluent spacing golden mapping for " + token)
  }
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == DesignTokenStatus::ThemeMapped)
}

///|
fn assert_fluent_preview_radius_source_import(
  token : String,
  expected_source_value : String,
  moui_token : String,
) -> Unit raise {
  guard source_import_coverage_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected Fluent radius source-import coverage for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.golden_mapped)
  assert_true(row.source_file.contains("borderRadius.ts"))
  assert_true(row.source_sha == "64523745129486fad856000b0443b55d47a21e9f")
  assert_true(row.source_value.contains(expected_source_value))
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == DesignTokenStatus::PreviewMapped)
  guard source_import_integrity_for(@common.DesignPreset::Fluent, token)
    is Some(integrity) else {
    fail("expected Fluent radius integrity record for " + token)
  }
  assert_true(integrity.integrity_ok)
  assert_true(integrity.moui_token_matches_golden)
}

///|
fn assert_fluent_preview_radius_runtime_alignment(
  token : String,
  expected_runtime_value : String,
  runtime_value : String,
) -> Unit raise {
  guard runtime_token_alignment_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected Fluent radius runtime alignment for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.source_value_resolved)
  assert_true(row.runtime_value_available)
  assert_false(row.runtime_aligned)
  assert_true(row.status == DesignTokenStatus::PreviewMapped)
  inspect(row.expected_runtime_value, content=expected_runtime_value)
  inspect(row.runtime_value, content=runtime_value)
}

///|
fn assert_fluent_preview_radius_official_coverage(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard official_token_coverage_for(@common.DesignPreset::Fluent, token)
    is Some(row) else {
    fail("expected Fluent radius official token coverage for " + token)
  }
  assert_true(row.mapped)
  assert_true(row.source_declared)
  assert_true(row.source_locked)
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == DesignTokenStatus::PreviewMapped)
}

///|
fn assert_fluent_preview_radius_golden_mapping(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard golden_mapping_for(@common.DesignPreset::Fluent, token) is Some(row) else {
    fail("expected Fluent radius golden mapping for " + token)
  }
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == DesignTokenStatus::PreviewMapped)
}
