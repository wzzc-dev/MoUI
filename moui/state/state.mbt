///|
/// Domain facade package `moui/state`:
/// re-exports high-frequency state holder and environment-kind types
/// from `moui/core`.
/// `@core` is the type source of truth; this package provides the
/// app-facing state/focus prefix for common state value types.
/// See `docs/moui-app-package-boundary.md` "领域 facade 暴露规则".

///|
pub using @core {type State}

///|
pub using @core {type Binding}

///|
pub using @core {type DerivedState}

///|
pub using @core {type ScrollState}

///|
pub using @core {type FocusState}

///|
pub using @core {type NavigationState}

///|
pub using @core {type ColorScheme}

///|
pub using @core {type LayoutDirection}

///|
pub using @core {type FocusScope}

///|
pub using @core {type FocusScopeItem}
