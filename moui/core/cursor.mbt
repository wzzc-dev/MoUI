///|
/// Neutral pointer-icon vocabulary for `View::cursor`.
///
/// The variants mirror the platform `wzzc-dev/window/core` `CursorIcon` set one
/// to one, in the same order, so a backend projects them with a mechanical
/// table (`moui/backend/common/window_cursor.mbt`) and the app-facing names stay
/// recognisable (`CursorColResize` ↔ `ColResize`, `CursorPointer` ↔ `Pointer`).
///
/// Two deliberate differences from a straight re-export of that type:
///
/// - **The `Cursor` prefix.** MoonBit constructors share one package-wide
///   namespace, so declaring bare `Pointer` / `Move` / `Text` / `Copy` in
///   `moui/core` would make existing unqualified `@core.Pointer(...)`-style
///   calls in other packages — and in downstream apps — ambiguous. The prefix
///   keeps the neutral set collision-free while leaving every name a direct
///   transliteration of the upstream variant.
/// - **It lives here, not as an alias.** `moui/core` is the cross-runtime
///   contract layer and must not depend on the platform window crate. An alias
///   would also leak an external-module type into every facade interface, which
///   the repository's API-surface gate rejects (the app facades are pinned to
///   `@core` aliases).
///
/// Unknown or unsupported shapes degrade to `Default` at the host boundary; the
/// framework never asks a host whether it can show a shape.
#derive(Eq, Debug)
pub(all) enum CursorIcon {
  CursorDefault
  CursorContextMenu
  CursorHelp
  CursorProgress
  CursorWait
  CursorCell
  CursorVerticalText
  CursorAlias
  CursorCopy
  CursorNoDrop
  CursorGrab
  CursorGrabbing
  CursorEResize
  CursorNResize
  CursorNeResize
  CursorNwResize
  CursorSResize
  CursorSeResize
  CursorSwResize
  CursorWResize
  CursorEwResize
  CursorNsResize
  CursorNeswResize
  CursorNwseResize
  CursorColResize
  CursorRowResize
  CursorAllScroll
  CursorZoomIn
  CursorZoomOut
  CursorPointer
  CursorText
  CursorCrosshair
  CursorMove
  CursorNotAllowed
}

///|
pub extend CursorIcon with Debug::{to_repr}

///|
pub extend CursorIcon with Eq::{not_equal, equal}

///|
/// A view's cursor request.
///
/// Three states, on purpose:
///
/// - `Inherit` keeps resolving outward to the nearest ancestor that declares a
///   style. Without it a child inside a `col_resize` splitter could not say
///   "back to the arrow" — the only alternative would be an explicit `Default`
///   at every level, which is what the two-state designs get wrong.
/// - `Default` is the arrow and an explicit stop for inheritance.
/// - `Icon(icon)` is a concrete pointer shape.
///
/// A declaration is intent, not host state: the runtime resolves the style of
/// the element under the pointer against the current hit chain every time the
/// pointer moves, and the host pushes the result at most once per change.
/// `Inherit` never reaches a host; `CursorStyle::icon` degrades it (and any
/// unsupported value) to `Default`.
#derive(Eq, Debug)
pub(all) enum CursorStyle {
  Inherit
  Default
  Icon(CursorIcon)
}

///|
pub extend CursorStyle with Debug::{to_repr}

///|
pub extend CursorStyle with Eq::{not_equal, equal}

///|
/// The concrete icon to hand to a host. `Inherit` is a view-tree-only state, so
/// it degrades to the arrow exactly like an unknown style would.
pub fn CursorStyle::icon(self : CursorStyle) -> CursorIcon {
  match self {
    Inherit | Default => CursorIcon::CursorDefault
    Icon(icon) => icon
  }
}

///|
/// `true` when the declaration defers to an ancestor instead of pinning a
/// shape. The runtime resolution walk uses it to keep climbing the hit chain.
pub fn CursorStyle::is_inherit(self : CursorStyle) -> Bool {
  match self {
    Inherit => true
    _ => false
  }
}
