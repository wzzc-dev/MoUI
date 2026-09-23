///|
test "source manifests keep preview presets from claiming full official coverage" {
  let material = @audit.manifest(Material)
  assert_true(material.stage == PreviewMapped)
  assert_true(
    material.token_coverage.any(item => {
      item.category == StateLayer && item.status == ComponentMapped
    }),
  )
  assert_true(
    material.component_coverage.any(item => {
      item.component == "Progress" &&
      item.status == ComponentMapped &&
      item.moui_surface == "@views.ProgressStyle"
    }),
  )
  assert_true(
    material.component_coverage.any(item => {
      item.component == "Slider" &&
      item.status == ComponentMapped &&
      item.moui_surface == "@views.SliderStyle"
    }),
  )
  assert_true(
    material.component_coverage.any(item => {
      item.component == "Picker" &&
      item.status == ComponentMapped &&
      item.moui_surface == "@views.PickerStyle"
    }),
  )
  assert_true(
    material.component_coverage.any(item => {
      item.component == "DatePicker" &&
      item.status == ComponentMapped &&
      item.moui_surface == "@views.PickerStyle"
    }),
  )
  assert_true(
    material.component_coverage.any(item => {
      item.component == "Feedback" &&
      item.status == ComponentMapped &&
      item.moui_surface == "@views.FeedbackStyle"
    }),
  )
  assert_true(
    material.component_coverage.any(item => {
      item.component == "Badge" &&
      item.status == ComponentMapped &&
      item.moui_surface == "@views.BadgeStyle"
    }),
  )
  assert_true(
    material.component_coverage.any(item => {
      item.component == "FormValidation" &&
      item.status == ComponentMapped &&
      item.moui_surface == "@views.FormValidationStyle"
    }),
  )
}

///|
test "customization coverage advertises inheritance and token override APIs" {
  let manifest = @audit.manifest(Carbon)
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
      item.status == ThemeMapped
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
      item.status == ComponentMapped
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
  for preset in [@common.DesignPreset::Material, Carbon, Primer, Fluent] {
    let report = @audit.customization_report(preset)
    assert_true(
      report.length() == @audit.manifest(preset).customization_coverage.length(),
    )
    assert_true(@audit.customization_report_count(preset) == 6)
    assert_true(@audit.customization_capability_gap_count(preset) == 0)
    assert_true(@audit.customization_official_parity_gap_count(preset) == 6)
    for item in report {
      assert_true(item.api_surface != "")
      assert_true(item.token_surface != "")
      assert_true(item.status != NotMapped)
      assert_true(
        @audit.manifest(preset).customization_coverage.any(coverage => {
          coverage.capability == item.capability &&
          coverage.api_surface == item.api_surface
        }),
      )
    }
  }
  guard @audit.customization_report_for(Material, "Design token group override")
    is Some(group_override) else {
    fail("expected design-token group override capability")
  }
  assert_true(group_override.kind == DesignTokenGroupOverride)
  assert_true(group_override.inherits_base)
  assert_true(group_override.supports_override)
  assert_true(group_override.recomputes_dependents)
  assert_true(group_override.remaining_gap.contains("Official per-system"))
  guard @audit.customization_report_for(Primer, "Component token override")
    is Some(component_override) else {
    fail("expected component token override capability")
  }
  assert_true(component_override.kind == ComponentTokenOverride)
  assert_true(component_override.status == ComponentMapped)
  assert_true(component_override.token_surface == "DesignComponentTokens")
  guard @audit.customization_report_for(Fluent, "Variant Theme resolver")
    is Some(variant_theme) else {
    fail("expected variant theme resolver capability")
  }
  assert_true(variant_theme.kind == VariantThemeResolution)
  assert_true(variant_theme.recomputes_dependents)
  assert_false(variant_theme.supports_override)
}

