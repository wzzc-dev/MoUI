///|
pub(all) struct DesignTokenTaxonomyRecord {
  preset : @common.DesignPreset
  category : DesignTokenCategory
  layer : DesignTokenLayer
  source_family : String
  source_declared : Bool
  source_label : String
  source_kind : String
  source_ref : String
  token_path : String
  source_locked : Bool
  token_surface : String
  moui_surface : String
  manifest_declared : Bool
  required : Bool
  status : DesignTokenStatus
  remaining_gap : String
  note : String
} derive(Eq, Debug, ToJson)

///|
priv struct DesignTokenTaxonomySourceEvidence {
  source_declared : Bool
  source_label : String
  source_kind : String
  source_ref : String
  token_path : String
  source_locked : Bool
  token_surface : String
  status : DesignTokenStatus
  remaining_gap : String
}

///|
pub fn token_taxonomy_report(
  preset : @common.DesignPreset,
) -> Array[DesignTokenTaxonomyRecord] {
  [
    token_taxonomy_record(preset, DesignTokenCategory::Color),
    token_taxonomy_record(preset, DesignTokenCategory::Typography),
    token_taxonomy_record(preset, DesignTokenCategory::Spacing),
    token_taxonomy_record(preset, DesignTokenCategory::Density),
    token_taxonomy_record(preset, DesignTokenCategory::Shape),
    token_taxonomy_record(preset, DesignTokenCategory::Elevation),
    token_taxonomy_record(preset, DesignTokenCategory::Motion),
    token_taxonomy_record(preset, DesignTokenCategory::Surface),
    token_taxonomy_record(preset, DesignTokenCategory::StateLayer),
    token_taxonomy_record(preset, DesignTokenCategory::ComponentStyle),
  ]
}

///|
pub fn token_taxonomy_for(
  preset : @common.DesignPreset,
  category : DesignTokenCategory,
) -> DesignTokenTaxonomyRecord? {
  for item in token_taxonomy_report(preset) {
    if item.category == category {
      return Some(item)
    }
  }
  None
}

///|
pub fn token_taxonomy_count(preset : @common.DesignPreset) -> Int {
  token_taxonomy_report(preset).length()
}

///|
pub fn token_taxonomy_required_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in token_taxonomy_report(preset) {
    if item.required {
      count = count + 1
    }
  }
  count
}

///|
pub fn token_taxonomy_mapped_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in token_taxonomy_report(preset) {
    if item.status != DesignTokenStatus::NotMapped &&
      item.manifest_declared &&
      item.source_declared &&
      item.source_locked {
      count = count + 1
    }
  }
  count
}

///|
pub fn token_taxonomy_gap_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in token_taxonomy_report(preset) {
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
pub fn token_taxonomy_source_gap_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in token_taxonomy_report(preset) {
    if item.required && (!item.source_declared || !item.source_locked) {
      count = count + 1
    }
  }
  count
}

///|
pub fn token_taxonomy_official_parity_gap_count(
  preset : @common.DesignPreset,
) -> Int {
  let mut count = 0
  for item in token_taxonomy_report(preset) {
    if item.required && item.remaining_gap != "none" {
      count = count + 1
    }
  }
  count
}

///|
fn token_taxonomy_record(
  preset : @common.DesignPreset,
  category : DesignTokenCategory,
) -> DesignTokenTaxonomyRecord {
  let coverage = token_taxonomy_coverage_for(preset, category)
  let evidence = token_taxonomy_source_evidence(preset, category)
  let manifest_declared = coverage.status != DesignTokenStatus::NotMapped
  let layer = if manifest_declared {
    coverage.layer
  } else {
    token_taxonomy_default_layer(category)
  }
  let source_family = if coverage.source_family == "" {
    token_taxonomy_category_label(category)
  } else {
    coverage.source_family
  }
  let moui_surface = if coverage.moui_surface == "" {
    token_taxonomy_default_moui_surface(category)
  } else {
    coverage.moui_surface
  }
  let status = token_taxonomy_status(coverage.status, evidence)
  {
    preset,
    category,
    layer,
    source_family,
    source_declared: evidence.source_declared,
    source_label: evidence.source_label,
    source_kind: evidence.source_kind,
    source_ref: evidence.source_ref,
    token_path: evidence.token_path,
    source_locked: evidence.source_locked,
    token_surface: if evidence.token_surface == "" {
      token_taxonomy_default_token_surface(category)
    } else {
      evidence.token_surface
    },
    moui_surface,
    manifest_declared,
    required: true,
    status,
    remaining_gap: token_taxonomy_remaining_gap(
      category, status, manifest_declared, evidence,
    ),
    note: if coverage.note == "" {
      "Required design-system token taxonomy row."
    } else {
      coverage.note
    },
  }
}

