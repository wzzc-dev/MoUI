///|
/// Small keyed cache for reusable pixmap resources.
pub struct PixmapCache {
  mut pixmaps : Map[String, Pixmap]
  mut access_order : Array[String]
  capacity : Int
  is_bounded : Bool
} derive(Debug)

///|
/// Result of reading a pixmap from cache or inserting it on miss.
pub struct PixmapCacheInsertResult {
  pixmap : Pixmap
  did_insert : Bool
} derive(Debug)

///|
/// Result of reading a pixmap from cache or decoding bytes on miss.
pub struct PixmapCacheDecodeResult {
  pixmap : Pixmap
  did_decode : Bool
} derive(Debug)

///|
/// Create an empty pixmap cache.
pub fn PixmapCache::new() -> PixmapCache {
  { pixmaps: Map([]), access_order: [], capacity: 0, is_bounded: false }
}

///|
/// Create an empty pixmap cache with least-recently-used eviction.
pub fn PixmapCache::with_capacity(capacity : Int) -> PixmapCache {
  {
    pixmaps: Map([]),
    access_order: [],
    capacity: capacity.max(1),
    is_bounded: true,
  }
}

///|
/// Get the resulting pixmap.
pub fn PixmapCacheInsertResult::get_pixmap(
  self : PixmapCacheInsertResult,
) -> Pixmap {
  self.pixmap
}

///|
/// Return whether this lookup inserted a new pixmap instead of hitting cache.
pub fn PixmapCacheInsertResult::did_insert(
  self : PixmapCacheInsertResult,
) -> Bool {
  self.did_insert
}

///|
/// Return whether this lookup reused a cached pixmap.
pub fn PixmapCacheInsertResult::did_hit_cache(
  self : PixmapCacheInsertResult,
) -> Bool {
  !self.did_insert
}

///|
/// Get the resulting pixmap.
pub fn PixmapCacheDecodeResult::get_pixmap(
  self : PixmapCacheDecodeResult,
) -> Pixmap {
  self.pixmap
}

///|
/// Return whether this lookup decoded bytes instead of hitting cache.
pub fn PixmapCacheDecodeResult::did_decode(
  self : PixmapCacheDecodeResult,
) -> Bool {
  self.did_decode
}

///|
/// Return whether this lookup reused a cached pixmap.
pub fn PixmapCacheDecodeResult::did_hit_cache(
  self : PixmapCacheDecodeResult,
) -> Bool {
  !self.did_decode
}

///|
/// Return the number of cached pixmaps.
pub fn PixmapCache::len(self : PixmapCache) -> Int {
  self.pixmaps.length()
}

///|
/// Return whether the cache currently has no pixmaps.
pub fn PixmapCache::is_empty(self : PixmapCache) -> Bool {
  self.len() is 0
}

///|
/// Return the maximum number of cached pixmaps, or 0 for an unbounded cache.
pub fn PixmapCache::capacity(self : PixmapCache) -> Int {
  self.capacity
}

///|
/// Return whether the cache has a configured entry limit.
pub fn PixmapCache::is_capacity_bounded(self : PixmapCache) -> Bool {
  self.is_bounded
}

///|
/// Return whether the cache has a pixmap for this key without refreshing LRU.
pub fn PixmapCache::contains(self : PixmapCache, key : String) -> Bool {
  self.pixmaps.contains(key)
}

///|
/// Look up a pixmap by caller-provided key.
pub fn PixmapCache::get(self : PixmapCache, key : String) -> Pixmap? {
  match self.pixmaps.get(key) {
    Some(pixmap) => {
      self.touch_key(key)
      Some(pixmap.copy())
    }
    None => None
  }
}

///|
/// Insert or replace a pixmap under a caller-provided key.
pub fn PixmapCache::insert(
  self : PixmapCache,
  key : String,
  pixmap : Pixmap,
) -> Pixmap {
  let stored = pixmap.copy()
  self.pixmaps[key] = stored
  self.touch_key(key)
  self.evict_over_capacity()
  stored.copy()
}

///|
/// Return a cached pixmap or insert this fallback pixmap on a miss.
pub fn PixmapCache::get_or_insert(
  self : PixmapCache,
  key : String,
  pixmap : Pixmap,
) -> Pixmap {
  self.get_or_insert_result(key, pixmap).get_pixmap()
}

