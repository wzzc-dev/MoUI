///|
/// Caller-owned text rendering resources shared across renderer text draws.
pub struct RendererTextResources {
  text_cache : @text.TextMaskCache
  glyph_cache : @text.GlyphMaskCache
  atlas : @text.GlyphMaskAtlas
} derive(Debug)

///|
/// Caller-owned renderer resources shared across GUI text and image draws.
pub struct RendererResources {
  font_cache : @text.FontFaceCache
  text : RendererTextResources
  image_cache : @graphics.PixmapCache
} derive(Debug)

///|
/// Snapshot of renderer text resource cache and atlas state.
pub struct RendererTextResourcesSnapshot {
  text_mask_count : Int
  text_mask_capacity : Int
  text_mask_is_bounded : Bool
  glyph_mask_count : Int
  glyph_mask_capacity : Int
  glyph_mask_is_bounded : Bool
  atlas_entry_count : Int
  atlas_width : Int
  atlas_height : Int
  atlas_capacity : Int
  atlas_used_pixel_count : Int
  atlas_free_pixel_count : Int
  atlas_occupancy_ratio : Double
} derive(Debug)

///|
/// Snapshot of renderer-wide resource cache state.
pub struct RendererResourcesSnapshot {
  font_face_count : Int
  font_face_capacity : Int
  font_face_is_bounded : Bool
  text_snapshot : RendererTextResourcesSnapshot
  image_count : Int
  image_capacity : Int
  image_is_bounded : Bool
} derive(Debug)

///|
/// One keyed font-byte source in an ordered fallback stack.
pub struct FontBytesFallbackSource {
  font_key : String
  font_data : Bytes
} derive(Debug)

///|
/// Create text resources with unbounded text/glyph caches and a glyph atlas.
pub fn RendererTextResources::new(
  atlas_width : Int,
  atlas_height : Int,
) -> RendererTextResources {
  {
    text_cache: @text.TextMaskCache::new(),
    glyph_cache: @text.GlyphMaskCache::new(),
    atlas: @text.GlyphMaskAtlas::new(atlas_width, atlas_height),
  }
}

///|
/// Create text resources with bounded text/glyph caches and a glyph atlas.
pub fn RendererTextResources::with_capacities(
  atlas_width : Int,
  atlas_height : Int,
  text_mask_capacity : Int,
  glyph_mask_capacity : Int,
) -> RendererTextResources {
  {
    text_cache: @text.TextMaskCache::with_capacity(text_mask_capacity),
    glyph_cache: @text.GlyphMaskCache::with_capacity(glyph_mask_capacity),
    atlas: @text.GlyphMaskAtlas::new(atlas_width, atlas_height),
  }
}

///|
/// Create renderer resources with unbounded font, text, and image caches.
pub fn RendererResources::new(
  atlas_width : Int,
  atlas_height : Int,
) -> RendererResources {
  {
    font_cache: @text.FontFaceCache::new(),
    text: RendererTextResources::new(atlas_width, atlas_height),
    image_cache: @graphics.PixmapCache::new(),
  }
}

///|
/// Create renderer resources with bounded text and image caches.
pub fn RendererResources::with_capacities(
  atlas_width : Int,
  atlas_height : Int,
  text_mask_capacity : Int,
  glyph_mask_capacity : Int,
  image_capacity : Int,
) -> RendererResources {
  {
    font_cache: @text.FontFaceCache::new(),
    text: RendererTextResources::with_capacities(
      atlas_width, atlas_height, text_mask_capacity, glyph_mask_capacity,
    ),
    image_cache: @graphics.PixmapCache::with_capacity(image_capacity),
  }
}

///|
/// Create renderer resources with bounded font, text, and image caches.
pub fn RendererResources::with_font_capacity(
  atlas_width : Int,
  atlas_height : Int,
  font_face_capacity : Int,
  text_mask_capacity : Int,
  glyph_mask_capacity : Int,
  image_capacity : Int,
) -> RendererResources {
  {
    font_cache: @text.FontFaceCache::with_capacity(font_face_capacity),
    text: RendererTextResources::with_capacities(
      atlas_width, atlas_height, text_mask_capacity, glyph_mask_capacity,
    ),
    image_cache: @graphics.PixmapCache::with_capacity(image_capacity),
  }
}

///|
/// Return the number of cached text masks in this snapshot.
pub fn RendererTextResourcesSnapshot::get_text_mask_count(
  self : RendererTextResourcesSnapshot,
) -> Int {
  self.text_mask_count
}

///|
/// Return the text-mask cache capacity, or 0 for unbounded caches.
pub fn RendererTextResourcesSnapshot::get_text_mask_capacity(
  self : RendererTextResourcesSnapshot,
) -> Int {
  self.text_mask_capacity
}

///|
/// Return whether the text-mask cache has an entry limit.
pub fn RendererTextResourcesSnapshot::is_text_mask_capacity_bounded(
  self : RendererTextResourcesSnapshot,
) -> Bool {
  self.text_mask_is_bounded
}

