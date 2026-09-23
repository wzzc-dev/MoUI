// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend BadgeStyle with Debug::{to_repr}

///|
#doc(hidden)
pub extend BadgeStyle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend BadgeStyle with ToJson::{to_json}

///|
#doc(hidden)
pub extend BadgeTheme with Debug::{to_repr}

///|
#doc(hidden)
pub extend BadgeTheme with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend BadgeTheme with ToJson::{to_json}

///|
#doc(hidden)
pub extend BadgeTone with Debug::{to_repr}

///|
#doc(hidden)
pub extend BadgeTone with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend BadgeTone with Show::{to_string, output}

///|
#doc(hidden)
pub extend BadgeTone with ToJson::{to_json}

///|
#doc(hidden)
pub extend ButtonStyle with Debug::{to_repr}

///|
#doc(hidden)
pub extend ButtonStyle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ButtonStyle with ToJson::{to_json}

///|
#doc(hidden)
pub extend ButtonTheme with Debug::{to_repr}

///|
#doc(hidden)
pub extend ButtonTheme with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ButtonTheme with ToJson::{to_json}

///|
#doc(hidden)
pub extend ButtonVariant with Debug::{to_repr}

///|
#doc(hidden)
pub extend ButtonVariant with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ButtonVariant with ToJson::{to_json}

///|
#doc(hidden)
pub extend ButtonVariantToken with Debug::{to_repr}

///|
#doc(hidden)
pub extend ButtonVariantToken with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ButtonVariantToken with ToJson::{to_json}

///|
#doc(hidden)
pub extend CheckMarkStyle with Debug::{to_repr}

///|
#doc(hidden)
pub extend CheckMarkStyle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend CheckMarkStyle with ToJson::{to_json}

///|
#doc(hidden)
pub extend ChipVariant with Debug::{to_repr}

///|
#doc(hidden)
pub extend ChipVariant with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ChipVariant with Show::{to_string, output}

///|
#doc(hidden)
pub extend ChipVariant with ToJson::{to_json}

///|
#doc(hidden)
pub extend ChoiceControlShape with Debug::{to_repr}

///|
#doc(hidden)
pub extend ChoiceControlShape with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ChoiceControlShape with ToJson::{to_json}

///|
#doc(hidden)
pub extend ChoiceControlStyle with Debug::{to_repr}

///|
#doc(hidden)
pub extend ChoiceControlStyle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ChoiceControlStyle with ToJson::{to_json}

///|
#doc(hidden)
pub extend ChoiceControlTheme with Debug::{to_repr}

///|
#doc(hidden)
pub extend ChoiceControlTheme with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ChoiceControlTheme with ToJson::{to_json}

///|
#doc(hidden)
pub extend ContainerVariant with Debug::{to_repr}

///|
#doc(hidden)
pub extend ContainerVariant with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ContainerVariant with Show::{to_string, output}

///|
#doc(hidden)
pub extend ContainerVariant with ToJson::{to_json}

///|
#doc(hidden)
pub extend ControlStateStyle with Debug::{to_repr}

///|
#doc(hidden)
pub extend ControlStateStyle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ControlStateStyle with ToJson::{to_json}

///|
#doc(hidden)
pub extend ControlStateTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend ControlStateTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ControlStateTokens with ToJson::{to_json}

///|
#doc(hidden)
pub extend ControlThemeSet with Debug::{to_repr}

///|
#doc(hidden)
pub extend ControlThemeSet with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ControlThemeSet with ToJson::{to_json}

///|
#doc(hidden)
pub extend CrossAlign with Debug::{to_repr}

///|
#doc(hidden)
pub extend CrossAlign with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend CrossAlign with Show::{to_string, output}

///|
#doc(hidden)
pub extend CrossAlign with ToJson::{to_json}

///|
#doc(hidden)
pub extend DatePickerMode with Debug::{to_repr}

///|
#doc(hidden)
pub extend DatePickerMode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DatePickerMode with Show::{to_string, output}

///|
#doc(hidden)
pub extend DatePickerMode with ToJson::{to_json}

///|
#doc(hidden)
pub extend FeedbackStyle with Debug::{to_repr}

///|
#doc(hidden)
pub extend FeedbackStyle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FeedbackStyle with ToJson::{to_json}

///|
#doc(hidden)
pub extend FeedbackTheme with Debug::{to_repr}

///|
#doc(hidden)
pub extend FeedbackTheme with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FeedbackTheme with ToJson::{to_json}

///|
#doc(hidden)
pub extend FeedbackTone with Debug::{to_repr}

///|
#doc(hidden)
pub extend FeedbackTone with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FeedbackTone with Show::{to_string, output}

///|
#doc(hidden)
pub extend FeedbackTone with ToJson::{to_json}

