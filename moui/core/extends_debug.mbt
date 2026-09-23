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
pub extend AccessibilityContrast with Debug::{to_repr}

///|
#doc(hidden)
pub extend ActionCommand with Debug::{to_repr}

///|
#doc(hidden)
pub extend Alignment with Debug::{to_repr}

///|
#doc(hidden)
pub extend AlignmentGuideSet with Debug::{to_repr}

///|
#doc(hidden)
pub extend AnimationStatus with Debug::{to_repr}

///|
#doc(hidden)
pub extend AppEvent with Debug::{to_repr}

///|
#doc(hidden)
pub extend Axis with Debug::{to_repr}

///|
#doc(hidden)
pub extend BlendMode with Debug::{to_repr}

///|
#doc(hidden)
pub extend BorderStyle with Debug::{to_repr}

///|
#doc(hidden)
pub extend Brush with Debug::{to_repr}

///|
#doc(hidden)
pub extend ChildLayoutInfo with Debug::{to_repr}

///|
#doc(hidden)
pub extend Color with Debug::{to_repr}

///|
#doc(hidden)
pub extend ColorMode with Debug::{to_repr}

///|
#doc(hidden)
pub extend ColorPalette with Debug::{to_repr}

///|
#doc(hidden)
pub extend ColorScheme with Debug::{to_repr}

///|
#doc(hidden)
pub extend CommandIntent with Debug::{to_repr}

///|
#doc(hidden)
pub extend CompositionUpdate with Debug::{to_repr}

///|
#doc(hidden)
pub extend Constraints with Debug::{to_repr}

///|
#doc(hidden)
pub extend ContentSizeCategory with Debug::{to_repr}

///|
#doc(hidden)
pub extend CrossAxisAlignment with Debug::{to_repr}

///|
#doc(hidden)
pub extend DamageRegion with Debug::{to_repr}

///|
#doc(hidden)
pub extend DateValue with Debug::{to_repr}

///|
#doc(hidden)
pub extend DeclarationChanges with Debug::{to_repr}

///|
#doc(hidden)
pub extend DeclarationKey with Debug::{to_repr}

///|
#doc(hidden)
pub extend DragDropEvent with Debug::{to_repr}

///|
#doc(hidden)
pub extend DragDropPhase with Debug::{to_repr}

///|
#doc(hidden)
pub extend DragGestureEvent with Debug::{to_repr}

///|
#doc(hidden)
pub extend DragGesturePhase with Debug::{to_repr}

///|
#doc(hidden)
pub extend DrawCommand with Debug::{to_repr}

///|
#doc(hidden)
pub extend DrawFrame with Debug::{to_repr}

///|
#doc(hidden)
pub extend Easing with Debug::{to_repr}

///|
#doc(hidden)
pub extend EffectDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend Environment with Debug::{to_repr}

///|
#doc(hidden)
pub extend FilterEffect with Debug::{to_repr}

///|
#doc(hidden)
pub extend FocusRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend FocusTraversalDirection with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontFamily with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontFamilyStack with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontSpec with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontStyle with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontVariation with Debug::{to_repr}

///|
#doc(hidden)
pub extend Frame with Debug::{to_repr}

///|
#doc(hidden)
pub extend ImageFit with Debug::{to_repr}

///|
#doc(hidden)
pub extend ImageRun with Debug::{to_repr}

///|
#doc(hidden)
pub extend Insets with Debug::{to_repr}

///|
#doc(hidden)
pub extend InteractionState with Debug::{to_repr}

///|
#doc(hidden)
pub extend KeyModifiers with Debug::{to_repr}

///|
#doc(hidden)
pub extend KeyboardEvent with Debug::{to_repr}

///|
#doc(hidden)
pub extend KeyboardShortcut with Debug::{to_repr}

///|
#doc(hidden)
pub extend LayerMask with Debug::{to_repr}

///|
#doc(hidden)
pub extend LayerSpec with Debug::{to_repr}

///|
#doc(hidden)
pub extend LayoutDirection with Debug::{to_repr}

///|
#doc(hidden)
pub extend LayoutResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend LinearGradientSpec with Debug::{to_repr}

///|
#doc(hidden)
pub extend MainAxisAlignment with Debug::{to_repr}

///|
#doc(hidden)
pub extend MotionScale with Debug::{to_repr}

///|
#doc(hidden)
pub extend PathSpec with Debug::{to_repr}

///|
#doc(hidden)
pub extend PathVerb with Debug::{to_repr}

