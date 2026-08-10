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
  let palette = {
    ..base.palette,
    primary: accent,
    danger: @core.Color::rgba(r=0.92, g=0.18, b=0.28),
  }
  let spacing_scale = { ..base.spacing_scale, sm: 14.0 }
  let radius_scale = { ..base.radius_scale, md: 10.0 }
  let customized = @common.custom(
    base~,
    palette~,
    radius_scale~,
    spacing_scale~,
  )
  assert_true(customized.palette.primary == accent)
  inspect(customized.radius_scale.md, content="10")
  inspect(customized.spacing_scale.sm, content="14")
  assert_true(customized.palette.background == base.palette.background)
  assert_true(
    customized.palette.danger == @core.Color::rgba(r=0.92, g=0.18, b=0.28),
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
    let manifest = manifest(preset)
    assert_true(manifest.sources.length() >= 3)
    assert_false(manifest.is_official_complete())
    assert_true(manifest.official_source_count() >= 1)
    assert_true(
      manifest.source_lock_count() == manifest.official_source_count(),
    )
    assert_true(manifest.has_official_source_locks())
    assert_true(
      source_lock_report(preset).length() == manifest.sources.length(),
    )
    assert_true(source_lock_quality_gap_count(preset) > 0)
    assert_true(stable_source_lock_count(preset) >= 1)
    assert_true(moving_source_ref_count(preset) > 0)
    assert_false(has_stable_source_locks(preset))
    assert_true(manifest.has_token_category(DesignTokenCategory::Color))
    assert_true(manifest.has_token_category(DesignTokenCategory::Typography))
    assert_true(
      manifest.has_token_category(DesignTokenCategory::ComponentStyle),
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
    let records = source_lock_report(preset)
    let stable = stable_source_lock_count(preset)
    assert_true(records.length() == sources(preset).length())
    assert_true(
      source_lock_quality_gap_count(preset) == records.length() - stable,
    )
    assert_true(stable >= 1)
    assert_true(source_snapshot_url_count(preset) == stable)
    assert_true(source_snapshot_url_gap_count(preset) == 0)
    assert_true(moving_source_ref_count(preset) == records.length() - stable)
    assert_false(has_stable_source_locks(preset))
    assert_true(
      records.any(item => {
        item.ref_kind == DesignSourceRefKind::StableSnapshotRef &&
        item.stable_lock &&
        item.token_path != "" &&
        item.snapshot_url.contains(item.source_ref) &&
        item.snapshot_url.contains(item.token_path)
      }),
    )
    assert_true(
      records.any(item => {
        item.ref_kind == DesignSourceRefKind::LiveDocumentationRef
      }),
    )
    assert_false(
      records.any(item => item.ref_kind == DesignSourceRefKind::MovingBranchRef),
    )
    for item in records {
      assert_true(item.declared_lock)
      assert_true(item.status == DesignTokenStatus::SourceMapped)
      if item.ref_kind == DesignSourceRefKind::StableSnapshotRef {
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
    let rows = source_package_inventory(preset)
    assert_true(rows.length() >= 2)
    assert_true(source_package_inventory_count(preset) == rows.length())
    assert_true(source_package_snapshot_count(preset) == rows.length())
    assert_true(source_package_snapshot_gap_count(preset) == 0)
    assert_true(source_package_mapped_token_count(preset) > 0)
    assert_true(source_package_imported_token_count(preset) > 0)
    assert_true(
      source_package_imported_token_count(preset) ==
      source_imported_token_count(preset),
    )
    assert_true(source_package_import_gap_count(preset) == rows.length())
    assert_true(rows.any(item => item.imported_token_count > 0))
    for item in rows {
      assert_true(item.source_ref != "")
      assert_true(item.snapshot_url.contains(item.source_ref))
      assert_true(item.snapshot_url.contains(item.token_path))
      assert_true(item.package_path != "")
      assert_true(item.tracked_path_count > 0)
      assert_true(item.pending_gap != "none")
      assert_true(item.status == DesignTokenStatus::PreviewMapped)
    }
  }
  let material_system = source_package_inventory(@common.DesignPreset::Material)[0]
  assert_true(material_system.package_path.contains("_md-sys"))
  assert_true(material_system.mapped_token_count == 13)
  assert_true(
    source_package_inventory(@common.DesignPreset::Material).any(item => {
      item.package_path == "tokens/versions/v0_192/_md-ref-palette.scss" &&
      item.imported_token_count == 9
    }),
  )
  assert_true(
    source_package_inventory(@common.DesignPreset::Material).any(item => {
      item.package_path == "tokens/_md-comp-*.scss" &&
      item.mapped_token_count == 5 &&
      item.imported_token_count == 5
    }),
  )
  assert_true(
    source_package_inventory(@common.DesignPreset::Carbon).any(item => {
      item.package_path == "packages/layout/src/*.ts" &&
      item.mapped_token_count == 25 &&
      item.imported_token_count == 25
    }),
  )
  assert_true(
    source_lock_report(@common.DesignPreset::Carbon).any(item => {
      item.source_url.contains("packages/colors") &&
      item.token_path == "packages/colors" &&
      item.stable_lock
    }),
  )
  assert_true(
    source_lock_report(@common.DesignPreset::Carbon).any(item => {
      item.source_url.contains("packages/styles") &&
      item.token_path == "packages/styles" &&
      item.stable_lock
    }),
  )
  let carbon_tokens = source_package_inventory(@common.DesignPreset::Carbon)[1]
  assert_true(carbon_tokens.package_path.contains("src/tokens"))
  assert_true(
    source_package_inventory(@common.DesignPreset::Carbon).any(item => {
      item.package_path == "packages/themes/src/{white,g10,g90,g100}.ts" &&
      item.imported_token_count == 17
    }),
  )
  assert_true(
    source_package_inventory(@common.DesignPreset::Carbon).any(item => {
      item.package_path == "packages/themes/src/component-tokens/**/*.ts" &&
      item.imported_token_count == 1 &&
      item.mapped_token_count == 1
    }),
  )
  assert_true(
    source_package_inventory(@common.DesignPreset::Carbon).any(item => {
      item.package_path == "packages/motion/src/index.ts" &&
      item.imported_token_count == 13 &&
      item.mapped_token_count == 13
    }),
  )
  assert_true(
    source_package_inventory(@common.DesignPreset::Carbon).any(item => {
      item.package_path == "packages/styles/scss/components/slider/*.scss" &&
      item.imported_token_count == 1 &&
      item.mapped_token_count == 1
    }),
  )
  assert_true(
    source_package_inventory(@common.DesignPreset::Carbon).any(item => {
      item.package_path == "packages/colors/src/colors.ts" &&
      item.source_url.contains("packages/colors") &&
      item.imported_token_count == 6
    }),
  )
  let primer_color = source_package_inventory(@common.DesignPreset::Primer)[0]
  assert_true(primer_color.package_path.contains("base/color"))
  assert_true(
    source_package_inventory(@common.DesignPreset::Primer).any(item => {
      item.package_path == "src/tokens/functional/color/*.json5" &&
      item.imported_token_count == 16 &&
      item.mapped_token_count == 13
    }),
  )
  assert_true(
    source_package_inventory(@common.DesignPreset::Primer).any(item => {
      item.package_path == "src/tokens/base/{motion,size,typography}" &&
      item.imported_token_count == 28 &&
      item.mapped_token_count == 28
    }),
  )
  assert_true(
    source_package_inventory(@common.DesignPreset::Primer).any(item => {
      item.package_path == "src/tokens/functional/size/*.json5" &&
      item.imported_token_count == 5 &&
      item.mapped_token_count == 5
    }),
  )
  assert_true(
    source_package_inventory(@common.DesignPreset::Primer).any(item => {
      item.package_path == "src/tokens/functional/shadow/*.json5" &&
      item.imported_token_count == 3 &&
      item.mapped_token_count == 3
    }),
  )
  assert_true(
    source_package_inventory(@common.DesignPreset::Primer).any(item => {
      item.package_path == "src/tokens/component/*.json5" &&
      item.imported_token_count == 3 &&
      item.mapped_token_count == 6
    }),
  )
  let fluent_global = source_package_inventory(@common.DesignPreset::Fluent)[0]
  assert_true(fluent_global.package_path.contains("src/global"))
  assert_true(fluent_global.mapped_token_count == 90)
  assert_true(fluent_global.imported_token_count == 90)
  assert_true(
    source_package_inventory(@common.DesignPreset::Fluent).any(item => {
      item.package_path == "packages/tokens/src/alias/*.ts" &&
      item.mapped_token_count == 12 &&
      item.imported_token_count == 15
    }),
  )
  assert_true(
    source_package_inventory(@common.DesignPreset::Fluent).any(item => {
      item.package_path == "packages/tokens/src/themes/**" &&
      item.mapped_token_count == 1 &&
      item.imported_token_count == 0
    }),
  )
  assert_true(
    source_package_inventory(@common.DesignPreset::Fluent).any(item => {
      item.package_path == "packages/web-components/src/progress-bar/*.ts" &&
      item.mapped_token_count == 1 &&
      item.imported_token_count == 1
    }),
  )
}

///|