///|
/// Return a cached pixmap or insert this fallback pixmap, reporting cache hits.
pub fn PixmapCache::get_or_insert_result(
  self : PixmapCache,
  key : String,
  pixmap : Pixmap,
) -> PixmapCacheInsertResult {
  match self.get(key) {
    Some(cached) => { pixmap: cached, did_insert: false }
    None => { pixmap: self.insert(key, pixmap), did_insert: true }
  }
}

///|
/// Return a cached pixmap or decode BMP bytes and cache the decoded pixmap.
pub fn PixmapCache::get_or_decode_bmp(
  self : PixmapCache,
  key : String,
  data : Bytes,
) -> Result[Pixmap, PixmapDecodeError] {
  match self.get_or_decode_bmp_result(key, data) {
    Ok(result) => Ok(result.get_pixmap())
    Err(error) => Err(error)
  }
}

///|
/// Return a cached pixmap or decode BMP bytes, reporting cache hits.
pub fn PixmapCache::get_or_decode_bmp_result(
  self : PixmapCache,
  key : String,
  data : Bytes,
) -> Result[PixmapCacheDecodeResult, PixmapDecodeError] {
  match self.get(key) {
    Some(cached) => Ok({ pixmap: cached, did_decode: false })
    None =>
      match Pixmap::from_bmp_bytes(data) {
        Ok(decoded) => {
          let pixmap = self.insert(key, decoded)
          Ok({ pixmap, did_decode: true })
        }
        Err(error) => Err(error)
      }
  }
}

///|
/// Return a cached pixmap or decode PNG bytes and cache the decoded pixmap.
pub fn PixmapCache::get_or_decode_png(
  self : PixmapCache,
  key : String,
  data : Bytes,
) -> Result[Pixmap, PixmapDecodeError] {
  match self.get_or_decode_png_result(key, data) {
    Ok(result) => Ok(result.get_pixmap())
    Err(error) => Err(error)
  }
}

///|
/// Return a cached pixmap or decode PNG bytes, reporting cache hits.
pub fn PixmapCache::get_or_decode_png_result(
  self : PixmapCache,
  key : String,
  data : Bytes,
) -> Result[PixmapCacheDecodeResult, PixmapDecodeError] {
  match self.get(key) {
    Some(cached) => Ok({ pixmap: cached, did_decode: false })
    None =>
      match Pixmap::from_png_bytes(data) {
        Ok(decoded) => {
          let pixmap = self.insert(key, decoded)
          Ok({ pixmap, did_decode: true })
        }
        Err(error) => Err(error)
      }
  }
}

///|
/// Return a cached pixmap or decode raw RGBA bytes and cache the pixmap.
pub fn PixmapCache::get_or_decode_rgba(
  self : PixmapCache,
  key : String,
  width : Int,
  height : Int,
  data : Bytes,
) -> Result[Pixmap, PixmapDecodeError] {
  match self.get_or_decode_rgba_result(key, width, height, data) {
    Ok(result) => Ok(result.get_pixmap())
    Err(error) => Err(error)
  }
}

///|
/// Return a cached pixmap or decode raw RGBA bytes, reporting cache hits.
pub fn PixmapCache::get_or_decode_rgba_result(
  self : PixmapCache,
  key : String,
  width : Int,
  height : Int,
  data : Bytes,
) -> Result[PixmapCacheDecodeResult, PixmapDecodeError] {
  match self.get(key) {
    Some(cached) => Ok({ pixmap: cached, did_decode: false })
    None =>
      match Pixmap::from_rgba_bytes(width, height, data) {
        Ok(decoded) => {
          let pixmap = self.insert(key, decoded)
          Ok({ pixmap, did_decode: true })
        }
        Err(error) => Err(error)
      }
  }
}

///|
/// Remove a cached pixmap by key.
pub fn PixmapCache::remove(self : PixmapCache, key : String) -> Unit {
  self.pixmaps.remove(key)
  self.remove_access_key(key)
}

///|
/// Drop all cached pixmaps.
pub fn PixmapCache::clear(self : PixmapCache) -> Unit {
  self.pixmaps = Map([])
  self.access_order = []
}

///|
fn PixmapCache::touch_key(self : PixmapCache, key : String) -> Unit {
  self.remove_access_key(key)
  self.access_order.push(key)
}

///|
fn PixmapCache::remove_access_key(self : PixmapCache, key : String) -> Unit {
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
fn PixmapCache::evict_over_capacity(self : PixmapCache) -> Unit {
  guard self.is_bounded && self.capacity > 0 else { return }
  while self.pixmaps.length() > self.capacity && self.access_order.length() > 0 {
    let key = self.access_order.remove(0)
    self.pixmaps.remove(key)
  }
}
