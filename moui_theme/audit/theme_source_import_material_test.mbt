///|
test "source imported Material tokens expose pinned source values" {
  guard source_imported_token_for(
      @common.DesignPreset::Material,
      "--md-sys-color-primary",
    )
    is Some(material_primary) else {
    fail("expected imported Material primary token")
  }
  assert_true(material_primary.source_file.contains("_md-sys-color.scss"))
  assert_true(material_primary.source_value.contains("primary40"))
  guard source_imported_token_for(
      @common.DesignPreset::Material,
      "md-ref-palette.primary40",
    )
    is Some(material_primary_ref) else {
    fail("expected Material primary40 reference-palette import")
  }
  assert_true(material_primary_ref.source_value.contains("#6750a4"))
  assert_true(material_primary_ref.source_file.contains("_md-ref-palette.scss"))
  guard source_import_coverage_for(
      @common.DesignPreset::Material,
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
  guard source_imported_token_for(
      @common.DesignPreset::Material,
      "--md-filled-button-container-color",
    )
    is Some(material_button_container) else {
    fail("expected imported Material filled-button container token")
  }
  assert_true(
    material_button_container.source_value.contains("container-color"),
  )
  assert_true(material_button_container.source_value.contains("#6750a4"))
  guard source_imported_token_for(
      @common.DesignPreset::Material,
      "--md-filled-button-label-text-color",
    )
    is Some(material_button_label) else {
    fail("expected imported Material filled-button label token")
  }
  assert_true(material_button_label.source_value.contains("label-text-color"))
  assert_true(material_button_label.source_value.contains("#fff"))
  guard source_imported_token_for(
      @common.DesignPreset::Material,
      "--md-filled-button-pressed-state-layer-opacity",
    )
    is Some(material_button_pressed) else {
    fail("expected imported Material filled-button pressed-state token")
  }
  assert_true(
    material_button_pressed.source_value.contains("pressed-state-layer-opacity"),
  )
  assert_true(material_button_pressed.source_value.contains("0.12"))
  guard source_imported_token_for(
      @common.DesignPreset::Material,
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
  guard source_imported_token_for(
      @common.DesignPreset::Material,
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
  guard source_imported_token_for(
      @common.DesignPreset::Material,
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
  guard source_import_coverage_for(
      @common.DesignPreset::Material,
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
  guard source_imported_token_for(
      @common.DesignPreset::Material,
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
  guard source_import_coverage_for(
      @common.DesignPreset::Material,
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
  guard source_imported_token_for(
      @common.DesignPreset::Material,
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
  guard source_import_coverage_for(
      @common.DesignPreset::Material,
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
  guard source_imported_token_for(
      @common.DesignPreset::Material,
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
  guard source_imported_token_for(
      @common.DesignPreset::Material,
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
  guard source_import_coverage_for(
      @common.DesignPreset::Material,
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
  guard source_import_integrity_for(
      @common.DesignPreset::Material,
      "--md-sys-motion-duration-short4",
    )
    is Some(material_motion_short4_integrity) else {
    fail("expected Material short4 motion source-import integrity")
  }
  assert_true(material_motion_short4_integrity.integrity_ok)
  assert_true(material_motion_short4_integrity.moui_token_matches_golden)
  guard source_imported_token_for(
      @common.DesignPreset::Material,
      "--md-sys-motion-duration-medium2",
    )
    is Some(material_motion_medium2_import) else {
    fail("expected imported Material medium2 motion token")
  }
  assert_true(
    material_motion_medium2_import.source_file.contains("_md-sys-motion.scss"),
  )
  assert_true(material_motion_medium2_import.source_value.contains("300ms"))
  guard source_import_coverage_for(
      @common.DesignPreset::Material,
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
  guard source_import_integrity_for(
      @common.DesignPreset::Material,
      "--md-sys-motion-duration-medium2",
    )
    is Some(material_motion_medium2_integrity) else {
    fail("expected Material medium2 motion source-import integrity")
  }
  assert_true(material_motion_medium2_integrity.integrity_ok)
  assert_true(material_motion_medium2_integrity.moui_token_matches_golden)
  guard source_imported_token_for(
      @common.DesignPreset::Material,
      "--md-sys-motion-duration-medium4",
    )
    is Some(material_motion_medium4_import) else {
    fail("expected imported Material medium4 motion token")
  }
  assert_true(
    material_motion_medium4_import.source_file.contains("_md-sys-motion.scss"),
  )
  assert_true(material_motion_medium4_import.source_value.contains("400ms"))
  guard source_import_coverage_for(
      @common.DesignPreset::Material,
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
  guard source_import_integrity_for(
      @common.DesignPreset::Material,
      "--md-sys-motion-duration-medium4",
    )
    is Some(material_motion_medium4_integrity) else {
    fail("expected Material medium4 motion source-import integrity")
  }
  assert_true(material_motion_medium4_integrity.integrity_ok)
  assert_true(material_motion_medium4_integrity.moui_token_matches_golden)
  guard source_imported_token_for(
      @common.DesignPreset::Material,
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
  guard source_import_coverage_for(
      @common.DesignPreset::Material,
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
    material_motion_easing_coverage.status == DesignTokenStatus::PreviewMapped,
  )
  guard source_import_integrity_for(
      @common.DesignPreset::Material,
      "--md-sys-motion-easing-standard",
    )
    is Some(material_motion_easing_integrity) else {
    fail("expected Material standard easing source-import integrity")
  }
  assert_true(material_motion_easing_integrity.integrity_ok)
  assert_true(material_motion_easing_integrity.moui_token_matches_golden)
  guard source_imported_token_for(
      @common.DesignPreset::Material,
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
  guard source_import_coverage_for(
      @common.DesignPreset::Material,
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
  guard source_import_integrity_for(
      @common.DesignPreset::Material,
      "--md-linear-progress-active-indicator-color",
    )
    is Some(material_progress_integrity) else {
    fail("expected Material progress source-import integrity")
  }
  assert_true(material_progress_integrity.integrity_ok)
  assert_true(material_progress_integrity.moui_token_matches_golden)
  guard source_imported_token_for(
      @common.DesignPreset::Material,
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
  guard source_import_coverage_for(
      @common.DesignPreset::Material,
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
  guard source_import_integrity_for(
      @common.DesignPreset::Material,
      "--md-menu-container-color",
    )
    is Some(material_menu_integrity) else {
    fail("expected Material menu source-import integrity")
  }
  assert_true(material_menu_integrity.integrity_ok)
  assert_true(material_menu_integrity.moui_token_matches_golden)
}
