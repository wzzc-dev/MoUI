// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend DesignAdaptationKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignAdaptationKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignAdaptationKind with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignAdaptationRecord with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignAdaptationRecord with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignAdaptationRecord with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignComponentCoverage with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignComponentCoverage with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignComponentCoverage with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignComponentStyleResolverRecord with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignComponentStyleResolverRecord with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignComponentStyleResolverRecord with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignComponentTokenMatrixRecord with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignComponentTokenMatrixRecord with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignComponentTokenMatrixRecord with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignCustomizationCapabilityRecord with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignCustomizationCapabilityRecord with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignCustomizationCapabilityRecord with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignCustomizationCoverage with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignCustomizationCoverage with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignCustomizationCoverage with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignCustomizationKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignCustomizationKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignCustomizationKind with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignDensityResolverRecord with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignDensityResolverRecord with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignDensityResolverRecord with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignOfficialTokenAnchor with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignOfficialTokenAnchor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignOfficialTokenAnchor with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignOfficialTokenCoverage with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignOfficialTokenCoverage with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignOfficialTokenCoverage with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignOfficialTokenSourceUsage with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignOfficialTokenSourceUsage with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignOfficialTokenSourceUsage with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignRuntimeTokenAlignmentRecord with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignRuntimeTokenAlignmentRecord with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignRuntimeTokenAlignmentRecord with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignSemanticPaletteRole with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignSemanticPaletteRole with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignSemanticPaletteRole with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignSemanticPaletteRoleRecord with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignSemanticPaletteRoleRecord with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignSemanticPaletteRoleRecord with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignSourceImportCoverage with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignSourceImportCoverage with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignSourceImportCoverage with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignSourceImportIntegrityRecord with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignSourceImportIntegrityRecord with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignSourceImportIntegrityRecord with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignSourceImportedToken with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignSourceImportedToken with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignSourceImportedToken with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignSourceLockRecord with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignSourceLockRecord with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignSourceLockRecord with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignSourcePackageRecord with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignSourcePackageRecord with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignSourcePackageRecord with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignSourceRefKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignSourceRefKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignSourceRefKind with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignSourceUsage with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignSourceUsage with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignSourceUsage with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignSystemManifest with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignSystemManifest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignSystemManifest with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignSystemReport with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignSystemReport with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignSystemReport with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignSystemRequirement with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignSystemRequirement with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignSystemRequirement with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignSystemRequirementAudit with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignSystemRequirementAudit with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignSystemRequirementAudit with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignSystemSource with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignSystemSource with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignSystemSource with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignTokenCategory with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignTokenCategory with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignTokenCategory with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignTokenCoverage with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignTokenCoverage with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignTokenCoverage with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignTokenGroupResolverRecord with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignTokenGroupResolverRecord with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignTokenGroupResolverRecord with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignTokenLayer with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignTokenLayer with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignTokenLayer with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignTokenMapping with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignTokenMapping with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignTokenMapping with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignTokenStatus with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignTokenStatus with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignTokenStatus with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignTokenTaxonomyRecord with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignTokenTaxonomyRecord with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignTokenTaxonomyRecord with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignTypographyRole with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignTypographyRole with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignTypographyRole with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignTypographyRoleRecord with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignTypographyRoleRecord with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignTypographyRoleRecord with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignVariantCoverage with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignVariantCoverage with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignVariantCoverage with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignVariantResolverRecord with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignVariantResolverRecord with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignVariantResolverRecord with ToJson::{to_json}

///|
#doc(hidden)
pub extend RuntimeTokenValue with Debug::{to_repr}

///|
#doc(hidden)
pub extend RuntimeTokenValue with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RuntimeTokenValue with ToJson::{to_json}
