///|
pub(all) enum DesignCustomizationKind {
  ThemeInheritance
  ThemeTokenOverride
  DesignTokenInheritance
  DesignTokenGroupOverride
  ComponentTokenOverride
  VariantThemeResolution
} derive(Eq, Debug, ToJson)

///|
pub(all) struct DesignCustomizationCapabilityRecord {
  preset : @common.DesignPreset
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
pub fn DesignCustomizationKind::label(
  preset : DesignCustomizationKind,
) -> String {
  match preset {
    ThemeInheritance => "theme inheritance"
    ThemeTokenOverride => "theme token override"
    DesignTokenInheritance => "design-token inheritance"
    DesignTokenGroupOverride => "design-token group override"
    ComponentTokenOverride => "component-token override"
    VariantThemeResolution => "variant theme resolution"
  }
}

///|
pub fn customization_report(
  preset : @common.DesignPreset,
) -> Array[DesignCustomizationCapabilityRecord] {
  [
    customization_capability_record(
      preset,
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
      preset,
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
      preset,
      DesignCustomizationKind::DesignTokenInheritance,
      "Design token base inheritance",
      "@common.custom_tokens(base=...)",
      "@common.DesignSystemTokens",
      inherits_base=true,
      supports_override=false,
      recomputes_dependents=true,
      status=DesignTokenStatus::ThemeMapped,
    ),
    customization_capability_record(
      preset,
      DesignCustomizationKind::DesignTokenGroupOverride,
      "Design token group override",
      "@common.custom_tokens(palette/typography/spacing/radius/elevation/motion/surfaces/state_layer)",
      "@common.DesignSystemTokens",
      inherits_base=true,
      supports_override=true,
      recomputes_dependents=true,
      status=DesignTokenStatus::ThemeMapped,
    ),
    customization_capability_record(
      preset,
      DesignCustomizationKind::ComponentTokenOverride,
      "Component token override",
      "@common.custom_tokens(components=...)",
      "@common.DesignComponentTokens",
      inherits_base=true,
      supports_override=true,
      recomputes_dependents=false,
      status=DesignTokenStatus::ComponentMapped,
    ),
    customization_capability_record(
      preset,
      DesignCustomizationKind::VariantThemeResolution,
      "Variant Theme resolver",
      "@common.DesignPreset::theme_for_variant(...)",
      "@common.DesignSchemeVariant -> @core.Theme",
      inherits_base=false,
      supports_override=false,
      recomputes_dependents=true,
      status=DesignTokenStatus::ThemeMapped,
    ),
  ]
}

///|
pub fn customization_report_for(
  preset : @common.DesignPreset,
  capability : String,
) -> DesignCustomizationCapabilityRecord? {
  for item in customization_report(preset) {
    if item.capability == capability {
      return Some(item)
    }
  }
  None
}

///|
pub fn customization_report_count(preset : @common.DesignPreset) -> Int {
  customization_report(preset).length()
}

///|
pub fn customization_capability_gap_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in customization_report(preset) {
    if item.status == DesignTokenStatus::NotMapped ||
      item.status == DesignTokenStatus::SourceMapped ||
      item.status == DesignTokenStatus::PreviewMapped {
      count = count + 1
    }
  }
  count
}

///|
pub fn customization_official_parity_gap_count(
  preset : @common.DesignPreset,
) -> Int {
  let mut count = 0
  for item in customization_report(preset) {
    if item.remaining_gap != "none" {
      count = count + 1
    }
  }
  count
}

///|
fn customization_capability_record(
  preset : @common.DesignPreset,
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