///|
test "requirement audits expose objective level gaps without claiming completion" {
  for preset in [@common.DesignPreset::Material, Carbon, Primer, Fluent] {
    let audit = @audit.requirement_audit(preset)
    assert_true(audit.length() >= 20)
    assert_false(@audit.is_design_system_complete(preset))
    assert_true(@audit.requirement_gap_count(preset) > 0)
    guard @audit.requirement_audit_for(preset, OfficialSources) is Some(sources) else {
      fail("expected official sources audit")
    }
    assert_true(sources.status == SourceMapped)
    assert_true(sources.evidence.contains("source anchors"))
    guard @audit.requirement_audit_for(preset, SourceVersionLocks)
      is Some(source_versions) else {
      fail("expected source version lock audit")
    }
    assert_true(source_versions.status == PreviewMapped)
    assert_true(source_versions.evidence.contains("stable source locks"))
    assert_true(
      source_versions.remaining_gap.contains("Live official documentation"),
    )
    guard @audit.requirement_audit_for(preset, SourcePackageInventory)
      is Some(source_packages) else {
      fail("expected source package inventory audit")
    }
    assert_true(source_packages.status == PreviewMapped)
    assert_true(source_packages.evidence.contains("source package rows"))
    assert_true(source_packages.evidence.contains("imported tokens"))
    assert_true(source_packages.evidence.contains("source-import records"))
    guard @audit.requirement_audit_for(preset, SourceImportedTokens)
      is Some(source_imports) else {
      fail("expected source-imported token audit")
    }
    assert_true(source_imports.status == SourceMapped)
    assert_true(source_imports.evidence.contains("official anchors"))
    assert_true(source_imports.evidence.contains("import coverage gaps"))
    assert_true(source_imports.evidence.contains("integrity gaps"))
    for
      requirement in [
        @audit.DesignSystemRequirement::SemanticPalette,
        Typography,
        ShapeRadius,
        ElevationShadow,
        Motion,
        Surface,
        StateLayer,
      ] {
      guard @audit.requirement_audit_for(preset, requirement)
        is Some(token_group) else {
        fail("expected token-group audit")
      }
      assert_true(token_group.status != NotMapped)
      assert_true(token_group.evidence.contains("token-group resolver records"))
      assert_true(token_group.evidence.contains("source-lock gaps"))
      assert_true(token_group.evidence.contains("official parity gaps"))
    }
    guard @audit.requirement_audit_for(preset, SpacingDensity)
      is Some(spacing_density) else {
      fail("expected spacing density audit")
    }
    assert_true(spacing_density.status == PreviewMapped)
    assert_true(spacing_density.evidence.contains("density resolver records"))
    assert_true(spacing_density.evidence.contains("source-lock gaps"))
    assert_true(spacing_density.evidence.contains("official parity gaps"))
    guard @audit.requirement_audit_for(preset, SchemeVariants)
      is Some(scheme_variants) else {
      fail("expected scheme variant audit")
    }
    assert_true(scheme_variants.status == PreviewMapped)
    assert_true(scheme_variants.evidence.contains("variant resolver records"))
    assert_true(scheme_variants.evidence.contains("source-lock gaps"))
    assert_true(scheme_variants.evidence.contains("official parity gaps"))
    guard @audit.requirement_audit_for(preset, RuntimeTokenAlignment)
      is Some(runtime_alignment) else {
      fail("expected runtime token alignment audit")
    }
    assert_true(runtime_alignment.status == PreviewMapped)
    assert_true(runtime_alignment.evidence.contains("runtime token rows"))
    assert_true(runtime_alignment.evidence.contains("alignment gaps"))
    guard @audit.requirement_audit_for(preset, Customization)
      is Some(customization) else {
      fail("expected customization audit")
    }
    assert_true(customization.status == ComponentMapped)
    assert_true(
      customization.evidence.contains("customization capability records"),
    )
    assert_true(customization.evidence.contains("official parity gaps"))
    guard @audit.requirement_audit_for(preset, ComponentTokens)
      is Some(components) else {
      fail("expected component token audit")
    }
    assert_true(components.status == ComponentMapped)
    assert_true(components.evidence.contains("component token surfaces"))
    assert_true(
      components.evidence.contains("component style resolver records"),
    )
    assert_true(components.evidence.contains("source-lock gaps"))
    assert_true(components.evidence.contains("official parity gaps"))
    guard @audit.requirement_audit_for(preset, ComponentMatrix)
      is Some(component_matrix) else {
      fail("expected component matrix audit")
    }
    assert_true(component_matrix.status == PreviewMapped)
    assert_true(component_matrix.evidence.contains("component matrix rows"))
    guard @audit.requirement_audit_for(preset, OfficialTokenCoverage)
      is Some(official_tokens) else {
      fail("expected official token coverage audit")
    }
    assert_true(official_tokens.status == PreviewMapped)
    assert_true(official_tokens.evidence.contains("official token anchors"))
    guard @audit.requirement_audit_for(preset, GoldenMappings) is Some(golden) else {
      fail("expected golden mapping audit")
    }
    assert_true(golden.status == PreviewMapped)
    assert_true(golden.remaining_gap != "none")
    guard @audit.requirement_audit_for(preset, AdaptationDifferences)
      is Some(adaptation) else {
      fail("expected adaptation differences audit")
    }
    assert_true(adaptation.status == PreviewMapped)
    assert_true(adaptation.evidence.contains("adaptation records"))
  }
}

