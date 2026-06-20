///|
pub(all) struct DesignTokenGroupResolverRecord {
  preset : @common.DesignPreset
  requirement : DesignSystemRequirement
  category : DesignTokenCategory
  source_family : String
  official_source : String
  source_declared : Bool
  source_label : String
  source_kind : String
  source_ref : String
  token_path : String
  source_locked : Bool
  token_surface : String
  tokens_api : String
  theme_api : String
  scheme : @core.ColorScheme
  resolves_tokens : Bool
  resolves_neutral_surface : Bool
  status : DesignTokenStatus
  remaining_gap : String
} derive(Eq, Debug, ToJson)

///|
pub fn token_group_resolver_report(
  preset : @common.DesignPreset,
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
) -> Array[DesignTokenGroupResolverRecord] {
  [
    token_group_resolver_record(
      preset,
      DesignSystemRequirement::SemanticPalette,
      DesignTokenCategory::Color,
      scheme,
    ),
    token_group_resolver_record(
      preset,
      DesignSystemRequirement::Typography,
      DesignTokenCategory::Typography,
      scheme,
    ),
    token_group_resolver_record(
      preset,
      DesignSystemRequirement::ShapeRadius,
      DesignTokenCategory::Shape,
      scheme,
    ),
    token_group_resolver_record(
      preset,
      DesignSystemRequirement::ElevationShadow,
      DesignTokenCategory::Elevation,
      scheme,
    ),
    token_group_resolver_record(
      preset,
      DesignSystemRequirement::Motion,
      DesignTokenCategory::Motion,
      scheme,
    ),
    token_group_resolver_record(
      preset,
      DesignSystemRequirement::Surface,
      DesignTokenCategory::Surface,
      scheme,
    ),
    token_group_resolver_record(
      preset,
      DesignSystemRequirement::StateLayer,
      DesignTokenCategory::StateLayer,
      scheme,
    ),
  ]
}

///|
pub fn token_group_resolver_for(
  preset : @common.DesignPreset,
  requirement : DesignSystemRequirement,
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
) -> DesignTokenGroupResolverRecord? {
  for item in token_group_resolver_report(preset, scheme~) {
    if item.requirement == requirement {
      return Some(item)
    }
  }
  None
}

///|
pub fn token_group_resolver_count(preset : @common.DesignPreset) -> Int {
  token_group_resolver_report(preset).length()
}

///|
pub fn token_group_resolver_gap_count(preset : @common.DesignPreset) -> Int {
  let mut count = 0
  for item in token_group_resolver_report(preset) {
    if !item.resolves_tokens ||
      !item.resolves_neutral_surface ||
      item.status == DesignTokenStatus::NotMapped ||
      item.status == DesignTokenStatus::SourceMapped ||
      item.status == DesignTokenStatus::PreviewMapped {
      count = count + 1
    }
  }
  count
}

///|
pub fn token_group_resolver_source_gap_count(
  preset : @common.DesignPreset,
) -> Int {
  let mut count = 0
  for item in token_group_resolver_report(preset) {
    if !item.source_declared || !item.source_locked {
      count = count + 1
    }
  }
  count
}

///|
pub fn token_group_resolver_official_parity_gap_count(
  preset : @common.DesignPreset,
) -> Int {
  let mut count = 0
  for item in token_group_resolver_report(preset) {
    if item.remaining_gap != "none" {
      count = count + 1
    }
  }
  count
}

///|
fn token_group_requirement_supported(
  requirement : DesignSystemRequirement,
) -> Bool {
  match requirement {
    DesignSystemRequirement::SemanticPalette
    | DesignSystemRequirement::Typography
    | DesignSystemRequirement::ShapeRadius
    | DesignSystemRequirement::ElevationShadow
    | DesignSystemRequirement::Motion
    | DesignSystemRequirement::Surface
    | DesignSystemRequirement::StateLayer => true
    _ => false
  }
}

///|
fn token_group_resolver_count_for(
  preset : @common.DesignPreset,
  requirement : DesignSystemRequirement,
) -> Int {
  let mut count = 0
  for item in token_group_resolver_report(preset) {
    if item.requirement == requirement {
      count = count + 1
    }
  }
  count
}

