///|
pub(all) struct DesignSystemReport {
  preset : DesignPreset
  scheme : @core.ColorScheme
  system_scheme : @core.ColorScheme
  density : DesignDensity
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
pub fn DesignPreset::design_system_report(
  self : DesignPreset,
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
  system_scheme? : @core.ColorScheme = @core.ColorScheme::Dark,
  density? : DesignDensity = DesignDensity::Standard,
) -> DesignSystemReport {
  let manifest = self.manifest()
  let complete = self.is_design_system_complete()
  {
    preset: self,
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
    requirement_audit: self.requirement_audit(),
    token_taxonomy: self.token_taxonomy_report(),
    semantic_palette_roles: self.semantic_palette_role_report(scheme~),
    typography_roles: self.typography_role_report(scheme~),
    sources: self.sources(),
    source_locks: self.source_lock_report(),
    source_packages: self.source_package_inventory(),
    source_imports: self.source_imported_tokens(),
    source_import_coverage: self.source_import_coverage(),
    source_import_integrity: self.source_import_integrity_report(),
    runtime_alignment: self.runtime_token_alignment_report(),
    token_group_resolvers: self.token_group_resolver_report(scheme~),
    density_resolvers: self.density_resolver_report(scheme~),
    variant_resolvers: self.variant_resolver_report(system_scheme~, density~),
    customization: self.customization_report(),
    official_token_coverage: self.official_token_coverage(),
    official_token_source_usage: self.official_token_source_usage(),
    component_token_matrix: self.component_token_matrix(),
    component_style_resolvers: self.component_style_resolver_report(scheme~),
    adaptation: self.adaptation_report(),
    golden_mappings: self.golden_mappings(),
    unanchored_golden_mappings: self.golden_mappings_without_official_anchor(),
    note: design_system_report_note(complete),
  }
}

///|
pub fn DesignSystemReport::evidence_row_count(self : DesignSystemReport) -> Int {
  self.requirement_audit.length() +
  self.token_taxonomy.length() +
  self.semantic_palette_roles.length() +
  self.typography_roles.length() +
  self.sources.length() +
  self.source_locks.length() +
  self.source_packages.length() +
  self.source_imports.length() +
  self.source_import_coverage.length() +
  self.source_import_integrity.length() +
  self.runtime_alignment.length() +
  self.token_group_resolvers.length() +
  self.density_resolvers.length() +
  self.variant_resolvers.length() +
  self.customization.length() +
  self.official_token_coverage.length() +
  self.official_token_source_usage.length() +
  self.component_token_matrix.length() +
  self.component_style_resolvers.length() +
  self.adaptation.length() +
  self.golden_mappings.length() +
  self.unanchored_golden_mappings.length()
}

///|
pub fn DesignSystemReport::gap_count(self : DesignSystemReport) -> Int {
  let mut count = 0
  for item in self.requirement_audit {
    if item.status != DesignTokenStatus::OfficialComplete {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignSystemReport::typography_gap_count(
  self : DesignSystemReport,
) -> Int {
  let mut count = 0
  for item in self.typography_roles {
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
  self : DesignSystemReport,
) -> Int {
  let mut count = 0
  for item in self.semantic_palette_roles {
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
pub fn DesignSystemReport::taxonomy_gap_count(self : DesignSystemReport) -> Int {
  let mut count = 0
  for item in self.token_taxonomy {
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
  self : DesignSystemReport,
) -> Bool {
  self.status == DesignTokenStatus::OfficialComplete || self.complete
}

///|
fn design_system_report_note(complete : Bool) -> String {
  if complete {
    "The aggregate report proves this design system package complete against the current MoUI requirement audit."
  } else {
    "The aggregate report is generation-ready evidence for a source-mapped preview; unresolved gaps prevent any official-complete compatibility claim."
  }
}
