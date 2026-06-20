///|
pub(all) enum DesignSystemRequirement {
  OfficialSources
  SourceVersionLocks
  SourcePackageInventory
  SourceImportedTokens
  RuntimeTokenAlignment
  TokenTaxonomy
  SemanticPalette
  Typography
  SpacingDensity
  ShapeRadius
  ElevationShadow
  Motion
  Surface
  StateLayer
  SchemeVariants
  ComponentTokens
  ComponentMatrix
  Customization
  OfficialTokenCoverage
  GoldenMappings
  AdaptationDifferences
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignSystemRequirementAudit {
  preset : @common.DesignPreset
  requirement : DesignSystemRequirement
  status : DesignTokenStatus
  evidence : String
  remaining_gap : String
} derive(Eq, Debug, ToJson)

///|
pub fn DesignSystemRequirement::label(
  preset : DesignSystemRequirement,
) -> String {
  match preset {
    OfficialSources => "official sources"
    SourceVersionLocks => "source version locks"
    SourcePackageInventory => "source package inventory"
    SourceImportedTokens => "source imported tokens"
    RuntimeTokenAlignment => "runtime token alignment"
    TokenTaxonomy => "token taxonomy"
    SemanticPalette => "semantic palette"
    Typography => "typography"
    SpacingDensity => "spacing and density"
    ShapeRadius => "shape and radius"
    ElevationShadow => "elevation and shadow"
    Motion => "motion"
    Surface => "surface"
    StateLayer => "state layer"
    SchemeVariants => "scheme variants"
    ComponentTokens => "component tokens"
    ComponentMatrix => "component token matrix"
    Customization => "customization"
    OfficialTokenCoverage => "official token coverage"
    GoldenMappings => "golden mappings"
    AdaptationDifferences => "adaptation differences"
  }
}

///|
pub fn requirement_audit(
  preset : @common.DesignPreset,
) -> Array[DesignSystemRequirementAudit] {
  let manifest = manifest(preset)
  [
    official_sources_audit(preset, manifest),
    source_version_lock_audit(preset),
    source_package_inventory_audit(preset),
    source_imported_token_audit(preset),
    runtime_token_alignment_audit(preset),
    token_taxonomy_audit(preset, manifest),
    category_audit(
      preset,
      manifest,
      DesignSystemRequirement::SemanticPalette,
      DesignTokenCategory::Color,
      "@common.DesignSemanticPalette plus @core.ColorPalette and @core.SemanticColorScale adapters",
      "Complete official semantic role matrix and generated token import are pending.",
    ),
    category_audit(
      preset,
      manifest,
      DesignSystemRequirement::Typography,
      DesignTokenCategory::Typography,
      "@common.DesignTypographyTokens plus @core.TypographyScale adapter",
      "Complete official type ramp and font-family token import are pending.",
    ),
    multi_category_audit(
      preset,
      manifest,
      DesignSystemRequirement::SpacingDensity,
      [DesignTokenCategory::Spacing, DesignTokenCategory::Density],
      "@common.DesignSpacingTokens and @common.DesignDensity resolve into @core.SpacingScale",
      "Complete official size/density matrices and component density overrides are pending.",
    ),
    category_audit(
      preset,
      manifest,
      DesignSystemRequirement::ShapeRadius,
      DesignTokenCategory::Shape,
      "@common.DesignRadiusTokens plus @core.RadiusScale adapter",
      "Complete official shape role matrix is pending.",
    ),
    category_audit(
      preset,
      manifest,
      DesignSystemRequirement::ElevationShadow,
      DesignTokenCategory::Elevation,
      "@common.DesignElevationTokens plus @core.ShadowScale adapter",
      "Official tonal elevation, layer, or shadow-level import is pending.",
    ),
    category_audit(
      preset,
      manifest,
      DesignSystemRequirement::Motion,
      DesignTokenCategory::Motion,
      "@common.DesignMotionTokens plus @core.MotionScale adapter",
      "Complete official duration/easing/component-motion import is pending.",
    ),
    category_audit(
      preset,
      manifest,
      DesignSystemRequirement::Surface,
      DesignTokenCategory::Surface,
      "@common.DesignSurfaceTokens plus @core.SurfaceScale adapter",
      "Complete official surface/layer role matrix is pending.",
    ),
    category_audit(
      preset,
      manifest,
      DesignSystemRequirement::StateLayer,
      DesignTokenCategory::StateLayer,
      "@common.DesignStateLayerTokens",
      "Component-specific state-layer matrix and disabled-state role coverage are pending.",
    ),
    scheme_variant_audit(preset, manifest),
    component_token_audit(preset, manifest),
    component_matrix_audit(preset),
    customization_audit(preset, manifest),
    official_token_coverage_audit(preset),
    golden_mapping_audit(preset),
    adaptation_difference_audit(preset),
  ]
}

///|
pub fn requirement_audit_for(
  preset : @common.DesignPreset,
  requirement : DesignSystemRequirement,
) -> DesignSystemRequirementAudit? {
  for item in requirement_audit(preset) {
    if item.requirement == requirement {
      return Some(item)
    }
  }
  None
}

///|
pub fn requirement_gap_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in requirement_audit(preset) {
    if item.status != DesignTokenStatus::OfficialComplete {
      count = count + 1
    }
  }
  count
}

