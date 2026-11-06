///|
/// Owner-local paragraph-layout memo. A renderer/text service creates one
/// instance and wraps its paragraph compute hook with it; the cache identity is
/// (text system id, owner font generation, full `TextLayoutInput`). Lookups
/// index a 64-bit FNV-1a digest into buckets and verify the exact identity on
/// hit, so a hash collision cannot return the wrong layout.
///
/// Font registration bumps only this owner's generation. Two renderers with
/// different font sets therefore never invalidate each other's paragraphs.
priv struct TextParagraphCacheEntry {
  text_system_id : String
  font_generation : Int32
  input : @core.TextLayoutInput
  mut result : @core.TextParagraphLayoutResult
  mut last_used : Int64
}

///|
/// Bounded, single-owner paragraph cache. The cache is intentionally not a
/// process global: the renderer session or text service owns one instance and
/// decides its capacity and byte budget.
pub struct TextParagraphCache {
  priv buckets : Map[UInt64, Array[TextParagraphCacheEntry]]
  priv mut count : Int32
  priv mut text_bytes : Int32
  priv mut font_generation : Int32
  priv mut tick : Int64
  priv capacity : Int32
  priv text_budget_bytes : Int32
}

///|
pub fn TextParagraphCache::new(
  capacity~ : Int32 = 4096,
  text_budget_bytes~ : Int32 = 16 * 1024 * 1024,
) -> TextParagraphCache {
  {
    buckets: Map([]),
    count: 0,
    text_bytes: 0,
    font_generation: 0,
    tick: 0L,
    capacity,
    text_budget_bytes,
  }
}

///|
pub fn TextParagraphCache::layout_paragraph(
  self : TextParagraphCache,
  text_system_id : String,
  input : @core.TextLayoutInput,
  compute : (@core.TextLayoutInput) -> @core.TextParagraphLayoutResult,
) -> @core.TextParagraphLayoutResult {
  match self.lookup(text_system_id, input) {
    Some(result) => result
    None => {
      let result = compute(input)
      self.store(text_system_id, input, result)
      result
    }
  }
}

///|
/// Retire every pre-registration entry for this owner. Called when the owner's
/// font set changes: measured widths can change for every cached paragraph.
pub fn TextParagraphCache::register_font_data(
  self : TextParagraphCache,
) -> Unit {
  self.font_generation = self.font_generation + 1
  self.clear()
}

///|
pub fn TextParagraphCache::count(self : TextParagraphCache) -> Int32 {
  self.count
}

///|
pub fn TextParagraphCache::text_bytes(self : TextParagraphCache) -> Int32 {
  self.text_bytes
}

///|
pub fn TextParagraphCache::font_generation(self : TextParagraphCache) -> Int32 {
  self.font_generation
}

///|
fn TextParagraphCache::clear(self : TextParagraphCache) -> Unit {
  self.buckets.clear()
  self.count = 0
  self.text_bytes = 0
}

///|
fn TextParagraphCache::next_tick(self : TextParagraphCache) -> Int64 {
  self.tick = self.tick + 1L
  self.tick
}

///|
fn TextParagraphCache::lookup(
  self : TextParagraphCache,
  text_system_id : String,
  input : @core.TextLayoutInput,
) -> @core.TextParagraphLayoutResult? {
  if self.count == 0 {
    return None
  }
  let digest = text_paragraph_cache_input_digest(
    text_system_id,
    input,
    self.font_generation,
  )
  match self.buckets.get(digest) {
    None => None
    Some(bucket) => {
      let mut found : @core.TextParagraphLayoutResult? = None
      for entry in bucket {
        if text_paragraph_cache_entry_matches(
            entry,
            text_system_id,
            input,
            self.font_generation,
          ) {
          entry.last_used = self.next_tick()
          found = Some(entry.result)
          break
        }
      }
      found
    }
  }
}

