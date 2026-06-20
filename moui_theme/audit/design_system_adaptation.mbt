///|
pub(all) enum DesignAdaptationKind {
  DirectRoleMapping
  CollapsedRoleMatrix
  Approximation
  PendingOfficialImport
  UnsupportedOfficialFeature
  CustomizableOverride
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignAdaptationRecord {
  preset : @common.DesignPreset
  kind : DesignAdaptationKind
  category : DesignTokenCategory
  official_scope : String
  official_source : String
  source_declared : Bool
  source_label : String
  source_kind : String
  source_ref : String
  token_path : String
  source_locked : Bool
  moui_surface : String
  status : DesignTokenStatus
  difference : String
  remaining_gap : String
} derive(Eq, Debug, ToJson)

///|
pub fn DesignAdaptationKind::label(preset : DesignAdaptationKind) -> String {
  match preset {
    DirectRoleMapping => "direct role mapping"
    CollapsedRoleMatrix => "collapsed role matrix"
    Approximation => "approximation"
    PendingOfficialImport => "pending official import"
    UnsupportedOfficialFeature => "unsupported official feature"
    CustomizableOverride => "customizable override"
  }
}

///|
pub fn adaptation_report(
  preset : @common.DesignPreset,
) -> Array[DesignAdaptationRecord] {
  match preset {
    Material => material_adaptation_report()
    Carbon => carbon_adaptation_report()
    Primer => primer_adaptation_report()
    Fluent => fluent_adaptation_report()
  }
}

///|
pub fn adaptation_report_for(
  preset : @common.DesignPreset,
  official_scope : String,
) -> DesignAdaptationRecord? {
  for item in adaptation_report(preset) {
    if item.official_scope == official_scope {
      return Some(item)
    }
  }
  None
}

///|
pub fn adaptation_record_count(preset : @common.DesignPreset) -> Int {
  adaptation_report(preset).length()
}

///|
pub fn aligned_adaptation_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in adaptation_report(preset) {
    if item.status == DesignTokenStatus::ThemeMapped ||
      item.status == DesignTokenStatus::ComponentMapped ||
      item.status == DesignTokenStatus::OfficialComplete {
      count = count + 1
    }
  }
  count
}

///|
pub fn adaptation_gap_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in adaptation_report(preset) {
    if item.status == DesignTokenStatus::NotMapped ||
      item.status == DesignTokenStatus::SourceMapped ||
      item.status == DesignTokenStatus::PreviewMapped {
      count = count + 1
    }
  }
  count
}

///|
pub fn adaptation_source_lock_gap_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in adaptation_report(preset) {
    if !item.source_declared || !item.source_locked {
      count = count + 1
    }
  }
  count
}

///|
pub fn undeclared_adaptation_source_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in adaptation_report(preset) {
    if !item.source_declared {
      count = count + 1
    }
  }
  count
}

///|
fn material_adaptation_report() -> Array[DesignAdaptationRecord] {
  let source = "https://material-web.dev/theming/material-theming/"
  [
    adaptation(
      @common.DesignPreset::Material,
      DesignAdaptationKind::CollapsedRoleMatrix,
      DesignTokenCategory::Color,
      "Material sys color roles",
      source,
      "DesignSemanticPalette + @core.ColorPalette",
      DesignTokenStatus::PreviewMapped,
      "Primary, on-primary, and error roles map into MoUI semantic slots; the full secondary, tertiary, inverse, and surface-container matrix is collapsed.",
      "Generated Material scheme import and full role matrix are pending.",
    ),
    adaptation(
      @common.DesignPreset::Material,
      DesignAdaptationKind::PendingOfficialImport,
      DesignTokenCategory::Color,
      "Material dynamic color generation",
      source,
      "DesignPreset::tokens",
      DesignTokenStatus::SourceMapped,
      "MoUI exposes static Material preview tokens rather than generating a full scheme from a seed color.",
      "Seed-color generation and source-locked generated token import are pending.",
    ),
    adaptation(
      @common.DesignPreset::Material,
      DesignAdaptationKind::CollapsedRoleMatrix,
      DesignTokenCategory::Typography,
      "Material type scale",
      source,
      "DesignTypographyTokens",
      DesignTokenStatus::PreviewMapped,
      "MoUI collapses the Material type scale into body, title, caption, and control slots.",
      "Complete display/headline/title/body/label token import is pending.",
    ),
    adaptation(
      @common.DesignPreset::Material,
      DesignAdaptationKind::Approximation,
      DesignTokenCategory::Elevation,
      "Material tonal elevation",
      source,
      "DesignElevationTokens",
      DesignTokenStatus::PreviewMapped,
      "MoUI approximates elevation with shadows and surface colors.",
      "Tonal elevation overlays and level-specific Material roles are pending.",
    ),
    adaptation(
      @common.DesignPreset::Material,
      DesignAdaptationKind::DirectRoleMapping,
      DesignTokenCategory::StateLayer,
      "Material state-layer opacity",
      source,
      "DesignStateLayerTokens",
      DesignTokenStatus::ComponentMapped,
      "Shared hover, focus, pressed, dragged, selected, and disabled opacity slots exist.",
      "Component-specific state-layer matrices are pending.",
    ),
    adaptation(
      @common.DesignPreset::Material,
      DesignAdaptationKind::CollapsedRoleMatrix,
      DesignTokenCategory::ComponentStyle,
      "Material component tokens",
      source,
      "DesignComponentTokens",
      DesignTokenStatus::ComponentMapped,
      "Representative button, input, progress, picker, feedback, badge, and validation tokens map to neutral component styles.",
      "The full Material component token matrix is pending.",
    ),
    adaptation(
      @common.DesignPreset::Material,
      DesignAdaptationKind::CustomizableOverride,
      DesignTokenCategory::Customization,
      "Material theme customization",
      source,
      "@common.custom_tokens",
      DesignTokenStatus::ThemeMapped,
      "Users can inherit Material preview tokens and override token groups.",
      "Material-specific builders for generated schemes are pending.",
    ),
  ]
}