///|
pub fn is_design_system_complete(preset : @common.DesignPreset) -> Bool {
  manifest(preset).is_official_complete() &&
  requirement_gap_count(preset) == 0 &&
  source_lock_quality_gap_count(preset) == 0 &&
  source_package_import_gap_count(preset) == 0 &&
  source_package_snapshot_gap_count(preset) == 0 &&
  source_import_coverage_gap_count(preset) == 0 &&
  source_import_unanchored_count(preset) == 0 &&
  source_imported_token_source_lock_gap_count(preset) == 0 &&
  source_import_integrity_gap_count(preset) == 0 &&
  runtime_token_alignment_gap_count(preset) == 0 &&
  semantic_palette_role_gap_count(preset) == 0 &&
  semantic_palette_role_source_gap_count(preset) == 0 &&
  semantic_palette_role_official_parity_gap_count(preset) == 0 &&
  typography_role_gap_count(preset) == 0 &&
  typography_role_source_gap_count(preset) == 0 &&
  typography_role_official_parity_gap_count(preset) == 0 &&
  typography_role_destination_gap_count(preset) == 0 &&
  token_taxonomy_gap_count(preset) == 0 &&
  token_taxonomy_source_gap_count(preset) == 0 &&
  token_taxonomy_official_parity_gap_count(preset) == 0 &&
  unmapped_official_token_anchor_count(preset) == 0 &&
  official_token_anchor_source_gap_count(preset) == 0 &&
  token_group_resolver_gap_count(preset) == 0 &&
  token_group_resolver_source_gap_count(preset) == 0 &&
  token_group_resolver_official_parity_gap_count(preset) == 0 &&
  density_resolver_gap_count(preset) == 0 &&
  density_resolver_source_gap_count(preset) == 0 &&
  density_resolver_official_parity_gap_count(preset) == 0 &&
  variant_resolver_gap_count(preset) == 0 &&
  variant_resolver_source_gap_count(preset) == 0 &&
  variant_resolver_official_parity_gap_count(preset) == 0 &&
  unanchored_golden_mapping_count(preset) == 0 &&
  golden_gap_count(preset) == 0 &&
  adaptation_gap_count(preset) == 0 &&
  adaptation_source_lock_gap_count(preset) == 0 &&
  customization_capability_gap_count(preset) == 0 &&
  customization_official_parity_gap_count(preset) == 0 &&
  component_style_resolver_gap_count(preset) == 0 &&
  component_style_resolver_source_gap_count(preset) == 0 &&
  component_style_resolver_official_parity_gap_count(preset) == 0 &&
  component_token_matrix_gap_count(preset) == 0 &&
  component_token_matrix_source_gap_count(preset) == 0
}

///|
fn official_sources_audit(
  preset : @common.DesignPreset,
  manifest : DesignSystemManifest,
) -> DesignSystemRequirementAudit {
  let undeclared = undeclared_golden_source_count(preset)
  let undeclared_token_sources = undeclared_official_token_anchor_source_count(
    preset,
  )
  let unused = unused_official_source_count(preset)
  let source_locks = manifest.source_lock_count()
  let official_sources = manifest.official_source_count()
  let has_official_docs = manifest.sources.any(source => {
    source.source_kind == "official-docs"
  })
  let has_official_source = official_sources > 0
  let has_official_source_locks = manifest.has_official_source_locks()
  let status = if manifest.is_official_complete() {
    DesignTokenStatus::OfficialComplete
  } else if undeclared > 0 || undeclared_token_sources > 0 {
    DesignTokenStatus::NotMapped
  } else if has_official_docs && has_official_source_locks {
    DesignTokenStatus::SourceMapped
  } else {
    DesignTokenStatus::NotMapped
  }
  audit(
    preset,
    DesignSystemRequirement::OfficialSources,
    status,
    manifest.sources.length().to_string() +
    " source anchors recorded; " +
    source_locks.to_string() +
    "/" +
    official_sources.to_string() +
    " official source locks; " +
    undeclared.to_string() +
    " undeclared golden sources; " +
    undeclared_token_sources.to_string() +
    " undeclared official-token sources",
    if status == DesignTokenStatus::OfficialComplete {
      "none"
    } else if undeclared > 0 || undeclared_token_sources > 0 {
      "One or more golden mappings or official-token anchors cite URLs that are not declared in the manifest sources."
    } else if has_official_source && !has_official_source_locks {
      "Official source package anchors need source_ref and token_path locks before generated token import can be trusted."
    } else if unused > 0 {
      unused.to_string() +
      " official source anchors have no golden mappings yet; generated token import/version-lock proof is pending."
    } else {
      "Official source anchors exist, but generated token import/version-lock proof is pending."
    },
  )
}

