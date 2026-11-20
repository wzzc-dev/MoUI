///|
/// A line segment for rasterization
#derive(Debug)
struct LineSegment {
  x0 : Double
  y0 : Double
  x1 : Double
  y1 : Double
}

///|
pub extend LineSegment with Debug::{to_repr}

///|
priv struct CurvePoint {
  cx : Double
  cy : Double
  curve_on : Bool
}

///|
/// Rasterizer for rendering glyph outlines to pixels
/// Implements scanline fill with anti-aliasing
struct Rasterizer {
  width : Int32
  height : Int32
  pixels : FixedArray[Byte]
  coverage : FixedArray[Int32] // Coverage buffer for anti-aliasing
}

///|
/// Grayscale coverage mask produced by text rasterization
///
/// `offset_x`/`offset_y` place the mask's top-left pixel in the device-space
/// box it was rasterized against, so a mask can be a tight line box instead of
/// a full-canvas buffer while still compositing at its absolute position.
/// `phase_x`/`phase_y` record the sub-pixel text origin the coverage was
/// rasterized for; the cache compares them on a hit, because the mask is
/// line-local and only differs by phase when the origin keeps the same integer
/// pixel.
#derive(Debug)
struct CoverageMask {
  width : Int32
  height : Int32
  pixels : FixedArray[Byte]
  offset_x : Int32
  offset_y : Int32
  phase_x : Double
  phase_y : Double
}

///|
pub extend CoverageMask with Debug::{to_repr}

///|
/// Create a coverage mask from grayscale pixels with its origin at (0, 0)
pub fn CoverageMask::new(
  width : Int32,
  height : Int32,
  pixels : FixedArray[Byte],
) -> CoverageMask {
  {
    width,
    height,
    pixels,
    offset_x: 0,
    offset_y: 0,
    phase_x: 0.0,
    phase_y: 0.0,
  }
}

///|
/// Create a coverage mask whose top-left pixel sits at a device-space offset
pub fn CoverageMask::new_at(
  width : Int32,
  height : Int32,
  pixels : FixedArray[Byte],
  offset_x : Int32,
  offset_y : Int32,
) -> CoverageMask {
  { width, height, pixels, offset_x, offset_y, phase_x: 0.0, phase_y: 0.0, }
}

///|
/// Create an offset-carrying coverage mask that records the sub-pixel origin
/// its coverage was rasterized for.
fn CoverageMask::new_at_phase(
  width : Int32,
  height : Int32,
  pixels : FixedArray[Byte],
  offset_x : Int32,
  offset_y : Int32,
  phase_x : Double,
  phase_y : Double,
) -> CoverageMask {
  { width, height, pixels, offset_x, offset_y, phase_x, phase_y, }
}

///|
/// Get the width of the mask
pub fn CoverageMask::get_width(self : CoverageMask) -> Int32 {
  self.width
}

///|
/// Get the height of the mask
pub fn CoverageMask::get_height(self : CoverageMask) -> Int32 {
  self.height
}

///|
/// Get the grayscale coverage pixels
pub fn CoverageMask::get_pixels(self : CoverageMask) -> FixedArray[Byte] {
  self.pixels
}

///|
/// Get the device-space x offset of the mask's top-left pixel
pub fn CoverageMask::get_offset_x(self : CoverageMask) -> Int32 {
  self.offset_x
}

///|
/// Get the device-space y offset of the mask's top-left pixel
pub fn CoverageMask::get_offset_y(self : CoverageMask) -> Int32 {
  self.offset_y
}

///|
/// Get the sub-pixel x origin the mask was rasterized for
fn CoverageMask::get_phase_x(self : CoverageMask) -> Double {
  self.phase_x
}

///|
/// Get the sub-pixel y origin the mask was rasterized for
fn CoverageMask::get_phase_y(self : CoverageMask) -> Double {
  self.phase_y
}

///|
/// Copy this coverage mask and its pixel storage.
pub fn CoverageMask::copy(self : CoverageMask) -> CoverageMask {
  CoverageMask::new_at_phase(
    self.width,
    self.height,
    copy_bytes(self.pixels),
    self.offset_x,
    self.offset_y,
    self.phase_x,
    self.phase_y,
  )
}

///|
/// Placement of one glyph mask inside a glyph mask atlas.
#derive(Debug)
struct GlyphAtlasEntry {
  key : String
  x : Int32
  y : Int32
  width : Int32
  height : Int32
}

///|
pub extend GlyphAtlasEntry with Debug::{to_repr}

///|
/// Result of inserting a glyph mask into an atlas with lifecycle policy.
#derive(Debug)
struct GlyphMaskAtlasInsertResult {
  entry : GlyphAtlasEntry
  did_clear : Bool
  did_reuse : Bool
}

///|
pub extend GlyphMaskAtlasInsertResult with Debug::{to_repr}

///|
priv struct GlyphAtlasPlacement {
  x : Int32
  y : Int32
  row_height : Int32
}

///|
/// Create a glyph atlas entry.
pub fn GlyphAtlasEntry::new(
  key~ : String,
  x~ : Int32,
  y~ : Int32,
  width~ : Int32,
  height~ : Int32,
) -> GlyphAtlasEntry {
  { key, x, y, width, height, }
}

///|
/// Get the caller-provided glyph key for this atlas entry.
pub fn GlyphAtlasEntry::get_key(self : GlyphAtlasEntry) -> String {
  self.key
}

///|
/// Get the atlas x coordinate.
pub fn GlyphAtlasEntry::get_x(self : GlyphAtlasEntry) -> Int32 {
  self.x
}

///|
/// Get the atlas y coordinate.
pub fn GlyphAtlasEntry::get_y(self : GlyphAtlasEntry) -> Int32 {
  self.y
}

///|
/// Get the entry width.
pub fn GlyphAtlasEntry::get_width(self : GlyphAtlasEntry) -> Int32 {
  self.width
}

///|
/// Get the entry height.
pub fn GlyphAtlasEntry::get_height(self : GlyphAtlasEntry) -> Int32 {
  self.height
}

///|
/// Get the placed atlas entry.
pub fn GlyphMaskAtlasInsertResult::get_entry(
  self : GlyphMaskAtlasInsertResult,
) -> GlyphAtlasEntry {
  self.entry
}

