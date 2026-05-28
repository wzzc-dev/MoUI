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
priv type ShaderHandle

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
/// Placeholder typeface type for non-native targets.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Typeface {
  priv handle : TypefaceHandle
}

///|
/// Placeholder shader type for non-native targets.
#warnings("-struct_never_constructed-unused_field")
pub(all) struct Shader {
  priv handle : ShaderHandle
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
pub fn Typeface::default() -> Typeface? {
  None
}

///|
pub fn Typeface::from_name(family_name : Bytes) -> Typeface? {
  ignore(family_name)
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
) -> Int {
  ignore(self)
  ignore(bounds)
  ignore(paint)
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
