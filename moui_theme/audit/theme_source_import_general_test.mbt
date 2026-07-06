///|
test "source imported tokens expose pinned source values without claiming full import" {
  for
    preset in [
      @common.DesignPreset::Material,
      @common.DesignPreset::Carbon,
      @common.DesignPreset::Primer,
      @common.DesignPreset::Fluent,
    ] {
    let rows = source_imported_tokens(preset)
    assert_true(rows.length() > 0)
    assert_true(source_imported_token_count(preset) == rows.length())
    assert_true(source_imported_token_mapped_count(preset) > 0)
    assert_true(source_imported_token_source_lock_gap_count(preset) == 0)
    assert_true(
      source_import_coverage_count(preset) ==
      official_token_anchor_count(preset),
    )
    assert_true(source_imported_official_token_count(preset) > 0)
    assert_true(source_import_coverage_gap_count(preset) == 0)
    assert_true(source_import_unanchored_count(preset) == 0)
    assert_true(source_import_integrity_gap_count(preset) == 0)
    assert_true(source_import_manifest_lock_gap_count(preset) == 0)
    assert_true(source_import_scope_gap_count(preset) == 0)
    assert_true(source_import_anchor_mismatch_count(preset) == 0)
    assert_true(source_import_golden_mismatch_count(preset) == 0)
    assert_true(
      runtime_token_alignment_count(preset) ==
      official_token_anchor_count(preset),
    )
    assert_true(runtime_token_alignment_gap_count(preset) > 0)
    assert_true(source_package_import_gap_count(preset) > 0)
    assert_false(is_design_system_complete(preset))
    for item in rows {
      assert_true(item.source_url != "")
      assert_true(item.source_ref != "")
      assert_true(item.token_path != "")
      assert_true(item.package_path != "")
      assert_true(item.source_file != "")
      assert_true(item.source_sha != "")
      assert_true(item.source_value != "")
      assert_true(item.moui_token != "")
      assert_true(item.official_token != "")
      assert_false(item.source_file.contains("moui/core"))
    }
    for item in source_import_coverage(preset) {
      assert_true(item.official_token != "")
      let material_spacing_placeholder = preset ==
        @common.DesignPreset::Material &&
        item.official_token == "--md-sys-spacing-*"
      if material_spacing_placeholder {
        assert_false(item.required)
      } else {
        assert_true(item.required)
      }
      if item.source_imported {
        assert_true(item.source_file != "")
        assert_true(item.source_sha != "")
        assert_true(item.source_value != "")
      }
    }
    for item in source_import_integrity_report(preset) {
      assert_true(item.integrity_ok)
      assert_true(item.source_declared)
      assert_true(item.source_locked)
      assert_true(item.source_file_scoped)
      assert_true(item.anchor_declared)
      assert_true(item.category_compatible)
      assert_true(item.layer_compatible)
      assert_true(item.moui_token_matches_golden)
      if item.golden_mapped {
        assert_true(item.golden_moui_token == item.moui_token)
      }
    }
  }
}
