///|
pub(all) struct DesignOfficialTokenAnchor {
  preset : @common.DesignPreset
  category : DesignTokenCategory
  layer : DesignTokenLayer
  official_token : String
  official_source : String
  required : Bool
  note : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignOfficialTokenCoverage {
  preset : @common.DesignPreset
  category : DesignTokenCategory
  layer : DesignTokenLayer
  official_token : String
  official_source : String
  source_declared : Bool
  source_label : String
  source_kind : String
  source_ref : String
  token_path : String
  source_locked : Bool
  required : Bool
  mapped : Bool
  moui_token : String
  status : DesignTokenStatus
  note : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignOfficialTokenSourceUsage {
  preset : @common.DesignPreset
  source_label : String
  source_url : String
  source_kind : String
  source_ref : String
  token_path : String
  source_locked : Bool
  anchor_count : Int
  mapped_anchor_count : Int
  unmapped_required_anchor_count : Int
  status : DesignTokenStatus
  note : String
} derive(Eq, Debug, ToJson)

///|
pub fn official_token_anchors(
  preset : @common.DesignPreset,
) -> Array[DesignOfficialTokenAnchor] {
  match preset {
    Material => material_official_token_anchors()
    Carbon => carbon_official_token_anchors()
    Primer => primer_official_token_anchors()
    Fluent => fluent_official_token_anchors()
  }
}

///|
pub fn official_token_coverage(
  preset : @common.DesignPreset,
) -> Array[DesignOfficialTokenCoverage] {
  let coverage : Array[DesignOfficialTokenCoverage] = []
  for anchor in official_token_anchors(preset) {
    coverage.push(official_token_coverage(preset, anchor))
  }
  coverage
}

///|
pub fn official_token_source_usage(
  preset : @common.DesignPreset,
) -> Array[DesignOfficialTokenSourceUsage] {
  let usages : Array[DesignOfficialTokenSourceUsage] = []
  let coverage = official_token_coverage(preset)
  for source in sources(preset) {
    let mut anchor_count = 0
    let mut mapped_anchor_count = 0
    let mut unmapped_required_anchor_count = 0
    for item in coverage {
      if item.official_source == source.url {
        anchor_count = anchor_count + 1
        if item.required && item.mapped {
          mapped_anchor_count = mapped_anchor_count + 1
        }
        if item.required && !item.mapped {
          unmapped_required_anchor_count = unmapped_required_anchor_count + 1
        }
      }
    }
    usages.push(
      official_token_source_usage(
        preset,
        source,
        anchor_count~,
        mapped_anchor_count~,
        unmapped_required_anchor_count~,
      ),
    )
  }
  usages
}

///|
pub fn official_token_anchor_count(preset : @common.DesignPreset) -> Int {
  official_token_anchors(preset).length()
}

///|
pub fn mapped_official_token_anchor_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in official_token_coverage(preset) {
    if item.required &&
      item.mapped &&
      (
        item.status == DesignTokenStatus::ThemeMapped ||
        item.status == DesignTokenStatus::ComponentMapped ||
        item.status == DesignTokenStatus::OfficialComplete
      ) {
      count = count + 1
    }
  }
  count
}

///|
pub fn unmapped_official_token_anchor_count(
  preset : @common.DesignPreset,
) -> Int {
  let mut count = 0
  for item in official_token_coverage(preset) {
    if item.required &&
      (
        !item.mapped ||
        item.status == DesignTokenStatus::NotMapped ||
        item.status == DesignTokenStatus::SourceMapped ||
        item.status == DesignTokenStatus::PreviewMapped
      ) {
      count = count + 1
    }
  }
  count
}

///|
pub fn golden_mappings_without_official_anchor(
  preset : @common.DesignPreset,
) -> Array[DesignTokenMapping] {
  let missing : Array[DesignTokenMapping] = []
  for mapping in golden_mappings(preset) {
    if !has_official_token_anchor(preset, mapping.official_token) {
      missing.push(mapping)
    }
  }
  missing
}

///|
pub fn unanchored_golden_mapping_count(preset : @common.DesignPreset) -> Int {
  golden_mappings_without_official_anchor(preset).length()
}

///|
pub fn official_token_anchor_source_lock_count(
  preset : @common.DesignPreset,
) -> Int {
  let mut count = 0
  for item in official_token_coverage(preset) {
    if item.required && item.source_declared && item.source_locked {
      count = count + 1
    }
  }
  count
}

///|
pub fn official_token_anchor_source_gap_count(
  preset : @common.DesignPreset,
) -> Int {
  let mut count = 0
  for item in official_token_coverage(preset) {
    if item.required && (!item.source_declared || !item.source_locked) {
      count = count + 1
    }
  }
  count
}

///|
pub fn undeclared_official_token_anchor_source_count(
  preset : @common.DesignPreset,
) -> Int {
  let mut count = 0
  for item in official_token_coverage(preset) {
    if item.required && !item.source_declared {
      count = count + 1
    }
  }
  count
}

///|
pub fn has_official_token_source_locks(preset : @common.DesignPreset) -> Bool {
  official_token_anchor_count(preset) > 0 &&
  official_token_anchor_source_gap_count(preset) == 0
}

///|
pub fn has_official_token_anchor(
  preset : @common.DesignPreset,
  official_token : String,
) -> Bool {
  preset
  .official_token_anchors()
  .any(item => item.official_token == official_token)
}

///|
pub fn official_token_coverage_for(
  preset : @common.DesignPreset,
  official_token : String,
) -> DesignOfficialTokenCoverage? {
  for item in official_token_coverage(preset) {
    if item.official_token == official_token {
      return Some(item)
    }
  }
  None
}

///|
fn official_token_coverage(
  preset : @common.DesignPreset,
  anchor : DesignOfficialTokenAnchor,
) -> DesignOfficialTokenCoverage {
  let source = official_token_source_for_url(preset, anchor.official_source)
  let (
    source_declared,
    source_label,
    source_kind,
    source_ref,
    token_path,
    source_locked,
  ) = match source {
    Some(source) =>
      (
        true,
        source.label,
        source.source_kind,
        source.source_ref,
        source.token_path,
        official_token_source_locked(source),
      )
    None => (false, "", "", "", "", false)
  }
  match golden_mapping_for(preset, anchor.official_token) {
    Some(mapping) =>
      {
        preset,
        category: anchor.category,
        layer: anchor.layer,
        official_token: anchor.official_token,
        official_source: anchor.official_source,
        source_declared,
        source_label,
        source_kind,
        source_ref,
        token_path,
        source_locked,
        required: anchor.required,
        mapped: true,
        moui_token: mapping.moui_token,
        status: mapping.status,
        note: mapping.note,
      }
    None =>
      {
        preset,
        category: anchor.category,
        layer: anchor.layer,
        official_token: anchor.official_token,
        official_source: anchor.official_source,
        source_declared,
        source_label,
        source_kind,
        source_ref,
        token_path,
        source_locked,
        required: anchor.required,
        mapped: false,
        moui_token: "",
        status: DesignTokenStatus::NotMapped,
        note: anchor.note,
      }
  }
}

///|
fn material_official_token_anchors() -> Array[DesignOfficialTokenAnchor] {
  let source = "https://material-web.dev/theming/material-theming/"
  [
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Surface,
      DesignTokenLayer::SystemToken,
      "--md-sys-color-background",
      source,
      "Material background color role.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Color,
      DesignTokenLayer::SystemToken,
      "--md-sys-color-on-surface",
      source,
      "Material on-surface color role.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Surface,
      DesignTokenLayer::SystemToken,
      "--md-sys-color-surface",
      source,
      "Material surface color role.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Surface,
      DesignTokenLayer::SystemToken,
      "--md-sys-color-surface-variant",
      source,
      "Material surface-variant color role.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Color,
      DesignTokenLayer::SystemToken,
      "--md-sys-color-outline",
      source,
      "Material outline color role.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Color,
      DesignTokenLayer::SystemToken,
      "--md-sys-color-on-surface-variant",
      source,
      "Material on-surface-variant color role.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Color,
      DesignTokenLayer::SystemToken,
      "--md-sys-color-primary",
      source,
      "Material primary color role.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Color,
      DesignTokenLayer::SystemToken,
      "--md-sys-color-on-primary",
      source,
      "Material on-primary color role.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Color,
      DesignTokenLayer::SystemToken,
      "--md-sys-color-error",
      source,
      "Material error role for validation and danger feedback.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Color,
      DesignTokenLayer::SystemToken,
      "--md-sys-color-scrim",
      source,
      "Material scrim color role.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Typography,
      DesignTokenLayer::SystemToken,
      "--md-sys-typescale-body-medium-size",
      source,
      "Material body type scale size.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Typography,
      DesignTokenLayer::SystemToken,
      "--md-sys-typescale-headline-small-size",
      source,
      "Material headline-small type scale size used by the neutral title slot.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Typography,
      DesignTokenLayer::SystemToken,
      "--md-sys-typescale-body-small-size",
      source,
      "Material body-small type scale size used by the neutral caption slot.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Typography,
      DesignTokenLayer::SystemToken,
      "--md-sys-typescale-label-large-size",
      source,
      "Material label-large type scale size used by the neutral control slot.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::SystemToken,
      "--md-sys-spacing-*",
      source,
      "Material Web's pinned token source does not expose a concrete md.sys spacing token family; spacing parity stays tracked by density resolver evidence.",
      required=false,
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Shape,
      DesignTokenLayer::SystemToken,
      "--md-sys-shape-corner-medium",
      source,
      "Material medium shape token.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Elevation,
      DesignTokenLayer::SystemToken,
      "--md-sys-elevation-level1",
      source,
      "Material level1 elevation token.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Elevation,
      DesignTokenLayer::SystemToken,
      "--md-sys-elevation-level3",
      source,
      "Material level3 elevation token.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Elevation,
      DesignTokenLayer::SystemToken,
      "--md-sys-elevation-level5",
      source,
      "Material level5 elevation token.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Motion,
      DesignTokenLayer::SystemToken,
      "--md-sys-motion-duration-short4",
      source,
      "Material short4 motion duration token.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Motion,
      DesignTokenLayer::SystemToken,
      "--md-sys-motion-duration-medium2",
      source,
      "Material medium2 motion duration token.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Motion,
      DesignTokenLayer::SystemToken,
      "--md-sys-motion-duration-medium4",
      source,
      "Material medium4 motion duration token.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Motion,
      DesignTokenLayer::SystemToken,
      "--md-sys-motion-easing-standard",
      source,
      "Material standard motion easing token.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::Motion,
      DesignTokenLayer::SystemToken,
      "--md-sys-motion-*",
      source,
      "Material motion token family remains preview-mapped until full import.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::ComponentToken,
      "--md-filled-button-container-color",
      source,
      "Material filled button container token.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::ComponentToken,
      "--md-filled-button-label-text-color",
      source,
      "Material filled button label token.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::StateLayer,
      DesignTokenLayer::ComponentToken,
      "--md-filled-button-pressed-state-layer-opacity",
      source,
      "Material filled button pressed state-layer opacity token.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::ComponentToken,
      "--md-linear-progress-active-indicator-color",
      source,
      "Material linear progress active indicator token.",
    ),
    anchor(
      @common.DesignPreset::Material,
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::ComponentToken,
      "--md-menu-container-color",
      source,
      "Material menu container token used by picker adapters.",
    ),
  ]
}