///|
#doc(hidden)
pub extend FormValidationStyle with Debug::{to_repr}

///|
#doc(hidden)
pub extend FormValidationStyle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FormValidationStyle with ToJson::{to_json}

///|
#doc(hidden)
pub extend FormValidationTheme with Debug::{to_repr}

///|
#doc(hidden)
pub extend FormValidationTheme with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FormValidationTheme with ToJson::{to_json}

///|
#doc(hidden)
pub extend IconName with Debug::{to_repr}

///|
#doc(hidden)
pub extend IconName with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend IconName with ToJson::{to_json}

///|
#doc(hidden)
pub extend MainAlign with Debug::{to_repr}

///|
#doc(hidden)
pub extend MainAlign with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MainAlign with Show::{to_string, output}

///|
#doc(hidden)
pub extend MainAlign with ToJson::{to_json}

///|
#doc(hidden)
pub extend PickerStyle with Debug::{to_repr}

///|
#doc(hidden)
pub extend PickerStyle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PickerStyle with ToJson::{to_json}

///|
#doc(hidden)
pub extend PickerTheme with Debug::{to_repr}

///|
#doc(hidden)
pub extend PickerTheme with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PickerTheme with ToJson::{to_json}

///|
#doc(hidden)
pub extend ProgressStyle with Debug::{to_repr}

///|
#doc(hidden)
pub extend ProgressStyle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ProgressStyle with ToJson::{to_json}

///|
#doc(hidden)
pub extend ProgressTheme with Debug::{to_repr}

///|
#doc(hidden)
pub extend ProgressTheme with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ProgressTheme with ToJson::{to_json}

///|
#doc(hidden)
pub extend SegmentedControlSize with Debug::{to_repr}

///|
#doc(hidden)
pub extend SegmentedControlSize with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SegmentedControlSize with Show::{to_string, output}

///|
#doc(hidden)
pub extend SegmentedControlSize with ToJson::{to_json}

///|
#doc(hidden)
pub extend SheetPresentationMode with Debug::{to_repr}

///|
#doc(hidden)
pub extend SheetPresentationMode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SheetPresentationMode with Show::{to_string, output}

///|
#doc(hidden)
pub extend SheetPresentationMode with ToJson::{to_json}

///|
#doc(hidden)
pub extend SliderStyle with Debug::{to_repr}

///|
#doc(hidden)
pub extend SliderStyle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SliderStyle with ToJson::{to_json}

///|
#doc(hidden)
pub extend SliderTheme with Debug::{to_repr}

///|
#doc(hidden)
pub extend SliderTheme with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SliderTheme with ToJson::{to_json}

///|
#doc(hidden)
pub extend StateLayerTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend StateLayerTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend StateLayerTokens with ToJson::{to_json}

///|
#doc(hidden)
pub extend SurfaceStyle with Debug::{to_repr}

///|
#doc(hidden)
pub extend SurfaceStyle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SurfaceStyle with ToJson::{to_json}

///|
#doc(hidden)
pub extend SurfaceTheme with Debug::{to_repr}

///|
#doc(hidden)
pub extend SurfaceTheme with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SurfaceTheme with ToJson::{to_json}

///|
#doc(hidden)
pub extend TextFieldAppearance with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextFieldAppearance with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextFieldAppearance with ToJson::{to_json}

///|
#doc(hidden)
pub extend TextFieldStyle with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextFieldStyle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextFieldStyle with ToJson::{to_json}

///|
#doc(hidden)
pub extend TextFieldTheme with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextFieldTheme with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextFieldTheme with ToJson::{to_json}

///|
#doc(hidden)
pub extend TextFieldVariant with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextFieldVariant with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextFieldVariant with Show::{to_string, output}

///|
#doc(hidden)
pub extend TextFieldVariant with ToJson::{to_json}

///|
#doc(hidden)
pub extend TextRole with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextRole with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextRole with Show::{to_string, output}

///|
#doc(hidden)
pub extend TextRole with ToJson::{to_json}

///|
#doc(hidden)
pub extend TextStyle with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextStyle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextStyle with ToJson::{to_json}

///|
#doc(hidden)
pub extend ThumbShape with Debug::{to_repr}

///|
#doc(hidden)
pub extend ThumbShape with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ThumbShape with ToJson::{to_json}

///|
#doc(hidden)
pub extend ToneStyle with Debug::{to_repr}

///|
#doc(hidden)
pub extend ToneStyle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ToneStyle with ToJson::{to_json}

///|
#doc(hidden)
pub extend ToneTokens with Debug::{to_repr}

///|
#doc(hidden)
pub extend ToneTokens with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ToneTokens with ToJson::{to_json}