///|
/// Return whether the atlas was cleared before this entry was inserted.
pub fn GlyphMaskAtlasInsertResult::did_clear(
  self : GlyphMaskAtlasInsertResult,
) -> Bool {
  self.did_clear
}

///|
/// Return whether this result reused an existing atlas entry.
pub fn GlyphMaskAtlasInsertResult::did_reuse(
  self : GlyphMaskAtlasInsertResult,
) -> Bool {
  self.did_reuse
}

///|
/// Small row-packed atlas for rendered glyph coverage masks.
#derive(Debug)
struct GlyphMaskAtlas {
  width : Int32
  height : Int32
  pixels : FixedArray[Byte]
  mut entries : Map[String, GlyphAtlasEntry]
  mut cursor_x : Int32
  mut cursor_y : Int32
  mut row_height : Int32
  mut used_pixel_count : Int32
}

///|
pub extend GlyphMaskAtlas with Debug::{to_repr}

///|
/// Create an empty glyph mask atlas.
pub fn GlyphMaskAtlas::new(width : Int32, height : Int32) -> GlyphMaskAtlas {
  {
    width,
    height,
    pixels: FixedArray::make(width * height, b"\x00"[0]),
    entries: Map([]),
    cursor_x: 0,
    cursor_y: 0,
    row_height: 0,
    used_pixel_count: 0,
  }
}

///|
/// Get the atlas width.
pub fn GlyphMaskAtlas::get_width(self : GlyphMaskAtlas) -> Int32 {
  self.width
}

///|
/// Get the atlas height.
pub fn GlyphMaskAtlas::get_height(self : GlyphMaskAtlas) -> Int32 {
  self.height
}

///|
/// Return the total pixel capacity of the atlas.
pub fn GlyphMaskAtlas::get_capacity(self : GlyphMaskAtlas) -> Int32 {
  self.width * self.height
}

///|
/// Return the number of atlas pixels occupied by placed glyph masks.
pub fn GlyphMaskAtlas::get_used_pixel_count(self : GlyphMaskAtlas) -> Int32 {
  self.used_pixel_count
}

///|
/// Return atlas capacity minus placed mask pixels.
pub fn GlyphMaskAtlas::get_free_pixel_count(self : GlyphMaskAtlas) -> Int32 {
  self.get_capacity() - self.used_pixel_count
}

///|
/// Return placed mask pixels divided by total atlas capacity.
pub fn GlyphMaskAtlas::get_occupancy_ratio(self : GlyphMaskAtlas) -> Double {
  let capacity = self.get_capacity()
  if capacity <= 0 {
    0.0
  } else {
    self.used_pixel_count.to_double() / capacity.to_double()
  }
}

///|
/// Return the number of placed glyph masks.
pub fn GlyphMaskAtlas::len(self : GlyphMaskAtlas) -> Int32 {
  self.entries.length()
}

///|
/// Return whether the atlas has no placed glyph masks.
pub fn GlyphMaskAtlas::is_empty(self : GlyphMaskAtlas) -> Bool {
  self.len() is 0
}

///|
/// Look up a placed glyph mask by key.
pub fn GlyphMaskAtlas::get(
  self : GlyphMaskAtlas,
  key : String,
) -> GlyphAtlasEntry? {
  self.entries.get(key)
}

///|
/// Snapshot the full atlas pixels as a coverage mask.
pub fn GlyphMaskAtlas::to_mask(self : GlyphMaskAtlas) -> CoverageMask {
  CoverageMask::new(self.width, self.height, copy_bytes(self.pixels))
}

///|
/// Return whether this mask can be placed as a new atlas entry.
pub fn GlyphMaskAtlas::can_fit(
  self : GlyphMaskAtlas,
  mask : CoverageMask,
) -> Bool {
  match self.next_placement(mask) {
    Some(_) => true
    None => false
  }
}

///|
/// Insert a rendered glyph mask if there is space, or return the existing entry.
pub fn GlyphMaskAtlas::insert(
  self : GlyphMaskAtlas,
  key : String,
  mask : CoverageMask,
) -> GlyphAtlasEntry? {
  match self.get(key) {
    Some(entry) => Some(entry)
    None => self.place(key, mask)
  }
}

///|
/// Insert a mask, clearing the atlas first if the current row-packing state is full.
/// When the result reports `did_clear`, previous atlas entries are no longer valid.
pub fn GlyphMaskAtlas::insert_or_clear(
  self : GlyphMaskAtlas,
  key : String,
  mask : CoverageMask,
) -> GlyphMaskAtlasInsertResult? {
  match self.get(key) {
    Some(entry) => Some({ entry, did_clear: false, did_reuse: true, })
    None =>
      match self.place(key, mask) {
        Some(entry) => Some({ entry, did_clear: false, did_reuse: false, })
        None => {
          guard self.can_fit_empty(mask) else { return None }
          self.clear()
          match self.place(key, mask) {
            Some(entry) => Some({ entry, did_clear: true, did_reuse: false, })
            None => None
          }
        }
      }
  }
}

///|
/// Remove all atlas entries and clear atlas pixels.
pub fn GlyphMaskAtlas::clear(self : GlyphMaskAtlas) -> Unit {
  self.entries = Map([])
  self.cursor_x = 0
  self.cursor_y = 0
  self.row_height = 0
  self.used_pixel_count = 0
  for i in 0..<self.pixels.length() {
    self.pixels[i] = b"\x00"[0]
  }
}

///|
fn GlyphMaskAtlas::next_placement(
  self : GlyphMaskAtlas,
  mask : CoverageMask,
) -> GlyphAtlasPlacement? {
  let mask_width = mask.get_width()
  let mask_height = mask.get_height()
  guard self.can_fit_empty(mask) else { return None }

  let should_wrap = self.cursor_x + mask_width > self.width
  let (entry_x, entry_y, current_row_height) = if should_wrap {
    (0, self.cursor_y + self.row_height, 0)
  } else {
    (self.cursor_x, self.cursor_y, self.row_height)
  }
  guard entry_y + mask_height <= self.height else { return None }
  Some({ x: entry_x, y: entry_y, row_height: current_row_height, })
}

///|
fn GlyphMaskAtlas::can_fit_empty(
  self : GlyphMaskAtlas,
  mask : CoverageMask,
) -> Bool {
  let mask_width = mask.get_width()
  let mask_height = mask.get_height()
  mask_width > 0 &&
  mask_height > 0 &&
  mask.get_pixels().length() >= mask_width * mask_height &&
  mask_width <= self.width &&
  mask_height <= self.height
}