///|
fn source_version_lock_audit(
  preset : @common.DesignPreset,
) -> DesignSystemRequirementAudit {
  let records = source_lock_report(preset)
  let stable = stable_source_lock_count(preset)
  let gaps = source_lock_quality_gap_count(preset)
  let moving = moving_source_ref_count(preset)
  let status = if manifest(preset).is_official_complete() && gaps == 0 {
    DesignTokenStatus::OfficialComplete
  } else if records.length() == 0 {
    DesignTokenStatus::NotMapped
  } else if gaps == 0 {
    DesignTokenStatus::ThemeMapped
  } else if stable > 0 {
    DesignTokenStatus::PreviewMapped
  } else {
    DesignTokenStatus::SourceMapped
  }
  audit(
    preset,
    DesignSystemRequirement::SourceVersionLocks,
    status,
    stable.to_string() +
    "/" +
    records.length().to_string() +
    " stable source locks; " +
    moving.to_string() +
    " moving refs",
    gap_for_status(
      status, "Live official documentation and any moving branch refs still need stable snapshot evidence before reproducible token import can be trusted.",
    ),
  )
}

///|
fn source_imported_token_audit(
  preset : @common.DesignPreset,
) -> DesignSystemRequirementAudit {
  let anchors = source_import_coverage_count(preset)
  let imported = source_imported_official_token_count(preset)
  let import_records = source_imported_token_count(preset)
  let gaps = source_import_coverage_gap_count(preset)
  let unanchored = source_import_unanchored_count(preset)
  let lock_gaps = source_imported_token_source_lock_gap_count(preset)
  let integrity_gaps = source_import_integrity_gap_count(preset)
  let manifest_lock_gaps = source_import_manifest_lock_gap_count(preset)
  let anchor_mismatches = source_import_anchor_mismatch_count(preset)
  let golden_mismatches = source_import_golden_mismatch_count(preset)
  let status = if manifest(preset).is_official_complete() &&
    gaps == 0 &&
    unanchored == 0 &&
    lock_gaps == 0 &&
    integrity_gaps == 0 {
    DesignTokenStatus::OfficialComplete
  } else if anchors == 0 ||
    unanchored > 0 ||
    lock_gaps > 0 ||
    integrity_gaps > 0 {
    DesignTokenStatus::NotMapped
  } else if gaps > 0 {
    DesignTokenStatus::PreviewMapped
  } else if imported > 0 {
    DesignTokenStatus::SourceMapped
  } else {
    DesignTokenStatus::NotMapped
  }
  audit(
    preset,
    DesignSystemRequirement::SourceImportedTokens,
    status,
    imported.to_string() +
    "/" +
    anchors.to_string() +
    " official anchors have pinned source-import records; " +
    import_records.to_string() +
    " import records; " +
    gaps.to_string() +
    " import coverage gaps; " +
    unanchored.to_string() +
    " unanchored imports; " +
    lock_gaps.to_string() +
    " source-import lock gaps; " +
    integrity_gaps.to_string() +
    " integrity gaps; " +
    manifest_lock_gaps.to_string() +
    " manifest-lock gaps; " +
    anchor_mismatches.to_string() +
    " anchor mismatches; " +
    golden_mismatches.to_string() +
    " golden mismatches",
    gap_for_status(
      status, "Every required official token anchor still needs a pinned source-import record before official completion.",
    ),
  )
}