///|
#doc(hidden)
pub extend PlatformViewEvent with Debug::{to_repr}

///|
#doc(hidden)
pub extend PlatformViewPlacement with Debug::{to_repr}

///|
#doc(hidden)
pub extend PlatformViewProperty with Debug::{to_repr}

///|
#doc(hidden)
pub extend Point with Debug::{to_repr}

///|
#doc(hidden)
pub extend PointerEvent with Debug::{to_repr}

///|
#doc(hidden)
pub extend PointerPhase with Debug::{to_repr}

///|
#doc(hidden)
pub extend PressableState with Debug::{to_repr}

///|
#doc(hidden)
pub extend RadialGradientSpec with Debug::{to_repr}

///|
#doc(hidden)
pub extend RadiusScale with Debug::{to_repr}

///|
#doc(hidden)
pub extend Rect with Debug::{to_repr}

///|
#doc(hidden)
pub extend RedrawReason with Debug::{to_repr}

///|
#doc(hidden)
pub extend RetainedLayerSpec with Debug::{to_repr}

///|
#doc(hidden)
pub extend RoundedRect with Debug::{to_repr}

///|
#doc(hidden)
pub extend ScrollRequest with Debug::{to_repr}

///|
#doc(hidden)
pub extend ShaderEffectSpec with Debug::{to_repr}

///|
#doc(hidden)
pub extend ShadowScale with Debug::{to_repr}

///|
#doc(hidden)
pub extend ShadowSpec with Debug::{to_repr}

///|
#doc(hidden)
pub extend ShadowStyle with Debug::{to_repr}

///|
#doc(hidden)
pub extend Size with Debug::{to_repr}

///|
#doc(hidden)
pub extend SpacingScale with Debug::{to_repr}

///|
#doc(hidden)
pub extend SubscriptionDescriptor with Debug::{to_repr}

///|
#doc(hidden)
pub extend SurfaceLevel with Debug::{to_repr}

///|
#doc(hidden)
pub extend SurfaceMetrics with Debug::{to_repr}

///|
#doc(hidden)
pub extend SurfaceScale with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextAlign with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextCommandResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextControlStateContext with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextHistoryEntryContext with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextInputEvent with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextInputState with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextLayoutInput with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextLayoutResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextParagraphHitTestResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextParagraphLayoutMetadata with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextParagraphLayoutResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextParagraphLineMetrics with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextParagraphVisualOrderMetadata with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextRange with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextRun with Debug::{to_repr}

///|
#doc(hidden)
pub extend Theme with Debug::{to_repr}

///|
#doc(hidden)
pub extend ThemeDensity with Debug::{to_repr}

///|
#doc(hidden)
pub extend ThemePreset with Debug::{to_repr}

///|
#doc(hidden)
pub extend ThemeSpec with Debug::{to_repr}

///|
#doc(hidden)
pub extend Transform2D with Debug::{to_repr}

///|
#doc(hidden)
pub extend TransitionSample with Debug::{to_repr}

///|
#doc(hidden)
pub extend TransitionSpec with Debug::{to_repr}

///|
#doc(hidden)
pub extend TransitionStyle with Debug::{to_repr}

///|
#doc(hidden)
pub extend TypographyScale with Debug::{to_repr}

///|
#doc(hidden)
pub extend ViewDirtyHint with Debug::{to_repr}

///|
#doc(hidden)
pub extend ViewEventResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend ViewLayoutResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend ViewPaintLayer with Debug::{to_repr}

///|
#doc(hidden)
pub extend ViewPaintPlan with Debug::{to_repr}

///|
#doc(hidden)
pub extend ViewSemanticsInfo with Debug::{to_repr}

///|
#doc(hidden)
pub extend ViewStateContext with Debug::{to_repr}

///|
#doc(hidden)
pub extend ViewStateSlots with Debug::{to_repr}

///|
#doc(hidden)
pub extend ViewStyle with Debug::{to_repr}

///|
#doc(hidden)
pub extend ViewTextCommandResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend VisualStyle with Debug::{to_repr}

///|
#doc(hidden)
pub extend ScrollAlignment with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticId with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsAction with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsActionKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsCheckedState with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsCollectionInfo with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsComposition with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsGeneration with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsLive with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsNode with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsNodeId with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsNumericValue with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsRelationKind with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsRelations with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsRelationsDeclaration with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsRole with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsScrollDirection with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsState with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsTarget with Debug::{to_repr}

///|
#doc(hidden)
pub extend SemanticsTextValue with Debug::{to_repr}
