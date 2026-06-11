///|
pub(all) enum DesignCustomizationKind {
  ThemeInheritance
  ThemeTokenOverride
  CompatibilityOverride
  DesignTokenInheritance
  DesignTokenGroupOverride
  ComponentTokenOverride
  VariantThemeResolution
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignCustomizationCapabilityRecord {
  preset : DesignPreset
  kind : DesignCustomizationKind
  capability : String
  api_surface : String
  token_surface : String
  inherits_base : Bool
  supports_override : Bool
  recomputes_dependents : Bool
  status : DesignTokenStatus
  remaining_gap : String
} derive(Eq, Debug, ToJson)

///|
pub fn DesignCustomizationKind::label(self : DesignCustomizationKind) -> String {
  match self {
    ThemeInheritance => "theme inheritance"
    ThemeTokenOverride => "theme token override"
    CompatibilityOverride => "compatibility override"
    DesignTokenInheritance => "design-token inheritance"
    DesignTokenGroupOverride => "design-token group override"
    ComponentTokenOverride => "component-token override"
    VariantThemeResolution => "variant theme resolution"
  }
}

///|
pub fn DesignPreset::customization_report(
  self : DesignPreset,
) -> Array[DesignCustomizationCapabilityRecord] {
  [
    customization_capability_record(
      self,
      DesignCustomizationKind::ThemeInheritance,
      "Theme base inheritance",
      "@common.custom(base=...)",
      "@core.Theme",
      inherits_base=true,
      supports_override=false,
      recomputes_dependents=false,
      status=DesignTokenStatus::ThemeMapped,
    ),
    customization_capability_record(
      self,
      DesignCustomizationKind::ThemeTokenOverride,
      "Theme token group override",
      "@common.custom(palette/semantic_colors/spacing_scale/radius_scale/typography/shadow_scale/motion/surfaces)",
      "@core.Theme token groups",
      inherits_base=true,
      supports_override=true,
      recomputes_dependents=false,
      status=DesignTokenStatus::ThemeMapped,
    ),
    customization_capability_record(
      self,
      DesignCustomizationKind::CompatibilityOverride,
      "Theme compatibility override",
      "@common.custom(font/foreground/background/accent/spacing/corner_radius)",
      "@core.Theme compatibility fields",
      inherits_base=true,
      supports_override=true,
      recomputes_dependents=false,
      status=DesignTokenStatus::ThemeMapped,
    ),
    customization_capability_record(
      self,
      DesignCustomizationKind::DesignTokenInheritance,
      "Design token base inheritance",
      "@common.custom_tokens(base=...)",
      "DesignSystemTokens",
      inherits_base=true,
      supports_override=false,
      recomputes_dependents=true,
      status=DesignTokenStatus::ThemeMapped,
    ),
    customization_capability_record(
      self,
      DesignCustomizationKind::DesignTokenGroupOverride,
      "Design token group override",
      "@common.custom_tokens(palette/typography/spacing/radius/elevation/motion/surfaces/state_layer)",
      "DesignSystemTokens",
      inherits_base=true,
      supports_override=true,
      recomputes_dependents=true,
      status=DesignTokenStatus::ThemeMapped,
    ),
    customization_capability_record(
      self,
      DesignCustomizationKind::ComponentTokenOverride,
      "Component token override",
      "@common.custom_tokens(components=...)",
      "DesignComponentTokens",
      inherits_base=true,
      supports_override=true,
      recomputes_dependents=false,
      status=DesignTokenStatus::ComponentMapped,
    ),
    customization_capability_record(
      self,
      DesignCustomizationKind::VariantThemeResolution,
      "Variant Theme resolver",
      "DesignPreset::theme_for_variant(...)",
      "DesignSchemeVariant -> @core.Theme",
      inherits_base=false,
      supports_override=false,
      recomputes_dependents=true,
      status=DesignTokenStatus::ThemeMapped,
    ),
  ]
}

///|
pub fn DesignPreset::customization_report_for(
  self : DesignPreset,
  capability : String,
) -> DesignCustomizationCapabilityRecord? {
  for item in self.customization_report() {
    if item.capability == capability {
      return Some(item)
    }
  }
  None
}

///|
pub fn DesignPreset::customization_report_count(self : DesignPreset) -> Int {
  self.customization_report().length()
}

///|
pub fn DesignPreset::customization_capability_gap_count(
  self : DesignPreset,
) -> Int {
  let mut count = 0
  for item in self.customization_report() {
    if item.status == DesignTokenStatus::NotMapped ||
      item.status == DesignTokenStatus::SourceMapped ||
      item.status == DesignTokenStatus::PreviewMapped {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignPreset::customization_official_parity_gap_count(
  self : DesignPreset,
) -> Int {
  let mut count = 0
  for item in self.customization_report() {
    if item.remaining_gap != "none" {
      count = count + 1
    }
  }
  count
}

///|
fn customization_capability_record(
  preset : DesignPreset,
  kind : DesignCustomizationKind,
  capability : String,
  api_surface : String,
  token_surface : String,
  inherits_base~ : Bool,
  supports_override~ : Bool,
  recomputes_dependents~ : Bool,
  status~ : DesignTokenStatus,
) -> DesignCustomizationCapabilityRecord {
  {
    preset,
    kind,
    capability,
    api_surface,
    token_surface,
    inherits_base,
    supports_override,
    recomputes_dependents,
    status,
    remaining_gap: customization_remaining_gap(),
  }
}

///|
fn customization_remaining_gap() -> String {
  "Official per-system generators and validation-specific builders are pending; this record covers the neutral MoUI customization API."
}
