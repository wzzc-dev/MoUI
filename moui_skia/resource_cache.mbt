///|
priv struct ResourceCacheItem[V] {
  value : V
  byte_size : Int64
  last_used : Int64
}

///|
/// Observable counters for a resource cache.
pub(all) struct ResourceCacheStats {
  count : Int
  byte_size : Int64
  max_bytes : Int64
  hits : Int
  misses : Int
  evictions : Int
} derive(Debug, Eq)

///|
/// Small deterministic LRU cache for renderer-owned resources.
pub(all) struct ResourceCache[K, V] {
  priv entries : Map[K, ResourceCacheItem[V]]
  priv mut max_bytes : Int64
  priv mut current_bytes : Int64
  priv mut clock : Int64
  priv mut hits : Int
  priv mut misses : Int
  priv mut evictions : Int
}

///|
fn non_negative_i64(value : Int64) -> Int64 {
  if value < 0L {
    0L
  } else {
    value
  }
}

///|
pub fn[K, V] ResourceCache::new(max_bytes? : Int64 = 0L) -> ResourceCache[K, V] {
  {
    entries: Default::default(),
    max_bytes: non_negative_i64(max_bytes),
    current_bytes: 0L,
    clock: 0L,
    hits: 0,
    misses: 0,
    evictions: 0,
  }
}

///|
pub fn[K, V] ResourceCache::length(self : ResourceCache[K, V]) -> Int {
  self.entries.length()
}

///|
pub fn[K, V] ResourceCache::is_empty(self : ResourceCache[K, V]) -> Bool {
  self.entries.is_empty()
}

///|
pub fn[K, V] ResourceCache::byte_size(self : ResourceCache[K, V]) -> Int64 {
  self.current_bytes
}

///|
pub fn[K, V] ResourceCache::max_bytes(self : ResourceCache[K, V]) -> Int64 {
  self.max_bytes
}

///|
pub fn[K, V] ResourceCache::stats(
  self : ResourceCache[K, V],
) -> ResourceCacheStats {
  {
    count: self.length(),
    byte_size: self.current_bytes,
    max_bytes: self.max_bytes,
    hits: self.hits,
    misses: self.misses,
    evictions: self.evictions,
  }
}

///|
fn[K, V] ResourceCache::least_recent_key(self : ResourceCache[K, V]) -> K? {
  let mut oldest_key : K? = None
  let mut oldest_tick = 0L
  self.entries.each(fn(key, item) {
    match oldest_key {
      None => {
        oldest_key = Some(key)
        oldest_tick = item.last_used
      }
      Some(_) =>
        if item.last_used < oldest_tick {
          oldest_key = Some(key)
          oldest_tick = item.last_used
        }
    }
  })
  oldest_key
}

///|
fn[K : Hash + Eq, V] ResourceCache::remove_without_stats(
  self : ResourceCache[K, V],
  key : K,
) -> Bool {
  match self.entries.get(key) {
    None => false
    Some(item) => {
      self.entries.remove(key)
      self.current_bytes -= item.byte_size
      true
    }
  }
}

///|
fn[K : Hash + Eq, V] ResourceCache::evict_until_fit(
  self : ResourceCache[K, V],
) -> Unit {
  if self.max_bytes > 0L && self.current_bytes > self.max_bytes {
    match self.least_recent_key() {
      None => ()
      Some(key) => {
        if self.remove_without_stats(key) {
          self.evictions += 1
        }
        self.evict_until_fit()
      }
    }
  }
}

///|
pub fn[K : Hash + Eq, V] ResourceCache::contains(
  self : ResourceCache[K, V],
  key : K,
) -> Bool {
  self.entries.contains(key)
}

///|
pub fn[K : Hash + Eq, V] ResourceCache::insert(
  self : ResourceCache[K, V],
  key : K,
  value : V,
  byte_size? : Int64 = 0L,
) -> Bool {
  let byte_size = non_negative_i64(byte_size)
  if self.max_bytes > 0L && byte_size > self.max_bytes {
    ignore(self.remove_without_stats(key))
    false
  } else {
    match self.entries.get(key) {
      None => ()
      Some(item) => self.current_bytes -= item.byte_size
    }
    self.clock += 1L
    self.entries.set(key, { value, byte_size, last_used: self.clock })
    self.current_bytes += byte_size
    self.evict_until_fit()
    true
  }
}

///|
pub fn[K : Hash + Eq, V] ResourceCache::peek(
  self : ResourceCache[K, V],
  key : K,
) -> V? {
  match self.entries.get(key) {
    None => None
    Some(item) => Some(item.value)
  }
}

///|
pub fn[K : Hash + Eq, V] ResourceCache::get(
  self : ResourceCache[K, V],
  key : K,
) -> V? {
  match self.entries.get(key) {
    None => {
      self.misses += 1
      None
    }
    Some(item) => {
      self.hits += 1
      self.clock += 1L
      self.entries.set(key, { ..item, last_used: self.clock })
      Some(item.value)
    }
  }
}

///|
pub fn[K : Hash + Eq, V] ResourceCache::remove(
  self : ResourceCache[K, V],
  key : K,
) -> Bool {
  self.remove_without_stats(key)
}

///|
pub fn[K, V] ResourceCache::clear(self : ResourceCache[K, V]) -> Unit {
  self.entries.clear()
  self.current_bytes = 0L
}

///|
pub fn[K : Hash + Eq, V] ResourceCache::set_max_bytes(
  self : ResourceCache[K, V],
  max_bytes : Int64,
) -> Unit {
  self.max_bytes = non_negative_i64(max_bytes)
  self.evict_until_fit()
}
