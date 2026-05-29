///|
/// Runtime availability of the linked Skia native backend.
pub fn skia_available() -> Bool {
  false
}

///|
priv type SurfaceHandle

///|
priv type CanvasHandle

///|
priv type DataHandle

///|
priv type CodecHandle

///|
priv type ImageHandle

///|
priv type PathHandle

///|
priv type FontHandle

///|
priv type TypefaceHandle

///|
priv type FontMgrHandle

///|
priv type ShaderHandle

///|
priv type ColorFilterHandle

///|
priv type ImageFilterHandle

///|
priv type MaskFilterHandle

///|
priv type BitmapHandle

///|
/// Placeholder surface type for non-native targets.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Surface {
  priv handle : SurfaceHandle
}

///|
/// Placeholder data type for non-native targets.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Data {
  priv handle : DataHandle
}

///|
/// Placeholder codec type for non-native targets.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Codec {
  priv handle : CodecHandle
}

///|
/// Placeholder image type for non-native targets.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Image {
  priv handle : ImageHandle
}

///|
/// Placeholder path type for non-native targets.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Path {
  priv handle : PathHandle
}

///|
/// Placeholder font type for non-native targets.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Font {
  priv handle : FontHandle
}

///|
/// Placeholder glyph identifier for non-native targets.
pub(all) struct GlyphId(UInt16) derive(Debug, Eq)

///|
pub fn GlyphId::new(value : UInt16) -> GlyphId {
  GlyphId(value)
}

///|
pub fn GlyphId::to_uint16(self : GlyphId) -> UInt16 {
  let GlyphId(value) = self
  value
}

///|
pub fn GlyphId::to_int(self : GlyphId) -> Int {
  self.to_uint16().to_int()
}

///|
/// Placeholder font metrics for non-native targets.
pub(all) struct FontMetrics {
  top : Float
  ascent : Float
  descent : Float
  bottom : Float
  leading : Float
  average_char_width : Float
  max_char_width : Float
  x_min : Float
  x_max : Float
  x_height : Float
  cap_height : Float
  underline_thickness : Float?
  underline_position : Float?
  strikeout_thickness : Float?
  strikeout_position : Float?
  has_bounds : Bool
} derive(Debug, Eq)

///|
/// Placeholder typeface type for non-native targets.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Typeface {
  priv handle : TypefaceHandle
}

///|
/// Placeholder font manager type for non-native targets.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct FontMgr {
  priv handle : FontMgrHandle
}

///|
/// Placeholder shader type for non-native targets.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Shader {
  priv handle : ShaderHandle
}

///|
/// Placeholder color-filter type for non-native targets.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct ColorFilter {
  priv handle : ColorFilterHandle
}

///|
/// Placeholder image-filter type for non-native targets.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct ImageFilter {
  priv handle : ImageFilterHandle
}

///|
/// Placeholder mask-filter type for non-native targets.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct MaskFilter {
  priv handle : MaskFilterHandle
}

///|
/// Placeholder bitmap type for non-native targets.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Bitmap {
  priv handle : BitmapHandle
}

///|
/// Placeholder canvas type for non-native targets.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Canvas {
  priv handle : CanvasHandle
  priv owner : Surface?
}

///|
pub fn Canvas::is_available(self : Canvas) -> Bool {
  ignore(self.owner)
  ignore(self)
  false
}

///|
pub fn Data::from_bytes(bytes : Bytes) -> Data? {
  ignore(bytes)
  None
}

///|
pub fn Data::is_available(self : Data) -> Bool {
  ignore(self)
  false
}

///|
pub fn Data::size(self : Data) -> Int {
  ignore(self)
  0
}

///|
pub fn Data::is_empty(self : Data) -> Bool {
  self.size() == 0
}

///|
pub fn Data::to_bytes(self : Data) -> Bytes {
  ignore(self)
  b""
}

///|
pub fn Codec::from_data(data : Data) -> Codec? {
  ignore(data)
  None
}

