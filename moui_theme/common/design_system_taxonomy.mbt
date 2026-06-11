///|
pub(all) struct DesignTokenTaxonomyRecord {
  preset : DesignPreset
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
pub fn DesignPreset::token_taxonomy_report(
  self : DesignPreset,
) -> Array[DesignTokenTaxonomyRecord] {
  [
    token_taxonomy_record(self, DesignTokenCategory::Color),
    token_taxonomy_record(self, DesignTokenCategory::Typography),
    token_taxonomy_record(self, DesignTokenCategory::Spacing),
    token_taxonomy_record(self, DesignTokenCategory::Density),
    token_taxonomy_record(self, DesignTokenCategory::Shape),
    token_taxonomy_record(self, DesignTokenCategory::Elevation),
    token_taxonomy_record(self, DesignTokenCategory::Motion),
    token_taxonomy_record(self, DesignTokenCategory::Surface),
    token_taxonomy_record(self, DesignTokenCategory::StateLayer),
    token_taxonomy_record(self, DesignTokenCategory::ComponentStyle),
  ]
}

///|
pub fn DesignPreset::token_taxonomy_for(
  self : DesignPreset,
  category : DesignTokenCategory,
) -> DesignTokenTaxonomyRecord? {
  for item in self.token_taxonomy_report() {
    if item.category == category {
      return Some(item)
    }
  }
  None
}

///|
pub fn DesignPreset::token_taxonomy_count(self : DesignPreset) -> Int {
  self.token_taxonomy_report().length()
}

///|
pub fn DesignPreset::token_taxonomy_required_count(self : DesignPreset) -> Int {
  let mut count = 0
  for item in self.token_taxonomy_report() {
    if item.required {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignPreset::token_taxonomy_mapped_count(self : DesignPreset) -> Int {
  let mut count = 0
  for item in self.token_taxonomy_report() {
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
pub fn DesignPreset::token_taxonomy_gap_count(self : DesignPreset) -> Int {
  let mut count = 0
  for item in self.token_taxonomy_report() {
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
pub fn DesignPreset::token_taxonomy_source_gap_count(
  self : DesignPreset,
) -> Int {
  let mut count = 0
  for item in self.token_taxonomy_report() {
    if item.required && (!item.source_declared || !item.source_locked) {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignPreset::token_taxonomy_official_parity_gap_count(
  self : DesignPreset,
) -> Int {
  let mut count = 0
  for item in self.token_taxonomy_report() {
    if item.required && item.remaining_gap != "none" {
      count = count + 1
    }
  }
  count
}

///|
fn token_taxonomy_record(
  preset : DesignPreset,
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
  preset : DesignPreset,
  category : DesignTokenCategory,
) -> DesignTokenCoverage {
  for item in preset.token_coverage() {
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
  preset : DesignPreset,
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
  preset : DesignPreset,
  requirement : DesignSystemRequirement,
) -> DesignTokenTaxonomySourceEvidence {
  match preset.token_group_resolver_for(requirement) {
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
  preset : DesignPreset,
) -> DesignTokenTaxonomySourceEvidence {
  match preset.density_resolver_for(DesignDensity::Standard) {
    Some(item) =>
      {
        source_declared: item.source_declared,
        source_label: item.source_label,
        source_kind: item.source_kind,
        source_ref: item.source_ref,
        token_path: item.token_path,
        source_locked: item.source_locked,
        token_surface: "DesignSpacingTokens + DesignDensity -> @core.SpacingScale",
        status: item.status,
        remaining_gap: item.remaining_gap,
      }
    None => empty_token_taxonomy_source_evidence()
  }
}

///|
fn token_taxonomy_from_component_style(
  preset : DesignPreset,
) -> DesignTokenTaxonomySourceEvidence {
  let source_gap_count = preset.component_style_resolver_source_gap_count()
  let parity_gap_count = preset.component_style_resolver_official_parity_gap_count()
  for item in preset.component_style_resolver_report() {
    return {
      source_declared: item.source_declared,
      source_label: item.source_label,
      source_kind: item.source_kind,
      source_ref: item.source_ref,
      token_path: item.token_path,
      source_locked: item.source_locked && source_gap_count == 0,
      token_surface: "DesignComponentTokens -> @core.*Style",
      status: if preset.component_style_resolver_gap_count() == 0 {
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
    Color => "DesignSemanticPalette"
    Typography => "DesignTypographyTokens"
    Spacing => "DesignSpacingTokens"
    Density => "DesignDensity"
    Shape => "DesignRadiusTokens"
    Elevation => "DesignElevationTokens"
    Motion => "DesignMotionTokens"
    Surface => "DesignSurfaceTokens"
    StateLayer => "DesignStateLayerTokens"
    ComponentStyle => "DesignComponentTokens"
    SchemeVariant => "DesignSchemeVariant"
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
    Density => "DesignDensity -> @core.SpacingScale"
    Shape => "@core.RadiusScale"
    Elevation => "@core.ShadowScale"
    Motion => "@core.MotionScale"
    Surface => "@core.SurfaceScale"
    StateLayer => "DesignStateLayerTokens -> DesignComponentTokens"
    ComponentStyle => "DesignComponentTokens -> @core.*Style"
    SchemeVariant => "DesignSchemeVariant -> @core.Theme"
    Customization => "@common.custom/custom_tokens"
  }
}