///|
fn GlyphMaskAtlas::place(
  self : GlyphMaskAtlas,
  key : String,
  mask : CoverageMask,
) -> GlyphAtlasEntry? {
  let mask_width = mask.get_width()
  let mask_height = mask.get_height()
  let placement = match self.next_placement(mask) {
    Some(placement) => placement
    None => return None
  }

  let entry = GlyphAtlasEntry::new(
    key~,
    x=placement.x,
    y=placement.y,
    width=mask_width,
    height=mask_height,
  )
  copy_mask_into_atlas(self, entry, mask)
  self.entries[key] = entry
  self.cursor_x = placement.x + mask_width
  self.cursor_y = placement.y
  self.row_height = placement.row_height.max(mask_height)
  self.used_pixel_count += mask_width * mask_height
  Some(entry)
}

///|
fn copy_mask_into_atlas(
  atlas : GlyphMaskAtlas,
  entry : GlyphAtlasEntry,
  mask : CoverageMask,
) -> Unit {
  let src = mask.get_pixels()
  for y in 0..<entry.height {
    for x in 0..<entry.width {
      atlas.pixels[(entry.y + y) * atlas.width + entry.x + x] = src[y *
        entry.width +
        x]
    }
  }
}

///|
/// Small keyed cache for rendered glyph coverage masks.
#derive(Debug)
struct GlyphMaskCache {
  mut masks : Map[String, CoverageMask]
  mut access_order : Array[String]
  capacity : Int32
  is_bounded : Bool
}

///|
pub extend GlyphMaskCache with Debug::{to_repr}

///|
/// Result of reading a glyph mask from cache or rasterizing it on miss.
#derive(Debug)
struct GlyphMaskCacheRasterizeResult {
  mask : CoverageMask
  did_rasterize : Bool
}

///|
pub extend GlyphMaskCacheRasterizeResult with Debug::{to_repr}

///|
/// Placement data for a glyph mask rendered from a font face.
#derive(Debug)
struct FaceGlyphMaskPlacement {
  width : Int32
  height : Int32
  origin_x : Double
  origin_y : Double
  draw_offset_x : Int32
  draw_offset_y : Int32
}

///|
pub extend FaceGlyphMaskPlacement with Debug::{to_repr}

///|
/// Result of reading a face glyph mask from cache or rasterizing it on miss.
#derive(Debug)
struct FaceGlyphMaskCacheResult {
  mask : CoverageMask
  placement : FaceGlyphMaskPlacement
  did_rasterize : Bool
}

///|
pub extend FaceGlyphMaskCacheResult with Debug::{to_repr}

///|
/// Create an empty glyph mask cache.
pub fn GlyphMaskCache::new() -> GlyphMaskCache {
  { masks: Map([]), access_order: [], capacity: 0, is_bounded: false, }
}

///|
/// Create an empty glyph mask cache with least-recently-used eviction.
pub fn GlyphMaskCache::with_capacity(capacity : Int32) -> GlyphMaskCache {
  {
    masks: Map([]),
    access_order: [],
    capacity: capacity.max(1),
    is_bounded: true,
  }
}

///|
/// Get the resulting glyph coverage mask.
fn GlyphMaskCacheRasterizeResult::get_mask(
  self : GlyphMaskCacheRasterizeResult,
) -> CoverageMask {
  self.mask
}

///|
/// Return whether this lookup rasterized a new mask instead of hitting cache.
fn GlyphMaskCacheRasterizeResult::did_rasterize(
  self : GlyphMaskCacheRasterizeResult,
) -> Bool {
  self.did_rasterize
}

///|
/// Get the resulting face glyph coverage mask.
pub fn FaceGlyphMaskCacheResult::get_mask(
  self : FaceGlyphMaskCacheResult,
) -> CoverageMask {
  self.mask
}

///|
/// Get placement data for the resulting face glyph coverage mask.
pub fn FaceGlyphMaskCacheResult::get_placement(
  self : FaceGlyphMaskCacheResult,
) -> FaceGlyphMaskPlacement {
  self.placement
}

///|
/// Return whether this lookup rasterized a new face glyph mask.
pub fn FaceGlyphMaskCacheResult::did_rasterize(
  self : FaceGlyphMaskCacheResult,
) -> Bool {
  self.did_rasterize
}

///|
/// Get the mask width for this placement.
pub fn FaceGlyphMaskPlacement::get_width(
  self : FaceGlyphMaskPlacement,
) -> Int32 {
  self.width
}

///|
/// Get the mask height for this placement.
pub fn FaceGlyphMaskPlacement::get_height(
  self : FaceGlyphMaskPlacement,
) -> Int32 {
  self.height
}

///|
/// Get the raster origin X coordinate for this placement.
pub fn FaceGlyphMaskPlacement::get_origin_x(
  self : FaceGlyphMaskPlacement,
) -> Double {
  self.origin_x
}

///|
/// Get the raster origin Y coordinate for this placement.
pub fn FaceGlyphMaskPlacement::get_origin_y(
  self : FaceGlyphMaskPlacement,
) -> Double {
  self.origin_y
}

///|
/// Get the draw offset X coordinate for this placement.
pub fn FaceGlyphMaskPlacement::get_draw_offset_x(
  self : FaceGlyphMaskPlacement,
) -> Int32 {
  self.draw_offset_x
}

///|
/// Get the draw offset Y coordinate for this placement.
pub fn FaceGlyphMaskPlacement::get_draw_offset_y(
  self : FaceGlyphMaskPlacement,
) -> Int32 {
  self.draw_offset_y
}

///|
/// Return the number of cached glyph masks.
pub fn GlyphMaskCache::len(self : GlyphMaskCache) -> Int32 {
  self.masks.length()
}

///|
/// Return whether the cache currently has no glyph masks.
pub fn GlyphMaskCache::is_empty(self : GlyphMaskCache) -> Bool {
  self.len() is 0
}

///|
/// Return the maximum number of cached glyph masks, or 0 for an unbounded cache.
pub fn GlyphMaskCache::capacity(self : GlyphMaskCache) -> Int32 {
  self.capacity
}

///|
/// Return whether the cache has a configured entry limit.
pub fn GlyphMaskCache::is_capacity_bounded(self : GlyphMaskCache) -> Bool {
  self.is_bounded
}

