///|
test "design presets preserve scheme and expose distinct tokens" {
  let material = @common.preset(@common.DesignPreset::Material)
  let carbon = @common.preset(@common.DesignPreset::Carbon)
  assert_true(material.scheme == @core.ColorScheme::Light)
  assert_true(carbon.scheme == @core.ColorScheme::Light)
  assert_true(material.palette.primary != carbon.palette.primary)
  assert_true(material.radius_scale.md != carbon.radius_scale.md)
}

///|
test "design presets support dark variants" {
  let light = @common.DesignPreset::Primer.theme()
  let dark = @common.DesignPreset::Primer.theme(scheme=@core.ColorScheme::Dark)
  assert_true(light.scheme == @core.ColorScheme::Light)
  assert_true(dark.scheme == @core.ColorScheme::Dark)
  assert_true(light.palette.background != dark.palette.background)
  assert_true(light.palette.primary != dark.palette.primary)
}

///|
test "custom theme can override selected token groups" {
  let accent = @core.Color::rgba(r=0.86, g=0.18, b=0.42)
  let base = @common.DesignPreset::Carbon.theme()
  let palette = { ..base.palette, primary: accent }
  let spacing_scale = { ..base.spacing_scale, sm: 14.0 }
  let radius_scale = { ..base.radius_scale, md: 10.0 }
  let customized = @common.custom(
    base~,
    palette~,
    semantic_colors={
      ..base.semantic_colors,
      danger: @core.Color::rgba(r=0.92, g=0.18, b=0.28),
    },
    radius_scale~,
    spacing_scale~,
  )
  assert_true(customized.palette.primary == accent)
  inspect(customized.radius_scale.md, content="10")
  inspect(customized.spacing_scale.sm, content="14")
  assert_true(customized.palette.background == base.palette.background)
  assert_true(
    customized.semantic_colors.danger ==
    @core.Color::rgba(r=0.92, g=0.18, b=0.28),
  )
}

///|
test "official design presets expose source mapped manifests" {
  for
    preset in [
      @common.DesignPreset::Material,
      @common.DesignPreset::Carbon,
      @common.DesignPreset::Primer,
      @common.DesignPreset::Fluent,
    ] {
    let manifest = preset.manifest()
    assert_true(manifest.sources.length() >= 3)
    assert_false(manifest.is_official_complete())
    assert_true(manifest.official_source_count() >= 1)
    assert_true(
      manifest.source_lock_count() == manifest.official_source_count(),
    )
    assert_true(manifest.has_official_source_locks())
    assert_true(
      preset.source_lock_report().length() == manifest.sources.length(),
    )
    assert_true(preset.source_lock_quality_gap_count() > 0)
    assert_true(preset.stable_source_lock_count() >= 1)
    assert_true(preset.moving_source_ref_count() > 0)
    assert_false(preset.has_stable_source_locks())
    assert_true(manifest.has_token_category(@common.DesignTokenCategory::Color))
    assert_true(
      manifest.has_token_category(@common.DesignTokenCategory::Typography),
    )
    assert_true(
      manifest.has_token_category(@common.DesignTokenCategory::ComponentStyle),
    )
    assert_true(manifest.has_variant(@common.DesignSchemeVariant::SchemeLight))
    assert_true(manifest.has_variant(@common.DesignSchemeVariant::SchemeDark))
    assert_true(
      manifest.has_variant(@common.DesignSchemeVariant::SchemeHighContrast),
    )
    assert_true(manifest.has_component("Button"))
    assert_true(manifest.has_component("TextField"))
    assert_true(manifest.has_component("Feedback"))
    assert_true(manifest.has_component("Badge"))
    assert_true(manifest.has_component("FormValidation"))
  }
}

///|
test "source lock reports distinguish declared locks from stable snapshots" {
  for
    preset in [
      @common.DesignPreset::Material,
      @common.DesignPreset::Carbon,
      @common.DesignPreset::Primer,
      @common.DesignPreset::Fluent,
    ] {
    let records = preset.source_lock_report()
    let stable = preset.stable_source_lock_count()
    assert_true(records.length() == preset.sources().length())
    assert_true(
      preset.source_lock_quality_gap_count() == records.length() - stable,
    )
    assert_true(stable >= 1)
    assert_true(preset.source_snapshot_url_count() == stable)
    assert_true(preset.source_snapshot_url_gap_count() == 0)
    assert_true(preset.moving_source_ref_count() == records.length() - stable)
    assert_false(preset.has_stable_source_locks())
    assert_true(
      records.any(item => {
        item.ref_kind == @common.DesignSourceRefKind::StableSnapshotRef &&
        item.stable_lock &&
        item.token_path != "" &&
        item.snapshot_url.contains(item.source_ref) &&
        item.snapshot_url.contains(item.token_path)
      }),
    )
    assert_true(
      records.any(item => {
        item.ref_kind == @common.DesignSourceRefKind::LiveDocumentationRef
      }),
    )
    assert_false(
      records.any(item => {
        item.ref_kind == @common.DesignSourceRefKind::MovingBranchRef
      }),
    )
    for item in records {
      assert_true(item.declared_lock)
      assert_true(item.status == @common.DesignTokenStatus::SourceMapped)
      if item.ref_kind == @common.DesignSourceRefKind::StableSnapshotRef {
        assert_true(item.stable_lock)
        assert_true(item.snapshot_url != "")
        assert_true(item.note.contains("stable lock"))
      } else {
        assert_false(item.stable_lock)
        assert_true(item.snapshot_url == "")
        assert_true(
          item.note.contains("moving branch") ||
          item.note.contains("live documentation"),
        )
      }
    }
  }
}

///|
test "source package inventories expose pinned package import gaps" {
  for
    preset in [
      @common.DesignPreset::Material,
      @common.DesignPreset::Carbon,
      @common.DesignPreset::Primer,
      @common.DesignPreset::Fluent,
    ] {
    let rows = preset.source_package_inventory()
    assert_true(rows.length() >= 2)
    assert_true(preset.source_package_inventory_count() == rows.length())
    assert_true(preset.source_package_snapshot_count() == rows.length())
    assert_true(preset.source_package_snapshot_gap_count() == 0)
    assert_true(preset.source_package_mapped_token_count() > 0)
    assert_true(preset.source_package_imported_token_count() > 0)
    assert_true(
      preset.source_package_imported_token_count() ==
      preset.source_imported_token_count(),
    )
    assert_true(preset.source_package_import_gap_count() == rows.length())
    assert_true(rows.any(item => item.imported_token_count > 0))
    for item in rows {
      assert_true(item.source_ref != "")
      assert_true(item.snapshot_url.contains(item.source_ref))
      assert_true(item.snapshot_url.contains(item.token_path))
      assert_true(item.package_path != "")
      assert_true(item.tracked_path_count > 0)
      assert_true(item.pending_gap != "none")
      assert_true(item.status == @common.DesignTokenStatus::PreviewMapped)
    }
  }
  guard @common.DesignPreset::Material.source_package_inventory()[0]
    is material_system else {
    fail("expected Material source package row")
  }
  assert_true(material_system.package_path.contains("_md-sys"))
  assert_true(material_system.mapped_token_count == 13)
  assert_true(
    @common.DesignPreset::Material
    .source_package_inventory()
    .any(item => {
      item.package_path == "tokens/versions/v0_192/_md-ref-palette.scss" &&
      item.imported_token_count == 9
    }),
  )
  assert_true(
    @common.DesignPreset::Material
    .source_package_inventory()
    .any(item => {
      item.package_path == "tokens/_md-comp-*.scss" &&
      item.mapped_token_count == 5 &&
      item.imported_token_count == 5
    }),
  )
  assert_true(
    @common.DesignPreset::Carbon
    .source_package_inventory()
    .any(item => {
      item.package_path == "packages/layout/src/*.ts" &&
      item.mapped_token_count == 25 &&
      item.imported_token_count == 25
    }),
  )
  assert_true(
    @common.DesignPreset::Carbon
    .source_lock_report()
    .any(item => {
      item.source_url.contains("packages/colors") &&
      item.token_path == "packages/colors" &&
      item.stable_lock
    }),
  )
  assert_true(
    @common.DesignPreset::Carbon
    .source_lock_report()
    .any(item => {
      item.source_url.contains("packages/styles") &&
      item.token_path == "packages/styles" &&
      item.stable_lock
    }),
  )
  guard @common.DesignPreset::Carbon.source_package_inventory()[1]
    is carbon_tokens else {
    fail("expected Carbon token source row")
  }
  assert_true(carbon_tokens.package_path.contains("src/tokens"))
  assert_true(
    @common.DesignPreset::Carbon
    .source_package_inventory()
    .any(item => {
      item.package_path == "packages/themes/src/{white,g10,g90,g100}.ts" &&
      item.imported_token_count == 17
    }),
  )
  assert_true(
    @common.DesignPreset::Carbon
    .source_package_inventory()
    .any(item => {
      item.package_path == "packages/themes/src/component-tokens/**/*.ts" &&
      item.imported_token_count == 1 &&
      item.mapped_token_count == 1
    }),
  )
  assert_true(
    @common.DesignPreset::Carbon
    .source_package_inventory()
    .any(item => {
      item.package_path == "packages/motion/src/index.ts" &&
      item.imported_token_count == 13 &&
      item.mapped_token_count == 13
    }),
  )
  assert_true(
    @common.DesignPreset::Carbon
    .source_package_inventory()
    .any(item => {
      item.package_path == "packages/styles/scss/components/slider/*.scss" &&
      item.imported_token_count == 1 &&
      item.mapped_token_count == 1
    }),
  )
  assert_true(
    @common.DesignPreset::Carbon
    .source_package_inventory()
    .any(item => {
      item.package_path == "packages/colors/src/colors.ts" &&
      item.source_url.contains("packages/colors") &&
      item.imported_token_count == 6
    }),
  )
  guard @common.DesignPreset::Primer.source_package_inventory()[0]
    is primer_color else {
    fail("expected Primer color source row")
  }
  assert_true(primer_color.package_path.contains("base/color"))
  assert_true(
    @common.DesignPreset::Primer
    .source_package_inventory()
    .any(item => {
      item.package_path == "src/tokens/functional/color/*.json5" &&
      item.imported_token_count == 16 &&
      item.mapped_token_count == 13
    }),
  )
  assert_true(
    @common.DesignPreset::Primer
    .source_package_inventory()
    .any(item => {
      item.package_path == "src/tokens/base/{motion,size,typography}" &&
      item.imported_token_count == 28 &&
      item.mapped_token_count == 28
    }),
  )
  assert_true(
    @common.DesignPreset::Primer
    .source_package_inventory()
    .any(item => {
      item.package_path == "src/tokens/functional/size/*.json5" &&
      item.imported_token_count == 5 &&
      item.mapped_token_count == 5
    }),
  )
  assert_true(
    @common.DesignPreset::Primer
    .source_package_inventory()
    .any(item => {
      item.package_path == "src/tokens/functional/shadow/*.json5" &&
      item.imported_token_count == 3 &&
      item.mapped_token_count == 3
    }),
  )
  assert_true(
    @common.DesignPreset::Primer
    .source_package_inventory()
    .any(item => {
      item.package_path == "src/tokens/component/*.json5" &&
      item.imported_token_count == 3 &&
      item.mapped_token_count == 6
    }),
  )
  guard @common.DesignPreset::Fluent.source_package_inventory()[0]
    is fluent_global else {
    fail("expected Fluent global source row")
  }
  assert_true(fluent_global.package_path.contains("src/global"))
  assert_true(fluent_global.mapped_token_count == 90)
  assert_true(fluent_global.imported_token_count == 90)
  assert_true(
    @common.DesignPreset::Fluent
    .source_package_inventory()
    .any(item => {
      item.package_path == "packages/tokens/src/alias/*.ts" &&
      item.mapped_token_count == 12 &&
      item.imported_token_count == 12
    }),
  )
  assert_true(
    @common.DesignPreset::Fluent
    .source_package_inventory()
    .any(item => {
      item.package_path == "packages/tokens/src/themes/**" &&
      item.mapped_token_count == 1 &&
      item.imported_token_count == 0
    }),
  )
  assert_true(
    @common.DesignPreset::Fluent
    .source_package_inventory()
    .any(item => {
      item.package_path == "packages/web-components/src/progress-bar/*.ts" &&
      item.mapped_token_count == 1 &&
      item.imported_token_count == 1
    }),
  )
}