///|
fn token_group_resolver_gap_count_for(
  preset : @common.DesignPreset,
  requirement : DesignSystemRequirement,
) -> Int {
  let mut count = 0
  for item in token_group_resolver_report(preset) {
    if item.requirement == requirement &&
      (
        !item.resolves_tokens ||
        !item.resolves_neutral_surface ||
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
fn token_group_resolver_source_gap_count_for(
  preset : @common.DesignPreset,
  requirement : DesignSystemRequirement,
) -> Int {
  let mut count = 0
  for item in token_group_resolver_report(preset) {
    if item.requirement == requirement &&
      (!item.source_declared || !item.source_locked) {
      count = count + 1
    }
  }
  count
}

///|
fn token_group_resolver_parity_gap_count_for(
  preset : @common.DesignPreset,
  requirement : DesignSystemRequirement,
) -> Int {
  let mut count = 0
  for item in token_group_resolver_report(preset) {
    if item.requirement == requirement && item.remaining_gap != "none" {
      count = count + 1
    }
  }
  count
}

///|
fn token_group_resolver_record(
  preset : @common.DesignPreset,
  requirement : DesignSystemRequirement,
  category : DesignTokenCategory,
  scheme : @core.ColorScheme,
) -> DesignTokenGroupResolverRecord {
  let coverage = token_group_coverage_for(preset, category)
  let official_source = token_group_official_source(preset, requirement)
  let source = token_group_source_for_url(preset, official_source)
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
        token_group_source_locked(source),
      )
    None => (false, "", "", "", "", false)
  }
  let tokens = preset.tokens(scheme~)
  let theme = preset.theme(scheme~)
  let resolves_tokens = token_group_resolves_tokens(tokens, requirement)
  let resolves_neutral_surface = token_group_resolves_neutral_surface(
    tokens, theme, requirement,
  )
  let status = if !source_declared ||
    !source_locked ||
    !resolves_tokens ||
    !resolves_neutral_surface {
    DesignTokenStatus::NotMapped
  } else if requirement == DesignSystemRequirement::StateLayer {
    DesignTokenStatus::ComponentMapped
  } else {
    DesignTokenStatus::ThemeMapped
  }
  {
    preset,
    requirement,
    category,
    source_family: if coverage.source_family == "" {
      requirement.label()
    } else {
      coverage.source_family
    },
    official_source,
    source_declared,
    source_label,
    source_kind,
    source_ref,
    token_path,
    source_locked,
    token_surface: token_group_surface(requirement, coverage.moui_surface),
    tokens_api: "@common.DesignPreset::tokens(...)",
    theme_api: token_group_theme_api(requirement),
    scheme,
    resolves_tokens,
    resolves_neutral_surface,
    status,
    remaining_gap: token_group_remaining_gap(requirement),
  }
}

///|
fn token_group_resolves_tokens(
  tokens : @common.DesignSystemTokens,
  requirement : DesignSystemRequirement,
) -> Bool {
  match requirement {
    DesignSystemRequirement::SemanticPalette =>
      tokens.palette.foreground != tokens.palette.background &&
      tokens.palette.primary != tokens.palette.background &&
      tokens.palette.focus.a > 0.0 &&
      tokens.palette.scrim.a > 0.0
    DesignSystemRequirement::Typography =>
      tokens.typography.body.size > 0.0 && tokens.typography.control.size > 0.0
    DesignSystemRequirement::ShapeRadius =>
      tokens.radius.md >= tokens.radius.sm &&
      tokens.radius.pill >= tokens.radius.lg
    DesignSystemRequirement::ElevationShadow =>
      tokens.elevation.md.blur_radius >= tokens.elevation.sm.blur_radius
    DesignSystemRequirement::Motion =>
      tokens.motion.normal_ms >= tokens.motion.fast_ms
    DesignSystemRequirement::Surface =>
      tokens.surfaces.core_surfaces().base == tokens.surfaces.base &&
      tokens.surfaces.core_surfaces().raised == tokens.surfaces.raised &&
      tokens.surfaces.core_surfaces().overlay == tokens.surfaces.overlay
    DesignSystemRequirement::StateLayer =>
      tokens.state_layer.hover_alpha > 0.0 &&
      tokens.state_layer.disabled_alpha > tokens.state_layer.hover_alpha
    _ => false
  }
}

///|
fn token_group_resolves_neutral_surface(
  tokens : @common.DesignSystemTokens,
  theme : @core.Theme,
  requirement : DesignSystemRequirement,
) -> Bool {
  match requirement {
    DesignSystemRequirement::SemanticPalette =>
      theme.palette == tokens.palette.core_palette(tokens.scheme)
    DesignSystemRequirement::Typography =>
      theme.typography == tokens.typography.core_typography()
    DesignSystemRequirement::ShapeRadius =>
      theme.radius_scale == tokens.radius.core_radius_scale()
    DesignSystemRequirement::ElevationShadow =>
      theme.shadow_scale == tokens.elevation.core_shadow_scale()
    DesignSystemRequirement::Motion =>
      theme.motion == tokens.motion.core_motion()
    DesignSystemRequirement::Surface =>
      theme.surfaces == tokens.surfaces.core_surfaces()
    DesignSystemRequirement::StateLayer =>
      tokens.components.button.primary.state_layer_alpha ==
      tokens.state_layer.pressed_alpha &&
      tokens.components.button.tonal.state_layer_alpha ==
      tokens.state_layer.hover_alpha &&
      tokens.components.text_field.focused.state_layer_alpha ==
      tokens.state_layer.focus_alpha &&
      tokens.components.text_field.disabled.state_layer_alpha ==
      tokens.state_layer.disabled_alpha
    _ => false
  }
}

///|
fn token_group_theme_api(requirement : DesignSystemRequirement) -> String {
  match requirement {
    DesignSystemRequirement::SemanticPalette =>
      "@common.DesignSemanticPalette::core_palette/core_semantic_colors -> @core.Theme"
    DesignSystemRequirement::Typography =>
      "@common.DesignTypographyTokens::core_typography -> @core.Theme"
    DesignSystemRequirement::ShapeRadius =>
      "@common.DesignRadiusTokens::core_radius_scale -> @core.Theme"
    DesignSystemRequirement::ElevationShadow =>
      "@common.DesignElevationTokens::core_shadow_scale -> @core.Theme"
    DesignSystemRequirement::Motion =>
      "@common.DesignMotionTokens::core_motion -> @core.Theme"
    DesignSystemRequirement::Surface =>
      "@common.DesignSurfaceTokens::core_surfaces -> @core.Theme"
    DesignSystemRequirement::StateLayer =>
      "@common.DesignStateLayerTokens -> @common.DesignComponentTokens"
    _ => ""
  }
}

///|
fn token_group_surface(
  requirement : DesignSystemRequirement,
  coverage_surface : String,
) -> String {
  let fallback = token_group_theme_api(requirement)
  let surface = if coverage_surface == "" { fallback } else { coverage_surface }
  match requirement {
    DesignSystemRequirement::SemanticPalette =>
      "@common.DesignSemanticPalette -> " + surface
    DesignSystemRequirement::Typography =>
      "@common.DesignTypographyTokens -> " + surface
    DesignSystemRequirement::ShapeRadius =>
      "@common.DesignRadiusTokens -> " + surface
    DesignSystemRequirement::ElevationShadow =>
      "@common.DesignElevationTokens -> " + surface
    DesignSystemRequirement::Motion =>
      "@common.DesignMotionTokens -> " + surface
    DesignSystemRequirement::Surface =>
      "@common.DesignSurfaceTokens -> " + surface
    DesignSystemRequirement::StateLayer =>
      "@common.DesignStateLayerTokens -> " + surface
    _ => surface
  }
}

///|
fn token_group_coverage_for(
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
    layer: DesignTokenLayer::MoUIAdapter,
    source_family: "",
    moui_surface: "",
    status: DesignTokenStatus::NotMapped,
    note: "Missing token coverage row.",
  }
}