///|
fn carbon_official_token_anchors() -> Array[DesignOfficialTokenAnchor] {
  let source = "https://carbondesignsystem.com/elements/color/tokens/"
  let layout_source = "https://github.com/carbon-design-system/carbon/tree/main/packages/layout"
  let motion_source = "https://github.com/carbon-design-system/carbon/tree/main/packages/motion"
  let type_source = "https://github.com/carbon-design-system/carbon/tree/main/packages/type"
  [
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "$background",
      source,
      "Carbon background token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Surface,
      DesignTokenLayer::AliasToken,
      "$layer-01",
      source,
      "Carbon layer token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Surface,
      DesignTokenLayer::AliasToken,
      "$layer-accent-01",
      source,
      "Carbon layer accent token used as MoUI surface-variant adapter.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "$text-primary",
      source,
      "Carbon primary text token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "$text-secondary",
      source,
      "Carbon secondary text token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "$text-on-color",
      source,
      "Carbon foreground token for text on color surfaces.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "$border-strong-01",
      source,
      "Carbon strong border token used as MoUI outline adapter.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "$background-brand",
      source,
      "Carbon brand background token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "$support-error",
      source,
      "Carbon support error token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "$support-success",
      source,
      "Carbon support success token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "$support-warning",
      source,
      "Carbon support warning token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "$support-info",
      source,
      "Carbon support info token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "$focus",
      source,
      "Carbon focus token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "$overlay",
      source,
      "Carbon overlay token used as MoUI scrim adapter.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::ComponentToken,
      "$button-primary",
      source,
      "Carbon primary button token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::StateLayer,
      DesignTokenLayer::AliasToken,
      "$background-hover",
      source,
      "Carbon hover background token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::ComponentToken,
      "$border-interactive",
      source,
      "Carbon interactive border token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::ComponentToken,
      "$slider-filled-track",
      source,
      "Carbon slider filled-track token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$spacing-01",
      layout_source,
      "Carbon spacing-01 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$spacing-02",
      layout_source,
      "Carbon spacing-02 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$spacing-03",
      layout_source,
      "Carbon spacing-03 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$spacing-04",
      layout_source,
      "Carbon spacing-04 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$spacing-05",
      layout_source,
      "Carbon spacing-05 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$spacing-06",
      layout_source,
      "Carbon spacing-06 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$spacing-07",
      layout_source,
      "Carbon spacing-07 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$spacing-08",
      layout_source,
      "Carbon spacing-08 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$spacing-09",
      layout_source,
      "Carbon spacing-09 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$spacing-10",
      layout_source,
      "Carbon spacing-10 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$spacing-11",
      layout_source,
      "Carbon spacing-11 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$spacing-12",
      layout_source,
      "Carbon spacing-12 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$spacing-13",
      layout_source,
      "Carbon spacing-13 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$layout-01",
      layout_source,
      "Carbon layout-01 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$layout-02",
      layout_source,
      "Carbon layout-02 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$layout-03",
      layout_source,
      "Carbon layout-03 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$layout-04",
      layout_source,
      "Carbon layout-04 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$layout-05",
      layout_source,
      "Carbon layout-05 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$layout-06",
      layout_source,
      "Carbon layout-06 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$layout-07",
      layout_source,
      "Carbon layout-07 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$container-01",
      layout_source,
      "Carbon container-01 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$container-02",
      layout_source,
      "Carbon container-02 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$container-03",
      layout_source,
      "Carbon container-03 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$container-04",
      layout_source,
      "Carbon container-04 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "$container-05",
      layout_source,
      "Carbon container-05 token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "$duration-fast-01",
      motion_source,
      "Carbon fast-01 duration token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "$duration-fast-02",
      motion_source,
      "Carbon fast-02 duration token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "$duration-moderate-01",
      motion_source,
      "Carbon moderate-01 duration token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "$duration-moderate-02",
      motion_source,
      "Carbon moderate-02 duration token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "$duration-slow-01",
      motion_source,
      "Carbon slow-01 duration token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "$duration-slow-02",
      motion_source,
      "Carbon slow-02 duration token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "easings.standard.productive",
      motion_source,
      "Carbon productive standard easing token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "easings.standard.expressive",
      motion_source,
      "Carbon expressive standard easing token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "easings.entrance.productive",
      motion_source,
      "Carbon productive entrance easing token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "easings.entrance.expressive",
      motion_source,
      "Carbon expressive entrance easing token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "easings.exit.productive",
      motion_source,
      "Carbon productive exit easing token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "easings.exit.expressive",
      motion_source,
      "Carbon expressive exit easing token.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "Carbon motion token family",
      motion_source,
      "Carbon motion family remains preview-mapped until full import.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "$body-02",
      type_source,
      "Carbon body-02 type style used by the neutral body slot.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "$productive-heading-03",
      type_source,
      "Carbon productive-heading-03 type style used by the neutral title slot.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "$caption-01",
      type_source,
      "Carbon caption-01 type style used by the neutral caption slot.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "$label-02",
      type_source,
      "Carbon label-02 type style used by the neutral control slot.",
    ),
    anchor(
      @common.DesignPreset::Carbon,
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::AliasToken,
      "$field",
      source,
      "Carbon field token used by picker adapters.",
    ),
  ]
}

