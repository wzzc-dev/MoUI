///|
pub fn preset() -> @common.DesignPreset {
  @common.DesignPreset::Fluent
}

///|
pub fn tokens(
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
  density? : @common.DesignDensity = @common.DesignDensity::Standard,
) -> @common.DesignSystemTokens {
  preset().tokens(scheme~, density~)
}

///|
pub fn tokens_for_variant(
  variant? : @common.DesignSchemeVariant = @common.DesignSchemeVariant::SchemeLight,
  system_scheme? : @core.ColorScheme = @core.ColorScheme::Light,
  density? : @common.DesignDensity = @common.DesignDensity::Standard,
) -> @common.DesignSystemTokens {
  preset().tokens_for_variant(variant~, system_scheme~, density~)
}

///|
pub fn theme(
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
  density? : @common.DesignDensity = @common.DesignDensity::Standard,
) -> @core.Theme {
  preset().theme(scheme~, density~)
}

///|
pub fn light_theme(
  density? : @common.DesignDensity = @common.DesignDensity::Standard,
) -> @core.Theme {
  theme(scheme=@core.ColorScheme::Light, density~)
}

///|
pub fn dark_theme(
  density? : @common.DesignDensity = @common.DesignDensity::Standard,
) -> @core.Theme {
  theme(scheme=@core.ColorScheme::Dark, density~)
}

///|
pub fn high_contrast_theme(
  system_scheme? : @core.ColorScheme = @core.ColorScheme::Light,
  density? : @common.DesignDensity = @common.DesignDensity::Standard,
) -> @core.Theme {
  preset().theme_for_variant(
    variant=@common.DesignSchemeVariant::SchemeHighContrast,
    system_scheme~,
    density~,
  )
}

///|
pub fn system_theme(
  system_scheme? : @core.ColorScheme = @core.ColorScheme::Light,
  density? : @common.DesignDensity = @common.DesignDensity::Standard,
) -> @core.Theme {
  preset().theme_for_variant(
    variant=@common.DesignSchemeVariant::SchemeSystem,
    system_scheme~,
    density~,
  )
}

///|
pub fn report(
  scheme? : @core.ColorScheme = @core.ColorScheme::Light,
  system_scheme? : @core.ColorScheme = @core.ColorScheme::Dark,
  density? : @common.DesignDensity = @common.DesignDensity::Standard,
) -> @common.DesignSystemReport {
  preset().design_system_report(scheme~, system_scheme~, density~)
}

///|
pub fn manifest() -> @common.DesignSystemManifest {
  preset().manifest()
}

///|
pub fn component_token_matrix() -> Array[
  @common.DesignComponentTokenMatrixRecord,
] {
  preset().component_token_matrix()
}
