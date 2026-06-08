///|
/// Runtime availability of the linked Skia native backend.
pub extern "C" fn skia_available() -> Bool = "moonbit_skia_available"

///|
/// Runtime availability of the optional linked Skia shaper backend.
pub extern "C" fn skia_shaper_available() -> Bool = "moonbit_skia_shaper_available"

///|
/// Runtime availability of the optional linked SkParagraph backend.
pub extern "C" fn skia_paragraph_available() -> Bool = "moonbit_skia_paragraph_available"