///|
/// Return the number of cached glyph masks in this snapshot.
pub fn RendererTextResourcesSnapshot::get_glyph_mask_count(
  self : RendererTextResourcesSnapshot,
) -> Int {
  self.glyph_mask_count
}

///|
/// Return the glyph-mask cache capacity, or 0 for unbounded caches.
pub fn RendererTextResourcesSnapshot::get_glyph_mask_capacity(
  self : RendererTextResourcesSnapshot,
) -> Int {
  self.glyph_mask_capacity
}

///|
/// Return whether the glyph-mask cache has an entry limit.
pub fn RendererTextResourcesSnapshot::is_glyph_mask_capacity_bounded(
  self : RendererTextResourcesSnapshot,
) -> Bool {
  self.glyph_mask_is_bounded
}

///|
/// Return the number of placed glyph atlas entries.
pub fn RendererTextResourcesSnapshot::get_atlas_entry_count(
  self : RendererTextResourcesSnapshot,
) -> Int {
  self.atlas_entry_count
}

///|
/// Return the glyph atlas width.
pub fn RendererTextResourcesSnapshot::get_atlas_width(
  self : RendererTextResourcesSnapshot,
) -> Int {
  self.atlas_width
}

///|
/// Return the glyph atlas height.
pub fn RendererTextResourcesSnapshot::get_atlas_height(
  self : RendererTextResourcesSnapshot,
) -> Int {
  self.atlas_height
}

///|
/// Return the total glyph atlas pixel capacity.
pub fn RendererTextResourcesSnapshot::get_atlas_capacity(
  self : RendererTextResourcesSnapshot,
) -> Int {
  self.atlas_capacity
}

///|
/// Return the number of glyph atlas pixels currently occupied.
pub fn RendererTextResourcesSnapshot::get_atlas_used_pixel_count(
  self : RendererTextResourcesSnapshot,
) -> Int {
  self.atlas_used_pixel_count
}

///|
/// Return the number of glyph atlas pixels still free.
pub fn RendererTextResourcesSnapshot::get_atlas_free_pixel_count(
  self : RendererTextResourcesSnapshot,
) -> Int {
  self.atlas_free_pixel_count
}

///|
/// Return used atlas pixels divided by atlas capacity.
pub fn RendererTextResourcesSnapshot::get_atlas_occupancy_ratio(
  self : RendererTextResourcesSnapshot,
) -> Double {
  self.atlas_occupancy_ratio
}

///|
/// Return the number of cached font faces in this snapshot.
pub fn RendererResourcesSnapshot::get_font_face_count(
  self : RendererResourcesSnapshot,
) -> Int {
  self.font_face_count
}

///|
/// Return the font-face cache capacity, or 0 for unbounded caches.
pub fn RendererResourcesSnapshot::get_font_face_capacity(
  self : RendererResourcesSnapshot,
) -> Int {
  self.font_face_capacity
}

///|
/// Return whether the font-face cache has an entry limit.
pub fn RendererResourcesSnapshot::is_font_face_capacity_bounded(
  self : RendererResourcesSnapshot,
) -> Bool {
  self.font_face_is_bounded
}

///|
/// Return the nested text-resource snapshot.
pub fn RendererResourcesSnapshot::get_text_snapshot(
  self : RendererResourcesSnapshot,
) -> RendererTextResourcesSnapshot {
  self.text_snapshot
}

///|
/// Return the number of cached image pixmaps in this snapshot.
pub fn RendererResourcesSnapshot::get_image_count(
  self : RendererResourcesSnapshot,
) -> Int {
  self.image_count
}

///|
/// Return the image cache capacity, or 0 for unbounded caches.
pub fn RendererResourcesSnapshot::get_image_capacity(
  self : RendererResourcesSnapshot,
) -> Int {
  self.image_capacity
}

///|
/// Return whether the image cache has an entry limit.
pub fn RendererResourcesSnapshot::is_image_capacity_bounded(
  self : RendererResourcesSnapshot,
) -> Bool {
  self.image_is_bounded
}

///|
/// Return a compact snapshot of text cache and glyph atlas telemetry.
pub fn RendererTextResources::snapshot(
  self : RendererTextResources,
) -> RendererTextResourcesSnapshot {
  {
    text_mask_count: self.text_cache.len(),
    text_mask_capacity: self.text_cache.capacity(),
    text_mask_is_bounded: self.text_cache.is_capacity_bounded(),
    glyph_mask_count: self.glyph_cache.len(),
    glyph_mask_capacity: self.glyph_cache.capacity(),
    glyph_mask_is_bounded: self.glyph_cache.is_capacity_bounded(),
    atlas_entry_count: self.atlas.len(),
    atlas_width: self.atlas.get_width(),
    atlas_height: self.atlas.get_height(),
    atlas_capacity: self.atlas.get_capacity(),
    atlas_used_pixel_count: self.atlas.get_used_pixel_count(),
    atlas_free_pixel_count: self.atlas.get_free_pixel_count(),
    atlas_occupancy_ratio: self.atlas.get_occupancy_ratio(),
  }
}