///|
/// Return whether the cache has a glyph mask for this key without refreshing LRU.
pub fn GlyphMaskCache::contains(self : GlyphMaskCache, key : String) -> Bool {
  self.masks.contains(key)
}

///|
/// Look up a rendered glyph mask by caller-provided key.
pub fn GlyphMaskCache::get(
  self : GlyphMaskCache,
  key : String,
) -> CoverageMask? {
  match self.masks.get(key) {
    Some(mask) => {
      self.touch_key(key)
      Some(mask.copy())
    }
    None => None
  }
}

///|
/// Insert or replace a rendered glyph mask under a caller-provided key.
pub fn GlyphMaskCache::insert(
  self : GlyphMaskCache,
  key : String,
  mask : CoverageMask,
) -> CoverageMask {
  let stored = mask.copy()
  self.masks[key] = stored
  self.touch_key(key)
  self.evict_over_capacity()
  stored.copy()
}

///|
/// Rasterize a glyph on first use and report whether this lookup missed cache.
fn GlyphMaskCache::get_or_rasterize_glyph_result(
  self : GlyphMaskCache,
  key : String,
  glyph : SimpleGlyph,
  width : Int32,
  height : Int32,
  x : Double,
  y : Double,
  scale : Double,
) -> GlyphMaskCacheRasterizeResult {
  match self.get(key) {
    Some(mask) => { mask, did_rasterize: false, }
    None => {
      let mask = self.insert(
        key,
        render_glyph_mask(glyph, width, height, x, y, scale),
      )
      { mask, did_rasterize: true, }
    }
  }
}

///|
/// Rasterize a glyph from a parsed font face on first use and report cache state.
pub fn GlyphMaskCache::get_or_rasterize_face_glyph_result(
  self : GlyphMaskCache,
  key : String,
  face : FontFace,
  glyph_id : Int32,
  scale : Double,
) -> FaceGlyphMaskCacheResult? {
  match face.get_glyph(glyph_id) {
    Simple(simple_glyph) =>
      match make_face_glyph_mask_placement(simple_glyph, scale) {
        Some(placement) => {
          let result = self.get_or_rasterize_glyph_result(
            key,
            simple_glyph,
            placement.width,
            placement.height,
            placement.origin_x,
            placement.origin_y,
            scale,
          )
          Some({
            mask: result.get_mask(),
            placement,
            did_rasterize: result.did_rasterize(),
          })
        }
        None => None
      }
    _ => None
  }
}

///|
fn make_face_glyph_mask_placement(
  glyph : SimpleGlyph,
  scale : Double,
) -> FaceGlyphMaskPlacement? {
  guard scale > 0.0 && glyph.contours.length() > 0 else { return None }
  let left = floor_to_int(glyph.xmin.to_double() * scale)
  let right = ceil_to_int(glyph.xmax.to_double() * scale)
  let top = floor_to_int(0.0 - glyph.ymax.to_double() * scale)
  let bottom = ceil_to_int(0.0 - glyph.ymin.to_double() * scale)
  guard right > left && bottom > top else { return None }
  Some({
    width: right - left,
    height: bottom - top,
    origin_x: (0 - left).to_double(),
    origin_y: (0 - top).to_double(),
    draw_offset_x: left,
    draw_offset_y: top,
  })
}

///|
/// Remove a cached glyph mask by key.
pub fn GlyphMaskCache::remove(self : GlyphMaskCache, key : String) -> Unit {
  self.masks.remove(key)
  self.remove_access_key(key)
}

///|
/// Drop all cached glyph masks.
pub fn GlyphMaskCache::clear(self : GlyphMaskCache) -> Unit {
  self.masks = Map([])
  self.access_order = []
}

///|
fn GlyphMaskCache::touch_key(self : GlyphMaskCache, key : String) -> Unit {
  self.remove_access_key(key)
  self.access_order.push(key)
}

///|
fn GlyphMaskCache::remove_access_key(
  self : GlyphMaskCache,
  key : String,
) -> Unit {
  let mut index = 0
  while index < self.access_order.length() {
    if self.access_order[index] == key {
      ignore(self.access_order.remove(index))
    } else {
      index += 1
    }
  }
}

///|
fn GlyphMaskCache::evict_over_capacity(self : GlyphMaskCache) -> Unit {
  guard self.is_bounded && self.capacity > 0 else { return }
  while self.masks.length() > self.capacity && self.access_order.length() > 0 {
    let key = self.access_order.remove(0)
    self.masks.remove(key)
  }
}

///|
/// Small keyed cache for rendered text coverage masks.
#derive(Debug)
struct TextMaskCache {
  mut masks : Map[String, CoverageMask]
  mut access_order : Array[String]
  /// Laid-out advance width per cached span, keyed the same way as the masks
  /// but without the sub-pixel phase. Static text is re-drawn every frame;
  /// re-running shaping only to recover a width that cannot have changed is a
  /// large part of that per-frame cost, so the width is memoised with the mask.
  mut advances : Map[String, Double]
  capacity : Int32
  is_bounded : Bool
}

///|
pub extend TextMaskCache with Debug::{to_repr}

///|
/// Result of reading a rendered text mask from cache or rendering it on miss.
#derive(Debug)
struct TextMaskCacheRenderResult {
  mask : CoverageMask
  did_render : Bool
}

///|
pub extend TextMaskCacheRenderResult with Debug::{to_repr}

///|
/// Create an empty text mask cache.
pub fn TextMaskCache::new() -> TextMaskCache {
  {
    masks: Map([]),
    access_order: [],
    advances: Map([]),
    capacity: 0,
    is_bounded: false,
  }
}

///|
/// Create an empty text mask cache with least-recently-used eviction.
pub fn TextMaskCache::with_capacity(capacity : Int32) -> TextMaskCache {
  {
    masks: Map([]),
    access_order: [],
    advances: Map([]),
    capacity: capacity.max(1),
    is_bounded: true,
  }
}

///|
/// Get the resulting text coverage mask.
pub fn TextMaskCacheRenderResult::get_mask(
  self : TextMaskCacheRenderResult,
) -> CoverageMask {
  self.mask
}

///|
/// Return whether this lookup rendered a new mask instead of hitting cache.
pub fn TextMaskCacheRenderResult::did_render(
  self : TextMaskCacheRenderResult,
) -> Bool {
  self.did_render
}