///|
pub fn Codec::from_bytes(bytes : Bytes) -> Codec? {
  ignore(bytes)
  None
}

///|
pub fn Codec::is_available(self : Codec) -> Bool {
  ignore(self)
  false
}

///|
pub fn Codec::width(self : Codec) -> Int {
  ignore(self)
  0
}

///|
pub fn Codec::height(self : Codec) -> Int {
  ignore(self)
  0
}

///|
pub fn Codec::dimensions(self : Codec) -> @skia.ISize {
  @skia.ISize::new(self.width(), self.height())
}

///|
pub fn Codec::image_info(self : Codec) -> @skia.ImageInfo {
  @skia.ImageInfo::n32_premul(self.dimensions())
}

///|
pub fn Codec::encoded_format(self : Codec) -> @skia.EncodedImageFormat? {
  ignore(self)
  None
}

///|
pub fn Codec::decode_n32_premul(self : Codec) -> Bitmap? {
  ignore(self)
  None
}

///|
pub fn Image::is_available(self : Image) -> Bool {
  ignore(self)
  false
}

///|
pub fn Image::width(self : Image) -> Int {
  ignore(self)
  0
}

///|
pub fn Image::height(self : Image) -> Int {
  ignore(self)
  0
}

///|
pub fn Image::dimensions(self : Image) -> @skia.ISize {
  @skia.ISize::new(self.width(), self.height())
}

///|
pub fn Image::image_info(self : Image) -> @skia.ImageInfo {
  @skia.ImageInfo::n32_premul(self.dimensions())
}

///|
pub fn Image::from_bitmap(bitmap : Bitmap) -> Image? {
  ignore(bitmap)
  None
}

///|
pub fn Image::from_encoded_data(data : Data) -> Image? {
  ignore(data)
  None
}

///|
pub fn Image::from_encoded_bytes(bytes : Bytes) -> Image? {
  ignore(bytes)
  None
}

///|
pub fn Image::encode_to_data(
  self : Image,
  format? : @skia.EncodedImageFormat = @skia.PNG,
  quality? : Int = 100,
) -> Data? {
  ignore(self)
  ignore(format)
  ignore(quality)
  None
}

///|
pub fn Path::new() -> Path? {
  None
}

///|
pub fn Path::from_value(path : @skia.Path) -> Path? {
  ignore(path)
  None
}

///|
pub fn Path::is_available(self : Path) -> Bool {
  ignore(self)
  false
}

///|
pub fn Path::set_fill_type(self : Path, fill_type : @skia.PathFillType) -> Unit {
  ignore(self)
  ignore(fill_type)
}

///|
pub fn Path::fill_type(self : Path) -> @skia.PathFillType {
  ignore(self)
  @skia.Winding
}

///|
pub fn Path::is_inverse_fill_type(self : Path) -> Bool {
  ignore(self)
  false
}

///|
pub fn Path::reset(self : Path) -> Unit {
  ignore(self)
}

///|
pub fn Path::rewind(self : Path) -> Unit {
  ignore(self)
}

///|
pub fn Path::move_to(self : Path, point : @skia.Point) -> Unit {
  ignore(self)
  ignore(point)
}

///|
pub fn Path::line_to(self : Path, point : @skia.Point) -> Unit {
  ignore(self)
  ignore(point)
}

///|
pub fn Path::quad_to(
  self : Path,
  control : @skia.Point,
  end : @skia.Point,
) -> Unit {
  ignore(self)
  ignore(control)
  ignore(end)
}

///|
pub fn Path::conic_to(
  self : Path,
  control : @skia.Point,
  end : @skia.Point,
  weight : Float,
) -> Unit {
  ignore(self)
  ignore(control)
  ignore(end)
  ignore(weight)
}

///|
pub fn Path::cubic_to(
  self : Path,
  control0 : @skia.Point,
  control1 : @skia.Point,
  end : @skia.Point,
) -> Unit {
  ignore(self)
  ignore(control0)
  ignore(control1)
  ignore(end)
}