///|
fn source_package_inventory_audit(
  preset : @common.DesignPreset,
) -> DesignSystemRequirementAudit {
  let rows = source_package_inventory_count(preset)
  let snapshots = source_package_snapshot_count(preset)
  let snapshot_gaps = source_package_snapshot_gap_count(preset)
  let mapped = source_package_mapped_token_count(preset)
  let imported = source_package_imported_token_count(preset)
  let imported_records = source_imported_token_count(preset)
  let imported_lock_gaps = source_imported_token_source_lock_gap_count(preset)
  let import_gaps = source_package_import_gap_count(preset)
  let status = if manifest(preset).is_official_complete() &&
    import_gaps == 0 &&
    snapshot_gaps == 0 &&
    imported_lock_gaps == 0 {
    DesignTokenStatus::OfficialComplete
  } else if rows == 0 || snapshot_gaps > 0 || imported_lock_gaps > 0 {
    DesignTokenStatus::NotMapped
  } else if import_gaps > 0 {
    DesignTokenStatus::PreviewMapped
  } else {
    DesignTokenStatus::ThemeMapped
  }
  audit(
    preset,
    DesignSystemRequirement::SourcePackageInventory,
    status,
    rows.to_string() +
    " source package rows; " +
    snapshots.to_string() +
    " snapshot URLs; " +
    mapped.to_string() +
    " mapped tokens; " +
    imported.to_string() +
    " imported tokens; " +
    imported_records.to_string() +
    " source-import records; " +
    imported_lock_gaps.to_string() +
    " source-import lock gaps; " +
    import_gaps.to_string() +
    " import gaps",
    gap_for_status(
      status, "Pinned official source packages have partial source-import records, but generated full-token imports are still pending.",
    ),
  )
}

///|
fn runtime_token_alignment_audit(
  preset : @common.DesignPreset,
) -> DesignSystemRequirementAudit {
  let rows = runtime_token_alignment_count(preset)
  let aligned = runtime_token_aligned_count(preset)
  let gaps = runtime_token_alignment_gap_count(preset)
  let unresolved = runtime_token_source_value_gap_count(preset)
  let destination_gaps = runtime_token_destination_gap_count(preset)
  let status = if manifest(preset).is_official_complete() && gaps == 0 {
    DesignTokenStatus::OfficialComplete
  } else if rows == 0 {
    DesignTokenStatus::NotMapped
  } else if aligned > 0 && gaps > 0 {
    DesignTokenStatus::PreviewMapped
  } else if aligned > 0 {
    DesignTokenStatus::ThemeMapped
  } else {
    DesignTokenStatus::PreviewMapped
  }
  audit(
    preset,
    DesignSystemRequirement::RuntimeTokenAlignment,
    status,
    aligned.to_string() +
    "/" +
    rows.to_string() +
    " runtime token rows align with resolved official source values; " +
    gaps.to_string() +
    " alignment gaps; " +
    unresolved.to_string() +
    " unresolved source values; " +
    destination_gaps.to_string() +
    " destination gaps",
    gap_for_status(
      status, "Pinned source imports still need generated value resolution and runtime-token equality checks before official completion.",
    ),
  )
}

///|
fn token_taxonomy_audit(
  preset : @common.DesignPreset,
  manifest : DesignSystemManifest,
) -> DesignSystemRequirementAudit {
  let rows = token_taxonomy_count(preset)
  let required = token_taxonomy_required_count(preset)
  let mapped = token_taxonomy_mapped_count(preset)
  let gaps = token_taxonomy_gap_count(preset)
  let source_gaps = token_taxonomy_source_gap_count(preset)
  let parity_gaps = token_taxonomy_official_parity_gap_count(preset)
  let complete = gaps == 0 && source_gaps == 0
  let status = if manifest.is_official_complete() && parity_gaps == 0 {
    DesignTokenStatus::OfficialComplete
  } else if rows == 0 || !complete {
    DesignTokenStatus::NotMapped
  } else {
    DesignTokenStatus::PreviewMapped
  }
  audit(
    preset,
    DesignSystemRequirement::TokenTaxonomy,
    status,
    mapped.to_string() +
    "/" +
    required.to_string() +
    " required taxonomy rows mapped; " +
    rows.to_string() +
    " taxonomy rows; " +
    gaps.to_string() +
    " taxonomy gaps; " +
    source_gaps.to_string() +
    " source-lock gaps; " +
    parity_gaps.to_string() +
    " official parity gaps",
    if status == DesignTokenStatus::OfficialComplete {
      "none"
    } else if complete {
      "Taxonomy exists, but full official token role matrices are not imported yet."
    } else {
      "One or more required token categories are missing."
    },
  )
}