///|
fn primer_official_token_anchors() -> Array[DesignOfficialTokenAnchor] {
  let source = "https://primer.style/product/primitives/color/"
  let primitives_source = "https://primer.style/primitives/"
  [
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "--fgColor-default",
      source,
      "Primer default foreground token.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "--fgColor-muted",
      source,
      "Primer muted foreground token.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "--fgColor-accent",
      source,
      "Primer accent foreground token used by informational text.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Surface,
      DesignTokenLayer::AliasToken,
      "--bgColor-accent-emphasis",
      source,
      "Primer emphasized accent background token used as MoUI primary adapter.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "--fgColor-onEmphasis",
      source,
      "Primer foreground token used on emphasis fills.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "--fgColor-danger",
      source,
      "Primer danger foreground token.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "--fgColor-success",
      source,
      "Primer success foreground token.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "--fgColor-attention",
      source,
      "Primer attention foreground token used as MoUI warning adapter.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Surface,
      DesignTokenLayer::AliasToken,
      "--bgColor-default",
      source,
      "Primer default background token.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Surface,
      DesignTokenLayer::AliasToken,
      "--bgColor-muted",
      source,
      "Primer muted background token.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Surface,
      DesignTokenLayer::AliasToken,
      "--bgColor-inset",
      source,
      "Primer inset background token.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "--borderColor-default",
      source,
      "Primer default border token.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "--borderColor-accent-emphasis",
      source,
      "Primer emphasized accent border token used for selected/focused elements.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::ComponentToken,
      "--overlay-backdrop-bgColor",
      source,
      "Primer overlay backdrop background token used as MoUI scrim adapter.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::ComponentToken,
      "--button-primary-bgColor-rest",
      source,
      "Primer primary button background token.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::StateLayer,
      DesignTokenLayer::ComponentToken,
      "--control-transparent-bgColor-hover",
      source,
      "Primer transparent control hover token.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::ComponentToken,
      "--control-borderColor-emphasis",
      source,
      "Primer emphasized control border token.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::ComponentToken,
      "--progressBar-fgColor-accent",
      source,
      "Primer progress bar accent token.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::ReferenceToken,
      "--base-size-4",
      primitives_source,
      "Primer 4px base size primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::ReferenceToken,
      "--base-size-8",
      primitives_source,
      "Primer 8px base size primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::ReferenceToken,
      "--base-size-12",
      primitives_source,
      "Primer 12px base size primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::ReferenceToken,
      "--base-size-16",
      primitives_source,
      "Primer 16px base size primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::ReferenceToken,
      "--base-size-24",
      primitives_source,
      "Primer 24px base size primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Typography,
      DesignTokenLayer::ReferenceToken,
      "--base-text-size-xs",
      primitives_source,
      "Primer 12px extra-small text size primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Typography,
      DesignTokenLayer::ReferenceToken,
      "--base-text-size-sm",
      primitives_source,
      "Primer 14px small/default body text size primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Typography,
      DesignTokenLayer::ReferenceToken,
      "--base-text-size-lg",
      primitives_source,
      "Primer 20px large title text size primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Typography,
      DesignTokenLayer::ReferenceToken,
      "--base-text-weight-normal",
      primitives_source,
      "Primer normal text weight primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Typography,
      DesignTokenLayer::ReferenceToken,
      "--base-text-weight-semibold",
      primitives_source,
      "Primer semibold text weight primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Shape,
      DesignTokenLayer::AliasToken,
      "--borderRadius-small",
      primitives_source,
      "Primer small border-radius token.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Shape,
      DesignTokenLayer::AliasToken,
      "--borderRadius-medium",
      primitives_source,
      "Primer medium border-radius token.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Shape,
      DesignTokenLayer::AliasToken,
      "--borderRadius-large",
      primitives_source,
      "Primer large border-radius token.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Shape,
      DesignTokenLayer::AliasToken,
      "--borderRadius-full",
      primitives_source,
      "Primer full border-radius token.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Shape,
      DesignTokenLayer::AliasToken,
      "--borderRadius-default",
      primitives_source,
      "Primer default border-radius alias.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Elevation,
      DesignTokenLayer::AliasToken,
      "--shadow-resting-small",
      primitives_source,
      "Primer small resting shadow token.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Elevation,
      DesignTokenLayer::AliasToken,
      "--shadow-resting-medium",
      primitives_source,
      "Primer medium resting shadow token.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Elevation,
      DesignTokenLayer::AliasToken,
      "--shadow-floating-large",
      primitives_source,
      "Primer large floating shadow token.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "--base-duration-0",
      primitives_source,
      "Primer 0ms duration primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "--base-duration-50",
      primitives_source,
      "Primer 50ms duration primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "--base-duration-100",
      primitives_source,
      "Primer 100ms duration primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "--base-duration-200",
      primitives_source,
      "Primer 200ms duration primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "--base-duration-300",
      primitives_source,
      "Primer 300ms duration primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "--base-duration-400",
      primitives_source,
      "Primer 400ms duration primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "--base-duration-500",
      primitives_source,
      "Primer 500ms duration primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "--base-duration-600",
      primitives_source,
      "Primer 600ms duration primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "--base-duration-700",
      primitives_source,
      "Primer 700ms duration primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "--base-duration-800",
      primitives_source,
      "Primer 800ms duration primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "--base-duration-900",
      primitives_source,
      "Primer 900ms duration primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "--base-duration-1000",
      primitives_source,
      "Primer 1000ms duration primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "--base-easing-linear",
      primitives_source,
      "Primer linear cubic-bezier primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "--base-easing-ease",
      primitives_source,
      "Primer CSS default ease cubic-bezier primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "--base-easing-easeIn",
      primitives_source,
      "Primer easeIn cubic-bezier primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "--base-easing-easeOut",
      primitives_source,
      "Primer easeOut cubic-bezier primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "--base-easing-easeInOut",
      primitives_source,
      "Primer easeInOut cubic-bezier primitive.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "Primer animation token family",
      source,
      "Primer animation family remains preview-mapped until full import.",
    ),
    anchor(
      @common.DesignPreset::Primer,
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::ComponentToken,
      "--control-bgColor-rest",
      source,
      "Primer rest control background token used by picker adapters.",
    ),
  ]
}

