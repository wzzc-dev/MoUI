///|
/// A caller-owned, multi-entry construction cache for keyed view builders.
///
/// Each entry is stored under a stable `builder_key` and records the
/// `content_key` used to build it. A lookup is a hit only when both match; a
/// miss replaces that builder's entry.
///
/// This is deliberately not dependency tracking or component state. The caller
/// must include every model value, environment/theme value, conditional branch,
/// event-handler payload, map-transform capture, and other construction input
/// in `content_key`. An incomplete key serves a stale view.
///
/// The cache does not evict automatically. Use `remove` when a keyed item or
/// conditional branch disappears, and `clear` when its owning screen/root is
/// torn down. Element identity, reconciliation, layout, paint, and transient
/// control state remain owned by the runtime.
///
/// `ViewBuilderCache` is a handle: copying the struct aliases the same entries
/// and counters. Keep one owner per bounded collection/screen. Use `ViewMemo`
/// instead for one independently invalidated subtree.
pub struct ViewBuilderCache[Msg] {
  priv state : Ref[ViewBuilderCacheState[Msg]]
}

///|
/// A caller-readable snapshot of one builder cache's construction counters.
///
/// A miss is counted when a lookup is not served from the cache. A build is
/// counted after `build` returns successfully. They are normally equal, but
/// remain separate so failed work cannot be mistaken for a completed build.
///
/// Counters cover the cache handle's lifetime. `clear` removes entries without
/// resetting these counters.
pub struct ViewBuilderCacheStats {
  priv build_count : Int32
  priv hit_count : Int32
  priv miss_count : Int32
  priv entry_count : Int32
} derive(Eq, Debug)

///|
pub extend ViewBuilderCacheStats with Debug::{to_repr}

///|
pub extend ViewBuilderCacheStats with Eq::{not_equal, equal}

///|
priv struct ViewBuilderCacheState[Msg] {
  entries : Map[DeclarationKey, ViewBuilderCacheEntry[Msg]]
  mut build_count : Int32
  mut hit_count : Int32
  mut miss_count : Int32
}

///|
priv struct ViewBuilderCacheEntry[Msg] {
  content_key : DeclarationKey
  view : View[Msg]
}

///|
pub fn[Msg] ViewBuilderCache::new() -> ViewBuilderCache[Msg] {
  {
    state: Ref({
      entries: Map([]),
      build_count: 0,
      hit_count: 0,
      miss_count: 0,
    }),
  }
}

///|
pub fn ViewBuilderCacheStats::build_count(
  self : ViewBuilderCacheStats,
) -> Int32 {
  self.build_count
}

///|
pub fn ViewBuilderCacheStats::hit_count(self : ViewBuilderCacheStats) -> Int32 {
  self.hit_count
}

///|
pub fn ViewBuilderCacheStats::miss_count(self : ViewBuilderCacheStats) -> Int32 {
  self.miss_count
}

///|
pub fn ViewBuilderCacheStats::entry_count(
  self : ViewBuilderCacheStats,
) -> Int32 {
  self.entry_count
}

///|
/// Return a snapshot of this cache's construction counters and current entry
/// count.
///
/// The counters stay inside the caller-owned cache. They are not registered
/// globally and do not appear in `RuntimeInspectorSnapshot`.
pub fn[Msg] ViewBuilderCache::stats(
  self : ViewBuilderCache[Msg],
) -> ViewBuilderCacheStats {
  {
    build_count: self.state.val.build_count,
    hit_count: self.state.val.hit_count,
    miss_count: self.state.val.miss_count,
    entry_count: self.state.val.entries.length(),
  }
}

///|
/// Return the view cached for `builder_key` when its recorded `content_key`
/// also matches. Otherwise run `build` and replace that builder's entry.
///
/// `builder_key` is the stable logical identity of the construction slot.
/// `content_key` is the complete dependency key for that slot. Use a stable
/// model-derived builder key across keyed reorders; include the reordered item's
/// content in `content_key`, not its array position in `builder_key`.
///
/// The builder should not mutate this cache's entry for the same builder key
/// while it runs. The cache is intended for synchronous, single-threaded view
/// construction.
pub fn[Msg] ViewBuilderCache::view(
  self : ViewBuilderCache[Msg],
  builder_key~ : DeclarationKey,
  content_key~ : DeclarationKey,
  build~ : () -> View[Msg],
) -> View[Msg] {
  match self.state.val.entries.get(builder_key) {
    Some(entry) if entry.content_key == content_key => {
      self.state.val.hit_count = self.state.val.hit_count + 1
      entry.view
    }
    _ => {
      self.state.val.miss_count = self.state.val.miss_count + 1
      let view = build()
      self.state.val.build_count = self.state.val.build_count + 1
      self.state.val.entries[builder_key] = { content_key, view, }
      view
    }
  }
}

///|
/// Remove one builder slot and its cached view.
///
/// Call this when a keyed item, conditional branch, or screen region leaves the
/// model. Counters remain cumulative. Removing an absent key is a no-op.
pub fn[Msg] ViewBuilderCache::remove(
  self : ViewBuilderCache[Msg],
  builder_key : DeclarationKey,
) -> Unit {
  self.state.val.entries.remove(builder_key)
}

///|
/// Remove every cached view without resetting construction counters.
///
/// Use this when the owning screen/root is torn down. Other handles that alias
/// this cache observe the cleared state.
pub fn[Msg] ViewBuilderCache::clear(self : ViewBuilderCache[Msg]) -> Unit {
  self.state.val.entries.clear()
}