///|
/// Removes the single least recently used entry across all buckets.
/// Returns false when the cache is already empty.
fn TextParagraphCache::evict_oldest(self : TextParagraphCache) -> Bool {
  let mut oldest_digest : UInt64? = None
  let mut oldest_bucket : Array[TextParagraphCacheEntry]? = None
  let mut oldest_index = 0
  let mut oldest_used : Int64 = 0L
  for digest, bucket in self.buckets {
    for index, entry in bucket {
      if oldest_bucket is None || entry.last_used < oldest_used {
        oldest_digest = Some(digest)
        oldest_bucket = Some(bucket)
        oldest_index = index
        oldest_used = entry.last_used
      }
    }
  }
  match oldest_bucket {
    None => false
    Some(bucket) => {
      let evicted = bucket.remove(oldest_index)
      if bucket.is_empty() {
        match oldest_digest {
          Some(digest) => ignore(self.buckets.remove(digest))
          None => ()
        }
      }
      self.count = self.count - 1
      self.text_bytes = self.text_bytes - evicted.input.text.length()
      true
    }
  }
}

///|
fn TextParagraphCache::store(
  self : TextParagraphCache,
  text_system_id : String,
  input : @core.TextLayoutInput,
  result : @core.TextParagraphLayoutResult,
) -> Unit {
  let text_bytes = input.text.length()
  if text_bytes > self.text_budget_bytes {
    return
  }
  let digest = text_paragraph_cache_input_digest(
    text_system_id,
    input,
    self.font_generation,
  )
  match self.buckets.get(digest) {
    Some(bucket) =>
      // An identity match updates the entry in place — no bucket rebuild,
      // no double-counted bytes, refreshed recency.
      for entry in bucket {
        if text_paragraph_cache_entry_matches(
            entry,
            text_system_id,
            input,
            self.font_generation,
          ) {
          entry.result = result
          entry.last_used = self.next_tick()
          return
        }
      }
    None => ()
  }
  // Evict least-recently-used entries one at a time until the new entry fits
  // both bounds, instead of dropping the whole cache.
  while self.count >= self.capacity ||
        self.text_bytes + text_bytes > self.text_budget_bytes {
    if !self.evict_oldest() {
      break
    }
  }
  let entry : TextParagraphCacheEntry = {
    text_system_id,
    font_generation: self.font_generation,
    input,
    result,
    last_used: self.next_tick(),
  }
  match self.buckets.get(digest) {
    Some(bucket) => bucket.push(entry)
    None => self.buckets[digest] = [entry]
  }
  self.count = self.count + 1
  self.text_bytes = self.text_bytes + text_bytes
}

///|
fn text_paragraph_cache_digest_mix(hash : UInt64, value : UInt64) -> UInt64 {
  let mut hash = hash ^ value
  hash = hash * 0x100000001b3UL
  hash
}

///|
fn text_paragraph_cache_digest_string(hash : UInt64, text : String) -> UInt64 {
  let mut hash = text_paragraph_cache_digest_mix(
    hash,
    text.length().to_uint64(),
  )
  for ch in text {
    hash = text_paragraph_cache_digest_mix(hash, ch.to_int().to_uint64())
  }
  hash
}

///|
fn text_paragraph_cache_digest_family(
  hash : UInt64,
  family : @core.FontFamily,
) -> UInt64 {
  match family {
    Name(name) =>
      text_paragraph_cache_digest_string(
        text_paragraph_cache_digest_mix(hash, 0UL),
        name,
      )
    SystemUi => text_paragraph_cache_digest_mix(hash, 1UL)
    UiSansSerif => text_paragraph_cache_digest_mix(hash, 2UL)
    UiSerif => text_paragraph_cache_digest_mix(hash, 3UL)
    UiMonospace => text_paragraph_cache_digest_mix(hash, 4UL)
    SansSerif => text_paragraph_cache_digest_mix(hash, 5UL)
    Serif => text_paragraph_cache_digest_mix(hash, 6UL)
    Monospace => text_paragraph_cache_digest_mix(hash, 7UL)
    Emoji => text_paragraph_cache_digest_mix(hash, 8UL)
    Math => text_paragraph_cache_digest_mix(hash, 9UL)
    FangSong => text_paragraph_cache_digest_mix(hash, 10UL)
  }
}

