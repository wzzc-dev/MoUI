///|
/// Domain facade package `moui/state`:
/// re-exports immutable environment and focus-scope value types
/// from `moui/core`.
/// `@core` is the type source of truth; this package provides the
/// app-facing state/focus prefix for common state value types.
/// See `docs/moui-app-package-boundary.md` "领域 facade 暴露规则".

///|
pub using @core {type ColorScheme}

///|
pub using @core {type LayoutDirection}

///|
pub using @core {type FocusScope}

///|
pub using @core {type FocusScopeItem}
