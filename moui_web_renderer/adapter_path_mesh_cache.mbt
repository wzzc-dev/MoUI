// Host-retained path meshes.
//
// A wasm-gc module has no linear memory to share, so a tessellated path crosses
// the boundary through `begin_create_string`/`string_append_char`: one import
// call per code point. A path vertex is fifteen `Double`s printed in full
// decimal, so one vertex costs roughly 150 calls, and a scene that repaints the
// same vector content every frame pays that again and again. Measured on the
// pelican scene, `wasm-to-js`, `string_append_char` and the host-side re-parse
// together took ~60% of the main thread while the rasterizer sat idle.
//
// The host now keeps the parsed mesh behind an integer handle and this adapter
// remembers it, keyed by the `PathSpec` whose tessellation produced it. A
// repeated path costs one two-scalar call; only geometry the host has not seen
// before pays tessellation, serialization and transfer.

///|
fn WebGpuPathMeshCache::new(limit : Int32) -> WebGpuPathMeshCache {
  { entries: [], frame: 0, limit, }
}

///|
fn WebGpuPathMeshCache::advance_frame(self : WebGpuPathMeshCache) -> Unit {
  self.frame = self.frame + 1
}

///|
/// The entry that belongs to `path`, whether or not its host mesh is still
/// alive. Identity is exact structural `PathSpec` equality, so a hit can never
/// draw the wrong geometry; two paths that hold the same verbs and brushes
/// share one mesh, which is what the host would have drawn anyway.
fn WebGpuPathMeshCache::find_entry(
  self : WebGpuPathMeshCache,
  path : @core.PathSpec,
) -> WebGpuPathMeshEntry? {
  for entry in self.entries {
    if entry.path == path {
      return Some(entry)
    }
  }
  None
}

///|
/// The host mesh to draw `path` with, if this adapter holds one the host still
/// has. Either way the entry's recency is touched, so a path that keeps being
/// looked up is the last one to leave the cache.
fn WebGpuPathMeshCache::find(
  self : WebGpuPathMeshCache,
  path : @core.PathSpec,
) -> Int32? {
  match self.find_entry(path) {
    Some(entry) => {
      entry.used_at = self.frame
      if entry.host_id > 0 {
        Some(entry.host_id)
      } else {
        None
      }
    }
    None => None
  }
}

///|
/// Mark `path` as needing a fresh upload and keep its slot. Used when the host
/// reports the mesh is gone, which is what happens after WebGPU recovery swaps
/// the page runtime this wasm module was instantiated against.
fn WebGpuPathMeshCache::forget(
  self : WebGpuPathMeshCache,
  path : @core.PathSpec,
) -> Unit {
  match self.find_entry(path) {
    Some(entry) => entry.host_id = 0
    None => ()
  }
}

///|
/// Remember that `host_id` is the host mesh for `path`. Returns the host mesh to
/// release because its slot was recycled to make room, or None when nothing was
/// displaced.
///
/// Space comes from the least recently used entry, and a mesh the host already
/// dropped goes first, so a long-running app cannot grow this cache past `limit`.
fn WebGpuPathMeshCache::record(
  self : WebGpuPathMeshCache,
  path : @core.PathSpec,
  host_id : Int32,
) -> Int32? {
  match self.find_entry(path) {
    Some(entry) => {
      let retired = entry.host_id
      entry.path = path
      entry.host_id = host_id
      entry.used_at = self.frame
      webgpu_retired_mesh(retired, host_id)
    }
    None =>
      if self.entries.length() < self.limit {
        self.entries.push({ path, host_id, used_at: self.frame, })
        None
      } else {
        match self.recyclable_entry() {
          None => {
            self.entries.push({ path, host_id, used_at: self.frame, })
            None
          }
          Some(recycled) => {
            let retired = recycled.host_id
            recycled.path = path
            recycled.host_id = host_id
            recycled.used_at = self.frame
            webgpu_retired_mesh(retired, host_id)
          }
        }
      }
  }
}

///|
/// The entry to hand to a new path: one whose host mesh is already gone, else
/// the one used longest ago.
fn WebGpuPathMeshCache::recyclable_entry(
  self : WebGpuPathMeshCache,
) -> WebGpuPathMeshEntry? {
  let mut chosen : WebGpuPathMeshEntry? = None
  for entry in self.entries {
    let better = match chosen {
      None => true
      Some(current) => webgpu_mesh_entry_is_more_reclaimable(entry, current)
    }
    if better {
      chosen = Some(entry)
    }
  }
  chosen
}

///|
fn webgpu_mesh_entry_is_more_reclaimable(
  candidate : WebGpuPathMeshEntry,
  current : WebGpuPathMeshEntry,
) -> Bool {
  if candidate.host_id == 0 && current.host_id > 0 {
    true
  } else if candidate.host_id > 0 && current.host_id == 0 {
    false
  } else {
    candidate.used_at < current.used_at
  }
}

///|
/// A recycled slot only leaks a host mesh when the incoming handle differs from
/// the one it held.
fn webgpu_retired_mesh(retired : Int32, incoming : Int32) -> Int32? {
  if retired > 0 && retired != incoming {
    Some(retired)
  } else {
    None
  }
}

///|
let webgpu_path_mesh_cache_limit : Int32 = 256

///|
/// One cache per wasm instance: the host meshes it names live in the page
/// runtime this module was instantiated against, which is also per page.
let webgpu_path_mesh_cache : WebGpuPathMeshCache = WebGpuPathMeshCache::new(
  webgpu_path_mesh_cache_limit,
)