///|
fn category_audit(
  preset : @common.DesignPreset,
  manifest : DesignSystemManifest,
  requirement : DesignSystemRequirement,
  category : DesignTokenCategory,
  evidence : String,
  remaining_gap : String,
) -> DesignSystemRequirementAudit {
  let status = token_category_status(manifest, category)
  let token_group_requirement = token_group_requirement_supported(requirement)
  let resolver_gaps = if token_group_requirement {
    token_group_resolver_gap_count_for(preset, requirement)
  } else {
    0
  }
  let source_gaps = if token_group_requirement {
    token_group_resolver_source_gap_count_for(preset, requirement)
  } else {
    0
  }
  let parity_gaps = if token_group_requirement {
    token_group_resolver_parity_gap_count_for(preset, requirement)
  } else {
    0
  }
  let semantic_palette_requirement = requirement ==
    DesignSystemRequirement::SemanticPalette
  let typography_requirement = requirement ==
    DesignSystemRequirement::Typography
  let semantic_role_gaps = if semantic_palette_requirement {
    semantic_palette_role_gap_count(preset)
  } else {
    0
  }
  let semantic_role_source_gaps = if semantic_palette_requirement {
    semantic_palette_role_source_gap_count(preset)
  } else {
    0
  }
  let semantic_role_parity_gaps = if semantic_palette_requirement {
    semantic_palette_role_official_parity_gap_count(preset)
  } else {
    0
  }
  let typography_role_gaps = if typography_requirement {
    typography_role_gap_count(preset)
  } else {
    0
  }
  let typography_role_source_gaps = if typography_requirement {
    typography_role_source_gap_count(preset)
  } else {
    0
  }
  let typography_role_destination_gaps = if typography_requirement {
    typography_role_destination_gap_count(preset)
  } else {
    0
  }
  let typography_role_parity_gaps = if typography_requirement {
    typography_role_official_parity_gap_count(preset)
  } else {
    0
  }
  let evidence = if token_group_requirement {
    evidence +
    "; " +
    token_group_resolver_count_for(preset, requirement).to_string() +
    " token-group resolver records; " +
    resolver_gaps.to_string() +
    " resolver gaps; " +
    source_gaps.to_string() +
    " source-lock gaps; " +
    parity_gaps.to_string() +
    " official parity gaps"
  } else {
    evidence
  }
  let evidence = if semantic_palette_requirement {
    evidence +
    "; " +
    semantic_palette_role_count(preset).to_string() +
    " semantic palette role records; " +
    semantic_palette_role_mapped_count(preset).to_string() +
    " role mappings; " +
    semantic_palette_role_aligned_count(preset).to_string() +
    " role alignments; " +
    semantic_role_gaps.to_string() +
    " role gaps; " +
    semantic_role_source_gaps.to_string() +
    " role source gaps; " +
    semantic_role_parity_gaps.to_string() +
    " role parity gaps"
  } else {
    evidence
  }
  let evidence = if typography_requirement {
    evidence +
    "; " +
    typography_role_count(preset).to_string() +
    " typography role records; " +
    typography_role_mapped_count(preset).to_string() +
    " role mappings; " +
    typography_role_aligned_count(preset).to_string() +
    " role alignments; " +
    typography_role_gaps.to_string() +
    " role gaps; " +
    typography_role_source_gaps.to_string() +
    " role source gaps; " +
    typography_role_destination_gaps.to_string() +
    " role destination gaps; " +
    typography_role_parity_gaps.to_string() +
    " role parity gaps"
  } else {
    evidence
  }
  let audit_status = if source_gaps > 0 {
    DesignTokenStatus::NotMapped
  } else if semantic_palette_requirement && semantic_role_gaps > 0 {
    DesignTokenStatus::PreviewMapped
  } else if typography_requirement &&
    (
      typography_role_gaps > 0 ||
      typography_role_source_gaps > 0 ||
      typography_role_destination_gaps > 0 ||
      typography_role_parity_gaps > 0
    ) {
    DesignTokenStatus::PreviewMapped
  } else {
    complete_status_if_manifest_complete(manifest, status)
  }
  audit(
    preset,
    requirement,
    audit_status,
    evidence,
    gap_for_status(audit_status, remaining_gap),
  )
}