///|
/// Return the number of cached masks.
pub fn TextMaskCache::len(self : TextMaskCache) -> Int32 {
  self.masks.length()
}

///|
/// Return whether the cache currently has no masks.
pub fn TextMaskCache::is_empty(self : TextMaskCache) -> Bool {
  self.len() is 0
}

///|
/// Return the maximum number of cached text masks, or 0 for an unbounded cache.
pub fn TextMaskCache::capacity(self : TextMaskCache) -> Int32 {
  self.capacity
}

///|
/// Return whether the cache has a configured entry limit.
pub fn TextMaskCache::is_capacity_bounded(self : TextMaskCache) -> Bool {
  self.is_bounded
}

///|
/// Return whether the cache has a text mask for this key without refreshing LRU.
pub fn TextMaskCache::contains(self : TextMaskCache, key : String) -> Bool {
  self.masks.contains(key)
}

///|
/// Look up a rendered mask by caller-provided key.
///
/// The cache owns its pixel buffers: lookups return a copy so a caller cannot
/// mutate cached coverage. Tight line-sized masks keep that copy cheap; a
/// canvas-sized mask must never reach this cache.
pub fn TextMaskCache::get(self : TextMaskCache, key : String) -> CoverageMask? {
  match self.masks.get(key) {
    Some(mask) => {
      self.touch_key(key)
      Some(mask.copy())
    }
    None => None
  }
}

///|
/// Return the memoised laid-out advance width for a span, if it was measured.
pub fn TextMaskCache::get_advance(
  self : TextMaskCache,
  key : String,
) -> Double? {
  self.advances.get(key)
}

///|
/// Memoise the laid-out advance width for a span.
pub fn TextMaskCache::insert_advance(
  self : TextMaskCache,
  key : String,
  width : Double,
) -> Unit {
  self.advances[key] = width
}

///|
/// Insert or replace a rendered mask under a caller-provided key.
///
/// The cache stores its own copy and returns the caller's mask, so later
/// mutation of either side cannot alias the other.
pub fn TextMaskCache::insert(
  self : TextMaskCache,
  key : String,
  mask : CoverageMask,
) -> CoverageMask {
  self.masks[key] = mask.copy()
  self.touch_key(key)
  self.evict_over_capacity()
  mask
}

///|
/// Render text from a checked face on first use and return the cached mask afterwards.
pub fn TextMaskCache::get_or_render_face(
  self : TextMaskCache,
  key : String,
  face : FontFace,
  text : String,
  width : Int32,
  height : Int32,
  x : Double,
  y : Double,
  config : LayoutConfig,
) -> CoverageMask {
  self
  .get_or_render_face_result(key, face, text, width, height, x, y, config)
  .get_mask()
}

///|
/// Render text from a checked face on first use and report whether cache missed.
pub fn TextMaskCache::get_or_render_face_result(
  self : TextMaskCache,
  key : String,
  face : FontFace,
  text : String,
  width : Int32,
  height : Int32,
  x : Double,
  y : Double,
  config : LayoutConfig,
) -> TextMaskCacheRenderResult {
  match self.get(key) {
    Some(mask) => { mask, did_render: false, }
    None => {
      let mask = self.insert(
        key,
        render_text_mask_face(face, text, width, height, x, y, config),
      )
      { mask, did_render: true, }
    }
  }
}

///|
/// Render text into a tight, offset-carrying mask on first use and return the
/// cached mask afterwards.
pub fn TextMaskCache::get_or_render_face_tight(
  self : TextMaskCache,
  key : String,
  face : FontFace,
  text : String,
  phase_x : Double,
  phase_y : Double,
  config : LayoutConfig,
) -> CoverageMask {
  self
  .get_or_render_face_tight_result(key, face, text, phase_x, phase_y, config)
  .get_mask()
}

///|
/// Render text into a tight, offset-carrying mask on first use and report
/// whether the cache missed.
pub fn TextMaskCache::get_or_render_face_tight_result(
  self : TextMaskCache,
  key : String,
  face : FontFace,
  text : String,
  phase_x : Double,
  phase_y : Double,
  config : LayoutConfig,
) -> TextMaskCacheRenderResult {
  match self.get(key) {
    // A tight mask bakes the sub-pixel phase into its coverage, while the key
    // stays position-independent so keyed-resource bookkeeping (`contains`,
    // eviction, `len`) keeps working. Reuse only when the phase matches;
    // otherwise re-rasterise and replace the entry under the same key.
    Some(mask) if mask.get_phase_x() == phase_x && mask.get_phase_y() == phase_y =>
      { mask, did_render: false, }
    Some(_) | None => {
      let mask = self.insert(
        key,
        render_text_mask_face_tight(face, text, phase_x, phase_y, config),
      )
      { mask, did_render: true, }
    }
  }
}

///|
/// Remove a cached mask by key.
pub fn TextMaskCache::remove(self : TextMaskCache, key : String) -> Unit {
  self.masks.remove(key)
  self.advances.remove(key)
  self.remove_access_key(key)
}

///|
/// Drop all cached masks.
pub fn TextMaskCache::clear(self : TextMaskCache) -> Unit {
  self.masks = Map([])
  self.advances = Map([])
  self.access_order = []
}

///|
fn TextMaskCache::touch_key(self : TextMaskCache, key : String) -> Unit {
  self.remove_access_key(key)
  self.access_order.push(key)
}

///|
fn TextMaskCache::remove_access_key(self : TextMaskCache, key : String) -> Unit {
  let mut index = 0
  while index < self.access_order.length() {
    if self.access_order[index] == key {
      ignore(self.access_order.remove(index))
    } else {
      index += 1
    }
  }
}

///|
fn TextMaskCache::evict_over_capacity(self : TextMaskCache) -> Unit {
  guard self.is_bounded && self.capacity > 0 else { return }
  while self.masks.length() > self.capacity && self.access_order.length() > 0 {
    let key = self.access_order.remove(0)
    self.masks.remove(key)
    self.advances.remove(key)
  }
}

///|
/// Create a new rasterizer
pub fn Rasterizer::new(width : Int32, height : Int32) -> Rasterizer {
  let size = width * height
  {
    width,
    height,
    pixels: FixedArray::make(size, b"\x00"[0]),
    coverage: FixedArray::make(size, 0),
  }
}

