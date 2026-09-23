// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of
// trait methods as regular methods (`derive(Eq, Debug)` making
// `x.equal(y)` and `x.to_repr()` resolve). Each promotion is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the
// promotions out of the generated interface, leaving the package's
// public API unchanged.

///|
#doc(hidden)
pub extend AccessibilityContrast with ToJson::{to_json}

///|
#doc(hidden)
pub extend ActionCommand with ToJson::{to_json}

///|
#doc(hidden)
pub extend Alignment with ToJson::{to_json}

///|
#doc(hidden)
pub extend AlignmentGuideSet with ToJson::{to_json}

///|
#doc(hidden)
pub extend AnimationStatus with ToJson::{to_json}

///|
#doc(hidden)
pub extend AppEvent with ToJson::{to_json}

///|
#doc(hidden)
pub extend Axis with ToJson::{to_json}

///|
#doc(hidden)
pub extend BlendMode with ToJson::{to_json}

///|
#doc(hidden)
pub extend BorderStyle with ToJson::{to_json}

///|
#doc(hidden)
pub extend Brush with ToJson::{to_json}

///|
#doc(hidden)
pub extend Color with ToJson::{to_json}

///|
#doc(hidden)
pub extend ColorMode with ToJson::{to_json}

///|
#doc(hidden)
pub extend ColorPalette with ToJson::{to_json}

///|
#doc(hidden)
pub extend ColorScheme with ToJson::{to_json}

///|
#doc(hidden)
pub extend CommandIntent with ToJson::{to_json}

///|
#doc(hidden)
pub extend CompositionUpdate with ToJson::{to_json}

///|
#doc(hidden)
pub extend Constraints with ToJson::{to_json}

///|
#doc(hidden)
pub extend ContentSizeCategory with ToJson::{to_json}

///|
#doc(hidden)
pub extend CrossAxisAlignment with ToJson::{to_json}

///|
#doc(hidden)
pub extend DamageRegion with ToJson::{to_json}

///|
#doc(hidden)
pub extend DateValue with ToJson::{to_json}

///|
#doc(hidden)
pub extend DragDropEvent with ToJson::{to_json}

///|
#doc(hidden)
pub extend DragDropPhase with ToJson::{to_json}

///|
#doc(hidden)
pub extend DragGestureEvent with ToJson::{to_json}

///|
#doc(hidden)
pub extend DragGesturePhase with ToJson::{to_json}

///|
#doc(hidden)
pub extend DrawCommand with ToJson::{to_json}

///|
#doc(hidden)
pub extend DrawFrame with ToJson::{to_json}

///|
#doc(hidden)
pub extend Easing with ToJson::{to_json}

///|
#doc(hidden)
pub extend EffectDescriptor with ToJson::{to_json}

///|
#doc(hidden)
pub extend Environment with ToJson::{to_json}

///|
#doc(hidden)
pub extend FilterEffect with ToJson::{to_json}

///|
#doc(hidden)
pub extend FocusRequest with ToJson::{to_json}

///|
#doc(hidden)
pub extend FocusTraversalDirection with ToJson::{to_json}

///|
#doc(hidden)
pub extend FontFamily with ToJson::{to_json}

///|
#doc(hidden)
pub extend FontFamilyStack with ToJson::{to_json}

///|
#doc(hidden)
pub extend FontSpec with ToJson::{to_json}

///|
#doc(hidden)
pub extend FontStyle with ToJson::{to_json}

///|
#doc(hidden)
pub extend FontVariation with ToJson::{to_json}

///|
#doc(hidden)
pub extend Frame with ToJson::{to_json}

///|
#doc(hidden)
pub extend ImageFit with ToJson::{to_json}

///|
#doc(hidden)
pub extend ImageRun with ToJson::{to_json}

///|
#doc(hidden)
pub extend Insets with ToJson::{to_json}

///|
#doc(hidden)
pub extend InteractionState with ToJson::{to_json}

///|
#doc(hidden)
pub extend KeyModifiers with ToJson::{to_json}

///|
#doc(hidden)
pub extend KeyboardEvent with ToJson::{to_json}

///|
#doc(hidden)
pub extend KeyboardShortcut with ToJson::{to_json}

///|
#doc(hidden)
pub extend LayerMask with ToJson::{to_json}

///|
#doc(hidden)
pub extend LayerSpec with ToJson::{to_json}

///|
#doc(hidden)
pub extend LayoutDirection with ToJson::{to_json}

///|
#doc(hidden)
pub extend LayoutResult with ToJson::{to_json}

///|
#doc(hidden)
pub extend LinearGradientSpec with ToJson::{to_json}

///|
#doc(hidden)
pub extend MainAxisAlignment with ToJson::{to_json}

///|
#doc(hidden)
pub extend MotionScale with ToJson::{to_json}

///|
#doc(hidden)
pub extend PathSpec with ToJson::{to_json}

///|
#doc(hidden)
pub extend PathVerb with ToJson::{to_json}

///|
#doc(hidden)
pub extend PlatformViewEvent with ToJson::{to_json}