///|
fn text_paragraph_cache_digest_font(
  hash : UInt64,
  font : @core.FontSpec,
) -> UInt64 {
  let mut hash = text_paragraph_cache_digest_mix(
    hash,
    font.families.families.length().to_uint64(),
  )
  for family in font.families.families {
    hash = text_paragraph_cache_digest_family(hash, family)
  }
  hash = text_paragraph_cache_digest_string(hash, font.size.to_string())
  hash = text_paragraph_cache_digest_string(hash, font.weight.to_string())
  hash = match font.style {
    Normal => text_paragraph_cache_digest_mix(hash, 0UL)
    Italic => text_paragraph_cache_digest_mix(hash, 1UL)
  }
  hash = text_paragraph_cache_digest_mix(
    hash,
    font.variations.length().to_uint64(),
  )
  for variation in font.variations {
    hash = text_paragraph_cache_digest_string(hash, variation.axis)
    hash = text_paragraph_cache_digest_string(hash, variation.value.to_string())
  }
  hash
}

///|
fn text_paragraph_cache_input_digest(
  text_system_id : String,
  input : @core.TextLayoutInput,
  font_generation : Int32,
) -> UInt64 {
  let mut hash = 0xcbf29ce484222325UL
  hash = text_paragraph_cache_digest_string(hash, text_system_id)
  hash = text_paragraph_cache_digest_mix(hash, font_generation.to_uint64())
  hash = match input.max_width {
    None => text_paragraph_cache_digest_mix(hash, 0UL)
    Some(width) =>
      text_paragraph_cache_digest_string(
        text_paragraph_cache_digest_mix(hash, 1UL),
        width.to_string(),
      )
  }
  hash = text_paragraph_cache_digest_string(hash, input.text)
  text_paragraph_cache_digest_font(hash, input.font)
}

///|
fn text_paragraph_cache_entry_matches(
  entry : TextParagraphCacheEntry,
  text_system_id : String,
  input : @core.TextLayoutInput,
  font_generation : Int32,
) -> Bool {
  entry.font_generation == font_generation &&
  entry.text_system_id == text_system_id &&
  entry.input == input
}

///|
fn text_paragraph_cache_test_result(
  input : @core.TextLayoutInput,
) -> @core.TextParagraphLayoutResult {
  let clusters = input.text.length()
  {
    text: input.text,
    size: @core.Size::new(width=10.0, height=20.0),
    baseline: 16.0,
    lines: [],
    caret_rects: [],
    visual_order: {
      logical_text: input.text,
      visual_text: input.text,
      logical_cluster_count: clusters,
      visual_cluster_count: clusters,
      segment_count: 1,
      glyph_count: clusters,
      visual_order_differs: false,
      bidi_visual_order_ready: false,
    },
    metadata: {
      text_system_id: "test",
      paragraph_layout_available: false,
      line_metrics_available: false,
      selection_rects_available: false,
      hit_test_available: false,
      native_paragraph_ready: false,
      bidi_visual_order_ready: false,
    },
  }
}

///|
test "paragraph layouts are memoized per input identity" {
  let cache = TextParagraphCache::new()
  let calls = Ref(0)
  let compute = input => {
    calls.val = calls.val + 1
    text_paragraph_cache_test_result(input)
  }
  let input = @core.TextLayoutInput::new(
    text="hello",
    font=@core.FontSpec::new(),
  )
  ignore(cache.layout_paragraph("test", input, compute))
  ignore(cache.layout_paragraph("test", input, compute))
  inspect(calls.val, content="1")
  inspect(cache.count(), content="1")
}

///|
test "font registration retires only the owning cache" {
  let first = TextParagraphCache::new()
  let second = TextParagraphCache::new()
  let calls = Ref(0)
  let compute = input => {
    calls.val = calls.val + 1
    text_paragraph_cache_test_result(input)
  }
  let input = @core.TextLayoutInput::new(
    text="hello",
    font=@core.FontSpec::new(),
  )
  ignore(first.layout_paragraph("test", input, compute))
  ignore(second.layout_paragraph("test", input, compute))
  first.register_font_data()
  ignore(second.layout_paragraph("test", input, compute))
  inspect(calls.val, content="2")
  inspect(first.count(), content="0")
  inspect(second.count(), content="1")
}

///|
test "cache evicts least recently used entries at the entry cap" {
  let cache = TextParagraphCache::new(capacity=2)
  let compute = text_paragraph_cache_test_result
  let font = @core.FontSpec::new()
  for text in ["a", "b", "c"] {
    ignore(
      cache.layout_paragraph(
        "test",
        @core.TextLayoutInput::new(text~, font~),
        compute,
      ),
    )
  }
  inspect(cache.count(), content="2")
}