///|
test "token taxonomy reports tie required categories to source locked neutral surfaces" {
  for preset in [@common.DesignPreset::Material, Carbon, Primer, Fluent] {
    let rows = @audit.token_taxonomy_report(preset)
    assert_true(rows.length() == 10)
    assert_true(@audit.token_taxonomy_count(preset) == 10)
    assert_true(@audit.token_taxonomy_required_count(preset) == 10)
    assert_true(@audit.token_taxonomy_mapped_count(preset) == 10)
    assert_true(@audit.token_taxonomy_gap_count(preset) == 0)
    assert_true(@audit.token_taxonomy_source_gap_count(preset) == 0)
    if preset == Material {
      assert_true(@audit.token_taxonomy_official_parity_gap_count(preset) == 10)
    } else {
      assert_true(@audit.token_taxonomy_official_parity_gap_count(preset) == 8)
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
      assert_true(item.status != NotMapped)
    }
    guard @audit.token_taxonomy_for(preset, Color) is Some(color) else {
      fail("expected color taxonomy row")
    }
    assert_true(color.token_surface.contains("DesignSemanticPalette"))
    assert_true(color.moui_surface.contains("@core."))
    guard @audit.token_taxonomy_for(preset, Density) is Some(density) else {
      fail("expected density taxonomy row")
    }
    assert_true(density.token_surface.contains("DesignDensity"))
    assert_true(density.moui_surface.contains("@core.SpacingScale"))
    guard @audit.token_taxonomy_for(preset, StateLayer) is Some(state_layer) else {
      fail("expected state-layer taxonomy row")
    }
    assert_true(state_layer.token_surface.contains("DesignStateLayerTokens"))
    assert_true(state_layer.status == ComponentMapped)
    guard @audit.token_taxonomy_for(preset, ComponentStyle) is Some(component) else {
      fail("expected component-style taxonomy row")
    }
    assert_true(component.token_surface.contains("DesignComponentTokens"))
    assert_true(component.status == ComponentMapped)
  }
}

///|
test "semantic palette role reports expose role-level source and core alignment gaps" {
  for preset in [@common.DesignPreset::Material, Carbon, Primer, Fluent] {
    let rows = @audit.semantic_palette_role_report(preset, scheme=Light)
    assert_true(rows.length() == 14)
    assert_true(@audit.semantic_palette_role_count(preset) == 14)
    assert_true(@audit.semantic_palette_role_mapped_count(preset) > 0)
    assert_true(@audit.semantic_palette_role_aligned_count(preset) > 0)
    for item in rows {
      assert_true(item.required)
      assert_true(item.token_surface.contains("DesignSemanticPalette"))
      assert_true(item.core_surface.contains("@core."))
      assert_true(item.token_value == item.core_value)
      assert_true(item.resolves_core_surface)
      assert_true(item.status != NotMapped)
    }
    guard @audit.semantic_palette_role_for(preset, PalettePrimary)
      is Some(primary) else {
      fail("expected primary semantic palette role")
    }
    assert_true(primary.token_surface == "DesignSemanticPalette.primary")
    assert_true(primary.core_surface == "@core.ColorPalette.primary")
    assert_true(primary.source_declared)
    assert_true(primary.source_locked)
    let expected_gap = match preset {
      Material => 4
      Carbon => 0
      Primer => 0
      // Fluent 2 maps warning/danger/info to status-background tokens
      // (#8a5400/#b10f0e/#0f6cbd) that differ from the pinned Fluent global
      // color primaries (orange/red/blue), so three roles stay unaligned by
      // design.
      Fluent => 3
    }
    let expected_source_gap = match preset {
      Fluent => 0
      _ => expected_gap
    }
    assert_true(@audit.semantic_palette_role_gap_count(preset) == expected_gap)
    assert_true(
      @audit.semantic_palette_role_source_gap_count(preset) ==
      expected_source_gap,
    )
    assert_true(
      @audit.semantic_palette_role_official_parity_gap_count(preset) ==
      expected_gap,
    )
    assert_true(primary.official_token_count > 0)
    assert_true(primary.source_imported_count > 0)
    assert_true(primary.runtime_aligned_count > 0)
    guard @audit.semantic_palette_role_for(preset, PaletteFocus) is Some(focus) else {
      fail("expected focus semantic palette role")
    }
    assert_true(focus.token_surface == "DesignSemanticPalette.focus")
    assert_true(focus.core_surface == "@core.SemanticColorScale.focus")
    if preset == Carbon {
      assert_true(focus.remaining_gap == "none")
      assert_true(focus.runtime_aligned_count > 0)
    } else if preset == Primer || preset == Fluent {
      assert_true(focus.remaining_gap == "none")
      assert_true(focus.runtime_aligned_count > 0)
    } else {
      assert_true(focus.remaining_gap != "none")
    }
  }
}