///|
fn token_taxonomy_coverage_for(
  preset : @common.DesignPreset,
  category : DesignTokenCategory,
) -> DesignTokenCoverage {
  for item in token_coverage(preset) {
    if item.category == category {
      return item
    }
  }
  {
    category,
    layer: token_taxonomy_default_layer(category),
    source_family: "",
    moui_surface: "",
    status: DesignTokenStatus::NotMapped,
    note: "Missing token coverage row.",
  }
}

///|
fn token_taxonomy_source_evidence(
  preset : @common.DesignPreset,
  category : DesignTokenCategory,
) -> DesignTokenTaxonomySourceEvidence {
  match category {
    Color =>
      token_taxonomy_from_token_group(
        preset,
        DesignSystemRequirement::SemanticPalette,
      )
    Typography =>
      token_taxonomy_from_token_group(
        preset,
        DesignSystemRequirement::Typography,
      )
    Spacing | Density => token_taxonomy_from_density(preset)
    Shape =>
      token_taxonomy_from_token_group(
        preset,
        DesignSystemRequirement::ShapeRadius,
      )
    Elevation =>
      token_taxonomy_from_token_group(
        preset,
        DesignSystemRequirement::ElevationShadow,
      )
    Motion =>
      token_taxonomy_from_token_group(preset, DesignSystemRequirement::Motion)
    Surface =>
      token_taxonomy_from_token_group(preset, DesignSystemRequirement::Surface)
    StateLayer =>
      token_taxonomy_from_token_group(
        preset,
        DesignSystemRequirement::StateLayer,
      )
    ComponentStyle => token_taxonomy_from_component_style(preset)
    _ => empty_token_taxonomy_source_evidence()
  }
}

///|
fn token_taxonomy_from_token_group(
  preset : @common.DesignPreset,
  requirement : DesignSystemRequirement,
) -> DesignTokenTaxonomySourceEvidence {
  match token_group_resolver_for(preset, requirement) {
    Some(item) =>
      {
        source_declared: item.source_declared,
        source_label: item.source_label,
        source_kind: item.source_kind,
        source_ref: item.source_ref,
        token_path: item.token_path,
        source_locked: item.source_locked,
        token_surface: item.token_surface,
        status: item.status,
        remaining_gap: item.remaining_gap,
      }
    None => empty_token_taxonomy_source_evidence()
  }
}

///|
fn token_taxonomy_from_density(
  preset : @common.DesignPreset,
) -> DesignTokenTaxonomySourceEvidence {
  match density_resolver_for(preset, @common.DesignDensity::Standard) {
    Some(item) =>
      {
        source_declared: item.source_declared,
        source_label: item.source_label,
        source_kind: item.source_kind,
        source_ref: item.source_ref,
        token_path: item.token_path,
        source_locked: item.source_locked,
        token_surface: "@common.DesignSpacingTokens + @common.DesignDensity -> @core.SpacingScale",
        status: item.status,
        remaining_gap: item.remaining_gap,
      }
    None => empty_token_taxonomy_source_evidence()
  }
}

///|
fn token_taxonomy_from_component_style(
  preset : @common.DesignPreset,
) -> DesignTokenTaxonomySourceEvidence {
  let source_gap_count = component_style_resolver_source_gap_count(preset)
  let parity_gap_count = component_style_resolver_official_parity_gap_count(
    preset,
  )
  for item in component_style_resolver_report(preset) {
    return {
      source_declared: item.source_declared,
      source_label: item.source_label,
      source_kind: item.source_kind,
      source_ref: item.source_ref,
      token_path: item.token_path,
      source_locked: item.source_locked && source_gap_count == 0,
      token_surface: "@common.DesignComponentTokens -> @core.*Style",
      status: if component_style_resolver_gap_count(preset) == 0 {
        DesignTokenStatus::ComponentMapped
      } else {
        DesignTokenStatus::NotMapped
      },
      remaining_gap: if parity_gap_count == 0 {
        "none"
      } else {
        "Official component token taxonomy is not fully imported for every neutral component style surface."
      },
    }
  }
  empty_token_taxonomy_source_evidence()
}