///|
/// Get the pixel buffer (grayscale)
pub fn Rasterizer::get_pixels(self : Rasterizer) -> FixedArray[Byte] {
  self.pixels
}

///|
/// Get the rasterizer width
pub fn Rasterizer::get_width(self : Rasterizer) -> Int32 {
  self.width
}

///|
/// Get the rasterizer height
pub fn Rasterizer::get_height(self : Rasterizer) -> Int32 {
  self.height
}

///|
/// Snapshot the current grayscale pixels as a coverage mask
pub fn Rasterizer::to_mask(self : Rasterizer) -> CoverageMask {
  CoverageMask::new(self.width, self.height, copy_bytes(self.pixels))
}

///|
/// Snapshot the current grayscale pixels as a coverage mask placed at a
/// device-space offset.
pub fn Rasterizer::to_mask_at(
  self : Rasterizer,
  offset_x : Int32,
  offset_y : Int32,
) -> CoverageMask {
  CoverageMask::new_at(
    self.width,
    self.height,
    copy_bytes(self.pixels),
    offset_x,
    offset_y,
  )
}

///|
/// Snapshot the current grayscale pixels as an offset- and phase-carrying
/// coverage mask.
fn Rasterizer::to_mask_at_phase(
  self : Rasterizer,
  offset_x : Int32,
  offset_y : Int32,
  phase_x : Double,
  phase_y : Double,
) -> CoverageMask {
  CoverageMask::new_at_phase(
    self.width,
    self.height,
    copy_bytes(self.pixels),
    offset_x,
    offset_y,
    phase_x,
    phase_y,
  )
}

///|
/// Clear the buffer
pub fn Rasterizer::clear(self : Rasterizer) -> Unit {
  for i in 0..<self.pixels.length() {
    self.pixels[i] = b"\x00"[0]
    self.coverage[i] = 0
  }
}

///|
/// Rasterize a simple glyph at the given position and scale with anti-aliasing
fn Rasterizer::rasterize_glyph(
  self : Rasterizer,
  glyph : SimpleGlyph,
  x : Double,
  y : Double,
  scale : Double,
) -> Unit {
  let segments = []
  for contour in glyph.contours {
    let contour_segments = flatten_contour(contour, x, y, scale)
    for segment in contour_segments {
      segments.push(segment)
    }
  }

  // Fill using scanline algorithm with anti-aliasing. The scanline pass owns
  // both the coverage write and the pixel apply, scoped to the glyph's own
  // bounding rows/columns, so no full-buffer clear is needed per glyph.
  scanline_fill_with_aa(self, segments)
}

///|
/// Rasterize laid-out text from a parsed font face into this rasterizer.
pub fn Rasterizer::rasterize_text_face(
  self : Rasterizer,
  face : FontFace,
  text : String,
  x : Double,
  y : Double,
  config : LayoutConfig,
) -> Unit {
  let font = face.get_font()
  let layout = layout_text_face(face, text, config)
  let scale = config.font_size / face.get_units_per_em().to_double()
  for run in layout.get_runs() {
    for glyph in run.get_glyphs() {
      match font.get_glyph(glyph.glyph_id) {
        Simple(simple_glyph) =>
          self.rasterize_glyph(
            simple_glyph,
            x + glyph.origin_x,
            y + run.get_baseline_y(),
            scale,
          )
        _ => ()
      }
    }
  }
}

///|
/// Render one glyph into a grayscale coverage mask.
fn render_glyph_mask(
  glyph : SimpleGlyph,
  width : Int32,
  height : Int32,
  x : Double,
  y : Double,
  scale : Double,
) -> CoverageMask {
  let rasterizer = Rasterizer::new(width, height)
  rasterizer.rasterize_glyph(glyph, x, y, scale)
  rasterizer.to_mask()
}

///|
/// Render text from a parsed font face into a grayscale coverage mask.
pub fn render_text_mask_face(
  face : FontFace,
  text : String,
  width : Int32,
  height : Int32,
  x : Double,
  y : Double,
  config : LayoutConfig,
) -> CoverageMask {
  let rasterizer = Rasterizer::new(width, height)
  rasterizer.rasterize_text_face(face, text, x, y, config)
  rasterizer.to_mask()
}

///|
/// Render text into a coverage mask that covers only the laid-out glyphs plus
/// one pixel of padding, and record the mask's device-space offset.
///
/// `phase_x`/`phase_y` are the sub-pixel position of the text origin inside
/// the pixel the caller will composite at; they are quantised by the caller
/// and recorded on the mask, so the cache can reuse it independent of the
/// absolute origin while still rejecting a mask rasterized for another phase.
pub fn render_text_mask_face_tight(
  face : FontFace,
  text : String,
  phase_x : Double,
  phase_y : Double,
  config : LayoutConfig,
) -> CoverageMask {
  let font = face.get_font()
  let layout = layout_text_face(face, text, config)
  let scale = config.font_size / face.get_units_per_em().to_double()
  let mut min_x = 0.0
  let mut min_y = 0.0
  let mut max_x = 0.0
  let mut max_y = 0.0
  let mut has_bounds = false
  for run in layout.get_runs() {
    let baseline_y = phase_y + run.get_baseline_y()
    for glyph in run.get_glyphs() {
      match font.get_glyph(glyph.glyph_id) {
        Simple(simple_glyph) =>
          if simple_glyph.contours.length() > 0 {
            let glyph_x = phase_x + glyph.origin_x
            let glyph_min_x = glyph_x + simple_glyph.xmin.to_double() * scale
            let glyph_max_x = glyph_x + simple_glyph.xmax.to_double() * scale
            let glyph_min_y = baseline_y - simple_glyph.ymax.to_double() * scale
            let glyph_max_y = baseline_y - simple_glyph.ymin.to_double() * scale
            if !has_bounds {
              min_x = glyph_min_x
              max_x = glyph_max_x
              min_y = glyph_min_y
              max_y = glyph_max_y
              has_bounds = true
            } else {
              if glyph_min_x < min_x {
                min_x = glyph_min_x
              }
              if glyph_max_x > max_x {
                max_x = glyph_max_x
              }
              if glyph_min_y < min_y {
                min_y = glyph_min_y
              }
              if glyph_max_y > max_y {
                max_y = glyph_max_y
              }
            }
          }
        _ => ()
      }
    }
  }
  if !has_bounds {
    return CoverageMask::new_at_phase(
      0,
      0,
      FixedArray::make(0, b"\x00"[0]),
      0,
      0,
      phase_x,
      phase_y,
    )
  }
  let left = floor_to_int(min_x) - 1
  let top = floor_to_int(min_y) - 1
  let width = ceil_to_int(max_x) + 1 - left
  let height = ceil_to_int(max_y) + 1 - top
  // One malformed font must not ask for an unbounded buffer; an empty mask
  // degrades to "nothing drawn" instead of exhausting memory.
  if width <= 0 || height <= 0 || width > 16384 || height > 4096 {
    return CoverageMask::new_at_phase(
      0,
      0,
      FixedArray::make(0, b"\x00"[0]),
      0,
      0,
      phase_x,
      phase_y,
    )
  }
  let rasterizer = Rasterizer::new(width, height)
  for run in layout.get_runs() {
    let baseline_y = phase_y + run.get_baseline_y()
    for glyph in run.get_glyphs() {
      match font.get_glyph(glyph.glyph_id) {
        Simple(simple_glyph) =>
          if simple_glyph.contours.length() > 0 {
            rasterizer.rasterize_glyph(
              simple_glyph,
              phase_x + glyph.origin_x - left.to_double(),
              baseline_y - top.to_double(),
              scale,
            )
          }
        _ => ()
      }
    }
  }
  rasterizer.to_mask_at_phase(left, top, phase_x, phase_y)
}

