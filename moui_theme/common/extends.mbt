// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend DesignBadgeTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignBadgeTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignBadgeTokens with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignButtonCoreStyles with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignButtonCoreStyles with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignButtonCoreStyles with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignButtonTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignButtonTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignButtonTokens with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignChoiceControlTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignChoiceControlTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignChoiceControlTokens with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignComponentTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignComponentTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignComponentTokens with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignControlStateTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignControlStateTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignControlStateTokens with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignCoreComponentStyles with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignCoreComponentStyles with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignCoreComponentStyles with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignDensity with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignDensity with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignDensity with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignElevationTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignElevationTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignElevationTokens with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignFeedbackTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignFeedbackTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignFeedbackTokens with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignFormValidationTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignFormValidationTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignFormValidationTokens with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignMotionTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignMotionTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignMotionTokens with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignPickerTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignPickerTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignPickerTokens with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignPreset with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignPreset with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignPreset with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignProgressTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignProgressTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignProgressTokens with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignRadiusTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignRadiusTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignRadiusTokens with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignSchemeVariant with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignSchemeVariant with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignSchemeVariant with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignSemanticPalette with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignSemanticPalette with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignSemanticPalette with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignSliderTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignSliderTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignSliderTokens with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignSpacingTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignSpacingTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignSpacingTokens with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignStateLayerTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignStateLayerTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignStateLayerTokens with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignSurfaceComponentTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignSurfaceComponentTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignSurfaceComponentTokens with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignSurfaceCoreStyles with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignSurfaceCoreStyles with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignSurfaceCoreStyles with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignSurfaceTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignSurfaceTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignSurfaceTokens with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignSystemTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignSystemTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignSystemTokens with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignTextFieldAppearance with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignTextFieldAppearance with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignTextFieldAppearance with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignTextFieldCoreStyles with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignTextFieldCoreStyles with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignTextFieldCoreStyles with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignTextFieldTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignTextFieldTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignTextFieldTokens with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignToneTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignToneTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignToneTokens with ToJson::{to_json}

///|
#doc(hidden)
pub extend DesignTypographyTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend DesignTypographyTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DesignTypographyTokens with ToJson::{to_json}
