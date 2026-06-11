///|
pub(all) struct DesignVariantResolverRecord {
  preset : DesignPreset
  variant : DesignSchemeVariant
  source_family : String
  official_source : String
  source_declared : Bool
  source_label : String
  source_kind : String
  source_ref : String
  token_path : String
  source_locked : Bool
  tokens_api : String
  theme_api : String
  system_scheme : @core.ColorScheme
  resolved_scheme : @core.ColorScheme
  density : DesignDensity
  resolves_tokens : Bool
  resolves_theme : Bool
  status : DesignTokenStatus
  remaining_gap : String
} derive(Eq, Debug, ToJson)

///|
pub fn DesignPreset::variant_resolver_report(
  self : DesignPreset,
  system_scheme? : @core.ColorScheme = @core.ColorScheme::Dark,
  density? : DesignDensity = DesignDensity::Standard,
) -> Array[DesignVariantResolverRecord] {
  let records : Array[DesignVariantResolverRecord] = []
  for item in self.variant_coverage() {
    records.push(variant_resolver_record(self, item, system_scheme, density))
  }
  records
}

///|
pub fn DesignPreset::variant_resolver_for(
  self : DesignPreset,
  variant : DesignSchemeVariant,
  system_scheme? : @core.ColorScheme = @core.ColorScheme::Dark,
  density? : DesignDensity = DesignDensity::Standard,
) -> DesignVariantResolverRecord? {
  for item in self.variant_resolver_report(system_scheme~, density~) {
    if item.variant == variant {
      return Some(item)
    }
  }
  None
}

///|
pub fn DesignPreset::variant_resolver_count(self : DesignPreset) -> Int {
  self.variant_resolver_report().length()
}

///|
pub fn DesignPreset::variant_resolver_gap_count(self : DesignPreset) -> Int {
  let mut count = 0
  for item in self.variant_resolver_report() {
    if !item.resolves_tokens ||
      !item.resolves_theme ||
      item.status == DesignTokenStatus::NotMapped ||
      item.status == DesignTokenStatus::SourceMapped ||
      item.status == DesignTokenStatus::PreviewMapped {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignPreset::variant_resolver_source_gap_count(
  self : DesignPreset,
) -> Int {
  let mut count = 0
  for item in self.variant_resolver_report() {
    if !item.source_declared || !item.source_locked {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignPreset::variant_resolver_official_parity_gap_count(
  self : DesignPreset,
) -> Int {
  let mut count = 0
  for item in self.variant_resolver_report() {
    if item.remaining_gap != "none" {
      count = count + 1
    }
  }
  count
}

///|
fn variant_resolver_record(
  preset : DesignPreset,
  coverage : DesignVariantCoverage,
  system_scheme : @core.ColorScheme,
  density : DesignDensity,
) -> DesignVariantResolverRecord {
  let official_source = variant_official_source(preset)
  let source = variant_source_for_url(preset, official_source)
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
        variant_source_locked(source),
      )
    None => (false, "", "", "", "", false)
  }
  let tokens = preset.tokens_for_variant(
    variant=coverage.variant,
    system_scheme~,
    density~,
  )
  let theme = preset.theme_for_variant(
    variant=coverage.variant,
    system_scheme~,
    density~,
  )
  let resolves_tokens = tokens.variant == coverage.variant &&
    tokens.density == density
  let resolves_theme = theme == tokens.to_theme()
  let status = if !source_declared ||
    !source_locked ||
    !resolves_tokens ||
    !resolves_theme {
    DesignTokenStatus::NotMapped
  } else {
    coverage.status
  }
  {
    preset,
    variant: coverage.variant,
    source_family: coverage.source_family,
    official_source,
    source_declared,
    source_label,
    source_kind,
    source_ref,
    token_path,
    source_locked,
    tokens_api: "DesignPreset::tokens_for_variant(...)",
    theme_api: "DesignPreset::theme_for_variant(...)",
    system_scheme,
    resolved_scheme: tokens.scheme,
    density,
    resolves_tokens,
    resolves_theme,
    status,
    remaining_gap: variant_remaining_gap(coverage),
  }
}

///|
fn variant_official_source(preset : DesignPreset) -> String {
  match preset {
    Material => "https://material-web.dev/theming/color/"
    Carbon => "https://carbondesignsystem.com/elements/themes/code/"
    Primer => "https://primer.style/product/primitives/color/"
    Fluent => "https://fluent2.microsoft.design/theming"
  }
}

///|
fn variant_remaining_gap(coverage : DesignVariantCoverage) -> String {
  if coverage.status == DesignTokenStatus::OfficialComplete {
    "none"
  } else {
    "Official scheme variant token matrices are not fully imported; this resolver proves the current neutral MoUI adapter only."
  }
}

///|
fn variant_source_for_url(
  preset : DesignPreset,
  url : String,
) -> DesignSystemSource? {
  for source in preset.sources() {
    if source.url == url {
      return Some(source)
    }
  }
  None
}

///|
fn variant_source_locked(source : DesignSystemSource) -> Bool {
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