///|
test "typography role reports expose role-level source and neutral typography gaps" {
  for preset in [@common.DesignPreset::Material, Carbon, Primer, Fluent] {
    let rows = @audit.typography_role_report(preset, scheme=Light)
    assert_true(rows.length() == 4)
    assert_true(@audit.typography_role_count(preset) == 4)
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
      assert_true(item.status != NotMapped)
    }
    guard @audit.typography_role_for(preset, TypographyBody) is Some(body) else {
      fail("expected body typography role")
    }
    assert_true(body.token_surface == "DesignTypographyTokens.body")
    assert_true(body.core_surface == "@core.TypographyScale.body")
    guard @audit.typography_role_for(preset, TypographyTitle) is Some(title) else {
      fail("expected title typography role")
    }
    assert_true(title.token_surface == "DesignTypographyTokens.title")
    guard @audit.requirement_audit_for(preset, Typography)
      is Some(typography_audit) else {
      fail("expected typography requirement audit")
    }
    assert_true(typography_audit.evidence.contains("typography role records"))
    assert_true(typography_audit.status == PreviewMapped)
    if preset == Material || preset == Carbon || preset == Primer {
      assert_true(@audit.typography_role_gap_count(preset) == 0)
      assert_true(@audit.typography_role_source_gap_count(preset) == 0)
      assert_true(@audit.typography_role_destination_gap_count(preset) == 0)
      assert_true(@audit.typography_role_official_parity_gap_count(preset) == 0)
    } else {
      assert_true(@audit.typography_role_gap_count(preset) > 0)
      assert_true(@audit.typography_role_official_parity_gap_count(preset) > 0)
    }
  }
  guard @audit.typography_role_for(Material, TypographyBody)
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
  guard @audit.typography_role_for(Carbon, TypographyBody) is Some(carbon_body) else {
    fail("expected Carbon body typography role")
  }
  assert_true(carbon_body.official_token == "$body-02")
  assert_true(carbon_body.official_token_count == 1)
  assert_true(carbon_body.source_imported_count == 1)
  assert_true(carbon_body.runtime_aligned_count == 1)
  assert_true(carbon_body.remaining_gap == "none")
  guard @audit.typography_role_for(Primer, TypographyBody) is Some(primer_body) else {
    fail("expected Primer body typography role")
  }
  assert_true(primer_body.official_token_count >= 2)
  assert_true(primer_body.source_imported_count >= 2)
  assert_true(primer_body.runtime_aligned_count >= 2)
  assert_true(primer_body.remaining_gap == "none")
  guard @audit.typography_role_for(Fluent, TypographyBody) is Some(fluent_body) else {
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
  for preset in [@common.DesignPreset::Material, Carbon, Primer, Fluent] {
    let report = @audit.design_system_report(
      preset,
      scheme=Dark,
      system_scheme=Dark,
      density=Compact,
    )
    assert_true(report.preset == preset)
    assert_true(report.scheme == Dark)
    assert_true(report.system_scheme == Dark)
    assert_true(report.density == Compact)
    assert_true(report.manifest == @audit.manifest(preset))
    assert_true(report.complete == @audit.is_design_system_complete(preset))
    assert_true(report.gap_count() == @audit.requirement_gap_count(preset))
    assert_true(report.sources.length() == @audit.sources(preset).length())
    assert_true(
      report.requirement_audit.length() ==
      @audit.requirement_audit(preset).length(),
    )
    assert_true(
      report.token_taxonomy.length() == @audit.token_taxonomy_count(preset),
    )
    assert_true(
      report.taxonomy_gap_count() == @audit.token_taxonomy_gap_count(preset),
    )
    assert_true(
      report.semantic_palette_roles.length() ==
      @audit.semantic_palette_role_count(preset),
    )
    assert_true(
      report.semantic_palette_gap_count() ==
      @audit.semantic_palette_role_official_parity_gap_count(preset),
    )
    assert_true(
      report.typography_roles.length() == @audit.typography_role_count(preset),
    )
    assert_true(
      report.typography_gap_count() ==
      @audit.typography_role_official_parity_gap_count(preset),
    )
    assert_true(
      report.source_locks.length() == @audit.source_lock_report(preset).length(),
    )
    assert_true(
      report.source_packages.length() ==
      @audit.source_package_inventory_count(preset),
    )
    assert_true(
      report.source_imports.length() ==
      @audit.source_imported_token_count(preset),
    )
    assert_true(
      report.source_import_coverage.length() ==
      @audit.source_import_coverage_count(preset),
    )
    assert_true(
      report.source_import_integrity.length() ==
      @audit.source_import_integrity_report(preset).length(),
    )
    assert_true(
      report.runtime_alignment.length() ==
      @audit.runtime_token_alignment_count(preset),
    )
    assert_true(
      report.token_group_resolvers.length() ==
      @audit.token_group_resolver_count(preset),
    )
    assert_true(
      report.density_resolvers.length() == @audit.density_resolver_count(preset),
    )
    assert_true(
      report.variant_resolvers.length() == @audit.variant_resolver_count(preset),
    )
    assert_true(
      report.customization.length() == @audit.customization_report_count(preset),
    )
    assert_true(
      report.official_token_coverage.length() ==
      @audit.official_token_anchor_count(preset),
    )
    assert_true(
      report.official_token_source_usage.length() ==
      @audit.sources(preset).length(),
    )
    assert_true(
      report.component_token_matrix.length() ==
      @audit.component_token_matrix_count(preset),
    )
    assert_true(
      report.component_style_resolvers.length() ==
      @audit.component_style_resolver_count(preset),
    )
    assert_true(
      report.adaptation.length() == @audit.adaptation_record_count(preset),
    )
    assert_true(
      report.golden_mappings.length() == @audit.golden_mappings(preset).length(),
    )
    assert_true(
      report.unanchored_golden_mappings.length() ==
      @audit.unanchored_golden_mapping_count(preset),
    )
    assert_true(report.evidence_row_count() > report.requirement_audit.length())
    for item in report.token_group_resolvers {
      assert_true(item.scheme == Dark)
    }
    for item in report.density_resolvers {
      assert_true(item.scheme == Dark)
    }
    for item in report.component_style_resolvers {
      assert_true(item.scheme == Dark)
    }
    for item in report.variant_resolvers {
      assert_true(item.system_scheme == Dark)
      assert_true(item.density == Compact)
    }
    if report.complete {
      assert_true(report.status == OfficialComplete)
    } else {
      assert_true(report.status == report.manifest.stage)
    }
    assert_false(report.has_official_completion_claim())
    assert_true(report.note.contains("source-mapped preview"))
  }
}