///|
fn empty_token_taxonomy_source_evidence() -> DesignTokenTaxonomySourceEvidence {
  {
    source_declared: false,
    source_label: "",
    source_kind: "",
    source_ref: "",
    token_path: "",
    source_locked: false,
    token_surface: "",
    status: DesignTokenStatus::NotMapped,
    remaining_gap: "Missing resolver evidence for this token taxonomy row.",
  }
}

///|
fn token_taxonomy_status(
  coverage_status : DesignTokenStatus,
  evidence : DesignTokenTaxonomySourceEvidence,
) -> DesignTokenStatus {
  if !evidence.source_declared || !evidence.source_locked {
    DesignTokenStatus::NotMapped
  } else if coverage_status != DesignTokenStatus::NotMapped {
    coverage_status
  } else {
    evidence.status
  }
}

///|
fn token_taxonomy_remaining_gap(
  category : DesignTokenCategory,
  status : DesignTokenStatus,
  manifest_declared : Bool,
  evidence : DesignTokenTaxonomySourceEvidence,
) -> String {
  if !manifest_declared {
    "Required token category is missing from the source-mapped manifest."
  } else if !evidence.source_declared || !evidence.source_locked {
    "Required taxonomy row is missing a declared stable source lock."
  } else if status == DesignTokenStatus::OfficialComplete {
    "none"
  } else if (
      category == DesignTokenCategory::Spacing ||
      category == DesignTokenCategory::Density
    ) &&
    evidence.remaining_gap == "none" {
    "none"
  } else if evidence.remaining_gap != "" && evidence.remaining_gap != "none" {
    evidence.remaining_gap
  } else {
    "Official " +
    token_taxonomy_category_label(category) +
    " token taxonomy is source-mapped but not fully imported."
  }
}

///|
fn token_taxonomy_category_label(category : DesignTokenCategory) -> String {
  match category {
    Color => "color"
    Typography => "typography"
    Spacing => "spacing"
    Density => "density"
    Shape => "shape"
    Elevation => "elevation"
    Motion => "motion"
    Surface => "surface"
    StateLayer => "state layer"
    SchemeVariant => "scheme variant"
    ComponentStyle => "component style"
    Customization => "customization"
  }
}

///|
fn token_taxonomy_default_layer(
  category : DesignTokenCategory,
) -> DesignTokenLayer {
  match category {
    StateLayer | ComponentStyle => DesignTokenLayer::ComponentToken
    _ => DesignTokenLayer::SystemToken
  }
}

///|
fn token_taxonomy_default_token_surface(
  category : DesignTokenCategory,
) -> String {
  match category {
    Color => "@common.DesignSemanticPalette"
    Typography => "@common.DesignTypographyTokens"
    Spacing => "@common.DesignSpacingTokens"
    Density => "@common.DesignDensity"
    Shape => "@common.DesignRadiusTokens"
    Elevation => "@common.DesignElevationTokens"
    Motion => "@common.DesignMotionTokens"
    Surface => "@common.DesignSurfaceTokens"
    StateLayer => "@common.DesignStateLayerTokens"
    ComponentStyle => "@common.DesignComponentTokens"
    SchemeVariant => "@common.DesignSchemeVariant"
    Customization => "custom_tokens/custom"
  }
}

///|
fn token_taxonomy_default_moui_surface(
  category : DesignTokenCategory,
) -> String {
  match category {
    Color => "@core.ColorPalette + @core.SemanticColorScale"
    Typography => "@core.TypographyScale"
    Spacing => "@core.SpacingScale"
    Density => "@common.DesignDensity -> @core.SpacingScale"
    Shape => "@core.RadiusScale"
    Elevation => "@core.ShadowScale"
    Motion => "@core.MotionScale"
    Surface => "@core.SurfaceScale"
    StateLayer =>
      "@common.DesignStateLayerTokens -> @common.DesignComponentTokens"
    ComponentStyle => "@common.DesignComponentTokens -> @core.*Style"
    SchemeVariant => "@common.DesignSchemeVariant -> @core.Theme"
    Customization => "@common.custom/custom_tokens"
  }
}
