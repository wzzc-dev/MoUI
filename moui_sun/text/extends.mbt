// Explicit trait-method promotions for this package's types.
//
// The upgraded MoonBit toolchain deprecated the implicit promotion of trait
// methods as regular methods (`derive(Eq, Debug)` making `x.equal(y)` and
// `x.to_repr()` resolve). Each promotion used by this package is declared
// here explicitly so it keeps working; `#doc(hidden)` keeps the promotions
// out of the generated interface, leaving the package's public API unchanged.

///|
#doc(hidden)
pub extend CoverageMask with Debug::{to_repr}

///|
#doc(hidden)
pub extend FaceGlyphMaskCacheResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend FaceGlyphMaskPlacement with Debug::{to_repr}

///|
#doc(hidden)
pub extend FileFontLoader with Debug::{to_repr}

///|
#doc(hidden)
pub extend FileFontLoader with FontLoader::{load_font_data}

///|
#doc(hidden)
pub extend Font with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontData with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontFace with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontFaceCache with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontFaceCacheParseResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontFallbackPlan with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontFallbackSpan with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontFileSource with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontFileSource with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FontHead with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontHead with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FontHhea with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontHhea with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FontLoadError with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontLoadError with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FontMetrics with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontMetrics with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend FontParseError with Debug::{to_repr}

///|
#doc(hidden)
pub extend FontParseError with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend GlyphAtlasEntry with Debug::{to_repr}

///|
#doc(hidden)
pub extend GlyphComponent with Debug::{to_repr}

///|
#doc(hidden)
pub extend GlyphContour with Debug::{to_repr}

///|
#doc(hidden)
pub extend GlyphData with Debug::{to_repr}

///|
#doc(hidden)
pub extend GlyphId with Debug::{to_repr}

///|
#doc(hidden)
pub extend GlyphId with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend GlyphInfo with Debug::{to_repr}

///|
#doc(hidden)
pub extend GlyphInfo with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend GlyphMaskAtlas with Debug::{to_repr}

///|
#doc(hidden)
pub extend GlyphMaskAtlasInsertResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend GlyphMaskCache with Debug::{to_repr}

///|
#doc(hidden)
pub extend GlyphMaskCacheRasterizeResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend GlyphPoint with Debug::{to_repr}

///|
#doc(hidden)
pub extend GlyphPoint with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend GlyphPosition with Debug::{to_repr}

///|
#doc(hidden)
pub extend GlyphPosition with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend GlyphRun with Debug::{to_repr}

///|
#doc(hidden)
pub extend KernPair with Debug::{to_repr}

///|
#doc(hidden)
pub extend KernPair with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend LayoutConfig with Debug::{to_repr}

///|
#doc(hidden)
pub extend LayoutLine with Debug::{to_repr}

///|
#doc(hidden)
pub extend LayoutMetrics with Debug::{to_repr}

///|
#doc(hidden)
pub extend LayoutMetrics with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend LayoutResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend LineBreakClass with Debug::{to_repr}

///|
#doc(hidden)
pub extend LineBreakClass with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend LineBreakClass with Show::{output}

///|
#doc(hidden)
pub extend LineSegment with Debug::{to_repr}

///|
#doc(hidden)
pub extend LongHorMetric with Debug::{to_repr}

///|
#doc(hidden)
pub extend LongHorMetric with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend MemoryFontLoader with Debug::{to_repr}

///|
#doc(hidden)
pub extend MemoryFontLoader with FontLoader::{load_font_data}

///|
#doc(hidden)
pub extend PositionedGlyph with Debug::{to_repr}

///|
#doc(hidden)
pub extend Script with Debug::{to_repr}

///|
#doc(hidden)
pub extend Script with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend ShapedText with Debug::{to_repr}

///|
#doc(hidden)
pub extend ShapingBuffer with Debug::{to_repr}

///|
#doc(hidden)
pub extend SimpleGlyph with Debug::{to_repr}

///|
#doc(hidden)
pub extend TableRecord with Debug::{to_repr}

///|
#doc(hidden)
pub extend TableRecord with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextAlign with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextAlign with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextCaret with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextCaret with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextDirection with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextDirection with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextLayout with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextMaskCache with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextMaskCacheRenderResult with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextRunOutline with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextSelectionRect with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextSelectionRect with Eq::{not_equal, equal}

///|
#doc(hidden)
pub extend TextSystem with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextSystem with FontLoader::{load_font_data}

///|
#doc(hidden)
pub extend TextSystemFontRegistration with Debug::{to_repr}

///|
#doc(hidden)
pub extend TextSystemLayout with Debug::{to_repr}
