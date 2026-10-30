///|
fn path_mesh_test_triangle(x : Double) -> @core.PathSpec {
  @core.PathSpec::new(
    verbs=[
      @core.MoveTo(@core.Point::new(x~, y=1.0)),
      @core.LineTo(@core.Point::new(x=x + 8.0, y=1.0)),
      @core.LineTo(@core.Point::new(x~, y=8.0)),
      @core.Close,
    ],
    fill=Some(@core.Brush::solid(@core.Color::blue())),
    stroke=None,
    stroke_width=1.0,
  )
}

///|
test "path mesh cache keys on path structure, not identity" {
  let cache = WebGpuPathMeshCache::new(4)
  let path = path_mesh_test_triangle(0.0)
  assert_true(cache.find(path) is None)
  assert_true(cache.record(path, 7) is None)
  assert_eq(cache.find(path), Some(7))
  // A rebuilt spec with the same verbs and brushes tessellates to the same
  // mesh, so it must hit the entry the first spec created.
  let rebuilt = path_mesh_test_triangle(0.0)
  assert_true(rebuilt == path)
  assert_eq(cache.find(rebuilt), Some(7))
  assert_eq(cache.entries.length(), 1)
  // Different geometry is a different mesh.
  assert_true(cache.find(path_mesh_test_triangle(4.0)) is None)
}

///|
test "path mesh cache retires the handle it displaces" {
  let cache = WebGpuPathMeshCache::new(2)
  cache.advance_frame()
  let first = path_mesh_test_triangle(0.0)
  assert_true(cache.record(first, 10) is None)
  cache.advance_frame()
  let second = path_mesh_test_triangle(4.0)
  assert_true(cache.record(second, 20) is None)
  // `first` is now the most recently used, so the oldest live mesh goes.
  cache.advance_frame()
  assert_eq(cache.find(first), Some(10))
  cache.advance_frame()
  let third = path_mesh_test_triangle(8.0)
  assert_eq(cache.record(third, 30), Some(20))
  assert_eq(cache.entries.length(), 2)
  assert_eq(cache.find(third), Some(30))
  assert_true(cache.find(second) is None)
  assert_eq(cache.find(first), Some(10))
}

///|
test "path mesh cache reclaims a dropped mesh before a live one" {
  let cache = WebGpuPathMeshCache::new(2)
  cache.advance_frame()
  let dropped = path_mesh_test_triangle(0.0)
  assert_true(cache.record(dropped, 10) is None)
  cache.advance_frame()
  let live = path_mesh_test_triangle(4.0)
  assert_true(cache.record(live, 20) is None)
  // The host reported `dropped` as gone, so it holds no mesh but its slot was
  // just touched: a plain least-recently-used policy would evict `live` here.
  cache.forget(dropped)
  cache.advance_frame()
  assert_true(cache.find(dropped) is None)
  let incoming = path_mesh_test_triangle(8.0)
  assert_eq(cache.record(incoming, 30), None)
  assert_eq(cache.find(live), Some(20))
  assert_eq(cache.find(incoming), Some(30))
}

///|
test "path mesh cache replaces a re-uploaded path in place" {
  let cache = WebGpuPathMeshCache::new(2)
  let path = path_mesh_test_triangle(0.0)
  assert_true(cache.record(path, 5) is None)
  assert_eq(cache.record(path, 6), Some(5))
  assert_eq(cache.find(path), Some(6))
  assert_eq(cache.entries.length(), 1)
  // Re-recording the handle it already holds releases nothing.
  assert_true(cache.record(path, 6) is None)
}

///|
test "path mesh cache frame counter only moves on present" {
  let cache = WebGpuPathMeshCache::new(2)
  assert_eq(cache.frame, 0)
  cache.advance_frame()
  cache.advance_frame()
  assert_eq(cache.frame, 2)
  let path = path_mesh_test_triangle(0.0)
  assert_true(cache.record(path, 3) is None)
  let used_at = match cache.find_entry(path) {
    Some(entry) => entry.used_at
    None => -1
  }
  assert_eq(used_at, 2)
}