///|
pub fn Path::close(self : Path) -> Unit {
  ignore(self)
}

///|
pub fn Path::add_path_value(
  self : Path,
  path : @skia.Path,
  matrix? : @skia.Matrix = @skia.Matrix::identity(),
  mode? : @skia.AddPathMode = @skia.Append,
) -> Unit {
  ignore(self)
  ignore(path)
  ignore(matrix)
  ignore(mode)
}

///|
pub fn Path::add_path_value_matrix(
  self : Path,
  path : @skia.Path,
  matrix : @skia.Matrix,
  mode? : @skia.AddPathMode = @skia.Append,
) -> Unit {
  ignore(self)
  ignore(path)
  ignore(matrix)
  ignore(mode)
}

///|
pub fn Path::add_path_value_offset(
  self : Path,
  path : @skia.Path,
  offset : @skia.Point,
  mode? : @skia.AddPathMode = @skia.Append,
) -> Unit {
  ignore(self)
  ignore(path)
  ignore(offset)
  ignore(mode)
}

///|
pub fn Path::add_poly(
  self : Path,
  points : Array[@skia.Point],
  close? : Bool = false,
) -> Unit {
  ignore(self)
  ignore(points)
  ignore(close)
}

///|
pub fn Path::add_rect(
  self : Path,
  rect : @skia.Rect,
  direction? : @skia.PathDirection = @skia.CW,
) -> Unit {
  ignore(self)
  ignore(rect)
  ignore(direction)
}

///|
pub fn Path::add_oval(
  self : Path,
  oval : @skia.Rect,
  direction? : @skia.PathDirection = @skia.CW,
) -> Unit {
  ignore(self)
  ignore(oval)
  ignore(direction)
}

///|
pub fn Path::add_circle(
  self : Path,
  center : @skia.Point,
  radius : Float,
  direction? : @skia.PathDirection = @skia.CW,
) -> Unit {
  ignore(self)
  ignore(center)
  ignore(radius)
  ignore(direction)
}

///|
pub fn Path::add_round_rect(
  self : Path,
  rect : @skia.Rect,
  rx : Float,
  ry : Float,
  direction? : @skia.PathDirection = @skia.CW,
) -> Unit {
  ignore(self)
  ignore(rect)
  ignore(rx)
  ignore(ry)
  ignore(direction)
}

///|
pub fn Path::add_rrect(
  self : Path,
  rrect : @skia.RRect,
  direction? : @skia.PathDirection = @skia.CW,
) -> Unit {
  ignore(self)
  ignore(rrect)
  ignore(direction)
}

///|
pub fn Path::transform(self : Path, matrix : @skia.Matrix) -> Unit {
  ignore(self)
  ignore(matrix)
}

///|
pub fn Path::offset(self : Path, dx : Float, dy : Float) -> Unit {
  ignore(self)
  ignore(dx)
  ignore(dy)
}

///|
pub fn Path::contains(self : Path, point : @skia.Point) -> Bool {
  ignore(self)
  ignore(point)
  false
}

///|
pub fn Path::is_empty(self : Path) -> Bool {
  ignore(self)
  true
}

///|
pub fn Path::is_finite(self : Path) -> Bool {
  ignore(self)
  true
}

///|
pub fn Path::count_points(self : Path) -> Int {
  ignore(self)
  0
}

///|
pub fn Path::count_verbs(self : Path) -> Int {
  ignore(self)
  0
}

///|
pub fn Path::segment_masks(self : Path) -> @skia.PathSegmentMask {
  ignore(self)
  @skia.PathSegmentMask::empty()
}

///|
pub fn Path::is_last_contour_closed(self : Path) -> Bool {
  ignore(self)
  false
}

///|
pub fn Path::last_point(self : Path) -> @skia.Point? {
  ignore(self)
  None
}

///|
pub fn Path::is_line(self : Path) -> @skia.PathLine? {
  ignore(self)
  None
}

