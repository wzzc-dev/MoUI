///|
pub(all) struct DesignDensityResolverRecord {
  preset : DesignPreset
  density : DesignDensity
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
  scheme : @core.ColorScheme
  density_multiplier : Double
  spacing_sm : Double
  spacing_md : Double
  theme_spacing_sm : Double
  theme_spacing_md : Double
  surface_padding : Double
  feedback_padding : Double
  resolves_tokens : Bool
  resolves_theme : Bool
  resolves_components : Bool
  status : DesignTokenStatus
  remaining_gap : String
} derive(Eq, Debug, ToJson)

///|
pub fn DesignPreset::density_resolver_report(
  self : DesignPreset,
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
) -> Array[DesignDensityResolverRecord] {
  [
    density_resolver_record(self, DesignDensity::Compact, scheme),
    density_resolver_record(self, DesignDensity::Standard, scheme),
    density_resolver_record(self, DesignDensity::Comfortable, scheme),
  ]
}

///|
pub fn DesignPreset::density_resolver_for(
  self : DesignPreset,
  density : DesignDensity,
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
) -> DesignDensityResolverRecord? {
  for item in self.density_resolver_report(scheme~) {
    if item.density == density {
      return Some(item)
    }
  }
  None
}

///|
pub fn DesignPreset::density_resolver_count(self : DesignPreset) -> Int {
  self.density_resolver_report().length()
}

///|
pub fn DesignPreset::density_resolver_gap_count(self : DesignPreset) -> Int {
  let mut count = 0
  for item in self.density_resolver_report() {
    if !item.resolves_tokens ||
      !item.resolves_theme ||
      !item.resolves_components ||
      item.status == DesignTokenStatus::NotMapped ||
      item.status == DesignTokenStatus::SourceMapped ||
      item.status == DesignTokenStatus::PreviewMapped {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignPreset::density_resolver_source_gap_count(
  self : DesignPreset,
) -> Int {
  let mut count = 0
  for item in self.density_resolver_report() {
    if !item.source_declared || !item.source_locked {
      count = count + 1
    }
  }
  count
}

///|
pub fn DesignPreset::density_resolver_official_parity_gap_count(
  self : DesignPreset,
) -> Int {
  let mut count = 0
  for item in self.density_resolver_report() {
    if item.remaining_gap != "none" {
      count = count + 1
    }
  }
  count
}

///|
fn density_resolver_record(
  preset : DesignPreset,
  density : DesignDensity,
  scheme : @core.ColorScheme,
) -> DesignDensityResolverRecord {
  let official_source = density_official_source(preset)
  let source = density_source_for_url(preset, official_source)
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
        density_source_locked(source),
      )
    None => (false, "", "", "", "", false)
  }
  let tokens = preset.tokens(scheme~, density~)
  let theme = preset.theme(scheme~, density~)
  let resolves_tokens = tokens.density == density &&
    tokens.spacing.density_multiplier == density.multiplier()
  let resolves_theme = theme == tokens.to_theme() &&
    theme.spacing_scale.sm == tokens.spacing.sm &&
    theme.spacing_scale.md == tokens.spacing.md
  let resolves_components = tokens.components.surface.base_padding ==
    tokens.spacing.md &&
    tokens.components.feedback.padding == tokens.spacing.sm &&
    tokens.components.form_validation.padding == tokens.spacing.md
  let status = if !source_declared ||
    !source_locked ||
    !resolves_tokens ||
    !resolves_theme ||
    !resolves_components {
    DesignTokenStatus::NotMapped
  } else {
    DesignTokenStatus::ThemeMapped
  }
  {
    preset,
    density,
    source_family: density_source_family(preset),
    official_source,
    source_declared,
    source_label,
    source_kind,
    source_ref,
    token_path,
    source_locked,
    tokens_api: "DesignPreset::tokens(..., density=...)",
    theme_api: "DesignPreset::theme(..., density=...)",
    scheme,
    density_multiplier: density.multiplier(),
    spacing_sm: tokens.spacing.sm,
    spacing_md: tokens.spacing.md,
    theme_spacing_sm: theme.spacing_scale.sm,
    theme_spacing_md: theme.spacing_scale.md,
    surface_padding: tokens.components.surface.base_padding,
    feedback_padding: tokens.components.feedback.padding,
    resolves_tokens,
    resolves_theme,
    resolves_components,
    status,
    remaining_gap: density_remaining_gap(preset),
  }
}

///|
fn density_source_family(preset : DesignPreset) -> String {
  match preset {
    Material => "Material density and spacing"
    Carbon => "Carbon productive and expressive density"
    Primer => "Primer size and density primitives"
    Fluent => "Fluent density and spacing tokens"
  }
}

///|
fn density_official_source(preset : DesignPreset) -> String {
  match preset {
    Material => "https://material-web.dev/theming/material-theming/"
    Carbon => "https://carbondesignsystem.com/elements/themes/code/"
    Primer => "https://primer.style/primitives/"
    Fluent => "https://fluent2.microsoft.design/design-tokens"
  }
}

///|
fn density_remaining_gap(preset : DesignPreset) -> String {
  if density_representative_spacing_aligned(preset) {
    "none"
  } else if preset == DesignPreset::Material {
    "Material Web's pinned token source does not expose concrete spacing tokens for the neutral MoUI spacing scale; density remains a MoUI adapter until an official source anchor is available."
  } else {
    "At least one neutral spacing slot lacks a pinned official source-import record that exact-aligns with the current density-aware MoUI spacing scale."
  }
}

///|
fn density_representative_spacing_aligned(preset : DesignPreset) -> Bool {
  for
    slot in [
      "DesignSpacingTokens.xs", "DesignSpacingTokens.sm", "DesignSpacingTokens.md",
      "DesignSpacingTokens.lg", "DesignSpacingTokens.xl",
    ] {
    let mut aligned = false
    for item in preset.runtime_token_alignment_report() {
      if item.moui_token == slot && item.source_imported && item.runtime_aligned {
        aligned = true
      }
    }
    if !aligned {
      return false
    }
  }
  true
}

///|
fn density_source_for_url(
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
fn density_source_locked(source : DesignSystemSource) -> Bool {
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
