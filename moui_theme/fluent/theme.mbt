///|
pub fn preset() -> @common.DesignPreset {
  Fluent
}

///|
pub fn tokens(
  scheme? : @core.ColorScheme = Light,
  density? : @common.DesignDensity = Standard,
) -> @common.DesignSystemTokens {
  preset().tokens(scheme~, density~)
}

///|
pub fn tokens_for_variant(
  variant? : @common.DesignSchemeVariant = SchemeLight,
  system_scheme? : @core.ColorScheme = Light,
  density? : @common.DesignDensity = Standard,
) -> @common.DesignSystemTokens {
  preset().tokens_for_variant(variant~, system_scheme~, density~)
}

///|
pub fn theme(
  scheme? : @core.ColorScheme = Light,
  density? : @common.DesignDensity = Standard,
) -> @core.Theme {
  preset().theme(scheme~, density~)
}

///|
pub fn light_theme(density? : @common.DesignDensity = Standard) -> @core.Theme {
  theme(scheme=Light, density~)
}

///|
pub fn dark_theme(density? : @common.DesignDensity = Standard) -> @core.Theme {
  theme(scheme=Dark, density~)
}

///|
pub fn high_contrast_theme(
  system_scheme? : @core.ColorScheme = Light,
  density? : @common.DesignDensity = Standard,
) -> @core.Theme {
  preset().theme_for_variant(
    variant=SchemeHighContrast,
    system_scheme~,
    density~,
  )
}

///|
pub fn system_theme(
  system_scheme? : @core.ColorScheme = Light,
  density? : @common.DesignDensity = Standard,
) -> @core.Theme {
  preset().theme_for_variant(variant=SchemeSystem, system_scheme~, density~)
}