///|
pub fn Path::is_rect(self : Path) -> @skia.PathRect? {
  ignore(self)
  None
}

///|
pub fn Path::is_oval(self : Path) -> @skia.Rect? {
  ignore(self)
  None
}

///|
pub fn Path::bounds(self : Path) -> @skia.Rect? {
  ignore(self)
  None
}

///|
pub fn Path::compute_tight_bounds(self : Path) -> @skia.Rect? {
  ignore(self)
  None
}

///|
pub fn Font::default(size? : Float = 12.0) -> Font? {
  ignore(size)
  None
}

///|
pub fn Font::from_typeface(typeface : Typeface, size? : Float = 12.0) -> Font? {
  ignore(typeface)
  ignore(size)
  None
}

///|
pub fn Font::is_available(self : Font) -> Bool {
  ignore(self)
  false
}

///|
pub fn Font::size(self : Font) -> Float {
  ignore(self)
  0.0
}

///|
pub fn Font::set_size(self : Font, size : Float) -> Unit {
  ignore(self)
  ignore(size)
}

///|
pub fn Font::measure_text_utf8(self : Font, text : Bytes) -> Float {
  ignore(self)
  ignore(text)
  0.0
}

///|
pub fn Font::count_text_utf8(self : Font, text : Bytes) -> Int {
  ignore(self)
  ignore(text)
  0
}

///|
pub fn Font::text_to_glyphs_utf8(self : Font, text : Bytes) -> Array[GlyphId] {
  ignore(self)
  ignore(text)
  []
}

///|
pub fn Font::glyph_width(self : Font, glyph : GlyphId) -> Float {
  ignore(self)
  ignore(glyph)
  0.0
}

///|
pub fn Font::glyph_widths(self : Font, glyphs : Array[GlyphId]) -> Array[Float] {
  ignore(self)
  ignore(glyphs)
  []
}

///|
pub fn Font::glyph_x_positions(
  self : Font,
  glyphs : Array[GlyphId],
  origin? : Float = 0.0,
) -> Array[Float] {
  ignore(self)
  ignore(glyphs)
  ignore(origin)
  []
}

///|
pub fn Font::glyph_positions(
  self : Font,
  glyphs : Array[GlyphId],
  origin? : @skia.Point = @skia.Point::new(0.0, 0.0),
) -> Array[@skia.Point] {
  ignore(self)
  ignore(glyphs)
  ignore(origin)
  []
}

///|
pub fn Font::text_glyph_x_positions_utf8(
  self : Font,
  text : Bytes,
  origin? : Float = 0.0,
) -> Array[Float] {
  ignore(self)
  ignore(text)
  ignore(origin)
  []
}

///|
pub fn Font::text_glyph_positions_utf8(
  self : Font,
  text : Bytes,
  origin? : @skia.Point = @skia.Point::new(0.0, 0.0),
) -> Array[@skia.Point] {
  ignore(self)
  ignore(text)
  ignore(origin)
  []
}

///|
pub fn Font::glyph_bounds(self : Font, glyph : GlyphId) -> @skia.Rect {
  ignore(self)
  ignore(glyph)
  @skia.Rect::empty()
}

///|
pub fn Font::glyph_bounds_many(
  self : Font,
  glyphs : Array[GlyphId],
) -> Array[@skia.Rect] {
  ignore(self)
  ignore(glyphs)
  []
}

///|
pub fn Font::measure_text_bounds_utf8(self : Font, text : Bytes) -> @skia.Rect? {
  ignore(self)
  ignore(text)
  None
}

///|
pub fn Font::metrics(self : Font) -> FontMetrics {
  ignore(self)
  {
    top: 0.0,
    ascent: 0.0,
    descent: 0.0,
    bottom: 0.0,
    leading: 0.0,
    average_char_width: 0.0,
    max_char_width: 0.0,
    x_min: 0.0,
    x_max: 0.0,
    x_height: 0.0,
    cap_height: 0.0,
    underline_thickness: None,
    underline_position: None,
    strikeout_thickness: None,
    strikeout_position: None,
    has_bounds: false,
  }
}