///|
fn carbon_adaptation_report() -> Array[DesignAdaptationRecord] {
  let source = "https://carbondesignsystem.com/elements/themes/code/"
  [
    adaptation(
      @common.DesignPreset::Carbon,
      DesignAdaptationKind::CollapsedRoleMatrix,
      DesignTokenCategory::SchemeVariant,
      "Carbon white/g10/g90/g100 themes",
      source,
      "DesignSchemeVariant",
      DesignTokenStatus::PreviewMapped,
      "MoUI maps Carbon theme families into light, dark, high-contrast, and system variants.",
      "Exact white/g10/g90/g100 generated token sets are pending.",
    ),
    adaptation(
      @common.DesignPreset::Carbon,
      DesignAdaptationKind::DirectRoleMapping,
      DesignTokenCategory::Color,
      "Carbon background/layer/text/support roles",
      source,
      "DesignSemanticPalette + @core.SemanticColorScale",
      DesignTokenStatus::ThemeMapped,
      "Background, layer, text, brand, support-error, and support-success roles map into semantic slots.",
      "The complete Carbon role matrix is pending.",
    ),
    adaptation(
      @common.DesignPreset::Carbon,
      DesignAdaptationKind::Approximation,
      DesignTokenCategory::Spacing,
      "Carbon spacing and density",
      source,
      "DesignSpacingTokens + @common.DesignDensity",
      DesignTokenStatus::PreviewMapped,
      "MoUI adapts Carbon density into compact, standard, and comfortable spacing multipliers.",
      "Productive/expressive size matrices and component density overrides are pending.",
    ),
    adaptation(
      @common.DesignPreset::Carbon,
      DesignAdaptationKind::Approximation,
      DesignTokenCategory::Elevation,
      "Carbon layer and shadow tokens",
      source,
      "DesignSurfaceTokens + @common.DesignElevationTokens",
      DesignTokenStatus::PreviewMapped,
      "MoUI maps layer-like surfaces and shadows into neutral surface/elevation slots.",
      "Complete Carbon layer stack and shadow token import is pending.",
    ),
    adaptation(
      @common.DesignPreset::Carbon,
      DesignAdaptationKind::PendingOfficialImport,
      DesignTokenCategory::Motion,
      "Carbon motion tokens",
      source,
      "DesignMotionTokens",
      DesignTokenStatus::PreviewMapped,
      "Carbon duration/easing tokens are imported, but MoUI collapses them into three neutral duration slots and one easing enum.",
      "A richer neutral motion model is pending.",
    ),
    adaptation(
      @common.DesignPreset::Carbon,
      DesignAdaptationKind::CollapsedRoleMatrix,
      DesignTokenCategory::ComponentStyle,
      "Carbon component tokens",
      source,
      "DesignComponentTokens",
      DesignTokenStatus::ComponentMapped,
      "Button, field, slider, feedback, badge, and validation mappings target neutral component style structs.",
      "The full Carbon component token matrix is pending.",
    ),
    adaptation(
      @common.DesignPreset::Carbon,
      DesignAdaptationKind::CustomizableOverride,
      DesignTokenCategory::Customization,
      "Carbon custom themes",
      source,
      "@common.custom_tokens",
      DesignTokenStatus::ThemeMapped,
      "Users can inherit Carbon preview tokens and override token groups.",
      "Carbon-specific custom theme validation is pending.",
    ),
  ]
}

