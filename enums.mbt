///|
/// Porter-Duff and extended blend modes mirrored from Skia.
#warnings("-deprecated_syntax")
pub(all) enum BlendMode {
  Clear
  Src
  Dst
  SrcOver
  DstOver
  SrcIn
  DstIn
  SrcOut
  DstOut
  SrcATop
  DstATop
  Xor
  Plus
  Modulate
  Screen
  Overlay
  Darken
  Lighten
  ColorDodge
  ColorBurn
  HardLight
  SoftLight
  Difference
  Exclusion
  Multiply
  Hue
  Saturation
  Color
  Luminosity
} derive(Debug, Eq)

///|
pub impl Default for BlendMode with default() {
  SrcOver
}

///|
pub fn BlendMode::to_skia_ordinal(self : BlendMode) -> Int {
  match self {
    Clear => 0
    Src => 1
    Dst => 2
    SrcOver => 3
    DstOver => 4
    SrcIn => 5
    DstIn => 6
    SrcOut => 7
    DstOut => 8
    SrcATop => 9
    DstATop => 10
    Xor => 11
    Plus => 12
    Modulate => 13
    Screen => 14
    Overlay => 15
    Darken => 16
    Lighten => 17
    ColorDodge => 18
    ColorBurn => 19
    HardLight => 20
    SoftLight => 21
    Difference => 22
    Exclusion => 23
    Multiply => 24
    Hue => 25
    Saturation => 26
    Color => 27
    Luminosity => 28
  }
}

///|
/// How paint geometry is rasterized.
#warnings("-deprecated_syntax")
pub(all) enum PaintStyle {
  Fill
  Stroke
  StrokeAndFill
} derive(Debug, Eq)

///|
pub impl Default for PaintStyle with default() {
  Fill
}

///|
pub fn PaintStyle::to_skia_ordinal(self : PaintStyle) -> Int {
  match self {
    Fill => 0
    Stroke => 1
    StrokeAndFill => 2
  }
}

///|
/// Shape used at the end of an open stroked contour.
#warnings("-deprecated_syntax")
pub(all) enum StrokeCap {
  Butt
  Round
  Square
} derive(Debug, Eq)

///|
pub impl Default for StrokeCap with default() {
  Butt
}

///|
pub fn StrokeCap::to_skia_ordinal(self : StrokeCap) -> Int {
  match self {
    Butt => 0
    Round => 1
    Square => 2
  }
}

///|
/// Shape used when two stroked segments meet.
#warnings("-deprecated_syntax")
pub(all) enum StrokeJoin {
  Miter
  Round
  Bevel
} derive(Debug, Eq)

///|
pub impl Default for StrokeJoin with default() {
  Miter
}

///|
pub fn StrokeJoin::to_skia_ordinal(self : StrokeJoin) -> Int {
  match self {
    Miter => 0
    Round => 1
    Bevel => 2
  }
}

///|
/// How `Canvas::draw_points` interprets a point array.
#warnings("-deprecated_syntax")
pub(all) enum PointMode {
  Points
  Lines
  Polygon
} derive(Debug, Eq)

///|
pub impl Default for PointMode with default() {
  Points
}

///|
pub fn PointMode::to_skia_ordinal(self : PointMode) -> Int {
  match self {
    Points => 0
    Lines => 1
    Polygon => 2
  }
}

///|
/// Interpretation of alpha in pixel data.
#warnings("-deprecated_syntax")
pub(all) enum AlphaType {
  Unknown
  Opaque
  Premul
  Unpremul
} derive(Debug, Eq)

///|
pub impl Default for AlphaType with default() {
  Unknown
}

///|
/// Pixel storage formats common in Skia surfaces and images.
#warnings("-deprecated_syntax")
pub(all) enum ColorType {
  Unknown
  Alpha8
  RGB565
  ARGB4444
  RGBA8888
  RGB888x
  BGRA8888
  RGBA1010102
  RGB101010x
  Gray8
  RGBAF16
  RGBAF32
} derive(Debug, Eq)

///|
pub impl Default for ColorType with default() {
  Unknown
}

///|
/// Sampling behavior when coordinates land outside shader bounds.
#warnings("-deprecated_syntax")
pub(all) enum TileMode {
  Clamp
  Repeat
  Mirror
  Decal
} derive(Debug, Eq)

///|
pub impl Default for TileMode with default() {
  Clamp
}

///|
pub fn TileMode::to_skia_ordinal(self : TileMode) -> Int {
  match self {
    Clamp => 0
    Repeat => 1
    Mirror => 2
    Decal => 3
  }
}

///|
/// Encoded image container formats accepted by Skia encoders.
#warnings("-deprecated_syntax")
pub(all) enum EncodedImageFormat {
  BMP
  GIF
  ICO
  JPEG
  PNG
  WBMP
  WEBP
  PKM
  KTX
  ASTC
  DNG
  HEIF
  AVIF
  JPEGXL
} derive(Debug, Eq)

///|
pub impl Default for EncodedImageFormat with default() {
  PNG
}

///|
pub fn EncodedImageFormat::to_skia_ordinal(self : EncodedImageFormat) -> Int {
  match self {
    BMP => 0
    GIF => 1
    ICO => 2
    JPEG => 3
    PNG => 4
    WBMP => 5
    WEBP => 6
    PKM => 7
    KTX => 8
    ASTC => 9
    DNG => 10
    HEIF => 11
    AVIF => 12
    JPEGXL => 13
  }
}

///|
pub fn EncodedImageFormat::from_skia_ordinal(
  ordinal : Int,
) -> EncodedImageFormat? {
  match ordinal {
    0 => Some(BMP)
    1 => Some(GIF)
    2 => Some(ICO)
    3 => Some(JPEG)
    4 => Some(PNG)
    5 => Some(WBMP)
    6 => Some(WEBP)
    7 => Some(PKM)
    8 => Some(KTX)
    9 => Some(ASTC)
    10 => Some(DNG)
    11 => Some(HEIF)
    12 => Some(AVIF)
    13 => Some(JPEGXL)
    _ => None
  }
}

///|
/// How a new clip geometry combines with the current canvas clip.
#warnings("-deprecated_syntax")
pub(all) enum ClipOp {
  Difference
  Intersect
} derive(Debug, Eq)

///|
pub impl Default for ClipOp with default() {
  Intersect
}

///|
pub fn ClipOp::to_skia_ordinal(self : ClipOp) -> Int {
  match self {
    Difference => 0
    Intersect => 1
  }
}

///|
/// Pixel reconstruction filter used when images are sampled.
#warnings("-deprecated_syntax")
pub(all) enum FilterMode {
  Nearest
  Linear
} derive(Debug, Eq)

///|
pub impl Default for FilterMode with default() {
  Nearest
}

///|
pub fn FilterMode::to_skia_ordinal(self : FilterMode) -> Int {
  match self {
    Nearest => 0
    Linear => 1
  }
}

///|
/// Mipmap sampling mode used together with `FilterMode`.
#warnings("-deprecated_syntax")
pub(all) enum MipmapMode {
  None
  Nearest
  Linear
} derive(Debug, Eq)

///|
pub impl Default for MipmapMode with default() {
  None
}

///|
pub fn MipmapMode::to_skia_ordinal(self : MipmapMode) -> Int {
  match self {
    None => 0
    Nearest => 1
    Linear => 2
  }
}
