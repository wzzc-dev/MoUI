///|
/// A type-erased modifier that dispatches to concrete modifier implementations
/// via closures. Replaces the 50-variant `ViewModifier[Msg]` enum.
///
/// Each concrete modifier (Padding, Frame, Background, OnTap, etc.) is a
/// standalone type that implements the subset of modifier behavior it needs
/// and converts to `AnyModifier` via a `to_any_modifier` method.
pub(all) struct AnyModifier[Msg] {
  /// Human-readable kind string for identity composition.
  identity_kind : String
  /// Declaration key for identity composition (used by KeyModifier).
  identity_key : Key?
  /// Declaration key for incremental caching.
  declaration : ViewDeclaration
  /// Transform child constraints before passing to child.
  child_constraints : (Constraints) -> Constraints
  /// Transform child environment before passing to child.
  child_environment : (Environment) -> Environment
  /// Transform child style before passing to child.
  child_style : (ViewStyle) -> ViewStyle
  /// Layout the modifier wrapper around the child.
  layout : (ViewLayoutContext) -> ViewLayoutResult
  /// Paint the modifier effect.
  paint : (ViewPaintContext) -> ViewPaintPlan
  /// Handle events intercepted by this modifier.
  event : (ViewEventContext) -> ViewEventResult[Msg]
  /// Semantics info contributed by this modifier.
  semantics : ViewSemanticsInfo
  /// Semantics actions contributed by this modifier.
  semantics_actions : Array[ViewSemanticsActionHandler[Msg]]
  /// Whether this modifier makes the element focusable.
  focusable : Bool
  /// Whether this modifier establishes a keyboard focus scope.
  focus_trap : Bool
  /// Flex weight contributed by this modifier.
  flex_weight : Double
}

///|
/// A modifier that does nothing — used as default for all vtable slots.
pub fn[Msg] noop_modifier() -> AnyModifier[Msg] {
  {
    identity_kind: "",
    identity_key: None,
    declaration: ViewDeclaration::constant(),
    child_constraints: fn(c) { c.loosen() },
    child_environment: fn(e) { e },
    child_style: fn(s) { s },
    layout: fn(ctx) {
      let child_size = match ctx.child_sizes {
        [s, ..] => s
        [] => Size::new(width=0.0, height=0.0)
      }
      let s = ctx.constraints.constrain(child_size)
      ViewLayoutResult::new(size=s, child_frames=[
        Rect::new(x=0.0, y=0.0, width=s.width, height=s.height),
      ])
    },
    paint: fn(_ctx) { ViewPaintPlan::empty() },
    event: fn(_ctx) { ViewEventResult::ignored() },
    semantics: ViewSemanticsInfo::new(),
    semantics_actions: [],
    focusable: false,
    focus_trap: false,
    flex_weight: 0.0,
  }
}

///|
/// ## Trait mapping reference
/// The `AnyModifier` vtable replaces the originally planned trait hierarchy
/// (LayoutModifier, PaintModifier, EventModifier, SemanticsModifier,
/// EnvironmentModifier). Each vtable slot corresponds to a conceptual trait:
///
///   Trait              Vtable slots filled
///   ─────              ───────────────────
///   Layout             child_constraints, layout, flex_weight, declaration
///   Paint              child_style, paint, declaration
///   Event              event
///   Semantics          semantics, semantics_actions, declaration
///   Environment        child_environment, declaration
///   Focus              focusable
///
/// Concrete modifiers fill only the slots they need:
///   PaddingModifier    → Layout only
///   BackgroundModifier → Paint only
///   OnTapModifier      → Event + Semantics + Focus
///   DisabledModifier   → Environment + Paint + Semantics
///
/// When MoonBit supports blanket trait implementations, the vtable can be
/// replaced with proper trait dispatch and generic `ModifierViewNode`.
