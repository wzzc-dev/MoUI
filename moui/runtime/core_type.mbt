using @core {
  type AccessibilityContrast,
  type ActionCommand,
  type ActionCommandMap,
  type Alignment,
  type AlignmentGuideSet,
  type AppEvent,
  type Axis,
  type BadgeStyle,
  type BlendMode,
  type BorderStyle,
  type Brush,
  type ButtonState,
  type ButtonStyle,
  type CachedLayerSpec,
  type ChoiceControlStyle,
  type Color,
  type ColorScheme,
  type CommandBinding,
  type CommandIntent,
  type ComponentEffect,
  type ComponentEffectCancelReason,
  type CompositionUpdate,
  type Constraints,
  type ContentSizeCategory,
  type CrossAxisAlignment,
  type CustomLayoutCache,
  type CustomLayoutContext,
  type CustomPlacementContext,
  type DamageRegion,
  type DatePickerMode,
  type DateValue,
  type DragDropEvent,
  type DragDropPhase,
  type DragGestureEvent,
  type DragGesturePhase,
  type DrawCommand,
  type DrawFrame,
  type Easing,
  type EffectDescriptor,
  type EffectPlanKind,
  type EffectPlanSummary,
  type EffectTaskCancelReason,
  type EffectTaskLifecycleSnapshot,
  type EffectTaskLifecycleStatus,
  type ElementId,
  type Environment,
  type FeedbackStyle,
  type FilterEffect,
  type FocusScope,
  type FocusScopeItem,
  type FocusState,
  type FocusTraversalDirection,
  type FontFamily,
  type FontFamilyStack,
  type FontSpec,
  type FontStyle,
  type FormValidationStyle,
  type FormValidationSummary,
  type Frame,
  type ImageFit,
  type ImageRun,
  type InspectorSnapshot,
  type Insets,
  type KeyboardEvent,
  type KeyboardShortcut,
  type KeyModifiers,
  type LayerMask,
  type LayerSpec,
  type LayoutBoundsInspectorEntry,
  type LayoutDirection,
  type LayoutInspectorSnapshot,
  type LayoutResult,
  type LinearGradientSpec,
  type MainAxisAlignment,
  type NavigationState,
  type PathSpec,
  type PathVerb,
  type PickerItem,
  type PickerStyle,
  type PlatformViewPlacement,
  type PointerEvent,
  type PointerPhase,
  type Point,
  type ProgramRuntimeSnapshot,
  type ProgressStyle,
  type RadiusScale,
  type Rect,
  type RedrawReason,
  type RenderInspectorSnapshot,
  type RichTextBlock,
  type RichTextDecoration,
  type RichTextDocument,
  type RichTextInputTransform,
  type RichTextRun,
  type RichTextSourceRange,
  type RichTextTableCell,
  type RichTextTable,
  type RouteFocusStore,
  type RouteLocation,
  type RoundedRect,
  type RuntimeDirtyStateSummary,
  type RuntimeInspectorSnapshot,
  type SaveableStateStore,
  type SemanticColorScale,
  type SemanticsAction,
  type SemanticsInspectorSnapshot,
  type SemanticsNode,
  type SemanticsRole,
  type SemanticsState,
  type ShadowSpec,
  type ShadowStyle,
  type SheetPresentationMode,
  type Size,
  type SliderStyle,
  type ScrollState,
  type SpacingScale,
  type StateSubscription,
  type SubscriptionCancelReason,
  type SubscriptionDescriptor,
  type SubscriptionKindCount,
  type SubscriptionLifecycleSnapshot,
  type SubscriptionLifecycleStatus,
  type SubscriptionPlanKind,
  type SubscriptionPlanSummary,
  type TextAlign,
  type TextCommandResult,
  type TextFieldStyle,
  type TextGraphemeBoundaries,
  type TextInputEvent,
  type TextInputState,
  type TextLayoutInput,
  type TextLayoutResult,
  type TextParagraphHitTestResult,
  type TextParagraphLayoutMetadata,
  type TextParagraphLayoutResult,
  type TextParagraphLineMetrics,
  type TextParagraphVisualOrderMetadata,
  type TextRange,
  type TextRun,
  type TextSystem,
  type Theme,
  type Transform2D,
  type ViewEnvironment,
  type ViewNodeInspectorSummary,
  type ViewStyle,
  type ViewTreeInspectorSnapshot,
  type VisualStyle,
  type WebViewCommand,
  type WebViewEvent,
  type WebViewNavigationPolicy,
  type WebViewSpec,
  type TransitionStyle,
  type TransitionSpec,
}

///|
type Binding[T] = @core.Binding[T]

///|
type DerivedState[T] = @core.DerivedState[T]

///|
type Effect[Msg] = @core.Effect[Msg]

///|
type EffectRuntimeOp[Msg] = @core.EffectRuntimeOp[Msg]

///|
type Program[Model, Msg] = @core.Program[Model, Msg]

///|
type SaveableCodec[T] = @core.SaveableCodec[T]

///|
type State[T] = @core.State[T]

///|
type Subscription[Msg] = @core.Subscription[Msg]

///|
type SubscriptionRuntimeSource[Msg] = @core.SubscriptionRuntimeSource[Msg]

///|
type View[Msg] = @core.View[Msg]

///|
type RichTextFormatter = (String) -> RichTextDocument

///| Normalizes a `TextRange` to grapheme boundaries via the core bridge.
fn normalize_grapheme_range(
  boundaries : TextGraphemeBoundaries,
  range : TextRange,
) -> TextRange {
  @core.normalize_grapheme_range(boundaries, range)
}

///| Computes the deletion range around `caret` in grapheme boundaries.
fn delete_grapheme_range(
  boundaries : TextGraphemeBoundaries,
  caret : Int,
  before : Int,
  after : Int,
) -> TextRange {
  @core.delete_grapheme_range(boundaries, caret, before, after)
}
