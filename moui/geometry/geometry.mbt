///|
/// Domain sugar package `moui/geometry`:
/// re-exports high-frequency geometry/layout value types from `moui/core`.
/// `@core` is the type source of truth; this package only provides
/// prefix-shortening sugar for the most common geometry types.
/// See `docs/moui-app-package-boundary.md` "领域糖包暴露规则".

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
