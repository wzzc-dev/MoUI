///|
/// Domain sugar package `moui/state`:
/// re-exports high-frequency state holder and environment-kind types
/// from `moui/core`.
/// `@core` is the type source of truth; this package only provides
/// prefix-shortening sugar for the most common state types.
/// See `docs/moui-app-package-boundary.md` "领域糖包暴露规则".

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