///|
fn fluent_official_token_anchors() -> Array[DesignOfficialTokenAnchor] {
  let source = "https://fluent2.microsoft.design/design-tokens"
  let component_source = "https://github.com/microsoft/fluentui/tree/master/packages/web-components"
  [
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "colorNeutralForeground1",
      source,
      "Fluent primary foreground alias.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "colorNeutralForeground3",
      source,
      "Fluent secondary foreground alias.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Surface,
      DesignTokenLayer::AliasToken,
      "colorNeutralBackground1",
      source,
      "Fluent neutral background alias.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Surface,
      DesignTokenLayer::AliasToken,
      "colorNeutralBackground2",
      source,
      "Fluent secondary neutral background alias.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Surface,
      DesignTokenLayer::AliasToken,
      "colorNeutralBackground3",
      source,
      "Fluent tertiary neutral background alias.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "colorNeutralStroke1",
      source,
      "Fluent neutral stroke alias.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "colorBrandBackground",
      source,
      "Fluent brand background alias.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "colorNeutralForegroundOnBrand",
      source,
      "Fluent foreground alias for text on brand backgrounds.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "colorBackgroundOverlay",
      source,
      "Fluent overlay background alias used as MoUI scrim adapter.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      "colorStrokeFocus2",
      source,
      "Fluent focus stroke alias used as MoUI focus adapter.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Color,
      DesignTokenLayer::ReferenceToken,
      "red.primary",
      source,
      "Fluent global red primary reference color for danger-like status roles.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Color,
      DesignTokenLayer::ReferenceToken,
      "green.primary",
      source,
      "Fluent global green primary reference color for success-like status roles.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Color,
      DesignTokenLayer::ReferenceToken,
      "lightGreen.primary",
      source,
      "Fluent global light-green primary reference color for success-like status roles.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Color,
      DesignTokenLayer::ReferenceToken,
      "cranberry.primary",
      source,
      "Fluent global cranberry primary reference color for danger-like status roles.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Color,
      DesignTokenLayer::ReferenceToken,
      "darkOrange.primary",
      source,
      "Fluent global dark-orange primary reference color for warning-like status roles.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Color,
      DesignTokenLayer::ReferenceToken,
      "orange.primary",
      source,
      "Fluent global orange primary reference color for warning-like status roles.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Color,
      DesignTokenLayer::ReferenceToken,
      "yellow.primary",
      source,
      "Fluent global yellow primary reference color for warning-like status roles.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Color,
      DesignTokenLayer::ReferenceToken,
      "marigold.primary",
      source,
      "Fluent global marigold primary reference color for warning-like status roles.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Color,
      DesignTokenLayer::ReferenceToken,
      "blue.primary",
      source,
      "Fluent global blue primary reference color for info-like status roles.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "fontSizeBase100",
      source,
      "Fluent base 100 type ramp token; exact MoUI caption parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "fontSizeBase200",
      source,
      "Fluent caption-size type ramp token.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "fontSizeBase300",
      source,
      "Fluent base type ramp token.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "fontSizeBase400",
      source,
      "Fluent base 400 type ramp token; exact neutral control parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "fontSizeBase500",
      source,
      "Fluent title-size type ramp token; exact MoUI title size remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "fontSizeBase600",
      source,
      "Fluent base 600 type ramp token; exact neutral title parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "fontSizeHero700",
      source,
      "Fluent hero 700 type ramp token; exact neutral title parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "fontSizeHero800",
      source,
      "Fluent hero 800 type ramp token; exact neutral title parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "fontSizeHero900",
      source,
      "Fluent hero 900 type ramp token; exact neutral title parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "fontSizeHero1000",
      source,
      "Fluent hero 1000 type ramp token; exact neutral title parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "lineHeightBase100",
      source,
      "Fluent base 100 line-height token; neutral line-height support remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "lineHeightBase200",
      source,
      "Fluent base 200 line-height token; neutral line-height support remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "lineHeightBase300",
      source,
      "Fluent base 300 line-height token; neutral line-height support remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "lineHeightBase400",
      source,
      "Fluent base 400 line-height token; neutral line-height support remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "lineHeightBase500",
      source,
      "Fluent base 500 line-height token; neutral line-height support remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "lineHeightBase600",
      source,
      "Fluent base 600 line-height token; neutral line-height support remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "lineHeightHero700",
      source,
      "Fluent hero 700 line-height token; neutral line-height support remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "lineHeightHero800",
      source,
      "Fluent hero 800 line-height token; neutral line-height support remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "lineHeightHero900",
      source,
      "Fluent hero 900 line-height token; neutral line-height support remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "lineHeightHero1000",
      source,
      "Fluent hero 1000 line-height token; neutral line-height support remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "fontWeightRegular",
      source,
      "Fluent regular font-weight token.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "fontWeightMedium",
      source,
      "Fluent medium font-weight token; exact neutral control parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "fontWeightSemibold",
      source,
      "Fluent semibold font-weight token.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "fontWeightBold",
      source,
      "Fluent bold font-weight token.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "fontFamilyBase",
      source,
      "Fluent base font-family stack; exact neutral font-family parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "fontFamilyMonospace",
      source,
      "Fluent monospace font-family stack; dedicated neutral monospace slot remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      "fontFamilyNumeric",
      source,
      "Fluent numeric font-family stack; dedicated neutral numeric slot remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::AliasToken,
      "strokeWidthThin",
      source,
      "Fluent thin stroke-width token.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::AliasToken,
      "strokeWidthThick",
      source,
      "Fluent thick stroke-width token.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::AliasToken,
      "strokeWidthThicker",
      source,
      "Fluent thicker stroke-width token; exact neutral stroke parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::AliasToken,
      "strokeWidthThickest",
      source,
      "Fluent thickest stroke-width token; exact neutral stroke parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Shape,
      DesignTokenLayer::AliasToken,
      "borderRadiusNone",
      source,
      "Fluent zero border radius token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Shape,
      DesignTokenLayer::AliasToken,
      "borderRadiusMedium",
      source,
      "Fluent medium border radius token.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Shape,
      DesignTokenLayer::AliasToken,
      "borderRadiusSmall",
      source,
      "Fluent small border radius token.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Shape,
      DesignTokenLayer::AliasToken,
      "borderRadiusLarge",
      source,
      "Fluent large border radius token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Shape,
      DesignTokenLayer::AliasToken,
      "borderRadiusXLarge",
      source,
      "Fluent extra-large border radius token.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Shape,
      DesignTokenLayer::AliasToken,
      "borderRadius2XLarge",
      source,
      "Fluent 2XL border radius token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Shape,
      DesignTokenLayer::AliasToken,
      "borderRadius3XLarge",
      source,
      "Fluent 3XL border radius token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Shape,
      DesignTokenLayer::AliasToken,
      "borderRadius4XLarge",
      source,
      "Fluent 4XL border radius token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Shape,
      DesignTokenLayer::AliasToken,
      "borderRadius5XLarge",
      source,
      "Fluent 5XL border radius token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Shape,
      DesignTokenLayer::AliasToken,
      "borderRadius6XLarge",
      source,
      "Fluent 6XL border radius token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Shape,
      DesignTokenLayer::AliasToken,
      "borderRadiusCircular",
      source,
      "Fluent circular radius token; MoUI uses a neutral pill sentinel.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::ComponentToken,
      "colorCompoundBrandBackground",
      source,
      "Fluent compound brand background token.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::StateLayer,
      DesignTokenLayer::AliasToken,
      "colorNeutralBackground1Hover",
      source,
      "Fluent neutral hover background alias.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::ComponentToken,
      "ProgressBar.indicator.backgroundColor",
      component_source,
      "Fluent progress bar indicator background component rule.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "durationUltraFast",
      source,
      "Fluent ultra-fast duration token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "durationFaster",
      source,
      "Fluent faster duration token used by the neutral fast motion slot.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "durationFast",
      source,
      "Fluent fast duration token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "durationNormal",
      source,
      "Fluent normal duration token.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "durationGentle",
      source,
      "Fluent gentle duration token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "durationSlow",
      source,
      "Fluent slow duration token used by the neutral slow motion slot.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "durationSlower",
      source,
      "Fluent slower duration token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "durationUltraSlow",
      source,
      "Fluent ultra-slow duration token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "spacingHorizontalNone",
      source,
      "Fluent zero horizontal spacing token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "spacingHorizontalXXS",
      source,
      "Fluent extra-extra-small horizontal spacing token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "spacingHorizontalM",
      source,
      "Fluent medium horizontal spacing token.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "spacingHorizontalXS",
      source,
      "Fluent extra-small horizontal spacing token.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "spacingHorizontalSNudge",
      source,
      "Fluent small nudge horizontal spacing token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "spacingHorizontalS",
      source,
      "Fluent small horizontal spacing token.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "spacingHorizontalMNudge",
      source,
      "Fluent medium nudge horizontal spacing token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "spacingHorizontalL",
      source,
      "Fluent large horizontal spacing token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "spacingHorizontalXL",
      source,
      "Fluent extra-large horizontal spacing token.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "spacingHorizontalXXL",
      source,
      "Fluent extra-extra-large horizontal spacing token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "spacingHorizontalXXXL",
      source,
      "Fluent extra-extra-extra-large horizontal spacing token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "spacingVerticalNone",
      source,
      "Fluent zero vertical spacing token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "spacingVerticalXXS",
      source,
      "Fluent extra-extra-small vertical spacing token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "spacingVerticalXS",
      source,
      "Fluent extra-small vertical spacing token.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "spacingVerticalSNudge",
      source,
      "Fluent small nudge vertical spacing token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "spacingVerticalS",
      source,
      "Fluent small vertical spacing token.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "spacingVerticalMNudge",
      source,
      "Fluent medium nudge vertical spacing token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "spacingVerticalM",
      source,
      "Fluent medium vertical spacing token.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "spacingVerticalL",
      source,
      "Fluent large vertical spacing token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "spacingVerticalXL",
      source,
      "Fluent extra-large vertical spacing token.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "spacingVerticalXXL",
      source,
      "Fluent extra-extra-large vertical spacing token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      "spacingVerticalXXXL",
      source,
      "Fluent extra-extra-extra-large vertical spacing token; exact neutral parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "curveAccelerateMax",
      source,
      "Fluent maximum acceleration curve token; exact runtime parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "curveAccelerateMid",
      source,
      "Fluent medium acceleration curve token; exact runtime parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "curveAccelerateMin",
      source,
      "Fluent minimum acceleration curve token; exact runtime parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "curveDecelerateMax",
      source,
      "Fluent maximum deceleration curve token; exact runtime parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "curveDecelerateMid",
      source,
      "Fluent medium deceleration curve token; exact runtime parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "curveDecelerateMin",
      source,
      "Fluent minimum deceleration curve token; exact runtime parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "curveEasyEaseMax",
      source,
      "Fluent maximum easy-ease curve token; exact runtime parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "curveEasyEase",
      source,
      "Fluent easy-ease curve token; exact runtime parity remains preview.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      "curveLinear",
      source,
      "Fluent linear curve token; exact runtime parity remains preview.",
    ),
    // Fluent 2 shadow tiers (shadow2/4/8/16/28/64). These are the first
    // Fluent elevation anchors; the alias ramp is the official source of truth
    // for layered card/flyout/dialog depth.
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Elevation,
      DesignTokenLayer::AliasToken,
      "shadow4",
      source,
      "Fluent shadow4 alias declares the two-layer resting card shadow; MoUI maps the key layer to the Fluent card elevation tier.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Elevation,
      DesignTokenLayer::AliasToken,
      "shadow16",
      source,
      "Fluent shadow16 alias declares the two-layer flyout/menu shadow; MoUI maps the key layer to the Fluent flyout elevation tier.",
    ),
    anchor(
      @common.DesignPreset::Fluent,
      DesignTokenCategory::Elevation,
      DesignTokenLayer::AliasToken,
      "shadow64",
      source,
      "Fluent shadow64 alias declares the two-layer dialog/modal shadow; MoUI maps the key layer to the Fluent dialog elevation tier.",
    ),
  ]
}

