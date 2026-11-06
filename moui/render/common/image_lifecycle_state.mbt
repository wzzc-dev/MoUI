///|
/// Renderer-neutral image record state machine. `generation` advances
/// on every actual record mutation so hot per-frame callers can skip
/// re-reading the record set when nothing changed.
#derive(Eq, Debug)
pub struct ImageResourceLifecycle {
  priv mut records : Map[String, @render.ImageResourceRecord]
  priv mut generation : Int64
}

///|
pub extend ImageResourceLifecycle with Debug::{to_repr}

///|
pub extend ImageResourceLifecycle with Eq::{not_equal, equal}

///|
pub fn ImageResourceLifecycle::new() -> ImageResourceLifecycle {
  { records: Map([]), generation: 0L, }
}

///|
/// Monotonic diff token: bumped every time the record set actually
/// changes (new record, changed status, eviction). A caller that
/// observes the same generation twice knows a re-scan would find
/// nothing new, so the snapshot pull and dedup scan can be skipped.
pub fn ImageResourceLifecycle::generation(
  self : ImageResourceLifecycle,
) -> Int64 {
  self.generation
}

///|
pub fn ImageResourceLifecycle::lookup(
  self : ImageResourceLifecycle,
  source : String,
) -> @render.ImageResourceRecord? {
  self.records.get(source)
}

///|
/// Returns the current records as a fresh array. Hot per-frame callers
/// should consult `generation` first and skip this call while it stands
/// still; the rebuild is only paid when a change actually happened.
pub fn ImageResourceLifecycle::snapshot(
  self : ImageResourceLifecycle,
) -> Array[@render.ImageResourceRecord] {
  self.snapshot_records()
}

///|
fn ImageResourceLifecycle::snapshot_records(
  self : ImageResourceLifecycle,
) -> Array[@render.ImageResourceRecord] {
  let records : Array[@render.ImageResourceRecord] = []
  for _, record in self.records {
    records.push(record)
  }
  records
}
