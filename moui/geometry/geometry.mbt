///|
/// Domain facade package `moui/geometry`:
/// re-exports high-frequency geometry/layout value types from `moui/core`.
/// `@core` is the type source of truth; this package provides the
/// app-facing geometry prefix for common layout value types.
/// See `docs/moui-app-package-boundary.md` "领域 facade 暴露规则".

///|
pub using @core {type Point}

///|
pub using @core {type Size}

///|
pub using @core {type Rect}

///|
pub using @core {type Insets}

///|
pub using @core {type Constraints}

///|
pub using @core {type Axis}

///|
pub using @core {type Alignment}