///|
fn multi_category_audit(
  preset : @common.DesignPreset,
  manifest : DesignSystemManifest,
  requirement : DesignSystemRequirement,
  categories : Array[DesignTokenCategory],
  evidence : String,
  remaining_gap : String,
) -> DesignSystemRequirementAudit {
  let statuses : Array[DesignTokenStatus] = []
  for category in categories {
    statuses.push(token_category_status(manifest, category))
  }
  let density_requirement = requirement ==
    DesignSystemRequirement::SpacingDensity
  let density_resolver_gaps = if density_requirement {
    density_resolver_gap_count(preset)
  } else {
    0
  }
  let density_source_gaps = if density_requirement {
    density_resolver_source_gap_count(preset)
  } else {
    0
  }
  let density_parity_gaps = if density_requirement {
    density_resolver_official_parity_gap_count(preset)
  } else {
    0
  }
  let status = complete_status_if_manifest_complete(
    manifest,
    combined_status(statuses, mapped_fallback=DesignTokenStatus::ThemeMapped),
  )
  let evidence = if density_requirement {
    evidence +
    "; " +
    density_resolver_count(preset).to_string() +
    " density resolver records; " +
    density_resolver_gaps.to_string() +
    " resolver gaps; " +
    density_source_gaps.to_string() +
    " source-lock gaps; " +
    density_parity_gaps.to_string() +
    " official parity gaps"
  } else {
    evidence
  }
  audit(
    preset,
    requirement,
    if density_source_gaps > 0 {
      DesignTokenStatus::NotMapped
    } else {
      status
    },
    evidence,
    gap_for_status(status, remaining_gap),
  )
}

///|
fn scheme_variant_audit(
  preset : @common.DesignPreset,
  manifest : DesignSystemManifest,
) -> DesignSystemRequirementAudit {
  let statuses : Array[DesignTokenStatus] = []
  for item in manifest.variant_coverage {
    statuses.push(item.status)
  }
  let resolver_gaps = variant_resolver_gap_count(preset)
  let source_gaps = variant_resolver_source_gap_count(preset)
  let official_parity_gaps = variant_resolver_official_parity_gap_count(preset)
  let status = complete_status_if_manifest_complete(
    manifest,
    combined_status(statuses, mapped_fallback=DesignTokenStatus::ThemeMapped),
  )
  audit(
    preset,
    DesignSystemRequirement::SchemeVariants,
    if source_gaps > 0 {
      DesignTokenStatus::NotMapped
    } else {
      status
    },
    manifest.variant_coverage.length().to_string() +
    " scheme variants covered; " +
    variant_resolver_count(preset).to_string() +
    " variant resolver records; " +
    resolver_gaps.to_string() +
    " resolver gaps; " +
    source_gaps.to_string() +
    " source-lock gaps; " +
    official_parity_gaps.to_string() +
    " official parity gaps",
    gap_for_status(
      status, "Official light/dark/high-contrast/system variant matrices are not fully imported yet.",
    ),
  )
}

///|
fn component_token_audit(
  preset : @common.DesignPreset,
  manifest : DesignSystemManifest,
) -> DesignSystemRequirementAudit {
  let statuses : Array[DesignTokenStatus] = []
  for item in manifest.component_coverage {
    statuses.push(item.status)
  }
  let complete = has_required_component(manifest, "Button") &&
    has_required_component(manifest, "TextField") &&
    has_required_component(manifest, "Surface") &&
    has_required_component(manifest, "ChoiceControl") &&
    has_required_component(manifest, "Progress") &&
    has_required_component(manifest, "Slider") &&
    has_required_component(manifest, "Picker") &&
    has_required_component(manifest, "DatePicker") &&
    has_required_component(manifest, "Feedback") &&
    has_required_component(manifest, "Badge") &&
    has_required_component(manifest, "FormValidation")
  let status = if !complete {
    DesignTokenStatus::NotMapped
  } else {
    complete_status_if_manifest_complete(
      manifest,
      combined_status(
        statuses,
        mapped_fallback=DesignTokenStatus::ComponentMapped,
      ),
    )
  }
  let resolver_gaps = component_style_resolver_gap_count(preset)
  let source_gaps = component_style_resolver_source_gap_count(preset)
  let official_parity_gaps = component_style_resolver_official_parity_gap_count(
    preset,
  )
  audit(
    preset,
    DesignSystemRequirement::ComponentTokens,
    if source_gaps > 0 {
      DesignTokenStatus::NotMapped
    } else {
      status
    },
    manifest.component_coverage.length().to_string() +
    " component token surfaces covered; " +
    component_style_resolver_count(preset).to_string() +
    " component style resolver records; " +
    resolver_gaps.to_string() +
    " resolver gaps; " +
    source_gaps.to_string() +
    " source-lock gaps; " +
    official_parity_gaps.to_string() +
    " official parity gaps",
    if complete {
      gap_for_status(
        status, "Neutral component tokens exist; complete official component token matrix is pending.",
      )
    } else {
      "One or more required neutral component token surfaces are missing."
    },
  )
}

