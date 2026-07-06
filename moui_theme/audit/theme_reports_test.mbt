///|
test "source manifests keep preview presets from claiming full official coverage" {
  let material = manifest(@common.DesignPreset::Material)
  assert_true(material.stage == DesignTokenStatus::PreviewMapped)
  assert_true(
    material.token_coverage.any(item => {
      item.category == DesignTokenCategory::StateLayer &&
      item.status == DesignTokenStatus::ComponentMapped
    }),
  )
  assert_true(
    material.component_coverage.any(item => {
      item.component == "Progress" &&
      item.status == DesignTokenStatus::ComponentMapped &&
      item.moui_surface == "@views.ProgressStyle"
    }),
  )
  assert_true(
    material.component_coverage.any(item => {
      item.component == "Slider" &&
      item.status == DesignTokenStatus::ComponentMapped &&
      item.moui_surface == "@views.SliderStyle"
    }),
  )
  assert_true(
    material.component_coverage.any(item => {
      item.component == "Picker" &&
      item.status == DesignTokenStatus::ComponentMapped &&
      item.moui_surface == "@views.PickerStyle"
    }),
  )
  assert_true(
    material.component_coverage.any(item => {
      item.component == "DatePicker" &&
      item.status == DesignTokenStatus::ComponentMapped &&
      item.moui_surface == "@views.PickerStyle"
    }),
  )
  assert_true(
    material.component_coverage.any(item => {
      item.component == "Feedback" &&
      item.status == DesignTokenStatus::ComponentMapped &&
      item.moui_surface == "@views.FeedbackStyle"
    }),
  )
  assert_true(
    material.component_coverage.any(item => {
      item.component == "Badge" &&
      item.status == DesignTokenStatus::ComponentMapped &&
      item.moui_surface == "@views.BadgeStyle"
    }),
  )
  assert_true(
    material.component_coverage.any(item => {
      item.component == "FormValidation" &&
      item.status == DesignTokenStatus::ComponentMapped &&
      item.moui_surface == "@views.FormValidationStyle"
    }),
  )
}

