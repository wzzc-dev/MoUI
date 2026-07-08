///|
/// Domain facade package `moui/animation`:
/// re-exports high-frequency motion value types from `moui/core`.
/// `@core` is the type source of truth; this package keeps app code off
/// low-level `@core` prefixes for transition authoring.
/// See `docs/moui-app-package-boundary.md` "领域 facade 暴露规则".

///|
pub using @core {type Easing}

///|
pub using @core {type TransitionSpec}

///|
pub using @core {type TransitionStyle}