///|
test "source imported tokens expose pinned source values without claiming full import" {
  for
    preset in [
      @common.DesignPreset::Material,
      @common.DesignPreset::Carbon,
      @common.DesignPreset::Primer,
      @common.DesignPreset::Fluent,
    ] {
    let rows = preset.source_imported_tokens()
    assert_true(rows.length() > 0)
    assert_true(preset.source_imported_token_count() == rows.length())
    assert_true(preset.source_imported_token_mapped_count() > 0)
    assert_true(preset.source_imported_token_source_lock_gap_count() == 0)
    assert_true(
      preset.source_import_coverage_count() ==
      preset.official_token_anchor_count(),
    )
    assert_true(preset.source_imported_official_token_count() > 0)
    assert_true(preset.source_import_coverage_gap_count() == 0)
    assert_true(preset.source_import_unanchored_count() == 0)
    assert_true(preset.source_import_integrity_gap_count() == 0)
    assert_true(preset.source_import_manifest_lock_gap_count() == 0)
    assert_true(preset.source_import_scope_gap_count() == 0)
    assert_true(preset.source_import_anchor_mismatch_count() == 0)
    assert_true(preset.source_import_golden_mismatch_count() == 0)
    assert_true(
      preset.runtime_token_alignment_count() ==
      preset.official_token_anchor_count(),
    )
    assert_true(preset.runtime_token_alignment_gap_count() > 0)
    assert_true(preset.source_package_import_gap_count() > 0)
    assert_false(preset.is_design_system_complete())
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
    for item in preset.source_import_coverage() {
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
    for item in preset.source_import_integrity_report() {
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
  guard @common.DesignPreset::Material.source_imported_token_for(
      "--md-sys-color-primary",
    )
    is Some(material_primary) else {
    fail("expected imported Material primary token")
  }
  assert_true(material_primary.source_file.contains("_md-sys-color.scss"))
  assert_true(material_primary.source_value.contains("primary40"))
  guard @common.DesignPreset::Material.source_imported_token_for(
      "md-ref-palette.primary40",
    )
    is Some(material_primary_ref) else {
    fail("expected Material primary40 reference-palette import")
  }
  assert_true(material_primary_ref.source_value.contains("#6750a4"))
  assert_true(material_primary_ref.source_file.contains("_md-ref-palette.scss"))
  guard @common.DesignPreset::Material.source_import_coverage_for(
      "--md-sys-color-primary",
    )
    is Some(material_primary_coverage) else {
    fail("expected Material source-import coverage")
  }
  assert_true(material_primary_coverage.source_imported)
  assert_true(material_primary_coverage.golden_mapped)
  assert_true(
    material_primary_coverage.source_token == "md-ref-palette.primary40",
  )
  guard @common.DesignPreset::Material.source_imported_token_for(
      "--md-filled-button-container-color",
    )
    is Some(material_button_container) else {
    fail("expected imported Material filled-button container token")
  }
  assert_true(
    material_button_container.source_value.contains("container-color"),
  )
  assert_true(material_button_container.source_value.contains("#6750a4"))
  guard @common.DesignPreset::Material.source_imported_token_for(
      "--md-filled-button-label-text-color",
    )
    is Some(material_button_label) else {
    fail("expected imported Material filled-button label token")
  }
  assert_true(material_button_label.source_value.contains("label-text-color"))
  assert_true(material_button_label.source_value.contains("#fff"))
  guard @common.DesignPreset::Material.source_imported_token_for(
      "--md-filled-button-pressed-state-layer-opacity",
    )
    is Some(material_button_pressed) else {
    fail("expected imported Material filled-button pressed-state token")
  }
  assert_true(
    material_button_pressed.source_value.contains("pressed-state-layer-opacity"),
  )
  assert_true(material_button_pressed.source_value.contains("0.12"))
  guard @common.DesignPreset::Material.source_imported_token_for(
      "--md-sys-typescale-body-medium-size",
    )
    is Some(material_body_size_import) else {
    fail("expected imported Material body-medium size token")
  }
  assert_true(
    material_body_size_import.source_file.contains("_md-sys-typescale.scss"),
  )
  assert_true(
    material_body_size_import.source_sha ==
    "6ed32803a82f80bff76431e72be2ba85339af479",
  )
  assert_true(material_body_size_import.source_value.contains("0.875rem"))
  guard @common.DesignPreset::Material.source_imported_token_for(
      "--md-sys-shape-corner-medium",
    )
    is Some(material_corner_import) else {
    fail("expected imported Material medium corner token")
  }
  assert_true(material_corner_import.source_file.contains("_md-sys-shape.scss"))
  assert_true(
    material_corner_import.source_sha ==
    "31f390646c9e7eeb82129ee897f05209a03dc3b0",
  )
  assert_true(material_corner_import.source_value.contains("12px"))
  guard @common.DesignPreset::Material.source_imported_token_for(
      "--md-sys-elevation-level1",
    )
    is Some(material_elevation_import) else {
    fail("expected imported Material level1 elevation token")
  }
  assert_true(
    material_elevation_import.source_file.contains("_md-sys-elevation.scss"),
  )
  assert_true(
    material_elevation_import.source_sha ==
    "0292f459b46e639d8f0013e3ca73147217081242",
  )
  assert_true(material_elevation_import.source_value.contains("level1"))
  assert_true(material_elevation_import.source_value.contains("1"))
  guard @common.DesignPreset::Material.source_import_coverage_for(
      "--md-sys-elevation-level1",
    )
    is Some(material_elevation_coverage) else {
    fail("expected Material elevation source-import coverage")
  }
  assert_true(material_elevation_coverage.source_imported)
  assert_true(material_elevation_coverage.golden_mapped)
  assert_true(
    material_elevation_coverage.moui_token ==
    "DesignElevationTokens.sm.offset.y",
  )
  guard @common.DesignPreset::Material.source_imported_token_for(
      "--md-sys-elevation-level3",
    )
    is Some(material_elevation_level3_import) else {
    fail("expected imported Material level3 elevation token")
  }
  assert_true(
    material_elevation_level3_import.source_file.contains(
      "_md-sys-elevation.scss",
    ),
  )
  assert_true(
    material_elevation_level3_import.source_sha ==
    "0292f459b46e639d8f0013e3ca73147217081242",
  )
  assert_true(material_elevation_level3_import.source_value.contains("level3"))
  assert_true(material_elevation_level3_import.source_value.contains("6"))
  guard @common.DesignPreset::Material.source_import_coverage_for(
      "--md-sys-elevation-level3",
    )
    is Some(material_elevation_level3_coverage) else {
    fail("expected Material level3 elevation source-import coverage")
  }
  assert_true(material_elevation_level3_coverage.source_imported)
  assert_true(material_elevation_level3_coverage.golden_mapped)
  assert_true(
    material_elevation_level3_coverage.moui_token ==
    "DesignElevationTokens.md.offset.y",
  )
  guard @common.DesignPreset::Material.source_imported_token_for(
      "--md-sys-elevation-level5",
    )
    is Some(material_elevation_level5_import) else {
    fail("expected imported Material level5 elevation token")
  }
  assert_true(
    material_elevation_level5_import.source_file.contains(
      "_md-sys-elevation.scss",
    ),
  )
  assert_true(
    material_elevation_level5_import.source_sha ==
    "0292f459b46e639d8f0013e3ca73147217081242",
  )
  assert_true(material_elevation_level5_import.source_value.contains("level5"))
  assert_true(material_elevation_level5_import.source_value.contains("12"))
  guard @common.DesignPreset::Material.source_import_coverage_for(
      "--md-sys-elevation-level5",
    )
    is Some(material_elevation_level5_coverage) else {
    fail("expected Material level5 elevation source-import coverage")
  }
  assert_true(material_elevation_level5_coverage.source_imported)
  assert_true(material_elevation_level5_coverage.golden_mapped)
  assert_true(
    material_elevation_level5_coverage.moui_token ==
    "DesignElevationTokens.lg.offset.y",
  )
  guard @common.DesignPreset::Material.source_imported_token_for(
      "--md-sys-motion-*",
    )
    is Some(material_motion_import) else {
    fail("expected imported Material motion token family")
  }
  assert_true(
    material_motion_import.source_file.contains("_md-sys-motion.scss"),
  )
  assert_true(
    material_motion_import.source_sha ==
    "08f9690a072bdd307856769aec20cbfee0036489",
  )
  assert_true(material_motion_import.source_value.contains("duration-medium2"))
  assert_true(material_motion_import.source_value.contains("300ms"))
  guard @common.DesignPreset::Material.source_imported_token_for(
      "--md-sys-motion-duration-short4",
    )
    is Some(material_motion_short4_import) else {
    fail("expected imported Material short4 motion token")
  }
  assert_true(
    material_motion_short4_import.source_file.contains("_md-sys-motion.scss"),
  )
  assert_true(
    material_motion_short4_import.source_sha ==
    "08f9690a072bdd307856769aec20cbfee0036489",
  )
  assert_true(
    material_motion_short4_import.source_value.contains("duration-short4"),
  )
  assert_true(material_motion_short4_import.source_value.contains("200ms"))
  guard @common.DesignPreset::Material.source_import_coverage_for(
      "--md-sys-motion-duration-short4",
    )
    is Some(material_motion_short4_coverage) else {
    fail("expected Material short4 motion source-import coverage")
  }
  assert_true(material_motion_short4_coverage.source_imported)
  assert_true(material_motion_short4_coverage.golden_mapped)
  assert_true(
    material_motion_short4_coverage.moui_token == "DesignMotionTokens.fast_ms",
  )
  guard @common.DesignPreset::Material.source_import_integrity_for(
      "--md-sys-motion-duration-short4",
    )
    is Some(material_motion_short4_integrity) else {
    fail("expected Material short4 motion source-import integrity")
  }
  assert_true(material_motion_short4_integrity.integrity_ok)
  assert_true(material_motion_short4_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Material.source_imported_token_for(
      "--md-sys-motion-duration-medium2",
    )
    is Some(material_motion_medium2_import) else {
    fail("expected imported Material medium2 motion token")
  }
  assert_true(
    material_motion_medium2_import.source_file.contains("_md-sys-motion.scss"),
  )
  assert_true(material_motion_medium2_import.source_value.contains("300ms"))
  guard @common.DesignPreset::Material.source_import_coverage_for(
      "--md-sys-motion-duration-medium2",
    )
    is Some(material_motion_medium2_coverage) else {
    fail("expected Material medium2 motion source-import coverage")
  }
  assert_true(material_motion_medium2_coverage.source_imported)
  assert_true(material_motion_medium2_coverage.golden_mapped)
  assert_true(
    material_motion_medium2_coverage.moui_token ==
    "DesignMotionTokens.normal_ms",
  )
  guard @common.DesignPreset::Material.source_import_integrity_for(
      "--md-sys-motion-duration-medium2",
    )
    is Some(material_motion_medium2_integrity) else {
    fail("expected Material medium2 motion source-import integrity")
  }
  assert_true(material_motion_medium2_integrity.integrity_ok)
  assert_true(material_motion_medium2_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Material.source_imported_token_for(
      "--md-sys-motion-duration-medium4",
    )
    is Some(material_motion_medium4_import) else {
    fail("expected imported Material medium4 motion token")
  }
  assert_true(
    material_motion_medium4_import.source_file.contains("_md-sys-motion.scss"),
  )
  assert_true(material_motion_medium4_import.source_value.contains("400ms"))
  guard @common.DesignPreset::Material.source_import_coverage_for(
      "--md-sys-motion-duration-medium4",
    )
    is Some(material_motion_medium4_coverage) else {
    fail("expected Material medium4 motion source-import coverage")
  }
  assert_true(material_motion_medium4_coverage.source_imported)
  assert_true(material_motion_medium4_coverage.golden_mapped)
  assert_true(
    material_motion_medium4_coverage.moui_token == "DesignMotionTokens.slow_ms",
  )
  guard @common.DesignPreset::Material.source_import_integrity_for(
      "--md-sys-motion-duration-medium4",
    )
    is Some(material_motion_medium4_integrity) else {
    fail("expected Material medium4 motion source-import integrity")
  }
  assert_true(material_motion_medium4_integrity.integrity_ok)
  assert_true(material_motion_medium4_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Material.source_imported_token_for(
      "--md-sys-motion-easing-standard",
    )
    is Some(material_motion_easing_import) else {
    fail("expected imported Material standard easing token")
  }
  assert_true(
    material_motion_easing_import.source_file.contains("_md-sys-motion.scss"),
  )
  assert_true(
    material_motion_easing_import.source_sha ==
    "08f9690a072bdd307856769aec20cbfee0036489",
  )
  assert_true(
    material_motion_easing_import.source_value.contains("easing-standard"),
  )
  assert_true(
    material_motion_easing_import.source_value.contains(
      "cubic-bezier(0.2, 0, 0, 1)",
    ),
  )
  guard @common.DesignPreset::Material.source_import_coverage_for(
      "--md-sys-motion-easing-standard",
    )
    is Some(material_motion_easing_coverage) else {
    fail("expected Material standard easing source-import coverage")
  }
  assert_true(material_motion_easing_coverage.source_imported)
  assert_true(material_motion_easing_coverage.golden_mapped)
  assert_true(
    material_motion_easing_coverage.moui_token == "DesignMotionTokens.easing",
  )
  assert_true(
    material_motion_easing_coverage.status ==
    @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Material.source_import_integrity_for(
      "--md-sys-motion-easing-standard",
    )
    is Some(material_motion_easing_integrity) else {
    fail("expected Material standard easing source-import integrity")
  }
  assert_true(material_motion_easing_integrity.integrity_ok)
  assert_true(material_motion_easing_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Material.source_imported_token_for(
      "--md-linear-progress-active-indicator-color",
    )
    is Some(material_progress_import) else {
    fail("expected imported Material linear progress token")
  }
  assert_true(
    material_progress_import.source_file.contains(
      "_md-comp-linear-progress-indicator.scss",
    ),
  )
  assert_true(
    material_progress_import.source_sha ==
    "7d97f7dd2aed6582cc05bd3dc3d4f9e7f57980b9",
  )
  assert_true(
    material_progress_import.source_value.contains("active-indicator-color"),
  )
  assert_true(material_progress_import.source_value.contains("#6750a4"))
  guard @common.DesignPreset::Material.source_import_coverage_for(
      "--md-linear-progress-active-indicator-color",
    )
    is Some(material_progress_coverage) else {
    fail("expected Material progress source-import coverage")
  }
  assert_true(material_progress_coverage.source_imported)
  assert_true(material_progress_coverage.golden_mapped)
  assert_true(
    material_progress_coverage.moui_token ==
    "DesignComponentTokens.progress.foreground",
  )
  guard @common.DesignPreset::Material.source_import_integrity_for(
      "--md-linear-progress-active-indicator-color",
    )
    is Some(material_progress_integrity) else {
    fail("expected Material progress source-import integrity")
  }
  assert_true(material_progress_integrity.integrity_ok)
  assert_true(material_progress_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Material.source_imported_token_for(
      "--md-menu-container-color",
    )
    is Some(material_menu_import) else {
    fail("expected imported Material menu token")
  }
  assert_true(material_menu_import.source_file.contains("_md-comp-menu.scss"))
  assert_true(
    material_menu_import.source_sha ==
    "0282b47a4bbc1e612ed53880d4b2600c3ab1477f",
  )
  assert_true(material_menu_import.source_value.contains("container-color"))
  assert_true(material_menu_import.source_value.contains("#f3edf7"))
  guard @common.DesignPreset::Material.source_import_coverage_for(
      "--md-menu-container-color",
    )
    is Some(material_menu_coverage) else {
    fail("expected Material menu source-import coverage")
  }
  assert_true(material_menu_coverage.source_imported)
  assert_true(material_menu_coverage.golden_mapped)
  assert_true(
    material_menu_coverage.moui_token ==
    "DesignComponentTokens.picker.background",
  )
  guard @common.DesignPreset::Material.source_import_integrity_for(
      "--md-menu-container-color",
    )
    is Some(material_menu_integrity) else {
    fail("expected Material menu source-import integrity")
  }
  assert_true(material_menu_integrity.integrity_ok)
  assert_true(material_menu_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Carbon.source_imported_token_for("$background")
    is Some(carbon_background) else {
    fail("expected imported Carbon background token")
  }
  assert_true(carbon_background.source_value.contains("background = white"))
  guard @common.DesignPreset::Carbon.source_imported_token_for("white")
    is Some(carbon_white) else {
    fail("expected imported Carbon white primitive")
  }
  assert_true(carbon_white.source_value.contains("#ffffff"))
  assert_true(
    carbon_white.source_file.contains("packages/colors/src/colors.ts"),
  )
  guard @common.DesignPreset::Carbon.source_imported_token_for(
      "$button-primary",
    )
    is Some(carbon_button) else {
    fail("expected imported Carbon button-primary token")
  }
  assert_true(carbon_button.source_value.contains("#0f62fe"))
  assert_true(carbon_button.source_file.contains("component-tokens/button"))
  guard @common.DesignPreset::Carbon.source_import_coverage_for(
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
  guard @common.DesignPreset::Carbon.source_import_integrity_for(
      "$button-primary",
    )
    is Some(carbon_button_integrity) else {
    fail("expected Carbon button-primary source-import integrity")
  }
  assert_true(carbon_button_integrity.integrity_ok)
  assert_true(carbon_button_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Carbon.source_imported_token_for(
      "$background-hover",
    )
    is Some(carbon_hover) else {
    fail("expected imported Carbon background-hover token")
  }
  assert_true(carbon_hover.source_value.contains("adjustAlpha(gray50, 0.12)"))
  assert_true(carbon_hover.source_value.contains("hover alpha 0.12"))
  guard @common.DesignPreset::Carbon.source_import_integrity_for(
      "$background-hover",
    )
    is Some(carbon_hover_integrity) else {
    fail("expected Carbon background-hover source-import integrity")
  }
  assert_true(carbon_hover_integrity.integrity_ok)
  guard @common.DesignPreset::Carbon.source_imported_token_for(
      "$border-interactive",
    )
    is Some(carbon_border) else {
    fail("expected imported Carbon border-interactive token")
  }
  assert_true(carbon_border.source_value.contains("borderInteractive = blue60"))
  assert_true(carbon_border.source_value.contains("#0f62fe"))
  guard @common.DesignPreset::Carbon.source_import_integrity_for(
      "$border-interactive",
    )
    is Some(carbon_border_integrity) else {
    fail("expected Carbon border-interactive source-import integrity")
  }
  assert_true(carbon_border_integrity.integrity_ok)
  guard @common.DesignPreset::Carbon.source_imported_token_for("$field")
    is Some(carbon_field) else {
    fail("expected imported Carbon field token")
  }
  assert_true(carbon_field.source_value.contains("field01 = gray10"))
  assert_true(carbon_field.source_value.contains("#f4f4f4"))
  guard @common.DesignPreset::Carbon.source_import_integrity_for("$field")
    is Some(carbon_field_integrity) else {
    fail("expected Carbon field source-import integrity")
  }
  assert_true(carbon_field_integrity.integrity_ok)
  guard @common.DesignPreset::Carbon.source_imported_token_for(
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
  guard @common.DesignPreset::Carbon.source_import_coverage_for(
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
  guard @common.DesignPreset::Carbon.source_import_integrity_for(
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
  guard @common.DesignPreset::Carbon.source_imported_token_for("durationFast01")
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
  guard @common.DesignPreset::Carbon.source_import_coverage_for(
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
    carbon_duration_fast01_coverage.status ==
    @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Carbon.source_imported_token_for("durationFast02")
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
  guard @common.DesignPreset::Carbon.source_import_coverage_for(
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
  guard @common.DesignPreset::Carbon.source_imported_token_for(
      "durationModerate01",
    )
    is Some(carbon_duration_normal) else {
    fail("expected imported Carbon moderate-01 duration token")
  }
  assert_true(carbon_duration_normal.source_value.contains("150ms"))
  guard @common.DesignPreset::Carbon.source_import_coverage_for(
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
  guard @common.DesignPreset::Carbon.source_import_integrity_for(
      "$duration-moderate-01",
    )
    is Some(carbon_duration_normal_integrity) else {
    fail("expected Carbon moderate-01 duration source-import integrity")
  }
  assert_true(carbon_duration_normal_integrity.integrity_ok)
  assert_true(carbon_duration_normal_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Carbon.source_imported_token_for(
      "durationModerate02",
    )
    is Some(carbon_duration_slow) else {
    fail("expected imported Carbon moderate-02 duration token")
  }
  assert_true(carbon_duration_slow.source_value.contains("240ms"))
  guard @common.DesignPreset::Carbon.source_import_coverage_for(
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
  guard @common.DesignPreset::Carbon.source_imported_token_for("durationSlow02")
    is Some(carbon_duration_slow02) else {
    fail("expected imported Carbon slow-02 duration token")
  }
  assert_true(carbon_duration_slow02.source_value.contains("durationSlow02"))
  assert_true(carbon_duration_slow02.source_value.contains("700ms"))
  guard @common.DesignPreset::Carbon.source_import_coverage_for(
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
    carbon_duration_slow02_coverage.status ==
    @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Carbon.source_imported_token_for(
      "easings.standard.productive",
    )
    is Some(carbon_easing) else {
    fail("expected imported Carbon standard productive easing token")
  }
  assert_true(
    carbon_easing.source_value.contains("cubic-bezier(0.2, 0, 0.38, 0.9)"),
  )
  guard @common.DesignPreset::Carbon.source_import_coverage_for(
      "easings.standard.productive",
    )
    is Some(carbon_easing_coverage) else {
    fail("expected Carbon standard productive easing source-import coverage")
  }
  assert_true(carbon_easing_coverage.source_imported)
  assert_true(carbon_easing_coverage.golden_mapped)
  assert_true(carbon_easing_coverage.moui_token == "DesignMotionTokens.easing")
  assert_true(
    carbon_easing_coverage.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Carbon.source_import_integrity_for(
      "easings.standard.productive",
    )
    is Some(carbon_easing_integrity) else {
    fail("expected Carbon standard productive easing source-import integrity")
  }
  assert_true(carbon_easing_integrity.integrity_ok)
  assert_true(carbon_easing_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Carbon.source_imported_token_for(
      "easings.exit.expressive",
    )
    is Some(carbon_easing_exit) else {
    fail("expected imported Carbon expressive exit easing token")
  }
  assert_true(
    carbon_easing_exit.source_value.contains("cubic-bezier(0.4, 0.14, 1, 1)"),
  )
  guard @common.DesignPreset::Carbon.source_import_coverage_for(
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
    carbon_easing_exit_coverage.status ==
    @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Carbon.source_import_integrity_for(
      "easings.exit.expressive",
    )
    is Some(carbon_easing_exit_integrity) else {
    fail("expected Carbon expressive exit easing source-import integrity")
  }
  assert_true(carbon_easing_exit_integrity.integrity_ok)
  assert_true(carbon_easing_exit_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Carbon.source_imported_token_for(
      "Carbon motion token family",
    )
    is Some(carbon_motion_family) else {
    fail("expected imported Carbon motion token family")
  }
  assert_true(carbon_motion_family.source_file.contains("packages/motion"))
  assert_true(carbon_motion_family.source_value.contains("durationFast01"))
  assert_true(carbon_motion_family.source_value.contains("standard"))
  guard @common.DesignPreset::Carbon.source_import_coverage_for(
      "Carbon motion token family",
    )
    is Some(carbon_motion_family_coverage) else {
    fail("expected Carbon motion family source-import coverage")
  }
  assert_true(carbon_motion_family_coverage.source_imported)
  assert_true(carbon_motion_family_coverage.golden_mapped)
  assert_true(carbon_motion_family_coverage.moui_token == "DesignMotionTokens")
  assert_true(
    carbon_motion_family_coverage.status ==
    @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Carbon.source_import_integrity_for(
      "Carbon motion token family",
    )
    is Some(carbon_motion_family_integrity) else {
    fail("expected Carbon motion family source-import integrity")
  }
  assert_true(carbon_motion_family_integrity.integrity_ok)
  assert_true(carbon_motion_family_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Primer.source_imported_token_for(
      "fgColor.default.$value",
    )
    is Some(primer_foreground_import) else {
    fail("expected imported Primer foreground token")
  }
  assert_true(primer_foreground_import.source_value.contains("#1f2328"))
  assert_true(primer_foreground_import.source_file.contains("fgColor.json5"))
  guard @common.DesignPreset::Primer.source_import_coverage_for(
      "--fgColor-default",
    )
    is Some(primer_foreground) else {
    fail("expected Primer source-import coverage")
  }
  assert_true(primer_foreground.source_imported)
  assert_true(primer_foreground.source_token == "fgColor.default.$value")
  guard @common.DesignPreset::Primer.source_imported_token_for(
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
  guard @common.DesignPreset::Primer.source_import_coverage_for("--base-size-4")
    is Some(primer_base_size_xs) else {
    fail("expected Primer base size 4 source-import coverage")
  }
  assert_true(primer_base_size_xs.source_imported)
  assert_true(primer_base_size_xs.golden_mapped)
  assert_true(primer_base_size_xs.source_token == "base.size.'4'.$value")
  assert_true(primer_base_size_xs.moui_token == "DesignSpacingTokens.xs")
  assert_true(
    primer_base_size_xs.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Primer.source_import_coverage_for("--base-size-8")
    is Some(primer_base_size_sm) else {
    fail("expected Primer base size 8 source-import coverage")
  }
  assert_true(primer_base_size_sm.source_imported)
  assert_true(primer_base_size_sm.golden_mapped)
  assert_true(primer_base_size_sm.source_token == "base.size.'8'.$value")
  assert_true(primer_base_size_sm.moui_token == "DesignSpacingTokens.sm")
  assert_true(
    primer_base_size_sm.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Primer.source_import_coverage_for(
      "--base-size-12",
    )
    is Some(primer_base_size_md) else {
    fail("expected Primer base size 12 source-import coverage")
  }
  assert_true(primer_base_size_md.source_imported)
  assert_true(primer_base_size_md.golden_mapped)
  assert_true(primer_base_size_md.source_token == "base.size.'12'.$value")
  assert_true(primer_base_size_md.moui_token == "DesignSpacingTokens.md")
  assert_true(
    primer_base_size_md.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Primer.source_imported_token_for(
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
  guard @common.DesignPreset::Primer.source_import_coverage_for(
      "--base-size-16",
    )
    is Some(primer_base_size) else {
    fail("expected Primer base size source-import coverage")
  }
  assert_true(primer_base_size.source_imported)
  assert_true(primer_base_size.golden_mapped)
  assert_true(primer_base_size.source_token == "base.size.'16'.$value")
  assert_true(primer_base_size.moui_token == "DesignSpacingTokens.lg")
  assert_true(primer_base_size.status == @common.DesignTokenStatus::ThemeMapped)
  guard @common.DesignPreset::Primer.source_import_integrity_for(
      "--base-size-16",
    )
    is Some(primer_base_size_integrity) else {
    fail("expected Primer base size source-import integrity")
  }
  assert_true(primer_base_size_integrity.integrity_ok)
  assert_true(primer_base_size_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Primer.source_imported_token_for(
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
  guard @common.DesignPreset::Primer.source_import_coverage_for(
      "--base-size-24",
    )
    is Some(primer_base_size_xl) else {
    fail("expected Primer base size 24 source-import coverage")
  }
  assert_true(primer_base_size_xl.source_imported)
  assert_true(primer_base_size_xl.golden_mapped)
  assert_true(primer_base_size_xl.source_token == "base.size.'24'.$value")
  assert_true(primer_base_size_xl.moui_token == "DesignSpacingTokens.xl")
  assert_true(
    primer_base_size_xl.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Primer.source_imported_token_for(
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
  guard @common.DesignPreset::Primer.source_import_coverage_for(
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
  assert_true(
    primer_caption_size.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Primer.source_import_coverage_for(
      "--base-text-size-sm",
    )
    is Some(primer_body_size) else {
    fail("expected Primer body text size source-import coverage")
  }
  assert_true(primer_body_size.source_imported)
  assert_true(primer_body_size.golden_mapped)
  assert_true(primer_body_size.source_token == "base.text.size.sm.$value")
  assert_true(primer_body_size.moui_token == "DesignTypographyTokens.body.size")
  assert_true(primer_body_size.status == @common.DesignTokenStatus::ThemeMapped)
  guard @common.DesignPreset::Primer.source_import_coverage_for(
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
  assert_true(
    primer_title_size.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Primer.source_import_coverage_for(
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
  assert_true(
    primer_body_weight.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Primer.source_imported_token_for(
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
  guard @common.DesignPreset::Primer.source_import_coverage_for(
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
  assert_true(
    primer_control_weight.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Primer.source_import_integrity_for(
      "--base-text-size-sm",
    )
    is Some(primer_body_size_integrity) else {
    fail("expected Primer body text size source-import integrity")
  }
  assert_true(primer_body_size_integrity.integrity_ok)
  assert_true(primer_body_size_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Primer.source_imported_token_for(
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
  guard @common.DesignPreset::Primer.source_import_coverage_for(
      "--borderRadius-small",
    )
    is Some(primer_radius_small) else {
    fail("expected Primer small radius source-import coverage")
  }
  assert_true(primer_radius_small.source_imported)
  assert_true(primer_radius_small.golden_mapped)
  assert_true(primer_radius_small.source_token == "borderRadius.small.$value")
  assert_true(primer_radius_small.moui_token == "DesignRadiusTokens.sm")
  assert_true(
    primer_radius_small.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Primer.source_import_coverage_for(
      "--borderRadius-medium",
    )
    is Some(primer_radius_medium) else {
    fail("expected Primer medium radius source-import coverage")
  }
  assert_true(primer_radius_medium.source_imported)
  assert_true(primer_radius_medium.golden_mapped)
  assert_true(primer_radius_medium.source_token == "borderRadius.medium.$value")
  assert_true(primer_radius_medium.moui_token == "DesignRadiusTokens.md")
  assert_true(
    primer_radius_medium.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Primer.source_import_coverage_for(
      "--borderRadius-large",
    )
    is Some(primer_radius_large) else {
    fail("expected Primer large radius source-import coverage")
  }
  assert_true(primer_radius_large.source_imported)
  assert_true(primer_radius_large.golden_mapped)
  assert_true(primer_radius_large.source_token == "borderRadius.large.$value")
  assert_true(primer_radius_large.moui_token == "DesignRadiusTokens.lg")
  assert_true(
    primer_radius_large.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Primer.source_import_coverage_for(
      "--borderRadius-full",
    )
    is Some(primer_radius_full) else {
    fail("expected Primer full radius source-import coverage")
  }
  assert_true(primer_radius_full.source_imported)
  assert_true(primer_radius_full.golden_mapped)
  assert_true(primer_radius_full.source_token == "borderRadius.full.$value")
  assert_true(primer_radius_full.moui_token == "DesignRadiusTokens.pill")
  assert_true(
    primer_radius_full.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Primer.source_imported_token_for(
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
  guard @common.DesignPreset::Primer.source_import_coverage_for(
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
  assert_true(
    primer_radius_default.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Primer.source_import_integrity_for(
      "--borderRadius-medium",
    )
    is Some(primer_radius_integrity) else {
    fail("expected Primer medium radius source-import integrity")
  }
  assert_true(primer_radius_integrity.integrity_ok)
  assert_true(primer_radius_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Primer.source_imported_token_for(
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
  guard @common.DesignPreset::Primer.source_import_coverage_for(
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
  assert_true(
    primer_shadow_small.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Primer.source_import_coverage_for(
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
  assert_true(
    primer_shadow_medium.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Primer.source_imported_token_for(
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
  guard @common.DesignPreset::Primer.source_import_coverage_for(
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
  assert_true(
    primer_shadow_large.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Primer.source_import_integrity_for(
      "--shadow-resting-small",
    )
    is Some(primer_shadow_integrity) else {
    fail("expected Primer small shadow source-import integrity")
  }
  assert_true(primer_shadow_integrity.integrity_ok)
  assert_true(primer_shadow_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Primer.source_imported_token_for(
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
  guard @common.DesignPreset::Primer.source_import_coverage_for(
      "--base-duration-0",
    )
    is Some(primer_duration_zero) else {
    fail("expected Primer 0ms duration source-import coverage")
  }
  assert_true(primer_duration_zero.source_imported)
  assert_true(primer_duration_zero.golden_mapped)
  assert_true(primer_duration_zero.source_token == "base.duration.'0'.$value")
  assert_true(primer_duration_zero.moui_token == "DesignMotionTokens.fast_ms")
  assert_true(
    primer_duration_zero.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Primer.source_imported_token_for(
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
  guard @common.DesignPreset::Primer.source_import_coverage_for(
      "--base-duration-100",
    )
    is Some(primer_duration_fast) else {
    fail("expected Primer 100ms duration source-import coverage")
  }
  assert_true(primer_duration_fast.source_imported)
  assert_true(primer_duration_fast.golden_mapped)
  assert_true(primer_duration_fast.source_token == "base.duration.'100'.$value")
  assert_true(primer_duration_fast.moui_token == "DesignMotionTokens.fast_ms")
  assert_true(
    primer_duration_fast.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Primer.source_import_coverage_for(
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
  assert_true(
    primer_duration_normal.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Primer.source_import_coverage_for(
      "--base-duration-300",
    )
    is Some(primer_duration_slow) else {
    fail("expected Primer 300ms duration source-import coverage")
  }
  assert_true(primer_duration_slow.source_imported)
  assert_true(primer_duration_slow.source_token == "base.duration.'300'.$value")
  assert_true(primer_duration_slow.moui_token == "DesignMotionTokens.slow_ms")
  assert_true(
    primer_duration_slow.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Primer.source_imported_token_for(
      "base.duration.'1000'.$value",
    )
    is Some(primer_duration_long_import) else {
    fail("expected imported Primer 1000ms duration token")
  }
  assert_true(primer_duration_long_import.source_file.contains("timing.json5"))
  assert_true(primer_duration_long_import.source_value.contains("value: 1000"))
  guard @common.DesignPreset::Primer.source_import_coverage_for(
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
  assert_true(
    primer_duration_long.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Primer.source_imported_token_for(
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
  guard @common.DesignPreset::Primer.source_import_coverage_for(
      "--base-easing-linear",
    )
    is Some(primer_linear) else {
    fail("expected Primer linear easing source-import coverage")
  }
  assert_true(primer_linear.source_imported)
  assert_true(primer_linear.source_token == "base.easing.linear.$value")
  assert_true(primer_linear.moui_token == "DesignMotionTokens.easing")
  assert_true(primer_linear.status == @common.DesignTokenStatus::PreviewMapped)
  guard @common.DesignPreset::Primer.source_imported_token_for(
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
  guard @common.DesignPreset::Primer.source_import_coverage_for(
      "--base-easing-easeOut",
    )
    is Some(primer_easing) else {
    fail("expected Primer easeOut source-import coverage")
  }
  assert_true(primer_easing.source_imported)
  assert_true(primer_easing.source_token == "base.easing.easeOut.$value")
  assert_true(primer_easing.moui_token == "DesignMotionTokens.easing")
  assert_true(primer_easing.status == @common.DesignTokenStatus::PreviewMapped)
  guard @common.DesignPreset::Primer.source_import_integrity_for(
      "--base-easing-easeOut",
    )
    is Some(primer_easing_integrity) else {
    fail("expected Primer easeOut source-import integrity")
  }
  assert_true(primer_easing_integrity.integrity_ok)
  assert_true(primer_easing_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Primer.source_imported_token_for(
      "base.easing.easeInOut.$value",
    )
    is Some(primer_ease_in_out_import) else {
    fail("expected imported Primer easeInOut token")
  }
  assert_true(primer_ease_in_out_import.source_file.contains("easing.json5"))
  assert_true(primer_ease_in_out_import.source_value.contains("0.6,0,0.2,1"))
  guard @common.DesignPreset::Primer.source_import_integrity_for(
      "--base-easing-easeInOut",
    )
    is Some(primer_ease_in_out_integrity) else {
    fail("expected Primer easeInOut source-import integrity")
  }
  assert_true(primer_ease_in_out_integrity.integrity_ok)
  assert_true(primer_ease_in_out_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Primer.source_imported_token_for(
      "Primer animation token family",
    )
    is Some(primer_animation_family) else {
    fail("expected imported Primer animation token family")
  }
  assert_true(primer_animation_family.source_file.contains("timing.json5"))
  assert_true(primer_animation_family.source_value.contains("base.duration"))
  assert_true(primer_animation_family.source_value.contains("base.easing"))
  guard @common.DesignPreset::Primer.source_import_coverage_for(
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
    primer_animation_family_coverage.status ==
    @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Primer.source_import_integrity_for(
      "Primer animation token family",
    )
    is Some(primer_animation_family_integrity) else {
    fail("expected Primer animation family source-import integrity")
  }
  assert_true(primer_animation_family_integrity.integrity_ok)
  assert_true(primer_animation_family_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Primer.source_imported_token_for(
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
  guard @common.DesignPreset::Primer.source_import_coverage_for(
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
  assert_true(
    primer_button.status == @common.DesignTokenStatus::ComponentMapped,
  )
  guard @common.DesignPreset::Primer.source_import_integrity_for(
      "--button-primary-bgColor-rest",
    )
    is Some(primer_button_integrity) else {
    fail("expected Primer primary button source-import integrity")
  }
  assert_true(primer_button_integrity.integrity_ok)
  assert_true(primer_button_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Primer.source_imported_token_for(
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
  guard @common.DesignPreset::Primer.source_import_coverage_for(
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
  assert_true(
    primer_control.status == @common.DesignTokenStatus::ComponentMapped,
  )
  guard @common.DesignPreset::Primer.source_import_integrity_for(
      "--control-bgColor-rest",
    )
    is Some(primer_control_integrity) else {
    fail("expected Primer control rest background source-import integrity")
  }
  assert_true(primer_control_integrity.integrity_ok)
  assert_true(primer_control_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Primer.source_imported_token_for(
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
  guard @common.DesignPreset::Primer.source_import_coverage_for(
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
  assert_true(
    primer_control_hover.status == @common.DesignTokenStatus::ComponentMapped,
  )
  guard @common.DesignPreset::Primer.source_import_integrity_for(
      "--control-transparent-bgColor-hover",
    )
    is Some(primer_control_hover_integrity) else {
    fail("expected Primer transparent hover source-import integrity")
  }
  assert_true(primer_control_hover_integrity.integrity_ok)
  assert_true(primer_control_hover_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Primer.source_imported_token_for(
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
  guard @common.DesignPreset::Primer.source_import_coverage_for(
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
    primer_control_border.status == @common.DesignTokenStatus::ComponentMapped,
  )
  guard @common.DesignPreset::Primer.source_import_integrity_for(
      "--control-borderColor-emphasis",
    )
    is Some(primer_control_border_integrity) else {
    fail("expected Primer control emphasized border source-import integrity")
  }
  assert_true(primer_control_border_integrity.integrity_ok)
  assert_true(primer_control_border_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Primer.source_imported_token_for(
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
  guard @common.DesignPreset::Primer.source_import_coverage_for(
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
  assert_true(
    primer_progress.status == @common.DesignTokenStatus::ComponentMapped,
  )
  guard @common.DesignPreset::Primer.source_import_integrity_for(
      "--progressBar-fgColor-accent",
    )
    is Some(primer_progress_integrity) else {
    fail("expected Primer progress source-import integrity")
  }
  assert_true(primer_progress_integrity.integrity_ok)
  assert_true(primer_progress_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Fluent.source_imported_token_for(
      "colorBrandBackground",
    )
    is Some(fluent_brand) else {
    fail("expected imported Fluent brand token")
  }
  assert_true(fluent_brand.source_value.contains("#0078d4"))
  guard @common.DesignPreset::Fluent.source_import_integrity_for(
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
  guard @common.DesignPreset::Fluent.source_imported_token_for(
      "colorCompoundBrandBackground",
    )
    is Some(fluent_compound_brand) else {
    fail("expected imported Fluent compound brand token")
  }
  assert_true(fluent_compound_brand.source_file.contains("lightColor.ts"))
  assert_true(fluent_compound_brand.source_value.contains("#0078d4"))
  guard @common.DesignPreset::Fluent.source_import_coverage_for(
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
    fluent_compound_brand_coverage.status ==
    @common.DesignTokenStatus::ComponentMapped,
  )
  guard @common.DesignPreset::Fluent.source_import_coverage_for(
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
  assert_true(
    fluent_progress.status == @common.DesignTokenStatus::ComponentMapped,
  )
  assert_true(fluent_progress.source_file.contains("progress-bar.styles.ts"))
  assert_true(
    fluent_progress.source_value.contains("colorCompoundBrandBackground"),
  )
  guard @common.DesignPreset::Fluent.source_import_integrity_for(
      "ProgressBar.indicator.backgroundColor",
    )
    is Some(fluent_progress_integrity) else {
    fail("expected Fluent progress source-import integrity record")
  }
  assert_true(fluent_progress_integrity.integrity_ok)
  assert_true(fluent_progress_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Fluent.source_import_integrity_for(
      "colorCompoundBrandBackground",
    )
    is Some(fluent_compound_brand_integrity) else {
    fail("expected Fluent compound brand integrity record")
  }
  assert_true(fluent_compound_brand_integrity.integrity_ok)
  assert_true(fluent_compound_brand_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Fluent.source_import_coverage_for(
      "spacingHorizontalM",
    )
    is Some(fluent_spacing) else {
    fail("expected Fluent spacing source-import coverage")
  }
  assert_true(fluent_spacing.source_imported)
  assert_true(fluent_spacing.golden_mapped)
  assert_true(fluent_spacing.moui_token == "DesignSpacingTokens.md")
  assert_true(fluent_spacing.status == @common.DesignTokenStatus::ThemeMapped)
  guard @common.DesignPreset::Fluent.source_import_integrity_for(
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
  guard @common.DesignPreset::Fluent.source_import_coverage_for(
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
    fluent_duration_ultra_fast.status ==
    @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Fluent.source_import_coverage_for(
      "durationFaster",
    )
    is Some(fluent_duration_fast) else {
    fail("expected Fluent faster duration source-import coverage")
  }
  assert_true(fluent_duration_fast.source_imported)
  assert_true(fluent_duration_fast.golden_mapped)
  assert_true(fluent_duration_fast.moui_token == "DesignMotionTokens.fast_ms")
  assert_true(
    fluent_duration_fast.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Fluent.source_import_integrity_for(
      "durationFaster",
    )
    is Some(fluent_duration_fast_integrity) else {
    fail("expected Fluent faster duration integrity record")
  }
  assert_true(fluent_duration_fast_integrity.integrity_ok)
  assert_true(fluent_duration_fast_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Fluent.source_import_coverage_for("durationFast")
    is Some(fluent_duration_fast_preview) else {
    fail("expected Fluent fast duration source-import coverage")
  }
  assert_true(fluent_duration_fast_preview.source_imported)
  assert_true(fluent_duration_fast_preview.golden_mapped)
  assert_true(
    fluent_duration_fast_preview.moui_token == "DesignMotionTokens.fast_ms",
  )
  assert_true(
    fluent_duration_fast_preview.status ==
    @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Fluent.source_import_coverage_for(
      "durationNormal",
    )
    is Some(fluent_duration) else {
    fail("expected Fluent duration source-import coverage")
  }
  assert_true(fluent_duration.source_imported)
  assert_true(fluent_duration.golden_mapped)
  assert_true(fluent_duration.moui_token == "DesignMotionTokens.normal_ms")
  assert_true(fluent_duration.status == @common.DesignTokenStatus::ThemeMapped)
  guard @common.DesignPreset::Fluent.source_import_integrity_for(
      "durationNormal",
    )
    is Some(fluent_duration_integrity) else {
    fail("expected Fluent duration integrity record")
  }
  assert_true(fluent_duration_integrity.integrity_ok)
  assert_true(fluent_duration_integrity.moui_token_matches_golden)
  guard @common.DesignPreset::Fluent.source_import_coverage_for(
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
  assert_true(
    fluent_duration_gentle.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Fluent.source_import_coverage_for("durationSlow")
    is Some(fluent_duration_slow) else {
    fail("expected Fluent slow duration source-import coverage")
  }
  assert_true(fluent_duration_slow.source_imported)
  assert_true(fluent_duration_slow.golden_mapped)
  assert_true(fluent_duration_slow.moui_token == "DesignMotionTokens.slow_ms")
  assert_true(
    fluent_duration_slow.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Fluent.source_import_coverage_for(
      "durationSlower",
    )
    is Some(fluent_duration_slower) else {
    fail("expected Fluent slower duration source-import coverage")
  }
  assert_true(fluent_duration_slower.source_imported)
  assert_true(fluent_duration_slower.golden_mapped)
  assert_true(fluent_duration_slower.moui_token == "DesignMotionTokens.slow_ms")
  assert_true(
    fluent_duration_slower.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Fluent.source_import_coverage_for(
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
    fluent_duration_ultra_slow.status ==
    @common.DesignTokenStatus::PreviewMapped,
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
  guard @common.DesignPreset::Fluent.source_import_coverage_for("curveEasyEase")
    is Some(fluent_curve) else {
    fail("expected Fluent curve source-import coverage")
  }
  assert_true(fluent_curve.source_imported)
  assert_true(fluent_curve.golden_mapped)
  assert_true(fluent_curve.moui_token == "DesignMotionTokens.easing")
  assert_true(fluent_curve.status == @common.DesignTokenStatus::PreviewMapped)
  guard @common.DesignPreset::Fluent.source_import_integrity_for(
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
  guard @common.DesignPreset::Fluent.source_imported_token_for(
      "fontSizeBase300",
    )
    is Some(fluent_font_size) else {
    fail("expected imported Fluent font-size token")
  }
  assert_true(fluent_font_size.source_file.contains("fonts.ts"))
  assert_true(fluent_font_size.source_value.contains("14px"))
  guard @common.DesignPreset::Fluent.source_import_coverage_for(
      "fontSizeBase300",
    )
    is Some(fluent_font_coverage) else {
    fail("expected Fluent font-size source-import coverage")
  }
  assert_true(fluent_font_coverage.source_imported)
  assert_true(fluent_font_coverage.golden_mapped)
  assert_true(
    fluent_font_coverage.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Fluent.source_import_coverage_for(
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
  assert_true(fluent_semibold.status == @common.DesignTokenStatus::ThemeMapped)
  guard @common.DesignPreset::Fluent.source_import_integrity_for(
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
  guard @common.DesignPreset::Fluent.source_imported_token_for(
      "spacingHorizontalXS",
    )
    is Some(fluent_spacing_xs_import) else {
    fail("expected imported Fluent extra-small spacing token")
  }
  assert_true(fluent_spacing_xs_import.source_file.contains("spacings.ts"))
  assert_true(fluent_spacing_xs_import.source_value.contains("'4px'"))
  guard @common.DesignPreset::Fluent.source_import_coverage_for(
      "spacingHorizontalXS",
    )
    is Some(fluent_spacing_xs) else {
    fail("expected Fluent extra-small spacing source-import coverage")
  }
  assert_true(fluent_spacing_xs.source_imported)
  assert_true(fluent_spacing_xs.golden_mapped)
  assert_true(fluent_spacing_xs.moui_token == "DesignSpacingTokens.xs")
  assert_true(
    fluent_spacing_xs.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Fluent.source_imported_token_for(
      "borderRadiusCircular",
    )
    is Some(fluent_radius_circular_import) else {
    fail("expected imported Fluent circular radius token")
  }
  assert_true(
    fluent_radius_circular_import.source_file.contains("borderRadius.ts"),
  )
  assert_true(fluent_radius_circular_import.source_value.contains("10000px"))
  guard @common.DesignPreset::Fluent.source_import_coverage_for(
      "borderRadiusCircular",
    )
    is Some(fluent_radius_circular) else {
    fail("expected Fluent circular radius source-import coverage")
  }
  assert_true(fluent_radius_circular.source_imported)
  assert_true(fluent_radius_circular.golden_mapped)
  assert_true(fluent_radius_circular.moui_token == "DesignRadiusTokens.pill")
  assert_true(
    fluent_radius_circular.status == @common.DesignTokenStatus::PreviewMapped,
  )
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

///|
test "runtime token alignment ties resolved source imports to design tokens" {
  for
    preset in [
      @common.DesignPreset::Material,
      @common.DesignPreset::Carbon,
      @common.DesignPreset::Primer,
      @common.DesignPreset::Fluent,
    ] {
    let rows = preset.runtime_token_alignment_report()
    assert_true(rows.length() == preset.official_token_anchor_count())
    assert_true(preset.runtime_token_alignment_count() == rows.length())
    assert_true(preset.runtime_token_alignment_gap_count() > 0)
    assert_false(preset.is_design_system_complete())
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
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
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
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
      "colorBrandBackground",
    )
    is Some(fluent_brand) else {
    fail("expected Fluent brand runtime alignment")
  }
  assert_true(fluent_brand.runtime_aligned)
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
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
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
      "ProgressBar.indicator.backgroundColor",
    )
    is Some(fluent_progress) else {
    fail("expected Fluent progress runtime alignment")
  }
  assert_true(fluent_progress.source_imported)
  assert_true(fluent_progress.source_value_resolved)
  assert_true(fluent_progress.runtime_value_available)
  assert_true(fluent_progress.runtime_aligned)
  assert_true(
    fluent_progress.status == @common.DesignTokenStatus::ComponentMapped,
  )
  assert_true(
    fluent_progress.moui_token == "DesignComponentTokens.progress.foreground",
  )
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
      "colorNeutralBackground2",
    )
    is Some(fluent_surface) else {
    fail("expected Fluent surface runtime alignment")
  }
  assert_true(fluent_surface.runtime_aligned)
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
      "colorNeutralBackground3",
    )
    is Some(fluent_surface_variant) else {
    fail("expected Fluent surface-variant runtime alignment")
  }
  assert_true(fluent_surface_variant.runtime_aligned)
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
      "colorNeutralStroke1",
    )
    is Some(fluent_outline) else {
    fail("expected Fluent outline runtime alignment")
  }
  assert_true(fluent_outline.runtime_aligned)
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
      "colorNeutralForeground3",
    )
    is Some(fluent_muted) else {
    fail("expected Fluent muted runtime alignment")
  }
  assert_true(fluent_muted.runtime_aligned)
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
      "borderRadiusMedium",
    )
    is Some(fluent_radius) else {
    fail("expected Fluent radius runtime alignment")
  }
  assert_true(fluent_radius.runtime_aligned)
  inspect(fluent_radius.runtime_value, content="4")
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
      "fontSizeBase300",
    )
    is Some(fluent_body_font_size) else {
    fail("expected Fluent body font-size runtime alignment")
  }
  assert_true(fluent_body_font_size.runtime_aligned)
  inspect(fluent_body_font_size.runtime_value, content="14")
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
      "fontSizeBase500",
    )
    is Some(fluent_title_font_size) else {
    fail("expected Fluent title font-size runtime alignment")
  }
  assert_true(fluent_title_font_size.source_value_resolved)
  assert_true(fluent_title_font_size.runtime_value_available)
  assert_false(fluent_title_font_size.runtime_aligned)
  assert_true(
    fluent_title_font_size.status == @common.DesignTokenStatus::PreviewMapped,
  )
  inspect(fluent_title_font_size.expected_runtime_value, content="20")
  inspect(fluent_title_font_size.runtime_value, content="22")
  assert_fluent_preview_typography_runtime_alignment(
    "fontSizeBase100", "10", "12",
  )
  assert_fluent_preview_typography_runtime_alignment(
    "fontSizeBase400", "16", "14",
  )
  assert_fluent_preview_typography_runtime_alignment(
    "fontSizeBase600", "24", "22",
  )
  assert_fluent_preview_typography_runtime_alignment(
    "fontSizeHero700", "28", "22",
  )
  assert_fluent_preview_typography_runtime_alignment(
    "fontSizeHero800", "32", "22",
  )
  assert_fluent_preview_typography_runtime_alignment(
    "fontSizeHero900", "40", "22",
  )
  assert_fluent_preview_typography_runtime_alignment(
    "fontSizeHero1000", "68", "22",
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
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
      "fontWeightSemibold",
    )
    is Some(fluent_semibold) else {
    fail("expected Fluent semibold runtime alignment")
  }
  assert_true(fluent_semibold.runtime_aligned)
  inspect(fluent_semibold.runtime_value, content="600")
  assert_fluent_mapped_typography_runtime_alignment("fontWeightBold", "700")
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
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
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
      "fontFamilyMonospace",
    )
    is Some(fluent_family_monospace) else {
    fail("expected Fluent monospace font-family runtime alignment")
  }
  assert_true(
    fluent_family_monospace.expected_runtime_value.contains("Consolas"),
  )
  inspect(fluent_family_monospace.runtime_value, content="system-ui")
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
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
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
      "spacingHorizontalM",
    )
    is Some(fluent_spacing) else {
    fail("expected Fluent spacing runtime alignment")
  }
  assert_true(fluent_spacing.runtime_aligned)
  inspect(fluent_spacing.runtime_value, content="12")
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
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
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
      "borderRadiusCircular",
    )
    is Some(fluent_radius_circular) else {
    fail("expected Fluent circular radius runtime alignment")
  }
  assert_true(fluent_radius_circular.source_value_resolved)
  assert_true(fluent_radius_circular.runtime_value_available)
  assert_false(fluent_radius_circular.runtime_aligned)
  assert_true(
    fluent_radius_circular.status == @common.DesignTokenStatus::PreviewMapped,
  )
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
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
      "durationUltraFast",
    )
    is Some(fluent_duration_ultra_fast) else {
    fail("expected Fluent ultra-fast duration runtime alignment")
  }
  assert_true(fluent_duration_ultra_fast.source_value_resolved)
  assert_true(fluent_duration_ultra_fast.runtime_value_available)
  assert_false(fluent_duration_ultra_fast.runtime_aligned)
  assert_true(
    fluent_duration_ultra_fast.status ==
    @common.DesignTokenStatus::PreviewMapped,
  )
  inspect(fluent_duration_ultra_fast.expected_runtime_value, content="50")
  inspect(fluent_duration_ultra_fast.runtime_value, content="100")
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
      "durationFaster",
    )
    is Some(fluent_duration_fast) else {
    fail("expected Fluent faster duration runtime alignment")
  }
  assert_true(fluent_duration_fast.runtime_aligned)
  assert_true(
    fluent_duration_fast.status == @common.DesignTokenStatus::ThemeMapped,
  )
  inspect(fluent_duration_fast.runtime_value, content="100")
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for("durationFast")
    is Some(fluent_duration_fast_preview) else {
    fail("expected Fluent fast duration runtime alignment")
  }
  assert_true(fluent_duration_fast_preview.source_value_resolved)
  assert_true(fluent_duration_fast_preview.runtime_value_available)
  assert_false(fluent_duration_fast_preview.runtime_aligned)
  assert_true(
    fluent_duration_fast_preview.status ==
    @common.DesignTokenStatus::PreviewMapped,
  )
  inspect(fluent_duration_fast_preview.expected_runtime_value, content="150")
  inspect(fluent_duration_fast_preview.runtime_value, content="100")
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
      "durationNormal",
    )
    is Some(fluent_duration) else {
    fail("expected Fluent duration runtime alignment")
  }
  assert_true(fluent_duration.runtime_aligned)
  assert_true(fluent_duration.status == @common.DesignTokenStatus::ThemeMapped)
  inspect(fluent_duration.runtime_value, content="200")
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
      "durationGentle",
    )
    is Some(fluent_duration_gentle) else {
    fail("expected Fluent gentle duration runtime alignment")
  }
  assert_true(fluent_duration_gentle.source_value_resolved)
  assert_true(fluent_duration_gentle.runtime_value_available)
  assert_false(fluent_duration_gentle.runtime_aligned)
  assert_true(
    fluent_duration_gentle.status == @common.DesignTokenStatus::PreviewMapped,
  )
  inspect(fluent_duration_gentle.expected_runtime_value, content="250")
  inspect(fluent_duration_gentle.runtime_value, content="200")
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for("durationSlow")
    is Some(fluent_duration_slow) else {
    fail("expected Fluent slow duration runtime alignment")
  }
  assert_true(fluent_duration_slow.runtime_aligned)
  assert_true(
    fluent_duration_slow.status == @common.DesignTokenStatus::ThemeMapped,
  )
  inspect(fluent_duration_slow.runtime_value, content="300")
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
      "durationSlower",
    )
    is Some(fluent_duration_slower) else {
    fail("expected Fluent slower duration runtime alignment")
  }
  assert_true(fluent_duration_slower.source_value_resolved)
  assert_true(fluent_duration_slower.runtime_value_available)
  assert_false(fluent_duration_slower.runtime_aligned)
  assert_true(
    fluent_duration_slower.status == @common.DesignTokenStatus::PreviewMapped,
  )
  inspect(fluent_duration_slower.expected_runtime_value, content="400")
  inspect(fluent_duration_slower.runtime_value, content="300")
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
      "durationUltraSlow",
    )
    is Some(fluent_duration_ultra_slow) else {
    fail("expected Fluent ultra-slow duration runtime alignment")
  }
  assert_true(fluent_duration_ultra_slow.source_value_resolved)
  assert_true(fluent_duration_ultra_slow.runtime_value_available)
  assert_false(fluent_duration_ultra_slow.runtime_aligned)
  assert_true(
    fluent_duration_ultra_slow.status ==
    @common.DesignTokenStatus::PreviewMapped,
  )
  inspect(fluent_duration_ultra_slow.expected_runtime_value, content="500")
  inspect(fluent_duration_ultra_slow.runtime_value, content="300")
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
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
      "curveEasyEase",
    )
    is Some(fluent_curve) else {
    fail("expected Fluent curve runtime alignment row")
  }
  assert_true(fluent_curve.source_imported)
  assert_true(fluent_curve.source_value_resolved)
  assert_true(fluent_curve.runtime_value_available)
  assert_false(fluent_curve.runtime_aligned)
  assert_true(fluent_curve.status == @common.DesignTokenStatus::PreviewMapped)
  inspect(
    fluent_curve.expected_runtime_value,
    content="cubic-bezier(0.33,0,0.67,1)",
  )
  inspect(fluent_curve.runtime_value, content="ease-out")
  assert_fluent_preview_curve_runtime_alignment(
    "curveLinear", "cubic-bezier(0,0,1,1)",
  )
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(
      "colorNeutralBackground1Hover",
    )
    is Some(fluent_hover) else {
    fail("expected Fluent hover runtime alignment row")
  }
  assert_false(fluent_hover.runtime_aligned)
  assert_true(fluent_hover.source_value_resolved)
  assert_true(fluent_hover.runtime_value_available)
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--fgColor-default",
    )
    is Some(primer_foreground) else {
    fail("expected Primer foreground runtime alignment")
  }
  assert_true(primer_foreground.runtime_aligned)
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--fgColor-accent",
    )
    is Some(primer_accent) else {
    fail("expected Primer accent runtime alignment")
  }
  assert_true(primer_accent.runtime_aligned)
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--button-primary-bgColor-rest",
    )
    is Some(primer_button) else {
    fail("expected Primer primary button runtime alignment row")
  }
  assert_true(primer_button.source_imported)
  assert_true(primer_button.source_value_resolved)
  assert_true(primer_button.runtime_value_available)
  assert_false(primer_button.runtime_aligned)
  assert_true(primer_button.status == @common.DesignTokenStatus::PreviewMapped)
  assert_true(
    primer_button.expected_runtime_value != primer_button.runtime_value,
  )
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--progressBar-fgColor-accent",
    )
    is Some(primer_progress) else {
    fail("expected Primer progress runtime alignment")
  }
  assert_true(primer_progress.source_imported)
  assert_true(primer_progress.source_value_resolved)
  assert_true(primer_progress.runtime_value_available)
  assert_true(primer_progress.runtime_aligned)
  assert_true(
    primer_progress.status == @common.DesignTokenStatus::ComponentMapped,
  )
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--base-size-4",
    )
    is Some(primer_base_size_xs) else {
    fail("expected Primer base size 4 runtime alignment")
  }
  assert_true(primer_base_size_xs.source_imported)
  assert_true(primer_base_size_xs.source_value_resolved)
  assert_true(primer_base_size_xs.runtime_value_available)
  assert_true(primer_base_size_xs.runtime_aligned)
  assert_true(
    primer_base_size_xs.status == @common.DesignTokenStatus::ThemeMapped,
  )
  inspect(primer_base_size_xs.runtime_value, content="4")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--base-size-8",
    )
    is Some(primer_base_size_sm) else {
    fail("expected Primer base size 8 runtime alignment")
  }
  assert_true(primer_base_size_sm.runtime_aligned)
  assert_true(
    primer_base_size_sm.status == @common.DesignTokenStatus::ThemeMapped,
  )
  inspect(primer_base_size_sm.runtime_value, content="8")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--base-size-12",
    )
    is Some(primer_base_size_md) else {
    fail("expected Primer base size 12 runtime alignment")
  }
  assert_true(primer_base_size_md.runtime_aligned)
  assert_true(
    primer_base_size_md.status == @common.DesignTokenStatus::ThemeMapped,
  )
  inspect(primer_base_size_md.runtime_value, content="12")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--base-size-16",
    )
    is Some(primer_base_size) else {
    fail("expected Primer base size runtime alignment")
  }
  assert_true(primer_base_size.source_imported)
  assert_true(primer_base_size.source_value_resolved)
  assert_true(primer_base_size.runtime_value_available)
  assert_true(primer_base_size.runtime_aligned)
  assert_true(primer_base_size.status == @common.DesignTokenStatus::ThemeMapped)
  inspect(primer_base_size.runtime_value, content="16")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--base-size-24",
    )
    is Some(primer_base_size_xl) else {
    fail("expected Primer base size 24 runtime alignment")
  }
  assert_true(primer_base_size_xl.runtime_aligned)
  assert_true(
    primer_base_size_xl.status == @common.DesignTokenStatus::ThemeMapped,
  )
  inspect(primer_base_size_xl.runtime_value, content="24")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--base-text-size-xs",
    )
    is Some(primer_caption_size) else {
    fail("expected Primer caption text size runtime alignment")
  }
  assert_true(primer_caption_size.source_imported)
  assert_true(primer_caption_size.source_value_resolved)
  assert_true(primer_caption_size.runtime_value_available)
  assert_true(primer_caption_size.runtime_aligned)
  assert_true(
    primer_caption_size.status == @common.DesignTokenStatus::ThemeMapped,
  )
  inspect(primer_caption_size.runtime_value, content="12")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--base-text-size-sm",
    )
    is Some(primer_body_size) else {
    fail("expected Primer body text size runtime alignment")
  }
  assert_true(primer_body_size.runtime_aligned)
  assert_true(primer_body_size.status == @common.DesignTokenStatus::ThemeMapped)
  inspect(primer_body_size.runtime_value, content="14")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--base-text-size-lg",
    )
    is Some(primer_title_size) else {
    fail("expected Primer title text size runtime alignment")
  }
  assert_true(primer_title_size.runtime_aligned)
  assert_true(
    primer_title_size.status == @common.DesignTokenStatus::ThemeMapped,
  )
  inspect(primer_title_size.runtime_value, content="20")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--base-text-weight-normal",
    )
    is Some(primer_body_weight) else {
    fail("expected Primer body text weight runtime alignment")
  }
  assert_true(primer_body_weight.runtime_aligned)
  assert_true(
    primer_body_weight.status == @common.DesignTokenStatus::ThemeMapped,
  )
  inspect(primer_body_weight.runtime_value, content="400")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--base-text-weight-semibold",
    )
    is Some(primer_control_weight) else {
    fail("expected Primer control text weight runtime alignment")
  }
  assert_true(primer_control_weight.runtime_aligned)
  assert_true(
    primer_control_weight.status == @common.DesignTokenStatus::ThemeMapped,
  )
  inspect(primer_control_weight.runtime_value, content="600")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--borderRadius-small",
    )
    is Some(primer_radius_small) else {
    fail("expected Primer small radius runtime alignment")
  }
  assert_true(primer_radius_small.source_imported)
  assert_true(primer_radius_small.source_value_resolved)
  assert_true(primer_radius_small.runtime_value_available)
  assert_false(primer_radius_small.runtime_aligned)
  assert_true(
    primer_radius_small.status == @common.DesignTokenStatus::PreviewMapped,
  )
  inspect(primer_radius_small.expected_runtime_value, content="3")
  inspect(primer_radius_small.runtime_value, content="4")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--borderRadius-medium",
    )
    is Some(primer_radius_medium) else {
    fail("expected Primer medium radius runtime alignment")
  }
  assert_true(primer_radius_medium.runtime_aligned)
  assert_true(
    primer_radius_medium.status == @common.DesignTokenStatus::ThemeMapped,
  )
  inspect(primer_radius_medium.runtime_value, content="6")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--borderRadius-large",
    )
    is Some(primer_radius_large) else {
    fail("expected Primer large radius runtime alignment")
  }
  assert_false(primer_radius_large.runtime_aligned)
  assert_true(
    primer_radius_large.status == @common.DesignTokenStatus::PreviewMapped,
  )
  inspect(primer_radius_large.expected_runtime_value, content="12")
  inspect(primer_radius_large.runtime_value, content="8")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--borderRadius-full",
    )
    is Some(primer_radius_full) else {
    fail("expected Primer full radius runtime alignment")
  }
  assert_false(primer_radius_full.runtime_aligned)
  assert_true(
    primer_radius_full.status == @common.DesignTokenStatus::PreviewMapped,
  )
  inspect(primer_radius_full.expected_runtime_value, content="9999")
  inspect(primer_radius_full.runtime_value, content="999")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--borderRadius-default",
    )
    is Some(primer_radius_default) else {
    fail("expected Primer default radius runtime alignment")
  }
  assert_true(primer_radius_default.runtime_aligned)
  assert_true(
    primer_radius_default.status == @common.DesignTokenStatus::ThemeMapped,
  )
  inspect(primer_radius_default.runtime_value, content="6")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--shadow-resting-small",
    )
    is Some(primer_shadow_small) else {
    fail("expected Primer small resting shadow runtime alignment")
  }
  assert_true(primer_shadow_small.source_imported)
  assert_true(primer_shadow_small.source_value_resolved)
  assert_true(primer_shadow_small.runtime_value_available)
  assert_true(primer_shadow_small.runtime_aligned)
  assert_true(
    primer_shadow_small.status == @common.DesignTokenStatus::PreviewMapped,
  )
  inspect(primer_shadow_small.runtime_value, content="1")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--shadow-resting-medium",
    )
    is Some(primer_shadow_medium) else {
    fail("expected Primer medium resting shadow runtime alignment")
  }
  assert_true(primer_shadow_medium.source_value_resolved)
  assert_true(primer_shadow_medium.runtime_value_available)
  assert_false(primer_shadow_medium.runtime_aligned)
  assert_true(
    primer_shadow_medium.status == @common.DesignTokenStatus::PreviewMapped,
  )
  inspect(primer_shadow_medium.expected_runtime_value, content="3")
  inspect(primer_shadow_medium.runtime_value, content="4")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--shadow-floating-large",
    )
    is Some(primer_shadow_large) else {
    fail("expected Primer large floating shadow runtime alignment")
  }
  assert_true(primer_shadow_large.source_value_resolved)
  assert_true(primer_shadow_large.runtime_value_available)
  assert_false(primer_shadow_large.runtime_aligned)
  assert_true(
    primer_shadow_large.status == @common.DesignTokenStatus::PreviewMapped,
  )
  inspect(primer_shadow_large.expected_runtime_value, content="40")
  inspect(primer_shadow_large.runtime_value, content="10")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--base-duration-0",
    )
    is Some(primer_duration_zero) else {
    fail("expected Primer 0ms duration runtime alignment")
  }
  assert_true(primer_duration_zero.source_imported)
  assert_true(primer_duration_zero.source_value_resolved)
  assert_true(primer_duration_zero.runtime_value_available)
  assert_false(primer_duration_zero.runtime_aligned)
  assert_true(
    primer_duration_zero.status == @common.DesignTokenStatus::PreviewMapped,
  )
  inspect(primer_duration_zero.expected_runtime_value, content="0")
  inspect(primer_duration_zero.runtime_value, content="100")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
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
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--base-duration-200",
    )
    is Some(primer_duration_normal) else {
    fail("expected Primer 200ms duration runtime alignment")
  }
  assert_true(primer_duration_normal.source_imported)
  assert_true(primer_duration_normal.source_value_resolved)
  assert_true(primer_duration_normal.runtime_value_available)
  assert_false(primer_duration_normal.runtime_aligned)
  assert_true(
    primer_duration_normal.status == @common.DesignTokenStatus::PreviewMapped,
  )
  inspect(primer_duration_normal.expected_runtime_value, content="200")
  inspect(primer_duration_normal.runtime_value, content="160")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--base-duration-300",
    )
    is Some(primer_duration_slow) else {
    fail("expected Primer 300ms duration runtime alignment")
  }
  assert_true(primer_duration_slow.source_imported)
  assert_true(primer_duration_slow.source_value_resolved)
  assert_true(primer_duration_slow.runtime_value_available)
  assert_false(primer_duration_slow.runtime_aligned)
  assert_true(
    primer_duration_slow.status == @common.DesignTokenStatus::PreviewMapped,
  )
  inspect(primer_duration_slow.expected_runtime_value, content="300")
  inspect(primer_duration_slow.runtime_value, content="260")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--base-duration-1000",
    )
    is Some(primer_duration_long) else {
    fail("expected Primer 1000ms duration runtime alignment")
  }
  assert_true(primer_duration_long.source_imported)
  assert_true(primer_duration_long.source_value_resolved)
  assert_true(primer_duration_long.runtime_value_available)
  assert_false(primer_duration_long.runtime_aligned)
  assert_true(
    primer_duration_long.status == @common.DesignTokenStatus::PreviewMapped,
  )
  inspect(primer_duration_long.expected_runtime_value, content="1000")
  inspect(primer_duration_long.runtime_value, content="260")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--base-easing-linear",
    )
    is Some(primer_linear) else {
    fail("expected Primer linear easing runtime alignment")
  }
  assert_true(primer_linear.source_imported)
  assert_true(primer_linear.source_value_resolved)
  assert_true(primer_linear.runtime_value_available)
  assert_false(primer_linear.runtime_aligned)
  assert_true(primer_linear.status == @common.DesignTokenStatus::PreviewMapped)
  inspect(primer_linear.expected_runtime_value, content="cubic-bezier(0,0,1,1)")
  inspect(primer_linear.runtime_value, content="ease-out")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--base-easing-easeOut",
    )
    is Some(primer_easing) else {
    fail("expected Primer easeOut runtime alignment")
  }
  assert_true(primer_easing.source_imported)
  assert_true(primer_easing.source_value_resolved)
  assert_true(primer_easing.runtime_value_available)
  assert_false(primer_easing.runtime_aligned)
  assert_true(primer_easing.status == @common.DesignTokenStatus::PreviewMapped)
  inspect(
    primer_easing.expected_runtime_value,
    content="cubic-bezier(0.3,0.8,0.6,1)",
  )
  inspect(primer_easing.runtime_value, content="ease-out")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--base-easing-easeInOut",
    )
    is Some(primer_ease_in_out) else {
    fail("expected Primer easeInOut runtime alignment")
  }
  assert_true(primer_ease_in_out.source_imported)
  assert_true(primer_ease_in_out.source_value_resolved)
  assert_true(primer_ease_in_out.runtime_value_available)
  assert_false(primer_ease_in_out.runtime_aligned)
  assert_true(
    primer_ease_in_out.status == @common.DesignTokenStatus::PreviewMapped,
  )
  inspect(
    primer_ease_in_out.expected_runtime_value,
    content="cubic-bezier(0.6,0,0.2,1)",
  )
  inspect(primer_ease_in_out.runtime_value, content="ease-out")
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--control-bgColor-rest",
    )
    is Some(primer_control) else {
    fail("expected Primer control rest background runtime alignment")
  }
  assert_true(primer_control.source_imported)
  assert_true(primer_control.source_value_resolved)
  assert_true(primer_control.runtime_value_available)
  assert_true(primer_control.runtime_aligned)
  assert_true(
    primer_control.status == @common.DesignTokenStatus::ComponentMapped,
  )
  assert_true(
    primer_control.moui_token == "DesignComponentTokens.picker.background",
  )
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--control-transparent-bgColor-hover",
    )
    is Some(primer_control_hover) else {
    fail("expected Primer transparent hover runtime alignment")
  }
  assert_true(primer_control_hover.source_imported)
  assert_true(primer_control_hover.source_value_resolved)
  assert_true(primer_control_hover.runtime_value_available)
  assert_false(primer_control_hover.runtime_aligned)
  assert_true(
    primer_control_hover.status == @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(
    primer_control_hover.expected_runtime_value !=
    primer_control_hover.runtime_value,
  )
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--control-borderColor-emphasis",
    )
    is Some(primer_control_border) else {
    fail("expected Primer control emphasized border runtime alignment")
  }
  assert_true(primer_control_border.source_imported)
  assert_true(primer_control_border.source_value_resolved)
  assert_true(primer_control_border.runtime_value_available)
  assert_false(primer_control_border.runtime_aligned)
  assert_true(
    primer_control_border.status == @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(
    primer_control_border.expected_runtime_value !=
    primer_control_border.runtime_value,
  )
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--bgColor-muted",
    )
    is Some(primer_surface) else {
    fail("expected Primer surface runtime alignment")
  }
  assert_true(primer_surface.runtime_aligned)
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--bgColor-inset",
    )
    is Some(primer_surface_variant) else {
    fail("expected Primer surface-variant runtime alignment")
  }
  assert_true(primer_surface_variant.runtime_aligned)
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--borderColor-default",
    )
    is Some(primer_outline) else {
    fail("expected Primer outline runtime alignment")
  }
  assert_true(primer_outline.runtime_aligned)
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--fgColor-muted",
    )
    is Some(primer_muted) else {
    fail("expected Primer muted runtime alignment")
  }
  assert_true(primer_muted.runtime_aligned)
  guard @common.DesignPreset::Primer.runtime_token_alignment_for(
      "--fgColor-danger",
    )
    is Some(primer_danger) else {
    fail("expected Primer danger runtime alignment")
  }
  assert_true(primer_danger.runtime_aligned)
  guard @common.DesignPreset::Material.runtime_token_alignment_for(
      "--md-sys-color-primary",
    )
    is Some(material_primary) else {
    fail("expected Material primary runtime alignment row")
  }
  assert_true(material_primary.source_imported)
  assert_true(material_primary.source_value_resolved)
  assert_true(material_primary.runtime_aligned)
  guard @common.DesignPreset::Material.runtime_token_alignment_for(
      "--md-sys-color-on-primary",
    )
    is Some(material_on_primary) else {
    fail("expected Material on-primary runtime alignment row")
  }
  assert_true(material_on_primary.runtime_aligned)
  guard @common.DesignPreset::Material.runtime_token_alignment_for(
      "--md-sys-color-error",
    )
    is Some(material_error) else {
    fail("expected Material error runtime alignment row")
  }
  assert_true(material_error.runtime_aligned)
  guard @common.DesignPreset::Material.runtime_token_alignment_for(
      "--md-sys-color-outline",
    )
    is Some(material_outline) else {
    fail("expected Material outline runtime alignment row")
  }
  assert_true(material_outline.runtime_aligned)
  guard @common.DesignPreset::Material.runtime_token_alignment_for(
      "--md-filled-button-container-color",
    )
    is Some(material_button_container) else {
    fail("expected Material filled-button container runtime alignment row")
  }
  assert_true(material_button_container.source_imported)
  assert_true(material_button_container.source_value_resolved)
  assert_true(material_button_container.runtime_value_available)
  assert_true(material_button_container.runtime_aligned)
  guard @common.DesignPreset::Material.runtime_token_alignment_for(
      "--md-filled-button-label-text-color",
    )
    is Some(material_button_label) else {
    fail("expected Material filled-button label runtime alignment row")
  }
  assert_true(material_button_label.source_imported)
  assert_true(material_button_label.source_value_resolved)
  assert_true(material_button_label.runtime_value_available)
  assert_true(material_button_label.runtime_aligned)
  guard @common.DesignPreset::Material.runtime_token_alignment_for(
      "--md-filled-button-pressed-state-layer-opacity",
    )
    is Some(material_button_pressed) else {
    fail("expected Material filled-button pressed runtime alignment row")
  }
  assert_true(material_button_pressed.source_imported)
  assert_true(material_button_pressed.source_value_resolved)
  assert_true(material_button_pressed.runtime_value_available)
  assert_true(material_button_pressed.runtime_aligned)
  guard @common.DesignPreset::Material.runtime_token_alignment_for(
      "--md-sys-typescale-body-medium-size",
    )
    is Some(material_body_size) else {
    fail("expected Material body type runtime alignment row")
  }
  assert_true(material_body_size.source_imported)
  assert_true(material_body_size.source_value_resolved)
  assert_true(material_body_size.runtime_value_available)
  assert_true(material_body_size.runtime_aligned)
  guard @common.DesignPreset::Material.runtime_token_alignment_for(
      "--md-sys-shape-corner-medium",
    )
    is Some(material_corner) else {
    fail("expected Material medium corner runtime alignment row")
  }
  assert_true(material_corner.source_imported)
  assert_true(material_corner.source_value_resolved)
  assert_true(material_corner.runtime_value_available)
  assert_true(material_corner.runtime_aligned)
  guard @common.DesignPreset::Material.runtime_token_alignment_for(
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
  guard @common.DesignPreset::Material.runtime_token_alignment_for(
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
  guard @common.DesignPreset::Material.runtime_token_alignment_for(
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
  guard @common.DesignPreset::Material.runtime_token_alignment_for(
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
  guard @common.DesignPreset::Material.runtime_token_alignment_for(
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
  guard @common.DesignPreset::Material.runtime_token_alignment_for(
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
  guard @common.DesignPreset::Material.runtime_token_alignment_for(
      "--md-sys-motion-easing-standard",
    )
    is Some(material_motion_easing) else {
    fail("expected Material standard easing runtime alignment row")
  }
  assert_true(material_motion_easing.source_imported)
  assert_true(material_motion_easing.source_value_resolved)
  assert_true(material_motion_easing.runtime_value_available)
  assert_false(material_motion_easing.runtime_aligned)
  assert_true(
    material_motion_easing.status == @common.DesignTokenStatus::PreviewMapped,
  )
  inspect(
    material_motion_easing.expected_runtime_value,
    content="cubic-bezier(0.2,0,0,1)",
  )
  inspect(material_motion_easing.runtime_value, content="ease-out")
  guard @common.DesignPreset::Material.runtime_token_alignment_for(
      "--md-sys-motion-*",
    )
    is Some(material_motion) else {
    fail("expected Material motion runtime alignment row")
  }
  assert_true(material_motion.source_imported)
  assert_true(material_motion.source_value_resolved)
  assert_true(material_motion.runtime_value_available)
  assert_true(material_motion.runtime_aligned)
  guard @common.DesignPreset::Material.runtime_token_alignment_for(
      "--md-linear-progress-active-indicator-color",
    )
    is Some(material_progress) else {
    fail("expected Material progress runtime alignment row")
  }
  assert_true(material_progress.source_imported)
  assert_true(material_progress.source_value_resolved)
  assert_true(material_progress.runtime_value_available)
  assert_true(material_progress.runtime_aligned)
  guard @common.DesignPreset::Material.runtime_token_alignment_for(
      "--md-menu-container-color",
    )
    is Some(material_menu) else {
    fail("expected Material menu runtime alignment row")
  }
  assert_true(material_menu.source_imported)
  assert_true(material_menu.source_value_resolved)
  assert_true(material_menu.runtime_value_available)
  assert_true(material_menu.runtime_aligned)
  guard @common.DesignPreset::Material.runtime_token_alignment_for(
      "--md-sys-spacing-*",
    )
    is Some(material_spacing) else {
    fail("expected Material spacing runtime alignment gap")
  }
  assert_false(material_spacing.source_imported)
  assert_false(material_spacing.required)
  assert_false(material_spacing.runtime_aligned)
  guard @common.DesignPreset::Carbon.runtime_token_alignment_for("$background")
    is Some(carbon_background) else {
    fail("expected Carbon background runtime alignment row")
  }
  assert_true(carbon_background.source_imported)
  assert_true(carbon_background.source_value_resolved)
  assert_true(carbon_background.runtime_aligned)
  guard @common.DesignPreset::Carbon.runtime_token_alignment_for(
      "$text-primary",
    )
    is Some(carbon_text) else {
    fail("expected Carbon text runtime alignment row")
  }
  assert_true(carbon_text.runtime_aligned)
  guard @common.DesignPreset::Carbon.runtime_token_alignment_for(
      "$support-error",
    )
    is Some(carbon_error) else {
    fail("expected Carbon support-error runtime alignment row")
  }
  assert_true(carbon_error.runtime_aligned)
  guard @common.DesignPreset::Carbon.runtime_token_alignment_for(
      "$button-primary",
    )
    is Some(carbon_button) else {
    fail("expected Carbon button-primary runtime alignment row")
  }
  assert_true(carbon_button.source_imported)
  assert_true(carbon_button.source_value_resolved)
  assert_true(carbon_button.runtime_aligned)
  guard @common.DesignPreset::Carbon.runtime_token_alignment_for(
      "$background-hover",
    )
    is Some(carbon_hover) else {
    fail("expected Carbon background-hover runtime alignment row")
  }
  assert_true(carbon_hover.source_imported)
  assert_true(carbon_hover.source_value_resolved)
  assert_true(carbon_hover.runtime_value_available)
  assert_true(carbon_hover.runtime_aligned)
  guard @common.DesignPreset::Carbon.runtime_token_alignment_for(
      "$border-interactive",
    )
    is Some(carbon_border) else {
    fail("expected Carbon border-interactive runtime alignment row")
  }
  assert_true(carbon_border.source_imported)
  assert_true(carbon_border.source_value_resolved)
  assert_true(carbon_border.runtime_value_available)
  assert_true(carbon_border.runtime_aligned)
  guard @common.DesignPreset::Carbon.runtime_token_alignment_for("$field")
    is Some(carbon_field) else {
    fail("expected Carbon field runtime alignment row")
  }
  assert_true(carbon_field.source_imported)
  assert_true(carbon_field.source_value_resolved)
  assert_true(carbon_field.runtime_value_available)
  assert_true(carbon_field.runtime_aligned)
  guard @common.DesignPreset::Carbon.runtime_token_alignment_for(
      "$slider-filled-track",
    )
    is Some(carbon_slider) else {
    fail("expected Carbon slider filled-track runtime alignment row")
  }
  assert_true(carbon_slider.source_imported)
  assert_true(carbon_slider.source_value_resolved)
  assert_true(carbon_slider.runtime_value_available)
  assert_true(carbon_slider.runtime_aligned)
  assert_true(
    carbon_slider.status == @common.DesignTokenStatus::ComponentMapped,
  )
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
  guard @common.DesignPreset::Carbon.runtime_token_alignment_for(
      "$duration-fast-01",
    )
    is Some(carbon_duration_fast01) else {
    fail("expected Carbon fast-01 duration runtime alignment row")
  }
  assert_true(carbon_duration_fast01.source_imported)
  assert_true(carbon_duration_fast01.source_value_resolved)
  assert_true(carbon_duration_fast01.runtime_value_available)
  assert_false(carbon_duration_fast01.runtime_aligned)
  assert_true(
    carbon_duration_fast01.status == @common.DesignTokenStatus::PreviewMapped,
  )
  inspect(carbon_duration_fast01.expected_runtime_value, content="70")
  inspect(carbon_duration_fast01.runtime_value, content="90")
  guard @common.DesignPreset::Carbon.runtime_token_alignment_for(
      "$duration-fast-02",
    )
    is Some(carbon_duration_fast) else {
    fail("expected Carbon fast duration runtime alignment row")
  }
  assert_true(carbon_duration_fast.source_imported)
  assert_true(carbon_duration_fast.source_value_resolved)
  assert_true(carbon_duration_fast.runtime_value_available)
  assert_false(carbon_duration_fast.runtime_aligned)
  assert_true(
    carbon_duration_fast.status == @common.DesignTokenStatus::PreviewMapped,
  )
  inspect(carbon_duration_fast.expected_runtime_value, content="110")
  inspect(carbon_duration_fast.runtime_value, content="90")
  guard @common.DesignPreset::Carbon.runtime_token_alignment_for(
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
  guard @common.DesignPreset::Carbon.runtime_token_alignment_for(
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
  guard @common.DesignPreset::Carbon.runtime_token_alignment_for(
      "$duration-slow-02",
    )
    is Some(carbon_duration_slow02) else {
    fail("expected Carbon slow-02 duration runtime alignment row")
  }
  assert_true(carbon_duration_slow02.source_imported)
  assert_true(carbon_duration_slow02.source_value_resolved)
  assert_true(carbon_duration_slow02.runtime_value_available)
  assert_false(carbon_duration_slow02.runtime_aligned)
  assert_true(
    carbon_duration_slow02.status == @common.DesignTokenStatus::PreviewMapped,
  )
  inspect(carbon_duration_slow02.expected_runtime_value, content="700")
  inspect(carbon_duration_slow02.runtime_value, content="240")
  guard @common.DesignPreset::Carbon.runtime_token_alignment_for(
      "easings.standard.productive",
    )
    is Some(carbon_easing) else {
    fail("expected Carbon standard productive easing runtime alignment row")
  }
  assert_true(carbon_easing.source_imported)
  assert_true(carbon_easing.source_value_resolved)
  assert_true(carbon_easing.runtime_value_available)
  assert_false(carbon_easing.runtime_aligned)
  assert_true(carbon_easing.status == @common.DesignTokenStatus::PreviewMapped)
  inspect(
    carbon_easing.expected_runtime_value,
    content="cubic-bezier(0.2,0,0.38,0.9)",
  )
  inspect(carbon_easing.runtime_value, content="ease-in-out")
  guard @common.DesignPreset::Carbon.runtime_token_alignment_for(
      "easings.exit.expressive",
    )
    is Some(carbon_easing_exit) else {
    fail("expected Carbon expressive exit easing runtime alignment row")
  }
  assert_true(carbon_easing_exit.source_imported)
  assert_true(carbon_easing_exit.source_value_resolved)
  assert_true(carbon_easing_exit.runtime_value_available)
  assert_false(carbon_easing_exit.runtime_aligned)
  assert_true(
    carbon_easing_exit.status == @common.DesignTokenStatus::PreviewMapped,
  )
  inspect(
    carbon_easing_exit.expected_runtime_value,
    content="cubic-bezier(0.4,0.14,1,1)",
  )
  inspect(carbon_easing_exit.runtime_value, content="ease-in-out")
}

///|
test "source manifests keep preview presets from claiming full official coverage" {
  let material = @common.DesignPreset::Material.manifest()
  assert_true(material.stage == @common.DesignTokenStatus::PreviewMapped)
  assert_true(
    material.token_coverage.any(item => {
      item.category == @common.DesignTokenCategory::StateLayer &&
      item.status == @common.DesignTokenStatus::ComponentMapped
    }),
  )
  assert_true(
    material.component_coverage.any(item => {
      item.component == "Progress" &&
      item.status == @common.DesignTokenStatus::ComponentMapped &&
      item.moui_surface == "@views.ProgressStyle"
    }),
  )
  assert_true(
    material.component_coverage.any(item => {
      item.component == "Slider" &&
      item.status == @common.DesignTokenStatus::ComponentMapped &&
      item.moui_surface == "@views.SliderStyle"
    }),
  )
  assert_true(
    material.component_coverage.any(item => {
      item.component == "Picker" &&
      item.status == @common.DesignTokenStatus::ComponentMapped &&
      item.moui_surface == "@views.PickerStyle"
    }),
  )
  assert_true(
    material.component_coverage.any(item => {
      item.component == "DatePicker" &&
      item.status == @common.DesignTokenStatus::ComponentMapped &&
      item.moui_surface == "@views.PickerStyle"
    }),
  )
  assert_true(
    material.component_coverage.any(item => {
      item.component == "Feedback" &&
      item.status == @common.DesignTokenStatus::ComponentMapped &&
      item.moui_surface == "@views.FeedbackStyle"
    }),
  )
  assert_true(
    material.component_coverage.any(item => {
      item.component == "Badge" &&
      item.status == @common.DesignTokenStatus::ComponentMapped &&
      item.moui_surface == "@views.BadgeStyle"
    }),
  )
  assert_true(
    material.component_coverage.any(item => {
      item.component == "FormValidation" &&
      item.status == @common.DesignTokenStatus::ComponentMapped &&
      item.moui_surface == "@views.FormValidationStyle"
    }),
  )
}

///|
test "customization coverage advertises inheritance and token override APIs" {
  let manifest = @common.DesignPreset::Carbon.manifest()
  assert_true(manifest.customization_coverage.length() == 6)
  assert_true(
    manifest.customization_coverage.any(item => {
      item.capability == "Theme base inheritance" &&
      item.api_surface == "@common.custom(base=...)"
    }),
  )
  assert_true(
    manifest.customization_coverage.any(item => {
      item.capability == "Theme token group override" &&
      item.status == @common.DesignTokenStatus::ThemeMapped
    }),
  )
  assert_true(
    manifest.customization_coverage.any(item => {
      item.capability == "Design token group override" &&
      item.api_surface.contains("@common.custom_tokens")
    }),
  )
  assert_true(
    manifest.customization_coverage.any(item => {
      item.capability == "Component token override" &&
      item.status == @common.DesignTokenStatus::ComponentMapped
    }),
  )
  assert_true(
    manifest.customization_coverage.any(item => {
      item.capability == "Variant Theme resolver" &&
      item.api_surface.contains("theme_for_variant")
    }),
  )
}

///|
test "customization reports tie public APIs to neutral token surfaces" {
  for
    preset in [
      @common.DesignPreset::Material,
      @common.DesignPreset::Carbon,
      @common.DesignPreset::Primer,
      @common.DesignPreset::Fluent,
    ] {
    let report = preset.customization_report()
    assert_true(
      report.length() == preset.manifest().customization_coverage.length(),
    )
    assert_true(preset.customization_report_count() == 6)
    assert_true(preset.customization_capability_gap_count() == 0)
    assert_true(preset.customization_official_parity_gap_count() == 6)
    for item in report {
      assert_true(item.api_surface != "")
      assert_true(item.token_surface != "")
      assert_true(item.status != @common.DesignTokenStatus::NotMapped)
      assert_true(
        preset.manifest().customization_coverage.any(coverage => {
          coverage.capability == item.capability &&
          coverage.api_surface == item.api_surface
        }),
      )
    }
  }
  guard @common.DesignPreset::Material.customization_report_for(
      "Design token group override",
    )
    is Some(group_override) else {
    fail("expected design-token group override capability")
  }
  assert_true(
    group_override.kind ==
    @common.DesignCustomizationKind::DesignTokenGroupOverride,
  )
  assert_true(group_override.inherits_base)
  assert_true(group_override.supports_override)
  assert_true(group_override.recomputes_dependents)
  assert_true(group_override.remaining_gap.contains("Official per-system"))
  guard @common.DesignPreset::Primer.customization_report_for(
      "Component token override",
    )
    is Some(component_override) else {
    fail("expected component token override capability")
  }
  assert_true(
    component_override.kind ==
    @common.DesignCustomizationKind::ComponentTokenOverride,
  )
  assert_true(
    component_override.status == @common.DesignTokenStatus::ComponentMapped,
  )
  assert_true(component_override.token_surface == "DesignComponentTokens")
  guard @common.DesignPreset::Fluent.customization_report_for(
      "Variant Theme resolver",
    )
    is Some(variant_theme) else {
    fail("expected variant theme resolver capability")
  }
  assert_true(
    variant_theme.kind ==
    @common.DesignCustomizationKind::VariantThemeResolution,
  )
  assert_true(variant_theme.recomputes_dependents)
  assert_false(variant_theme.supports_override)
}

///|
test "requirement audits expose objective level gaps without claiming completion" {
  for
    preset in [
      @common.DesignPreset::Material,
      @common.DesignPreset::Carbon,
      @common.DesignPreset::Primer,
      @common.DesignPreset::Fluent,
    ] {
    let audit = preset.requirement_audit()
    assert_true(audit.length() >= 20)
    assert_false(preset.is_design_system_complete())
    assert_true(preset.requirement_gap_count() > 0)
    guard preset.requirement_audit_for(
        @common.DesignSystemRequirement::OfficialSources,
      )
      is Some(sources) else {
      fail("expected official sources audit")
    }
    assert_true(sources.status == @common.DesignTokenStatus::SourceMapped)
    assert_true(sources.evidence.contains("source anchors"))
    guard preset.requirement_audit_for(
        @common.DesignSystemRequirement::SourceVersionLocks,
      )
      is Some(source_versions) else {
      fail("expected source version lock audit")
    }
    assert_true(
      source_versions.status == @common.DesignTokenStatus::PreviewMapped,
    )
    assert_true(source_versions.evidence.contains("stable source locks"))
    assert_true(
      source_versions.remaining_gap.contains("Live official documentation"),
    )
    guard preset.requirement_audit_for(
        @common.DesignSystemRequirement::SourcePackageInventory,
      )
      is Some(source_packages) else {
      fail("expected source package inventory audit")
    }
    assert_true(
      source_packages.status == @common.DesignTokenStatus::PreviewMapped,
    )
    assert_true(source_packages.evidence.contains("source package rows"))
    assert_true(source_packages.evidence.contains("imported tokens"))
    assert_true(source_packages.evidence.contains("source-import records"))
    guard preset.requirement_audit_for(
        @common.DesignSystemRequirement::SourceImportedTokens,
      )
      is Some(source_imports) else {
      fail("expected source-imported token audit")
    }
    assert_true(
      source_imports.status == @common.DesignTokenStatus::SourceMapped,
    )
    assert_true(source_imports.evidence.contains("official anchors"))
    assert_true(source_imports.evidence.contains("import coverage gaps"))
    assert_true(source_imports.evidence.contains("integrity gaps"))
    for
      requirement in [
        @common.DesignSystemRequirement::SemanticPalette,
        @common.DesignSystemRequirement::Typography,
        @common.DesignSystemRequirement::ShapeRadius,
        @common.DesignSystemRequirement::ElevationShadow,
        @common.DesignSystemRequirement::Motion,
        @common.DesignSystemRequirement::Surface,
        @common.DesignSystemRequirement::StateLayer,
      ] {
      guard preset.requirement_audit_for(requirement) is Some(token_group) else {
        fail("expected token-group audit")
      }
      assert_true(token_group.status != @common.DesignTokenStatus::NotMapped)
      assert_true(token_group.evidence.contains("token-group resolver records"))
      assert_true(token_group.evidence.contains("source-lock gaps"))
      assert_true(token_group.evidence.contains("official parity gaps"))
    }
    guard preset.requirement_audit_for(
        @common.DesignSystemRequirement::SpacingDensity,
      )
      is Some(spacing_density) else {
      fail("expected spacing density audit")
    }
    assert_true(
      spacing_density.status == @common.DesignTokenStatus::PreviewMapped,
    )
    assert_true(spacing_density.evidence.contains("density resolver records"))
    assert_true(spacing_density.evidence.contains("source-lock gaps"))
    assert_true(spacing_density.evidence.contains("official parity gaps"))
    guard preset.requirement_audit_for(
        @common.DesignSystemRequirement::SchemeVariants,
      )
      is Some(scheme_variants) else {
      fail("expected scheme variant audit")
    }
    assert_true(
      scheme_variants.status == @common.DesignTokenStatus::PreviewMapped,
    )
    assert_true(scheme_variants.evidence.contains("variant resolver records"))
    assert_true(scheme_variants.evidence.contains("source-lock gaps"))
    assert_true(scheme_variants.evidence.contains("official parity gaps"))
    guard preset.requirement_audit_for(
        @common.DesignSystemRequirement::RuntimeTokenAlignment,
      )
      is Some(runtime_alignment) else {
      fail("expected runtime token alignment audit")
    }
    assert_true(
      runtime_alignment.status == @common.DesignTokenStatus::PreviewMapped,
    )
    assert_true(runtime_alignment.evidence.contains("runtime token rows"))
    assert_true(runtime_alignment.evidence.contains("alignment gaps"))
    guard preset.requirement_audit_for(
        @common.DesignSystemRequirement::Customization,
      )
      is Some(customization) else {
      fail("expected customization audit")
    }
    assert_true(
      customization.status == @common.DesignTokenStatus::ComponentMapped,
    )
    assert_true(
      customization.evidence.contains("customization capability records"),
    )
    assert_true(customization.evidence.contains("official parity gaps"))
    guard preset.requirement_audit_for(
        @common.DesignSystemRequirement::ComponentTokens,
      )
      is Some(components) else {
      fail("expected component token audit")
    }
    assert_true(components.status == @common.DesignTokenStatus::ComponentMapped)
    assert_true(components.evidence.contains("component token surfaces"))
    assert_true(
      components.evidence.contains("component style resolver records"),
    )
    assert_true(components.evidence.contains("source-lock gaps"))
    assert_true(components.evidence.contains("official parity gaps"))
    guard preset.requirement_audit_for(
        @common.DesignSystemRequirement::ComponentMatrix,
      )
      is Some(component_matrix) else {
      fail("expected component matrix audit")
    }
    assert_true(
      component_matrix.status == @common.DesignTokenStatus::PreviewMapped,
    )
    assert_true(component_matrix.evidence.contains("component matrix rows"))
    guard preset.requirement_audit_for(
        @common.DesignSystemRequirement::OfficialTokenCoverage,
      )
      is Some(official_tokens) else {
      fail("expected official token coverage audit")
    }
    assert_true(
      official_tokens.status == @common.DesignTokenStatus::PreviewMapped,
    )
    assert_true(official_tokens.evidence.contains("official token anchors"))
    guard preset.requirement_audit_for(
        @common.DesignSystemRequirement::GoldenMappings,
      )
      is Some(golden) else {
      fail("expected golden mapping audit")
    }
    assert_true(golden.status == @common.DesignTokenStatus::PreviewMapped)
    assert_true(golden.remaining_gap != "none")
    guard preset.requirement_audit_for(
        @common.DesignSystemRequirement::AdaptationDifferences,
      )
      is Some(adaptation) else {
      fail("expected adaptation differences audit")
    }
    assert_true(adaptation.status == @common.DesignTokenStatus::PreviewMapped)
    assert_true(adaptation.evidence.contains("adaptation records"))
  }
}

///|
test "token taxonomy reports tie required categories to source locked neutral surfaces" {
  for
    preset in [
      @common.DesignPreset::Material,
      @common.DesignPreset::Carbon,
      @common.DesignPreset::Primer,
      @common.DesignPreset::Fluent,
    ] {
    let rows = preset.token_taxonomy_report()
    assert_true(rows.length() == 10)
    assert_true(preset.token_taxonomy_count() == 10)
    assert_true(preset.token_taxonomy_required_count() == 10)
    assert_true(preset.token_taxonomy_mapped_count() == 10)
    assert_true(preset.token_taxonomy_gap_count() == 0)
    assert_true(preset.token_taxonomy_source_gap_count() == 0)
    if preset == @common.DesignPreset::Material {
      assert_true(preset.token_taxonomy_official_parity_gap_count() == 10)
    } else {
      assert_true(preset.token_taxonomy_official_parity_gap_count() == 8)
    }
    for item in rows {
      assert_true(item.required)
      assert_true(item.manifest_declared)
      assert_true(item.source_declared)
      assert_true(item.source_locked)
      assert_true(item.source_ref != "")
      assert_true(item.token_surface != "")
      assert_true(item.moui_surface != "")
      assert_false(item.moui_surface.contains("moui/views"))
      assert_true(item.status != @common.DesignTokenStatus::NotMapped)
    }
    guard preset.token_taxonomy_for(@common.DesignTokenCategory::Color)
      is Some(color) else {
      fail("expected color taxonomy row")
    }
    assert_true(color.token_surface.contains("DesignSemanticPalette"))
    assert_true(color.moui_surface.contains("@core."))
    guard preset.token_taxonomy_for(@common.DesignTokenCategory::Density)
      is Some(density) else {
      fail("expected density taxonomy row")
    }
    assert_true(density.token_surface.contains("DesignDensity"))
    assert_true(density.moui_surface.contains("@core.SpacingScale"))
    guard preset.token_taxonomy_for(@common.DesignTokenCategory::StateLayer)
      is Some(state_layer) else {
      fail("expected state-layer taxonomy row")
    }
    assert_true(state_layer.token_surface.contains("DesignStateLayerTokens"))
    assert_true(
      state_layer.status == @common.DesignTokenStatus::ComponentMapped,
    )
    guard preset.token_taxonomy_for(@common.DesignTokenCategory::ComponentStyle)
      is Some(component) else {
      fail("expected component-style taxonomy row")
    }
    assert_true(component.token_surface.contains("DesignComponentTokens"))
    assert_true(component.status == @common.DesignTokenStatus::ComponentMapped)
  }
}

///|
test "semantic palette role reports expose role-level source and core alignment gaps" {
  for
    preset in [
      @common.DesignPreset::Material,
      @common.DesignPreset::Carbon,
      @common.DesignPreset::Primer,
      @common.DesignPreset::Fluent,
    ] {
    let rows = preset.semantic_palette_role_report(
      scheme=@core.ColorScheme::Light,
    )
    assert_true(rows.length() == 14)
    assert_true(preset.semantic_palette_role_count() == 14)
    assert_true(preset.semantic_palette_role_mapped_count() > 0)
    assert_true(preset.semantic_palette_role_aligned_count() > 0)
    for item in rows {
      assert_true(item.required)
      assert_true(item.token_surface.contains("DesignSemanticPalette"))
      assert_true(item.core_surface.contains("@core."))
      assert_true(item.token_value == item.core_value)
      assert_true(item.resolves_core_surface)
      assert_true(item.status != @common.DesignTokenStatus::NotMapped)
    }
    guard preset.semantic_palette_role_for(
        @common.DesignSemanticPaletteRole::PalettePrimary,
      )
      is Some(primary) else {
      fail("expected primary semantic palette role")
    }
    assert_true(primary.token_surface == "DesignSemanticPalette.primary")
    assert_true(primary.core_surface == "@core.ColorPalette.primary")
    assert_true(primary.source_declared)
    assert_true(primary.source_locked)
    let expected_gap = match preset {
      @common.DesignPreset::Material => 4
      @common.DesignPreset::Carbon => 0
      @common.DesignPreset::Primer => 0
      @common.DesignPreset::Fluent => 0
    }
    assert_true(preset.semantic_palette_role_gap_count() == expected_gap)
    assert_true(preset.semantic_palette_role_source_gap_count() == expected_gap)
    assert_true(
      preset.semantic_palette_role_official_parity_gap_count() == expected_gap,
    )
    assert_true(primary.official_token_count > 0)
    assert_true(primary.source_imported_count > 0)
    assert_true(primary.runtime_aligned_count > 0)
    guard preset.semantic_palette_role_for(
        @common.DesignSemanticPaletteRole::PaletteFocus,
      )
      is Some(focus) else {
      fail("expected focus semantic palette role")
    }
    assert_true(focus.token_surface == "DesignSemanticPalette.focus")
    assert_true(focus.core_surface == "@core.SemanticColorScale.focus")
    if preset == @common.DesignPreset::Carbon {
      assert_true(focus.remaining_gap == "none")
      assert_true(focus.runtime_aligned_count > 0)
    } else if preset == @common.DesignPreset::Primer ||
      preset == @common.DesignPreset::Fluent {
      assert_true(focus.remaining_gap == "none")
      assert_true(focus.runtime_aligned_count > 0)
    } else {
      assert_true(focus.remaining_gap != "none")
    }
  }
}

///|
test "typography role reports expose role-level source and neutral typography gaps" {
  for
    preset in [
      @common.DesignPreset::Material,
      @common.DesignPreset::Carbon,
      @common.DesignPreset::Primer,
      @common.DesignPreset::Fluent,
    ] {
    let rows = preset.typography_role_report(scheme=@core.ColorScheme::Light)
    assert_true(rows.length() == 4)
    assert_true(preset.typography_role_count() == 4)
    for item in rows {
      assert_true(item.required)
      assert_true(item.token_surface.contains("DesignTypographyTokens"))
      assert_true(item.core_surface.contains("@core.TypographyScale"))
      assert_true(item.token_size == item.core_size)
      assert_true(item.token_weight == item.core_weight)
      assert_true(item.token_family == item.core_family)
      assert_true(item.resolves_core_surface)
      assert_true(item.source_declared)
      assert_true(item.source_locked)
      assert_true(item.status != @common.DesignTokenStatus::NotMapped)
    }
    guard preset.typography_role_for(
        @common.DesignTypographyRole::TypographyBody,
      )
      is Some(body) else {
      fail("expected body typography role")
    }
    assert_true(body.token_surface == "DesignTypographyTokens.body")
    assert_true(body.core_surface == "@core.TypographyScale.body")
    guard preset.typography_role_for(
        @common.DesignTypographyRole::TypographyTitle,
      )
      is Some(title) else {
      fail("expected title typography role")
    }
    assert_true(title.token_surface == "DesignTypographyTokens.title")
    guard preset.requirement_audit_for(
        @common.DesignSystemRequirement::Typography,
      )
      is Some(typography_audit) else {
      fail("expected typography requirement audit")
    }
    assert_true(typography_audit.evidence.contains("typography role records"))
    assert_true(
      typography_audit.status == @common.DesignTokenStatus::PreviewMapped,
    )
    if preset == @common.DesignPreset::Material ||
      preset == @common.DesignPreset::Carbon ||
      preset == @common.DesignPreset::Primer {
      assert_true(preset.typography_role_gap_count() == 0)
      assert_true(preset.typography_role_source_gap_count() == 0)
      assert_true(preset.typography_role_destination_gap_count() == 0)
      assert_true(preset.typography_role_official_parity_gap_count() == 0)
    } else {
      assert_true(preset.typography_role_gap_count() > 0)
      assert_true(preset.typography_role_official_parity_gap_count() > 0)
    }
  }
  guard @common.DesignPreset::Material.typography_role_for(
      @common.DesignTypographyRole::TypographyBody,
    )
    is Some(material_body) else {
    fail("expected Material body typography role")
  }
  assert_true(
    material_body.official_token == "--md-sys-typescale-body-medium-size",
  )
  assert_true(material_body.official_token_count == 1)
  assert_true(material_body.source_imported_count == 1)
  assert_true(material_body.runtime_aligned_count == 1)
  assert_true(material_body.remaining_gap == "none")
  guard @common.DesignPreset::Carbon.typography_role_for(
      @common.DesignTypographyRole::TypographyBody,
    )
    is Some(carbon_body) else {
    fail("expected Carbon body typography role")
  }
  assert_true(carbon_body.official_token == "$body-02")
  assert_true(carbon_body.official_token_count == 1)
  assert_true(carbon_body.source_imported_count == 1)
  assert_true(carbon_body.runtime_aligned_count == 1)
  assert_true(carbon_body.remaining_gap == "none")
  guard @common.DesignPreset::Primer.typography_role_for(
      @common.DesignTypographyRole::TypographyBody,
    )
    is Some(primer_body) else {
    fail("expected Primer body typography role")
  }
  assert_true(primer_body.official_token_count >= 2)
  assert_true(primer_body.source_imported_count >= 2)
  assert_true(primer_body.runtime_aligned_count >= 2)
  assert_true(primer_body.remaining_gap == "none")
  guard @common.DesignPreset::Fluent.typography_role_for(
      @common.DesignTypographyRole::TypographyBody,
    )
    is Some(fluent_body) else {
    fail("expected Fluent body typography role")
  }
  assert_true(fluent_body.official_token_count > 1)
  assert_true(fluent_body.source_imported_count > 1)
  assert_true(fluent_body.runtime_aligned_count > 0)
  assert_true(fluent_body.runtime_destination_gap_count > 0)
  assert_true(fluent_body.remaining_gap.contains("line-height"))
}

///|
test "design system reports aggregate generation ready evidence surfaces" {
  for
    preset in [
      @common.DesignPreset::Material,
      @common.DesignPreset::Carbon,
      @common.DesignPreset::Primer,
      @common.DesignPreset::Fluent,
    ] {
    let report = preset.design_system_report(
      scheme=@core.ColorScheme::Dark,
      system_scheme=@core.ColorScheme::Dark,
      density=@common.DesignDensity::Compact,
    )
    assert_true(report.preset == preset)
    assert_true(report.scheme == @core.ColorScheme::Dark)
    assert_true(report.system_scheme == @core.ColorScheme::Dark)
    assert_true(report.density == @common.DesignDensity::Compact)
    assert_true(report.manifest == preset.manifest())
    assert_true(report.complete == preset.is_design_system_complete())
    assert_true(report.gap_count() == preset.requirement_gap_count())
    assert_true(report.sources.length() == preset.sources().length())
    assert_true(
      report.requirement_audit.length() == preset.requirement_audit().length(),
    )
    assert_true(report.token_taxonomy.length() == preset.token_taxonomy_count())
    assert_true(
      report.taxonomy_gap_count() == preset.token_taxonomy_gap_count(),
    )
    assert_true(
      report.semantic_palette_roles.length() ==
      preset.semantic_palette_role_count(),
    )
    assert_true(
      report.semantic_palette_gap_count() ==
      preset.semantic_palette_role_official_parity_gap_count(),
    )
    assert_true(
      report.typography_roles.length() == preset.typography_role_count(),
    )
    assert_true(
      report.typography_gap_count() ==
      preset.typography_role_official_parity_gap_count(),
    )
    assert_true(
      report.source_locks.length() == preset.source_lock_report().length(),
    )
    assert_true(
      report.source_packages.length() == preset.source_package_inventory_count(),
    )
    assert_true(
      report.source_imports.length() == preset.source_imported_token_count(),
    )
    assert_true(
      report.source_import_coverage.length() ==
      preset.source_import_coverage_count(),
    )
    assert_true(
      report.source_import_integrity.length() ==
      preset.source_import_integrity_report().length(),
    )
    assert_true(
      report.runtime_alignment.length() ==
      preset.runtime_token_alignment_count(),
    )
    assert_true(
      report.token_group_resolvers.length() ==
      preset.token_group_resolver_count(),
    )
    assert_true(
      report.density_resolvers.length() == preset.density_resolver_count(),
    )
    assert_true(
      report.variant_resolvers.length() == preset.variant_resolver_count(),
    )
    assert_true(
      report.customization.length() == preset.customization_report_count(),
    )
    assert_true(
      report.official_token_coverage.length() ==
      preset.official_token_anchor_count(),
    )
    assert_true(
      report.official_token_source_usage.length() == preset.sources().length(),
    )
    assert_true(
      report.component_token_matrix.length() ==
      preset.component_token_matrix_count(),
    )
    assert_true(
      report.component_style_resolvers.length() ==
      preset.component_style_resolver_count(),
    )
    assert_true(report.adaptation.length() == preset.adaptation_record_count())
    assert_true(
      report.golden_mappings.length() == preset.golden_mappings().length(),
    )
    assert_true(
      report.unanchored_golden_mappings.length() ==
      preset.unanchored_golden_mapping_count(),
    )
    assert_true(report.evidence_row_count() > report.requirement_audit.length())
    for item in report.token_group_resolvers {
      assert_true(item.scheme == @core.ColorScheme::Dark)
    }
    for item in report.density_resolvers {
      assert_true(item.scheme == @core.ColorScheme::Dark)
    }
    for item in report.component_style_resolvers {
      assert_true(item.scheme == @core.ColorScheme::Dark)
    }
    for item in report.variant_resolvers {
      assert_true(item.system_scheme == @core.ColorScheme::Dark)
      assert_true(item.density == @common.DesignDensity::Compact)
    }
    if report.complete {
      assert_true(report.status == @common.DesignTokenStatus::OfficialComplete)
    } else {
      assert_true(report.status == report.manifest.stage)
    }
    assert_false(report.has_official_completion_claim())
    assert_true(report.note.contains("source-mapped preview"))
  }
}

///|
test "component token matrices expose source locked official component gaps" {
  for
    preset in [
      @common.DesignPreset::Material,
      @common.DesignPreset::Carbon,
      @common.DesignPreset::Primer,
      @common.DesignPreset::Fluent,
    ] {
    let rows = preset.component_token_matrix()
    assert_true(rows.length() == 11)
    assert_true(preset.component_token_matrix_count() == 11)
    assert_true(preset.component_token_matrix_mapped_count() > 0)
    assert_true(preset.component_token_matrix_source_imported_count() > 0)
    assert_true(preset.component_token_matrix_runtime_aligned_count() > 0)
    assert_true(
      preset.component_token_matrix_required_count() >
      preset.component_token_matrix_mapped_count(),
    )
    assert_true(preset.component_token_matrix_gap_count() > 0)
    assert_true(preset.component_token_matrix_source_gap_count() == 0)
    assert_false(rows.any(item => item.moui_surface.contains("moui/views")))
    assert_true(rows.any(item => item.component == "Button"))
    assert_true(rows.any(item => item.component == "TextField"))
    assert_true(rows.any(item => item.component == "Surface"))
    assert_true(rows.any(item => item.component == "ChoiceControl"))
    assert_true(rows.any(item => item.component == "Progress"))
    assert_true(rows.any(item => item.component == "Slider"))
    assert_true(rows.any(item => item.component == "Picker"))
    assert_true(rows.any(item => item.component == "DatePicker"))
    assert_true(rows.any(item => item.component == "Feedback"))
    assert_true(rows.any(item => item.component == "Badge"))
    assert_true(rows.any(item => item.component == "FormValidation"))
    for item in rows {
      assert_true(item.source_declared)
      assert_true(item.source_locked)
      assert_true(item.source_ref != "")
      assert_true(item.required_token_count > 0)
      assert_true(item.source_imported_token_count >= 0)
      assert_true(item.runtime_aligned_token_count >= 0)
      assert_true(
        item.runtime_aligned_token_count <= item.source_imported_token_count,
      )
      assert_true(item.pending_token_family != "")
    }
  }
  guard @common.DesignPreset::Material.component_token_matrix_for("Button")
    is Some(material_button) else {
    fail("expected Material button matrix")
  }
  assert_true(material_button.mapped_token_count == 3)
  assert_true(material_button.source_imported_token_count == 3)
  assert_true(material_button.runtime_aligned_token_count == 3)
  assert_true(
    material_button.required_token_count > material_button.mapped_token_count,
  )
  guard @common.DesignPreset::Material.component_token_matrix_for("TextField")
    is Some(material_text_field) else {
    fail("expected Material text-field matrix")
  }
  assert_true(material_text_field.source_imported_token_count == 0)
  assert_true(material_text_field.runtime_aligned_token_count == 0)
  guard @common.DesignPreset::Carbon.component_token_matrix_for("Feedback")
    is Some(carbon_feedback) else {
    fail("expected Carbon feedback matrix")
  }
  assert_true(carbon_feedback.mapped_token_count == 2)
  assert_true(carbon_feedback.source_imported_token_count >= 4)
  assert_true(carbon_feedback.runtime_aligned_token_count >= 3)
  guard @common.DesignPreset::Carbon.component_token_matrix_for("TextField")
    is Some(carbon_text_field) else {
    fail("expected Carbon text-field matrix")
  }
  assert_true(carbon_text_field.source_imported_token_count == 2)
  assert_true(carbon_text_field.runtime_aligned_token_count == 2)
  guard @common.DesignPreset::Primer.component_token_matrix_for("Button")
    is Some(primer_button) else {
    fail("expected Primer button matrix")
  }
  assert_true(primer_button.source_imported_token_count == 1)
  assert_true(primer_button.runtime_aligned_token_count == 0)
  guard @common.DesignPreset::Primer.component_token_matrix_for("Picker")
    is Some(primer_picker) else {
    fail("expected Primer picker matrix")
  }
  inspect(primer_picker.moui_surface, content="@views.PickerStyle")
  assert_true(primer_picker.source_imported_token_count >= 3)
  assert_true(primer_picker.runtime_aligned_token_count >= 1)
  guard @common.DesignPreset::Fluent.component_token_matrix_for("DatePicker")
    is Some(fluent_date_picker) else {
    fail("expected Fluent date-picker matrix")
  }
  assert_true(
    fluent_date_picker.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Fluent.component_token_matrix_for("Picker")
    is Some(fluent_picker) else {
    fail("expected Fluent picker matrix")
  }
  assert_true(fluent_picker.source_imported_token_count == 1)
  assert_true(fluent_picker.runtime_aligned_token_count == 1)
}

///|
test "component style resolver reports tie component tokens to neutral core styles" {
  for
    preset in [
      @common.DesignPreset::Material,
      @common.DesignPreset::Carbon,
      @common.DesignPreset::Primer,
      @common.DesignPreset::Fluent,
    ] {
    let rows = preset.component_style_resolver_report(
      scheme=@core.ColorScheme::Light,
    )
    assert_true(rows.length() == 11)
    assert_true(preset.component_style_resolver_count() == 11)
    assert_true(preset.component_style_resolver_gap_count() == 0)
    assert_true(preset.component_style_resolver_source_gap_count() == 0)
    assert_true(
      preset.component_style_resolver_official_parity_gap_count() == 11,
    )
    for item in rows {
      assert_true(item.source_declared)
      assert_true(item.source_locked)
      assert_true(item.source_ref != "")
      assert_true(item.token_surface.contains("DesignComponentTokens"))
      assert_true(item.core_style_surface.contains("@views."))
      assert_true(item.tokens_api.contains("DesignPreset::tokens"))
      assert_true(item.style_api != "")
      assert_true(item.resolves_tokens)
      assert_true(item.resolves_core_style)
      assert_true(item.status == @common.DesignTokenStatus::ComponentMapped)
    }
  }
  guard @common.DesignPreset::Material.component_style_resolver_for("Button")
    is Some(material_button) else {
    fail("expected Material button style resolver")
  }
  assert_true(material_button.core_style_surface == "@views.ButtonStyle")
  assert_true(material_button.style_api.contains("core_component_styles"))
  assert_true(material_button.remaining_gap.contains("state layers"))
  guard @common.DesignPreset::Carbon.component_style_resolver_for("Feedback")
    is Some(carbon_feedback) else {
    fail("expected Carbon feedback style resolver")
  }
  assert_true(carbon_feedback.style_api.contains("DesignFeedbackTokens"))
  assert_true(carbon_feedback.core_style_surface == "@views.FeedbackStyle")
  guard @common.DesignPreset::Primer.component_style_resolver_for("Picker")
    is Some(primer_picker) else {
    fail("expected Primer picker style resolver")
  }
  assert_true(primer_picker.core_style_surface == "@views.PickerStyle")
  assert_true(primer_picker.token_surface.contains("picker"))
  guard @common.DesignPreset::Fluent.component_style_resolver_for("DatePicker")
    is Some(fluent_date_picker) else {
    fail("expected Fluent date-picker style resolver")
  }
  assert_true(fluent_date_picker.core_style_surface == "@views.PickerStyle")
  assert_true(fluent_date_picker.remaining_gap.contains("calendar"))
}

///|
test "design system component style bundle resolves neutral core styles" {
  let material = @common.DesignPreset::Material.tokens()
  let material_styles = material.core_component_styles()
  assert_true(
    material_styles.button.primary.normal.background ==
    @core.Brush::solid(material.components.button.primary.background),
  )
  assert_true(
    material_styles.button.primary.disabled.foreground ==
    material.components.button.primary.foreground.multiply_alpha(
      material.state_layer.disabled_alpha,
    ),
  )
  assert_true(
    material_styles.button.ghost.hovered.background ==
    @core.Brush::solid(
      material.state_layer.color.with_alpha(material.state_layer.hover_alpha),
    ),
  )
  assert_true(
    material_styles.text_field.filled.cursor_color ==
    material.components.text_field.cursor,
  )
  assert_true(material_styles.text_field.plain.normal.border is None)
  assert_true(
    material_styles.surface.base.padding ==
    @core.Insets::all(material.components.surface.base_padding),
  )
  assert_true(
    material_styles.surface.overlay.level == @core.SurfaceLevel::Overlay,
  )
  let carbon = @common.DesignPreset::Carbon.tokens()
  let carbon_styles = carbon.core_component_styles()
  assert_true(
    carbon_styles.slider.foreground == carbon.components.slider.foreground,
  )
  assert_true(
    carbon_styles.slider.foreground != carbon.to_theme().palette.primary,
  )
  assert_true(
    carbon_styles.picker.background == carbon.components.picker.background,
  )
  let fluent_dark = @common.DesignPreset::Fluent.tokens(
    scheme=@core.ColorScheme::Dark,
  )
  let fluent_styles = fluent_dark.core_component_styles()
  assert_true(
    fluent_styles.date_picker.background ==
    fluent_dark.components.date_picker.background,
  )
  assert_true(
    fluent_styles.form_validation.foreground ==
    fluent_dark.components.form_validation.foreground,
  )
}

///|
test "adaptation reports expose source locked MoUI differences" {
  for
    preset in [
      @common.DesignPreset::Material,
      @common.DesignPreset::Carbon,
      @common.DesignPreset::Primer,
      @common.DesignPreset::Fluent,
    ] {
    let records = preset.adaptation_report()
    assert_true(records.length() >= 7)
    assert_true(preset.aligned_adaptation_count() > 0)
    assert_true(preset.adaptation_gap_count() > 0)
    assert_true(preset.adaptation_source_lock_gap_count() == 0)
    assert_true(preset.undeclared_adaptation_source_count() == 0)
    assert_false(records.any(item => item.moui_surface.contains("moui/views")))
    assert_true(
      records.any(item => {
        item.kind == @common.DesignAdaptationKind::CollapsedRoleMatrix
      }),
    )
    assert_true(
      records.any(item => {
        item.kind == @common.DesignAdaptationKind::CustomizableOverride &&
        item.status == @common.DesignTokenStatus::ThemeMapped
      }),
    )
    for item in records {
      assert_true(item.source_declared)
      assert_true(item.source_locked)
      assert_true(item.source_ref != "")
      assert_true(item.remaining_gap != "")
    }
  }
  guard @common.DesignPreset::Material.adaptation_report_for(
      "Material dynamic color generation",
    )
    is Some(material_dynamic) else {
    fail("expected Material dynamic color adaptation")
  }
  assert_true(
    material_dynamic.status == @common.DesignTokenStatus::SourceMapped,
  )
  assert_true(
    material_dynamic.kind == @common.DesignAdaptationKind::PendingOfficialImport,
  )
  guard @common.DesignPreset::Carbon.adaptation_report_for(
      "Carbon white/g10/g90/g100 themes",
    )
    is Some(carbon_themes) else {
    fail("expected Carbon theme adaptation")
  }
  assert_true(carbon_themes.status == @common.DesignTokenStatus::PreviewMapped)
  guard @common.DesignPreset::Primer.adaptation_report_for(
      "Primer color modes and accessibility themes",
    )
    is Some(primer_modes) else {
    fail("expected Primer mode adaptation")
  }
  assert_true(
    primer_modes.kind == @common.DesignAdaptationKind::CollapsedRoleMatrix,
  )
  guard @common.DesignPreset::Primer.adaptation_report_for(
      "Primer typography primitives",
    )
    is Some(primer_typography) else {
    fail("expected Primer typography adaptation")
  }
  assert_true(
    primer_typography.status == @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(
    primer_typography.remaining_gap.contains("line-height") &&
    primer_typography.remaining_gap.contains("title weight"),
  )
  guard @common.DesignPreset::Fluent.adaptation_report_for(
      "Fluent light/dark/high contrast themes",
    )
    is Some(fluent_variants) else {
    fail("expected Fluent variant adaptation")
  }
  assert_true(fluent_variants.status == @common.DesignTokenStatus::ThemeMapped)
  guard @common.DesignPreset::Fluent.adaptation_report_for("Fluent type ramp")
    is Some(fluent_typography) else {
    fail("expected Fluent typography adaptation")
  }
  assert_true(
    fluent_typography.status == @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(
    fluent_typography.difference.contains("full Fluent global font file") &&
    fluent_typography.remaining_gap.contains("line-height") &&
    fluent_typography.remaining_gap.contains("font-family"),
  )
  guard @common.DesignPreset::Fluent.adaptation_report_for(
      "Fluent spacing scales",
    )
    is Some(fluent_spacing) else {
    fail("expected Fluent spacing adaptation")
  }
  assert_true(fluent_spacing.status == @common.DesignTokenStatus::PreviewMapped)
  assert_true(
    fluent_spacing.difference.contains("horizontal and vertical spacing") &&
    fluent_spacing.remaining_gap.contains("axis-specific"),
  )
  guard @common.DesignPreset::Fluent.adaptation_report_for(
      "Fluent border radius scale",
    )
    is Some(fluent_radius) else {
    fail("expected Fluent radius adaptation")
  }
  assert_true(fluent_radius.status == @common.DesignTokenStatus::PreviewMapped)
  assert_true(
    fluent_radius.difference.contains("full Fluent global border-radius scale") &&
    fluent_radius.remaining_gap.contains("extended radius"),
  )
  guard @common.DesignPreset::Fluent.adaptation_report_for(
      "Fluent shadow and stroke depth",
    )
    is Some(fluent_depth) else {
    fail("expected Fluent depth adaptation")
  }
  assert_true(fluent_depth.status == @common.DesignTokenStatus::PreviewMapped)
  assert_true(
    fluent_depth.difference.contains("global stroke widths") &&
    fluent_depth.remaining_gap.contains("shadow/depth") &&
    fluent_depth.remaining_gap.contains("stroke-width scale"),
  )
}

///|
test "official token anchors expose mapped coverage and required gaps" {
  for
    preset in [
      @common.DesignPreset::Material,
      @common.DesignPreset::Carbon,
      @common.DesignPreset::Primer,
      @common.DesignPreset::Fluent,
    ] {
    assert_true(preset.official_token_anchor_count() >= 8)
    assert_true(preset.mapped_official_token_anchor_count() > 0)
    assert_true(preset.unmapped_official_token_anchor_count() > 0)
    assert_true(preset.unanchored_golden_mapping_count() == 0)
    assert_true(preset.golden_mappings_without_official_anchor().length() == 0)
    if preset == @common.DesignPreset::Material {
      assert_true(
        preset.official_token_anchor_source_lock_count() ==
        preset.official_token_anchor_count() - 1,
      )
    } else {
      assert_true(
        preset.official_token_anchor_source_lock_count() ==
        preset.official_token_anchor_count(),
      )
    }
    assert_true(preset.official_token_anchor_source_gap_count() == 0)
    assert_true(preset.undeclared_official_token_anchor_source_count() == 0)
    assert_true(preset.has_official_token_source_locks())
    assert_true(
      preset.official_token_source_usage().length() == preset.sources().length(),
    )
    assert_true(
      preset
      .official_token_source_usage()
      .any(item => {
        item.anchor_count > 0 && item.source_locked && item.source_ref != ""
      }),
    )
    assert_false(preset.is_design_system_complete())
    assert_true(
      preset.has_official_token_anchor(
        preset.official_token_anchors()[0].official_token,
      ),
    )
    for mapping in preset.golden_mappings() {
      assert_true(preset.has_official_token_anchor(mapping.official_token))
    }
  }
  guard @common.DesignPreset::Material.official_token_coverage_for(
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
  guard @common.DesignPreset::Material.official_token_coverage_for(
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
  guard @common.DesignPreset::Material.official_token_coverage_for(
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
  guard @common.DesignPreset::Material.official_token_coverage_for(
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
  guard @common.DesignPreset::Material.official_token_coverage_for(
      "--md-sys-motion-duration-short4",
    )
    is Some(material_motion_short4) else {
    fail("expected Material short4 motion official token coverage")
  }
  assert_true(material_motion_short4.mapped)
  assert_true(material_motion_short4.source_declared)
  assert_true(material_motion_short4.source_locked)
  assert_true(material_motion_short4.moui_token == "DesignMotionTokens.fast_ms")
  guard @common.DesignPreset::Material.official_token_coverage_for(
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
  guard @common.DesignPreset::Material.official_token_coverage_for(
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
  guard @common.DesignPreset::Material.official_token_coverage_for(
      "--md-sys-motion-easing-standard",
    )
    is Some(material_motion_easing) else {
    fail("expected Material standard easing official token coverage")
  }
  assert_true(material_motion_easing.mapped)
  assert_true(material_motion_easing.source_declared)
  assert_true(material_motion_easing.source_locked)
  assert_true(
    material_motion_easing.status == @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(material_motion_easing.moui_token == "DesignMotionTokens.easing")
  guard @common.DesignPreset::Material.official_token_coverage_for(
      "--md-sys-spacing-*",
    )
    is Some(material_spacing) else {
    fail("expected Material spacing official token gap")
  }
  assert_false(material_spacing.required)
  assert_false(material_spacing.mapped)
  assert_true(material_spacing.status == @common.DesignTokenStatus::NotMapped)
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
  guard @common.DesignPreset::Carbon.official_token_coverage_for(
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
  guard @common.DesignPreset::Carbon.official_token_coverage_for(
      "easings.standard.productive",
    )
    is Some(carbon_easing) else {
    fail("expected Carbon easing official token coverage")
  }
  assert_true(carbon_easing.mapped)
  assert_true(carbon_easing.source_declared)
  assert_true(carbon_easing.source_locked)
  assert_true(carbon_easing.status == @common.DesignTokenStatus::PreviewMapped)
  assert_true(carbon_easing.moui_token == "DesignMotionTokens.easing")
  guard @common.DesignPreset::Carbon.official_token_coverage_for(
      "$duration-slow-02",
    )
    is Some(carbon_duration_slow02) else {
    fail("expected Carbon slow-02 duration official token coverage")
  }
  assert_true(carbon_duration_slow02.mapped)
  assert_true(carbon_duration_slow02.source_declared)
  assert_true(carbon_duration_slow02.source_locked)
  assert_true(
    carbon_duration_slow02.status == @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(carbon_duration_slow02.moui_token == "DesignMotionTokens.slow_ms")
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--button-primary-bgColor-rest",
    )
    is Some(primer_button) else {
    fail("expected Primer primary button official token coverage")
  }
  assert_true(primer_button.mapped)
  assert_true(primer_button.source_declared)
  assert_true(primer_button.source_locked)
  assert_true(
    primer_button.status == @common.DesignTokenStatus::ComponentMapped,
  )
  assert_true(
    primer_button.moui_token ==
    "DesignComponentTokens.button.primary.background",
  )
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--control-bgColor-rest",
    )
    is Some(primer_control) else {
    fail("expected Primer control rest background official token coverage")
  }
  assert_true(primer_control.mapped)
  assert_true(primer_control.source_declared)
  assert_true(primer_control.source_locked)
  assert_true(
    primer_control.status == @common.DesignTokenStatus::ComponentMapped,
  )
  assert_true(
    primer_control.moui_token == "DesignComponentTokens.picker.background",
  )
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--control-transparent-bgColor-hover",
    )
    is Some(primer_control_hover) else {
    fail("expected Primer transparent hover official token coverage")
  }
  assert_true(primer_control_hover.mapped)
  assert_true(primer_control_hover.source_declared)
  assert_true(primer_control_hover.source_locked)
  assert_true(
    primer_control_hover.status == @common.DesignTokenStatus::ComponentMapped,
  )
  assert_true(
    primer_control_hover.moui_token == "DesignStateLayerTokens.hover_alpha",
  )
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--control-borderColor-emphasis",
    )
    is Some(primer_control_border) else {
    fail("expected Primer control emphasized border official token coverage")
  }
  assert_true(primer_control_border.mapped)
  assert_true(primer_control_border.source_declared)
  assert_true(primer_control_border.source_locked)
  assert_true(
    primer_control_border.status == @common.DesignTokenStatus::ComponentMapped,
  )
  assert_true(
    primer_control_border.moui_token == "DesignTextFieldTokens.focused.border",
  )
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--base-size-4",
    )
    is Some(primer_base_size_xs) else {
    fail("expected Primer base size 4 official token coverage")
  }
  assert_true(primer_base_size_xs.mapped)
  assert_true(primer_base_size_xs.source_declared)
  assert_true(primer_base_size_xs.source_locked)
  assert_true(
    primer_base_size_xs.status == @common.DesignTokenStatus::ThemeMapped,
  )
  assert_true(primer_base_size_xs.moui_token == "DesignSpacingTokens.xs")
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--base-size-8",
    )
    is Some(primer_base_size_sm) else {
    fail("expected Primer base size 8 official token coverage")
  }
  assert_true(primer_base_size_sm.mapped)
  assert_true(primer_base_size_sm.source_declared)
  assert_true(primer_base_size_sm.source_locked)
  assert_true(
    primer_base_size_sm.status == @common.DesignTokenStatus::ThemeMapped,
  )
  assert_true(primer_base_size_sm.moui_token == "DesignSpacingTokens.sm")
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--base-size-12",
    )
    is Some(primer_base_size_md) else {
    fail("expected Primer base size 12 official token coverage")
  }
  assert_true(primer_base_size_md.mapped)
  assert_true(primer_base_size_md.source_declared)
  assert_true(primer_base_size_md.source_locked)
  assert_true(
    primer_base_size_md.status == @common.DesignTokenStatus::ThemeMapped,
  )
  assert_true(primer_base_size_md.moui_token == "DesignSpacingTokens.md")
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--base-size-16",
    )
    is Some(primer_base_size) else {
    fail("expected Primer base size official token coverage")
  }
  assert_true(primer_base_size.mapped)
  assert_true(primer_base_size.source_declared)
  assert_true(primer_base_size.source_locked)
  assert_true(primer_base_size.status == @common.DesignTokenStatus::ThemeMapped)
  assert_true(primer_base_size.moui_token == "DesignSpacingTokens.lg")
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--base-size-24",
    )
    is Some(primer_base_size_xl) else {
    fail("expected Primer base size 24 official token coverage")
  }
  assert_true(primer_base_size_xl.mapped)
  assert_true(primer_base_size_xl.source_declared)
  assert_true(primer_base_size_xl.source_locked)
  assert_true(
    primer_base_size_xl.status == @common.DesignTokenStatus::ThemeMapped,
  )
  assert_true(primer_base_size_xl.moui_token == "DesignSpacingTokens.xl")
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--base-text-size-xs",
    )
    is Some(primer_caption_size) else {
    fail("expected Primer caption text size official token coverage")
  }
  assert_true(primer_caption_size.mapped)
  assert_true(primer_caption_size.source_declared)
  assert_true(primer_caption_size.source_locked)
  assert_true(
    primer_caption_size.status == @common.DesignTokenStatus::ThemeMapped,
  )
  assert_true(
    primer_caption_size.moui_token == "DesignTypographyTokens.caption.size",
  )
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--base-text-size-sm",
    )
    is Some(primer_body_size) else {
    fail("expected Primer body text size official token coverage")
  }
  assert_true(primer_body_size.mapped)
  assert_true(primer_body_size.source_declared)
  assert_true(primer_body_size.source_locked)
  assert_true(primer_body_size.status == @common.DesignTokenStatus::ThemeMapped)
  assert_true(primer_body_size.moui_token == "DesignTypographyTokens.body.size")
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--base-text-size-lg",
    )
    is Some(primer_title_size) else {
    fail("expected Primer title text size official token coverage")
  }
  assert_true(primer_title_size.mapped)
  assert_true(primer_title_size.source_declared)
  assert_true(primer_title_size.source_locked)
  assert_true(
    primer_title_size.status == @common.DesignTokenStatus::ThemeMapped,
  )
  assert_true(
    primer_title_size.moui_token == "DesignTypographyTokens.title.size",
  )
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--base-text-weight-normal",
    )
    is Some(primer_body_weight) else {
    fail("expected Primer body text weight official token coverage")
  }
  assert_true(primer_body_weight.mapped)
  assert_true(primer_body_weight.source_declared)
  assert_true(primer_body_weight.source_locked)
  assert_true(
    primer_body_weight.status == @common.DesignTokenStatus::ThemeMapped,
  )
  assert_true(
    primer_body_weight.moui_token == "DesignTypographyTokens.body.weight",
  )
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--base-text-weight-semibold",
    )
    is Some(primer_control_weight) else {
    fail("expected Primer control text weight official token coverage")
  }
  assert_true(primer_control_weight.mapped)
  assert_true(primer_control_weight.source_declared)
  assert_true(primer_control_weight.source_locked)
  assert_true(
    primer_control_weight.status == @common.DesignTokenStatus::ThemeMapped,
  )
  assert_true(
    primer_control_weight.moui_token == "DesignTypographyTokens.control.weight",
  )
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--borderRadius-small",
    )
    is Some(primer_radius_small) else {
    fail("expected Primer small radius official token coverage")
  }
  assert_true(primer_radius_small.mapped)
  assert_true(primer_radius_small.source_declared)
  assert_true(primer_radius_small.source_locked)
  assert_true(
    primer_radius_small.status == @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(primer_radius_small.moui_token == "DesignRadiusTokens.sm")
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--borderRadius-medium",
    )
    is Some(primer_radius_medium) else {
    fail("expected Primer medium radius official token coverage")
  }
  assert_true(primer_radius_medium.mapped)
  assert_true(primer_radius_medium.source_declared)
  assert_true(primer_radius_medium.source_locked)
  assert_true(
    primer_radius_medium.status == @common.DesignTokenStatus::ThemeMapped,
  )
  assert_true(primer_radius_medium.moui_token == "DesignRadiusTokens.md")
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--borderRadius-large",
    )
    is Some(primer_radius_large) else {
    fail("expected Primer large radius official token coverage")
  }
  assert_true(primer_radius_large.mapped)
  assert_true(primer_radius_large.source_declared)
  assert_true(primer_radius_large.source_locked)
  assert_true(
    primer_radius_large.status == @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(primer_radius_large.moui_token == "DesignRadiusTokens.lg")
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--borderRadius-full",
    )
    is Some(primer_radius_full) else {
    fail("expected Primer full radius official token coverage")
  }
  assert_true(primer_radius_full.mapped)
  assert_true(primer_radius_full.source_declared)
  assert_true(primer_radius_full.source_locked)
  assert_true(
    primer_radius_full.status == @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(primer_radius_full.moui_token == "DesignRadiusTokens.pill")
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--borderRadius-default",
    )
    is Some(primer_radius_default) else {
    fail("expected Primer default radius official token coverage")
  }
  assert_true(primer_radius_default.mapped)
  assert_true(primer_radius_default.source_declared)
  assert_true(primer_radius_default.source_locked)
  assert_true(
    primer_radius_default.status == @common.DesignTokenStatus::ThemeMapped,
  )
  assert_true(primer_radius_default.moui_token == "DesignRadiusTokens.md")
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--shadow-resting-small",
    )
    is Some(primer_shadow_small) else {
    fail("expected Primer small resting shadow official token coverage")
  }
  assert_true(primer_shadow_small.mapped)
  assert_true(primer_shadow_small.source_declared)
  assert_true(primer_shadow_small.source_locked)
  assert_true(
    primer_shadow_small.status == @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(
    primer_shadow_small.moui_token == "DesignElevationTokens.sm.offset.y",
  )
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--shadow-resting-medium",
    )
    is Some(primer_shadow_medium) else {
    fail("expected Primer medium resting shadow official token coverage")
  }
  assert_true(primer_shadow_medium.mapped)
  assert_true(primer_shadow_medium.source_declared)
  assert_true(primer_shadow_medium.source_locked)
  assert_true(
    primer_shadow_medium.status == @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(
    primer_shadow_medium.moui_token == "DesignElevationTokens.md.offset.y",
  )
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--shadow-floating-large",
    )
    is Some(primer_shadow_large) else {
    fail("expected Primer large floating shadow official token coverage")
  }
  assert_true(primer_shadow_large.mapped)
  assert_true(primer_shadow_large.source_declared)
  assert_true(primer_shadow_large.source_locked)
  assert_true(
    primer_shadow_large.status == @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(
    primer_shadow_large.moui_token == "DesignElevationTokens.lg.offset.y",
  )
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--base-duration-0",
    )
    is Some(primer_duration_zero) else {
    fail("expected Primer 0ms duration official token coverage")
  }
  assert_true(primer_duration_zero.mapped)
  assert_true(primer_duration_zero.source_declared)
  assert_true(primer_duration_zero.source_locked)
  assert_true(
    primer_duration_zero.status == @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(primer_duration_zero.moui_token == "DesignMotionTokens.fast_ms")
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--base-duration-100",
    )
    is Some(primer_duration_fast) else {
    fail("expected Primer 100ms duration official token coverage")
  }
  assert_true(primer_duration_fast.mapped)
  assert_true(primer_duration_fast.source_declared)
  assert_true(primer_duration_fast.source_locked)
  assert_true(
    primer_duration_fast.status == @common.DesignTokenStatus::ThemeMapped,
  )
  assert_true(primer_duration_fast.moui_token == "DesignMotionTokens.fast_ms")
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--base-duration-200",
    )
    is Some(primer_duration_normal) else {
    fail("expected Primer 200ms duration official token coverage")
  }
  assert_true(primer_duration_normal.mapped)
  assert_true(primer_duration_normal.source_declared)
  assert_true(primer_duration_normal.source_locked)
  assert_true(
    primer_duration_normal.status == @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(
    primer_duration_normal.moui_token == "DesignMotionTokens.normal_ms",
  )
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--base-duration-300",
    )
    is Some(primer_duration_slow) else {
    fail("expected Primer 300ms duration official token coverage")
  }
  assert_true(primer_duration_slow.mapped)
  assert_true(primer_duration_slow.source_declared)
  assert_true(primer_duration_slow.source_locked)
  assert_true(
    primer_duration_slow.status == @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(primer_duration_slow.moui_token == "DesignMotionTokens.slow_ms")
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--base-duration-1000",
    )
    is Some(primer_duration_long) else {
    fail("expected Primer 1000ms duration official token coverage")
  }
  assert_true(primer_duration_long.mapped)
  assert_true(primer_duration_long.source_declared)
  assert_true(primer_duration_long.source_locked)
  assert_true(
    primer_duration_long.status == @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(primer_duration_long.moui_token == "DesignMotionTokens.slow_ms")
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--base-easing-linear",
    )
    is Some(primer_linear) else {
    fail("expected Primer linear easing official token coverage")
  }
  assert_true(primer_linear.mapped)
  assert_true(primer_linear.source_declared)
  assert_true(primer_linear.source_locked)
  assert_true(primer_linear.status == @common.DesignTokenStatus::PreviewMapped)
  assert_true(primer_linear.moui_token == "DesignMotionTokens.easing")
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--base-easing-easeOut",
    )
    is Some(primer_easing) else {
    fail("expected Primer easeOut official token coverage")
  }
  assert_true(primer_easing.mapped)
  assert_true(primer_easing.source_declared)
  assert_true(primer_easing.source_locked)
  assert_true(primer_easing.status == @common.DesignTokenStatus::PreviewMapped)
  assert_true(primer_easing.moui_token == "DesignMotionTokens.easing")
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--base-easing-easeInOut",
    )
    is Some(primer_ease_in_out) else {
    fail("expected Primer easeInOut official token coverage")
  }
  assert_true(primer_ease_in_out.mapped)
  assert_true(primer_ease_in_out.source_declared)
  assert_true(primer_ease_in_out.source_locked)
  assert_true(
    primer_ease_in_out.status == @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(primer_ease_in_out.moui_token == "DesignMotionTokens.easing")
  guard @common.DesignPreset::Primer.official_token_coverage_for(
      "--progressBar-fgColor-accent",
    )
    is Some(primer_progress) else {
    fail("expected Primer progress official token coverage")
  }
  assert_true(primer_progress.mapped)
  assert_true(primer_progress.source_declared)
  assert_true(primer_progress.source_locked)
  assert_true(
    primer_progress.status == @common.DesignTokenStatus::ComponentMapped,
  )
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
  guard @common.DesignPreset::Fluent.official_token_coverage_for(
      "spacingHorizontalM",
    )
    is Some(fluent_spacing) else {
    fail("expected Fluent spacing official token coverage")
  }
  assert_true(fluent_spacing.mapped)
  assert_true(fluent_spacing.source_declared)
  assert_true(fluent_spacing.source_locked)
  assert_true(fluent_spacing.moui_token == "DesignSpacingTokens.md")
  guard @common.DesignPreset::Fluent.official_token_coverage_for(
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
  guard @common.DesignPreset::Fluent.official_token_coverage_for(
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
  guard @common.DesignPreset::Fluent.official_token_coverage_for(
      "borderRadiusCircular",
    )
    is Some(fluent_radius_circular) else {
    fail("expected Fluent circular radius official token coverage")
  }
  assert_true(fluent_radius_circular.mapped)
  assert_true(fluent_radius_circular.source_declared)
  assert_true(fluent_radius_circular.source_locked)
  assert_true(fluent_radius_circular.moui_token == "DesignRadiusTokens.pill")
  assert_true(
    fluent_radius_circular.status == @common.DesignTokenStatus::PreviewMapped,
  )
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
  guard @common.DesignPreset::Fluent.official_token_coverage_for(
      "durationUltraFast",
    )
    is Some(fluent_duration_ultra_fast) else {
    fail("expected Fluent ultra-fast duration official token coverage")
  }
  assert_true(fluent_duration_ultra_fast.mapped)
  assert_true(fluent_duration_ultra_fast.source_declared)
  assert_true(fluent_duration_ultra_fast.source_locked)
  assert_true(
    fluent_duration_ultra_fast.status ==
    @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(
    fluent_duration_ultra_fast.moui_token == "DesignMotionTokens.fast_ms",
  )
  guard @common.DesignPreset::Fluent.official_token_coverage_for(
      "durationFaster",
    )
    is Some(fluent_duration_fast) else {
    fail("expected Fluent faster duration official token coverage")
  }
  assert_true(fluent_duration_fast.mapped)
  assert_true(fluent_duration_fast.source_declared)
  assert_true(fluent_duration_fast.source_locked)
  assert_true(
    fluent_duration_fast.status == @common.DesignTokenStatus::ThemeMapped,
  )
  assert_true(fluent_duration_fast.moui_token == "DesignMotionTokens.fast_ms")
  guard @common.DesignPreset::Fluent.official_token_coverage_for("durationFast")
    is Some(fluent_duration_fast_preview) else {
    fail("expected Fluent fast duration official token coverage")
  }
  assert_true(fluent_duration_fast_preview.mapped)
  assert_true(fluent_duration_fast_preview.source_declared)
  assert_true(fluent_duration_fast_preview.source_locked)
  assert_true(
    fluent_duration_fast_preview.status ==
    @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(
    fluent_duration_fast_preview.moui_token == "DesignMotionTokens.fast_ms",
  )
  guard @common.DesignPreset::Fluent.official_token_coverage_for(
      "durationNormal",
    )
    is Some(fluent_duration) else {
    fail("expected Fluent duration official token coverage")
  }
  assert_true(fluent_duration.mapped)
  assert_true(fluent_duration.source_declared)
  assert_true(fluent_duration.source_locked)
  assert_true(fluent_duration.status == @common.DesignTokenStatus::ThemeMapped)
  assert_true(fluent_duration.moui_token == "DesignMotionTokens.normal_ms")
  guard @common.DesignPreset::Fluent.official_token_coverage_for(
      "durationGentle",
    )
    is Some(fluent_duration_gentle) else {
    fail("expected Fluent gentle duration official token coverage")
  }
  assert_true(fluent_duration_gentle.mapped)
  assert_true(fluent_duration_gentle.source_declared)
  assert_true(fluent_duration_gentle.source_locked)
  assert_true(
    fluent_duration_gentle.status == @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(
    fluent_duration_gentle.moui_token == "DesignMotionTokens.normal_ms",
  )
  guard @common.DesignPreset::Fluent.official_token_coverage_for("durationSlow")
    is Some(fluent_duration_slow) else {
    fail("expected Fluent slow duration official token coverage")
  }
  assert_true(fluent_duration_slow.mapped)
  assert_true(fluent_duration_slow.source_declared)
  assert_true(fluent_duration_slow.source_locked)
  assert_true(
    fluent_duration_slow.status == @common.DesignTokenStatus::ThemeMapped,
  )
  assert_true(fluent_duration_slow.moui_token == "DesignMotionTokens.slow_ms")
  guard @common.DesignPreset::Fluent.official_token_coverage_for(
      "durationSlower",
    )
    is Some(fluent_duration_slower) else {
    fail("expected Fluent slower duration official token coverage")
  }
  assert_true(fluent_duration_slower.mapped)
  assert_true(fluent_duration_slower.source_declared)
  assert_true(fluent_duration_slower.source_locked)
  assert_true(
    fluent_duration_slower.status == @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(fluent_duration_slower.moui_token == "DesignMotionTokens.slow_ms")
  guard @common.DesignPreset::Fluent.official_token_coverage_for(
      "durationUltraSlow",
    )
    is Some(fluent_duration_ultra_slow) else {
    fail("expected Fluent ultra-slow duration official token coverage")
  }
  assert_true(fluent_duration_ultra_slow.mapped)
  assert_true(fluent_duration_ultra_slow.source_declared)
  assert_true(fluent_duration_ultra_slow.source_locked)
  assert_true(
    fluent_duration_ultra_slow.status ==
    @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(
    fluent_duration_ultra_slow.moui_token == "DesignMotionTokens.slow_ms",
  )
  guard @common.DesignPreset::Fluent.official_token_coverage_for(
      "colorCompoundBrandBackground",
    )
    is Some(fluent_compound_brand) else {
    fail("expected Fluent compound brand official token coverage")
  }
  assert_true(fluent_compound_brand.mapped)
  assert_true(fluent_compound_brand.source_declared)
  assert_true(fluent_compound_brand.source_locked)
  assert_true(
    fluent_compound_brand.status == @common.DesignTokenStatus::ComponentMapped,
  )
  assert_true(
    fluent_compound_brand.moui_token ==
    "DesignComponentTokens.button.primary.background",
  )
  guard @common.DesignPreset::Fluent.official_token_coverage_for(
      "ProgressBar.indicator.backgroundColor",
    )
    is Some(fluent_progress) else {
    fail("expected Fluent progress official token coverage")
  }
  assert_true(fluent_progress.mapped)
  assert_true(fluent_progress.source_declared)
  assert_true(fluent_progress.source_locked)
  assert_true(
    fluent_progress.status == @common.DesignTokenStatus::ComponentMapped,
  )
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
  guard @common.DesignPreset::Fluent.official_token_coverage_for(
      "curveEasyEase",
    )
    is Some(fluent_curve) else {
    fail("expected Fluent curve official token coverage")
  }
  assert_true(fluent_curve.mapped)
  assert_true(fluent_curve.source_declared)
  assert_true(fluent_curve.source_locked)
  assert_true(fluent_curve.status == @common.DesignTokenStatus::PreviewMapped)
  assert_true(fluent_curve.moui_token == "DesignMotionTokens.easing")
  assert_fluent_preview_curve_official_coverage("curveLinear")
}

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
    material_tokens.to_theme().semantic_colors.success ==
    material_tokens.palette.success,
  )
  assert_true(
    material_tokens.to_theme().semantic_colors.danger ==
    material_tokens.palette.danger,
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
    let report = preset.token_group_resolver_report()
    assert_true(report.length() == 7)
    assert_true(preset.token_group_resolver_count() == 7)
    assert_true(preset.token_group_resolver_gap_count() == 0)
    assert_true(preset.token_group_resolver_source_gap_count() == 0)
    assert_true(preset.token_group_resolver_official_parity_gap_count() == 7)
    for item in report {
      assert_true(item.source_declared)
      assert_true(item.source_locked)
      assert_true(item.source_ref != "")
      assert_true(item.token_surface != "")
      assert_true(item.tokens_api.contains("DesignPreset::tokens"))
      assert_true(item.theme_api != "")
      assert_true(item.resolves_tokens)
      assert_true(item.resolves_neutral_surface)
      assert_true(item.status != @common.DesignTokenStatus::NotMapped)
    }
  }
  guard @common.DesignPreset::Material.token_group_resolver_for(
      @common.DesignSystemRequirement::SemanticPalette,
    )
    is Some(material_palette) else {
    fail("expected Material semantic palette token-group resolver")
  }
  assert_true(material_palette.source_label == "Material Web color theming")
  assert_true(material_palette.token_surface.contains("DesignSemanticPalette"))
  assert_true(material_palette.remaining_gap.contains("semantic palette"))
  guard @common.DesignPreset::Fluent.token_group_resolver_for(
      @common.DesignSystemRequirement::Motion,
    )
    is Some(fluent_motion) else {
    fail("expected Fluent motion token-group resolver")
  }
  assert_true(fluent_motion.source_label == "Fluent 2 design tokens")
  assert_true(fluent_motion.theme_api.contains("DesignMotionTokens"))
  guard @common.DesignPreset::Carbon.token_group_resolver_for(
      @common.DesignSystemRequirement::StateLayer,
    )
    is Some(carbon_state_layer) else {
    fail("expected Carbon state-layer token-group resolver")
  }
  assert_true(
    carbon_state_layer.status == @common.DesignTokenStatus::ComponentMapped,
  )
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
    let report = preset.density_resolver_report(scheme=@core.ColorScheme::Light)
    assert_true(report.length() == 3)
    assert_true(preset.density_resolver_count() == 3)
    assert_true(preset.density_resolver_gap_count() == 0)
    assert_true(preset.density_resolver_source_gap_count() == 0)
    if preset == @common.DesignPreset::Material {
      assert_true(preset.density_resolver_official_parity_gap_count() == 3)
    } else {
      assert_true(preset.density_resolver_official_parity_gap_count() == 0)
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
  guard @common.DesignPreset::Carbon.density_resolver_for(
      @common.DesignDensity::Compact,
    )
    is Some(carbon_compact) else {
    fail("expected Carbon compact density resolver")
  }
  assert_true(carbon_compact.status == @common.DesignTokenStatus::ThemeMapped)
  assert_true(carbon_compact.source_label == "Carbon themes")
  inspect(carbon_compact.density_multiplier, content="0.82")
  guard @common.DesignPreset::Material.density_resolver_for(
      @common.DesignDensity::Comfortable,
    )
    is Some(material_comfortable) else {
    fail("expected Material comfortable density resolver")
  }
  assert_true(material_comfortable.spacing_md > material_comfortable.spacing_sm)
  assert_true(material_comfortable.remaining_gap.contains("Material Web"))
  guard @common.DesignPreset::Fluent.density_resolver_for(
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
    let report = preset.variant_resolver_report(
      system_scheme=@core.ColorScheme::Dark,
      density=@common.DesignDensity::Compact,
    )
    assert_true(report.length() == preset.variant_coverage().length())
    assert_true(preset.variant_resolver_count() == report.length())
    assert_true(preset.variant_resolver_source_gap_count() == 0)
    assert_true(preset.variant_resolver_gap_count() == 2)
    assert_true(preset.variant_resolver_official_parity_gap_count() == 4)
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
  guard @common.DesignPreset::Material.variant_resolver_for(
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
  assert_true(
    material_high_contrast.status == @common.DesignTokenStatus::ThemeMapped,
  )
  assert_true(material_high_contrast.official_source.contains("material-web"))
  guard @common.DesignPreset::Carbon.variant_resolver_for(
      @common.DesignSchemeVariant::SchemeLight,
    )
    is Some(carbon_light) else {
    fail("expected Carbon light variant resolver")
  }
  assert_true(carbon_light.resolved_scheme == @core.ColorScheme::Light)
  assert_true(carbon_light.status == @common.DesignTokenStatus::PreviewMapped)
  assert_true(carbon_light.remaining_gap.contains("Official scheme variant"))
  guard @common.DesignPreset::Fluent.variant_resolver_for(
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
  assert_true(customized.to_theme().semantic_colors.success == palette.success)
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
    let mappings = preset.golden_mappings()
    assert_true(mappings.length() >= 8)
    assert_true(preset.golden_mapped_count() >= 6)
    assert_true(preset.golden_gap_count() >= 1)
    assert_false(mappings.any(item => item.moui_token.contains("moui/views.")))
    assert_true(
      mappings.any(item => item.category == @common.DesignTokenCategory::Color),
    )
    assert_true(
      mappings.any(item => {
        item.category == @common.DesignTokenCategory::ComponentStyle &&
        item.status == @common.DesignTokenStatus::ComponentMapped
      }),
    )
    assert_true(
      mappings.any(item => {
        item.status == @common.DesignTokenStatus::SourceMapped ||
        item.status == @common.DesignTokenStatus::PreviewMapped ||
        item.status == @common.DesignTokenStatus::NotMapped
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
    let usages = preset.source_usage()
    assert_true(usages.length() == preset.sources().length())
    assert_true(preset.undeclared_golden_source_count() == 0)
    assert_true(usages.any(item => item.golden_mapping_count > 0))
    assert_true(preset.unused_official_source_count() > 0)
    assert_true(
      usages.any(item => {
        item.source_kind == "official-source" &&
        item.source_ref != "" &&
        item.token_path != "" &&
        item.source_status == @common.DesignTokenStatus::SourceMapped &&
        item.golden_mapping_count == 0
      }),
    )
  }
}

///|
test "progress and slider golden mappings use component tokens" {
  guard @common.DesignPreset::Material.golden_mapping_for(
      "--md-linear-progress-active-indicator-color",
    )
    is Some(material_progress) else {
    fail("expected Material progress token mapping")
  }
  inspect(
    material_progress.moui_token,
    content="DesignComponentTokens.progress.foreground",
  )
  assert_true(
    material_progress.status == @common.DesignTokenStatus::ComponentMapped,
  )
  guard @common.DesignPreset::Carbon.golden_mapping_for("$slider-filled-track")
    is Some(carbon_slider) else {
    fail("expected Carbon slider token mapping")
  }
  inspect(
    carbon_slider.moui_token,
    content="DesignComponentTokens.slider.foreground",
  )
  assert_true(
    carbon_slider.status == @common.DesignTokenStatus::ComponentMapped,
  )
}

///|
test "picker golden mappings use component tokens" {
  guard @common.DesignPreset::Material.golden_mapping_for(
      "--md-menu-container-color",
    )
    is Some(material_picker) else {
    fail("expected Material picker token mapping")
  }
  inspect(
    material_picker.moui_token,
    content="DesignComponentTokens.picker.background",
  )
  assert_true(
    material_picker.status == @common.DesignTokenStatus::ComponentMapped,
  )
  assert_true(@common.DesignPreset::Carbon.has_golden_mapping("$field"))
  assert_true(
    @common.DesignPreset::Primer.has_golden_mapping("--control-bgColor-rest"),
  )
}

///|
test "status color golden mappings use semantic palette roles" {
  guard @common.DesignPreset::Material.golden_mapping_for(
      "--md-sys-color-error",
    )
    is Some(material_error) else {
    fail("expected Material error token mapping")
  }
  inspect(material_error.moui_token, content="DesignSemanticPalette.danger")
  assert_true(material_error.status == @common.DesignTokenStatus::ThemeMapped)
  guard @common.DesignPreset::Carbon.golden_mapping_for("$support-success")
    is Some(carbon_success) else {
    fail("expected Carbon support-success token mapping")
  }
  inspect(carbon_success.moui_token, content="DesignSemanticPalette.success")
  assert_true(carbon_success.status == @common.DesignTokenStatus::ThemeMapped)
  guard @common.DesignPreset::Carbon.golden_mapping_for("$support-error")
    is Some(carbon_error) else {
    fail("expected Carbon support-error token mapping")
  }
  inspect(carbon_error.moui_token, content="DesignSemanticPalette.danger")
  assert_true(carbon_error.status == @common.DesignTokenStatus::ThemeMapped)
  assert_true(
    @common.DesignPreset::Primer.has_golden_mapping("--fgColor-danger"),
  )
  guard @common.DesignPreset::Primer.golden_mapping_for("--fgColor-success")
    is Some(primer_success) else {
    fail("expected Primer success token mapping")
  }
  inspect(primer_success.moui_token, content="DesignSemanticPalette.success")
  assert_true(primer_success.status == @common.DesignTokenStatus::ThemeMapped)
}

///|
test "golden mappings resolve known official token names" {
  guard @common.DesignPreset::Material.golden_mapping_for(
      "--md-sys-color-primary",
    )
    is Some(material_primary) else {
    fail("expected Material primary token mapping")
  }
  inspect(material_primary.moui_token, content="DesignSemanticPalette.primary")
  assert_true(material_primary.status == @common.DesignTokenStatus::ThemeMapped)
  guard @common.DesignPreset::Material.golden_mapping_for(
      "--md-sys-motion-duration-short4",
    )
    is Some(material_motion_short4) else {
    fail("expected Material short4 motion token mapping")
  }
  inspect(
    material_motion_short4.moui_token,
    content="DesignMotionTokens.fast_ms",
  )
  assert_true(
    material_motion_short4.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Material.golden_mapping_for(
      "--md-sys-motion-duration-medium2",
    )
    is Some(material_motion_medium2) else {
    fail("expected Material medium2 motion token mapping")
  }
  inspect(
    material_motion_medium2.moui_token,
    content="DesignMotionTokens.normal_ms",
  )
  assert_true(
    material_motion_medium2.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Material.golden_mapping_for(
      "--md-sys-motion-duration-medium4",
    )
    is Some(material_motion_medium4) else {
    fail("expected Material medium4 motion token mapping")
  }
  inspect(
    material_motion_medium4.moui_token,
    content="DesignMotionTokens.slow_ms",
  )
  assert_true(
    material_motion_medium4.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Material.golden_mapping_for(
      "--md-sys-motion-easing-standard",
    )
    is Some(material_motion_easing) else {
    fail("expected Material standard easing token mapping")
  }
  inspect(
    material_motion_easing.moui_token,
    content="DesignMotionTokens.easing",
  )
  assert_true(
    material_motion_easing.status == @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(
    @common.DesignPreset::Carbon.has_golden_mapping("$button-primary"),
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
  guard @common.DesignPreset::Carbon.golden_mapping_for("$duration-moderate-01")
    is Some(carbon_duration) else {
    fail("expected Carbon moderate duration token mapping")
  }
  assert_true(carbon_duration.moui_token == "DesignMotionTokens.normal_ms")
  assert_true(carbon_duration.status == @common.DesignTokenStatus::ThemeMapped)
  guard @common.DesignPreset::Carbon.golden_mapping_for(
      "easings.standard.productive",
    )
    is Some(carbon_easing) else {
    fail("expected Carbon standard productive easing token mapping")
  }
  assert_true(carbon_easing.moui_token == "DesignMotionTokens.easing")
  assert_true(carbon_easing.status == @common.DesignTokenStatus::PreviewMapped)
  guard @common.DesignPreset::Carbon.golden_mapping_for("$duration-fast-01")
    is Some(carbon_duration_fast01) else {
    fail("expected Carbon fast-01 duration token mapping")
  }
  assert_true(carbon_duration_fast01.moui_token == "DesignMotionTokens.fast_ms")
  assert_true(
    carbon_duration_fast01.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Carbon.golden_mapping_for(
      "easings.exit.expressive",
    )
    is Some(carbon_easing_exit) else {
    fail("expected Carbon expressive exit easing token mapping")
  }
  assert_true(carbon_easing_exit.moui_token == "DesignMotionTokens.easing")
  assert_true(
    carbon_easing_exit.status == @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(
    @common.DesignPreset::Primer.has_golden_mapping("--fgColor-default"),
  )
  guard @common.DesignPreset::Primer.golden_mapping_for("--base-size-4")
    is Some(primer_base_size_xs) else {
    fail("expected Primer base size 4 token mapping")
  }
  assert_true(primer_base_size_xs.moui_token == "DesignSpacingTokens.xs")
  assert_true(
    primer_base_size_xs.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Primer.golden_mapping_for("--base-size-8")
    is Some(primer_base_size_sm) else {
    fail("expected Primer base size 8 token mapping")
  }
  assert_true(primer_base_size_sm.moui_token == "DesignSpacingTokens.sm")
  assert_true(
    primer_base_size_sm.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Primer.golden_mapping_for("--base-size-12")
    is Some(primer_base_size_md) else {
    fail("expected Primer base size 12 token mapping")
  }
  assert_true(primer_base_size_md.moui_token == "DesignSpacingTokens.md")
  assert_true(
    primer_base_size_md.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Primer.golden_mapping_for("--base-size-16")
    is Some(primer_base_size) else {
    fail("expected Primer base size token mapping")
  }
  assert_true(primer_base_size.moui_token == "DesignSpacingTokens.lg")
  assert_true(primer_base_size.status == @common.DesignTokenStatus::ThemeMapped)
  guard @common.DesignPreset::Primer.golden_mapping_for("--base-size-24")
    is Some(primer_base_size_xl) else {
    fail("expected Primer base size 24 token mapping")
  }
  assert_true(primer_base_size_xl.moui_token == "DesignSpacingTokens.xl")
  assert_true(
    primer_base_size_xl.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Primer.golden_mapping_for("--base-text-size-xs")
    is Some(primer_caption_size) else {
    fail("expected Primer caption text size token mapping")
  }
  assert_true(
    primer_caption_size.moui_token == "DesignTypographyTokens.caption.size",
  )
  assert_true(
    primer_caption_size.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Primer.golden_mapping_for("--base-text-size-sm")
    is Some(primer_body_size) else {
    fail("expected Primer body text size token mapping")
  }
  assert_true(primer_body_size.moui_token == "DesignTypographyTokens.body.size")
  assert_true(primer_body_size.status == @common.DesignTokenStatus::ThemeMapped)
  guard @common.DesignPreset::Primer.golden_mapping_for("--base-text-size-lg")
    is Some(primer_title_size) else {
    fail("expected Primer title text size token mapping")
  }
  assert_true(
    primer_title_size.moui_token == "DesignTypographyTokens.title.size",
  )
  assert_true(
    primer_title_size.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Primer.golden_mapping_for(
      "--base-text-weight-normal",
    )
    is Some(primer_body_weight) else {
    fail("expected Primer body text weight token mapping")
  }
  assert_true(
    primer_body_weight.moui_token == "DesignTypographyTokens.body.weight",
  )
  assert_true(
    primer_body_weight.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Primer.golden_mapping_for(
      "--base-text-weight-semibold",
    )
    is Some(primer_control_weight) else {
    fail("expected Primer control text weight token mapping")
  }
  assert_true(
    primer_control_weight.moui_token == "DesignTypographyTokens.control.weight",
  )
  assert_true(
    primer_control_weight.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Primer.golden_mapping_for("--borderRadius-small")
    is Some(primer_radius_small) else {
    fail("expected Primer small radius token mapping")
  }
  assert_true(primer_radius_small.moui_token == "DesignRadiusTokens.sm")
  assert_true(
    primer_radius_small.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Primer.golden_mapping_for("--borderRadius-medium")
    is Some(primer_radius_medium) else {
    fail("expected Primer medium radius token mapping")
  }
  assert_true(primer_radius_medium.moui_token == "DesignRadiusTokens.md")
  assert_true(
    primer_radius_medium.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Primer.golden_mapping_for("--borderRadius-large")
    is Some(primer_radius_large) else {
    fail("expected Primer large radius token mapping")
  }
  assert_true(primer_radius_large.moui_token == "DesignRadiusTokens.lg")
  assert_true(
    primer_radius_large.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Primer.golden_mapping_for("--borderRadius-full")
    is Some(primer_radius_full) else {
    fail("expected Primer full radius token mapping")
  }
  assert_true(primer_radius_full.moui_token == "DesignRadiusTokens.pill")
  assert_true(
    primer_radius_full.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Primer.golden_mapping_for(
      "--borderRadius-default",
    )
    is Some(primer_radius_default) else {
    fail("expected Primer default radius token mapping")
  }
  assert_true(primer_radius_default.moui_token == "DesignRadiusTokens.md")
  assert_true(
    primer_radius_default.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Primer.golden_mapping_for(
      "--shadow-resting-small",
    )
    is Some(primer_shadow_small) else {
    fail("expected Primer small resting shadow token mapping")
  }
  assert_true(
    primer_shadow_small.moui_token == "DesignElevationTokens.sm.offset.y",
  )
  assert_true(
    primer_shadow_small.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Primer.golden_mapping_for(
      "--shadow-resting-medium",
    )
    is Some(primer_shadow_medium) else {
    fail("expected Primer medium resting shadow token mapping")
  }
  assert_true(
    primer_shadow_medium.moui_token == "DesignElevationTokens.md.offset.y",
  )
  assert_true(
    primer_shadow_medium.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Primer.golden_mapping_for(
      "--shadow-floating-large",
    )
    is Some(primer_shadow_large) else {
    fail("expected Primer large floating shadow token mapping")
  }
  assert_true(
    primer_shadow_large.moui_token == "DesignElevationTokens.lg.offset.y",
  )
  assert_true(
    primer_shadow_large.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Primer.golden_mapping_for("--base-duration-0")
    is Some(primer_duration_zero) else {
    fail("expected Primer 0ms duration token mapping")
  }
  assert_true(primer_duration_zero.moui_token == "DesignMotionTokens.fast_ms")
  assert_true(
    primer_duration_zero.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Primer.golden_mapping_for("--base-duration-100")
    is Some(primer_duration_fast) else {
    fail("expected Primer 100ms duration token mapping")
  }
  assert_true(primer_duration_fast.moui_token == "DesignMotionTokens.fast_ms")
  assert_true(
    primer_duration_fast.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Primer.golden_mapping_for("--base-duration-200")
    is Some(primer_duration_normal) else {
    fail("expected Primer 200ms duration token mapping")
  }
  assert_true(
    primer_duration_normal.moui_token == "DesignMotionTokens.normal_ms",
  )
  assert_true(
    primer_duration_normal.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Primer.golden_mapping_for("--base-duration-300")
    is Some(primer_duration_slow) else {
    fail("expected Primer 300ms duration token mapping")
  }
  assert_true(primer_duration_slow.moui_token == "DesignMotionTokens.slow_ms")
  assert_true(
    primer_duration_slow.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Primer.golden_mapping_for("--base-duration-1000")
    is Some(primer_duration_long) else {
    fail("expected Primer 1000ms duration token mapping")
  }
  assert_true(primer_duration_long.moui_token == "DesignMotionTokens.slow_ms")
  assert_true(
    primer_duration_long.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Primer.golden_mapping_for("--base-easing-linear")
    is Some(primer_linear) else {
    fail("expected Primer linear easing token mapping")
  }
  assert_true(primer_linear.moui_token == "DesignMotionTokens.easing")
  assert_true(primer_linear.status == @common.DesignTokenStatus::PreviewMapped)
  guard @common.DesignPreset::Primer.golden_mapping_for("--base-easing-easeOut")
    is Some(primer_easing) else {
    fail("expected Primer easeOut token mapping")
  }
  assert_true(primer_easing.moui_token == "DesignMotionTokens.easing")
  assert_true(primer_easing.status == @common.DesignTokenStatus::PreviewMapped)
  guard @common.DesignPreset::Primer.golden_mapping_for(
      "--base-easing-easeInOut",
    )
    is Some(primer_ease_in_out) else {
    fail("expected Primer easeInOut token mapping")
  }
  assert_true(primer_ease_in_out.moui_token == "DesignMotionTokens.easing")
  assert_true(
    primer_ease_in_out.status == @common.DesignTokenStatus::PreviewMapped,
  )
  assert_true(
    @common.DesignPreset::Fluent.has_golden_mapping("colorBrandBackground"),
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
  guard @common.DesignPreset::Fluent.golden_mapping_for("durationUltraFast")
    is Some(fluent_duration_ultra_fast) else {
    fail("expected Fluent ultra-fast duration token mapping")
  }
  assert_true(
    fluent_duration_ultra_fast.moui_token == "DesignMotionTokens.fast_ms",
  )
  assert_true(
    fluent_duration_ultra_fast.status ==
    @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Fluent.golden_mapping_for("durationFaster")
    is Some(fluent_duration_fast) else {
    fail("expected Fluent faster duration token mapping")
  }
  assert_true(fluent_duration_fast.moui_token == "DesignMotionTokens.fast_ms")
  assert_true(
    fluent_duration_fast.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Fluent.golden_mapping_for("durationFast")
    is Some(fluent_duration_fast_preview) else {
    fail("expected Fluent fast duration token mapping")
  }
  assert_true(
    fluent_duration_fast_preview.moui_token == "DesignMotionTokens.fast_ms",
  )
  assert_true(
    fluent_duration_fast_preview.status ==
    @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Fluent.golden_mapping_for("durationNormal")
    is Some(fluent_duration) else {
    fail("expected Fluent duration token mapping")
  }
  assert_true(fluent_duration.moui_token == "DesignMotionTokens.normal_ms")
  assert_true(fluent_duration.status == @common.DesignTokenStatus::ThemeMapped)
  guard @common.DesignPreset::Fluent.golden_mapping_for("durationGentle")
    is Some(fluent_duration_gentle) else {
    fail("expected Fluent gentle duration token mapping")
  }
  assert_true(
    fluent_duration_gentle.moui_token == "DesignMotionTokens.normal_ms",
  )
  assert_true(
    fluent_duration_gentle.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Fluent.golden_mapping_for("durationSlow")
    is Some(fluent_duration_slow) else {
    fail("expected Fluent slow duration token mapping")
  }
  assert_true(fluent_duration_slow.moui_token == "DesignMotionTokens.slow_ms")
  assert_true(
    fluent_duration_slow.status == @common.DesignTokenStatus::ThemeMapped,
  )
  guard @common.DesignPreset::Fluent.golden_mapping_for("durationSlower")
    is Some(fluent_duration_slower) else {
    fail("expected Fluent slower duration token mapping")
  }
  assert_true(fluent_duration_slower.moui_token == "DesignMotionTokens.slow_ms")
  assert_true(
    fluent_duration_slower.status == @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Fluent.golden_mapping_for("durationUltraSlow")
    is Some(fluent_duration_ultra_slow) else {
    fail("expected Fluent ultra-slow duration token mapping")
  }
  assert_true(
    fluent_duration_ultra_slow.moui_token == "DesignMotionTokens.slow_ms",
  )
  assert_true(
    fluent_duration_ultra_slow.status ==
    @common.DesignTokenStatus::PreviewMapped,
  )
  guard @common.DesignPreset::Fluent.golden_mapping_for("spacingHorizontalM")
    is Some(fluent_spacing) else {
    fail("expected Fluent spacing token mapping")
  }
  assert_true(fluent_spacing.moui_token == "DesignSpacingTokens.md")
  assert_true(fluent_spacing.status == @common.DesignTokenStatus::ThemeMapped)
  guard @common.DesignPreset::Fluent.golden_mapping_for("spacingHorizontalXL")
    is Some(fluent_spacing_xl) else {
    fail("expected Fluent extra-large spacing token mapping")
  }
  assert_true(fluent_spacing_xl.moui_token == "DesignSpacingTokens.lg")
  assert_true(
    fluent_spacing_xl.status == @common.DesignTokenStatus::ThemeMapped,
  )
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
  guard @common.DesignPreset::Fluent.golden_mapping_for("fontWeightSemibold")
    is Some(fluent_semibold) else {
    fail("expected Fluent semibold token mapping")
  }
  assert_true(
    fluent_semibold.moui_token == "DesignTypographyTokens.control.weight",
  )
  assert_true(fluent_semibold.status == @common.DesignTokenStatus::ThemeMapped)
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
  guard @common.DesignPreset::Fluent.golden_mapping_for("borderRadiusCircular")
    is Some(fluent_radius_circular) else {
    fail("expected Fluent circular radius token mapping")
  }
  assert_true(fluent_radius_circular.moui_token == "DesignRadiusTokens.pill")
  assert_true(
    fluent_radius_circular.status == @common.DesignTokenStatus::PreviewMapped,
  )
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
  guard @common.DesignPreset::Fluent.golden_mapping_for("curveEasyEase")
    is Some(fluent_curve) else {
    fail("expected Fluent curve token mapping")
  }
  assert_true(fluent_curve.moui_token == "DesignMotionTokens.easing")
  assert_true(fluent_curve.status == @common.DesignTokenStatus::PreviewMapped)
  assert_fluent_preview_curve_golden_mapping("curveLinear")
}

///|
fn assert_fluent_preview_curve_source_import(
  token : String,
  expected_source_value : String,
) -> Unit raise {
  guard @common.DesignPreset::Fluent.source_import_coverage_for(token)
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
  guard @common.DesignPreset::Fluent.source_import_integrity_for(token)
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
  guard @common.DesignPreset::Fluent.source_import_coverage_for(token)
    is Some(row) else {
    fail("expected Fluent global color source-import coverage for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.golden_mapped)
  assert_true(row.source_file.contains("colors.ts"))
  assert_true(row.source_sha == "e8744d569ba821d013ab3f4cec0c319c16c6da50")
  assert_true(row.source_value.contains(expected_source_value))
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == fluent_global_color_expected_status(token))
  guard @common.DesignPreset::Fluent.source_import_integrity_for(token)
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
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(token)
    is Some(row) else {
    fail("expected Fluent global color runtime alignment for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.source_value_resolved)
  assert_true(row.runtime_value_available)
  if fluent_global_color_runtime_aligned(token) {
    assert_true(row.runtime_aligned)
  } else {
    assert_false(row.runtime_aligned)
  }
  assert_true(row.status == fluent_global_color_expected_status(token))
  inspect(row.expected_runtime_value, content=expected_runtime_value)
}

///|
fn assert_fluent_preview_global_color_official_coverage(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard @common.DesignPreset::Fluent.official_token_coverage_for(token)
    is Some(row) else {
    fail("expected Fluent global color official coverage for " + token)
  }
  assert_true(row.mapped)
  assert_true(row.source_declared)
  assert_true(row.source_locked)
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == fluent_global_color_expected_status(token))
}

///|
fn assert_fluent_preview_global_color_golden_mapping(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard @common.DesignPreset::Fluent.golden_mapping_for(token) is Some(row) else {
    fail("expected Fluent global color golden mapping for " + token)
  }
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == fluent_global_color_expected_status(token))
}

///|
fn fluent_global_color_runtime_aligned(token : String) -> Bool {
  token == "red.primary" ||
  token == "green.primary" ||
  token == "darkOrange.primary" ||
  token == "blue.primary"
}

///|
fn fluent_global_color_expected_status(
  token : String,
) -> @common.DesignTokenStatus {
  if fluent_global_color_runtime_aligned(token) {
    @common.DesignTokenStatus::ThemeMapped
  } else {
    @common.DesignTokenStatus::PreviewMapped
  }
}

///|
fn assert_fluent_preview_typography_source_import(
  token : String,
  expected_source_value : String,
  moui_token : String,
) -> Unit raise {
  guard @common.DesignPreset::Fluent.source_import_coverage_for(token)
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
  guard @common.DesignPreset::Fluent.source_import_integrity_for(token)
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
  guard @common.DesignPreset::Fluent.source_import_coverage_for(token)
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
  guard @common.DesignPreset::Fluent.source_import_integrity_for(token)
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
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(token)
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
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(token)
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
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(token)
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
  guard @common.DesignPreset::Fluent.official_token_coverage_for(token)
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
  guard @common.DesignPreset::Fluent.official_token_coverage_for(token)
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
  guard @common.DesignPreset::Fluent.golden_mapping_for(token) is Some(row) else {
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
  guard @common.DesignPreset::Fluent.golden_mapping_for(token) is Some(row) else {
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
  guard @common.DesignPreset::Fluent.source_import_coverage_for(token)
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
  guard @common.DesignPreset::Fluent.source_import_integrity_for(token)
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
  guard @common.DesignPreset::Fluent.source_import_coverage_for(token)
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
  guard @common.DesignPreset::Fluent.source_import_integrity_for(token)
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
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(token)
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
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(token)
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
  guard @common.DesignPreset::Fluent.official_token_coverage_for(token)
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
  guard @common.DesignPreset::Fluent.official_token_coverage_for(token)
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
  guard @common.DesignPreset::Fluent.golden_mapping_for(token) is Some(row) else {
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
  guard @common.DesignPreset::Fluent.golden_mapping_for(token) is Some(row) else {
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
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(token)
    is Some(row) else {
    fail("expected Fluent curve runtime alignment for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.source_value_resolved)
  assert_true(row.runtime_value_available)
  assert_false(row.runtime_aligned)
  assert_true(row.status == @common.DesignTokenStatus::PreviewMapped)
  inspect(row.expected_runtime_value, content=expected_runtime_value)
  inspect(row.runtime_value, content="ease-out")
}

///|
fn assert_fluent_preview_curve_official_coverage(token : String) -> Unit raise {
  guard @common.DesignPreset::Fluent.official_token_coverage_for(token)
    is Some(row) else {
    fail("expected Fluent curve official token coverage for " + token)
  }
  assert_true(row.mapped)
  assert_true(row.source_declared)
  assert_true(row.source_locked)
  assert_true(row.moui_token == "DesignMotionTokens.easing")
  assert_true(row.status == @common.DesignTokenStatus::PreviewMapped)
}

///|
fn assert_fluent_preview_curve_golden_mapping(token : String) -> Unit raise {
  guard @common.DesignPreset::Fluent.golden_mapping_for(token) is Some(row) else {
    fail("expected Fluent curve golden mapping for " + token)
  }
  assert_true(row.moui_token == "DesignMotionTokens.easing")
  assert_true(row.status == @common.DesignTokenStatus::PreviewMapped)
}

///|
fn assert_carbon_mapped_layout_source_import(
  token : String,
  expected_source_token : String,
  expected_mini_units : String,
  expected_px : String,
  moui_token : String,
) -> Unit raise {
  guard @common.DesignPreset::Carbon.source_import_coverage_for(token)
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
  assert_true(row.status == @common.DesignTokenStatus::ThemeMapped)
  guard @common.DesignPreset::Carbon.source_import_integrity_for(token)
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
  guard @common.DesignPreset::Carbon.source_import_coverage_for(token)
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
  assert_true(row.status == @common.DesignTokenStatus::PreviewMapped)
  guard @common.DesignPreset::Carbon.source_import_integrity_for(token)
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
  guard @common.DesignPreset::Carbon.runtime_token_alignment_for(token)
    is Some(row) else {
    fail("expected Carbon spacing runtime alignment for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.source_value_resolved)
  assert_true(row.runtime_value_available)
  assert_true(row.runtime_aligned)
  assert_true(row.status == @common.DesignTokenStatus::ThemeMapped)
  inspect(row.runtime_value, content=runtime_value)
}

///|
fn assert_carbon_preview_spacing_runtime_alignment(
  token : String,
  expected_runtime_value : String,
  runtime_value : String,
) -> Unit raise {
  guard @common.DesignPreset::Carbon.runtime_token_alignment_for(token)
    is Some(row) else {
    fail("expected Carbon preview spacing runtime alignment for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.source_value_resolved)
  assert_true(row.runtime_value_available)
  assert_false(row.runtime_aligned)
  assert_true(row.status == @common.DesignTokenStatus::PreviewMapped)
  inspect(row.expected_runtime_value, content=expected_runtime_value)
  inspect(row.runtime_value, content=runtime_value)
}

///|
fn assert_carbon_mapped_spacing_official_coverage(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard @common.DesignPreset::Carbon.official_token_coverage_for(token)
    is Some(row) else {
    fail("expected Carbon spacing official token coverage for " + token)
  }
  assert_true(row.mapped)
  assert_true(row.source_declared)
  assert_true(row.source_locked)
  assert_true(row.source_kind == "official-source")
  assert_true(row.token_path == "packages/layout")
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == @common.DesignTokenStatus::ThemeMapped)
}

///|
fn assert_carbon_preview_spacing_official_coverage(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard @common.DesignPreset::Carbon.official_token_coverage_for(token)
    is Some(row) else {
    fail("expected Carbon preview spacing official token coverage for " + token)
  }
  assert_true(row.mapped)
  assert_true(row.source_declared)
  assert_true(row.source_locked)
  assert_true(row.source_kind == "official-source")
  assert_true(row.token_path == "packages/layout")
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == @common.DesignTokenStatus::PreviewMapped)
}

///|
fn assert_carbon_mapped_spacing_golden_mapping(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard @common.DesignPreset::Carbon.golden_mapping_for(token) is Some(row) else {
    fail("expected Carbon spacing golden mapping for " + token)
  }
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == @common.DesignTokenStatus::ThemeMapped)
}

///|
fn assert_carbon_preview_spacing_golden_mapping(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard @common.DesignPreset::Carbon.golden_mapping_for(token) is Some(row) else {
    fail("expected Carbon preview spacing golden mapping for " + token)
  }
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == @common.DesignTokenStatus::PreviewMapped)
}

///|
fn assert_fluent_preview_spacing_source_import(
  token : String,
  expected_source_value : String,
  moui_token : String,
) -> Unit raise {
  guard @common.DesignPreset::Fluent.source_import_coverage_for(token)
    is Some(row) else {
    fail("expected Fluent spacing source-import coverage for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.golden_mapped)
  assert_true(row.source_file.contains("spacings.ts"))
  assert_true(row.source_sha == "fa5df4c81834b5abfb508d2317e4c50eff101d1c")
  assert_true(row.source_value.contains(expected_source_value))
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == @common.DesignTokenStatus::PreviewMapped)
  guard @common.DesignPreset::Fluent.source_import_integrity_for(token)
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
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(token)
    is Some(row) else {
    fail("expected Fluent spacing runtime alignment for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.source_value_resolved)
  assert_true(row.runtime_value_available)
  assert_false(row.runtime_aligned)
  assert_true(row.status == @common.DesignTokenStatus::PreviewMapped)
  inspect(row.expected_runtime_value, content=expected_runtime_value)
  inspect(row.runtime_value, content=runtime_value)
}

///|
fn assert_fluent_preview_spacing_official_coverage(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard @common.DesignPreset::Fluent.official_token_coverage_for(token)
    is Some(row) else {
    fail("expected Fluent spacing official token coverage for " + token)
  }
  assert_true(row.mapped)
  assert_true(row.source_declared)
  assert_true(row.source_locked)
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == @common.DesignTokenStatus::PreviewMapped)
}

///|
fn assert_fluent_preview_spacing_golden_mapping(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard @common.DesignPreset::Fluent.golden_mapping_for(token) is Some(row) else {
    fail("expected Fluent spacing golden mapping for " + token)
  }
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == @common.DesignTokenStatus::PreviewMapped)
}

///|
fn assert_fluent_mapped_spacing_source_import(
  token : String,
  expected_source_value : String,
  moui_token : String,
) -> Unit raise {
  guard @common.DesignPreset::Fluent.source_import_coverage_for(token)
    is Some(row) else {
    fail("expected mapped Fluent spacing source-import coverage for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.golden_mapped)
  assert_true(row.source_file.contains("spacings.ts"))
  assert_true(row.source_sha == "fa5df4c81834b5abfb508d2317e4c50eff101d1c")
  assert_true(row.source_value.contains(expected_source_value))
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == @common.DesignTokenStatus::ThemeMapped)
  guard @common.DesignPreset::Fluent.source_import_integrity_for(token)
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
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(token)
    is Some(row) else {
    fail("expected mapped Fluent spacing runtime alignment for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.source_value_resolved)
  assert_true(row.runtime_value_available)
  assert_true(row.runtime_aligned)
  assert_true(row.status == @common.DesignTokenStatus::ThemeMapped)
  inspect(row.runtime_value, content=runtime_value)
}

///|
fn assert_fluent_mapped_spacing_official_coverage(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard @common.DesignPreset::Fluent.official_token_coverage_for(token)
    is Some(row) else {
    fail("expected mapped Fluent spacing official token coverage for " + token)
  }
  assert_true(row.mapped)
  assert_true(row.source_declared)
  assert_true(row.source_locked)
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == @common.DesignTokenStatus::ThemeMapped)
}

///|
fn assert_fluent_mapped_spacing_golden_mapping(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard @common.DesignPreset::Fluent.golden_mapping_for(token) is Some(row) else {
    fail("expected mapped Fluent spacing golden mapping for " + token)
  }
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == @common.DesignTokenStatus::ThemeMapped)
}

///|
fn assert_fluent_preview_radius_source_import(
  token : String,
  expected_source_value : String,
  moui_token : String,
) -> Unit raise {
  guard @common.DesignPreset::Fluent.source_import_coverage_for(token)
    is Some(row) else {
    fail("expected Fluent radius source-import coverage for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.golden_mapped)
  assert_true(row.source_file.contains("borderRadius.ts"))
  assert_true(row.source_sha == "64523745129486fad856000b0443b55d47a21e9f")
  assert_true(row.source_value.contains(expected_source_value))
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == @common.DesignTokenStatus::PreviewMapped)
  guard @common.DesignPreset::Fluent.source_import_integrity_for(token)
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
  guard @common.DesignPreset::Fluent.runtime_token_alignment_for(token)
    is Some(row) else {
    fail("expected Fluent radius runtime alignment for " + token)
  }
  assert_true(row.source_imported)
  assert_true(row.source_value_resolved)
  assert_true(row.runtime_value_available)
  assert_false(row.runtime_aligned)
  assert_true(row.status == @common.DesignTokenStatus::PreviewMapped)
  inspect(row.expected_runtime_value, content=expected_runtime_value)
  inspect(row.runtime_value, content=runtime_value)
}

///|
fn assert_fluent_preview_radius_official_coverage(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard @common.DesignPreset::Fluent.official_token_coverage_for(token)
    is Some(row) else {
    fail("expected Fluent radius official token coverage for " + token)
  }
  assert_true(row.mapped)
  assert_true(row.source_declared)
  assert_true(row.source_locked)
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == @common.DesignTokenStatus::PreviewMapped)
}

///|
fn assert_fluent_preview_radius_golden_mapping(
  token : String,
  moui_token : String,
) -> Unit raise {
  guard @common.DesignPreset::Fluent.golden_mapping_for(token) is Some(row) else {
    fail("expected Fluent radius golden mapping for " + token)
  }
  assert_true(row.moui_token == moui_token)
  assert_true(row.status == @common.DesignTokenStatus::PreviewMapped)
}