///|
#doc(hidden)
pub extend PlatformViewPlacement with ToJson::{to_json}

///|
#doc(hidden)
pub extend PlatformViewProperty with ToJson::{to_json}

///|
#doc(hidden)
pub extend Point with ToJson::{to_json}

///|
#doc(hidden)
pub extend PointerEvent with ToJson::{to_json}

///|
#doc(hidden)
pub extend PointerPhase with ToJson::{to_json}

///|
#doc(hidden)
pub extend PressableState with ToJson::{to_json}

///|
#doc(hidden)
pub extend RadialGradientSpec with ToJson::{to_json}

///|
#doc(hidden)
pub extend RadiusScale with ToJson::{to_json}

///|
#doc(hidden)
pub extend Rect with ToJson::{to_json}

///|
#doc(hidden)
pub extend RedrawReason with ToJson::{to_json}

///|
#doc(hidden)
pub extend RetainedLayerSpec with ToJson::{to_json}

///|
#doc(hidden)
pub extend RoundedRect with ToJson::{to_json}

///|
#doc(hidden)
pub extend ScrollRequest with ToJson::{to_json}

///|
#doc(hidden)
pub extend ShaderEffectSpec with ToJson::{to_json}

///|
#doc(hidden)
pub extend ShadowScale with ToJson::{to_json}

///|
#doc(hidden)
pub extend ShadowSpec with ToJson::{to_json}

///|
#doc(hidden)
pub extend ShadowStyle with ToJson::{to_json}

///|
#doc(hidden)
pub extend Size with ToJson::{to_json}

///|
#doc(hidden)
pub extend SpacingScale with ToJson::{to_json}

///|
#doc(hidden)
pub extend SubscriptionDescriptor with ToJson::{to_json}

///|
#doc(hidden)
pub extend SurfaceLevel with ToJson::{to_json}

///|
#doc(hidden)
pub extend SurfaceMetrics with ToJson::{to_json}

///|
#doc(hidden)
pub extend SurfaceScale with ToJson::{to_json}

///|
#doc(hidden)
pub extend TextAlign with ToJson::{to_json}

///|
#doc(hidden)
pub extend TextCommandResult with ToJson::{to_json}

///|
#doc(hidden)
pub extend TextControlStateContext with ToJson::{to_json}

///|
#doc(hidden)
pub extend TextHistoryEntryContext with ToJson::{to_json}

///|
#doc(hidden)
pub extend TextInputEvent with ToJson::{to_json}

///|
#doc(hidden)
pub extend TextInputState with ToJson::{to_json}

///|
#doc(hidden)
pub extend TextLayoutInput with ToJson::{to_json}

///|
#doc(hidden)
pub extend TextLayoutResult with ToJson::{to_json}

///|
#doc(hidden)
pub extend TextParagraphHitTestResult with ToJson::{to_json}

///|
#doc(hidden)
pub extend TextParagraphLayoutMetadata with ToJson::{to_json}

///|
#doc(hidden)
pub extend TextParagraphLayoutResult with ToJson::{to_json}

///|
#doc(hidden)
pub extend TextParagraphLineMetrics with ToJson::{to_json}

///|
#doc(hidden)
pub extend TextParagraphVisualOrderMetadata with ToJson::{to_json}

///|
#doc(hidden)
pub extend TextRange with ToJson::{to_json}

///|
#doc(hidden)
pub extend TextRun with ToJson::{to_json}

///|
#doc(hidden)
pub extend Theme with ToJson::{to_json}

///|
#doc(hidden)
pub extend ThemeDensity with ToJson::{to_json}

///|
#doc(hidden)
pub extend ThemePreset with ToJson::{to_json}

///|
#doc(hidden)
pub extend ThemeSpec with ToJson::{to_json}

///|
#doc(hidden)
pub extend Transform2D with ToJson::{to_json}

///|
#doc(hidden)
pub extend TransitionSample with ToJson::{to_json}

///|
#doc(hidden)
pub extend TransitionSpec with ToJson::{to_json}

///|
#doc(hidden)
pub extend TransitionStyle with ToJson::{to_json}

///|
#doc(hidden)
pub extend TypographyScale with ToJson::{to_json}

///|
#doc(hidden)
pub extend ViewLayoutResult with ToJson::{to_json}

///|
#doc(hidden)
pub extend ViewSemanticsInfo with ToJson::{to_json}

///|
#doc(hidden)
pub extend ViewStyle with ToJson::{to_json}

///|
#doc(hidden)
pub extend VisualStyle with ToJson::{to_json}

///|
#doc(hidden)
pub extend ScrollAlignment with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticId with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsAction with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsActionKind with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsCheckedState with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsCollectionInfo with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsComposition with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsGeneration with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsLive with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsNode with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsNodeId with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsNumericValue with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsRelationKind with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsRelations with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsRelationsDeclaration with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsRole with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsScrollDirection with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsState with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsTarget with ToJson::{to_json}

///|
#doc(hidden)
pub extend SemanticsTextValue with ToJson::{to_json}