///|
/// Return a compact snapshot of renderer-wide resource telemetry.
pub fn RendererResources::snapshot(
  self : RendererResources,
) -> RendererResourcesSnapshot {
  {
    font_face_count: self.font_cache.len(),
    font_face_capacity: self.font_cache.capacity(),
    font_face_is_bounded: self.font_cache.is_capacity_bounded(),
    text_snapshot: self.text.snapshot(),
    image_count: self.image_cache.len(),
    image_capacity: self.image_cache.capacity(),
    image_is_bounded: self.image_cache.is_capacity_bounded(),
  }
}

///|
/// Get the reusable rendered text-mask cache.
pub fn RendererTextResources::get_text_mask_cache(
  self : RendererTextResources,
) -> @text.TextMaskCache {
  self.text_cache
}

///|
/// Get the reusable glyph mask cache.
pub fn RendererTextResources::get_glyph_mask_cache(
  self : RendererTextResources,
) -> @text.GlyphMaskCache {
  self.glyph_cache
}

///|
/// Get the reusable glyph mask atlas.
pub fn RendererTextResources::get_glyph_mask_atlas(
  self : RendererTextResources,
) -> @text.GlyphMaskAtlas {
  self.atlas
}

///|
/// Return whether these text resources have a rendered text mask for this key.
pub fn RendererTextResources::contains_text_mask(
  self : RendererTextResources,
  key : String,
) -> Bool {
  self.text_cache.contains(key)
}

///|
/// Return whether these text resources have a rendered glyph mask for this key.
pub fn RendererTextResources::contains_glyph_mask(
  self : RendererTextResources,
  key : String,
) -> Bool {
  self.glyph_cache.contains(key)
}

///|
/// Get the reusable checked font-face cache.
pub fn RendererResources::get_font_face_cache(
  self : RendererResources,
) -> @text.FontFaceCache {
  self.font_cache
}

///|
/// Get the reusable text rendering resources.
pub fn RendererResources::get_text_resources(
  self : RendererResources,
) -> RendererTextResources {
  self.text
}

///|
/// Get the reusable rendered text-mask cache.
pub fn RendererResources::get_text_mask_cache(
  self : RendererResources,
) -> @text.TextMaskCache {
  self.text.get_text_mask_cache()
}

///|
/// Get the reusable glyph mask cache.
pub fn RendererResources::get_glyph_mask_cache(
  self : RendererResources,
) -> @text.GlyphMaskCache {
  self.text.get_glyph_mask_cache()
}

///|
/// Get the reusable glyph mask atlas.
pub fn RendererResources::get_glyph_mask_atlas(
  self : RendererResources,
) -> @text.GlyphMaskAtlas {
  self.text.get_glyph_mask_atlas()
}

///|
/// Get the reusable image pixmap cache.
pub fn RendererResources::get_image_cache(
  self : RendererResources,
) -> @graphics.PixmapCache {
  self.image_cache
}

///|
/// Return whether these resources have a parsed font face for this key.
pub fn RendererResources::contains_font_face(
  self : RendererResources,
  key : String,
) -> Bool {
  self.font_cache.contains(key)
}

///|
/// Return whether these resources have a rendered text mask for this key.
pub fn RendererResources::contains_text_mask(
  self : RendererResources,
  key : String,
) -> Bool {
  self.text.contains_text_mask(key)
}

///|
/// Return whether these resources have a rendered glyph mask for this key.
pub fn RendererResources::contains_glyph_mask(
  self : RendererResources,
  key : String,
) -> Bool {
  self.text.contains_glyph_mask(key)
}

///|
/// Return whether these resources have an image pixmap for this key.
pub fn RendererResources::contains_image(
  self : RendererResources,
  key : String,
) -> Bool {
  self.image_cache.contains(key)
}

///|
/// Drop all cached text masks, glyph masks, and atlas entries.
pub fn RendererTextResources::clear(self : RendererTextResources) -> Unit {
  self.text_cache.clear()
  self.glyph_cache.clear()
  self.atlas.clear()
}

///|
/// Drop all cached font faces, text masks, glyph masks, atlas entries, and image
/// pixmaps.
pub fn RendererResources::clear(self : RendererResources) -> Unit {
  self.font_cache.clear()
  self.text.clear()
  self.image_cache.clear()
}

///|
/// Create one keyed font-byte source for fallback rendering.
pub fn FontBytesFallbackSource::new(
  font_key : String,
  font_data : Bytes,
) -> FontBytesFallbackSource {
  { font_key, font_data }
}

///|
/// Return the stable font-resource key for this fallback source.
pub fn FontBytesFallbackSource::get_font_key(
  self : FontBytesFallbackSource,
) -> String {
  self.font_key
}

///|
/// Return the font bytes for this fallback source.
pub fn FontBytesFallbackSource::get_font_data(
  self : FontBytesFallbackSource,
) -> Bytes {
  self.font_data
}