///|
fn primer_adaptation_report() -> Array[DesignAdaptationRecord] {
  let source = "https://primer.style/product/primitives/color/"
  [
    adaptation(
      @common.DesignPreset::Primer,
      DesignAdaptationKind::CollapsedRoleMatrix,
      DesignTokenCategory::SchemeVariant,
      "Primer color modes and accessibility themes",
      source,
      "DesignSchemeVariant",
      DesignTokenStatus::PreviewMapped,
      "MoUI collapses Primer light, dark, colorblind, and high-contrast modes into light, dark, high-contrast, and system variants.",
      "Exact Primer mode matrix and mode-specific overrides are pending.",
    ),
    adaptation(
      @common.DesignPreset::Primer,
      DesignAdaptationKind::DirectRoleMapping,
      DesignTokenCategory::Color,
      "Primer fg/bg/border/status roles",
      source,
      "DesignSemanticPalette + @core.SemanticColorScale",
      DesignTokenStatus::ThemeMapped,
      "Foreground, background, border, accent, danger, and success roles map into MoUI semantic slots.",
      "The full Primer primitive color matrix is pending.",
    ),
    adaptation(
      @common.DesignPreset::Primer,
      DesignAdaptationKind::Approximation,
      DesignTokenCategory::Spacing,
      "Primer size and spacing primitives",
      source,
      "DesignSpacingTokens + @common.DesignDensity",
      DesignTokenStatus::PreviewMapped,
      "MoUI imports the five neutral Primer base-size representatives and applies density multipliers through five spacing slots.",
      "Remaining Primer size primitives, negative sizes, z-index, and typography imports are pending.",
    ),
    adaptation(
      @common.DesignPreset::Primer,
      DesignAdaptationKind::Approximation,
      DesignTokenCategory::Typography,
      "Primer typography primitives",
      source,
      "DesignTypographyTokens",
      DesignTokenStatus::PreviewMapped,
      "MoUI imports representative Primer text sizes and weights for caption, body, title, and control slots.",
      "Remaining Primer text sizes, line-height, font-family, and exact title weight coverage are pending.",
    ),
    adaptation(
      @common.DesignPreset::Primer,
      DesignAdaptationKind::Approximation,
      DesignTokenCategory::Shape,
      "Primer borderRadius primitives",
      source,
      "DesignRadiusTokens",
      DesignTokenStatus::PreviewMapped,
      "MoUI imports Primer borderRadius medium/default directly and maps small, large, and full into neutral radius slots.",
      "Exact Primer small, large, and full radius parity plus component-specific radius overrides remain pending.",
    ),
    adaptation(
      @common.DesignPreset::Primer,
      DesignAdaptationKind::Approximation,
      DesignTokenCategory::Elevation,
      "Primer shadow primitives",
      source,
      "DesignElevationTokens",
      DesignTokenStatus::PreviewMapped,
      "MoUI imports representative Primer resting small, resting medium, and floating large shadows into neutral elevation slots.",
      "Exact multi-layer shadow parity, mode overrides, high-contrast variants, inset shadows, and remaining floating/resting levels remain pending.",
    ),
    adaptation(
      @common.DesignPreset::Primer,
      DesignAdaptationKind::PendingOfficialImport,
      DesignTokenCategory::Motion,
      "Primer animation primitives",
      source,
      "DesignMotionTokens",
      DesignTokenStatus::PreviewMapped,
      "MoUI imports Primer base duration/easing primitives but collapses them into three neutral duration slots and one easing enum.",
      "A richer neutral motion model and full animation-family parity are pending.",
    ),
    adaptation(
      @common.DesignPreset::Primer,
      DesignAdaptationKind::CollapsedRoleMatrix,
      DesignTokenCategory::ComponentStyle,
      "Primer control tokens",
      source,
      "DesignComponentTokens",
      DesignTokenStatus::ComponentMapped,
      "Control, button, progress, picker, feedback, badge, and validation mappings target neutral component styles.",
      "The complete Primer component token matrix is pending.",
    ),
    adaptation(
      @common.DesignPreset::Primer,
      DesignAdaptationKind::CustomizableOverride,
      DesignTokenCategory::Customization,
      "Primer custom primitives",
      source,
      "@common.custom_tokens",
      DesignTokenStatus::ThemeMapped,
      "Users can inherit Primer preview tokens and override token groups.",
      "Primer-specific mode override validation is pending.",
    ),
  ]
}