///|
pub fn Font::spacing(self : Font) -> Float {
  ignore(self)
  0.0
}

///|
pub fn Typeface::default() -> Typeface? {
  None
}

///|
pub fn Typeface::from_name(
  family_name : Bytes,
  weight? : Int = 400,
  width? : Int = 5,
  slant? : Int = 0,
) -> Typeface? {
  ignore(family_name)
  ignore(weight)
  ignore(width)
  ignore(slant)
  None
}

///|
pub fn FontMgr::default() -> FontMgr? {
  None
}

///|
pub fn FontMgr::is_available(self : FontMgr) -> Bool {
  ignore(self)
  false
}

///|
pub fn FontMgr::count_families(self : FontMgr) -> Int {
  ignore(self)
  0
}

///|
pub fn FontMgr::family_name(self : FontMgr, index : Int) -> Bytes? {
  ignore(self)
  ignore(index)
  None
}

///|
pub fn FontMgr::match_family_style(
  self : FontMgr,
  family_name : Bytes,
  weight? : Int = 400,
  width? : Int = 5,
  slant? : Int = 0,
) -> Typeface? {
  ignore(self)
  ignore(family_name)
  ignore(weight)
  ignore(width)
  ignore(slant)
  None
}

///|
pub fn Typeface::from_font_mgr_family(
  font_mgr : FontMgr,
  family_name : Bytes,
  weight? : Int = 400,
  width? : Int = 5,
  slant? : Int = 0,
) -> Typeface? {
  ignore(font_mgr)
  ignore(family_name)
  ignore(weight)
  ignore(width)
  ignore(slant)
  None
}

///|
pub fn Typeface::is_available(self : Typeface) -> Bool {
  ignore(self)
  false
}

///|
pub fn Typeface::is_bold(self : Typeface) -> Bool {
  ignore(self)
  false
}

///|
pub fn Typeface::is_italic(self : Typeface) -> Bool {
  ignore(self)
  false
}

///|
pub fn Typeface::is_fixed_pitch(self : Typeface) -> Bool {
  ignore(self)
  false
}

///|
pub fn Shader::color(color : @skia.Color) -> Shader? {
  ignore(color)
  None
}

///|
pub fn Shader::linear_gradient(
  start : @skia.Point,
  end : @skia.Point,
  start_color : @skia.Color,
  end_color : @skia.Color,
  tile_mode? : @skia.TileMode = @skia.Clamp,
) -> Shader? {
  ignore(start)
  ignore(end)
  ignore(start_color)
  ignore(end_color)
  ignore(tile_mode)
  None
}

///|
pub fn Shader::radial_gradient(
  center : @skia.Point,
  radius : Float,
  inner_color : @skia.Color,
  outer_color : @skia.Color,
  tile_mode? : @skia.TileMode = @skia.Clamp,
) -> Shader? {
  ignore(center)
  ignore(radius)
  ignore(inner_color)
  ignore(outer_color)
  ignore(tile_mode)
  None
}

///|
pub fn Shader::is_available(self : Shader) -> Bool {
  ignore(self)
  false
}

///|
pub fn ColorFilter::matrix(values : Array[Float]) -> ColorFilter? {
  ignore(values)
  None
}

///|
pub fn ColorFilter::saturation(amount : Float) -> ColorFilter? {
  ignore(amount)
  None
}

///|
pub fn ColorFilter::brightness(amount : Float) -> ColorFilter? {
  ignore(amount)
  None
}

///|
pub fn ColorFilter::contrast(amount : Float) -> ColorFilter? {
  ignore(amount)
  None
}

///|
pub fn ColorFilter::is_available(self : ColorFilter) -> Bool {
  ignore(self)
  false
}

///|
pub fn ImageFilter::blur(sigma_x : Float, sigma_y : Float) -> ImageFilter? {
  ignore(sigma_x)
  ignore(sigma_y)
  None
}

