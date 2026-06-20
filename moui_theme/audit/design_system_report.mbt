///|
pub(all) struct DesignSystemReport {
  preset : @common.DesignPreset
  scheme : @core.ColorScheme
  system_scheme : @core.ColorScheme
  density : @common.DesignDensity
  status : DesignTokenStatus
  complete : Bool
  manifest : DesignSystemManifest
  requirement_audit : Array[DesignSystemRequirementAudit]
  token_taxonomy : Array[DesignTokenTaxonomyRecord]
  semantic_palette_roles : Array[DesignSemanticPaletteRoleRecord]
  typography_roles : Array[DesignTypographyRoleRecord]
  sources : Array[DesignSystemSource]
  source_locks : Array[DesignSourceLockRecord]
  source_packages : Array[DesignSourcePackageRecord]
  source_imports : Array[DesignSourceImportedToken]
  source_import_coverage : Array[DesignSourceImportCoverage]
  source_import_integrity : Array[DesignSourceImportIntegrityRecord]
  runtime_alignment : Array[DesignRuntimeTokenAlignmentRecord]
  token_group_resolvers : Array[DesignTokenGroupResolverRecord]
  density_resolvers : Array[DesignDensityResolverRecord]
  variant_resolvers : Array[DesignVariantResolverRecord]
  customization : Array[DesignCustomizationCapabilityRecord]
  official_token_coverage : Array[DesignOfficialTokenCoverage]
  official_token_source_usage : Array[DesignOfficialTokenSourceUsage]
  component_token_matrix : Array[DesignComponentTokenMatrixRecord]
  component_style_resolvers : Array[DesignComponentStyleResolverRecord]
  adaptation : Array[DesignAdaptationRecord]
  golden_mappings : Array[DesignTokenMapping]
  unanchored_golden_mappings : Array[DesignTokenMapping]
  note : String
} derive(Eq, Debug, ToJson)

///|
pub fn design_system_report(
  preset : @common.DesignPreset,
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
  system_scheme? : @core.ColorScheme = @core.ColorScheme::Dark,
  density? : @common.DesignDensity = @common.DesignDensity::Standard,
) -> DesignSystemReport {
  let manifest = manifest(preset)
  let complete = is_design_system_complete(preset)
  {
    preset,
    scheme,
    system_scheme,
    density,
    status: if complete {
      DesignTokenStatus::OfficialComplete
    } else {
      manifest.stage
    },
    complete,
    manifest,
    requirement_audit: requirement_audit(preset),
    token_taxonomy: token_taxonomy_report(preset),
    semantic_palette_roles: semantic_palette_role_report(preset, scheme~),
    typography_roles: typography_role_report(preset, scheme~),
    sources: sources(preset),
    source_locks: source_lock_report(preset),
    source_packages: source_package_inventory(preset),
    source_imports: source_imported_tokens(preset),
    source_import_coverage: source_import_coverage(preset),
    source_import_integrity: source_import_integrity_report(preset),
    runtime_alignment: runtime_token_alignment_report(preset),
    token_group_resolvers: token_group_resolver_report(preset, scheme~),
    density_resolvers: density_resolver_report(preset, scheme~),
    variant_resolvers: variant_resolver_report(preset, system_scheme~, density~),
    customization: customization_report(preset),
    official_token_coverage: official_token_coverage(preset),
    official_token_source_usage: official_token_source_usage(preset),
    component_token_matrix: component_token_matrix(preset),
    component_style_resolvers: component_style_resolver_report(preset, scheme~),
    adaptation: adaptation_report(preset),
    golden_mappings: golden_mappings(preset),
    unanchored_golden_mappings: golden_mappings_without_official_anchor(preset),
    note: design_system_report_note(complete),
  }
}

///|
pub fn DesignSystemReport::evidence_row_count(
  preset : DesignSystemReport,
) -> Int {
  preset.requirement_audit.length() +
  preset.token_taxonomy.length() +
  preset.semantic_palette_roles.length() +
  preset.typography_roles.length() +
  preset.sources.length() +
  preset.source_locks.length() +
  preset.source_packages.length() +
  preset.source_imports.length() +
  preset.source_import_coverage.length() +
  preset.source_import_integrity.length() +
  preset.runtime_alignment.length() +
  preset.token_group_resolvers.length() +
  preset.density_resolvers.length() +
  preset.variant_resolvers.length() +
  preset.customization.length() +
  preset.official_token_coverage.length() +
  preset.official_token_source_usage.length() +
  preset.component_token_matrix.length() +
  preset.component_style_resolvers.length() +
  preset.adaptation.length() +
  preset.golden_mappings.length() +
  preset.unanchored_golden_mappings.length()
}

///|
pub fn DesignSystemReport::gap_count(preset : DesignSystemReport) -> Int {
  let mut count = 0
  for item in preset.requirement_audit {
    if item.status != DesignTokenStatus::OfficialComplete {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignSystemReport::typography_gap_count(
  preset : DesignSystemReport,
) -> Int {
  let mut count = 0
  for item in preset.typography_roles {
    if item.required &&
      (
        !item.resolves_core_surface ||
        item.status == DesignTokenStatus::NotMapped ||
        item.remaining_gap != "none"
      ) {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignSystemReport::semantic_palette_gap_count(
  preset : DesignSystemReport,
) -> Int {
  let mut count = 0
  for item in preset.semantic_palette_roles {
    if item.required &&
      (
        !item.resolves_core_surface ||
        item.status == DesignTokenStatus::NotMapped ||
        item.remaining_gap != "none"
      ) {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignSystemReport::taxonomy_gap_count(
  preset : DesignSystemReport,
) -> Int {
  let mut count = 0
  for item in preset.token_taxonomy {
    if item.required &&
      (
        item.status == DesignTokenStatus::NotMapped ||
        !item.manifest_declared ||
        !item.source_declared ||
        !item.source_locked
      ) {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignSystemReport::has_official_completion_claim(
  preset : DesignSystemReport,
) -> Bool {
  preset.status == DesignTokenStatus::OfficialComplete || preset.complete
}

///|
fn design_system_report_note(complete : Bool) -> String {
  if complete {
    "The aggregate report proves this design system package complete against the current MoUI requirement audit."
  } else {
    "The aggregate report is generation-ready evidence for a source-mapped preview; unresolved gaps prevent any official-complete compatibility claim."
  }
}
