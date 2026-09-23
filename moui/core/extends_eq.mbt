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
pub extend AccessibilityContrast with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ActionCommand with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Alignment with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AlignmentGuideSet with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AnimationStatus with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend AppEvent with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Axis with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend BlendMode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend BorderStyle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Brush with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ChildLayoutInfo with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Color with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ColorMode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ColorPalette with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ColorScheme with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend CommandIntent with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend CompositionUpdate with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Constraints with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ContentSizeCategory with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend CrossAxisAlignment with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DamageRegion with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DateValue with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DeclarationChanges with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DeclarationChannel with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DeclarationKey with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DragDropEvent with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DragDropPhase with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DragGestureEvent with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DragGesturePhase with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DrawCommand with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend DrawFrame with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Easing with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend EffectDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Environment with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FilterEffect with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FocusRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FocusScope with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FocusScopeItem with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FocusTraversalDirection with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FontFamily with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FontFamilyStack with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FontSpec with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FontStyle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FontVariation with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Frame with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ImageFit with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ImageRun with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Insets with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend InteractionState with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Key with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend KeyModifiers with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend KeyboardEvent with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend KeyboardShortcut with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend LayerMask with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend LayerSpec with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend LayoutDirection with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend LayoutResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend LinearGradientSpec with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MainAxisAlignment with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MotionScale with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PathSpec with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PathVerb with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PlatformViewEvent with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PlatformViewPlacement with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PlatformViewProperty with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Point with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PointerEvent with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PointerPhase with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend PressableState with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RadialGradientSpec with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RadiusScale with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Rect with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RedrawReason with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RetainedLayerSpec with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend RoundedRect with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ScrollRequest with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ShaderEffectSpec with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ShadowScale with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ShadowSpec with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ShadowStyle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Size with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SpacingScale with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SubscriptionDescriptor with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SurfaceLevel with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SurfaceMetrics with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SurfaceScale with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextAlign with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextCommandResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextControlStateContext with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextHistoryEntryContext with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextInputEvent with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextInputState with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextLayoutInput with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextLayoutResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextParagraphHitTestResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextParagraphLayoutMetadata with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextParagraphLayoutResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextParagraphLineMetrics with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextParagraphVisualOrderMetadata with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextRange with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextRun with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Theme with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ThemeDensity with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ThemePreset with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ThemeSpec with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend Transform2D with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TransitionSample with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TransitionSpec with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TransitionStyle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TypographyScale with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ViewDeclaration with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ViewDirtyHint with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ViewEventResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ViewIdentity with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ViewLayoutResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ViewPaintLayer with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ViewPaintPlan with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ViewSemanticsInfo with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ViewStateContext with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ViewStateSlots with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ViewStyle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ViewTextCommandResult with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend VisualStyle with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ScrollAlignment with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticId with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsAction with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsActionKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsCheckedState with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsCollectionInfo with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsComposition with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsGeneration with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsLive with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsNode with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsNodeId with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsNumericValue with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsRelationKind with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsRelations with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsRelationsDeclaration with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsRole with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsScrollDirection with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsState with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsTarget with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend SemanticsTextValue with Eq::{not_equal, equal}