///|
pub fn ImageFilter::is_available(self : ImageFilter) -> Bool {
  ignore(self)
  false
}

///|
pub fn MaskFilter::blur(sigma : Float) -> MaskFilter? {
  ignore(sigma)
  None
}

///|
pub fn MaskFilter::is_available(self : MaskFilter) -> Bool {
  ignore(self)
  false
}

///|
pub fn Bitmap::alloc_n32_premul(size : @skia.ISize) -> Bitmap? {
  ignore(size)
  None
}

///|
pub fn Bitmap::is_available(self : Bitmap) -> Bool {
  ignore(self)
  false
}

///|
pub fn Bitmap::width(self : Bitmap) -> Int {
  ignore(self)
  0
}

///|
pub fn Bitmap::height(self : Bitmap) -> Int {
  ignore(self)
  0
}

///|
pub fn Bitmap::dimensions(self : Bitmap) -> @skia.ISize {
  @skia.ISize::new(self.width(), self.height())
}

///|
pub fn Bitmap::image_info(self : Bitmap) -> @skia.ImageInfo {
  @skia.ImageInfo::n32_premul(self.dimensions())
}

///|
pub fn Bitmap::row_bytes(self : Bitmap) -> Int {
  ignore(self)
  0
}

///|
pub fn Bitmap::byte_size(self : Bitmap) -> Int {
  ignore(self)
  0
}

///|
pub fn Bitmap::erase_color(self : Bitmap, color : @skia.Color) -> Unit {
  ignore(self)
  ignore(color)
}

///|
pub fn Bitmap::to_bytes(self : Bitmap) -> Bytes {
  ignore(self)
  b""
}

///|
pub fn Bitmap::to_pixmap(self : Bitmap) -> @skia.Pixmap? {
  ignore(self)
  None
}

///|
pub fn Canvas::save(self : Canvas) -> Int {
  ignore(self)
  0
}

///|
pub fn Canvas::save_layer(
  self : Canvas,
  bounds? : @skia.Rect? = None,
  paint? : @skia.Paint = @skia.Paint::new(),
  color_filter? : ColorFilter? = None,
  image_filter? : ImageFilter? = None,
  mask_filter? : MaskFilter? = None,
) -> Int {
  ignore(self)
  ignore(bounds)
  ignore(paint)
  ignore(color_filter)
  ignore(image_filter)
  ignore(mask_filter)
  0
}

///|
pub fn Canvas::restore(self : Canvas) -> Unit {
  ignore(self)
}

///|
pub fn Canvas::restore_to_count(self : Canvas, count : Int) -> Unit {
  ignore(self)
  ignore(count)
}

///|
pub fn Canvas::save_count(self : Canvas) -> Int {
  ignore(self)
  0
}

///|
pub fn Canvas::translate(self : Canvas, delta : @skia.Point) -> Unit {
  ignore(self)
  ignore(delta)
}

///|
pub fn Canvas::scale(self : Canvas, scale : @skia.Size) -> Unit {
  ignore(self)
  ignore(scale)
}

///|
pub fn Canvas::rotate(self : Canvas, degrees : Float) -> Unit {
  ignore(self)
  ignore(degrees)
}

///|
pub fn Canvas::skew(self : Canvas, skew : @skia.Point) -> Unit {
  ignore(self)
  ignore(skew)
}

///|
pub fn Canvas::concat(self : Canvas, matrix : @skia.Matrix) -> Unit {
  ignore(self)
  ignore(matrix)
}

///|
pub fn Canvas::reset_matrix(self : Canvas) -> Unit {
  ignore(self)
}

///|
pub fn Canvas::discard(self : Canvas) -> Unit {
  ignore(self)
}

///|
pub fn Canvas::clip_rect(
  self : Canvas,
  rect : @skia.Rect,
  op? : @skia.ClipOp = @skia.Intersect,
  anti_alias? : Bool = false,
) -> Unit {
  ignore(self)
  ignore(rect)
  ignore(op)
  ignore(anti_alias)
}

