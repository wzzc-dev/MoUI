///|
priv struct MeshCacheDecision {
  mut revision : Int64
  mut uploads : Int
}

///|
fn MeshCacheDecision::new() -> MeshCacheDecision {
  { revision: -1L, uploads: 0 }
}

///|
fn MeshCacheDecision::observe(
  self : MeshCacheDecision,
  revision : Int64,
) -> Bool {
  if self.revision == revision {
    false
  } else {
    self.revision = revision
    self.uploads = self.uploads + 1
    true
  }
}

///|
test "native mesh cache uploads once per packet revision" {
  let cache = MeshCacheDecision::new()
  assert_true(cache.observe(4L))
  assert_true(!cache.observe(4L))
  assert_true(cache.observe(5L))
  assert_eq(cache.uploads, 2)
}