///|
fn token_group_official_source(
  preset : @common.DesignPreset,
  requirement : DesignSystemRequirement,
) -> String {
  match preset {
    Material =>
      match requirement {
        DesignSystemRequirement::SemanticPalette
        | DesignSystemRequirement::Surface =>
          "https://material-web.dev/theming/color/"
        _ => "https://material-web.dev/theming/material-theming/"
      }
    Carbon =>
      match requirement {
        DesignSystemRequirement::SemanticPalette
        | DesignSystemRequirement::Surface
        | DesignSystemRequirement::StateLayer =>
          "https://carbondesignsystem.com/elements/color/tokens/"
        _ => "https://carbondesignsystem.com/elements/themes/code/"
      }
    Primer =>
      match requirement {
        DesignSystemRequirement::SemanticPalette
        | DesignSystemRequirement::Surface
        | DesignSystemRequirement::StateLayer =>
          "https://primer.style/product/primitives/color/"
        _ => "https://primer.style/primitives/"
      }
    Fluent =>
      match requirement {
        DesignSystemRequirement::SemanticPalette
        | DesignSystemRequirement::Surface
        | DesignSystemRequirement::StateLayer =>
          "https://fluent2.microsoft.design/theming"
        _ => "https://fluent2.microsoft.design/design-tokens"
      }
  }
}

///|
fn token_group_remaining_gap(requirement : DesignSystemRequirement) -> String {
  "Official " +
  requirement.label() +
  " token matrix is not fully imported; this resolver proves the current neutral MoUI adapter only."
}

///|
fn token_group_source_for_url(
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
fn token_group_source_locked(source : DesignSystemSource) -> Bool {
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