///|
fn component_matrix_audit(
  preset : @common.DesignPreset,
) -> DesignSystemRequirementAudit {
  let rows = component_token_matrix_count(preset)
  let mapped = component_token_matrix_mapped_count(preset)
  let required = component_token_matrix_required_count(preset)
  let source_imported = component_token_matrix_source_imported_count(preset)
  let runtime_aligned = component_token_matrix_runtime_aligned_count(preset)
  let gaps = component_token_matrix_gap_count(preset)
  let source_gaps = component_token_matrix_source_gap_count(preset)
  let status = if manifest(preset).is_official_complete() &&
    gaps == 0 &&
    source_gaps == 0 {
    DesignTokenStatus::OfficialComplete
  } else if rows == 0 || source_gaps > 0 {
    DesignTokenStatus::NotMapped
  } else if gaps > 0 {
    DesignTokenStatus::PreviewMapped
  } else {
    DesignTokenStatus::ComponentMapped
  }
  audit(
    preset,
    DesignSystemRequirement::ComponentMatrix,
    status,
    rows.to_string() +
    " component matrix rows; " +
    mapped.to_string() +
    "/" +
    required.to_string() +
    " mapped component-token anchors; " +
    source_imported.to_string() +
    " related source-imported anchors; " +
    runtime_aligned.to_string() +
    " runtime-aligned anchors; " +
    source_gaps.to_string() +
    " source-lock gaps",
    gap_for_status(
      status, "Every neutral component surface needs a source-locked official component-token matrix before official completion.",
    ),
  )
}

///|
fn customization_audit(
  preset : @common.DesignPreset,
  manifest : DesignSystemManifest,
) -> DesignSystemRequirementAudit {
  let statuses : Array[DesignTokenStatus] = []
  for item in manifest.customization_coverage {
    statuses.push(item.status)
  }
  let capability_gaps = customization_capability_gap_count(preset)
  let official_parity_gaps = customization_official_parity_gap_count(preset)
  let status = complete_status_if_manifest_complete(
    manifest,
    combined_status(statuses, mapped_fallback=DesignTokenStatus::ThemeMapped),
  )
  audit(
    preset,
    DesignSystemRequirement::Customization,
    status,
    manifest.customization_coverage.length().to_string() +
    " manifest customization APIs; " +
    customization_report_count(preset).to_string() +
    " customization capability records; " +
    capability_gaps.to_string() +
    " API gaps; " +
    official_parity_gaps.to_string() +
    " official parity gaps",
    gap_for_status(
      status, "Custom inheritance and overrides exist; official per-system theme-builder parity is pending.",
    ),
  )
}

///|
fn golden_mapping_audit(
  preset : @common.DesignPreset,
) -> DesignSystemRequirementAudit {
  let mapped = golden_mapped_count(preset)
  let gaps = golden_gap_count(preset)
  let status = if manifest(preset).is_official_complete() && gaps == 0 {
    DesignTokenStatus::OfficialComplete
  } else if mapped > 0 && gaps > 0 {
    DesignTokenStatus::PreviewMapped
  } else if mapped > 0 {
    DesignTokenStatus::SourceMapped
  } else {
    DesignTokenStatus::NotMapped
  }
  audit(
    preset,
    DesignSystemRequirement::GoldenMappings,
    status,
    mapped.to_string() + " mapped, " + gaps.to_string() + " gaps",
    gap_for_status(
      status, "Every official token name still needs a mapped or intentionally unsupported golden entry.",
    ),
  )
}

///|
fn official_token_coverage_audit(
  preset : @common.DesignPreset,
) -> DesignSystemRequirementAudit {
  let anchors = official_token_anchor_count(preset)
  let mapped = mapped_official_token_anchor_count(preset)
  let gaps = unmapped_official_token_anchor_count(preset)
  let source_gaps = official_token_anchor_source_gap_count(preset)
  let source_locks = official_token_anchor_source_lock_count(preset)
  let unanchored = unanchored_golden_mapping_count(preset)
  let status = if manifest(preset).is_official_complete() &&
    gaps == 0 &&
    source_gaps == 0 &&
    unanchored == 0 {
    DesignTokenStatus::OfficialComplete
  } else if source_gaps > 0 || unanchored > 0 {
    DesignTokenStatus::NotMapped
  } else if anchors == 0 {
    DesignTokenStatus::NotMapped
  } else if mapped > 0 && gaps > 0 {
    DesignTokenStatus::PreviewMapped
  } else if mapped > 0 {
    DesignTokenStatus::SourceMapped
  } else {
    DesignTokenStatus::NotMapped
  }
  audit(
    preset,
    DesignSystemRequirement::OfficialTokenCoverage,
    status,
    mapped.to_string() +
    "/" +
    anchors.to_string() +
    " required official token anchors mapped; " +
    gaps.to_string() +
    " required gaps; " +
    source_locks.to_string() +
    "/" +
    anchors.to_string() +
    " source locks; " +
    unanchored.to_string() +
    " unanchored golden mappings",
    gap_for_status(
      status, "Every required official token anchor needs a mapped or intentionally unsupported golden entry.",
    ),
  )
}