///|
fn flatten_contour(
  contour : GlyphContour,
  x : Double,
  y : Double,
  scale : Double,
) -> Array[LineSegment] {
  let points = contour.points
  let segments = []
  let len = points.length()
  guard len >= 2 else { return segments }

  let first = transform_point(points[0], x, y, scale)
  let last = transform_point(points[len - 1], x, y, scale)
  let mut current = if first.curve_on {
    first
  } else if last.curve_on {
    last
  } else {
    midpoint(last, first)
  }
  let mut index = if first.curve_on { 1 } else { 0 }
  let mut processed = 0

  while processed < len {
    let point = transform_point(points[index % len], x, y, scale)
    if point.curve_on {
      segments.push({
        x0: current.cx,
        y0: current.cy,
        x1: point.cx,
        y1: point.cy,
      })
      current = point
      index = index + 1
      processed = processed + 1
    } else {
      let next = transform_point(points[(index + 1) % len], x, y, scale)
      if next.curve_on {
        push_quadratic_segments(segments, current, point, next)
        current = next
        index = index + 2
        processed = processed + 2
      } else {
        let implicit = midpoint(point, next)
        push_quadratic_segments(segments, current, point, implicit)
        current = implicit
        index = index + 1
        processed = processed + 1
      }
    }
  }

  segments
}

///|
fn transform_point(
  point : GlyphPoint,
  x : Double,
  y : Double,
  scale : Double,
) -> CurvePoint {
  {
    cx: x + point.x.to_double() * scale,
    cy: y - point.y.to_double() * scale,
    curve_on: point.on_curve,
  }
}

///|
fn midpoint(a : CurvePoint, b : CurvePoint) -> CurvePoint {
  { cx: (a.cx + b.cx) / 2.0, cy: (a.cy + b.cy) / 2.0, curve_on: true, }
}

///|
fn push_quadratic_segments(
  segments : Array[LineSegment],
  start : CurvePoint,
  control : CurvePoint,
  end : CurvePoint,
) -> Unit {
  let bezier_segments = flatten_quadratic_bezier(
    start.cx,
    start.cy,
    control.cx,
    control.cy,
    end.cx,
    end.cy,
  )
  for segment in bezier_segments {
    segments.push(segment)
  }
}

