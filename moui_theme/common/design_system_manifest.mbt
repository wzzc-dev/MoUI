///|
pub(all) enum DesignTokenCategory {
  Color
  Typography
  Spacing
  Density
  Shape
  Elevation
  Motion
  Surface
  StateLayer
  SchemeVariant
  ComponentStyle
  Customization
} derive(Eq, Debug, ToJson)

///|
pub(all) enum DesignTokenLayer {
  ReferenceToken
  SystemToken
  AliasToken
  ComponentToken
  MoUIAdapter
} derive(Eq, Debug, ToJson)

///|
pub(all) enum DesignSchemeVariant {
  SchemeLight
  SchemeDark
  SchemeHighContrast
  SchemeSystem
} derive(Eq, Debug, ToJson)

///|
pub(all) enum DesignTokenStatus {
  NotMapped
  SourceMapped
  PreviewMapped
  ThemeMapped
  ComponentMapped
  OfficialComplete
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignSystemSource {
  label : String
  url : String
  source_kind : String
  source_ref : String
  token_path : String
  status : DesignTokenStatus
  note : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignTokenCoverage {
  category : DesignTokenCategory
  layer : DesignTokenLayer
  source_family : String
  moui_surface : String
  status : DesignTokenStatus
  note : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignVariantCoverage {
  variant : DesignSchemeVariant
  source_family : String
  status : DesignTokenStatus
  note : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignComponentCoverage {
  component : String
  source_family : String
  moui_surface : String
  status : DesignTokenStatus
  note : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignCustomizationCoverage {
  capability : String
  api_surface : String
  status : DesignTokenStatus
  note : String
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignSystemManifest {
  preset : DesignPreset
  official_name : String
  stage : DesignTokenStatus
  sources : Array[DesignSystemSource]
  token_coverage : Array[DesignTokenCoverage]
  variant_coverage : Array[DesignVariantCoverage]
  component_coverage : Array[DesignComponentCoverage]
  customization_coverage : Array[DesignCustomizationCoverage]
  note : String
} derive(Eq, Debug, ToJson)

///|
pub fn DesignPreset::manifest(self : DesignPreset) -> DesignSystemManifest {
  match self {
    Material => material_manifest()
    Carbon => carbon_manifest()
    Primer => primer_manifest()
    Fluent => fluent_manifest()
  }
}

///|
pub fn DesignPreset::sources(self : DesignPreset) -> Array[DesignSystemSource] {
  self.manifest().sources
}

///|
pub fn DesignPreset::token_coverage(
  self : DesignPreset,
) -> Array[DesignTokenCoverage] {
  self.manifest().token_coverage
}

///|
pub fn DesignPreset::variant_coverage(
  self : DesignPreset,
) -> Array[DesignVariantCoverage] {
  self.manifest().variant_coverage
}

///|
pub fn DesignPreset::component_coverage(
  self : DesignPreset,
) -> Array[DesignComponentCoverage] {
  self.manifest().component_coverage
}

///|
pub fn DesignPreset::customization_coverage(
  self : DesignPreset,
) -> Array[DesignCustomizationCoverage] {
  self.manifest().customization_coverage
}

///|
pub fn DesignSystemManifest::is_official_complete(
  self : DesignSystemManifest,
) -> Bool {
  let mut complete = self.stage == DesignTokenStatus::OfficialComplete
  for item in self.sources {
    if item.status != DesignTokenStatus::OfficialComplete {
      complete = false
    }
  }
  for item in self.token_coverage {
    if item.status != DesignTokenStatus::OfficialComplete {
      complete = false
    }
  }
  for item in self.variant_coverage {
    if item.status != DesignTokenStatus::OfficialComplete {
      complete = false
    }
  }
  for item in self.component_coverage {
    if item.status != DesignTokenStatus::OfficialComplete {
      complete = false
    }
  }
  for item in self.customization_coverage {
    if item.status != DesignTokenStatus::OfficialComplete {
      complete = false
    }
  }
  complete
}

///|
pub fn DesignSystemManifest::has_token_category(
  self : DesignSystemManifest,
  category : DesignTokenCategory,
) -> Bool {
  self.token_coverage.any(item => item.category == category)
}

///|
pub fn DesignSystemManifest::has_variant(
  self : DesignSystemManifest,
  variant : DesignSchemeVariant,
) -> Bool {
  self.variant_coverage.any(item => item.variant == variant)
}

///|
pub fn DesignSystemManifest::has_component(
  self : DesignSystemManifest,
  component : String,
) -> Bool {
  self.component_coverage.any(item => item.component == component)
}

///|
pub fn DesignSystemManifest::official_source_count(
  self : DesignSystemManifest,
) -> Int {
  let mut count = 0
  for source in self.sources {
    if source.source_kind == "official-source" {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignSystemManifest::source_lock_count(
  self : DesignSystemManifest,
) -> Int {
  let mut count = 0
  for source in self.sources {
    if source.source_kind == "official-source" &&
      source.source_ref != "" &&
      source.token_path != "" &&
      source.status != DesignTokenStatus::NotMapped {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignSystemManifest::has_official_source_locks(
  self : DesignSystemManifest,
) -> Bool {
  let official_sources = self.official_source_count()
  official_sources > 0 && self.source_lock_count() == official_sources
}

///|
fn material_manifest() -> DesignSystemManifest {
  {
    preset: DesignPreset::Material,
    official_name: "Material Design 3",
    stage: DesignTokenStatus::PreviewMapped,
    sources: [
      source(
        "Material Web tokens", "https://material-web.dev/theming/material-theming/",
        "official-docs", "Documents reference, system, and component token layers for Material Web.",
      ),
      source(
        "Material Web color theming", "https://material-web.dev/theming/color/",
        "official-docs", "Documents Material color roles and generated theme colors.",
      ),
      source(
        "Material Web token source",
        "https://github.com/material-components/material-web/tree/main/tokens",
        "official-source",
        "Token source used as the canonical implementation target for MoUI mapping.",
        source_ref="a3379a361431fc63f69ec0eaa66ac23b663bff85",
        token_path="tokens",
      ),
    ],
    token_coverage: material_token_coverage(),
    variant_coverage: material_variant_coverage(),
    component_coverage: material_component_coverage(),
    customization_coverage: customization_coverage(
      DesignTokenStatus::ThemeMapped,
    ),
    note: "Current MoUI tokens are source-mapped previews, not full Material compliance.",
  }
}

///|
fn carbon_manifest() -> DesignSystemManifest {
  {
    preset: DesignPreset::Carbon,
    official_name: "IBM Carbon Design System",
    stage: DesignTokenStatus::PreviewMapped,
    sources: [
      source(
        "Carbon themes", "https://carbondesignsystem.com/elements/themes/code/",
        "official-docs", "Documents the Carbon theme token model and shipped theme sets.",
      ),
      source(
        "Carbon color tokens", "https://carbondesignsystem.com/elements/color/tokens/",
        "official-docs", "Documents color token roles across Carbon themes.",
      ),
      source(
        "Carbon theme package source",
        "https://github.com/carbon-design-system/carbon/tree/main/packages/themes",
        "official-source",
        "Source package for Carbon theme token values.",
        source_ref="f3241ee5c211baa5d04297be3a39901996ab3465",
        token_path="packages/themes",
      ),
      source(
        "Carbon color package source",
        "https://github.com/carbon-design-system/carbon/tree/main/packages/colors",
        "official-source",
        "Source package for Carbon color primitive values referenced by theme tokens.",
        source_ref="f3241ee5c211baa5d04297be3a39901996ab3465",
        token_path="packages/colors",
      ),
      source(
        "Carbon styles package source",
        "https://github.com/carbon-design-system/carbon/tree/main/packages/styles",
        "official-source",
        "Source package for Carbon component SCSS used by generated component styles.",
        source_ref="f3241ee5c211baa5d04297be3a39901996ab3465",
        token_path="packages/styles",
      ),
      source(
        "Carbon motion package source",
        "https://github.com/carbon-design-system/carbon/tree/main/packages/motion",
        "official-source",
        "Source package for Carbon duration and easing token values.",
        source_ref="f3241ee5c211baa5d04297be3a39901996ab3465",
        token_path="packages/motion",
      ),
      source(
        "Carbon layout package source",
        "https://github.com/carbon-design-system/carbon/tree/main/packages/layout",
        "official-source",
        "Source package for Carbon spacing, layout, container, and size token values.",
        source_ref="f3241ee5c211baa5d04297be3a39901996ab3465",
        token_path="packages/layout",
      ),
      source(
        "Carbon type package source",
        "https://github.com/carbon-design-system/carbon/tree/main/packages/type",
        "official-source",
        "Source package for Carbon typography style token values.",
        source_ref="f3241ee5c211baa5d04297be3a39901996ab3465",
        token_path="packages/type",
      ),
    ],
    token_coverage: carbon_token_coverage(),
    variant_coverage: carbon_variant_coverage(),
    component_coverage: carbon_component_coverage(),
    customization_coverage: customization_coverage(
      DesignTokenStatus::ThemeMapped,
    ),
    note: "Current MoUI tokens are source-mapped previews, not full Carbon compliance.",
  }
}

///|
fn primer_manifest() -> DesignSystemManifest {
  {
    preset: DesignPreset::Primer,
    official_name: "GitHub Primer",
    stage: DesignTokenStatus::PreviewMapped,
    sources: [
      source(
        "Primer primitives", "https://primer.style/primitives/", "official-docs",
        "Documents Primer tokens and themeable primitive families.",
      ),
      source(
        "Primer primitives source",
        "https://github.com/primer/primitives",
        "official-source",
        "Canonical Primer token source, including colors, typography, spacing, and overrides.",
        source_ref="dfbda0f82d702ade63e73dbf79856bce750bc24b",
        token_path="src/tokens",
      ),
      source(
        "Primer color primitives", "https://primer.style/product/primitives/color/",
        "official-docs", "Documents Primer color primitives and mode-specific token behavior.",
      ),
    ],
    token_coverage: primer_token_coverage(),
    variant_coverage: primer_variant_coverage(),
    component_coverage: primer_component_coverage(),
    customization_coverage: customization_coverage(
      DesignTokenStatus::ThemeMapped,
    ),
    note: "Current MoUI tokens are source-mapped previews, not full Primer compliance.",
  }
}

///|
fn fluent_manifest() -> DesignSystemManifest {
  {
    preset: DesignPreset::Fluent,
    official_name: "Microsoft Fluent 2",
    stage: DesignTokenStatus::PreviewMapped,
    sources: [
      source(
        "Fluent 2 design tokens", "https://fluent2.microsoft.design/design-tokens",
        "official-docs", "Documents Fluent global and alias tokens used for theming.",
      ),
      source(
        "Fluent UI tokens source",
        "https://github.com/microsoft/fluentui/tree/master/packages/tokens",
        "official-source",
        "Canonical Fluent UI token package for theme implementation.",
        source_ref="80a7fb1847f8123de709fb604d20b194e4fc1379",
        token_path="packages/tokens",
      ),
      source(
        "Fluent Web Components source",
        "https://github.com/microsoft/fluentui/tree/master/packages/web-components",
        "official-source",
        "Fluent component source used for source-mapped component style rules.",
        source_ref="80a7fb1847f8123de709fb604d20b194e4fc1379",
        token_path="packages/web-components",
      ),
      source(
        "Fluent theming", "https://fluent2.microsoft.design/theming", "official-docs",
        "Documents Fluent light, dark, high-contrast, and brand theming behavior.",
      ),
    ],
    token_coverage: fluent_token_coverage(),
    variant_coverage: fluent_variant_coverage(),
    component_coverage: fluent_component_coverage(),
    customization_coverage: customization_coverage(
      DesignTokenStatus::ThemeMapped,
    ),
    note: "Current MoUI tokens are source-mapped previews, not full Fluent compliance.",
  }
}

///|
fn material_token_coverage() -> Array[DesignTokenCoverage] {
  [
    coverage(
      DesignTokenCategory::Color,
      DesignTokenLayer::SystemToken,
      "md.sys.color roles",
      "@core.ColorPalette + @core.SemanticColorScale",
      DesignTokenStatus::PreviewMapped,
      "Mapped into MoUI palette slots; full role matrix is pending.",
    ),
    coverage(
      DesignTokenCategory::Typography,
      DesignTokenLayer::SystemToken,
      "md.sys.typescale",
      "@core.TypographyScale",
      DesignTokenStatus::PreviewMapped,
      "Mapped to body/title/caption/control; full type scale is pending.",
    ),
    coverage(
      DesignTokenCategory::Spacing,
      DesignTokenLayer::SystemToken,
      "Material layout spacing",
      "@core.SpacingScale",
      DesignTokenStatus::PreviewMapped,
      "Five-point MoUI scale stands in for the broader Material spacing system.",
    ),
    coverage(
      DesignTokenCategory::Density,
      DesignTokenLayer::SystemToken,
      "Material density",
      "DesignDensity -> @core.SpacingScale",
      DesignTokenStatus::ThemeMapped,
      "Density-aware spacing resolver is exposed by DesignPreset::tokens.",
    ),
    coverage(
      DesignTokenCategory::Shape,
      DesignTokenLayer::SystemToken,
      "md.sys.shape.corner",
      "@core.RadiusScale",
      DesignTokenStatus::PreviewMapped,
      "Mapped to small/medium/large/pill radius slots.",
    ),
    coverage(
      DesignTokenCategory::Elevation,
      DesignTokenLayer::SystemToken,
      "md.sys.elevation",
      "@core.ShadowScale",
      DesignTokenStatus::PreviewMapped,
      "Approximated through shadows; tonal elevation overlay is pending.",
    ),
    coverage(
      DesignTokenCategory::Motion,
      DesignTokenLayer::SystemToken,
      "md.sys.motion",
      "@core.MotionScale",
      DesignTokenStatus::PreviewMapped,
      "Duration/easing mapped; component motion specs are pending.",
    ),
    coverage(
      DesignTokenCategory::Surface,
      DesignTokenLayer::SystemToken,
      "md.sys.color surface roles",
      "@core.SurfaceScale",
      DesignTokenStatus::PreviewMapped,
      "Surface colors are generated from palette roles.",
    ),
    coverage(
      DesignTokenCategory::StateLayer,
      DesignTokenLayer::ComponentToken,
      "md.comp.* state-layer tokens",
      "DesignStateLayerTokens",
      DesignTokenStatus::ComponentMapped,
      "State-layer opacity tokens are represented; full component-specific matrix is pending.",
    ),
    coverage(
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::ComponentToken,
      "md.comp.* tokens",
      "DesignComponentTokens",
      DesignTokenStatus::ComponentMapped,
      "Button, text-field, surface, choice-control, progress, slider, picker, date-picker, feedback, badge, and form-validation token sets exist; full Material component matrix is pending.",
    ),
  ]
}

///|
fn carbon_token_coverage() -> Array[DesignTokenCoverage] {
  common_official_token_coverage(
    color_family="Carbon theme color tokens",
    typography_family="Carbon type tokens",
    spacing_family="Carbon spacing scale",
    density_family="Carbon productive/expressive density",
    shape_family="Carbon border radius tokens",
    elevation_family="Carbon layer/shadow tokens",
    motion_family="Carbon motion tokens",
    surface_family="Carbon layer tokens",
    state_family="Carbon interactive state tokens",
    component_family="Carbon component tokens",
  )
}

///|
fn primer_token_coverage() -> Array[DesignTokenCoverage] {
  common_official_token_coverage(
    color_family="Primer color primitives and modes",
    typography_family="Primer typography primitives",
    spacing_family="Primer size and spacing primitives",
    density_family="Primer density and size overrides",
    shape_family="Primer borderRadius primitives",
    elevation_family="Primer shadow primitives",
    motion_family="Primer animation primitives",
    surface_family="Primer canvas and overlay tokens",
    state_family="Primer control interaction tokens",
    component_family="Primer component tokens",
  )
}

///|
fn fluent_token_coverage() -> Array[DesignTokenCoverage] {
  common_official_token_coverage(
    color_family="Fluent alias color tokens",
    typography_family="Fluent type ramp tokens",
    spacing_family="Fluent spacing tokens",
    density_family="Fluent density tokens",
    shape_family="Fluent border radius tokens",
    elevation_family="Fluent shadow tokens",
    motion_family="Fluent duration and curve tokens",
    surface_family="Fluent neutral background tokens",
    state_family="Fluent state and stroke tokens",
    component_family="Fluent component tokens",
  )
}

///|
fn common_official_token_coverage(
  color_family~ : String,
  typography_family~ : String,
  spacing_family~ : String,
  density_family~ : String,
  shape_family~ : String,
  elevation_family~ : String,
  motion_family~ : String,
  surface_family~ : String,
  state_family~ : String,
  component_family~ : String,
) -> Array[DesignTokenCoverage] {
  [
    coverage(
      DesignTokenCategory::Color,
      DesignTokenLayer::AliasToken,
      color_family,
      "@core.ColorPalette + @core.SemanticColorScale",
      DesignTokenStatus::PreviewMapped,
      "Mapped into MoUI palette slots; complete semantic role matrix is pending.",
    ),
    coverage(
      DesignTokenCategory::Typography,
      DesignTokenLayer::AliasToken,
      typography_family,
      "@core.TypographyScale",
      DesignTokenStatus::PreviewMapped,
      "Mapped to body/title/caption/control; complete type ramp is pending.",
    ),
    coverage(
      DesignTokenCategory::Spacing,
      DesignTokenLayer::AliasToken,
      spacing_family,
      "@core.SpacingScale",
      DesignTokenStatus::PreviewMapped,
      "Mapped into five MoUI spacing slots.",
    ),
    coverage(
      DesignTokenCategory::Density,
      DesignTokenLayer::AliasToken,
      density_family,
      "DesignDensity -> @core.SpacingScale",
      DesignTokenStatus::ThemeMapped,
      "Density variants resolve through DesignPreset::tokens.",
    ),
    coverage(
      DesignTokenCategory::Shape,
      DesignTokenLayer::AliasToken,
      shape_family,
      "@core.RadiusScale",
      DesignTokenStatus::PreviewMapped,
      "Mapped to small/medium/large/pill radius slots.",
    ),
    coverage(
      DesignTokenCategory::Elevation,
      DesignTokenLayer::AliasToken,
      elevation_family,
      "@core.ShadowScale",
      DesignTokenStatus::PreviewMapped,
      "Mapped to small/medium/large shadow slots.",
    ),
    coverage(
      DesignTokenCategory::Motion,
      DesignTokenLayer::AliasToken,
      motion_family,
      "@core.MotionScale",
      DesignTokenStatus::PreviewMapped,
      "Duration/easing mapped; component motion specs are pending.",
    ),
    coverage(
      DesignTokenCategory::Surface,
      DesignTokenLayer::AliasToken,
      surface_family,
      "@core.SurfaceScale",
      DesignTokenStatus::PreviewMapped,
      "Surface roles are adapted into base/raised/overlay.",
    ),
    coverage(
      DesignTokenCategory::StateLayer,
      DesignTokenLayer::ComponentToken,
      state_family,
      "DesignStateLayerTokens",
      DesignTokenStatus::ComponentMapped,
      "Interaction-state tokens are represented; full component-specific matrix is pending.",
    ),
    coverage(
      DesignTokenCategory::ComponentStyle,
      DesignTokenLayer::ComponentToken,
      component_family,
      "DesignComponentTokens",
      DesignTokenStatus::ComponentMapped,
      "Button, text-field, surface, choice-control, progress, slider, picker, date-picker, feedback, badge, and form-validation token sets exist; complete official component matrix is pending.",
    ),
  ]
}

///|
fn material_variant_coverage() -> Array[DesignVariantCoverage] {
  official_variant_coverage("Material light/dark color schemes")
}

///|
fn carbon_variant_coverage() -> Array[DesignVariantCoverage] {
  official_variant_coverage("Carbon white/g10/g90/g100 themes")
}

///|
fn primer_variant_coverage() -> Array[DesignVariantCoverage] {
  official_variant_coverage("Primer light/dark/colorblind/high-contrast themes")
}

///|
fn fluent_variant_coverage() -> Array[DesignVariantCoverage] {
  [
    variant(
      DesignSchemeVariant::SchemeLight,
      "Fluent light theme",
      DesignTokenStatus::PreviewMapped,
      "Mapped to the MoUI light preset.",
    ),
    variant(
      DesignSchemeVariant::SchemeDark,
      "Fluent dark theme",
      DesignTokenStatus::PreviewMapped,
      "Mapped to the MoUI dark preset.",
    ),
    variant(
      DesignSchemeVariant::SchemeHighContrast,
      "Fluent high contrast theme",
      DesignTokenStatus::ThemeMapped,
      "Dedicated high-contrast token adapter exists in moui_theme/common.",
    ),
    variant(
      DesignSchemeVariant::SchemeSystem,
      "Fluent system-aware theme selection",
      DesignTokenStatus::ThemeMapped,
      "Preset-preserving system-scheme token resolver exists in moui_theme/common.",
    ),
  ]
}

///|
fn official_variant_coverage(
  source_family : String,
) -> Array[DesignVariantCoverage] {
  [
    variant(
      DesignSchemeVariant::SchemeLight,
      source_family,
      DesignTokenStatus::PreviewMapped,
      "Mapped to the MoUI light preset.",
    ),
    variant(
      DesignSchemeVariant::SchemeDark,
      source_family,
      DesignTokenStatus::PreviewMapped,
      "Mapped to the MoUI dark preset.",
    ),
    variant(
      DesignSchemeVariant::SchemeHighContrast,
      source_family,
      DesignTokenStatus::ThemeMapped,
      "Dedicated high-contrast token adapter exists in moui_theme/common.",
    ),
    variant(
      DesignSchemeVariant::SchemeSystem,
      source_family,
      DesignTokenStatus::ThemeMapped,
      "Preset-preserving system-scheme token resolver exists in moui_theme/common.",
    ),
  ]
}

///|
fn material_component_coverage() -> Array[DesignComponentCoverage] {
  neutral_component_coverage(
    "Material component tokens",
    DesignTokenStatus::ComponentMapped,
  )
}

///|
fn carbon_component_coverage() -> Array[DesignComponentCoverage] {
  neutral_component_coverage(
    "Carbon component tokens",
    DesignTokenStatus::ComponentMapped,
  )
}

///|
fn primer_component_coverage() -> Array[DesignComponentCoverage] {
  neutral_component_coverage(
    "Primer component tokens",
    DesignTokenStatus::ComponentMapped,
  )
}

///|
fn fluent_component_coverage() -> Array[DesignComponentCoverage] {
  neutral_component_coverage(
    "Fluent component tokens",
    DesignTokenStatus::ComponentMapped,
  )
}

///|
fn neutral_component_coverage(
  source_family : String,
  status : DesignTokenStatus,
) -> Array[DesignComponentCoverage] {
  [
    component(
      "Button", source_family, "@views.ButtonStyle", status, "MoUI has neutral filled/tonal/outline/ghost styles.",
    ),
    component(
      "TextField", source_family, "@views.TextFieldStyle", status, "MoUI has neutral filled/outline/plain style mapping.",
    ),
    component(
      "Surface", source_family, "@views.SurfaceStyle", status, "MoUI has neutral base/raised/overlay surface mapping.",
    ),
    component(
      "ChoiceControl", source_family, "@views.ChoiceControlStyle", status, "MoUI has a neutral choice-control style contract.",
    ),
    component(
      "Progress", source_family, "@views.ProgressStyle", status, "MoUI has a neutral progress style contract.",
    ),
    component(
      "Slider", source_family, "@views.SliderStyle", status, "MoUI has a neutral slider style contract.",
    ),
    component(
      "Picker", source_family, "@views.PickerStyle", status, "MoUI has a neutral picker style contract.",
    ),
    component(
      "DatePicker", source_family, "@views.PickerStyle", status, "MoUI reuses the neutral picker style contract for date pickers.",
    ),
    component(
      "Feedback", source_family, "@views.FeedbackStyle", status, "MoUI has neutral status-surface tokens for toast, snackbar, banner, callout, and state panels.",
    ),
    component(
      "Badge", source_family, "@views.BadgeStyle", status, "MoUI has neutral badge tone tokens for status labels.",
    ),
    component(
      "FormValidation", source_family, "@views.FormValidationStyle", status, "MoUI has neutral form-validation status tokens.",
    ),
  ]
}

///|
fn customization_coverage(
  status : DesignTokenStatus,
) -> Array[DesignCustomizationCoverage] {
  [
    customization(
      "Theme base inheritance", "@common.custom(base=...)", status, "Custom themes can inherit from any preset-generated @core.Theme.",
    ),
    customization(
      "Theme token group override", "@common.custom(palette/semantic_colors/spacing_scale/radius_scale/typography/shadow_scale/motion/surfaces)",
      status, "Custom themes can replace complete @core.Theme token groups.",
    ),
    customization(
      "Design token base inheritance", "@common.custom_tokens(base=...)", status,
      "Custom design-system tokens can inherit from preset token bundles.",
    ),
    customization(
      "Design token group override", "@common.custom_tokens(palette/typography/spacing/radius/elevation/motion/surfaces/state_layer)",
      status, "Custom design-system tokens can override token groups and recompute dependent surfaces/components.",
    ),
    customization(
      "Component token override",
      "@common.custom_tokens(components=...)",
      DesignTokenStatus::ComponentMapped,
      "Custom design-system tokens can replace component token bundles explicitly.",
    ),
    customization(
      "Variant Theme resolver", "DesignPreset::theme_for_variant(...)", status, "Preset variants can resolve directly to neutral @core.Theme values.",
    ),
  ]
}

///|
fn source(
  label : String,
  url : String,
  source_kind : String,
  note : String,
  source_ref? : String = "live",
  token_path? : String = "",
  status? : DesignTokenStatus = DesignTokenStatus::SourceMapped,
) -> DesignSystemSource {
  { label, url, source_kind, source_ref, token_path, status, note }
}

///|
fn coverage(
  category : DesignTokenCategory,
  layer : DesignTokenLayer,
  source_family : String,
  moui_surface : String,
  status : DesignTokenStatus,
  note : String,
) -> DesignTokenCoverage {
  { category, layer, source_family, moui_surface, status, note }
}

///|
fn variant(
  variant : DesignSchemeVariant,
  source_family : String,
  status : DesignTokenStatus,
  note : String,
) -> DesignVariantCoverage {
  { variant, source_family, status, note }
}

///|
fn component(
  component : String,
  source_family : String,
  moui_surface : String,
  status : DesignTokenStatus,
  note : String,
) -> DesignComponentCoverage {
  { component, source_family, moui_surface, status, note }
}

///|
fn customization(
  capability : String,
  api_surface : String,
  status : DesignTokenStatus,
  note : String,
) -> DesignCustomizationCoverage {
  { capability, api_surface, status, note }
}