///|
fn adaptation_difference_audit(
  preset : @common.DesignPreset,
) -> DesignSystemRequirementAudit {
  let records = adaptation_record_count(preset)
  let aligned = aligned_adaptation_count(preset)
  let gaps = adaptation_gap_count(preset)
  let source_gaps = adaptation_source_lock_gap_count(preset)
  let undeclared = undeclared_adaptation_source_count(preset)
  let status = if manifest(preset).is_official_complete() &&
    gaps == 0 &&
    source_gaps == 0 {
    DesignTokenStatus::OfficialComplete
  } else if records == 0 || source_gaps > 0 || undeclared > 0 {
    DesignTokenStatus::NotMapped
  } else if aligned > 0 && gaps > 0 {
    DesignTokenStatus::PreviewMapped
  } else if aligned > 0 {
    DesignTokenStatus::SourceMapped
  } else {
    DesignTokenStatus::NotMapped
  }
  audit(
    preset,
    DesignSystemRequirement::AdaptationDifferences,
    status,
    records.to_string() +
    " adaptation records; " +
    aligned.to_string() +
    " aligned; " +
    gaps.to_string() +
    " gaps; " +
    source_gaps.to_string() +
    " source-lock gaps",
    gap_for_status(
      status, "MoUI adaptation differences must be closed or marked with source-mapped unsupported evidence before official completion.",
    ),
  )
}

///|
fn token_category_status(
  manifest : DesignSystemManifest,
  category : DesignTokenCategory,
) -> DesignTokenStatus {
  for item in manifest.token_coverage {
    if item.category == category {
      return item.status
    }
  }
  DesignTokenStatus::NotMapped
}

///|
fn has_required_component(
  manifest : DesignSystemManifest,
  component : String,
) -> Bool {
  manifest.component_coverage.any(item => item.component == component)
}

///|
fn complete_status_if_manifest_complete(
  manifest : DesignSystemManifest,
  status : DesignTokenStatus,
) -> DesignTokenStatus {
  if manifest.is_official_complete() {
    DesignTokenStatus::OfficialComplete
  } else {
    status
  }
}

///|
fn combined_status(
  statuses : Array[DesignTokenStatus],
  mapped_fallback~ : DesignTokenStatus,
) -> DesignTokenStatus {
  let mut all_official = statuses.length() > 0
  let mut has_not_mapped = false
  let mut has_source = false
  let mut has_preview = false
  let mut has_component = false
  let mut has_theme = false
  for status in statuses {
    if status != DesignTokenStatus::OfficialComplete {
      all_official = false
    }
    match status {
      DesignTokenStatus::NotMapped => has_not_mapped = true
      DesignTokenStatus::SourceMapped => has_source = true
      DesignTokenStatus::PreviewMapped => has_preview = true
      DesignTokenStatus::ComponentMapped => has_component = true
      DesignTokenStatus::ThemeMapped => has_theme = true
      DesignTokenStatus::OfficialComplete => ()
    }
  }
  if all_official {
    DesignTokenStatus::OfficialComplete
  } else if has_not_mapped {
    DesignTokenStatus::NotMapped
  } else if has_source {
    DesignTokenStatus::SourceMapped
  } else if has_preview {
    DesignTokenStatus::PreviewMapped
  } else if has_component {
    DesignTokenStatus::ComponentMapped
  } else if has_theme {
    DesignTokenStatus::ThemeMapped
  } else {
    mapped_fallback
  }
}

///|
fn gap_for_status(status : DesignTokenStatus, gap : String) -> String {
  if status == DesignTokenStatus::OfficialComplete {
    "none"
  } else {
    gap
  }
}

///|
fn audit(
  preset : @common.DesignPreset,
  requirement : DesignSystemRequirement,
  status : DesignTokenStatus,
  evidence : String,
  remaining_gap : String,
) -> DesignSystemRequirementAudit {
  { preset, requirement, status, evidence, remaining_gap }
}