///|
test "customization coverage advertises inheritance and token override APIs" {
  let manifest = manifest(@common.DesignPreset::Carbon)
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
      item.status == DesignTokenStatus::ThemeMapped
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
      item.status == DesignTokenStatus::ComponentMapped
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
    let report = customization_report(preset)
    assert_true(
      report.length() == manifest(preset).customization_coverage.length(),
    )
    assert_true(customization_report_count(preset) == 6)
    assert_true(customization_capability_gap_count(preset) == 0)
    assert_true(customization_official_parity_gap_count(preset) == 6)
    for item in report {
      assert_true(item.api_surface != "")
      assert_true(item.token_surface != "")
      assert_true(item.status != DesignTokenStatus::NotMapped)
      assert_true(
        manifest(preset).customization_coverage.any(coverage => {
          coverage.capability == item.capability &&
          coverage.api_surface == item.api_surface
        }),
      )
    }
  }
  guard customization_report_for(
      @common.DesignPreset::Material,
      "Design token group override",
    )
    is Some(group_override) else {
    fail("expected design-token group override capability")
  }
  assert_true(
    group_override.kind == DesignCustomizationKind::DesignTokenGroupOverride,
  )
  assert_true(group_override.inherits_base)
  assert_true(group_override.supports_override)
  assert_true(group_override.recomputes_dependents)
  assert_true(group_override.remaining_gap.contains("Official per-system"))
  guard customization_report_for(
      @common.DesignPreset::Primer,
      "Component token override",
    )
    is Some(component_override) else {
    fail("expected component token override capability")
  }
  assert_true(
    component_override.kind == DesignCustomizationKind::ComponentTokenOverride,
  )
  assert_true(component_override.status == DesignTokenStatus::ComponentMapped)
  assert_true(component_override.token_surface == "DesignComponentTokens")
  guard customization_report_for(
      @common.DesignPreset::Fluent,
      "Variant Theme resolver",
    )
    is Some(variant_theme) else {
    fail("expected variant theme resolver capability")
  }
  assert_true(
    variant_theme.kind == DesignCustomizationKind::VariantThemeResolution,
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
    let audit = requirement_audit(preset)
    assert_true(audit.length() >= 20)
    assert_false(is_design_system_complete(preset))
    assert_true(requirement_gap_count(preset) > 0)
    guard requirement_audit_for(
        preset,
        DesignSystemRequirement::OfficialSources,
      )
      is Some(sources) else {
      fail("expected official sources audit")
    }
    assert_true(sources.status == DesignTokenStatus::SourceMapped)
    assert_true(sources.evidence.contains("source anchors"))
    guard requirement_audit_for(
        preset,
        DesignSystemRequirement::SourceVersionLocks,
      )
      is Some(source_versions) else {
      fail("expected source version lock audit")
    }
    assert_true(source_versions.status == DesignTokenStatus::PreviewMapped)
    assert_true(source_versions.evidence.contains("stable source locks"))
    assert_true(
      source_versions.remaining_gap.contains("Live official documentation"),
    )
    guard requirement_audit_for(
        preset,
        DesignSystemRequirement::SourcePackageInventory,
      )
      is Some(source_packages) else {
      fail("expected source package inventory audit")
    }
    assert_true(source_packages.status == DesignTokenStatus::PreviewMapped)
    assert_true(source_packages.evidence.contains("source package rows"))
    assert_true(source_packages.evidence.contains("imported tokens"))
    assert_true(source_packages.evidence.contains("source-import records"))
    guard requirement_audit_for(
        preset,
        DesignSystemRequirement::SourceImportedTokens,
      )
      is Some(source_imports) else {
      fail("expected source-imported token audit")
    }
    assert_true(source_imports.status == DesignTokenStatus::SourceMapped)
    assert_true(source_imports.evidence.contains("official anchors"))
    assert_true(source_imports.evidence.contains("import coverage gaps"))
    assert_true(source_imports.evidence.contains("integrity gaps"))
    for
      requirement in [
        DesignSystemRequirement::SemanticPalette,
        DesignSystemRequirement::Typography,
        DesignSystemRequirement::ShapeRadius,
        DesignSystemRequirement::ElevationShadow,
        DesignSystemRequirement::Motion,
        DesignSystemRequirement::Surface,
        DesignSystemRequirement::StateLayer,
      ] {
      guard requirement_audit_for(preset, requirement) is Some(token_group) else {
        fail("expected token-group audit")
      }
      assert_true(token_group.status != DesignTokenStatus::NotMapped)
      assert_true(token_group.evidence.contains("token-group resolver records"))
      assert_true(token_group.evidence.contains("source-lock gaps"))
      assert_true(token_group.evidence.contains("official parity gaps"))
    }
    guard requirement_audit_for(preset, DesignSystemRequirement::SpacingDensity)
      is Some(spacing_density) else {
      fail("expected spacing density audit")
    }
    assert_true(spacing_density.status == DesignTokenStatus::PreviewMapped)
    assert_true(spacing_density.evidence.contains("density resolver records"))
    assert_true(spacing_density.evidence.contains("source-lock gaps"))
    assert_true(spacing_density.evidence.contains("official parity gaps"))
    guard requirement_audit_for(preset, DesignSystemRequirement::SchemeVariants)
      is Some(scheme_variants) else {
      fail("expected scheme variant audit")
    }
    assert_true(scheme_variants.status == DesignTokenStatus::PreviewMapped)
    assert_true(scheme_variants.evidence.contains("variant resolver records"))
    assert_true(scheme_variants.evidence.contains("source-lock gaps"))
    assert_true(scheme_variants.evidence.contains("official parity gaps"))
    guard requirement_audit_for(
        preset,
        DesignSystemRequirement::RuntimeTokenAlignment,
      )
      is Some(runtime_alignment) else {
      fail("expected runtime token alignment audit")
    }
    assert_true(runtime_alignment.status == DesignTokenStatus::PreviewMapped)
    assert_true(runtime_alignment.evidence.contains("runtime token rows"))
    assert_true(runtime_alignment.evidence.contains("alignment gaps"))
    guard requirement_audit_for(preset, DesignSystemRequirement::Customization)
      is Some(customization) else {
      fail("expected customization audit")
    }
    assert_true(customization.status == DesignTokenStatus::ComponentMapped)
    assert_true(
      customization.evidence.contains("customization capability records"),
    )
    assert_true(customization.evidence.contains("official parity gaps"))
    guard requirement_audit_for(
        preset,
        DesignSystemRequirement::ComponentTokens,
      )
      is Some(components) else {
      fail("expected component token audit")
    }
    assert_true(components.status == DesignTokenStatus::ComponentMapped)
    assert_true(components.evidence.contains("component token surfaces"))
    assert_true(
      components.evidence.contains("component style resolver records"),
    )
    assert_true(components.evidence.contains("source-lock gaps"))
    assert_true(components.evidence.contains("official parity gaps"))
    guard requirement_audit_for(
        preset,
        DesignSystemRequirement::ComponentMatrix,
      )
      is Some(component_matrix) else {
      fail("expected component matrix audit")
    }
    assert_true(component_matrix.status == DesignTokenStatus::PreviewMapped)
    assert_true(component_matrix.evidence.contains("component matrix rows"))
    guard requirement_audit_for(
        preset,
        DesignSystemRequirement::OfficialTokenCoverage,
      )
      is Some(official_tokens) else {
      fail("expected official token coverage audit")
    }
    assert_true(official_tokens.status == DesignTokenStatus::PreviewMapped)
    assert_true(official_tokens.evidence.contains("official token anchors"))
    guard requirement_audit_for(preset, DesignSystemRequirement::GoldenMappings)
      is Some(golden) else {
      fail("expected golden mapping audit")
    }
    assert_true(golden.status == DesignTokenStatus::PreviewMapped)
    assert_true(golden.remaining_gap != "none")
    guard requirement_audit_for(
        preset,
        DesignSystemRequirement::AdaptationDifferences,
      )
      is Some(adaptation) else {
      fail("expected adaptation differences audit")
    }
    assert_true(adaptation.status == DesignTokenStatus::PreviewMapped)
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
    let rows = token_taxonomy_report(preset)
    assert_true(rows.length() == 10)
    assert_true(token_taxonomy_count(preset) == 10)
    assert_true(token_taxonomy_required_count(preset) == 10)
    assert_true(token_taxonomy_mapped_count(preset) == 10)
    assert_true(token_taxonomy_gap_count(preset) == 0)
    assert_true(token_taxonomy_source_gap_count(preset) == 0)
    if preset == @common.DesignPreset::Material {
      assert_true(token_taxonomy_official_parity_gap_count(preset) == 10)
    } else {
      assert_true(token_taxonomy_official_parity_gap_count(preset) == 8)
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
      assert_true(item.status != DesignTokenStatus::NotMapped)
    }
    guard token_taxonomy_for(preset, DesignTokenCategory::Color) is Some(color) else {
      fail("expected color taxonomy row")
    }
    assert_true(color.token_surface.contains("DesignSemanticPalette"))
    assert_true(color.moui_surface.contains("@core."))
    guard token_taxonomy_for(preset, DesignTokenCategory::Density)
      is Some(density) else {
      fail("expected density taxonomy row")
    }
    assert_true(density.token_surface.contains("DesignDensity"))
    assert_true(density.moui_surface.contains("@core.SpacingScale"))
    guard token_taxonomy_for(preset, DesignTokenCategory::StateLayer)
      is Some(state_layer) else {
      fail("expected state-layer taxonomy row")
    }
    assert_true(state_layer.token_surface.contains("DesignStateLayerTokens"))
    assert_true(state_layer.status == DesignTokenStatus::ComponentMapped)
    guard token_taxonomy_for(preset, DesignTokenCategory::ComponentStyle)
      is Some(component) else {
      fail("expected component-style taxonomy row")
    }
    assert_true(component.token_surface.contains("DesignComponentTokens"))
    assert_true(component.status == DesignTokenStatus::ComponentMapped)
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
    let rows = semantic_palette_role_report(
      preset,
      scheme=@core.ColorScheme::Light,
    )
    assert_true(rows.length() == 14)
    assert_true(semantic_palette_role_count(preset) == 14)
    assert_true(semantic_palette_role_mapped_count(preset) > 0)
    assert_true(semantic_palette_role_aligned_count(preset) > 0)
    for item in rows {
      assert_true(item.required)
      assert_true(item.token_surface.contains("DesignSemanticPalette"))
      assert_true(item.core_surface.contains("@core."))
      assert_true(item.token_value == item.core_value)
      assert_true(item.resolves_core_surface)
      assert_true(item.status != DesignTokenStatus::NotMapped)
    }
    guard semantic_palette_role_for(
        preset,
        DesignSemanticPaletteRole::PalettePrimary,
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
      // Fluent 2 maps warning/danger/info to status-background tokens
      // (#8a5400/#b10f0e/#0f6cbd) that differ from the pinned Fluent global
      // color primaries (orange/red/blue), so three roles stay unaligned by
      // design.
      @common.DesignPreset::Fluent => 3
    }
    let expected_source_gap = match preset {
      @common.DesignPreset::Fluent => 0
      _ => expected_gap
    }
    assert_true(semantic_palette_role_gap_count(preset) == expected_gap)
    assert_true(
      semantic_palette_role_source_gap_count(preset) == expected_source_gap,
    )
    assert_true(
      semantic_palette_role_official_parity_gap_count(preset) == expected_gap,
    )
    assert_true(primary.official_token_count > 0)
    assert_true(primary.source_imported_count > 0)
    assert_true(primary.runtime_aligned_count > 0)
    guard semantic_palette_role_for(
        preset,
        DesignSemanticPaletteRole::PaletteFocus,
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
    let rows = typography_role_report(preset, scheme=@core.ColorScheme::Light)
    assert_true(rows.length() == 4)
    assert_true(typography_role_count(preset) == 4)
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
      assert_true(item.status != DesignTokenStatus::NotMapped)
    }
    guard typography_role_for(preset, DesignTypographyRole::TypographyBody)
      is Some(body) else {
      fail("expected body typography role")
    }
    assert_true(body.token_surface == "DesignTypographyTokens.body")
    assert_true(body.core_surface == "@core.TypographyScale.body")
    guard typography_role_for(preset, DesignTypographyRole::TypographyTitle)
      is Some(title) else {
      fail("expected title typography role")
    }
    assert_true(title.token_surface == "DesignTypographyTokens.title")
    guard requirement_audit_for(preset, DesignSystemRequirement::Typography)
      is Some(typography_audit) else {
      fail("expected typography requirement audit")
    }
    assert_true(typography_audit.evidence.contains("typography role records"))
    assert_true(typography_audit.status == DesignTokenStatus::PreviewMapped)
    if preset == @common.DesignPreset::Material ||
      preset == @common.DesignPreset::Carbon ||
      preset == @common.DesignPreset::Primer {
      assert_true(typography_role_gap_count(preset) == 0)
      assert_true(typography_role_source_gap_count(preset) == 0)
      assert_true(typography_role_destination_gap_count(preset) == 0)
      assert_true(typography_role_official_parity_gap_count(preset) == 0)
    } else {
      assert_true(typography_role_gap_count(preset) > 0)
      assert_true(typography_role_official_parity_gap_count(preset) > 0)
    }
  }
  guard typography_role_for(
      @common.DesignPreset::Material,
      DesignTypographyRole::TypographyBody,
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
  guard typography_role_for(
      @common.DesignPreset::Carbon,
      DesignTypographyRole::TypographyBody,
    )
    is Some(carbon_body) else {
    fail("expected Carbon body typography role")
  }
  assert_true(carbon_body.official_token == "$body-02")
  assert_true(carbon_body.official_token_count == 1)
  assert_true(carbon_body.source_imported_count == 1)
  assert_true(carbon_body.runtime_aligned_count == 1)
  assert_true(carbon_body.remaining_gap == "none")
  guard typography_role_for(
      @common.DesignPreset::Primer,
      DesignTypographyRole::TypographyBody,
    )
    is Some(primer_body) else {
    fail("expected Primer body typography role")
  }
  assert_true(primer_body.official_token_count >= 2)
  assert_true(primer_body.source_imported_count >= 2)
  assert_true(primer_body.runtime_aligned_count >= 2)
  assert_true(primer_body.remaining_gap == "none")
  guard typography_role_for(
      @common.DesignPreset::Fluent,
      DesignTypographyRole::TypographyBody,
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
    let report = design_system_report(
      preset,
      scheme=@core.ColorScheme::Dark,
      system_scheme=@core.ColorScheme::Dark,
      density=@common.DesignDensity::Compact,
    )
    assert_true(report.preset == preset)
    assert_true(report.scheme == @core.ColorScheme::Dark)
    assert_true(report.system_scheme == @core.ColorScheme::Dark)
    assert_true(report.density == @common.DesignDensity::Compact)
    assert_true(report.manifest == manifest(preset))
    assert_true(report.complete == is_design_system_complete(preset))
    assert_true(report.gap_count() == requirement_gap_count(preset))
    assert_true(report.sources.length() == sources(preset).length())
    assert_true(
      report.requirement_audit.length() == requirement_audit(preset).length(),
    )
    assert_true(report.token_taxonomy.length() == token_taxonomy_count(preset))
    assert_true(report.taxonomy_gap_count() == token_taxonomy_gap_count(preset))
    assert_true(
      report.semantic_palette_roles.length() ==
      semantic_palette_role_count(preset),
    )
    assert_true(
      report.semantic_palette_gap_count() ==
      semantic_palette_role_official_parity_gap_count(preset),
    )
    assert_true(
      report.typography_roles.length() == typography_role_count(preset),
    )
    assert_true(
      report.typography_gap_count() ==
      typography_role_official_parity_gap_count(preset),
    )
    assert_true(
      report.source_locks.length() == source_lock_report(preset).length(),
    )
    assert_true(
      report.source_packages.length() == source_package_inventory_count(preset),
    )
    assert_true(
      report.source_imports.length() == source_imported_token_count(preset),
    )
    assert_true(
      report.source_import_coverage.length() ==
      source_import_coverage_count(preset),
    )
    assert_true(
      report.source_import_integrity.length() ==
      source_import_integrity_report(preset).length(),
    )
    assert_true(
      report.runtime_alignment.length() == runtime_token_alignment_count(preset),
    )
    assert_true(
      report.token_group_resolvers.length() ==
      token_group_resolver_count(preset),
    )
    assert_true(
      report.density_resolvers.length() == density_resolver_count(preset),
    )
    assert_true(
      report.variant_resolvers.length() == variant_resolver_count(preset),
    )
    assert_true(
      report.customization.length() == customization_report_count(preset),
    )
    assert_true(
      report.official_token_coverage.length() ==
      official_token_anchor_count(preset),
    )
    assert_true(
      report.official_token_source_usage.length() == sources(preset).length(),
    )
    assert_true(
      report.component_token_matrix.length() ==
      component_token_matrix_count(preset),
    )
    assert_true(
      report.component_style_resolvers.length() ==
      component_style_resolver_count(preset),
    )
    assert_true(report.adaptation.length() == adaptation_record_count(preset))
    assert_true(
      report.golden_mappings.length() == golden_mappings(preset).length(),
    )
    assert_true(
      report.unanchored_golden_mappings.length() ==
      unanchored_golden_mapping_count(preset),
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
      assert_true(report.status == DesignTokenStatus::OfficialComplete)
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
    let rows = component_token_matrix(preset)
    assert_true(rows.length() == 11)
    assert_true(component_token_matrix_count(preset) == 11)
    assert_true(component_token_matrix_mapped_count(preset) > 0)
    assert_true(component_token_matrix_source_imported_count(preset) > 0)
    assert_true(component_token_matrix_runtime_aligned_count(preset) > 0)
    assert_true(
      component_token_matrix_required_count(preset) >
      component_token_matrix_mapped_count(preset),
    )
    assert_true(component_token_matrix_gap_count(preset) > 0)
    assert_true(component_token_matrix_source_gap_count(preset) == 0)
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
  guard component_token_matrix_for(@common.DesignPreset::Material, "Button")
    is Some(material_button) else {
    fail("expected Material button matrix")
  }
  assert_true(material_button.mapped_token_count == 3)
  assert_true(material_button.source_imported_token_count == 3)
  assert_true(material_button.runtime_aligned_token_count == 3)
  assert_true(
    material_button.required_token_count > material_button.mapped_token_count,
  )
  guard component_token_matrix_for(@common.DesignPreset::Material, "TextField")
    is Some(material_text_field) else {
    fail("expected Material text-field matrix")
  }
  assert_true(material_text_field.source_imported_token_count == 0)
  assert_true(material_text_field.runtime_aligned_token_count == 0)
  guard component_token_matrix_for(@common.DesignPreset::Carbon, "Feedback")
    is Some(carbon_feedback) else {
    fail("expected Carbon feedback matrix")
  }
  assert_true(carbon_feedback.mapped_token_count == 2)
  assert_true(carbon_feedback.source_imported_token_count >= 4)
  assert_true(carbon_feedback.runtime_aligned_token_count >= 3)
  guard component_token_matrix_for(@common.DesignPreset::Carbon, "TextField")
    is Some(carbon_text_field) else {
    fail("expected Carbon text-field matrix")
  }
  assert_true(carbon_text_field.source_imported_token_count == 2)
  assert_true(carbon_text_field.runtime_aligned_token_count == 2)
  guard component_token_matrix_for(@common.DesignPreset::Primer, "Button")
    is Some(primer_button) else {
    fail("expected Primer button matrix")
  }
  assert_true(primer_button.source_imported_token_count == 1)
  assert_true(primer_button.runtime_aligned_token_count == 0)
  guard component_token_matrix_for(@common.DesignPreset::Primer, "Picker")
    is Some(primer_picker) else {
    fail("expected Primer picker matrix")
  }
  inspect(primer_picker.moui_surface, content="@views.PickerStyle")
  assert_true(primer_picker.source_imported_token_count >= 3)
  assert_true(primer_picker.runtime_aligned_token_count >= 1)
  guard component_token_matrix_for(@common.DesignPreset::Fluent, "DatePicker")
    is Some(fluent_date_picker) else {
    fail("expected Fluent date-picker matrix")
  }
  assert_true(fluent_date_picker.status == DesignTokenStatus::PreviewMapped)
  guard component_token_matrix_for(@common.DesignPreset::Fluent, "Picker")
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
    let rows = component_style_resolver_report(
      preset,
      scheme=@core.ColorScheme::Light,
    )
    assert_true(rows.length() == 11)
    assert_true(component_style_resolver_count(preset) == 11)
    assert_true(component_style_resolver_gap_count(preset) == 0)
    assert_true(component_style_resolver_source_gap_count(preset) == 0)
    assert_true(
      component_style_resolver_official_parity_gap_count(preset) == 11,
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
      assert_true(item.status == DesignTokenStatus::ComponentMapped)
    }
  }
  guard component_style_resolver_for(@common.DesignPreset::Material, "Button")
    is Some(material_button) else {
    fail("expected Material button style resolver")
  }
  assert_true(material_button.core_style_surface == "@views.ButtonStyle")
  assert_true(material_button.style_api.contains("core_component_styles"))
  assert_true(material_button.remaining_gap.contains("state layers"))
  guard component_style_resolver_for(@common.DesignPreset::Carbon, "Feedback")
    is Some(carbon_feedback) else {
    fail("expected Carbon feedback style resolver")
  }
  assert_true(carbon_feedback.style_api.contains("DesignFeedbackTokens"))
  assert_true(carbon_feedback.core_style_surface == "@views.FeedbackStyle")
  guard component_style_resolver_for(@common.DesignPreset::Primer, "Picker")
    is Some(primer_picker) else {
    fail("expected Primer picker style resolver")
  }
  assert_true(primer_picker.core_style_surface == "@views.PickerStyle")
  assert_true(primer_picker.token_surface.contains("picker"))
  guard component_style_resolver_for(@common.DesignPreset::Fluent, "DatePicker")
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
    let records = adaptation_report(preset)
    assert_true(records.length() >= 7)
    assert_true(aligned_adaptation_count(preset) > 0)
    assert_true(adaptation_gap_count(preset) > 0)
    assert_true(adaptation_source_lock_gap_count(preset) == 0)
    assert_true(undeclared_adaptation_source_count(preset) == 0)
    assert_false(records.any(item => item.moui_surface.contains("moui/views")))
    assert_true(
      records.any(item => item.kind == DesignAdaptationKind::CollapsedRoleMatrix),
    )
    assert_true(
      records.any(item => {
        item.kind == DesignAdaptationKind::CustomizableOverride &&
        item.status == DesignTokenStatus::ThemeMapped
      }),
    )
    for item in records {
      assert_true(item.source_declared)
      assert_true(item.source_locked)
      assert_true(item.source_ref != "")
      assert_true(item.remaining_gap != "")
    }
  }
  guard adaptation_report_for(
      @common.DesignPreset::Material,
      "Material dynamic color generation",
    )
    is Some(material_dynamic) else {
    fail("expected Material dynamic color adaptation")
  }
  assert_true(material_dynamic.status == DesignTokenStatus::SourceMapped)
  assert_true(
    material_dynamic.kind == DesignAdaptationKind::PendingOfficialImport,
  )
  guard adaptation_report_for(
      @common.DesignPreset::Carbon,
      "Carbon white/g10/g90/g100 themes",
    )
    is Some(carbon_themes) else {
    fail("expected Carbon theme adaptation")
  }
  assert_true(carbon_themes.status == DesignTokenStatus::PreviewMapped)
  guard adaptation_report_for(
      @common.DesignPreset::Primer,
      "Primer color modes and accessibility themes",
    )
    is Some(primer_modes) else {
    fail("expected Primer mode adaptation")
  }
  assert_true(primer_modes.kind == DesignAdaptationKind::CollapsedRoleMatrix)
  guard adaptation_report_for(
      @common.DesignPreset::Primer,
      "Primer typography primitives",
    )
    is Some(primer_typography) else {
    fail("expected Primer typography adaptation")
  }
  assert_true(primer_typography.status == DesignTokenStatus::PreviewMapped)
  assert_true(
    primer_typography.remaining_gap.contains("line-height") &&
    primer_typography.remaining_gap.contains("title weight"),
  )
  guard adaptation_report_for(
      @common.DesignPreset::Fluent,
      "Fluent light/dark/high contrast themes",
    )
    is Some(fluent_variants) else {
    fail("expected Fluent variant adaptation")
  }
  assert_true(fluent_variants.status == DesignTokenStatus::ThemeMapped)
  guard adaptation_report_for(@common.DesignPreset::Fluent, "Fluent type ramp")
    is Some(fluent_typography) else {
    fail("expected Fluent typography adaptation")
  }
  assert_true(fluent_typography.status == DesignTokenStatus::PreviewMapped)
  assert_true(
    fluent_typography.difference.contains("full Fluent global font file") &&
    fluent_typography.remaining_gap.contains("line-height") &&
    fluent_typography.remaining_gap.contains("font-family"),
  )
  guard adaptation_report_for(
      @common.DesignPreset::Fluent,
      "Fluent spacing scales",
    )
    is Some(fluent_spacing) else {
    fail("expected Fluent spacing adaptation")
  }
  assert_true(fluent_spacing.status == DesignTokenStatus::PreviewMapped)
  assert_true(
    fluent_spacing.difference.contains("horizontal and vertical spacing") &&
    fluent_spacing.remaining_gap.contains("axis-specific"),
  )
  guard adaptation_report_for(
      @common.DesignPreset::Fluent,
      "Fluent border radius scale",
    )
    is Some(fluent_radius) else {
    fail("expected Fluent radius adaptation")
  }
  assert_true(fluent_radius.status == DesignTokenStatus::PreviewMapped)
  assert_true(
    fluent_radius.difference.contains("full Fluent global border-radius scale") &&
    fluent_radius.remaining_gap.contains("extended radius"),
  )
  guard adaptation_report_for(
      @common.DesignPreset::Fluent,
      "Fluent shadow and stroke depth",
    )
    is Some(fluent_depth) else {
    fail("expected Fluent depth adaptation")
  }
  assert_true(fluent_depth.status == DesignTokenStatus::PreviewMapped)
  assert_true(
    fluent_depth.difference.contains("global stroke widths") &&
    fluent_depth.remaining_gap.contains("shadow/depth") &&
    fluent_depth.remaining_gap.contains("stroke-width scale"),
  )
}

///|
