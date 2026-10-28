///|
/// Cross-frame cache for `BeginRetainedLayer` repaint boundaries.
///
/// The mechanism is the pool the host already has. A boundary's group is painted
/// into its own offscreen pass target, `moui_metal_pass_target` keeps one target
/// per slot between frames and rebuilds it only when the size differs, and the
/// composite samples that slot by number. So when the same boundary claims the
/// same slot at the same device rect in two consecutive frames, the pixels the
/// first frame wrote are still sitting in that texture and the second frame can
/// composite it without rebuilding the group. Nothing is copied and no new host
/// object is introduced; the only host change is that a pass record with no
/// children gets no encoder, because clearing it is exactly what would destroy
/// the cached pixels.
///
/// Three guards make that reuse safe rather than lucky, and each closes a
/// different way to paint an old picture:
///
/// - `revision` must match. `content_revision` is the framework's statement that
///   the group's content changed, and this route trusts it the way the runtime's
///   own caches do — which is why a boundary whose content changed *without* a
///   revision bump keeps painting the cached pixels. That is the contract, and
///   `metal_retained_wbtest.mbt` pins it as a pixel claim rather than leaving it
///   implied, because a stale-look is the only observable difference between
///   reading a cache and re-rendering it.
/// - `slot`, `device_x`, `device_y`, `device_width`, `device_height` must all
///   match. Slots are claimed per frame in post-order, so an unchanged-looking
///   boundary can move down the list when a sibling appears or disappears; if it
///   does, the texture at its old slot belongs to whatever claimed it, and a
///   rect that moved is a different render of the same content.
/// - the entry must have been painted in the frame *immediately* before this one.
///   A gap means some other frame ran between the two, and a pass target is not
///   private to a boundary — anything that claimed that slot in the gap overwrote
///   it. Ageing entries out at the start of each frame is what turns the cache
///   into a working set, and the drops it causes are counted. A hit re-stamps the
///   entry without painting, which keeps the same rule true for a stable page (an
///   entry that aged out on its second hit would make the cache save one frame in
///   two) and is still sound, because the frame that hit also *claimed* the slot,
///   so nothing else could have painted it.
priv struct MetalRetainedEntry {
  revision : Int32
  slot : Int32
  device_x : Int32
  device_y : Int32
  device_width : Int32
  device_height : Int32
  painted_at : Int32
}

///|
priv struct MetalRetainedCache {
  mut context : UInt64
  mut generation : Int32
  mut entries : Map[String, MetalRetainedEntry]
  // Entries dropped at the start of the frame being built, so a host can tell a
  // page that holds its boundaries from one whose list keeps changing.
  mut evicted : Int32
}

///|
fn new_metal_retained_cache() -> MetalRetainedCache {
  MetalRetainedCache::{
    context: 0UL,
    generation: 0,
    entries: Map([]),
    evicted: 0,
  }
}

///|
/// Forget every entry. Used when the surface is resized, which re-sizes the host
/// pass targets the entries point into, and by a frame that has no history to
/// consult — the CPU-only report and a single proof frame.
fn clear_metal_retained_cache(cache : MetalRetainedCache) -> Unit {
  cache.entries = Map([])
  cache.evicted = 0
}

///|
/// Open one frame's worth of cache. A different context handle means a different
/// Metal device, whose pool holds nothing this cache painted, so every entry goes.
/// Otherwise every entry that was not painted by the immediately preceding frame
/// is dropped: its target may have been claimed by another pass in the gap.
fn MetalRetainedCache::begin_frame(
  self : MetalRetainedCache,
  context : UInt64,
) -> Unit {
  if self.context != context {
    self.context = context
    self.entries = Map([])
  }
  let kept : Map[String, MetalRetainedEntry] = Map([])
  self.evicted = 0
  for (key, entry) in self.entries {
    if entry.painted_at == self.generation {
      kept.set(key, entry)
    } else {
      self.evicted = self.evicted + 1
    }
  }
  self.entries = kept
  self.generation = self.generation + 1
}

///|
/// True when this boundary may composite the texture it already owns. The caller
/// passes the slot it is *about* to claim, so the answer is a statement about
/// this frame's layout, not about a past one.
fn metal_retained_hit(
  cache : MetalRetainedCache,
  key : String,
  revision : Int32,
  slot : Int32,
  device_x : Int32,
  device_y : Int32,
  device_width : Int32,
  device_height : Int32,
) -> Bool {
  match cache.entries.get(key) {
    Some(entry) =>
      entry.revision == revision &&
      entry.slot == slot &&
      entry.device_x == device_x &&
      entry.device_y == device_y &&
      entry.device_width == device_width &&
      entry.device_height == device_height &&
      entry.painted_at == cache.generation - 1
    None => false
  }
}

///|
/// Record what this frame painted into the slot, so the next one can ask whether
/// it may skip the work. The return says whether this key previously held a
/// *different* revision, which is the `update` case: the group was repainted
/// because the framework said its content changed, not because the layout moved.
fn metal_retained_store(
  cache : MetalRetainedCache,
  key : String,
  revision : Int32,
  slot : Int32,
  device_x : Int32,
  device_y : Int32,
  device_width : Int32,
  device_height : Int32,
) -> Bool {
  let updated = match cache.entries.get(key) {
    Some(entry) => entry.revision != revision
    None => false
  }
  cache.entries.set(key, MetalRetainedEntry::{
    revision,
    slot,
    device_x,
    device_y,
    device_width,
    device_height,
    painted_at: cache.generation,
  })
  updated
}