///|
test "component token matrices expose source locked official component gaps" {
  for preset in [@common.DesignPreset::Material, Carbon, Primer, Fluent] {
    let rows = @audit.component_token_matrix(preset)
    assert_true(rows.length() == 11)
    assert_true(@audit.component_token_matrix_count(preset) == 11)
    assert_true(@audit.component_token_matrix_mapped_count(preset) > 0)
    assert_true(@audit.component_token_matrix_source_imported_count(preset) > 0)
    assert_true(@audit.component_token_matrix_runtime_aligned_count(preset) > 0)
    assert_true(
      @audit.component_token_matrix_required_count(preset) >
      @audit.component_token_matrix_mapped_count(preset),
    )
    assert_true(@audit.component_token_matrix_gap_count(preset) > 0)
    assert_true(@audit.component_token_matrix_source_gap_count(preset) == 0)
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
  guard @audit.component_token_matrix_for(Material, "Button")
    is Some(material_button) else {
    fail("expected Material button matrix")
  }
  assert_true(material_button.mapped_token_count == 3)
  assert_true(material_button.source_imported_token_count == 3)
  assert_true(material_button.runtime_aligned_token_count == 3)
  assert_true(
    material_button.required_token_count > material_button.mapped_token_count,
  )
  guard @audit.component_token_matrix_for(Material, "TextField")
    is Some(material_text_field) else {
    fail("expected Material text-field matrix")
  }
  assert_true(material_text_field.source_imported_token_count == 0)
  assert_true(material_text_field.runtime_aligned_token_count == 0)
  guard @audit.component_token_matrix_for(Carbon, "Feedback")
    is Some(carbon_feedback) else {
    fail("expected Carbon feedback matrix")
  }
  assert_true(carbon_feedback.mapped_token_count == 2)
  assert_true(carbon_feedback.source_imported_token_count >= 4)
  assert_true(carbon_feedback.runtime_aligned_token_count >= 3)
  guard @audit.component_token_matrix_for(Carbon, "TextField")
    is Some(carbon_text_field) else {
    fail("expected Carbon text-field matrix")
  }
  assert_true(carbon_text_field.source_imported_token_count == 2)
  assert_true(carbon_text_field.runtime_aligned_token_count == 2)
  guard @audit.component_token_matrix_for(Primer, "Button")
    is Some(primer_button) else {
    fail("expected Primer button matrix")
  }
  assert_true(primer_button.source_imported_token_count == 1)
  assert_true(primer_button.runtime_aligned_token_count == 0)
  guard @audit.component_token_matrix_for(Primer, "Picker")
    is Some(primer_picker) else {
    fail("expected Primer picker matrix")
  }
  inspect(primer_picker.moui_surface, content="@views.PickerStyle")
  assert_true(primer_picker.source_imported_token_count >= 3)
  assert_true(primer_picker.runtime_aligned_token_count >= 1)
  guard @audit.component_token_matrix_for(Fluent, "DatePicker")
    is Some(fluent_date_picker) else {
    fail("expected Fluent date-picker matrix")
  }
  assert_true(fluent_date_picker.status == PreviewMapped)
  guard @audit.component_token_matrix_for(Fluent, "Picker")
    is Some(fluent_picker) else {
    fail("expected Fluent picker matrix")
  }
  assert_true(fluent_picker.source_imported_token_count == 1)
  assert_true(fluent_picker.runtime_aligned_token_count == 1)
}

///|
test "component style resolver reports tie component tokens to neutral core styles" {
  for preset in [@common.DesignPreset::Material, Carbon, Primer, Fluent] {
    let rows = @audit.component_style_resolver_report(preset, scheme=Light)
    assert_true(rows.length() == 11)
    assert_true(@audit.component_style_resolver_count(preset) == 11)
    assert_true(@audit.component_style_resolver_gap_count(preset) == 0)
    assert_true(@audit.component_style_resolver_source_gap_count(preset) == 0)
    assert_true(
      @audit.component_style_resolver_official_parity_gap_count(preset) == 11,
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
      assert_true(item.status == ComponentMapped)
    }
  }
  guard @audit.component_style_resolver_for(Material, "Button")
    is Some(material_button) else {
    fail("expected Material button style resolver")
  }
  assert_true(material_button.core_style_surface == "@views.ButtonStyle")
  assert_true(material_button.style_api.contains("core_component_styles"))
  assert_true(material_button.remaining_gap.contains("state layers"))
  guard @audit.component_style_resolver_for(Carbon, "Feedback")
    is Some(carbon_feedback) else {
    fail("expected Carbon feedback style resolver")
  }
  assert_true(carbon_feedback.style_api.contains("DesignFeedbackTokens"))
  assert_true(carbon_feedback.core_style_surface == "@views.FeedbackStyle")
  guard @audit.component_style_resolver_for(Primer, "Picker")
    is Some(primer_picker) else {
    fail("expected Primer picker style resolver")
  }
  assert_true(primer_picker.core_style_surface == "@views.PickerStyle")
  assert_true(primer_picker.token_surface.contains("picker"))
  guard @audit.component_style_resolver_for(Fluent, "DatePicker")
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
  assert_true(material_styles.surface.overlay.level == Overlay)
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
  let fluent_dark = @common.DesignPreset::Fluent.tokens(scheme=Dark)
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
  for preset in [@common.DesignPreset::Material, Carbon, Primer, Fluent] {
    let records = @audit.adaptation_report(preset)
    assert_true(records.length() >= 7)
    assert_true(@audit.aligned_adaptation_count(preset) > 0)
    assert_true(@audit.adaptation_gap_count(preset) > 0)
    assert_true(@audit.adaptation_source_lock_gap_count(preset) == 0)
    assert_true(@audit.undeclared_adaptation_source_count(preset) == 0)
    assert_false(records.any(item => item.moui_surface.contains("moui/views")))
    assert_true(records.any(item => item.kind == CollapsedRoleMatrix))
    assert_true(
      records.any(item => {
        item.kind == CustomizableOverride && item.status == ThemeMapped
      }),
    )
    for item in records {
      assert_true(item.source_declared)
      assert_true(item.source_locked)
      assert_true(item.source_ref != "")
      assert_true(item.remaining_gap != "")
    }
  }
  guard @audit.adaptation_report_for(
      Material,
      "Material dynamic color generation",
    )
    is Some(material_dynamic) else {
    fail("expected Material dynamic color adaptation")
  }
  assert_true(material_dynamic.status == SourceMapped)
  assert_true(material_dynamic.kind == PendingOfficialImport)
  guard @audit.adaptation_report_for(Carbon, "Carbon white/g10/g90/g100 themes")
    is Some(carbon_themes) else {
    fail("expected Carbon theme adaptation")
  }
  assert_true(carbon_themes.status == PreviewMapped)
  guard @audit.adaptation_report_for(
      Primer,
      "Primer color modes and accessibility themes",
    )
    is Some(primer_modes) else {
    fail("expected Primer mode adaptation")
  }
  assert_true(primer_modes.kind == CollapsedRoleMatrix)
  guard @audit.adaptation_report_for(Primer, "Primer typography primitives")
    is Some(primer_typography) else {
    fail("expected Primer typography adaptation")
  }
  assert_true(primer_typography.status == PreviewMapped)
  assert_true(
    primer_typography.remaining_gap.contains("line-height") &&
    primer_typography.remaining_gap.contains("title weight"),
  )
  guard @audit.adaptation_report_for(
      Fluent,
      "Fluent light/dark/high contrast themes",
    )
    is Some(fluent_variants) else {
    fail("expected Fluent variant adaptation")
  }
  assert_true(fluent_variants.status == ThemeMapped)
  guard @audit.adaptation_report_for(Fluent, "Fluent type ramp")
    is Some(fluent_typography) else {
    fail("expected Fluent typography adaptation")
  }
  assert_true(fluent_typography.status == PreviewMapped)
  assert_true(
    fluent_typography.difference.contains("full Fluent global font file") &&
    fluent_typography.remaining_gap.contains("line-height") &&
    fluent_typography.remaining_gap.contains("font-family"),
  )
  guard @audit.adaptation_report_for(Fluent, "Fluent spacing scales")
    is Some(fluent_spacing) else {
    fail("expected Fluent spacing adaptation")
  }
  assert_true(fluent_spacing.status == PreviewMapped)
  assert_true(
    fluent_spacing.difference.contains("horizontal and vertical spacing") &&
    fluent_spacing.remaining_gap.contains("axis-specific"),
  )
  guard @audit.adaptation_report_for(Fluent, "Fluent border radius scale")
    is Some(fluent_radius) else {
    fail("expected Fluent radius adaptation")
  }
  assert_true(fluent_radius.status == PreviewMapped)
  assert_true(
    fluent_radius.difference.contains("full Fluent global border-radius scale") &&
    fluent_radius.remaining_gap.contains("extended radius"),
  )
  guard @audit.adaptation_report_for(Fluent, "Fluent shadow and stroke depth")
    is Some(fluent_depth) else {
    fail("expected Fluent depth adaptation")
  }
  assert_true(fluent_depth.status == PreviewMapped)
  assert_true(
    fluent_depth.difference.contains("global stroke widths") &&
    fluent_depth.remaining_gap.contains("shadow/depth") &&
    fluent_depth.remaining_gap.contains("stroke-width scale"),
  )
}

///|