///|
pub fn Canvas::clip_rrect(
  self : Canvas,
  rrect : @skia.RRect,
  op? : @skia.ClipOp = @skia.Intersect,
  anti_alias? : Bool = false,
) -> Unit {
  ignore(self)
  ignore(rrect)
  ignore(op)
  ignore(anti_alias)
}

///|
pub fn Canvas::clip_path(
  self : Canvas,
  path : Path,
  op? : @skia.ClipOp = @skia.Intersect,
  anti_alias? : Bool = false,
) -> Unit {
  ignore(self)
  ignore(path)
  ignore(op)
  ignore(anti_alias)
}

///|
pub fn Canvas::local_clip_bounds(self : Canvas) -> @skia.Rect? {
  ignore(self)
  None
}

///|
pub fn Canvas::device_clip_bounds(self : Canvas) -> @skia.IRect? {
  ignore(self)
  None
}

///|
pub fn Canvas::quick_reject_rect(self : Canvas, rect : @skia.Rect) -> Bool {
  ignore(self)
  ignore(rect)
  false
}

///|
pub fn Canvas::quick_reject_path(self : Canvas, path : Path) -> Bool {
  ignore(self)
  ignore(path)
  false
}

///|
pub fn Canvas::draw_color(
  self : Canvas,
  color : @skia.Color,
  blend_mode? : @skia.BlendMode = @skia.SrcOver,
) -> Unit {
  ignore(self)
  ignore(color)
  ignore(blend_mode)
}

///|
pub fn Canvas::clear(self : Canvas, color : @skia.Color) -> Unit {
  ignore(self)
  ignore(color)
}

///|
pub fn Canvas::draw_paint(self : Canvas, paint : @skia.Paint) -> Unit {
  ignore(self)
  ignore(paint)
}

///|
pub fn Canvas::draw_point(
  self : Canvas,
  point : @skia.Point,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(point)
  ignore(paint)
}

///|
pub fn Canvas::draw_line(
  self : Canvas,
  start : @skia.Point,
  end : @skia.Point,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(start)
  ignore(end)
  ignore(paint)
}

///|
pub fn Canvas::draw_points(
  self : Canvas,
  points : Array[@skia.Point],
  paint : @skia.Paint,
  mode? : @skia.PointMode = @skia.Points,
) -> Unit {
  ignore(self)
  ignore(points)
  ignore(paint)
  ignore(mode)
}

///|
pub fn Canvas::draw_rect(
  self : Canvas,
  rect : @skia.Rect,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(rect)
  ignore(paint)
}

///|
pub fn Canvas::draw_oval(
  self : Canvas,
  oval : @skia.Rect,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(oval)
  ignore(paint)
}

///|
pub fn Canvas::draw_circle(
  self : Canvas,
  center : @skia.Point,
  radius : Float,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(center)
  ignore(radius)
  ignore(paint)
}

///|
pub fn Canvas::draw_arc(
  self : Canvas,
  oval : @skia.Rect,
  start_angle : Float,
  sweep_angle : Float,
  use_center : Bool,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(oval)
  ignore(start_angle)
  ignore(sweep_angle)
  ignore(use_center)
  ignore(paint)
}

///|
pub fn Canvas::draw_round_rect(
  self : Canvas,
  rect : @skia.Rect,
  rx : Float,
  ry : Float,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(rect)
  ignore(rx)
  ignore(ry)
  ignore(paint)
}

///|
pub fn Canvas::draw_rrect(
  self : Canvas,
  rrect : @skia.RRect,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(rrect)
  ignore(paint)
}

///|
pub fn Canvas::draw_drrect(
  self : Canvas,
  outer : @skia.RRect,
  inner : @skia.RRect,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(outer)
  ignore(inner)
  ignore(paint)
}

///|
pub fn Canvas::draw_path(
  self : Canvas,
  path : Path,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(path)
  ignore(paint)
}

