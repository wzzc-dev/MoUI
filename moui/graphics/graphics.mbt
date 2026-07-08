///|
/// Domain facade package `moui/graphics`:
/// re-exports high-frequency paint/graphics value types from `moui/core`.
/// `@core` is the type source of truth; this package provides the
/// app-facing graphics prefix for common paint and drawing types.
/// See `docs/moui-app-package-boundary.md` "领域 facade 暴露规则".

///|
pub using @core {type Color}

///|
pub using @core {type Brush}

///|
pub using @core {type BorderStyle}

///|
pub using @core {type ShadowStyle}

///|
pub using @core {type RoundedRect}

///|
pub using @core {type PathSpec}

///|
pub using @core {type PathVerb}

///|
pub using @core {type ImageRun}

///|
pub using @core {type ImageFit}

///|
pub using @core {type BlendMode}

///|
pub using @core {type LayerSpec}

///|
pub using @core {type LayerMask}

///|
pub using @core {type FilterEffect}

///|
pub using @core {type ShadowSpec}

///|
pub using @core {type Transform2D}

///|
pub using @core {type ShaderEffectSpec}