///|
/// Flatten a quadratic bezier curve into line segments
fn flatten_quadratic_bezier(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> Array[LineSegment] {
  let segments = []
  let steps = calculate_bezier_steps(x0, y0, x1, y1, x2, y2)
  let mut prev_x = x0
  let mut prev_y = y0

  for i in 1..<=steps {
    let t = i.to_double() / steps.to_double()
    let mt = 1.0 - t
    let px = mt * mt * x0 + 2.0 * mt * t * x1 + t * t * x2
    let py = mt * mt * y0 + 2.0 * mt * t * y1 + t * t * y2
    segments.push({ x0: prev_x, y0: prev_y, x1: px, y1: py, })
    prev_x = px
    prev_y = py
  }

  segments
}

///|
/// Calculate number of steps needed for bezier flattening based on curve complexity
fn calculate_bezier_steps(
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
  x2 : Double,
  y2 : Double,
) -> Int32 {
  // Calculate deviation from straight line
  let dx = x2 - x0
  let dy = y2 - y0
  let d = dx * dx + dy * dy

  // If very short, use few steps
  if d < 4.0 {
    return 2
  }

  // Calculate control point deviation
  let mid_x = (x0 + x2) / 2.0
  let mid_y = (y0 + y2) / 2.0
  let dev_x = x1 - mid_x
  let dev_y = y1 - mid_y
  let deviation = dev_x * dev_x + dev_y * dev_y

  // More steps for higher deviation
  if deviation > 100.0 {
    32
  } else if deviation > 25.0 {
    16
  } else if deviation > 4.0 {
    8
  } else {
    4
  }
}

///|
/// One segment crossing of a horizontal sub-scanline.
priv struct ScanlineCrossing {
  x : Double
  dir : Int32
}

///|
/// Scanline fill with non-zero winding rule and 4x4 supersampling anti-aliasing
///
/// The winding test only depends on the crossings of one horizontal line, so
/// each sub-scanline is resolved once: collect where the segments cross it,
/// sort, and turn the accumulated winding into x-intervals. Per-pixel coverage
/// then falls out of the sub-columns of the four sub-scanlines, instead of
/// testing every pixel sample against every segment of the whole glyph run.
/// The crossing formula and its strict `x < sample` comparison are unchanged,
/// so the coverage bytes are identical to the former per-sample test.
fn scanline_fill_with_aa(
  rasterizer : Rasterizer,
  segments : Array[LineSegment],
) -> Unit {
  guard segments.length() > 0 else { return }

  // Find bounding box
  let mut min_y = segments[0].y0
  let mut max_y = segments[0].y0
  for seg in segments {
    if seg.y0 < min_y {
      min_y = seg.y0
    }
    if seg.y1 < min_y {
      min_y = seg.y1
    }
    if seg.y0 > max_y {
      max_y = seg.y0
    }
    if seg.y1 > max_y {
      max_y = seg.y1
    }
  }

  let y_start = min_y.to_int().max(0)
  let y_end = (max_y.to_int() + 1).min(rasterizer.height)
  let x_start = min_x(segments).to_int().max(0)
  let x_end = (max_x(segments).to_int() + 1).min(rasterizer.width)
  guard y_start < y_end && x_start < x_end else { return }

  // 4x4 supersampling for anti-aliasing
  let sample_count = 4
  let sample_count_sq = sample_count * sample_count // 16
  let crossings : Array[ScanlineCrossing] = []

  for y in y_start..<y_end {
    let row = y * rasterizer.width
    // `coverage` is a per-row accumulator of covered sub-samples; clear the
    // slice this glyph can touch before adding to it.
    for offset in 0..<(x_end - x_start) {
      rasterizer.coverage[row + x_start + offset] = 0
    }
    for sy in 0..<sample_count {
      let sample_y = y.to_double() +
        (sy.to_double() + 0.5) / sample_count.to_double()
      crossings.clear()
      for seg in segments {
        let y0 = seg.y0
        let y1 = seg.y1
        // Half-open crossing test: a shared vertex crosses exactly one of its
        // two segments, the same rule the per-sample winding test used.
        if (y0 < sample_y && y1 >= sample_y) ||
          (y1 < sample_y && y0 >= sample_y) {
          let t = (sample_y - y0) / (y1 - y0)
          crossings.push({
            x: seg.x0 + t * (seg.x1 - seg.x0),
            dir: if y0 < y1 {
              1
            } else {
              -1
            },
          })
        }
      }
      if crossings.is_empty() {
        continue
      }
      sort_crossings(crossings)
      let mut winding = 0
      let mut span_start = 0.0
      for crossing in crossings {
        let inside_before = winding != 0
        winding = winding + crossing.dir
        let inside_after = winding != 0
        if !inside_before && inside_after {
          span_start = crossing.x
        } else if inside_before && !inside_after {
          // A sample at sub-column x + q is inside iff span_start < x + q <
          // crossing.x, so each sub-column covers one integer px interval.
          for sx in 0..<sample_count {
            let q = (sx.to_double() + 0.5) / sample_count.to_double()
            let first = (floor_to_int(span_start - q) + 1).max(x_start)
            let last = (ceil_to_int(crossing.x - q) - 1).min(x_end - 1)
            let mut px = first
            while px <= last {
              let index = row + px
              rasterizer.coverage[index] = rasterizer.coverage[index] + 1
              px = px + 1
            }
          }
        }
      }
    }
    for x in x_start..<x_end {
      let index = row + x
      let covered = rasterizer.coverage[index]
      // Map coverage count to 0-255 and apply it (max-composite; overlapping
      // glyphs keep the stronger coverage).
      let value = if covered > 0 { covered * 255 / sample_count_sq } else { 0 }
      if value > 0 {
        let coverage = value.min(255).to_byte()
        if coverage.to_int() > rasterizer.pixels[index].to_int() {
          rasterizer.pixels[index] = coverage
        }
      }
    }
  }
}

///|
/// Insertion sort of one sub-scanline's crossings; a scanline crosses only a
/// handful of segments, so the quadratic order is below the noise.
fn sort_crossings(crossings : Array[ScanlineCrossing]) -> Unit {
  let mut index = 1
  while index < crossings.length() {
    let value = crossings[index]
    let mut slot = index
    while slot > 0 && crossings[slot - 1].x > value.x {
      crossings[slot] = crossings[slot - 1]
      slot = slot - 1
    }
    crossings[slot] = value
    index = index + 1
  }
}

///|
fn copy_bytes(src : FixedArray[Byte]) -> FixedArray[Byte] {
  let dst = FixedArray::make(src.length(), b"\x00"[0])
  for i in 0..<src.length() {
    dst[i] = src[i]
  }
  dst
}

///|
fn floor_to_int(value : Double) -> Int32 {
  let truncated = value.to_int()
  if truncated.to_double() > value {
    truncated - 1
  } else {
    truncated
  }
}

///|
fn ceil_to_int(value : Double) -> Int32 {
  let truncated = value.to_int()
  if truncated.to_double() < value {
    truncated + 1
  } else {
    truncated
  }
}

///|
/// Get minimum x coordinate from segments
fn min_x(segments : Array[LineSegment]) -> Double {
  let mut min_val = segments[0].x0
  for seg in segments {
    if seg.x0 < min_val {
      min_val = seg.x0
    }
    if seg.x1 < min_val {
      min_val = seg.x1
    }
  }
  min_val
}

///|
/// Get maximum x coordinate from segments
fn max_x(segments : Array[LineSegment]) -> Double {
  let mut max_val = segments[0].x0
  for seg in segments {
    if seg.x0 > max_val {
      max_val = seg.x0
    }
    if seg.x1 > max_val {
      max_val = seg.x1
    }
  }
  max_val
}

///|
/// Draw a line using Bresenham's algorithm (for outline rendering)
pub fn Rasterizer::draw_line(
  self : Rasterizer,
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Unit {
  let x_start = x0.to_int()
  let y_start = y0.to_int()
  let x_end = x1.to_int()
  let y_end = y1.to_int()

  let dx = (x_end - x_start).abs()
  let dy = (y_end - y_start).abs()
  let sx = if x_start < x_end { 1 } else { -1 }
  let sy = if y_start < y_end { 1 } else { -1 }
  let mut err = dx - dy

  let mut x = x_start
  let mut y = y_start

  while true {
    self.set_pixel(x, y, b"\xff"[0])

    if x == x_end && y == y_end {
      break
    }

    let e2 = 2 * err
    if e2 > -dy {
      err = err - dy
      x = x + sx
    }
    if e2 < dx {
      err = err + dx
      y = y + sy
    }
  }
}

///|
/// Set a pixel with bounds checking
fn Rasterizer::set_pixel(
  self : Rasterizer,
  x : Int32,
  y : Int32,
  value : Byte,
) -> Unit {
  guard x >= 0 && x < self.width && y >= 0 && y < self.height else { return }
  let idx = y * self.width + x
  self.pixels[idx] = value
}