///|
pub fn Canvas::draw_path_shader(
  self : Canvas,
  path : Path,
  shader : Shader,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(path)
  ignore(shader)
  ignore(paint)
}

///|
pub fn Canvas::draw_path_value(
  self : Canvas,
  path : @skia.Path,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(path)
  ignore(paint)
}

///|
pub fn Canvas::draw_image(
  self : Canvas,
  image : Image,
  top_left : @skia.Point,
) -> Unit {
  ignore(self)
  ignore(image)
  ignore(top_left)
}

///|
pub fn Canvas::draw_image_rect(
  self : Canvas,
  image : Image,
  src : @skia.Rect,
  dst : @skia.Rect,
  paint : @skia.Paint,
  sampling? : @skia.SamplingOptions = @skia.SamplingOptions::new(),
) -> Unit {
  ignore(self)
  ignore(image)
  ignore(src)
  ignore(dst)
  ignore(paint)
  ignore(sampling)
}

///|
pub fn Canvas::draw_paint_shader(
  self : Canvas,
  shader : Shader,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(shader)
  ignore(paint)
}

///|
pub fn Canvas::draw_rect_shader(
  self : Canvas,
  rect : @skia.Rect,
  shader : Shader,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(rect)
  ignore(shader)
  ignore(paint)
}

///|
pub fn Canvas::draw_round_rect_shader(
  self : Canvas,
  rect : @skia.Rect,
  rx : Float,
  ry : Float,
  shader : Shader,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(rect)
  ignore(rx)
  ignore(ry)
  ignore(shader)
  ignore(paint)
}

///|
pub fn Canvas::draw_text_utf8(
  self : Canvas,
  text : Bytes,
  origin : @skia.Point,
  font : Font,
  paint : @skia.Paint,
) -> Unit {
  ignore(self)
  ignore(text)
  ignore(origin)
  ignore(font)
  ignore(paint)
}

///|
pub fn Canvas::draw_glyphs(
  self : Canvas,
  glyphs : Array[GlyphId],
  positions : Array[@skia.Point],
  font : Font,
  paint : @skia.Paint,
  origin? : @skia.Point = @skia.Point::zero(),
) -> Unit {
  ignore(self)
  ignore(glyphs)
  ignore(positions)
  ignore(origin)
  ignore(font)
  ignore(paint)
}

///|
/// Allocate a raster N32 premultiplied surface.
///
/// Non-native targets do not link Skia, so this always returns `None`.
pub fn Surface::raster_n32_premul(size : @skia.ISize) -> Surface? {
  ignore(size)
  None
}

///|
pub fn Surface::width(self : Surface) -> Int {
  ignore(self)
  0
}

///|
pub fn Surface::height(self : Surface) -> Int {
  ignore(self)
  0
}

///|
pub fn Surface::dimensions(self : Surface) -> @skia.ISize {
  @skia.ISize::new(self.width(), self.height())
}

///|
pub fn Surface::image_info(self : Surface) -> @skia.ImageInfo {
  @skia.ImageInfo::n32_premul(self.dimensions())
}

///|
/// Snapshot current surface contents into an immutable image.
pub fn Surface::image_snapshot(self : Surface) -> Image? {
  ignore(self)
  None
}

///|
/// Snapshot a bounded rectangle of current surface contents into an image.
pub fn Surface::image_snapshot_with_bounds(
  self : Surface,
  bounds : @skia.IRect,
) -> Image? {
  ignore(self)
  ignore(bounds)
  None
}

///|
/// Read surface pixels into an owned MoonBit `Pixmap`.
pub fn Surface::read_pixels(
  self : Surface,
  bounds? : @skia.IRect = self.image_info().bounds(),
) -> @skia.Pixmap? {
  ignore(self)
  ignore(bounds)
  None
}

///|
/// Borrow the surface canvas.
pub fn Surface::canvas(self : Surface) -> Canvas? {
  ignore(self)
  None
}