///|
fn fluent_adaptation_report() -> Array[DesignAdaptationRecord] {
  let source = "https://fluent2.microsoft.design/design-tokens"
  [
    adaptation(
      @common.DesignPreset::Fluent,
      DesignAdaptationKind::CollapsedRoleMatrix,
      DesignTokenCategory::Color,
      "Fluent global and alias color tokens",
      source,
      "DesignSemanticPalette + @core.ColorPalette",
      DesignTokenStatus::PreviewMapped,
      "MoUI maps core foreground, background, brand, and status aliases into semantic slots.",
      "Complete global/alias color role import is pending.",
    ),
    adaptation(
      @common.DesignPreset::Fluent,
      DesignAdaptationKind::DirectRoleMapping,
      DesignTokenCategory::SchemeVariant,
      "Fluent light/dark/high contrast themes",
      source,
      "DesignSchemeVariant",
      DesignTokenStatus::ThemeMapped,
      "Light, dark, high-contrast, and system-aware variants are represented.",
      "Exact Fluent generated theme token sets are pending.",
    ),
    adaptation(
      @common.DesignPreset::Fluent,
      DesignAdaptationKind::CollapsedRoleMatrix,
      DesignTokenCategory::Typography,
      "Fluent type ramp",
      source,
      "DesignTypographyTokens",
      DesignTokenStatus::PreviewMapped,
      "MoUI source-imports the full Fluent global font file, but collapses the type ramp into body, title, caption, and control slots.",
      "Dedicated neutral line-height, font-family, and expanded type-ramp slots are pending.",
    ),
    adaptation(
      @common.DesignPreset::Fluent,
      DesignAdaptationKind::CollapsedRoleMatrix,
      DesignTokenCategory::Spacing,
      "Fluent spacing scales",
      source,
      "DesignSpacingTokens",
      DesignTokenStatus::PreviewMapped,
      "MoUI imports the full Fluent horizontal and vertical spacing aliases, but collapses axis, none, nudge, and extended values into five neutral spacing slots.",
      "Exact axis-specific, nudge, and extended neutral spacing slots are pending.",
    ),
    adaptation(
      @common.DesignPreset::Fluent,
      DesignAdaptationKind::CollapsedRoleMatrix,
      DesignTokenCategory::Shape,
      "Fluent border radius scale",
      source,
      "DesignRadiusTokens",
      DesignTokenStatus::PreviewMapped,
      "MoUI imports the full Fluent global border-radius scale, but collapses none, large, 2XL-6XL, and circular values into four neutral radius slots.",
      "Exact zero, extended radius, and circular sentinel parity are pending.",
    ),
    adaptation(
      @common.DesignPreset::Fluent,
      DesignAdaptationKind::Approximation,
      DesignTokenCategory::Elevation,
      "Fluent shadow and stroke depth",
      source,
      "DesignElevationTokens",
      DesignTokenStatus::PreviewMapped,
      "MoUI imports Fluent global stroke widths into neutral component border-width slots and still approximates depth through neutral shadow slots and outline colors.",
      "Complete Fluent shadow/depth import and richer neutral stroke-width scale parity are pending.",
    ),
    adaptation(
      @common.DesignPreset::Fluent,
      DesignAdaptationKind::Approximation,
      DesignTokenCategory::Motion,
      "Fluent duration and curve tokens",
      source,
      "DesignMotionTokens",
      DesignTokenStatus::PreviewMapped,
      "Fluent duration and curve rows are source-imported, but MoUI collapses them into three duration slots and one neutral easing slot.",
      "A richer neutral motion curve model is pending.",
    ),
    adaptation(
      @common.DesignPreset::Fluent,
      DesignAdaptationKind::CollapsedRoleMatrix,
      DesignTokenCategory::ComponentStyle,
      "Fluent component tokens",
      source,
      "DesignComponentTokens",
      DesignTokenStatus::ComponentMapped,
      "Compound brand, progress, picker, feedback, badge, and validation mappings target neutral component styles.",
      "The complete Fluent component token matrix is pending.",
    ),
    adaptation(
      @common.DesignPreset::Fluent,
      DesignAdaptationKind::CustomizableOverride,
      DesignTokenCategory::Customization,
      "Fluent brand customization",
      source,
      "@common.custom_tokens",
      DesignTokenStatus::ThemeMapped,
      "Users can inherit Fluent preview tokens and override semantic, component, and motion token groups.",
      "Fluent-specific brand-ramp generation is pending.",
    ),
  ]
}

///|
fn adaptation(
  preset : @common.DesignPreset,
  kind : DesignAdaptationKind,
  category : DesignTokenCategory,
  official_scope : String,
  official_source : String,
  moui_surface : String,
  status : DesignTokenStatus,
  difference : String,
  remaining_gap : String,
) -> DesignAdaptationRecord {
  let source = adaptation_source_for_url(preset, official_source)
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
        adaptation_source_locked(source),
      )
    None => (false, "", "", "", "", false)
  }
  {
    preset,
    kind,
    category,
    official_scope,
    official_source,
    source_declared,
    source_label,
    source_kind,
    source_ref,
    token_path,
    source_locked,
    moui_surface,
    status,
    difference,
    remaining_gap,
  }
}

///|
fn adaptation_source_for_url(
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
fn adaptation_source_locked(source : DesignSystemSource) -> Bool {
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
