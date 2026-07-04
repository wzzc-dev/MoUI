///|
/// Domain sugar package `moui/graphics`:
/// re-exports high-frequency paint/graphics value types from `moui/core`.
/// `@core` is the type source of truth; this package only provides
/// prefix-shortening sugar for the most common graphics types.
/// See `docs/moui-app-package-boundary.md` "领域糖包暴露规则".

///|
pub using @core {type Color}

///|
pub using @core {type Brush}

///|
pub using @core {type BorderStyle}

///|
pub using @core {type ShadowStyle}