///|
fn anchor(
  preset : @common.DesignPreset,
  category : DesignTokenCategory,
  layer : DesignTokenLayer,
  official_token : String,
  official_source : String,
  note : String,
  required? : Bool = true,
) -> DesignOfficialTokenAnchor {
  { preset, category, layer, official_token, official_source, required, note }
}

///|
fn official_token_source_for_url(
  preset : @common.DesignPreset,
  url : String,
) -> DesignSystemSource? {
  for source in sources(preset) {
    if source.url == url {
      return Some(source)
    }
  }
  None
}

///|
fn official_token_source_locked(source : DesignSystemSource) -> Bool {
  if source.status == DesignTokenStatus::NotMapped || source.source_ref == "" {
    false
  } else if source.source_kind == "official-source" ||
    source.source_kind == "internal-token-contract" ||
    source.source_kind == "internal-component-adapter" {
    source.token_path != ""
  } else {
    true
  }
}

///|
fn official_token_source_usage(
  preset : @common.DesignPreset,
  source : DesignSystemSource,
  anchor_count~ : Int,
  mapped_anchor_count~ : Int,
  unmapped_required_anchor_count~ : Int,
) -> DesignOfficialTokenSourceUsage {
  let source_locked = official_token_source_locked(source)
  let status = if anchor_count == 0 {
    DesignTokenStatus::NotMapped
  } else if !source_locked {
    DesignTokenStatus::SourceMapped
  } else if unmapped_required_anchor_count == 0 {
    DesignTokenStatus::ThemeMapped
  } else if mapped_anchor_count > 0 {
    DesignTokenStatus::PreviewMapped
  } else {
    DesignTokenStatus::NotMapped
  }
  {
    preset,
    source_label: source.label,
    source_url: source.url,
    source_kind: source.source_kind,
    source_ref: source.source_ref,
    token_path: source.token_path,
    source_locked,
    anchor_count,
    mapped_anchor_count,
    unmapped_required_anchor_count,
    status,
    note: if anchor_count == 0 {
      "No official token anchors cite this source yet."
    } else if !source_locked {
      "Official token anchors cite this source, but its source_ref/token_path lock is incomplete."
    } else {
      anchor_count.to_string() +
      " official token anchors cite this locked source."
    },
  }
}
