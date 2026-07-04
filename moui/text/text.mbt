///|
/// Domain sugar package `moui/text`:
/// re-exports high-frequency text value types from `moui/core`.
/// `@core` is the type source of truth; this package only provides
/// prefix-shortening sugar for the most common text types.
/// See `docs/moui-app-package-boundary.md` "领域糖包暴露规则".

///|
pub using @core {type FontSpec}

///|
pub using @core {type FontFamily}

///|
pub using @core {type TextRange}

///|
pub using @core {type TextAlign}

///|
pub using @core {type FontFamilyStack}

///|
pub using @core {type TextRun}
