///|
/// A single-entry, explicitly keyed view-construction memo.
///
/// The caller owns the memo and supplies a canonical `DeclarationKey` covering
/// every input read by `build`. A hit returns the previously built `View`
/// without running `build`; a miss builds and replaces the entry.
///
/// This is deliberately not dependency tracking. A key that omits a model
/// field, message payload captured by an event handler, environment value, or
/// other view input will serve a stale view. Use one memo per independently
/// invalidated subtree, and construct the key with named record fields so the
/// dependency set is reviewable at the call site.
///
/// The memo caches construction, not runtime state. Element identity,
/// reconciliation, layout, paint, and transient control state remain owned by
/// the runtime.
///
/// `ViewMemo` is a handle: copying the struct aliases the same entry. Keep one
/// owner per independently invalidated subtree rather than sharing a memo
/// across unrelated call sites.
pub struct ViewMemo[Msg] {
  priv state : Ref[ViewMemoState[Msg]]
}

///|
/// A caller-readable snapshot of one memo's construction counters.
///
/// A miss is counted when a lookup is not served from the cache. A build is
/// counted after `build` returns successfully. They are normally equal, but
/// remain separate so a failed build cannot be mistaken for completed work.
pub struct ViewMemoStats {
  priv build_count : Int32
  priv hit_count : Int32
  priv miss_count : Int32
} derive(Eq, Debug)

///|
pub extend ViewMemoStats with Debug::{to_repr}

///|
pub extend ViewMemoStats with Eq::{not_equal, equal}

///|
priv struct ViewMemoState[Msg] {
  mut entry : ViewMemoEntry[Msg]?
  mut build_count : Int32
  mut hit_count : Int32
  mut miss_count : Int32
}

///|
priv struct ViewMemoEntry[Msg] {
  key : DeclarationKey
  view : View[Msg]
}

///|
pub fn[Msg] ViewMemo::new() -> ViewMemo[Msg] {
  { state: Ref({ entry: None, build_count: 0, hit_count: 0, miss_count: 0, }), }
}

///|
pub fn ViewMemoStats::build_count(self : ViewMemoStats) -> Int32 {
  self.build_count
}

///|
pub fn ViewMemoStats::hit_count(self : ViewMemoStats) -> Int32 {
  self.hit_count
}

///|
pub fn ViewMemoStats::miss_count(self : ViewMemoStats) -> Int32 {
  self.miss_count
}

///|
/// Return a snapshot of this memo's counters.
///
/// The counters stay inside the caller-owned memo. They are not registered
/// globally and do not appear in `RuntimeInspectorSnapshot`, which only knows
/// about runtime-owned caches.
pub fn[Msg] ViewMemo::stats(self : ViewMemo[Msg]) -> ViewMemoStats {
  {
    build_count: self.state.val.build_count,
    hit_count: self.state.val.hit_count,
    miss_count: self.state.val.miss_count,
  }
}

///|
/// Return the view for `key`, running `build` only when this memo has no entry
/// for that key.
pub fn[Msg] ViewMemo::view(
  self : ViewMemo[Msg],
  key~ : DeclarationKey,
  build~ : () -> View[Msg],
) -> View[Msg] {
  match self.state.val.entry {
    Some(entry) if entry.key == key => {
      self.state.val.hit_count = self.state.val.hit_count + 1
      entry.view
    }
    _ => {
      self.state.val.miss_count = self.state.val.miss_count + 1
      let view = build()
      self.state.val.build_count = self.state.val.build_count + 1
      self.state.val.entry = Some({ key, view, })
      view
    }
  }
}
